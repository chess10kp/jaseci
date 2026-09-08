import from parser { parse_file }
import from ast_nodes { Module, FunctionDef, ClassDef }
import from compiler_validate { validate_module_body }
import from compiler_symtable { build_module_symtable }
import from compiler_defs { compile_fn_cfg, sym_function_child }
import from flowgraph { verify_cfg, block_has_dead_code_after_terminator }
import from compiler_diagnostics { internal_compiler_diagnostic }

def dump_fn(name: str, fd: FunctionDef, sym_top: any) -> None {
    sym_fn = sym_function_child(sym_top, name);
    if sym_fn is None {
        print(name + ": no sym");
        return;
    }
    u = compile_fn_cfg(
        name, fd.args, fd.body, fd.lineno, "<probe>", sym_fn, None, None
    );
    bi = 0;
    while bi < len(u.blocks) {
        b = u.blocks[bi];
        if block_has_dead_code_after_terminator(b) {
            print("BAD block " + str(b.id));
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
        }
        bi = bi + 1;
    }
    cfg = verify_cfg(u);
    if cfg.diag is not None {
        d = cfg.diag as internal_compiler_diagnostic;
        print("verify: " + d.message);
    } else {
        print("verify ok");
    }
}

glob src = (
         "class Differ:\n"
         + "    def _fancy_replace(self, a, alo, ahi, b, blo, bhi):\n"
         + "        cruncher = None\n"
         + "        for i, bj in enumerate(b[blo:bhi]):\n"
         + "            best_i = None\n"
         + "            if best_i is None:\n"
         + "                continue\n"
         + "            yield from self._fancy_helper(a, 0, 1, b, 0, 1)\n"
         + "            aelt = a[0]\n"
         + "            for tag, ai1, ai2, bj1, bj2 in []:\n"
         + "                pass\n"
         + "        yield from self._fancy_helper(a, 0, 1, b, 0, 1)\n"
     );

with entry {
    m = parse_file(src, "<probe>");
    body = (m as Module).body;
    validate_module_body(body);
    sr = build_module_symtable(body);
    cls = body[0] as ClassDef;
    fi = 0;
    while fi < len(cls.body) {
        item = cls.body[fi];
        if isinstance(item, FunctionDef) and item.name == "_fancy_replace" {
            dump_fn("_fancy_replace", item as FunctionDef, sr.top);
            break;
        }
        fi = fi + 1;
    }
}
