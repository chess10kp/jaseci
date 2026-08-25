"""Product-path entry smoke test.

Historically this locked the compiler module-split's loading contract:
compiler_codegen had to finish loading before split-out sibling modules
(compiler_defs/exc/loops/match) bound names from it, because the codegen
late-import block re-entered partially initialized modules on sibling-first
entry. The siblings were merged back into compiler_codegen.jac (breaking
the codegen<->sibling import cycles tracked by p3_import_cycle_gate.py),
so that ordering contract is gone; the test remains as a cheap end-to-end
check that the product entry path compiles a full program.
"""

import from objects { is_error }
import from product_compile { compile_source }


test "split: product-path entry compiles after full sibling graph load" {
    r = compile_source("1 + 2", "<split-ordering>", "eval", 0);
    assert not is_error(r), r;
}
