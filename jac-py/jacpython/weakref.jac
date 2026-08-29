# Product-path facade for the _weakref accelerator module (native Jac).
#
# Semantics mirror CPython 3.14 ``Modules/_weakref.c``: the module surface is
# getweakrefcount/getweakrefs/proxy/_remove_dead_weakref plus the names the
# module exec installs (ref/ReferenceType/ProxyType/CallableProxyType).
#
# Backing model -- identical to ceval's weakref shim: host weakrefs are taken
# over the RAW jacpython wrapper objects (PyUserObj/PyClass/functions are
# ordinary CPython objects), so deref hands back the identical object and death
# follows refcounting exactly. Boxed value types and host proxies stay
# un-weakreferenceable through the shared gate in ceval.
#
# Relationship to ceval: ``ref``/``ReferenceType`` ARE ceval's PyWeakRefFn
# (single source of truth for the identity-faithful ref). ceval keeps a minimal
# fallback shim built when guest code imports weakref before this facade is
# loaded; calling install_weakref_module() swaps in this full surface via
# register_shim_module, and ceval's import-path membership guard then leaves it
# alone. (Jac forbids import cycles, so ceval cannot import from here --
# everything here may import FROM ceval, never the reverse.)
#
# Documented deviations from CPython:
# - ProxyType/CallableProxyType collapse onto the single native proxy
#   constructor: one implementation serves both callable and plain targets.
# - getweakrefs wraps every live host weakref as a reference object; proxies
#   listed there lose their proxy forwarding when wrapped.

import from objects {
    PyObj,
    PyStr,
    PyInt,
    PyList,
    PyDict,
    PyNoneType,
    py_none,
    py_error,
    _base_type_name,
    is_error,
    dict_key_repr,
}
import from ceval {
    PyModule,
    PyWeakRefFn,
    PyWeakRef,
    register_shim_module,
    to_host,
    weakref_target_rejected,
    weakref_target_error,
}
import from ceval_defs { PyHostProxy, }

import from importlib { import_module }

# Host bridge (see header note). importlib indirection because a bare
# ``import weakref`` inside this package resolves same-directory first and
# would re-enter this very module now that jacpython/weakref.jac exists.
glob _host_weakref: any = import_module("weakref");

# ---- shared plumbing --------------------------------------------------------

def _arity_error(fname: str, want: str) -> PyObj {
    return py_error("TypeError", fname + " expected " + want + " argument(s)");
}

# A host weakref counts as dead when its raw slot reads None (the same check
# ceval's _jac_weakref_deref performs).
def _host_weakref_dead(wr: any) -> bool {
    return wr() is None;
}

# ---- _weakref.getweakrefcount ----------------------------------------------

obj PyWeakRefCountFn(PyObj) {
    # Identity hash (CPython: builtin-style callables hash by id); converted
    # stdlib code stores these wrappers in sets and dict keys.
    def tp_hashkey -> PyObj {
        return PyStr(t="str", val="obj:" + str(id(self)));
    }

    def tp_call(args: list[PyObj], kwargs: dict[str, PyObj]) -> PyObj {
        if len(args) != 1 or len(kwargs) > 0 {
            return _arity_error("getweakrefcount", "1");
        }
        target = args[0];
        if weakref_target_rejected(target) {
            return weakref_target_error(target);
        }
        # Host getweakrefcount counts live weakrefs over the raw wrapper --
        # exactly CPython's wr_list walk.
        return PyInt(t="int", val=int(_host_weakref.getweakrefcount(target)));
    }
}

# ---- _weakref.getweakrefs ---------------------------------------------------

obj PyWeakRefsFn(PyObj) {
    def tp_hashkey -> PyObj {
        return PyStr(t="str", val="obj:" + str(id(self)));
    }

    def tp_call(args: list[PyObj], kwargs: dict[str, PyObj]) -> PyObj {
        if len(args) != 1 or len(kwargs) > 0 {
            return _arity_error("getweakrefs", "1");
        }
        target = args[0];
        if weakref_target_rejected(target) {
            # CPython returns an empty list when the type has no weakref list.
            return PyList(t="list", items=[]);
        }
        out: list[PyObj] = [];
        for wr in _host_weakref.getweakrefs(target) {
            out.append(PyWeakRef(t="weakref", wr=wr));
        }
        return PyList(t="list", items=out);
    }
}

# ---- _weakref.proxy ---------------------------------------------------------

obj PyWeakProxyFn(PyObj) {
    def tp_hashkey -> PyObj {
        return PyStr(t="str", val="obj:" + str(id(self)));
    }

    def tp_call(args: list[PyObj], kwargs: dict[str, PyObj]) -> PyObj {
        if len(kwargs) > 0 {
            return py_error("TypeError", "proxy() takes no keyword arguments");
        }
        if len(args) < 1 or len(args) > 2 {
            return _arity_error("proxy", "1 or 2");
        }
        target = args[0];
        if weakref_target_rejected(target) {
            return weakref_target_error(target);
        }
        cb_host: any = None;
        if len(args) == 2 and not isinstance(args[1], PyNoneType) {
            # Guest callables cross as trampolines (to_host policy table), so
            # the host can invoke the callback with the dying proxy exactly
            # like CPython's finalize path does.
            cb_host = to_host(args[1]);
            if cb_host is None {
                return py_error("TypeError", "callback is not callable");
            }
        }
        raw: any;
        try {
            if cb_host is None {
                raw = _host_weakref.proxy(target);
            } else {
                raw = _host_weakref.proxy(target, cb_host);
            }
        } except TypeError as e {
            return py_error("TypeError", str(e));
        }
        # PyHostProxy forwards attribute access and calls to the wrapped host
        # proxy, which delegates to the target while it lives and raises
        # ReferenceError (mapped to the guest error channel by the bridge)
        # after it dies -- CPython's proxy contract.
        return PyHostProxy(t="host", val=raw);
    }
}

# ---- _weakref._remove_dead_weakref ------------------------------------------
#
# Mirrors the clinic pair (_remove_dead_weakref(dct, key) over
# _PyDict_DelItemIf + is_dead_weakref): atomically drop key from dct when its
# value is a dead weakref. KeyError when the key is absent; TypeError when the
# stored value is not a weakref at all (is_dead_weakref's own check).

obj PyWeakrefRemoveDeadFn(PyObj) {
    def tp_hashkey -> PyObj {
        return PyStr(t="str", val="obj:" + str(id(self)));
    }

    def tp_call(args: list[PyObj], kwargs: dict[str, PyObj]) -> PyObj {
        if len(args) != 2 or len(kwargs) > 0 {
            return _arity_error("_remove_dead_weakref", "2");
        }
        if not isinstance(args[0], PyDict) {
            return py_error(
                "TypeError",
                "_remove_dead_weakref() argument 'dct' must be dict, not '"
                    + _base_type_name(args[0]) + "'"
            );
        }
        dct = args[0] as PyDict;
        key = args[1];
        if not dct.dict_contains(key) {
            return py_error("KeyError", dict_key_repr(key));
        }
        val = dct.mp_subscript(key);
        if is_error(val) {
            return val;
        }
        if not isinstance(val, PyWeakRef) {
            return py_error("TypeError", "not a weakref");
        }
        if _host_weakref_dead((val as PyWeakRef).wr) {
            return dct.mp_del_subscript(key);
        }
        return py_none();
    }
}

# ---- module assembly --------------------------------------------------------

def build_weakref_facade -> PyModule {
    ref_fn = PyWeakRefFn(t="weakref_fn");
    proxy_fn = PyWeakProxyFn(t="weakref_proxy_fn");
    attrs: dict[str, PyObj] = {
        # Module-exec installed names (weakref_exec in _weakref.c): ref and
        # ReferenceType alias the same RefType object, as in CPython.
        "ref": ref_fn,
        "ReferenceType": ref_fn,
        # ProxyType/CallableProxyType collapse onto the single native proxy
        # constructor (see header deviation note).
        "ProxyType": proxy_fn,
        "CallableProxyType": proxy_fn,
        "proxy": proxy_fn,
        "getweakrefcount": PyWeakRefCountFn(t="weakref_count_fn"),
        "getweakrefs": PyWeakRefsFn(t="weakref_refs_fn"),
        "_remove_dead_weakref": PyWeakrefRemoveDeadFn(t="weakref_remove_dead_fn"),
    };
    return PyModule(t="module", name="weakref", attrs=attrs);
}

# Swap ceval's minimal fallback shim for this full surface. Safe to call
# repeatedly and before or after the first guest `import weakref`: ceval's
# import paths only build their fallback when no shim is registered yet.
def install_weakref_module {
    register_shim_module("weakref", build_weakref_facade());
}
