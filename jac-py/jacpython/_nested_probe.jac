import from parser { parse_file }
import from ast_nodes { Module }
import from compiler_validate { validate_module_body }
import from compiler_symtable { build_module_symtable }
import from compiler_codegen { compile_exec }
import from compiler_defs { visit_function_def }
import from compiler_exc { visit_try }
import from compiler_loops { visit_if, visit_for }
import from compiler_match { visit_match }
import from flowgraph { verify_cfg }

def dump_fn_cfg(src: str) -> None {
    wrapped = "def f():\n" + src;
    m = parse_file(wrapped, "<probe>");
    body = (m as Module).body;
    vr = validate_module_body(body);
    if vr.diag is not None {
        print("validate fail");
        return;
    }
    sr = build_module_symtable(body);
    u = compile_exec(body, "<probe>", "<module>", 1, sr.top);
    if u.diag is not None {
        print("compile diag set");
        return;
    }
    # find nested function code unit - use first FunctionDef's codegen result
    # Instead dump module unit blocks for the f function by compiling inner only
    fn_body = ((body[0]) as FunctionDef).body;
    sr2 = build_function_symtable(((body[0]) as FunctionDef), sr.top);
    fu = compile_function_body(fn_body, "<probe>", "f", sr2, True);
    bi = 0;
    while bi < len(fu.blocks) {
        b = fu.blocks[bi];
        print("block " + str(b.id) + " placed=" + str(b.placed));
        ii = 0;
        while ii < len(b.instrs) {
            ins = b.instrs[ii];
            tgt = "";
            if ins.target_block >= 0 {
                tgt = " ->" + str(ins.target_block);
            }
            print("  op=" + str(ins.opcode) + tgt);
            ii = ii + 1;
        }
        bi = bi + 1;
    }
    cfg = verify_cfg(fu);
    if cfg.diag is not None {
        print("verify fail");
    } else {
        print("verify ok");
    }
}

with entry {
    dump_fn_cfg(
        "    for j in []:\n"
            + "        yield from []\n"
            + "        for tag in []:\n"
            + "            pass\n"
    );
}
