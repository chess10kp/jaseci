import from parser { parse_file }
import from ast_nodes { Module, FunctionDef }
import from compiler_validate { validate_module_body }
import from compiler_symtable { build_module_symtable, sym_block }
import from compiler_defs { compile_fn_cfg, sym_function_child }
import from flowgraph { verify_cfg, block_has_dead_code_after_terminator }
import from compiler_diagnostics { internal_compiler_diagnostic }

def dump_fn(fd: FunctionDef, sym_top: any) -> None {
    sym_fn = sym_function_child(sym_top, fd.name);
    if sym_fn is None {
        print("no sym");
        return;
    }
    fn_sym = sym_fn as sym_block;
    u = compile_fn_cfg(
        fd.name, fd.args, fd.body, fd.lineno, "<probe>", fn_sym, None, None
    );
    bi = 0;
    while bi < len(u.blocks) {
        b = u.blocks[bi];
        print("block " + str(b.id) + " n=" + str(len(b.instrs)));
        ii = 0;
        while ii < len(b.instrs) {
            ins = b.instrs[ii];
            mark = "";
            if ins.target_block >= 0 {
                mark = " ->" + str(ins.target_block);
            }
            dead = "";
            if block_has_dead_code_after_terminator(b) {
                dead = " DEAD";
            }
            print("  [" + str(ii) + "] op=" + str(ins.opcode) + mark + dead);
            ii = ii + 1;
        }
        bi = bi + 1;
    }
}

glob src = (
         "def f(blo, bhi):\n"
         + "    for j in range(blo, bhi):\n"
         + "        if True:\n"
         + "            break\n"
         + "        yield from []\n"
         + "    yield from []\n"
     );

with entry {
    m = parse_file(src, "<probe>");
    body = (m as Module).body;
    validate_module_body(body);
    sr = build_module_symtable(body);
    dump_fn(body[0] as FunctionDef, sr.top);
}
