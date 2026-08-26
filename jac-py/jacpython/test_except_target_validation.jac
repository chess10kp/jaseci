# Lane-census pins: except-target validation in ceval's CHECK_EXC_MATCH.
#
# CPython 3.14.7 oracle provenance: _PyErr_ExceptionMatches (reached via
# CHECK_EXC_MATCH) raises "TypeError: catching classes that do not inherit
# from BaseException is not allowed" whenever an except target is not an
# exception class -- an exception INSTANCE (Lib/test/test_baseexception.py
# UsageTests.test_catch_BaseException_instance / catch_fails), a plain class
# with no BaseException base (test_catch_non_BaseException), or a string
# (test_catch_string). Tuple targets validate each element; an empty tuple is
# valid and matches nothing. The TypeError raised during handler matching
# unwinds out of the whole try statement (later handlers of the SAME try are
# skipped; enclosing handlers see it).
#
# Pins (guest source driven through product_exec + exec_code), each asserting
# the host-captured outcome:
#   1. except BaseException() -> TypeError message (BROKEN before the fix:
#      the instance fell through exception_matches to a name-level miss, so
#      the original exception propagated instead of the TypeError).
#   2. except (BaseException(),) -> same TypeError via tuple element check.
#   3. except PlainClass -> TypeError.
#   4. except 'spam' -> TypeError.
#   5. except () -> valid, matches nothing, Exception propagates uncaught
#      (pinned via the propagated outcome).
#   6. TypeError during matching skips later handlers of the same try and is
#      seen by the OUTER try's TypeError handler ("outer", not "second").
#   7. Control: normal user subclass target still matches.

import from layer9_product_exec { product_exec }
import from pyc_first { exec_code, to_host }
import from objects { PyObj, PyStr, PyCode, PyError, is_error }


def _run_native(src: str) -> str {
    # Native front end -> PyCode -> VM; str of module global `r`, or
    # "TypeName: message" when the VM raised.
    co = product_exec(src);
    ns: dict[str, PyObj] = {"__name__": PyStr(t="str", val="__main__")};
    out = exec_code(co as PyCode, [], ns);
    if is_error(out) {
        e = out as PyError;
        return str(e.exception.type_name) + ": " + str(e.exception.message);
    }
    if "r" in ns {
        return str(to_host(ns["r"]));
    }
    return "";
}


glob _CATCH_TYPEERROR_MSG: str = (
    "catching classes that do not inherit from BaseException is not allowed"
);

test "except-target: BaseException() instance raises TypeError" {
    # Host oracle (CPython 3.14.7): the TypeError above.
    assert _run_native(
        "r = 'missed'\n"
        "try:\n"
        "    raise Exception\n"
        "except BaseException():\n"
        "    r = 'caught'\n"
    ) == "TypeError: " + _CATCH_TYPEERROR_MSG;
}

test "except-target: tuple containing an instance raises TypeError" {
    assert _run_native(
        "r = 'missed'\n"
        "try:\n"
        "    raise Exception\n"
        "except (BaseException(),):\n"
        "    r = 'caught'\n"
    ) == "TypeError: " + _CATCH_TYPEERROR_MSG;
}

test "except-target: plain non-exception class raises TypeError" {
    assert _run_native(
        "r = 'missed'\n"
        "class NB(object):\n"
        "    pass\n"
        "try:\n"
        "    raise Exception\n"
        "except NB:\n"
        "    r = 'caught'\n"
    ) == "TypeError: " + _CATCH_TYPEERROR_MSG;
}

test "except-target: string target raises TypeError" {
    assert _run_native(
        "r = 'missed'\n"
        "try:\n"
        "    raise Exception\n"
        "except 'spam':\n"
        "    r = 'caught'\n"
    ) == "TypeError: " + _CATCH_TYPEERROR_MSG;
}

test "except-target: empty tuple is valid but matches nothing" {
    # Host oracle: Exception propagates uncaught (no TypeError, no catch).
    assert _run_native(
        "r = 'missed'\n"
        "try:\n"
        "    raise Exception\n"
        "except ():\n"
        "    r = 'caught'\n"
    ) == "Exception: ";
}

test "except-target: match-time TypeError skips same-try handlers" {
    # Host oracle: outer handler sees the TypeError ("outer"), the later
    # handler of the inner try does NOT run.
    assert _run_native(
        "r = 'unset'\n"
        "try:\n"
        "    try:\n"
        "        raise Exception\n"
        "    except 42:\n"
        "        pass\n"
        "    except TypeError:\n"
        "        r = 'second'\n"
        "except TypeError:\n"
        "    r = 'outer'\n"
    ) == "outer";
}

test "except-target: control -- real class targets still match" {
    assert _run_native(
        "class MyErr(ValueError):\n"
        "    pass\n"
        "r = 'missed'\n"
        "try:\n"
        "    raise MyErr('x')\n"
        "except ValueError:\n"
        "    r = 'caught'\n"
    ) == "caught";
}
