"""Unit tests for `RcFactsPass`: which function-local lists may carry a
stack-constructed header.

The native backend allocates the `{len, cap, data}` list header in the frame
and keeps only the data buffer on the heap when every binding of a local is a
list display and every use provably keeps the header inside the function
(append/len/subscript/iteration) or is a release point (`del`). Any channel
that could observe the header after the frame dies — return, alias into
another local, user-call argument, closure capture, re-binding from a
non-display value, augmented re-assignment — must refuse the mark so the
backend keeps the plain heap header.

Fixtures: `list_stack_cases.jac`; each function isolates one shape and names
its list `sN` (must stamp) or `nN` (must refuse).
"""

import os;
import from tests.support { TESTS_DIR }
import jaclang;
import from jaclang.compiler.driver.program { JacProgram }
import jaclang.compiler.frontend.unitree as uni;
import from jaclang.compiler.passes.rc_facts_pass { RcFactsPass }
import from jaclang.compiler.driver.pass_driver { run_pass }

glob FIXTURES = os.path.join(TESTS_DIR, "compiler", "passes", "fixtures");

with entry {
    os.environ["JAC_NATIVE_STACK_LIST_HEADERS"] = "1";
}

"""Map every single-target local list binding to its `na_list_stack_ok` mark."""
def list_stack_marks(fixture: str) -> dict[str, bool] {
    prog = JacProgram();
    ir = prog.compile(file_path=str(os.path.join(FIXTURES, fixture)));
    errors = [str(e) for e in prog.errors_had] if prog.errors_had else [];
    assert not prog.errors_had , f"Compilation errors in {fixture}: {errors}";
    run_pass(RcFactsPass, ir, prog);
    out: dict[str, bool] = {};
    for nd in ir.get_all_sub_nodes(uni.Name) {
        sym = nd.sym;
        if sym is not None and sym.defn and (nd in sym.defn) {
            out[nd.value] = sym.na_list_stack_ok;
        }
    }
    return out;
}

test "display-bound locals with header-local uses are marked" {
    marks = list_stack_marks("list_stack_cases.jac");
    assert marks["s1"] , "append/extend/len churn must be marked";
    assert marks["s2"] , "empty display plus append must be marked";
    assert marks["s3"] , "iteration and subscript use must be marked";
    assert marks["s4"] , "re-binding to another display must stay marked";
    assert marks["s5"] , "bare decl then display binding must be marked";
}

test "escape channels refuse the mark" {
    marks = list_stack_marks("list_stack_cases.jac");
    assert not marks["n1"] , "a returned list must refuse";
    assert not marks["n2"] , "alias into another local must refuse";
    assert not marks["n3"] , "user-call argument must refuse";
    assert not marks["n4"] , "re-binding from a call must refuse";
    assert not marks["n5"] , "augmented re-assignment must refuse";
    assert not marks["n6"] , "conditionally re-binding from a call must refuse";
    assert not marks["n7"] , "BoolExpr result aliasing must refuse";
    assert not marks["n8"] , "closure capture must refuse";
}
