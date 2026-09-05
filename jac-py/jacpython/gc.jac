# Product-path facade for the gc stdlib surface (native Jac).
# Semantics mirror CPython 3.14 ``Modules/gcmodule.c`` for everything
# expressible against jacpython's runtime API. The collector itself is NOT
# re-implemented -- jacpython containers are refcount/host-GC managed, with no
# generational collector to drive:
#
# - enable/disable/isenabled/set_debug/get_debug/set_threshold/get_threshold
#   manage the same module state CPython keeps (enabled flag, debug bits,
#   generation thresholds); the VM never consults it because nothing in-VM
#   allocates through a generational allocator.
# - collect/get_count/get_stats report the zero-activity steady state that
#   follows from having no in-VM cycle collector: counts stay (0, 0, 0),
#   collect() finds nothing, per-generation stats stay all-zero.
# - freeze/unfreeze/get_freeze_count accept calls but track no objects
#   (CPython's permanent generation has no analogue here), so the frozen
#   count stays 0.
# - is_tracked answers with the native atomic-scalar split (scalars are
#   untracked, everything else tracked) -- matching CPython for common
#   values; the tuple-containing-container refinement is not reproduced.
# - get_referents returns direct referents of native containers only;
#   get_referrers needs a whole-heap reverse scan that no runtime API
#   exposes, so it has no arm (attribute access raises AttributeError).
# - garbage/callbacks are live lists; callbacks never fire (nothing is ever
#   collected) and DEBUG_SAVEALL therefore never appends into garbage.

import from ceval_api { gc_collect_cycles }
import from objects {
    PyObj,
    PyStr,
    PyInt,
    PyBool,
    PyList,
    PyTuple,
    PyDict,
    PySet,
    PyFloat,
    PyBytes,
    PyComplex,
    PyNoneType,
    py_none,
    py_error,
}

glob _gc_enabled: bool = True;
glob _gc_debug: int = 0;
glob _gc_thresholds: list[int] = [700, 10, 10];

obj PyGcFn(PyObj) {
    has name: str;

    def tp_call(args: list[PyObj], kwargs: dict[str, PyObj]) -> PyObj {
        if self.name == "enable" or self.name == "disable" {
            _gc_enabled = self.name == "enable";
            return py_none();
        }
        if self.name == "isenabled" {
            return PyBool(t="bool", val=_gc_enabled);
        }
        if self.name == "set_debug" {
            flags = _gc_int_arg(args, 0);
            if flags is None {
                return py_error("TypeError", "an integer is required");
            }
            _gc_debug = flags;
            return py_none();
        }
        if self.name == "get_debug" {
            return PyInt(t="int", val=_gc_debug);
        }
        if self.name == "set_threshold" {
            t0 = _gc_int_arg(args, 0);
            if t0 is None {
                return py_error("TypeError", "an integer is required");
            }
            _gc_thresholds[0] = t0;
            for slot in [1, 2] {
                if slot >= len(args) or isinstance(args[slot], PyNoneType) {
                    # Omitted or explicit None leaves the generation untouched.
                    continue;
                }
                v = _gc_int_arg(args, slot);
                if v is None {
                    return py_error("TypeError", "an integer is required");
                }
                _gc_thresholds[slot] = v;
            }
            return py_none();
        }
        if self.name == "get_threshold" {
            items: list[PyObj] = [
                PyInt(t="int", val=_gc_thresholds[0]),
                PyInt(t="int", val=_gc_thresholds[1]),
                PyInt(t="int", val=_gc_thresholds[2]),
            ];
            return PyTuple(t="tuple", items=items);
        }
        if self.name == "get_count" {
            zero3: list[PyObj] = [
                PyInt(t="int", val=0),
                PyInt(t="int", val=0),
                PyInt(t="int", val=0),
            ];
            return PyTuple(t="tuple", items=zero3);
        }
        if self.name == "collect" {
            if len(args) > 0 and _gc_int_arg(args, 0) is None {
                return py_error("TypeError", "an integer is required");
            }
            return PyInt(t="int", val=gc_collect_cycles());
        }
        if self.name == "get_stats" {
            stats: list[PyObj] = [];
            for gen in [0, 1, 2] {
                d = PyDict(t="dict", items={});
                d.dict_set(PyStr(t="str", val="collections"), PyInt(t="int", val=0));
                d.dict_set(PyStr(t="str", val="collected"), PyInt(t="int", val=0));
                d.dict_set(PyStr(t="str", val="uncollectable"), PyInt(t="int", val=0));
                stats.append(d as PyObj);
            }
            return PyList(t="list", items=stats);
        }
        if self.name == "freeze" or self.name == "unfreeze" {
            # No permanent generation exists to move objects into/out of.
            return py_none();
        }
        if self.name == "get_freeze_count" {
            return PyInt(t="int", val=0);
        }
        if self.name == "is_tracked" {
            if len(args) != 1 {
                return py_error(
                    "TypeError", "is_tracked() takes exactly one argument"
                );
            }
            probe = args[0];
            tracked = not (
                isinstance(probe, PyStr)
                or isinstance(probe, PyInt)
                or isinstance(probe, PyBool)
                or isinstance(probe, PyFloat)
                or isinstance(probe, PyComplex)
                or isinstance(probe, PyBytes)
                or isinstance(probe, PyNoneType)
            );
            return PyBool(t="bool", val=tracked);
        }
        if self.name == "is_finalized" {
            # Nothing finalizes ahead of deallocation without a cycle pass.
            if len(args) != 1 {
                return py_error(
                    "TypeError", "is_finalized() takes exactly one argument"
                );
            }
            return PyBool(t="bool", val=False);
        }
        if self.name == "get_referents" {
            if len(args) != 1 {
                return py_error(
                    "TypeError", "get_referents() takes exactly one argument"
                );
            }
            refs: list[PyObj] = [];
            target = args[0];
            if isinstance(target, PyList) {
                refs = list((target as PyList).items);
            } elif isinstance(target, PyTuple) {
                refs = list((target as PyTuple).items);
            } elif isinstance(target, PyDict) {
                for hk in (target as PyDict).items {
                    e = (target as PyDict).items[hk];
                    refs.append(e.key);
                    refs.append(e.value);
                }
            } elif isinstance(target, PySet) {
                for hk in (target as PySet).items {
                    refs.append((target as PySet).items[hk]);
                }
            }
            return PyList(t="list", items=refs);
        }
        return py_error("SystemError", "unknown gc function '" + self.name + "'");
    }
}

# Strict int argument read: returns the value when args[idx] is an int (bool
# folds like the int subclass it is), else None so the caller raises
# CPython's clinic TypeError text.
def _gc_int_arg(args: list[PyObj], idx: int) -> int | None {
    if idx >= len(args) {
        return None;
    }
    a = args[idx];
    if isinstance(a, PyBool) {
        return ((a as PyBool).to_index() as PyInt).val;
    }
    if isinstance(a, PyInt) {
        return (a as PyInt).val;
    }
    return None;
}

# Shim-module attribute table consumed by the ceval import sites.
def gc_module_attrs() -> dict[str, PyObj] {
    attrs: dict[str, PyObj] = {};
    for fname in [
        "enable",
        "disable",
        "isenabled",
        "set_debug",
        "get_debug",
        "set_threshold",
        "get_threshold",
        "get_count",
        "collect",
        "get_stats",
        "freeze",
        "unfreeze",
        "get_freeze_count",
        "is_tracked",
        "is_finalized",
        "get_referents",
    ] {
        attrs[fname] = PyGcFn(t="gc_fn", name=fname) as PyObj;
    }
    # Debug flag bits mirror Include/internal/pycore_gc.h exactly.
    attrs["DEBUG_STATS"] = PyInt(t="int", val=1);
    attrs["DEBUG_COLLECTABLE"] = PyInt(t="int", val=2);
    attrs["DEBUG_UNCOLLECTABLE"] = PyInt(t="int", val=4);
    attrs["DEBUG_SAVEALL"] = PyInt(t="int", val=32);
    attrs["DEBUG_LEAK"] = PyInt(t="int", val=38);
    attrs["garbage"] = PyList(t="list", items=[]);
    attrs["callbacks"] = PyList(t="list", items=[]);
    return attrs;
}
