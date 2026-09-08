# Baseline oracle-exactness for module try + tail shapes (pre/post fix).
import from objects { PyCode }
import from compiler_slice { compile_parsed_exec, oracle_exec }

def check(source: str, label: str) {
    act = compile_parsed_exec(source, "<f>") as PyCode;
    exp = oracle_exec(source, "<f>") as PyCode;
    ok = act.co_code == exp.co_code
        and act.exceptiontable == exp.exceptiontable
        and act.linetable == exp.linetable;
    if ok {
        print(label + ": EXACT");
    } else {
        tag = "DIFF";
        if act.co_code != exp.co_code {
            tag = tag + " code";
        }
        if act.exceptiontable != exp.exceptiontable {
            tag = tag + " extab";
        }
        if act.linetable != exp.linetable {
            tag = tag + " lines";
        }
        print(label + ": " + tag);
    }
}

glob t1 = "try:\n    pass\nexcept ImportError:\n    pass\n",
     t1f = "try:\n    pass\nexcept ImportError:\n    pass\nfinally:\n    pass\n";

with entry {
    check(t1f, "tef alone");
    check(t1f + "x = 1\n", "tef+assign");
    check(t1f + "x = 1\ny = 2\n", "tef+assign2");
    check(t1f + "if x:\n    y = 1\n", "tef+if");
    check(t1f + t1, "tef+try");
    check("try:\n    pass\nfinally:\n    pass\n" + t1, "tf+try");
    check(
        "try:\n    pass\nexcept ImportError:\n    pass\nelse:\n    pass\n" + t1,
        "telse+try"
    );
    check(t1, "try alone");
    check(t1 + "x = 1\n", "try+assign");
    check(t1 + "x = 1\ny = 2\n", "try+assign2");
    check(t1 + "if x:\n    y = 1\n", "try+if");
    check(t1 + "for i in x:\n    y = 1\n", "try+for");
    check(t1 + "with x:\n    y = 1\n", "try+with");
    check(t1 + "def f():\n    pass\n", "try+def");
    check(t1 + "class C:\n    pass\n", "try+class");
    check(t1 + "while x:\n    y = 1\n", "try+while");
    check(t1 + t1, "try+try");
    check("x = 0\n" + t1 + "y = 1\n", "assign+try+assign");
    check("try:\n    x = 1\nexcept ImportError:\n    pass\n" + t1, "trybody+try");
    check("try:\n    pass\nexcept ImportError:\n    x = 1\n" + t1, "tryexcbody+try");
}
