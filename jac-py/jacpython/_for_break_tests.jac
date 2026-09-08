import from product_compile { compile_source }
import from objects { is_error, PyError }

glob tests = [
         (
             "break_assign",
             "def f(blo, bhi):\n"
                 + "    for j in range(blo, bhi):\n"
                 + "        if True:\n"
                 + "            break\n"
                 + "        yield from []\n"
                 + "    x = 1\n"
         ),
         (
             "break_yield",
             "def f(blo, bhi):\n"
                 + "    for j in range(blo, bhi):\n"
                 + "        if True:\n"
                 + "            break\n"
                 + "        yield from []\n"
                 + "    yield from []\n"
         ),
         (
             "break_return",
             "def f(blo, bhi):\n"
                 + "    for j in range(blo, bhi):\n"
                 + "        if True:\n"
                 + "            break\n"
                 + "    return None\n"
         ),

     ];

with entry {
    ti = 0;
    while ti < len(tests) {
        (label, src) = tests[ti];
        co = compile_source(src, "t", "exec", 0);
        if is_error(co) {
            e = co as PyError;
            print(label + ":" + e.exception.message);
        } else {
            print(label + ":OK");
        }
        ti = ti + 1;
    }
}
