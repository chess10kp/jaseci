import from parser { parse_file }
import from ast_nodes { Module }
import from compiler_validate { validate_module_body }
import from compiler_symtable { build_module_symtable }
import from compiler_defs { visit_function_def }
import from compiler_loops { visit_if }
import from flowgraph { verify_cfg }

def dump_cfg(src: str) -> None {
    m = parse_file(src, "<probe>");
    if m is None {
        print("parse fail");
        return;
    }
    body = (m as Module).body;
    vr = validate_module_body(body);
    if vr.diag is not None {
        print("validate fail");
        return;
    }
    sr = build_module_symtable(body);
    if sr.diag is not None {
        print("sym fail");
        return;
    }
    u = compile_exec(body, "<probe>", "<module>", 1, sr.top);
    if u.diag is not None {
        print("compile fail");
        return;
    }
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
    } else {
        print("verify ok");
    }
}

with entry {
    dump_cfg(
        "def m():\n    for x in []:\n        pass\n    if True:\n        for y in []:\n            pass\n"
    );
}
