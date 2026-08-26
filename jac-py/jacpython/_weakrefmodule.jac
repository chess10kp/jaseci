# Native weakref facade -- lift of reference/cpython/Modules/_weakref.c.
#
# _weakref.c is thin: four module functions over the per-object weakref list
# that object allocation maintains (GET_WEAKREFS_LISTPTR), plus the three
# proxy/ref types added to the module dict at multi-phase exec. This facade
# mirrors that surface against jacpython's lifetime oracle -- HOST weakrefs
# taken over the RAW PyObj. PyUserObj/PyClass/native wrappers are ordinary
# CPython objects, so a host weakref tracks their exact refcount lifetime:
# deref hands back the identical object (`r() is o`) and death follows
# refcounting with no extra bookkeeping.
#
# Surface (each piece traced to its C origin):
# - ref / ReferenceType  -> _PyWeakref_RefType (one shared callable; the two
#   names are the SAME module attr, so `weakref.ref is weakref.ReferenceType`
#   holds like CPython).
# - ProxyType / CallableProxyType / proxy -> _PyWeakref_{,Callable}ProxyType
#   plus the clinic `proxy` function; CPython's `proxy` IS ProxyType.
# - getweakrefcount(object) -> len of the live weakref list (0 for objects
#   whose type does not support weakrefs, like CPython's listptr probe).
# - getweakrefs(object) -> live refs only, exactly as the C walk appends only
#   entries it can incref under the lock.
# - _remove_dead_weakref(dct, key) -> the Weak*Dictionary cleanup primitive:
#   delete key iff its value is a dead weakref ("not a weakref" TypeError on
#   foreign values, KeyError on missing keys, mirroring is_dead_weakref +
#   _PyDict_DelItemIf).
#
# Registry: CPython threads weakrefs onto the REFERENT; jacpython keeps an
# id(target) -> [wrappers] table (_registry) pruned by host death callbacks,
# which is also what fires guest callbacks eagerly at referent death the way
# CPython's handle_weakrefs does.
#
# Divergences from CPython (v1, all documented at the touching code):
# - callback exceptions are swallowed instead of unraisable-printed to stderr;
#   GC re-entrancy makes the stderr path unsafe here.
# - weakref objects expose no __callback__/__referent__ attrs yet.
# - proxies delegate getattr/setattr/call/==/!= to the live referent but keep
#   the default identity-free richcompare for orderings and base tp_bool;
#   CPython delegates a wider special-method surface.
#
# Wiring: ceval.jac registers build_weakref_module_attrs() as the lazy shim in
# both import_native and host_import, replacing the previous one-function shim
# (build_weakref_module) that leaked every other name to AttributeError.
#
# NAMING: this file is deliberately NOT `jac-py/jacpython/weakref.jac`. The
# Jac module resolver (compiler/driver/modresolver.jac) prefers a .jac file in
# the importing module's directory over stdlib .py, so a project-level
# weakref.jac would capture ceval.jac's five host-side `import weakref` sites
# (_jac_make_weakref callers / class standins) and silently rebind them to
# this facade -- which cannot itself provide the host weakref module without
# a self-import cycle. The _<module>module.jac spelling follows the sibling
# convention (_bisectmodule.jac, _collectionsmodule.jac) and matches the
# suite-routing mapping weakref -> _weakref.

import from objects {
    PyObj,
    PyStr,
    PyInt,
    PyBool,
    PyList,
    PyTuple,
    PyDict,
    PySet,
    PyFloat,
    PyBytes,
    PyNoneType,
    DictEntry,
    ShimTypeMarker,
    py_none,
    py_error,
    hashkey_str,
    is_error,
    dict_key_repr,
    PY_NOT_IMPLEMENTED,
}

# id(target) -> live wrapper PyObjs handed to guest code. Entries remove
# themselves through the host death callback; liveness is additionally
# re-checked (and dead entries pruned) on every registry query, so a missed
# callback can never surface as a stale count -- only as deferred cleanup.
glob _registry: dict[int, list[PyObj]] = {};

# Shared ctor instances: ref/ReferenceType must be ONE object and
# proxy/ProxyType must be ONE object for `is` identity like CPython.
glob _reference_ctor: PyWeakRefFn = PyWeakRefFn(t="weakref_fn");
glob _proxy_ctor: PyWeakProxyCtor = PyWeakProxyCtor(t="weak_proxy_ctor", call=False);
glob _callable_proxy_ctor: PyWeakProxyCtor = PyWeakProxyCtor(
    t="weak_proxy_ctor", call=True
);

# CPython _PyType_SUPPORTS_WEAKREFS over the native split: boxed scalars,
# their immutable containers and host proxies are un-weakreferenceable (host
# proxies because deref would mint a fresh stand-in and break `r() is o`;
# PyHostProxy lives in ceval.jac, hence the tag compare), everything else
# takes a real host weakref.
def _supports_weakrefs(target: PyObj) -> bool {
    if target.t == "host" {
        return False;
    }
    return not isinstance(
        target,
        (
            PyInt, PyFloat, PyBool, PyStr, PyBytes,
            PyTuple, PyList, PyDict, PySet, PyNoneType,
        ),
    );
}

# Live wrappers registered for a referent id, pruning dead entries while
# walking -- the registry analogue of CPython clearing wr_list on dealloc.
def _live_wrappers_for(key: int) -> list[PyObj] {
    entries = _registry.get(key);
    if entries is None {
        return [];
    }
    alive: list[PyObj] = [e for e in entries if (e as PyWeakRef).wr() is not None];
    if len(alive) == 0 {
        del _registry[key];
    } else {
        _registry[key] = alive;
    }
    return alive;
}

# Create a host weakref over the raw target, register its wrapper and arm the
# eager death path: the host callback drops the entry from the registry and
# invokes the guest callback with the wrapper, exactly like CPython calling
# the callback with the dying weakref. Returns None when the target cannot be
# weakreferenced at the host layer either.
def _register_weakref(target: PyObj, cb: PyObj, tag: str, call: bool) -> PyWeakRef | None {
    import weakref;
    key = id(target);
    box: list[PyObj] = [];

    def _on_death(_host_wr: any) {
        # Runs inside host GC: never let anything escape into the VM.
        try {
            w = box[0];
            entries = _registry.get(key);
            if entries is not None {
                kept: list[PyObj] = [e for e in entries if e is not w];
                if len(kept) == 0 {
                    del _registry[key];
                } else {
                    _registry[key] = kept;
                }
            }
            if cb is not None and not isinstance(cb, PyNoneType) {
                (cb as PyObj).tp_call([w], {});
            }
        } except BaseException {
            return;
        }
    }

    try {
        host_wr = weakref.ref(target, _on_death);
    } except TypeError {
        return None;
    }
    if call {
        w: PyWeakRef = PyWeakProxy(t=tag, wr=host_wr, call=True);
    } else {
        w: PyWeakRef = PyWeakRef(t=tag, wr=host_wr);
    }
    box.append(w);
    entries = _registry.get(key);
    if entries is None {
        _registry[key] = [w];
    } else {
        entries.append(w);
    }
    return w;
}

# Shared arg shaping for ref()/proxy(): one positional object plus an optional
# callback (second positional or callback= keyword). Returns py_none() when no
# callback was supplied, or a PyError marker for arity/kwarg violations.
def _shape_args(args: list[PyObj], kwargs: dict[str, PyObj], fname: str) -> PyObj {
    for k in kwargs {
        if k != "callback" {
            return py_error(
                "TypeError",
                fname + "() got an unexpected keyword argument '" + k + "'"
            );
        }
    }
    kwcb = kwargs.get("callback");
    if len(args) == 2 {
        if kwcb is not None {
            return py_error(
                "TypeError", fname + "() got multiple values for argument 'callback'"
            );
        }
        return args[1];
    }
    if kwcb is not None {
        return kwcb;
    }
    return py_none();
}

# The ref type (Modules/_weakref.c rides on Objects/weakrefobject.c's
# weakref___init__ / _PyWeakref_NewRef): object [, callback] -> live wrapper.
obj PyWeakRefFn(PyObj) {
    # Identity hash (CPython: builtin-style callables hash by id); copy.py's
    # module init stores these wrappers in hash-keyed dispatch structures.
    def tp_hashkey -> PyObj {
        return PyStr(t="str", val="obj:" + str(id(self)));
    }

    def tp_call(args: list[PyObj], kwargs: dict[str, PyObj]) -> PyObj {
        cb = _shape_args(args, kwargs, "weakref.ref");
        if is_error(cb) {
            return cb;
        }
        if len(args) < 1 {
            return py_error("TypeError", "weakref.ref expected at least 1 argument");
        }
        if len(args) > 2 {
            return py_error("TypeError", "weakref.ref expected at most 2 arguments");
        }
        target = args[0];
        if not _supports_weakrefs(target) {
            return py_error(
                "TypeError",
                "cannot create weak reference to '" + target.tp_type_name() + "' object",
            );
        }
        w = _register_weakref(target, cb, "weakref", False);
        if w is None {
            return py_error("TypeError", "cannot create weak reference to 'object' object");
        }
        return w;
    }
}

# Calling a weakref derefs it: the raw value IS the original PyObj, so
# identity (`r() is o`) holds; a dead reference calls to None.
obj PyWeakRef(PyObj) {
    has wr: any;

    def tp_hashkey -> PyObj {
        return PyStr(t="str", val="obj:" + str(id(self)));
    }

    def tp_call(args: list[PyObj], kwargs: dict[str, PyObj]) -> PyObj {
        raw = self.wr();
        if raw is None {
            return py_none();
        }
        return raw as PyObj;
    }
}

# The proxy types (PyWeakref_ProxyType / PyWeakref_CallableProxyType): every
# access goes through the LIVE referent; once it dies any access raises
# ReferenceError("weakly-referenced object no longer exists") like CPython's
# proxy_getattr dead path.
obj PyWeakProxy(PyWeakRef) {
    has call: bool = False;

    def _live_referent -> PyObj {
        raw = self.wr();
        if raw is None {
            return py_error("ReferenceError", "weakly-referenced object no longer exists");
        }
        return raw as PyObj;
    }

    def tp_getattro(name: str) -> PyObj {
        target = self._live_referent();
        if is_error(target) {
            return target;
        }
        return target.tp_getattro(name);
    }

    def tp_setattro(name: str, value: PyObj) -> PyObj {
        target = self._live_referent();
        if is_error(target) {
            return target;
        }
        return target.tp_setattro(name, value);
    }

    def tp_call(args: list[PyObj], kwargs: dict[str, PyObj]) -> PyObj {
        target = self._live_referent();
        if is_error(target) {
            return target;
        }
        if not self.call {
            return py_error("TypeError", "'" + self.t + "' object is not callable");
        }
        return target.tp_call(args, kwargs);
    }

    def tp_richcompare(kind: int, other: PyObj) -> PyObj {
        # Proxies compare by referent equality (== / != only; orderings stay
        # PY_NOT_IMPLEMENTED so the reflected slot machinery still runs).
        target = self._live_referent();
        if is_error(target) {
            return target;
        }
        if kind == 2 or kind == 3 {
            return target.tp_richcompare(kind, other);
        }
        return PY_NOT_IMPLEMENTED;
    }
}

# The shared constructor behind ProxyType / CallableProxyType / proxy().
obj PyWeakProxyCtor(PyObj) {
    has call: bool;

    def tp_hashkey -> PyObj {
        return PyStr(t="str", val="obj:" + str(id(self)));
    }

    def tp_call(args: list[PyObj], kwargs: dict[str, PyObj]) -> PyObj {
        cb = _shape_args(args, kwargs, "weakref.proxy");
        if is_error(cb) {
            return cb;
        }
        if len(args) < 1 {
            return py_error("TypeError", "weakref.proxy expected at least 1 argument");
        }
        if len(args) > 2 {
            return py_error("TypeError", "weakref.proxy expected at most 2 arguments");
        }
        target = args[0];
        if not _supports_weakrefs(target) {
            return py_error(
                "TypeError",
                "cannot create weak reference to '" + target.tp_type_name() + "' object",
            );
        }
        w = _register_weakref(target, cb, "weak_proxy", self.call);
        if w is None {
            return py_error("TypeError", "cannot create weak reference to 'object' object");
        }
        return w;
    }
}

# The plain module functions: getweakrefcount / getweakrefs /
# _remove_dead_weakref (weakref_functions[] in _weakref.c).
obj PyWrefFunc(PyObj) {
    has name: str;

    def tp_hashkey -> PyObj {
        return PyStr(t="str", val="obj:" + str(id(self)));
    }

    def tp_call(args: list[PyObj], kwargs: dict[str, PyObj]) -> PyObj {
        if self.name == "getweakrefcount" {
            if len(args) != 1 or len(kwargs) > 0 {
                return py_error("TypeError", "getweakrefcount expected 1 argument");
            }
            target = args[0];
            if not _supports_weakrefs(target) {
                # CPython answers 0 when the type carries no weakref listptr.
                return PyInt(t="int", val=0);
            }
            return PyInt(t="int", val=len(_live_wrappers_for(id(target))));
        }
        if self.name == "getweakrefs" {
            if len(args) != 1 or len(kwargs) > 0 {
                return py_error("TypeError", "getweakrefs expected 1 argument");
            }
            target = args[0];
            if not _supports_weakrefs(target) {
                # _weakref_getweakrefs returns a fresh empty list here.
                return PyList(t="list", items=[]);
            }
            return PyList(t="list", items=_live_wrappers_for(id(target)));
        }
        if self.name == "_remove_dead_weakref" {
            if len(args) != 2 or len(kwargs) > 0 {
                return py_error("TypeError", "_remove_dead_weakref expected 2 arguments");
            }
            dct = args[0];
            if not isinstance(dct, PyDict) {
                return py_error("TypeError", "_remove_dead_weakref: dct must be a dict");
            }
            key = args[1];
            hk_res = key.tp_hashkey();
            if is_error(hk_res) {
                return py_error(
                    "TypeError", "unhashable type: '" + key.tp_type_name() + "'"
                );
            }
            d = dct as PyDict;
            hk = hashkey_str(hk_res);
            slot = d.items.get(hk);
            if slot is None {
                return py_error("KeyError", dict_key_repr(key));
            }
            value = (slot as DictEntry).value;
            return self._remove_if_dead(d, hk, value);
        }
        return py_error("SystemError", "unknown _weakref function " + self.name);
    }

    def _remove_if_dead(d: PyDict, hk: str, value: PyObj) -> PyObj {
        # is_dead_weakref: foreign values raise TypeError("not a weakref"),
        # dead weakrefs delete, live ones leave the entry untouched --
        # exactly the _PyDict_DelItemIf contract.
        if not isinstance(value, PyWeakRef) {
            return py_error("TypeError", "not a weakref");
        }
        if (value as PyWeakRef).wr() is None {
            del d.items[hk];
        }
        return py_none();
    }
}

# Module dict exactly as weakref_exec builds it (ref + the three type attrs)
# plus weakref_functions[] -- with the type names wrapped as shim markers so
# isinstance(w, ReferenceType) matches the native tags (same mechanism as the
# traceback shim). ref/ReferenceType and proxy/ProxyType share one marker
# each, preserving CPython's `is` identity between the aliases.
def build_weakref_module_attrs -> dict[str, PyObj] {
    ref_type = ShimTypeMarker(t="shim_type_marker", tag="weakref", ctor=_reference_ctor);
    proxy_type = ShimTypeMarker(
        t="shim_type_marker", tag="weak_proxy", ctor=_proxy_ctor
    );
    callable_proxy_type = ShimTypeMarker(
        t="shim_type_marker", tag="weak_callable_proxy", ctor=_callable_proxy_ctor
    );
    return {
        "ref": ref_type,
        "ReferenceType": ref_type,
        "ProxyType": proxy_type,
        "proxy": proxy_type,
        "CallableProxyType": callable_proxy_type,
        "getweakrefcount": PyWrefFunc(t="weakref_func", name="getweakrefcount"),
        "getweakrefs": PyWrefFunc(t="weakref_func", name="getweakrefs"),
        "_remove_dead_weakref": PyWrefFunc(
            t="weakref_func", name="_remove_dead_weakref"
        ),
    };
}
