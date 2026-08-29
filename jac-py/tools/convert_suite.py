#!/usr/bin/env python3
"""D2 mechanical test-conversion pipeline: CPython Lib/test file -> .jac pins.

For every ``test_*`` method in a CPython ``Lib/test`` file this tool:

1. Extracts the method via AST and mechanically rewrites the common
   ``unittest`` assertion vocabulary (``assertEqual``, ``assertRaises``, ...)
   into plain asserts/try-except. ``setUp`` bodies are spliced ahead of each
   test (fixture vocabulary), and plain ``self.<attr>`` loads/stores are
   satisfied by binding ``self`` to a bare namespace object; anything outside
   the supported vocabulary (other ``self.*`` attributes, unresolved names,
   skip machinery, decorators) is quarantined with a reason instead of
   silently mistranslating.
2. Captures the HOST ORACLE first: each rewritten snippet runs under host
   CPython in a sandboxed subprocess (fresh cwd, minimal env, hard timeout).
   A snippet is only pinnable when the host prints the success marker;
   host-failing/host-timing-out snippets carry no usable oracle.
3. Emits a ``.jac`` pin file following the repo parity convention
   (``test "..." { ... }`` blocks calling ``layer_p2_libtest.p2_libtest_run_snippet``
   so every snippet executes on jacpython's ceval, never the host).
4. Writes a ``<name>.conv.json`` sidecar (per-test status, oracle, quarantine
   reasons) and registers the module in the conformance manifest consumed by
   ``conformance_dashboard.py``.

Usage:
    .venv/bin/python jac-py/tools/convert_suite.py \\
        reference/cpython/Lib/test/test_copy.py [-o OUTDIR] [--name conv_copy]

Package-style suites (``Lib/test/test_string/``, ``test_doctest/``, ...)
are directories: pass the INNER ``test_*.py`` file path explicitly and
disambiguate the output with ``--name`` (an inner file's stem can match
other suites), e.g.::

    .venv/bin/python jac-py/tools/convert_suite.py \\
        reference/cpython/Lib/test/test_string/test_string.py \\
        --name conv_string
"""
from __future__ import annotations

import argparse
import ast
import builtins
import copy
import doctest
import json
import os
import subprocess
import sys
import tempfile
import textwrap
from dataclasses import dataclass, field
from pathlib import Path

_HERE = Path(__file__).resolve().parent
_REPO = _HERE.parent.parent
_DEFAULT_LIB = _REPO / "reference" / "cpython" / "Lib"
_TESTS_DIR = _REPO / "jac-py" / "tests"
_MANIFEST = _TESTS_DIR / "conformance_manifest_convpipe.json"

TOOL_VERSION = "conv_suite-0.6.0"
CPYTHON_VERSION = "3.14.6"


def attempt_header(command: list[str]) -> dict:
    """Build-contract fingerprint block shared by every emitted artifact."""
    import hashlib
    import subprocess as sp

    def _git(args: list[str], cwd: Path) -> str:
        try:
            return sp.run(["git"] + args, cwd=str(cwd), capture_output=True,
                          text=True, timeout=10).stdout.strip()
        except Exception:
            return "unknown"

    jac_exe = _REPO / ".venv" / "bin" / "jac"
    jac_sha = "unknown"
    if jac_exe.is_file():
        jac_sha = _git(["rev-parse", "HEAD"], _REPO)
    cpython_sha = _git(["rev-parse", "HEAD"], _REPO / "reference" / "cpython")
    hashes = {}
    for label, p in (("jac_source", _REPO / "jac"),):
        pass  # source-tree hash too costly per attempt; sha fields carry provenance
    return {
        "schema_version": 1,
        "tool_version": TOOL_VERSION,
        "jac_sha": jac_sha,
        "cpython": {"version": CPYTHON_VERSION, "sha": cpython_sha},
        "command": command,
        "generated_at": __import__("datetime").datetime.now().isoformat(timespec="seconds"),
        "hashes": hashes,
    }


def file_sha256(path: Path) -> str:
    import hashlib
    h = hashlib.sha256()
    h.update(path.read_bytes())
    return h.hexdigest()

HOST_TIMEOUT = 60  # seconds, hard limit per oracle capture

_ORACLE_OK = "ok"
_ORACLE_EXC = "ORACLE_EXC "

@dataclass
class Quarantined:
    ident: str
    reason: str


@dataclass
class Pinned:
    ident: str
    snippet: str
    oracle: dict  # {"status": "ok"} after the host pass


@dataclass
class Extraction:
    pinned: list[Pinned] = field(default_factory=list)
    quarantined: list[Quarantined] = field(default_factory=list)


class Unsupported(Exception):
    """Raised during rewrite when a construct has no mechanical mapping."""


# ---------------------------------------------------------------------------
# Assertion rewriting (AST -> AST)


def _call_name(node: ast.expr) -> str | None:
    if (
        isinstance(node, ast.Attribute)
        and isinstance(node.value, ast.Name)
        and node.value.id == "self"
    ):
        return node.attr
    return None


def _msg_of(call: ast.Call, label: str, operands: list[ast.expr]) -> ast.expr:
    parts: list[ast.expr] = [ast.Constant(value=label)]
    parts.extend(operands)
    extra = None
    for kw in call.keywords:
        if kw.arg == "msg":
            extra = kw.value
    if extra is not None:
        parts.append(extra)
    return ast.Tuple(elts=parts, ctx=ast.Load())


def _binary_assert(
    call: ast.Call, label: str, op: type[ast.cmpop]
) -> ast.Assert:
    _need_args(call, 2)
    a, b = call.args[0], call.args[1]
    return ast.Assert(
        test=ast.Compare(left=a, ops=[op()], comparators=[b]),
        msg=_msg_of(call, label, [a, b]),
    )


def _unary_assert(call: ast.Call, negate: bool) -> ast.Assert:
    _need_args(call, 1)
    x = call.args[0]
    test: ast.expr = x
    if negate:
        test = ast.UnaryOp(op=ast.Not(), operand=x)
    return ast.Assert(test=test, msg=_msg_of(call, "assertFalse" if negate else "assertTrue", [x]))


def _isinstance_assert(call: ast.Call, negate: bool) -> ast.Assert:
    _need_args(call, 2)
    a, b = call.args[0], call.args[1]
    test: ast.expr = ast.Call(
        func=ast.Name(id="isinstance", ctx=ast.Load()), args=[a, b], keywords=[]
    )
    if negate:
        test = ast.UnaryOp(op=ast.Not(), operand=test)
    return ast.Assert(test=test, msg=_msg_of(call, "assertIsInstance", [a, b]))


def _almost_assert(call: ast.Call, negate: bool) -> ast.Assert:
    _need_args(call, 2)
    a, b = call.args[0], call.args[1]
    places: ast.expr = ast.Constant(value=7)
    if len(call.args) >= 3:
        places = call.args[2]
    for kw in call.keywords:
        if kw.arg == "places":
            places = kw.value
    delta = ast.BinOp(left=a, op=ast.Sub(), right=b)
    test: ast.expr = ast.Compare(
        left=ast.Call(
            func=ast.Name(id="round", ctx=ast.Load()), args=[delta, places], keywords=[]
        ),
        ops=[ast.NotEq() if negate else ast.Eq()],
        comparators=[ast.Constant(value=0)],
    )
    label = "assertNotAlmostEqual" if negate else "assertAlmostEqual"
    return ast.Assert(test=test, msg=_msg_of(call, label, [a, b]))


def _issubclass_assert(call: ast.Call, negate: bool) -> ast.Assert:
    _need_args(call, 2)
    a, b = call.args[0], call.args[1]
    test: ast.expr = ast.Call(
        func=ast.Name(id="issubclass", ctx=ast.Load()), args=[a, b], keywords=[]
    )
    if negate:
        test = ast.UnaryOp(op=ast.Not(), operand=test)
    label = "assertNotIsSubclass" if negate else "assertIsSubclass"
    return ast.Assert(
        test=test,
        msg=_msg_of(call, label, [a, b]),
    )


def _hasattr_assert(call: ast.Call, negate: bool) -> ast.Assert:
    _need_args(call, 2)
    obj, attr = call.args[0], call.args[1]
    test: ast.expr = ast.Call(
        func=ast.Name(id="hasattr", ctx=ast.Load()), args=[obj, attr], keywords=[]
    )
    if negate:
        test = ast.UnaryOp(op=ast.Not(), operand=test)
    label = "assertNotHasAttr" if negate else "assertHasAttr"
    return ast.Assert(test=test, msg=_msg_of(call, label, [obj, attr]))


def _regex_assert(call: ast.Call, negate: bool) -> ast.Assert:
    # assertRegex(text, pattern): CPython searches pattern IN text.
    _need_args(call, 2)
    text, pattern = call.args[0], call.args[1]
    test: ast.expr = ast.Call(
        func=ast.Attribute(value=ast.Name(id="_re", ctx=ast.Load()), attr="search", ctx=ast.Load()),
        args=[pattern, text],
        keywords=[],
    )
    if negate:
        test = ast.UnaryOp(op=ast.Not(), operand=test)
    label = "assertNotRegex" if negate else "assertRegex"
    return ast.Assert(test=test, msg=_msg_of(call, label, [text, pattern]))


def _starts_ends_assert(call: ast.Call, negate: bool, *, ends: bool = False) -> ast.Assert:
    # assertStartsWith(s, prefix) / assertEndsWith(s, suffix): direct
    # str.startswith/str.endswith checks (both accept tuple arguments,
    # matching CPython 3.14 unittest semantics).
    _need_args(call, 2)
    s, affix = call.args[0], call.args[1]
    label = ("assertEndsWith" if ends else "assertStartsWith")
    method = "endswith" if ends else "startswith"
    test: ast.expr = ast.Call(
        func=ast.Attribute(value=s, attr=method, ctx=ast.Load()),
        args=[affix],
        keywords=[],
    )
    if negate:
        test = ast.UnaryOp(op=ast.Not(), operand=test)
    return ast.Assert(test=test, msg=_msg_of(call, label, [s, affix]))


def _count_equal_assert(call: ast.Call) -> ast.Assert:
    _need_args(call, 2)
    a, b = call.args[0], call.args[1]
    # sorted(a, key=repr) == sorted(b, key=repr): repr keys keep the compare
    # total for unorderable element types; no lambda so snippets stay trivial
    # for the guest VM.
    def _sorted(x: ast.expr) -> ast.expr:
        return ast.Call(
            func=ast.Name(id="sorted", ctx=ast.Load()),
            args=[x],
            keywords=[ast.keyword(arg="key", value=ast.Name(id="repr", ctx=ast.Load()))],
        )

    return ast.Assert(
        test=ast.Compare(
            left=_sorted(a), ops=[ast.Eq()], comparators=[_sorted(b)]
        ),
        msg=_msg_of(call, "assertCountEqual", [a, b]),
    )


def _need_args(call: ast.Call, n: int) -> None:
    if len(call.args) < n:
        raise Unsupported("too few operands")


_EQUALITY_ALIASES = {
    "assertEqual": ast.Eq,
    "assertEquals": ast.Eq,
    "assertNotEqual": ast.NotEq,
    "assertMultiLineEqual": ast.Eq,
    "assertListEqual": ast.Eq,
    "assertTupleEqual": ast.Eq,
    "assertDictEqual": ast.Eq,
    "assertSetEqual": ast.Eq,
    "assertFrozenSetEqual": ast.Eq,
}

_ORDER_ALIASES = {
    "assertLess": ast.Lt,
    "assertLessEqual": ast.LtE,
    "assertGreater": ast.Gt,
    "assertGreaterEqual": ast.GtE,
}


def rewrite_assert_stmt(stmt: ast.stmt) -> list[ast.stmt]:
    """Rewrite one statement; returns replacement statements.

    Raises Unsupported when there is no mechanical mapping.
    """
    if isinstance(stmt, ast.Assert):
        return [stmt]
    if isinstance(stmt, ast.Raise):
        # self.fail(...) -> raise AssertionError(...); any other raise is
        # already valid Python and passes through untouched.
        if isinstance(stmt.exc, ast.Call) and _call_name(stmt.exc.func) == "fail":
            msg = stmt.exc.args[0] if stmt.exc.args else ast.Constant(value="fail()")
            return [
                ast.Raise(exc=ast.Call(func=ast.Name(id="AssertionError", ctx=ast.Load()), args=[msg], keywords=[]), cause=None)
            ]
        return [stmt]
    if not isinstance(stmt, ast.Expr) or not isinstance(stmt.value, ast.Call):
        raise Unsupported(f"statement {type(stmt).__name__}")
    call = stmt.value
    fname = _call_name(call.func)
    if fname is None:
        raise Unsupported("non-self call statement")
    if fname == "fail":
        msg = call.args[0] if call.args else ast.Constant(value="fail()")
        return [
            ast.Raise(exc=ast.Call(func=ast.Name(id="AssertionError", ctx=ast.Load()), args=[msg], keywords=[]), cause=None)
        ]
    if fname == "skipTest":
        # unittest.TestCase.skipTest(msg) *is* ``raise unittest.SkipTest(msg)``;
        # rewriting keeps conditional guards (``if cond: self.skipTest(...)``)
        # faithful: the raise only fires when its guard is true, and a guard
        # that is false at runtime leaves the test body intact. Requires
        # ``import unittest`` in the source file (checked by _check_names).
        msg = call.args[0] if call.args else ast.Constant(value="")
        return [
            ast.Raise(
                exc=ast.Call(
                    func=ast.Attribute(
                        value=ast.Name(id="unittest", ctx=ast.Load()),
                        attr="SkipTest",
                        ctx=ast.Load(),
                    ),
                    args=[msg],
                    keywords=[],
                ),
                cause=None,
            )
        ]
    if fname in ("assertWarns", "assertWarnsRegex", "assertLogs", "assertNoLogs"):
        raise Unsupported(fname)
    if fname in ("assertRaises", "assertRaisesRegex"):
        return _rewrite_raises(call, regex=fname == "assertRaisesRegex")
    if fname in _EQUALITY_ALIASES:
        return [_binary_assert(call, fname, _EQUALITY_ALIASES[fname])]
    if fname in _ORDER_ALIASES:
        return [_binary_assert(call, fname, _ORDER_ALIASES[fname])]
    if fname == "assertTrue":
        return [_unary_assert(call, negate=False)]
    if fname == "assertFalse":
        return [_unary_assert(call, negate=True)]
    if fname == "assertIs":
        return [_binary_assert(call, fname, ast.Is)]
    if fname == "assertIsNot":
        return [_binary_assert(call, fname, ast.IsNot)]
    if fname == "assertIn":
        return [_binary_assert(call, fname, ast.In)]
    if fname == "assertNotIn":
        return [_binary_assert(call, fname, ast.NotIn)]
    if fname == "assertIsNone":
        return [_is_none_assert(call, negate=False)]
    if fname == "assertIsNotNone":
        return [_is_none_assert(call, True)]
    if fname == "assertIsInstance":
        return [_isinstance_assert(call, negate=False)]
    if fname in ("assertIsNotInstance", "assertNotIsInstance"):
        # assertNotIsInstance is the legacy spelling of assertIsNotInstance.
        return [_isinstance_assert(call, negate=True)]
    if fname == "assertAlmostEqual":
        return [_almost_assert(call, negate=False)]
    if fname == "assertNotAlmostEqual":
        return [_almost_assert(call, negate=True)]
    if fname == "assertCountEqual":
        return [_count_equal_assert(call)]
    if fname in ("assertIsSubclass", "assertNotIsSubclass"):
        return [_issubclass_assert(call, negate=(fname == "assertNotIsSubclass"))]
    if fname == "assertHasAttr":
        return [_hasattr_assert(call, negate=False)]
    if fname == "assertNotHasAttr":
        return [_hasattr_assert(call, negate=True)]
    if fname == "assertRegex":
        return [_regex_assert(call, negate=False)]
    if fname == "assertNotRegex":
        return [_regex_assert(call, negate=True)]
    if fname == "addCleanup":
        return [_add_cleanup_stmt(call)]
    if fname == "assertStartsWith":
        return [_starts_ends_assert(call, negate=False)]
    if fname == "assertEndsWith":
        return [_starts_ends_assert(call, negate=False, ends=True)]
    raise Unsupported(f"self.{fname}")


def _add_cleanup_stmt(call: ast.Call) -> ast.Expr:
    """self.addCleanup(f, *a, **k) -> _add_cleanup(f, *a, **k).

    The harness helper registers the callable; render_snippet runs the
    registered cleanups LIFO in the wrapper's finalbody (unittest order),
    so a cleanup failure still surfaces to the host oracle.
    """
    _need_args(call, 1)
    fn = call.args[0]
    extra = list(call.args[1:])
    starargs: list[ast.expr] = []
    if extra:
        starargs = [ast.Starred(value=ast.Tuple(elts=extra, ctx=ast.Load()), ctx=ast.Load())]
    return ast.Expr(
        value=ast.Call(
            func=ast.Name(id="_add_cleanup", ctx=ast.Load()),
            args=[fn, *starargs],
            keywords=list(call.keywords),
        )
    )


def _is_none_assert(call: ast.Call, negate: bool) -> ast.Assert:
    _need_args(call, 1)
    x = call.args[0]
    test: ast.expr = ast.Compare(
        left=x, ops=[ast.Is() if not negate else ast.IsNot()],
        comparators=[ast.Constant(value=None)],
    )
    label = "assertIsNotNone" if negate else "assertIsNone"
    return ast.Assert(test=test, msg=_msg_of(call, label, [x]))


def _rewrite_raises(call: ast.Call, regex: bool) -> list[ast.stmt]:
    """Both forms: ``self.assertRaises(E, fn, *a)`` and (via caller for With)
    the context-manager form is handled separately in rewrite_with."""
    _need_args(call, 1)
    exc = call.args[0]
    handler = ast.ExceptHandler(
        type=exc, name=None, body=[ast.Pass()],
    )
    body: list[ast.stmt] = []
    if regex:
        _need_args(call, 2)
        pattern = call.args[1]
        body.append(
            ast.Assert(
                test=ast.Call(
                    func=ast.Attribute(
                        value=ast.Name(id="_re", ctx=ast.Load()),
                        attr="search", ctx=ast.Load(),
                    ),
                    args=[pattern, ast.Call(func=ast.Name(id="str", ctx=ast.Load()), args=[ast.Name(id="_exc", ctx=ast.Load())], keywords=[])],
                    keywords=[],
                ),
                msg=ast.Constant(value="assertRaisesRegex: message mismatch"),
            )
        )
    else_stmt: list[ast.stmt] = [
        ast.Raise(
            exc=ast.Call(
                func=ast.Name(id="AssertionError", ctx=ast.Load()),
                args=[ast.Constant(value="assertRaises: did not raise")],
                keywords=[],
            ),
            cause=None,
        )
    ]
    if len(call.args) >= (3 if regex else 2):
        # Call form: assertRaises(E, fn, *a) /
        # assertRaisesRegex(E, pattern, fn, *a). args[1] (or [2] for the
        # regex form) is the pattern; everything after it is callable + args.
        offset = 2 if regex else 1
        fn = call.args[offset]
        extra = list(call.args[offset + 1 :])
        starargs: list[ast.expr] = []
        if extra:
            starargs = [
                ast.Starred(value=ast.Tuple(elts=extra, ctx=ast.Load()), ctx=ast.Load())
            ]
        invoke: ast.expr = ast.Call(func=fn, args=starargs, keywords=list(call.keywords))
        tried: list[ast.stmt] = [ast.Expr(value=invoke)]
    else:
        if regex:
            raise Unsupported("assertRaisesRegex call form")
        raise Unsupported("context-manager form routed wrongly")
    return [
        ast.Try(
            body=tried,
            handlers=[handler],
            orelse=[],
            finalbody=[],
        )
    ]


def rewrite_raises_with(item: ast.withitem, body: list[ast.stmt]) -> ast.Try:
    """``with self.assertRaises(E[, regex]): <body>`` -> try/except/else.

    An ``as <name>`` target binds ``<name>`` directly to the caught exception
    (unittest's context object only wraps it as ``<name>.exception``, which the
    alias pre-pass in rewrite_block flattens to plain ``<name>`` loads).
    """
    call = item.context_expr
    fname = _call_name(call.func) if isinstance(call, ast.Call) else None
    if fname not in ("assertRaises", "assertRaisesRegex") or not isinstance(call, ast.Call):
        raise Unsupported("non-assertRaises with-block")
    _need_args(call, 1)
    exc = call.args[0]
    # ``except E as n`` deletes ``n`` when the handler exits, so the handler
    # keeps the internal ``_exc`` name and a visible alias (if any) is bound
    # inside the handler -- mirroring unittest's context object surviving the
    # with-block.
    alias: str | None = None
    if item.optional_vars is not None:
        if not isinstance(item.optional_vars, ast.Name):
            raise Unsupported("non-Name assertRaises target")
        alias = item.optional_vars.id
    regex = None
    if fname == "assertRaisesRegex":
        _need_args(call, 2)
        regex = call.args[1]
    handler_body: list[ast.stmt] = []
    if regex is not None:
        handler_body.append(
            ast.Assert(
                test=ast.Call(
                    func=ast.Attribute(
                        value=ast.Name(id="_re", ctx=ast.Load()),
                        attr="search", ctx=ast.Load(),
                    ),
                    args=[regex, ast.Call(func=ast.Name(id="str", ctx=ast.Load()), args=[ast.Name(id="_exc", ctx=ast.Load())], keywords=[])],
                    keywords=[],
                ),
                msg=ast.Constant(value="assertRaisesRegex: message mismatch"),
            )
        )
    if alias is not None:
        handler_body.append(
            ast.Assign(
                targets=[ast.Name(id=alias, ctx=ast.Store())],
                value=ast.Name(id="_exc", ctx=ast.Load()),
            )
        )
    handler = ast.ExceptHandler(type=exc, name="_exc", body=handler_body)

    return ast.Try(
        body=list(body),
        handlers=[handler],
        orelse=[
            ast.Raise(
                exc=ast.Call(
                    func=ast.Name(id="AssertionError", ctx=ast.Load()),
                    args=[ast.Constant(value="assertRaises: did not raise")],
                    keywords=[],
                ),
                cause=None,
            )
        ],
        finalbody=[],
    )


def _is_self_assert_stmt(stmt: ast.stmt) -> bool:
    """True when the statement is a unittest assertion needing rewrite."""
    if isinstance(stmt, (ast.Assert, ast.Raise)):
        return True
    return (
        isinstance(stmt, ast.Expr)
        and isinstance(stmt.value, ast.Call)
        and _call_name(stmt.value.func) is not None
    )


class _ImplDetailFolder(ast.NodeTransformer):
    """``support.check_impl_detail(...)`` -> ``True``.

    The guest mirrors CPython semantics by definition, so the predicate is
    constant-True at pin scope. Folding it (instead of quarantining on the
    ``from test import support`` import) lets the pruning pass drop the
    test.support import from snippets that reference nothing else from it.
    """

    def visit_Call(self, node: ast.Call) -> ast.AST:
        self.generic_visit(node)
        func = node.func
        if (
            isinstance(func, ast.Attribute)
            and func.attr == "check_impl_detail"
            and isinstance(func.value, ast.Name)
            and func.value.id in ("support", "test")
        ):
            return ast.Constant(value=True)
        return node


def rewrite_block(stmts: list[ast.stmt]) -> tuple[list[ast.stmt], bool]:
    """Recursively rewrite a statement list; returns (new stmts, needs_re)."""
    needs_re = False

    def rec(block: list[ast.stmt]) -> list[ast.stmt]:
        nonlocal needs_re
        new: list[ast.stmt] = []
        for stmt in block:
            if isinstance(stmt, (ast.If, ast.For, ast.AsyncFor, ast.While)):
                stmt.body = rec(stmt.body)
                stmt.orelse = rec(stmt.orelse)
                new.append(stmt)
            elif isinstance(stmt, (ast.Try, ast.TryStar)):
                stmt.body = rec(stmt.body)
                stmt.orelse = rec(stmt.orelse)
                stmt.finalbody = rec(stmt.finalbody)
                for handler in stmt.handlers:
                    handler.body = rec(handler.body)
                new.append(stmt)
            elif isinstance(stmt, ast.With):
                handled = False
                if len(stmt.items) == 1:
                    call = stmt.items[0].context_expr
                    if (
                        isinstance(call, ast.Call)
                        and _call_name(call.func) in ("assertRaises", "assertRaisesRegex")
                    ):
                        out_stmt = rewrite_raises_with(stmt.items[0], stmt.body)
                        needs_re = needs_re or _with_needs_re(stmt.items[0])
                        new.append(out_stmt)
                        handled = True
                    elif isinstance(call, ast.Call) and _call_name(call.func) == "subTest":
                        # unittest subTest scopes failure labels without stopping
                        # the test; any failing subtest makes the host oracle
                        # non-"ok", so such cases never become pins. Inlining the
                        # body plainly is therefore oracle-safe.
                        new.extend(rec(stmt.body))
                        handled = True
                if not handled:
                    stmt.body = rec(stmt.body)
                    new.append(stmt)
            else:
                if _is_self_assert_stmt(stmt):
                    new.extend(rewrite_assert_stmt(stmt))
                else:
                    # Plain statements (assignments, nested helper defs, ...)
                    # are already valid Python.
                    if isinstance(stmt, (ast.FunctionDef, ast.AsyncFunctionDef)):
                        stmt.body = rec(stmt.body)
                    new.append(stmt)
        return new

    binds: list[tuple[str, int]] = [
        (item.optional_vars.id, item.context_expr.lineno)
        for node in ast.walk(ast.Module(body=stmts, type_ignores=[]))
        if isinstance(node, ast.With)
        for item in node.items
        if isinstance(item.optional_vars, ast.Name)
        and isinstance(item.context_expr, ast.Call)
        and _call_name(item.context_expr.func) in ("assertRaises", "assertRaisesRegex")
    ]
    if binds:
        stmts = _RaisesAliasAttrFlattener(binds).visit(
            ast.Module(body=list(stmts), type_ignores=[])
        ).body
    new_block = rec(stmts)
    new_block = [_ImplDetailFolder().visit(s) for s in new_block]
    # Any emitted statement loading _re requires the module import. Scanning
    # the final AST (not per-rewrite flags) keeps every vocabulary addition
    # that may emit _re.search honest without plumbing a flag through each.
    for node in ast.walk(ast.Module(body=new_block, type_ignores=[])):
        if isinstance(node, ast.Name) and node.id == "_re" and isinstance(node.ctx, ast.Load):
            needs_re = True
            break
    return new_block, needs_re


class _RaisesAliasAttrFlattener(ast.NodeTransformer):
    """Flatten ``<alias>.exception`` loads after ``assertRaises(E) as <alias>``.

    The with-rewrite binds ``<alias>`` straight to the caught exception, so
    post-bind ``<alias>.exception`` attribute loads must become plain
    ``<alias>`` loads. Only accesses at or after the binding line in the same
    scope are rewritten; anything else stays untouched and surfaces through
    the normal unresolved-name quarantine.
    """

    def __init__(self, binds: list[tuple[str, int]]) -> None:
        self.binds = binds

    def visit_Attribute(self, node: ast.Attribute) -> ast.expr:
        self.generic_visit(node)
        if (
            node.attr == "exception"
            and isinstance(node.value, ast.Name)
            and isinstance(node.ctx, ast.Load)
            and any(a == node.value.id and ln <= node.lineno for a, ln in self.binds)
        ):
            return ast.copy_location(ast.Name(id=node.value.id, ctx=node.ctx), node)
        return node


def _with_needs_re(item: ast.withitem) -> bool:
    call = item.context_expr
    return isinstance(call, ast.Call) and _call_name(call.func) == "assertRaisesRegex"


# ---------------------------------------------------------------------------
# Cleanup harness (self.addCleanup lowering)


_ORACLE_EMIT_HELPERS = '''\
import os as _os
def _oracle_write(text):
    # Raw fd-1 write: survives snippets that monkeypatch sys.stdout/
    # sys.stderr (unittest.mock.patch of stdout would swallow a plain
    # print() and strand the oracle marker).
    _os.write(1, (text + "\\n").encode())
'''

_CLEANUP_HELPERS = '''\
_cleanups = []
def _add_cleanup(f, *args, **kwargs):
    _cleanups.append((f, args, kwargs))
def _run_cleanups():
    while _cleanups:
        f, args, kwargs = _cleanups.pop()
        f(*args, **kwargs)
'''


def _uses_cleanup_helpers(stmts: list[ast.stmt]) -> bool:
    tree = ast.Module(body=stmts, type_ignores=[])
    return any(
        isinstance(node, ast.Name)
        and node.id in ("_add_cleanup", "_run_cleanups")
        and isinstance(node.ctx, ast.Load)
        for node in ast.walk(tree)
    )


def _parse_helpers(src: str) -> list[ast.stmt]:
    return ast.parse(src).body


# ---------------------------------------------------------------------------
# Name resolution checks


_BUILTIN_NAMES: set[str] = set(dir(builtins))
_EXTRA_ALLOWED = {
    "True", "False", "None", "__name__", "__class__", "self",
    "_re", "_exc", "AssertionError", "Exception", "BaseException",
    "_add_cleanup", "_run_cleanups",
}


def _bound_names(nodes: ast.AST) -> set[str]:
    out: set[str] = set()
    for node in ast.walk(nodes):
        if isinstance(node, ast.Name) and isinstance(node.ctx, (ast.Store, ast.Del)):
            out.add(node.id)
        elif isinstance(node, (ast.FunctionDef, ast.AsyncFunctionDef, ast.ClassDef)):
            out.add(node.name)
        elif isinstance(node, ast.arg):
            out.add(node.arg)
        elif isinstance(node, ast.alias):
            out.add(node.asname or node.name.split(".")[0])
        elif isinstance(node, ast.excepthandler) and node.name:
            out.add(node.name)
    return out


def _loaded_names(nodes: ast.AST) -> set[str]:
    return {
        node.id
        for node in ast.walk(nodes)
        if isinstance(node, ast.Name) and isinstance(node.ctx, ast.Load)
    }


def _self_attr_stores(body: list[ast.stmt]) -> set[str]:
    """Attribute names assigned via ``self.<attr> = ...`` anywhere in body."""
    out: set[str] = set()
    for node in ast.walk(ast.Module(body=body, type_ignores=[])):
        targets: list[ast.expr] = []
        if isinstance(node, ast.Assign):
            targets = node.targets
        elif isinstance(node, ast.AnnAssign):
            targets = [node.target]
        for t in targets:
            if isinstance(t, ast.Attribute) and isinstance(t.value, ast.Name) \
                    and t.value.id == "self":
                out.add(t.attr)
    return out


def _scan_self_usage(body: list[ast.stmt], namespace_callable: set[str] | None = None) -> tuple[set[str], set[str]]:
    """Partition ``self.*`` references into namespace-safe attrs vs calls.

    Returns (ns_attrs, call_attrs): ``ns_attrs`` are plain attribute
    loads/stores (``self.data``, ``self.data[i] = x``) that a bare namespace
    object bound to ``self`` satisfies at runtime; ``call_attrs`` are
    ``self.method(...)`` references that need helper-vocabulary lifting (the
    caller reports them unsupported when the rewriter left them behind).
    """
    tree = ast.Module(body=body, type_ignores=[])
    call_func_ids = {
        id(node.func)
        for node in ast.walk(tree)
        if isinstance(node, ast.Call)
        and isinstance(node.func, ast.Attribute)
        and isinstance(node.func.value, ast.Name)
        and node.func.value.id == "self"
    }
    ns_attrs: set[str] = set()
    call_attrs: set[str] = set()
    for node in ast.walk(tree):
        if (
            isinstance(node, ast.Attribute)
            and isinstance(node.value, ast.Name)
            and node.value.id == "self"
        ):
            if id(node) in call_func_ids:
                call_attrs.add(node.attr)
            else:
                ns_attrs.add(node.attr)
    return ns_attrs, call_attrs


_NS_PRELUDE_SRC = "class _SelfNS:\n    pass\nself = _SelfNS()\n"
_NS_CLASS_NAME = "_SelfNS"


def _namespace_prelude() -> list[ast.stmt]:
    """AST prelude binding ``self`` to a bare attribute namespace."""
    return ast.parse(_NS_PRELUDE_SRC).body


def _check_self_usage(body: list[ast.stmt], prefix: str = "") -> None:
    _, call_attrs = _scan_self_usage(body)
    if call_attrs:
        raise Unsupported(f"{prefix}uses-self.{sorted(call_attrs)[0]}")


def _check_names(body: list[ast.stmt], available: set[str]) -> None:
    local = _bound_names(ast.Module(body=body, type_ignores=[])) | available | _EXTRA_ALLOWED | _BUILTIN_NAMES
    for name in sorted(_loaded_names(ast.Module(body=body, type_ignores=[]))):
        if name not in local:
            raise Unsupported(f"unresolved-name:{name}")


_SKIP_DECOS = {
    "skip", "skipIf", "skipUnless", "expectedFailure",
    "skipUnlessDB", "requires",  # support.requires* caught below
}

# Harness modules with NATIVE facades in jacpython (layer_p2_libtest
# register_shim_module): guest replays resolve these, so prelude imports of
# them no longer force a blanket quarantine -- only harness surface with no
# facade does.
_SHIMMED_TEST_MODULES = {
    "test",
    "test.support",
    "test.support.os_helper",
    "test.support.import_helper",
    "test.support.numbers",
}

# Availability-gate decorators: pure skip predicates (platform/feature
# probes), never test logic. On the host that captures the oracle they
# always pass, so stripping them keeps the oracle valid; drop instead of
# quarantine.
_DROPPABLE_DECOS = {
    "cpython_only", "requires_subprocess",
    # Environment gates, not test logic: requires_mac_ver is a platform
    # predicate and requires_resource only reserves capture-host quota.
    "requires_mac_ver", "requires_resource",
}

# Conditional availability gates (@unittest.skipIf / @unittest.skipUnless):
# the predicate is capture-environment logic, not test logic, and the oracle
# is captured by actually running the body on the host -- so stripping the
# gate keeps every pin a valid host-vs-guest differential regardless of how
# the predicate evaluates here. Bare @skip stays quarantined: an
# unconditionally skipped method contributes no upstream coverage to mirror.
_GATE_DECOS = {"skipIf", "skipUnless"}


def _host_skip_env(tree: ast.Module) -> dict:
    """Namespace for constant-folding skip-decorator predicates on the host.

    Built by executing the suite's own top-level imports and assignments
    (os, sys, mmap, PAGESIZE = mmap.PAGESIZE, ...) -- exactly what the
    predicates read. The oracle-capture interpreter IS this host, so a
    predicate evaluated here decides faithfully whether unittest would run
    or skip the test; anything that fails to evaluate keeps the old
    blanket-quarantine behavior.
    """
    env: dict = {"__builtins__": __builtins__}

    def _import_module(name: str):
        return __import__(name)

    # Fallback seeds for names from the harness package when it cannot load
    # on this interpreter: stable support constants plus no-op helpers.
    env.setdefault("import_module", _import_module)
    env.setdefault("_1G", 2**30)
    env.setdefault("_2G", 2**31)
    env.setdefault("_4G", 2**32)
    for node in tree.body:
        try:
            if isinstance(node, ast.Import | ast.ImportFrom):
                if node.col_offset != 0:
                    continue
                code = compile(ast.Module(body=[node], type_ignores=[]), "<skip-env>", "exec")
                exec(code, env)
            elif isinstance(node, ast.Assign | ast.AnnAssign) and node.col_offset == 0:
                code = compile(ast.Module(body=[node], type_ignores=[]), "<skip-env>", "exec")
                exec(code, env)
        except Exception:
            continue
    return env


def _eval_skip_cond(cond: ast.expr, env: dict) -> bool | None:
    """Evaluate a skipIf/skipUnless condition on the host; None on failure."""
    try:
        code = compile(ast.Expression(cond), "<skip-cond>", "eval")
        return bool(eval(code, env))  # noqa: S307 - pinned reference tree input
    except Exception:
        return None


def _decorator_reason(deco: ast.expr, env: dict | None = None) -> str | None:
    name = None
    if isinstance(deco, ast.Name):
        name = deco.id
    elif isinstance(deco, ast.Attribute):
        base = deco.value.id if isinstance(deco.value, ast.Name) else ""
        if deco.attr in _SKIP_DECOS:
            if deco.attr in _GATE_DECOS and base in ("", "unittest"):
                return None
            return f"decorator:{base}.{deco.attr}" if base else f"decorator:{deco.attr}"
        if deco.attr in _DROPPABLE_DECOS and base in ("", "support"):
            return None
        if base == "support" or deco.attr.startswith("requires"):
            return f"decorator:{base}.{deco.attr}"
        return None
    elif isinstance(deco, ast.Call):
        func = deco.func
        attr = base = ""
        if isinstance(func, ast.Attribute):
            base = func.value.id if isinstance(func.value, ast.Name) else ""
            attr = func.attr
        elif isinstance(func, ast.Name):
            attr = func.id
        if attr in ("skipIf", "skipUnless") and base in ("", "unittest") and deco.args:
            # Constant-fold the gate on the host oracle interpreter (same
            # policy as _DROPPABLE_DECOS): when the predicate evaluates we
            # know whether unittest would run or skip -- strip runnable
            # gates, quarantine skipped ones precisely. Unevaluable gates
            # keep the blanket decorator quarantine below.
            verdict = _eval_skip_cond(deco.args[0], env) if env is not None else None
            if verdict is True:
                return None if attr == "skipUnless" else "skipped-on-host"
            if verdict is False:
                return None if attr == "skipIf" else "skipped-on-host"
        if base == "support" and attr.startswith("requires") and deco.args:
            # test.support availability gates (requires_linux_version, ...):
            # call the real gate with its literal arguments and probe the
            # returned wrapper the way unittest application would -- a gate
            # that would NOT skip here keeps the pin a valid differential.
            # Anything unevaluable keeps the blanket quarantine below.
            try:
                fn = eval("%s.%s" % (base, attr), env) if env is not None else None  # noqa: S307 - pinned reference tree input
                if fn is not None:
                    gate_args = [ast.literal_eval(a) for a in deco.args]
                    probe = fn(*gate_args)(lambda: None)
                    if not getattr(probe, "__unittest_skip__", False):
                        return None
            except Exception:
                pass
        return _decorator_reason(func, env)
    if name and name in _DROPPABLE_DECOS:
        return None
    if name and name in _SKIP_DECOS:
        if name in _GATE_DECOS:
            return None
        return f"decorator:{name}"
    return None


# ---------------------------------------------------------------------------
# Fixture-vocabulary lifting (custom TestCase helper methods)
#
# Suites like test_htmlparser route every assertion through helpers defined
# on the TestCase hierarchy (``self._run_check(...)``). Those methods are
# mechanically liftable: drop the ``self`` parameter, rewrite nested
# ``self.helper(...)`` calls to plain calls, and reuse the standard
# assertion vocabulary inside the helper body. Anything a helper does that
# has no mechanical mapping (instance state, decorators, unresolved names)
# quarantines the *test* with the helper's precise reason instead of
# mistranslating.


@dataclass
class _ClassInfo:
    methods: dict[str, ast.FunctionDef]
    bases: list[str]


def _module_class_map(tree: ast.Module) -> dict[str, _ClassInfo]:
    cmap: dict[str, _ClassInfo] = {}
    for node in tree.body:
        if isinstance(node, ast.ClassDef):
            cmap[node.name] = _ClassInfo(
                methods={
                    m.name: m for m in node.body if isinstance(m, ast.FunctionDef)
                },
                bases=[b.id for b in node.bases if isinstance(b, ast.Name)],
            )
    return cmap


def _resolve_method(
    cmap: dict[str, _ClassInfo], cls_name: str | None, attr: str
) -> ast.FunctionDef | None:
    """attr on cls_name or its in-module bases (BFS); test methods excluded."""
    seen: set[str] = set()
    queue = [cls_name] if cls_name else []
    while queue:
        name = queue.pop(0)
        if name in seen:
            continue
        seen.add(name)
        info = cmap.get(name)
        if info is None:
            continue
        fn = info.methods.get(attr)
        if fn is not None and not attr.startswith("test"):
            return fn
        queue.extend(info.bases)
    return None


def _drop_self_arg(fn: ast.FunctionDef) -> ast.arguments:
    """Copy fn.args minus the leading ``self`` parameter."""
    a = fn.args
    posonly = list(a.posonlyargs)
    args = list(a.args)
    if posonly and posonly[0].arg == "self":
        posonly.pop(0)
    elif args and args[0].arg == "self":
        args.pop(0)
    else:
        raise Unsupported("missing-self-parameter")
    total_before = len(a.posonlyargs) + len(a.args)
    defaults = list(a.defaults)
    if len(defaults) == total_before:
        # self itself was defaulted; shift defaults with the parameter list
        defaults = defaults[1:]
    return ast.arguments(
        posonlyargs=posonly,
        args=args,
        vararg=a.vararg,
        kwonlyargs=list(a.kwonlyargs),
        kw_defaults=list(a.kw_defaults),
        kwarg=a.kwarg,
        defaults=defaults,
    )


class _HelperCallRewriter(ast.NodeTransformer):
    """``self.helper(...)`` -> ``helper(...)``, lifting helper transitively.

    self-attribute calls that do not resolve to an in-module method are left
    untouched so downstream checks report them with their usual reason.
    """

    def __init__(self, session: "_FixtureVocab") -> None:
        self.session = session

    def visit_Call(self, node: ast.Call) -> ast.AST:
        self.generic_visit(node)
        func = node.func
        if (
            isinstance(func, ast.Attribute)
            and isinstance(func.value, ast.Name)
            and func.value.id == "self"
            and _resolve_method(self.session.cmap, self.session.cls_name, func.attr)
            is not None
        ):
            self.session.ensure(func.attr)
            node.func = ast.Name(id=func.attr, ctx=ast.Load())
        return node


class _FixtureVocab:
    """Per-candidate lifting session for one test method's class."""

    def __init__(self, cls_name: str | None, cmap: dict[str, _ClassInfo],
                 available_names: set[str]) -> None:
        self.cls_name = cls_name
        self.cmap = cmap
        self.available_names = available_names
        self.lifted: list[ast.FunctionDef] = []  # insertion order
        self.needs_re = False
        self.needs_ns = False
        # self.<attr> names that resolve to callables at runtime (class-level
        # attribute seeds or setUp-assigned); calls through them are legal
        # once the namespace exists.
        self.allowed_calls: set[str] = set()
        self._ok: dict[str, ast.FunctionDef] = {}
        self._failed: dict[str, Unsupported] = {}
        self._lifting: set[str] = set()

    def ensure(self, attr: str) -> ast.FunctionDef:
        if attr in self._ok:
            return self._ok[attr]
        if attr in self._failed:
            raise self._failed[attr]
        if attr in self._lifting:
            raise Unsupported(f"recursive-helper:{attr}")
        self._lifting.add(attr)
        try:
            fn = _resolve_method(self.cmap, self.cls_name, attr)
            if fn is None:
                raise Unsupported("not-in-class-hierarchy")
            lifted, needs_re = self._lift(fn)
        except Unsupported as exc:
            wrapped = Unsupported(f"helper:{attr}({exc})")
            self._failed[attr] = wrapped
            raise wrapped from None
        finally:
            self._lifting.discard(attr)
        self._ok[attr] = lifted
        self.lifted.append(lifted)
        self.needs_re = self.needs_re or needs_re
        return lifted

    def _lift(self, fn: ast.FunctionDef) -> tuple[ast.FunctionDef, bool]:
        # Deep-copy before transforming: helper methods are tree nodes shared
        # by every test candidate; in-place substitution would leak one
        # candidate's rewriting into the next candidate's lift.
        fn = copy.deepcopy(fn)
        if fn.decorator_list:
            raise Unsupported("decorated-helper")
        args = _drop_self_arg(fn)
        rewriter = _HelperCallRewriter(self)
        body = [rewriter.visit(stmt) for stmt in fn.body]
        body, needs_re = rewrite_block(body)
        ns_attrs, call_attrs = _scan_self_usage(body)
        bad = {a for a in call_attrs if a not in self.allowed_calls}
        if bad:
            raise Unsupported(f"uses-self.{sorted(bad)[0]}")
        if ns_attrs or (call_attrs and self.allowed_calls):
            self.needs_ns = True
        try:
            siblings = {f.name for f in self.lifted} | {
                f.name for f in self._ok.values()
            }
            params = {
                a.arg
                for group in (
                    args.posonlyargs, args.args, args.kwonlyargs,
                    ([args.vararg] if args.vararg else []),
                    ([args.kwarg] if args.kwarg else []),
                )
                for a in group
            }
            _check_names(body, self.available_names | siblings | params)
        except Unsupported as exc:
            raise Unsupported(str(exc)) from None
        return (
            ast.FunctionDef(
                name=fn.name,
                args=args,
                body=body,
                decorator_list=[],
                returns=None,
                type_params=[],
            ),
            needs_re,
        )


def _helper_class_deps(
    lifted: list[ast.FunctionDef], mod_classes: dict[str, ast.ClassDef]
) -> list[ast.stmt]:
    """Module classes referenced by lifted helpers, base classes first.

    Helper bodies construct fixture classes (EventCollector & co.); those
    must join the prune pool or name resolution would quarantine every
    helper-using test. Test bodies referencing classes directly keep the
    stricter pre-existing behavior (classes stay out of scope for them).
    """
    if not lifted:
        return []
    used: set[str] = set()
    for fn in lifted:
        used |= _loaded_names(ast.Module(body=[fn], type_ignores=[]))
    ordered: list[ast.ClassDef] = []
    placed: set[str] = set()
    pending = [c for c in mod_classes.values() if c.name in used]
    while pending:
        rest = []
        progressed = False
        for cnode in pending:
            deps = {
                b.id for b in cnode.bases if isinstance(b, ast.Name)
            } & set(mod_classes)
            if deps <= placed:
                ordered.append(cnode)
                placed.add(cnode.name)
                used |= _loaded_names(cnode)
                progressed = True
            else:
                rest.append(cnode)
        pending = [c for c in rest if c.name not in placed and c.name in used]
        if not progressed and pending:
            # cyclic or externally-unsatisfied bases; emit remaining as-is
            ordered.extend(pending)
            break
    return ordered


def _guarded_class_stmts(body: list[ast.stmt]) -> list[ast.stmt]:
    """Class-body statements, descending into guarded ``if`` blocks.

    C/py dual-module test classes assign their ``module``/``partial``
    attributes inside ``if c_functools:`` guards; those assignments are real
    class attributes whenever the guard holds, so seeds must see them.
    """
    out: list[ast.stmt] = []
    for stmt in body:
        if isinstance(stmt, ast.If):
            out.extend(_guarded_class_stmts(stmt.body))
            out.extend(_guarded_class_stmts(stmt.orelse))
        else:
            out.append(stmt)
    return out


def _class_attr_seeds(
    cls_name: str | None, cmap: dict[str, _ClassInfo],
    mod_classes: dict[str, ast.ClassDef],
) -> list[tuple[str, ast.expr]]:
    """Class-level attribute assignments along the MRO, base-first.

    ``module = py_operator``-style attributes resolve via class attribute
    lookup in CPython; with a namespace ``self`` they must be seeded onto it.
    Later (sub)class assignments override earlier ones. Method names are not
    attributes here -- the helper vocabulary handles those separately.
    """
    if cls_name is None:
        return []
    chain: list[str] = []
    seen: set[str] = set()
    stack = [cls_name]
    while stack:
        name = stack.pop()
        if name in seen:
            continue
        seen.add(name)
        chain.append(name)
        info = cmap.get(name)
        if info is not None:
            stack.extend(reversed(info.bases))
    seeds: dict[str, ast.expr] = {}
    # ``chain`` is child-first; seed in reverse so subclass attributes
    # override inherited defaults (CPython attribute lookup semantics).
    for name in reversed(chain):
        cd = mod_classes.get(name)
        if cd is None:
            continue
        for stmt in _guarded_class_stmts(cd.body):
            if isinstance(stmt, ast.Assign) and len(stmt.targets) == 1 \
                    and isinstance(stmt.targets[0], ast.Name):
                seeds[stmt.targets[0].id] = stmt.value
            elif isinstance(stmt, ast.AnnAssign) and isinstance(stmt.target, ast.Name) \
                    and stmt.value is not None:
                seeds[stmt.target.id] = stmt.value
            elif isinstance(stmt, ast.ClassDef):
                seeds[stmt.name] = ast.Name(id=stmt.name, ctx=ast.Load())
    # Drop names that are methods on any class in the chain (a method always
    # wins over a same-named data attribute in the lookup that matters here,
    # and calling conventions differ).
    for name in chain:
        info = cmap.get(name)
        if info is not None:
            for meth in info.methods:
                seeds.pop(meth, None)
    return sorted(seeds.items())


def _nested_class_defs(cls_name: str | None, cmap: dict[str, _ClassInfo],
                       mod_classes: dict[str, ast.ClassDef]) -> list[ast.ClassDef]:
    """Class definitions nested inside the candidate's class chain.

    ``self.simplecmd``-style references to classes defined in a TestCase body
    resolve via class attribute lookup in CPython; with a namespace ``self``
    the definition itself must execute at snippet scope before the seed.
    """
    if cls_name is None:
        return []
    out: list[ast.ClassDef] = []
    seen: set[str] = set()
    stack = [cls_name]
    while stack:
        name = stack.pop()
        if name in seen:
            continue
        seen.add(name)
        cd = mod_classes.get(name)
        if cd is not None:
            for stmt in cd.body:
                if isinstance(stmt, ast.ClassDef):
                    out.append(stmt)
        info = cmap.get(name)
        if info is not None:
            stack.extend(info.bases)
    return out


def _apply_fixture_vocab(
    body: list[ast.stmt],
    cls_name: str,
    cmap: dict[str, _ClassInfo],
    mod_classes: dict[str, ast.ClassDef],
    available_names: set[str],
) -> tuple[list[ast.stmt], list[ast.stmt], list[ast.stmt], list[ast.stmt], bool]:
    """Lift custom helper vocabulary for one test candidate.

    Returns (rewritten body, lifted helper defs, extra prelude statements,
    namespace seed assignments, needs_re).

    Lifted helpers are returned separately (not folded into the prelude
    pool): they are emitted *inside* the wrapped snippet body so any ``self``
    reference in a helper resolves through the namespace closure instead of
    raising NameError at module scope.
    """
    session = _FixtureVocab(cls_name, cmap, available_names)
    # self.<attr> callables: class-attr seeds plus anything any method of the
    # class chain (ancestors and descendants) stores onto self (setUp and
    # friends). Calls through these resolve at runtime once the namespace
    # exists.
    related: list[str] = []
    seen_cls = {cls_name}
    stack = [cls_name]
    while stack:
        name = stack.pop()
        related.append(name)
        info = cmap.get(name)
        if info is not None:
            for b in info.bases:
                if b not in seen_cls:
                    seen_cls.add(b)
                    stack.append(b)
            for child in cmap:
                if cls_name in cmap[child].bases or name in cmap[child].bases:
                    if child not in seen_cls:
                        seen_cls.add(child)
                        stack.append(child)
    for name in related:
        info = cmap.get(name)
        if info is None:
            continue
        for meth in info.methods.values():
            session.allowed_calls |= _self_attr_stores(meth.body)
    session.allowed_calls |= {
        attr for attr, _ in _class_attr_seeds(cls_name, cmap, mod_classes)
    }
    prefix: list[ast.stmt] = []
    if _resolve_method(cmap, cls_name, "setUp") is not None:
        # unittest runs setUp before every test; splice its lifted body so
        # locals it binds become locals of the test. A setUp that cannot be
        # lifted cleanly fails the whole test via ensure()'s reason.
        prefix = list(session.ensure("setUp").body)
        prefix = [copy.deepcopy(s) for s in prefix]
    rewriter = _HelperCallRewriter(session)
    stmts = [rewriter.visit(s) for s in prefix + list(body)]
    rewritten, needs_re = rewrite_block(stmts)
    # Scan lifted helper bodies together with the test body: a helper's
    # ``self.<attr>`` load/store has the same runtime fate as one written
    # inline in the test.
    scanned = [*session.lifted, *rewritten]
    ns_attrs, call_attrs = _scan_self_usage(scanned)
    bad = {a for a in call_attrs if a not in session.allowed_calls}
    if bad:
        raise Unsupported(f"uses-self.{sorted(bad)[0]}")
    # Namespace loads must be satisfiable at runtime: class-level seeds plus
    # stores that actually execute inside the snippet (spliced setUp, test
    # body, lifted helpers). Stores confined to unlifted methods (__init__
    # and friends) never run, so a load of such an attr would only die as an
    # opaque AttributeError during oracle capture -- quarantine it precisely
    # instead.
    executed_stores = _self_attr_stores(scanned)
    seed_attrs = {attr for attr, _ in _class_attr_seeds(cls_name, cmap, mod_classes)}
    unseeded = ns_attrs - seed_attrs - executed_stores
    if unseeded:
        raise Unsupported(f"uses-self.{sorted(unseeded)[0]}")
    helper_defs = list(session.lifted)
    extra_prelude = _helper_class_deps(session.lifted, mod_classes)
    extra_prelude += _nested_class_defs(cls_name, cmap, mod_classes)
    ns_block: list[ast.stmt] = []
    # Calls through seeded self.<attr> survive rewriting on purpose (they
    # resolve at runtime once the namespace exists), so any surviving
    # self.* usage -- data loads/stores or allowed calls -- needs the
    # namespace object.
    if bool(ns_attrs) or bool(call_attrs) or session.needs_ns:
        ns_block = _namespace_prelude()
        for attr, value in _class_attr_seeds(cls_name, cmap, mod_classes):
            for owner in ("self", _NS_CLASS_NAME):
                # Seed both the instance and its class: tests that do
                # ``cls = self.__class__; cls.<attr>`` resolve through the
                # class, which under unittest holds the same attribute.
                assign = ast.Assign(
                    targets=[ast.Attribute(value=ast.Name(id=owner, ctx=ast.Load()),
                                           attr=attr, ctx=ast.Store())],
                    value=copy.deepcopy(value),
                )
                ast.fix_missing_locations(assign)
                ns_block.append(assign)
    return rewritten, helper_defs, extra_prelude, ns_block, needs_re or session.needs_re


# ---------------------------------------------------------------------------
# Extraction


def _src(node: ast.AST, source: str) -> str:
    seg = ast.get_source_segment(source, node)
    return seg or ast.unparse(node)


def _is_platform_alias_import_guard(node: ast.Try) -> bool:
    """True for the try-import fallback idiom (test_posix.py's
    ``try: import posix`` / ``except ImportError: import nt as posix``):
    every statement in the body and in each ImportError handler is a bare
    module import, with no else/final clauses. The whole Try joins the
    prelude pool and binds its import aliases at module scope."""
    if node.orelse or node.finalbody:
        return False

    def _all_imports(stmts: list[ast.stmt]) -> bool:
        return all(isinstance(s, ast.Import) for s in stmts)

    if not _all_imports(node.body):
        return False
    return all(
        isinstance(h.type, ast.Name) and h.type.id == "ImportError"
        and not h.name and _all_imports(h.body)
        for h in node.handlers
    )


def collect_prelude(tree: ast.Module, source: str, include_classes: bool = False) -> tuple[list[ast.stmt], set[str]]:
    """Module-level imports/assigns/function defs/classes usable as prelude.

    Everything enters the same prunable pool: ``_prune_prelude`` keeps only
    items whose bindings the test body (transitively) references, so a
    module-level helper class lands in a snippet only when the body actually
    names it -- previously such references quarantined as
    ``unresolved-name:<Class>``. Try-wrapped platform-alias import guards
    (see ``_is_platform_alias_import_guard``) join the pool too; previously
    their bindings (e.g. ``posix``) were invisible to every snippet.
    """
    stmts: list[ast.stmt] = []
    names: set[str] = set()
    for node in tree.body:
        if isinstance(node, (ast.Import, ast.ImportFrom, ast.Assign, ast.AnnAssign,
                             ast.FunctionDef)):
            stmts.append(node)
            names |= _bound_names(node)
        elif isinstance(node, ast.Try) and _is_platform_alias_import_guard(node):
            stmts.append(node)
            names |= _bound_names(node)
        elif include_classes and isinstance(node, ast.ClassDef):
            stmts.append(node)
            names.add(node.name)
    return stmts, names


def _prelude_bindings(item: ast.stmt) -> set[str]:
    """Names a prelude item binds at module scope. Classes AND functions
    bind exactly their own name (_bound_names would also pull in nested
    method/local names, wrongly matching unrelated bodies during pruning)."""
    if isinstance(item, (ast.ClassDef, ast.FunctionDef, ast.AsyncFunctionDef)):
        return {item.name}
    return _bound_names(item)


def _prune_prelude(
    body: list[ast.stmt], prelude: list[ast.stmt], prelude_names: set[str]
) -> list[ast.stmt]:
    """Fixpoint: keep only prelude items whose bindings the body (+ kept
    items transitively) reference."""
    used = set(_loaded_names(ast.Module(body=body, type_ignores=[])))
    kept: dict[int, ast.stmt] = {}
    changed = True
    while changed:
        changed = False
        for idx, item in enumerate(prelude):
            if idx in kept:
                continue
            binds = _prelude_bindings(item)
            if binds & used:
                kept[idx] = item
                new_used = _loaded_names(item)
                if not new_used <= used:
                    used |= new_used
                    changed = True
    return [kept[i] for i in sorted(kept)]


def extract_tests(
    tree: ast.Module, source: str,
    ext_ctx: dict | None = None,
) -> Extraction:
    result = Extraction()
    prelude, prelude_names = collect_prelude(tree, source, include_classes=True)
    skip_env = _host_skip_env(tree)
    cmap = _module_class_map(tree)
    mod_classes = {
        node.name: node for node in tree.body if isinstance(node, ast.ClassDef)
    }
    ext_prelude: list[ast.stmt] = []
    if ext_ctx is not None:
        # Helper-module context (multibytecodec_support-style suites): its
        # classes join the class map so MRO lookups (setUp, helpers, attr
        # seeds) see them; its importable top-level statements join the
        # prunable prelude pool. _external_base_context has already folded
        # every seed that referenced the helper module into literals.
        for name, info in ext_ctx["cmap"].items():
            cmap.setdefault(name, info)
        for name, cd in ext_ctx["mod_classes"].items():
            mod_classes.setdefault(name, cd)
        ext_prelude = ext_ctx["prelude"]
        prelude_names |= {
            b for item in ext_prelude for b in _prelude_bindings(item)
        }
    # Lifted helper bodies may reference module-level fixture classes; those
    # are materialized into the snippet pool afterwards (_helper_class_deps).
    vocab_available = prelude_names | set(mod_classes)

    candidates: list[tuple[str | None, str, list[ast.stmt]]] = []
    for node in tree.body:
        if isinstance(node, ast.ClassDef):
            class_reason = None
            for deco in node.decorator_list:
                reason = _decorator_reason(deco, skip_env)
                if reason:
                    class_reason = reason
            seen_methods: set[str] = set()
            for member in node.body:
                if not isinstance(member, ast.FunctionDef) or not member.name.startswith("test"):
                    continue
                seen_methods.add(member.name)
                ident = f"{node.name}.{member.name}"
                reason = class_reason
                if reason is None:
                    for deco in member.decorator_list:
                        reason = _decorator_reason(deco, skip_env)
                        if reason:
                            break
                if reason is not None:
                    result.quarantined.append(Quarantined(ident, reason))
                    continue
                candidates.append((node.name, ident, list(member.body)))
            # Inherited test vocabulary: unittest runs every test_* method
            # reachable through the MRO against this class's attribute seeds.
            # Lift each ancestor method once per concrete class here (the
            # leaf-expansion below only covers in-module base classes).
            queue = list(cmap.get(node.name).bases) if node.name in cmap else []
            visited: set[str] = set()
            while queue:
                anc = queue.pop(0)
                if anc in visited:
                    continue
                visited.add(anc)
                info = cmap.get(anc)
                if info is None:
                    continue
                queue.extend(info.bases)
                for meth_name, fn in info.methods.items():
                    if not meth_name.startswith("test") or meth_name in seen_methods:
                        continue
                    seen_methods.add(meth_name)
                    ident = f"{node.name}.{meth_name}"
                    if class_reason is not None:
                        result.quarantined.append(Quarantined(ident, class_reason))
                        continue
                    candidates.append((node.name, ident, list(fn.body)))
        elif isinstance(node, ast.FunctionDef) and node.name.startswith("test"):
            for deco in node.decorator_list:
                reason = _decorator_reason(deco, skip_env)
                if reason:
                    result.quarantined.append(Quarantined(node.name, reason))
                    break
            else:
                candidates.append((None, node.name, list(node.body)))

    # Concrete-subclass variant expansion: a test-bearing base class whose
    # subclasses carry distinct class attributes (``module = py_operator`` vs
    # ``c_operator``) runs once per concrete leaf in CPython, each seeing its
    # own attribute values through the MRO. Expand such candidates per leaf;
    # classes without in-module descendants keep their single candidate.
    children: dict[str, list[str]] = {}
    for cname, info in cmap.items():
        for b in info.bases:
            children.setdefault(b, []).append(cname)

    def _leaves(name: str) -> list[str]:
        kids = children.get(name, [])
        if not kids:
            return [name]
        out: list[str] = []
        for k in kids:
            out.extend(_leaves(k))
        return out

    expanded: list[tuple[str | None, str, list[ast.stmt]]] = []
    for cls_name, ident, body_stmts in candidates:
        if cls_name is not None and children.get(cls_name):
            for leaf in _leaves(cls_name):
                expanded.append(
                    (leaf, f"{leaf}.{ident.split('.', 1)[1]}", body_stmts)
                )
        else:
            expanded.append((cls_name, ident, body_stmts))
    candidates = expanded

    for cls_name, ident, body_stmts in candidates:
        try:
            extra_prelude: list[ast.stmt] = []
            ns_block: list[ast.stmt] = []
            helper_defs: list[ast.FunctionDef] = []
            # Candidate bodies are shared AST nodes across leaf-class
            # expansions; the rewriters below mutate in place, so isolate
            # each candidate's view (helper lifts deep-copy for the same
            # reason).
            body_stmts = [copy.deepcopy(s) for s in body_stmts]
            if cls_name is not None:
                rewritten, helper_defs, extra_prelude, ns_block, needs_re = _apply_fixture_vocab(
                    body_stmts, cls_name, cmap, mod_classes, vocab_available
                )
            else:
                rewritten, needs_re = rewrite_block(body_stmts)
                # Module-level test functions have no self binding; keep the
                # strict sweep there (any self.* reference is unsupported).
                _check_self_usage(rewritten)
            if ns_block:
                rewritten = ns_block + rewritten
            # Lifted helpers nest inside the wrapped body so their ``self``
            # references resolve through the namespace closure.
            candidate = [*helper_defs, *rewritten]
            pool = [*prelude, *ext_prelude, *extra_prelude]
            pool_names = prelude_names | {
                binding
                for item in extra_prelude
                for binding in _prelude_bindings(item)
            }
            kept_prelude = _prune_prelude(candidate, pool, pool_names)
            # The CPython test harness surface WITHOUT a native facade is not
            # part of any guest stdlib and cannot replay on jacpython --
            # quarantine precisely on that module. Shimmed harness modules
            # (see _SHIMMED_TEST_MODULES) flow through: their host oracle is
            # capturable (reference Lib appended to sys.path) and their guest
            # replay resolves through the registered facades.
            for stmt in kept_prelude:
                if isinstance(stmt, ast.Import):
                    mods = [alias.name for alias in stmt.names]
                elif isinstance(stmt, ast.ImportFrom) and stmt.module:
                    mods = [stmt.module]
                else:
                    continue
                for m in mods:
                    is_test = m == "test" or m.startswith("test.")
                    if is_test and m not in _SHIMMED_TEST_MODULES:
                        raise Unsupported(f"unsupported-import:{m}")
            available = pool_names | _bound_names(ast.Module(body=kept_prelude, type_ignores=[]))
            _check_names(candidate, available)
        except Unsupported as exc:
            result.quarantined.append(Quarantined(ident, str(exc)))
            continue
        snippet = render_snippet(
            candidate,
            kept_prelude,
            needs_re,
            needs_cleanup=_uses_cleanup_helpers([*candidate, *extra_prelude]),
        )
        result.pinned.append(Pinned(ident, snippet, oracle={}))

    # self.skipTest anywhere in candidate bodies -> quarantine (checked after
    # the general self.* sweep would already have flagged it, but keep the
    # explicit reason for readability).
    for pin in list(result.pinned):
        if "skipTest" in pin.snippet:
            result.pinned.remove(pin)
            result.quarantined.append(Quarantined(pin.ident, "self.skipTest"))
    return result


# ---------------------------------------------------------------------------
# Module-level doctest extraction (test_genexps-style files)


def _eval_str_value(value: ast.expr, modname: str) -> str | None:
    """Statically evaluate a module-level string expression.

    Handles plain constants and the ``"..." % {'modname': __name__}``
    interpolation idiom (test_descrtut). ``__name__`` is substituted with
    *modname*, which must equal the ``__name__`` both the host oracle and
    the guest harness exec snippets under ("__main__").
    """
    try:
        val = ast.literal_eval(value)
    except (ValueError, SyntaxError, TypeError, MemoryError):
        if (
            isinstance(value, ast.BinOp)
            and isinstance(value.op, ast.Mod)
            and isinstance(value.left, ast.Constant)
            and isinstance(value.left.value, str)
        ):
            right: dict[str, object] = {}
            dict_node = value.right
            if not isinstance(dict_node, ast.Dict):
                return None
            ok = True
            for k, v in zip(dict_node.keys, dict_node.values):
                if k is None or not isinstance(k, ast.Constant):
                    ok = False
                    break
                if isinstance(v, ast.Name) and v.id == "__name__":
                    right[k.value] = modname
                    continue
                try:
                    right[k.value] = ast.literal_eval(v)
                except (ValueError, SyntaxError, TypeError, MemoryError):
                    ok = False
                    break
            if not ok:
                return None
            try:
                val = value.left.value % right
            except (TypeError, ValueError, KeyError):
                return None
        else:
            return None
    return val if isinstance(val, str) else None


def collect_doctest_sources(tree: ast.Module, modname: str) -> list[tuple[str, str]]:
    """Find module-level doctest texts: ``doctests = "..."`` registered via
    ``__test__`` (dict of label -> string/name), falling back to any
    module-level string constant named ``doctests`` containing examples."""
    strings: dict[str, str] = {}
    test_map: dict | None = None
    for node in tree.body:
        target_name = None
        value = None
        if isinstance(node, ast.Assign) and len(node.targets) == 1 and isinstance(node.targets[0], ast.Name):
            target_name, value = node.targets[0].id, node.value
        elif isinstance(node, ast.AnnAssign) and isinstance(node.target, ast.Name) and node.value is not None:
            target_name, value = node.target.id, node.value
        if target_name is None:
            continue
        if target_name == "__test__":
            if isinstance(value, ast.Dict):
                test_map = {
                    k.value: v
                    for k, v in zip(value.keys, value.values)
                    if isinstance(k, ast.Constant)
                }
            continue
        text = _eval_str_value(value, modname)
        if text is not None and ">>>" in text:
            strings[target_name] = text

    sources: list[tuple[str, str]] = []
    if test_map is not None:
        for label, ref in test_map.items():
            if isinstance(ref, ast.Constant) and isinstance(ref.value, str):
                if ">>>" in ref.value:
                    sources.append((str(label), ref.value))
            elif isinstance(ref, ast.Name) and ref.id in strings:
                sources.append((str(label), strings[ref.id]))
    if not sources and "doctests" in strings:
        sources.append(("doctests", strings["doctests"]))
    if not sources:
        # DocTestSuite()-style modules carry their examples in the module
        # docstring (loaded via ``load_tests`` + ``doctest.DocTestSuite()``).
        doc = ast.get_docstring(tree, clean=False)
        if doc and ">>>" in doc:
            sources.append(("__doc__", doc))
    return sources


class _PrintRenamer(ast.NodeTransformer):
    """Route print output into the snippet-local capture buffer.

    Renames ``print(...)`` calls AND bare ``print`` loads (e.g. the
    ``a['print'] = print`` idiom before ``exec(..., a)``) to ``_d_print``,
    since the ambient print is overridden by the guest harness with its own
    capture and would otherwise bypass the buffer on one side only.
    """

    def visit_Call(self, node: ast.Call) -> ast.AST:
        self.generic_visit(node)
        if isinstance(node.func, ast.Name) and node.func.id == "print":
            node.func = ast.Name(id="_d_print", ctx=ast.Load())
        return node

    def visit_Name(self, node: ast.Name) -> ast.AST:
        if node.id == "print" and isinstance(node.ctx, ast.Load):
            return ast.Name(id="_d_print", ctx=ast.Load())
        return node


def _norm_want(want: str) -> str:
    lines = [ln.rstrip() for ln in want.splitlines()]
    while lines and not lines[-1]:
        lines.pop()
    while lines and not lines[0]:
        lines.pop(0)
    lines = ["" if ln.strip() == "<BLANKLINE>" else ln for ln in lines]
    return "\n".join(lines)


_DOCTEST_HELPERS = """\
_d_buf = []
def _d_print(*args, sep=' '):
    _d_buf.append(sep.join(str(a) for a in args))
def _d_clear():
    _d_buf.clear()
def _d_ell_match(want, got):
    parts = want.split('...')
    if len(parts) == 1:
        return want == got
    if not got.startswith(parts[0]) or not got.endswith(parts[-1]):
        return False
    pos = len(parts[0])
    end = len(got) - len(parts[-1])
    for seg in parts[1:-1]:
        idx = got.find(seg, pos)
        if idx < 0 or idx > end:
            return False
        pos = idx + len(seg)
    return True
def _d_check(idx, want, ell=False):
    got = chr(10).join(_d_buf)
    ok = _d_ell_match(want, got) if ell else got == want
    if not ok and want in ('0', '1'):
        # doctest OutputChecker accepts False for 0 and True for 1.
        ok = got == ('False' if want == '0' else 'True')
    assert ok, ('doctest', idx, got, want)
"""


def _exc_ident(exc_msg: str) -> str | None:
    head = exc_msg.partition(":")[0].strip()
    parts = head.split(".")
    if parts and all(p.isidentifier() for p in parts):
        return head
    return None


def _example_stmts(idx: int, example: doctest.Example, stem: str) -> tuple[list[ast.stmt], str | None]:
    """Render one doctest example as snippet statements.

    Returns (statements, quarantine_reason). quarantine_reason is None when
    the example translated cleanly.
    """
    # Expected outputs hardcoding the real module path (e.g. "TypeError:
    # test.test_unpack_ex.f() ..." or reprs like <class 'test.metaclass.B'>)
    # can never match a standalone snippet; quarantine rather than pin a
    # false failure.
    for probe in (example.want, example.exc_msg or ""):
        if f"test_{stem}" in probe or f"test.{stem}" in probe:
            return [], "doctest-module-qualified-expected"
    opts = set(example.options)
    if opts - {doctest.ELLIPSIS} or (opts and example.options.get(doctest.ELLIPSIS) is not True):
        return [], f"doctest-options:{sorted(example.options)}"
    use_ell = doctest.ELLIPSIS in opts
    try:
        # compile() is authoritative: ast.parse accepts constructs real
        # compilation rejects (multiple starred targets, repeated kwargs).
        compile(example.source, "<doctest>", "exec")
    except SyntaxError:
        # Compile-time-invalid source (e.g. pep646 syntax errors): run it
        # through exec() and assert the SyntaxError surfaces.
        src_lit = ast.Constant(value=example.source)
        return [
            ast.Try(
                body=[ast.Expr(value=ast.Call(func=ast.Name(id="exec", ctx=ast.Load()), args=[src_lit], keywords=[])),
                      ast.Raise(exc=ast.Call(func=ast.Name(id="AssertionError", ctx=ast.Load()),
                                             args=[ast.Constant(value=f"ex{idx}: expected SyntaxError")], keywords=[]), cause=None)],
                handlers=[ast.ExceptHandler(type=ast.Name(id="SyntaxError", ctx=ast.Load()), name=None, body=[ast.Pass()])],
                orelse=[], finalbody=[],
            )
        ], None

    parsed = ast.parse(example.source)

    if example.exc_msg is not None:
        exc_name = _exc_ident(example.exc_msg)
        if exc_name is None:
            return [], f"doctest-exc-msg:{example.exc_msg[:60]}"
        expected = _norm_want(example.exc_msg)
        renamer = _PrintRenamer()
        body = [renamer.visit(stmt) for stmt in parsed.body]
        msg_expr: ast.expr = ast.Call(func=ast.Name(id="str", ctx=ast.Load()), args=[ast.Name(id="_d_e", ctx=ast.Load())], keywords=[])
        # str(SyntaxError) appends file/line info that doctest's
        # format_exception_only strips; e.msg is the bare message.
        msg_expr = ast.IfExp(
            test=ast.Call(
                func=ast.Name(id="isinstance", ctx=ast.Load()),
                args=[ast.Name(id="_d_e", ctx=ast.Load()), ast.Name(id="SyntaxError", ctx=ast.Load())],
                keywords=[],
            ),
            body=ast.Attribute(value=ast.Name(id="_d_e", ctx=ast.Load()), attr="msg", ctx=ast.Load()),
            orelse=msg_expr,
        )
        got_exc = ast.BinOp(
            left=ast.Attribute(
                value=ast.Call(func=ast.Name(id="type", ctx=ast.Load()), args=[ast.Name(id="_d_e", ctx=ast.Load())], keywords=[]),
                attr="__name__", ctx=ast.Load(),
            ),
            op=ast.Add(),
            right=ast.IfExp(
                test=ast.Compare(
                    left=msg_expr,
                    ops=[ast.NotEq()],
                    comparators=[ast.Constant(value="")],
                ),
                body=ast.BinOp(left=ast.Constant(value=": "), op=ast.Add(), right=msg_expr),
                orelse=ast.Constant(value=""),
            ),
        )
        if "..." in expected:
            check_test: ast.expr = ast.Call(
                func=ast.Name(id="_d_ell_match", ctx=ast.Load()),
                args=[ast.Constant(value=expected), got_exc], keywords=[],
            )
        else:
            check_test = ast.Compare(left=got_exc, ops=[ast.Eq()], comparators=[ast.Constant(value=expected)])
        return [
            ast.Try(
                body=[ast.Expr(value=ast.Call(func=ast.Name(id="_d_clear", ctx=ast.Load()), args=[], keywords=[])), *list(body)],
                handlers=[ast.ExceptHandler(type=_name_or_attr(exc_name), name="_d_e", body=[ast.Assert(test=check_test, msg=ast.Tuple(elts=[ast.Constant(value=f"doctest-exc{idx}"), ast.Name(id="_d_e", ctx=ast.Load())], ctx=ast.Load()))])],
                orelse=[ast.Raise(exc=ast.Call(func=ast.Name(id="AssertionError", ctx=ast.Load()),
                                               args=[ast.Constant(value=f"ex{idx}: expected {exc_name}")], keywords=[]), cause=None)],
                finalbody=[],
            )
        ], None

    # Output example: reset buffer. Every top-level expression statement
    # appends repr(result), mirroring compile(..., "single") displayhook
    # semantics for multi-statement sources like ``A[*b] = 1; A``.
    renamer = _PrintRenamer()
    want = _norm_want(example.want)
    clear = ast.Expr(value=ast.Call(func=ast.Name(id="_d_clear", ctx=ast.Load()), args=[], keywords=[]))
    out: list[ast.stmt] = [clear]
    if is_expr := (len(parsed.body) == 1 and isinstance(parsed.body[0], ast.Expr)):
        out.append(ast.Assign(
            targets=[ast.Name(id="_d_r", ctx=ast.Store())],
            value=renamer.visit(parsed.body[0].value),
        ))
    else:
        for stmt in parsed.body:
            if isinstance(stmt, ast.Expr):
                out.append(ast.Assign(
                    targets=[ast.Name(id="_d_r", ctx=ast.Store())],
                    value=renamer.visit(stmt.value),
                ))
                out.append(_d_flush_stmt())
            else:
                out.append(renamer.visit(stmt))
    if is_expr and want:
        out.append(_d_flush_stmt())
    if want:
        out.append(ast.Expr(value=ast.Call(
            func=ast.Name(id="_d_check", ctx=ast.Load()),
            args=[ast.Constant(value=idx), ast.Constant(value=want)],
            keywords=[ast.keyword(arg="ell", value=ast.Constant(value=True))] if use_ell else [],
        )))
    return out, None


def _d_flush_stmt() -> ast.stmt:
    """Emit ``if _d_r is not None: _d_buf.append(repr(_d_r))`` (displayhook)."""
    return ast.If(
        test=ast.Compare(
            left=ast.Name(id="_d_r", ctx=ast.Load()),
            ops=[ast.IsNot()],
            comparators=[ast.Constant(value=None)],
        ),
        body=[ast.Expr(value=ast.Call(
            func=ast.Attribute(value=ast.Name(id="_d_buf", ctx=ast.Load()), attr="append", ctx=ast.Load()),
            args=[ast.Call(func=ast.Name(id="repr", ctx=ast.Load()), args=[ast.Name(id="_d_r", ctx=ast.Load())], keywords=[])],
            keywords=[],
        ))],
        orelse=[],
    )


def _name_or_attr(dotted: str) -> ast.expr:
    parts = dotted.split(".")
    node: ast.expr = ast.Name(id=parts[0], ctx=ast.Load())
    for part in parts[1:]:
        node = ast.Attribute(value=node, attr=part, ctx=ast.Load())
    return node


def extract_module_doctests(tree: ast.Module, source: str, modname: str, stem: str) -> Extraction:
    """Convert module-level doctest strings into runnable pins.

    One pin per labeled docstring (preserves doctest's shared-namespace
    execution order); each example becomes an inline buffer/compare block.
    Module-level prelude (imports/classes/functions) is pruned to what the
    examples reference, mirroring the unittest-method path.
    """
    result = Extraction()
    sources = collect_doctest_sources(tree, modname)
    if not sources:
        return result
    parser = doctest.DocTestParser()
    all_bodies: dict[str, list[ast.stmt]] = {}
    for label, text in sources:
        ident = f"{stem}.doctests:{label}"
        examples = parser.get_examples(text)
        if not examples:
            result.quarantined.append(Quarantined(ident, "doctest-no-examples"))
            continue
        helper_stmts = ast.parse(_DOCTEST_HELPERS).body
        body: list[ast.stmt] = list(helper_stmts)
        dropped_bindings: set[str] = set()
        for i, example in enumerate(examples):
            stmts, reason = _example_stmts(i, example, stem)
            try:
                ex_tree = ast.parse(example.source)
            except SyntaxError:
                ex_tree = ast.Module(body=[], type_ignores=[])
            loads = _loaded_names(ex_tree)
            if reason is None and loads & dropped_bindings:
                # A definition this example relies on was dropped; running it
                # would produce a false failure (or mask one).
                reason = f"doctest-depends-on-dropped:{sorted(loads & dropped_bindings)[:4]}"
            if reason is not None:
                # Drop only the offending example; keep the rest of the
                # docstring runnable. Account for it as a per-example
                # quarantine entry.
                result.quarantined.append(Quarantined(f"{ident}.ex{i}", reason))
                dropped_bindings |= _bound_names(ex_tree)
                continue
            body.extend(stmts)
        all_bodies[ident] = body
    if not all_bodies:
        return result
    prelude, prelude_names = collect_prelude(tree, source, include_classes=True)
    # Fixpoint closure over everything the examples reference, including
    # prelude-to-prelude deps (e.g. `tool = Tool()` needs class Tool).
    kept_prelude = _prune_prelude(
        [s for b in all_bodies.values() for s in b], prelude, prelude_names
    )
    for label, text in sources:
        ident = f"{stem}.doctests:{label}"
        body = all_bodies.get(ident)
        if body is None:
            continue
        snippet = render_snippet(body, kept_prelude, needs_re=False, wrap=False)
        result.pinned.append(Pinned(ident, snippet, {}))
    return result


# ---------------------------------------------------------------------------
# Snippet rendering


def _concat_expr(parts: list[ast.expr]) -> ast.expr:
    """left-to-right string concatenation expression."""
    out = parts[0]
    for part in parts[1:]:
        out = ast.BinOp(left=out, op=ast.Add(), right=part)
    return out


def render_snippet(
    body: list[ast.stmt],
    prelude: list[ast.stmt],
    needs_re: bool,
    wrap: bool = True,
    needs_cleanup: bool = False,
) -> str:
    module = ast.Module(body=[], type_ignores=[])
    stmts: list[ast.stmt] = []
    stmts.extend(_parse_helpers(_ORACLE_EMIT_HELPERS))
    if needs_re:
        stmts.append(ast.Import(names=[ast.alias(name="re as _re", asname=None)]))
    if needs_cleanup and wrap:
        stmts.extend(_parse_helpers(_CLEANUP_HELPERS))
    stmts.extend(prelude)
    if not wrap:
        # Doctest pins run at module level: classes/examples must get
        # module-level __qualname__ (doctest execs at globals scope) and
        # repr(class) like "<class '__main__.C'>" must match the oracle.
        stmts.extend(body)
        # Any failure raises and aborts the process (harness reports it);
        # reaching this line means every check passed.
        stmts.append(ast.Expr(value=ast.Call(func=ast.Name(id="_oracle_write", ctx=ast.Load()), args=[ast.Constant(value=_ORACLE_OK)], keywords=[])))
        module.body = stmts
        ast.fix_missing_locations(module)
        return textwrap.dedent(ast.unparse(module)) + "\n"
    stmts.append(
        ast.FunctionDef(
            name="_t",
            args=ast.arguments(
                posonlyargs=[], args=[], vararg=None, kwonlyargs=[],
                kw_defaults=[], kwarg=None, defaults=[],
            ),
            body=body,
            decorator_list=[],
            returns=None,
            type_params=[],
        )
    )
    stmts.append(
        ast.Try(
            body=[ast.Expr(value=ast.Call(func=ast.Name(id="_t", ctx=ast.Load()), args=[], keywords=[]))],
            handlers=[
                ast.ExceptHandler(
                    type=ast.Name(id="BaseException", ctx=ast.Load()),
                    name="_e",
                    body=[
                        ast.Expr(
                            value=ast.Call(
                                func=ast.Name(id="_oracle_write", ctx=ast.Load()),
                                args=[
                                    _concat_expr([
                                        ast.Constant(value=_ORACLE_EXC),
                                        ast.Attribute(
                                            value=ast.Call(
                                                func=ast.Name(id="type", ctx=ast.Load()),
                                                args=[ast.Name(id="_e", ctx=ast.Load())],
                                                keywords=[],
                                            ),
                                            attr="__name__",
                                            ctx=ast.Load(),
                                        ),
                                        ast.Constant(value=" "),
                                        ast.Call(
                                            func=ast.Name(id="repr", ctx=ast.Load()),
                                            args=[
                                                ast.Call(
                                                    func=ast.Name(id="str", ctx=ast.Load()),
                                                    args=[ast.Name(id="_e", ctx=ast.Load())],
                                                    keywords=[],
                                                )
                                            ],
                                            keywords=[],
                                        ),
                                    ])
                                ],
                                keywords=[],
                            )
                        )
                    ],
                )
            ],
            orelse=[ast.Expr(value=ast.Call(func=ast.Name(id="_oracle_write", ctx=ast.Load()), args=[ast.Constant(value=_ORACLE_OK)], keywords=[]))],
            finalbody=(
                [ast.Expr(value=ast.Call(func=ast.Name(id="_run_cleanups", ctx=ast.Load()), args=[], keywords=[]))]
                if needs_cleanup
                else []
            ),
        )
    )
    module.body = stmts
    ast.fix_missing_locations(module)
    text = ast.unparse(module)
    return textwrap.dedent(text) + "\n"


# ---------------------------------------------------------------------------
# Host oracle capture


def capture_host_oracle(snippet: str, cpython_lib: Path) -> dict:
    """Run one snippet under host CPython in a sandboxed subprocess."""
    with tempfile.TemporaryDirectory(prefix="conv_suite_") as td:
        tdp = Path(td)
        script = tdp / "oracle_snippet.py"
        script.write_text(snippet, encoding="utf-8")
        env = {
            "PATH": os.environ.get("PATH", "/usr/bin:/bin"),
            "HOME": str(tdp),
            "PYTHONDONTWRITEBYTECODE": "1",
        }
        # The reference Lib dir must NOT shadow the host stdlib: a version-
        # mismatched pure-Python ``re``/``sre`` on PYTHONPATH aborts with
        # "SRE module mismatch". Append it instead so the host interpreter
        # resolves its own stdlib first and the reference tree only supplies
        # modules the host lacks.
        driver = (
            "import runpy, sys; "
            f"sys.path.append({str(cpython_lib)!r}); "
            f"runpy.run_path({str(script)!r}, run_name='__main__')"
        )
        try:
            proc = subprocess.run(
                [sys.executable, "-c", driver],
                cwd=str(tdp),
                env=env,
                capture_output=True,
                text=True,
                timeout=HOST_TIMEOUT,
            )
        except subprocess.TimeoutExpired:
            return {"status": "timeout"}
        lines = [ln for ln in proc.stdout.splitlines() if ln.strip()]
        if lines and lines[-1].startswith(_ORACLE_OK):
            return {"status": "ok"}
        if lines and lines[-1].startswith(_ORACLE_EXC):
            payload = lines[-1][len(_ORACLE_EXC):]
            exc_type, _, literal = payload.partition(" ")
            try:
                msg = ast.literal_eval(literal)
            except (ValueError, SyntaxError):
                msg = literal
            return {"status": "raised", "exc_type": exc_type, "exc_msg": msg}
        tail = (proc.stderr or proc.stdout or "").strip().splitlines()
        return {
            "status": "error",
            "detail": tail[-1][:200] if tail else f"exit {proc.returncode}",
        }


# ---------------------------------------------------------------------------
# Pin + manifest emission


def _jac_string(text: str) -> str:
    """Escape a Python snippet as a Jac-compatible string literal.

    JSON escapes (\\n, \\", \\\\, \\uXXXX) are accepted by the Jac lexer.
    """
    return json.dumps(text, ensure_ascii=True)


_PIN_HEADER = '''\
# Generated by jac-py/tools/convert_suite.py — DO NOT EDIT BY HAND.
# Output-oracle pins: every snippet replays its CPython Lib/test method on
# jacpython's ceval via layer_p2_libtest and asserts the host-captured
# outcome (host oracle captured at generation time).
import from layer_p2_libtest {{ p2_libtest_run_snippet }}
'''


def emit_pin_file(pins: list[Pinned], source_file: Path) -> str:
    out = [_PIN_HEADER.format(), ""]
    out.append(f'# Source: {source_file.name}\n')
    for pin in pins:
        lit = _jac_string(pin.snippet)
        out.append(f'test "{pin.ident}" {{')
        out.append(f"    (ok, detail) = p2_libtest_run_snippet({lit});")
        out.append('    assert ok , "RUN<" + detail + ">";')
        out.append('    assert detail == "ok" , "GOT<" + detail + ">";')
        out.append("}\n")
    return "\n".join(out)


def write_manifest_entry(stem: str, outdir: Path, pins_file: str, total: int) -> Path:
    doc: dict = {}
    if _MANIFEST.is_file():
        doc = json.loads(_MANIFEST.read_text(encoding="utf-8"))
    else:
        doc = {
            "version": 1,
            "wave": "conv_pipeline",
            "description": "D2 mechanical test-conversion pipeline (convert_suite/diff_runner)",
            "module_count": 0,
            "modules": [],
        }
    rel_pins = str(Path(outdir.relative_to(_REPO)) / pins_file) if outdir.is_relative_to(_REPO) else pins_file
    row = {
        "stem": stem,
        "gate_type": "oracle",
        "status": "converted",
        "oracle_tests": [rel_pins],
        "libtest_snippets": [],
        "notes": f"{total} output-oracle pins generated from CPython Lib/test; run diff_runner to gate.",
        "conversion_meta": str(Path(outdir.relative_to(_REPO)) / "conversion.json")
        if outdir.is_relative_to(_REPO)
        else "conversion.json",
    }
    for i, existing in enumerate(doc["modules"]):
        if existing.get("stem") == stem:
            doc["modules"][i] = row
            break
    else:
        doc["modules"].append(row)
    doc["module_count"] = len(doc["modules"])
    _MANIFEST.write_text(json.dumps(doc, indent=2) + "\n", encoding="utf-8")
    return _MANIFEST


# ---------------------------------------------------------------------------


def _literal_reprable(value: object) -> bool:
    """True when value can round-trip through an ast.Constant literal."""
    if value is None or isinstance(value, (bytes, str, bool, int, float, complex)):
        return True
    if isinstance(value, tuple):
        return all(_literal_reprable(v) for v in value)
    if isinstance(value, frozenset):
        return all(_literal_reprable(v) for v in value)
    return False


def _external_base_context(tree: ast.Module, cpython_lib: Path) -> dict | None:
    """Resolve test vocabulary inherited from a sibling helper module.

    Suites like test_codecencodings_*.py define only concrete TestCase
    classes whose entire ``test_*`` vocabulary lives on a mixin imported
    from the test package (``from test import multibytecodec_support``).
    Mechanically lift that context:

    - parse the helper module so its classes join the class map;
    - rewrite ``helper.TestBase`` attribute bases to plain names;
    - constant-fold class-attribute seeds that call into the helper module
      (``tstring = multibytecodec_support.load_teststring('gb2312')`` reads
      data files no guest sandbox can reach) by evaluating them against the
      helper module executed on the host at generation time.

    Returns None when no external base is involved; mutates ``tree`` in
    place when one is.
    """
    # alias -> helper-module file path under cpython_lib
    aliases: dict[str, Path] = {}
    for node in tree.body:
        if (
            isinstance(node, ast.ImportFrom)
            and node.level == 0
            and node.module
            and (node.module == "test" or node.module.startswith("test."))
        ):
            parts = node.module.split(".")
            for a in node.names:
                if a.name == "*":
                    continue
                stem = cpython_lib.joinpath(*parts, a.name).with_suffix(".py")
                pkg = cpython_lib.joinpath(*parts, a.name, "__init__.py")
                if stem.is_file():
                    aliases[a.asname or a.name] = stem
                elif pkg.is_file():
                    aliases[a.asname or a.name] = pkg
        elif isinstance(node, ast.Import):
            for a in node.names:
                parts = a.name.split(".")
                if parts[0] != "test":
                    continue
                stem = cpython_lib.joinpath(*parts).with_suffix(".py")
                pkg = cpython_lib.joinpath(*parts, "__init__.py")
                if stem.is_file():
                    aliases[a.asname or a.name] = stem
                elif pkg.is_file():
                    aliases[a.asname or a.name] = pkg
    if not aliases:
        return None

    classes = [n for n in tree.body if isinstance(n, ast.ClassDef)]
    used_aliases: set[str] = set()
    for cd in classes:
        for b in cd.bases:
            if isinstance(b, ast.Attribute) and isinstance(b.value, ast.Name):
                used_aliases.add(b.value.id)
        for stmt in _guarded_class_stmts(cd.body):
            value = None
            if isinstance(stmt, ast.Assign) and len(stmt.targets) == 1:
                value = stmt.value
            elif isinstance(stmt, ast.AnnAssign) and stmt.value is not None:
                value = stmt.value
            if value is None:
                continue
            used_aliases |= {
                n.id for n in ast.walk(value)
                if isinstance(n, ast.Name) and n.id in aliases
            }
    used_aliases &= set(aliases)
    if not used_aliases:
        return None

    ext_cmap: dict[str, _ClassInfo] = {}
    ext_classes: dict[str, ast.ClassDef] = {}
    ext_prelude: list[ast.stmt] = []
    host_ns: dict[str, object] = {}
    import contextlib
    import importlib.util

    with contextlib.suppress(Exception), _host_test_package(cpython_lib / "test"):
        for alias in sorted(used_aliases):
            path = aliases[alias]
            text = path.read_text(encoding="utf-8")
            ext_tree = ast.parse(text)
            ext_cmap.update(_module_class_map(ext_tree))
            ext_classes.update({
                n.name: n for n in ext_tree.body if isinstance(n, ast.ClassDef)
            })
            ext_prelude.extend(
                n for n in ext_tree.body if not isinstance(n, ast.ClassDef)
            )
            code = compile(ext_tree, str(path), "exec")
            spec = importlib.util.spec_from_file_location(
                f"_conv_ext_{alias}", path,
            )
            assert spec is not None and spec.loader is not None
            ext_mod = importlib.util.module_from_spec(spec)
            spec.loader.exec_module(ext_mod)  # generation-time host execution only
            host_ns[alias] = ext_mod

    if not host_ns:
        return None

    folded: list[str] = []
    for cd in classes:
        rewritten_bases = []
        for b in cd.bases:
            if (
                isinstance(b, ast.Attribute)
                and isinstance(b.value, ast.Name)
                and b.value.id in host_ns
                and b.attr in ext_cmap
            ):
                rewritten_bases.append(ast.copy_location(
                    ast.Name(id=b.attr, ctx=ast.Load()), b))
            else:
                rewritten_bases.append(b)
        cd.bases = rewritten_bases
        for stmt in _guarded_class_stmts(cd.body):
            value = None
            setter = None
            if isinstance(stmt, ast.Assign) and len(stmt.targets) == 1:
                value, setter = stmt.value, lambda v: setattr(stmt, "value", v)
            elif isinstance(stmt, ast.AnnAssign) and stmt.value is not None:
                value, setter = stmt.value, lambda v: setattr(stmt, "value", v)
            if value is None:
                continue
            refs = {
                n.id for n in ast.walk(value)
                if isinstance(n, ast.Name) and n.id in host_ns
            }
            if not refs:
                continue
            try:
                expr = compile(ast.Expression(body=value), "<seed-fold>", "eval")
                folded_value = eval(expr, dict(host_ns))  # noqa: S307
            except Exception:
                continue
            if not _literal_reprable(folded_value):
                continue
            setter(ast.copy_location(ast.Constant(value=folded_value), value))
            folded.append(f"{cd.name}.{getattr(stmt.targets[0] if isinstance(stmt, ast.Assign) else stmt.target, 'id', '?')}")

    return {
        "prelude": ext_prelude,
        "cmap": ext_cmap,
        "mod_classes": ext_classes,
        "folded_seeds": folded,
    }


class _sys_path_front:
    """Temporarily put ``path`` at sys.path[0]."""

    def __init__(self, path: str) -> None:
        self._path = path

    def __enter__(self) -> None:
        import sys as _sys
        self._sys = _sys
        self._saved = _sys.path[:]
        while self._path in _sys.path:
            _sys.path.remove(self._path)
        _sys.path.insert(0, self._path)

    def __exit__(self, *exc: object) -> None:
        self._sys.path[:] = self._saved


class _host_test_package:
    """Expose the pinned reference tree's ``test`` package to the host
    interpreter for the duration of the block, WITHOUT putting the tree on
    sys.path (that would shadow version-matched stdlib modules like ``re``).
    Only ``test.*`` imports resolve into the reference tree."""

    def __init__(self, pkg_dir: Path) -> None:
        self._pkg_dir = pkg_dir

    def __enter__(self) -> None:
        import importlib.util
        import sys
        init = self._pkg_dir / "__init__.py"
        if not init.is_file():
            raise ImportError(f"no test package at {self._pkg_dir}")
        self._saved = {
            name: sys.modules.get(name)
            for name in list(sys.modules)
            if name == "test" or name.startswith("test.")
        }
        spec = importlib.util.spec_from_file_location(
            "test", init,
            submodule_search_locations=[str(self._pkg_dir)],
        )
        assert spec is not None and spec.loader is not None
        mod = importlib.util.module_from_spec(spec)
        sys.modules[spec.name] = mod
        spec.loader.exec_module(mod)
        # The pinned tree may be newer than the host interpreter; when its
        # support module cannot load here, bind a lazy stub instead. Seed
        # evaluation only needs data-file helpers that never touch support;
        # anything else fails eval and stays unfolded (-> quarantine).
        try:
            import importlib
            importlib.import_module("test.support")
        except Exception:
            import types
            stub = types.ModuleType("test.support")
            def _unavailable(*args: object, **kwargs: object) -> object:
                raise RuntimeError("test.support unavailable on this host")
            stub.__getattr__ = _unavailable  # type: ignore[method-assign]
            sys.modules["test.support"] = stub

    def __exit__(self, *exc: object) -> None:
        import sys
        for name in [
            name for name in sys.modules
            if name == "test" or name.startswith("test.")
        ]:
            saved = self._saved.get(name)
            if saved is None:
                sys.modules.pop(name, None)
            else:
                sys.modules[name] = saved


def run_conversion(source: Path, outdir: Path, name: str, cpython_lib: Path, write_manifest: bool) -> dict:
    command = ["convert_suite.py", str(source), "-o", str(outdir), "--name", name]
    header = attempt_header(command)
    source_text = source.read_text(encoding="utf-8")
    tree = ast.parse(source_text)
    # The skip-decorator constant folder executes the suite's own top-level
    # imports in-process (_host_skip_env); give it the same reference-Lib
    # access the oracle-capture subprocess already has (APPENDED, never
    # shadowing the host stdlib), so harness-gated predicates such as
    # hasattr(resource, 'RLIMIT_FSIZE') fold instead of quarantining.
    if str(cpython_lib) not in sys.path:
        sys.path.append(str(cpython_lib))
    ext_ctx = _external_base_context(tree, cpython_lib)
    extraction = extract_tests(tree, source_text, ext_ctx=ext_ctx)
    doctests = extract_module_doctests(tree, source_text, "__main__", name.removeprefix("conv_"))
    extraction.pinned.extend(doctests.pinned)
    extraction.quarantined.extend(doctests.quarantined)

    meta: dict = {
        **header,
        "source_file": str(source),
        "generator": "jac-py/tools/convert_suite.py",
        "module_stem": name.removeprefix("conv_"),
        "pins_file": f"{name}_pins.jac",
        "pins": [],
        "quarantined": [],
    }

    survivors: list[Pinned] = []
    for pin in extraction.pinned:
        oracle = capture_host_oracle(pin.snippet, cpython_lib)
        if oracle["status"] == "ok":
            pin.oracle = oracle
            survivors.append(pin)
            meta["pins"].append({"ident": pin.ident, "status": "pinned", "oracle": oracle, "snippet": pin.snippet})
        elif oracle["status"] == "timeout":
            meta["pins"].append({"ident": pin.ident, "status": "quarantined", "reason": "host-timeout"})
        elif oracle["status"] == "raised":
            meta["pins"].append(
                {
                    "ident": pin.ident,
                    "status": "quarantined",
                    "reason": f"host-raised:{oracle['exc_type']}: {oracle['exc_msg'][:120]}",
                }
            )
        else:
            meta["pins"].append(
                {"ident": pin.ident, "status": "quarantined", "reason": f"harness-error:{oracle.get('detail', '')[:120]}"}
            )
    for q in extraction.quarantined:
        meta["quarantined"].append({"ident": q.ident, "reason": q.reason})
    meta["counts"] = {
        "extracted": len(extraction.pinned) + len(extraction.quarantined),
        "pinned": len(survivors),
        "quarantined": len(meta["pins"]) - len(survivors) + len(extraction.quarantined),
    }
    # Write-time invariants: the transient class behind a reported
    # counts-vs-entries mismatch (counts.pinned != #status-pinned entries)
    # should fail loudly here instead of poisoning downstream dashboards.
    assert meta["counts"]["pinned"] == sum(
        1 for p in meta["pins"] if p["status"] == "pinned"
    ), f"{name}: counts.pinned != status-pinned entries"
    assert meta["counts"]["extracted"] == len(meta["pins"]) + len(meta["quarantined"]), \
        f"{name}: counts.extracted != pins + quarantined"

    outdir.mkdir(parents=True, exist_ok=True)
    pins_path = outdir / meta["pins_file"]
    pins_path.write_text(emit_pin_file(survivors, source), encoding="utf-8")
    meta["hashes"] = {"pins_jac": file_sha256(pins_path)}
    meta_path = outdir / "conversion.json"
    meta_path.write_text(json.dumps(meta, indent=2) + "\n", encoding="utf-8")

    manifest_path = None
    if write_manifest:
        manifest_path = write_manifest_entry(name.removeprefix("conv_"), outdir, meta["pins_file"], len(survivors))

    return {
        "pins_file": str(pins_path),
        "meta_file": str(meta_path),
        "manifest": str(manifest_path) if manifest_path else None,
        "counts": meta["counts"],
    }


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("cpython_test_file", help="CPython Lib/test .py file (named file)")
    parser.add_argument("-o", "--outdir", default=None, help="output dir (default: jac-py/tests/conv_<stem>)")
    parser.add_argument("--name", default=None, help="conversion name (default: conv_<stem>)")
    parser.add_argument("--cpython-lib", default=str(_DEFAULT_LIB), help="pinned CPython Lib dir")
    parser.add_argument("--no-manifest", action="store_true", help="skip conformance manifest update")
    args = parser.parse_args(argv)

    source = Path(args.cpython_test_file)
    if not source.is_file() or source.suffix != ".py":
        parser.error(f"not a named .py file: {source}")
    stem = source.stem.removeprefix("test_")
    name = args.name or f"conv_{stem}"
    outdir = Path(args.outdir) if args.outdir else _TESTS_DIR / name

    result = run_conversion(source, outdir, name, Path(args.cpython_lib), not args.no_manifest)
    counts = result["counts"]
    print(f"converted {source.name}: {counts['pinned']} pinned, "
          f"{counts['quarantined']} quarantined of {counts['extracted']} extracted")
    print(f"pins:     {result['pins_file']}")
    print(f"meta:     {result['meta_file']}")
    if result["manifest"]:
        print(f"manifest: {result['manifest']}")
    print(f"next: .venv/bin/python jac-py/tools/diff_runner.py {result['pins_file']}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
