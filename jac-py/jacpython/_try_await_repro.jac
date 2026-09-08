# Repro for await-inside-try footer underflow (contextlib __aexit__ shape).
import from product_compile { compile_source }
import from objects { is_error }

glob src = "async def g(a, b):\n    try:\n        await a\n    except StopAsyncIteration:\n        pass\n    await b\n";
with entry {
    r = compile_source(src, "<repro>", "exec", 0);
    if is_error(r) {
        print("ERR: " + str(r));
    } else {
        print("OK");
    }
}
