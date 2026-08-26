# Census fp-v1:c0667a09 pins: identity hash for property objects.
#
# 'TypeError: cannot use 'property_ctor' as a set element (unhashable type:
# 'property_ctor')' (census suite test_minidom): both the `property` builtin
# constructor object and property instances lacked tp_hashkey, so set/dict-key
# idioms that CPython's stdlib relies on raised TypeError. Fixed by identity
# hashkey overrides on PyPropertyCtor and PyProperty (CPython hashes builtin-
# style objects by id); these pins lock the surface in.
#
# Host oracle (CPython 3.14.7):
#   p = property; len({p})          -> 1
#   {property} == {property}        -> True  (singletons, equal identity hash)
#   class-level @property in a set  -> 1
#   {C.x: 'v'}[C.x]                 -> 'v'
import from host_oracle { host_compile_marshal }
import from pyc_first { unmarshal, exec_code, to_host }
import from objects { PyObj, PyStr, is_error }


# Exec `src` on ceval with fresh module globals; fails the test on raise.
def vm_exec(src: str) -> dict[str, PyObj] {
    ns: dict[str, PyObj] = {"__name__": PyStr(t="str", val="__main__")};
    outcome = exec_code(
        unmarshal(host_compile_marshal(src, "<prop_hash>", "exec")), [], ns
    );
    assert not is_error(outcome);
    return ns;
}

# Run `src`, capturing `expr`'s value or its exception as "Type: message".
def outcome_str(src: str, expr: str) -> str {
    ns = vm_exec(
        src +
        "try:\n"
        "    r = " + expr + "\n"
        "except BaseException as e:\n"
        "    r = type(e).__name__ + ': ' + str(e)\n"
    );
    v = to_host(ns["r"]);
    if isinstance(v, str) {
        return v;
    }
    return str(v);
}


test "property ctor object hashes into a set" {
    assert outcome_str("p = property\n", "len({p})") == "1";
}

test "property builtin keeps singleton identity across loads" {
    # Memoized host_builtin minting one object per name is what makes the set
    # hold a single element; a fresh wrapper per load would give 2.
    assert outcome_str("", "{property} == {property}") == "True";
}

test "class-level property instance is set-key legal" {
    src = "class C:\n"
        "    @property\n"
        "    def x(self):\n"
        "        return 1\n";
    assert outcome_str(src, "len({C.x})") == "1";
}

test "property instance works as a dict key" {
    src = "class C:\n"
        "    @property\n"
        "    def x(self):\n"
        "        return 1\n";
    assert outcome_str(src, "({C.x: 'v'})[C.x]") == "'v'";
}
