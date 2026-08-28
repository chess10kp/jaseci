# Guest-metaclass boot pins: native _abc subclasscheck during abc/enum/typing import.
#
# Regression: host C _abc could not traverse guest PyClass MROs once Lib/abc.py
# booted in-VM, breaking ``import typing`` and enum's IntFlag extends Flag gate
# with ``<enum 'IntFlag'> cannot extend <class 'ceval.Flag'>``.

import from objects { PyError, is_error }
import from pyc_first {
    PyObj,
    PyStr,
    exec_code,
    unmarshal,
    host_compile_marshal,
    set_layer3_active,
    clear_sys3_modules,
    to_host,
}

def _boot_reset() {
    clear_sys3_modules();
    set_layer3_active(True);
}

def _boot_run(source: str) -> dict[str, PyObj] {
    _boot_reset();
    g: dict[str, PyObj] = {"__name__": PyStr(t="str", val="m")};
    outcome = exec_code(unmarshal(host_compile_marshal(source)), [], g);
    assert not is_error(outcome), _boot_err(outcome);
    return g;
}

def _boot_err(outcome: PyObj) -> str {
    if isinstance(outcome, PyError) {
        exc = (outcome as PyError).exception;
        return exc.type_name + ": " + exc.message;
    }
    return "non-error failure";
}

test "abc boot pins: guest abc imports native _abc surface" {
    g = _boot_run(
        "import _abc\n"
        "ok = hasattr(_abc, '_abc_subclasscheck') and hasattr(_abc, '_abc_init')\n"
    );
    assert to_host(g["ok"]) == True;
}

test "abc boot pins: import abc after native _abc shim" {
    g = _boot_run(
        "import abc\n"
        "ok = hasattr(abc, 'ABCMeta') and hasattr(abc.ABCMeta, '__subclasscheck__')\n"
    );
    assert to_host(g["ok"]) == True;
}

test "abc boot pins: import enum reaches IntFlag" {
    g = _boot_run(
        "import enum\n"
        "ok = enum.IntFlag is not None and enum.Flag is not None\n"
    );
    assert to_host(g["ok"]) == True;
}

test "abc boot pins: import typing after guest abc boot" {
    g = _boot_run("import typing\nok = hasattr(typing, 'Generic')\n");
    assert to_host(g["ok"]) == True;
}
