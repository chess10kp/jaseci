# Pins: invalid plain-except targets raise TypeError (OP_CHECK_EXC_MATCH).
#
# CPython 3.14 oracle provenance: ceval.c CHECK_EXC_MATCH calls
# check_except_type_valid before PyErr_GivenExceptionMatches -- every `except`
# target must be an exception class (tuple members included); anything else
# raises "TypeError: catching classes that do not inherit from BaseException
# is not allowed" BEFORE any match attempt. Anchor cases mirror
# Lib/test/test_baseexception.py UsageTests.catch_fails.
#
# Pins (guest source driven through product_exec + exec_code):
#   1. except BaseException()  -> TypeError (instance targets are invalid;
#      this was BROKEN before the fix -- exception_matches returned False and
#     the inner exception escaped into unrelated handlers).
#   2. except (BaseException(),) -> TypeError (invalid member inside tuple).
#   3. except NotAnException -> TypeError (guest class without a
#      BaseException ancestor; test_catch_non_BaseException shape).
#   4. except 'spam' -> TypeError (string target; test_catch_string shape).
#   5. Control: except BaseException still matches a raised Exception.

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


test "except instance of BaseException raises TypeError" {
    # Host oracle: catch_fails(BaseException()) sees TypeError, not a match.
    assert _run_native(
        "r = 'no-error'\n"
        "try:\n"
        "    try:\n"
        "        raise Exception\n"
        "    except BaseException():\n"
        "        r = 'matched'\n"
        "except TypeError:\n"
        "    r = 'typeerror'\n"
    ) == "typeerror";
}

test "except tuple with instance member raises TypeError" {
    # Host oracle: check_except_type_valid recurses into tuples.
    assert _run_native(
        "r = 'no-error'\n"
        "try:\n"
        "    try:\n"
        "        raise Exception\n"
        "    except (ValueError, BaseException()):\n"
        "        r = 'matched'\n"
        "except TypeError:\n"
        "    r = 'typeerror'\n"
    ) == "typeerror";
}

test "except non-exception guest class raises TypeError" {
    # Host oracle: test_catch_non_BaseException shape.
    assert _run_native(
        "class NotAnException(object):\n"
        "    pass\n"
        "r = 'no-error'\n"
        "try:\n"
        "    try:\n"
        "        raise Exception\n"
        "    except NotAnException:\n"
        "        r = 'matched'\n"
        "except TypeError:\n"
        "    r = 'typeerror'\n"
    ) == "typeerror";
}

test "except string raises TypeError" {
    # Host oracle: test_catch_string shape.
    assert _run_native(
        "r = 'no-error'\n"
        "try:\n"
        "    try:\n"
        "        raise Exception\n"
        "    except 'spam':\n"
        "        r = 'matched'\n"
        "except TypeError:\n"
        "    r = 'typeerror'\n"
    ) == "typeerror";
}

test "valid exception class target still matches" {
    # Host oracle: control -- normal matching is untouched by validation.
    assert _run_native(
        "r = 'missed'\n"
        "try:\n"
        "    raise Exception\n"
        "except BaseException:\n"
        "    r = 'caught'\n"
    ) == "caught";
}
