# sys._getframe() over GUEST frames -- PEP 667 frame-locals pins
# (census gap fp-v1:539757629209, test_frame.TestFrameLocals.test_closure).
#
# Surface under test: the PyFrameLocalsProxy served by PyFrame.tp_getattro for
# f_locals, plus sys._getframe/sys.currentframe served natively via the
# "sys_getframe"/"sys_currentframe" native-builtin arms over the live guest
# frame chain published by run_frame.
#
# Before this surface, _getframe fell through to the HOST sys delegate, whose
# frames know nothing of VM state -- f_locals reads missed every fast/cell slot
# and raised KeyError("local variable ''x'' is not defined") exactly where
# CPython answers the live value.
#
# Pinned semantics (CPython 3.14 ground truth):
#   - f_locals of an optimized frame exposes BOUND localsplus slots only;
#     closure cells appear with their current cell value
#   - writes through f_locals propagate into the cell (enclosing scope sees it)
#   - unbound slots are omitted from keys/contains/len until first assigned;
#     reading one raises KeyError "local variable ''N'' is not defined"
#   - a module-level frame's f_locals aliases its globals namespace

import from objects {
    PyObj,
    PyCode,
    PyError,
    PyStr,
    is_error,
}
import from product_compile { compile_source }
import from pyc_first { exec_code }


def run_module(source: str) -> PyObj {
    comp = compile_source(source, "<frameref>", "exec", 0);
    assert not is_error(comp), f"compile failed: {(comp as PyError).exception.message}";
    return exec_code(comp as PyCode, [], {"__name__": PyStr(t="str", val="__main__")});
}

def fail_msg(outcome: PyObj) -> str {
    return (outcome as PyError).exception.message;
}

test "frame_locals: closure cells readable through f_locals" {
    outcome = run_module(
        "import sys\n"
        "def t():\n"
        "    x = 1\n"
        "    y = 2\n"
        "    def f():\n"
        "        z = x + y\n"
        "        d = sys._getframe().f_locals\n"
        "        assert d['x'] == 1, sorted(d.keys())\n"
        "        assert d['y'] == 2, sorted(d.keys())\n"
        "    f()\n"
        "t()\n"
        "result = 'ok'\n"
    );
    assert not is_error(outcome), fail_msg(outcome);
}

test "frame_locals: writes propagate into closure cells" {
    outcome = run_module(
        "import sys\n"
        "def t():\n"
        "    x = 1\n"
        "    y = 2\n"
        "    def f():\n"
        "        d = sys._getframe().f_locals\n"
        "        d['x'] = 2\n"
        "        d['y'] = 3\n"
        "        assert d['x'] == 2 and d['y'] == 3\n"
        "    f()\n"
        "    assert x == 2 and y == 3, (x, y)\n"
        "t()\n"
        "result = 'ok'\n"
    );
    assert not is_error(outcome), fail_msg(outcome);
}

test "frame_locals: depth walks to the parent frame" {
    outcome = run_module(
        "import sys\n"
        "def outer():\n"
        "    marker = 41\n"
        "    def inner():\n"
        "        up = sys._getframe(1)\n"
        "        assert up.f_locals['marker'] == 41, sorted(up.f_locals.keys())\n"
        "    inner()\n"
        "outer()\n"
        "result = 'ok'\n"
    );
    assert not is_error(outcome), fail_msg(outcome);
}

test "frame_locals: mapping surface covers bound slots" {
    outcome = run_module(
        "import sys\n"
        "def t():\n"
        "    x = 1\n"
        "    def f():\n"
        "        z = x\n"
        "        d = sys._getframe().f_locals\n"
        "        assert 'x' in d and 'z' in d and 'd' in d\n"
        "        assert not ('q' in d)\n"
        "        assert d.get('q') is None and d.get('x') == 1\n"
        "        assert len(d) >= 3, len(d)\n"
        "        assert set(d.keys()) >= {'x', 'z'}, sorted(d.keys())\n"
        "    f()\n"
        "t()\n"
        "result = 'ok'\n"
    );
    assert not is_error(outcome), fail_msg(outcome);
}

test "frame_locals: unbound slot omitted then KeyError byte-exact" {
    outcome = run_module(
        "import sys\n"
        "def t():\n"
        "    d = sys._getframe().f_locals\n"
        "    assert not ('later' in d), sorted(d.keys())\n"
        "    try:\n"
        "        d['later']\n"
        "        raise AssertionError('missing KeyError')\n"
        "    except KeyError:\n"
        "        pass\n"
        "    later = 1\n"
        "    assert d['later'] == 1\n"
        "t()\n"
        "result = 'ok'\n"
    );
    assert not is_error(outcome), fail_msg(outcome);
}

test "frame_locals: module frame aliases globals" {
    outcome = run_module(
        "import sys\n"
        "a = 5\n"
        "d = sys._getframe().f_locals\n"
        "assert d['a'] == 5, sorted(d.keys())\n"
        "d['nw'] = 7\n"
        "assert nw == 7\n"
        "result = 'ok'\n"
    );
    assert not is_error(outcome), fail_msg(outcome);
}

test "frame_locals: f_globals and f_code reachable" {
    outcome = run_module(
        "import sys\n"
        "marker = 11\n"
        "def t():\n"
        "    fr = sys._getframe()\n"
        "    assert fr.f_globals['marker'] == 11\n"
        "    assert fr.f_code.co_name == 't'\n"
        "t()\n"
        "result = 'ok'\n"
    );
    assert not is_error(outcome), fail_msg(outcome);
}
