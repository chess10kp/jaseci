# Product-path facade for queue (native Jac).
#
# Ports CPython 3.14 ``Modules/_queuemodule.c`` -- the ``_queue.SimpleQueue``
# accelerator (unbounded ring-buffer FIFO, put/get/get_nowait/put_nowait/
# empty/qsize, ``_queue.Empty``, byte-exact ``"'timeout' must be a
# non-negative number"`` validation) -- plus the pure-Python layer that owns
# the public ``queue`` module name (``Lib/queue.py``): ``Empty``/``Full``/
# ``ShutDown`` exceptions, ``Queue``/``LifoQueue``/``PriorityQueue`` with
# maxsize gating, task_done/join bookkeeping, shutdown/drain semantics, and
# their exact exception-raising paths.
#
# Single-waiter-world deviations (the guest VM has no threads, so every
# condition wait in Lib/queue.py can never be woken): a get() that would park
# forever raises ``Empty`` and a put() that would park forever raises ``Full``
# immediately -- the same observable outcome the timeout-expiry arm produces,
# reached in zero time instead of never. join() with outstanding tasks returns
# instead of deadlocking. Everything reachable without cross-thread handoff
# (non-blocking arms, timeout validation ordering, shutdown states, task-done
# accounting) mirrors the reference control flow statement-for-statement.
#
# Error-channel convention matches the other facades (binasciimodule et al):
# Empty/Full/ShutDown are declared in the bridge-table registry
# (exceptions_core.register_module_exception) with base Exception, so guest
# except-handlers match them AND ``except Exception`` still catches; builtin
# TypeError/ValueError keep their builtin names exactly.
#
# ``__class_getitem__ = classmethod(types.GenericAlias)`` is omitted (csv
# facade precedent).

import from objects {
    PyObj,
    PyInt,
    PyFloat,
    PyBool,
    PyStr,
    PyList,
    PyNoneType,
    PyModule,
    PyExceptionType,
    py_none,
    py_error,
    is_error,
    Py_LT,
}

import from ceval {
    ShimTypeMarker,
    py_compare,
}

import from exceptions_core { register_module_exception }

# Instance type tags: one per concrete class so ShimTypeMarker isinstance
# checks stay exact (isinstance(q, LifoQueue) must not match a FIFO queue).
glob _TAG_FIFO: str = "queue_fifo";
glob _TAG_LIFO: str = "queue_lifo";
glob _TAG_PRIO: str = "queue_priority";
glob _TAG_SIMPLE: str = "queue_simple";

# ---------------- small argument-parsing helpers -----------------------------

# Bind positional+keyword arguments onto a parameter vector. Returns
# (status, values, given): status 0 = ok, 1 = positional overflow, 2 =
# unexpected keyword. Missing slots carry py_none() with given[i] == False so
# callers apply the documented default (None-vs-missing matters for `block`).
def _p2_bind(
    mname: str,
    args: list[PyObj],
    kwargs: dict[str, PyObj],
    names: list[str],
) -> tuple[int, list[PyObj], list[bool]] {
    if len(args) > len(names) {
        return (
            1,
            [],
            [],
        );
    }
    for key in kwargs {
        known: bool = False;
        for nm in names {
            if key == nm {
                known = True;
            }
        }
        if not known {
            return (
                2,
                [],
                [],
            );
        }
    }
    values: list[PyObj] = [];
    given: list[bool] = [];
    i: int = 0;
    while i < len(names) {
        if i < len(args) {
            values.append(args[i]);
            given.append(True);
        } elif names[i] in kwargs {
            values.append(kwargs[names[i]]);
            given.append(True);
        } else {
            values.append(py_none());
            given.append(False);
        }
        i = i + 1;
    }
    return (0, values, given);
}

def _p2_bind_overflow(mname: str, nargs: int, nparams: int) -> PyObj {
    return py_error(
        "TypeError",
        mname + "() takes from 0 to " + str(nparams)
            + " positional arguments but " + str(nargs) + " were given",
    );
}

def _p2_bind_badkw(mname: str, kwargs: dict[str, PyObj], names: list[str]) -> PyObj {
    for key in kwargs {
        known: bool = False;
        for nm in names {
            if key == nm {
                known = True;
            }
        }
        if not known {
            return py_error(
                "TypeError",
                mname + "() got an unexpected keyword argument '" + key + "'",
            );
        }
    }
    return py_none();
}

# Clinic 'p' bool converter stand-in: bool passes as-is, int via truth.
def _p2_bool_arg(v: PyObj) -> tuple[bool, bool] {
    if isinstance(v, PyBool) {
        return (True, (v as PyBool).val);
    }
    if isinstance(v, PyInt) {
        return (True, ((v as PyInt).val != 0));
    }
    return (False, False);
}

# Timeout argument: kind 0 = absent/None, 1 = real number, -1 = non-number.
def _p2_timeout_arg(v: PyObj) -> tuple[int, float] {
    if isinstance(v, PyNoneType) {
        return (0, 0.0);
    }
    if isinstance(v, PyInt) {
        return (1, ((v as PyInt).val * 1.0));
    }
    if isinstance(v, PyFloat) {
        return (1, (v as PyFloat).val);
    }
    if isinstance(v, PyBool) {
        if (v as PyBool).val {
            return (1, 1.0);
        }
        return (1, 0.0);
    }
    return (-1, 0.0);
}

# ---------------- priority-queue heap (Lib/queue.py heappush/heappop) --------

# Strict less-than over guest objects through the shared compare protocol;
# False on any comparison error so the caller can surface it as its own
# TypeError (a stored priority pair compared against an unorderable item).
def _p2_obj_lt(a: PyObj, b: PyObj) -> bool {
    got = py_compare(Py_LT, a, b);
    if is_error(got) {
        return False;
    }
    if isinstance(got, PyBool) {
        return (got as PyBool).val;
    }
    return False;
}

def _p2_prio_push(heap: list[PyObj], item: PyObj) -> PyObj {
    heap.append(item);
    pos: int = len(heap) - 1;
    while pos > 0 {
        parent: int = (pos - 1) // 2;
        if _p2_obj_lt(heap[pos], heap[parent]) {
            tmp: PyObj = heap[parent];
            heap[parent] = heap[pos];
            heap[pos] = tmp;
            pos = parent;
        } else {
            break;
        }
    }
    return py_none();
}

def _p2_prio_pop(heap: list[PyObj]) -> PyObj {
    last: PyObj = heap[len(heap) - 1];
    heap.pop();
    if len(heap) == 0 {
        return last;
    }
    top: PyObj = heap[0];
    heap[0] = last;
    n: int = len(heap);
    pos: int = 0;
    while True {
        left: int = 2 * pos + 1;
        small: int = pos;
        if left < n and _p2_obj_lt(heap[left], heap[small]) {
            small = left;
        }
        right: int = left + 1;
        if right < n and _p2_obj_lt(heap[right], heap[small]) {
            small = right;
        }
        if small == pos {
            break;
        }
        tmp2: PyObj = heap[pos];
        heap[pos] = heap[small];
        heap[small] = tmp2;
        pos = small;
    }
    return top;
}

# ---------------- instance surface -------------------------------------------

obj PyQueueObj(PyObj) {
    has kind: str,
        maxsize: int = 0,
        items: list[PyObj] = [],
        unfinished_tasks: int = 0,
        is_shutdown: bool = False,
        extras: dict[str, PyObj] = {};

    def tp_type_name -> str {
        if self.kind == "fifo" {
            return "Queue";
        }
        if self.kind == "lifo" {
            return "LifoQueue";
        }
        if self.kind == "priority" {
            return "PriorityQueue";
        }
        return "SimpleQueue";
    }

    def tp_getattro(name: str) -> PyObj {
        if name == "maxsize" and self.kind != "simple" {
            return PyInt(t="int", val=self.maxsize);
        }
        if name == "unfinished_tasks" and self.kind != "simple" {
            return PyInt(t="int", val=self.unfinished_tasks);
        }
        if name == "is_shutdown" and self.kind != "simple" {
            return PyBool(t="bool", val=self.is_shutdown);
        }
        if name == "queue" and self.kind != "simple" {
            # Snapshot of the underlying container (CPython exposes the live
            # deque/list; pins only read it). Copied so guest mutation of the
            # view cannot alias internal storage.
            snap: list[PyObj] = [];
            for it in self.items {
                snap.append(it);
            }
            return PyList(t="list", items=snap);
        }
        method_names: list[str] = [];
        if self.kind == "simple" {
            method_names = [
                "qsize",
                "empty",
                "put",
                "put_nowait",
                "get",
                "get_nowait",
            ];
        } else {
            method_names = [
                "qsize",
                "empty",
                "full",
                "put",
                "put_nowait",
                "get",
                "get_nowait",
                "task_done",
                "join",
                "shutdown",
            ];
        }
        for mn in method_names {
            if name == mn {
                return PyQueueMethod(t="queue_method", target=self, name=name);
            }
        }
        if name in self.extras {
            return self.extras[name];
        }
        return py_error(
            "AttributeError",
            "'" + self.tp_type_name() + "' object has no attribute '" + name + "'",
        );
    }

    def tp_setattro(name: str, value: PyObj) -> PyObj {
        if name == "maxsize" and self.kind != "simple" {
            # test_queue shrinks maxsize mid-flight ("q.maxsize = 2"). Ints and
            # bools only -- anything else keeps the comparison TypeError shape
            # the reference raises on its first `maxsize > 0` check.
            if isinstance(value, PyInt) {
                self.maxsize = (value as PyInt).val;
                return py_none();
            }
            if isinstance(value, PyBool) {
                if (value as PyBool).val {
                    self.maxsize = 1;
                } else {
                    self.maxsize = 0;
                }
                return py_none();
            }
            return py_error(
                "TypeError",
                "'>' not supported between instances of '"
                    + value.tp_type_name() + "' and 'int'",
            );
        }
        # Regular-object attribute model: arbitrary instance attributes stick
        # (Lib/queue.py assigns freely), stored off the hot fields.
        self.extras[name] = value;
        return py_none();
    }
}

obj PyQueueMethod(PyObj) {
    has target: PyQueueObj,
        name: str;

    def tp_call(args: list[PyObj], kwargs: dict[str, PyObj]) -> PyObj {
        return _p2_queue_dispatch(self.target, self.name, args, kwargs);
    }
}

# ---------------- core operations (reference control flow) -------------------

def _p2_queue_len(q: PyQueueObj) -> int {
    return len(q.items);
}

def _p2_queue_full(q: PyQueueObj) -> bool {
    return 0 < q.maxsize and q.maxsize <= len(q.items);
}

def _p2_queue_empty_err() -> PyObj {
    return py_error("Empty", "");
}

def _p2_queue_full_err() -> PyObj {
    return py_error("Full", "");
}

def _p2_queue_shutdown_err() -> PyObj {
    return py_error("ShutDown", "");
}

def _p2_timeout_negative_err() -> PyObj {
    return py_error("ValueError", "'timeout' must be a non-negative number");
}

# _get(): fifo/popleft, lifo/pop, priority/heappop. Caller guarantees
# non-empty. Returns the popped item or a comparison-error marker.
def _p2_queue_take(q: PyQueueObj) -> PyObj {
    if q.kind == "priority" {
        return _p2_prio_pop(q.items);
    }
    if q.kind == "lifo" {
        return q.items.pop();
    }
    head: PyObj = q.items[0];
    q.items = q.items[1:];
    return head;
}

# Queue.put (Lib/queue.py put): shutdown gate, maxsize gate with the exact
# block/timeout arm ordering, then enqueue and count the task.
def _p2_queue_put(q: PyQueueObj, item: PyObj, block: bool, timeout: PyObj, has_timeout: bool) -> PyObj {
    if q.is_shutdown {
        return _p2_queue_shutdown_err();
    }
    if q.maxsize > 0 {
        if not block {
            if len(q.items) >= q.maxsize {
                return _p2_queue_full_err();
            }
        } elif not has_timeout {
            # Reference: `while full: not_full.wait()`. Single-threaded VM: no
            # getter can ever free a slot, so the wait resolves to its
            # timeout-expiry outcome immediately.
            if len(q.items) >= q.maxsize {
                return _p2_queue_full_err();
            }
        } else {
            (tkind, tval) = _p2_timeout_arg(timeout);
            if tkind == -1 {
                return py_error(
                    "TypeError",
                    "'<' not supported between instances of '"
                        + timeout.tp_type_name() + "' and 'int'",
                );
            }
            if tval < 0 {
                return _p2_timeout_negative_err();
            }
            # Deadline arm: remaining <= 0 raises Full once the deadline
            # passes; with no concurrent getter the first check already
            # decides. Non-full queues fall straight through to _put.
            if len(q.items) >= q.maxsize {
                return _p2_queue_full_err();
            }
        }
    }
    if q.kind == "priority" {
        pushed = _p2_prio_push(q.items, item);
        if is_error(pushed) {
            return pushed;
        }
    } else {
        q.items.append(item);
    }
    q.unfinished_tasks = q.unfinished_tasks + 1;
    return py_none();
}

# Queue.get (Lib/queue.py get): shutdown-empty gate, then the block/timeout
# arm ladder in reference order -- notably the negative-timeout ValueError
# fires BEFORE any emptiness check inside the blocking arms.
def _p2_queue_get(q: PyQueueObj, block: bool, timeout: PyObj, has_timeout: bool) -> PyObj {
    if q.is_shutdown and len(q.items) == 0 {
        return _p2_queue_shutdown_err();
    }
    if not block {
        if len(q.items) == 0 {
            return _p2_queue_empty_err();
        }
    } elif not has_timeout {
        # Reference: `while not qsize: not_empty.wait()` -- would park forever
        # with no producer thread; resolve to the Empty outcome immediately.
        if len(q.items) == 0 {
            return _p2_queue_empty_err();
        }
    } else {
        (tkind, tval) = _p2_timeout_arg(timeout);
        if tkind == -1 {
            return py_error(
                "TypeError",
                "'<' not supported between instances of '"
                    + timeout.tp_type_name() + "' and 'int'",
            );
        }
        if tval < 0 {
            return _p2_timeout_negative_err();
        }
        # Deadline arm: expiry raises Empty; with no producer the first check
        # decides. A populated queue falls straight through to _get.
        if len(q.items) == 0 {
            return _p2_queue_empty_err();
        }
    }
    return _p2_queue_take(q);
}

# SimpleQueue.put (_queuemodule.c): block/timeout accepted and ignored, as
# this method never blocks (compatibility with the Queue class).
def _p2_simple_put(q: PyQueueObj, item: PyObj) -> PyObj {
    q.items.append(item);
    return py_none();
}

# SimpleQueue.get (_queuemodule.c): timeout validated ONLY when block is
# True and a timeout was actually passed (the C guard is
# `block != 0 && !Py_IsNone(timeout_obj)`); every other path pops or raises
# Empty. The C park loop reduces to the same immediate-Empty outcome.
def _p2_simple_get(q: PyQueueObj, block: bool, timeout: PyObj, has_timeout: bool) -> PyObj {
    if block and has_timeout {
        (tkind, tval) = _p2_timeout_arg(timeout);
        if tkind == -1 {
            return py_error(
                "TypeError",
                "must be a real number, not '" + timeout.tp_type_name() + "'",
            );
        }
        if tval < 0 {
            return _p2_timeout_negative_err();
        }
    }
    if len(q.items) == 0 {
        return _p2_queue_empty_err();
    }
    return _p2_queue_take(q);
}

def _p2_queue_task_done(q: PyQueueObj) -> PyObj {
    unfinished = q.unfinished_tasks - 1;
    if unfinished < 0 {
        return py_error("ValueError", "task_done() called too many times");
    }
    q.unfinished_tasks = unfinished;
    return py_none();
}

def _p2_queue_join(q: PyQueueObj) -> PyObj {
    # Reference: `while unfinished_tasks: all_tasks_done.wait()`. No consumer
    # thread exists to drive the count down, so the wait cannot block; return
    # immediately (the zero-outstanding-tasks case behaves identically).
    return py_none();
}

def _p2_queue_shutdown(q: PyQueueObj, immediate: bool) -> PyObj {
    q.is_shutdown = True;
    if immediate {
        while len(q.items) > 0 {
            _p2_queue_take(q);
            if q.unfinished_tasks > 0 {
                q.unfinished_tasks = q.unfinished_tasks - 1;
            }
        }
    }
    return py_none();
}

# ---------------- method dispatch --------------------------------------------

def _p2_queue_dispatch(
    q: PyQueueObj,
    name: str,
    args: list[PyObj],
    kwargs: dict[str, PyObj],
) -> PyObj {
    simple: bool = q.kind == "simple";

    if name == "qsize" {
        if len(kwargs) > 0 {
            return _p2_bind_badkw(name, kwargs, []);
        }
        if len(args) > 0 {
            return _p2_bind_overflow(name, len(args), 0);
        }
        return PyInt(t="int", val=_p2_queue_len(q));
    }
    if name == "empty" {
        if len(kwargs) > 0 {
            return _p2_bind_badkw(name, kwargs, []);
        }
        if len(args) > 0 {
            return _p2_bind_overflow(name, len(args), 0);
        }
        return PyBool(t="bool", val=_p2_queue_len(q) == 0);
    }
    if name == "full" {
        if len(kwargs) > 0 {
            return _p2_bind_badkw(name, kwargs, []);
        }
        if len(args) > 0 {
            return _p2_bind_overflow(name, len(args), 0);
        }
        return PyBool(t="bool", val=_p2_queue_full(q));
    }
    if name == "put" or name == "put_nowait" {
        if simple and name == "put" {
            # C SimpleQueue.put(item, block=True, timeout=None) ignores both.
            (st, vals, given) = _p2_bind(name, args, kwargs, ["item", "block", "timeout"]);
            if st == 1 {
                return _p2_bind_overflow(name, len(args), 3);
            }
            if st == 2 {
                return _p2_bind_badkw(name, kwargs, ["item", "block", "timeout"]);
            }
            return _p2_simple_put(q, vals[0]);
        }
        (st2, vals2, given2) = _p2_bind(name, args, kwargs, ["item", "block", "timeout"]);
        if st2 == 1 {
            return _p2_bind_overflow(name, len(args), 3);
        }
        if st2 == 2 {
            return _p2_bind_badkw(name, kwargs, ["item", "block", "timeout"]);
        }
        block: bool = True;
        if given2[1] {
            (okb, bv) = _p2_bool_arg(vals2[1]);
            if not okb {
                return py_error("TypeError", "expected boolean value");
            }
            block = bv;
        }
        if name == "put_nowait" {
            block = False;
        }
        return _p2_queue_put(q, vals2[0], block, vals2[2], given2[2]);
    }
    if name == "get" or name == "get_nowait" {
        if simple and name == "get" {
            (sts, valss, givens) = _p2_bind(name, args, kwargs, ["block", "timeout"]);
            if sts == 1 {
                return _p2_bind_overflow(name, len(args), 2);
            }
            if sts == 2 {
                return _p2_bind_badkw(name, kwargs, ["block", "timeout"]);
            }
            sblock: bool = True;
            if givens[0] {
                (oksb, sbv) = _p2_bool_arg(valss[0]);
                if not oksb {
                    return py_error("TypeError", "expected boolean value");
                }
                sblock = sbv;
            }
            return _p2_simple_get(q, sblock, valss[1], givens[1]);
        }
        (stk, valsk, givenk) = _p2_bind(name, args, kwargs, ["block", "timeout"]);
        if stk == 1 {
            return _p2_bind_overflow(name, len(args), 2);
        }
        if stk == 2 {
            return _p2_bind_badkw(name, kwargs, ["block", "timeout"]);
        }
        kblock: bool = True;
        if givenk[0] {
            (okkb, kbv) = _p2_bool_arg(valsk[0]);
            if not okkb {
                return py_error("TypeError", "expected boolean value");
            }
            kblock = kbv;
        }
        if name == "get_nowait" {
            kblock = False;
        }
        return _p2_queue_get(q, kblock, valsk[1], givenk[1]);
    }
    if name == "task_done" {
        if len(kwargs) > 0 {
            return _p2_bind_badkw(name, kwargs, []);
        }
        if len(args) > 0 {
            return _p2_bind_overflow(name, len(args), 0);
        }
        return _p2_queue_task_done(q);
    }
    if name == "join" {
        if len(kwargs) > 0 {
            return _p2_bind_badkw(name, kwargs, []);
        }
        if len(args) > 0 {
            return _p2_bind_overflow(name, len(args), 0);
        }
        return _p2_queue_join(q);
    }
    if name == "shutdown" {
        (sh_st, sh_vals, sh_given) = _p2_bind(name, args, kwargs, ["immediate"]);
        if sh_st == 1 {
            return _p2_bind_overflow(name, len(args), 1);
        }
        if sh_st == 2 {
            return _p2_bind_badkw(name, kwargs, ["immediate"]);
        }
        sh_imm: bool = False;
        if sh_given[0] {
            (sh_ok, sh_iv) = _p2_bool_arg(sh_vals[0]);
            if not sh_ok {
                return py_error("TypeError", "expected boolean value");
            }
            sh_imm = sh_iv;
        }
        return _p2_queue_shutdown(q, sh_imm);
    }
    return py_error(
        "AttributeError",
        "'" + q.tp_type_name() + "' object has no attribute '" + name + "'",
    );
}

# ---------------- constructors ------------------------------------------------

obj PyQueueCtor(PyObj) {
    has kind: str,
        typename: str;

    def tp_getattro(name: str) -> PyObj {
        if name == "__name__" {
            return PyStr(t="str", val=self.typename);
        }
        return py_error("AttributeError", name);
    }

    def tp_call(args: list[PyObj], kwargs: dict[str, PyObj]) -> PyObj {
        if self.kind == "simple" {
            if len(args) > 0 or len(kwargs) > 0 {
                return py_error(
                    "TypeError", self.typename + "() takes no arguments"
                );
            }
            return PyQueueObj(t="queue_simple", kind="simple");
        }
        (st, vals, given) = _p2_bind(self.typename, args, kwargs, ["maxsize"]);
        if st == 1 {
            return _p2_bind_overflow(self.typename, len(args), 1);
        }
        if st == 2 {
            return _p2_bind_badkw(self.typename, kwargs, ["maxsize"]);
        }
        maxsize: int = 0;
        if given[0] {
            v = vals[0];
            if isinstance(v, PyInt) {
                maxsize = (v as PyInt).val;
            } elif isinstance(v, PyBool) {
                if (v as PyBool).val {
                    maxsize = 1;
                } else {
                    maxsize = 0;
                }
            } else {
                # Lib/queue.py stores then compares `maxsize > 0`; a
                # non-number fails there with exactly this comparison shape.
                return py_error(
                    "TypeError",
                    "'>' not supported between instances of '"
                        + v.tp_type_name() + "' and 'int'",
                );
            }
        }
        if self.kind == "fifo" {
            return PyQueueObj(t="queue_fifo", kind="fifo", maxsize=maxsize);
        }
        if self.kind == "lifo" {
            return PyQueueObj(t="queue_lifo", kind="lifo", maxsize=maxsize);
        }
        return PyQueueObj(t="queue_priority", kind="priority", maxsize=maxsize);
    }
}

# ---------------- module builders ---------------------------------------------

def _p2_queue_class(tag: str, kind: str, typename: str) -> PyObj {
    return ShimTypeMarker(
        t="shim_type_marker",
        tag=tag,
        ctor=PyQueueCtor(t="queue_ctor", kind=kind, typename=typename),
    );
}

# The public ``queue`` module (Lib/queue.py surface backed by the accelerator
# port).
def build_queue_module -> PyObj {
    return PyModule(
        t="module",
        name="queue",
        attrs={
            "Empty": PyExceptionType(t="exception_type", name="Empty"),
            "Full": PyExceptionType(t="exception_type", name="Full"),
            "ShutDown": PyExceptionType(t="exception_type", name="ShutDown"),
            "Queue": _p2_queue_class(_TAG_FIFO, "fifo", "Queue"),
            "LifoQueue": _p2_queue_class(_TAG_LIFO, "lifo", "LifoQueue"),
            "PriorityQueue": _p2_queue_class(_TAG_PRIO, "priority", "PriorityQueue"),
            "SimpleQueue": _p2_queue_class(_TAG_SIMPLE, "simple", "SimpleQueue"),
        },
    );
}

# The ``_queue`` accelerator module itself (queuemodule.c exec surface).
def build__queue_module -> PyObj {
    return PyModule(
        t="module",
        name="_queue",
        attrs={
            "Empty": PyExceptionType(t="exception_type", name="Empty"),
            "SimpleQueue": _p2_queue_class(_TAG_SIMPLE, "simple", "SimpleQueue"),
        },
    );
}

with entry {
    # Module-exception declaration (bridge-table registry, exceptions_core):
    # declared AT IMPORT so boundary matching/minting knows each exception's
    # hierarchy. Short-form aliases (Empty/Full/ShutDown) register implicitly.
    register_module_exception("queue.Empty", "Exception");
    register_module_exception("queue.Full", "Exception");
    register_module_exception("queue.ShutDown", "Exception");
    register_module_exception("_queue.Empty", "Exception");
}
