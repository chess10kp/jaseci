# ceval type definitions (jac-py/PLAN.md §4 acyclic leaf).
# Callable/heap proxy types extracted from ceval.jac; spokes import these
# instead of ceval. Back-edge calls go through ceval_api forwarders.

import from hash_dispatch { hash_element, }
import from abstract_protocol {
    PyObject_GetIter,
    PyIter_Check,
    PyObject_Hash,
    PyObject_HashNotImplemented,
}
import from exceptions_core { exc_name_matches, }
import from typeobject { type_richcompare, }
import from dictobject { dict_richcompare, }
import from vm_dispatch { jac_frame_chain_slot_ref, }
import from ceval_api {
    _jac_builtin_base_name,
    _jac_builtin_new,
    _jac_conversion_ctor_kind,
    _jac_host_eq,
    _jac_host_hashkey,
    _jac_host_same_object,
    _jac_host_type_attr,
    _jac_host_type_name,
    _jac_is_complex_type,
    _jac_is_object_type,
    _jac_is_slice_type,
    _jac_is_super_type,
    _jac_is_type_type,
    _jac_static_type_name,
    _jac_validate_type_bases,
    as_error,
    bind_attribute,
    builtin_sorted_min_max,
    call_user_dunder,
    class_full_mro,
    class_is_exception,
    class_lookup_attr,
    class_mro,
    compute_host_base,
    construct_host_typed_base,
    construct_native_base,
    default_user_delattro,
    default_user_getattro,
    default_user_setattro,
    descriptor_get,
    dict_from_str_map,
    dict_lookup_value,
    dict_subscript_missing,
    frame_clear,
    exec_code_frame,
    format_exception_text,
    from_host,
    func_attr_is_fixed,
    agen_asend_step,
    gc_track_user,
    gen_close,
    gen_send,
    gen_throw,
    host_builtin,
    host_getattr,
    host_getitem,
    host_import,
    host_iter,
    host_result_error,
    host_result_ok,
    host_setattr,
    instance_of_class,
    is_mutable_base,
    is_notimplemented,
    localsplus_name,
    metaclass_of,
    meth_no_kwargs,
    meth_takes_none,
    meth_takes_one,
    mro_hash_blocked,
    normalize_throw_args,
    obj_is_callable,
    py_attr,
    py_aiter,
    py_anext,
    py_build_class,
    py_call_host,
    py_compare,
    py_convert_complex,
    py_convert_float,
    py_convert_int,
    py_del_attr,
    py_dir,
    py_hash,
    py_id,
    py_identity,
    py_invoke,
    py_isinstance,
    py_issubclass,
    py_iter,
    py_len,
    py_raise_value,
    py_repr,
    py_set_attr,
    py_slot_truth,
    py_store_subscript,
    py_str,
    py_type_of,
    send_into,
    stop_iteration,
    to_host,
    to_host_coerce,
    type_new,
    user_binop,
    user_compare,
    user_has_dunder,
    user_instance_dict,
}
import from objects {
    Py_EQ,
    Py_NE,
    DictEntry,
    _unhashable_error,
    PyObj,
    PyInt,
    PyStr,
    PyBool,
    PyNoneType,
    PyCode,
    PyCell,
    PyTuple,
    PyList,
    PyDict,
    PySet,
    PySlice,
    PyError,
    PyException,
    PyExceptionType,
    PyCallableIter,
    PyIter,
    find_name,
    expect_str,
    py_none,
    py_error,
    is_error,
    hashkey_str,
    dict_key_repr,
    PY_NOT_IMPLEMENTED,
}

# opcode_meta NB_OR / NB_INPLACE_OR (ceval_defs cannot import opcode_meta)
glob _NB_OR: int = 7;
glob _NB_INPLACE_OR: int = 20;

obj PyHostProxy(PyObj) {
    has val: any;

    # Proxies follow the wrapped host object's identity/equality so dict/set
    # bucketing by tp_hashkey (the host hash) stays consistent: same host
    # object -> equal; distinct host objects defer to host ==. Non-proxy
    # operands defer to the caller's fallback (PY_NOT_IMPLEMENTED).
    def tp_richcompare(kind: int, other: PyObj) -> PyObj {
        if kind != 2 and kind != 3 {
            return PY_NOT_IMPLEMENTED;
        }
        if isinstance(other, PyHostProxy) {
            mine = self.val;
            theirs = (other as PyHostProxy).val;
            if _jac_host_same_object(mine, theirs) {
                return PyBool(t="bool", val=kind == 2);
            }
            res = _jac_host_eq(mine, theirs);
            if not ((res[0] as bool)) {
                return host_result_error(res);
            }
            if (res[1] as bool) {
                return PyBool(t="bool", val=True);
            }
            return PY_NOT_IMPLEMENTED;
        }
        return PY_NOT_IMPLEMENTED;
    }

    def tp_getattro(name: str) -> PyObj {
        # object.__new__ builds a plain in-VM instance (so a user class's __new__
        # that calls it produces a PyUserObj, not a host object). Narrow to the
        # exact `object` type; every other type's __new__ stays host-routed.
        if name == "__new__" and _jac_is_object_type(self.val) {
            return PyNativeNew(t="native_new", base_name="object");
        }
        # Unbound object.__getattribute__/__setattr__/__delattr__: the canonical
        # delegation target inside user overrides (object.__setattr__(self, n,
        # v)). A host proxy would see to_host(instance) == None; route through
        # PyObjectAttrSlot instead, which runs the default protocol in-VM.
        if _jac_is_object_type(self.val)
            and (name == "__getattribute__" or name == "__setattr__"
                or name == "__delattr__") {
            return PyObjectAttrSlot(t="obj_attr_slot", op=name);
        }
        # A subclassable builtin's __new__ (str.__new__, int.__new__, ...) builds a
        # native subclass instance boxing that value, so `str.__new__(EnumCls, v)`
        # (enum member creation for a str/int mixin) yields a PyUserObj tagged with
        # the native class -- not a host str.__new__(None) on a lost to_host class.
        if name == "__new__" {
            builtin_name: str = str(_jac_builtin_base_name(self.val));
            if builtin_name != "" {
                return PyNativeNew(t="native_new", base_name=builtin_name);
            }
        }
        return host_getattr(self, name);
    }

    def tp_setattro(name: str, value: PyObj) -> PyObj {
        # CPython type___setattr__ policy, allow-on-subclass-only: a static
        # builtin/extension type (int, str, tuple, ...) rejects every attribute
        # write with the canonical TypeError -- enforced natively so the answer
        # never depends on the assigned value surviving the host-boundary
        # coercion. Heap types (Python classes, guest standin classes) keep
        # delegating to the host, where writes stick.
        tname: str = str(_jac_static_type_name(self.val));
        if tname != "" {
            return py_error(
                "TypeError",
                "can't set attributes of built-in/extension type '" + tname + "'"
            );
        }
        return host_setattr(self, name, value);
    }

    def tp_call(args: list[PyObj], kwargs: dict[str, PyObj]) -> PyObj {
        # `type(x)` (one positional arg) must be answered in-VM: a native user
        # instance's type is its own PyClass, not host type(to_host(x)) -- which
        # was NoneType because to_host of a plain user object is None. The 3-arg
        # `type(name, bases, ns)` class constructor and every real metaclass call
        # stay host-routed. `type` is the exact builtin here, never a subclass.
        if len(args) == 1 and len(kwargs) == 0 and bool(_jac_is_type_type(self.val)) {
            return py_type_of(args[0]);
        }
        # 3-arg type(name, bases, ns): reject __mro_entries__ / non-class bases
        # with CPython's messages BEFORE building. Then construct IN-VM per
        # CPython type_call: resolve the most-derived metaclass among 'type'
        # and the bases' metaclasses and build through it. Host routing here
        # minted standins and lost class identity entirely (enum's
        # _simple_enum converts classes through exactly this shape).
        if len(args) == 3 and bool(_jac_is_type_type(self.val)) {
            raw_bases: list[PyObj] = [];
            if isinstance(args[1], PyTuple) {
                for tb in (args[1] as PyTuple).items {
                    raw_bases.append(tb);
                }
            } elif isinstance(args[1], PyList) {
                for tb in (args[1] as PyList).items {
                    raw_bases.append(tb);
                }
            }
            rejected = _jac_validate_type_bases(raw_bases);
            if rejected is not None {
                return rejected;
            }
            winner: any = None;
            conflict = False;
            for tb3 in raw_bases {
                if not isinstance(tb3, PyClass) {
                    continue;
                }
                bm3 = metaclass_of(tb3 as PyClass);
                if bm3 is None or not isinstance(bm3, PyClass) {
                    continue;
                }
                if winner is None {
                    winner = bm3;
                } elif py_issubclass(bm3 as PyObj, winner as PyObj) {
                    # current winner stays most-derived
                } elif py_issubclass(winner as PyObj, bm3 as PyObj) {
                    winner = bm3;
                } else {
                    conflict = True;
                }
            }
            if conflict {
                return py_error("TypeError", "metaclass conflict");
            }
            ns_obj = args[2];
            if winner is not None {
                made_t = py_invoke(
                    winner as PyObj, [args[0], args[1], ns_obj], kwargs
                );
                if is_error(made_t) {
                    return made_t;
                }
                return made_t;
            }
            built_t = type_new([self as PyObj, args[0], args[1], ns_obj], kwargs);
            if is_error(built_t) {
                return built_t;
            }
            return built_t;
        }
        # Zero-arg super() at a GENERIC call site (the proxy wraps the host
        # super TYPE): the compiler lowers every cell-backed super().attr to
        # LOAD_SUPER_ATTR, so this is exactly CPython's frame-without-cell case
        # -- raise its error instead of letting the host super introspect the
        # jaclang interpreter's own Python frame.
        if len(args) == 0 and len(kwargs) == 0 and bool(_jac_is_super_type(self.val)) {
            return py_error("RuntimeError", "super(): no arguments");
        }
        # The conversion constructors int()/float()/bool()/str() over a NATIVE
        # operand answer through the implicit slot machinery instead of crossing
        # the bridge: to_host of a plain user object is None, so the host
        # constructor saw nothing (bool(obj) was literally False; int(obj),
        # float(obj) raised; str(obj) yielded 'None'). Each native operand found
        # converts ITSELF (never args[0]).
        #
        # EXCEPTION -- explicit-base int(x, base): every operand must cross,
        # so builtin-mixin instances (an Enum-style str/int subclass) unwrap
        # to their boxed base value and the host constructor parses with the
        # FULL argument list. Hijacking the native operand alone dropped the
        # base (int(str_sub('ff'), 16) failed as "base 10"). A plain user
        # instance stays opaque; the host then reports CPython's own "can't
        # convert non-string with explicit base" TypeError.
        ckind = str(_jac_conversion_ctor_kind(self.val));
        if ckind == "int" and (len(args) >= 2 or len(kwargs) > 0) {
            unwrapped: list[PyObj] = [];
            for a in args {
                if isinstance(a, PyUserObj) and (a as PyUserObj)._has_base() {
                    unwrapped.append((a as PyUserObj)._base_obj());
                } else {
                    unwrapped.append(a);
                }
            }
            return py_call_host(self, unwrapped, kwargs);
        }
        if len(args) >= 1 and ckind != "" {
            for a in args {
                if isinstance(a, PyUserObj) {
                    if ckind == "bool" {
                        return py_slot_truth(a);
                    }
                    if ckind == "int" {
                        return py_convert_int(a);
                    }
                    if ckind == "str" {
                        return py_str(a);
                    }
                    return py_convert_float(a);
                }
            }
        }
        # The complex() constructor over native operands answers in-VM
        # (string parsing, numeric promotion); shapes without a native
        # answer fall back to the host call below, byte-exact.
        if len(args) <= 2 and bool(_jac_is_complex_type(self.val)) {
            cres = py_convert_complex(args);
            if not is_notimplemented(cres) {
                return cres;
            }
        }
        # The slice() constructor answers in-VM as a native PySlice: every
        # subscript slot gates on isinstance(PySlice), so a host proxy here
        # would make xs[s] raise "list indices must be integers or slices"
        # while inline xs[1:7:2] works (same rationale as from_host's slice
        # branch). Bounds are stored raw exactly like BUILD_SLICE; CPython's
        # arity/keyword errors are raised before any construction.
        if bool(_jac_is_slice_type(self.val)) {
            if len(kwargs) > 0 {
                return py_error("TypeError", "slice() takes no keyword arguments");
            }
            if len(args) == 0 {
                return py_error("TypeError", "slice expected at least 1 argument, got 0");
            }
            if len(args) > 3 {
                return py_error(
                    "TypeError",
                    "slice expected at most 3 arguments, got " + str(len(args)),
                );
            }
            if len(args) == 1 {
                return PySlice(t="slice", start=py_none(), stop=args[0], step=py_none());
            }
            step_arg = py_none();
            if len(args) == 3 {
                step_arg = args[2];
            }
            return PySlice(t="slice", start=args[0], stop=args[1], step=step_arg);
        }
        return py_call_host(self, args, kwargs);
    }

    def tp_hashkey -> PyObj {
        hks: str = str(_jac_host_hashkey(self.val));
        if hks == "" {
            return py_error("TypeError", "unhashable type");
        }
        return PyStr(t="str", val=hks);
    }

    def mp_subscript(index: PyObj) -> PyObj {
        return host_getitem(self, index);
    }

    def tp_iter -> PyObj {
        return host_iter(self);
    }
}

# ---------------- native range (TODO item 19) --------------------------------
# Heap-type wrapper over the lifted leaf math in rangeobject.jac: identity and
# O(1) len/contains/index/slice arithmetic instead of materializing elements
# across the bridge. Design: docs/RANGE_BRIDGE_DESIGN.md.
obj PyClass(PyObj) {
    has name: str,
        attrs: dict[str, PyObj],
        bases: list[PyObj] = [],
        native_base: str = "",
        # Non-builtin host C-type ancestor (io.BytesIO, zlib.Compress, ...)
        # recorded by compute_host_base: the resolved host type itself. Unlike
        # plain user classes there is live per-instance C state behind every
        # method call, so instances must box a REAL base instance.
        host_base: any = None,
        # The type OF this class (its metaclass). None means the default `type`.
        # A user metaclass (EnumType, ABCMeta) is recorded here by type.__new__ so
        # `class Sub(Base)` can re-derive it from a base and re-run the protocol.
        metaclass: any = None,
        # ``PyType_Ready`` lifecycle flags (P5 heap types).
        tp_flags: int = 0,
        # __slots__ layout state (CPython type_new_set_attrs / type_ready setdict):
        # slot_members is the MERGED member list (own mangled members first, then
        # inherited), slots_declared gates enforcement (a late `Cls.__slots__ =
        # ...` assignment must stay inert), and instance_has_dict follows the
        # CPython inheritance rule -- no declaration means a dict; with one, only
        # an explicit `__dict__` entry or a dict-bearing base keeps the dict.
        # Defaults keep every non-slotted construction site permissive.
        slot_members: list[str] = [],
        slots_declared: bool = False,
        instance_has_dict: bool = True;

    # Attribute lookup walks the MRO (self first, then bases) so an inherited
    # method/attr is visible on a subclass. Instance access binds via PyUserObj.
    def tp_getattro(name: str) -> PyObj {
        # A class's __name__ is its own name, NOT whatever the body namespace left
        # behind: the class-body frame seeds `__name__` to the module name (correct
        # inside the body), and that entry leaks into attrs. Answer from self.name
        # before the attribute lookup so `Cls.__name__` isn't the module. (__module__
        # legitimately IS that seeded module name, so it stays an attrs lookup.)
        if name == "__name__" {
            return PyStr(t="str", val=self.name);
        }
        if name == "__class__" {
            # CPython: a class's __class__ IS its metaclass (type when none).
            if self.metaclass is not None {
                return self.metaclass as PyObj;
            }
            return host_builtin("type");
        }
        found = class_lookup_attr(self, name);
        if not is_error(found) {
            # Class-level access: a classmethod binds this class, a staticmethod
            # unwraps, a property object is returned as-is (no instance to invoke).
            return descriptor_get(found, py_none(), self);
        }
        # Standard type dunders CPython always answers: a missing docstring is
        # None, and __name__/__qualname__ report the class name.
        if name == "__doc__" {
            return py_none();
        }
        if name == "__name__" or name == "__qualname__" {
            return PyStr(t="str", val=self.name);
        }
        if name == "__dict__" {
            return dict_from_str_map(self.attrs);
        }
        if name == "__mro__" {
            return PyTuple(t="tuple", items=class_full_mro(self));
        }
        if name == "mro" {
            return PyClassMroMethod(t="class_mro", cls=self);
        }
        if name == "__bases__" {
            # CPython type_ready seeds a baseless class with (object,).
            if len(self.bases) > 0 {
                return PyTuple(t="tuple", items=self.bases);
            }
            return PyTuple(t="tuple", items=[host_builtin("object")]);
        }
        if name == "__base__" {
            if len(self.bases) > 0 {
                return self.bases[0];
            }
            return host_builtin("object");
        }
        # A class with no user __new__ inherits object.__new__ (or the builtin base
        # constructor). Attribute access -- unlike class_lookup_attr, which drives
        # construction -- exposes it so `Cls.__new__` reads and compares (enum's
        # _find_new_ tests target against object.__new__/Enum.__new__).
        if name == "__new__" {
            base = self.native_base;
            if base == "" or base == "type" {
                base = "object";
            }
            return PyNativeNew(t="native_new", base_name=base);
        }
        # Inherited slot-wrapper surface: CPython serves `Cls.__repr__` through
        # the metaclass channel -- type(Cls).__mro__ reaches object, whose type
        # dict carries every slot wrapper. Guest classes store no such entries
        # in attrs, so walk the MRO's native-base surfaces first (a dict
        # subclass inherits dict.__repr__'s wrapper) and finish on object's.
        for klass_obj in class_mro(self) {
            klass = klass_obj as PyClass;
            nb = klass.native_base;
            if nb != "" {
                r = _jac_host_type_attr(nb, name);
                if host_result_ok(r) {
                    return from_host(r[1]);
                }
            }
        }
        obj_r = _jac_host_type_attr("object", name);
        if host_result_ok(obj_r) {
            return from_host(obj_r[1]);
        }
        # A method defined on the metaclass (EnumType._add_member_, __call__) is
        # accessible on the class itself, bound to it -- the class is an instance
        # of its metaclass.
        meta_found = self._meta_dunder(name);
        if not is_error(meta_found) {
            return meta_found;
        }
        return py_error("AttributeError", name);
    }

    def tp_setattro(name: str, value: PyObj) -> PyObj {
        self.attrs[name] = value;
        return py_none();
    }

    # A class is hashable by identity (type-keyed dispatch tables, base_chain sets
    # in enum's _find_data_type_). Distinct classes get distinct buckets.
    def tp_hashkey -> PyObj {
        return PyStr(t="str", val="obj:" + str(id(self)));
    }

    # Classes compare by identity: `ReprEnum in (Enum,)` must be False so enum's
    # ReprEnum-mixin check doesn't misfire on distinct classes.
    def tp_richcompare(kind: int, other: PyObj) -> PyObj {
        return type_richcompare(kind, self as PyObj, other);
    }

    # A metaclass instance dunder: looked up on the class's metaclass MRO and bound
    # to this class. `for m in EnumColor` dispatches EnumType.__iter__(cls); the
    # same channel serves __getitem__/__contains__/__len__ on a class.
    def _meta_dunder(name: str) -> PyObj {
        if self.metaclass is not None and isinstance(self.metaclass, PyClass) {
            found = class_lookup_attr(self.metaclass as PyClass, name);
            if not is_error(found) {
                return bind_attribute(found, self);
            }
        }
        return py_error("AttributeError", name);
    }

    def tp_iter -> PyObj {
        it = self._meta_dunder("__iter__");
        if is_error(it) {
            return py_error("TypeError", "object is not iterable");
        }
        return it.tp_call([], {});
    }

    def mp_subscript(index: PyObj) -> PyObj {
        # A custom metaclass __getitem__ outranks __class_getitem__: CPython
        # installs slot_tp_subscript on the metaclass, which intercepts before
        # type_subscript ever consults the class MRO.
        gi = self._meta_dunder("__getitem__");
        if not is_error(gi) {
            return gi.tp_call([index], {});
        }
        # type_subscript fallback: resolve __class_getitem__ on this class's own
        # MRO (an explicit def or one inherited from Generic / an ABC base) and
        # bind it to the class -- Cls[...] is sugar for
        # Cls.__class_getitem__(index).
        cgi = class_lookup_attr(self, "__class_getitem__");
        if not is_error(cgi) and isinstance(cgi, PyNoneType) {
            # CPython type_subscript: __class_getitem__ = None means the class
            # explicitly opted out -- fall through to the not-subscriptable
            # error naming this class.
            cgi = py_error("AttributeError", "__class_getitem__");
        }
        if not is_error(cgi) {
            return bind_attribute(cgi, self).tp_call([index], {});
        }
        return py_error(
            "TypeError", "type '" + self.name + "' is not subscriptable"
        );
    }

    def tp_call(args: list[PyObj], kwargs: dict[str, PyObj]) -> PyObj {
        # A python-level __new__ (common on builtin subclasses that control their
        # boxed value, e.g. re._constants._NamedIntConstant) governs construction:
        # call __new__(cls, *args) and use its return value. __init__ then runs
        # only if __new__ returned an instance of this class (CPython's rule).
        # NOTE the two shapes __new__ takes from guest namespaces: since the
        # type_new_staticmethod replication above, guest-stored __new__ is a
        # PyStaticMethod wrapping the real function; CPython's type_call looks
        # through the descriptor to the underlying function.
        user_new = class_lookup_attr(self, "__new__");
        new_fn: any = py_none();
        has_user_new = False;
        if not is_error(user_new) {
            cand: any = user_new;
            if isinstance(user_new, PyStaticMethod) {
                cand = (user_new as PyStaticMethod).func;
            }
            if isinstance(cand, PyFunction) or isinstance(cand, PyHostProxy) {
                new_fn = cand;
                has_user_new = True;
            }
        }
        if not has_user_new and self.native_base == "type"
            and len(args) == 3
            and isinstance(args[0], PyStr)
            and isinstance(args[1], PyTuple)
            and isinstance(args[2], PyDict) {
            # CPython type_call falls back to the inherited type.__new__ slot
            # when neither this metaclass nor its ancestors define one. The
            # factory-shaped call (name, bases, ns) must BUILD THE CLASS tagged
            # with metaclass=self -- degrading to a blank instance of the
            # metaclass loses the class identity entirely ('C.__class__ is M'
            # False, instances unconstructible).
            factory_args: list[PyObj] = [self as PyObj];
            for fa in args {
                factory_args.append(fa);
            }
            built = type_new(factory_args, kwargs);
            # CPython type_call runs the metaclass __init__ after __new__ on
            # this path too: type.__new__ returned a class tagged with THIS
            # metaclass, so Meta.__init__(cls, name, bases, ns) must fire even
            # when Meta itself defines no __new__ (same silent-drop shape the
            # user-__new__ branch below guards against).
            if isinstance(built, PyClass) and (built as PyClass).metaclass is self {
                built_init = class_lookup_attr(self, "__init__");
                if not is_error(built_init) and isinstance(built_init, PyFunction) {
                    built_ir = bind_attribute(built_init, built).tp_call(args, kwargs);
                    if built_ir.t == "error" {
                        return built_ir;
                    }
                }
            }
            return built;
        }
        if has_user_new {
            new_args: list[PyObj] = [self];
            for a in args {
                new_args.append(a);
            }
            made = py_invoke(new_fn as PyObj, new_args, kwargs);
            if is_error(made) {
                return made;
            }
            # CPython type_call runs __init__ iff isinstance(obj, cls). Two
            # shapes qualify: an ordinary PyUserObj instance, AND the class
            # object itself on the class-creation path (type.__new__ returns a
            # PyClass tagged with THIS metaclass -- skipping its __init__ here
            # silently drops _ProtocolMeta-style bodies).
            made_is_meta_inst = False;
            if isinstance(made, PyUserObj)
                and instance_of_class(made as PyUserObj, self) {
                made_is_meta_inst = True;
            }
            if isinstance(made, PyClass)
                and (made as PyClass).metaclass is self {
                made_is_meta_inst = True;
            }
            if made_is_meta_inst {
                init2 = class_lookup_attr(self, "__init__");
                if not is_error(init2) and isinstance(init2, PyFunction) {
                    ir = bind_attribute(init2, made).tp_call(args, kwargs);
                    if ir.t == "error" {
                        return ir;
                    }
                } elif self.native_base == "set" and len(kwargs) > 0 {
                    # No user __init__: CPython's type_call still runs the
                    # MRO-resolved initializer -- set.__init__, which rejects
                    # keywords (`subclass_with_new(x, newarg=3)` must raise).
                    # list/tuple/frozenset resolve leniently here (their slot
                    # inheritance drops excess args); dict consumed **kwds at
                    # __new__ time.
                    return py_error(
                        "TypeError", "set() takes no keyword arguments"
                    );
                }
            }
            return made;
        }
        # A subclass of a builtin (native_base != "") boxes the underlying value.
        # An immutable base (int/str/...) takes its value at __new__ time from the
        # args. A mutable base (dict/list/set) WITH a user __init__ is created empty
        # -- __init__ (which typically calls super().__init__(...)) fills it -- so
        # `class D(dict): def __init__(self, name): super().__init__()` boxes an
        # empty dict, not dict(name). Without a user __init__ the args fill it
        # directly (MyList([1,2,3])).
        init = class_lookup_attr(self, "__init__");
        has_user_init = not is_error(init);
        boxed: PyObj = py_none();
        if self.native_base != "" {
            if not has_user_init and len(kwargs) > 0
                and self.native_base != "dict" {
                # With no user __init__ the MRO-resolved initializer is the
                # builtin base's own -- it rejects keywords exactly as the bare
                # constructor does (`Sub(sequence=())` must TypeError).
                return py_error(
                    "TypeError", self.native_base + "() takes no keyword arguments"
                );
            }
            box_args = args;
            if has_user_init and is_mutable_base(self.native_base) {
                box_args = [];
            }
            # Tuple subclasses without a recognized __new__ (host-eval namedtuple
            # lambdas that slipped past the PyFunction/PyHostProxy gate) still need
            # tuple.__new__(cls, (a, b, ...)) packing, not tuple(a, b, ...).
            if self.native_base == "tuple" and len(box_args) > 1 {
                box_args = [PyTuple(t="tuple", items=box_args)];
            }
            boxed = construct_native_base(self.native_base, box_args);
            if is_error(boxed) {
                return boxed;
            }
            if not has_user_init and self.native_base == "dict"
                and len(kwargs) > 0 {
                # dict is the one base whose constructor consumes **kwds.
                upd = PyDictMethod(
                    t="dict_method", target=(boxed as PyDict), name="update"
                ).tp_call([], kwargs);
                if upd.t == "error" {
                    return upd;
                }
            }
        } elif self.host_base is not None {
            # A non-builtin host C-type base boxes a REAL instance of the host
            # type (same empty-then-fill pattern as mutable builtins when a
            # user __init__ will call super().__init__ itself).
            if not has_user_init and len(kwargs) > 0 {
                tname: str = str(_jac_host_type_name(self.host_base));
                return py_error("TypeError", tname + "() takes no keyword arguments");
            }
            box_args2 = args;
            if has_user_init {
                box_args2 = [];
            }
            boxed = construct_host_typed_base(self.host_base, box_args2);
            if is_error(boxed) {
                return boxed;
            }
        }
        instance = PyUserObj(t="instance", cls=self, attrs={}, base=boxed);
        gc_track_user(instance);
        if class_is_exception(self) {
            # CPython's BaseException_new records the constructor args on the
            # instance BEFORE __init__ runs, so a user __init__ that never calls
            # super().__init__ still leaves e.args == constructor args.
            arg_items: list[PyObj] = [];
            arg_items.extend(args);
            instance.attrs["args"] = PyTuple(t="tuple", items=arg_items);
        }
        if has_user_init {
            initialized = bind_attribute(init, instance).tp_call(args, kwargs);
            if initialized.t == "error" {
                return initialized;
            }
        }
        return instance;
    }
}

# The generic heap-type object (PLAN.md §5): one archetype for every user
# class instance; its slots resolve through instance/class dict lookup rather
# than a per-type vtable -- exactly the static-vs-heap line CPython draws.
obj PyUserObj(PyObj) {
    has cls: PyClass,
        attrs: dict[str, PyObj],
        base: any = None,
        # Live instance-``__dict__`` view (PyInstanceDict) minted on first
        # access and kept identity-stable -- CPython returns the SAME dict
        # object every time. attrs_version mirrors attribute mutations into
        # the view so reads through it stay current.
        dict_cache: any = None,
        attrs_version: int = 0;

    # The boxed builtin value (int/str/...) for a builtin subclass, or a
    # PyNoneType sentinel for a plain user class. _has_base tells them apart.
    def _has_base -> bool {
        return self.base is not None and not isinstance(self.base, PyNoneType);
    }

    def _base_obj -> PyObj {
        return self.base as PyObj;
    }

    def tp_getattro(name: str) -> PyObj {
        # CPython slot_tp_getattro: the MRO-resolved __getattribute__ IS the get
        # protocol -- it wraps EVERYTHING (properties, instance dict, __class__,
        # the boxed base). The lookup is a raw class-dict walk (never an
        # attribute access), so resolving the override cannot re-enter it.
        attr_override = class_lookup_attr(self.cls, "__getattribute__");
        if not is_error(attr_override) {
            res = bind_attribute(attr_override, self as PyObj).tp_call(
                [PyStr(t="str", val=name)], {}
            );
        } else {
            res = default_user_getattro(self, name);
        }
        # slot_tp_getattr: an AttributeError from the get protocol (user
        # override or default) falls back to a type-level __getattr__.
        if is_error(res)
            and isinstance(res, PyError)
            and (res as PyError).exception.type_name == "AttributeError" {
            fallback = class_lookup_attr(self.cls, "__getattr__");
            if not is_error(fallback) {
                return bind_attribute(fallback, self as PyObj).tp_call(
                    [PyStr(t="str", val=name)], {}
                );
            }
        }
        return res;
    }

    def tp_setattro(name: str, value: PyObj) -> PyObj {
        # Mirror of tp_getattro for writes: a type-level __setattr__ intercepts
        # every assignment BEFORE data-descriptor checks (slot_tp_setattro).
        attr_override = class_lookup_attr(self.cls, "__setattr__");
        if not is_error(attr_override) {
            return bind_attribute(attr_override, self as PyObj).tp_call(
                [PyStr(t="str", val=name), value], {}
            );
        }
        return default_user_setattro(self, name, value);
    }

    # ---- boxed-builtin slot delegation (subclass of int/str/list/...) --------
    # When the class dict doesn't override a slot, a builtin subclass behaves as
    # its boxed value: MyInt(5)+1 == 6, MyInt(5) is a valid dict key, etc. The
    # right operand is unwrapped too so MyInt(5)+MyInt(1) works.
    def nb_binop(kind: int, other: PyObj) -> PyObj {
        return user_binop(kind, self, other);
    }

    def tp_richcompare(kind: int, other: PyObj) -> PyObj {
        return user_compare(kind, self, other);
    }

    def to_index -> PyObj {
        # A user-defined __index__ IS the index slot (operator.index()).
        if user_has_dunder(self, "__index__") {
            res = call_user_dunder(self, "__index__", []);
            if is_error(res) {
                return res;
            }
            if isinstance(res, PyBool) {
                return PyInt(t="int", val=1 if (res as PyBool).val else 0);
            }
            if isinstance(res, PyInt) {
                return res;
            }
            return py_error(
                "TypeError", "__index__ returned non-int of type '" + res.t + "'"
            );
        }
        # A builtin-int subclass instance (re._constants._NamedIntConstant, an
        # IntEnum member, ...) indexes as its boxed int.
        if self._has_base() {
            return self._base_obj().to_index();
        }
        return py_error("TypeError", "object cannot be interpreted as an integer");
    }

    def tp_hashkey -> PyObj {
        # CPython slot machinery (Objects/typeobject.c): inherit_slots (~8372)
        # copies tp_richcompare AND tp_hash together from the first MRO base
        # only while this class overrides neither; otherwise a still-NULL
        # tp_hash is resolved by type_ready_set_hash (~8773), which injects
        # tp_dict["__hash__"] = None (update_one_slot ~11655 maps that None to
        # PyObject_HashNotImplemented). Net rule, reproduced here without the
        # dict mutation: walk the MRO; the NEAREST class dict defining either
        # name decides.
        if mro_hash_blocked(self) {
            return py_error("TypeError", "unhashable type");
        }
        # A user-defined __hash__ keys the object by value; routing through
        # py_hash keeps raised/non-int returns byte-exact with hash() itself
        # (slot_tp_hash, typeobject.c ~10295).
        if user_has_dunder(self, "__hash__") {
            h = py_hash(self as PyObj);
            if is_error(h) {
                return h;
            }
            return PyStr(t="str", val="n:" + str((h as PyInt).val));
        }
        if self._has_base() {
            return self._base_obj().tp_hashkey();
        }
        # Default object.__hash__: identity-keyed, distinct per object.
        return PyStr(t="str", val="obj:" + str(id(self)));
    }

    # CPython ``tp_name``: error messages quote the real class name, not the
    # internal "instance" tag (e.g. "cannot use 'AlwaysEq' as a set element").
    def tp_type_name -> str {
        return self.cls.name;
    }

    def tp_bool -> bool {
        if self._has_base() {
            return self._base_obj().tp_bool();
        }
        return True;
    }

    def tp_iter -> PyObj {
        # A user-defined __iter__ returns the iterator (driven by FOR_ITER/SEND
        # via its __next__); fall back to a boxed builtin base, else not iterable.
        if user_has_dunder(self, "__iter__") {
            return call_user_dunder(self, "__iter__", []);
        }
        if self._has_base() {
            return self._base_obj().tp_iter();
        }
        return py_error("TypeError", "object is not iterable");
    }

    def tp_call(args: list[PyObj], kwargs: dict[str, PyObj]) -> PyObj {
        # A user-defined __call__ makes the instance callable: bind the MRO-
        # resolved dunder to the instance and invoke it. A raised exception
        # propagates verbatim (same path as every other dunder slot); no result
        # check -- any object __call__ returns is the call's value.
        if user_has_dunder(self, "__call__") {
            method = class_lookup_attr(self.cls, "__call__");
            return bind_attribute(method, self).tp_call(args, kwargs);
        }
        if self._has_base() {
            return self._base_obj().tp_call(args, kwargs);
        }
        return py_error("TypeError", "object is not callable");
    }

    def mp_subscript(index: PyObj) -> PyObj {
        if user_has_dunder(self, "__getitem__") {
            return call_user_dunder(self, "__getitem__", [index]);
        }
        if self._has_base() {
            base = self._base_obj();
            # A builtin-dict base with no __getitem__ override IS
            # ``dict.__getitem__`` -- route the miss through the type-level
            # __missing__ consult (defaultdict / user subclasses).
            if isinstance(base, PyDict) {
                return dict_subscript_missing(self, base as PyDict, index);
            }
            return base.mp_subscript(index);
        }
        return py_error("TypeError", "object is not subscriptable");
    }

    def mp_ass_subscript(index: PyObj, value: PyObj) -> PyObj {
        if user_has_dunder(self, "__setitem__") {
            r = call_user_dunder(self, "__setitem__", [index, value]);
            if is_error(r) {
                return r;
            }
            return py_none();
        }
        if self._has_base() {
            # Route through public dispatch so builtin-subclass storage shares
            # the slice-assignment iterable normalization (a boxed list receives
            # values of its own Python type, not just native PyList).
            return py_store_subscript(self._base_obj(), index, value);
        }
        return py_error("TypeError", "object does not support item assignment");
    }

    def mp_del_subscript(index: PyObj) -> PyObj {
        if user_has_dunder(self, "__delitem__") {
            r = call_user_dunder(self, "__delitem__", [index]);
            if is_error(r) {
                return r;
            }
            return py_none();
        }
        if self._has_base() {
            return self._base_obj().mp_del_subscript(index);
        }
        return py_error("TypeError", "object does not support item deletion");
    }
}

# The DEFAULT attribute protocol for a generic instance -- what
# object.__getattribute__/__setattr__/__delattr__ do in CPython. Factored out of
# PyUserObj so the slot dispatch AND the exposed object.__*attr__ slot wrappers
# (PyObjectAttrSlot) share one implementation: calling through the wrapper runs
# the default protocol directly, which is exactly CPython's recursion guard for
# a user __getattribute__/__setattr__ delegating via
# object.__getattribute__(self, n) / super().__setattr__(n, v).
obj PyInstanceDict(PyDict) {
    # ``owner`` is typed ``any`` because a non-default field cannot follow the
    # inherited defaulted ``version`` field.
    has owner: any = None,
        overlay: dict[str, PyObj] = {};

    # Single mutation entry for mirrored attribute writes. Items live under
    # the SAME hash-key namespace as every other PyDict ("s:"-prefixed for
    # str keys), so inherited lookups/iteration see them.
    def view_set(name: str, value: PyObj) {
        hk = hashkey_str((PyStr(t="str", val=name)).tp_hashkey());
        self.items[hk] = DictEntry(key=PyStr(t="str", val=name), value=value);
        self.version = self.version + 1;
    }

    # Single removal entry for mirrored attribute deletes.
    def view_del(name: str) {
        del self.items[hashkey_str((PyStr(t="str", val=name)).tp_hashkey())];
        self.version = self.version + 1;
    }

    def mp_ass_subscript(index: PyObj, value: PyObj) -> PyObj {
        hkr = index.tp_hashkey();
        if is_error(hkr) {
            return _unhashable_error("a dict key", index);
        }
        if isinstance(index, PyStr) {
            name = (index as PyStr).val;
            owner_u = self.owner as PyUserObj;
            if name in owner_u.cls.slot_members {
                self.overlay[name] = value;
            } else {
                owner_u.attrs[name] = value;
            }
            self.view_set(name, value);
            return py_none();
        }
        # Non-string key: a pure dict entry, invisible to the attribute
        # protocol (CPython stores it in the instance dict the same way).
        self.items[hashkey_str(hkr)] = DictEntry(key=index, value=value);
        self.version = self.version + 1;
        return py_none();
    }

    def mp_del_subscript(index: PyObj) -> PyObj {
        hkr = index.tp_hashkey();
        if is_error(hkr) {
            return _unhashable_error("a dict key", index);
        }
        if isinstance(index, PyStr) {
            name = (index as PyStr).val;
            owner_u = self.owner as PyUserObj;
            if name in self.overlay {
                del self.overlay[name];
                self.view_del(name);
                return py_none();
            }
            if name in owner_u.attrs {
                del owner_u.attrs[name];
                self.view_del(name);
                return py_none();
            }
            return py_error("KeyError", dict_key_repr(index));
        }
        hk = hashkey_str(hkr);
        if hk in self.items {
            del self.items[hk];
            self.version = self.version + 1;
            return py_none();
        }
        return py_error("KeyError", dict_key_repr(index));
    }
}

obj PyClassMroMethod(PyObj) {
    has cls: PyClass;

    def tp_call(args: list[PyObj], kwargs: dict[str, PyObj]) -> PyObj {
        if len(kwargs) > 0 {
            return py_error("TypeError", "mro() takes no keyword arguments");
        }
        if len(args) > 0 {
            return py_error(
                "TypeError",
                self.cls.name + ".mro() takes no arguments (" + str(len(args)) + " given)",
            );
        }
        return PyList(t="list", items=class_full_mro(self.cls));
    }
}



# Bound __mro_entries__ callable for PyGenericAlias: CPython's _GenericAlias
# method returns a tuple of replacement bases when __build_class__ invokes it
# (bltinmodule.c update_bases); ours resolves to Generic itself.
obj PyStaticMethod(PyObj) {
    has func: PyObj;

    def tp_getattro(name: str) -> PyObj {
        if name == "__func__" {
            return self.func;
        }
        # Descriptor protocol visibility (see PyGetDescriptorFn).
        if name == "__get__" {
            return PyGetDescriptorFn(t="get_descriptor", target=self);
        }
        return py_attr(self.func, name);
    }

    def tp_setattro(name: str, value: PyObj) -> PyObj {
        return self.func.tp_setattro(name, value);
    }
}

obj PyObjectAttrSlot(PyObj) {
    has op: str,
        target: any = None;

    def tp_call(args: list[PyObj], kwargs: dict[str, PyObj]) -> PyObj {
        recv: PyObj;
        rest: list[PyObj] = [];
        if self.target is None {
            if len(args) < 1 {
                return py_error(
                    "TypeError", "unbound attribute slot needs an instance"
                );
            }
            recv = args[0];
            for i in range(1, len(args)) {
                rest.append(args[i]);
            }
        } else {
            recv = self.target as PyObj;
            rest.extend(args);
        }
        if self.op == "__getattribute__" {
            if len(rest) != 1 {
                return py_error(
                    "TypeError",
                    "__getattribute__ expected 1 argument, got " + str(len(rest)),
                );
            }
            name = expect_str(rest[0]);
            if isinstance(recv, PyUserObj) {
                return default_user_getattro(recv as PyUserObj, name);
            }
            return py_attr(recv, name);
        }
        if self.op == "__setattr__" {
            if len(rest) != 2 {
                return py_error(
                    "TypeError",
                    "__setattr__ expected 2 arguments, got " + str(len(rest)),
                );
            }
            name2 = expect_str(rest[0]);
            if isinstance(recv, PyUserObj) {
                return default_user_setattro(recv as PyUserObj, name2, rest[1]);
            }
            return py_set_attr(recv, name2, rest[1]);
        }
        if len(rest) != 1 {
            return py_error(
                "TypeError",
                "__delattr__ expected 1 argument, got " + str(len(rest)),
            );
        }
        name3 = expect_str(rest[0]);
        if isinstance(recv, PyUserObj) {
            return default_user_delattro(recv as PyUserObj, name3);
        }
        return py_del_attr(recv, name3);
    }
}

obj PyFunction(PyObj) {
    has code: PyCode,
        globals: dict[str, PyObj],
        name: str,
        defaults: list[PyObj] = [],
        kwdefaults: dict[str, PyObj] = {},
        closure: list[PyCell] = [],
        # The function's writable __dict__ + overridable dunders. functools.wraps
        # / update_wrapper copy __module__/__name__/__qualname__/__doc__ and set
        # __wrapped__ here, so decorators (pervasive in the unittest closure) work.
        attrs: dict[str, PyObj] = {},
        # Identity-stable live views minted on first read; invalidated by
        # explicit reassignment.
        kw_live: any = None,
        attr_dict_live: any = None;

    def _func_doc -> PyObj {
        if len(self.code.consts) > 0 and isinstance(self.code.consts[0], PyStr) {
            return self.code.consts[0];
        }
        return py_none();
    }

    def tp_getattro(name: str) -> PyObj {
        if name in self.attrs {
            return self.attrs[name];
        }
        if name == "__name__" {
            return PyStr(t="str", val=self.name);
        }
        if name == "__qualname__" {
            return PyStr(t="str", val=self.code.qualname);
        }
        if name == "__doc__" {
            return self._func_doc();
        }
        if name == "__module__" {
            if "__name__" in self.globals {
                return self.globals["__name__"];
            }
            return py_none();
        }
        if name == "__defaults__" {
            # An explicit f.__defaults__ assignment lands in attrs (checked
            # above); this branch serves the MAKE_FUNCTION-built table.
            if len(self.defaults) == 0 {
                return py_none();
            }
            return PyTuple(t="tuple", items=self.defaults);
        }
        if name == "__kwdefaults__" {
            # CPython: None when no keyword-only default exists; otherwise the
            # SAME live dict every read, whose mutations affect later calls.
            if len(self.kwdefaults) == 0 {
                return py_none();
            }
            if self.kw_live is not None {
                return self.kw_live as PyObj;
            }
            kw_view = PyFuncKwDefaults(t="dict", owner=self, items={});
            for k in self.kwdefaults {
                hk = hashkey_str((PyStr(t="str", val=k)).tp_hashkey());
                kw_view.items[hk] = DictEntry(
                    key=PyStr(t="str", val=k), value=self.kwdefaults[k]
                );
            }
            self.kw_live = kw_view;
            return kw_view as PyObj;
        }
        if name == "__closure__" {
            # CPython: None for functions without free variables, else a tuple
            # of cells (introspection surface used by inspect and functools).
            if len(self.closure) == 0 {
                return py_none();
            }
            return PyTuple(t="tuple", items=self.closure);
        }
        if name == "__code__" {
            return self.code;
        }
        if name == "__dict__" {
            # functools.wraps / update_wrapper reads and UPDATES a function's
            # __dict__ (WRAPPER_UPDATES), so the snapshot-per-read copy lost
            # every update -- CPython hands out the live attribute dict.
            # Fixed-surface names (__name__, __code__, ...) stay out of the
            # view exactly as they are absent from CPython's func_dict.
            if self.attr_dict_live is not None {
                return self.attr_dict_live as PyObj;
            }
            attr_view = PyFuncDictView(t="dict", owner=self, items={});
            for k in self.attrs {
                if not func_attr_is_fixed(k) {
                    hk = hashkey_str((PyStr(t="str", val=k)).tp_hashkey());
                    attr_view.items[hk] = DictEntry(
                        key=PyStr(t="str", val=k), value=self.attrs[k]
                    );
                }
            }
            self.attr_dict_live = attr_view;
            return attr_view as PyObj;
        }
        if name == "__wrapped__" {
            return py_error("AttributeError", name);
        }
        # Descriptor protocol visibility: functions ARE descriptors; enum's
        # _EnumDict and inspect/functools classify via hasattr(obj, '__get__').
        if name == "__get__" {
            return PyGetDescriptorFn(t="get_descriptor", target=self);
        }
        return py_error("AttributeError", name);
    }

    def tp_setattro(name: str, value: PyObj) -> PyObj {
        if name == "__kwdefaults__" {
            # Rebind: the call path resolves through attrs from now on, so the
            # old live view would go stale -- drop it.
            self.kw_live = None;
        }
        self.attrs[name] = value;
        # Dynamic attributes join the live __dict__ view; fixed-surface names
        # never appear in it (CPython keeps them on the type).
        if self.attr_dict_live is not None and not func_attr_is_fixed(name) {
            (self.attr_dict_live as PyFuncDictView).view_set(name, value);
        }
        return py_none();
    }

    # Effective default tables for THIS call: an explicit __defaults__ /
    # __kwdefaults__ attribute assignment overrides the MAKE_FUNCTION tables
    # (CPython binds those attributes to the call machinery).
    def _effective_defaults -> list[PyObj] {
        if "__defaults__" in self.attrs {
            v = self.attrs["__defaults__"];
            if v is not None and isinstance(v, PyTuple) {
                return (v as PyTuple).items;
            }
            return [];
        }
        return self.defaults;
    }

    def _effective_kwdefaults -> dict[str, PyObj] {
        if "__kwdefaults__" in self.attrs {
            v = self.attrs["__kwdefaults__"];
            if v is not None and isinstance(v, PyDict) {
                return (v as PyDict).dict_str_map();
            }
            return {};
        }
        return self.kwdefaults;
    }
    def tp_hashkey -> PyObj {
        return PyStr(t="str", val="obj:" + str(id(self)));
    }

    def tp_call(args: list[PyObj], kwargs: dict[str, PyObj]) -> PyObj {
        return exec_code_frame(
            self.code,
            args,
            kwargs,
            self.globals,
            {},
            self.closure,
            self._effective_defaults(),
            self._effective_kwdefaults()
        );
    }
}

obj PyFuncDictView(PyDict) {
    # ``owner`` is typed ``any`` because a non-default field cannot follow the
    # inherited defaulted ``version`` field.
    has owner: any = None;

    def view_set(name: str, value: PyObj) {
        hk = hashkey_str((PyStr(t="str", val=name)).tp_hashkey());
        self.items[hk] = DictEntry(key=PyStr(t="str", val=name), value=value);
        self.version = self.version + 1;
    }

    def mp_ass_subscript(index: PyObj, value: PyObj) -> PyObj {
        hkr = index.tp_hashkey();
        if is_error(hkr) {
            return _unhashable_error("a dict key", index);
        }
        hk = hashkey_str(hkr);
        if isinstance(index, PyStr) {
            name = (index as PyStr).val;
            self.items[hk] = DictEntry(key=index, value=value);
            self.version = self.version + 1;
            if not func_attr_is_fixed(name) {
                (self.owner as PyFunction).attrs[name] = value;
            }
            return py_none();
        }
        self.items[hk] = DictEntry(key=index, value=value);
        self.version = self.version + 1;
        return py_none();
    }

    def mp_del_subscript(index: PyObj) -> PyObj {
        hkr = index.tp_hashkey();
        if is_error(hkr) {
            return _unhashable_error("a dict key", index);
        }
        hk = hashkey_str(hkr);
        if isinstance(index, PyStr) {
            name = (index as PyStr).val;
            owner_f = self.owner as PyFunction;
            if name in owner_f.attrs {
                del owner_f.attrs[name];
                del self.items[hk];
                self.version = self.version + 1;
                return py_none();
            }
        }
        if hk in self.items {
            del self.items[hk];
            self.version = self.version + 1;
            return py_none();
        }
        return py_error("KeyError", dict_key_repr(index));
    }
}

# Live ``__kwdefaults__`` view for a PyFunction: a real dict whose mutations
# write straight through to the function's kw-default table (CPython hands
# out the borrowed internal dict; later calls observe every change).
obj PyFuncKwDefaults(PyDict) {
    # ``owner`` is typed ``any`` because a non-default field cannot follow the
    # inherited defaulted ``version`` field.
    has owner: any = None;

    def mp_ass_subscript(index: PyObj, value: PyObj) -> PyObj {
        hkr = index.tp_hashkey();
        if is_error(hkr) {
            return _unhashable_error("a dict key", index);
        }
        hk = hashkey_str(hkr);
        if isinstance(index, PyStr) {
            name = (index as PyStr).val;
            (self.owner as PyFunction).kwdefaults[name] = value;
        } else {
            return py_error(
                "TypeError", "keywords must be strings"
            );
        }
        self.items[hk] = DictEntry(key=index, value=value);
        self.version = self.version + 1;
        return py_none();
    }

    def mp_del_subscript(index: PyObj) -> PyObj {
        hkr = index.tp_hashkey();
        if is_error(hkr) {
            return _unhashable_error("a dict key", index);
        }
        hk = hashkey_str(hkr);
        if isinstance(index, PyStr) {
            name = (index as PyStr).val;
            owner_f = self.owner as PyFunction;
            if name in owner_f.kwdefaults {
                del owner_f.kwdefaults[name];
                del self.items[hk];
                self.version = self.version + 1;
                return py_none();
            }
        } elif hk in self.items {
            del self.items[hk];
            self.version = self.version + 1;
            return py_none();
        }
        return py_error("KeyError", dict_key_repr(index));
    }
}
# Cycle guard for from_host container conversion (host marshal/pickle can
# hand back SELF-REFERENTIAL structures, e.g. marshal.loads(b'[<R>]')). Keyed
# on host id(); list/dict/set placeholders are registered BEFORE filling so
# re-entry returns the same guest container (identity preserved); tuples are
# immutable so a re-entrant reference degrades to a host proxy instead of
# recursing forever.
obj PyNativeNew(PyObj) {
    has base_name: str;

    # Value identity by base_name so every object.__new__ producer compares equal
    # (enum's _find_new_ does `target in {object.__new__, ...}`).
    def tp_hashkey -> PyObj {
        return PyStr(t="str", val="nativenew:" + self.base_name);
    }

    def tp_richcompare(kind: int, other: PyObj) -> PyObj {
        same = isinstance(other, PyNativeNew)
            and self.base_name == (other as PyNativeNew).base_name;
        if kind == 2 {
            return PyBool(t="bool", val=same);
        }
        if kind == 3 {
            return PyBool(t="bool", val=not same);
        }
        return py_error("TypeError", "unsupported comparison");
    }

    def tp_call(args: list[PyObj], kwargs: dict[str, PyObj]) -> PyObj {
        if len(args) == 0 {
            return py_error("TypeError", "__new__() takes a class argument");
        }
        target_cls = args[0];
        # type.__new__(mcls, name, bases, namespace): the class factory reached by
        # super().__new__ inside a metaclass __new__. Builds a PyClass tagged with
        # mcls as its metaclass so a subclass re-runs the same protocol.
        if self.base_name == "type" {
            return type_new(args, kwargs);
        }
        # object.__new__(cls): a plain instance, no boxed builtin value. This is
        # the super().__new__(cls) / object.__new__(cls) path of a class whose
        # only base is object (functools._PlaceholderType, most user classes).
        if self.base_name == "object" {
            if isinstance(target_cls, PyClass) {
                return PyUserObj(
                    t="instance", cls=target_cls as PyClass, attrs={}, base=py_none()
                );
            }
            return py_error("TypeError", "object.__new__ requires a class");
        }
        box_args: list[PyObj] = [];
        j = 1;
        while j < len(args) {
            box_args.append(args[j]);
            j = j + 1;
        }
        if self.base_name == "tuple" and len(box_args) > 1 {
            box_args = [PyTuple(t="tuple", items=box_args)];
        }
        # builtin.__new__ over a HOST class (namedtuple's dynamic tuple subclass)
        # stays host-side so the host subclass instance is preserved.
        if isinstance(target_cls, PyHostProxy) {
            raw_box: list[any] = [];
            for a in box_args {
                raw_box.append(to_host(a));
            }
            hres = _jac_builtin_new(
                self.base_name, (target_cls as PyHostProxy).val, raw_box
            );
            if host_result_ok(hres) {
                return from_host(hres[1]);
            }
            return host_result_error(hres);
        }
        boxed = construct_native_base(self.base_name, box_args);
        if is_error(boxed) {
            return boxed;
        }
        if isinstance(target_cls, PyClass) {
            return PyUserObj(
                t="instance", cls=target_cls as PyClass, attrs={}, base=boxed
            );
        }
        # Called with the exact builtin type (not a user subclass): plain value.
        return boxed;
    }
}

# super().<name> delegation when no python ancestor defines <name>: inside a
# builtin-subclass method (dict/list/... subclass) the boxed base's own slots
# answer -- e.g. _EnumDict(dict).__setitem__ calling super().__setitem__(k, v)
# mutates the underlying dict -- and a BASE-LESS class falls through to the
# object surface (object.__repr__/__str__/__init__). Bound to the instance at
# lookup time, so the call site applies only the operands.
obj PyDictMethod(PyObj) {
    has target: PyDict,
        name: str;

    def tp_call(args: list[PyObj], kwargs: dict[str, PyObj]) -> PyObj {
        n = self.name;
        d = self.target;
        # CPython method-descriptor arity contracts, byte-exact: fixed-arity
        # methods raise instead of ignoring extras; only update consumes **kwds.
        if n != "update" and len(kwargs) > 0 {
            return meth_no_kwargs("dict", n);
        }
        if n == "popitem" or n == "clear" or n == "copy" {
            if len(args) != 0 {
                return meth_takes_none("dict", n, len(args));
            }
        }
        if n == "__contains__" or n == "__getitem__" {
            if len(args) != 1 {
                return meth_takes_one("dict", n, len(args));
            }
        }
        if n == "__setitem__" and len(args) != 2 {
            return py_error("TypeError", "__setitem__ expected 2 arguments, got " + str(len(args)));
        }
        if n == "__delitem__" and len(args) != 1 {
            return py_error("TypeError", "expected 1 argument, got " + str(len(args)));
        }
        if n == "get" or n == "setdefault" or n == "pop" {
            if len(args) < 1 {
                return py_error("TypeError", n + " expected at least 1 argument, got 0");
            }
            if len(args) > 2 {
                return py_error("TypeError", n + " expected at most 2 arguments, got " + str(len(args)));
            }
        }
        if n == "update" and len(args) > 1 {
            return py_error("TypeError", "update expected at most 1 argument, got " + str(len(args)));
        }
        if n == "get" {
            if d.dict_contains(args[0]) {
                return d.mp_subscript(args[0]);
            }
            return args[1] if len(args) >= 2 else py_none();
        }
        if n == "setdefault" {
            if d.dict_contains(args[0]) {
                return d.mp_subscript(args[0]);
            }
            default_val = args[1] if len(args) >= 2 else py_none();
            r = d.mp_ass_subscript(args[0], default_val);
            if is_error(r) {
                return r;
            }
            return default_val;
        }
        if n == "pop" {
            if d.dict_contains(args[0]) {
                v = d.mp_subscript(args[0]);
                d.mp_del_subscript(args[0]);
                return v;
            }
            if len(args) >= 2 {
                return args[1];
            }
            return py_error("KeyError", dict_key_repr(args[0]));
        }
        if n == "popitem" {
            # LIFO: dict.popitem() returns the LAST inserted (key, value) pair,
            # not the first. dict_keys() yields insertion order, so take the tail.
            last_key: PyObj = py_none();
            has_key = False;
            for keyobj in d.dict_keys() {
                last_key = keyobj;
                has_key = True;
            }
            if has_key {
                v = d.mp_subscript(last_key);
                d.mp_del_subscript(last_key);
                return PyTuple(t="tuple", items=[last_key, v]);
            }
            return py_error("KeyError", "popitem(): dictionary is empty");
        }
        if n == "clear" {
            for keyobj in d.dict_keys() {
                d.mp_del_subscript(keyobj);
            }
            return py_none();
        }
        if n == "copy" {
            nd = PyDict(t="dict", items={});
            for keyobj in d.dict_keys() {
                nd.dict_set(keyobj, d.mp_subscript(keyobj));
            }
            return nd;
        }
        if n == "update" {
            if len(args) >= 1 {
                src = args[0];
                if isinstance(src, PyDict) {
                    sd = src as PyDict;
                    for keyobj in sd.dict_keys() {
                        d.dict_set(keyobj, sd.mp_subscript(keyobj));
                    }
                } elif isinstance(src, PyUserObj)
                    and (src as PyUserObj)._has_base()
                    and isinstance((src as PyUserObj)._base_obj(), PyDict) {
                    sd = (src as PyUserObj)._base_obj() as PyDict;
                    for keyobj in sd.dict_keys() {
                        d.dict_set(keyobj, sd.mp_subscript(keyobj));
                    }
                } else {
                    # An iterable of (key, value) pairs.
                    pairs: list[PyObj] = [];
                    if isinstance(src, PyList) {
                        pairs = (src as PyList).items;
                    } elif isinstance(src, PyTuple) {
                        pairs = (src as PyTuple).items;
                    } else {
                        seq = py_iter(src);
                        if is_error(seq) {
                            return seq;
                        }
                        if isinstance(seq, PyIter) {
                            pairs = (seq as PyIter).items;
                        }
                    }
                    for pair in pairs {
                        if isinstance(pair, PyTuple) {
                            pt = (pair as PyTuple).items;
                            if len(pt) == 2 {
                                d.dict_set(pt[0], pt[1]);
                            }
                        }
                    }
                }
            }
            for k in kwargs {
                d.dict_set(PyStr(t="str", val=k), kwargs[k]);
            }
            return py_none();
        }
        if n == "__contains__" {
            return PyBool(t="bool", val=d.dict_contains(args[0]));
        }
        if n == "__getitem__" {
            return d.mp_subscript(args[0]);
        }
        if n == "__setitem__" {
            return d.mp_ass_subscript(args[0], args[1]);
        }
        if n == "__delitem__" {
            return d.mp_del_subscript(args[0]);
        }
        return py_error("AttributeError", n);
    }
}

# ---- native dict views (.keys()/.values()/.items()) -----------------------
# CPython dict views are lazy, set-like windows on a live dict. Native ones let
# view comparison / set operations invoke element __eq__ (so a raising element
# comparison propagates, unlike the by-hashkey set model) and let view iteration
# carry the dict's mutation guard. keys/items are set-like; values is not.

# Sentinel returned by dict_lookup_value when a key is absent (None is a valid
# stored value, so it can't double as the not-found marker).

obj PyBoundMethod(PyObj) {
    has function: PyObj,
        receiver: PyObj;

    def tp_call(args: list[PyObj], kwargs: dict[str, PyObj]) -> PyObj {
        call_args: list[PyObj] = [self.receiver];
        call_args.extend(args);
        return self.function.tp_call(call_args, kwargs);
    }

    # A bound method exposes __func__/__self__ and otherwise forwards attribute
    # reads (__name__, __qualname__, __doc__) to the underlying function.
    def tp_getattro(name: str) -> PyObj {
        if name == "__func__" {
            return self.function;
        }
        if name == "__self__" {
            return self.receiver;
        }
        # Bound methods are descriptors too (self-reproducing __get__).
        if name == "__get__" {
            return PyGetDescriptorFn(t="get_descriptor", target=self);
        }
        return py_attr(self.function, name);
    }
}
# typing._GenericAlias(Generic, params) stand-in -- the implicit PEP 695 class
# base produced by CALL_INTRINSIC_1 arg 10 (INTRINSIC_SUBSCRIPT_GENERIC).
# Data-only: attribute answers (__origin__/__args__/__parameters__), the repr,
# and the __mro_entries__ hook live in ceval (py_attr / py_repr) because the
# origin is typing_generic_class() below and resolution re-enters execution.
obj PyGenericAlias(PyObj) {
    has params: PyObj;
}
obj PyBuildClass(PyObj) {
    def tp_call(args: list[PyObj], kwargs: dict[str, PyObj]) -> PyObj {
        return py_build_class(args, kwargs);
    }
}
obj PyGetDescriptorFn(PyObj) {
    has target: PyObj;

    def tp_call(args: list[PyObj], kwargs: dict[str, PyObj]) -> PyObj {
        instance = py_none();
        owner = py_none();
        if len(args) >= 1 {
            instance = args[0];
        }
        if len(args) >= 2 {
            owner = args[1];
        }
        return descriptor_get(self.target, instance, owner);
    }
}
glob _handled_exc_stack: list[PyObj] = [];

def current_handled_exc() -> PyObj {
    if len(_handled_exc_stack) == 0 {
        return py_none();
    }
    return _handled_exc_stack[len(_handled_exc_stack) - 1];
}

# Identity-counting removal of one occurrence per item: generator suspend must
# deactivate exactly ITS handler entries so unrelated frames stop seeing them
# (CPython exc_info is dynamic; the global stack is a single-threaded mirror).
def _handled_stack_remove_each(items: list[PyObj]) -> None {
    for it in items {
        idx = -1;
        i = 0;
        while i < len(_handled_exc_stack) {
            if py_identity(_handled_exc_stack[i], it) {
                idx = i;
                break;
            }
            i = i + 1;
        }
        if idx >= 0 {
            _handled_exc_stack = _handled_exc_stack[:idx] + _handled_exc_stack[idx + 1:];
        }
    }
}

def _handled_stack_append_each(items: list[PyObj]) -> None {
    for it in items {
        _handled_exc_stack.append(it);
    }
}
# ---------------- generator frame machinery (PLAN.md §5, P5) ----------------
# CPython implements a generator as a suspended frame; jacpython mirrors that.
# PyFrame captures the resumable eval state (stack/fast/ip). YIELD_VALUE
# saves it and hands a PyYield up to run_frame's caller; PyGenerator drives the
# frame forward one yield at a time. PyGenStop is the "frame returned normally"
# (StopIteration) sentinel that distinguishes exhaustion from a real raise.
obj PyFrame(PyObj) {
    has co: PyCode,
        # Merged localsplus: [varnames] [non-arg cellvar cells] [freevar cells].
        # Entries hold values or PyCell objects (see resolve_cell); OP_MAKE_CELL
        # converts more slots dynamically mid-frame.
        fast: list[PyObj],
        assigned: list[bool],
        closure: list[PyCell],
        stack: list[PyObj],
        globals: dict[str, PyObj],
        locals: dict[str, PyObj],
        ip: int = 0,
        # True when suspended inside `yield from` (YIELD_VALUE oparg 1). A throw
        # is then delegated into the sub-iterator via the SEND loop rather than
        # injected at the outer suspend point.
        yf: bool = False,
        # A pending exception to throw into the current yield-from sub-iterator,
        # consumed by the next SEND instead of a normal send.
        pending_throw: any = None,
        # True once the frame's locals/stack have been released (gen.close() or
        # gi_frame.clear()); guards against running __del__ finalizers twice.
        cleared: bool = False,
        # Exception-handler stack captured at a YIELD_VALUE suspension and
        # restored when the generator resumes, so a bare `raise` inside an
        # except block that spans a yield re-raises the right exception
        # (CPython keeps this state in the frame's exc_info across suspends).
        exc_state: list[PyObj] | None = None,
        # PEP 667 "extra locals" -- keys written through f_locals that are not
        # localsplus slots (CPython frame->f_extra_locals). Keyed by hashkey so
        # non-string keys work exactly like CPython's extras dict.
        extra_locals: dict[str, DictEntry] = {};

    def tp_getattro(name2: str) -> PyObj {
        if name2 == "f_locals" {
            return PyFrameLocalsProxy(t="frame_locals_proxy", frame=self) as PyObj;
        }
        if name2 == "f_globals" {
            return PyGlobalsProxy(t="globals", ns=self.globals);
        }
        if name2 == "f_code" {
            return self.co as PyObj;
        }
        if name2 == "f_back" {
            # The live guest chain published by run_frame (innermost last).
            i = len(jac_frame_chain_slot_ref()) - 1;
            while i >= 0 {
                if jac_frame_chain_slot_ref()[i] is self {
                    if i > 0 {
                        return jac_frame_chain_slot_ref()[i - 1] as PyObj;
                    }
                    break;
                }
                i = i - 1;
            }
            return py_none();
        }
        return py_error("AttributeError", name2);
    }
}

obj PyYield(PyObj) {
    has val: PyObj;
}
obj PyNativeBuiltin(PyObj) {
    has name: str;

    def tp_call(args: list[PyObj], kwargs: dict[str, PyObj]) -> PyObj {

        if self.name == "exc_info" {
            # sys.exc_info() over GUEST handled-exception state (host sys cannot
            # see guest frames). Returns (type, value, traceback); empty stack
            # yields CPython's (None, None, None).
            if len(_handled_exc_stack) == 0 {
                none3: list[PyObj] = [py_none(), py_none(), py_none()];
                return PyTuple(t="tuple", items=none3);
            }
            e = _handled_exc_stack[len(_handled_exc_stack) - 1] as PyException;
            tbv = e.tp_getattro("__traceback__");
            if is_error(tbv) or isinstance(tbv, PyNoneType) {
                tbv = py_none();
            }
            # CANONICAL type identity: CPython guarantees sys.exc_info()[0] is
            # THE exception class object (exc_info()[0] is ValueError). Two
            # shapes carry it: user exceptions keep their defining PyClass in
            # raw; everything else resolves through the memoized builtin
            # registry so repeated calls return the SAME marker. py_type_of
            # would instead mint a fresh host-type proxy per call -- right
            # __name__, wrong identity.
            etype: PyObj;
            if e.raw is not None and isinstance(e.raw, PyUserObj) {
                etype = (e.raw as PyUserObj).cls as PyObj;
            } else {
                etype = host_builtin(e.type_name);
                if is_error(etype) {
                    etype = py_type_of(e);
                }
            }
            vals: list[PyObj] = [etype, e, tbv];
            return PyTuple(t="tuple", items=vals);
        }
        if self.name == "sys_getframe" {
            # sys._getframe(depth=0) over GUEST frames (host sys cannot see
            # them): walk the live chain published by run_frame, innermost
            # last. Errors byte-match CPython's sysmodule.c.
            depth = 0;
            if len(args) > 0 {
                if not isinstance(args[0], PyInt) {
                    return py_error("TypeError", "an integer is required");
                }
                depth = (args[0] as PyInt).val;
                if depth < 0 {
                    return py_error("ValueError", "depth must be non-negative");
                }
            }
            i = len(jac_frame_chain_slot_ref()) - 1 - depth;
            if i < 0 {
                return py_error("ValueError", "call stack is not deep enough");
            }
            return jac_frame_chain_slot_ref()[i] as PyObj;
        }
        if self.name == "sys_currentframe" {
            # sys.currentframe(): None where _getframe would raise -- only
            # possible in guest when no frame is executing at all.
            if len(jac_frame_chain_slot_ref()) == 0 {
                return py_none();
            }
            return jac_frame_chain_slot_ref()[len(jac_frame_chain_slot_ref()) - 1] as PyObj;
        }
        if self.name == "anext" {
            # anext(aiter[, default]): must stay NATIVE -- routed through the
            # host, a guest async generator crosses to its stand-in face and
            # the yielded item is lost (silently-None / not-an-async-
            # iterator). Returns the __anext__ awaitable; the caller's AWAIT
            # drives it. Divergence: with default=, CPython converts the
            # terminal StopIteration into the default -- that conversion needs
            # coroutine wrapping and is documented as absent for now.
            if len(args) < 1 or len(args) > 2 {
                return py_error(
                    "TypeError", "anext expected at least 1 argument, got " + str(len(args))
                );
            }
            result = py_anext(args[0]);
            if is_error(result) {
                if len(args) == 2 and exc_name_matches(
                    (result as PyError).exception.type_name, "StopAsyncIteration"
                ) {
                    return args[1];
                }
                return result;
            }
            return result;
        }
        if self.name == "aiter" {
            if len(args) != 1 {
                return py_error("TypeError", "aiter expected exactly 1 argument");
            }
            return py_aiter(args[0]);
        }
        if self.name == "exception" {
            # sys.exception() over GUEST handled-exception state: the most
            # recently caught exception, or None with no active handler. Must
            # agree with the exc_info branch above (same _handled_exc_stack).
            if len(_handled_exc_stack) == 0 {
                return py_none();
            }
            return _handled_exc_stack[len(_handled_exc_stack) - 1];
        }
        if self.name == "intern" {
            # sys.intern() must return its argument ITSELF (CPython identity
            # contract). The host bridge would round-trip a guest PyStr into a
            # fresh host string, breaking `intern(s) is s`; keep it in-VM.
            if len(args) != 1 {
                return py_error(
                    "TypeError",
                    "intern expected 1 argument, got " + str(len(args))
                );
            }
            if not isinstance(args[0], PyStr) {
                return py_error(
                    "TypeError", "intern() argument must be str, not " + args[0].tp_type_name()
                );
            }
            return args[0];
        }
        if self.name == "tb_format_exc" {
            current_exc = current_handled_exc();
            if isinstance(current_exc, PyNoneType) {
                return PyStr(t="str", val="NoneType: None\n");
            }
            return format_exception_text(current_exc);
        }
        if self.name == "tb_print_exc" or self.name == "tb_print_exc_legacy" {
            # print_exc()/print_exception(): full-chain text to stderr or a
            # guest file-like. print_exc with no positional args reads the
            # CURRENTLY HANDLED exception; legacy form takes (etype, value, tb)
            # and renders value.
            target = py_none();
            for wkey in kwargs {
                if wkey == "file" {
                    target = kwargs[wkey];
                } else {
                    return py_error("TypeError", "unsupported keyword argument: " + wkey);
                }
            }
            no_pos = len(args) == 0;
            if self.name == "tb_print_exc" and len(args) > 0 and isinstance(args[0], PyNoneType) {
                no_pos = True;
            }
            if no_pos {
                print_exc = current_handled_exc();
                if isinstance(print_exc, PyNoneType) {
                    return py_error("RuntimeError", "No active exception to re-raise");
                }
                text = format_exception_text(print_exc);
            }
            elif self.name == "tb_print_exc_legacy" and len(args) >= 2 {
                text = format_exception_text(args[1]);
            }
            else {
                text = format_exception_text(args[0]);
            }
            w = py_attr(target, "write");
            if is_error(w) {
                return w;
            }
            return py_invoke(w, [text], {});
        }
        if self.name == "sorted" or self.name == "max" or self.name == "min" {
            return builtin_sorted_min_max(self.name, args, kwargs);
        }
        if self.name == "super" {
            # Zero-arg super() at a GENERIC call site: the compiler lowers every
            # super().attr / super().m() inside a method with a __class__ cell
            # to LOAD_SUPER_ATTR, so a plain super() call here is exactly
            # CPython's frame-without-cell case (class body, module level,
            # function without the closure) -- same RuntimeError.
            if len(args) == 0 and len(kwargs) == 0 {
                return py_error("RuntimeError", "super(): no arguments");
            }
        }
        if self.name == "id" {
            if len(kwargs) > 0 {
                return py_error("TypeError", "id() takes no keyword arguments");
            }
            if len(args) != 1 {
                return py_error(
                    "TypeError", "id() takes exactly one argument (" + str(len(args)) + " given)"
                );
            }
            return PyInt(t="int", val=py_id(args[0]));
        }
        if self.name == "len" {
            if len(args) != 1 {
                return py_error(
                    "TypeError", "len() takes exactly one argument (" + str(len(args)) + " given)"
                );
            }
            return py_len(args[0]);
        }
        if self.name == "hash" {
            if len(args) != 1 {
                return py_error(
                    "TypeError", "hash() takes exactly one argument (" + str(len(args)) + " given)"
                );
            }
            return py_hash(args[0]);
        }
        if self.name == "repr" {
            if len(args) != 1 {
                return py_error(
                    "TypeError", "repr() takes exactly one argument (" + str(len(args)) + " given)"
                );
            }
            return py_repr(args[0]);
        }
        if self.name == "isinstance" {
            if len(args) != 2 {
                return py_error(
                    "TypeError",
                    "isinstance expected 2 arguments, got " + str(len(args)),
                );
            }
            return PyBool(t="bool", val=py_isinstance(args[0], args[1]));
        }
        if self.name == "issubclass" {
            if len(args) != 2 {
                return py_error(
                    "TypeError",
                    "issubclass expected 2 arguments, got " + str(len(args)),
                );
            }
            return PyBool(t="bool", val=py_issubclass(args[0], args[1]));
        }
        if self.name == "callable" {
            if len(args) != 1 {
                return py_error(
                    "TypeError",
                    "callable() takes exactly one argument (" + str(len(args)) + " given)",
                );
            }
            return PyBool(t="bool", val=obj_is_callable(args[0]));
        }
        if self.name == "getattr" {
            # getattr(obj, name[, default]): native attribute access, honoring a
            # 3rd-arg default on AttributeError (CPython only swallows that one).
            if len(args) < 2 {
                return py_error(
                    "TypeError",
                    "getattr expected at least 2 arguments, got " + str(len(args)),
                );
            }
            attr = py_attr(args[0], expect_str(args[1]));
            if is_error(attr)
                and len(args) >= 3
                and (attr as PyError).exception.type_name == "AttributeError" {
                return args[2];
            }
            return attr;
        }
        if self.name == "hasattr" {
            if len(args) != 2 {
                return py_error(
                    "TypeError",
                    "hasattr expected 2 arguments, got " + str(len(args)),
                );
            }
            probe = py_attr(args[0], expect_str(args[1]));
            return PyBool(t="bool", val=not is_error(probe));
        }
        if self.name == "setattr" {
            if len(args) != 3 {
                return py_error("TypeError", "setattr expected 3 arguments, got " + str(len(args)));
            }
            return py_set_attr(args[0], expect_str(args[1]), args[2]);
        }
        if self.name == "delattr" {
            if len(args) < 2 {
                return py_error("TypeError", "delattr expected 2 arguments");
            }
            return py_del_attr(args[0], expect_str(args[1]));
        }
        if self.name == "dir" {
            # dir(obj): CPython attribute enumeration over the NATIVE object
            # (see py_dir). The no-arg form is intercepted at the ceval CALL
            # site (it reads that frame's locals); reaching tp_call with zero
            # args means an indirect host-side callback, where CPython would
            # see the trampoline frame -- an empty local scope answers []
            # instead of leaking foreign frame names.
            if len(kwargs) > 0 {
                return py_error("TypeError", "dir() takes no keyword arguments");
            }
            if len(args) == 0 {
                return PyList(t="list", items=[]);
            }
            if len(args) > 1 {
                return py_error(
                    "TypeError", "dir expected at most 1 argument, got " + str(len(args))
                );
            }
            return py_dir(args[0]);
        }
        if self.name == "vars" {
            if len(kwargs) > 0 {
                return py_error("TypeError", "vars() takes no keyword arguments");
            }
            if len(args) == 0 {
                # No-arg vars() is locals(); like dir(), only the ceval CALL
                # site sees that frame -- an indirect call answers an empty
                # dict instead of leaking a foreign frame.
                return PyDict(t="dict", items={});
            }
            if len(args) > 1 {
                return py_error(
                    "TypeError", "vars expected at most 1 argument, got " + str(len(args))
                );
            }
            # A user instance answers with its LIVE __dict__ (identity-stable
            # view); routing through the host crossed as a stand-in and lost
            # every guest attribute behind the _jac_guest_ marker.
            o = args[0];
            if isinstance(o, PyUserObj) {
                return user_instance_dict(o as PyUserObj);
            }
            d = py_attr(o, "__dict__");
            if is_error(d)
                and (d as PyError).exception.type_name == "AttributeError" {
                return py_error(
                    "TypeError", "vars() argument must have __dict__ attribute"
                );
            }
            return d;
        }
        if self.name == "iter" {
            if len(args) == 0 {
                return py_error("TypeError", "iter expected at least 1 argument");
            }
            if len(args) >= 2 {
                # Two-arg form (CPython calliterobject). The callable check is
                # EAGER -- builtin_iter raises "iter(v, w): v must be callable"
                # at construction time, not on first next(). Iteration then
                # calls it with no args until the result equals the sentinel.
                if not obj_is_callable(args[0]) {
                    return py_error("TypeError", "iter(v, w): v must be callable");
                }
                return PyCallableIter(t="calliter", fn=args[0], sentinel=args[1]);
            }
            result = py_iter(args[0]);
            if is_error(result) and isinstance(args[0], PyHostProxy) {
                # Dict views and other host-only iterables still materialize once.
                return host_iter(args[0] as PyHostProxy);
            }
            return result;
        }
        # next(iterator[, default])
        if len(args) == 0 {
            return py_error("TypeError", "next expected at least 1 argument, got 0");
        }
        if len(args) > 2 {
            return py_error("TypeError", "next expected at most 2 arguments, got " + str(len(args)));
        }
        if args[0].t == "async_generator" {
            # PyAsyncGenObject has no tp_iternext; CPython rejects it in
            # builtin_next via PyIter_Check with this dedicated message.
            return py_error("TypeError", "'async_generator' object is not an iterator");
        }
        step = send_into(args[0], py_none());
        if step.t == "genstop" {
            if len(args) > 1 {
                return args[1];
            }
            # Forward the generator's return value as StopIteration.value
            # (CPython: next() exhaustion surfaces `return x` as .value).
            return stop_iteration((step as PyGenStop).val);
        }
        return step;
    }
}
# A live view of a running frame's globals (`dict[str, PyObj]`, held by
# reference). globals() returns one so module init idioms that MUTATE the module
# namespace -- globals().update({...}), globals()[name] = value -- bind real
# globals a later LOAD_GLOBAL/LOAD_NAME resolves. A snapshot dict would silently
# drop those writes (re._constants._makecodes builds its OPCODES this way).
obj PyGlobalsProxy(PyObj) {
    has ns: dict[str, PyObj];

    def mp_subscript(index: PyObj) -> PyObj {
        key = expect_str(index);
        if key in self.ns {
            return self.ns[key];
        }
        return py_error("KeyError", key);
    }

    def mp_ass_subscript(index: PyObj, value: PyObj) -> PyObj {
        self.ns[expect_str(index)] = value;
        return py_none();
    }

    # Iterating globals() yields its keys (module code does
    # `[n for n in globals() if ...]` to compute __all__).
    def tp_iter -> PyObj {
        keys: list[PyObj] = [];
        for k in self.ns {
            keys.append(PyStr(t="str", val=k));
        }
        return PyIter(t="iter", items=keys, index=0);
    }

    def tp_getattro(name: str) -> PyObj {
        if name == "update" {
            return PyNsMethod(t="ns_method", ns=self.ns, op="update");
        }
        if name == "get" {
            return PyNsMethod(t="ns_method", ns=self.ns, op="get");
        }
        if name == "keys" {
            return PyNsMethod(t="ns_method", ns=self.ns, op="keys");
        }
        if name == "values" {
            return PyNsMethod(t="ns_method", ns=self.ns, op="values");
        }
        if name == "items" {
            return PyNsMethod(t="ns_method", ns=self.ns, op="items");
        }
        if name == "setdefault" {
            return PyNsMethod(t="ns_method", ns=self.ns, op="setdefault");
        }
        return py_error("AttributeError", name);
    }
}
# The bound dict-method objects a PyGlobalsProxy hands out. Kept minimal to the
# surface module-init code exercises; each mutates/reads the shared ns directly.
obj PyNsMethod(PyObj) {
    has ns: dict[str, PyObj],
        op: str;

    def tp_call(args: list[PyObj], kwargs: dict[str, PyObj]) -> PyObj {
        if self.op == "update" {
            if len(args) > 0 {
                src = args[0];
                pairs: PyObj = py_none();
                if isinstance(src, PyDict) {
                    pairs = src as PyObj;
                } else {
                    hsrc_r = to_host_coerce(src);
                    hsrc = hsrc_r[1];
                    if not ((hsrc_r[0] as bool)) {
                        return hsrc_r[1] as PyObj;
                    }
                    pairs = from_host(hsrc) as PyObj;
                }
                if isinstance(pairs, PyDict) {
                    smap = (pairs as PyDict).dict_str_map();
                    for k in smap {
                        self.ns[k] = smap[k];
                    }
                }
            }
            for kw in kwargs {
                self.ns[kw] = kwargs[kw];
            }
            return py_none();
        }
        if self.op == "get" {
            if len(args) > 0 {
                key = expect_str(args[0]);
                if key in self.ns {
                    return self.ns[key];
                }
            }
            if len(args) > 1 {
                return args[1];
            }
            return py_none();
        }
        if self.op == "setdefault" {
            if len(args) > 0 {
                key = expect_str(args[0]);
                if key in self.ns {
                    return self.ns[key];
                }
                fallback = py_none();
                if len(args) > 1 {
                    fallback = args[1];
                }
                self.ns[key] = fallback;
                return fallback;
            }
            return py_none();
        }
        if self.op == "keys" {
            out: list[PyObj] = [];
            for k in self.ns {
                out.append(PyStr(t="str", val=k));
            }
            return PyList(t="list", items=out);
        }
        if self.op == "values" {
            vout: list[PyObj] = [];
            for k in self.ns {
                vout.append(self.ns[k]);
            }
            return PyList(t="list", items=vout);
        }
        if self.op == "items" {
            iout: list[PyObj] = [];
            for k in self.ns {
                pair: list[PyObj] = [PyStr(t="str", val=k), self.ns[k]];
                iout.append(PyTuple(t="tuple", items=pair));
            }
            return PyList(t="list", items=iout);
        }
        return py_error("TypeError", "unsupported namespace op");
    }
}
def framelocals_nslots(co: PyCode) -> int {
    n = len(co.varnames);
    ci = 0;
    while ci < len(co.cellvars) {
        if find_name(co.varnames, co.cellvars[ci]) < 0 {
            n = n + 1;
        }
        ci = ci + 1;
    }
    return n + len(co.freevars);
}

def framelocals_keyerror(key: PyObj) -> PyObj {
    r = py_repr(key);
    if is_error(r) {
        return r;
    }
    # CPython formats KeyError with repr(key): for 'zz' the message carries
    # doubled quotes -- byte-exact with host FrameLocalsProxy.__getitem__.
    return py_error("KeyError", "local variable '" + (r as PyStr).val + "' is not defined");
}

obj PyFrameLocalsProxy(PyObj) {
    has frame: PyFrame;

    def slot_index(key: str) -> int {
        co = self.frame.co;
        i = 0;
        while i < framelocals_nslots(co) {
            if localsplus_name(co, i) == key {
                return i;
            }
            i = i + 1;
        }
        return -1;
    }

    def slot_bound(i: int) -> bool {
        slot = self.frame.fast[i];
        if isinstance(slot, PyCell) {
            return (slot as PyCell).filled;
        }
        if i < len(self.frame.assigned) {
            return self.frame.assigned[i];
        }
        return False;
    }

    def slot_get(i: int) -> PyObj {
        slot = self.frame.fast[i];
        if isinstance(slot, PyCell) {
            return (slot as PyCell).val;
        }
        return slot;
    }

    # (bound?, value) for a string key already known to sit in the slots.
    def ns_has(key: str) -> bool {
        return key in self.frame.locals;
    }

    # All visible pairs in CPython order: bound slots, then extras, then the
    # namespace dict (empty for function frames).
    def entry_pairs() -> list[PyObj] {
        out: list[PyObj] = [];
        co = self.frame.co;
        i = 0;
        while i < framelocals_nslots(co) {
            if self.slot_bound(i) {
                pair: list[PyObj] = [
                    PyStr(t="str", val=localsplus_name(co, i)),
                    self.slot_get(i),
                ];
                out.append(PyTuple(t="tuple", items=pair));
            }
            i = i + 1;
        }
        for hk in self.frame.extra_locals {
            e = self.frame.extra_locals[hk];
            pair2: list[PyObj] = [e.key, e.value];
            out.append(PyTuple(t="tuple", items=pair2));
        }
        for k in self.frame.locals {
            pair3: list[PyObj] = [PyStr(t="str", val=k), self.frame.locals[k]];
            out.append(PyTuple(t="tuple", items=pair3));
        }
        return out;
    }

    def keys_list() -> list[PyObj] {
        out: list[PyObj] = [];
        for p in self.entry_pairs() {
            out.append(((p as PyTuple).items[0]));
        }
        return out;
    }

    def as_dict() -> PyDict {
        d = PyDict(t="dict", items={});
        for p in self.entry_pairs() {
            _ = d.dict_set((p as PyTuple).items[0], (p as PyTuple).items[1]);
        }
        return d;
    }

    # Core lookup behind mp_subscript/get/contains: found? value.
    def lookup(index: PyObj) -> tuple[bool, PyObj] {
        hkr = index.tp_hashkey();
        if is_error(hkr) {
            return (False, _unhashable_error("a dict key", index));
        }
        hk = hashkey_str(hkr);
        if isinstance(index, PyStr) {
            k = (index as PyStr).val;
            i = self.slot_index(k);
            if i >= 0 {
                if self.slot_bound(i) {
                    return (True, self.slot_get(i));
                }
                # An unbound slot falls through like CPython (getval NULL).
                return (False, py_none());
            }
            if self.ns_has(k) {
                return (True, self.frame.locals[k]);
            }
        }
        if hk in self.frame.extra_locals {
            return (True, self.frame.extra_locals[hk].value);
        }
        return (False, py_none());
    }

    def contains_key(index: PyObj) -> PyObj {
        (found, val) = self.lookup(index);
        if is_error(val) {
            return val;
        }
        return PyBool(t="bool", val=found);
    }

    def mp_subscript(index: PyObj) -> PyObj {
        (found, val) = self.lookup(index);
        if is_error(val) {
            return val;
        }
        if found {
            return val;
        }
        return framelocals_keyerror(index);
    }

    def mp_ass_subscript(index: PyObj, value: PyObj) -> PyObj {
        if isinstance(index, PyStr) {
            k = (index as PyStr).val;
            i = self.slot_index(k);
            if i >= 0 {
                slot = self.frame.fast[i];
                if isinstance(slot, PyCell) {
                    c = slot as PyCell;
                    c.val = value;
                    c.filled = True;
                } else {
                    self.frame.fast[i] = value;
                    while len(self.frame.assigned) <= i {
                        self.frame.assigned.append(False);
                    }
                    self.frame.assigned[i] = True;
                }
                return py_none();
            }
            if self.ns_has(k) {
                self.frame.locals[k] = value;
                return py_none();
            }
        }
        hkr = index.tp_hashkey();
        if is_error(hkr) {
            return _unhashable_error("a dict key", index);
        }
        self.frame.extra_locals[hashkey_str(hkr)] = DictEntry(key=index, value=value);
        return py_none();
    }

    def mp_del_subscript(index: PyObj) -> PyObj {
        if isinstance(index, PyStr) {
            if self.slot_index((index as PyStr).val) >= 0 {
                return py_error(
                    "ValueError",
                    "cannot remove local variables from FrameLocalsProxy",
                );
            }
            k = (index as PyStr).val;
            if self.ns_has(k) {
                del self.frame.locals[k];
                return py_none();
            }
        }
        hkr = index.tp_hashkey();
        if is_error(hkr) {
            return _unhashable_error("a dict key", index);
        }
        hk = hashkey_str(hkr);
        if hk in self.frame.extra_locals {
            del self.frame.extra_locals[hk];
            return py_none();
        }
        return py_error("KeyError", dict_key_repr(index));
    }

    # Pairs of a merge source (dict | proxy); error otherwise.
    def merge_pairs(other: PyObj) -> PyObj {
        if isinstance(other, PyFrameLocalsProxy) {
            return PyList(t="list", items=(other as PyFrameLocalsProxy).entry_pairs());
        }
        if isinstance(other, PyDict) {
            src = other as PyDict;
            pairs: list[PyObj] = [];
            for hk in src.items {
                pair: list[PyObj] = [src.items[hk].key, src.items[hk].value];
                pairs.append(PyTuple(t="tuple", items=pair));
            }
            return PyList(t="list", items=pairs);
        }
        return py_error(
            "TypeError",
            "'" + other.t + "' object cannot be merged into FrameLocalsProxy",
        );
    }

    def nb_binop(kind: int, other: PyObj) -> PyObj {
        if kind != _NB_OR and kind != _NB_INPLACE_OR {
            return PY_NOT_IMPLEMENTED;
        }
        pairs_r = self.merge_pairs(other);
        if is_error(pairs_r) {
            if kind == _NB_INPLACE_OR {
                return pairs_r;
            }
            return PY_NOT_IMPLEMENTED;
        }
        if kind == _NB_INPLACE_OR {
            for p in (pairs_r as PyList).items {
                err = self.mp_ass_subscript((p as PyTuple).items[0], (p as PyTuple).items[1]);
                if is_error(err) {
                    return err;
                }
            }
            return self as PyObj;
        }
        result = self.as_dict();
        for p in (pairs_r as PyList).items {
            _ = result.dict_set((p as PyTuple).items[0], (p as PyTuple).items[1]);
        }
        return result;
    }

    def tp_richcompare(kind: int, other: PyObj) -> PyObj {
        if kind != Py_EQ and kind != Py_NE {
            return PY_NOT_IMPLEMENTED;
        }
        if isinstance(other, PyFrameLocalsProxy) {
            eq = self.frame is (other as PyFrameLocalsProxy).frame;
            return PyBool(t="bool", val=eq if kind == Py_EQ else not eq);
        }
        if isinstance(other, PyDict) {
            return dict_richcompare(kind, self.as_dict(), other as PyDict, py_compare);
        }
        return PY_NOT_IMPLEMENTED;
    }

    def tp_iter -> PyObj {
        return PyIter(t="iter", items=self.keys_list(), index=0);
    }

    def tp_getattro(name2: str) -> PyObj {
        if name2 == "keys" or name2 == "values" or name2 == "items"
            or name2 == "get" or name2 == "setdefault" or name2 == "update"
            or name2 == "copy" or name2 == "pop" or name2 == "__getitem__"
            or name2 == "__setitem__" or name2 == "__len__"
            or name2 == "__contains__" {
            return PyFrameLocalsMethod(t="framelocals_method", proxy=self, op=name2);
        }
        return py_error("AttributeError", name2);
    }
}

# Bound method surface of PyFrameLocalsProxy (dict-shaped mapping API; .clear()
# is deliberately absent so it raises AttributeError like CPython's).
def framelocals_len(p: PyFrameLocalsProxy) -> int {
    return len(p.entry_pairs());
}

obj PyFrameLocalsMethod(PyObj) {
    has proxy: PyFrameLocalsProxy,
        op: str;

    def tp_call(args: list[PyObj], kwargs: dict[str, PyObj]) -> PyObj {
        p = self.proxy;
        if self.op == "keys" {
            return PyList(t="list", items=p.keys_list());
        }
        if self.op == "values" {
            out: list[PyObj] = [];
            for pr in p.entry_pairs() {
                out.append((pr as PyTuple).items[1]);
            }
            return PyList(t="list", items=out);
        }
        if self.op == "items" {
            return PyList(t="list", items=p.entry_pairs());
        }
        if self.op == "copy" {
            return p.as_dict();
        }
        if self.op == "__len__" {
            return PyInt(t="int", val=len(p.entry_pairs()));
        }
        if self.op == "__contains__" {
            if len(args) < 1 {
                return py_error("TypeError", "__contains__ expected 1 argument");
            }
            return p.contains_key(args[0]);
        }
        if self.op == "__getitem__" {
            if len(args) < 1 {
                return py_error("TypeError", "__getitem__ expected 1 argument");
            }
            return p.mp_subscript(args[0]);
        }
        if self.op == "__setitem__" {
            if len(args) < 2 {
                return py_error("TypeError", "__setitem__ expected 2 arguments");
            }
            return p.mp_ass_subscript(args[0], args[1]);
        }
        if self.op == "get" {
            if len(args) < 1 {
                return py_error("TypeError", "get expected at least 1 argument");
            }
            (found, val) = p.lookup(args[0]);
            if is_error(val) {
                return val;
            }
            if found {
                return val;
            }
            if len(args) > 1 {
                return args[1];
            }
            return py_none();
        }
        if self.op == "setdefault" {
            if len(args) < 1 {
                return py_error("TypeError", "setdefault expected at least 1 argument");
            }
            (found2, val2) = p.lookup(args[0]);
            if is_error(val2) {
                return val2;
            }
            if found2 {
                return val2;
            }
            fallback = py_none();
            if len(args) > 1 {
                fallback = args[1];
            }
            err = p.mp_ass_subscript(args[0], fallback);
            if is_error(err) {
                return err;
            }
            return fallback;
        }
        if self.op == "update" {
            if len(args) < 1 {
                return py_error("TypeError", "update expected at least 1 argument");
            }
            pairs_r = p.merge_pairs(args[0]);
            if is_error(pairs_r) {
                return pairs_r;
            }
            for pr in (pairs_r as PyList).items {
                err2 = p.mp_ass_subscript((pr as PyTuple).items[0], (pr as PyTuple).items[1]);
                if is_error(err2) {
                    return err2;
                }
            }
            return py_none();
        }
        if self.op == "pop" {
            if len(args) < 1 {
                return py_error("TypeError", "pop expected at least 1 argument");
            }
            index = args[0];
            if isinstance(index, PyStr) and p.slot_index((index as PyStr).val) >= 0 {
                return py_error(
                    "ValueError",
                    "cannot remove local variables from FrameLocalsProxy",
                );
            }
            (found3, val3) = p.lookup(index);
            if is_error(val3) {
                return val3;
            }
            if found3 {
                del_err = p.mp_del_subscript(index);
                if is_error(del_err) {
                    return del_err;
                }
                return val3;
            }
            if len(args) > 1 {
                return args[1];
            }
            return py_error("KeyError", dict_key_repr(index));
        }
        return py_error("TypeError", "unsupported FrameLocalsProxy op");
    }
}
# A frame that ran to RETURN_VALUE. `val` is the generator's return value, which
# `yield from` yields as the sub-expression result and .send()/next() surface as
# StopIteration(val).
obj PyGenStop(PyObj) {
    has val: PyObj;
}

# INTRINSIC_ASYNC_GEN_WRAP's payload (generated_cases.c.h): every value an
# async generator yields is wrapped so the anext/asend driver can tell a
# yield from a return even though both cross the same resume machinery.
obj PyAsyncGenWrappedValue(PyObj) {
    has val: PyObj;
}

# The one-shot awaitable `ag.__anext__()` / `ag.asend(v)` returns. The SEND
# loop drives it through agen_asend_step like a native coroutine: a yield
# surfaces the UNWRAPPED value, exhaustion raises StopAsyncIteration.
obj PyAsyncGenASendSend(PyObj) {
    has target: PyAsyncGenASend;

    def tp_call(args: list[PyObj], kwargs: dict[str, PyObj]) -> PyObj {
        sent = py_none();
        if len(args) > 0 {
            sent = args[0];
        }
        result = agen_asend_step(self.target, sent);
        # Bare ``ag.__anext__().send(None)`` (Lib/test asyncgen pins): surface the
        # unwrapped yield as a return value; exhaustion becomes StopIteration so
        # ``except StopIteration`` can drain without ``await``.
        if result.t == "genstop" {
            return (result as PyGenStop).val;
        }
        if is_error(result) {
            err = result as PyError;
            if err.exception.type_name == "StopAsyncIteration" {
                return stop_iteration(py_none());
            }
            return result;
        }
        return result;
    }
}

obj PyAsyncGenASend(PyObj) {
    has gen: PyGenerator,
        value: PyObj,
        started: bool = False;

    # CPython async_gen_asend exposes send() so bare ``ag.__anext__().send(None)``
    # drives one step without ``await`` (Lib/test asyncgen pins).
    def tp_getattro(name: str) -> PyObj {
        if name == "send" {
            return PyAsyncGenASendSend(t="agen_asend_send", target=self);
        }
        return py_error(
            "AttributeError",
            "async_generator_asend object has no attribute '" + name + "'",
        );
    }
}

# The one-shot awaitable `ag.athrow(exc)` / `ag.aclose()` returns: on first
# drive it throws `err` into the generator at its suspend point. aclose=True
# runs the GeneratorExit close protocol (silent on clean exit, RuntimeError
# when the generator yields again).
obj PyAsyncGenAThrow(PyObj) {
    has gen: PyGenerator,
        err: PyObj,
        aclose: bool = False,
        started: bool = False;
}

# A bound async-generator driver (asend/athrow/aclose/__anext__/__aiter__).
# Each call returns a FRESH awaitable object (genobject.c's
# async_gen_asend/athrow_new); awaiting it drives the underlying frame.
obj PyAsyncGenMethod(PyObj) {
    has gen: PyGenerator,
        kind: str;

    def tp_call(args: list[PyObj], kwargs: dict[str, PyObj]) -> PyObj {
        if self.kind == "anext" or self.kind == "__anext__" {
            return PyAsyncGenASend(t="agen_asend", gen=self.gen, value=py_none());
        }
        if self.kind == "asend" {
            if len(args) < 1 {
                return py_error("TypeError", "asend expected at least 1 argument");
            }
            return PyAsyncGenASend(t="agen_asend", gen=self.gen, value=args[0]);
        }
        if self.kind == "aclose" {
            return PyAsyncGenAThrow(
                t="agen_athrow", gen=self.gen, err=py_none(), aclose=True
            );
        }
        if self.kind == "__aiter__" {
            # PyAsyncGenObject.__aiter__ returns self, so `async for`
            # iterates the generator itself.
            return self.gen;
        }
        # athrow: an exception instance or type, coerced now so a bad operand
        # surfaces at call time. Multi-arg (type, value[, tb]) forms stay in
        # parity with the sync gen_throw surface.
        thrown = py_none();
        if len(args) > 0 {
            thrown = args[0];
        }
        err = as_error(thrown);
        if err.t != "error" {
            return err;
        }
        return PyAsyncGenAThrow(t="agen_athrow", gen=self.gen, err=err);
    }
}

obj PyGenerator(PyObj) {
    has frame: PyFrame,
        started: bool = False,
        finished: bool = False,
        running: bool = False,
        # __name__ / __qualname__ overrides (gen_set_name/gen_set_qualname write
        # the generator object, not the code). Empty string = fall back to the
        # code object's name, matching CPython's pre-assignment read path.
        gen_name: str = "",
        gen_qualname: str = "",
        frame_facade: PyObj | None = None;

    def tp_iter -> PyObj {
        # An async generator is driven exclusively through __anext__/asend;
        # CPython gives it no tp_iter at all.
        if self.t == "async_generator" {
            return py_error("TypeError", "'async_generator' object is not iterable");
        }
        return self;
    }

    # gi_frame / ag_frame surface accessor: CPython caches the frame object on
    # the generator (identity stable across accesses) and returns None once the
    # generator completed (frame released, 3.13+). One facade per generator;
    # the gen<->facade reference cycle is host-gc collectible.
    def frame_surface -> PyObj {
        if self.finished {
            return py_none();
        }
        if self.frame_facade is None {
            self.frame_facade = PyGenFrame(t="genframe", gen=self);
        }
        return self.frame_facade as PyObj;
    }

    # gen.send / gen.throw / gen.close / gen.__next__ resolve to native bound
    # driver methods; every other attribute is a real AttributeError. An async
    # generator (CO_ASYNC_GENERATOR) presents the ag_* surface instead: its
    # drivers return awaitables, and the sync driver names are absent exactly
    # as CPython's PyAsyncGenObject lacks send/throw/close/__next__.
    def tp_getattro(name: str) -> PyObj {
        if self.t == "async_generator" {
            if name == "asend" or name == "athrow" or name == "aclose"
                or name == "__anext__" or name == "__aiter__" {
                return PyAsyncGenMethod(t="agen_method", gen=self, kind=name);
            }
            if name == "ag_frame" {
                return self.frame_surface();
            }
            if name == "ag_running" {
                # True only while the frame is actively executing, like gi_running.
                return PyBool(t="bool", val=self.running);
            }
            return py_error(
                "AttributeError",
                "'async_generator' object has no attribute '" + name + "'",
            );
        }
        if name == "send" or name == "throw" or name == "close" or name == "__next__" {
            return PyGenMethod(t="gen_method", gen=self, kind=name);
        }
        if name == "gi_frame" or name == "ag_frame" {
            return self.frame_surface();
        }
        if name == "gi_running" or name == "ag_running" {
            # True only while the generator's frame is actively executing;
            # observable from re-entrant access (the generator inspecting
            # itself through a callback), False while suspended/finished.
            return PyBool(t="bool", val=self.running);
        }
        if name == "gi_yieldfrom" {
            # The sub-iterator a `yield from` is currently delegating to, else
            # None (genobject.c gi_yieldfrom getter). At a YIELD_VALUE(oparg 1)
            # suspension the sent slot has been consumed by the yield, so the
            # delegating receiver is the stack top.
            if self.frame.yf and len(self.frame.stack) >= 1 {
                return self.frame.stack[len(self.frame.stack) - 1];
            }
            return py_none();
        }
        if name == "__name__" {
            gname = self.gen_name;
            if gname == "" {
                gname = self.frame.co.name;
            }
            return PyStr(t="str", val=gname);
        }
        if name == "__qualname__" {
            gqn = self.gen_qualname;
            if gqn == "" {
                gqn = self.frame.co.qualname;
            }
            return PyStr(t="str", val=gqn);
        }
        return py_error("AttributeError", name);
    }

    # Only __name__/__qualname__ are writable on a generator object; everything
    # else keeps raising AttributeError (CPython has no other settable members).
    def tp_setattro(name: str, value: PyObj) -> PyObj {
        if name != "__name__" and name != "__qualname__" {
            return py_error("AttributeError", name);
        }
        if not isinstance(value, PyStr) {
            label = "__qualname__";
            if name == "__name__" {
                label = "__name__";
            }
            return py_error("TypeError", label + " must be set to a string object");
        }
        if self.running {
            return py_error("ValueError", "generator already executing");
        }
        text = (value as PyStr).val;
        if name == "__name__" {
            self.gen_name = text;
        } else {
            self.gen_qualname = text;
        }
        return py_none();
    }
}

# A bound generator driver (gen.send/throw/close/__next__). Calling it drives the
# suspended frame and raises StopIteration on exhaustion, matching CPython's
# generator method surface (unlike FOR_ITER, which swallows the StopIteration).
obj PyGenMethod(PyObj) {
    has gen: PyGenerator,
        kind: str;

    def tp_call(args: list[PyObj], kwargs: dict[str, PyObj]) -> PyObj {
        # Method-name prefix in arity errors mirrors CPython's METH_DEF_NAME
        # bindings: "generator.send()", "coroutine.close()", ...
        label = self.gen.t;
        if len(kwargs) > 0 {
            return py_error("TypeError", label + "." + self.kind + "() takes no keyword arguments");
        }
        if self.kind == "throw" {
            if len(args) < 1 {
                return py_error("TypeError", "throw expected at least 1 argument, got 0");
            }
            if len(args) > 3 {
                return py_error(
                    "TypeError",
                    "throw expected at most 3 arguments, got " + str(len(args))
                );
            }
            thrown = normalize_throw_args(args);
            result = gen_throw(self.gen, thrown);
            # A generator that catches the injected exception and returns
            # normally exhausts like any other run: surface its return value as
            # StopIteration(return_value), not a bare sentinel (gen_send_ex).
            if result.t == "genstop" {
                return stop_iteration((result as PyGenStop).val);
            }
            return result;
        }
        if self.kind == "close" {
            if len(args) > 0 {
                return py_error(
                    "TypeError",
                    label + ".close() takes no arguments (" + str(len(args)) + " given)"
                );
            }
            return gen_close(self.gen);
        }
        if self.kind == "send" {
            if len(args) != 1 {
                return py_error(
                    "TypeError",
                    label + ".send() takes exactly one argument ("
                        + str(len(args)) + " given)"
                );
            }
            return gen_send(self.gen, args[0]);
        }
        # __next__: CPython's slot wrapper takes no arguments.
        if len(args) > 0 {
            return py_error(
                "TypeError",
                label + ".__next__() takes no arguments (" + str(len(args)) + " given)"
            );
        }
        return gen_send(self.gen, py_none());
    }
}
# A generator's gi_frame/ag_frame surface: a stable facade over the generator's
# real frame. .clear() stays local (releases the suspended frame's locals and
# finalizes dropped user objects, then marks the generator exhausted); every
# f_* attribute delegates to PyFrame.tp_getattro, so f_back answers from the
# live chain walk -- None while not-started/suspended/exhausted, the resumer's
# frame while running -- and f_code/f_locals/f_globals come from PyFrame.
obj PyGenFrame(PyObj) {
    has gen: PyGenerator;

    def tp_getattro(name: str) -> PyObj {
        if name == "clear" {
            return PyGenFrameClear(t="genframe_clear", gen=self.gen);
        }
        if name.startswith("f_") {
            return self.gen.frame.tp_getattro(name);
        }
        return py_error("AttributeError", name);
    }
}

obj PyGenFrameClear(PyObj) {
    has gen: PyGenerator;

    def tp_call(args: list[PyObj], kwargs: dict[str, PyObj]) -> PyObj {
        frame_clear(self.gen.frame);
        self.gen.finished = True;
        return py_none();
    }
}
