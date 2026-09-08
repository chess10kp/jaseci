import from parser { parse_file }
import from ast_nodes { Module, FunctionDef, ClassDef }
import from compiler_validate { validate_module_body }
import from compiler_symtable { build_module_symtable }
import from compiler_defs { compile_fn_cfg, sym_function_child, sym_class_child }
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
    bad = 0;
    while bi < len(u.blocks) {
        b = u.blocks[bi];
        if block_has_dead_code_after_terminator(b) {
            bad = bad + 1;
            print("BAD block " + str(b.id) + " ninstr=" + str(len(b.instrs)));
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
        }
        bi = bi + 1;
    }
    print("bad blocks: " + str(bad));
    cfg = verify_cfg(u);
    if cfg.diag is not None {
        d = cfg.diag as internal_compiler_diagnostic;
        print("verify: " + d.message);
    } else {
        print("verify ok");
    }
}

with entry {
    src = open("reference/cpython/Lib/difflib.py").read();
    m = parse_file(src, "difflib.py");
    body = (m as Module).body;
    validate_module_body(body);
    sr = build_module_symtable(body);
    ci = 0;
    while ci < len(body) {
        nd = body[ci];
        if isinstance(nd, ClassDef) and nd.name == "Differ" {
            sym_cls = sym_class_child(sr.top, "Differ");
            if sym_cls is None {
                print("no Differ sym");
                break;
            }
            fi = 0;
            while fi < len((nd as ClassDef).body) {
                item = (nd as ClassDef).body[fi];
                if isinstance(item, FunctionDef) and item.name == "_fancy_replace" {
                    dump_fn("_fancy_replace", item as FunctionDef, sym_cls);
                    break;
                }
                fi = fi + 1;
            }
            break;
        }
        ci = ci + 1;
    }
}
