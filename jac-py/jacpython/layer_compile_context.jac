# Per-compilation context pins (PLAN.md Phase 3 / #4).
#
# Verifies failed-then-valid, nested/reentrant, and repeated product compiles
# leave no product_compile_active residue or pending_break_finishes leakage.

import from objects { PyCode, PyError, is_error }
import from product_compile { compile_source }
import from compiler_context {
    enter_compile_context,
    exit_compile_context,
    product_compile_active,
}

test "compile context: product path flag starts clear" {
    assert not product_compile_active();
}

test "compile context: failed then valid leaves flag clear" {
    bad = compile_source("1+", "<bad>", "eval", 0);
    assert is_error(bad);
    assert isinstance(bad, PyError);
    assert not product_compile_active();
    good = compile_source("1+1", "<good>", "eval", 0);
    assert not is_error(good);
    assert isinstance(good, PyCode);
    assert not product_compile_active();
}

test "compile context: exec parse error then valid loop compile" {
    bad = compile_source("while True\n    break\n", "<bad>", "exec", 0);
    assert is_error(bad);
    assert not product_compile_active();
    good = compile_source("while True:\n    break\n", "<loop>", "exec", 0);
    assert not is_error(good);
    assert isinstance(good, PyCode);
    assert not product_compile_active();
}

test "compile context: repeated compilation stays clean" {
    i = 0;
    while i < 8 {
        co = compile_source(str(i) + "+" + str(i), "<rep>", "eval", 0);
        assert not is_error(co);
        assert isinstance(co, PyCode);
        i = i + 1;
    }
    assert not product_compile_active();
}

test "compile context: nested active contexts survive inner compile" {
    enter_compile_context();
    assert product_compile_active();
    inner = compile_source("2+2", "<inner>", "eval", 0);
    assert not is_error(inner);
    assert product_compile_active();
    exit_compile_context();
    assert not product_compile_active();
}

test "compile context: failed inner compile under outer context" {
    enter_compile_context();
    bad = compile_source("return 1\n", "<bad-exec>", "exec", 0);
    assert is_error(bad);
    assert product_compile_active();
    good = compile_source("x = 1\n", "<good-exec>", "exec", 0);
    assert not is_error(good);
    exit_compile_context();
    assert not product_compile_active();
}
