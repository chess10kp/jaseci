"""Micro-benchmarks for the Objects/*.c ports: ns per op, best of 5.

Run the same file under the stock C build and the JacPython build of one
CPython version and compare line by line (jacpython-perf.yml does this).
"""
import timeit, sys, types
B = {
 "range_iter":      ("for i in r: pass", "r=range(1000)", 2000),
 "range_neg_iter":  ("for i in r: pass", "r=range(1000,0,-1)", 2000),
 "range_new":       ("range(10)", "", 200000),
 "range_slice":     ("r[1:50:2]", "r=range(100)", 200000),
 "range_index":     ("r[5]", "r=range(100)", 500000),
 "range_contains":  ("50 in r", "r=range(100)", 500000),
 "reversed_range":  ("for i in reversed(r): pass", "r=range(1000)", 2000),
 "range_len":       ("len(r)", "r=range(100)", 500000),
 "slice_new":       ("slice(1,2,3)", "", 500000),
 "list_slice":      ("l[1:5]", "l=list(range(10))", 500000),
 "slice_indices":   ("s.indices(100)", "s=slice(1,50,2)", 300000),
 "enumerate":       ("for i,x in enumerate(l): pass", "l=list(range(1000))", 2000),
 "reversed_list":   ("for x in reversed(l): pass", "l=list(range(1000))", 2000),
 "seqiter":         ("for x in S(): pass", "class S:\n def __getitem__(s,i):\n  if i>=200: raise IndexError\n  return i", 2000),
 "calliter":        ("for x in iter(f, 200): pass", "c=[0]\ndef f():\n c[0]+=1\n return c[0]", 2000),
 "bool_ops":        ("a & b; a | b; a ^ b", "a=True; b=False", 500000),
 "bool_new":        ("bool(x)", "x=5", 500000),
 "bool_repr":       ("repr(a)", "a=True", 500000),
 "closure_cell":    ("f()", "def g():\n x=1\n def f(): return x\n return f\nf=g()", 500000),
 "namespace":       ("types.SimpleNamespace(a=1).a", "import types", 200000),
}
only = sys.argv[1:] or list(B)
for k in only:
    stmt, setup, n = B[k]
    t = min(timeit.repeat(stmt, setup, number=n, repeat=5))
    print(f"{k} {t/n*1e9:.1f}")
