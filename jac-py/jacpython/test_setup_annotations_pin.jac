# Census fp-v1:8e23f488 pins: SETUP_ANNOTATIONS (opcode 36) dispatch arm.
#
# The census fingerprint 'SystemError: unsupported opcode 36' spanned 26 suites
# (test_fstring, test_logging, test_scope, test_typing, test_super, ...): any
# marshal payload compiled by CPython <= 3.13 carries opcode 36 at module or
# class scope for annotated statements, and ceval had no dispatch arm, so the
# frame aborted with SystemError before any test logic ran. Fixed by the
# SETUP_ANNOTATIONS arm in run_frame_inner; these pins lock it in. The host
# 3.14 compiler never emits opcode 36 (PEP 649 defers annotations into
# __annotate__), so -- like the o91 pins -- the arm is driven via a
# hand-assembled code object marshaled from the host.
#
# Host oracle (CPython 3.14.7 exec of the same code object):
#   fresh namespace            -> r == {}
#   ns pre-seeded {'a': 1}     -> r == {'a': 1}   (arm must not clobber)
import from pyc_first { unmarshal, exec_code, to_host }
import from objects { PyObj, PyStr, PyInt, PyDict, PyError, is_error }
import marshal;
import types as pytypes;


def _run_setup_annotations(seed: bool) -> str {
    # Hand-assemble SETUP_ANNOTATIONS; LOAD_NAME __annotations__; STORE_NAME r;
    # LOAD_CONST None; RETURN_VALUE -- drives the arm end-to-end through the VM.
    co_host = pytypes.CodeType(
        0,
        0,
        0,
        0,
        3,
        64,
        bytes([36, 0, 93, 0, 116, 1, 82, 0, 35, 0]),
        (None,),
        ("__annotations__", "r"),
        (),
        "<setup_ann>",
        "<setup_ann>",
        "<setup_ann>",
        1,
        b"",
        b"",
        (),
        ()
    );
    co = unmarshal(marshal.dumps(co_host) as list[int]);
    ns: dict[str, PyObj] = {"__name__": PyStr(t="str", val="__main__")};
    if seed {
        seeded: dict[str, PyObj] = {};
        seeded["a"] = PyInt(t="int", val=1);
        ns["__annotations__"] = PyDict(t="dict", items=seeded);
    }
    out = exec_code(co, [], ns);
    if is_error(out) {
        e = out as PyError;
        return str(e.exception.type_name) + ": " + str(e.exception.message);
    }
    if "r" in ns {
        return repr(to_host(ns["r"]));
    }
    return "";
}

test "setup-annotations hand-assembled: binds empty __annotations__" {
    assert _run_setup_annotations(False) == "{}";
}

test "setup-annotations hand-assembled: pre-seeded mapping survives" {
    assert _run_setup_annotations(True) == "{'a': 1}";
}
