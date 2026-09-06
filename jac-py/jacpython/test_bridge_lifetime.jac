# Bridge stand-in cache lifetime pins (PLAN.md phase 5 / bridge-lifetime).
#
# Crossing a guest class or plain user object mints a cached host stand-in.
# The cache must NOT retain released guest objects: entries are doubly weak
# (guest wr + host-face wr) with stale-id() guards and death callbacks that
# scrub _jac_guest_cls_ / _jac_guest_ back-references.

import from host_oracle { host_compile_marshal }
import from pyc_first { unmarshal, exec_code, to_host }
import from ceval { _jac_standin_cache_sizes }
import from objects { PyObj, PyStr, is_error }

def vm_exec(src: str) -> dict[str, PyObj] {
    ns: dict[str, PyObj] = {"__name__": PyStr(t="str", val="__main__")};
    outcome = exec_code(
        unmarshal(host_compile_marshal(src, "<bridge_lifetime>", "exec")), [], ns
    );
    assert not is_error(outcome);
    return ns;
}

def vm_bool(ns: dict[str, PyObj], name: str) -> bool {
    return to_host(ns[name]) as bool;
}

test "guest class released after stand-in crossing is not cache-retained" {
    ns = vm_exec(
        "import weakref\n"
        "def cross_cls(c):\n"
        "    try:\n"
        "        __import__('json').dumps(c)\n"
        "    except BaseException:\n"
        "        pass\n"
        "class C:\n"
        "    pass\n"
        "cross_cls(C)\n"
        "r = weakref.ref(C)\n"
        "del C\n"
        "dead = r() is None\n"
    );
    assert vm_bool(ns, "dead");
}

test "many guest classes churn without stand-in cache growth" {
    ns = vm_exec(
        "import weakref\n"
        "def cross_cls(c):\n"
        "    try:\n"
        "        __import__('json').dumps(c)\n"
        "    except BaseException:\n"
        "        pass\n"
        "ok = True\n"
        "for _ in range(64):\n"
        "    class C:\n"
        "        pass\n"
        "    cross_cls(C)\n"
        "    r = weakref.ref(C)\n"
        "    del C\n"
        "    if r() is not None:\n"
        "        ok = False\n"
        "        break\n"
    );
    assert vm_bool(ns, "ok");
    (n_cls, n_user) = _jac_standin_cache_sizes();
    assert n_cls == 0;
    assert n_user == 0;
}

test "guest instance released after stand-in crossing is not cache-retained" {
    ns = vm_exec(
        "import weakref\n"
        "class C:\n"
        "    pass\n"
        "def cross(o):\n"
        "    try:\n"
        "        __import__('json').dumps(o)\n"
        "    except BaseException:\n"
        "        pass\n"
        "o = C()\n"
        "cross(o)\n"
        "r = weakref.ref(o)\n"
        "del o\n"
        "dead = r() is None\n"
    );
    assert vm_bool(ns, "dead");
}

test "many guest instances churn without stand-in cache growth" {
    ns = vm_exec(
        "import weakref\n"
        "class C:\n"
        "    pass\n"
        "def cross(o):\n"
        "    try:\n"
        "        __import__('json').dumps(o)\n"
        "    except BaseException:\n"
        "        pass\n"
        "ok = True\n"
        "for _ in range(64):\n"
        "    o = C()\n"
        "    cross(o)\n"
        "    r = weakref.ref(o)\n"
        "    del o\n"
        "    if r() is not None:\n"
        "        ok = False\n"
        "        break\n"
    );
    assert vm_bool(ns, "ok");
    (n_cls, n_user) = _jac_standin_cache_sizes();
    assert n_cls == 0;
    assert n_user == 0;
}
