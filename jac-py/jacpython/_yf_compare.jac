import from parser { parse_file }
import from ast_nodes { Module }
import from compiler_validate { validate_module_body }
import from compiler_symtable { build_module_symtable }
import from compiler_codegen { compile_exec }
import from flowgraph { verify_cfg }
import from assembler { assemble }
import from pyc_first { host_compile_marshal, unmarshal, PyCode }

def nested_by_name(co: PyCode, name: str) -> PyCode | None {
    ci = 0;
    while ci < len(co.consts) {
        c = co.consts[ci];
        if isinstance(c, PyCode) and (c as PyCode).co_name == name {
            return c as PyCode;
        }
        ci = ci + 1;
    }
    return None;
}

glob src = "def f():\n    for j in []:\n        yield from []\n        for tag in []:\n            pass\n";

with entry {
    m = parse_file(src, "<probe>");
    body = (m as Module).body;
    vr = validate_module_body(body);
    sr = build_module_symtable(body);
    u = compile_exec(body, "<probe>", "<module>", 1, sr.top);
    if u.diag is not None {
        print("compile diag: " + u.diag.message);
    } else {
        cfg = verify_cfg(u);
        if cfg.diag is not None {
            print("verify: " + cfg.diag.message);
        } else {
            actual = assemble(cfg);
            act_fn = nested_by_name(actual, "f");
            if act_fn is None {
                print("no fn code");
            } else {
                print("actual bytes=" + str(len((act_fn as PyCode).co_code)));
            }
        }
    }
    exp = unmarshal(host_compile_marshal(src, "<probe>", "exec", 0));
    exp_fn = nested_by_name(exp as PyCode, "f");
    if exp_fn is None {
        print("no oracle fn");
    } else {
        print("oracle bytes=" + str(len((exp_fn as PyCode).co_code)));
    }
}
