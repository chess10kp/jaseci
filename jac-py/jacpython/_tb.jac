import from product_compile { compile_source }
import from objects { is_error, PyError }
with entry { co=compile_source("def f(blo,bhi):\n    for j in range(blo,bhi):\n        if True:\n            break\n        yield from []\n    yield from []\n","t","exec",0); if is_error(co): e=co as PyError; print("for_break_yf:"+e.exception.message[:50]); else: print("for_break_yf:OK") }