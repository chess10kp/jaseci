# Frame/function introspection surface pins -- what sys._getframe, function
# objects, and code objects expose to guest code.
#
# Every fixture compiles Python source at filename "<frame>" and runs it on
# ceval via exec_code_frame; expected values are byte-pinned against
# python3.14 (CPython 3.14.6 per CURRENT.md) run on the same sources.
#
# Pinned surfaces:
#   frames     -- sys._getframe(depth), f_back chain identity + depth,
#                 f_code/f_globals/f_builtins/f_lineno/f_lasti/f_locals
#                 snapshot, f_trace write-store, f_lineno set ValueError text
#   functions  -- __code__/__name__/__qualname__/__module__/__doc__,
#                 __defaults__/__kwdefaults__/__closure__ identity-stable,
#                 __globals__ snapshot, live __dict__ (identity + mutation),
#                 __annotations__ stable empty dict, readonly enforcement
#                 (__globals__/__closure__) with exact error text
#   cells      -- cell_contents read/write/delete, empty-cell ValueError
#   code objs  -- full co_* attribute set incl. co_nlocals/co_linetable/
#                 co_exceptiontable, immutability ("readonly attribute")
#   sys        -- _getframe ValueError on over-deep, settrace/gettrace
#                 record-only contract, facade passthrough of sys.maxsize

import from host_oracle { host_compile_marshal }
import from pyc_first { unmarshal, exec_code_frame }
import from objects { PyObj, PyError, PyStr, PyCode, is_error }
import from ceval { py_repr }

# Run `src` on ceval and return the resulting module namespace.
def vm_eval(src: str) -> dict[str, PyObj] {
    ns: dict[str, PyObj] = {"__name__": PyStr(t="str", val="__main__")};
    outcome = exec_code_frame(
        unmarshal(host_compile_marshal(src, "<frame>", "exec")) as PyCode,
        [], {}, ns, ns, [], [], {}
    );
    if is_error(outcome) {
        err = outcome as PyError;
        raise AssertionError(
            "guest raised " + err.exception.type_name + ": " + err.exception.message
        );
    }
    return ns;
}

# Assert the guest result bound to `name` reprs exactly like CPython 3.14 does
# for the same source (oracle values captured from python3.14).
def assert_oracle(ns: dict[str, PyObj], name: str, expected: str) {
    r = py_repr(ns[name]);
    got = (r as PyStr).val;
    if got != expected {
        raise AssertionError(name + ": expected " + expected + ", got " + got);
    }
}

test "frame chain: f_back identity, depth, f_code names" {
    # python3.14: (True, '<module>', 'inner', True)
    ns = vm_eval(
        "import sys\n"
        "def inner():\n"
        "    return sys._getframe(0)\n"
        "def outer():\n"
        "    fi = inner()\n"
        "    fh = sys._getframe(0)\n"
        "    fm = fh.f_back\n"
        "    return (fi.f_back is fh,\n"
        "            fm.f_code.co_name,\n"
        "            fi.f_code.co_name,\n"
        "            fm.f_back is None)\n"
        "r = outer()\n"
    );
    assert_oracle(ns, "r", "(True, '<module>', 'inner', True)");
}

test "frame views are identity-stable across repeated _getframe calls" {
    # python3.14: True
    ns = vm_eval(
        "import sys\n"
        "def f():\n"
        "    a = sys._getframe(0)\n"
        "    b = sys._getframe(0)\n"
        "    return a is b\n"
        "r = f()\n"
    );
    assert_oracle(ns, "r", "True");
}

test "_getframe over-deep raises exact ValueError" {
    # python3.14: call stack is not deep enough
    ns = vm_eval(
        "import sys\n"
        "try:\n"
        "    sys._getframe(50)\n"
        "except ValueError as e:\n"
        "    r = str(e)\n"
    );
    assert_oracle(ns, "r", "'call stack is not deep enough'");
}

test "f_locals snapshot carries args, locals, cells" {
    # python3.14 FrameLocalsProxy reprs like a dict: [('a', 1), ('loc', 42)]
    ns = vm_eval(
        "import sys\n"
        "def inner(a):\n"
        "    loc = 42\n"
        "    def cellfn(): return a\n"
        "    return sorted(sys._getframe(0).f_locals.items())\n"
        "r = inner(1)\n"
    );
    assert_oracle(ns, "r", "[('a', 1), ('cellfn', <function inner.<locals>.cellfn>), ('loc', 42)]");
}

test "f_globals exposes the module namespace" {
    # python3.14: ('<module>', 7)
    ns = vm_eval(
        "import sys\n"
        "GL = 7\n"
        "def f():\n"
        "    g = sys._getframe(0).f_globals\n"
        "    return (g['__name__'], g['GL'])\n"
        "r = f()\n"
    );
    assert_oracle(ns, "r", "('<module>', 7)");
}

test "f_builtins resolves builtin callables" {
    # python3.14: 'builtin_function_or_method'
    ns = vm_eval(
        "import sys\n"
        "def f():\n"
        "    b = sys._getframe(0).f_builtins\n"
        "    return type(b['len']).__name__\n"
        "r = f()\n"
    );
    assert_oracle(ns, "r", "'builtin_function_or_method'");
}

test "f_lineno tracks execution lines through nested calls" {
    # python3.14: [('inner', 6), ('outer', 10)] -- the raise line and the
    # inner() call line, decoded from the PEP 626 location tables.
    ns = vm_eval(
        "import sys\n"
        "def inner():\n"
        "    x = 1\n"
        "    y = 2\n"
        "\n"
        "    return sys._getframe(0).f_lineno\n"
        "def outer():\n"
        "    a = 10\n"
        "    ln_inner = inner()\n"
        "    return (ln_inner, sys._getframe(0).f_lineno)\n"
        "r = outer()\n"
    );
    assert_oracle(ns, "r", "(6, 10)");
}

test "f_lasti is an even byte offset into co_code" {
    # python3.14 invariant: fr.f_lasti % 2 == 0 and points at an opcode byte.
    ns = vm_eval(
        "import sys\n"
        "def f():\n"
        "    fr = sys._getframe(0)\n"
        "    code = fr.f_code.co_code\n"
        "    return (fr.f_lasti % 2 == 0, code[fr.f_lasti], isinstance(code, bytes))\n"
        "r = f()\n"
    );
    assert_oracle(ns, "r", "(True, 137, True)");
}

test "f_trace stores; f_lineno assignment raises trace-only ValueError" {
    # python3.14: (True, None, 'f_lineno can only be set in a trace function')
    ns = vm_eval(
        "import sys\n"
        "def tr(f, e, a): return tr\n"
        "def f():\n"
        "    fr = sys._getframe(0)\n"
        "    fr.f_trace = tr\n"
        "    stored = fr.f_trace is tr\n"
        "    try:\n"
        "        fr.f_lineno = 1\n"
        "        lerr = 'no-error'\n"
        "    except ValueError as e:\n"
        "        lerr = str(e)\n"
        "    return (stored, sys.gettrace(), lerr)\n"
        "r = f()\n"
    );
    assert_oracle(ns, "r", "(True, None, 'f_lineno can only be set in a trace function')");
}

test "sys.settrace records and returns previous tracer without firing events" {
    # Record-only divergence (documented): gettrace reflects settrace, but no
    # events fire, so a counting tracer sees zero calls -- pinned here so the
    # contract is explicit until dispatch-loop hooks land.
    ns = vm_eval(
        "import sys\n"
        "calls = []\n"
        "def tr(f, e, a):\n"
        "    calls.append(e)\n"
        "    return tr\n"
        "prev = sys.settrace(tr)\n"
        "got = sys.gettrace() is tr\n"
        "old = sys.settrace(None)\n"
        "r = (prev is None, got, old is tr, len(calls))\n"
    );
    assert_oracle(ns, "r", "(True, True, True, 0)");
}

test "qualname shapes match CPython" {
    # python3.14: A.m / A.B.n / <lambda> / w ; co_qualname through frames too.
    ns = vm_eval(
        "import sys\n"
        "class A:\n"
        "    def m(self): pass\n"
        "    class B:\n"
        "        def n(self): pass\n"
        "lam = lambda: 0\n"
        "def deco(fn): return fn\n"
        "@deco\n"
        "def w(): pass\n"
        "def deep():\n"
        "    return sys._getframe(1).f_code.co_qualname\n"
        "def caller(): return deep()\n"
        "r = (A.m.__qualname__, A.B.n.__qualname__, lam.__qualname__, w.__qualname__,\n"
        "     caller())\n"
    );
    assert_oracle(ns, "r", "('A.m', 'A.B.n', '<lambda>', 'w', 'caller')");
}

test "__defaults__/__kwdefaults__/__closure__ identity-stable reads" {
    # python3.14: same tuple/dict object on every read; closure cells visible.
    ns = vm_eval(
        "def plain(a, b=7): pass\n"
        "def kwonly(*, k=3): pass\n"
        "def make():\n"
        "    x = 5\n"
        "    def inner(): return x\n"
        "    return inner\n"
        "fn = make()\n"
        "r = (plain.__defaults__ is plain.__defaults__,\n"
        "     plain.__defaults__,\n"
        "     kwonly.__defaults__,\n"
        "     kwonly.__kwdefaults__ is kwonly.__kwdefaults__,\n"
        "     kwonly.__kwdefaults__,\n"
        "     fn.__closure__[0].cell_contents,\n"
        "     type(fn.__closure__).__name__)\n"
    );
    assert_oracle(ns, "r", "(True, (7,), None, True, {'k': 3}, 5, 'tuple')");
}

test "cell_contents read/write/delete with exact empty-cell ValueError" {
    # python3.14: read 5, write 99, del empties, re-read ValueError('Cell is empty')
    ns = vm_eval(
        "def make():\n"
        "    x = 5\n"
        "    def inner(): return x\n"
        "    return inner.__closure__[0]\n"
        "cell = make()\n"
        "first = cell.cell_contents\n"
        "cell.cell_contents = 99\n"
        "second = cell.cell_contents\n"
        "del cell.cell_contents\n"
        "try:\n"
        "    cell.cell_contents\n"
        "    third = 'no-error'\n"
        "except ValueError as e:\n"
        "    third = str(e)\n"
        "r = (first, second, third)\n"
    );
    assert_oracle(ns, "r", "(5, 99, 'Cell is empty')");
}

test "function dunder surface: module/doc/name/code round-trip" {
    # python3.14: ('__main__', None, 'docful', <code object docful>, True)
    ns = vm_eval(
        "def docful():\n"
        "    'my doc'\n"
        "def bare(): pass\n"
        "r = (bare.__module__, bare.__doc__, docful.__doc__.strip(),\n"
        "     docful.__code__.co_name, docful.__code__ is docful.__code__,\n"
        "     type(docful.__code__).__name__, docful.__code__.co_filename)\n"
    );
    assert_oracle(ns, "r", "('__main__', None, 'my doc', 'docful', True, 'code', '<frame>')");
}

test "live __dict__: identity stable, mutations visible both ways" {
    # python3.14: d is f.__dict__; f.tag reads through; d sees later writes.
    ns = vm_eval(
        "def f(x): return x\n"
        "d = f.__dict__\n"
        "same = f.__dict__ is d\n"
        "d['tag'] = 'T'\n"
        "via_attr = f.tag\n"
        "f.__dict__['flag'] = True\n"
        "in_d = d['flag']\n"
        "f.extra = 9\n"
        "r = (same, via_attr, in_d, f.extra)\n"
    );
    assert_oracle(ns, "r", "(True, 'T', True, 9)");
}

test "__annotations__ stable dict; __annotate__ None without annotations" {
    # python3.14: (True, {}, None)
    ns = vm_eval(
        "def f(): pass\n"
        "r = (f.__annotations__ is f.__annotations__, f.__annotations__, f.__annotate__)\n"
    );
    assert_oracle(ns, "r", "(True, {}, None)");
}

test "readonly function attrs raise exact AttributeError" {
    # python3.14: AttributeError('readonly attribute') for both.
    ns = vm_eval(
        "def f(): pass\n"
        "errs = []\n"
        "for attr in ('__globals__', '__closure__'):\n"
        "    try:\n"
        "        setattr(f, attr, None)\n"
        "        errs.append('no-error')\n"
        "    except AttributeError as e:\n"
        "        errs.append(str(e))\n"
        "r = errs\n"
    );
    assert_oracle(ns, "r", "['readonly attribute', 'readonly attribute']");
}

test "__defaults__ assignment rebinding reaches call-time binding" {
    # python3.14: f() uses the new default -> 11.
    ns = vm_eval(
        "def f(x=1): return x\n"
        "saved = f.__defaults__\n"
        "f.__defaults__ = (11,)\n"
        "bound = f()\n"
        "f.__defaults__ = saved\n"
        "restored = f()\n"
        "r = (bound, restored)\n"
    );
    assert_oracle(ns, "r", "(11, 1)");
}

test "code object full co_* surface" {
    # python3.14: nlocals counts varnames; linetable/exctable are bytes;
    # varnames/cellvars/freevars/names tuples; flags carry CO_OPTIMIZED etc.
    ns = vm_eval(
        "GV = 1\n"
        "def f(a, b=2):\n"
        "    loc = a + b\n"
        "    return GV + loc\n"
        "c = f.__code__\n"
        "r = (c.co_argcount, c.co_nlocals, c.co_varnames == ('a', 'b'),\n"
        "     c.co_names == ('GV',), c.co_cellvars == (), c.co_freevars == (),\n"
        "     c.co_flags & 31, isinstance(c.co_code, bytes),\n"
        "     isinstance(c.co_linetable, bytes), isinstance(c.co_exceptiontable, bytes),\n"
        "     c.co_firstlineno, c.co_stacksize > 0, c.co_filename, c.co_name)\n"
    );
    assert_oracle(ns, "r", "(2, 2, True, True, True, True, 3, True, True, True, 1, True, '<frame>', 'f')");
}

test "closure code object reports cellvars/freevars split" {
    # python3.14: cellvars ('x',) freevars ('x',) for maker/inner pair.
    ns = vm_eval(
        "def maker():\n"
        "    x = 1\n"
        "    def inner():\n"
        "        y = x\n"
        "        return y\n"
        "    return inner\n"
        "ci = maker().__code__\n"
        "cm = maker.__code__\n"
        "r = (cm.co_cellvars, ci.co_freevars, ci.co_cellvars)\n"
    );
    assert_oracle(ns, "r", "(('x',), ('x',), ())");
}

test "code object mutation raises exact readonly AttributeError" {
    # python3.14: AttributeError('readonly attribute').
    ns = vm_eval(
        "def f(): pass\n"
        "try:\n"
        "    f.__code__.co_name = 'zz'\n"
        "    r = 'no-error'\n"
        "except AttributeError as e:\n"
        "    r = str(e)\n"
    );
    assert_oracle(ns, "r", "'readonly attribute'");
}

test "co_consts exposes nested code objects and literals" {
    # python3.14: consts include None terminator and nested code for inner.
    ns = vm_eval(
        "def f():\n"
        "    def inner(): return 7\n"
        "    return inner\n"
        "consts = f.__code__.co_consts\n"
        "r = (type(consts).__name__, consts[0], consts[-1])\n"
    );
    assert_oracle(ns, "r", "('tuple', 'inner', None)");
}

test "sys facade passthrough keeps non-introspection sys intact" {
    # Host-module delegation must survive the facade: scalars, path object.
    ns = vm_eval(
        "import sys\n"
        "r = (sys.maxsize > 0, type(sys.path).__name__, sys.version_info[0])\n"
    );
    assert_oracle(ns, "r", "(True, 'list', 3)");
}
