import from objects { PyCode }
import from compiler_slice { compile_parsed_exec, oracle_exec }
import from pycode_diff { disassemble_lines }

def dump(tag: str, co: PyCode) {
    print("=== " + tag + " ===");
    for ln in disassemble_lines(co) {
        print(ln);
    }
}

glob src = "try:\n    pass\nexcept ImportError:\n    pass\nfinally:\n    pass\nx = 1\n";
with entry {
    dump("ACTUAL", compile_parsed_exec(src, "<f>") as PyCode);
    dump("ORACLE", oracle_exec(src, "<f>") as PyCode);
}
