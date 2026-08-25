# Except-target validation pins (fix/gap-e87cd28cf35e).
#
# CPython's CHECK_EXC_MATCH validates the target BEFORE any matching
# (_PyEval_CheckExceptTypeValid): every plain-except target must be an
# exception class (bare or tuple member). Anything else -- a plain class,
# a plain-class instance, a string, even a BaseException instance on 3.14 --
# raises TypeError "catching classes that do not inherit from BaseException
# is not allowed" instead of silently not matching. Mirrors CPython Lib/test
# test_baseexception.py UsageTests.catch_fails / test_catch_non_BaseException.
import from layer_p2_libtest { p2_libtest_run_snippet }

def expect_ok(name: str, src: str) {
    (ok, detail) = p2_libtest_run_snippet(src);
    assert ok , name + " RUN<" + detail + ">";
    assert detail == "ok" , name + " GOT<" + detail + ">";
}

def catch_fails_snippet(targets_src: str, prelude: str = "") -> str {
    # Shared oracle body: each target must surface TypeError from both the
    # bare and tuple forms, never route the raised Exception into a silent
    # non-match or an AssertionError fallthrough.
    return (
        prelude
        + "def _t():\n"
        "    for target in [" + targets_src + "]:\n"
        "        caught_type_error = False\n"
        "        try:\n"
        "            try:\n"
        "                raise Exception\n"
        "            except target:\n"
        "                pass\n"
        "        except TypeError:\n"
        "            caught_type_error = True\n"
        "        if not caught_type_error:\n"
        "            raise AssertionError('TypeError expected when catching %s' % type(target))\n"
        "        caught_type_error = False\n"
        "        try:\n"
        "            try:\n"
        "                raise Exception\n"
        "            except (target,):\n"
        "                pass\n"
        "        except TypeError:\n"
        "            caught_type_error = True\n"
        "        if not caught_type_error:\n"
        "            raise AssertionError('TypeError expected when catching %s in a tuple' % type(target))\n"
        "try:\n"
        "    _t()\n"
        "except BaseException as _e:\n"
        "    print('ORACLE_EXC ' + type(_e).__name__ + ' ' + repr(str(_e)))\n"
        "else:\n"
        "    print('ok')\n"
    );
}

test "except_target: non-BaseException class and instance" {
    expect_ok(
        "catch_non_baseexception",
        catch_fails_snippet(
            "NonBaseException, NonBaseException()",
            "class NonBaseException(object):\n    pass\n"
        )
    );
}

test "except_target: string and int targets" {
    expect_ok("catch_string_int", catch_fails_snippet("'spam', 42"));
}

test "except_target: BaseException instance target is TypeError on 3.14" {
    expect_ok("catch_baseexception_instance", catch_fails_snippet("BaseException()"));
}

test "except_target: valid targets still match normally" {
    expect_ok(
        "sanity_valid_targets",
        "def _t():\n"
        "    got = ''\n"
        "    try:\n"
        "        raise ValueError('boom')\n"
        "    except (TypeError, ValueError) as e:\n"
        "        got = type(e).__name__ + ':' + str(e)\n"
        "    try:\n"
        "        class MyErr(KeyError):\n"
        "            pass\n"
        "        raise MyErr('k')\n"
        "    except LookupError as e2:\n"
        "        got += ' sub:' + type(e2).__name__\n"
        "    assert got == 'ValueError:boom sub:MyErr', got\n"
        "try:\n"
        "    _t()\n"
        "except BaseException as _e:\n"
        "    print('ORACLE_EXC ' + type(_e).__name__ + ' ' + repr(str(_e)))\n"
        "else:\n"
        "    print('ok')\n"
    );
}
