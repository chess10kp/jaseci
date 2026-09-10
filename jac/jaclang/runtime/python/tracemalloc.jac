# Product-path facade for ``_tracemalloc`` (CPython 3.14:
# ``Modules/_tracemalloc.c`` module glue over ``Python/tracemalloc.c``),
# exercised by CPython's ``test_tracemalloc``.
#
# Ported surface -- every function of the C module with its exact semantics:
#   start/stop/is_tracing/clear_traces/get_traceback_limit/
#   get_tracemalloc_memory/get_traced_memory/reset_peak/_get_traces/
#   _get_object_traceback
#
# Divergence (documented like the warnings facade): CPython installs
# PyMem allocator hooks plus a ref tracer to observe live allocations;
# jacpython's ceval has no allocation-hook seam yet. The traced-state
# machine is complete here and driven by explicit notify calls --
# ceval wiring that observes object birth/death should call
# _p2_trace_malloc/_p2_trace_free (mirroring how _PyTraceMalloc_TraceRef
# feeds the same tables). Until wired, start() succeeds and tracing state,
# limits and counters behave exactly like an idle CPython session: no
# blocks recorded, get_traced_memory() == (0, 0), _get_traces() == [].
#
# Raw-trace shape matches what Lib/tracemalloc.py consumes from
# _get_traces(): ``(domain, size, traceback, total_nframe)`` where
# traceback is a tuple of (filename, lineno) pairs.

glob _MAX_NFRAME: int = 65535;  # UINT16_MAX, Python/tracemalloc.c
glob _DEFAULT_DOMAIN: int = 0;

glob _tracing: bool = False;
glob _max_nframe: int = 1;
# (domain, ptr) -> [size, traceback, total_nframe]; ptr identity is the
# allocation site key CPython derives from the object header address.
glob _traces: dict = {};
glob _traced_memory: int = 0;
glob _peak_traced_memory: int = 0;

def is_tracing() -> bool {
    return _tracing;
}

def start(nframe: int = 1) {
    if nframe < 1 or nframe > _MAX_NFRAME {
        raise ValueError(
            f"the number of frames must be in range [1; {_MAX_NFRAME}]"
        );
    }
    if _tracing {
        # hooks already installed: do nothing (CPython keeps the old limit)
        return;
    }
    _max_nframe = nframe;
    _tracing = True;
}

def stop() {
    if not _tracing {
        return;
    }
    _tracing = False;
    _clear_traces_unlocked();
}

def clear_traces() {
    if _tracing {
        _clear_traces_unlocked();
    }
}

def get_traceback_limit() -> int {
    return _max_nframe;
}

def get_tracemalloc_memory() -> int {
    # Bytes held by the internal tables. CPython sums hashtable overhead +
    # item storage; the dict model charges one conservative item stride
    # per trace so the counter moves with real bookkeeping work.
    if not _tracing {
        return 0;
    }
    return len(_traces) * 64;
}

def get_traced_memory() -> tuple {
    if not _tracing {
        return (0, 0);
    }
    return (_traced_memory, _peak_traced_memory);
}

def reset_peak() {
    if _tracing {
        _peak_traced_memory = _traced_memory;
    }
}

def _get_traces() -> list {
    if not _tracing {
        return [];
    }
    traces: list = [];
    for item in _traces.items() {
        domain: int = item[0][0];
        record = item[1];
        traces.append((domain, record[0], record[1], record[2]));
    }
    return traces;
}

def _get_object_traceback(target: any) -> tuple | None {
    if not _tracing {
        return None;
    }
    for item in _traces.items() {
        record = item[1];
        if item[0][0] == _DEFAULT_DOMAIN and record[3] is target {
            return record[1];
        }
    }
    return None;
}

# ---- allocator-hook seam (ceval wiring calls these) ------------------------

def _clear_traces_unlocked() {
    _traces.clear();
    _traced_memory = 0;
    _peak_traced_memory = 0;
}

def _p2_trace_malloc(domain: int, ptr: any, size: int, traceback: tuple = (), total_nframe: int = 0) {
    # Mirrors tracemalloc_trace: record the block under (domain, ptr) and
    # move current/peak. Peak tracking follows CPython exactly: it never
    # decreases inside the hook window.
    _traces[(domain, ptr)] = [size, traceback, total_nframe, ptr];
    _traced_memory += size;
    if _traced_memory > _peak_traced_memory {
        _peak_traced_memory = _traced_memory;
    }
}

def _p2_trace_free(domain: int, ptr: any) {
    record = _traces.pop((domain, ptr), None);
    if record is not None {
        _traced_memory -= record[0];
    }
}
