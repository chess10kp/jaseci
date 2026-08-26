# Product-path facade for heapq (native list algorithms).
# Staged ``jac-py/Modules/_heapqmodule.jac`` remains the C-API hand oracle
# (PyObj stubs) for cc differential tests - not byte-identical to this facade.
# Semantics mirror CPython 3.14 ``Lib/heapq.py`` / ``Modules/_heapqmodule.c``.

def _siftdown(heap: list, startpos: int, pos: int) {
    newitem: any = heap[pos];
    while pos > startpos {
        parentpos = (pos - 1) >> 1;
        parent: any = heap[parentpos];
        if not (newitem < parent) {
            break;
        }
        heap[pos] = parent;
        pos = parentpos;
    }
    heap[pos] = newitem;
}

def _siftup(heap: list, pos: int) {
    endpos = len(heap);
    startpos = pos;
    newitem: any = heap[pos];
    childpos = 2 * pos + 1;
    while childpos < endpos {
        rightpos = childpos + 1;
        if rightpos < endpos and not (heap[childpos] < heap[rightpos]) {
            childpos = rightpos;
        }
        heap[pos] = heap[childpos];
        pos = childpos;
        childpos = 2 * pos + 1;
    }
    heap[pos] = newitem;
    _siftdown(heap, startpos, pos);
}

def _p2_heappush(heap: list, item: any) {
    heap.append(item);
    _siftdown(heap, 0, len(heap) - 1);
}

def _p2_heappop(heap: list) -> any {
    lastelt: any = heap.pop();
    if heap {
        returnitem: any = heap[0];
        heap[0] = lastelt;
        _siftup(heap, 0);
        return returnitem;
    }
    return lastelt;
}

def _p2_heapify(heap: list) {
    n = len(heap);
    i = n // 2;
    while i > 0 {
        i = i - 1;
        _siftup(heap, i);
    }
}

def _p2_heapreplace(heap: list, item: any) -> any {
    returnitem: any = heap[0];
    heap[0] = item;
    _siftup(heap, 0);
    return returnitem;
}

def _p2_heappushpop(heap: list, item: any) -> any {
    if heap and heap[0] < item {
        oldtop: any = heap[0];
        heap[0] = item;
        _siftup(heap, 0);
        return oldtop;
    }
    return item;
}

# ---- max-heap family (heapq.py wrappers over _heapqmodule.c privates) ------

def _siftdown_max(heap: list, startpos: int, pos: int) {
    newitem: any = heap[pos];
    while pos > startpos {
        parentpos = (pos - 1) >> 1;
        parent: any = heap[parentpos];
        if not (parent < newitem) {
            break;
        }
        heap[pos] = parent;
        pos = parentpos;
    }
    heap[pos] = newitem;
}

def _siftup_max(heap: list, pos: int) {
    endpos = len(heap);
    startpos = pos;
    newitem: any = heap[pos];
    childpos = 2 * pos + 1;
    while childpos < endpos {
        rightpos = childpos + 1;
        if rightpos < endpos and not (heap[rightpos] < heap[childpos]) {
            childpos = rightpos;
        }
        heap[pos] = heap[childpos];
        pos = childpos;
        childpos = 2 * pos + 1;
    }
    heap[pos] = newitem;
    _siftdown_max(heap, startpos, pos);
}

def _p2_heappush_max(heap: list, item: any) {
    heap.append(item);
    _siftdown_max(heap, 0, len(heap) - 1);
}

def _p2_heappop_max(heap: list) -> any {
    lastelt: any = heap.pop();
    if heap {
        returnitem: any = heap[0];
        heap[0] = lastelt;
        _siftup_max(heap, 0);
        return returnitem;
    }
    return lastelt;
}

def _p2_heapify_max(heap: list) {
    n = len(heap);
    i = n // 2;
    while i > 0 {
        i = i - 1;
        _siftup_max(heap, i);
    }
}

def _p2_heapreplace_max(heap: list, item: any) -> any {
    returnitem: any = heap[0];
    heap[0] = item;
    _siftup_max(heap, 0);
    return returnitem;
}

def _p2_heappushpop_max(heap: list, item: any) -> any {
    if heap and item < heap[0] {
        oldtop: any = heap[0];
        heap[0] = item;
        _siftup_max(heap, 0);
        return oldtop;
    }
    return item;
}
