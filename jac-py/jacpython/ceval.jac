# ceval + host bridge (jac-py/PLAN.md §4 module-boundary constraint).
# Callable/heap/proxy types, Layer 3 import, py_* dispatch,
# generator machinery, Track B builtin subclassing, native set/dict methods.
# Host-bridge ::py:: helpers live in ceval_host_bridge.jac (acyclic leaf).
# Jac-coupled bridge shims live in ceval_bridge_guest.jac.
# Exception unwind/matching and except* kernel in ceval_exceptions.jac.
# Container opcode handlers live in ceval_opcodes_containers.jac.
# Frame execution (exec_code_frame/run_frame) in ceval_exec_frame.jac.

::py::
import ceval_host_bridge as _hb
import ceval_bridge_guest as _bg

def _jac_host_error(exc):
    return _hb._jac_host_error(exc)

def _jac_host_import(name, fromlist):
    return _hb._jac_host_import(name, fromlist)

def _jac_host_getattr(value, name):
    return _hb._jac_host_getattr(value, name)

def _jac_host_setattr(value, name, field):
    return _hb._jac_host_setattr(value, name, field)

def _jac_host_call(fn, args, kwargs):
    return _hb._jac_host_call(fn, args, kwargs)

def _jac_host_dir(value):
    return _hb._jac_host_dir(value)

def _jac_host_type_surface(kind):
    return _hb._jac_host_type_surface(kind)

def _jac_host_type_attr(kind, name):
    return _hb._jac_host_type_attr(kind, name)

def _jac_host_is_callable(value):
    return _hb._jac_host_is_callable(value)

def _jac_host_getitem(value, index):
    return _hb._jac_host_getitem(value, index)

def _jac_host_str_encode(s, encoding, errors):
    return _hb._jac_host_str_encode(s, encoding, errors)

def _jac_host_len(value):
    return _hb._jac_host_len(value)

def _jac_is_object_type(value):
    return _hb._jac_is_object_type(value)

def _jac_is_type_type(value):
    return _hb._jac_is_type_type(value)

def _jac_static_type_name(value):
    return _hb._jac_static_type_name(value)

def _jac_is_super_type(value):
    return _hb._jac_is_super_type(value)

def _jac_is_range_type(value):
    return _hb._jac_is_range_type(value)

def _jac_is_slice_type(value):
    return _hb._jac_is_slice_type(value)

def _jac_conversion_ctor_kind(value):
    return _hb._jac_conversion_ctor_kind(value)

def _jac_is_builtin_func(value, name):
    return _hb._jac_is_builtin_func(value, name)

def _jac_is_complex_type(value):
    return _hb._jac_is_complex_type(value)

def _jac_host_hashkey(value):
    return _hb._jac_host_hashkey(value)

def _jac_host_contains(member, container):
    return _hb._jac_host_contains(member, container)

def _jac_is_notimpl(v):
    return _hb._jac_is_notimpl(v)

def _jac_host_iter(value):
    return _hb._jac_host_iter(value)

def _jac_host_builtin(name):
    return _hb._jac_host_builtin(name)

def _jac_host_code_marshal(co):
    return _hb._jac_host_code_marshal(co)

def _jac_host_source_marshal(source):
    return _hb._jac_host_source_marshal(source)

def _jac_host_type_name(value):
    return _hb._jac_host_type_name(value)

def _jac_host_id(value):
    return _hb._jac_host_id(value)

def _jac_host_type(value):
    return _hb._jac_host_type(value)

def _jac_host_delattr(host_obj, name):
    return _hb._jac_host_delattr(host_obj, name)

def _jac_wrap_classmethod(host_fn):
    return _hb._jac_wrap_classmethod(host_fn)

def _jac_wrap_staticmethod(host_fn):
    return _hb._jac_wrap_staticmethod(host_fn)

def _jac_wrap_property(fget, fset, fdel):
    return _hb._jac_wrap_property(fget, fset, fdel)

def _jac_wrap_mappingproxy(d):
    return _hb._jac_wrap_mappingproxy(d)

def _jac_wrap_tstr_interp(value, expression, conversion, format_spec):
    return _hb._jac_wrap_tstr_interp(value, expression, conversion, format_spec)

def _jac_wrap_tstr_template(strings, interpolations):
    return _hb._jac_wrap_tstr_template(strings, interpolations)

def _jac_construct_host_type(host_type, raw_args):
    return _hb._jac_construct_host_type(host_type, raw_args)

def _jac_builtin_base_name(host_val):
    return _hb._jac_builtin_base_name(host_val)

def _jac_construct_builtin(name, raw_args):
    return _hb._jac_construct_builtin(name, raw_args)

def _jac_make_exception_type(name):
    return _hb._jac_make_exception_type(name)

def _jac_make_module_exc_type(qname, base_name):
    return _hb._jac_make_module_exc_type(qname, base_name)

def _jac_builtin_new(name, host_cls, raw_args):
    return _hb._jac_builtin_new(name, host_cls, raw_args)

def _jac_builtin_new_slot(name):
    return _hb._jac_builtin_new_slot(name)

def _jac_isinstance_of_builtin(host_val, name):
    return _hb._jac_isinstance_of_builtin(host_val, name)

def _jac_host_isinstance(host_obj, host_type):
    return _hb._jac_host_isinstance(host_obj, host_type)

def _jac_type_has_flag(host_obj, flag_bit):
    return _hb._jac_type_has_flag(host_obj, flag_bit)

def _jac_host_pattern_name(host_val):
    return _hb._jac_host_pattern_name(host_val)

def _jac_host_type_name(host_obj):
    return _hb._jac_host_type_name(host_obj)

def _jac_is_exception_type(host_val):
    return _hb._jac_is_exception_type(host_val)

def _jac_host_issubclass(host_cls, host_type):
    return _hb._jac_host_issubclass(host_cls, host_type)

def _jac_host_class_name(value):
    return _hb._jac_host_class_name(value)

def _jac_exc_name_subclass(target_name, exc_name):
    return _hb._jac_exc_name_subclass(target_name, exc_name)

def _jac_host_format(value, spec):
    return _hb._jac_host_format(value, spec)

def _jac_host_unbound_method_info(value):
    return _hb._jac_host_unbound_method_info(value)

def _jac_bound_method_type():
    return _hb._jac_bound_method_type()

def _jac_list_iterator_type():
    return _hb._jac_list_iterator_type()

def _jac_seq_iterator_type():
    return _hb._jac_seq_iterator_type()

def _jac_builtin_function_or_method_type():
    return _hb._jac_builtin_function_or_method_type()

def _jac_generator_type():
    return _hb._jac_generator_type()

def _jac_coroutine_type():
    return _hb._jac_coroutine_type()

def _jac_async_generator_type():
    return _hb._jac_async_generator_type()

def _jac_host_same_object(a, b):
    return _hb._jac_host_same_object(a, b)

def _jac_host_eq(a, b):
    return _hb._jac_host_eq(a, b)

def _jac_host_richcompare(kind, a, b):
    return _hb._jac_host_richcompare(kind, a, b)

def _jac_host_binop(kind, a, b):
    return _hb._jac_host_binop(kind, a, b)

def _jac_host_convert(value, conv):
    return _hb._jac_host_convert(value, conv)

def _jac_module_info(absname):
    return _hb._jac_module_info(absname)

def _jac_sys_modules_lookup(absname):
    return _hb._jac_sys_modules_lookup(absname)

def _jac_star_names(host_val):
    return _hb._jac_star_names(host_val)

def _jac_dir_names(value):
    return _hb._jac_dir_names(value)

def _jac_host_weakref():
    return _hb._jac_host_weakref()

def _jac_make_weakref(target):
    return _hb._jac_make_weakref(target)

def _jac_weakref_deref(wr):
    return _hb._jac_weakref_deref(wr)

def _jac_dbg_dead_check_simple(r):
    return _hb._jac_dbg_dead_check_simple(r)

def _jac_recover_native(raw):
    return _hb._jac_recover_native(raw)

def _jac_reraise_pyerror(*args, **kwargs):
    return _bg._jac_reraise_pyerror(*args, **kwargs)

def _jac_instantiate_registered_exception(*args, **kwargs):
    return _bg._jac_instantiate_registered_exception(*args, **kwargs)

def _jac_host_exception_instance(*args, **kwargs):
    return _bg._jac_host_exception_instance(*args, **kwargs)

def _jac_make_live_ns_view(*args, **kwargs):
    return _bg._jac_make_live_ns_view(*args, **kwargs)

def _jac_make_live_list(*args, **kwargs):
    return _bg._jac_make_live_list(*args, **kwargs)

def _jac_make_live_dict(*args, **kwargs):
    return _bg._jac_make_live_dict(*args, **kwargs)

def _jac_make_live_set(*args, **kwargs):
    return _bg._jac_make_live_set(*args, **kwargs)

def _jac_make_host_trampoline(*args, **kwargs):
    return _bg._jac_make_host_trampoline(*args, **kwargs)

def _jac_notimpl_value(*args, **kwargs):
    return _bg._jac_notimpl_value(*args, **kwargs)

def _jac_standin_class(*args, **kwargs):
    return _bg._jac_standin_class(*args, **kwargs)

def _jac_user_standin(*args, **kwargs):
    return _bg._jac_user_standin(*args, **kwargs)

def _jac_user_standin_typed(*args, **kwargs):
    return _bg._jac_user_standin_typed(*args, **kwargs)

def _jac_standin_mro_covers(*args, **kwargs):
    return _bg._jac_standin_mro_covers(*args, **kwargs)

def _jac_hostproxy_val_is_type(*args, **kwargs):
    return _bg._jac_hostproxy_val_is_type(*args, **kwargs)

def _jac_recover_guest(*args, **kwargs):
    return _bg._jac_recover_guest(*args, **kwargs)

def _jac_make_host_iterator(*args, **kwargs):
    return _bg._jac_make_host_iterator(*args, **kwargs)

def _jac_is_builtin_subclass_instance(*args, **kwargs):
    return _bg._jac_is_builtin_subclass_instance(*args, **kwargs)

def _jac_host_val_is_type(*args, **kwargs):
    return _bg._jac_host_val_is_type(*args, **kwargs)

def _jac_host_type_mro(*args, **kwargs):
    return _bg._jac_host_type_mro(*args, **kwargs)

def _jac_host_val_is_object_type(*args, **kwargs):
    return _bg._jac_host_val_is_object_type(*args, **kwargs)

def _jac_host_val_same(*args, **kwargs):
    return _bg._jac_host_val_same(*args, **kwargs)

def _jac_make_guest_coroutine(*args, **kwargs):
    return _bg._jac_make_guest_coroutine(*args, **kwargs)

def _jac_host_resolve_awaitable(*args, **kwargs):
    return _bg._jac_host_resolve_awaitable(*args, **kwargs)

def _jac_make_guest_async_generator(*args, **kwargs):
    return _bg._jac_make_guest_async_generator(*args, **kwargs)

::py::


import marshal;




import from marshal_reader { unmarshal, bytes_to_str }

# Bootstrap transport duplicate (pyc_first.jac keeps the canonical copy for re-export).
def host_compile_marshal(source: str) -> list[int] {
    raw = marshal.dumps(compile(source, "<jacpython-host>", "exec"));
    return raw as list[int];
}

# The object core -- the PyObj data-type hierarchy, value/container slots, and
# pure helpers -- lives in the na-clean leaf `objects.jac`. This module (the
# ceval + host bridge + marshal transport) imports it and adds the callable/
# heap/proxy types that OVERRIDE the call/attr slots (cross-module inheritance),
# because those slots re-enter the interpreter or the host and so cannot live in
# the acyclic leaf. See PLAN.md §4 (module-boundary constraint).
import from hash_dispatch { hash_element, }
import from objects {
    Py_EQ,
    Py_LE,
    Py_GE,
    PyObject_RichCompare,
    PyObject_RichCompareBool,
    py_ordering_type_error,
    _base_type_name,
    _uint_to_str,
}
import from abstract_protocol {
    PyObject_GetIter,
    PyIter_Check,
    PyObject_Hash,
    PyObject_HashNotImplemented,
}
import from rangeobject { get_len_of_range, range_contains_longs, range_equals_longs, }
import from type_slots {
    type_slots_attr_allowed,
    type_slots_mangle,
    type_slots_member_repr,
    type_slots_merge_names,
    type_slots_has_dict,
    type_slots_in_dict_view,
}
import from tupleobject { tuple_hash, tuple_richcompare, }
import from longobject { long_hash_obj, int_repr, }
import from setobject { set_hash_obj, set_richcompare, }
import from typeobject {
    type_repr,
    type_richcompare,
    type_richcompare_same,
    type_tp_name,
    type_ready,
    Py_TPFLAGS_READY,
}
import from bytesobject { bytes_hash_obj, bytes_richcompare, bytes_repr, }
import from strobject { str_repr, }
import from floatobject { float_repr, }
import from complexobject { complex_repr_text, complex_parse_text, }
import from listobject { list_richcompare, list_repr, }
import from dictobject { dict_richcompare, dict_repr, }
import from exceptions_core {
    exc_name_matches,
    baseexception_str,
    baseexception_repr,
    prep_reraise_star,
    registered_exc_base,
}

import from ceval_exceptions {
    read_varint,
    read_svarint,
    pycode_lineno,
    find_handler,
    recover_exception,
    dispatch_exception,
    except_target_valid,
    exception_matches,
    class_is_exception,
    exc_is_eg_family,
    eg_target_family,
    eg_validate_star_target,
    eg_is_group,
    eg_leaf_family,
    eg_members,
    eg_message,
    eg_all_exception,
    eg_build,
    eg_condition_error,
    eg_condition_kind,
    eg_cond_match,
    eg_split_rec,
    eg_copy_chain,
    eg_split_entry,
    eg_subgroup_entry,
    exception_group_split,
    PyAddNoteMethod,
    PyExcGroupMethod,
}
import from objects { exc_is_subclass_of }
import from tb_render { tb_display_error, }
import from tracebackmodule { traceback_module_attrs, format_exception_text, tb_write_bound, _tb_shim_type_tags }
import from gc_shim { gc_module_attrs }
import from sysconfig_shim { sysconfig_module_attrs }
import from errno_shim { errno_module_attrs }
import from signal_shim { signal_module_attrs }
import from _abcmodule { abc_module_attrs }
import from objects {
    _zero_step_error,
    DictEntry,
    _unhashable_error,
    slice_indices,
    PyObj,
    PyInt,
    PyStr,
    PyBytes,
    PyFloat,
    PyBool,
    PyNoneType,
    PyComplex,
    PySlice,
    PyTuple,
    PyList,
    PyCode,
    PyCell,
    PyTypeAlias,
    PyTypeVar,
    PyDict,
    PyDictIter,
    PySet,
    PySeqIter,
    PyExceptionType,
    PyExcGroup,
    PyException,
    PyError,
    PyTraceback,
    PyIter,
    PyCallableIter,
    PyHandler,
    bytes_value,
    tuple_value,
    str_value,
    str_values,
    int_values,
    expect_int,
    expect_str,
    expect_float,
    expect_bool,
    list_value,
    concat_items,
    find_name,
    py_none,
    py_error,
    py_error_with_args,
    py_exception_type,
    PyNotImplementedSentinel,
    is_builtin_exception_name,
    dict_key_repr,
    _pyobj_repr,
    _repr_unicode_escape,
    str_mod_format,
    is_error,
    hashkey_str,
    PY_NOT_IMPLEMENTED
}
import from ceval_opcodes_containers {
    op_build_list,
    op_build_map,
    op_build_set,
    op_set_update,
    op_list_extend,
    op_list_append,
    op_set_add,
    op_map_add,
    op_dict_update,
    op_dict_merge,
    op_binary_subscript,
    op_binary_slice,
    op_store_slice,
    op_store_subscr,
    op_delete_subscr,
}
import from ceval_exec_frame {
    exec_code_frame,
    run_frame,
    jac_frame_chain_slot,
    jac_frame_globals_slot,
    jac_current_module_name,
    jac_current_frame,
}

import from opcode_meta {
    OP_CACHE,
    OP_RESUME,
    OP_LOAD_BUILD_CLASS,
    OP_LOAD_LOCALS,
    OP_LOAD_FROM_DICT_OR_DEREF,
    OP_LOAD_FROM_DICT_OR_GLOBALS,
    OP_NOT_TAKEN,
    OP_SETUP_ANNOTATIONS,
    OP_POP_TOP,
    OP_PUSH_EXC_INFO,
    OP_PUSH_NULL,
    OP_RETURN_VALUE,
    OP_BINARY_SLICE,
    OP_BUILD_SLICE,
    OP_STORE_SLICE,
    OP_CHECK_EG_MATCH,
    OP_STORE_SUBSCR,
    OP_UNARY_NOT,
    OP_WITH_EXCEPT_START,
    OP_BINARY_OP,
    NB_REMAINDER,
    NB_AND,
    NB_INPLACE_ADD,
    NB_INPLACE_AND,
    NB_INPLACE_MULTIPLY,
    NB_INPLACE_OR,
    NB_INPLACE_SUBTRACT,
    NB_INPLACE_XOR,
    NB_MULTIPLY,
    NB_OR,
    NB_SUBTRACT,
    NB_XOR,
    OP_BUILD_LIST,
    OP_BUILD_MAP,
    OP_BUILD_TUPLE,
    OP_BUILD_INTERPOLATION,
    OP_BUILD_TEMPLATE,
    OP_CALL,
    OP_CALL_KW,
    OP_COMPARE_OP,
    OP_COPY,
    OP_COPY_FREE_VARS,
    OP_END_FOR,
    OP_END_ASYNC_FOR,
    OP_GET_AITER,
    OP_GET_ANEXT,
    OP_GET_ITER,
    OP_IMPORT_FROM,
    OP_IMPORT_NAME,
    OP_IS_OP,
    OP_JUMP_BACKWARD,
    OP_JUMP_BACKWARD_NO_INTERRUPT,
    OP_JUMP_FORWARD,
    OP_LIST_APPEND,
    OP_SET_ADD,
    OP_LIST_EXTEND,
    OP_LOAD_ATTR,
    OP_LOAD_SUPER_ATTR,
    OP_LOAD_CONST,
    OP_LOAD_DEREF,
    OP_LOAD_CLOSURE,
    OP_LOAD_FAST,
    OP_LOAD_FAST_BORROW,
    OP_LOAD_FAST_BORROW_LOAD_FAST_BORROW,
    OP_LOAD_FAST_CHECK,
    OP_LOAD_FAST_LOAD_FAST,
    OP_LOAD_GLOBAL,
    OP_LOAD_NAME,
    OP_LOAD_SMALL_INT,
    OP_LOAD_SPECIAL,
    OP_MAKE_CELL,
    OP_MAKE_FUNCTION,
    OP_POP_JUMP_IF_FALSE,
    OP_POP_JUMP_IF_NONE,
    OP_POP_JUMP_IF_NOT_NONE,
    OP_POP_JUMP_IF_TRUE,
    OP_RAISE_VARARGS,
    OP_RERAISE,
    OP_SET_FUNCTION_ATTRIBUTE,
    OP_STORE_ATTR,
    OP_DELETE_ATTR,
    OP_DELETE_DEREF,
    OP_STORE_DEREF,
    OP_STORE_FAST,
    OP_DELETE_FAST,
    OP_STORE_NAME,
    OP_STORE_GLOBAL,
    OP_DELETE_GLOBAL,
    OP_DELETE_NAME,
    OP_SWAP,
    OP_CHECK_EXC_MATCH,
    OP_POP_EXCEPT,
    OP_BUILD_SET,
    OP_SET_UPDATE,
    OP_CONVERT_VALUE,
    OP_FORMAT_SIMPLE,
    OP_FORMAT_WITH_SPEC,
    OP_BUILD_STRING,
    OP_RETURN_GENERATOR,
    OP_YIELD_VALUE,
    OP_STORE_FAST_LOAD_FAST,
    OP_TO_BOOL,
    OP_CONTAINS_OP,
    OP_LOAD_COMMON_CONSTANT,
    OP_CALL_INTRINSIC_1,
    OP_CALL_INTRINSIC_2,
    OP_LOAD_FAST_AND_CLEAR,
    OP_SEND,
    OP_END_SEND,
    OP_GET_YIELD_FROM_ITER,
    OP_GET_AWAITABLE,
    OP_CLEANUP_THROW,
    OP_UNARY_NEGATIVE,
    OP_UNARY_INVERT,
    OP_UNPACK_SEQUENCE,
    OP_UNPACK_EX,
    OP_GET_LEN,
    OP_MATCH_SEQUENCE,
    OP_MATCH_MAPPING,
    OP_MATCH_KEYS,
    OP_MATCH_CLASS,
    OP_DELETE_SUBSCR,
    OP_MAP_ADD,
    OP_DICT_MERGE,
    OP_DICT_UPDATE,
    OP_STORE_FAST_STORE_FAST,
    OP_EXTENDED_ARG,
    OP_CALL_FUNCTION_EX,
    OP_NOP,
    OP_FOR_ITER,
    OP_POP_ITER,
    opcode_cache_count,
}

def dict_from_str_map(m: dict[str, PyObj]) -> PyDict {
    # Wrap an inherently str-keyed implementation map (frame locals / class
    # namespace / __dict__) into a PyDict with PyStr keys under the hash-key
    # protocol.
    d = PyDict(t="dict", items={});
    for k in m {
        d.dict_set(PyStr(t="str", val=k), m[k]);
    }
    return d;
}

# The proxy archetype (PLAN.md §5, TODO.md Layer 1): wraps a host object and
# routes every slot across the substrate boundary. Born here on the same slot
# mechanism as PyUserObj so bootstrap-time module proxying (import re -> host
# re wrapped in a PyHostProxy) has its socket from day one, not bolted on later.
# Native module object for Layer 2 shim imports (unittest, test.support).
# Installed via register_shim_module so IMPORT_NAME resolves proxy-free.
obj PyModule(PyObj) {
    has name: str,
        attrs: dict[str, PyObj] = {};

    def tp_getattro(attr: str) -> PyObj {
        if attr in self.attrs {
            return self.attrs[attr];
        }
        # Every real module exposes __name__; synthesize it from the registry
        # name so shims behave like CPython modules (IMPORT_FROM error messages
        # used to degrade to "cannot import name 'x' from '<unknown>'").
        if attr == "__name__" {
            return PyStr(t="str", val=self.name);
        }
        if attr == "__dict__" {
            return dict_from_str_map(self.attrs);
        }
        return py_error("AttributeError", attr);
    }

    def tp_setattro(attr: str, value: PyObj) -> PyObj {
        self.attrs[attr] = value;
        return py_none();
    }
}

# Layer 2 shim registry: name -> PyModule. Checked before host import.
glob shim_modules: dict[str, PyObj] = {};

def register_shim_module(name: str, module: PyObj) {
    shim_modules[name] = module;
}

def clear_shim_modules {
    shim_modules = {};
}

def shim_module_get(name: str) -> PyObj {
    if name in shim_modules {
        return shim_modules[name];
    }
    return py_error("ImportError", "shim module '" + name + "' is not installed");
}

def sys3_module_cached(name: str) -> bool {
    return name in sys3_modules;
}

# ---------------- stdlib delegation registry ---------------------------------
# Principled stdlib DELEGATION: pure-C / heavy CPython modules are best served
# by the host interpreter rather than ported or run in-VM. A guest
# ``import <mod>`` / ``from <mod> import ...`` whose module has no NATIVE
# facade (shim_modules) resolves through this single registry instead of the
# ad-hoc per-call-site host proxies used before: the host module is imported
# once, its full dir() surface is snapshotted into a native PyModule (scalars
# converted natively, callables/classes left as transparent host proxies),
# and __name__ carries the full dotted module name.
#
# Precedence: native facades win automatically -- every resolution site checks
# shim_modules BEFORE this registry, so landing e.g. a native ``re`` facade
# later needs no registry edit; deletion of the entry re-activates delegation.
#
# Policy "full": snapshot the whole dir() surface minus non-value module
# machinery (__loader__/__spec__/__path__/__builtins__ never round-trip
# meaningfully); synthesized __name__ always wins over the host's copy.
glob delegate_modules: dict[str, str] = {
    "re": "full",
    "datetime": "full",
    "hashlib": "full",
    "base64": "full",
    "zlib": "full",
    "binascii": "full",
    "uuid": "full",
    # C-extension surface (termios.c lift, jac-py/jacpython/termios.jac):
    # snapshot keeps the constant block guest-native instead of leaking host
    # int identity through a raw PyHostProxy module.
    "termios": "full",
};

# sys.modules semantics: one delegated PyModule per name, identity-stable
# across repeated imports in guest code.
glob delegate_cache: dict[str, PyObj] = {};

# Attribute overrides shared by EVERY guest-sys construction site: exception
# state and frame introspection must read GUEST state -- host sys cannot see
# guest frames. _getframe/currentframe serve live guest PyFrames via the
# jac_frame_chain_slot published by run_frame.
def install_sys_guest_overrides(mod: PyObj) {
    m = mod as PyModule;
    m.attrs["exc_info"] = PyNativeBuiltin(t="native_builtin", name="exc_info");
    m.attrs["exception"] = PyNativeBuiltin(t="native_builtin", name="exception");
    m.attrs["intern"] = PyNativeBuiltin(t="native_builtin", name="intern");
    m.attrs["_getframe"] = PyNativeBuiltin(t="native_builtin", name="sys_getframe");
    m.attrs["currentframe"] = PyNativeBuiltin(
        t="native_builtin", name="sys_currentframe"
    );
    m.attrs["__jac_marker__"] = PyStr(t="str", val="installed");
}

def register_delegate_module(name: str, policy: str) {
    if policy != "full" {
        raise ValueError("unknown delegation policy: " + policy);
    }
    delegate_modules[name] = policy;
}

def clear_delegate_modules {
    delegate_modules = {};
    delegate_cache = {};
}

# Build (or fetch cached) the native PyModule standing in for host module
# `name`. Raises through py_error exactly like host_import when the HOST
# import itself fails (ModuleNotFoundError etc. cross faithfully).
def delegated_module(name: str) -> PyObj {
    if name in delegate_cache {
        return delegate_cache[name];
    }
    star: list[PyObj] = [PyStr(t="str", val="*")];
    result = _jac_host_import(name, to_host(PyList(t="list", items=star)));
    if not ((result[0] as bool)) {
        return py_error(str(result[1]), str(result[2]));
    }
    raw = result[1];
    names_res = _jac_dir_names(raw);
    if not ((names_res[0] as bool)) {
        return py_error(str(names_res[1]), str(names_res[2]));
    }
    attrs: dict[str, PyObj] = {};
    for attr_name in names_res[1] {
        if attr_name == "__loader__" or attr_name == "__spec__"
            or attr_name == "__path__" or attr_name == "__builtins__"
            or attr_name == "__name__" {
            continue;
        }
        got = _jac_host_getattr(raw, attr_name);
        if not ((got[0] as bool)) {
            # A lazy attribute that refuses getattr is simply absent from the
            # snapshot; the guest sees our AttributeError, mirroring a failed
            # host access without poisoning the whole import.
            continue;
        }
        attrs[attr_name] = from_host(got[1]);
    }
    attrs["__name__"] = PyStr(t="str", val=name);
    mod = PyModule(t="module", name=name, attrs=attrs);
    delegate_cache[name] = mod;
    return mod;
}

# ---------------- Layer 3: real un-proxied module import ---------------------
# (jac-py/PLAN.md Layer 3 -- "real unittest boots un-proxied".) When
# layer3_active is set, IMPORT_NAME resolves a module by running its actual
# CPython source as bytecode INSIDE jacpython's own ceval, building a native
# PyModule from the resulting namespace -- rather than wrapping the host module
# in a PyHostProxy. C-extension / built-in / frozen modules (no .py source) stay
# host-proxied; every pure-Python module in the closure executes proxy-free. The
# recursion through IMPORT_NAME pulls the whole dependency closure in-VM. This is
# the milestone that proves the interpreter is real: unittest exercises classes,
# descriptors, exceptions, comprehensions, and the full language surface.

glob sys3_modules: dict[str, PyObj] = {},
     layer3_force_host: list[str] = [],
     layer3_flag: list[bool] = [False];

# Modules deliberately kept host-proxied even though pure-Python source exists,
# because they rely on VM features not yet native (custom metaclasses: enum's
# EnumType drives __prepare__/__new__/__iter__). Proxying a metaclass-heavy leaf
# is the same pragmatic line drawn for C extensions -- it keeps the rest of the
# closure (unittest's own code) running proxy-free. Revisit when metaclasses land.

# One-slot holder rather than a bare `glob layer3_active: bool` -- a scalar glob
# rebound inside a function is scoped local and never persists (see PLAN/memory);
# a list mutated in place does. Read via layer3_is_active() on the IMPORT_NAME path.
def set_layer3_active(flag: bool) {
    layer3_flag[0] = flag;
}

def layer3_is_active -> bool {
    return layer3_flag[0];
}

def clear_sys3_modules {
    sys3_modules = {};
}

# Drop one key from the module cache (used to un-register a module whose in-VM
# execution raised, so a retry re-runs it instead of seeing a half-built shell).
def _sys3_forget(name: str) {
    if name in sys3_modules {
        del sys3_modules[name];
    }
}

def _last_component(dotted: str) -> str {
    parts = dotted.split(".");
    return parts[len(parts) - 1];
}

def _parent_package(dotted: str) -> str {
    parts = dotted.split(".");
    if len(parts) <= 1 {
        return "";
    }
    out = parts[0];
    i = 1;
    while i < len(parts) - 1 {
        out = out + "." + parts[i];
        i = i + 1;
    }
    return out;
}

# Resolve a (possibly relative) import to its absolute module name. `level` is the
# IMPORT_NAME dot-count: 0 = absolute, 1 = current package, 2 = its parent, ...
def _resolve_relative(current_package: str, name: str, level: int) -> str {
    if level == 0 {
        return name;
    }
    parts = current_package.split(".");
    drop = level - 1;
    keep = len(parts) - drop;
    if keep < 0 {
        keep = 0;
    }
    base = "";
    i = 0;
    while i < keep {
        if base == "" {
            base = parts[i];
        } else {
            base = base + "." + parts[i];
        }
        i = i + 1;
    }
    if name == "" {
        return base;
    }
    if base == "" {
        return name;
    }
    return base + "." + name;
}

# Import one fully-qualified module natively, caching it in sys3_modules. Parent
# packages import first (and the submodule is bound as an attribute on its
# parent, per CPython). Pure-Python source runs in-VM; anything else is proxied.
def import_native(absname: str) -> PyObj {
    if absname == "weakref" and not ("weakref" in shim_modules) {
        # Register before the module-info lookup: weakref.py is pure-Python
        # stdlib and would otherwise be executed in-VM against C internals.
        shim_modules["weakref"] = build_weakref_module();
    }
    if absname == "heapq" and not ("heapq" in shim_modules) {
        # heapq.py is pure Python but served from the host it mutates a COPY
        # of every guest list (heappush/heapify silently no-op). The native
        # shim operates on live PyList storage instead.
        shim_modules["heapq"] = build_heapq_module();
    }
    if absname == "gc" and not ("gc" in shim_modules) {
        # Host gc sees only host objects: native guest containers would cross
        # as lossy to_host copies and every query would answer about the wrong
        # heap. Serve the native facade instead (see gc.jac).
        shim_modules["gc"] = PyModule(t="module", name="gc", attrs=gc_module_attrs());
    }
    if absname == "signal" and not ("signal" in shim_modules) {
        # signalmodule.c lift: guest-native constants plus a synchronous
        # dispatch core (signal/getsignal/raise_signal/default_int_handler)
        # layered over the delegated host snapshot for the OS-bound surface.
        sigmod = build_signal_facade();
        if not is_error(sigmod) {
            shim_modules["signal"] = sigmod;
        }
    }
    if absname == "errno" and not ("errno" in shim_modules) {
        # errnomodule.c lift: a pure-data surface (constants + errorcode). The
        # host proxy leaks host int/str identity through every constant and
        # errorcode round-trip; the native facade keeps them guest-native.
        shim_modules["errno"] = PyModule(
            t="module", name="errno", attrs=errno_module_attrs()
        );
    }
    if absname == "_sysconfig" and not ("_sysconfig" in shim_modules) {
        # _sysconfig.c lift: pure-data accelerator for sysconfig (config_vars).
        # The host proxy would answer about the HOST build flags; the facade
        # pins the guest's own build surface instead.
        shim_modules["_sysconfig"] = PyModule(
            t="module", name="_sysconfig", attrs=sysconfig_module_attrs()
        );
    }
    if absname == "sys" and not ("sys" in shim_modules) {
        # Serve a delegate snapshot with exception-state OVERRIDDEN: the host sys
        # sees only host exception state, never guest frames. Snapshot failure
        # falls through to plain delegation (no worse than before).
        sysmod = delegated_module("sys");
        if not is_error(sysmod) {
            install_sys_guest_overrides(sysmod);
            shim_modules["sys"] = sysmod;
        }
    }
    if absname == "traceback" and not ("traceback" in shim_modules) {
        # The host traceback module is unreachable: every API takes tb objects
        # and a native PyTraceback has no to_host arm (host TracebackType needs
        # real host frames). Serve the native chain-walking surface instead.
        tbmod = PyModule(t="module", name="traceback", attrs=traceback_module_attrs());
        (tbmod as PyModule).attrs["format_exc"] = PyNativeBuiltin(
            t="native_builtin", name="tb_format_exc"
        );
        (tbmod as PyModule).attrs["print_exc"] = PyNativeBuiltin(
            t="native_builtin", name="tb_print_exc"
        );
        (tbmod as PyModule).attrs["print_exception"] = PyNativeBuiltin(
            t="native_builtin", name="tb_print_exc_legacy"
        );
        # Shim type markers: make exposed classes isinstance-matchable
        # (ratified exception/tb-surface scope; hot-path guard lives in
        # py_isinstance keyed on one t compare).
        tagmap = _tb_shim_type_tags();
        for tname in tagmap {
            raw_ctor = (tbmod as PyModule).attrs[tname];
            (tbmod as PyModule).attrs[tname] = ShimTypeMarker(
                t="shim_type_marker",
                tag=(tagmap[tname] as PyStr).val,
                ctor=raw_ctor,
            );
        }

        shim_modules["traceback"] = tbmod;
    }
    if absname == "_abc" and not ("_abc" in shim_modules) {
        # Modules/_abc.c lift: guest Lib/abc.py must run subclass/instance
        # checks against native PyClass MROs. A host-proxied _abc hands
        # standins to C ABCMeta.__subclasscheck__, which cannot see guest
        # ancestry -- typing's Protocol gate and enum's IntFlag extend check
        # die with spurious ceval.Flag failures.
        shim_modules["_abc"] = PyModule(
            t="module", name="_abc", attrs=abc_module_attrs()
        );
    }
    if absname in sys3_modules {
        return sys3_modules[absname];
    }
    if absname in shim_modules {
        return shim_modules[absname];
    }
    if absname in delegate_modules {
        # Delegation precedes the module-info lookup: a pure-Python delegatee
        # (re, uuid) must NOT be executed in-VM, and a C module must not take
        # the generic host-proxy path -- both resolve to the same snapshot.
        mod = delegated_module(absname);
        if is_error(mod) {
            return mod;
        }
        sys3_modules[absname] = mod;
        return mod;
    }
    if absname in layer3_force_host {
        star2: list[PyObj] = [PyStr(t="str", val="*")];
        forced = host_import(absname, PyList(t="list", items=star2));
        if is_error(forced) {
            return forced;
        }
        sys3_modules[absname] = forced;
        return forced;
    }
    info = _jac_module_info(absname);
    status = str(info[0]);
    if status == "missing" {
        # CPython imports the parent package BEFORE resolving the submodule,
        # then consults sys.modules before any finder: a package body may have
        # registered the submodule as a registry alias at exec time (see
        # _jac_sys_modules_lookup -- collections.abc on 3.14 has no file).
        if "." in absname {
            pmod = import_native(_parent_package(absname));
            if is_error(pmod) {
                return pmod;
            }
        } else {
            pmod = py_none();
        }
        looked = _jac_sys_modules_lookup(absname);
        looked_status = str(looked[0]);
        if looked_status == "error" {
            return py_error(str(looked[1]), str(looked[2]));
        }
        if looked_status == "hit" {
            alias = PyHostProxy(t="host", val=looked[1]);
            if "." in absname {
                bound = py_set_attr(
                    pmod, _last_component(absname), alias as PyObj
                );
                if is_error(bound) {
                    return bound;
                }
            }
            sys3_modules[absname] = alias;
            return alias;
        }
        return py_error("ModuleNotFoundError", "No module named '" + absname + "'");
    }
    if status == "not-package" {
        return py_error("ModuleNotFoundError", str(info[4]));
    }
    if status == "native" {
        # C extension / built-in / frozen: no source to run in-VM. Proxy the real
        # host module (fromlist truthy so importlib returns the named submodule,
        # not just the top package).
        star: list[PyObj] = [PyStr(t="str", val="*")];
        proxy = host_import(absname, PyList(t="list", items=star));
        if is_error(proxy) {
            return proxy;
        }
        sys3_modules[absname] = proxy;
        return proxy;
    }
    source = str(info[1]);
    is_pkg = info[2] as bool;
    origin = str(info[3]);
    parent = _parent_package(absname);
    if parent != "" {
        pmod = import_native(parent);
        if is_error(pmod) {
            return pmod;
        }
    }
    pkg_name = parent;
    if is_pkg {
        pkg_name = absname;
    }
    modglobals: dict[str, PyObj] = {
        "__name__": PyStr(t="str", val=absname),
        "__package__": PyStr(t="str", val=pkg_name),
        "__file__": PyStr(t="str", val=origin),
        "__doc__": py_none(),

    };
    module = PyModule(t="module", name=absname, attrs=modglobals);
    # Register the (still-executing) module before running its body so a circular
    # import mid-closure resolves to this partial module instead of re-entering.
    sys3_modules[absname] = module;
    outcome = exec_code(unmarshal(host_compile_marshal(source)), [], modglobals);
    if is_error(outcome) {
        _sys3_forget(absname);
        return outcome;
    }
    if absname == "types" {
        # The real types.py runs in-VM, but its coroutine() fast path needs host
        # FunctionType/CodeType identity, which native PyFunction lacks -- its
        # fallback wrapper then hands back plain generators that GET_AWAITABLE
        # must reject. Serve CPython's fast-path semantics natively instead.
        (module as PyModule).attrs["coroutine"] = PyTypesCoroutine(
            t="types_coroutine"
        );
    }
    # attrs aliases modglobals (same dict), so STORE_NAME writes are already live.
    if parent != "" and isinstance(sys3_modules[parent], PyModule) {
        (sys3_modules[parent] as PyModule).attrs[_last_component(absname)] = module;
    }
    return module;
}

# The public names `from module import *` binds: a native PyModule's __all__ (or
# its non-underscore keys); a proxied module's __all__/dir() via the host.
def import_star_names(module: PyObj) -> list[str] {
    if isinstance(module, PyModule) {
        attrs = (module as PyModule).attrs;
        if "__all__" in attrs {
            # __all__ is commonly a list literal (not only a tuple); read either.
            allobj = attrs["__all__"];
            items: list[PyObj] = [];
            if isinstance(allobj, PyList) {
                items = (allobj as PyList).items;
            } else {
                items = tuple_value(allobj);
            }
            allnames: list[str] = [];
            for it in items {
                allnames.append(str_value(it));
            }
            return allnames;
        }
        out: list[str] = [];
        for k in attrs {
            if not k.startswith("_") {
                out.append(k);
            }
        }
        return out;
    }
    result = _jac_star_names(to_host(module));
    if host_result_ok(result) {
        names: list[str] = [];
        for n in result[1] {
            names.append(str(n));
        }
        return names;
    }
    return [];
}

# INTRINSIC_IMPORT_STAR: bind every exported name of `module` into `globals`.
def import_star_into(module: PyObj, globals: dict[str, PyObj]) -> PyObj {
    for nm in import_star_names(module) {
        val = py_attr(module, nm);
        if is_error(val) {
            return val;
        }
        globals[nm] = val;
    }
    return py_none();
}

# IMPORT_NAME entry point under Layer 3. Mirrors CPython's __import__ contract:
# with no fromlist, `import a.b.c` binds and returns the TOP package `a`; with a
# fromlist, returns the named module and ensures each requested submodule exists.
def py_import_name(
    name: str, fromlist: PyObj, level: int, globals: dict[str, PyObj]
) -> PyObj {
    # CPython's import_name package-derivation rule: an explicit string
    # __package__ wins verbatim (even empty -- no fallback); otherwise the
    # parent of __name__ ("a.b.m" -> "a.b"); a dotless name has no parent.
    # Relative imports with no parent at all raise "attempted relative import
    # with no known parent package"; climbing past the top raises
    # "attempted relative import beyond top-level package".
    current_package = "";
    saw_package_str = False;
    if "__package__" in globals {
        pkg = globals["__package__"];
        if isinstance(pkg, PyStr) {
            current_package = (pkg as PyStr).val;
            saw_package_str = True;
        }
    }
    if not saw_package_str and "__name__" in globals {
        nm = globals["__name__"];
        if isinstance(nm, PyStr) {
            current_package = _parent_package((nm as PyStr).val);
        }
    }
    if level > 0 {
        if current_package == "" {
            return py_error(
                "ImportError", "attempted relative import with no known parent package"
            );
        }
        bits = current_package.split(".");
        if len(bits) < level {
            return py_error(
                "ImportError", "attempted relative import beyond top-level package"
            );
        }
    }
    absname = _resolve_relative(current_package, name, level);
    mod = import_native(absname);
    if is_error(mod) {
        return mod;
    }
    has_fromlist = False;
    from_names: list[str] = [];
    if fromlist.t != "none" {
        from_names = str_values(fromlist);
        if len(from_names) > 0 {
            has_fromlist = True;
        }
    }
    if not has_fromlist {
        if level == 0 and "." in absname {
            # `import a.b.c` returns the top package a (STORE_NAME binds `a`).
            top = absname.split(".")[0];
            return import_native(top);
        }
        return mod;
    }
    # `from pkg import x, y`: x/y may be submodules that aren't imported yet. Try
    # to import each as a submodule; a plain attribute (not a module) simply
    # isn't found here and is resolved later by IMPORT_FROM off `mod`.
    for item in from_names {
        if item == "*" {
            continue;
        }
        existing = py_attr(mod, item);
        if is_error(existing) {
            sub = import_native(absname + "." + item);
            # A ModuleNotFoundError just means `item` is a plain attribute, not a
            # submodule -- IMPORT_FROM resolves it off `mod`. Any other error is a
            # real failure importing the submodule and must propagate.
            if is_error(sub)
                and (sub as PyError).exception.type_name != "ModuleNotFoundError" {
                return sub;
            }
        }
    }
    return mod;
}

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
        tname: str = _jac_static_type_name(self.val);
        if tname != "" {
            return py_error(
                "TypeError",
                "can't set attributes of built-in/extension type '" + tname + "'"
            );
        }
        return host_setattr(self, name, value);
    }

    def tp_call(args: list[PyObj], kwargs: dict[str, PyObj]) -> PyObj {
        # Exact host `type` still reaches this proxy on identity edges; route
        # factory shapes through the shared native type_call implementation.
        if bool(_jac_is_type_type(self.val)) {
            return py_type_call(self as PyObj, args, kwargs);
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
        hks = _jac_host_hashkey(self.val);
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
obj PyRange(PyObj) {
    has start: int,
        stop: int,
        step: int;

    def length -> int {
        return get_len_of_range(self.start, self.stop, self.step);
    }

    def tp_getattro(name: str) -> PyObj {
        if name == "start" {
            return PyInt(t="int", val=self.start);
        }
        if name == "stop" {
            return PyInt(t="int", val=self.stop);
        }
        if name == "step" {
            return PyInt(t="int", val=self.step);
        }
        if name == "index" or name == "count" {
            return PyRangeMethod(t="range_method", target=self, name=name);
        }
        return py_error("AttributeError", name);
    }

    # CPython range_hash: hash of the None-stub triple (len, start, step).
    # Computed via the real lifted tuple/int hash machinery so VALUES are
    # byte-parity with the host ratchet, not just equivalence classes.
    # hash(None) is process-stable in CPython (4238894112); substituting an
    # int of that value keeps every lane's hash identical to the real triple.
    def tp_hashkey -> PyObj {
        n = self.length();
        triple: list[PyObj] = [PyInt(t="int", val=n)];
        if n == 0 {
            triple.append(PyInt(t="int", val=4238894112));
            triple.append(PyInt(t="int", val=4238894112));
        } else {
            triple.append(PyInt(t="int", val=self.start));
            if n == 1 {
                triple.append(PyInt(t="int", val=4238894112));
            } else {
                triple.append(PyInt(t="int", val=self.step));
            }
        }
        th = tuple_hash(PyTuple(t="tuple", items=triple));
        if is_error(th) {
            return th;
        }
        # Already-signed numeric digest: the "n:" namespace passes it through
        # verbatim (see _hashkey_digest).
        return PyStr(t="str", val="n:" + str((th as PyInt).val));
    }

    def tp_iter -> PyObj {
        # Fresh cursor per iteration: ranges are re-iterable.
        return PyRangeIter(
            t="rangeiter", cur=self.start, remaining=self.length(), step=self.step
        );
    }

    def tp_bool -> bool {
        return self.length() > 0;
    }

    def mp_subscript(index: PyObj) -> PyObj {
        if isinstance(index, PySlice) {
            err = _zero_step_error(index as PySlice);
            if is_error(err) {
                return err;
            }
            b = slice_indices(index as PySlice, self.length());
            count = get_len_of_range(b[0], b[1], b[2]);
            new_start = self.start + b[0] * self.step;
            new_step = self.step * b[2];
            return PyRange(
                t="range",
                start=new_start,
                stop=new_start + count * new_step,
                step=new_step,
            );
        }
        idx_obj = index.to_index();
        if is_error(idx_obj) {
            return py_error(
                "TypeError",
                "range indices must be integers or slices, not '" + index.t + "'",
            );
        }
        i = (idx_obj as PyInt).val;
        n = self.length();
        if i < 0 {
            i = n + i;
        }
        if i >= 0 and i < n {
            return PyInt(t="int", val=self.start + i * self.step);
        }
        return py_error("IndexError", "range object index out of range");
    }

    def tp_richcompare(kind: int, other: PyObj) -> PyObj {
        # CPython range_richcompare: eq/ne via length-normalized comparison
        # (range(0,10,3) == range(0,12,3)); ordering is NotImplemented.
        if kind == 2 or kind == 3 {
            if isinstance(other, PyRange) {
                og = other as PyRange;
                same = range_equals_longs(
                    self.start, self.stop, self.step, og.start, og.stop, og.step
                );
                return PyBool(t="bool", val=same == (kind == 2));
            }
            return PY_NOT_IMPLEMENTED;
        }
        return PY_NOT_IMPLEMENTED;
    }
}

# One-shot cursor over a PyRange: arithmetic per step, no materialization.
# Driven by the explicit send_into arm (design Q3: hot-loop path).
obj PyRangeIter(PyObj) {
    has cur: int,
        remaining: int,
        step: int;
}

# Owner-prefixed method-descriptor arg errors, byte-matching CPython's
# descriptor wording: `set.add() takes exactly one argument (2 given)`,
# `dict.keys() takes no arguments (1 given)`, and the kwargs refusal form.
def meth_takes_one(owner: str, name: str, n: int) -> PyObj {
    return py_error(
        "TypeError",
        owner + "." + name + "() takes exactly one argument (" + str(n) + " given)",
    );
}

def meth_takes_none(owner: str, name: str, n: int) -> PyObj {
    return py_error(
        "TypeError", owner + "." + name + "() takes no arguments (" + str(n) + " given)"
    );
}

def meth_no_kwargs(owner: str, name: str) -> PyObj {
    return py_error("TypeError", owner + "." + name + "() takes no keyword arguments");
}

# Bound .index()/.count() methods over a PyRange (CPython range_index/
# range_count): exact-int needles take O(1) arithmetic from the lifted leaf;
# everything else scans with real == (_PySequence_IterSearch semantics).
obj PyRangeMethod(PyObj) {
    has target: PyRange,
        name: str;

    def tp_call(args: list[PyObj], kwargs: dict[str, PyObj]) -> PyObj {
        if len(kwargs) > 0 {
            return meth_no_kwargs("range", self.name);
        }
        if len(args) != 1 {
            return meth_takes_one("range", self.name, len(args));
        }
        rg = self.target;
        value = args[0];
        is_int = isinstance(value, PyInt) or isinstance(value, PyBool);
        if self.name == "count" {
            if is_int {
                v = (value as PyInt).val;
                hit = range_contains_longs(rg.start, rg.stop, rg.step, v);
                return PyInt(t="int", val=1 if hit else 0);
            }
            hits = 0;
            cursor = rg.tp_iter();
            while True {
                scan_step = send_into(cursor, py_none());
                if scan_step.t == "genstop" {
                    return PyInt(t="int", val=hits);
                }
                cmp = py_compare(2, value, scan_step);
                if is_error(cmp) {
                    return cmp;
                }
                if cmp.tp_bool() {
                    hits = hits + 1;
                }
            }
        }
        # .index(value)
        if is_int {
            v = (value as PyInt).val;
            if range_contains_longs(rg.start, rg.stop, rg.step, v) {
                pos = (v - rg.start) // rg.step;
                return PyInt(t="int", val=pos);
            }
            return py_error("ValueError", "range.index(x): x not in range");
        }
        cursor = rg.tp_iter();
        position = 0;
        while True {
            scan_step2 = send_into(cursor, py_none());
            if scan_step2.t == "genstop" {
                break;
            }
            cmp = py_compare(2, value, scan_step2);
            if is_error(cmp) {
                return cmp;
            }
            if cmp.tp_bool() {
                return PyInt(t="int", val=position);
            }
            position = position + 1;
        }
        return py_error("ValueError", "sequence.index(x): x not in sequence");
    }
}

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
        for klass in class_mro(self) {
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
            if isinstance(cand, PyFunction) {
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
            return type_new(factory_args, kwargs);
        }
        if has_user_new {
            new_args: list[PyObj] = [self];
            for a in args {
                new_args.append(a);
            }
            made = py_invoke(new_fn as PyFunction, new_args, kwargs);
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
def default_user_getattro(u: PyUserObj, name: str) -> PyObj {
    # A property is a data descriptor: it wins over the instance dict, so
    # `o.v` runs the getter even after `o.v = ...` routed through the setter.
    classattr = class_lookup_attr(u.cls, name);
    if isinstance(classattr, PyProperty) {
        return descriptor_get(classattr, u, u.cls);
    }
    # A slot member descriptor is likewise a data descriptor: reads go through
    # it (host-exact unset-slot error) rather than a raw instance-dict peek.
    if isinstance(classattr, PyMemberDescr) {
        return (classattr as PyMemberDescr)._get(u);
    }
    # A user-defined data descriptor (its type's MRO defines __set__ or
    # __delete__) outranks the instance dict too: reads route through its
    # __get__ via descriptor_get below. CPython precedence order: data
    # descriptor > instance dict > non-data descriptor > class attr.
    if isinstance(classattr, PyUserObj)
        and (user_has_dunder(classattr as PyUserObj, "__set__")
            or user_has_dunder(classattr as PyUserObj, "__delete__")) {
        return descriptor_get(classattr, u, u.cls);
    }
    if name in u.attrs {
        # Instance-__dict__ values return RAW: CPython applies function
        # descriptor binding only to class/MRO entries, never instance-dict
        # data (enum.py:1075 copies found_descriptor.fget and then CALLS it
        # explicitly with the member -- an implicitly bound copy overflows
        # the getter with a doubled receiver).
        return u.attrs[name];
    }
    found = classattr;
    if not is_error(found) {
        # Instance access: bind a method, invoke a property getter, unwrap a
        # staticmethod, or bind a classmethod to the instance's class.
        return descriptor_get(found, u, u.cls);
    }
    # __dict__ exists ONLY when the class layout says so (a slotted class with
    # no explicit __dict__ entry and no dict-bearing base has none -- host:
    # AttributeError 'C' object has no attribute '__dict__'). Checked BEFORE
    # the boxed-base fallthrough so the error names the subclass, not the base.
    if name == "__dict__" {
        return user_instance_dict(u);
    }
    # Fall through to the boxed builtin value's own attributes/methods
    # (str.upper on a str subclass, etc.).
    if u._has_base() {
        return py_attr(u._base_obj(), name);
    }
    # Identity dunder: every object's __class__ resolves to its type object
    # (CPython object.__class__ descriptor). Needed for e.__class__.__name__
    # on caught exceptions and isinstance-style idioms.
    if name == "__class__" {
        return u.cls;
    }
    # object's attribute-protocol methods are real attributes of every
    # instance (hasattr(inst, '__getattribute__') is True); expose them as
    # bound slot wrappers over the generic attribute dispatch.
    if name == "__getattribute__" or name == "__setattr__"
        or name == "__delattr__" {
        return PyObjectAttrSlot(t="obj_attr_slot", target=u as PyObj, op=name);
    }
    return py_error("AttributeError", name);
}

def default_user_setattro(u: PyUserObj, name: str, value: PyObj) -> PyObj {
    # A property with a setter is a data descriptor: assignment routes through
    # fset instead of writing the instance dict.
    classattr = class_lookup_attr(u.cls, name);
    if isinstance(classattr, PyProperty) {
        p = classattr as PyProperty;
        if p.fset is not None {
            res = py_invoke(p.fset as PyObj, [u as PyObj, value], {});
            if is_error(res) {
                return res;
            }
            return py_none();
        }
        return py_error("AttributeError", "can't set attribute '" + name + "'");
    }
    # A slot member descriptor takes the write (data-descriptor priority).
    if isinstance(classattr, PyMemberDescr) {
        return (classattr as PyMemberDescr)._set(u, value);
    }
    # A user-defined data descriptor takes the write through its __set__
    # instead of landing raw in the instance dict (host: type's tp_descr_set);
    # subsequent reads then flow back through its __get__.
    if isinstance(classattr, PyUserObj)
        and user_has_dunder(classattr as PyUserObj, "__set__") {
        return call_user_dunder(classattr as PyUserObj, "__set__", [u as PyObj, value]);
    }
    # __slots__ enforcement: a declared-slot class with no instance dict only
    # accepts its member names -- anything else is the host's two-clause error
    # (the same text delattr produces; CPython shares the no-dict path).
    if u.cls.slots_declared and not u.cls.instance_has_dict
        and not type_slots_attr_allowed(name, False, u.cls.slot_members) {
        return py_error(
            "AttributeError",
            "'" + u.cls.name + "' object has no attribute '" + name
                + "' and no __dict__ for setting new attributes",
        );
    }
    u.attrs[name] = value;
    # Keep the live __dict__ view current (identity-stable mirror).
    if u.dict_cache is not None
        and type_slots_in_dict_view(name, u.cls.slot_members) {
        d = u.dict_cache as PyDict;
        (d as PyInstanceDict).view_set(name, value);
    }
    return py_none();
}

def default_user_delattro(u: PyUserObj, name: str) -> PyObj {
    # A property with a deleter is a data descriptor: deletion routes through
    # fdel instead of removing an instance-dict entry (mirror of the setter
    # branch in default_user_setattro).
    classattr = class_lookup_attr(u.cls, name);
    if isinstance(classattr, PyProperty) {
        p = classattr as PyProperty;
        if p.fdel is not None {
            res = py_invoke(p.fdel as PyObj, [u as PyObj], {});
            if is_error(res) {
                return res;
            }
            return py_none();
        }
        return py_error("AttributeError", "can't delete attribute '" + name + "'");
    }
    # A slot member descriptor takes the delete (empty slot reports the bare
    # member name via _del).
    if isinstance(classattr, PyMemberDescr) {
        return (classattr as PyMemberDescr)._del(u);
    }
    # Same no-dict gate as writes: deleting an undeclared name on a slotted,
    # dict-less instance raises the host's two-clause AttributeError.
    if u.cls.slots_declared and not u.cls.instance_has_dict
        and not type_slots_attr_allowed(name, False, u.cls.slot_members) {
        return py_error(
            "AttributeError",
            "'" + u.cls.name + "' object has no attribute '" + name
                + "' and no __dict__ for setting new attributes",
        );
    }
    if name in u.attrs {
        del u.attrs[name];
        if u.dict_cache is not None
            and type_slots_in_dict_view(name, u.cls.slot_members) {
            (u.dict_cache as PyInstanceDict).view_del(name);
        }
        return py_none();
    }
    return py_error("AttributeError", name);
}

# The live instance ``__dict__``: a real dict (subclass of PyDict) whose items
# mirror the owner's attribute map, so CPython's identity/write-through/
# reflection triangle holds -- ``o.__dict__ is o.__dict__``, writes through a
# fetched reference are visible as attributes and vice versa. Slot member
# names stay OUT of the view (CPython keeps d.a out of d.__dict__ even with
# __slots__ = ('a', '__dict__')); writes of those names land in an overlay so
# they iterate in the view while attribute reads still hit the member
# descriptor first.
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

def user_instance_dict(u: PyUserObj) -> PyObj {
    if not u.cls.instance_has_dict {
        return py_error(
            "AttributeError",
            "'" + u.cls.name + "' object has no attribute '__dict__'",
        );
    }
    if u.dict_cache is not None {
        return u.dict_cache as PyObj;
    }
    d = PyInstanceDict(t="dict", owner=u, items={});
    for k in u.attrs {
        if type_slots_in_dict_view(k, u.cls.slot_members) {
            (d as PyInstanceDict).view_set(k, u.attrs[k]);
        }
    }
    u.dict_cache = d;
    return d as PyObj;
}

# CPython mappingproxy: a read-only view over a dict (class __dict__,
# ``Field.metadata``, module surfaces). Reads and iteration delegate to the
# wrapped dict; every mutation entry raises the host's two-clause TypeError.
obj PyMappingProxy(PyObj) {
    has target: PyDict;

    def mp_subscript(index: PyObj) -> PyObj {
        return self.target.mp_subscript(index);
    }

    def mp_ass_subscript(index: PyObj, value: PyObj) -> PyObj {
        return py_error(
            "TypeError", "'mappingproxy' object does not support item assignment"
        );
    }

    def mp_del_subscript(index: PyObj) -> PyObj {
        return py_error(
            "TypeError", "'mappingproxy' object does not support item deletion"
        );
    }

    def tp_getattro(name: str) -> PyObj {
        # Read-only method surface: mapping-style accessors delegate to the
        # wrapped dict's native methods; keys/values/items construct live
        # set-like views exactly as a plain dict does.
        if name == "keys" or name == "values" or name == "items" {
            return PyDictViewCtor(
                t="view_ctor", d=self.target, mode=name
            );
        }
        if name == "get" or name == "copy" or name == "__contains__"
            or name == "__getitem__" {
            return PyDictMethod(
                t="dict_method", target=self.target, name=name
            );
        }
        return py_error("AttributeError", name);
    }
}

# type.mro() as a bound method on a class: the C3 linearization with the
# terminal object appended -- the same list __mro__ displays. A class-dict
# `mro` entry shadows this via the attrs-first lookup in tp_getattro, matching
# CPython's overridable type.mro.
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

# Bound __mro_entries__ callable for PyGenericAlias: CPython's _GenericAlias
# method returns a tuple of replacement bases when __build_class__ invokes it
# (bltinmodule.c update_bases); ours resolves to Generic itself.
obj PyGenericMroEntries(PyObj) {
    def tp_call(args: list[PyObj], kwargs: dict[str, PyObj]) -> PyObj {
        return PyTuple(t="tuple", items=[typing_generic_class()]);
    }
}

# typing.NoDefault sentinel (PEP 696): a type parameter without an explicit
# default answers __default__ with this immortal singleton.
obj PyNoDefault(PyObj) {
}

glob _no_default_singleton: any = None;

def no_default_sentinel() -> PyObj {
    if _no_default_singleton is None {
        _no_default_singleton = PyNoDefault(t="nodefault");
    }
    return _no_default_singleton;
}

glob _generic_class_cache: any = None;

# Native stand-in for typing.Generic: the base that implicit PEP 695 class
# parameters resolve to through __mro_entries__, so a generic class's MRO
# reads (C, Generic, object) like CPython's. Cached -- every generic class
# shares this one base object, so identity comparisons hold.
def typing_generic_class() -> PyClass {
    if _generic_class_cache is None {
        _generic_class_cache = PyClass(
            t="class",
            name="Generic",
            attrs={
                "__module__": PyStr(t="str", val="typing"),
                "__qualname__": PyStr(t="str", val="Generic"),
            },
        );
    }
    return _generic_class_cache as PyClass;
}

obj PyBuildClass(PyObj) {
    def tp_call(args: list[PyObj], kwargs: dict[str, PyObj]) -> PyObj {
        return py_build_class(args, kwargs);
    }
}

# ---------------- native descriptors: classmethod / staticmethod / property ----
# These are pervasive across the stdlib closure (enum, typing, abc, dataclasses).
# Each is a descriptor: attribute lookup on a class/instance resolves it through
# descriptor_get, which binds the class (classmethod), unwraps (staticmethod), or
# invokes the getter (property).
obj PyClassMethod(PyObj) {
    has func: PyObj;

    # `__func__` exposes the wrapped function (namedtuple rewrites
    # `_make.__func__.__qualname__`; functools/abc read it too).
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

obj PyProperty(PyObj) {
    has fget: any = None,
        fset: any = None,
        fdel: any = None;

    # Identity hash: CPython property objects are set/dict-key legal.
    def tp_hashkey -> PyObj {
        return PyStr(t="str", val="obj:" + str(id(self)));
    }

    # `@x.setter` / `.getter` / `.deleter` each yield a modifier that rebuilds the
    # property with one accessor replaced.
    def tp_getattro(name: str) -> PyObj {
        if name == "setter" {
            return PyPropModifier(t="propmod", prop=self, which="set");
        }
        if name == "getter" {
            return PyPropModifier(t="propmod", prop=self, which="get");
        }
        if name == "deleter" {
            return PyPropModifier(t="propmod", prop=self, which="del");
        }
        if name == "fget" {
            return self.fget if self.fget is not None else py_none();
        }
        if name == "fset" {
            return self.fset if self.fset is not None else py_none();
        }
        if name == "fdel" {
            return self.fdel if self.fdel is not None else py_none();
        }
        # CPython property.__doc__: the getter's docstring (None when absent);
        # derived lazily so @x.setter chains keep the original doc for free.
        if name == "__doc__" {
            if self.fget is not None {
                doc = py_attr(self.fget as PyObj, "__doc__");
                if not is_error(doc) {
                    return doc;
                }
            }
            return py_none();
        }
        # ABC machinery reads this on every attribute walk of an abstract
        # base -- absent answers False unless any accessor declares itself
        # abstract (CPython property_init / prop_get___isabstractmethod__).
        if name == "__isabstractmethod__" {
            for acc in [self.fget, self.fset, self.fdel] {
                if acc is not None {
                    mark = py_attr(acc as PyObj, "__isabstractmethod__");
                    if not is_error(mark)
                        and isinstance(mark, PyBool)
                        and (mark as PyBool).val {
                        return mark;
                    }
                }
            }
            return PyBool(t="bool", val=False);
        }
        # The descriptor protocol surface itself: property.__get__/__set__/
        # __delete__ are real attributes in CPython (C.v.__get__(inst) runs the
        # accessor directly).
        if name == "__get__" or name == "__set__" or name == "__delete__" {
            return PyPropAccess(t="prop_access", prop=self, op=name);
        }
        # A property object is itself an object: its attribute protocol answers
        # through the same bound slot wrapper instances get.
        if name == "__getattribute__" {
            return PyObjectAttrSlot(t="obj_attr_slot", target=self as PyObj, op=name);
        }
        return py_error("AttributeError", name);
    }
}

# The bound property.__get__/__set__/__delete__ accessors (descriptor-protocol
# parity: the same operations implicit attribute dispatch uses, invocable by
# hand as CPython's slot wrappers are).
obj PyPropAccess(PyObj) {
    has prop: PyProperty,
        op: str;

    def tp_call(args: list[PyObj], kwargs: dict[str, PyObj]) -> PyObj {
        p = self.prop;
        if self.op == "__get__" {
            if len(args) < 1 {
                return py_error(
                    "TypeError",
                    "__get__ expected at least 1 argument, got " + str(len(args)),
                );
            }
            if isinstance(args[0], PyNoneType) {
                # obj.__get__(None, owner): class-level access returns the
                # property object itself.
                return p as PyObj;
            }
            if p.fget is None {
                return py_error("AttributeError", "property has no getter");
            }
            return py_invoke(p.fget as PyObj, [args[0]], {});
        }
        if self.op == "__set__" {
            if len(args) < 2 {
                return py_error(
                    "TypeError", "__set__ expected 2 arguments, got " + str(len(args))
                );
            }
            if p.fset is None {
                return py_error("AttributeError", "property has no setter");
            }
            return py_invoke(p.fset as PyObj, [args[0], args[1]], {});
        }
        if len(args) < 1 {
            return py_error(
                "TypeError",
                "__delete__ expected at least 1 argument, got " + str(len(args)),
            );
        }
        if p.fdel is None {
            return py_error("AttributeError", "property has no deleter");
        }
        return py_invoke(p.fdel as PyObj, [args[0]], {});
    }
}

obj PyPropModifier(PyObj) {
    has prop: PyProperty,
        which: str;

    def tp_call(args: list[PyObj], kwargs: dict[str, PyObj]) -> PyObj {
        fn = args[0];
        p = self.prop;
        if self.which == "set" {
            return PyProperty(t="property", fget=p.fget, fset=fn, fdel=p.fdel);
        }
        if self.which == "del" {
            return PyProperty(t="property", fget=p.fget, fset=p.fset, fdel=fn);
        }
        return PyProperty(t="property", fget=fn, fset=p.fset, fdel=p.fdel);
    }
}

# object.__init__ / a builtin's default __init__: accepts any args, does nothing.
# Reached when `inst.__init__(*args)` runs on an object whose class defines no
# __init__ (enum calls enum_member.__init__(*args) unconditionally).
obj PyNoOpInit(PyObj) {
    def tp_call(args: list[PyObj], kwargs: dict[str, PyObj]) -> PyObj {
        return py_none();
    }
}

# Bound object.__getattribute__/__setattr__/__delattr__ over a native instance:
# the generic attribute protocol exposed AS attributes, exactly as CPython's
# slot wrappers are (hasattr(inst, '__getattribute__') is True). With target
# None it is the UNBOUND wrapper (object.__setattr__ read off the type); the
# receiver then comes from the first call argument. On a PyUserObj receiver it
# runs default_user_* directly -- the wrapper IS object.__*attr__, so a user
# override delegating through it must not re-enter itself.
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

obj PyClassMethodCtor(PyObj) {
    def tp_call(args: list[PyObj], kwargs: dict[str, PyObj]) -> PyObj {
        if len(args) < 1 {
            return py_error(
                "TypeError", "classmethod expected 1 argument, got " + str(len(args))
            );
        }
        return PyClassMethod(t="classmethod", func=args[0]);
    }
}

obj PyStaticMethodCtor(PyObj) {
    def tp_call(args: list[PyObj], kwargs: dict[str, PyObj]) -> PyObj {
        if len(args) < 1 {
            return py_error(
                "TypeError", "staticmethod expected 1 argument, got " + str(len(args))
            );
        }
        return PyStaticMethod(t="staticmethod", func=args[0]);
    }
}

obj PyPropertyCtor(PyObj) {
    # Identity hash (CPython: builtin_function_or_method-style objects hash by
    # id) -- property/property-constructor objects live in sets and dict keys
    # across the stdlib (codec registries, ABC caches).
    def tp_hashkey -> PyObj {
        return PyStr(t="str", val="obj:" + str(id(self)));
    }

    def tp_call(args: list[PyObj], kwargs: dict[str, PyObj]) -> PyObj {
        fget: PyObj = py_none();
        fset: PyObj = py_none();
        fdel: PyObj = py_none();
        if len(args) >= 1 {
            fget = args[0];
        }
        if len(args) >= 2 {
            fset = args[1];
        }
        if len(args) >= 3 {
            fdel = args[2];
        }
        if "fget" in kwargs {
            fget = kwargs["fget"];
        }
        if "fset" in kwargs {
            fset = kwargs["fset"];
        }
        if "fdel" in kwargs {
            fdel = kwargs["fdel"];
        }
        return PyProperty(
            t="property",
            fget=fget if not isinstance(fget, PyNoneType) else None,
            fset=fset if not isinstance(fset, PyNoneType) else None,
            fdel=fdel if not isinstance(fdel, PyNoneType) else None
        );
    }
}

# The descriptor protocol for attribute access. `instance` is the object the
# attribute was fetched from (None for class-level access); `owner` is the class
# that supplied the attribute. Plain functions bind to a real instance and stay
# unbound on class access; the native descriptors do their own binding.
# The ``__slots__`` member descriptor (CPython PyMemberDescr for T_OBJECT_EX
# slots): one per OWN declared slot, installed on the class at creation. It is a
# data descriptor -- reads/writes/deletes route through _get/_set/_del with the
# host-exact error surfaces -- and its storage lives on the instance attribute
# map under the (mangled) member name, filtered out of __dict__ views.
obj PyMemberDescr(PyObj) {
    has member: str,
        owner: str;

    def tp_getattro(name: str) -> PyObj {
        if name == "__name__" {
            return PyStr(t="str", val=self.member);
        }
        if name == "__qualname__" {
            return PyStr(t="str", val=self.owner + "." + self.member);
        }
        # The descriptor protocol surface itself: member.__get__/__set__/
        # __delete__ are invocable by hand in CPython (bound slot wrappers).
        if name == "__get__" or name == "__set__" or name == "__delete__" {
            return PyMemberAccess(t="member_access", descr=self, op=name);
        }
        return py_error("AttributeError", name);
    }

    def tp_str -> PyObj {
        return PyStr(
            t="str", val=type_slots_member_repr(self.member, self.owner)
        );
    }

    # slot-member read: unset raises the generic getattro message (host:
    # `'C' object has no attribute 'x'`).
    def _get(u: PyUserObj) -> PyObj {
        if self.member in u.attrs {
            return u.attrs[self.member];
        }
        return py_error(
            "AttributeError",
            "'" + self.owner + "' object has no attribute '" + self.member + "'",
        );
    }

    def _set(u: PyUserObj, value: PyObj) -> PyObj {
        u.attrs[self.member] = value;
        return py_none();
    }

    # Deleting an empty slot reports the bare member name (host:
    # `AttributeError: x`), unlike every other attr error.
    def _del(u: PyUserObj) -> PyObj {
        if self.member in u.attrs {
            del u.attrs[self.member];
            return py_none();
        }
        return py_error("AttributeError", self.member);
    }
}

# The bound member.__get__/__set__/__delete__ accessors (same descriptor-
# protocol parity pattern as PyPropAccess for property).
obj PyMemberAccess(PyObj) {
    has descr: PyMemberDescr,
        op: str;

    def tp_call(args: list[PyObj], kwargs: dict[str, PyObj]) -> PyObj {
        d = self.descr;
        if self.op == "__get__" {
            # (obj, owner); obj=None answers the descriptor itself.
            if len(args) < 1 or not isinstance(args[0], PyUserObj) {
                return d;
            }
            return d._get(args[0] as PyUserObj);
        }
        if self.op == "__set__" {
            if len(args) < 2 or not isinstance(args[0], PyUserObj) {
                return py_error(
                    "TypeError",
                    "__set__ takes (instance, value) -- descriptor '"
                        + d.member + "' of '" + d.owner + "' objects",
                );
            }
            return d._set(args[0] as PyUserObj, args[1]);
        }
        if len(args) < 1 or not isinstance(args[0], PyUserObj) {
            return py_error(
                "TypeError",
                "__delete__ takes (instance) -- descriptor '"
                    + d.member + "' of '" + d.owner + "' objects",
            );
        }
        return d._del(args[0] as PyUserObj);
    }
}

def descriptor_get(value: PyObj, instance: PyObj, owner: PyObj) -> PyObj {
    if isinstance(value, PyClassMethod) {
        return PyBoundMethod(
            t="bound_method", function=(value as PyClassMethod).func, receiver=owner
        );
    }
    if isinstance(value, PyStaticMethod) {
        return (value as PyStaticMethod).func;
    }
    if isinstance(value, PyProperty) {
        prop = value as PyProperty;
        if not isinstance(instance, PyNoneType) {
            if prop.fget is None {
                return py_error("AttributeError", "unreadable attribute");
            }
            return py_invoke(prop.fget as PyObj, [instance], {});
        }
        return value;
    }
    if value.t == "function" and not isinstance(instance, PyNoneType) {
        return PyBoundMethod(t="bound_method", function=value, receiver=instance);
    }
    # User-defined descriptor protocol (host: any type whose MRO defines
    # __get__ carries a non-NULL tp_descr_get): a class-dict object of such a
    # type binds through it -- `C().attr` runs descr.__get__(obj, owner)
    # instead of leaking the raw descriptor object. A None instance on
    # class-level access still invokes __get__(None, owner), matching
    # slot_tp_descr_get's Py_None substitution -- the descriptor itself
    # decides. Probed via direct MRO dict walks (user_has_dunder), never the
    # attribute dispatch, so probing the protocol names cannot re-enter this
    # code.
    if isinstance(value, PyUserObj)
        and user_has_dunder(value as PyUserObj, "__get__") {
        return call_user_dunder(value as PyUserObj, "__get__", [instance, owner]);
    }
    return value;
}

# Bound `__get__` accessor minted by function/classmethod/staticmethod
# tp_getattro arms so the descriptor protocol is visible through hasattr /
# getattr on the wrappers themselves (enum's _EnumDict classifies methods via
# hasattr(obj, '__get__'); inspect/functools/copy do the same). Calling it
# performs the real binding through descriptor_get.
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
            d = PyFuncKwDefaults(t="dict", owner=self, items={});
            for k in self.kwdefaults {
                hk = hashkey_str((PyStr(t="str", val=k)).tp_hashkey());
                d.items[hk] = DictEntry(
                    key=PyStr(t="str", val=k), value=self.kwdefaults[k]
                );
            }
            self.kw_live = d;
            return d as PyObj;
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
            d = PyFuncDictView(t="dict", owner=self, items={});
            for k in self.attrs {
                if not func_attr_is_fixed(k) {
                    hk = hashkey_str((PyStr(t="str", val=k)).tp_hashkey());
                    d.items[hk] = DictEntry(
                        key=PyStr(t="str", val=k), value=self.attrs[k]
                    );
                }
            }
            self.attr_dict_live = d;
            return d as PyObj;
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

def host_result_ok(result: any) -> bool {
    return result[0] == True;
}

# Function fixed-surface names: never visible in f.__dict__ (CPython stores
# them as type-level descriptors, not dict entries).
def func_attr_is_fixed(name: str) -> bool {
    return name in {
        "__name__", "__qualname__", "__doc__", "__module__",
        "__defaults__", "__kwdefaults__", "__code__", "__globals__",
        "__closure__", "__builtins__", "__dict__", "__wrapped__"
    };
}

# Live ``f.__dict__`` view: mutations write through to the function attribute
# map (minus the fixed surface) and attribute assignments reflect into it.
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
glob _from_host_memo: dict[int, PyObj] = {};

# Process-wide mirror of the per-frame exc_handling stack: the exception
# currently being handled, for sys.exc_info()/traceback.format_exc(). Pushed at
# OP_PUSH_EXC_INFO, popped at OP_POP_EXCEPT. Divergence vs CPython: a generator
# suspended inside an except block keeps its entry visible to unrelated frames
# until it resumes/pops (single-threaded VM approximation).
glob _handled_exc_stack: list[PyObj] = [];

def current_handled_exc() -> PyObj {
    if len(_handled_exc_stack) == 0 {
        return py_none();
    }
    return _handled_exc_stack[len(_handled_exc_stack) - 1];
}

# Explicit opt-in live bridge (fp-e87c ContextVar cluster): consumers that need
# WRITE-THROUGH container crossing -- guest mutations visible to host code and
# vice versa -- call this INSTEAD of the default snapshot to_host arms. The
# default MUTABLE_COPY policy for plain list/dict/set stays untouched (existing
# consumers rely on snapshot isolation); live views are minted only through
# this explicit path. Returns None for anything not a live-viewable mutable
# container (frozenset included) so callers can fall back to to_host.
def live_container_bridge(value: PyObj) -> any {
    match value {
        case PyList():
            return _jac_make_live_list(value);
        case PyDict():
            return _jac_make_live_dict(value);
        case PySet():
            if not (value as PySet).frozen {
                return _jac_make_live_set(value as PySet);
            }
    }
    return None;
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

def from_host(raw: any) -> PyObj {
    if raw is None {
        return py_none();
    }
    # STANDIN round-trip: a host stand-in crossing back recovers the ORIGINAL
    # guest class/instance (identity preserved). The helper self-gates on
    # type/__dict__ presence so scalar/container fast paths stay cheap.
    g = _jac_recover_guest(raw);
    if g is not None {
        return g as PyObj;
    }
    # A host instance whose type is a PROPER subclass of a builtin container/
    # scalar (namedtuple, IntEnum, a host-built `class X(list)`) must not be
    # flattened into a native PyTuple/PyList/PyInt -- that would erase its real
    # type and its own descriptors. Keep it as a proxy so p.x / .name / repr all
    # route back to the host object. (A trampoline we minted is recovered first.)
    if _jac_is_builtin_subclass_instance(raw) {
        recovered = _jac_recover_native(raw);
        if recovered is not None {
            return recovered as PyObj;
        }
        return PyHostProxy(t="host", val=raw);
    }
    # VALUE_COPY both ways: the richcompare-deferral sentinel crossing back
    # home must recover the native singleton, not degrade to an opaque proxy.
    if raw is NotImplemented {
        return PY_NOT_IMPLEMENTED;
    }
    if isinstance(raw, bool) {
        return PyBool(t="bool", val=raw);
    }
    if isinstance(raw, int) {
        return PyInt(t="int", val=raw);
    }
    if isinstance(raw, float) {
        return PyFloat(t="float", val=raw);
    }
    if isinstance(raw, complex) {
        # VALUE_COPY declares complex lossless BOTH ways, but the reverse arm
        # was missing: a host complex (e.g. returned by a bridged call) fell
        # through to PyHostProxy, breaking native arithmetic/repr on return.
        return PyComplex(t="complex", real=raw.real, imag=raw.imag);
    }
    if isinstance(raw, str) {
        return PyStr(t="str", val=raw);
    }
    if isinstance(raw, bytes) {
        byte_values: list[int] = [];
        for item in raw {
            byte_values.append(item);
        }
        return PyBytes(t="bytes", val=byte_values);
    }
    if isinstance(raw, range) {
        # Native PyRange preserves identity AND laziness (TODO item 19): no
        # element drain -- start/stop/step carry all the information.
        return PyRange(t="range", start=raw.start, stop=raw.stop, step=raw.step);
    }
    if isinstance(raw, slice) {
        # A dynamic host slice (slice(1, 7, 2) built by bridged guest code)
        # materializes as a native PySlice: the subscript slots' slice branches
        # key on isinstance(PySlice), and a PyHostProxy here would make xs[s]
        # raise "list indices must be integers" while inline xs[1:7:2] works.
        return PySlice(
            t="slice",
            start=from_host(raw.start),
            stop=from_host(raw.stop),
            step=from_host(raw.step),
        );
    }
    if isinstance(raw, list) {
        memo_key = _jac_host_id(raw);
        if memo_key in _from_host_memo {
            return _from_host_memo[memo_key];
        }
        placeholder = PyList(t="list", items=[]);
        _from_host_memo[memo_key] = placeholder;
        for item in raw {
            (placeholder as PyList).items.append(from_host(item));
        }
        _from_host_memo.pop(memo_key);
        return placeholder;
    }
    if isinstance(raw, tuple) {
        memo_key = _jac_host_id(raw);
        if memo_key in _from_host_memo {
            # Immutable: a cycle through this tuple cannot be patched up
            # post-construction; degrade the re-entrant reference to a proxy.
            return PyHostProxy(t="host", val=raw);
        }
        _from_host_memo[memo_key] = PyNoneType(t="none");
        tuple_values: list[PyObj] = [];
        for item in raw {
            tuple_values.append(from_host(item));
        }
        _from_host_memo.pop(memo_key);
        return PyTuple(t="tuple", items=tuple_values);
    }
    if isinstance(raw, dict) {
        # Native PyDict now keys on the hash-key protocol, so any hashable key
        # (int, tuple, float, ...) lands natively. A key whose from_host wrapper
        # is unhashable (e.g. an opaque host object) keeps the whole dict opaque
        # as a PyHostProxy -- it round-trips through to_host unchanged.
        memo_key = _jac_host_id(raw);
        if memo_key in _from_host_memo {
            return _from_host_memo[memo_key];
        }
        native = PyDict(t="dict", items={});
        _from_host_memo[memo_key] = native;
        for key in raw {
            keyobj = from_host(key);
            if is_error(keyobj.tp_hashkey()) {
                _from_host_memo.pop(memo_key);
                return PyHostProxy(t="host", val=raw);
            }
            native.dict_set(keyobj, from_host(raw[key]));
        }
        _from_host_memo.pop(memo_key);
        return native;
    }
    if isinstance(raw, frozenset) {
        fs = PySet(t="frozenset", items={}, frozen=True);
        for member in raw {
            memberobj = from_host(member);
            if is_error(memberobj.tp_hashkey()) {
                return PyHostProxy(t="host", val=raw);
            }
            fs.set_add(memberobj);
        }
        return fs;
    }
    if isinstance(raw, set) {
        ns = PySet(t="set", items={}, frozen=False);
        for member in raw {
            memberobj = from_host(member);
            if is_error(memberobj.tp_hashkey()) {
                return PyHostProxy(t="host", val=raw);
            }
            ns.set_add(memberobj);
        }
        return ns;
    }
    # A host trampoline coming back home (e.g. a native __new__ that host type()
    # stored, then handed back on class construction) recovers its original
    # native function rather than nesting host->native->host indirection.
    recovered = _jac_recover_native(raw);
    if recovered is not None {
        return recovered as PyObj;
    }
    return PyHostProxy(t="host", val=raw);
}

# ================= typed guest<->host boundary table ========================
# ONE authoritative policy per native type tag. Every crossing decision lives
# here; ad-hoc match+fallthrough in to_host/_host_representable is gone. An
# unknown tag FAILS LOUDLY (RuntimeError naming the tag) -- it can never again
# silently degrade to None at the boundary.
#
# Policies:
#   VALUE_COPY   immutable scalar copied by value both ways (lossless)
#   DEEP_COPY    immutable aggregate deep-copied (tuple/frozenset/slice/range)
#   MUTABLE_COPY declared divergence: mutable container deep-copied; mutations
#                on either side DO NOT propagate (documented, greppable)
#   VIEW_COPY    dict view rebuilt as a live host view over a copied dict
#   TRAMPOLINE   callable becomes a host trampoline calling back into ceval
#   LAZY_ITER    iterator/generator becomes a LAZY host iterator sharing
#                position with the guest object (no silent draining/consuming)
#   STANDIN      name-faithful cached host stand-in (classes, plain user
#                objects); round-trips back to the original guest object
#   EXCEPTION    exception materializes as a real host BaseException via the
#                module-exception registry (exceptions_core.jac)
#   PROXY        opaque host-backed proxy passthrough (PyHostProxy)
#   FAIL         no host representation: loud RuntimeError naming the tag
enum BridgePolicy {
    VALUE_COPY,
    DEEP_COPY,
    MUTABLE_COPY,
    VIEW_COPY,
    TRAMPOLINE,
    LAZY_ITER,
    STANDIN,
    EXCEPTION,
    PROXY,
    FAIL,
}

def to_host_policy(tag: str) -> BridgePolicy {
    if tag == "none"
        or tag == "bool"
        or tag == "int"
        or tag == "float"
        or tag == "complex"
        or tag == "str"
        or tag == "bytes"
        or tag == "notimplemented" {
        return BridgePolicy.VALUE_COPY;
    }
    if tag == "tuple" or tag == "frozenset" or tag == "slice" or tag == "range" {
        return BridgePolicy.DEEP_COPY;
    }
    if tag == "list" or tag == "dict" or tag == "set" {
        return BridgePolicy.MUTABLE_COPY;
    }
    if tag == "mappingproxy" or tag == "interpolation" or tag == "template" {
        return BridgePolicy.DEEP_COPY;
    }
    if tag == "dictview_obj" or tag == "globals" {
        return BridgePolicy.VIEW_COPY;
    }
    if tag == "function"
        or tag == "native_builtin"
        or tag == "bound_method"
        or tag == "gen_method"
        or tag == "list_method"
        or tag == "dict_method"
        or tag == "set_method"
        or tag == "native_new"
        or tag == "classmethod"
        or tag == "staticmethod"
        or tag == "classmethod_ctor"
        or tag == "staticmethod_ctor"
        or tag == "property_ctor"
        or tag == "property" {
        return BridgePolicy.TRAMPOLINE;
    }
    if tag == "iter"
        or tag == "seqiter"
        or tag == "rangeiter"
        or tag == "dictiter"
        or tag == "calliter"
        or tag == "generator" {
        return BridgePolicy.LAZY_ITER;
    }
    if tag == "class" or tag == "instance" {
        return BridgePolicy.STANDIN;
    }
    if tag == "exception" {
        return BridgePolicy.EXCEPTION;
    }
    if tag == "host" {
        return BridgePolicy.PROXY;
    }
    return BridgePolicy.FAIL;
}

def to_host(value: PyObj) -> any {
    # Table gate FIRST: an unknown tag fails loudly before any conversion runs.
    # A tag WITH policy but missing conversion arm below also fails loudly.
    policy = to_host_policy(value.t);
    match value {
        case PyNoneType():
            return None;

        case PyBool():
            return value.val;

        case PyInt():
            return value.val;

        case PyFloat():
            return value.val;

        case PyComplex():
            return complex(value.real, value.imag);

        case PyStr():
            return value.val;

        case PyBytes():
            return bytes(value.val);

        case PyTuple():
            tuple_items: list[any] = [];
            for item in value.items {
                tuple_items.append(to_host(item));
            }
            return tuple(tuple_items);

        case PyList():
            list_items: list[any] = [];
            for item in value.items {
                list_items.append(to_host(item));
            }
            return list_items;

        case PyDict():
            dict_items: dict[any, any] = {};
            for hk in value.items {
                `entry = value.items[hk];
                dict_items[to_host(`entry.key)] = to_host(`entry.value);
            }
            return dict_items;

        case PySet():
            members: list[any] = [];
            for member in value.set_members() {
                members.append(to_host(member));
            }
            if value.frozen {
                return frozenset(members);
            }
            return set(members);

        case PySlice():
            return slice(
                to_host(value.start), to_host(value.stop), to_host(value.step)
            );

        case PyRange():
            # A real host range, so host consumers see the reference type. Note:
            # a NEW host object per crossing -- identity does not round-trip
            # (accepted deviation D-RANGE-ID, docs/RANGE_BRIDGE_DESIGN.md).
            return range(value.start, value.stop, value.step);

        case PyFunction():
            # A native function crossing to the host becomes a trampoline that
            # calls back into ceval (see _jac_make_host_trampoline). This is what
            # lets host type()/classmethod/property/functools wrap and later
            # invoke jacpython functions -- the round-trip that unblocks
            # namedtuple's dynamic class creation and decorator machinery.
            return _jac_make_host_trampoline(value);

        case PyNativeBuiltin():
            # NB: Jac match has NO grouped/stacked case labels -- `case A():
            # case B(): body` gives ONLY B the body and silently drops A.
            # Each callable kind therefore carries its own (shared) arm.
            return _jac_make_host_trampoline(value);

        case PyBoundMethod():
            return _jac_make_host_trampoline(value);

        case PyGenMethod():
            # Native builtins/bound methods crossing to the host become
            # trampolines too (same round-trip as PyFunction): host code can
            # call them and from_host recovers the native via __jac_native__.
            return _jac_make_host_trampoline(value);

        case PyListMethod():
            return _jac_make_host_trampoline(value);

        case PyDictMethod():
            return _jac_make_host_trampoline(value);

        case PySetMethod():
            return _jac_make_host_trampoline(value);

        case PyStrMethod():
            return _jac_make_host_trampoline(value);

        case PyClassMethodCtor():
            # The classmethod/staticmethod/property builtin objects themselves
            # crossing to the host: trampoline replays their tp_call so the
            # host sees working descriptor factories.
            return _jac_make_host_trampoline(value);

        case PyStaticMethodCtor():
            return _jac_make_host_trampoline(value);

        case PyPropertyCtor():
            return _jac_make_host_trampoline(value);

        case PyNativeNew():
            # object.__new__ / tuple.__new__ crossing to the host (namedtuple binds
            # `_tuple_new = tuple.__new__`) becomes the real host builtin __new__.
            return _jac_builtin_new_slot(value.base_name);

        case PyClassMethod():
            # A native classmethod handed to host type()/a host class becomes a
            # real host classmethod over the wrapped function's trampoline, so
            # `Cls.cmeth(...)` dispatched by the host binds the class correctly.
            return _jac_wrap_classmethod(to_host(value.func));

        case PyStaticMethod():
            return _jac_wrap_staticmethod(to_host(value.func));

        case PyProperty():
            fget = to_host(value.fget as PyObj) if value.fget is not None else None;
            fset = to_host(value.fset as PyObj) if value.fset is not None else None;
            fdel = to_host(value.fdel as PyObj) if value.fdel is not None else None;
            return _jac_wrap_property(fget, fset, fdel);

        case PyMappingProxy():
            # Host mappingproxy over a converted copy of the wrapped dict:
            # read-only view semantics survive the boundary.
            return _jac_wrap_mappingproxy(to_host(value.target));

        case PyTStrInterpolation():
            # Host templatelib requires str for format_spec; the guest default
            # is None (CPython stores '' host-side, None surfaces via
            # Interpolation only when unset -- normalize to empty string).
            fs = to_host(value.format_spec);
            if fs is None {
                fs = "";
            }
            cv = to_host(value.conversion);
            return _jac_wrap_tstr_interp(
                to_host(value.value), value.expression, cv, fs
            );

        case PyTStrTemplate():
            return _jac_wrap_tstr_template(
                to_host(value.strings), to_host(value.interpolations)
            );

        case PyIter():
            # LAZY_ITER: a lazy host iterator sharing position with the guest
            # object -- no silent draining, and partial host consumption leaves
            # the remaining items for the guest (CPython iterator semantics).
            # One arm per iterator kind: seqiter/rangeiter/dictiter/calliter
            # are distinct obj types, and grouped labels would drop them all
            # but the last (see note at PyNativeBuiltin).
            return _jac_make_host_iterator(value);

        case PySeqIter():
            return _jac_make_host_iterator(value);

        case PyRangeIter():
            return _jac_make_host_iterator(value);

        case PyDictIter():
            return _jac_make_host_iterator(value);

        case PyCallableIter():
            return _jac_make_host_iterator(value);

        case PyClass():
            # STANDIN for the guest class object itself: a cached name-faithful
            # host class whose back-reference recovers the original on
            # round-trip (json/type()/isinstance machinery see a real type).
            return _jac_standin_class(value);

        case PyHostProxy():
            return value.val;

        case PyException():
            # A caught exception crossing to the host (str(e)/repr(e)/type(e), or
            # handed to host logging/warnings) becomes a REAL host exception
            # instance carrying the same args -- previously this fell through to
            # None, so str(e) was "None" and type(e) was NoneType.
            return host_exception(value);

        case PyClass():
            # STANDIN: the guest class itself crossing to the host gets its
            # cached name-faithful stand-in (same "class" policy-table entry
            # as instances; from_host recovers the original via
            # _jac_guest_cls_, so identity round-trips).
            return _jac_standin_class(value);

        case PyUserObj():
            # A builtin subclass reaching the host boundary (len/print/format)
            # presents as its boxed value; an exception-derived user instance
            # presents as a REAL host BaseException carrying its args -- so
            # str(e)/print(e) match CPython instead of degrading to None. Any
            # other plain user object gets a NAME-FAITHFUL cached host stand-in
            # whose back-reference recovers the original on round-trip.
            if value._has_base() {
                if (value as PyUserObj).cls.host_base is not None {
                    # Host-C-type subclass: adopt the boxed base AS the
                    # stand-in so live C state and guest overrides both
                    # survive the crossing (host reader callbacks must see
                    # the override, never a bare base).
                    return _jac_user_standin_typed(value as PyUserObj);
                }
                return to_host(value._base_obj());
            }
            if class_is_exception(value.cls) {
                return host_exception(user_exception_view(value));
            }
            return _jac_user_standin(value);

        case PyGenerator():
            if value.t == "coroutine" {
                # A guest coroutine crossing to the host becomes a REAL host
                # awaitable (send/throw/close/__await__, asyncio.iscoroutine
                # true) that marshals each drive into frame resumption -- never
                # drained: a coroutine is consumed by its own driver.
                return _jac_make_guest_coroutine(value);
            }
            if value.t == "async_generator" {
                return _jac_make_guest_async_generator(value);
            }
            # LAZY_ITER: a plain generator/genexpr crossing to the host is
            # driven ONE step per host __next__ through the real suspend/resume
            # machinery -- laziness preserved, no silent drain, shared
            # consumption position (islice-then-next keeps working).
            return _jac_make_host_iterator(value);


        case PyGlobalsProxy():
            # globals() crossing to host-delegated code stays LIVE: a snapshot
            # would silently drop host-side writes and guest-side visibility
            # (CPython passes the real module dict). See _jac_make_live_ns_view.
            return _jac_make_live_ns_view(value);

        case PyDictView():
            # Rebuild a real host dict and hand back the matching live view, so
            # both iteration (list()/sorted()/set()) AND repr round-trip: repr of
            # the result is `dict_keys([...])`/`dict_values([...])`/`dict_items([
            # ...])`, not a bare list. Order follows the dict's insertion order.
            hd: dict[any, any] = {};
            for hk in value.d.items {
                `entry = value.d.items[hk];
                hd[to_host(`entry.key)] = to_host(`entry.value);
            }
            if value.mode == "values" {
                return hd.values();
            }
            if value.mode == "items" {
                return hd.items();
            }
            return hd.keys();

        case PyNotImplementedSentinel():
            return _jac_notimpl_value();

    }
    # Unreachable for every tag with a table policy and a matching arm above;
    # both gaps fail LOUDLY here instead of degrading to None -- except the
    # TRAMPOLINE family's long tail: native module functions are dozens of
    # small wrapper objs tagged t="function"/"native_builtin" (PyWarningsWarnFn
    # & co) that no per-class case above can enumerate. Their policy already
    # declares the crossing semantics, so mint the same tp_call-backing
    # trampoline the dedicated arms use. Non-callable stragglers surface their
    # PyError at INVOCATION time (trampoline re-raises), not at crossing time.
    if policy == BridgePolicy.TRAMPOLINE {
        return _jac_make_host_trampoline(value);
    }
    raise RuntimeError(
        "bridge-table: type '"
        + value.t
        + "' has policy "
        + str(policy)
        + " but no to_host conversion arm"
    );
}

# Guest->host ARGUMENT channel (py_call_host, host binops, constructors, ...):
# a FAIL-policy operand surfaces as a guest-visible TypeError -- CPython also
# raises TypeError for unrepresentable arguments -- instead of unwinding the
# VM. Returns the host value, or a PyError the caller must propagate.
def to_host_coerce(value: PyObj) -> tuple[bool, any] {
    try {
        return (True, to_host(value));
    } except RuntimeError as e {
        return (False, py_error("TypeError", str(e)));
    }
}

# Host-boundary error conversion: the host shims report failures as
# (False, type_name, message[, live_exception]). When the live instance is
# present, keep it in `raw` with its full args tuple and host-computed str so a
# caught exception exposes real fields (e.errno, e.filename, ...) and byte-exact
# __str__ -- identical to how py_raise_value treats raised host exceptions.
def host_result_error(result: any) -> PyObj {
    if len(result) > 3 and result[3] is not None {
        inst = _jac_host_exception_instance(result[3]);
        if bool(inst[0]) {
            return PyError(
                t="error",
                exception=PyException(
                    t="exception",
                    type_name=str(result[1]),
                    message=str(inst[2]),
                    args=inst[3],
                    raw=PyHostProxy(t="host", val=result[3]),
                ),
            );
        }
    }
    return py_error(str(result[1]), str(result[2]));
}

def host_builtin(name: str) -> PyObj {
    # Identity memo: native builtins are singletons (CPython's builtin tables
    # hold one object per name). Minting a fresh wrapper per lookup breaks
    # identity idioms -- {property: 1}[property], `len is len`, etc.
    if name in native_builtin_cache {
        return native_builtin_cache[name] as PyObj;
    }
    built = _mint_host_builtin(name);
    if not is_error(built) {
        native_builtin_cache[name] = built;
    }
    return built;
}

glob native_builtin_cache: dict[str, PyObj] = {};

def _mint_host_builtin(name: str) -> PyObj {
    # The FULL builtin exception tree resolves to native PyExceptionType
    # markers: construction then runs the typed constructors (OSError
    # errno/strerror/filename forms, ImportError name/path, SyntaxError info,
    # Unicode*Error fields) with attributes served from type_fields, instead of
    # collapsing through a lossy host-proxy round-trip. Host-RAISED errors
    # still arrive with their live instance in `raw` (byte-exact str via the
    # boundary), and except-matching/isinstance/issubclass work across both
    # shapes through the shared name hierarchy.
    if is_builtin_exception_name(name) {
        return py_exception_type(name);
    }
    # next()/iter() are handled natively so a native generator or iterator is
    # driven one step in-VM instead of being drained across the host boundary.
    # sorted()/max()/min() are native so key=/reverse=/default= reach VM
    # callables: routed through the host, a key function (a PyFunction) cannot
    # cross the substrate boundary and was silently dropped.
    # id() is native so it reports stable object identity (consistent with `is`)
    # rather than the host id of a throwaway to_host value. len() reads a native
    # container's own size (and dispatches __len__) instead of counting a
    # to_host copy, which drops plain user objects held as members/keys.
    # getattr/setattr/hasattr must be native: they route through py_attr so a
    # native object's own attributes (a PyFunction's __module__, a PyModule's
    # members, a user class's descriptors) are seen, instead of host getattr on
    # a lossy to_host copy. This is load-bearing for the import closure, where
    # decorators (functools.wraps, reprlib.recursive_repr) copy dunders via
    # getattr(fn, '__module__').
    # dir() is native so it enumerates the NATIVE object surface (a PyUserObj's
    # class chain / a PyModule's namespace) instead of host dir() on a lossy
    # to_host copy -- and the no-arg form reads the CALLING frame's locals,
    # which only the ceval call site can see.
    # exec() is native so the namespace dicts stay LIVE: routed through the
    # host, they cross by copy and every top-level binding the executed code
    # makes (def/class/assignment) is lost before control returns.
    if name == "exec"
        or name == "next"
        or name == "iter"
        or name == "id"
        or name == "len"
        or name == "repr"
        or name == "hash"
        or name == "callable"
        or name == "isinstance"
        or name == "issubclass"
        or name == "getattr"
        or name == "setattr"
        or name == "hasattr"
        or name == "delattr"
        or name == "globals"
        or name == "sorted"
        or name == "max"
        or name == "min"
        or name == "dir"
        or name == "vars"
        or name == "anext"
        or name == "aiter" {
        # globals() must be native: it returns a LIVE view of the running frame's
        # module namespace, so `globals().update({...})` / `globals()[k] = v`
        # (module init idioms, e.g. re._constants) bind real module globals that a
        # later LOAD_GLOBAL can see. The call site in run_frame supplies the ns.
        return PyNativeBuiltin(t="native_builtin", name=name);
    }
    # classmethod/staticmethod/property are native descriptors so a method decorated
    # with them is resolved in-VM (bound to the class, unwrapped, or invoked as a
    # getter) instead of being frozen into an uncallable host wrapper. Pervasive in
    # enum/abc/typing/dataclasses.
    if name == "classmethod" {
        return PyClassMethodCtor(t="classmethod_ctor");
    }
    if name == "staticmethod" {
        return PyStaticMethodCtor(t="staticmethod_ctor");
    }
    if name == "property" {
        return PyPropertyCtor(t="property_ctor");
    }
    # type() must stay native: a host-routed bare type(name, bases, ns) mints
    # standin classes and loses guest identity (enum's _simple_enum path).
    if name == "type" {
        return PyNativeBuiltin(t="native_builtin", name="type");
    }
    result = _jac_host_builtin(name);
    if host_result_ok(result) {
        return PyHostProxy(t="host", val=result[1]);
    }
    return host_result_error(result);
}

def host_import(name: str, fromlist: PyObj) -> PyObj {
    if name == "errno" and not ("errno" in shim_modules) {
        # Mirror of the import_native site: errnomodule.c is pure data, so the
        # native facade serves it without a host round-trip.
        shim_modules["errno"] = PyModule(
            t="module", name="errno", attrs=errno_module_attrs()
        );
    }
    if name == "weakref" and not ("weakref" in shim_modules) {
        # The host module's ref() sees to_host conversions (plain objects ->
        # None), so serve our identity-faithful shim instead.
        shim_modules["weakref"] = build_weakref_module();
    }
    if name == "heapq" and not ("heapq" in shim_modules) {
        # Same copy-mutation hazard as import_native: host heapq mutates a
        # copy of any guest list argument.
        shim_modules["heapq"] = build_heapq_module();
    }
    if name == "gc" and not ("gc" in shim_modules) {
        # Same rationale as the import_native site above: host gc cannot see
        # native guest objects.
        shim_modules["gc"] = PyModule(t="module", name="gc", attrs=gc_module_attrs());
    }
    if name == "signal" and not ("signal" in shim_modules) {
        # Mirror of the import_native site: same constant/dispatch overlay.
        sigmod = build_signal_facade();
        if not is_error(sigmod) {
            shim_modules["signal"] = sigmod;
        }
    }
    if name == "types" and not ("types" in shim_modules) {
        # The host types.coroutine cannot mark VM-native functions (it mutates
        # host code objects our PyFunction does not share), so its fallback
        # wrapper hands GET_AWAITABLE plain generators -- which must be
        # rejected. Serve a facade over the real module with the fast-path
        # semantics implemented natively. The layer3 boot path instead runs
        # the real types.py in-VM and overrides just the coroutine attribute.
        shim_modules["types"] = build_types_facade();
    }
    if name == "_sysconfig" and not ("_sysconfig" in shim_modules) {
        # Mirror of the import_native site: the host _sysconfig describes the
        # HOST build, never ours.
        shim_modules["_sysconfig"] = PyModule(
            t="module", name="_sysconfig", attrs=sysconfig_module_attrs()
        );
    }
    if name == "sys" and not ("sys" in shim_modules) {
        # Mirror of the import_native site: exception-state attrs must read
        # GUEST state.
        sysmod = delegated_module("sys");
        if not is_error(sysmod) {
            install_sys_guest_overrides(sysmod);
            shim_modules["sys"] = sysmod;
        }
    }
    if name == "traceback" and not ("traceback" in shim_modules) {
        # Same rationale as the import_native site above: host traceback APIs
        # cannot accept native PyTraceback across the bridge.
        tbmod = PyModule(t="module", name="traceback", attrs=traceback_module_attrs());
        (tbmod as PyModule).attrs["format_exc"] = PyNativeBuiltin(
            t="native_builtin", name="tb_format_exc"
        );
        (tbmod as PyModule).attrs["print_exc"] = PyNativeBuiltin(
            t="native_builtin", name="tb_print_exc"
        );
        (tbmod as PyModule).attrs["print_exception"] = PyNativeBuiltin(
            t="native_builtin", name="tb_print_exc_legacy"
        );
        # Shim type markers: make exposed classes isinstance-matchable
        # (ratified exception/tb-surface scope; hot-path guard lives in
        # py_isinstance keyed on one t compare).
        tagmap = _tb_shim_type_tags();
        for tname in tagmap {
            raw_ctor = (tbmod as PyModule).attrs[tname];
            (tbmod as PyModule).attrs[tname] = ShimTypeMarker(
                t="shim_type_marker",
                tag=(tagmap[tname] as PyStr).val,
                ctor=raw_ctor,
            );
        }
        shim_modules["traceback"] = tbmod;
    }
    if name == "_abc" and not ("_abc" in shim_modules) {
        # Mirror of the import_native site: guest abc boot needs native
        # subclasscheck over PyClass MROs, not host C _abc on standins.
        shim_modules["_abc"] = PyModule(
            t="module", name="_abc", attrs=abc_module_attrs()
        );
    }
    if name in shim_modules {
        return shim_modules[name];
    }
    if name in delegate_modules {
        return delegated_module(name);
    }
    result = _jac_host_import(name, to_host(fromlist));
    if host_result_ok(result) {
        return PyHostProxy(t="host", val=result[1]);
    }
    return host_result_error(result);
}

# LOAD_GLOBAL/LOAD_NAME fallthrough after locals/globals: builtins resolve
# here. A miss must surface as CPython's NameError, not the AttributeError the
# host getattr inside _jac_host_builtin would raise.
def load_name_fallback(name: str) -> PyObj {
    value = host_builtin(name);
    if is_error(value) {
        return py_error("NameError", "name '" + name + "' is not defined");
    }
    return value;
}

# type(obj): the object's type. A native user instance answers with its own
# PyClass; a class answers with its metaclass (or the host `type` for the default);
# everything else (scalars, proxied host values) round-trips through host type().
def py_type_of(o: PyObj) -> PyObj {
    if isinstance(o, PyUserObj) {
        return (o as PyUserObj).cls as PyObj;
    }
    if isinstance(o, PyClass) {
        m = (o as PyClass).metaclass;
        if m is not None and isinstance(m, PyClass) {
            return m as PyObj;
        }
        return host_builtin("type");
    }
    # CANONICAL exception type identity: type(ValueError("x")) must BE the
    # ValueError marker guests compare against (sys.exc_info()[0] is ValueError,
    # identity-keyed dispatch tables). The to_host fallthrough below would mint
    # a fresh host-type proxy -- right __name__, wrong identity.
    if isinstance(o, PyException) {
        e = o as PyException;
        if e.raw is not None and isinstance(e.raw, PyUserObj) {
            return (e.raw as PyUserObj).cls as PyObj;
        }
        t = host_builtin(e.type_name);
        if not is_error(t) {
            return t;
        }
        # Synthetic (shim-raised) exception names (unittest.SkipTest et al)
        # are not builtins: serve the canonical exception-type marker instead
        # of crashing type()/__name__ lookups on a faithfully raised error.
        return py_exception_type(e.type_name);
    }
    # Native callable wrappers have no faithful host object (to_host drops
    # them), so answer with the matching HOST callable type instead of NoneType
    # via the to_host fallthrough. CPython distinguishes builtin_function_or_
    # method (builtins/bound builtins), method (bound user functions), and the
    # concrete iterator types.
    if isinstance(o, PyNativeBuiltin) or isinstance(o, PyListMethod)
        or isinstance(o, PyDictMethod) or isinstance(o, PySetMethod)
        or isinstance(o, PyStrMethod) {
        return from_host(_jac_builtin_function_or_method_type());
    }
    if isinstance(o, PyBoundMethod) or isinstance(o, PyGenMethod) {
        return from_host(_jac_bound_method_type());
    }
    if isinstance(o, PyIter) {
        return from_host(_jac_list_iterator_type());
    }
    if isinstance(o, PySeqIter) {
        # CPython: iter() over a __getitem__-only object is the plain
        # `iterator` type (PySeqIter_Type), not list_iterator.
        return from_host(_jac_seq_iterator_type());
    }
    if isinstance(o, PyGenerator) {
        # The three suspendable frame wrappers map to their real host types;
        # the to_host fallthrough would DRAIN them into a list ("list").
        gen = o as PyGenerator;
        if gen.t == "coroutine" {
            return from_host(_jac_coroutine_type());
        }
        if gen.t == "async_generator" {
            return from_host(_jac_async_generator_type());
        }
        return from_host(_jac_generator_type());
    }
    ho_r = to_host_coerce(o);
    ho = ho_r[1];
    if not ((ho_r[0] as bool)) {
        # A FAIL-tag operand has no host type answer at all (VM-internal tag);
        # degrade to `object` rather than the old lie of NoneType. Unreachable
        # for every tag guests can hold as a first-class value.
        return from_host(_jac_host_type(object()));
    }
    return from_host(_jac_host_type(ho));
}

# Build a real host exception instance from a native PyException, so the host's
# own str()/repr()/type()/isinstance machinery drives it. Uses the recorded args
# (falling back to `message` for VM-raised errors, which carry no args tuple). A
# non-builtin type_name (a user Exception subclass) can't be reconstructed as a
# host type, so it degrades to a plain Exception carrying the message -- enough
# for str()/repr(); `except <UserClass>` matching stays native (exception_matches
# uses the raw PyUserObj's MRO, never this host form).
def host_exception(exc: PyException) -> any {
    # An exception VIEW backed by an actual host instance (a host error that
    # crossed into the VM and is now crossing back out) presents the ORIGINAL
    # object -- identity/args/chaining/traceback all stay intact.
    if exc.raw is not None and isinstance(exc.raw, PyHostProxy) {
        return exc.raw.val;
    }
    raw_args: list[any] = [];
    for a in exc.args {
        raw_args.append(to_host(a));
    }
    if len(raw_args) == 0 and exc.message != "" {
        raw_args.append(exc.message);
    }
    built = _jac_construct_builtin(exc.type_name, raw_args);
    if bool(built[0]) {
        return built[1];
    }
    # Registry-aware materialization: registered module exceptions mint a
    # cached host subclass of their DECLARED BASE; user exception names mint a
    # cached same-name Exception subclass. A name that survives neither the
    # builtin lookup nor minting FAILS LOUDLY -- the boundary never degrades a
    # caught exception to a generic Exception() (which erased its hierarchy).
    maker_result = _jac_instantiate_registered_exception(exc.type_name, raw_args);
    if bool(maker_result[0]) {
        return maker_result[1];
    }
    raise RuntimeError(
        "bridge-table: no host exception type for '" + exc.type_name + "'"
    );
}

# f-string / format() machinery. The __format__ / __str__ protocols resolve
# NATIVELY for user instances (to_host of a plain user object is None -- the
# host bridge would answer on a lost value); everything else stays delegated
# to host CPython's format()/repr()/ascii(), which keeps objects.jac na-clean.
def host_format(value: PyObj, spec: str) -> PyObj {
    if isinstance(value, PyUserObj) {
        u = value as PyUserObj;
        # An explicit __format__ receives the raw spec (empty included) and its
        # result must be str; a raised exception propagates verbatim.
        if user_has_dunder(u, "__format__") {
            res = call_user_dunder(u, "__format__", [PyStr(t="str", val=spec)]);
            if is_error(res) {
                return res;
            }
            if isinstance(res, PyStr) {
                return res;
            }
            return py_error(
                "TypeError",
                "__format__ must return a str, not " + _slot_result_type_name(res),
            );
        }
        # object.__format__: empty spec delegates exactly like str(); a non-
        # empty spec is CPython's TypeError verbatim.
        if spec != "" {
            return py_error(
                "TypeError",
                "unsupported format string passed to " + u.cls.name + ".__format__",
            );
        }
        return py_str(value);
    }
    hv_r = to_host_coerce(value);
    hv = hv_r[1];
    if not ((hv_r[0] as bool)) {
        return hv_r[1] as PyObj;
    }
    result = _jac_host_format(hv, spec);
    if host_result_ok(result) {
        return from_host(result[1]);
    }
    return host_result_error(result);
}

def host_convert(value: PyObj, conv: int) -> PyObj {
    # str()/repr() over a native user instance answer in-VM (see host_format);
    # ascii() keeps the host path (its non-ASCII escaping is not ported).
    if isinstance(value, PyUserObj) {
        if conv == 1 {
            return py_str(value);
        }
        if conv == 2 {
            return py_repr(value);
        }
    }
    # A member descriptor converts to its repr form on BOTH str() and repr()
    # (host: str(C.__dict__['x']) == repr(C.__dict__['x'])).
    if isinstance(value, PyMemberDescr) {
        return py_repr(value);
    }
    hv_r = to_host_coerce(value);
    if not ((hv_r[0] as bool)) {
        return hv_r[1] as PyObj;
    }
    result = _jac_host_convert(hv_r[1], conv);
    if host_result_ok(result) {
        return from_host(result[1]);
    }
    return host_result_error(result);
}

def host_getattr(value: PyObj, name: str) -> PyObj {
    hv_r = to_host_coerce(value);
    hv = hv_r[1];
    if not ((hv_r[0] as bool)) {
        return hv_r[1] as PyObj;
    }
    result = _jac_host_getattr(hv, name);
    if host_result_ok(result) {
        return from_host(result[1]);
    }
    return host_result_error(result);
}

def host_getitem(value: PyObj, index: PyObj) -> PyObj {
    hv_r = to_host_coerce(value);
    hv = hv_r[1];
    if not ((hv_r[0] as bool)) {
        return hv_r[1] as PyObj;
    }
    hi_r = to_host_coerce(index);
    hi = hi_r[1];
    if not ((hi_r[0] as bool)) {
        return hi_r[1] as PyObj;
    }
    result = _jac_host_getitem(hv, hi);
    if host_result_ok(result) {
        return from_host(result[1]);
    }
    return host_result_error(result);
}

def host_setattr(value: PyObj, name: str, field: PyObj) -> PyObj {
    hv_r = to_host_coerce(value);
    hv = hv_r[1];
    if not ((hv_r[0] as bool)) {
        return hv_r[1] as PyObj;
    }
    hf_r = to_host_coerce(field);
    hf = hf_r[1];
    if not ((hf_r[0] as bool)) {
        return hf_r[1] as PyObj;
    }
    result = _jac_host_setattr(hv, name, hf);
    if host_result_ok(result) {
        return py_none();
    }
    return host_result_error(result);
}


# ---------------- ceval ----------------
# Opcode numbers and cache metadata: opcode_meta.jac (PLAN.md P0.1).

# ---------------- implicit type-slot machinery ------------------------------
# CPython fills each type's slots (tp_bool/sq_contains/nb_int/nb_float/tp_hash)
# from dunder presence when the heap type is created. jacpython's heap types
# (PyClass/PyUserObj) have no frozen vtable to patch: the same protocols resolve
# through MRO dunder lookup AT DISPATCH, funneled through the helpers below so
# every entry point -- branch truthiness, bool(), `in`, hash()/dict-keying,
# int()/float() -- shares one set of semantics.

# Truthiness slot (nb_bool + sq_length; CPython PyObject_IsTrue): __bool__,
# then __len__, then a boxed builtin base's own truthiness, then True.
def py_slot_truth(value: PyObj) -> PyObj {
    if isinstance(value, PyUserObj) {
        u = value as PyUserObj;
        if user_has_dunder(u, "__bool__") {
            res = call_user_dunder(u, "__bool__", []);
            if is_error(res) {
                return res;
            }
            if isinstance(res, PyBool) {
                return res;
            }
            return py_error("TypeError", "__bool__ should return bool");
        }
        if user_has_dunder(u, "__len__") {
            ln = py_len(value);
            if is_error(ln) {
                return ln;
            }
            return PyBool(t="bool", val=(ln as PyInt).val != 0);
        }
        if u._has_base() {
            return py_slot_truth(u._base_obj());
        }
        return PyBool(t="bool", val=True);
    }
    # A read-only mapping view is truthy iff its dict is (len-based).
    if isinstance(value, PyMappingProxy) {
        ln = py_len((value as PyMappingProxy).target as PyObj);
        if is_error(ln) {
            return ln;
        }
        return PyBool(t="bool", val=(ln as PyInt).val != 0);
    }
    return PyBool(t="bool", val=value.tp_bool());
}

# True iff the boxed builtin base supplies its own number slot that a heap
# subclass inherits wholesale (CPython typeobject.c inherit_special copies
# tp_as_number; update_one_slot resolves __int__/__float__ wrappers from the
# base's tp_dict): int/bool carry long's slots, float carries its own. Such an
# inherited slot PREEMPTS a user-defined __index__ -- PyNumber_Long/
# PyNumber_Float consult nb_index only when nb_int/nb_float is absent -- while
# non-number bases (str/list/dict, ...) do not.
def boxed_number_base(u: PyUserObj) -> bool {
    if not u._has_base() {
        return False;
    }
    b = u._base_obj();
    return isinstance(b, PyInt) or isinstance(b, PyBool) or isinstance(b, PyFloat);
}

# int(x) conversion slot (nb_int over dunders): __int__ first, then an
# inherited builtin number slot, then the index slot; nothing applicable is
# CPython's TypeError.
def py_convert_int(x: PyObj) -> PyObj {
    if isinstance(x, PyUserObj) {
        u = x as PyUserObj;
        # CPython abstract.c PyNumber_Long: once nb_int exists its result and
        # its exceptions are final -- __index__ is tried only when nb_int is
        # absent entirely.
        if user_has_dunder(u, "__int__") {
            res = call_user_dunder(u, "__int__", []);
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
                "TypeError", "__int__ returned non-int (type " + res.t + ")"
            );
        }
        # A builtin number base's own slot is inherited by the subclass.
        if boxed_number_base(u) {
            return py_convert_int(u._base_obj());
        }
        # No nb_int anywhere in the hierarchy: nb_index next; its exceptions
        # and non-int reports propagate verbatim (PyNumber_Index).
        if user_has_dunder(u, "__index__") {
            return (u as PyObj).to_index();
        }
        # Remaining bases convert on their own terms (str/bytes parsing, ...);
        # none applicable is CPython's final TypeError.
        if u._has_base() {
            return py_convert_int(u._base_obj());
        }
        return py_error(
            "TypeError",
            "int() argument must be a string, a bytes-like object or a real number, not '"
                + u.cls.name + "'",
        );
    }
    return py_host_convert("int", x);
}

# float(x) conversion slot (nb_float over dunders): __float__ first, then an
# inherited builtin number slot, then the index slot; nothing applicable is
# CPython's TypeError.
# Native complex() constructor over native operands (PyHostProxy.tp_call
# interception). PY_NOT_IMPLEMENTED marks shapes with no native answer --
# bytes, kwargs, user/host objects, the both-imag-parts deprecation combo --
# so the caller falls through to the host call and keeps CPython's exact
# behavior including its TypeErrors.
def _complex_arg_parts(x: PyObj) -> tuple[bool, float, float] {
    if isinstance(x, PyComplex) {
        c = x as PyComplex;
        return (True, c.real, c.imag);
    }
    if isinstance(x, PyFloat) {
        return (True, (x as PyFloat).val, 0.0);
    }
    if isinstance(x, PyInt) {
        return (True, float((x as PyInt).val), 0.0);
    }
    if isinstance(x, PyBool) {
        if (x as PyBool).val {
            return (True, 1.0, 0.0);
        }
        return (True, 0.0, 0.0);
    }
    return (False, 0.0, 0.0);
}

def py_convert_complex(args: list[PyObj]) -> PyObj {
    n = len(args);
    if n > 2 {
        return py_error(
            "TypeError",
            "complex() takes at most 2 arguments (" + str(n) + " given)",
        );
    }
    if n == 0 {
        return PyComplex(t="complex", real=0.0, imag=0.0);
    }
    a = args[0];
    if isinstance(a, PyStr) {
        if n == 2 {
            return py_error(
                "TypeError", "complex() argument 'real' must be a real number, not str"
            );
        }
        (ok, err, re, im) = complex_parse_text((a as PyStr).val);
        if not ok {
            return py_error("ValueError", err);
        }
        return PyComplex(t="complex", real=re, imag=im);
    }
    (ok1, r1, i1) = _complex_arg_parts(a);
    if not ok1 {
        return PY_NOT_IMPLEMENTED;
    }
    if n == 1 {
        # A complex argument is copied whole; reals get a FRESH +0 imaginary
        # (complex(-0.0) == -0+0j -- the sign does NOT propagate).
        if isinstance(a, PyComplex) {
            c = a as PyComplex;
            return PyComplex(t="complex", real=c.real, imag=c.imag);
        }
        return PyComplex(t="complex", real=r1, imag=0.0);
    }
    (ok2, r2, i2) = _complex_arg_parts(args[1]);
    if not ok2 {
        return PY_NOT_IMPLEMENTED;
    }
    # Two-arg forms preserve signed zeros exactly like CPython: real x real
    # copies both parts verbatim (complex(3, -0.0) == 3-0j), while a complex
    # first arg adds the second operand to its imaginary part
    # (complex(1+2j, 3) == 1+5j). Two imaginary parts are the deprecated
    # combo and stay host-routed.
    if i1 != 0.0 and i2 != 0.0 {
        return PY_NOT_IMPLEMENTED;
    }
    if isinstance(a, PyComplex) {
        return PyComplex(t="complex", real=r1, imag=i1 + r2);
    }
    return PyComplex(t="complex", real=r1, imag=r2);
}

def py_convert_float(x: PyObj) -> PyObj {
    if isinstance(x, PyUserObj) {
        u = x as PyUserObj;
        # CPython abstract.c PyNumber_Float: once nb_float exists its result and
        # exceptions are final -- nb_index is tried only when nb_float is
        # absent entirely.
        if user_has_dunder(u, "__float__") {
            res = call_user_dunder(u, "__float__", []);
            if is_error(res) {
                return res;
            }
            if isinstance(res, PyFloat) {
                return res;
            }
            return py_error(
                "TypeError",
                u.cls.name + ".__float__ returned non-float (type " + res.t + ")"
            );
        }
        # A builtin number base's own slot is inherited by the subclass.
        if boxed_number_base(u) {
            return py_convert_float(u._base_obj());
        }
        # No nb_float anywhere in the hierarchy: nb_index next; its exceptions
        # and non-int reports propagate verbatim (PyNumber_Index).
        if user_has_dunder(u, "__index__") {
            idx = (u as PyObj).to_index();
            if is_error(idx) {
                return idx;
            }
            return PyFloat(t="float", val=float((idx as PyInt).val));
        }
        # Remaining bases convert on their own terms (str parsing, ...); none
        # applicable is CPython's final TypeError (PyNumber_Float falls back to
        # PyFloat_FromString, which the host constructor path reproduces).
        if u._has_base() {
            return py_convert_float(u._base_obj());
        }
        return py_error(
            "TypeError",
            "float() argument must be a string or a real number, not '"
                + u.cls.name + "'",
        );
    }
    # Plain int: guard the host conversion so oversized ints raise the
    # guest-exact OverflowError instead of an escaping host error.
    if isinstance(x, PyInt) {
        try {
            return PyFloat(t="float", val=float((x as PyInt).val));
        } except OverflowError {
            return py_error("OverflowError", "int too large to convert to float");
        }
    }
    return py_host_convert("float", x);
}

# The host constructor of `name` over a value with no native slot answer
# (str/bytes parsing, float truncation, opaque proxies). Exact legacy behavior.
def py_host_convert(name: str, x: PyObj) -> PyObj {
    result = _jac_host_builtin(name);
    if host_result_ok(result) {
        fn = PyHostProxy(t="host", val=result[1]);
        return fn.tp_call([x], {});
    }
    return host_result_error(result);
}

# A key/value that is NOT a builtin (a user object or a host proxy) can carry a
# custom __eq__, so the hashkey-bucket match must be confirmed with a real
# comparison. Between two builtins the hashkey protocol already IS value equality
# (numeric collapse included), so the confirming eq is skipped -- the fast path.
def _needs_eq_confirm(o: PyObj) -> bool {
    return isinstance(o, PyUserObj) or isinstance(o, PyHostProxy);
}

# CPython tuple_repr: trailing comma for length-1 tuples.
def tuple_repr(v: PyTuple) -> PyObj {
    if len(v.items) == 0 {
        return PyStr(t="str", val="()");
    }
    out = "(";
    i = 0;
    while i < len(v.items) {
        if i > 0 {
            out = out + ", ";
        }
        piece = py_repr(v.items[i]);
        if is_error(piece) {
            return piece;
        }
        out = out + (piece as PyStr).val;
        i = i + 1;
    }
    if len(v.items) == 1 {
        out = out + ",";
    }
    return PyStr(t="str", val=out + ")");
}

# ---------------- tp_str/tp_repr/tp_format slots -----------------------------
# Same implicit-slot convention as py_slot_truth/py_convert_int: heap types
# have no frozen vtable, so __str__/__repr__/__format__ resolve through MRO
# dunder lookup AT DISPATCH (never instance getattribute), before any to_host
# bridging -- a plain user object marshals as None, so the host would answer
# 'None' or raise on a lost value.

# CPython type name of a slot RESULT for the __str__/__repr__ non-string TypeErrors.
def _slot_result_type_name(v: PyObj) -> str {
    if isinstance(v, PyUserObj) {
        return (v as PyUserObj).cls.name;
    }
    if isinstance(v, PyClass) {
        return (v as PyClass).name;
    }
    return _base_type_name(v);
}

# True iff a str-% argument carries a native user instance whose %s/%r piece
# needs slot dispatch (scalar-only args stay on the lifted fast path). One level
# of tuple/dict nesting is scanned; deeper nesting remains a residual.
def mod_args_need_user_slots(args: PyObj) -> bool {
    if isinstance(args, PyUserObj) {
        return True;
    }
    if isinstance(args, PyTuple) {
        for item in (args as PyTuple).items {
            if isinstance(item, PyUserObj) {
                return True;
            }
        }
        return False;
    }
    if isinstance(args, PyDict) {
        for hk in (args as PyDict).items {
            pair = (args as PyDict).items[hk];
            if isinstance(pair.value, PyUserObj) {
                return True;
            }
        }
    }
    return False;
}

# CPython object.__repr__: '<module.Class object at 0x..>' (bare class name when
# no __module__), address = lowercase hex of id(), byte-exact vs the host.
def default_obj_repr_text(u: PyUserObj) -> str {
    mod = "";
    if "__module__" in u.cls.attrs {
        m = u.cls.attrs["__module__"];
        if isinstance(m, PyStr) {
            mod = (m as PyStr).val;
        }
    }
    return "<" + type_tp_name(u.cls.name, mod) + " object at 0x"
        + _uint_to_str(py_id(u as PyObj), 16, "0123456789abcdef") + ">";
}

# The repr slot: explicit __repr__, then a boxed builtin base's own repr,
# then the default identity form.
def user_repr_slot(u: PyUserObj) -> PyObj {
    if user_has_dunder(u, "__repr__") {
        res = call_user_dunder(u, "__repr__", []);
        if is_error(res) {
            return res;
        }
        if isinstance(res, PyStr) {
            return res;
        }
        return py_error(
            "TypeError",
            "__repr__ returned non-string (type '" + _slot_result_type_name(res)
                + "')",
        );
    }
    # A builtin-exception ancestor contributes ITS repr slot even though
    # Exception is not a boxed-layout native base (native_base stays ""), so
    # route through the same view the raise path wraps raised instances in.
    # CPython heap subclasses of Exception inherit BaseException's tp_repr.
    if class_is_exception(u.cls) {
        return baseexception_repr(user_exception_view(u), py_repr);
    }
    if u._has_base() {
        return py_repr(u._base_obj());
    }
    return PyStr(t="str", val=default_obj_repr_text(u));
}

# The str slot: explicit __str__, else the type's repr slot (object.__str__ IS
# object.__repr__ in CPython, including the default identity form).
def user_str_slot(u: PyUserObj) -> PyObj {
    if user_has_dunder(u, "__str__") {
        res = call_user_dunder(u, "__str__", []);
        if is_error(res) {
            return res;
        }
        if isinstance(res, PyStr) {
            return res;
        }
        return py_error(
            "TypeError",
            "__str__ returned non-string (type '" + _slot_result_type_name(res)
                + "')",
        );
    }
    # A boxed builtin base contributes ITS str slot (str.__str__ returns the
    # value itself: str(SS('ab')) == 'ab', not repr); only object.__str__ -- the
    # no-base case -- collapses to the repr form above.
    if u._has_base() {
        return py_str(u._base_obj());
    }
    # Same inherited-slot rule for str: BaseException_str (+ the per-type forms
    # like KeyError repr-of-payload) applies pre-raise too.
    if class_is_exception(u.cls) {
        return baseexception_str(user_exception_view(u), py_repr, py_str);
    }
    return user_repr_slot(u);
}

# Native str(): exceptions read their args natively, user instances through the
# str slot; every other shape has a faithful host form and delegates so the
# bytes stay exact CPython.
def py_str(value: PyObj) -> PyObj {
    if isinstance(value, PyException) {
        exc = value as PyException;
        # Host-raised instance (raw is a PyHostProxy): byte-exact str straight
        # from the live object. A PyUserObj raw (guest user exception) keeps
        # the native dispatch below.
        if isinstance(exc.raw, PyHostProxy) {
            return host_convert(exc.raw as PyObj, 1);
        }
        # A raised guest user exception keeps its live instance in `raw`; an
        # explicit __str__ on the class overrides the inherited BaseException
        # slots (CPython MRO lookup), so dispatch through the user slot.
        if isinstance(exc.raw, PyUserObj)
            and user_has_dunder(exc.raw as PyUserObj, "__str__") {
            return user_str_slot(exc.raw as PyUserObj);
        }
        return baseexception_str(exc, py_repr, py_str);
    }
    if isinstance(value, PyUserObj) {
        return user_str_slot(value as PyUserObj);
    }
    # TypeVar has no __str__ of its own; object.__str__ falls back to tp_repr,
    # so str(T) == 'T' byte-exact. Same for the generic-alias stand-in and the
    # NoDefault sentinel.
    if isinstance(value, PyTypeVar)
        or isinstance(value, PyGenericAlias)
        or isinstance(value, PyNoDefault) {
        return py_repr(value);
    }
    if isinstance(value, PyComplex) {
        # CPython complex_str IS complex_repr (same paren rules as repr).
        return PyStr(t="str", val=complex_repr_text(value as PyComplex));
    }
    # A member descriptor's str is its repr (host: str(C.__dict__['x']) ==
    # "<member 'x' of 'C' objects>").
    if isinstance(value, PyMemberDescr) {
        return py_repr(value);
    }
    # Containers have no tp_str in CPython: str == repr, answered in-VM so
    # self-referential structures hit the repr cycle guards instead of
    # recursing unbounded inside to_host conversion.
    if isinstance(value, PyDict) or isinstance(value, PyList)
        or isinstance(value, PyTuple) or isinstance(value, PyMappingProxy) {
        return py_repr(value);
    }
    return host_convert(value, 1);
}

# Native repr(): scalars, containers, class + user __repr__ in-VM; remainder
# falls back to host_convert(..., 2).
def py_obj_is_type(value: PyObj) -> bool {
    if isinstance(value, PyClass) {
        return True;
    }
    if isinstance(value, PyHostProxy) {
        return bool(_jac_host_val_is_type((value as PyHostProxy).val));
    }
    return False;
}

def py_type_same(a: PyObj, b: PyObj) -> bool {
    if a is b {
        return True;
    }
    if isinstance(a, PyHostProxy) and isinstance(b, PyHostProxy) {
        return (a as PyHostProxy).val is (b as PyHostProxy).val;
    }
    return False;
}

def py_repr(value: PyObj) -> PyObj {
    if isinstance(value, PyException) {
        exc = value as PyException;
        # Same override rule as py_str: an explicit __repr__ on a raised guest
        # user exception's class beats the inherited BaseException repr slot.
        if isinstance(exc.raw, PyUserObj)
            and user_has_dunder(exc.raw as PyUserObj, "__repr__") {
            return user_repr_slot(exc.raw as PyUserObj);
        }
        return baseexception_repr(value as PyException, py_repr);
    }
    if isinstance(value, PyRange) {
        rg = value as PyRange;
        # CPython range_repr: ALWAYS two-arg when step==1 -- there is no
        # stop-only form (host oracle: repr(range(5)) == 'range(0, 5)').
        if rg.step == 1 {
            return PyStr(
                t="str",
                val="range(" + str(rg.start) + ", " + str(rg.stop) + ")",
            );
        }
        return PyStr(
            t="str",
            val="range("
                + str(rg.start)
                + ", "
                + str(rg.stop)
                + ", "
                + str(rg.step)
                + ")",
        );
    }
    # CPython TypeAliasType_repr prints the bare alias name (repr(type X = int
    # alias) == 'X'), never a qualified or angled form.
    if isinstance(value, PyTypeAlias) {
        return PyStr(t="str", val=(value as PyTypeAlias).name);
    }
    # CPython typevar_repr: infer-variance parameters print the bare name
    # (module 'typing', implicit PEP 695); explicit construction prefixes the
    # variance marker ('+' covariant / '-' contravariant / '~' invariant).
    if isinstance(value, PyTypeVar) {
        tv = value as PyTypeVar;
        if tv.infer_variance {
            return PyStr(t="str", val=tv.name);
        }
        marker = "~";
        if tv.covariant {
            marker = "+";
        }
        if tv.contravariant {
            marker = "-";
        }
        return PyStr(t="str", val=marker + tv.name);
    }
    # CPython _GenericAlias.__repr__ for the implicit generic base prints
    # 'typing.Generic[T, ...]'; str falls back to the same (no __str__).
    if isinstance(value, PyGenericAlias) {
        parts: list[str] = [];
        for gp in ((value as PyGenericAlias).params as PyTuple).items {
            r = py_repr(gp);
            if is_error(r) {
                return r;
            }
            parts.append((r as PyStr).val);
        }
        return PyStr(t="str", val="typing.Generic[" + ", ".join(parts) + "]");
    }
    # typing.NoDefault: repr and str are both 'typing.NoDefault'.
    if isinstance(value, PyNoDefault) {
        return PyStr(t="str", val="typing.NoDefault");
    }
    if isinstance(value, PyTuple) {
        return tuple_repr(value as PyTuple);
    }
    if isinstance(value, PyList) {
        return list_repr(value as PyList, py_repr);
    }
    if isinstance(value, PyBytes) {
        return bytes_repr(value as PyBytes);
    }
    if isinstance(value, PyDict) {
        return dict_repr(value as PyDict, py_repr);
    }
    if isinstance(value, PyMappingProxy) {
        inner = dict_repr((value as PyMappingProxy).target, py_repr);
        return PyStr(t="str", val="mappingproxy(" + str_value(inner) + ")");
    }
    if isinstance(value, PyClass) {
        c = value as PyClass;
        mod = "";
        if "__module__" in c.attrs {
            m = c.attrs["__module__"];
            if isinstance(m, PyStr) {
                mod = (m as PyStr).val;
            }
        } elif "__name__" in c.attrs {
            m = c.attrs["__name__"];
            if isinstance(m, PyStr) {
                mod = (m as PyStr).val;
            }
        }
        return type_repr(type_tp_name(c.name, mod));
    }
    if isinstance(value, PyMemberDescr) {
        m = value as PyMemberDescr;
        return PyStr(
            t="str", val=type_slots_member_repr(m.member, m.owner)
        );
    }
    if isinstance(value, PyStr) {
        return str_repr(value as PyStr);
    }
    if isinstance(value, PyInt) {
        return int_repr(value as PyInt);
    }
    if isinstance(value, PyFloat) {
        return float_repr(value as PyFloat);
    }
    if isinstance(value, PyComplex) {
        # CPython complex_str IS complex_repr; built in-VM for paren rules.
        return PyStr(t="str", val=complex_repr_text(value as PyComplex));
    }
    if isinstance(value, PyBool) or isinstance(value, PyNoneType) {
        return PyStr(t="str", val=_pyobj_repr(value));
    }
    if isinstance(value, PyUserObj) {
        return user_repr_slot(value as PyUserObj);
    }
    # Native bound-method/builtin wrappers have no faithful host form (to_host
    # drops them to None, which would repr as 'None'), so synthesize the
    # CPython-style repr minus the embedded address.
    if isinstance(value, PyListMethod) {
        return PyStr(t="str", val="<built-in method " + (value as PyListMethod).name + " of list object>");
    }
    if isinstance(value, PyStrMethod) {
        return PyStr(t="str", val="<built-in method " + (value as PyStrMethod).name + " of str object>");
    }
    if isinstance(value, PyDictMethod) {
        return PyStr(t="str", val="<built-in method " + (value as PyDictMethod).name + " of dict object>");
    }
    if isinstance(value, PySetMethod) {
        return PyStr(t="str", val="<built-in method " + (value as PySetMethod).name + " of set object>");
    }
    if isinstance(value, PyNativeBuiltin) {
        return PyStr(t="str", val="<built-in function " + (value as PyNativeBuiltin).name + ">");
    }
    if isinstance(value, PyIter) {
        # repr is observational: it must NOT route through to_host, whose drain
        # would exhaust the iterator as a side effect.
        return PyStr(t="str", val="<iterator object>");
    }
    result = host_convert(value, 2);
    if is_error(result) {
        return result;
    }
    return result;
}

def py_compare(kind: int, lhs: PyObj, rhs: PyObj) -> PyObj {
    if isinstance(lhs, PyUserObj) or isinstance(rhs, PyUserObj) {
        return user_compare(kind, lhs, rhs);
    }
    # A dict view on either side compares set-like (keys/items), invoking element
    # __eq__: {1:1}.keys() == {1}, and d1.items() == d2.items() propagating a raise.
    if isinstance(lhs, PyDictView) or isinstance(rhs, PyDictView) {
        return dictview_richcompare(kind, lhs, rhs);
    }
    # PEP 667 frame-locals proxies compare dict-like against dicts and by
    # identity against each other (Objects/frameobject.c).
    if isinstance(lhs, PyFrameLocalsProxy) or isinstance(rhs, PyFrameLocalsProxy) {
        return framelocals_richcompare(kind, lhs, rhs);
    }
    if isinstance(lhs, PyMappingProxy) {
        lhs = (lhs as PyMappingProxy).target;
    }
    if isinstance(rhs, PyMappingProxy) {
        rhs = (rhs as PyMappingProxy).target;
    }
    if isinstance(lhs, PyDict) and isinstance(rhs, PyDict) {
        return dict_richcompare(kind, lhs as PyDict, rhs as PyDict, py_compare);
    }
    if isinstance(lhs, PyList) and isinstance(rhs, PyList) {
        return list_richcompare(kind, lhs as PyList, rhs as PyList, py_compare);
    }
    if isinstance(lhs, PyTuple) and isinstance(rhs, PyTuple) {
        return tuple_richcompare(kind, lhs as PyTuple, rhs as PyTuple);
    }
    if isinstance(lhs, PyBytes) and isinstance(rhs, PyBytes) {
        return bytes_richcompare(kind, lhs as PyBytes, rhs as PyBytes);
    }
    # Native bytes vs a host-proxied bytes-like (bytearray): CPython makes
    # them mutually comparable; the generic fallthrough degrades to identity
    # for == and TypeError for ordering (item 27 bytearray half).
    if isinstance(lhs, PyBytes) != isinstance(rhs, PyBytes)
        and (isinstance(lhs, PyHostProxy) or isinstance(rhs, PyHostProxy)) {
        hl_r = to_host_coerce(lhs);
        hl = hl_r[1];
        if not ((hl_r[0] as bool)) {
            return hl_r[1] as PyObj;
        }
        hr_r = to_host_coerce(rhs);
        hr = hr_r[1];
        if not ((hr_r[0] as bool)) {
            return hr_r[1] as PyObj;
        }
        res = _jac_host_richcompare(kind, hl, hr);
        if not ((res[0] as bool)) {
            return host_result_error(res);
        }
        return PyBool(t="bool", val=res[1] as bool);
    }
    # Proxy-vs-proxy ORDERING (bytearray < bytearray, ...): tp_richcompare
    # handles only eq/ne (identity fast path + host eq defer), so ordering
    # would fall to NotImplemented -> TypeError where CPython compares the
    # host values. Unorderable host types surface the host TypeError verbatim.
    if (
        isinstance(lhs, PyHostProxy) and isinstance(rhs, PyHostProxy)
        and (kind == 0 or kind == 1 or kind == 4 or kind == 5)
    ) {
        res = _jac_host_richcompare(kind, lhs.val, rhs.val);
        if not ((res[0] as bool)) {
            return host_result_error(res);
        }
        return PyBool(t="bool", val=res[1] as bool);
    }
    if isinstance(lhs, PySet) and isinstance(rhs, PySet) {
        return set_richcompare(kind, lhs as PySet, rhs as PySet);
    }
    if py_obj_is_type(lhs) and py_obj_is_type(rhs) {
        return type_richcompare_same(kind, py_type_same(lhs, rhs));
    }
    return PyObject_RichCompare(lhs, rhs, kind);
}

# Native nb_binop covers the ported fast paths (int/str Gap #2 %-format, tuple/
# list concat, ...). Operand/format combos not yet ported (str % with %f/%i or
# multiple args, str * int, ...) fall back across the substrate to host CPython
# when both operands are host-backed. Purely additive: only a native error
# triggers the fallback, so ported semantics always win.
def host_binop(kind: int, lhs: PyObj, rhs: PyObj) -> PyObj {
    hl_r = to_host_coerce(lhs);
    hl = hl_r[1];
    if not ((hl_r[0] as bool)) {
        return hl_r[1] as PyObj;
    }
    hr_r = to_host_coerce(rhs);
    hr = hr_r[1];
    if not ((hr_r[0] as bool)) {
        return hr_r[1] as PyObj;
    }
    result = _jac_host_binop(kind, hl, hr);
    if host_result_ok(result) {
        return from_host(result[1]);
    }
    return host_result_error(result);
}

def _host_representable(t: str) -> bool {
    # Table query: a tag is host-representable iff the boundary table gives it
    # any policy other than FAIL. Native PySet/PyList/... are MUTABLE_COPY
    # (declared divergence), so mixed native/host operand binops can still fall
    # back to the host; PyClass/PyUserObj are STANDIN (name-faithful stand-ins).
    return to_host_policy(t) != BridgePolicy.FAIL;
}

# Object identity for `is` / `id()`. None and booleans are true singletons in
# CPython, and small ints [-5, 256] are cached, so for these three identity is
# deterministically value-equality -- we answer them by value and match CPython
# without interning every construction site (which the na-clean leaf can't hold
# a persistent singleton for anyway). Every other object uses real Jac reference
# identity: fresh containers/strings/big-ints are `is`-equal only when aliased.
def _small_int_cached(v: int) -> bool {
    return v >= -5 and v <= 256;
}

def py_identity(a: PyObj, b: PyObj) -> bool {
    if isinstance(a, PyNoneType) or isinstance(b, PyNoneType) {
        return isinstance(a, PyNoneType) and isinstance(b, PyNoneType);
    }
    if isinstance(a, PyBool) and isinstance(b, PyBool) {
        return (a as PyBool).val == (b as PyBool).val;
    }
    if isinstance(a, PyInt) and isinstance(b, PyInt) {
        av = (a as PyInt).val;
        bv = (b as PyInt).val;
        if av == bv and _small_int_cached(av) {
            return True;
        }
        return a is b;
    }
    # Two proxies to the SAME host object are the same object: `type(x) is str`
    # (str being a host-type proxy, type(x) another) must hold, or CPython idioms
    # like namedtuple's `type(name) is not str` field-name check spuriously fail.
    if isinstance(a, PyHostProxy) and isinstance(b, PyHostProxy) {
        return (a as PyHostProxy).val is (b as PyHostProxy).val;
    }
    return a is b;
}

# id(): stable per-object integer. For the cached-immutable classes above, return
# a synthetic id in a reserved low band so `id(x) == id(y)` iff `x is y` stays
# consistent with py_identity; every other object reports its Jac reference id.
def py_id(o: PyObj) -> int {
    if isinstance(o, PyNoneType) {
        return 1;
    }
    if isinstance(o, PyBool) {
        if (o as PyBool).val {
            return 3;
        }
        return 2;
    }
    if isinstance(o, PyInt) {
        v = (o as PyInt).val;
        if _small_int_cached(v) {
            return 1000 + v;
        }
    }
    # A proxy's identity is its underlying host object's identity (consistent
    # with py_identity treating same-host-object proxies as one object).
    if isinstance(o, PyHostProxy) {
        return id((o as PyHostProxy).val);
    }
    return id(o);
}

# A dunder returned NotImplemented (native sentinel or host singleton proxy).
def is_notimplemented(o: PyObj) -> bool {
    if o is PY_NOT_IMPLEMENTED {
        return True;
    }
    if isinstance(o, PyHostProxy) {
        return _jac_is_notimpl((o as PyHostProxy).val) as bool;
    }
    return False;
}

# ---- user-class operator overloading (__add__/__eq__/... dispatch) ---------
# The native nb_binop/tp_richcompare slots only know builtin types; a plain user
# class defines operators as `__add__`/`__eq__`/... methods in its class dict.
# These helpers implement CPython's binary-operator protocol (normal slot, then
# reflected slot, then TypeError) over the MRO for PyUserObj operands.

# NB_ binop kind -> dunder name ("" if the kind has no overload slot).
def binop_dunder(kind: int) -> str {
    names = [
        "__add__",
        "__and__",
        "__floordiv__",
        "__lshift__",
        "__matmul__",
        "__mul__",
        "__mod__",
        "__or__",
        "__pow__",
        "__rshift__",
        "__sub__",
        "__truediv__",
        "__xor__"
    ];
    if kind >= 0 and kind < len(names) {
        return names[kind];
    }
    return "";
}

# Reflected counterpart (__radd__/__rmul__/...) for the same kind.
def binop_rdunder(kind: int) -> str {
    names = [
        "__radd__",
        "__rand__",
        "__rfloordiv__",
        "__rlshift__",
        "__rmatmul__",
        "__rmul__",
        "__rmod__",
        "__ror__",
        "__rpow__",
        "__rrshift__",
        "__rsub__",
        "__rtruediv__",
        "__rxor__"
    ];
    if kind >= 0 and kind < len(names) {
        return names[kind];
    }
    return "";
}

# Rich-compare kind (0<,1<=,2==,3!=,4>,5>=) -> dunder name.
def compare_dunder(kind: int) -> str {
    names = ["__lt__", "__le__", "__eq__", "__ne__", "__gt__", "__ge__"];
    if kind >= 0 and kind < len(names) {
        return names[kind];
    }
    return "";
}

# Reflected comparison kind: < <-> >, <= <-> >=, ==/!= are self-reflected.
def compare_swap(kind: int) -> int {
    swap = [4, 5, 2, 3, 0, 1];
    if kind >= 0 and kind < len(swap) {
        return swap[kind];
    }
    return kind;
}

def user_has_dunder(u: PyUserObj, name: str) -> bool {
    return not is_error(class_lookup_attr(u.cls, name));
}

# CPython operator subclass priority: when `type(rhs)` is a PROPER subclass of
# `type(lhs)` and overrides the reflected slot (`rname`), the reflected call is
# tried BEFORE the left operand's forward slot. True iff that reordering applies.
def rhs_reflected_priority(lhs: PyObj, rhs: PyObj, rname: str) -> bool {
    if rname == "" {
        return False;
    }
    if not (isinstance(lhs, PyUserObj) and isinstance(rhs, PyUserObj)) {
        return False;
    }
    lcls = (lhs as PyUserObj).cls;
    rcls = (rhs as PyUserObj).cls;
    if lcls is rcls {
        return False;
    }
    # rhs's class must be a proper subclass of lhs's class (it already differs).
    if not instance_of_class(rhs as PyUserObj, lcls) {
        return False;
    }
    return user_has_dunder(rhs as PyUserObj, rname);
}

# Bind the MRO-resolved dunder to the receiver and call it with `args`. The
# result -- a value, a raised exception (PyError), or NotImplemented -- is
# returned verbatim for the protocol layer to interpret.
def call_user_dunder(u: PyUserObj, name: str, args: list[PyObj]) -> PyObj {
    method = class_lookup_attr(u.cls, name);
    return bind_attribute(method, u).tp_call(args, {});
}

# CPython ``dict_subscript`` consults a type-level ``__missing__``: when the
# lookup on a dict whose TYPE is a subclass misses, ``dict.__getitem__`` calls
# the MRO-resolved ``__missing__(key)`` and returns its value instead of
# raising KeyError (this is defaultdict's mechanism). Only the subscript slot
# does this -- get()/pop()/``in`` never invoke ``__missing__``. A user-defined
# ``__getitem__`` replaces the slot wholesale, so callers that dispatched an
# override never reach here. An unhashable key fails before lookup (TypeError),
# so only a genuine KeyError miss falls back.
def dict_subscript_missing(owner: PyUserObj, d: PyDict, index: PyObj) -> PyObj {
    res = d.mp_subscript(index);
    if not is_error(res) {
        return res;
    }
    err = res as PyError;
    if err.exception.type_name != "KeyError" {
        return res;
    }
    missing = class_lookup_attr(owner.cls, "__missing__");
    if is_error(missing) {
        return res;
    }
    return bind_attribute(missing, owner).tp_call([index], {});
}

# CPython binary-operator protocol for PyUserObj operands: try lhs.__op__(rhs),
# then the reflected rhs.__rop__(lhs); a builtin-subclass operand with no user
# override delegates to its boxed value; otherwise TypeError. A raised exception
# from a dunder propagates immediately (it is not NotImplemented).
def user_binop(kind: int, lhs: PyObj, rhs: PyObj) -> PyObj {
    name = binop_dunder(kind);
    rname = binop_rdunder(kind);
    # Subclass reflected priority: A() + B() where B(A) overrides __radd__ runs
    # B.__radd__ first (CPython rule).
    if rhs_reflected_priority(lhs, rhs, rname) {
        res = call_user_dunder(rhs as PyUserObj, rname, [lhs]);
        if not is_notimplemented(res) {
            return res;
        }
    }
    if isinstance(lhs, PyUserObj) {
        lu = lhs as PyUserObj;
        if name != "" and user_has_dunder(lu, name) {
            res = call_user_dunder(lu, name, [rhs]);
            if not is_notimplemented(res) {
                return res;
            }
        }
    }
    if isinstance(rhs, PyUserObj) {
        ru = rhs as PyUserObj;
        if rname != "" and user_has_dunder(ru, rname) {
            res = call_user_dunder(ru, rname, [lhs]);
            if not is_notimplemented(res) {
                return res;
            }
        }
    }
    # No user override matched: a builtin subclass acts as its boxed value.
    if isinstance(lhs, PyUserObj) and (lhs as PyUserObj)._has_base() {
        r = (lhs as PyUserObj)._base_obj().nb_binop(kind, unwrap_base(rhs));
        if not is_error(r) {
            return r;
        }
    }
    if isinstance(rhs, PyUserObj) and (rhs as PyUserObj)._has_base() {
        r = unwrap_base(lhs).nb_binop(kind, (rhs as PyUserObj)._base_obj());
        if not is_error(r) {
            return r;
        }
    }
    # NB_* kind -> operator symbol, same order as binop_dunder's name table.
    symbols = ["+", "&", "//", "<<", "@", "*", "%", "|", "**", ">>", "-", "/", "^"];
    op = symbols[kind] if kind >= 0 and kind < len(symbols) else "?";
    return py_error(
        "TypeError",
        "unsupported operand type(s) for " + op + ": '"
            + _compare_type_name(lhs) + "' and '" + _compare_type_name(rhs) + "'"
    );
}

# Instance -> CPython type name for protocol error messages. Wraps the
# builtin tag map in abstract_protocol with the operand kinds only ceval
# knows about: user class instances print their class name, dict views
# print dict_keys / dict_values / dict_items.
def _compare_type_name(v: PyObj) -> str {
    if isinstance(v, PyUserObj) {
        return (v as PyUserObj).cls.name;
    }
    if isinstance(v, PyDictView) {
        return "dict_" + (v as PyDictView).mode;
    }
    return _base_type_name(v);
}

# CPython rich-comparison protocol for PyUserObj operands. Same shape as
# user_binop, plus the == / != identity fallback when neither side overrides.
def user_compare(kind: int, lhs: PyObj, rhs: PyObj) -> PyObj {
    name = compare_dunder(kind);
    rname = compare_dunder(compare_swap(kind));
    # Subclass reflected priority: rhs's reflected comparison runs first when
    # type(rhs) is a proper subclass of type(lhs) and overrides it.
    if rhs_reflected_priority(lhs, rhs, rname) {
        res = call_user_dunder(rhs as PyUserObj, rname, [lhs]);
        if not is_notimplemented(res) {
            return res;
        }
    }
    # A builtin subclass's OWN comparison dunder wins (class MyInt(int) that
    # overrides __eq__), mirroring user_binop -- user_has_dunder only finds it
    # when the user class actually defines it, so an unoverridden subclass still
    # falls through to the boxed-value comparison below.
    if isinstance(lhs, PyUserObj) {
        lu = lhs as PyUserObj;
        if name != "" and user_has_dunder(lu, name) {
            res = call_user_dunder(lu, name, [rhs]);
            if not is_notimplemented(res) {
                return res;
            }
        }
    }
    if isinstance(rhs, PyUserObj) {
        ru = rhs as PyUserObj;
        if rname != "" and user_has_dunder(ru, rname) {
            res = call_user_dunder(ru, rname, [lhs]);
            if not is_notimplemented(res) {
                return res;
            }
        }
    }
    if isinstance(lhs, PyUserObj) and (lhs as PyUserObj)._has_base() {
        res = (lhs as PyUserObj)._base_obj().tp_richcompare(kind, unwrap_base(rhs));
        if not is_notimplemented(res) {
            return res;
        }
    }
    if isinstance(rhs, PyUserObj) and (rhs as PyUserObj)._has_base() {
        res = unwrap_base(lhs).tp_richcompare(kind, (rhs as PyUserObj)._base_obj());
        if not is_notimplemented(res) {
            return res;
        }
    }
    if kind == 2 {
        return PyBool(t="bool", val=lhs is rhs);
    }
    if kind == 3 {
        # CPython object.__ne__: when either side defines __eq__ (and neither
        # defined __ne__ -- both were tried above), != is the negated result
        # of the full == protocol, not an identity test. Recursing with kind 2
        # reuses reflected priority, builtin-subclass slots, and the base
        # tp_richcompare chain; a NotImplemented from __eq__ still lands on
        # that chain's identity fallback before negation.
        eq_lhs = False;
        eq_rhs = False;
        if isinstance(lhs, PyUserObj) {
            eq_lhs = user_has_dunder(lhs as PyUserObj, "__eq__");
        }
        if isinstance(rhs, PyUserObj) {
            eq_rhs = user_has_dunder(rhs as PyUserObj, "__eq__");
        }
        if eq_lhs or eq_rhs {
            res = user_compare(2, lhs, rhs);
            if is_error(res) {
                return res;
            }
            truth = py_slot_truth(res);
            if is_error(truth) {
                return truth;
            }
            return PyBool(t="bool", val=not (truth as PyBool).val);
        }
        return PyBool(t="bool", val=lhs is not rhs);
    }
    return py_ordering_type_error(kind, lhs, rhs, _compare_type_name);
}

# ---------------- NB_INPLACE_* : mutate-and-return-self protocol ----------------

# list.__iadd__ / list.__imul__ (CPython listobject.c list_inplace_concat /
# list_inplace_repeat): mutate `lst` storage and return it, so every alias
# observes the update and the trailing STORE_FAST re-binds the SAME object.
def list_inplace_binop(lst: PyList, kind: int, rhs: PyObj) -> PyObj {
    if kind == NB_INPLACE_ADD {
        # Extend semantics: any iterable is accepted (unlike __add__, which
        # only concatenates lists).
        drained = iter_drain(rhs);
        if is_error(drained) {
            return drained;
        }
        for x in (drained as PyList).items {
            lst.items.append(x);
        }
        return lst;
    }
    if kind == NB_INPLACE_MULTIPLY {
        idx = rhs.to_index();
        if is_error(idx) {
            return py_error(
                "TypeError",
                "can't multiply sequence by non-int of type '" + rhs.t + "'",
            );
        }
        n = (idx as PyInt).val;
        repeated: list[PyObj] = [];
        while n > 0 {
            repeated.extend(lst.items);
            n = n - 1;
        }
        lst.items = repeated;
        return lst;
    }
    return PY_NOT_IMPLEMENTED;
}

# set |= &= -= ^= (CPython setobject.c set_ior/iand/isub/ixor): mutate `s`
# storage and return it. Frozen sets decline (no in-place slots) -- py_binop
# then folds to the base binop, producing a NEW frozenset on rebind, which is
# exactly CPython's legal `fs |= {x}` behavior.
def set_inplace_binop(s: PySet, kind: int, rhs: PyObj) -> PyObj {
    if s.frozen {
        return PY_NOT_IMPLEMENTED;
    }
    if kind != NB_INPLACE_OR and kind != NB_INPLACE_AND
        and kind != NB_INPLACE_SUBTRACT and kind != NB_INPLACE_XOR {
        return PY_NOT_IMPLEMENTED;
    }
    # All four arms consume any iterable (set_update-family semantics); drain
    # up front so failed iteration raises before self mutates.
    drained = iter_drain(rhs);
    if is_error(drained) {
        return drained;
    }
    elems = (drained as PyList).items;
    if kind == NB_INPLACE_OR {
        for x in elems {
            err = s.set_add(x);
            if is_error(err) {
                return err;
            }
        }
        return s;
    }
    # Hash incoming elements before touching self: an unhashable member raises
    # with self still untouched.
    other_hks: list[str] = [];
    for x in elems {
        hkr = x.tp_hashkey();
        if is_error(hkr) {
            return py_error("TypeError", "unhashable type: '" + x.t + "'");
        }
        other_hks.append(hashkey_str(hkr));
    }
    rebuilt: dict[str, PyObj] = {};
    if kind == NB_INPLACE_AND {
        # intersection_update keeps self elements present in other.
        for hk in s.items {
            if hk in other_hks {
                rebuilt[hk] = s.items[hk];
            }
        }
    } elif kind == NB_INPLACE_SUBTRACT {
        for hk in s.items {
            if not (hk in other_hks) {
                rebuilt[hk] = s.items[hk];
            }
        }
    } else {
        # symmetric_difference_update: keep self-only members, add other-only
        # ones (first occurrence wins on duplicates within other).
        for hk in s.items {
            if not (hk in other_hks) {
                rebuilt[hk] = s.items[hk];
            }
        }
        i = 0;
        while i < len(other_hks) {
            hk = other_hks[i];
            if not (hk in s.items) and not (hk in rebuilt) {
                rebuilt[hk] = elems[i];
            }
            i = i + 1;
        }
    }
    s.items = rebuilt;
    return s;
}

# The BINARY_OP in-place arm (opcode.h NB_INPLACE_* 13..25). Mutable native
# containers expose CPython-style in-place slots that MUTATE the receiver and
# return it -- aliases observe the update (`a = b = []; a += [x]` keeps
# `a is b` True). Everything else returns PY_NOT_IMPLEMENTED and py_binop
# folds the kind to its base binop (immutable fallback: str/bytes/int/tuple
# legitimately rebind).
def py_inplace_binop(kind: int, lhs: PyObj, rhs: PyObj) -> PyObj {
    if isinstance(lhs, PyList) {
        return list_inplace_binop(lhs as PyList, kind, rhs);
    }
    if isinstance(lhs, PySet) {
        return set_inplace_binop(lhs as PySet, kind, rhs);
    }
    return PY_NOT_IMPLEMENTED;
}

def py_binop(kind: int, lhs: PyObj, rhs: PyObj) -> PyObj {
    # NB_INPLACE_* (13..25): try the receiver's in-place slot first; when it
    # declines (immutables, frozen sets), reduce to the base binop (0..12) so
    # `x += y` is `x = x + y` and the trailing STORE rebinds -- CPython's
    # immutable-type fallback.
    if kind >= NB_INPLACE_ADD and kind <= NB_INPLACE_XOR {
        inplace = py_inplace_binop(kind, lhs, rhs);
        if not is_notimplemented(inplace) {
            return inplace;
        }
        kind = kind - NB_INPLACE_ADD;
    }
    # A user-class operand routes through the operator-overload protocol first.
    # EXCEPT str %-format over a native operand carrying user instances: CPython
    # calls str.__mod__ FIRST -- %s/%r stringify through the operand's own
    # __str__/__repr__ slots -- and never falls back to __rmod__ past its real
    # TypeError ('%d' % X() raises even when X defines __rmod__). The result,
    # success or error, propagates; scalar-only args keep the lifted fast path
    # with its host-bridge error fallback below.
    if kind == NB_REMAINDER and isinstance(lhs, PyStr)
        and mod_args_need_user_slots(rhs) {
        return str_mod_format((lhs as PyStr).val, rhs, py_str, py_repr);
    }
    if isinstance(lhs, PyUserObj) or isinstance(rhs, PyUserObj) {
        return user_binop(kind, lhs, rhs);
    }
    # A dict view on either side does set algebra (| & - ^) yielding a PySet,
    # e.g. {1:1}.keys() | {2} and {2} | {1:1}.items().
    if isinstance(lhs, PyDictView) or isinstance(rhs, PyDictView) {
        return dictview_binop(kind, lhs, rhs);
    }
    result = lhs.nb_binop(kind, rhs);
    if is_error(result) {
        # A builtin-subclass operand the other side's slot didn't recognize
        # (e.g. 1 + MyInt(5), where int.nb_binop rejects the "instance" tag):
        # retry with both operands unwrapped to their boxed values.
        ul = unwrap_base(lhs);
        ur = unwrap_base(rhs);
        if not (ul is lhs) or not (ur is rhs) {
            result = ul.nb_binop(kind, ur);
        }
    }
    if is_error(result) and kind == NB_MULTIPLY and isinstance(rhs, PyList) {
        # Reflected sequence repeat: 3 * [x] -- int.__mul__ declines, so
        # CPython falls through to list.__rmul__ (sq_repeat). Must stay
        # native: the host fallback would to_host() each element and break
        # reference aliasing ([[0]]*3 must share one inner list).
        return rhs.nb_binop(NB_MULTIPLY, lhs);
    }
    if is_error(result) and kind == NB_MULTIPLY and isinstance(rhs, PyTuple) {
        return rhs.nb_binop(NB_MULTIPLY, lhs);
    }
    if is_error(result) and isinstance(rhs, PyComplex) {
        # Reflected complex tower (2 - 1j, 6 / (3+0j), 2 ** (3+0j)): CPython's
        # int/float slots decline a complex operand and the complex r-slot
        # promotes. Numeric errors stay native; PY_NOT_IMPLEMENTED falls
        # through to the host fallback below for byte-exact messages.
        lhs_real = lhs.t == "int" or lhs.t == "float" or lhs.t == "bool";
        if lhs_real {
            rres = (rhs as PyComplex)._reflected_binop(kind, lhs);
            if not is_error(rres) and not is_notimplemented(rres) {
                return rres;
            }
            if is_error(rres) {
                terr = (rres as PyError).exception.type_name;
                if terr == "ZeroDivisionError" or terr == "OverflowError" {
                    return rres;
                }
            }
        }
    }
    if is_error(result) and _host_representable(lhs.t) and _host_representable(rhs.t) {
        # Fall back when native slots are incomplete (TypeError, ValueError from
        # partial str %-format, ...). Operational numeric errors must stay native
        # so exception messages match CPython in-VM (e.g. str(e) after `1 // 0`).
        err = result as PyError;
        tn = err.exception.type_name;
        if tn != "ZeroDivisionError" and tn != "OverflowError" {
            return host_binop(kind, lhs, rhs);
        }
    }
    return result;
}

def py_subscript(container: PyObj, index: PyObj) -> PyObj {
    return container.mp_subscript(index);
}

# Membership test (CONTAINS_OP). Native sets/dicts answer via the hash-key
# protocol; other container shapes route through the host so `in` stays
# consistent for opaque proxies during bootstrap.
def py_contains(container: PyObj, member: PyObj) -> PyObj {
    if isinstance(container, PyRange) {
        rg = container as PyRange;
        # Exact-int needles (incl. bool, per CPython's int-instance check) take
        # the O(1) arithmetic path from the lifted leaf.
        if isinstance(member, PyInt) or isinstance(member, PyBool) {
            v = (member as PyInt).val;
            return PyBool(
                t="bool", val=range_contains_longs(rg.start, rg.stop, rg.step, v)
            );
        }
        # Non-int needles scan item by item with real == (CPython's
        # _PySequence_IterSearch fallback); same O(n) behavior as CPython.
        cursor = rg.tp_iter();
        while True {
            scan_step = send_into(cursor, py_none());
            if scan_step.t == "genstop" {
                return PyBool(t="bool", val=False);
            }
            cmp = py_compare(2, member, scan_step);
            if is_error(cmp) {
                return cmp;
            }
            if cmp.tp_bool() {
                return PyBool(t="bool", val=True);
            }
        }
    }
    if isinstance(container, PyDictView) {
        return view_contains(container as PyDictView, member);
    }
    if isinstance(container, PySet) {
        return (container as PySet).set_lookup(member);
    }
    if isinstance(container, PyDict) {
        return PyBool(t="bool", val=(container as PyDict).dict_contains(member));
    }
    # PEP 667: FrameLocalsProxy answers sq_contains through its slot/extra
    # lookup, not iteration (Objects/frameobject.c frame_localsproxy_contains).
    if isinstance(container, PyFrameLocalsProxy) {
        return (container as PyFrameLocalsProxy).contains_key(member);
    }
    # Native tuple/list membership compares elements with a real == in-VM. Routing
    # through the host collapses every native class/instance to None (to_host), so
    # `SomeClass in (OtherClass,)` would wrongly match; keep it native.
    if isinstance(container, PyTuple) or isinstance(container, PyList) {
        elems: list[PyObj] = [];
        if isinstance(container, PyTuple) {
            elems = (container as PyTuple).items;
        } else {
            elems = (container as PyList).items;
        }
        for item in elems {
            cmp = py_compare(2, member, item);
            if is_error(cmp) {
                return cmp;
            }
            if cmp.tp_bool() {
                return PyBool(t="bool", val=True);
            }
        }
        return PyBool(t="bool", val=False);
    }
    # Implicit sq_contains slot on user classes: __contains__ wins; without it
    # CPython's default sq_contains iterates with real ==; neither available
    # is the TypeError.
    if isinstance(container, PyUserObj) {
        u = container as PyUserObj;
        if user_has_dunder(u, "__contains__") {
            hit = call_user_dunder(u, "__contains__", [member]);
            if is_error(hit) {
                return hit;
            }
            truth = py_slot_truth(hit);
            if is_error(truth) {
                return truth;
            }
            return truth;
        }
        cursor = (u as PyObj).tp_iter();
        if is_error(cursor) {
            return py_error(
                "TypeError", "argument of type '" + u.cls.name + "' is not iterable"
            );
        }
        while True {
            scan = send_into(cursor, py_none());
            if scan.t == "genstop" {
                return PyBool(t="bool", val=False);
            }
            if is_error(scan) {
                return scan;
            }
            cmp2 = py_compare(2, member, scan);
            if is_error(cmp2) {
                return cmp2;
            }
            found = py_slot_truth(cmp2);
            if is_error(found) {
                return found;
            }
            if (found as PyBool).val {
                return PyBool(t="bool", val=True);
            }
        }
    }
    hm_r = to_host_coerce(member);
    hm = hm_r[1];
    if not ((hm_r[0] as bool)) {
        return hm_r[1] as PyObj;
    }
    hc_r = to_host_coerce(container);
    hc = hc_r[1];
    if not ((hc_r[0] as bool)) {
        return hc_r[1] as PyObj;
    }
    result = _jac_host_contains(hm, hc);
    if host_result_ok(result) {
        return from_host(result[1]);
    }
    return host_result_error(result);
}

def py_store_subscript(container: PyObj, index: PyObj, value: PyObj) -> PyObj {
    # Slice assignment accepts ANY iterable as its value; CPython runs it
    # through PySequence_Fast before list_ass_subscript. members_of() is that
    # conversion (py_iter-first, host fallback), so user generators/iterables
    # drain in-VM instead of dying inside the na-clean leaf slot.
    if isinstance(container, PyList) and isinstance(index, PySlice) {
        seq = members_of(value);
        if is_error(seq) {
            return seq;
        }
        return container.mp_ass_subscript(index, seq);
    }
    return container.mp_ass_subscript(index, value);
}

def py_delete_subscript(container: PyObj, index: PyObj) -> PyObj {
    return container.mp_del_subscript(index);
}

# DICT_UPDATE/DICT_MERGE source view: validate the merge source against
# CPython's mapping protocol (ceval.c TARGET(DICT_UPDATE)/TARGET(DICT_MERGE))
# and yield its pairs. Accepted sources: native PyDict, a host-backed mapping
# whose from_host conversion lands as PyDict, or a user object exposing both
# keys() and __getitem__ (drained through the dunder protocol). Anything else
# is rejected exactly where CPython rejects it:
#   - DICT_UPDATE ({**x}): TypeError "'<type>' object is not a mapping"
#   - DICT_MERGE (f(**x)): TypeError "argument after ** must be a mapping,
#     not <type>" -- host additionally prefixes the caller qualname, which the
#     VM omits (house style for call-site errors, see fast-bind messages).
# Returns the pair source as a PyObj holding a PyDict, or an unraised error.
def dict_mapping_pairs(source: PyObj, kwargs_call: bool) -> PyObj {
    if isinstance(source, PyDict) {
        return source;
    }
    if isinstance(source, PyHostProxy) {
        converted = from_host((source as PyHostProxy).val);
        if isinstance(converted, PyDict) {
            return converted;
        }
    }
    if isinstance(source, PyUserObj) {
        u = source as PyUserObj;
        if user_has_dunder(u, "keys") and user_has_dunder(u, "__getitem__") {
            keys_res = call_user_dunder(u, "keys", []);
            if is_error(keys_res) {
                return keys_res;
            }
            # LAZY drain over the keys() result (CPython PyMapping_Keys
            # semantics): d.keys() views carry staleness, so a mapping whose
            # underlying storage mutates mid-merge raises RuntimeError during
            # this loop exactly like host (test_dict doctests exc62/65). An
            # eager snapshot here would silently hide that mutation.
            kit = py_iter(keys_res);
            out = PyDict(t="dict", items={});
            while True {
                k = send_into(kit, py_none());
                if k.t == "genstop" {
                    break;
                }
                if is_error(k) {
                    return k;
                }
                v = call_user_dunder(u, "__getitem__", [k]);
                if is_error(v) {
                    return v;
                }
                out.dict_set(k, v);
            }
            return out;
        }
        # Mapping-subclass fallback: user classes inheriting from host-ABC
        # stand-ins (collections.abc Mapping/MutableMapping) have no visible
        # inherited keys() -- class_mro-based dunder lookup skips host-proxy
        # bases -- but CPython still merges such objects because instances
        # are an iterable of their keys. Drive __iter__ LAZILY so a mapping
        # mutating storage mid-iteration raises RuntimeError during the
        # drain exactly like CPython (test_dict doctests exc62/65); an
        # eager members_of() snapshot would hide that.
        if user_has_dunder(u, "__iter__") and user_has_dunder(u, "__getitem__") {
            it = call_user_dunder(u, "__iter__", []);
            if is_error(it) {
                return it;
            }
            iter_out = PyDict(t="dict", items={});
            while True {
                step = send_into(it, py_none());
                if step.t == "genstop" {
                    break;
                }
                if is_error(step) {
                    return step;
                }
                v = call_user_dunder(u, "__getitem__", [step]);
                if is_error(v) {
                    return v;
                }
                iter_out.dict_set(step, v);
            }
            return iter_out;
        }
    }
    tname = _compare_type_name(source);
    if kwargs_call {
        return py_error("TypeError", "argument after ** must be a mapping, not " + tname);
    }
    return py_error("TypeError", "'" + tname + "' object is not a mapping");
}

# UNARY_NEGATIVE (-x). int/bool negate to int (-True == -1), float to float,
# complex negates both parts; any other operand is a TypeError, matching
# CPython's nb_negative == NULL path.
def py_negative(value: PyObj) -> PyObj {
    if isinstance(value, PyBool) {
        v = 0;
        if (value as PyBool).val {
            v = 1;
        }
        return PyInt(t="int", val=-v);
    }
    if isinstance(value, PyInt) {
        return PyInt(t="int", val=-(value as PyInt).val);
    }
    if isinstance(value, PyFloat) {
        return PyFloat(t="float", val=-(value as PyFloat).val);
    }
    if isinstance(value, PyComplex) {
        c = value as PyComplex;
        return PyComplex(t="complex", real=-c.real, imag=-c.imag);
    }
    return py_error("TypeError", "bad operand type for unary -");
}

# UNARY_INVERT (~x). Defined only for ints/bools: ~x == -x - 1.
def py_invert(value: PyObj) -> PyObj {
    if isinstance(value, PyBool) {
        v = 0;
        if (value as PyBool).val {
            v = 1;
        }
        return PyInt(t="int", val=-v - 1);
    }
    if isinstance(value, PyInt) {
        return PyInt(t="int", val=-(value as PyInt).val - 1);
    }
    return py_error("TypeError", "bad operand type for unary ~");
}

def append_to_list(target: PyObj, iterable: PyObj) -> PyObj {
    target_list = target as PyList;
    if iterable.t == "list" {
        target_list.items.extend(list_value(iterable));
        return py_none();
    } elif iterable.t == "tuple" {
        target_list.items.extend(tuple_value(iterable));
        return py_none();
    } elif iterable.t == "str" {
        for ch in str_value(iterable) {
            target_list.items.append(PyStr(t="str", val=ch));
        }
        return py_none();
    }
    # CPython's LIST_EXTEND accepts ANY iterable (range/dict/set/generators
    # included); the old shape dispatch silently produced an empty extend for
    # every other kind. Fall back to a generic iterator drain and propagate
    # the TypeError for non-iterables.
    drained = iter_drain(iterable);
    if is_error(drained) {
        return drained;
    }
    target_list.items.extend((drained as PyList).items);
    return py_none();
}

# Native scalar/container tags whose method surface is not yet ported. During
# bootstrap their attribute lookups fall back across the substrate boundary to
# host CPython (host_getattr returns a bound method, which from_host wraps as a
# callable PyHostProxy). This is the object-core-clean seam: the fallback lives
# here in pyc_first (host-allowed), never in the na-clean objects.jac, so e.g.
# 'abc'.upper() / {}.copy() / dict().keys() work before their native ports land.
def _is_host_backed(t: str) -> bool {
    return t == "str"
        or t == "bytes"
        or t == "int"
        or t == "bool"
        or t == "float"
        or t == "list"
        or t == "tuple"
        or t == "dict"
        or t == "complex";
}

# PEP 695 lazy alias evaluation (CPython TypeAliasType.__value__ /
# evaluate_value): run the hidden value function once at format 0, cache the
# result, and serve every later access from the cache. Errors propagate
# uncached, so a retry re-evaluates (and re-raises) exactly like a fresh call.
def typealias_value(ta: PyTypeAlias) -> PyObj {
    if ta.computed {
        return ta.cached_value;
    }
    res = py_invoke(ta.value_fn, [PyInt(t="int", val=0)], {});
    if is_error(res) {
        return res;
    }
    ta.computed = True;
    ta.cached_value = res;
    return res;
}

# PEP 695 lazy bound/constraints/default resolution (CALL_INTRINSIC_2 arms
# 2/3/5): the evaluator runs once through py_invoke and its value caches on
# the TypeVar, mirroring CPython typevarobject.c getsets. Absent evaluators
# answer the CPython defaults: None / the empty tuple / NoDefault.
def typevar_bound_value(tv: PyTypeVar) -> PyObj {
    if tv.bound_resolved {
        return tv.cached_bound;
    }
    res = py_none();
    if tv.evaluate_bound.t != "none" {
        res = py_invoke(tv.evaluate_bound, [], {});
        if is_error(res) {
            return res;
        }
    }
    tv.cached_bound = res;
    tv.bound_resolved = True;
    return res;
}

def typevar_constraints_value(tv: PyTypeVar) -> PyObj {
    if tv.constraints_resolved {
        return tv.cached_constraints;
    }
    res = PyTuple(t="tuple", items=[]);
    if tv.evaluate_constraints.t != "none" {
        res = py_invoke(tv.evaluate_constraints, [], {});
        if is_error(res) {
            return res;
        }
    }
    tv.cached_constraints = res;
    tv.constraints_resolved = True;
    return res;
}

def typevar_default_value(tv: PyTypeVar) -> PyObj {
    if tv.default_resolved {
        return tv.cached_default;
    }
    res = no_default_sentinel() as PyObj;
    if tv.evaluate_default.t != "none" {
        res = py_invoke(tv.evaluate_default, [], {});
        if is_error(res) {
            return res;
        }
    }
    tv.cached_default = res;
    tv.default_resolved = True;
    return res;
}

def py_attr(value: PyObj, name: str) -> PyObj {
    # The alias's lazy __value__ re-enters the interpreter (it runs the hidden
    # value function), so it is served here rather than in the na-clean obj's
    # tp_getattro -- see typealias_value.
    if isinstance(value, PyTypeAlias) and name == "__value__" {
        return typealias_value(value as PyTypeAlias);
    }
    # Same seam for the TypeVar's lazy __bound__/__constraints__/__default__
    # (PEP 749 const-evaluators installed by CALL_INTRINSIC_2) -- see
    # typevar_bound_value and siblings.
    if isinstance(value, PyTypeVar) {
        if name == "__bound__" {
            return typevar_bound_value(value as PyTypeVar);
        }
        if name == "__constraints__" {
            return typevar_constraints_value(value as PyTypeVar);
        }
        if name == "__default__" {
            return typevar_default_value(value as PyTypeVar);
        }
        # has_default() is syntactic (PEP 696: never forces evaluation) but
        # needs a callable wrapper built on this side of the substrate
        # boundary, like the dict/list/set method wrappers below.
        if name == "has_default" {
            return PyTypeVarMethod(t="typevar_method", tv=value as PyTypeVar, name=name);
        }
    }
    # typing.Generic[T, ...] stand-ins answer origin/args/parameters plus the
    # __mro_entries__ hook that __build_class__ resolves (update_bases port in
    # py_build_class).
    if isinstance(value, PyGenericAlias) {
        ga = value as PyGenericAlias;
        if name == "__origin__" {
            return typing_generic_class();
        }
        if name == "__args__" or name == "__parameters__" {
            return ga.params;
        }
        if name == "__mro_entries__" {
            return PyGenericMroEntries(t="generic_mro_entries");
        }
    }
    result = value.tp_getattro(name);
    # A native dict's keys()/values()/items() are bound zero-arg constructors of
    # a live, set-like PyDictView (not host proxies), so view comparison / set
    # algebra can invoke element __eq__ and iteration carries the mutation guard.
    if is_error(result)
        and isinstance(value, PyDict)
        and (name == "keys" or name == "values" or name == "items") {
        return PyDictViewCtor(t="view_ctor", d=value as PyDict, mode=name);
    }
    # Native mutating/accessor dict methods, so a dict-subclass mutation lands in
    # real storage rather than a to_host copy.
    if is_error(result) and isinstance(value, PyDict) and is_dict_method(name) {
        return PyDictMethod(t="dict_method", target=value as PyDict, name=name);
    }
    # Native list methods, so `lst.append(x)` mutates the real list, not a copy.
    if is_error(result) and isinstance(value, PyList) and is_list_method(name) {
        return PyListMethod(t="list_method", target=value as PyList, name=name);
    }
    if is_error(result)
        and isinstance(value, PySet)
        and is_set_method(name, (value as PySet).frozen) {
        return PySetMethod(t="set_method", target=value as PySet, name=name);
    }
    # Native str methods: a bound PyStrMethod keeps instance calls in-VM instead
    # of crossing the substrate boundary for every 'x'.upper() (same seam as the
    # dict/list/set arms above; unported names still fall through to the host).
    if is_error(result) and isinstance(value, PyStr) and is_str_method(name) {
        return PyStrMethod(t="str_method", target=value as PyStr, name=name);
    }
    # ExceptionGroup split/subgroup kernel (PEP 654): bound native methods so
    # partitioning runs on live guest objects rather than host copies.
    if is_error(result) and isinstance(value, PyException) and name == "add_note" {
        return PyAddNoteMethod(t="add_note_method", target=value as PyException);
    }
    if is_error(result) and isinstance(value, PyExcGroup)
        and (name == "split" or name == "subgroup") {
        return PyExcGroupMethod(
            t="egroup_method", target=value as PyExcGroup, name=name
        );
    }
    # Native __iter__ on containers and __next__ on native iterators bind to
    # in-VM implementations: the substrate fallback bridges container
    # __iter__ to a host slot wrapper whose iterator is an eager snapshot
    # (silently losing dict mutation staleness -- test_dict exc62/65), and
    # native iterators otherwise expose no callable __next__ at all.
    # MUST precede the _is_host_backed fallback or it never runs.
    if is_error(result) and name == "__iter__"
        and (isinstance(value, PyDict) or isinstance(value, PyList)
            or isinstance(value, PySet) or isinstance(value, PyTuple)
            or isinstance(value, PyStr)) {
        return PyNativeIterMethod(t="native_iter_method", target=value);
    }
    if is_error(result) and name == "__next__"
        and (PyIter_Check(value) or isinstance(value, PyCallableIter)) {
        return PyNativeNextMethod(t="native_next_method", target=value);
    }
    if is_error(result) and _is_host_backed(value.t) {
        return host_getattr(value, name);
    }
    # `.__new__` on any object with no override is object.__new__ (inherited), so
    # None.__new__ / instance.__new__ resolve instead of raising -- enum compares
    # candidate constructors against object.__new__.
    if is_error(result) and name == "__new__" {
        return PyNativeNew(t="native_new", base_name="object");
    }
    # `.__init__` with no user override is object.__init__ (a no-op accepting any
    # args), so inst.__init__(*args) resolves rather than raising.
    if is_error(result) and name == "__init__" {
        return PyNoOpInit(t="noop_init");
    }
    return result;
}

def bind_attribute(value: PyObj, receiver: PyObj) -> PyObj {
    # Explicit bind (a looked-up __init__/__new__/__prepare__ against a known
    # receiver). Routes through the descriptor protocol so a classmethod binds its
    # class and a staticmethod unwraps, not just a plain function.
    if isinstance(value, PyClassMethod) or isinstance(value, PyStaticMethod) {
        return descriptor_get(value, receiver, receiver);
    }
    if value.t == "function" {
        return PyBoundMethod(t="bound_method", function=value, receiver=receiver);
    }
    return value;
}

def py_set_attr(value: PyObj, name: str, field: PyObj) -> PyObj {
    return value.tp_setattro(name, field);
}

# `del obj.name` / delattr(obj, name). Native objects delete from their own
# writable attribute map; anything else falls back to the host.
def py_del_attr(value: PyObj, name: str) -> PyObj {
    if isinstance(value, PyClass) {
        c = value as PyClass;
        if name in c.attrs {
            del c.attrs[name];
            return py_none();
        }
        return py_error("AttributeError", name);
    }
    if isinstance(value, PyUserObj) {
        u = value as PyUserObj;
        # slot_tp_setattro dispatches deletion through the type-level
        # __delattr__ when the MRO defines one, before any default handling.
        attr_override = class_lookup_attr(u.cls, "__delattr__");
        if not is_error(attr_override) {
            return bind_attribute(attr_override, u as PyObj).tp_call(
                [PyStr(t="str", val=name)], {}
            );
        }
        return default_user_delattro(u, name);
    }
    if isinstance(value, PyModule) {
        m = value as PyModule;
        if name in m.attrs {
            del m.attrs[name];
            return py_none();
        }
        return py_error("AttributeError", name);
    }
    if isinstance(value, PyFunction) {
        f = value as PyFunction;
        if name in f.attrs {
            del f.attrs[name];
            return py_none();
        }
        return py_error("AttributeError", name);
    }
    # Native facade objects may define their own deleter (base slot reports the
    # generic AttributeError, so untouched objects fall through unchanged).
    dres = value.tp_del_attr(name);
    if not is_error(dres) {
        return dres;
    }
    hv_r = to_host_coerce(value);
    hv = hv_r[1];
    if not ((hv_r[0] as bool)) {
        return hv_r[1] as PyObj;
    }
    result = _jac_host_delattr(hv, name);
    if host_result_ok(result) {
        return py_none();
    }
    return host_result_error(result);
}

# One step of the iter(callable, sentinel) callable-iterator: invoke the
# callable with no args; a result equal to the sentinel ends the iteration
# (permanently -- a later next keeps returning StopIteration). Comparison
# uses the full == protocol; errors propagate.
def calliter_next(it: PyCallableIter) -> PyObj {
    if it.exhausted {
        return PyGenStop(t="genstop", val=py_none());
    }
    res = (it.fn as PyObj).tp_call([], {});
    if is_error(res) {
        # CPython calliter_iternext: a callable raising StopIteration (or a
        # subclass) ends this step -- the error is cleared and tp_iternext
        # returns NULL, so FOR_ITER pops the loop instead of propagating.
        # Exhaustion is NOT latched: each next() retries the callable.
        if error_is_stopiteration(res) {
            return PyGenStop(t="genstop", val=py_none());
        }
        return res;
    }
    eq = py_compare(2, res, it.sentinel);
    if is_error(eq) {
        return eq;
    }
    truth = py_slot_truth(eq);
    if is_error(truth) {
        return truth;
    }
    if (truth as PyBool).val {
        it.exhausted = True;
        return PyGenStop(t="genstop", val=py_none());
    }
    return res;
}

# One step of the old-style sequence iterator (CPython sq_iterator): fetch
# seq[index], incrementing; IndexError (matched by type, like
# PyErr_ExceptionMatches) ends the iteration permanently. Any other error
# propagates -- notably KeyError does NOT stop a sequence iterator.
def seqiter_next(it: PySeqIter) -> PyObj {
    res = it.seq.mp_subscript(PyInt(t="int", val=it.index));
    if is_error(res) {
        if error_is_indexerror(res) {
            it.index = -1;
            return PyGenStop(t="genstop", val=py_none());
        }
        return res;
    }
    it.index = it.index + 1;
    return res;
}

# True iff an iteration step failed with IndexError or a subclass -- the
# only exception that stops a sequence iterator (CPython
# PyErr_ExceptionMatches(PyExc_IndexError) in sq_iterator).
def error_is_indexerror(err: PyObj) -> bool {
    if err.t != "error" {
        return False;
    }
    exc = (err as PyError).exception;
    if exc_name_matches(exc.type_name, "IndexError") {
        return True;
    }
    raw = exc.raw;
    if raw is not None and isinstance(raw, PyUserObj) {
        for klass in class_mro((raw as PyUserObj).cls) {
            for base in klass.bases {
                if isinstance(base, PyExceptionType)
                    and (base as PyExceptionType).name == "IndexError" {
                    return True;
                }
            }
        }
    }
    return False;
}

def py_iter(value: PyObj) -> PyObj {
    # CPython tp_iter self-return: anything that IS an iterator is its own
    # iterator -- `it = iter(d); for x in it:` re-GET_ITERs the stored
    # iterator and must push it through unchanged, not fail or re-bridge.
    if PyIter_Check(value) or isinstance(value, PyCallableIter) {
        return value;
    }
    # A callable-iterator (two-arg iter) is its own iterator.
    if isinstance(value, PyCallableIter) {
        return value;
    }
    # A read-only mapping view iterates exactly like its dict.
    if isinstance(value, PyMappingProxy) {
        return py_iter((value as PyMappingProxy).target as PyObj);
    }
    if isinstance(value, PyUserObj) {
        u = value as PyUserObj;
        if user_has_dunder(u, "__iter__") {
            res = call_user_dunder(u, "__iter__", []);
            if is_error(res) {
                return res;
            }
            # A plain object returned by __iter__ that defines __next__ IS an
            # iterator (the self-returning class-iterator idiom): CPython fills
            # tp_iternext from __next__, so PyIter_Check accepts it.
            if not PyIter_Check(res)
                and not (
                    isinstance(res, PyUserObj)
                    and user_has_dunder(res as PyUserObj, "__next__")
                ) {
                return py_error(
                    "TypeError", "iter() returned non-iterator of type '" + res.t + "'"
                );
            }
            return res;
        }
        if u._has_base() {
            return PyObject_GetIter(u._base_obj());
        }
        # Old-style sequence protocol: __getitem__ without __iter__ synthesizes
        # a CPython sequence iterator (successive seq[i] until IndexError).
        # Checked after the boxed-base fallback so a builtin subclass keeps its
        # inherited tp_iter, matching CPython's slot order.
        if user_has_dunder(u, "__getitem__") {
            return PySeqIter(t="seqiter", seq=u as PyObj);
        }
    }
    return PyObject_GetIter(value);
}

# The __eq__/__hash__ MRO decision of CPython's slot machinery, shared by
# hash() and the hash-key protocol so they can never disagree. True iff the
# nearest class dict in the MRO defining either name makes instances
# unhashable: a callable __hash__ wins; an explicit `__hash__ = None` (or the
# marker type_ready_set_hash would inject for __eq__-without-__hash__, which
# shadows every ancestor's explicit __hash__) blocks.
def mro_hash_blocked(u: PyUserObj) -> bool {
    for klass in class_mro(u.cls) {
        if "__hash__" in klass.attrs {
            return isinstance(klass.attrs["__hash__"], PyNoneType);
        }
        if "__eq__" in klass.attrs {
            return True;
        }
    }
    return False;
}

# Native ``hash()`` for ported builtins and user ``__hash__``; no host fallback.
def py_hash(value: PyObj) -> PyObj {
    if isinstance(value, PyUserObj) {
        u = value as PyUserObj;
        # The MRO pair decision gates everything: it beats both a plain
        # user_has_dunder("__hash__") hit (an ancestor's __hash__ does not
        # rescue a subclass whose body defines only __eq__) and the boxed
        # builtin base delegation (an int subclass defining __eq__ is
        # unhashable despite int's own hashing).
        if mro_hash_blocked(u) {
            return py_error("TypeError", "unhashable type: '" + u.cls.name + "'");
        }
        if user_has_dunder(u, "__hash__") {
            h = call_user_dunder(u, "__hash__", []);
            if is_error(h) {
                return h;
            }
            if isinstance(h, PyBool) {
                h = PyInt(t="int", val=1 if (h as PyBool).val else 0);
            }
            if isinstance(h, PyInt) {
                return h;
            }
            # slot_tp_hash (typeobject.c ~10318) message, byte-exact.
            return py_error("TypeError", "__hash__ method should return an integer");
        }
        if u._has_base() {
            return py_hash(u._base_obj());
        }
        # Default tp_hash: object.__hash__ (the identity-keyed digest), or the
        # __eq__-without-__hash__ unhashable rule -- both owned by tp_hashkey,
        # so hash() and dict/set keying cannot disagree.
        hkr = u.tp_hashkey();
        if is_error(hkr) {
            return py_error("TypeError", "unhashable type: '" + u.cls.name + "'");
        }
        return PyObject_Hash(value);
    }
    if isinstance(value, PyTuple) {
        return tuple_hash(value as PyTuple);
    }
    if isinstance(value, PyInt) {
        return long_hash_obj(value as PyInt);
    }
    if isinstance(value, PyBytes) {
        return bytes_hash_obj(value as PyBytes);
    }
    if isinstance(value, PySet) {
        return set_hash_obj(value as PySet);
    }
    return hash_element(value);
}

def py_aiter_has_anext(value: PyObj) -> bool {
    if isinstance(value, PyUserObj) {
        return user_has_dunder(value as PyUserObj, "__anext__");
    }
    return not is_error(py_attr(value, "__anext__"));
}

# `async for`: call __aiter__ and verify the result exposes __anext__.
def py_aiter(value: PyObj) -> PyObj {
    if isinstance(value, PyUserObj)
        and user_has_dunder(value as PyUserObj, "__aiter__") {
        result = call_user_dunder(value as PyUserObj, "__aiter__", []);
    } else {
        method = py_attr(value, "__aiter__");
        if is_error(method) {
            return method;
        }
        result = py_invoke(method, [], {});
    }
    if is_error(result) {
        return result;
    }
    if not py_aiter_has_anext(result) {
        type_label = result.t;
        if isinstance(result, PyUserObj) {
            type_label = (result as PyUserObj).cls.name;
        }
        return py_error(
            "TypeError",
            "'async for' received an object from __aiter__ that does not implement __anext__: "
                + type_label
        );
    }
    return result;
}

# Resolve a value to the iterator GET_AWAITABLE / SEND drive (native coroutine,
# generator, native async-gen driver, or host awaitable). A plain generator is
# only admitted when its code carries CO_ITERABLE_COROUTINE -- the
# types.coroutine contract; unmarked generators are rejected exactly as
# CPython's GET_AWAITABLE).
def py_get_awaitable(value: PyObj) -> PyObj {
    if value.t == "coroutine" {
        return value;
    }
    if value.t == "generator" {
        gen = value as PyGenerator;
        if (gen.frame.co.flags & 256) != 0 {
            return value;
        }
        return py_error("TypeError", "'generator' object can't be awaited");
    }
    if value.t == "agen_asend" or value.t == "agen_athrow" {
        return value;
    }
    if value.t == "async_generator" {
        return py_error("TypeError", "object async_generator can't be used in 'await' expression");
    }
    if isinstance(value, PyHostProxy) {
        hp = value as PyHostProxy;
        resolved = _jac_host_resolve_awaitable(hp.val);
        if bool(resolved[0]) {
            # Directly drivable (native coroutine/generator send surface) or
            # already resolved through __await__(): keep the proxy; SEND drives
            # it via its own send/throw attribute surface.
            return PyHostProxy(t="host", val=resolved[1]);
        }
        return py_error("TypeError", str(resolved[2]));
    }
    return py_error("TypeError", "object can't be used in 'await' expression");
}

# `async for` loop step: call __anext__ on the async iterator and wrap the result
# as an awaitable for the following SEND loop.
def py_anext(aiter: PyObj) -> PyObj {
    if isinstance(aiter, PyUserObj)
        and user_has_dunder(aiter as PyUserObj, "__anext__") {
        result = call_user_dunder(aiter as PyUserObj, "__anext__", []);
    } else {
        method = py_attr(aiter, "__anext__");
        if is_error(method) {
            return method;
        }
        result = py_invoke(method, [], {});
    }
    if is_error(result) {
        return result;
    }
    return py_get_awaitable(result);
}

def py_len(value: PyObj) -> PyObj {
    if isinstance(value, PyRange) {
        return PyInt(t="int", val=(value as PyRange).length());
    }
    if isinstance(value, PyStr) {
        return PyInt(t="int", val=len((value as PyStr).val));
    }
    if isinstance(value, PyBytes) {
        return PyInt(t="int", val=len((value as PyBytes).val));
    }
    if isinstance(value, PyTuple) {
        return PyInt(t="int", val=len((value as PyTuple).items));
    }
    if isinstance(value, PyList) {
        return PyInt(t="int", val=len((value as PyList).items));
    }
    if isinstance(value, PyDict) {
        return PyInt(t="int", val=len((value as PyDict).items));
    }
    if isinstance(value, PySet) {
        return PyInt(t="int", val=len((value as PySet).items));
    }
    if isinstance(value, PyDictView) {
        return PyInt(t="int", val=len((value as PyDictView).d.items));
    }
    if isinstance(value, PyMappingProxy) {
        return py_len((value as PyMappingProxy).target as PyObj);
    }
    if isinstance(value, PyFrameLocalsProxy) {
        return PyInt(t="int", val=framelocals_len(value as PyFrameLocalsProxy));
    }
    if isinstance(value, PyUserObj) {
        u = value as PyUserObj;
        if user_has_dunder(u, "__len__") {
            res = call_user_dunder(u, "__len__", []);
            if is_error(res) {
                return res;
            }
            if isinstance(res, PyBool) {
                # bool IS an int subclass in CPython: True/False are valid lens.
                res = PyInt(t="int", val=1 if (res as PyBool).val else 0);
            }
            if isinstance(res, PyInt) {
                if (res as PyInt).val < 0 {
                    return py_error("ValueError", "__len__() should return >= 0");
                }
                return res;
            }
            return py_error("TypeError", "'__len__' should return an integer");
        }
        if u._has_base() {
            return py_len(u._base_obj());
        }
    }
    if isinstance(value, PyHostProxy) {
        # A proxied host object (e.g. a namedtuple instance produced by
        # tuple.__new__, or any C-extension container) answers len() on the host.
        hv_r = to_host_coerce(value);
        hv = hv_r[1];
        if not ((hv_r[0] as bool)) {
            return hv_r[1] as PyObj;
        }
        result = _jac_host_len(hv);
        if host_result_ok(result) {
            return from_host(result[1]);
        }
        return host_result_error(result);
    }
    return py_error("TypeError", "object of type '" + value.t + "' has no len()");
}

# CPython tp_flags bits (Include/object.h) used by MATCH_* opcodes.
glob _TPFLAGS_SEQUENCE: int = 32,
     _TPFLAGS_MAPPING: int = 64,
     _TPFLAGS_MATCH_SELF: int = 4194304,
     _match_keys_dummy: PyObj = py_none();

def match_keys_dummy -> PyObj {
    if _match_keys_dummy.t == "none" {
        built = _jac_construct_builtin("object", []);
        if host_result_ok(built) {
            _match_keys_dummy = from_host(built[1]);
        }
    }
    return _match_keys_dummy;
}

def py_type_has_sequence_flag(value: PyObj) -> bool {
    if value.t == "list" or value.t == "tuple" {
        return True;
    }
    if value.t == "str" or value.t == "bytes" {
        return False;
    }
    if isinstance(value, PyUserObj) {
        return obj_is_builtin(value, "list") or obj_is_builtin(value, "tuple");
    }
    if isinstance(value, PyHostProxy) {
        host_val = (value as PyHostProxy).val;
        if _jac_isinstance_of_builtin(host_val, "str")
            or _jac_isinstance_of_builtin(host_val, "bytes") {
            return False;
        }
        if _jac_type_has_flag(host_val, _TPFLAGS_SEQUENCE) {
            return True;
        }
        return (_jac_isinstance_of_builtin(host_val, "list")
            or _jac_isinstance_of_builtin(host_val, "tuple")) as bool;
    }
    return False;
}

def py_type_has_mapping_flag(value: PyObj) -> bool {
    if value.t == "dict" {
        return True;
    }
    if isinstance(value, PyUserObj) {
        return obj_is_builtin(value, "dict");
    }
    if isinstance(value, PyHostProxy) {
        host_val = (value as PyHostProxy).val;
        if _jac_type_has_flag(host_val, _TPFLAGS_MAPPING) {
            return True;
        }
        return _jac_isinstance_of_builtin(host_val, "dict") as bool;
    }
    return False;
}

def py_type_has_match_self_flag(type_obj: PyObj) -> bool {
    if isinstance(type_obj, PyHostProxy) {
        return _jac_type_has_flag((type_obj as PyHostProxy).val, _TPFLAGS_MATCH_SELF) as bool;
    }
    return False;
}

def match_class_type_name(type_obj: PyObj) -> str {
    if isinstance(type_obj, PyClass) {
        return (type_obj as PyClass).name;
    }
    # A host class pattern wraps the class itself; _jac_host_pattern_name
    # quotes its own name (not the metaclass's) like CPython's tp_name.
    if isinstance(type_obj, PyHostProxy) {
        return str(_jac_host_pattern_name((type_obj as PyHostProxy).val));
    }
    return "?";
}

def py_match_attr_optional(value: PyObj, name: str) -> PyObj {
    attr = py_attr(value, name);
    if is_error(attr) {
        if isinstance(attr, PyError)
            and (attr as PyError).exception.type_name == "AttributeError" {
            return py_none();
        }
        return attr;
    }
    return attr;
}

def py_match_type_attr_optional(type_obj: PyObj, name: str) -> PyObj {
    if isinstance(type_obj, PyClass) {
        found = class_lookup_attr(type_obj as PyClass, name);
        if not is_error(found) {
            return found;
        }
        if isinstance(found, PyError)
            and (found as PyError).exception.type_name == "AttributeError" {
            return py_none();
        }
        return found;
    }
    return py_match_attr_optional(type_obj, name);
}

def py_match_class_attr(
    subject: PyObj, type_obj: PyObj, name: PyObj, seen: PySet
) -> PyObj {
    if not isinstance(name, PyStr) {
        return py_error(
            "TypeError", "__match_args__ elements must be strings (got " + name.t + ")",
        );
    }
    if seen.set_contains(name) {
        return py_error(
            "TypeError",
            match_class_type_name(type_obj)
                + "() got multiple sub-patterns for attribute "
                + dict_key_repr(name),
        );
    }
    seen.set_add(name);
    attr = py_match_attr_optional(subject, (name as PyStr).val);
    if is_error(attr) {
        return attr;
    }
    if attr.t == "none" {
        return py_none();
    }
    return attr;
}

def py_match_keys(map_obj: PyObj, keys: PyObj) -> PyObj {
    if not isinstance(keys, PyTuple) {
        return py_error("TypeError", "MATCH_KEYS keys must be a tuple");
    }
    key_items = (keys as PyTuple).items;
    nkeys = len(key_items);
    if nkeys == 0 {
        return PyTuple(t="tuple", items=[]);
    }
    get_m = py_attr(map_obj, "get");
    if is_error(get_m) {
        return get_m;
    }
    dummy = match_keys_dummy();
    seen = PySet(t="set", items={}, frozen=False);
    values: list[PyObj] = [];
    ki = 0;
    while ki < nkeys {
        key = key_items[ki];
        if seen.set_contains(key) {
            return py_error(
                "ValueError",
                "mapping pattern checks duplicate key (" + dict_key_repr(key) + ")",
            );
        }
        seen.set_add(key);
        val = py_invoke(get_m, [key, dummy], {});
        if is_error(val) {
            return val;
        }
        if val is dummy {
            return py_none();
        }
        values.append(val);
        ki = ki + 1;
    }
    return PyTuple(t="tuple", items=values);
}

def py_match_class(
    subject: PyObj, type_obj: PyObj, nargs: int, kw_names: PyObj
) -> PyObj {
    if not isinstance(type_obj, PyClass) and not isinstance(type_obj, PyHostProxy) {
        return py_error("TypeError", "called match pattern must be a class");
    }
    if not isinstance(kw_names, PyTuple) {
        return py_error("TypeError", "MATCH_CLASS names must be a tuple");
    }
    if not py_isinstance(subject, type_obj) {
        return py_none();
    }
    seen = PySet(t="set", items={}, frozen=False);
    attrs_list: list[PyObj] = [];
    if nargs > 0 {
        match_args_obj = py_match_type_attr_optional(type_obj, "__match_args__");
        if is_error(match_args_obj) {
            return match_args_obj;
        }
        match_self = 0;
        match_args: PyTuple;
        if match_args_obj.t == "none" {
            match_args = PyTuple(t="tuple", items=[]);
            if py_type_has_match_self_flag(type_obj) {
                match_self = 1;
            }
        } else {
            if not isinstance(match_args_obj, PyTuple) {
                got = match_args_obj.t;
                if isinstance(match_args_obj, PyHostProxy) {
                    got = str(_jac_host_type_name((match_args_obj as PyHostProxy).val));
                }
                return py_error(
                    "TypeError",
                    match_class_type_name(type_obj)
                        + ".__match_args__ must be a tuple (got "
                        + got
                        + ")",
                );
            }
            match_args = match_args_obj as PyTuple;
        }
        allowed = len(match_args.items);
        if match_self {
            allowed = 1;
        }
        if allowed < nargs {
            plural = "s";
            if allowed == 1 {
                plural = "";
            }
            return py_error(
                "TypeError",
                match_class_type_name(type_obj)
                    + "() accepts "
                    + str(allowed)
                    + " positional sub-pattern"
                    + plural
                    + " ("
                    + str(nargs)
                    + " given)",
            );
        }
        if match_self {
            attrs_list.append(subject);
        } else {
            pi = 0;
            while pi < nargs {
                name = match_args.items[pi];
                attr = py_match_class_attr(subject, type_obj, name, seen);
                if is_error(attr) {
                    return attr;
                }
                if attr.t == "none" {
                    return py_none();
                }
                attrs_list.append(attr);
                pi = pi + 1;
            }
        }
    }
    kw_tuple = kw_names as PyTuple;
    ki = 0;
    while ki < len(kw_tuple.items) {
        name = kw_tuple.items[ki];
        attr = py_match_class_attr(subject, type_obj, name, seen);
        if is_error(attr) {
            return attr;
        }
        if attr.t == "none" {
            return py_none();
        }
        attrs_list.append(attr);
        ki = ki + 1;
    }
    return PyTuple(t="tuple", items=attrs_list);
}

# Materialize a host iterable (range, dict-view, map/filter object, ...) into a
# native PyIter so GET_ITER/FOR_ITER drive it without a host round-trip per step.
def host_iter(value: PyHostProxy) -> PyObj {
    result = _jac_host_iter(value.val);
    if host_result_ok(result) {
        items: list[PyObj] = [];
        for item in result[1] {
            items.append(from_host(item));
        }
        return PyIter(t="iter", items=items, index=0);
    }
    return host_result_error(result);
}

# The PyObj yielded by a dict iterator at its current position: the key (keys),
# the value (values), or a (key, value) PyTuple (items). The caller has already
# confirmed the iterator is not stale, so the hashkey is still present.
def dictiter_yield(di: PyDictIter) -> PyObj {
    hk = di.keys[di.index];
    `entry = di.d.items[hk];
    if di.mode == "values" {
        return `entry.value;
    }
    if di.mode == "items" {
        return PyTuple(t="tuple", items=[`entry.key, `entry.value]);
    }
    return `entry.key;
}

def dictiter_error -> PyObj {
    return py_error("RuntimeError", "dictionary changed size during iteration");
}

# CPython 3.11+ indexes LOAD_FAST / *_DEREF / MAKE_CELL into a single merged
# "localsplus" array laid out as [varnames(nlocals)] [cellvars-not-already-a-var]
# [freevars]. This VM mirrors that with ONE physical array (frame.fast): entries
# hold a plain value OR a PyCell -- cells live IN their slots, seeded at frame
# setup and extended mid-frame by OP_MAKE_CELL (inlined comprehensions), which
# is what makes per-execution fresh comprehension cells possible. resolve_cell
# reads the slot directly; there is deliberately NO static name->cell map (a
# static map pins one cell per name per frame, clobbering cells captured by
# earlier comprehension runs).
def resolve_cell(fast: list[PyObj], arg: int) -> PyCell | None {
    if arg < len(fast) and isinstance(fast[arg], PyCell) {
        return fast[arg] as PyCell;
    }
    return None;
}

# Name of merged-localsplus slot `arg`: [varnames] [cellvars not shadowing a
# varname, in cellvar order] [freevars] -- the layout frame setup builds.
def localsplus_name(co: PyCode, arg: int) -> str {
    nv = len(co.varnames);
    if arg < nv {
        return co.varnames[arg];
    }
    off = nv;
    ci = 0;
    while ci < len(co.cellvars) {
        if find_name(co.varnames, co.cellvars[ci]) < 0 {
            if arg == off {
                return co.cellvars[ci];
            }
            off = off + 1;
        }
        ci = ci + 1;
    }
    return co.freevars[arg - off];
}

# CPython _PyEval_FormatExcUnbound (Python/ceval.c): a localsplus index below
# the free region is an UnboundLocalError; at or above it, the free-variable
# NameError. Message text byte-exact with the host.
def format_exc_unbound(co: PyCode, arg: int) -> PyObj {
    lpname = localsplus_name(co, arg);
    ncell = 0;
    ci = 0;
    while ci < len(co.cellvars) {
        if find_name(co.varnames, co.cellvars[ci]) < 0 {
            ncell = ncell + 1;
        }
        ci = ci + 1;
    }
    if arg < len(co.varnames) + ncell {
        return py_error(
            "UnboundLocalError",
            "cannot access local variable '" + lpname + "' where it is not associated with a value",
        );
    }
    return py_error(
        "NameError",
        "cannot access free variable '" + lpname + "' where it is not associated with a value in enclosing scope",
    );
}

def fast_value(co: PyCode, arg: int, fast: list[PyObj]) -> PyObj {
    # A converted (cell) slot yields the CELL OBJECT -- that is how LOAD_FAST /
    # LOAD_FAST_BORROW fetch a live cell to seed an inner function's closure
    # (CPython's GETLOCAL returns whatever lives in the slot). A plain local
    # yields its value.
    if arg < len(fast) {
        return fast[arg];
    }
    return py_error("UnboundLocalError", "local variable is not set");
}

def fast_value_check(
    co: PyCode,
    arg: int,
    fast: list[PyObj],
    assigned: list[bool],
) -> PyObj {
    # LOAD_FAST_CHECK: like LOAD_FAST but raises UnboundLocalError when the
    # plain-local slot was never STORE_FAST-bound (CPython 3.14+ null check).
    # Converted (cell) slots are always bound.
    if arg >= len(fast) {
        return py_error("UnboundLocalError", "local variable is not set");
    }
    if isinstance(fast[arg], PyCell) {
        return fast[arg];
    }
    if arg < len(assigned) and not assigned[arg] {
        vname = "?";
        if arg < len(co.varnames) {
            vname = co.varnames[arg];
        }
        return py_error(
            "UnboundLocalError",
            "cannot access local variable '"
                + vname
                + "' where it is not associated with a value",
        );
    }
    return fast[arg];
}

def user_exception_view(u: PyUserObj) -> PyException {
    exc_args: list[PyObj] = [];
    stored = u.attrs.get("args");
    if isinstance(stored, PyTuple) {
        exc_args.extend((stored as PyTuple).items);
    }
    # Resolve the nearest builtin exception ancestor (class MyErr(KeyError) ->
    # "KeyError") so per-type __str__/attribute semantics inherited from the
    # builtin base apply to the wrapper view exactly like CPython's slots.
    family: str = "";
    for klass in class_mro(u.cls) {
        for base in klass.bases {
            if isinstance(base, PyExceptionType) {
                family = (base as PyExceptionType).name;
            } elif isinstance(base, PyHostProxy)
                and bool(_jac_is_exception_type((base as PyHostProxy).val)) {
                family = _jac_host_class_name((base as PyHostProxy).val) as str;
            }
        }
        if family != "" {
            break;
        }
    }
    return PyException(
        t="exception", type_name=u.cls.name, message="", args=exc_args,
        family=family, value=stopiter_value_from_args(family, u.cls.name, exc_args)
    );
}

# CPython stopiteration_init: a StopIteration instance (or subclass instance)
# records args[0] as .value at construction. User subclasses raise through the
# PyUserObj wrapper view, so derive the payload there too -- yield-from
# unwinding reads exc.value off this view.
def stopiter_value_from_args(family: str, name: str, args: list[PyObj]) -> PyObj {
    if name == "StopIteration" or family == "StopIteration"
        or exc_is_subclass_of(name, "StopIteration")
        or (family != "" and exc_is_subclass_of(family, "StopIteration")) {
        if len(args) > 0 {
            return args[0];
        }
    }
    return py_none();
}

# True iff a raised exception IS StopIteration or derives from it -- the
# exhaustion test every yield-from unwinding performs (genobject.c uses
# PyErr_ExceptionMatches(PyExc_StopIteration)). Builtin names resolve through
# the name-level tree; user subclasses through the wrapper view's family.
def exc_is_stopiter(exc: PyException) -> bool {
    return exc_name_matches(exc.type_name, "StopIteration")
        or (exc.family != "" and exc_name_matches(exc.family, "StopIteration"));
}

def py_raise_value(value: PyObj) -> PyObj {
    if value.t == "exception" {
        return PyError(t="error", exception=value as PyException);
    }
    if value.t == "exception_type" {
        typ = value as PyExceptionType;
        return PyError(
            t="error",
            exception=PyException(t="exception", type_name=typ.name, message="")
        );
    }
    # A raised user exception instance (class Exc(Exception); raise Exc()) surfaces
    # as a PyException tagged with the user class name, keeping the instance in
    # `raw` so `except <UserClass>` can match it by MRO. The wrapper's args mirror
    # the args the instance recorded at construction time (PyClass.tp_call stores
    # them for exception-derived classes, matching CPython's BaseException_new),
    # so str(e)/repr(e)/e.args on a caught user exception see real arguments.
    if isinstance(value, PyUserObj) {
        u = value as PyUserObj;
        if class_is_exception(u.cls) {
            view = user_exception_view(u);
            # Keep the instance so `except <UserClass>` can match by MRO.
            view.raw = value;
            return PyError(t="error", exception=view);
        }
    }
    # A raised exception CLASS (raise Exc) auto-instantiates, then re-raises.
    if isinstance(value, PyClass) and class_is_exception(value as PyClass) {
        instance = (value as PyClass).tp_call([], {});
        if is_error(instance) {
            return instance;
        }
        # CPython do_raise contract: calling the class must yield a real
        # BaseException INSTANCE (a subclass instance passes -- MRO-aware).
        # A broken __new__ that returns the class itself (or an unrelated
        # object) must TypeError here; recursing on the same input would
        # loop forever (gen.throw(E) VM-crash fingerprint).
        if isinstance(instance, PyClass)
            or (isinstance(instance, PyUserObj)
                and not instance_of_class(instance as PyUserObj, value as PyClass)) {
            return py_error(
                "TypeError", "should have returned an instance of BaseException"
            );
        }
        return py_raise_value(instance);
    }
    if isinstance(value, PyHostProxy) {
        raw = (value as PyHostProxy).val;
        if bool(_jac_is_exception_type(raw)) {
            return PyError(
                t="error",
                exception=PyException(
                    t="exception", type_name=str(_jac_host_class_name(raw)), message=""
                )
            );
        }
        inst = _jac_host_exception_instance(raw);
        if bool(inst[0]) {
            return PyError(
                t="error",
                exception=PyException(
                    t="exception",
                    type_name=str(inst[1]),
                    message=str(inst[2]),
                    args=inst[3],
                    raw=value
                )
            );
        }
    }
    return py_error("TypeError", "exceptions must derive from BaseException");
}

def py_call_host(
    fn: PyHostProxy, args: list[PyObj], kwargs: dict[str, PyObj]
) -> PyObj {
    # An unbound builtin-method descriptor called with a NATIVE container as
    # receiver (list.append(lst, x), dict.get(d, k)) must operate on the real
    # native storage: marshaling through to_host hands the host a COPY, so the
    # call would silently no-op for mutators. Dispatch natively instead.
    info = _jac_host_unbound_method_info(fn.val);
    if bool(info[0]) and len(args) > 0 {
        owner = str(info[1]);
        meth = str(info[2]);
        recv = args[0];
        rest: list[PyObj] = [];
        i = 1;
        while i < len(args) {
            rest.append(args[i]);
            i = i + 1;
        }
        if owner == "list" and isinstance(recv, PyList) and is_list_method(meth) {
            return PyListMethod(t="list_method", target=(recv as PyList), name=meth).tp_call(rest, kwargs);
        }
        if owner == "dict" and isinstance(recv, PyDict) and is_dict_method(meth) {
            return PyDictMethod(t="dict_method", target=(recv as PyDict), name=meth).tp_call(rest, kwargs);
        }
        if owner == "set" and isinstance(recv, PySet) and is_set_method(meth, (recv as PySet).frozen) {
            return PySetMethod(t="set_method", target=(recv as PySet), name=meth).tp_call(rest, kwargs);
        }
    }
    # The `list` constructor consults iteration IN-VM before any bridge attempt:
    # to_host drops plain user objects (a generator/user iterable marshals as
    # None and host list(None) fails with the misleading 'NoneType' error while
    # iter(same object) works -- family-C bridge-first call site). py_iter sees
    # tp_iter/__iter__/boxed bases; on error fall through to the host call,
    # which stays authoritative for host-only iterables (dict views) and raises
    # the exact CPython TypeError for non-iterables.
    if len(args) == 1 and len(kwargs) == 0 and _jac_builtin_base_name(fn.val) == "list" {
        it = py_iter(args[0]);
        if not is_error(it) {
            return drain_to_list(it);
        }
    }
    # The `range` constructor builds a native PyRange in-VM: identity + laziness
    # (TODO item 19). Args must each be int-like (to_index unwraps bool and
    # boxed-int subclasses); ANY other arg shape -- non-int args, wrong arity,
    # keyword args, step == 0 -- falls through to the host call so error
    # messages stay byte-exact CPython.
    if len(kwargs) == 0 and _jac_is_range_type(fn.val)
        and (len(args) > 0 and len(args) < 4) {
        vals: list[int] = [];
        all_int = True;
        for a in args {
            iv = a.to_index();
            if is_error(iv) or not isinstance(iv, PyInt) {
                all_int = False;
                break;
            }
            vals.append((iv as PyInt).val);
        }
        if all_int {
            if len(args) == 1 {
                return PyRange(t="range", start=0, stop=vals[0], step=1);
            }
            if len(args) == 2 {
                return PyRange(t="range", start=vals[0], stop=vals[1], step=1);
            }
            if vals[2] != 0 {
                return PyRange(t="range", start=vals[0], stop=vals[1], step=vals[2]);
            }
        }
    }
    # repr()/format()/print() stringify their NATIVE operands in-VM BEFORE any
    # bridge attempt -- same family-C call-site rule as the list ctor above:
    # to_host of a plain user object is None, so the host builtin would answer
    # repr(None)/format(None, spec)/print(None) on a lost value. Anything that
    # is not a single native operand (arity errors, non-str format specs,
    # keyword-only shapes) falls through to the host call so error messages
    # stay byte-exact CPython.
    if len(kwargs) == 0 and len(args) == 1 and _jac_is_builtin_func(fn.val, "repr") {
        return py_repr(args[0]);
    }
    if len(kwargs) == 0 and len(args) == 1 and _jac_is_builtin_func(fn.val, "str") {
        return py_str(args[0]);
    }
    if len(kwargs) == 0 and len(args) >= 1 and len(args) <= 2
        and _jac_is_builtin_func(fn.val, "format")
        and (len(args) == 1 or isinstance(args[1], PyStr)) {
        spec = "";
        if len(args) == 2 {
            spec = (args[1] as PyStr).val;
        }
        return host_format(args[0], spec);
    }
    if _jac_is_builtin_func(fn.val, "print") {
        # print() applies str() to every positional argument natively
        # (PyObject_Str semantics); sep/end/file/flush kwargs pass through.
        printed: list[PyObj] = [];
        for item in args {
            s = py_str(item);
            if is_error(s) {
                return s;
            }
            printed.append(s);
        }
        args = printed;
    }
    raw_args: list[any] = [];
    for item in args {
        hi_r = to_host_coerce(item);
        hi = hi_r[1];
        if not ((hi_r[0] as bool)) {
            return hi_r[1] as PyObj;
        }
        raw_args.append(hi);
    }
    raw_kwargs: dict[str, any] = {};
    for key in kwargs {
        hk_r = to_host_coerce(kwargs[key]);
        hk = hk_r[1];
        if not ((hk_r[0] as bool)) {
            return hk_r[1] as PyObj;
        }
        raw_kwargs[key] = hk;
    }
    result = _jac_host_call(fn.val, raw_args, raw_kwargs);
    if host_result_ok(result) {
        return from_host(result[1]);
    }
    return host_result_error(result);
}

def py_invoke(fn: PyObj, args: list[PyObj], kwargs: dict[str, PyObj]) -> PyObj {
    # A pending error flowing into a call site propagates unchanged; every real
    # callable resolves through its tp_call slot (function/class/bound method/
    # exception type/host proxy/build-class), never a tag switch.
    if fn.t == "error" {
        return fn;
    }
    return fn.tp_call(args, kwargs);
}

# callable(): mirrors the tp_call slot presence. User instances are callable
# iff their MRO resolves __call__ (or they box a callable builtin base);
# host proxies delegate the probe to the wrapped value.
def obj_is_callable(x: PyObj) -> bool {
    if isinstance(x, (PyFunction, PyNativeBuiltin, PyClass, PyExceptionType,
                      PyBoundMethod, PyClassMethodCtor, PyStaticMethodCtor,
                      PyListMethod, PyDictMethod, PySetMethod, PyRangeMethod,
                      PyNsMethod, PyGenMethod, PyBuiltinSuperMethod, PyStrMethod)) {
        return True;
    }
    if isinstance(x, PyUserObj) {
        u = x as PyUserObj;
        if user_has_dunder(x, "__call__") {
            return True;
        }
        if u._has_base() {
            return obj_is_callable(u._base_obj());
        }
        return False;
    }
    if isinstance(x, PyHostProxy) {
        return (_jac_host_is_callable((x as PyHostProxy).val)) as bool;
    }
    return False;
}

# ---------------- Track B: builtin subclassing support -----------------------

# True iff the class's metaclass chain derives from an in-VM ABCMeta: any
# metaclass ancestor defines BOTH register and __subclasshook__ (the Lib/abc.py
# ABCMeta surface). Gates ABC-aware standin minting -- host C
# ABCMeta.__subclasscheck__ cannot see guest MROs, so such standins need the
# native check (_JacABCMeta).
def class_has_abc_meta(cls: PyClass) -> bool {
    meta = cls.metaclass;
    if meta is None or not isinstance(meta, PyClass) {
        return False;
    }
    for klass in class_mro(meta as PyClass) {
        if "register" in (klass as PyClass).attrs
            and "__subclasshook__" in (klass as PyClass).attrs {
            return True;
        }
    }
    return False;
}

# C3 linearization: L[C] = C + merge(L[B1], ..., L[Bn], [B1, ..., Bn]). This gives
# the strict CPython MRO -- a diamond D(B, C) with B,C : A resolves [D, B, C, A],
# so an attribute on both A and C picks C, not A. An inconsistent hierarchy (no
# valid linearization) degrades to the partial order computed so far rather than
# looping. Only PyClass bases participate; a native/host base is not a node here.
def class_mro(cls: PyClass) -> list[PyClass] {
    seqs: list[list[PyClass]] = [];
    direct: list[PyClass] = [];
    for base in cls.bases {
        if isinstance(base, PyClass) {
            seqs.append(class_mro(base as PyClass));
            direct.append(base as PyClass);
        }
    }
    if len(direct) > 0 {
        seqs.append(direct);
    }
    result: list[PyClass] = [cls];
    for klass in c3_merge(seqs) {
        result.append(klass);
    }
    return result;
}

# The full CPython MRO: class_mro's linearization plus the terminal object.
# class_mro stops at the last user class, but CPython's __mro__/mro() end with
# object -- appended here as the same host-object proxy the guest sees for the
# global name `object`, so display matches isinstance/issubclass semantics
# (both answer True for that proxy via obj_is_builtin).
#
# Host-type bases (__mro_entries__ replacements like `dict`, or explicit host
# base classes) participate in the linearization as opaque nodes: each expands
# to its own host MRO chain (minus the terminal object), and a shared
# PyObj-level C3 merge orders everything.
def class_full_mro(cls: PyClass) -> list[PyObj] {
    seqs: list[list[PyObj]] = [];
    direct: list[PyObj] = [];
    has_host_base = False;
    for base in cls.bases {
        if isinstance(base, PyClass) {
            # Bare linearization only -- the terminal object is appended once,
            # globally, after the merged order.
            sub: list[PyObj] = [];
            for k in class_mro(base as PyClass) {
                sub.append(k);
            }
            seqs.append(sub);
            direct.append(base);
        } elif isinstance(base, PyHostProxy)
            and _jac_host_val_is_type((base as PyHostProxy).val) {
            has_host_base = True;
            seqs.append(host_type_mro_chain(base));
            direct.append(base);
        }
        # Non-class non-host bases cannot appear post-update_build_class_bases.
    }
    if len(direct) > 0 {
        seqs.append(direct);
    }
    result: list[PyObj] = [cls];
    if has_host_base {
        for klass in c3_merge_objs(seqs) {
            result.append(klass);
        }
    } else {
        # Pure guest-class chain: reuse the established PyClass merge.
        pc_seqs: list[list[PyClass]] = [];
        for s in seqs {
            row: list[PyClass] = [];
            for x in s {
                if isinstance(x, PyClass) {
                    row.append(x as PyClass);
                }
            }
            pc_seqs.append(row);
        }
        for klass in c3_merge(pc_seqs) {
            result.append(klass);
        }
    }
    result.append(host_builtin("object"));
    return result;
}

# The MRO contribution of a host type base: the type itself plus its host
# ancestors, excluding the terminal object (appended once globally).
def host_type_mro_chain(base: PyObj) -> list[PyObj] {
    raw = (base as PyHostProxy).val;
    chain: list[PyObj] = [];
    for t in _jac_host_type_mro(raw) {
        if _jac_host_val_is_object_type(t) {
            continue;
        }
        chain.append(PyHostProxy(t="host", val=t));
    }
    return chain;
}

# Merge step of C3: repeatedly take the head of some sequence that appears in no
# other sequence's tail, append it, and strip it from every head. Stops when all
# sequences drain (success) or no valid head exists (inconsistent -> partial).
def c3_merge(seqs: list[list[PyClass]]) -> list[PyClass] {
    work: list[list[PyClass]] = [];
    for s in seqs {
        row: list[PyClass] = [];
        for x in s {
            row.append(x);
        }
        work.append(row);
    }
    result: list[PyClass] = [];
    while True {
        live: list[list[PyClass]] = [];
        for s in work {
            if len(s) > 0 {
                live.append(s);
            }
        }
        if len(live) == 0 {
            return result;
        }
        chosen: PyClass | None = None;
        for s in live {
            head = s[0];
            in_tail = False;
            for other in live {
                k = 1;
                while k < len(other) {
                    if other[k] is head {
                        in_tail = True;
                    }
                    k = k + 1;
                }
            }
            if not in_tail {
                chosen = head;
                break;
            }
        }
        if chosen is None {
            return result;
        }
        result.append(chosen);
        for s in live {
            if len(s) > 0 and s[0] is chosen {
                s.pop(0);
            }
        }
        work = live;
    }
    return result;
}

# C3 over mixed nodes (guest PyClass + host-type proxies). Same algorithm as
# c3_merge at PyObj identity; host proxies compare by underlying type via `is`
# on the raw value so repeated ancestors dedupe correctly.
def c3_merge_objs(seqs: list[list[PyObj]]) -> list[PyObj] {
    work: list[list[PyObj]] = [];
    for s in seqs {
        row: list[PyObj] = [];
        for x in s {
            row.append(x);
        }
        work.append(row);
    }
    result: list[PyObj] = [];
    while True {
        live: list[list[PyObj]] = [];
        for s in work {
            if len(s) > 0 {
                live.append(s);
            }
        }
        if len(live) == 0 {
            return result;
        }
        chosen: PyObj | None = None;
        for s in live {
            head = s[0];
            in_tail = False;
            for other in live {
                k = 1;
                while k < len(other) {
                    if _jac_mro_node_is(other[k], head) {
                        in_tail = True;
                    }
                    k = k + 1;
                }
            }
            if not in_tail {
                chosen = head;
                break;
            }
        }
        if chosen is None {
            # Inconsistent merge (host/guest cycles cannot occur): stop at the
            # longest consistent prefix, like the PyClass merge does.
            return result;
        }
        result.append(chosen);
        for s in live {
            if len(s) > 0 and _jac_mro_node_is(s[0], chosen) {
                s.pop(0);
            }
        }
        work = live;
    }
    return result;
}

def _jac_mro_node_is(a: PyObj, b: PyObj) -> bool {
    if a is b {
        return True;
    }
    if isinstance(a, PyHostProxy) and isinstance(b, PyHostProxy) {
        raw_a = (a as PyHostProxy).val;
        raw_b = (b as PyHostProxy).val;
        return _jac_host_val_same(raw_a, raw_b);
    }
    return False;
}

def class_lookup_attr(cls: PyClass, name: str) -> PyObj {
    for klass in class_mro(cls) {
        if name in klass.attrs {
            return klass.attrs[name];
        }
    }
    return py_error("AttributeError", name);
}

# ---------------- dir(): CPython attribute enumeration -----------------------

# CPython's dir(obj) for a non-module object is a sorted union of __dict__ keys
# across obj's type MRO (for instances) or the class's own MRO (for classes),
# plus the instance's own __dict__ when present. Two native gaps need filling
# to stay byte-exact with the host: the terminal `object` (and any boxed
# builtin base like int/Exception) contributes its HOST type-dict surface, and
# a dict-bearing user class's own dict carries synthesized `__dict__` /
# `__weakref__` descriptors the VM never stores in attrs.
def py_dir_add_surface(names: dict[str, bool], kind: str) -> PyObj {
    surface = _jac_host_type_surface(kind);
    if host_result_ok(surface) {
        for k in (surface[1] as list[str]) {
            names[k] = True;
        }
        return py_none();
    }
    return host_result_error(surface);
}

def py_dir_add_class(names: dict[str, bool], cls: PyClass) -> PyObj {
    # Namespace entries CPython's type.__new__ never lets reach the class dict:
    # __name__/__qualname__ are stripped at class creation (answered via slot
    # access instead), and __classdictcell__ is this VM's internal anchor for
    # method-scope class references. Emitting them would diverge from host
    # dir(cls)/dir(instance).
    skip_names: dict[str, bool] = {"__name__": True, "__qualname__": True, "__classdictcell__": True};
    for klass in class_mro(cls) {
        for k in klass.attrs.keys() {
            if k not in skip_names {
                names[k] = True;
            }
        }
        # A dict-bearing heap class owns __dict__/__weakref__ member
        # descriptors in CPython; the VM models them implicitly.
        if klass.instance_has_dict {
            names["__dict__"] = True;
            names["__weakref__"] = True;
        }
    }
    if cls.native_base != "" {
        err = py_dir_add_surface(names, cls.native_base);
        if is_error(err) {
            return err;
        }
    }
    return py_dir_add_surface(names, "object");
}

def py_dir_sorted(names: dict[str, bool]) -> PyObj {
    items: list[PyObj] = [];
    for k in names {
        items.append(PyStr(t="str", val=k));
    }
    return builtin_sorted_min_max(
        "sorted", [PyList(t="list", items=items)], {}
    );
}

# dir(arg): one argument. Order mirrors CPython builtin_dir -- a type-level
# __dir__ override wins, then modules answer from their namespace, then the
# generic MRO/__dict__ union. Host-backed values (proxies and faithful native
# scalars/containers) defer to the host interpreter so their name lists are
# byte-exact by construction.
def py_dir(arg: PyObj) -> PyObj {
    # __dir__ override lookup: on the INSTANCE's class, or on a CLASS's
    # metaclass (a body-defined __dir__ serves instances of that class, never
    # the class itself). The result is iterated exactly like CPython -- a
    # non-iterable result surfaces the iteration TypeError unchanged.
    owner: PyClass | None = None;
    if isinstance(arg, PyUserObj) {
        owner = (arg as PyUserObj).cls;
    } elif isinstance(arg, PyClass) {
        mc = (arg as PyClass).metaclass;
        if isinstance(mc, PyClass) {
            owner = mc as PyClass;
        }
    }
    if owner is not None {
        d = class_lookup_attr(owner, "__dir__");
        if not is_error(d) {
            res = bind_attribute(d, arg).tp_call([], {});
            if is_error(res) {
                return res;
            }
            items = members_of(res);
            if is_error(items) {
                return items;
            }
            return builtin_sorted_min_max("sorted", [items], {});
        }
    }
    if isinstance(arg, PyModule) {
        names: dict[str, bool] = {};
        for k in (arg as PyModule).attrs.keys() {
            names[k] = True;
        }
        return py_dir_sorted(names);
    }
    if isinstance(arg, PyHostProxy) {
        r = _jac_host_dir((arg as PyHostProxy).val);
        if host_result_ok(r) {
            strs: list[PyObj] = [];
            for n in (r[1] as list[str]) {
                strs.append(PyStr(t="str", val=n));
            }
            return PyList(t="list", items=strs);
        }
        return host_result_error(r);
    }
    # Native scalars/containers marshal faithfully across the bridge, so the
    # host's own dir() IS the correct enumeration (dir([1]) == host dir of a
    # real list). User objects/classes must NOT cross here -- to_host loses
    # them -- they fall through to the native walks below.
    tag = arg.t;
    if tag == "none" or tag == "bool" or tag == "int" or tag == "float"
        or tag == "complex" or tag == "str" or tag == "bytes" or tag == "tuple"
        or tag == "list" or tag == "dict" or tag == "set" or tag == "frozenset"
        or tag == "slice" or tag == "range" or tag == "notimplemented"
        or tag == "dictview_obj" {
        h_r = to_host_coerce(arg);
        if not ((h_r[0] as bool)) {
            return h_r[1] as PyObj;
        }
        hd = _jac_host_dir(h_r[1]);
        if host_result_ok(hd) {
            strs2: list[PyObj] = [];
            for n2 in (hd[1] as list[str]) {
                strs2.append(PyStr(t="str", val=n2));
            }
            return PyList(t="list", items=strs2);
        }
        return host_result_error(hd);
    }
    if isinstance(arg, PyException) {
        names_exc: dict[str, bool] = {};
        err_exc = py_dir_add_surface(names_exc, "BaseException");
        if is_error(err_exc) {
            return err_exc;
        }
        return py_dir_sorted(names_exc);
    }
    if isinstance(arg, PyClass) {
        names_cls: dict[str, bool] = {};
        err_cls = py_dir_add_class(names_cls, arg as PyClass);
        if is_error(err_cls) {
            return err_cls;
        }
        return py_dir_sorted(names_cls);
    }
    if isinstance(arg, PyUserObj) {
        u = arg as PyUserObj;
        names_u: dict[str, bool] = {};
        for k in u.attrs.keys() {
            names_u[k] = True;
        }
        err_u = py_dir_add_class(names_u, u.cls);
        if is_error(err_u) {
            return err_u;
        }
        return py_dir_sorted(names_u);
    }
    if isinstance(arg, PyFunction) {
        f = arg as PyFunction;
        names_f: dict[str, bool] = {};
        for k in f.attrs.keys() {
            names_f[k] = True;
        }
        err_f = py_dir_add_surface(names_f, "function");
        if is_error(err_f) {
            return err_f;
        }
        return py_dir_sorted(names_f);
    }
    # Unknown native shape: only the shared object surface is knowable.
    names_obj: dict[str, bool] = {};
    err_obj = py_dir_add_surface(names_obj, "object");
    if is_error(err_obj) {
        return err_obj;
    }
    return py_dir_sorted(names_obj);
}

# super().name lookup: search the instance's MRO starting AFTER the defining
# class (zero-arg super semantics). defining_cls comes from the __class__ cell;
# if it isn't a PyClass, fall back to the instance's own class.
# `builtin.__new__(cls, *box_args)` reached through super() from a subclass's
# own __new__ (e.g. re._constants._NamedIntConstant, IntEnum members). The first
# arg is the class to instantiate; the rest box the builtin base. Returns a
# PyUserObj tagged with that class so the subclass's identity and attributes
# (a .name set right after) survive -- exactly the value/ref line Track B draws.
# super().__init__/__str__/__repr__ inside a user exception subclass's method.
# Exception is not a boxed-layout native base (native_base stays ""), so there
# is no boxed value to delegate to -- these run BaseException's own slot
# semantics directly over the live instance, exactly like CPython's inherited
# BaseException slots.
obj PyExcSuperSlot(PyObj) {
    has target: PyObj,
        name: str;

    def tp_call(args: list[PyObj], kwargs: dict[str, PyObj]) -> PyObj {
        u = self.target as PyUserObj;
        if self.name == "__init__" {
            # CPython BaseException_init: replaces args wholesale.
            if len(kwargs) > 0 {
                return py_error(
                    "TypeError", "__init__() takes no keyword arguments"
                );
            }
            stored: list[PyObj] = [];
            stored.extend(args);
            u.attrs["args"] = PyTuple(t="tuple", items=stored);
            return py_none();
        }
        view = user_exception_view(u);
        if self.name == "__str__" {
            return baseexception_str(view, py_repr, py_str);
        }
        if self.name == "__repr__" {
            return baseexception_repr(view, py_repr);
        }
        return py_error("AttributeError", self.name);
    }
}

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
obj PyBuiltinSuperMethod(PyObj) {
    # The boxed base value, or the PyNoneType sentinel for a base-less class.
    has base: PyObj,
        name: str,
        # The subclass instance this super() binding came from. __getitem__ on
        # a boxed dict base must consult the OWNER's type-level __missing__ on
        # a miss (CPython dict.__getitem__ does), which needs the instance's
        # class -- not just the boxed storage; the base-less object surface
        # builds object.__repr__ from it.
        owner: PyObj = py_none();

    def tp_call(args: list[PyObj], kwargs: dict[str, PyObj]) -> PyObj {
        n = self.name;
        b = self.base;
        boxed = not isinstance(b, PyNoneType);
        if not boxed {
            # object-surface fallback (MRO exhausted above a base-less class).
            if n == "__repr__" {
                return PyStr(t="str", val=default_obj_repr_text(self.owner as PyUserObj));
            }
            if n == "__str__" {
                # object.__str__ IS object.__repr__ (the identity form).
                return PyStr(t="str", val=default_obj_repr_text(self.owner as PyUserObj));
            }
            if n == "__init__" {
                if len(args) == 0 {
                    return py_none();
                }
                return py_error(
                    "TypeError",
                    "object.__init__() takes exactly one argument (the instance to initialize)"
                );
            }
            return py_error(
                "AttributeError", "'super' object has no attribute '" + n + "'"
            );
        }
        if n == "__init__" {
            # super().__init__(...) on a boxed builtin base runs the base's OWN
            # initializer over the live boxed storage -- in CPython terms the
            # MRO-resolved __init__ IS set_init/list_init/dict_init. Immutable
            # bases have no initializer of their own (tuple/frozenset/str/int
            # inherit object.__init__), so their args are ignored. The box is
            # mutated IN PLACE -- never marshaled through to_host (a copy would
            # silently no-op for mutators).
            if len(args) == 0 {
                return py_none();
            }
            if isinstance(b, PyList) {
                lst = b as PyList;
                if len(kwargs) > 0 {
                    return py_error(
                        "TypeError", "list() takes no keyword arguments"
                    );
                }
                if len(args) > 1 {
                    return py_error(
                        "TypeError", "list() takes at most one argument"
                    );
                }
                lst.items = [];
                return PyListMethod(
                    t="list_method", target=lst, name="extend"
                ).tp_call([args[0]], {});
            }
            if isinstance(b, PySet) {
                s = b as PySet;
                if len(kwargs) > 0 {
                    return py_error(
                        "TypeError", "set() takes no keyword arguments"
                    );
                }
                if len(args) > 1 {
                    return py_error(
                        "TypeError", "set() takes at most one argument"
                    );
                }
                s.set_clear();
                return PySetMethod(
                    t="set_method", target=s, name="update"
                ).tp_call(args, {});
            }
            if isinstance(b, PyDict) {
                return PyDictMethod(
                    t="dict_method", target=(b as PyDict), name="update"
                ).tp_call(args, kwargs);
            }
            return py_none();
        }
        if n == "__setitem__" {
            # Route through the public dispatch (not the raw slot) so slice
            # assignment shares the iterable-value normalization above.
            return py_store_subscript(b, args[0], args[1]);
        }
        if n == "__getitem__" {
            if isinstance(b, PyDict) and isinstance(self.owner, PyUserObj)
                and not user_has_dunder(self.owner as PyUserObj, "__getitem__") {
                return dict_subscript_missing(
                    self.owner as PyUserObj, b as PyDict, args[0]
                );
            }
            return b.mp_subscript(args[0]);
        }
        if n == "__delitem__" {
            return b.mp_del_subscript(args[0]);
        }
        if n == "__len__" {
            return py_len(b);
        }
        if n == "__iter__" {
            return b.tp_iter();
        }
        if n == "__contains__" {
            return py_contains(b, args[0]);
        }
        if n == "__repr__" {
            # The base type's own repr of the live boxed storage.
            return py_repr(b);
        }
        if n == "__str__" {
            return py_str(b);
        }
        # Everything else resolves onto the boxed base through the standard
        # attribute surface -- the same per-type dispatch (dict/list/set/str
        # methods, live view constructors, host fallback for unported names)
        # any base value presents outside super(). No name table here.
        res = py_attr(b, n);
        if is_error(res) {
            return res;
        }
        return res.tp_call(args, kwargs);
    }
}

# True iff `inst` is an instance of `cls` (walks the instance class's MRO).
def instance_of_class(inst: PyUserObj, cls: PyClass) -> bool {
    for klass in class_mro(inst.cls) {
        if klass is cls {
            return True;
        }
    }
    return False;
}

def super_lookup(defining_cls: PyObj, instance: PyObj, name: str) -> PyObj {
    # `instance` is a real instance for a normal super().method(), but a CLASS
    # for super(Cls, cls).__new__(...) inside a __new__. Resolve which class's
    # MRO to walk from either shape.
    walk_cls = py_none();
    if isinstance(instance, PyUserObj) {
        walk_cls = (instance as PyUserObj).cls;
    } elif isinstance(instance, PyClass) {
        walk_cls = instance;
    } else {
        return py_error("AttributeError", name);
    }
    start: PyClass = walk_cls as PyClass;
    if isinstance(defining_cls, PyClass) {
        start = defining_cls as PyClass;
    }
    mro = class_mro(walk_cls as PyClass);
    past = False;
    for klass in mro {
        if past {
            # CPython type.__init__ after creation is arg validation + no-op;
            # guest classes are already built when a metaclass __init__ chains
            # super().__init__. The native `type` surface carries no attrs, so
            # serve the no-op arm here instead of falling through to
            # AttributeError (Lib/typing.py _ProtocolMeta.__init__ depends on
            # this exact chain).
            if name == "__init__" and klass.native_base == "type" {
                return PyNoOpInit(t="noop_init");
            }
            if name in klass.attrs {
                return klass.attrs[name];
            }
        }
        if klass is start {
            past = True;
        }
    }
        # A CLASS receiver means we are inside a metaclass body chaining
        # super().__init__ during creation: class_mro nodes end at the newest
        # guest class (implicit object/type roots are not class_mro nodes), so
        # the walk found nothing. CPython's terminal there is type.__init__ --
        # arg-validation + no-op over the already-built class.
        if name == "__init__" and isinstance(instance, PyClass) {
            return PyNoOpInit(t="noop_init");
        }
    # No python ancestor defines it. A super().<dunder>() on a boxed-builtin
    # subclass (dict/list/... subclass calling super().__setitem__ etc.) delegates
    # to the base value's own slot.
    if name != "__new__" and isinstance(instance, PyUserObj) {
        inst = instance as PyUserObj;
        # object.__getattribute__/__setattr__/__delattr__ close every MRO: a
        # super().<attr-protocol>() delegation resolves to the DEFAULT protocol
        # -- never a re-dispatch through the override that called super(). This
        # is the recursion guard inside user __setattr__/__delattr__/
        # __getattribute__ implementations.
        if name == "__getattribute__" or name == "__setattr__"
            or name == "__delattr__" {
            return PyObjectAttrSlot(t="obj_attr_slot", target=inst as PyObj, op=name);
        }
        if inst._has_base() {
            return PyBuiltinSuperMethod(
                t="builtin_super",
                base=inst._base_obj(),
                name=name,
                owner=instance
            );
        }
        # Exception-derived user classes have no boxed builtin layout: the
        # BaseException surface answers instead. CPython gives them
        # BaseException.__init__/__str__/__repr__ via slot inheritance -- serve
        # those over the live instance.
        if class_is_exception(inst.cls) {
            if name == "args" {
                stored = inst.attrs.get("args");
                if isinstance(stored, PyTuple) {
                    return stored;
                }
                return PyTuple(t="tuple", items=[]);
            }
            if name == "__init__" or name == "__str__" or name == "__repr__" {
                return PyExcSuperSlot(
                    t="exc_super_slot", target=inst as PyObj, name=name
                );
            }
        }
        # Base-less class: the walk exhausted every python ancestor including
        # the implicit object root, so the object surface answers.
        return PyBuiltinSuperMethod(
            t="builtin_super", base=py_none(), name=name, owner=instance
        );
    }
    # No python ancestor defines it. super().__new__ resolves to the base
    # constructor: a builtin (int.__new__, str.__new__, ...) when the chain boxes
    # one, else object.__new__ (a plain instance of the class).
    if name == "__new__" {
        base = start.native_base;
        for klass in mro {
            if klass.native_base != "" {
                base = klass.native_base;
            }
        }
        if base == "" {
            base = "object";
        }
        return PyNativeNew(t="native_new", base_name=base);
    }
    # object.__init_subclass__ terminal: CPython's default accepts the class
    # and zero keywords (returning None); keyword arguments raise TypeError.
    # Without this terminal, user __init_subclass__ overrides that chain
    # super().__init_subclass__() die with AttributeError.
    if name == "__init_subclass__" {
        return PyNoOpInitSubclass(t="noop_init_subclass");
    }
    return py_error(
        "AttributeError", "'super' object has no attribute '" + name + "'"
    );
}

# The object.__init_subclass__ slot-wrapper view: cls positional, zero kwargs
# succeed; any keyword raises CPython's exact refusal.
obj PyNoOpInitSubclass(PyObj) {
    def tp_call(args: list[PyObj], kwargs: dict[str, PyObj]) -> PyObj {
        if len(kwargs) > 0 {
            first = "";
            for k in kwargs {
                first = k;
                break;
            }
            return py_error(
                "TypeError", "__init_subclass__() got an unexpected keyword argument '" + first + "'"
            );
        }
        return py_none();
    }
}

# Box a builtin subclass instance by running the builtin constructor over the
# call args (int("5") -> 5, list(x) -> [...]). Errors propagate.
def construct_native_base(name: str, args: list[PyObj]) -> PyObj {
    raw_args: list[any] = [];
    for a in args {
        ha_r = to_host_coerce(a);
        ha = ha_r[1];
        if not ((ha_r[0] as bool)) {
            return ha_r[1] as PyObj;
        }
        raw_args.append(ha);
    }
    result = _jac_construct_builtin(name, raw_args);
    if host_result_ok(result) {
        return from_host(result[1]);
    }
    return host_result_error(result);
}

# Same boundary contract as construct_native_base, for non-builtin host C-type
# bases recorded on the class (compute_host_base): call the actual host type
# so per-instance C state is real.
def construct_host_typed_base(host_type: any, args: list[PyObj]) -> PyObj {
    raw_args: list[any] = [];
    for a in args {
        ha_r = to_host_coerce(a);
        ha = ha_r[1];
        if not ((ha_r[0] as bool)) {
            return ha_r[1] as PyObj;
        }
        raw_args.append(ha);
    }
    result = _jac_construct_host_type(host_type, raw_args);
    if host_result_ok(result) {
        return from_host(result[1]);
    }
    return host_result_error(result);
}

# For operator delegation: a builtin subclass on either operand acts as its
# boxed value (MyInt(5) + MyInt(1) -> 5 + 1).
def unwrap_base(o: PyObj) -> PyObj {
    if isinstance(o, PyUserObj) {
        u = o as PyUserObj;
        if u._has_base() {
            return u._base_obj();
        }
    }
    return o;
}

# True iff `obj` counts as an instance of the builtin named `name`, honoring
# builtin-subclass boxing and the bool<:int relationship.
def obj_is_builtin(ob: PyObj, name: str) -> bool {
    if name == "object" {
        return True;
    }
    if isinstance(ob, PyUserObj) {
        u = ob as PyUserObj;
        for klass in class_mro(u.cls) {
            if klass.native_base == name {
                return True;
            }
        }
        if u._has_base() {
            return obj_is_builtin(u._base_obj(), name);
        }
        return False;
    }
    if ob.t == name {
        return True;
    }
    if name == "int" and ob.t == "bool" {
        return True;
    }
    return False;
}

def py_isinstance(ob: PyObj, typ: PyObj) -> bool {
    if isinstance(typ, PyTuple) {
        for t in (typ as PyTuple).items {
            if py_isinstance(ob, t) {
                return True;
            }
        }
        return False;
    }
    # Shim type-marker fast path: one t compare on miss, exact tag match on
    # hit (ratified exception/tb-surface scope; generic across future shims).
    if typ.t == "shim_type_marker" {
        return ob.t == ((typ as ShimTypeMarker).tag);
    }
    if isinstance(ob, PyException) {
        if typ.t == "exception_type" {
            return exc_name_matches(
                (ob as PyException).type_name, (typ as PyExceptionType).name
            );
        }
        if isinstance(typ, PyHostProxy) {
            host_type = (typ as PyHostProxy).val;
            if bool(_jac_is_exception_type(host_type)) {
                tname = _jac_host_class_name(host_type) as str;
                return exc_name_matches((ob as PyException).type_name, tname);
            }
        }
        if isinstance(typ, PyClass) {
            return exc_name_matches(
                (ob as PyException).type_name, (typ as PyClass).name
            );
        }
    }
    if isinstance(typ, PyClass) {
        if isinstance(ob, PyUserObj) {
            for klass in class_mro((ob as PyUserObj).cls) {
                if klass is (typ as PyClass) {
                    return True;
                }
            }
        }
        # isinstance(SomeClass, Meta): a class is an instance of its metaclass, so
        # walk the class's metaclass MRO (isinstance(Enum, EnumType) is True).
        if isinstance(ob, PyClass) {
            meta = (ob as PyClass).metaclass;
            if meta is not None and isinstance(meta, PyClass) {
                for klass in class_mro(meta as PyClass) {
                    if klass is (typ as PyClass) {
                        return True;
                    }
                }
            }
        }
        return False;
    }
    if isinstance(typ, PyHostProxy) {
        host_type = (typ as PyHostProxy).val;
        name: str = str(_jac_builtin_base_name(host_type));
        if name != "" {
            return obj_is_builtin(ob, name);
        }
        hob_r = to_host_coerce(ob);
        hob = hob_r[1];
        if not ((hob_r[0] as bool)) {
            return False;
        }
        return bool(_jac_host_isinstance(hob, host_type));
    }
    # A host-proxied exception INSTANCE tested against a native exception-type
    # marker: match through the shared name hierarchy (mirrors the proxy-target
    # branch above).
    if isinstance(ob, PyHostProxy) and typ.t == "exception_type" {
        inst = _jac_host_exception_instance((ob as PyHostProxy).val);
        if bool(inst[0]) {
            return exc_name_matches(str(inst[1]), (typ as PyExceptionType).name);
        }
        return False;
    }
    # A NATIVE user-exception instance tested against a native exception-type
    # marker (isinstance(MyErr('x'), Exception)): walk the instance class MRO's
    # RAW bases for exception markers/host proxies and match through the shared
    # name hierarchy. Without this arm every native user-exception instance
    # answered False against marker builtins -- the marker never survives to
    # isinstance dispatch through the PyClass arms because builtin exception
    # bases are PyExceptionType objects, not PyClass nodes.
    # Descriptor-family ctor markers used as second args of isinstance:
    # Lib code branches on isinstance(v, staticmethod)/classmethod/property
    # (enum.py unwraps value.__func__ only through that gate). The builtins
    # resolve to the ctor marker objects, so match them against the wrapper
    # types they construct.
    if typ.t == "staticmethod_ctor" {
        return isinstance(ob, PyStaticMethod);
    }
    if typ.t == "classmethod_ctor" {
        return isinstance(ob, PyClassMethod);
    }
    if typ.t == "property_ctor" {
        return isinstance(ob, PyProperty);
    }
    if isinstance(ob, PyUserObj) and typ.t == "exception_type" {
        for klass in class_mro((ob as PyUserObj).cls) {
            for base in (klass as PyClass).bases {
                if isinstance(base, PyExceptionType)
                    and exc_name_matches(
                        (base as PyExceptionType).name,
                        (typ as PyExceptionType).name
                    ) {
                    return True;
                }
                if isinstance(base, PyHostProxy)
                    and bool(_jac_is_exception_type((base as PyHostProxy).val)) {
                    tn2 = _jac_host_class_name((base as PyHostProxy).val) as str;
                    if exc_name_matches(tn2, (typ as PyExceptionType).name) {
                        return True;
                    }
                }
            }
        }
        return False;
    }
    return False;
}

# issubclass(cls, typ) metaclass hook: ABCMeta.__subclasscheck__ (and peers)
# consult virtual registries (numbers.Integral.register(int), ...). Builtin
# issubclass must route here before answering False for host cls + guest ABC.
def py_type_subclasscheck_via_meta(cls: PyObj, typ: PyClass) -> bool | None {
    sc = typ._meta_dunder("__subclasscheck__");
    if is_error(sc) {
        return None;
    }
    result = sc.tp_call([cls], {});
    if is_error(result) {
        return None;
    }
    truth = py_slot_truth(result);
    if is_error(truth) {
        return None;
    }
    return (truth as PyBool).val;
}

def py_issubclass(cls: PyObj, typ: PyObj) -> bool {
    if isinstance(typ, PyTuple) {
        for t in (typ as PyTuple).items {
            if py_issubclass(cls, t) {
                return True;
            }
        }
        return False;
    }
    if isinstance(cls, PyClass) {
        c = cls as PyClass;
        if isinstance(typ, PyClass) {
            for klass in class_mro(c) {
                if klass is (typ as PyClass) {
                    return True;
                }
            }
            via_meta = py_type_subclasscheck_via_meta(cls, typ as PyClass);
            if via_meta is not None {
                return via_meta;
            }
            return False;
        }
        if isinstance(typ, PyHostProxy) {
            # A host-proxied NON-builtin type (e.g. typing.Generic from the C
            # _typing accelerator) still participates: ask the host whether any
            # standin of the guest MRO subclasses it, before the builtin-name
            # fallback answers False.
            hv_r = _jac_hostproxy_val_is_type((typ as PyHostProxy).val);
            if hv_r != "" {
                covered = _jac_standin_mro_covers(c, hv_r);
                if covered {
                    return True;
                }
            }
            name: str = str(_jac_builtin_base_name((typ as PyHostProxy).val));
            if name == "object" {
                return True;
            }
            if name != "" {
                for klass in class_mro(c) {
                    if klass.native_base == name {
                        return True;
                    }
                }
            }
            return False;
        }
        return False;
    }
    if isinstance(cls, PyHostProxy) and isinstance(typ, PyHostProxy) {
        return bool(
            _jac_host_issubclass((cls as PyHostProxy).val, (typ as PyHostProxy).val)
        );
    }
    # Builtin exception types exist in two shapes -- native PyExceptionType
    # markers and host-proxied classes -- and subclass tests must cross the
    # split. Match by name through the shared EXC_PARENT hierarchy.
    cls_name: str = "";
    typ_name: str = "";
    if cls.t == "exception_type" {
        cls_name = (cls as PyExceptionType).name;
    } elif isinstance(cls, PyHostProxy)
        and bool(_jac_is_exception_type((cls as PyHostProxy).val)) {
        cls_name = _jac_host_class_name((cls as PyHostProxy).val) as str;
    }
    if typ.t == "exception_type" {
        typ_name = (typ as PyExceptionType).name;
    } elif isinstance(typ, PyHostProxy)
        and bool(_jac_is_exception_type((typ as PyHostProxy).val)) {
        typ_name = _jac_host_class_name((typ as PyHostProxy).val) as str;
    }
    if cls_name != "" and typ_name != "" {
        return exc_name_matches(cls_name, typ_name);
    }
    if isinstance(typ, PyClass) {
        via_meta = py_type_subclasscheck_via_meta(cls, typ as PyClass);
        if via_meta is not None {
            return via_meta;
        }
    }
    return False;
}

# The builtin ancestor (if any) that dictates a class's instance layout, plus the
# `type` marker for a metaclass. Inherited from a user base's own native_base when
# subclassing a subclass; read off a host builtin/`type` base directly.
# The subclassable builtins whose instances are filled by __init__ rather than
# frozen at __new__ time. A user __init__ on such a subclass creates an empty base
# and fills it (usually via super().__init__).
def is_mutable_base(name: str) -> bool {
    return name == "dict" or name == "list" or name == "set";
}

def compute_native_base(bases: list[PyObj]) -> str {
    native_base = "";
    for base in bases {
        if isinstance(base, PyClass) {
            inherited = (base as PyClass).native_base;
            if inherited != "" {
                native_base = inherited;
            }
        } elif isinstance(base, PyHostProxy) {
            hostval = (base as PyHostProxy).val;
            if _jac_is_type_type(hostval) {
                # `class Meta(type)` -- a metaclass. super().__new__ builds classes.
                native_base = "type";
            } else {
                builtin_name: str = str(_jac_builtin_base_name(hostval));
                if builtin_name != "" and builtin_name != "object" {
                    native_base = builtin_name;
                }
            }
        }
    }
    return native_base;
}

# The non-builtin host C-type ancestor (if any): a proxied HOST type base the
# _JAC_BUILTIN_BASES list does not cover (io.BytesIO, zlib.Compress, ...).
# Recorded on the class so instances box a REAL base instance -- every method
# call behind it touches live per-instance C state that must survive
# boundary crossings.
def compute_host_base(bases: list[PyObj]) -> any {
    for base in bases {
        if isinstance(base, PyClass) {
            inherited = (base as PyClass).host_base;
            if inherited is not None {
                return inherited;
            }
        } elif isinstance(base, PyHostProxy) {
            hostval = (base as PyHostProxy).val;
            # Metaclasses ride native_base="type"; listed builtins ride
            # native_base; exception bases ride the exception machinery.
            if _jac_is_type_type(hostval) {
                continue;
            }
            if str(_jac_builtin_base_name(hostval)) != "" {
                continue;
            }
            if bool(_jac_is_exception_type(hostval)) {
                continue;
            }
            cand = _jac_hostproxy_val_is_type(hostval);
            if not isinstance(cand, str) {
                return cand;
            }
        }
    }
    return None;
}

# Box a PyClass from a resolved name/bases/namespace. `meta` is the metaclass that
# produced it (None = the default `type`), recorded so a later subclass can
# re-derive and re-run the metaclass protocol.
# __slots__ finalization for a freshly built class (CPython type_new_set_attrs
# + the dict/weakref inheritance rules in type_ready setdict). Returns either a
# PyError (conflict / malformed declaration -- class creation fails) or a
# PyTuple of [merged member names, declared?, instance-has-dict?].
#
# Host-exact behaviors pinned against CPython 3.14:
# - string form: __slots__ = "q" declares exactly one slot q;
# - non-iterable: TypeError "'int' object is not iterable";
# - non-string item: TypeError "__slots__ items must be strings, not 'int'";
# - slot vs class variable: ValueError "'v' in __slots__ conflicts with class
#   variable" (checked AFTER mangling, like the host);
# - private names mangle (`__p` -> `_M__p`) and install under the mangled key;
# - duplicate names are allowed (deduped); `__dict__`/`__weakref__` are layout
#   flags, not members;
# - instance dict survives only if listed or inherited from a base (a builtin
#   boxed base does NOT grant one once __slots__ is declared);
# - two bases each declaring non-empty members raise the host layout conflict.
def compute_class_slots(
    class_name: str, bases: list[PyObj], namespace: dict[str, PyObj]
) -> PyObj {
    if "__slots__" not in namespace {
        # No own declaration: the class keeps a permissive dict, but the
        # EFFECTIVE layout still carries every inherited slot member -- the
        # dict VIEW must keep hiding their storage (host: B(A) with A slotted
        # answers b.__dict__ == {'zz': 1} after b.zz = 1; b.a = 2, even though
        # both live on the same attribute map).
        return PyTuple(
            t="tuple",
            items=[
                PyList(
                    t="list",
                    items=[
                        PyStr(t="str", val=m)
                        for m in _inherited_slot_members(bases)
                    ],
                ),
                PyBool(t="bool", val=False),
                PyBool(t="bool", val=True),
            ],
        );
    }
    slots_obj = namespace["__slots__"];
    raw: list[str] = [];
    if isinstance(slots_obj, PyStr) {
        raw.append((slots_obj as PyStr).val);
    } elif isinstance(slots_obj, PyTuple) or isinstance(slots_obj, PyList) {
        items = (slots_obj as PyTuple).items
            if isinstance(slots_obj, PyTuple)
            else (slots_obj as PyList).items;
        for item in items {
            if not isinstance(item, PyStr) {
                return py_error(
                    "TypeError",
                    "__slots__ items must be strings, not '"
                        + _slot_item_type_name(item) + "'",
                );
            }
            raw.append((item as PyStr).val);
        }
    } else {
        return py_error(
            "TypeError",
            "'" + _slot_item_type_name(slots_obj) + "' object is not iterable",
        );
    }
    wants_dict = False;
    local: list[str] = [];
    seen: dict[str, bool] = {};
    for name in raw {
        if name == "__dict__" {
            wants_dict = True;
            continue;
        }
        if name == "__weakref__" {
            continue;
        }
        mangled = type_slots_mangle(name, class_name);
        # The conflict check runs on the MANGLED form: a slot named `__v` in a
        # body that also binds `_C__v` collides exactly as the host's does.
        if mangled in namespace {
            return py_error(
                "ValueError",
                "'" + mangled + "' in __slots__ conflicts with class variable",
            );
        }
        if mangled in seen {
            continue;
        }
        seen[mangled] = True;
        local.append(mangled);
    }
    # Merge inherited members and OR the base dict flags across all bases.
    inherited = _inherited_slot_members(bases);
    base_has_dict = False;
    nonempty_layout_bases = 0;
    for b in bases {
        if not isinstance(b, PyClass) {
            continue;
        }
        bc = b as PyClass;
        if bc.instance_has_dict {
            base_has_dict = True;
        }
        if len(bc.slot_members) > 0 {
            nonempty_layout_bases = nonempty_layout_bases + 1;
        }
    }
    if nonempty_layout_bases > 1 {
        return py_error(
            "TypeError", "multiple bases have instance lay-out conflict"
        );
    }
    merged = type_slots_merge_names(local, inherited);
    has_dict = type_slots_has_dict(True, wants_dict, base_has_dict);
    return PyTuple(
        t="tuple",
        items=[
            PyList(t="list", items=[PyStr(t="str", val=m) for m in merged]),
            PyBool(t="bool", val=True),
            PyBool(t="bool", val=has_dict),
        ],
    );
}

# Union of all PyClass bases' slot members, in MRO-ish declaration order
# (deduped): the inherited half of a subclass's effective slot layout.
def _inherited_slot_members(bases: list[PyObj]) -> list[str] {
    inherited: list[str] = [];
    for b in bases {
        if isinstance(b, PyClass) {
            inherited = type_slots_merge_names(
                [], inherited + (b as PyClass).slot_members
            );
        }
    }
    return inherited;
}

def _slot_item_type_name(v: PyObj) -> str {
    if isinstance(v, PyInt) {
        return "int";
    }
    if isinstance(v, PyFloat) {
        return "float";
    }
    if isinstance(v, PyNoneType) {
        return "NoneType";
    }
    return v.t;
}

def make_pyclass_from_map(
    class_name: str, bases: list[PyObj], namespace: dict[str, PyObj], meta: any
) -> PyObj {
    # CPython type_new derives cls.__module__ from the namespace's own
    # __module__ entry, falling back to the invoking frame's globals. Our
    # builder runs on paths where neither exists -- a metaclass __prepare__
    # mapping like enum's _EnumDict carries no seeded entry, and tp_call
    # dispatch into type.__new__ has no frame to consult. Mirror the fallback
    # chain here: inherit from the nearest base carrying a real __module__
    # (each base's MRO in order), else read the calling frame's globals via
    # jac_current_module_name, else reuse the defining-context module name the
    # class-body frame seeds as __name__. Without this, classes built through
    # guest EnumType chains have no provenance -- enum's bootstrap extend guard
    # compares base __module__/repr provenance and rejects its own classes.
    if "__module__" not in namespace {
        for tb in bases {
            if isinstance(tb, PyClass) {
                mod = class_lookup_attr(tb as PyClass, "__module__");
                if not is_error(mod) {
                    namespace["__module__"] = mod;
                    break;
                }
            }
        }
    }
    if "__module__" not in namespace {
        fnm = jac_current_module_name();
        if fnm is not None {
            namespace["__module__"] = fnm;
        }
    }
    if "__module__" not in namespace and "__name__" in namespace {
        nm = namespace["__name__"];
        if isinstance(nm, PyStr) {
            namespace["__module__"] = nm;
        }
    }
    # CPython type_new_staticmethod (Objects/typeobject.c): a plain-function
    # __new__ in the namespace is stored as a STATICMETHOD so it never
    # instance-binds -- super().__new__(mcls, ...) must reach it unbound (the
    # receiver arrives as the explicit mcls argument). Without this, metaclass
    # chains double-bind through descriptor_get and die with 'too many
    # positional arguments' (Lib/typing.py _ProtocolMeta.__new__).
    if "__new__" in namespace and isinstance(namespace["__new__"], PyFunction) {
        namespace["__new__"] = PyStaticMethod(
            t="staticmethod", func=namespace["__new__"]
        );
    }
    flags = type_ready(0);
    if flags < 0 {
        flags = Py_TPFLAGS_READY;
    }
    slots_state = compute_class_slots(class_name, bases, namespace);
    if is_error(slots_state) {
        return slots_state;
    }
    state = (slots_state as PyTuple).items;
    members: list[str] = [];
    for mo in (state[0] as PyList).items {
        members.append((mo as PyStr).val);
    }
    declared = (state[1] as PyBool).val;
    has_dict = (state[2] as PyBool).val;
    cls = PyClass(
        t="class",
        name=class_name,
        attrs=namespace,
        bases=bases,
        native_base=compute_native_base(bases),
        host_base=compute_host_base(bases),
        metaclass=meta,
        tp_flags=flags,
        slot_members=members,
        slots_declared=declared,
        instance_has_dict=has_dict
    );
    # Install one member descriptor per OWN declared slot (inherited slots
    # already carry their defining class's descriptor and resolve via the MRO).
    # A body binding of the same name raised ValueError above, so nothing here
    # shadows an explicit namespace entry.
    inherited_set: dict[str, bool] = {};
    for b in bases {
        if isinstance(b, PyClass) {
            for im in (b as PyClass).slot_members {
                inherited_set[im] = True;
            }
        }
    }
    for m in members {
        if m not in namespace and m not in inherited_set {
            cls.attrs[m] = PyMemberDescr(t="member_descr", member=m, owner=class_name);
        }
    }
    return cls;
}

# type.__new__(mcls, name, bases, namespace): build a class object. Serves both
# the metaclass super().__new__ path and a bare 3-arg type(name, bases, ns) call.
# Shared 3-arg type(name, bases, ns) base validation: a non-class base that
# defines __mro_entries__ gets CPython's escape-hatch message; any other
# non-class base is rejected outright. Returns None when bases are acceptable.
def _jac_validate_type_bases(bases: list[PyObj]) -> PyObj | None {
    for tb in bases {
        if isinstance(tb, PyClass) {
            continue;
        }
        if isinstance(tb, PyExceptionType) {
            # Builtin exception markers (Exception, ValueError, ...) ARE the
            # guest's classes for the exception tree: user subclasses build
            # against them on the default path, and a metaclass factory call
            # (`class Unh(Exception, metaclass=Meta)`) reaches type_new with
            # them after py_build_class already resolved/validated the bases.
            continue;
        }
        if isinstance(tb, PyHostProxy) and _jac_host_val_is_type((tb as PyHostProxy).val) {
            continue;
        }
        hook = py_attr(tb, "__mro_entries__");
        if not is_error(hook) {
            return py_error(
                "TypeError",
                "type() doesn't support MRO entry resolution; use types.new_class()"
            );
        }
        return py_error("TypeError", "all bases must be classes");
    }
    return None;
}

# Shared type(obj) / type(name, bases, ns[, **kwds]) dispatch for the native
# builtin and any exact-host-type proxy edge. Builds guest PyClass objects
# through type_new instead of py_call_host standins.
def py_type_call(mcls: PyObj, args: list[PyObj], kwargs: dict[str, PyObj]) -> PyObj {
    if len(args) == 1 and len(kwargs) == 0 {
        return py_type_of(args[0]);
    }
    if len(args) != 3 {
        return py_error("TypeError", "type() takes 1 or 3 arguments");
    }
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
    if "metaclass" in kwargs and isinstance(kwargs["metaclass"], PyClass) {
        winner = kwargs["metaclass"];
    }
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
        call_kwds: dict[str, PyObj] = {};
        for k in kwargs {
            if k != "metaclass" {
                call_kwds[k] = kwargs[k];
            }
        }
        made_t = py_invoke(
            winner as PyObj, [args[0], args[1], ns_obj], call_kwds
        );
        if is_error(made_t) {
            return made_t;
        }
        return made_t;
    }
    built_t = type_new([mcls, args[0], args[1], ns_obj], kwargs);
    if is_error(built_t) {
        return built_t;
    }
    return built_t;
}

def type_new(args: list[PyObj], kwargs: dict[str, PyObj]) -> PyObj {
    # kwargs = class-creation keywords left over by the metaclass chain
    # (CPython type.__new__ forwards them to __init_subclass__).
    if len(args) < 4 {
        return py_error("TypeError", "type.__new__() takes name, bases, dict");
    }
    mcls = args[0];
    class_name = expect_str(args[1]);
    bases: list[PyObj] = [];
    bases_obj = args[2];
    if isinstance(bases_obj, PyTuple) {
        bases = (bases_obj as PyTuple).items;
    } elif isinstance(bases_obj, PyList) {
        bases = (bases_obj as PyList).items;
    }
    namespace = extract_namespace(args[3]);
    # CPython type_new_impl: a bare 3-arg type() never resolves __mro_entries__.
    rejected = _jac_validate_type_bases(bases);
    if rejected is not None {
        return rejected;
    }
    made_cls = make_pyclass_from_map(class_name, bases, namespace, mcls);
    if is_error(made_cls) {
        return made_cls;
    }
    cls = made_cls as PyClass;
    ordered: list[str] = [];
    for k in namespace {
        ordered.append(k);
    }
    hooked = apply_set_name_hooks(cls, ordered);
    if is_error(hooked) {
        return hooked;
    }
    # CPython type_new_init_subclass: leftover class keywords reach the nearest
    # base's __init_subclass__ (PEP 487). Previously dropped silently.
    return apply_init_subclass(cls, kwargs);
}

# After a class is built, type.__new__ calls __set_name__(cls, name) on every
# namespace value that defines it, in definition order (PEP 487). This drives
# enum member creation: each _proto_member's __set_name__ builds the real member
# and registers it on the class. Returns the class, or the first hook's error.
def apply_set_name_hooks(cls: PyClass, ordered_names: list[str]) -> PyObj {
    for name in ordered_names {
        if name in cls.attrs {
            value = cls.attrs[name];
            if isinstance(value, PyUserObj)
                and user_has_dunder(value as PyUserObj, "__set_name__") {
                res = call_user_dunder(
                    value as PyUserObj, "__set_name__", [cls, PyStr(t="str", val=name)]
                );
                if is_error(res) {
                    return res;
                }
            }
        }
    }
    return cls;
}

# Metaclass __new__ keyword-only parameters (enum.EnumType.boundary, _simple, ...)
# are consumed before type.__new__ forwards leftovers to __init_subclass__.
# Guest type() calls that bypass the metaclass must not leak them through.
def filter_init_subclass_kwds(kwds: dict[str, PyObj]) -> dict[str, PyObj] {
    metaclass_only: dict[str, bool] = {
        "boundary": True,
        "_simple": True,
    };
    out: dict[str, PyObj] = {};
    for k in kwds {
        if not (k in metaclass_only) {
            out[k] = kwds[k];
        }
    }
    return out;
}

# PEP 487: CPython type_new_init_subclass calls super(type, type).__init_subclass__
# once with the class-creation keywords. That cooperative super walk fires only
# bases that DEFINE __init_subclass__ in their own namespace (skipping inherited
# copies on intermediate bases like Left(Base)) and chains through each hook's
# super().__init_subclass__() for the rest.
def apply_init_subclass(cls: PyClass, kwds: dict[str, PyObj]) -> PyObj {
    hook_kwds = filter_init_subclass_kwds(kwds);
    cls_obj = cls as PyObj;
    found = super_lookup(cls_obj, cls_obj, "__init_subclass__");
    if is_error(found) {
        return cls;
    }
    bound = descriptor_get(found, cls_obj, cls_obj);
    if is_error(bound) {
        return bound;
    }
    res = py_invoke(bound, [], hook_kwds);
    if is_error(res) {
        return res;
    }
    return cls;
}

# Read a PyDict whose keys are all strings (a class namespace) into a jac str map.
def pydict_to_str_map(d: PyDict) -> dict[str, PyObj] {
    m: dict[str, PyObj] = {};
    for keyobj in d.dict_keys() {
        val = d.mp_subscript(keyobj);
        m[expect_str(keyobj)] = val;
    }
    return m;
}

# The class namespace as a str map, whether the metaclass __prepare__ returned a
# plain dict or a custom mapping (a dict-subclass like enum's _EnumDict, which
# boxes a real dict). A mapping's own tracking attributes stay on the object; the
# stored member/method entries live in the boxed dict.
def extract_namespace(ns_obj: PyObj) -> dict[str, PyObj] {
    if isinstance(ns_obj, PyDict) {
        return pydict_to_str_map(ns_obj as PyDict);
    }
    if isinstance(ns_obj, PyUserObj) {
        u = ns_obj as PyUserObj;
        if u._has_base() and isinstance(u._base_obj(), PyDict) {
            return pydict_to_str_map(u._base_obj() as PyDict);
        }
    }
    return {};
}

# The metaclass of a base object (its `type`), or None. Only PyClass bases carry a
# recorded metaclass; a host base (object/type/builtins) resolves to the default.
def metaclass_of(base: PyObj) -> any {
    if isinstance(base, PyClass) {
        m = (base as PyClass).metaclass;
        if m is not None and isinstance(m, PyClass) {
            return m;
        }
    }
    return None;
}

# Pick the class's metaclass: the most-derived of an explicit `metaclass=` kwarg
# and every base's own metaclass (CPython's winner rule). Returns None for the
# default `type` path. An explicit `metaclass=type` (host proxy) stays default.
def resolve_metaclass(kwargs: dict[str, PyObj], bases: list[PyObj]) -> any {
    winner: any = None;
    if "metaclass" in kwargs {
        m = kwargs["metaclass"];
        if isinstance(m, PyClass) {
            winner = m;
        }
    }
    for base in bases {
        bm = metaclass_of(base);
        if isinstance(bm, PyClass) {
            if winner is None {
                winner = bm;
            } elif py_issubclass(bm as PyObj, winner as PyObj) {
                winner = bm;
            }
        }
    }
    return winner;
}

# Port of CPython bltinmodule.c update_bases: non-class bases may replace
# themselves through __mro_entries__ (typing.Generic[T], the implicit PEP 695
# class base, resolves to Generic this way) before the metaclass is derived
# from the bases. Each hook receives the ORIGINAL bases tuple and must return
# one; real classes (guest PyClass, host type proxies) never get looked up,
# matching the PyType_Check short-circuit in the host. Appends the resolved
# bases to `out`; returns a PyError when the protocol fails.
def update_build_class_bases(bases: list[PyObj], out: list[PyObj]) -> PyObj {
    new_bases: list[PyObj] = [];
    ub_j = 0;
    while ub_j < len(bases) {
        base = bases[ub_j];
        if isinstance(base, PyClass)
            or (isinstance(base, PyHostProxy)
                and _jac_host_val_is_type((base as PyHostProxy).val)) {
            new_bases.append(base);
            ub_j = ub_j + 1;
            continue;
        }
        entries = py_attr(base, "__mro_entries__");
        if is_error(entries) {
            if ((entries as PyError).exception.type_name != "AttributeError") {
                return entries;
            }
            new_bases.append(base);
            ub_j = ub_j + 1;
            continue;
        }
        repl = py_invoke(entries, [PyTuple(t="tuple", items=bases)], {});
        if is_error(repl) {
            return repl;
        }
        if not isinstance(repl, PyTuple) {
            return py_error("TypeError", "__mro_entries__ must return a tuple");
        }
        for rb in (repl as PyTuple).items {
            new_bases.append(rb);
        }
        ub_j = ub_j + 1;
    }
    for nb in new_bases {
        out.append(nb);
    }
    return py_none();
}

# True when the two base lists hold identical objects pairwise (CPython's
# `bases != orig_bases` identity check after update_bases).
def bases_are_same(a: list[PyObj], b: list[PyObj]) -> bool {
    if len(a) != len(b) {
        return False;
    }
    i = 0;
    while i < len(a) {
        if a[i] is not b[i] {
            return False;
        }
        i = i + 1;
    }
    return True;
}

def py_build_class(args: list[PyObj], kwargs: dict[str, PyObj]) -> PyObj {
    if len(args) < 2 {
        return py_error("TypeError", "__build_class__ needs a body and name");
    }
    body = args[0] as PyFunction;
    class_name = expect_str(args[1]);
    # args[2:] are the base objects.
    bases: list[PyObj] = [];
    j = 2;
    while j < len(args) {
        bases.append(args[j]);
        j = j + 1;
    }
    # Class keyword args other than `metaclass` are forwarded to __prepare__ and
    # the metaclass call (e.g. __init_subclass__ kwargs).
    class_kwds: dict[str, PyObj] = {};
    for k in kwargs {
        if k != "metaclass" {
            class_kwds[k] = kwargs[k];
        }
    }
    # CPython resolves __mro_entries__ replacements BEFORE deriving the
    # metaclass from the bases -- see update_build_class_bases.
    orig_base_list: list[PyObj] = [];
    for ob in bases {
        orig_base_list.append(ob);
    }
    resolved_base_list: list[PyObj] = [];
    ub_err = update_build_class_bases(bases, resolved_base_list);
    if is_error(ub_err) {
        return ub_err;
    }
    bases_changed = not bases_are_same(bases, resolved_base_list);
    bases = resolved_base_list;
    metaclass = resolve_metaclass(kwargs, bases);
    # A user metaclass (EnumType, ABCMeta): run the full protocol -- __prepare__
    # for the body namespace, then call the metaclass as the class factory.
    if isinstance(metaclass, PyClass) {
        return build_class_via_metaclass(
            metaclass as PyClass, class_name, bases, body, class_kwds,
            orig_base_list, bases_changed
        );
    }
    # CPython __build_class__ seeds the body namespace's __name__ from the
    # CALLING FRAME's globals so type.__new__ derives cls.__module__ from the
    # defining module -- never a hardcoded "__main__".
    modname = "__main__";
    if "__name__" in body.globals {
        gm = body.globals["__name__"];
        if isinstance(gm, PyStr) {
            modname = (gm as PyStr).val;
        }
    }
    # Default `type`: execute the body into a plain namespace and box a PyClass.
    namespace: dict[str, PyObj] = {"__name__": PyStr(t="str", val=modname)};
    body_result = exec_code_frame(
        body.code, [], {}, body.globals, namespace, body.closure, [], {}
    );
    if body_result.t == "error" {
        return body_result;
    }
    # CPython type.__new__ pops __classcell__ from the mapping so it never
    # becomes a class attribute; py_build_class seeds the returned cell itself.
    if "__classcell__" in namespace {
        del namespace["__classcell__"];
    }
    # CPython bltinmodule.c: when update_bases replaced any base, the original
    # bases land in the namespace as __orig_bases__ AFTER the body ran.
    if bases_changed {
        namespace["__orig_bases__"] = PyTuple(t="tuple", items=orig_base_list);
    }
    built_cls = make_pyclass_from_map(class_name, bases, namespace, None);
    if is_error(built_cls) {
        return built_cls;
    }
    cls = built_cls as PyClass;
    # CPython bltinmodule.c __build_class__: when the body declares a __class__
    # cellvar, the finished class object is written into that live cell (the
    # epilogue returned it) so methods' captured closures deref it for
    # zero-arg super().
    if isinstance(body_result, PyCell) {
        cc = body_result as PyCell;
        cc.val = cls;
        cc.filled = True;
    }
    ordered: list[str] = [];
    for k in namespace {
        ordered.append(k);
    }
    hooked = apply_set_name_hooks(cls, ordered);
    if is_error(hooked) {
        return hooked;
    }
    return apply_init_subclass(cls, class_kwds);
}

# The custom-metaclass class-creation protocol: metaclass.__prepare__ produces the
# body namespace, the body runs into it, then the metaclass is called as
# (name, bases, namespace, **kwds) -- its __new__/__init__ build and finish the
# class. Only a plain-dict namespace is supported; a custom mapping (enum's
# _EnumDict) as a live body namespace is a later refinement.
def build_class_via_metaclass(
    metaclass: PyClass,
    class_name: str,
    bases: list[PyObj],
    body: PyFunction,
    class_kwds: dict[str, PyObj],
    orig_bases: list[PyObj],
    bases_changed: bool
) -> PyObj {
    # Module identity for __module__ derivation (same rule as py_build_class).
    modname = "__main__";
    if "__name__" in body.globals {
        gm = body.globals["__name__"];
        if isinstance(gm, PyStr) {
            modname = (gm as PyStr).val;
        }
    }
    bases_tuple = PyTuple(t="tuple", items=bases);
    prepared: PyObj = py_none();
    prep = class_lookup_attr(metaclass, "__prepare__");
    if not is_error(prep) {
        prep_args: list[PyObj] = [PyStr(t="str", val=class_name), bases_tuple];
        prepared = py_invoke(bind_attribute(prep, metaclass), prep_args, class_kwds);
        if is_error(prepared) {
            return prepared;
        }
    }
    # A custom mapping namespace (enum's _EnumDict, a dict subclass): run the body
    # into a plain ordered map, then replay each binding through the mapping's
    # __setitem__ so its member-tracking side effects fire in source order. The
    # mapping itself is handed to the metaclass as the classdict.
    if isinstance(prepared, PyUserObj) {
        namespace: dict[str, PyObj] = {};
        body_result = exec_code_frame(
            body.code, [], {}, body.globals, namespace, body.closure, [], {}
        );
        if body_result.t == "error" {
            return body_result;
        }
        mapping = prepared as PyUserObj;
        # CPython __build_class__ stores the ORIGINAL bases in the classdict
        # (after the body ran) whenever update_bases replaced any -- visible to
        # the metaclass call and later as cls.__orig_bases__.
        if bases_changed {
            res_ob = call_user_dunder(
                mapping, "__setitem__",
                [PyStr(t="str", val="__orig_bases__"),
                    PyTuple(t="tuple", items=orig_bases)]
            );
            if is_error(res_ob) {
                return res_ob;
            }
        }
        if user_has_dunder(mapping, "__setitem__") {
            for k in namespace {
                res = call_user_dunder(
                    mapping, "__setitem__", [PyStr(t="str", val=k), namespace[k]]
                );
                if is_error(res) {
                    return res;
                }
            }
        }
            # NOTE: no __name__ injection into custom mappings here - enum's
            # _EnumDict diverges from host on dunder writes (raises where host
            # ignores); the module identity is stamped on the RESULTING class
            # below instead, mirroring type.__new__'s frame-globals fallback.
        call_args: list[PyObj] = [
            PyStr(t="str", val=class_name),
            bases_tuple,
            prepared
        ];
        res_cls = py_invoke(metaclass, call_args, class_kwds);
        if is_error(res_cls) {
            return res_cls;
        }
        # Stamp the defining module onto classes whose classdict lacked
        # __module__ (type.__new__ derives it from the invoking frame's
        # globals; our native builder substitutes this explicit fallback).
        if isinstance(res_cls, PyClass) {
            rc = res_cls as PyClass;
            if "__module__" not in rc.attrs {
                rc.attrs["__module__"] = PyStr(t="str", val=modname);
            }
        }
        return res_cls;
    }
    # A plain-dict (or absent) namespace: seed, run the body, box a real dict.
    namespace2: dict[str, PyObj] = {"__name__": PyStr(t="str", val=modname)};
    if isinstance(prepared, PyDict) {
        prep_map = pydict_to_str_map(prepared as PyDict);
        for pk in prep_map {
            namespace2[pk] = prep_map[pk];
        }
    }
    if bases_changed {
        namespace2["__orig_bases__"] = PyTuple(t="tuple", items=orig_bases);
    }
    body_result2 = exec_code_frame(
        body.code, [], {}, body.globals, namespace2, body.closure, [], {}
    );
    if body_result2.t == "error" {
        return body_result2;
    }
    if "__classcell__" in namespace2 {
        del namespace2["__classcell__"];
    }
    ns_dict = dict_from_str_map(namespace2);
    call_args2: list[PyObj] = [PyStr(t="str", val=class_name), bases_tuple, ns_dict];
    made = py_invoke(metaclass, call_args2, class_kwds);
    if not is_error(made) and isinstance(body_result2, PyCell) {
        # Same __classcell__ seeding as the default-type path: the metaclass's
        # returned class object goes into the body's live cell.
        cc2 = body_result2 as PyCell;
        cc2.val = made;
        cc2.filled = True;
    }
    return made;
}

def make_function_from_stack(stack: list[PyObj], globals: dict[str, PyObj]) -> PyObj {
    if len(stack) == 0 {
        return py_error("RuntimeError", "MAKE_FUNCTION stack underflow");
    }
    code_obj = stack.pop();
    if code_obj.t != "code" {
        return py_error("TypeError", "MAKE_FUNCTION needs code");
    }
    code = code_obj as PyCode;
    return PyFunction(t="function", code=code, globals=globals, name=code.name);
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
            i = len(jac_frame_chain_slot) - 1;
            while i >= 0 {
                if jac_frame_chain_slot[i] is self {
                    if i > 0 {
                        return jac_frame_chain_slot[i - 1] as PyObj;
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

# next()/iter() as native callables (host_builtin routes these here) so they
# drive a native generator/iterator in-VM rather than draining it to a host list.
# Native shim "type" marker (isinstance-matchable shim classes): wraps a
# constructor callable and carries the PyObj.t tag its instances carry.
# py_isinstance answers marker matches with a single value.t comparison --
# no getattr probes, no host bridge. Registered by module shims that expose
# real class-shaped surfaces (traceback.FrameSummary, TracebackException).
obj ShimTypeMarker(PyObj) {
    has tag: str,
        ctor: PyObj;

    def tp_call(args: list[PyObj], kwargs: dict[str, PyObj]) -> PyObj {
        return (self.ctor as PyObj).tp_call(args, kwargs);
    }

    def tp_getattro(name2: str) -> PyObj {
        if name2 == "__jac_shim_tag__" {
            return PyStr(t="str", val=self.tag);
        }
        return (self.ctor as PyObj).tp_getattro(name2);
    }
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
            e = _handled_exc_stack[len(_handled_exc_stack) - 1];
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
            i = len(jac_frame_chain_slot) - 1 - depth;
            if i < 0 {
                return py_error("ValueError", "call stack is not deep enough");
            }
            return jac_frame_chain_slot[i] as PyObj;
        }
        if self.name == "sys_currentframe" {
            # sys.currentframe(): None where _getframe would raise -- only
            # possible in guest when no frame is executing at all.
            if len(jac_frame_chain_slot) == 0 {
                return py_none();
            }
            return jac_frame_chain_slot[len(jac_frame_chain_slot) - 1] as PyObj;
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
            e = current_handled_exc();
            if isinstance(e, PyNoneType) {
                return PyStr(t="str", val="NoneType: None\n");
            }
            return format_exception_text(e);
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
                e = current_handled_exc();
                if isinstance(e, PyNoneType) {
                    return py_error("RuntimeError", "No active exception to re-raise");
                }
                text = format_exception_text(e);
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
        if self.name == "type" {
            return py_type_call(self as PyObj, args, kwargs);
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
                    pairs = src;
                } else {
                    hsrc_r = to_host_coerce(src);
                    hsrc = hsrc_r[1];
                    if not ((hsrc_r[0] as bool)) {
                        return hsrc_r[1] as PyObj;
                    }
                    pairs = from_host(hsrc);
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
# sys._getframe() serves these frames natively via the "sys_getframe"
# native-builtin arm in PyNativeBuiltin.tp_call (frame chain in ceval_exec_frame.jac).

# Total merged localsplus size: [varnames][cellvars not shadowing a varname]
# [freevars] -- same layout localsplus_name resolves against.
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
        if kind != NB_OR and kind != NB_INPLACE_OR {
            return PY_NOT_IMPLEMENTED;
        }
        pairs_r = self.merge_pairs(other);
        if is_error(pairs_r) {
            if kind == NB_INPLACE_OR {
                return pairs_r;
            }
            return PY_NOT_IMPLEMENTED;
        }
        if kind == NB_INPLACE_OR {
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

def framelocals_richcompare(kind: int, lhs: PyObj, rhs: PyObj) -> PyObj {
    if isinstance(lhs, PyFrameLocalsProxy) {
        return (lhs as PyFrameLocalsProxy).tp_richcompare(kind, rhs);
    }
    # Reflected: proxy on the right, plain dict on the left.
    if isinstance(rhs, PyFrameLocalsProxy) and isinstance(lhs, PyDict) {
        return (rhs as PyFrameLocalsProxy).tp_richcompare(kind, lhs);
    }
    return PY_NOT_IMPLEMENTED;
}

# ---- native set methods (.pop/.difference/.union/... ) --------------------
# PySet is a native (na-clean leaf) container, so its methods can't route to the
# host the way str/list/dict do -- to_host would round-trip and lose identity.
# The method surface lives here (host-adjacent: arbitrary-iterable args are
# drained through py_iter/host_iter), wrapping the leaf's value-based set algebra.

# Drain an iterator to exhaustion, collecting the yielded values into a FRESH
# PyList. The first error the iterator propagates is returned verbatim.
def drain_to_list(it: PyObj) -> PyObj {
    out: list[PyObj] = [];
    while True {
        step = send_into(it, py_none());
        if step.t == "genstop" {
            break;
        }
        if is_error(step) {
            return step;
        }
        out.append(step);
    }
    return PyList(t="list", items=out);
}

# Materialize any iterable arg into a PyList of its members, or return a PyError
# if it is not iterable (this is the TypeError set().difference(123) must raise).
def members_of(arg: PyObj) -> PyObj {
    if isinstance(arg, PySet) {
        return PyList(t="list", items=(arg as PySet).set_members());
    }
    # A list arg needs no copy here: every consumer only READS the members
    # (set algebra). The list() ctor has its own path and always copies.
    if isinstance(arg, PyList) {
        return arg;
    }
    it = py_iter(arg);
    if is_error(it) {
        harg_r = to_host_coerce(arg);
        harg = harg_r[1];
        if not ((harg_r[0] as bool)) {
            return harg_r[1] as PyObj;
        }
        it = host_iter(PyHostProxy(t="host", val=harg));
        if is_error(it) {
            return it;
        }
    }
    return drain_to_list(it);
}

def set_from_members(members: list[PyObj], frozen: bool) -> PyObj {
    tag = "set";
    if frozen {
        tag = "frozenset";
    }
    s = PySet(t=tag, items={}, frozen=frozen);
    for m in members {
        r = s.set_add(m);
        if is_error(r) {
            return r;
        }
    }
    return s;
}

# Build a fresh PySet from one iterable arg (used to coerce a .difference([...])
# operand into set algebra). Propagates the not-iterable TypeError.
def coerce_set(arg: PyObj) -> PyObj {
    om = members_of(arg);
    if is_error(om) {
        return om;
    }
    return set_from_members((om as PyList).items, False);
}

def is_set_method(name: str, frozen: bool) -> bool {
    shared = name == "copy"
        or name == "union"
        or name == "intersection"
        or name == "difference"
        or name == "symmetric_difference"
        or name == "issubset"
        or name == "issuperset"
        or name == "isdisjoint"
        or name == "__contains__";
    if shared {
        return True;
    }
    if frozen {
        return False;
    }
    return name == "add"
        or name == "discard"
        or name == "remove"
        or name == "pop"
        or name == "clear"
        or name == "update"
        or name == "difference_update"
        or name == "intersection_update"
        or name == "symmetric_difference_update";
}

obj PySetMethod(PyObj) {
    has target: PySet,
        name: str;

    def tp_call(args: list[PyObj], kwargs: dict[str, PyObj]) -> PyObj {
        n = self.name;
        s = self.target;
        # CPython's set method descriptors enforce arity up front (owner-prefixed
        # TypeErrors) instead of silently ignoring extras; only the *others
        # set-algebra families are variadic. update takes no kwargs either.
        variadic = n == "union"
            or n == "intersection"
            or n == "difference"
            or n == "update"
            or n == "difference_update"
            or n == "intersection_update"
            or n == "symmetric_difference_update";
        if len(kwargs) > 0 {
            return meth_no_kwargs("set", n);
        }
        if not variadic {
            if n == "pop" or n == "copy" or n == "clear" {
                if len(args) != 0 {
                    return meth_takes_none("set", n, len(args));
                }
            } elif len(args) != 1 {
                return meth_takes_one("set", n, len(args));
            }
        }
        if n == "__contains__" {
            return s.set_lookup(args[0]);
        }
        # --- no-arg mutating / accessor methods ---
        if n == "pop" {
            return s.set_pop();
        }
        if n == "copy" {
            return s.set_copy();
        }
        if n == "clear" {
            return s.set_clear();
        }
        if n == "add" {
            return s.set_add(args[0]);
        }
        if n == "discard" {
            return s.set_discard(args[0]);
        }
        if n == "remove" {
            if not s.set_contains(args[0]) {
                return py_error("KeyError", dict_key_repr(args[0]));
            }
            return s.set_discard(args[0]);
        }
        # --- single-iterable-arg predicates ---
        if n == "issubset" or n == "issuperset" or n == "isdisjoint" {
            other = coerce_set(args[0]);
            if is_error(other) {
                return other;
            }
            os = other as PySet;
            if n == "issubset" {
                return set_richcompare(Py_LE, s, os);
            }
            if n == "issuperset" {
                return set_richcompare(Py_GE, s, os);
            }
            # isdisjoint: no shared member (element ``==``, not hashkey only).
            for hk in s.items {
                elem = s.items[hk];
                found = os.set_lookup(elem);
                if is_error(found) {
                    return found;
                }
                if (found as PyBool).val {
                    return PyBool(t="bool", val=False);
                }
            }
            return PyBool(t="bool", val=True);
        }
        # --- *others set-algebra (non-mutating) ---
        if n == "union"
            or n == "intersection"
            or n == "difference"
            or n == "symmetric_difference" {
            kind = NB_OR;
            if n == "intersection" {
                kind = NB_AND;
            } elif n == "difference" {
                kind = NB_SUBTRACT;
            } elif n == "symmetric_difference" {
                kind = NB_XOR;
            }
            acc = s.set_copy();
            for a in args {
                other = coerce_set(a);
                if is_error(other) {
                    return other;
                }
                acc = acc.nb_binop(kind, other as PySet);
                if is_error(acc) {
                    return acc;
                }
            }
            return acc;
        }
        # --- *others mutating updates ---
        if n == "update"
            or n == "difference_update"
            or n == "intersection_update"
            or n == "symmetric_difference_update" {
            kind = NB_OR;
            if n == "difference_update" {
                kind = NB_SUBTRACT;
            } elif n == "intersection_update" {
                kind = NB_AND;
            } elif n == "symmetric_difference_update" {
                kind = NB_XOR;
            }
            acc = s.set_copy();
            for a in args {
                other = coerce_set(a);
                if is_error(other) {
                    return other;
                }
                acc = acc.nb_binop(kind, other as PySet);
                if is_error(acc) {
                    return acc;
                }
            }
            # Write the result back into the receiver's storage in place.
            s.items = (acc as PySet).items;
            return py_none();
        }
        return py_error("AttributeError", n);
    }
}

# ---------------- native str methods ----------------
#
# The bound-method surface of boxed strings ('abc'.upper resolves to one of
# these), mirroring PyListMethod/PyDictMethod: dispatch runs entirely in-VM so
# lookups never round-trip a to_host COPY through host_getattr. Algorithms
# delegate to the underlying host string's own intrinsics after strict
# argument validation, so results (and the error messages below) stay
# byte-exact CPython -- including 3.14's lazy encode-error-handler lookup.
def is_str_method(name: str) -> bool {
    return name == "capitalize"
        or name == "casefold"
        or name == "center"
        or name == "count"
        or name == "encode"
        or name == "endswith"
        or name == "expandtabs"
        or name == "find"
        or name == "index"
        or name == "isalnum"
        or name == "isalpha"
        or name == "isascii"
        or name == "isdecimal"
        or name == "isdigit"
        or name == "isidentifier"
        or name == "islower"
        or name == "isnumeric"
        or name == "isprintable"
        or name == "isspace"
        or name == "istitle"
        or name == "isupper"
        or name == "join"
        or name == "ljust"
        or name == "lower"
        or name == "lstrip"
        or name == "maketrans"
        or name == "partition"
        or name == "removeprefix"
        or name == "removesuffix"
        or name == "replace"
        or name == "rfind"
        or name == "rindex"
        or name == "rjust"
        or name == "rpartition"
        or name == "rsplit"
        or name == "rstrip"
        or name == "split"
        or name == "splitlines"
        or name == "startswith"
        or name == "strip"
        or name == "swapcase"
        or name == "title"
        or name == "translate"
        or name == "upper"
        or name == "zfill";
}

obj PyStrMethod(PyObj) {
    has target: PyStr,
        name: str;

    def tp_call(args: list[PyObj], kwargs: dict[str, PyObj]) -> PyObj {
        return str_method_call(self.target.val, self.name, args, kwargs);
    }
}

# Positional-or-keyword argument fetch. Absent arguments come back as the
# PY_NOT_IMPLEMENTED sentinel (never a legit method argument).
def _sm_arg(args: list[PyObj], kwargs: dict[str, PyObj], idx: int, kwname: str) -> PyObj {
    if idx < len(args) {
        return args[idx];
    }
    if kwname in kwargs {
        return kwargs[kwname];
    }
    return PY_NOT_IMPLEMENTED;
}

def _sm_absent(o: PyObj) -> bool {
    return o.t == "notimplemented";
}

# METH_NOARGS arity: ``str.upper() takes no arguments (1 given)`` /
# ``str.lower() takes no keyword arguments``.
def _sm_noargs(n: str, args: list[PyObj], kwargs: dict[str, PyObj]) -> PyObj {
    if len(kwargs) > 0 {
        return py_error("TypeError", "str." + n + "() takes no keyword arguments");
    }
    if len(args) > 0 {
        return py_error("TypeError", "str." + n + "() takes no arguments (" + str(len(args)) + " given)");
    }
    return py_none();
}

# Exactly-one-argument methods (join/partition/zfill/translate/maketrans arg1):
# ``str.join() takes exactly one argument (2 given)``.
def _sm_one_arg(n: str, args: list[PyObj], kwargs: dict[str, PyObj]) -> PyObj {
    total = len(args) + len(kwargs);
    if total != 1 {
        return py_error("TypeError", "str." + n + "() takes exactly one argument (" + str(total) + " given)");
    }
    if len(args) == 1 {
        return args[0];
    }
    for kv in kwargs {
        return kwargs[kv];
    }
    return PY_NOT_IMPLEMENTED;
}

# Plain __index__ context (width/maxsplit/count/tabsize):
# "'<T>' object cannot be interpreted as an integer".
def _sm_int(o: PyObj) -> PyObj {
    r = o.to_index();
    if is_error(r) {
        return py_error("TypeError", "'" + o.tp_type_name() + "' object cannot be interpreted as an integer");
    }
    return r;
}

# Slice-index context (start/end): None passes through, anything else must
# index -- "slice indices must be integers or None or have an __index__ method".
def _sm_slice_int(o: PyObj) -> PyObj {
    if isinstance(o, PyNoneType) {
        return o;
    }
    r = o.to_index();
    if is_error(r) {
        return py_error("TypeError", "slice indices must be integers or None or have an __index__ method");
    }
    return r;
}

# Drain any native iterable into elems for join(); True iff supported.
def _sm_iter_elems(src: PyObj, elems: list[PyObj]) -> bool {
    if isinstance(src, PyList) {
        for x in (src as PyList).items { elems.append(x); }
        return True;
    }
    if isinstance(src, PyTuple) {
        for x in tuple_value(src) { elems.append(x); }
        return True;
    }
    if isinstance(src, PySet) {
        for x in (src as PySet).set_members() { elems.append(x); }
        return True;
    }
    if isinstance(src, PyDict) {
        d = src as PyDict;
        for hk in d.items { elems.append(d.items[hk].key); }
        return True;
    }
    if isinstance(src, PyStr) {
        for ch in (src as PyStr).val { elems.append(PyStr(t="str", val=ch)); }
        return True;
    }
    if isinstance(src, PyIter) {
        it = src as PyIter;
        i = it.index;
        while i < len(it.items) { elems.append(it.items[i]); i = i + 1; }
        return True;
    }
    return False;
}

# str.encode with byte-exact UnicodeEncodeError construction. Intrinsic codecs
# (utf-8/ascii/latin-1) match their alias tables, then every codepoint is
# pre-scanned so the host intrinsic only ever sees fully encodable input (its
# exceptions would otherwise escape the VM unconverted). Every OTHER encoding
# mirrors CPython's PyCodec_Encode route through the codec registry by crossing
# to the host codec machinery, so registry-resolved C codecs (gb2312, euc-jp,
# ...) work and failures come back with their live exception identity.
def _sm_encode(s: str, encoding: str, errors: str) -> PyObj {
    enc = encoding.lower().replace("_", "-");
    limit = 1114111;
    canon = "utf-8";
    surrogates_only = False;
    if enc == "utf-8" or enc == "utf8" {
        surrogates_only = True;
    } elif enc == "ascii" or enc == "us-ascii" or enc == "us" or enc == "646" or enc == "ansi_x3.4-1968" or enc == "iso-ir-6" or enc == "iso646-us" or enc == "csascii" or enc == "cp367" or enc == "ibm367" {
        limit = 127;
        canon = "ascii";
    } elif enc == "latin-1" or enc == "latin1" or enc == "iso-8859-1" or enc == "iso8859-1" or enc == "l1" or enc == "8859-1" or enc == "cp819" or enc == "iso-ir-100" or enc == "latin" or enc == "cp28591" {
        limit = 255;
        canon = "latin-1";
    } else {
        # Registry-resolved encoding: delegate to the host codec machinery
        # (CPython str.encode semantics, including lazy handler validation).
        res = _jac_host_str_encode(s, encoding, errors);
        if host_result_ok(res) {
            return from_host(res[1]);
        }
        return host_result_error(res);
    }
    # Pre-scan for the first unencodable codepoint.
    bad_pos = -1;
    bad_cp = 0;
    i = 0;
    while i < len(s) {
        cp = ord(s[i]);
        viol = False;
        if surrogates_only {
            viol = cp >= 0xD800 and cp <= 0xDFFF;
        } else {
            viol = cp > limit;
        }
        if viol {
            bad_pos = i;
            bad_cp = cp;
            break;
        }
        i = i + 1;
    }
    out: list[int] = [];
    if bad_pos < 0 {
        bb = s.encode(encoding);
        for v in bb { out.append(v); }
        return PyBytes(t="bytes", val=out);
    }
    # An error was actually consulted: validate the handler now (3.14 semantics).
    h = errors.lower().replace("_", "-").replace(" ", "");
    known = h == "strict" or h == "ignore" or h == "replace"
        or h == "backslashreplace" or h == "xmlcharrefreplace";
    if not known {
        return py_error("LookupError", "unknown error handler name '" + errors + "'");
    }
    if h == "strict" {
        reason = "ordinal not in range(" + str(limit + 1) + ")";
        if surrogates_only {
            reason = "surrogates not allowed";
        }
        msg = "'" + canon + "' codec can't encode character '"
            + _repr_unicode_escape(bad_cp) + "' in position " + str(bad_pos) + ": " + reason;
        return py_error("UnicodeEncodeError", msg);
    }
    i = 0;
    while i < len(s) {
        ch = s[i];
        cp = ord(ch);
        viol = False;
        if surrogates_only {
            viol = cp >= 0xD800 and cp <= 0xDFFF;
        } else {
            viol = cp > limit;
        }
        if not viol {
            bb2 = ch.encode(encoding);
            for v in bb2 { out.append(v); }
        } elif h == "ignore" {
        } elif h == "replace" {
            out.append(63);
        } elif h == "backslashreplace" {
            esc = _repr_unicode_escape(cp);
            j = 0;
            while j < len(esc) { out.append(ord(esc[j])); j = j + 1; }
        } else {
            ref = "&#" + str(cp) + ";";
            j = 0;
            while j < len(ref) { out.append(ord(ref[j])); j = j + 1; }
        }
        i = i + 1;
    }
    return PyBytes(t="bytes", val=out);
}

# The full str method surface. `s` is the receiver's raw value.
def str_method_call(s: str, n: str, args: list[PyObj], kwargs: dict[str, PyObj]) -> PyObj {
    # ---- no-arg transforms ----
    if n == "upper" or n == "lower" or n == "capitalize" or n == "casefold"
        or n == "swapcase" or n == "title" {
        e = _sm_noargs(n, args, kwargs);
        if is_error(e) { return e; }
        r = s;
        if n == "upper" { r = s.upper(); }
        elif n == "lower" { r = s.lower(); }
        elif n == "capitalize" { r = s.capitalize(); }
        elif n == "casefold" { r = s.casefold(); }
        elif n == "swapcase" { r = s.swapcase(); }
        else { r = s.title(); }
        return PyStr(t="str", val=r);
    }
    # ---- no-arg predicates ----
    if n == "isalpha" or n == "isalnum" or n == "isascii" or n == "isdecimal"
        or n == "isdigit" or n == "isidentifier" or n == "islower"
        or n == "isnumeric" or n == "isprintable" or n == "isspace"
        or n == "istitle" or n == "isupper" {
        e = _sm_noargs(n, args, kwargs);
        if is_error(e) { return e; }
        b = False;
        if n == "isalpha" { b = s.isalpha(); }
        elif n == "isalnum" { b = s.isalnum(); }
        elif n == "isascii" { b = s.isascii(); }
        elif n == "isdecimal" { b = s.isdecimal(); }
        elif n == "isdigit" { b = s.isdigit(); }
        elif n == "isidentifier" { b = s.isidentifier(); }
        elif n == "islower" { b = s.islower(); }
        elif n == "isnumeric" { b = s.isnumeric(); }
        elif n == "isprintable" { b = s.isprintable(); }
        elif n == "isspace" { b = s.isspace(); }
        elif n == "istitle" { b = s.istitle(); }
        else { b = s.isupper(); }
        return PyBool(t="bool", val=b);
    }
    # ---- padding / alignment ----
    if n == "center" or n == "ljust" or n == "rjust" {
        wobj = _sm_arg(args, kwargs, 0, "width");
        if _sm_absent(wobj) {
            return py_error("TypeError", n + " expected at least 1 argument, got 0");
        }
        w = _sm_int(wobj);
        if is_error(w) { return w; }
        fill = " ";
        fobj = _sm_arg(args, kwargs, 1, "fillchar");
        if not _sm_absent(fobj) {
            if not isinstance(fobj, PyStr) {
                return py_error("TypeError", "The fill character must be a unicode character, not " + fobj.tp_type_name());
            }
            fill = (fobj as PyStr).val;
            if len(fill) != 1 {
                return py_error("TypeError", "The fill character must be exactly one character long");
            }
        }
        r = "";
        if n == "center" { r = s.center((w as PyInt).val, fill); }
        elif n == "ljust" { r = s.ljust((w as PyInt).val, fill); }
        else { r = s.rjust((w as PyInt).val, fill); }
        return PyStr(t="str", val=r);
    }
    if n == "zfill" {
        a = _sm_one_arg(n, args, kwargs);
        if is_error(a) { return a; }
        w = _sm_int(a);
        if is_error(w) { return w; }
        return PyStr(t="str", val=s.zfill((w as PyInt).val));
    }
    if n == "expandtabs" {
        if len(args) + len(kwargs) > 1 {
            return py_error("TypeError", "expandtabs() takes at most 1 argument (" + str(len(args) + len(kwargs)) + " given)");
        }
        tsize = 8;
        tobj = _sm_arg(args, kwargs, 0, "tabsize");
        if not _sm_absent(tobj) {
            ti = _sm_int(tobj);
            if is_error(ti) { return ti; }
            tsize = (ti as PyInt).val;
        }
        return PyStr(t="str", val=s.expandtabs(tsize));
    }
    # ---- strip family ----
    if n == "strip" or n == "lstrip" or n == "rstrip" {
        chars: any = None;
        cobj = _sm_arg(args, kwargs, 0, "chars");
        if not _sm_absent(cobj) {
            if not (isinstance(cobj, PyStr) or isinstance(cobj, PyNoneType)) {
                return py_error("TypeError", n + " arg must be None or str");
            }
            if isinstance(cobj, PyStr) { chars = (cobj as PyStr).val; }
        }
        r = "";
        if chars is None {
            if n == "strip" { r = s.strip(); }
            elif n == "lstrip" { r = s.lstrip(); }
            else { r = s.rstrip(); }
        } else {
            if n == "strip" { r = s.strip(chars); }
            elif n == "lstrip" { r = s.lstrip(chars); }
            else { r = s.rstrip(chars); }
        }
        return PyStr(t="str", val=r);
    }
    # ---- split family ----
    if n == "split" or n == "rsplit" {
        sep: any = None;
        sep_given = False;
        sobj = _sm_arg(args, kwargs, 0, "sep");
        if not _sm_absent(sobj) {
            if not (isinstance(sobj, PyStr) or isinstance(sobj, PyNoneType)) {
                return py_error("TypeError", "must be str or None, not " + sobj.tp_type_name());
            }
            if isinstance(sobj, PyStr) {
                sep = (sobj as PyStr).val;
                if len(sep) == 0 {
                    return py_error("ValueError", "empty separator");
                }
            }
            sep_given = True;
        }
        ms = -1;
        mobj = _sm_arg(args, kwargs, 1, "maxsplit");
        if not _sm_absent(mobj) {
            mi = _sm_int(mobj);
            if is_error(mi) { return mi; }
            ms = (mi as PyInt).val;
        }
        parts: list[str] = [];
        if not sep_given {
            if n == "split" { parts = s.split(None, ms); }
            else { parts = s.rsplit(None, ms); }
        } else {
            if n == "split" { parts = s.split(sep, ms); }
            else { parts = s.rsplit(sep, ms); }
        }
        items: list[PyObj] = [];
        for p in parts { items.append(PyStr(t="str", val=p)); }
        return PyList(t="list", items=items);
    }
    if n == "splitlines" {
        keep = False;
        kobj = _sm_arg(args, kwargs, 0, "keepends");
        if not _sm_absent(kobj) {
            kt = py_slot_truth(kobj);
            if is_error(kt) { return kt; }
            keep = (kt as PyBool).val;
        }
        parts: list[str] = [];
        if keep { parts = s.splitlines(True); } else { parts = s.splitlines(); }
        items: list[PyObj] = [];
        for p in parts { items.append(PyStr(t="str", val=p)); }
        return PyList(t="list", items=items);
    }
    # ---- partition ----
    if n == "partition" or n == "rpartition" {
        a = _sm_one_arg(n, args, kwargs);
        if is_error(a) { return a; }
        if not isinstance(a, PyStr) {
            return py_error("TypeError", "must be str, not " + a.tp_type_name());
        }
        sv = (a as PyStr).val;
        if len(sv) == 0 {
            return py_error("ValueError", "empty separator");
        }
        tup: tuple[str, str, str] = ("", "", "");
        if n == "partition" { tup = s.partition(sv); }
        else { tup = s.rpartition(sv); }
        items: list[PyObj] = [];
        for p in tup { items.append(PyStr(t="str", val=p)); }
        return PyTuple(t="tuple", items=items);
    }
    # ---- find family + count ----
    if n == "find" or n == "rfind" or n == "index" or n == "rindex" or n == "count" {
        sub = _sm_arg(args, kwargs, 0, "sub");
        if _sm_absent(sub) {
            return py_error("TypeError", n + " expected at least 1 argument, got 0");
        }
        if not isinstance(sub, PyStr) {
            return py_error("TypeError", n + "() argument 1 must be str, not " + sub.tp_type_name());
        }
        stv: any = None;
        env: any = None;
        sob = _sm_arg(args, kwargs, 1, "start");
        if not _sm_absent(sob) {
            si = _sm_slice_int(sob);
            if is_error(si) { return si; }
            stv = (si as PyInt).val;
        }
        eob = _sm_arg(args, kwargs, 2, "end");
        if not _sm_absent(eob) {
            ei = _sm_slice_int(eob);
            if is_error(ei) { return ei; }
            env = (ei as PyInt).val;
        }
        sv = (sub as PyStr).val;
        r = 0;
        if n == "rfind" or n == "rindex" { r = s.rfind(sv, stv, env); }
        elif n == "count" { r = s.count(sv, stv, env); }
        else { r = s.find(sv, stv, env); }
        if (n == "index" or n == "rindex") and r == -1 {
            return py_error("ValueError", "subsection not found");
        }
        return PyInt(t="int", val=r);
    }
    # ---- startswith / endswith ----
    if n == "startswith" or n == "endswith" {
        pfx = _sm_arg(args, kwargs, 0, n + "fix");
        if _sm_absent(pfx) {
            return py_error("TypeError", n + " expected at least 1 argument, got 0");
        }
        affs: any = None;
        if isinstance(pfx, PyStr) {
            affs = (pfx as PyStr).val;
        } elif isinstance(pfx, PyTuple) {
            ts: list[str] = [];
            for itp in tuple_value(pfx) {
                if not isinstance(itp, PyStr) {
                    return py_error("TypeError", "tuple for " + n + " must only contain str, not " + itp.tp_type_name());
                }
                ts.append((itp as PyStr).val);
            }
            affs = tuple(ts);
        } else {
            return py_error("TypeError", n + " first arg must be str or a tuple of str, not " + pfx.tp_type_name());
        }
        stv: any = None;
        env: any = None;
        sob = _sm_arg(args, kwargs, 1, "start");
        if not _sm_absent(sob) {
            si = _sm_slice_int(sob);
            if is_error(si) { return si; }
            stv = (si as PyInt).val;
        }
        eob = _sm_arg(args, kwargs, 2, "end");
        if not _sm_absent(eob) {
            ei = _sm_slice_int(eob);
            if is_error(ei) { return ei; }
            env = (ei as PyInt).val;
        }
        b = False;
        if n == "startswith" { b = s.startswith(affs, stv, env); }
        else { b = s.endswith(affs, stv, env); }
        return PyBool(t="bool", val=b);
    }
    # ---- replace ----
    if n == "replace" {
        oobj = _sm_arg(args, kwargs, 0, "old");
        nobj = _sm_arg(args, kwargs, 1, "new");
        if _sm_absent(oobj) or _sm_absent(nobj) {
            given = len(args) + len(kwargs);
            return py_error("TypeError", "replace() takes at least 2 positional arguments (" + str(given) + " given)");
        }
        if not isinstance(oobj, PyStr) {
            return py_error("TypeError", "replace() argument 1 must be str, not " + oobj.tp_type_name());
        }
        if not isinstance(nobj, PyStr) {
            return py_error("TypeError", "replace() argument 2 must be str, not " + nobj.tp_type_name());
        }
        cnt = -1;
        cobj = _sm_arg(args, kwargs, 2, "count");
        if not _sm_absent(cobj) {
            ci = _sm_int(cobj);
            if is_error(ci) { return ci; }
            cnt = (ci as PyInt).val;
        }
        return PyStr(t="str", val=s.replace((oobj as PyStr).val, (nobj as PyStr).val, cnt));
    }
    # ---- removeprefix / removesuffix ----
    if n == "removeprefix" or n == "removesuffix" {
        a = _sm_one_arg(n, args, kwargs);
        if is_error(a) { return a; }
        if not isinstance(a, PyStr) {
            return py_error("TypeError", n + "() argument must be str, not " + a.tp_type_name());
        }
        av = (a as PyStr).val;
        if n == "removeprefix" { return PyStr(t="str", val=s.removeprefix(av)); }
        return PyStr(t="str", val=s.removesuffix(av));
    }
    # ---- join ----
    if n == "join" {
        a = _sm_one_arg(n, args, kwargs);
        if is_error(a) { return a; }
        elems: list[PyObj] = [];
        if not _sm_iter_elems(a, elems) {
            itres = PyObject_GetIter(a);
            if is_error(itres) {
                return py_error("TypeError", "can only join an iterable");
            }
            drained = drain_to_list(itres);
            if is_error(drained) { return drained; }
            elems = (drained as PyList).items;
        }
        acc = "";
        i = 0;
        while i < len(elems) {
            el = elems[i];
            if not isinstance(el, PyStr) {
                return py_error("TypeError", "sequence item " + str(i) + ": expected str instance, " + el.tp_type_name() + " found");
            }
            if i > 0 { acc = acc + s; }
            acc = acc + (el as PyStr).val;
            i = i + 1;
        }
        return PyStr(t="str", val=acc);
    }
    # ---- translate ----
    if n == "translate" {
        table = _sm_one_arg(n, args, kwargs);
        if is_error(table) { return table; }
        out = "";
        i = 0;
        while i < len(s) {
            res = table.mp_subscript(PyInt(t="int", val=ord(s[i])));
            if is_error(res) {
                etn = (res as PyError).exception.type_name;
                if etn != "KeyError" {
                    if etn == "TypeError" {
                        return py_error("TypeError", "'" + table.tp_type_name() + "' object is not subscriptable");
                    }
                    return res;
                }
                out = out + s[i];
            } elif isinstance(res, PyNoneType) {
            } elif isinstance(res, PyStr) {
                out = out + (res as PyStr).val;
            } elif isinstance(res, PyInt) {
                cp = (res as PyInt).val;
                if cp < 0 or cp > 1114111 {
                    return py_error("ValueError", "character mapping must be in range(0x110000)");
                }
                out = out + chr(cp);
            } else {
                return py_error("TypeError", "character mapping must return integer, None or str");
            }
            i = i + 1;
        }
        return PyStr(t="str", val=out);
    }
    # ---- maketrans (staticmethod, reachable from instances too) ----
    if n == "maketrans" {
        if len(kwargs) > 0 {
            return py_error("TypeError", "str.maketrans() takes no keyword arguments");
        }
        if len(args) == 0 or len(args) > 3 {
            return py_error("TypeError", "maketrans expected at least 1 argument, got " + str(len(args)));
        }
        x = args[0];
        d = PyDict(t="dict", items={});
        if isinstance(x, PyStr) {
            if len(args) < 2 {
                return py_error("TypeError", "if you give only one argument to maketrans it must be a dict");
            }
            y = args[1];
            if not isinstance(y, PyStr) {
                return py_error("TypeError", "maketrans() argument 2 must be str, not " + y.tp_type_name());
            }
            xv = (x as PyStr).val;
            yv = (y as PyStr).val;
            if len(xv) != len(yv) {
                return py_error("ValueError", "the first two maketrans arguments must have equal length");
            }
            i = 0;
            while i < len(xv) {
                se = d.dict_set(PyInt(t="int", val=ord(xv[i])), PyInt(t="int", val=ord(yv[i])));
                if is_error(se) { return se; }
                i = i + 1;
            }
        } elif isinstance(x, PyDict) {
            if len(args) > 1 {
                return py_error("TypeError", "first maketrans argument must be a string if there is a second argument");
            }
            xd = x as PyDict;
            for hk in xd.items {
                ko = xd.items[hk].key;
                vo = xd.items[hk].value;
                nk: PyObj = ko;
                if isinstance(ko, PyStr) {
                    kv = (ko as PyStr).val;
                    if len(kv) != 1 {
                        return py_error("TypeError", "keys in translate table mustbe strings or integers");
                    }
                    nk = PyInt(t="int", val=ord(kv));
                } elif isinstance(ko, PyBool) {
                    bv = 0;
                    if (ko as PyBool).val { bv = 1; }
                    nk = PyInt(t="int", val=bv);
                } elif not isinstance(ko, PyInt) {
                    return py_error("TypeError", "keys in translate table mustbe strings or integers");
                }
                se = d.dict_set(nk, vo);
                if is_error(se) { return se; }
            }
        } else {
            return py_error("TypeError", "first maketrans argument must be a string if there is a second argument");
        }
        if len(args) == 3 {
            z = args[2];
            if not isinstance(z, PyStr) {
                return py_error("TypeError", "maketrans() argument 3 must be str, not " + z.tp_type_name());
            }
            zv = (z as PyStr).val;
            i = 0;
            while i < len(zv) {
                se = d.dict_set(PyInt(t="int", val=ord(zv[i])), py_none());
                if is_error(se) { return se; }
                i = i + 1;
            }
        }
        return d;
    }
    # ---- encode ----
    if n == "encode" {
        enc = "utf-8";
        errs = "strict";
        eobj = _sm_arg(args, kwargs, 0, "encoding");
        if not _sm_absent(eobj) {
            if not isinstance(eobj, PyStr) {
                return py_error("TypeError", "encode() argument 'encoding' must be str, not " + eobj.tp_type_name());
            }
            enc = (eobj as PyStr).val;
        }
        robj = _sm_arg(args, kwargs, 1, "errors");
        if not _sm_absent(robj) {
            if not isinstance(robj, PyStr) {
                return py_error("TypeError", "encode() argument 'errors' must be str, not " + robj.tp_type_name());
            }
            errs = (robj as PyStr).val;
        }
        return _sm_encode(s, enc, errs);
    }
    return py_error("AttributeError", n);
}

# Native mutating/accessor list methods. Without these, `lst.append(x)` routes to
# host_getattr on a to_host COPY of the list -- the mutation is lost. Load-bearing
# for any code that builds a list by `.append` (enum's EnumDict._member_names
# tracking, most stdlib), not just comprehensions (which use LIST_APPEND).
def is_list_method(name: str) -> bool {
    return name == "append"
        or name == "extend"
        or name == "insert"
        or name == "pop"
        or name == "remove"
        or name == "clear"
        or name == "index"
        or name == "count"
        or name == "reverse"
        or name == "sort"
        or name == "copy";
}

# Materialize the elements of a native iterable argument (list/tuple/set/iter).
def iterable_items(src: PyObj) -> list[PyObj] {
    if isinstance(src, PyList) {
        return (src as PyList).items;
    }
    if isinstance(src, PyTuple) {
        return (src as PyTuple).items;
    }
    if isinstance(src, PySet) {
        return (src as PySet).set_members();
    }
    if isinstance(src, PyIter) {
        return (src as PyIter).items;
    }
    it = py_iter(src);
    if isinstance(it, PyIter) {
        return (it as PyIter).items;
    }
    return [];
}

# Materialize any iterable into a fresh list, propagating iteration errors.
def iter_drain(src: PyObj) -> PyObj {
    it = py_iter(src);
    if is_error(it) {
        return it;
    }
    out: list[PyObj] = [];
    while True {
        step = send_into(it, py_none());
        if step.t == "genstop" {
            break;
        }
        if is_error(step) {
            return step;
        }
        out.append(step);
    }
    return PyList(t="list", items=out);
}

# sorted()/max()/min(): natively served so key= (a VM callable) actually runs.
# sorted reuses list_sort_inplace's decorate-sort-undecorate machinery, so
# key=/reverse= behave exactly like list.sort(). max/min follow CPython: one
# positional iterable (with default= for emptiness) or several positionals,
# ties keep the first candidate, key failures and comparison failures raise.
def builtin_sorted_min_max(name: str, args: list[PyObj], kwargs: dict[str, PyObj]) -> PyObj {
    is_sorted = name == "sorted";
    key_fn = py_none();
    do_reverse = False;
    has_default = False;
    default_val = py_none();
    for kw in kwargs {
        if kw == "key" {
            key_fn = kwargs[kw];
        } elif is_sorted and kw == "reverse" {
            rev = py_slot_truth(kwargs[kw]);
            if is_error(rev) {
                return rev;
            }
            do_reverse = (rev as PyBool).val;
        } elif not is_sorted and kw == "default" {
            has_default = True;
            default_val = kwargs[kw];
        } else {
            return py_error("TypeError", "'" + kw + "' is an invalid keyword argument for " + name + "()");
        }
    }
    if is_sorted {
        # CPython's sorted is (iterable, /): both under- and over-calls report
        # the plain "expected 1 argument" clinic wording.
        if len(args) != 1 {
            return py_error("TypeError", name + " expected 1 argument, got " + str(len(args)));
        }
        drained = iter_drain(args[0]);
        if is_error(drained) {
            return drained;
        }
        out = drained as PyList;
        err = list_sort_inplace(out, key_fn, do_reverse);
        if is_error(err) {
            return err;
        }
        return out as PyObj;
    }
    if len(args) == 0 {
        return py_error("TypeError", name + " expected at least 1 argument, got 0");
    }
    candidates: list[PyObj] = [];
    if len(args) == 1 {
        drained = iter_drain(args[0]);
        if is_error(drained) {
            return drained;
        }
        candidates = (drained as PyList).items;
    } else {
        if has_default {
            return py_error("TypeError", "Cannot specify a default for " + name + "() with multiple positional arguments");
        }
        candidates = args;
    }
    best: PyObj | None = None;
    best_key: PyObj | None = None;
    for v in candidates {
        k = v;
        if not (key_fn.t == "none") {
            k = key_fn.tp_call([v], {});
            if is_error(k) {
                return k;
            }
        }
        take = best is None;
        if not take {
            if name == "max" {
                cmp = py_compare(0, best_key as PyObj, k);
            } else {
                cmp = py_compare(0, k, best_key as PyObj);
            }
            if is_error(cmp) {
                return cmp;
            }
            ctruth = py_slot_truth(cmp);
            if is_error(ctruth) {
                return ctruth;
            }
            take = (ctruth as PyBool).val;
        }
        if take {
            best = v;
            best_key = k;
        }
    }
    if best is None {
        if has_default {
            return default_val;
        }
        return py_error("ValueError", name + "() iterable argument is empty");
    }
    return best as PyObj;
}

# CPython list.sort(): stable merge sort driven by py_compare(<). key= uses
# decorate-sort-undecorate; reverse= flips the comparison (NOT the tie-break),
# so equal elements keep insertion order in both directions. Mutates lst in
# place; returns an error from a failing comparison, else None.
def list_sort_inplace(lst: PyList, key_fn: PyObj, do_reverse: bool) -> PyObj {
    n_count = len(lst.items);
    if n_count <= 1 {
        return py_none();
    }
    pairs: list[PyObj] = [];
    idx = 0;
    while idx < n_count {
        v = lst.items[idx];
        k = v;
        if not (key_fn.t == "none") {
            res = key_fn.tp_call([v], {});
            if is_error(res) {
                return res;
            }
            k = res;
        }
        pairs.append(PyTuple(t="tuple", items=[k, v]));
        idx = idx + 1;
    }
    width = 1;
    while width < n_count {
        merged: list[PyObj] = [];
        i = 0;
        while i < n_count {
            mid = i + width;
            hi = i + 2 * width;
            if mid > n_count {
                mid = n_count;
            }
            if hi > n_count {
                hi = n_count;
            }
            a = i;
            b = mid;
            while a < mid and b < hi {
                ka = ((pairs[a] as PyTuple).items[0]);
                kb = ((pairs[b] as PyTuple).items[0]);
                # Normal order takes b when kb < ka; reverse takes b when
                # ka < kb. Ties always take a, which is what keeps the sort
                # stable in both directions.
                if do_reverse {
                    lt = py_compare(0, ka, kb);
                } else {
                    lt = py_compare(0, kb, ka);
                }
                if is_error(lt) {
                    return lt;
                }
                if (lt as PyBool).val {
                    merged.append(pairs[b]);
                    b = b + 1;
                } else {
                    merged.append(pairs[a]);
                    a = a + 1;
                }
            }
            while a < mid {
                merged.append(pairs[a]);
                a = a + 1;
            }
            while b < hi {
                merged.append(pairs[b]);
                b = b + 1;
            }
            i = i + 2 * width;
        }
        pairs = merged;
        width = width * 2;
    }
    sorted_items: list[PyObj] = [];
    for p in pairs {
        sorted_items.append((p as PyTuple).items[1]);
    }
    lst.items = sorted_items;
    return py_none();
}

# Bound __iter__ on a native container: calling it produces the NATIVE
# iterator (dict views carry mutation staleness; list/set/tuple/str iterate
# live storage) instead of bridging to a host slot wrapper whose returned
# iterator is an eager snapshot, silently losing mutation visibility
# (test_dict CrazyDict exc62/65 family).
obj PyNativeIterMethod(PyObj) {
    has target: PyObj;

    def tp_call(args: list[PyObj], kwargs: dict[str, PyObj]) -> PyObj {
        if len(args) > 0 or len(kwargs) > 0 {
            return py_error("TypeError", "__iter__() takes no arguments");
        }
        return py_iter(self.target);
    }
}

# Bound __next__ on a native iterator: advances via the same send_into path
# FOR_ITER uses, so staleness errors propagate and exhaustion raises
# StopIteration (catchable by name) instead of a silent genstop.
obj PyNativeNextMethod(PyObj) {
    has target: PyObj;

    def tp_call(args: list[PyObj], kwargs: dict[str, PyObj]) -> PyObj {
        step = send_into(self.target, py_none());
        if step.t == "genstop" {
            return py_error("StopIteration", "");
        }
        return step;
    }
}

obj PyListMethod(PyObj) {
    has target: PyList,
        name: str;

    def tp_call(args: list[PyObj], kwargs: dict[str, PyObj]) -> PyObj {
        n = self.name;
        lst = self.target;
        if n == "append" {
            lst.items.append(args[0]);
            return py_none();
        }
        if n == "extend" {
            for x in iterable_items(args[0]) {
                lst.items.append(x);
            }
            return py_none();
        }
        if n == "insert" {
            i = (args[0].to_index() as PyInt).val;
            if i < 0 {
                i = len(lst.items) + i;
            }
            if i < 0 {
                i = 0;
            }
            if i > len(lst.items) {
                i = len(lst.items);
            }
            rebuilt: list[PyObj] = [];
            j = 0;
            while j < len(lst.items) {
                if j == i {
                    rebuilt.append(args[1]);
                }
                rebuilt.append(lst.items[j]);
                j = j + 1;
            }
            if i >= len(lst.items) {
                rebuilt.append(args[1]);
            }
            lst.items = rebuilt;
            return py_none();
        }
        if n == "pop" {
            if len(lst.items) == 0 {
                return py_error("IndexError", "pop from empty list");
            }
            i = len(lst.items) - 1;
            if len(args) >= 1 {
                i = (args[0].to_index() as PyInt).val;
                if i < 0 {
                    i = len(lst.items) + i;
                }
            }
            if i < 0 or i >= len(lst.items) {
                return py_error("IndexError", "pop index out of range");
            }
            v = lst.items[i];
            kept: list[PyObj] = [];
            j = 0;
            while j < len(lst.items) {
                if j != i {
                    kept.append(lst.items[j]);
                }
                j = j + 1;
            }
            lst.items = kept;
            return v;
        }
        if n == "remove" {
            j = 0;
            while j < len(lst.items) {
                if list_elem_eq(lst.items[j], args[0]) {
                    kept2: list[PyObj] = [];
                    k = 0;
                    while k < len(lst.items) {
                        if k != j {
                            kept2.append(lst.items[k]);
                        }
                        k = k + 1;
                    }
                    lst.items = kept2;
                    return py_none();
                }
                j = j + 1;
            }
            return py_error("ValueError", "list.remove(x): x not in list");
        }
        if n == "clear" {
            lst.items = [];
            return py_none();
        }
        if n == "index" {
            j = 0;
            while j < len(lst.items) {
                if list_elem_eq(lst.items[j], args[0]) {
                    return PyInt(t="int", val=j);
                }
                j = j + 1;
            }
            return py_error("ValueError", "not in list");
        }
        if n == "count" {
            c = 0;
            for x in lst.items {
                if list_elem_eq(x, args[0]) {
                    c = c + 1;
                }
            }
            return PyInt(t="int", val=c);
        }
        if n == "reverse" {
            rev: list[PyObj] = [];
            j = len(lst.items) - 1;
            while j >= 0 {
                rev.append(lst.items[j]);
                j = j - 1;
            }
            lst.items = rev;
            return py_none();
        }
        if n == "sort" {
            if len(args) != 0 {
                return py_error("TypeError", "sort() takes no positional arguments");
            }
            key_fn = py_none();
            do_reverse = False;
            for kw in kwargs {
                if kw == "key" {
                    key_fn = kwargs[kw];
                } elif kw == "reverse" {
                    truth = py_slot_truth(kwargs[kw]);
                    if is_error(truth) {
                        return truth;
                    }
                    do_reverse = (truth as PyBool).val;
                } else {
                    return py_error("TypeError", "'" + kw + "' is an invalid keyword argument for sort()");
                }
            }
            return list_sort_inplace(lst, key_fn, do_reverse);
        }
        if n == "copy" {
            dup: list[PyObj] = [];
            for x in lst.items {
                dup.append(x);
            }
            return PyList(t="list", items=dup);
        }
        return py_error("AttributeError", n);
    }
}

# Element equality for list membership (remove/index/count): a real __eq__ so a
# user object or boxed value compares by value, not identity.
def list_elem_eq(a: PyObj, b: PyObj) -> bool {
    res = py_compare(2, a, b);
    if isinstance(res, PyBool) {
        return (res as PyBool).val;
    }
    return False;
}

# The native mutating/accessor dict methods. keys()/values()/items() are served
# separately by PyDictViewCtor; these must be native too so that a mutation on a
# dict subclass instance (enum's EnumDict.setdefault/pop) hits the real storage
# instead of a throwaway to_host copy.
def is_dict_method(name: str) -> bool {
    return name == "get"
        or name == "setdefault"
        or name == "pop"
        or name == "popitem"
        or name == "update"
        or name == "clear"
        or name == "copy"
        or name == "__contains__"
        or name == "__getitem__"
        or name == "__setitem__"
        or name == "__delitem__";
}

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
obj PyAbsent(PyObj) {}

# Membership test for a key, confirming a hashkey-bucket hit with a real eq when
# either side carries a custom __eq__. Returns PyBool or a PyError (raising eq).
def dict_haskey(d: PyDict, key: PyObj) -> PyObj {
    hkr = key.tp_hashkey();
    if is_error(hkr) {
        return py_error("TypeError", "unhashable type");
    }
    hk = hashkey_str(hkr);
    if not (hk in d.items) {
        return PyBool(t="bool", val=False);
    }
    stored = d.items[hk].key;
    if _needs_eq_confirm(stored) or _needs_eq_confirm(key) {
        keq = py_compare(2, stored, key);
        if is_error(keq) {
            return keq;
        }
        # py_slot_truth returns a PyBool on success -- hand it straight back.
        return py_slot_truth(keq);
    }
    return PyBool(t="bool", val=True);
}

# The stored value for a key, a PyAbsent sentinel if not present, or a PyError.
def dict_lookup_value(d: PyDict, key: PyObj) -> PyObj {
    hkr = key.tp_hashkey();
    if is_error(hkr) {
        return py_error("TypeError", "unhashable type");
    }
    hk = hashkey_str(hkr);
    if not (hk in d.items) {
        return PyAbsent(t="absent");
    }
    stored = d.items[hk].key;
    if _needs_eq_confirm(stored) or _needs_eq_confirm(key) {
        keq = py_compare(2, stored, key);
        if is_error(keq) {
            return keq;
        }
        truth = py_slot_truth(keq);
        if is_error(truth) {
            return truth;
        }
        if not (truth as PyBool).val {
            return PyAbsent(t="absent");
        }
    }
    return d.items[hk].value;
}

# The bound method object d.keys / d.values / d.items resolves to; calling it
# builds the view (matching CPython, where `d.keys` is a builtin method and
# `d.keys()` is the view).
# Bound has_default() on a PEP 695 TypeVar (PEP 696): zero-arg probe of
# whether a default was supplied at parameter creation -- purely syntactic,
# never forces default evaluation.
obj PyTypeVarMethod(PyObj) {
    has tv: PyTypeVar,
        name: str;

    def tp_call(args: list[PyObj], kwargs: dict[str, PyObj]) -> PyObj {
        if len(kwargs) > 0 {
            return meth_no_kwargs("TypeVar", self.name);
        }
        if len(args) != 0 {
            return meth_takes_none("TypeVar", self.name, len(args));
        }
        # CPython typevar_has_default_impl is syntactic: an evaluator or an
        # eagerly-constructed non-sentinel default answers True without ever
        # forcing lazy evaluation.
        if self.tv.evaluate_default.t != "none" {
            return PyBool(t="bool", val=True);
        }
        if self.tv.default_resolved {
            return PyBool(
                t="bool",
                val=not ((self.tv.cached_default as PyObj) is no_default_sentinel()),
            );
        }
        return PyBool(t="bool", val=False);
    }
}

obj PyDictViewCtor(PyObj) {
    has d: PyDict,
        mode: str;

    def tp_call(args: list[PyObj], kwargs: dict[str, PyObj]) -> PyObj {
        if len(kwargs) > 0 {
            return meth_no_kwargs("dict", self.mode);
        }
        if len(args) != 0 {
            return meth_takes_none("dict", self.mode, len(args));
        }
        return PyDictView(t="dictview_obj", d=self.d, mode=self.mode);
    }
}

obj PyDictView(PyObj) {
    has d: PyDict,
        mode: str;

    def tp_type_name -> str {
        return "dict_" + self.mode;
    }

    def tp_iter -> PyObj {
        return self.d.dict_iter(self.mode);
    }

    def tp_bool -> bool {
        return len(self.d.items) != 0;
    }

    def tp_richcompare(kind: int, other: PyObj) -> PyObj {
        return dictview_richcompare(kind, self, other);
    }

    def nb_binop(kind: int, other: PyObj) -> PyObj {
        return dictview_binop(kind, self, other);
    }
}

# The view's elements as PyObjs: keys, values, or (key, value) tuples.
def dictview_elements(view: PyDictView) -> list[PyObj] {
    out: list[PyObj] = [];
    for hk in view.d.items {
        `entry = view.d.items[hk];
        if view.mode == "values" {
            out.append(`entry.value);
        } elif view.mode == "items" {
            out.append(PyTuple(t="tuple", items=[`entry.key, `entry.value]));
        } else {
            out.append(`entry.key);
        }
    }
    return out;
}

# Element-wise containment that invokes __eq__ where CPython does: a keys/values
# element by comparison, an items (k, v) pair by key lookup + value compare.
def view_contains(view: PyDictView, elem: PyObj) -> PyObj {
    if view.mode == "keys" {
        return dict_haskey(view.d, elem);
    }
    if view.mode == "items" {
        if not isinstance(elem, PyTuple) {
            return PyBool(t="bool", val=False);
        }
        pair = elem as PyTuple;
        if len(pair.items) != 2 {
            return PyBool(t="bool", val=False);
        }
        look = dict_lookup_value(view.d, pair.items[0]);
        if is_error(look) {
            return look;
        }
        if look.t == "absent" {
            return PyBool(t="bool", val=False);
        }
        return py_compare(2, pair.items[1], look);
    }
    # values view: linear scan, comparing each stored value.
    for hk in view.d.items {
        c = py_compare(2, view.d.items[hk].value, elem);
        if is_error(c) {
            return c;
        }
        ctruth = py_slot_truth(c);
        if is_error(ctruth) {
            return ctruth;
        }
        if (ctruth as PyBool).val {
            return PyBool(t="bool", val=True);
        }
    }
    return PyBool(t="bool", val=False);
}

# Elements of any set-like operand (view / native set / dict[keys]).
def setlike_elements(o: PyObj) -> list[PyObj] {
    if isinstance(o, PyDictView) {
        return dictview_elements(o as PyDictView);
    }
    if isinstance(o, PySet) {
        return (o as PySet).set_members();
    }
    if isinstance(o, PyDict) {
        return (o as PyDict).dict_keys();
    }
    return [];
}

def setlike_count(o: PyObj) -> int {
    if isinstance(o, PyDictView) {
        return len((o as PyDictView).d.items);
    }
    if isinstance(o, PySet) {
        return len((o as PySet).items);
    }
    if isinstance(o, PyDict) {
        return len((o as PyDict).items);
    }
    return len(setlike_elements(o));
}

# elem in a set-like container, routing to the eq-invoking path per container.
def setlike_contains(container: PyObj, elem: PyObj) -> PyObj {
    if isinstance(container, PyDictView) {
        return view_contains(container as PyDictView, elem);
    }
    if isinstance(container, PySet) {
        return (container as PySet).set_lookup(elem);
    }
    if isinstance(container, PyDict) {
        return dict_haskey(container as PyDict, elem);
    }
    return py_contains(container, elem);
}

# True iff every element of x is contained in y (PyBool), or a PyError if an
# element comparison raised. The subset primitive under set-like comparison.
def all_contained(x: PyObj, y: PyObj) -> PyObj {
    for e in setlike_elements(x) {
        c = setlike_contains(y, e);
        if is_error(c) {
            return c;
        }
        ctruth = py_slot_truth(c);
        if is_error(ctruth) {
            return ctruth;
        }
        if not (ctruth as PyBool).val {
            return PyBool(t="bool", val=False);
        }
    }
    return PyBool(t="bool", val=True);
}

# CPython dict-view set comparison (==, !=, <, <=, >, >=). Both operands are
# treated as sets; an element __eq__ raised mid-comparison propagates.
def dictview_richcompare(kind: int, a: PyObj, b: PyObj) -> PyObj {
    la = setlike_count(a);
    lb = setlike_count(b);
    if kind == 2 {
        if la != lb {
            return PyBool(t="bool", val=False);
        }
        return all_contained(a, b);
    }
    if kind == 3 {
        if la != lb {
            return PyBool(t="bool", val=True);
        }
        r = all_contained(a, b);
        if is_error(r) {
            return r;
        }
        truth = py_slot_truth(r);
        if is_error(truth) {
            return truth;
        }
        return PyBool(t="bool", val=not (truth as PyBool).val);
    }
    if kind == 1 {
        return all_contained(a, b);
    }
    if kind == 5 {
        return all_contained(b, a);
    }
    if kind == 0 {
        if not (la < lb) {
            return PyBool(t="bool", val=False);
        }
        return all_contained(a, b);
    }
    if kind == 4 {
        if not (la > lb) {
            return PyBool(t="bool", val=False);
        }
        return all_contained(b, a);
    }
    return py_ordering_type_error(kind, a, b, _compare_type_name);
}

# Coerce a set-op operand to a PySet: a view materializes its elements, a set
# passes through, anything else is drained as an iterable (propagating the
# not-iterable TypeError).
def to_set_like(o: PyObj) -> PyObj {
    if isinstance(o, PySet) {
        return o;
    }
    if isinstance(o, PyDictView) {
        return set_from_members(dictview_elements(o as PyDictView), False);
    }
    return coerce_set(o);
}

# Dict-view set algebra (| & - ^) with a view on either side, producing a PySet.
def dictview_binop(kind: int, lhs: PyObj, rhs: PyObj) -> PyObj {
    ls = to_set_like(lhs);
    if is_error(ls) {
        return ls;
    }
    rs = to_set_like(rhs);
    if is_error(rs) {
        return rs;
    }
    return (ls as PySet).nb_binop(kind, rs as PySet);
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
obj PyAsyncGenASend(PyObj) {
    has gen: PyGenerator,
        value: PyObj,
        started: bool = False;
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
        gen_qualname: str = "";

    def tp_iter -> PyObj {
        # An async generator is driven exclusively through __anext__/asend;
        # CPython gives it no tp_iter at all.
        if self.t == "async_generator" {
            return py_error("TypeError", "'async_generator' object is not iterable");
        }
        return self;
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
                return PyGenFrame(t="genframe", gen=self);
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
            return PyGenFrame(t="genframe", gen=self);
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

# Normalize gen.throw(a[, b[, c]]) operands into the error to inject, following
# CPython _gen_throw: instance with a separate value is rejected; a type is
# instantiated with the value; anything else is a TypeError naming its type.
# (The 2/3-arg form carries a DeprecationWarning upstream; the VM has no warning
# machinery yet, so only the behavior is mirrored here.)
def normalize_throw_args(args: list[PyObj]) -> PyObj {
    typ = args[0];
    val = py_none();
    if len(args) >= 2 {
        val = args[1];
    }
    if len(args) == 3 and args[2].t != "none" {
        return py_error("TypeError", "throw() third argument must be a traceback object");
    }
    if isinstance(typ, PyHostProxy) {
        # Host-proxied exception classes/instances (the non-layer3 builtin
        # surface). Same normalization order as CPython, decided over the raw
        # host object.
        raw = (typ as PyHostProxy).val;
        inst_info = _jac_host_exception_instance(raw);
        if inst_info[0] as bool {
            if val.t != "none" {
                return py_error("TypeError", "instance exception may not have a separate value");
            }
            return as_error(typ);
        }
        if bool(_jac_is_exception_type(raw)) {
            if val.t == "none" {
                return as_error(typ);
            }
            inst = typ.tp_call([val], {});
            if is_error(inst) {
                return inst;
            }
            return py_raise_value(inst);
        }
    }
    if typ.t == "exception"
        or (isinstance(typ, PyUserObj)
            and class_is_exception((typ as PyUserObj).cls)) {
        # Raising an instance: the value must be a dummy.
        if val.t != "none" {
            return py_error("TypeError", "instance exception may not have a separate value");
        }
        return as_error(typ);
    }
    if typ.t == "exception_type" {
        if val.t == "none" {
            return as_error(typ);
        }
        return PyError(
            t="error",
            exception=(typ as PyExceptionType).tp_call([val], {}) as PyException,
        );
    }
    if isinstance(typ, PyClass) and class_is_exception(typ as PyClass) {
        if val.t == "none" {
            return as_error(typ);
        }
        inst = (typ as PyClass).tp_call([val], {});
        if is_error(inst) {
            return inst;
        }
        return py_raise_value(inst);
    }
    # Not something you can throw.
    type_label = "object";
    tn = py_type_of(typ);
    if isinstance(tn, PyClass) {
        type_label = (tn as PyClass).name;
    } elif isinstance(tn, PyHostProxy) {
        nm = (tn as PyHostProxy).tp_getattro("__name__");
        if not is_error(nm) and isinstance(nm, PyStr) {
            type_label = (nm as PyStr).val;
        }
    }
    return py_error(
        "TypeError",
        "exceptions must be classes or instances deriving from BaseException, not "
            + type_label
    );
}

# Resume `gen` with `sent` (the value YIELD_VALUE produces on wake; None for
# plain iteration). Returns the yielded PyObj on a yield, a PyGenStop on normal
# return (exhaustion), or a propagating error object on a raise.
def gen_resume(gen: PyGenerator, sent: PyObj) -> PyObj {    if gen.running {
        # CPython: resuming a generator whose frame is already executing
        # (self-resume via a callback/trampoline) raises ValueError.
        return py_error("ValueError", "generator already executing");
    }
    if gen.finished {
        if gen.t == "coroutine" {
            # CPython coro_send: a finished coroutine cannot be driven again.
            return py_error("RuntimeError", "cannot reuse already awaited coroutine");
        }
        return PyGenStop(t="genstop", val=py_none());
    }
    if gen.started {
        # YIELD_VALUE popped its operand when it suspended; the resume value
        # takes its place on the stack (the trailing POP_TOP discards it in a
        # genexpr; `x = yield` would bind it in a full generator).
        gen.frame.stack.append(sent);
    }
    gen.started = True;
    gen.running = True;
    result = run_frame(gen.frame);
    return finish_gen_result(gen, result);
}

# Common tail for every generator re-entry (resume/send/throw): translate the
# raw run_frame outcome into the yielded value | PyGenStop(return value) | error
# shape that all generator drivers speak.
def finish_gen_result(gen: PyGenerator, result: PyObj) -> PyObj {
    gen.running = False;
    if is_error(result) {
        gen.finished = True;
        if gen.t == "async_generator"
            and ((result as PyError).exception).type_name == "StopAsyncIteration" {
            # genobject.c gen_send_ex2: StopAsyncIteration escaping an async
            # generator's body means the generator tried to end its own
            # iteration -- the RuntimeError analogue of PEP 479's StopIteration
            # guard for sync generators.
            return py_error("RuntimeError", "async generator raised StopAsyncIteration");
        }
        return result;
    }
    if result.t == "yield" {
        return (result as PyYield).val;
    }
    gen.finished = True;
    return PyGenStop(t="genstop", val=result);
}

# gen.send(v): resume with v, returning the next yielded value or raising
# StopIteration(return_value) on exhaustion. A just-started generator only
# accepts None (CPython raises TypeError otherwise).
def gen_send(gen: PyGenerator, sent: PyObj) -> PyObj {
    if not gen.started and not gen.finished and sent.t != "none" {
        return py_error(
            "TypeError", "can't send non-None value to a just-started generator"
        );
    }
    result = gen_resume(gen, sent);
    if result.t == "genstop" {
        return stop_iteration((result as PyGenStop).val);
    }
    return result;
}

# StopIteration carrying the generator's return value as its .value payload.
# CPython gen_send_ex raises StopIteration(value), so the payload must also
# materialize through args -> .args / __str__ / __repr__ (StopIteration(42),
# not an argless StopIteration() hiding its payload in .value alone). A None
# payload (bare return / fall-off-end) stays argless exactly like the host:
# StopIteration(), args=(), .value=None.
def stop_iteration(value: PyObj) -> PyObj {
    if value.t == "none" {
        return PyError(
            t="error",
            exception=PyException(
                t="exception", type_name="StopIteration", message="", value=value
            ),
        );
    }
    return PyError(
        t="error",
        exception=PyException(
            t="exception",
            type_name="StopIteration",
            message="",
            args=[value],
            value=value
        ),
    );
}

# Coerce a thrown operand (exception instance, exception type, or already-raised
# error) into a PyError for injection at the suspend point.
def as_error(value: PyObj) -> PyObj {
    if value.t == "error" {
        return value;
    }
    return py_raise_value(value);
}

# gen.throw(exc): resume the generator as though `exc` were raised at the point
# where it last suspended, so a try/except surrounding the yield can catch it.
def gen_throw(gen: PyGenerator, thrown: PyObj) -> PyObj {
    if gen.running {
        return py_error("ValueError", "generator already executing");
    }
    err = as_error(thrown);
    if err.t != "error" {
        return err;
    }
    if gen.finished and gen.t == "coroutine" {
        # Same reuse guard as gen_resume: throwing into a finished coroutine
        # reports the re-await, not the injected exception (CPython coro throw).
        return py_error("RuntimeError", "cannot reuse already awaited coroutine");
    }
    if not gen.started or gen.finished {
        # Nothing suspended to resume into: the exception propagates directly.
        gen.finished = True;
        return err;
    }
    frame = gen.frame;
    if frame.yf {
        # Suspended inside `yield from`: delegate the throw into the sub-iterator
        # by re-running the SEND loop in throw mode. SEND's existing yield /
        # exhaustion / error handling then completes or unwinds the yield-from.
        frame.pending_throw = err;
        frame.stack.append(py_none());  # sent-value placeholder SEND reads below
        gen.running = True;
        return finish_gen_result(gen, run_frame(frame));
    }
    # frame.ip sits one instruction past YIELD_VALUE; the handler lookup wants
    # the yield's own offset (YIELD_VALUE has no inline cache, so -2 bytes).
    offset = frame.ip - 2;
    target = recover_exception(frame.co, err, offset, frame.stack);
    if target < 0 {
        gen.finished = True;
        return err;
    }
    frame.ip = target;
    gen.running = True;
    result = run_frame(frame);
    return finish_gen_result(gen, result);
}

# Throw `err` into a yield-from sub-iterator (the SEND-in-throw-mode step).
# Returns the same yielded-value | PyGenStop | error shape as send_into.
def send_throw_into(receiver: PyObj, err: PyObj) -> PyObj {
    if receiver.t == "generator" or receiver.t == "coroutine" {
        return gen_throw(receiver as PyGenerator, err);
    }
    # A non-generator sub-iterator with a .throw() gets it; otherwise the
    # exception simply propagates at the delegation point.
    thrower = py_attr(receiver, "throw");
    if is_error(thrower) {
        return err;
    }
    result = py_invoke(thrower, [(err as PyError).exception], {});
    if is_error(result) {
        exc = (result as PyError).exception;
        if exc_is_stopiter(exc) {
            payload = py_none();
            if exc.value is not None {
                payload = exc.value as PyObj;
            }
            return PyGenStop(t="genstop", val=payload);
        }
        return result;
    }
    return result;
}

# Release a frame's held references (fast locals, evaluation stack, cell
# contents) and run __del__ finalizers on any user object thereby dropped. This
# models CPython's frame teardown on gen.close()/gi_frame.clear(): a local whose
# last reference lived in the frame is finalized. We approximate "last reference"
# by the common case the generator machinery guarantees -- an argument passed
# straight into the generator call is reachable only through its frame -- since
# jacpython does not carry Python-level refcounts. Idempotent via frame.cleared.
def frame_clear(frame: PyFrame) -> None {
    if frame.cleared {
        return;
    }
    frame.cleared = True;
    held: list[PyObj] = [];
    idx = 0;
    while idx < len(frame.fast) {
        # Converted (cell) slots release the cell's contents; plain slots release
        # their value when bound. Covers dynamically MAKE_CELL'd slots too.
        slot_entry = frame.fast[idx];
        if isinstance(slot_entry, PyCell) {
            held.append((slot_entry as PyCell).val);
        } elif idx < len(frame.assigned) and frame.assigned[idx] {
            held.append(slot_entry);
        }
        idx = idx + 1;
    }
    for item in frame.stack {
        held.append(item);
    }
    for name in frame.locals {
        held.append(frame.locals[name]);
    }
    if frame.exc_state is not None {
        # Abandoned (never-resumed/closed) generator: its suspended handler
        # entries were already removed at suspend time EXCEPT when cleared
        # mid-handling after a resume -- drain any residual copies.
        _handled_stack_remove_each(frame.exc_state as list[PyObj]);
    }
    frame.fast = [];
    frame.stack = [];
    frame.locals = {};
    for obj in held {
        if isinstance(obj, PyUserObj)
            and user_has_dunder(obj as PyUserObj, "__del__") {
            _ = call_user_dunder(obj as PyUserObj, "__del__", []);
        }
    }
}

# A generator's gi_frame surface: only .clear() is modeled (the frame-teardown
# entry point CPython exposes), which releases the suspended frame's locals and
# finalizes any user object dropped -- then marks the generator exhausted.
obj PyGenFrame(PyObj) {
    has gen: PyGenerator;

    def tp_getattro(name: str) -> PyObj {
        if name == "clear" {
            return PyGenFrameClear(t="genframe_clear", gen=self.gen);
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

# Native copy.copy / copy.deepcopy. Generators (and coroutines) are uncopyable in
# CPython -- no __copy__/__reduce_ex__ support, so copy raises TypeError -- and a
# native generator can't cross to_host as a live generator anyway (it would drain
# to a list, spuriously succeeding). Every other value delegates to host copy.
obj PyCopyFn(PyObj) {
    has deep: bool;

    # Identity hash: same stdlib set/dict-key surface as the weakref shim.
    def tp_hashkey -> PyObj {
        return PyStr(t="str", val="obj:" + str(id(self)));
    }

    def tp_call(args: list[PyObj], kwargs: dict[str, PyObj]) -> PyObj {
        if len(args) < 1 {
            return py_error("TypeError", "copy expected at least 1 argument");
        }
        if isinstance(args[0], PyGenerator) {
            return py_error("TypeError", "cannot pickle 'generator' object");
        }
        mod = host_import("copy", py_none());
        if is_error(mod) {
            return mod;
        }
        fnname = "copy";
        if self.deep {
            fnname = "deepcopy";
        }
        fn = mod.tp_getattro(fnname);
        if is_error(fn) {
            return fn;
        }
        return py_invoke(fn, args, kwargs);
    }
}

# The native `copy` module, seeded into a Layer-1 namespace so a test that does
# copy.copy(gen) sees CPython's TypeError natively (the host proxy would drain).
# Shared un-weakreferenceable gate: the boxed builtin shapes CPython rejects in
# get_or_create_weakref, plus host proxies (deref would mint a fresh proxy and
# break `r() is o` identity). Shared by weakref.ref and the _weakref facade
# entry points in jacpython/weakref.jac.
def weakref_target_rejected(target: PyObj) -> bool {
    return isinstance(target, PyHostProxy) or isinstance(target, PyInt)
        or isinstance(target, PyFloat) or isinstance(target, PyBool)
        or isinstance(target, PyStr) or isinstance(target, PyBytes)
        or isinstance(target, PyTuple) or isinstance(target, PyList)
        or isinstance(target, PyDict) or isinstance(target, PySet)
        or isinstance(target, PyNoneType);
}

# The canonical rejection TypeError, byte-matching CPython's
# "cannot create weak reference to '%s' object" formatting.
def weakref_target_error(target: PyObj) -> PyObj {
    tname = "object";
    tn = py_type_of(target);
    if isinstance(tn, PyClass) {
        tname = (tn as PyClass).name;
    }
    return py_error("TypeError", "cannot create weak reference to '" + tname + "' object");
}

# Native weakref module surface (shimmed over host weakref). CPython-faithful
# for objects whose RAW Python identity is the object itself (PyUserObj,
# PyClass, functions, generators): deref hands back the identical object, and
# death follows refcounting exactly. Boxed value types (int/str/list/...) are
# rejected up front because CPython makes them un-weakreferenceable, and host
# proxies are rejected because deref would mint a fresh proxy and break
# `r() is o` identity.
obj PyWeakRefFn(PyObj) {
    # Identity hash (CPython: builtin-style callables hash by id); copy.py's
    # module init stores these wrappers in hash-keyed dispatch structures.
    def tp_hashkey -> PyObj {
        return PyStr(t="str", val="obj:" + str(id(self)));
    }

    def tp_call(args: list[PyObj], kwargs: dict[str, PyObj]) -> PyObj {
        if len(args) != 1 {
            # callback= / weakref.ref(cls) forms unsupported by this surface.
            return py_error("TypeError", "weakref.ref expected 1 argument");
        }
        target = args[0];
        if weakref_target_rejected(target) {
            return weakref_target_error(target);
        }
        wr = _jac_make_weakref(target);
        if wr is None {
            return py_error("TypeError", "cannot create weak reference to 'object' object");
        }
        return PyWeakRef(t="weakref", wr=wr);
    }
}

obj PyWeakRef(PyObj) {
    has wr: any;

    def tp_call(args: list[PyObj], kwargs: dict[str, PyObj]) -> PyObj {
        raw = _jac_weakref_deref(self.wr);
        if raw is None {
            return py_none();
        }
        # The raw value IS the original PyObj: identity (`r() is o`) holds.
        return raw as PyObj;
    }
}

# Native types.coroutine fast path: mark a generator function's code object
# CO_ITERABLE_COROUTINE (0x100) in place, exactly like CPython mutates
# func.__code__, so GET_AWAITABLE accepts the generators it produces. Callables
# that are not native generator functions pass through unchanged (CPython would
# wrap their returned generators; the VM has no faithful equivalent yet).
obj PyTypesCoroutine(PyObj) {
    def tp_call(args: list[PyObj], kwargs: dict[str, PyObj]) -> PyObj {
        if len(args) != 1 or len(kwargs) > 0 {
            return py_error("TypeError", "coroutine() expects a callable");
        }
        fn = args[0];
        if isinstance(fn, PyFunction) {
            co = (fn as PyFunction).code;
            if (co.flags & 0x180) == 0 and (co.flags & 32) != 0 {
                co.flags = co.flags | 256;
            }
        }
        return fn;
    }
}

# Facade over the real host `types` module for the proxy import path: every
# public member stays the same host object that direct proxying would serve,
# with coroutine swapped for the native implementation above.
def build_signal_facade -> PyObj {
    # signalmodule.c lift: start from the delegated host snapshot (OS-bound
    # surface: alarm, itimers, pthread_sigmask, sigwait family, wakeup fd,
    # strsignal, valid_signals, Signals/Handlers/Sigmasks enums) and overlay
    # the guest-native constants plus the synchronous dispatch core from
    # signal.jac. Same facade-over-host composition as build_types_facade.
    mod = delegated_module("signal");
    if is_error(mod) {
        return mod;
    }
    m = mod as PyModule;
    native = signal_module_attrs();
    for k in native {
        m.attrs[k] = native[k];
    }
    return mod;
}

def build_types_facade -> PyObj {
    star: list[PyObj] = [PyStr(t="str", val="*")];
    result = _jac_host_import("types", star);
    attrs: dict[str, PyObj] = {};
    if host_result_ok(result) {
        host_mod = result[1];
        names = _jac_star_names(host_mod);
        if host_result_ok(names) {
            for nm in names[1] {
                member = _jac_host_getattr(host_mod, nm);
                if host_result_ok(member) {
                    attrs[nm] = PyHostProxy(t="host", val=member[1]);
                }
            }
        }
    }
    attrs["coroutine"] = PyTypesCoroutine(t="types_coroutine");
    return PyModule(t="module", name="types", attrs=attrs);
}

def build_weakref_module -> PyObj {
    return PyModule(
        t="module",
        name="weakref",
        attrs={
            "ref": PyWeakRefFn(t="weakref_fn"),
        },
    );
}

# ---- heapq product-path shim ----------------------------------------------
# CPython's heapq.py is pure Python, but served from the host every guest list
# crosses as MUTABLE_COPY: heappush/heapify mutate the copy and the guest's
# heap never changes. These natives run the Lib/heapq.py algorithms over the
# LIVE PyList storage instead (Modules/_heapqmodule.c semantics).

# LT via the shared rich-compare dispatch: guest objects compare with full
# __lt__ semantics. Returns the comparison result or the error to propagate.
def _hq_lt(a: PyObj, b: PyObj) -> PyObj {
    return py_compare(0, a, b);
}

# Error-channel convention for the sift helpers: py_none() on success, any
# error result propagates upward unchanged.
def _hqsift_down(items: list[PyObj], startpos: int, pos: int) -> PyObj {
    newitem: PyObj = items[pos];
    while pos > startpos {
        parentpos = (pos - 1) >> 1;
        parent: PyObj = items[parentpos];
        c = _hq_lt(newitem, parent);
        if is_error(c) {
            return c;
        }
        if not ((c as PyBool).val) {
            break;
        }
        items[pos] = parent;
        pos = parentpos;
    }
    items[pos] = newitem;
    return py_none();
}

def _hqsift_up(items: list[PyObj], pos: int) -> PyObj {
    endpos = len(items);
    startpos = pos;
    newitem: PyObj = items[pos];
    childpos = 2 * pos + 1;
    while childpos < endpos {
        rightpos = childpos + 1;
        if rightpos < endpos {
            c = _hq_lt(items[childpos], items[rightpos]);
            if is_error(c) {
                return c;
            }
            if not ((c as PyBool).val) {
                childpos = rightpos;
            }
        }
        items[pos] = items[childpos];
        pos = childpos;
        childpos = 2 * pos + 1;
    }
    items[pos] = newitem;
    return _hqsift_down(items, startpos, pos);
}

# Max-heap variants of the sift helpers (heapq.py's _siftdown_max/_siftup_max,
# backed in CPython by the private _heapqmodule.c functions).

def _hqsift_down_max(items: list[PyObj], startpos: int, pos: int) -> PyObj {
    newitem: PyObj = items[pos];
    while pos > startpos {
        parentpos = (pos - 1) >> 1;
        parent: PyObj = items[parentpos];
        c = _hq_lt(parent, newitem);
        if is_error(c) {
            return c;
        }
        if not ((c as PyBool).val) {
            break;
        }
        items[pos] = parent;
        pos = parentpos;
    }
    items[pos] = newitem;
    return py_none();
}

def _hqsift_up_max(items: list[PyObj], pos: int) -> PyObj {
    endpos = len(items);
    startpos = pos;
    newitem: PyObj = items[pos];
    childpos = 2 * pos + 1;
    while childpos < endpos {
        rightpos = childpos + 1;
        if rightpos < endpos {
            c = _hq_lt(items[rightpos], items[childpos]);
            if is_error(c) {
                return c;
            }
            if (c as PyBool).val {
                childpos = rightpos;
            }
        }
        items[pos] = items[childpos];
        pos = childpos;
        childpos = 2 * pos + 1;
    }
    items[pos] = newitem;
    return _hqsift_down_max(items, startpos, pos);
}

# Shared arity/heap-type gate for all entry points.
def _hq_heap_arg(args: list[PyObj], n: int, fname: str) -> PyList | PyObj {
    if len(args) != n {
        return py_error(
            "TypeError", fname + " expected " + str(n) + " arguments, got " + str(len(args))
        );
    }
    h = args[0];
    if not isinstance(h, PyList) {
        return py_error("TypeError", "heap argument must be a list");
    }
    return h as PyList;
}

obj PyHeapqFn(PyObj) {
    has name: str;

    # Identity hash (builtin-style callable; stdlib stores these in sets).
    def tp_hashkey -> PyObj {
        return PyStr(t="str", val="obj:" + str(id(self)));
    }

    def tp_call(args: list[PyObj], kwargs: dict[str, PyObj]) -> PyObj {
        n = self.name;
        if n == "heapify" {
            h_r = _hq_heap_arg(args, 1, "heapify");
            if not isinstance(h_r, PyList) {
                return h_r as PyObj;
            }
            items: list[PyObj] = (h_r as PyList).items;
            i = len(items) // 2;
            while i > 0 {
                i = i - 1;
                r = _hqsift_up(items, i);
                if is_error(r) {
                    return r;
                }
            }
            return py_none();
        }
        if n == "heappush" {
            h_r = _hq_heap_arg(args, 2, "heappush");
            if not isinstance(h_r, PyList) {
                return h_r as PyObj;
            }
            items2: list[PyObj] = (h_r as PyList).items;
            items2.append(args[1]);
            return _hqsift_down(items2, 0, len(items2) - 1);
        }
        if n == "heappop" {
            h_r = _hq_heap_arg(args, 1, "heappop");
            if not isinstance(h_r, PyList) {
                return h_r as PyObj;
            }
            items3: list[PyObj] = (h_r as PyList).items;
            lastelt: PyObj = items3[len(items3) - 1];
            items3.pop();
            if len(items3) > 0 {
                returnitem: PyObj = items3[0];
                items3[0] = lastelt;
                r = _hqsift_up(items3, 0);
                if is_error(r) {
                    return r;
                }
                return returnitem;
            }
            return lastelt;
        }
        if n == "heapreplace" {
            h_r = _hq_heap_arg(args, 2, "heapreplace");
            if not isinstance(h_r, PyList) {
                return h_r as PyObj;
            }
            items4: list[PyObj] = (h_r as PyList).items;
            if len(items4) == 0 {
                return py_error("IndexError", "index out of range");
            }
            returnitem2: PyObj = items4[0];
            items4[0] = args[1];
            r2 = _hqsift_up(items4, 0);
            if is_error(r2) {
                return r2;
            }
            return returnitem2;
        }
        if n == "heappushpop" {
            h_r = _hq_heap_arg(args, 2, "heappushpop");
            if not isinstance(h_r, PyList) {
                return h_r as PyObj;
            }
            items5: list[PyObj] = (h_r as PyList).items;
            item: PyObj = args[1];
            if len(items5) == 0 {
                return item;
            }
            c = _hq_lt(items5[0], item);
            if is_error(c) {
                return c;
            }
            if (c as PyBool).val {
                oldtop: PyObj = items5[0];
                items5[0] = item;
                r3 = _hqsift_up(items5, 0);
                if is_error(r3) {
                    return r3;
                }
                return oldtop;
            }
            return item;
        }
        if n == "heappush_max" {
            h_r = _hq_heap_arg(args, 2, "heappush_max");
            if not isinstance(h_r, PyList) {
                return h_r as PyObj;
            }
            items6: list[PyObj] = (h_r as PyList).items;
            items6.append(args[1]);
            return _hqsift_down_max(items6, 0, len(items6) - 1);
        }
        if n == "heappop_max" {
            h_r = _hq_heap_arg(args, 1, "heappop_max");
            if not isinstance(h_r, PyList) {
                return h_r as PyObj;
            }
            items7: list[PyObj] = (h_r as PyList).items;
            lastelt2: PyObj = items7[len(items7) - 1];
            items7.pop();
            if len(items7) > 0 {
                returnitem3: PyObj = items7[0];
                items7[0] = lastelt2;
                r4 = _hqsift_up_max(items7, 0);
                if is_error(r4) {
                    return r4;
                }
                return returnitem3;
            }
            return lastelt2;
        }
        if n == "heapify_max" {
            h_r = _hq_heap_arg(args, 1, "heapify_max");
            if not isinstance(h_r, PyList) {
                return h_r as PyObj;
            }
            items8: list[PyObj] = (h_r as PyList).items;
            i = len(items8) // 2;
            while i > 0 {
                i = i - 1;
                r5 = _hqsift_up_max(items8, i);
                if is_error(r5) {
                    return r5;
                }
            }
            return py_none();
        }
        if n == "heapreplace_max" {
            h_r = _hq_heap_arg(args, 2, "heapreplace_max");
            if not isinstance(h_r, PyList) {
                return h_r as PyObj;
            }
            items9: list[PyObj] = (h_r as PyList).items;
            if len(items9) == 0 {
                return py_error("IndexError", "index out of range");
            }
            returnitem4: PyObj = items9[0];
            items9[0] = args[1];
            r6 = _hqsift_up_max(items9, 0);
            if is_error(r6) {
                return r6;
            }
            return returnitem4;
        }
        if n == "heappushpop_max" {
            h_r = _hq_heap_arg(args, 2, "heappushpop_max");
            if not isinstance(h_r, PyList) {
                return h_r as PyObj;
            }
            items10: list[PyObj] = (h_r as PyList).items;
            item2: PyObj = args[1];
            if len(items10) == 0 {
                return item2;
            }
            c2 = _hq_lt(item2, items10[0]);
            if is_error(c2) {
                return c2;
            }
            if (c2 as PyBool).val {
                oldtop2: PyObj = items10[0];
                items10[0] = item2;
                r7 = _hqsift_up_max(items10, 0);
                if is_error(r7) {
                    return r7;
                }
                return oldtop2;
            }
            return item2;
        }
        if n == "nlargest" or n == "nsmallest" {
            # Documented semantics: sorted(iterable, key=key, reverse=... )[:n].
            if len(args) < 2 or len(args) > 3 {
                return py_error(
                    "TypeError", n + " expected 2 or 3 arguments, got " + str(len(args))
                );
            }
            if not isinstance(args[0], PyInt) {
                return py_error("TypeError", "an integer is required");
            }
            cnt = (args[0] as PyInt).val;
            sort_kwargs: dict[str, PyObj] = {};
            for kw in kwargs {
                sort_kwargs[kw] = kwargs[kw];
            }
            if len(args) == 3 and "key" not in sort_kwargs {
                sort_kwargs["key"] = args[2];
            }
            if n == "nlargest" {
                sort_kwargs["reverse"] = PyBool(t="bool", val=True);
            }
            ordered = builtin_sorted_min_max("sorted", [args[1]], sort_kwargs);
            if is_error(ordered) {
                return ordered;
            }
            all_items = (ordered as PyList).items;
            if cnt <= 0 {
                return PyList(t="list", items=[]);
            }
            if cnt >= len(all_items) {
                return ordered;
            }
            return PyList(t="list", items=all_items[:cnt]);
        }
        return py_error("AttributeError", "module 'heapq' has no attribute '" + n + "'");
    }
}

# PEP 750 t-string runtime surfaces (string.templatelib parity). Equality is
# identity (CPython defines neither __eq__ nor __hash__ overrides); iteration
# over a Template yields literal strings and interpolations interleaved.
obj PyTStrInterpolation(PyObj) {
    has value: PyObj,
        expression: str,
        conversion: PyObj,
        format_spec: PyObj;

    def tp_getattro(name: str) -> PyObj {
        if name == "value" {
            return self.value;
        }
        if name == "expression" {
            return PyStr(t="str", val=self.expression);
        }
        if name == "conversion" {
            return self.conversion;
        }
        if name == "format_spec" {
            return self.format_spec;
        }
        if name == "__class__" {
            # Type-identity surrogate: answers __name__ for introspection.
            return PyExceptionType(t="exception_type", name="Interpolation");
        }
        return py_error("AttributeError", name);
    }

    def tp_repr -> PyObj {
        return PyStr(
            t="str",
            val="Interpolation(" + str(py_repr(self.value)) + ", "
                + str(py_repr(PyStr(t="str", val=self.expression))) + ", "
                + str(py_repr(self.conversion)) + ", "
                + str(py_repr(self.format_spec)) + ")"
        );
    }
}

obj PyTStrTemplate(PyObj) {
    has strings: PyTuple,
        interpolations: PyTuple;

    def tp_getattro(name: str) -> PyObj {
        if name == "strings" {
            return self.strings as PyObj;
        }
        if name == "interpolations" {
            return self.interpolations as PyObj;
        }
        if name == "values" {
            vals: list[PyObj] = [];
            for part in (self.interpolations as PyTuple).items {
                vals.append((part as PyInterpolation).value);
            }
            return PyTuple(t="tuple", items=vals);
        }
        if name == "__class__" {
            return PyExceptionType(t="exception_type", name="Template");
        }
        return py_error("AttributeError", name);
    }

    def tp_iter -> PyObj {
        # Interleave literal strings with interpolations in source order.
        items: list[PyObj] = [];
        strs = (self.strings as PyTuple).items;
        parts = (self.interpolations as PyTuple).items;
        si = 0;
        pi = 0;
        while si < len(strs) or pi < len(parts) {
            if si < len(strs) {
                items.append(strs[si]);
                si = si + 1;
            }
            if pi < len(parts) {
                items.append(parts[pi]);
                pi = pi + 1;
            }
        }
        return PyIter(t="iter", items=items, index=0);
    }

    def tp_repr -> PyObj {
        return PyStr(
            t="str",
            val="Template(strings=" + str(py_repr(self.strings)) + ", interpolations="
                + str(py_repr(self.interpolations)) + ")"
        );
    }
}

# Factory indirection for the run_frame arms: direct obj construction inside
# the interpreter loop fails name resolution at runtime, so mint through
# module-level helpers instead.

def make_interpolation(value_i: PyObj, expr_s: str, conv: PyObj, fmt: PyObj) -> PyObj {
    return PyTStrInterpolation(
        t="interpolation",
        value=value_i,
        expression=expr_s,
        conversion=conv,
        format_spec=fmt
    ) as PyObj;
}

def make_template(strings_t: PyTuple, parts_t: PyTuple) -> PyObj {
    return PyTStrTemplate(
        t="template",
        strings=strings_t,
        interpolations=parts_t
    ) as PyObj;
}

def build_heapq_module -> PyObj {
    return PyModule(
        t="module",
        name="heapq",
        attrs={
            "heapify": PyHeapqFn(t="heapq_fn", name="heapify"),
            "heappush": PyHeapqFn(t="heapq_fn", name="heappush"),
            "heappop": PyHeapqFn(t="heapq_fn", name="heappop"),
            "heapreplace": PyHeapqFn(t="heapq_fn", name="heapreplace"),
            "heappushpop": PyHeapqFn(t="heapq_fn", name="heappushpop"),
            "heappush_max": PyHeapqFn(t="heapq_fn", name="heappush_max"),
            "heappop_max": PyHeapqFn(t="heapq_fn", name="heappop_max"),
            "heapify_max": PyHeapqFn(t="heapq_fn", name="heapify_max"),
            "heapreplace_max": PyHeapqFn(t="heapq_fn", name="heapreplace_max"),
            "heappushpop_max": PyHeapqFn(t="heapq_fn", name="heappushpop_max"),
            "nlargest": PyHeapqFn(t="heapq_fn", name="nlargest"),
            "nsmallest": PyHeapqFn(t="heapq_fn", name="nsmallest"),
        },
    );
}

def build_copy_module -> PyObj {
    return PyModule(
        t="module",
        name="copy",
        attrs={
            "copy": PyCopyFn(t="copy_fn", deep=False),
            "deepcopy": PyCopyFn(t="copy_fn", deep=True),

        },
    );
}

# gen.close(): throw GeneratorExit in. Swallowing it (StopIteration or letting
# GeneratorExit propagate) is a clean close; yielding again is a RuntimeError.
def gen_close(gen: PyGenerator) -> PyObj {
    if gen.finished or not gen.started {
        gen.finished = True;
        frame_clear(gen.frame);
        return py_none();
    }
    gen_exit = PyException(t="exception", type_name="GeneratorExit", message="");
    result = gen_throw(gen, gen_exit);
    gen.finished = True;
    frame_clear(gen.frame);
    if result.t == "genstop" {
        # The generator caught GeneratorExit and returned; close() surfaces that
        # return value (None if it just fell off the end). (CPython 3.13+.)
        return (result as PyGenStop).val;
    }
    if is_error(result) {
        if (result as PyError).exception.type_name == "GeneratorExit" {
            return py_none();
        }
        return result;
    }
    return py_error("RuntimeError", "generator ignored GeneratorExit");
}

# Drive one step of `await ag.__anext__()` / `await ag.asend(v)` (genobject.c
# async_gen_asend_send). The awaitable carries the resume value (None for
# __anext__, asend's operand otherwise); a yield unwraps to its payload,
# exhaustion becomes StopAsyncIteration, errors propagate.
def agen_asend_step(a: PyAsyncGenASend, sent: PyObj) -> PyObj {
    if a.started {
        return py_error("RuntimeError", "cannot reuse already awaited __anext__()/asend()");
    }
    a.started = True;
    gen = a.gen;
    if not gen.started and not gen.finished and a.value.t != "none" {
        return py_error(
            "TypeError", "can't send non-None value to a just-started async generator"
        );
    }
    result = gen_resume(gen, a.value);
    return agen_translate(result);
}

# Drive one step of `await ag.athrow(exc)` / `await ag.aclose()` (genobject.c
# async_gen_athrow_send). athrow: a caught exception followed by another yield
# surfaces that yield; a clean return raises StopAsyncIteration; throwing into
# an ALREADY-EXHAUSTED generator completes silently (CPython 3.14 quirk).
# aclose runs the GeneratorExit protocol and never raises on a clean exit.
def agen_athrow_step(a: PyAsyncGenAThrow, sent: PyObj) -> PyObj {
    if a.started {
        return py_error("RuntimeError", "cannot reuse already awaited aclose()/athrow()");
    }
    a.started = True;
    gen = a.gen;
    if a.aclose {
        if gen.finished or not gen.started {
            gen.finished = True;
            frame_clear(gen.frame);
            return PyGenStop(t="genstop", val=py_none());
        }
        gen_exit = PyException(t="exception", type_name="GeneratorExit", message="");
        result = gen_throw(gen, gen_exit);
        gen.finished = True;
        frame_clear(gen.frame);
        if is_error(result) {
            if ((result as PyError).exception).type_name == "GeneratorExit" {
                # GeneratorExit propagating out is a clean close.
                return PyGenStop(t="genstop", val=py_none());
            }
            return result;
        }
        if result.t == "async_wrapped" {
            return py_error("RuntimeError", "async generator ignored GeneratorExit");
        }
        # Caught GeneratorExit and returned: clean close, value dropped.
        return PyGenStop(t="genstop", val=py_none());
    }
    if gen.finished {
        # Nothing left to throw into; CPython drops the resume outcome.
        return PyGenStop(t="genstop", val=py_none());
    }
    result2 = gen_throw(gen, a.err);
    return agen_translate(result2);
}

# Shared translation of an async-generator resume outcome into the awaitable
# protocol. One drive IS one complete await: a yield finishes the asend/anext
# coroutine with the UNWRAPPED payload (PyGenStop makes the SEND loop treat it
# like a coroutine return), while normal exhaustion raises StopAsyncIteration.
def agen_translate(result: PyObj) -> PyObj {
    if is_error(result) {
        return result;
    }
    if result.t == "async_wrapped" {
        return PyGenStop(t="genstop", val=(result as PyAsyncGenWrappedValue).val);
    }
    return PyError(
        t="error",
        exception=PyException(t="exception", type_name="StopAsyncIteration", message=""),
    );
}

# Drive one step of a yield-from sub-iterator (SEND). Returns the yielded value,
# a PyGenStop(return value) on exhaustion, or a propagating error.
def send_into(receiver: PyObj, sent: PyObj) -> PyObj {
    # Async-generator awaitables (from __anext__/asend/athrow/aclose) drive
    # through their own step functions; the SEND loop awaits them like any
    # other awaitable.
    if receiver.t == "agen_asend" {
        return agen_asend_step(receiver as PyAsyncGenASend, sent);
    }
    if receiver.t == "agen_athrow" {
        return agen_athrow_step(receiver as PyAsyncGenAThrow, sent);
    }
    # A native coroutine drives through the identical suspend/resume machinery as
    # a generator -- `await` lowers to the same SEND loop `yield from` uses.
    if receiver.t == "generator" or receiver.t == "coroutine" {
        return gen_resume(receiver as PyGenerator, sent);
    }
    if receiver.t == "calliter" {
        # next(calliter) drives the callable-iterator; send() is not a
        # calliterobject method (CPython raises AttributeError).
        if sent.t != "none" {
            return py_error("AttributeError", "send");
        }
        return calliter_next(receiver as PyCallableIter);
    }
    if receiver.t == "seqiter" {
        # next(seqiter) drives the old-style sequence iterator; same no-send
        # rule as the callable-iterator.
        if sent.t != "none" {
            return py_error("AttributeError", "send");
        }
        return seqiter_next(receiver as PySeqIter);
    }
    if receiver.t == "rangeiter" {
        ri = receiver as PyRangeIter;
        if sent.t != "none" {
            return py_error("AttributeError", "send");
        }
        if ri.remaining > 0 {
            ritem = PyInt(t="int", val=ri.cur);
            ri.cur = ri.cur + ri.step;
            ri.remaining = ri.remaining - 1;
            return ritem;
        }
        return PyGenStop(t="genstop", val=py_none());
    }
    if receiver.t == "iter" {
        it = receiver as PyIter;
        if sent.t != "none" {
            return py_error("AttributeError", "send");
        }
        if it.index < len(it.items) {
            item = it.items[it.index];
            it.index = it.index + 1;
            return item;
        }
        return PyGenStop(t="genstop", val=py_none());
    }
    if receiver.t == "dictiter" {
        di = receiver as PyDictIter;
        if sent.t != "none" {
            return py_error("AttributeError", "send");
        }
        if di.dictiter_stale() {
            return dictiter_error();
        }
        if di.index < len(di.keys) {
            item = dictiter_yield(di);
            di.index = di.index + 1;
            return item;
        }
        return PyGenStop(t="genstop", val=py_none());
    }
    # Any other iterator: drive it through its own send/__next__ surface. An
    # object exposing send() -- notably a host coroutine/proxy driven after
    # GET_AWAITABLE resolved it directly -- MUST be resumed with send(None);
    # only bare iterators without send fall back to __next__.
    method_name = "send";
    if py_attr(receiver, "send").t == "error" {
        method_name = "__next__";
    }
    if is_error(py_attr(receiver, method_name)) {
        return py_error("TypeError", "object can't be sent");
    }
    driver = py_attr(receiver, method_name);
    if is_error(driver) {
        return driver;
    }
    call_args: list[PyObj] = [];
    if method_name == "send" {
        call_args.append(sent);
    }
    result = py_invoke(driver, call_args, {});
    if is_error(result) {
        exc = (result as PyError).exception;
        if exc_is_stopiter(exc) {
            payload = py_none();
            if exc.value is not None {
                payload = exc.value as PyObj;
            }
            return PyGenStop(t="genstop", val=payload);
        }
        return result;
    }
    return result;
}

# Drain a generator to exhaustion through the real suspend/resume machinery and
# return the yielded PyObjs as a list. Used at the host boundary (to_host) so
# list()/tuple()/sum()/... consume a native genexpr without an eager-eval shim.
def gen_drain(gen: PyGenerator) -> PyObj {
    items: list[PyObj] = [];
    while True {
        nxt = gen_resume(gen, py_none());
        if nxt.t == "genstop" {
            return PyList(t="list", items=items);
        }
        if is_error(nxt) {
            return nxt;
        }
        items.append(nxt);
    }
    return PyList(t="list", items=items);
}
# Sync a guest PyDict argument with the working map exec() ran against:
# every name the code bound (or rebound) lands in the caller's dict, and
# every name the code deleted is removed -- STORE_NAME must stay observable
# through the ORIGINAL object the caller passed.
def _sync_ns_back(d: PyDict, work: dict[str, PyObj]) -> PyObj {
    stale: list[PyObj] = [];
    for hk in d.items {
        key_obj = d.items[hk].key;
        if key_obj.t == "str" and not (expect_str(key_obj) in work) {
            stale.append(key_obj);
        }
    }
    for k in stale {
        del_err = d.mp_del_subscript(k);
        if is_error(del_err) {
            return del_err;
        }
    }
    for name in work {
        set_err = d.dict_set(PyStr(t="str", val=name), work[name]);
        if is_error(set_err) {
            return set_err;
        }
    }
    return py_none();
}

# Native builtin exec(source, globals=None, locals=None) -- port of
# bltinmodule.c builtin_exec_impl. The executed module-level MAKE_FUNCTION /
# STORE_NAME sequence binds top-level names through the frame's f_locals and
# f_globals, so those must be the caller's LIVE namespaces -- never copies on
# the host side of the bridge. Guest PyDict arguments run against an internal
# map seeded from the dict and synced back after the run (see _sync_ns_back);
# PyGlobalsProxy views (globals()) are live already. Known accepted delta:
# functions/classes defined by the exec'd code capture the working map as
# their __globals__, not the caller's dict object.
def builtin_exec(
    args: list[PyObj],
    kwargs: dict[str, PyObj],
    frame_globals: dict[str, PyObj],
    frame_locals: dict[str, PyObj]
) -> PyObj {
    if len(kwargs) > 0 {
        return py_error("TypeError", "exec() takes no keyword arguments");
    }
    if len(args) < 1 or len(args) > 3 {
        return py_error(
            "TypeError",
            "exec expected at least 1 argument, got " + str(len(args))
        );
    }
    # str/bytes source: compile through the same marshal transport the import
    # machinery uses (native statement-mode compile is Phase C) and normalize
    # to a PyCode before dispatch. A host SyntaxError surfaces as a catchable
    # guest exception, matching CPython's exec('for = 1') -> SyntaxError.
    if isinstance(args[0], PyStr) or isinstance(args[0], PyBytes) {
        src = "";
        if isinstance(args[0], PyStr) {
            src = (args[0] as PyStr).val;
        } else {
            src = bytes_to_str((args[0] as PyBytes).val);
        }
        packed_src = _jac_host_source_marshal(src);
        if not host_result_ok(packed_src) {
            return host_result_error(packed_src);
        }
        converted_src = unmarshal(packed_src[1] as list[int]);
        if is_error(converted_src) {
            # Surface load-time failures (e.g. opcode validation) verbatim.
            return converted_src;
        }
        if not isinstance(converted_src, PyCode) {
            return py_error("TypeError", "exec() argument 1 must be a code object");
        }
        args[0] = converted_src;
    }
    co: PyCode;
    match args[0] {
        case PyCode():
            co = args[0] as PyCode;
        case PyHostProxy():
            # compile()/types.CodeType built on the host arrive as proxies;
            # bring the code back through the marshal transport -- the same
            # route every oracle code object already travels.
            packed = _jac_host_code_marshal((args[0] as PyHostProxy).val);
            if not host_result_ok(packed) {
                return py_error("TypeError", "exec() argument 1 must be a code object");
            }
            converted = unmarshal(packed[1] as list[int]);
            if not isinstance(converted, PyCode) {
                return py_error("TypeError", "exec() argument 1 must be a code object");
            }
            co = converted as PyCode;
        case _:
            return py_error("TypeError", "exec() argument 1 must be a code object");
    }
    g_work: dict[str, PyObj] = frame_globals;
    g_copy = False;
    if len(args) >= 2 and not isinstance(args[1], PyNoneType) {
        if isinstance(args[1], PyDict) {
            g_work = (args[1] as PyDict).dict_str_map();
            g_copy = True;
        } elif isinstance(args[1], PyGlobalsProxy) {
            g_work = (args[1] as PyGlobalsProxy).ns;
        } else {
            return py_error(
                "TypeError",
                "exec() argument 2 must be a dict, not '"
                    + _compare_type_name(args[1]) + "'"
            );
        }
    }
    l_work: dict[str, PyObj] = g_work;
    l_copy = False;
    if len(args) == 3 and not isinstance(args[2], PyNoneType) {
        if isinstance(args[2], PyDict) {
            l_work = (args[2] as PyDict).dict_str_map();
            l_copy = True;
        } elif isinstance(args[2], PyGlobalsProxy) {
            l_work = (args[2] as PyGlobalsProxy).ns;
        } else {
            return py_error(
                "TypeError",
                "exec() argument 3 must be a dict, not '"
                    + _compare_type_name(args[2]) + "'"
            );
        }
    }
    outcome = exec_code_frame(co, [], {}, g_work, l_work, [], [], {});
    if is_error(outcome) {
        return outcome;
    }
    if g_copy {
        sync_g = _sync_ns_back(args[1] as PyDict, g_work);
        if is_error(sync_g) {
            return sync_g;
        }
    }
    if l_copy {
        sync_l = _sync_ns_back(args[2] as PyDict, l_work);
        if is_error(sync_l) {
            return sync_l;
        }
    }
    return py_none();
}

# Depth of exec_code invocations on the current host stack. Guest execution
# re-enters exec_code for synthesized operator/comprehension code objects
# (pyc_first), so the final-error traceback display must only fire at the
# OUTERMOST call -- where an error genuinely escapes the program -- never for
# inner errors a guest handler may still catch.
glob _tb_exec_depth: int = 0;

def exec_code(co: PyObj, args: list[PyObj], globals: dict[str, PyObj]) -> PyObj {
    match co {
        case PyCode():
            _tb_exec_depth += 1;
            try {
                outcome = exec_code_frame(co, args, {}, globals, globals, [], [], {});
            } finally {
                _tb_exec_depth -= 1;
            }
            if is_error(outcome) and _tb_exec_depth == 0 {
                # Final-error surfacing: render the guest traceback chain to
                # stderr shaped exactly like CPython's uncaught-exception path.
                tb_display_error(outcome, py_str);
            }
            return outcome;
    }
    return py_error("TypeError", "expected code object");
}

def exec_module(co: PyObj) -> dict[str, PyObj] {
    globals: dict[str, PyObj] = {"__name__": PyStr(t="str", val="__main__")};
    outcome = exec_code(co, [], globals);
    # CPython import semantics: an exception raised by a module body propagates
    # to the importer. Discarding it here silently handed callers partial
    # globals on any failure.
    if is_error(outcome) {
        _jac_reraise_pyerror(outcome as PyError);
    }
    return globals;
}
