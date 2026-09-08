import from parser { parse_file }
import from ast_nodes { Module, FunctionDef }
import from compiler_validate { validate_module_body }
import from compiler_symtable { build_module_symtable }
import from compiler_defs { compile_fn_cfg, sym_function_child }
import from compiler_symtable { sym_block }

glob src = (
         "def f(blo, bhi):\n"
         + "    for j in range(blo, bhi):\n"
         + "        break\n"
         + "    yield from []\n"
     );

with entry {
    m = parse_file(src, "<probe>");
    body = (m as Module).body;
    validate_module_body(body);
    sr = build_module_symtable(body);
    sym_fn = sym_function_child(sr.top, "f");
    if sym_fn is None {
        print("no sym");
    } else {
        fn_sym = sym_fn as sym_block;
        u = compile_fn_cfg(
            "f",
            (body[0] as FunctionDef).args,
            (body[0] as FunctionDef).body,
            1,
            "<probe>",
            fn_sym,
            None,
            None
        );
        bi = 0;
        while bi < len(u.blocks) {
            b = u.blocks[bi];
            print("block " + str(b.id));
            ii = 0;
            while ii < len(b.instrs) {
                ins = b.instrs[ii];
                tgt = "";
                if ins.target_block >= 0 {
                    tgt = " ->" + str(ins.target_block);
                }
                print("  [" + str(ii) + "] op=" + str(ins.opcode) + tgt);
                ii = ii + 1;
            }
            bi = bi + 1;
        }
    }
}
