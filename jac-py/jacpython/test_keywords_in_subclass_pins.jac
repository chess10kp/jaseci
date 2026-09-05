# keywords_in_subclass scoping pins -- builtin-subclass construction dispatch
# decomposed per arm, one pin per (base type x dispatch path).
#
# Scope (objects-lane task 090): CPython Lib/test/test_{set,list,tuple}.py
# ``test_keywords_in_subclass`` spans FIVE distinct construction paths through
# PyClass.tp_call's native-base handling:
#   A. no user __init__/__new__, positional args -> base box filled from args
#   B. no user __init__, kwargs            -> MRO-resolved init rejects kwargs
#   C. user __init__ over mutable base     -> empty box + super().__init__ fill
#      user __init__ over immutable base   -> box frozen at __new__ time,
#                                             __init__ only records attrs
#   D. user __new__ (+ super().__new__)    -> __new__ boxes, sets attrs
#   E. user __new__ ONLY, called with kwargs -> set.__init__ rejects (bpo-43413)
# Every expected string below was recorded from host CPython (python3) before
# being pinned; any red isolates the exact divergent arm.
#
# NOTE: the dispatch under test lives in ceval.jac (PyClass.tp_call /
# PyBuiltinSuperMethod / construct_native_base), not objects.jac (data defs
# only). Metaclass/type-side behavior is typesys lane -- out of scope here.

import from objects { PyObj, PyCode, PyError, is_error }
import from product_compile { compile_source }
import from pyc_first { exec_code, to_host }


def run_src(src: str) -> str {
    # Compile + VM execute; repr of module global `r`, or "Type: message" when
    # the VM raised (error-arm pins match on the full CPython message).
    co = compile_source(src, "<kw-subclass>", "exec", 0);
    if is_error(co) {
        e = co as PyError;
        return "CompileError: " + str(e.exception.message);
    }
    ns: dict[str, PyObj] = {};
    outcome = exec_code(co as PyCode, [], ns);
    if is_error(outcome) {
        e2 = outcome as PyError;
        return str(e2.exception.type_name) + ": " + str(e2.exception.message);
    }
    if "r" in ns {
        return repr(to_host(ns["r"]));
    }
    return "";
}

# ---- list ----

test "list subclass: no-init positional fills box" {
    assert run_src(
        "class subclass(list):\n"
        + "    pass\n"
        + "u = subclass([1, 2])\n"
        + "r = (type(u) is subclass, list(u))\n"
    ) == "(True, [1, 2])";
}

test "list subclass: no-init kwargs rejected" {
    assert run_src(
        "class subclass(list):\n"
        + "    pass\n"
        + "try:\n"
        + "    subclass(sequence=())\n"
        + "    r = 'NO-RAISE'\n"
        + "except TypeError as e:\n"
        + "    r = 'TypeError: ' + str(e)\n"
    ) == "TypeError: list() takes no keyword arguments";
}

test "list subclass: user __init__ gets kwargs, super().__init__ fills" {
    assert run_src(
        "class subclass_with_init(list):\n"
        + "    def __init__(self, seq, newarg=None):\n"
        + "        super().__init__(seq)\n"
        + "        self.newarg = newarg\n"
        + "u = subclass_with_init([1, 2], newarg=3)\n"
        + "r = (type(u) is subclass_with_init, list(u), u.newarg)\n"
    ) == "(True, [1, 2], 3)";
}

# ---- tuple ----

test "tuple subclass: no-init positional freezes box at __new__" {
    assert run_src(
        "class subclass(tuple):\n"
        + "    pass\n"
        + "u = subclass([1, 2])\n"
        + "r = (type(u) is subclass, list(u))\n"
    ) == "(True, [1, 2])";
}

test "tuple subclass: no-init kwargs rejected" {
    assert run_src(
        "class subclass(tuple):\n"
        + "    pass\n"
        + "try:\n"
        + "    subclass(sequence=())\n"
        + "    r = 'NO-RAISE'\n"
        + "except TypeError as e:\n"
        + "    r = 'TypeError: ' + str(e)\n"
    ) == "TypeError: tuple() takes no keyword arguments";
}

test "tuple subclass: user __init__ records kwargs, box frozen from args" {
    assert run_src(
        "class subclass_with_init(tuple):\n"
        + "    def __init__(self, arg, newarg=None):\n"
        + "        self.newarg = newarg\n"
        + "u = subclass_with_init([1, 2], newarg=3)\n"
        + "r = (type(u) is subclass_with_init, list(u), u.newarg)\n"
    ) == "(True, [1, 2], 3)";
}

test "tuple subclass: user __new__ accepts kwargs via object.__init__ rule" {
    # No user __init__: MRO resolves to object.__init__, which tolerates excess
    # args exactly because __new__ IS overridden (CPython typeobject.c rule).
    assert run_src(
        "class subclass_with_new(tuple):\n"
        + "    def __new__(cls, arg, newarg=None):\n"
        + "        self = super().__new__(cls, arg)\n"
        + "        self.newarg = newarg\n"
        + "        return self\n"
        + "u = subclass_with_new([1, 2], newarg=3)\n"
        + "r = (type(u) is subclass_with_new, list(u), u.newarg)\n"
    ) == "(True, [1, 2], 3)";
}

# ---- set ----

test "set subclass: no-init positional fills box" {
    assert run_src(
        "class subclass(set):\n"
        + "    pass\n"
        + "u = subclass([1, 2])\n"
        + "r = (type(u) is subclass, set(u) == {1, 2})\n"
    ) == "(True, True)";
}

test "set subclass: no-init kwargs rejected" {
    assert run_src(
        "class subclass(set):\n"
        + "    pass\n"
        + "try:\n"
        + "    subclass(sequence=())\n"
        + "    r = 'NO-RAISE'\n"
        + "except TypeError as e:\n"
        + "    r = 'TypeError: ' + str(e)\n"
    ) == "TypeError: set() takes no keyword arguments";
}

test "set subclass: user __init__ gets kwargs, super().__init__ fills" {
    assert run_src(
        "class subclass_with_init(set):\n"
        + "    def __init__(self, arg, newarg=None):\n"
        + "        super().__init__(arg)\n"
        + "        self.newarg = newarg\n"
        + "u = subclass_with_init([1, 2], newarg=3)\n"
        + "r = (type(u) is subclass_with_init, set(u) == {1, 2}, u.newarg)\n"
    ) == "(True, True, 3)";
}

test "set subclass: user __new__ boxes and records attr" {
    assert run_src(
        "class subclass_with_new(set):\n"
        + "    def __new__(cls, arg, newarg=None):\n"
        + "        self = super().__new__(cls, arg)\n"
        + "        self.newarg = newarg\n"
        + "        return self\n"
        + "u = subclass_with_new([1, 2])\n"
        + "r = (type(u) is subclass_with_new, set(u) == {1, 2}, u.newarg is None)\n"
    ) == "(True, True, True)";
}

test "set subclass: __new__-only with kwargs -> set.__init__ rejects" {
    # bpo-43413: no user __init__, so the MRO-resolved initializer is
    # set.__init__, which rejects keywords even after a user __new__ ran.
    assert run_src(
        "class subclass_with_new(set):\n"
        + "    def __new__(cls, arg, newarg=None):\n"
        + "        self = super().__new__(cls, arg)\n"
        + "        self.newarg = newarg\n"
        + "        return self\n"
        + "try:\n"
        + "    subclass_with_new([1, 2], newarg=3)\n"
        + "    r = 'NO-RAISE'\n"
        + "except TypeError as e:\n"
        + "    r = 'TypeError: ' + str(e)\n"
    ) == "TypeError: set() takes no keyword arguments";
}

# ---- frozenset ----

test "frozenset subclass: no-init positional freezes box at __new__" {
    assert run_src(
        "class subclass(frozenset):\n"
        + "    pass\n"
        + "u = subclass([1, 2])\n"
        + "r = (type(u) is subclass, set(u) == {1, 2})\n"
    ) == "(True, True)";
}

test "frozenset subclass: no-init kwargs rejected" {
    assert run_src(
        "class subclass(frozenset):\n"
        + "    pass\n"
        + "try:\n"
        + "    subclass(sequence=())\n"
        + "    r = 'NO-RAISE'\n"
        + "except TypeError as e:\n"
        + "    r = 'TypeError: ' + str(e)\n"
    ) == "TypeError: frozenset() takes no keyword arguments";
}

test "frozenset subclass: user __init__ records kwargs, box frozen from args" {
    assert run_src(
        "class subclass_with_init(frozenset):\n"
        + "    def __init__(self, arg, newarg=None):\n"
        + "        self.newarg = newarg\n"
        + "u = subclass_with_init([1, 2], newarg=3)\n"
        + "r = (type(u) is subclass_with_init, set(u) == {1, 2}, u.newarg)\n"
    ) == "(True, True, 3)";
}

test "frozenset subclass: user __new__ accepts call-site kwargs (host parity)" {
    # Host oracle: frozenset inherits object.__init__, which tolerates excess
    # kwargs when __new__ is overridden (unlike set.__init__).
    assert run_src(
        "class subclass_with_new(frozenset):\n"
        + "    def __new__(cls, arg, newarg=None):\n"
        + "        self = super().__new__(cls, arg)\n"
        + "        self.newarg = newarg\n"
        + "        return self\n"
        + "u = subclass_with_new([1, 2], newarg=3)\n"
        + "r = (type(u) is subclass_with_new, set(u) == {1, 2}, u.newarg)\n"
    ) == "(True, True, 3)";
}
