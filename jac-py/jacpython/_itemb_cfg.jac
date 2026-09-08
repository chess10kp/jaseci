# Dump module-unit CFG: blocks in layout order, regions, stack depths.
import from parser { parse_file }
import from ast_nodes { Module }
import from compiler_validate { validate_module_body }
import from compiler_symtable { build_module_symtable }
import from product_compile { compile_source }
import from compiler_codegen { compile_exec }
import from flowgraph {
    calculate_stackdepth,
    layout_next_block,
    layout_pos,
    build_layout_pos,
    find_block
}

def dump_cfg(src: str, label: str) -> None {
    m = parse_file(src, "<probe>");
    body = (m as Module).body;
    validate_module_body(body);
    sr = build_module_symtable(body);
    if sr.top is None {
        print(label + ": no sym");
        return;
    }
    u = compile_exec(body, "<probe>", "<module>", 0, sr.top);
    print("=== " + label + " ===");
    print("--- REGIONS ---");
    ri = 0;
    while ri < len(u.except_regions) {
        rg = u.except_regions[ri];
        print(
            "region "
                + str(rg.start_block)
                + ".."
                + str(rg.end_block)
                + " -> "
                + str(rg.handler_block)
                + " d="
                + str(rg.stack_depth)
        );
        ri = ri + 1;
    }
    (maxd, diag) = calculate_stackdepth(u);
    if diag is not None {
        print("depth calc: " + str(diag));
    } else {
        print("depth calc OK max=" + str(maxd));
    }
    pos = build_layout_pos(u);
    print("--- LAYOUT (with startdepths) ---");
    bi = 0;
    while bi < len(u.blocks) {
        b = u.blocks[bi];
        s = "blk "
            + str(b.id)
            + " placed="
            + str(b.placed)
            + " sd="
            + str(u.block_startdepths[b.id])
            + ":";
        ii = 0;
        while ii < len(b.instrs) {
            ins = b.instrs[ii];
            tgt = "";
            if ins.target_block >= 0 {
                tgt = "->" + str(ins.target_block);
            }
            s = s + " " + str(ins.opcode) + tgt;
            ii = ii + 1;
        }
        nb = layout_next_block(u, layout_pos(pos, b.id));
        s = s + "  [next=" + (str(nb.id) if nb is not None else "None") + "]";
        print(s);
        bi = bi + 1;
    }
}

glob t1 = "try:\n    pass\nexcept ImportError:\n    pass\n";
with entry {
    dump_cfg(t1 + "x = 1\n", "try+x");
}
