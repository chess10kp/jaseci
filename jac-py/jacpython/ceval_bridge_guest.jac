# ceval bridge guest (jac-py/PLAN.md §4 module-boundary constraint).
# Jac-coupled host-bridge shims: live views, trampolines, reraise, standins,
# coroutine/async-generator host faces. Pure ::py:: helpers live in
# ceval_host_bridge.jac (acyclic leaf); ceval.jac re-exports via thin wrappers.

import ceval_host_bridge as _hb;

import from objects {
    PyException,
    PyError,
    PyStr,
    PyInt,
    PyExceptionType,
    is_error,
    py_none,
}
import from ceval_defs {
    PyHostProxy,
    PyClass,
    PyFunction,
    PyGenStop,
    PyAsyncGenWrappedValue,
    PyNativeBuiltin,
    PyUserObj,
}
import from exceptions_core {
    exc_name_matches,
    registered_exc_base,
}
import from ceval_api {
    to_host,
    from_host,
    host_exception,
    py_repr,
    py_str,
    py_iter,
    py_attr,
    bind_attribute,
    send_into,
    class_lookup_attr,
    class_has_abc_meta,
    class_mro,
    gen_throw,
    gen_send,
    gen_close,
}

::py::
def _jac_exc_chain_to_host(value):
    # __cause__/__context__ stored on a guest PyException arrive as PyException
    # value-structs; convert them to their host form before attaching to the
    # re-raised host exception. Non-exception values pass through unchanged.
    if isinstance(value, PyException):
        return host_exception(value)
    return value

def _jac_reraise_pyerror(err):
    # Surface a guest PyError to HOST control flow with maximal fidelity:
    # import-style callers of the VM must see module-body failures, never a
    # silently discarded error. The carried PyException already holds
    # everything CPython's import machinery would observe, so no synthesis:
    #   - a host-proxied exception instance keeps its ORIGINAL host object in
    #     `raw` -- raise it directly (identity/args/chaining/traceback intact);
    #   - anything else converts through host_exception, which preserves type
    #     name and the full args tuple (user Exception subclasses mint a cached
    #     same-name host subclass, the same degradation to_host uses).
    # Explicit (__cause__) and implicit (__context__) chains are re-attached so
    # `raise ... from ...` inside a module body survives the boundary.
    exc = err.exception
    raw = exc.raw
    if raw is not None and isinstance(raw, PyHostProxy):
        raise raw.val
    built = host_exception(exc)
    cause = _jac_exc_chain_to_host(exc.cause)
    if cause is not None:
        setattr(built, "__cause__", cause)
    context = _jac_exc_chain_to_host(exc.context)
    if context is not None:
        setattr(built, "__context__", context)
    raise built
def _jac_instantiate_registered_exception(qname, raw_args):
    # Checked resolution (no bare getattr): builtin first, then the module
    # registry's declared base. Instantiation never raises past this boundary.
    import builtins
    t = getattr(builtins, qname, None)
    if not (isinstance(t, type) and issubclass(t, BaseException)):
        t = _hb._jac_make_module_exc_type(qname, registered_exc_base(qname))
    try:
        if raw_args:
            return (True, t(*raw_args))
        return (True, t())
    except BaseException as exc:
        return _hb._jac_host_error(exc)
def _jac_host_exception_instance(raw):
  # True with (type_name, message, args) when raw is a raised host BaseException
  # instance. Args carries the FULL constructor tuple (BaseException.args) so a
  # host-proxied exception raised through the VM keeps its arguments -- a single
  # `message` string alone made repr(e.__cause__) lose args. getattr with a
  # default cannot raise on a BaseException, so no guard is needed.
    if isinstance(raw, BaseException):
        exc_args = [from_host(a) for a in getattr(raw, "args", ())]
        return (True, type(raw).__name__, str(raw), exc_args)
    return (False, "", "", [])
def _jac_make_live_ns_view(proxy):
    # Live host view over a guest namespace (PyGlobalsProxy crossing to
    # host-delegated code): CPython hands the LIVE module dict, so reads route
    # through mp_subscript (KeyError-faithful) and writes through
    # mp_ass_subscript -- host-side mutations land in the guest ns and guest
    # writes stay visible to the host. A Mapping (not a dict subclass)
    # because the storage is the Jac name->PyObj table, not a host dict;
    # documented deltas: no del support (the proxy has no delete protocol)
    # and isinstance(x, dict) is False.
    import collections.abc
    class _LiveNsView(collections.abc.Mapping):
        def __getitem__(self, k):
            r = proxy.mp_subscript(PyStr(t="str", val=k))
            if isinstance(r, PyError):
                raise KeyError(k)
            return to_host(r)
        def __setitem__(self, k, v):
            proxy.mp_ass_subscript(PyStr(t="str", val=k), from_host(v))
        def __contains__(self, k):
            return isinstance(k, str) and k in proxy.ns
        def __iter__(self):
            return iter(list(proxy.ns.keys()))
        def __len__(self):
            return len(proxy.ns)
        def __repr__(self):
            return repr(dict(self))
        get = collections.abc.Mapping.get
    return _LiveNsView()

def _jac_make_live_list(pylist):
    # Live host view over a guest PyList crossing to host code (fp-e87c live-
    # view cluster): reads route through mp_subscript, writes through
    # mp_ass_subscript / the raw items table -- host mutations land in the
    # guest list and guest appends stay visible to the host. A MutableSequence
    # (not a list subclass) because the storage is the Jac PyObj items table,
    # not a host list; documented deltas: isinstance(x, list) is False, ==
    # against a real list falls back to identity (Sequence defines no __eq__),
    # and __iter__ walks by index through mp_subscript so it reflects appends
    # made during iteration instead of snapshotting.
    import collections.abc
    class _LiveListView(collections.abc.MutableSequence):
        def __getitem__(self, i):
            r = pylist.mp_subscript(from_host(i))
            if isinstance(r, PyError):
                _jac_reraise_pyerror(r)
            return to_host(r)
        def __setitem__(self, i, v):
            r = pylist.mp_ass_subscript(from_host(i), from_host(v))
            if isinstance(r, PyError):
                _jac_reraise_pyerror(r)
        def __delitem__(self, i):
            # PyList carries mp_del_subscript, so del works here (unlike the ns
            # view, whose proxy has no delete protocol).
            r = pylist.mp_del_subscript(from_host(i))
            if isinstance(r, PyError):
                _jac_reraise_pyerror(r)
        def __len__(self):
            return len(pylist.items)
        def __iter__(self):
            i = 0
            while True:
                r = pylist.mp_subscript(PyInt(t="int", val=i))
                if isinstance(r, PyError):
                    return
                yield to_host(r)
                i = i + 1
        def insert(self, i, v):
            # CPython list.insert clamps out-of-range positions; do the same on
            # the backing table (MutableSequence.append routes through here).
            n = len(pylist.items)
            if i < 0:
                i = max(0, n + i)
            else:
                i = min(i, n)
            pylist.items.insert(i, from_host(v))
        def __repr__(self):
            return repr([x for x in self])
    return _LiveListView()

def _jac_make_live_dict(pydict):
    # Live host view over a guest PyDict: same contract as _jac_make_live_list.
    # Errors re-raise through _jac_reraise_pyerror so KeyError/IndexError carry
    # the exact guest type+args (KeyError('k'), "unhashable type") instead of a
    # resynthesized message. __contains__/get inherit from MutableMapping, whose
    # try-getitem shape propagates TypeError for unhashable keys like CPython.
    import collections.abc
    class _LiveDictView(collections.abc.MutableMapping):
        def __getitem__(self, k):
            r = pydict.mp_subscript(from_host(k))
            if isinstance(r, PyError):
                _jac_reraise_pyerror(r)
            return to_host(r)
        def __setitem__(self, k, v):
            r = pydict.mp_ass_subscript(from_host(k), from_host(v))
            if isinstance(r, PyError):
                _jac_reraise_pyerror(r)
        def __delitem__(self, k):
            r = pydict.mp_del_subscript(from_host(k))
            if isinstance(r, PyError):
                _jac_reraise_pyerror(r)
        def __iter__(self):
            return iter([to_host(k) for k in pydict.dict_keys()])
        def __len__(self):
            return len(pydict.items)
        def __repr__(self):
            return repr(dict(self))
    return _LiveDictView()

def _jac_make_live_set(pyset):
    # Live host view over a guest MUTABLE PySet (frozensets never cross here --
    # the dispatcher refuses them): MutableSet's add/discard/contains surface.
    import collections.abc
    class _LiveSetView(collections.abc.MutableSet):
        def __contains__(self, v):
            return pyset.set_contains(from_host(v))
        def __iter__(self):
            return iter([to_host(m) for m in pyset.set_members()])
        def __len__(self):
            return len(pyset.items)
        def add(self, v):
            r = pyset.set_add(from_host(v))
            if isinstance(r, PyError):
                _jac_reraise_pyerror(r)
        def discard(self, v):
            r = pyset.set_discard(from_host(v))
            if isinstance(r, PyError):
                _jac_reraise_pyerror(r)
        def __repr__(self):
            return repr(set(self))
    return _LiveSetView()

def _jac_make_host_trampoline(native_fn):
    # Native-callable -> host round-trip. When a native PyFunction crosses the
    # host boundary (to_host), it can't become None -- host machinery that wraps
    # or invokes it (type(name, bases, ns) installing a native __repr__, a
    # classmethod/property over a native function, functools.partial, a callback
    # handed to a proxied C module) needs a REAL callable. Return a host closure
    # that marshals host args back into PyObjs, runs the function in jacpython's
    # own ceval via tp_call, and marshals the result back out. A raised PyError
    # is re-raised with its original object/args/chaining intact so host
    # control flow sees it.
    def _trampoline(*args, **kwargs):
        pyargs = [from_host(a) for a in args]
        pykwargs = {}
        for k in kwargs:
            pykwargs[k] = from_host(kwargs[k])
        result = native_fn.tp_call(pyargs, pykwargs)
        if isinstance(result, PyError):
            _jac_reraise_pyerror(result)
        return to_host(result)
    # Present as the wrapped function so introspection (functools.wraps,
    # type()'s method registration, repr) sees the right identity. Keep a
    # back-pointer so a round-trip (from_host of this trampoline) recovers the
    # native function instead of re-wrapping it as an opaque proxy.
    try:
        _trampoline.__name__ = native_fn.name
        # PyFunction carries code/_func_doc; other callables (PyNativeBuiltin,
        # bound/method wrappers) only carry .name.
        if hasattr(native_fn, "code"):
            _trampoline.__qualname__ = native_fn.code.qualname
            doc = native_fn._func_doc()
            _trampoline.__doc__ = doc.val if isinstance(doc, PyStr) else None
        else:
            _trampoline.__qualname__ = native_fn.name
        _trampoline.__jac_native__ = native_fn
    except BaseException:
        pass
    return _trampoline
# ---- typed-boundary stand-ins and lazy iterators ---------------------------
# Bridge-table support (see to_host_policy in this file):
#
# STANDIN: a guest PyClass or plain PyUserObj crossing to the host gets a
# NAME-FAITHFUL cached host stand-in -- never None. The minted host class
# carries the guest class's name and bases; instances keep a back-reference so
# from_host recovers the ORIGINAL guest object (identity round-trip) and so
# guest-defined __str__/__repr__ run through the VM.
#
# LAZY_ITER: a native iterator/generator crossing to the host becomes a lazy
# host iterator that pulls ONE step per __next__ through the same tp_iternext
# helpers FOR_ITER uses. Position stays SHARED with the guest object, so host
# consumption no longer drains/consumes the underlying iterator silently.

_JAC_CLASS_STANDINS = {}   # id(guest_cls) -> [weakref.ref(cls), host_class]
_JAC_USER_STANDINS = {}    # id(user_obj) -> [weakref.ref(obj), standin_instance]

_JAC_ITER_DONE = object()  # sentinel for iter(callable, sentinel)


def _jac_notimpl_value():
    # VALUE_COPY for the native richcompare-deferral sentinel: the host sees the
    # real NotImplemented singleton (previously a silent None fallthrough).
    return NotImplemented


def _jac_standin_bases(cls):
    # Resolve guest base declarations to host classes for type() minting.
    # Unresolvable bases are skipped; if nothing resolves, `object` is used.
    import builtins
    bases = []
    for b in cls.bases:
        hb = None
        if isinstance(b, PyClass):
            hb = _jac_standin_class(b)
        elif isinstance(b, PyExceptionType):
            t = getattr(builtins, b.name, None)
            if isinstance(t, type) and issubclass(t, BaseException):
                hb = t
        elif isinstance(b, PyHostProxy) and isinstance(b.val, type):
            hb = b.val
        if hb is not None and hb not in bases and hb is not object:
            bases.append(hb)
    if not bases:
        return (object,)
    try:
        probe = type("_probe", tuple(bases), {})
    except TypeError:
        return (bases[0],)
    return tuple(bases)


def _jac_standin_dunder(dunder_name, vm_fn):
    # Host method that replays a guest dunder through the VM on the ORIGINAL
    # user object recovered from the stand-in's back-reference.
    def _meth(self, *args):
        u = getattr(self, "_jac_guest_", None)
        if u is None:
            raise RuntimeError(
                "bridge-table: stand-in lost its guest back-reference"
            )
        res = vm_fn(u)
        if isinstance(res, PyError):
            _jac_reraise_pyerror(res)
        return to_host(res)
    _meth.__name__ = dunder_name
    return _meth


def _jac_standin_iter_method():
    # Host __iter__ that recovers the guest object and serves iteration through
    # py_iter -- the exact CPython tp_iter surface (__iter__, boxed bases,
    # then the old-style __getitem__ sequence protocol) -- drained LAZILY via
    # the shared _jac_make_host_iterator so guest and host observe the SAME
    # consumption position. This is what lets host-routed consumers
    # (tuple()/sum()/any()/all()/enumerate()/zip()/dict.fromkeys()/...) see a
    # user object as iterable instead of a non-iterable repr/str-only standin.
    def _meth(self):
        u = getattr(self, "_jac_guest_", None)
        if u is None:
            raise RuntimeError(
                "bridge-table: stand-in lost its guest back-reference"
            )
        it = py_iter(u)
        if isinstance(it, PyError):
            _jac_reraise_pyerror(it)
        return _jac_make_host_iterator(it)
    _meth.__name__ = "__iter__"
    return _meth



def _jac_standin_next_method():
    # Host __next__ for standins of guest classes that ARE iterators: drives
    # the recovered guest object through the shared tp_iternext helper and
    # maps normal completion back to host StopIteration.
    def _meth(self):
        u = getattr(self, "_jac_guest_", None)
        if u is None:
            raise RuntimeError(
                "bridge-table: stand-in lost its guest back-reference"
            )
        step = send_into(u, py_none())
        if isinstance(step, PyGenStop):
            raise StopIteration
        if isinstance(step, PyError):
            exc = step.exception
            if exc_name_matches(exc.type_name, "StopIteration"):
                raise StopIteration
            _jac_reraise_pyerror(step)
        return to_host(step)
    _meth.__name__ = "__next__"
    return _meth

def _jac_standin_method(name):
    # Host method that replays a guest-defined method through the VM on the
    # recovered original object. Host callers (C reader loops, callbacks) then
    # see guest OVERRIDES, not just inherited base behavior.
    def _meth(self, *args, **kwargs):
        u = getattr(self, "_jac_guest_", None)
        if u is None:
            raise RuntimeError(
                "bridge-table: stand-in lost its guest back-reference"
            )
        m = py_attr(u, name)
        if isinstance(m, PyError):
            _jac_reraise_pyerror(m)
        b = bind_attribute(m, u)
        if isinstance(b, PyError):
            _jac_reraise_pyerror(b)
        h_args = [from_host(a) for a in args]
        h_kwargs = {}
        for k in kwargs:
            h_kwargs[k] = from_host(kwargs[k])
        res = b.tp_call(h_args, h_kwargs)
        if isinstance(res, PyError):
            _jac_reraise_pyerror(res)
        return to_host(res)
    _meth.__name__ = name
    return _meth




def _jac_standin_install_methods(ns, cls):
    # Install trampolines for every guest-DEFINED plain method (own attrs;
    # only PyFunction values install so data is never shadowed). Inherited
    # behavior answers through the real host base; identity dunders keep host
    # semantics.
    try:
        items = list(cls.attrs.items())
    except BaseException:
        return
    for name, val in items:
        if name in ns or not isinstance(val, PyFunction):
            continue
        if name.startswith("__"):
            continue
        ns[name] = _jac_standin_method(name)


def _jac_standin_class(cls):
    # The cached name-faithful host class for a guest PyClass.
    key = id(cls)
    ent = _JAC_CLASS_STANDINS.get(key)
    if ent is not None and ent[0]() is cls:
        return ent[1]
    ns = {}
    _jac_standin_install_methods(ns, cls)
    r = class_lookup_attr(cls, "__repr__")
    if not is_error(r):
        ns["__repr__"] = _jac_standin_dunder("__repr__", py_repr)
    s = class_lookup_attr(cls, "__str__")
    if not is_error(s):
        ns["__str__"] = _jac_standin_dunder("__str__", py_str)
    # Iteration protocol: install only what the guest MRO actually defines
    # (class-level lookup -- never the instance dict, so __getattr__ tails are
    # not swallowed into spurious protocol presence). Like CPython's
    # type_ready_set_slots, an __getitem__-without-__iter__ class still gets a
    # working tp_iter equivalent; py_iter synthesizes the sequence iterator.
    if (
        not is_error(class_lookup_attr(cls, "__iter__"))
        or not is_error(class_lookup_attr(cls, "__getitem__"))
    ):
        ns["__iter__"] = _jac_standin_iter_method()
    if not is_error(class_lookup_attr(cls, "__next__")):
        ns["__next__"] = _jac_standin_next_method()
    # Module-faithful: a host type() inherits __module__ from the CALLING module
    # (always 'ceval' here). Copy the guest class's real __module__ so reprs and
    # identity checks crossing back read the defining module, not the bridge.
    mod = class_lookup_attr(cls, "__module__")
    if not is_error(mod):
        hm = to_host(mod)
        if isinstance(hm, str):
            ns["__module__"] = hm
    if class_has_abc_meta(cls):
        _jac_install_abc_trampolines()
        host_cls = _JacABCMeta(cls.name, _jac_standin_bases(cls), ns)
    else:
        host_cls = type(cls.name, _jac_standin_bases(cls), ns)
    host_cls._jac_guest_cls_ = cls
    _JAC_CLASS_STANDINS[key] = [_hb._jac_host_weakref().ref(cls), host_cls]
    return host_cls


def _jac_user_standin(u):
    # The cached name-faithful host instance for a plain guest PyUserObj.
    key = id(u)
    ent = _JAC_USER_STANDINS.get(key)
    if ent is not None and ent[0]() is u:
        return ent[1]
    host_cls = _jac_standin_class(u.cls)
    inst = host_cls.__new__(host_cls)
    # Strong back-reference: while the host holds the stand-in, the guest
    # object stays alive and recoverable (identity round-trip).
    inst._jac_guest_ = u
    _JAC_USER_STANDINS[key] = [_hb._jac_host_weakref().ref(u), inst]
    return inst


def _jac_standin_adopt(base_obj, host_cls, guest_u):
    # Re-class the boxed host-C-type base AS the guest class's stand-in: one
    # object then carries BOTH the live C state (buffer, position, ...) and
    # the guest method trampolines. False on layout mismatch -- callers
    # degrade to presenting the bare base.
    try:
        base_obj.__class__ = host_cls
    except BaseException:
        return False
    try:
        base_obj._jac_guest_ = guest_u
    except BaseException:
        pass
    return True


def _jac_user_standin_typed(u):
    # Stand-in for an instance of a guest class whose ancestor is a proxied
    # host C TYPE outside the builtin list (io.BytesIO, ...). The boxed base
    # instance is ADOPTED as the stand-in class instead of a fresh __new__
    # shell: C state constructed in-VM survives the crossing AND guest
    # overrides stay visible to host callbacks (marshal-style readers).
    key = id(u)
    ent = _JAC_USER_STANDINS.get(key)
    if ent is not None and ent[0]() is u:
        return ent[1]
    base_r = to_host(u._base_obj())
    host_cls = _jac_standin_class(u.cls)
    if not _jac_standin_adopt(base_r, host_cls, u):
        return base_r
    _JAC_USER_STANDINS[key] = [_hb._jac_host_weakref().ref(u), base_r]
    return base_r


class _JacABCMeta(type):
    # Metaclass for standins of guest classes whose metaclass chain derives
    # from in-VM ABCMeta. Host C ABCMeta.__subclasscheck__ cannot traverse a
    # guest PyClass MRO (returns False even for direct ancestry), which killed
    # typing._ProtocolMeta.__new__ (issubclass(base, Generic) gate). These
    # overrides recover the guest objects and run the test in ceval; when
    # either side is not recoverable (pure host type like int) they fall back
    # to plain type semantics.
    def __subclasscheck__(cls, other):
        g = cls.__dict__.get("_jac_guest_cls_")
        gother = _jac_recover_guest(other)
        if g is None or gother is None:
            return super().__subclasscheck__(other)
        fn = _JAC_ABC_TRAMPOLINES[0]
        return bool(fn(g, gother))

    def __instancecheck__(cls, instance):
        g = cls.__dict__.get("_jac_guest_cls_")
        ginst = _jac_recover_guest(instance)
        if g is None or ginst is None:
            return super().__instancecheck__(instance)
        fn = _JAC_ABC_TRAMPOLINES[1]
        return bool(fn(ginst, g))


# [guest-issubclass trampoline, guest-isinstance trampoline] -- filled lazily
# by _jac_install_abc_trampolines on first ABC standin mint.
_JAC_ABC_TRAMPOLINES = [None, None]


def _jac_install_abc_trampolines():
    if _JAC_ABC_TRAMPOLINES[0] is None:
        _JAC_ABC_TRAMPOLINES[0] = _jac_make_host_trampoline(
            PyNativeBuiltin(t="native_builtin", name="issubclass")
        )
        _JAC_ABC_TRAMPOLINES[1] = _jac_make_host_trampoline(
            PyNativeBuiltin(t="native_builtin", name="isinstance")
        )


def _jac_standin_mro_covers(guest_cls, host_typ):
    # True iff any node of the guest class's MRO, once minted as a host
    # standin, is host_typ or subclasses it. Lets issubclass(instance-of-guest,
    # HOST-PROXIED type) answer through real host semantics instead of the
    # builtin-name fallback (which only knows int/str/list/...).
    try:
        mro = class_mro(guest_cls)
    except BaseException:
        return False
    for k in mro:
        try:
            hk = _jac_standin_class(k)
            if hk is host_typ or issubclass(hk, host_typ):
                return True
        except BaseException:
            continue
    return False


def _jac_hostproxy_val_is_type(val):
    # Returns the raw value if it is a host type, else "" (sentinel usable
    # from native callers without optional returns).
    import types as _types
    if isinstance(val, type):
        return val
    return ""


def _jac_recover_guest(raw):
    # from_host hook: a stand-in crossing BACK yields the original guest object
    # (class or instance). Cheaply gated on the marker living in __dict__/type.
    if isinstance(raw, type):
        g = raw.__dict__.get("_jac_guest_cls_")
        if g is not None:
            return g
        return None
    d = getattr(raw, "__dict__", None)
    if d is not None:
        return d.get("_jac_guest_")
    return None


def _jac_make_host_iterator(value):
    # LAZY_ITER policy: one host iterator pulling single steps out of the
    # native iterator/generator via the shared tp_iternext helpers, so guest
    # and host observe the SAME position and neither side silently drains it.
    def _next():
        step = send_into(value, py_none())
        if isinstance(step, PyGenStop):
            raise StopIteration
        if isinstance(step, PyError):
            exc = step.exception
            if exc_name_matches(exc.type_name, "StopIteration"):
                raise StopIteration
            _jac_reraise_pyerror(step)
        return to_host(step)
    return iter(_next, _JAC_ITER_DONE)

_JAC_EXACT_BUILTINS = (
    int, float, str, bytes, tuple, list, dict, set, frozenset, bool,
)

def _jac_is_builtin_subclass_instance(raw):
    # True iff raw is an instance of a container/scalar builtin whose type is a
    # PROPER SUBCLASS (namedtuple, IntEnum, a user `class X(list)` built on the
    # host, ...). Such an instance must stay a PyHostProxy: converting it to a
    # native PyTuple/PyList/PyInt would discard its real type and its own
    # attributes/descriptors (namedtuple field access, enum .name/.value).
    t = type(raw)
    if t in _JAC_EXACT_BUILTINS:
        return False
    return isinstance(raw, _JAC_EXACT_BUILTINS)

def _jac_host_val_is_type(val):
    return isinstance(val, type)


def _jac_host_type_mro(val):
    return type(val).mro(val)[:-1]


def _jac_host_val_is_object_type(val):
    return val is object


def _jac_host_val_same(a, b):
    return a is b


def _jac_drive_native(gen_obj, method_name, args):
    # Call a PyGenMethod driver (send/throw/close/...) on the native PyGenerator
    # and translate the outcome to HOST control flow: a yielded value converts
    # through to_host; normal completion (PyGenStop, e.g. a throw the guest
    # caught and returned from) re-raises StopIteration with the return value;
    # an explicit StopIteration error carries the coroutine's result payload;
    # any other guest error re-raises with its original object/args/chaining.
    m = gen_obj.tp_getattro(method_name)
    result = m.tp_call(args, {})
    if isinstance(result, PyError):
        exc = result.exception
        if exc.type_name == "StopIteration":
            raise StopIteration(to_host(exc.value))
        _jac_reraise_pyerror(result)
    if hasattr(result, "t") and result.t == "genstop":
        raise StopIteration(to_host(result.val))
    return to_host(result)


def _jac_host_exc_instance(exc):
    # Normalize throw() input to an exception INSTANCE, CPython-style: an
    # exception class is instantiated with no args; (exc, value) legacy forms
    # collapse to their first member.
    if isinstance(exc, BaseException):
        return exc
    if isinstance(exc, type) and issubclass(exc, BaseException):
        return exc()
    if isinstance(exc, tuple) and len(exc) > 0:
        return _jac_host_exc_instance(exc[0])
    raise TypeError("exceptions must derive from BaseException")


class coroutine:
    # Host face of a jacpython-native coroutine. Presents the real CPython
    # coroutine surface -- send/throw/close/__await__, type name `coroutine` --
    # so host asyncio (Task, Runner.run, ensure_future all gate on
    # asyncio.iscoroutine) drives it natively. Every drive marshals into frame
    # resumption on the guest side (gen_send/gen_throw/gen_close); nothing is
    # drained or copied.
    def __init__(self, gen_obj):
        self.__jac_native_coroutine__ = gen_obj

    def __repr__(self):
        native = self.__jac_native_coroutine__
        qual = ""
        try:
            qual = str(native.frame.co.qualname)
        except BaseException:
            pass
        return f"<coroutine object {qual}>"

    def send(self, value=None):
        try:
            started = bool(self.__jac_native_coroutine__.started)
        except BaseException:
            started = True
        if not started and value is not None:
            raise TypeError(
                "can't send non-None value to a just-started coroutine"
            )
        return _jac_drive_native(
            self.__jac_native_coroutine__, "send", [from_host(value)]
        )

    def throw(self, exc, value=None, tb=None):
        return _jac_drive_native(
            self.__jac_native_coroutine__,
            "throw",
            [from_host(_jac_host_exc_instance(exc))],
        )

    def close(self):
        try:
            return _jac_drive_native(
                self.__jac_native_coroutine__, "close", []
            )
        except StopIteration:
            return None

    def __await__(self):
        # Coroutine-protocol iterator: yield each suspended value up to the
        # driver, resume with what comes back, return StopIteration.value.
        sent = None
        while True:
            try:
                yielded = self.send(sent)
            except StopIteration as e:
                return e.value
            sent = yield yielded


try:
    import collections.abc as _cabc

    _cabc.Coroutine.register(coroutine)
except BaseException:
    pass


def _jac_make_guest_coroutine(gen_obj):
    return coroutine(gen_obj)


def _jac_host_resolve_awaitable(raw):
    # GET_AWAITABLE's host half (CPython semantics): an object with a native
    # coroutine/generator send/throw surface is driven directly; anything else
    # must expose __await__(), which is CALLED and must return an iterator.
    # Returns (ok, drivable, msg): ok=1 -> drive `drivable`; ok=0 -> raise
    # TypeError(msg), already composed byte-exact.
    import types as _types
    bad = f"object {type(raw).__name__} can't be used in 'await' expression"
    if isinstance(raw, (_types.CoroutineType, _types.GeneratorType)):
        return (1, raw, "")
    aw = getattr(type(raw), "__await__", None)
    if aw is None:
        return (0, None, bad)
    try:
        it = raw.__await__()
    except BaseException as exc:
        return (0, None, str(exc))
    try:
        iter(it)
    except BaseException:
        return (0, None,
            f"__await__() returned non-iterator of type '{type(it).__name__}'")
    return (1, it, "")


def _jac_make_guest_async_generator(agen_obj):
    # Host face of a native async generator: __aiter__/__anext__/aclose with
    # real awaitables, so host `async for` and contextlib.aclosing drive it.
    agen = agen_obj

    class _JacGuestANext:
        def __init__(self, step_fn):
            self._step = step_fn

        def __await__(self):
            # Drive one guest step at a time; suspend on guest yields so host
            # awaits inside the generator body propagate to the driver, and
            # forward throws raised by the driver into the guest frame.
            sent = None
            pending_throw = None
            while True:
                if pending_throw is not None:
                    thrown, pending_throw = pending_throw, None
                    outcome = self._step("throw", thrown)
                else:
                    outcome = self._step("send", sent)
                kind = outcome[0]
                if kind == "item":
                    return outcome[1]
                if kind == "done":
                    raise StopAsyncIteration(outcome[1])
                try:
                    sent = yield outcome[1]
                except BaseException as exc:
                    pending_throw = exc

    class _JacGuestAsyncGenerator:
        def __init__(self, gen_obj):
            self.__jac_native_coroutine__ = gen_obj

        def __repr__(self):
            return "<async_generator object>"

        def __aiter__(self):
            return self

        def __anext__(self):
            return _JacGuestANext(self._drive_anext)

        def aclose(self):
            return _JacGuestANext(self._drive_aclose)

        def _drive_anext(self, mode, payload):
            if mode == "throw":
                err = gen_throw(agen, from_host(payload))
            else:
                err = gen_send(agen, from_host(payload))
            if isinstance(err, PyError):
                exc = err.exception
                if exc.type_name == "StopIteration":
                    return ("done", to_host(exc.value))
                _jac_reraise_pyerror(err)
            if hasattr(err, "t") and err.t == "genstop":
                return ("done", None)
            if isinstance(err, PyAsyncGenWrappedValue):
                # A wrapped yield is the async-gen ITEM: this anext awaitable
                # completes with it (CPython async_generator_asend semantics).
                return ("item", to_host(err.val))
            return ("yield", to_host(err))

        def _drive_aclose(self, mode, payload):
            result = gen_close(agen)
            if isinstance(result, PyError):
                _jac_reraise_pyerror(result)
            return ("done", None)

    return _JacGuestAsyncGenerator(agen)
::py::
