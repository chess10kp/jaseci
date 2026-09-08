import from parser { parse_file }
import from ast_nodes { Module, FunctionDef }
import from compiler_validate { validate_module_body }
import from compiler_symtable { build_module_symtable }
import from compiler_defs { compile_fn_cfg, sym_function_child }
import from compiler_exc { visit_try }
import from compiler_loops { visit_if, visit_for }
import from compiler_match { visit_match }
import from flowgraph { verify_cfg }

def dump_fn(name: str, fd: FunctionDef, sym_top: any) -> None {
    sym_fn = sym_function_child(sym_top, name);
    if sym_fn is None {
        print(name + ": no sym");
        return;
    }
    u = compile_fn_cfg(
        name, fd.args, fd.body, fd.lineno, "<probe>", sym_fn, None, None
    );
    print("=== " + name + " ===");
    bi = 0;
    while bi < len(u.blocks) {
        b = u.blocks[bi];
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
    cfg = verify_cfg(u);
    if cfg.diag is not None {
        print("verify fail");
    }
}

glob src = (
         "def outer():\n"
         + "    yield from inner()\n"
         + "def inner():\n"
         + "    yield 1\n"
         + "    yield 2\n"
     );

with entry {
    m = parse_file(src, "<probe>");
    body = (m as Module).body;
    validate_module_body(body);
    sr = build_module_symtable(body);
    if sr.top is not None {
        dump_fn("outer", body[0] as FunctionDef, sr.top);
    }
}
