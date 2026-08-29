# Product-path facade for the gc stdlib module (native Jac).
#
# Semantics mirror CPython 3.14 ``Modules/gcmodule.c`` for everything
# expressible against jacpython's runtime API. Implementation lives in
# gc_shim.jac (shared with ceval's import fallback); this module file
# exports the same surface natively so guest ``import gc`` resolves here.

import from objects { PyObj, PyInt, PyList }
import from gc_shim { PyGcFn }

glob enable: PyObj = PyGcFn(t="gc_fn", name="enable") as PyObj;
glob disable: PyObj = PyGcFn(t="gc_fn", name="disable") as PyObj;
glob isenabled: PyObj = PyGcFn(t="gc_fn", name="isenabled") as PyObj;
glob set_debug: PyObj = PyGcFn(t="gc_fn", name="set_debug") as PyObj;
glob get_debug: PyObj = PyGcFn(t="gc_fn", name="get_debug") as PyObj;
glob set_threshold: PyObj = PyGcFn(t="gc_fn", name="set_threshold") as PyObj;
glob get_threshold: PyObj = PyGcFn(t="gc_fn", name="get_threshold") as PyObj;
glob get_count: PyObj = PyGcFn(t="gc_fn", name="get_count") as PyObj;
glob collect: PyObj = PyGcFn(t="gc_fn", name="collect") as PyObj;
glob get_stats: PyObj = PyGcFn(t="gc_fn", name="get_stats") as PyObj;
glob freeze: PyObj = PyGcFn(t="gc_fn", name="freeze") as PyObj;
glob unfreeze: PyObj = PyGcFn(t="gc_fn", name="unfreeze") as PyObj;
glob get_freeze_count: PyObj = PyGcFn(t="gc_fn", name="get_freeze_count") as PyObj;
glob is_tracked: PyObj = PyGcFn(t="gc_fn", name="is_tracked") as PyObj;
glob is_finalized: PyObj = PyGcFn(t="gc_fn", name="is_finalized") as PyObj;
glob get_referents: PyObj = PyGcFn(t="gc_fn", name="get_referents") as PyObj;

glob DEBUG_STATS: int = 1;
glob DEBUG_COLLECTABLE: int = 2;
glob DEBUG_UNCOLLECTABLE: int = 4;
glob DEBUG_SAVEALL: int = 32;
glob DEBUG_LEAK: int = 38;
glob garbage: PyObj = PyList(t="list", items=[]) as PyObj;
glob callbacks: PyObj = PyList(t="list", items=[]) as PyObj;
