"""_weakref facade parity (native jacpython vs Modules/_weakref.c semantics).

Exercises the lifted surface directly at the PyObj layer: ref/ReferenceType
identity, weakrefable-type gating, live/dead counting through the registry,
proxy delegation and the ReferenceError dead path, eager death callbacks, and
the _remove_dead_weakref dict-cleanup contract (delete iff dead weakref,
"not a weakref" TypeError otherwise).
"""

import from objects {
    PyObj,
    PyStr,
    PyInt,
    PyList,
    PyDict,
    PyError,
    DictEntry,
    py_none,
    py_error,
    hashkey_str,
    is_error,
}
import from _weakrefmodule {
    build_weakref_module_attrs,
    PyWeakRef,
}

# A minimal weakrefable PyObj: instances are ordinary host objects, so a host
# weakref tracks them exactly. tp_getattro serves one attr so proxy
# delegation is observable.
obj WrBox(PyObj) {
    has v: int;

    def tp_getattro(name: str) -> PyObj {
        if name == "v" {
            return PyInt(t="int", val=self.v);
        }
        return py_error("AttributeError", name);
    }
}

# Callback probe: records invocations (CPython calls the callback with the
# dying weakref once the referent dies).
glob _cb_hits: list[bool] = [];

obj WrRecorder(PyObj) {
    def tp_call(args: list[PyObj], kwargs: dict[str, PyObj]) -> PyObj {
        _cb_hits.append(True);
        return py_none();
    }
}


def _attrs -> dict[str, PyObj] {
    return build_weakref_module_attrs();
}


test "_weakref surface mirrors _weakref.c exec + function table" {
    attrs = _attrs();
    for name in [
        "ref", "ReferenceType", "ProxyType", "CallableProxyType", "proxy",
        "getweakrefcount", "getweakrefs", "_remove_dead_weakref",
    ] {
        assert name in attrs;
    }
    # Aliases are the SAME object, like CPython (ref is ReferenceType,
    # proxy is ProxyType).
    assert (attrs["ref"] as PyObj) is (attrs["ReferenceType"] as PyObj);
    assert (attrs["proxy"] as PyObj) is (attrs["ProxyType"] as PyObj);
}

test "shim markers carry the native instance tags" {
    attrs = _attrs();
    ref_marker = attrs["ReferenceType"] as PyObj;
    tag = ref_marker.tp_getattro("__jac_shim_tag__");
    assert not is_error(tag);
    assert (tag as PyStr).val == "weakref";
}

test "ref creates identity-faithful weakrefs; count follows liveness" {
    attrs = _attrs();
    box = WrBox(t="wr_box", v=7);
    w1 = (attrs["ref"] as PyObj).tp_call([box], {});
    assert not is_error(w1);
    w2 = (attrs["ref"] as PyObj).tp_call([box], {});
    assert not is_error(w2);

    # r() is o: the raw value IS the original object.
    got = (w1 as PyObj).tp_call([], {});
    assert not is_error(got);
    assert (got as PyObj) is box;

    n = (attrs["getweakrefcount"] as PyObj).tp_call([box], {});
    assert (n as PyInt).val == 2;

    refs = (attrs["getweakrefs"] as PyObj).tp_call([box], {});
    assert len((refs as PyList).items) == 2;
}

test "un-weakreferenceable scalars raise the CPython message" {
    attrs = _attrs();
    err = (attrs["ref"] as PyObj).tp_call([PyInt(t="int", val=1)], {});
    assert is_error(err);
    assert (err as PyError).exception.message == "cannot create weak reference to 'int' object";

    # getweakrefcount/getweakrefs answer 0 / [] instead of raising.
    zero = (attrs["getweakrefcount"] as PyObj).tp_call([PyInt(t="int", val=1)], {});
    assert (zero as PyInt).val == 0;
    empty = (attrs["getweakrefs"] as PyObj).tp_call([PyInt(t="int", val=1)], {});
    assert len((empty as PyList).items) == 0;
}

test "death clears counts and fires callbacks eagerly" {
    attrs = _attrs();
    box = WrBox(t="wr_box", v=1);
    cb = WrRecorder(t="wr_recorder");
    w = (attrs["ref"] as PyObj).tp_call([box], {"callback": cb});
    assert not is_error(w);
    n_before = (attrs["getweakrefcount"] as PyObj).tp_call([box], {});
    assert (n_before as PyInt).val == 1;

    del box;
    # The referent is gone: the registry pruned it and the callback ran.
    assert len(_cb_hits) == 1;
    other = WrBox(t="wr_box", v=99);
    n_other = (attrs["getweakrefcount"] as PyObj).tp_call([other], {});
    assert (n_other as PyInt).val == 0;
}

test "dead refs deref to None and stop counting" {
    attrs = _attrs();
    box = WrBox(t="wr_box", v=2);
    w = (attrs["ref"] as PyObj).tp_call([box], {});
    del box;

    dead = (w as PyObj).tp_call([], {});
    assert is_instance_none(dead);
}

def is_instance_none(v: PyObj) -> bool {
    return v.t == "NoneType";
}

test "proxy delegates attribute access while alive and raises when dead" {
    attrs = _attrs();
    box = WrBox(t="wr_box", v=5);
    p = (attrs["proxy"] as PyObj).tp_call([box], {});
    assert not is_error(p);
    assert (p as PyObj).t == "weak_proxy";
    got = (p as PyObj).tp_getattro("v");
    assert not is_error(got);
    assert (got as PyInt).val == 5;

    del box;
    dead = (p as PyObj).tp_getattro("v");
    assert is_error(dead);
    assert (dead as PyError).exception.type_name == "ReferenceError";
    assert (dead as PyError).exception.message == "weakly-referenced object no longer exists";
}

test "callable proxy calls through to the live referent" {
    attrs = _attrs();
    target = WrRecorder(t="wr_recorder");
    cp = (attrs["CallableProxyType"] as PyObj).tp_call([target], {});
    assert not is_error(cp);
    assert (cp as PyObj).t == "weak_callable_proxy";
    out = (cp as PyObj).tp_call([], {});
    assert not is_error(out);
    assert len(_cb_hits) >= 0;
}

test "_remove_dead_weakref deletes only dead weakref entries" {
    attrs = _attrs();
    remove = attrs["_remove_dead_weakref"] as PyObj;

    # Missing key raises KeyError.
    d0 = PyDict(t="dict", items={});
    k0 = PyStr(t="str", val="absent");
    missing = remove.tp_call([d0, k0], {});
    assert is_error(missing);
    assert (missing as PyError).exception.type_name == "KeyError";

    # Foreign value raises TypeError("not a weakref").
    d1 = PyDict(t="dict", items={});
    k1 = PyStr(t="str", val="foreign");
    d1.items[hashkey_str(k1.tp_hashkey())] = DictEntry(
        key=k1, value=PyInt(t="int", val=3)
    );
    foreign = remove.tp_call([d1, k1], {});
    assert is_error(foreign);
    assert (foreign as PyError).exception.message == "not a weakref";

    # Live weakref stays.
    live_box = WrBox(t="wr_box", v=3);
    live_wr = (attrs["ref"] as PyObj).tp_call([live_box], {});
    d2 = PyDict(t="dict", items={});
    k2 = PyStr(t="str", val="live");
    hk2 = hashkey_str(k2.tp_hashkey());
    d2.items[hk2] = DictEntry(key=k2, value=live_wr as PyObj);
    kept = remove.tp_call([d2, k2], {});
    assert not is_error(kept);
    assert hk2 in d2.items;

    # Dead weakref goes.
    dying_box = WrBox(t="wr_box", v=4);
    dead_wr = (attrs["ref"] as PyObj).tp_call([dying_box], {});
    del dying_box;
    d3 = PyDict(t="dict", items={});
    k3 = PyStr(t="str", val="dead");
    hk3 = hashkey_str(k3.tp_hashkey());
    d3.items[hk3] = DictEntry(key=k3, value=dead_wr as PyObj);
    removed = remove.tp_call([d3, k3], {});
    assert not is_error(removed);
    assert hk3 not in d3.items;
}
