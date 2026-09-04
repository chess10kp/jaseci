# Guest-facing ``array`` module facade (native Jac).
#
# ``import array`` in guest code resolves here through the ceval shim
# registry (build site: ceval.import_native/host_import). A proxied HOST
# array loses every VM-level slot -- `a[:] = a`, `a += a`, item assignment --
# which is exactly how the converted test_array pins failed before this
# facade existed ("object does not support item assignment").
#
# Storage and per-typecode pack/unpack semantics live in arrayobject.jac
# (the wave-14 product facade mirroring Modules/arraymodule.c on LP64).
# This module carries only the substrate boundary: PyObj wrappers that
# route the full CPython surface (construction, sequence protocol, methods,
# richcompare, add/mul binops, in-place ops) onto live Array instances, so
# arrays never cross the host bridge. Native raises inside the core convert
# to PyError at the wrapper edge -- the eval loop can only recover errors
# carried as values.

import from objects {
    PyObj,
    PyStr,
    PyInt,
    PyFloat,
    PyBool,
    PyBytes,
    PyTuple,
    PyList,
    PySet,
    PySlice,
    PySeqIter,
    PyIter,
    PyNoneType,
    PY_NOT_IMPLEMENTED,
    Py_LT,
    Py_LE,
    Py_EQ,
    Py_NE,
    Py_GT,
    Py_GE,
    is_error,
    py_none,
    py_error,
}
import from opcode_meta {
    NB_ADD,
    NB_MULTIPLY,
    NB_INPLACE_ADD,
    NB_INPLACE_MULTIPLY,
}
import from arrayobject {
    Array,
    _p2_array,
    _tc_is_int,
}


# ---------------------------------------------------------------------------
# Boundary conversions
# ---------------------------------------------------------------------------

def _arr_item_of(v: PyObj) -> any {
    # Guest scalar -> native scalar. Anything opaque passes through; the
    # Array item validators raise CPython-pinned TypeErrors for it.
    if isinstance(v, PyBool) {
        return (v as PyBool).val;
    }
    if isinstance(v, PyInt) {
        return (v as PyInt).val;
    }
    if isinstance(v, PyFloat) {
        return (v as PyFloat).val;
    }
    if isinstance(v, PyStr) {
        return (v as PyStr).val;
    }
    if isinstance(v, PyNoneType) {
        return None;
    }
    return v;
}

def _arr_item_py(v: any) -> PyObj {
    # Native unpacked item -> guest scalar. Array items are always
    # int/float/str by construction of the descriptor table.
    if isinstance(v, str) {
        return PyStr(t="str", val=v);
    }
    if isinstance(v, float) {
        return PyFloat(t="float", val=v);
    }
    return PyInt(t="int", val=v);
}

def _arr_wrap(v: any) -> PyObj {
    # Native result -> guest value. Array-valued results (slicing, concat)
    # wrap back into this facade so mutation stays VM-native.
    if isinstance(v, Array) {
        return _arr_new_wrapper(v);
    }
    if isinstance(v, bool) {
        return PyBool(t="bool", val=v);
    }
    if isinstance(v, int) {
        return PyInt(t="int", val=v);
    }
    if isinstance(v, float) {
        return PyFloat(t="float", val=v);
    }
    if isinstance(v, str) {
        return PyStr(t="str", val=v);
    }
    if isinstance(v, bytes) {
        vals: list[int] = [];
        for b in v {
            vals.append(b);
        }
        return PyBytes(t="bytes", val=vals);
    }
    if isinstance(v, list) {
        items: list[PyObj] = [];
        for x in v {
            items.append(_arr_item_py(x));
        }
        return PyList(t="list", items=items);
    }
    if isinstance(v, tuple) {
        items2: list[PyObj] = [];
        for x2 in v {
            items2.append(_arr_item_py(x2));
        }
        return PyTuple(t="tuple", items=items2);
    }
    return py_none();
}

def _arr_new_wrapper(a: Array) -> PyArrayObj {
    w = PyArrayObj(t="array");
    w.arr = a;
    return w;
}

# Drain a guest iterable into native scalars. Covers the shapes the array
# surface legitimately receives (list/tuple/set/str/bytes/range/iterators/
# other arrays); generators and arbitrary user iterables stay residual.
def _arr_drain(v: PyObj) -> any {
    out: list[any] = [];
    if isinstance(v, PyList) or isinstance(v, PyTuple) or isinstance(v, PySet) {
        for item in (v as PyList).items {
            out.append(_arr_item_of(item));
        }
        return out;
    }
    if isinstance(v, PyBytes) {
        for b2 in (v as PyBytes).val {
            out.append(b2);
        }
        return out;
    }
    if isinstance(v, PyStr) {
        s: str = (v as PyStr).val;
        for ch in s {
            out.append(ch);
        }
        return out;
    }
    if v.t == "range" {
        # Tag-keyed (PyRange lives in ceval; importing it here would close a
        # cycle). Fields come through the attribute slot.
        start = _arr_attr_int(v, "start");
        stop = _arr_attr_int(v, "stop");
        step = _arr_attr_int(v, "step");
        cur: int = start;
        if step > 0 {
            while cur < stop {
                out.append(cur);
                cur += step;
            }
        } else {
            while cur > stop {
                out.append(cur);
                cur += step;
            }
        }
        return out;
    }
    if isinstance(v, PyArrayObj) {
        src: Array = (v as PyArrayObj).arr as Array;
        n = src._n_items();
        i: int = 0;
        while i < n {
            out.append(src._unpack_at(i));
            i += 1;
        }
        return out;
    }
    if v.t == "iter" {
        it = v as PyIter;
        idx = it.index;
        while idx < len(it.items) {
            out.append(_arr_item_of(it.items[idx]));
            idx += 1;
        }
        return out;
    }
    if v.t == "seqiter" {
        seq = (v as PySeqIter).seq;
        pos = (v as PySeqIter).index;
        while True {
            got = seq.mp_subscript(PyInt(t="int", val=pos));
            if is_error(got) {
                break;
            }
            out.append(_arr_item_of(got));
            pos += 1;
        }
        return out;
    }
    return py_error(
        "TypeError", "'" + v.tp_type_name() + "' object is not iterable"
    );
}

def _arr_attr_int(v: PyObj, name: str) -> int {
    a = v.tp_getattro(name);
    if is_error(a) or not isinstance(a, PyInt) {
        return 0;
    }
    return (a as PyInt).val;
}


# ---------------------------------------------------------------------------
# Construction (Modules/arraymodule.c array_new)
# ---------------------------------------------------------------------------

obj PyArrayCtor(PyObj) {

    def tp_hashkey -> PyObj {
        # Identity hash (builtin-style callable).
        return PyStr(t="str", val="obj:" + str(id(self)));
    }

    def tp_call(args: list[PyObj], kwargs: dict[str, PyObj]) -> PyObj {
        if len(kwargs) > 0 {
            return py_error("TypeError", "array() takes no keyword arguments");
        }
        if len(args) == 0 {
            return py_error(
                "TypeError", "array() missing required argument 'typecode' (pos 1)"
            );
        }
        if len(args) > 2 {
            return py_error(
                "TypeError",
                "array expected at most 2 arguments, got " + str(len(args)),
            );
        }
        try {
            tc_native: any = _arr_item_of(args[0]);
            init_native: any = None;
            if len(args) == 2 {
                raw = args[1];
                # str/bytes initializers keep their native shape so
                # array_new's per-typecode validation sees exactly what
                # CPython sees ("cannot use a str to initialize an array
                # with typecode 'i'" etc).
                if isinstance(raw, PyStr) {
                    init_native = (raw as PyStr).val;
                } elif isinstance(raw, PyBytes) {
                    init_native = bytes((raw as PyBytes).val);
                } else {
                    drained = _arr_drain(raw);
                    if not isinstance(drained, list) {
                        return drained as PyObj;
                    }
                    init_native = drained;
                }
            }
            if len(args) == 2 {
                return _arr_wrap(_p2_array(tc_native, init_native));
            }
            return _arr_wrap(_p2_array(tc_native));
        } except BaseException as e {
            return py_error(type(e).__name__, str(e));
        }
    }
}


# ---------------------------------------------------------------------------
# Instance surface
# ---------------------------------------------------------------------------

glob _ARRAY_METHODS: list[str] = [
    "append", "extend", "insert", "pop", "remove", "index", "count",
    "reverse", "tobytes", "frombytes", "fromlist", "tolist", "fromunicode",
    "tounicode", "buffer_info", "byteswap", "fromfile", "tofile",
    "__copy__", "__deepcopy__", "__len__", "__iter__", "__getitem__",
    "__setitem__", "__delitem__", "__repr__", "__eq__", "__add__", "__mul__",
];

def _is_array_method(name: str) -> bool {
    for m in _ARRAY_METHODS {
        if m == name {
            return True;
        }
    }
    return False;
}

obj PyArrayMethod(PyObj) {
    has target: PyArrayObj,
        name: str;

    def tp_call(args: list[PyObj], kwargs: dict[str, PyObj]) -> PyObj {
        if len(kwargs) > 0 {
            return py_error(
                "TypeError", self.name + "() takes no keyword arguments"
            );
        }
        try {
            return self._dispatch(args);
        } except BaseException as e {
            return py_error(type(e).__name__, str(e));
        }
    }

    def _need(args: list[PyObj], lo: int, hi: int) -> any {
        if len(args) < lo or len(args) > hi {
            span: str = str(lo);
            if lo != hi {
                span = str(lo) + " to " + str(hi);
            }
            return py_error(
                "TypeError",
                self.name + "() takes " + span
                + " arguments but " + str(len(args)) + " were given",
            );
        }
        return False;
    }

    def _dispatch(args: list[PyObj]) -> PyObj {
        a: Array = self.target.arr as Array;
        n = self.name;
        if n == "append" {
            chk = self._need(args, 1, 1);
            if not isinstance(chk, bool) {
                return chk as PyObj;
            }
            a.append(_arr_item_of(args[0]));
            return py_none();
        }
        if n == "extend" {
            chk2 = self._need(args, 1, 1);
            if not isinstance(chk2, bool) {
                return chk2 as PyObj;
            }
            drained = _arr_drain(args[0]);
            if not isinstance(drained, list) {
                return drained as PyObj;
            }
            for v in drained {
                a._append_value(v);
            }
            return py_none();
        }
        if n == "insert" {
            chk3 = self._need(args, 2, 2);
            if not isinstance(chk3, bool) {
                return chk3 as PyObj;
            }
            a.insert(_arr_item_of(args[0]), _arr_item_of(args[1]));
            return py_none();
        }
        if n == "pop" {
            chk4 = self._need(args, 0, 1);
            if not isinstance(chk4, bool) {
                return chk4 as PyObj;
            }
            if len(args) == 1 {
                return _arr_wrap(a.pop(_arr_item_of(args[0])));
            }
            return _arr_wrap(a.pop(None));
        }
        if n == "remove" {
            chk5 = self._need(args, 1, 1);
            if not isinstance(chk5, bool) {
                return chk5 as PyObj;
            }
            a.remove(_arr_item_of(args[0]));
            return py_none();
        }
        if n == "index" {
            chk6 = self._need(args, 1, 3);
            if not isinstance(chk6, bool) {
                return chk6 as PyObj;
            }
            start: any = None;
            stop: any = None;
            if len(args) >= 2 {
                start = _arr_item_of(args[1]);
            }
            if len(args) >= 3 {
                stop = _arr_item_of(args[2]);
            }
            return _arr_wrap(a.index(_arr_item_of(args[0]), start, stop));
        }
        if n == "count" {
            chk7 = self._need(args, 1, 1);
            if not isinstance(chk7, bool) {
                return chk7 as PyObj;
            }
            return _arr_wrap(a.count(_arr_item_of(args[0])));
        }
        if n == "reverse" {
            a.reverse();
            return py_none();
        }
        if n == "tobytes" {
            return _arr_wrap(a.tobytes());
        }
        if n == "tolist" {
            return _arr_wrap(a.tolist());
        }
        if n == "tounicode" {
            return _arr_wrap(a.tounicode());
        }
        if n == "frombytes" {
            chk8 = self._need(args, 1, 1);
            if not isinstance(chk8, bool) {
                return chk8 as PyObj;
            }
            buf = args[0];
            if not isinstance(buf, PyBytes) {
                return py_error(
                    "TypeError",
                    "a bytes-like object is required, not '"
                    + buf.tp_type_name() + "'",
                );
            }
            payload: bytes = bytes((buf as PyBytes).val);
            a.frombytes(payload);
            return py_none();
        }
        if n == "fromlist" {
            chk9 = self._need(args, 1, 1);
            if not isinstance(chk9, bool) {
                return chk9 as PyObj;
            }
            drained2 = _arr_drain(args[0]);
            if not isinstance(drained2, list) {
                return drained2 as PyObj;
            }
            a.fromlist(drained2);
            return py_none();
        }
        if n == "fromunicode" {
            chk10 = self._need(args, 1, 1);
            if not isinstance(chk10, bool) {
                return chk10 as PyObj;
            }
            if not isinstance(args[0], PyStr) {
                return py_error(
                    "TypeError",
                    "fromunicode() argument must be str, not "
                    + args[0].tp_type_name(),
                );
            }
            a.fromunicode((args[0] as PyStr).val);
            return py_none();
        }
        if n == "buffer_info" {
            info: list[PyObj] = [
                PyInt(t="int", val=0),
                PyInt(t="int", val=a._n_items()),
            ];
            return PyTuple(t="tuple", items=info);
        }
        if n == "byteswap" {
            a.byteswap();
            return py_none();
        }
        if n == "fromfile" or n == "tofile" {
            return self._file_bridge(a, args);
        }
        if n == "__copy__" or n == "__deepcopy__" {
            # Items are immutable scalars: copy == deepcopy for arrays.
            return _arr_wrap(_p2_array(a.typecode, a));
        }
        if n == "__len__" {
            return PyInt(t="int", val=a._n_items());
        }
        if n == "__iter__" {
            return self.target.tp_iter();
        }
        if n == "__getitem__" {
            return self.target.mp_subscript(args[0]);
        }
        if n == "__setitem__" {
            chk11 = self._need(args, 2, 2);
            if not isinstance(chk11, bool) {
                return chk11 as PyObj;
            }
            return self.target.mp_ass_subscript(args[0], args[1]);
        }
        if n == "__delitem__" {
            chk12 = self._need(args, 1, 1);
            if not isinstance(chk12, bool) {
                return chk12 as PyObj;
            }
            return self.target.mp_del_subscript(args[0]);
        }
        if n == "__repr__" {
            return PyStr(t="str", val=a.__repr__());
        }
        if n == "__eq__" {
            other = args[0];
            if isinstance(other, PyArrayObj) {
                eqv: bool = a.__eq__((other as PyArrayObj).arr as Array);
                return PyBool(t="bool", val=eqv);
            }
            return PyBool(t="bool", val=False);
        }
        if n == "__add__" {
            other2 = args[0];
            if isinstance(other2, PyArrayObj) {
                return _arr_wrap(a.__add__((other2 as PyArrayObj).arr as Array));
            }
            return py_error(
                "TypeError",
                'can only append array (not "' + other2.tp_type_name()
                + '") to array',
            );
        }
        if n == "__mul__" {
            return _arr_wrap(a.__mul__(_arr_item_of(args[0])));
        }
        return py_error("AttributeError", n);
    }

    def _file_bridge(a: Array, args: list[PyObj]) -> PyObj {
        n = self.name;
        want_n: int = 2;
        if n == "tofile" {
            want_n = 1;
        }
        if len(args) != want_n {
            return py_error(
                "TypeError",
                n + "() takes exactly " + str(want_n) + " arguments",
            );
        }
        f = args[0];
        if n == "tofile" {
            write_m = f.tp_getattro("write");
            if is_error(write_m) {
                return py_error(
                    "TypeError",
                    "'" + f.tp_type_name() + "' object has no attribute 'write'",
                );
            }
            payload2: bytes = a.tobytes();
            blob: list[int] = [];
            for b3 in payload2 {
                blob.append(b3);
            }
            r = (write_m as PyObj).tp_call([PyBytes(t="bytes", val=blob)], {});
            if is_error(r) {
                return r;
            }
            return py_none();
        }
        count = _arr_item_of(args[1]);
        if not isinstance(count, int) {
            return py_error(
                "TypeError", "an integer is required"
            );
        }
        read_m = f.tp_getattro("read");
        if is_error(read_m) {
            return py_error(
                "TypeError",
                "'" + f.tp_type_name() + "' object has no attribute 'read'",
            );
        }
        want = count * a.itemsize;
        got = (read_m as PyObj).tp_call([PyInt(t="int", val=want)], {});
        if is_error(got) {
            return got;
        }
        if not isinstance(got, PyBytes) {
            raise EOFError("read() didn't return enough bytes");
        }
        vals: list[int] = (got as PyBytes).val;
        size: int = len(vals);
        complete: int = size - (size % a.itemsize);
        if complete > 0 {
            a.data += bytearray(bytes(vals[0:complete]));
        }
        if size != want {
            raise EOFError("read() didn't return enough bytes");
        }
        return py_none();
    }
}


obj PyArrayObj(PyObj) {

    # Live storage: an Array from arrayobject.jac (bytearray-backed,
    # typecode-dispatched packing). Typed any because Array is defined in a
    # sibling module; every use casts.
    has arr: any = None;

    def tp_type_name -> str {
        return "array.array";
    }

    def _guard_err(e: any) -> PyObj {
        return py_error(type(e).__name__, str(e));
    }

    def tp_getattro(name: str) -> PyObj {
        a: Array = self.arr as Array;
        if name == "typecode" {
            return PyStr(t="str", val=a.typecode);
        }
        if name == "itemsize" {
            return PyInt(t="int", val=a.itemsize);
        }
        if _is_array_method(name) {
            return PyArrayMethod(t="array_method", target=self, name=name);
        }
        return py_error("AttributeError", name);
    }

    def tp_iter -> PyObj {
        # Fresh cursor per iteration (arrays are re-iterable); PySeqIter
        # drives mp_subscript until IndexError, matching sq_iterator.
        return PySeqIter(t="seqiter", seq=self as PyObj);
    }

    def tp_bool -> bool {
        a: Array = self.arr as Array;
        return a._n_items() > 0;
    }

    def tp_hashkey -> PyObj {
        return py_error("TypeError", "unhashable type: 'array.array'");
    }

    def mp_subscript(index: PyObj) -> PyObj {
        try {
            a: Array = self.arr as Array;
            if isinstance(index, PySlice) {
                sl = index as PySlice;
                ns = slice(
                    _arr_slice_bound(sl.start),
                    _arr_slice_bound(sl.stop),
                    _arr_slice_bound(sl.step),
                );
                return _arr_wrap(a.__getitem__(ns));
            }
            iv = index.to_index();
            if is_error(iv) {
                return py_error(
                    "TypeError",
                    "array indices must be integers or slices, not "
                    + index.tp_type_name(),
                );
            }
            return _arr_wrap(a.__getitem__((iv as PyInt).val));
        } except BaseException as e {
            return self._guard_err(e);
        }
    }

    def mp_ass_subscript(index: PyObj, value: PyObj) -> PyObj {
        try {
            a: Array = self.arr as Array;
            if isinstance(index, PySlice) {
                # CPython array_ass_subscript: slice targets accept only a
                # same-typecode array.
                if not isinstance(value, PyArrayObj) {
                    return py_error(
                        "TypeError",
                        'can only assign array (not "'
                        + value.tp_type_name() + '") to array slice',
                    );
                }
                sl2 = index as PySlice;
                ns2 = slice(
                    _arr_slice_bound(sl2.start),
                    _arr_slice_bound(sl2.stop),
                    _arr_slice_bound(sl2.step),
                );
                a._ass_slice(ns2, (value as PyArrayObj).arr as Array);
                return py_none();
            }
            store_v: any = _arr_item_of(value);
            # CPython array_ass_item: PyNumber_Index on the RHS runs before
            # the bounds check so a __index__ can resize the array first.
            if _tc_is_int(a.typecode)
                and not isinstance(value, PyInt)
                and not isinstance(value, PyBool) {
                coerced = value.to_index();
                if is_error(coerced) {
                    return coerced;
                }
                store_v = (coerced as PyInt).val;
            }
            iv2 = index.to_index();
            if is_error(iv2) {
                return py_error(
                    "TypeError",
                    "array indices must be integers or slices, not "
                    + index.tp_type_name(),
                );
            }
            a.__setitem__(
                (iv2 as PyInt).val, store_v
            );
            return py_none();
        } except BaseException as e {
            return self._guard_err(e);
        }
    }

    def mp_del_subscript(index: PyObj) -> PyObj {
        try {
            a: Array = self.arr as Array;
            if isinstance(index, PySlice) {
                sl3 = index as PySlice;
                ns3 = slice(
                    _arr_slice_bound(sl3.start),
                    _arr_slice_bound(sl3.stop),
                    _arr_slice_bound(sl3.step),
                );
                a.__delitem__(ns3);
                return py_none();
            }
            iv3 = index.to_index();
            if is_error(iv3) {
                return py_error(
                    "TypeError",
                    "array indices must be integers or slices, not "
                    + index.tp_type_name(),
                );
            }
            a.__delitem__((iv3 as PyInt).val);
            return py_none();
        } except BaseException as e {
            return self._guard_err(e);
        }
    }

    def nb_binop(kind: int, other: PyObj) -> PyObj {
        if kind == NB_ADD and isinstance(other, PyArrayObj) {
            try {
                a: Array = self.arr as Array;
                return _arr_wrap(a.__add__((other as PyArrayObj).arr as Array));
            } except BaseException as e {
                return self._guard_err(e);
            }
        }
        if kind == NB_MULTIPLY {
            iv = other.to_index();
            if is_error(iv) {
                return py_error(
                    "TypeError",
                    "can't multiply sequence by non-int of type '"
                    + other.t + "'",
                );
            }
            try {
                a2: Array = self.arr as Array;
                return _arr_wrap(a2.__mul__((iv as PyInt).val));
            } except BaseException as e2 {
                return self._guard_err(e2);
            }
        }
        return PY_NOT_IMPLEMENTED;
    }

    def tp_richcompare(kind: int, other: PyObj) -> PyObj {
        if kind == Py_EQ or kind == Py_NE {
            if isinstance(other, PyArrayObj) {
                try {
                    a: Array = self.arr as Array;
                    eqv2: bool = a.__eq__((other as PyArrayObj).arr as Array);
                    return PyBool(t="bool", val=eqv2 == (kind == Py_EQ));
                } except BaseException as e {
                    return self._guard_err(e);
                }
            }
            # CPython array_richcompare: non-array operand is just unequal.
            return PyBool(t="bool", val=kind == Py_NE);
        }
        if kind == Py_LT or kind == Py_LE or kind == Py_GT or kind == Py_GE {
            if isinstance(other, PyArrayObj) {
                try {
                    a2: Array = self.arr as Array;
                    oa: Array = (other as PyArrayObj).arr as Array;
                    op: str = "<";
                    if kind == Py_LE {
                        op = "<=";
                    } elif kind == Py_GT {
                        op = ">";
                    } elif kind == Py_GE {
                        op = ">=";
                    }
                    return _arr_wrap(a2._rich_order(oa, op));
                } except BaseException as e2 {
                    return self._guard_err(e2);
                }
            }
            return py_error(
                "TypeError",
                "'<' not supported between instances of 'array.array' and '"
                + other.tp_type_name() + "'",
            );
        }
        return PY_NOT_IMPLEMENTED;
    }
}


def _arr_slice_bound(v: PyObj) -> any {
    # Slice bounds: None stays None; ints (and bools) coerce; anything else
    # reaches slice.indices and raises the CPython TypeError there.
    if isinstance(v, PyNoneType) {
        return None;
    }
    return _arr_item_of(v);
}


# ---------------------------------------------------------------------------
# ceval integration helpers (kept here so ceval holds no Array internals)
# ---------------------------------------------------------------------------

def array_obj_len(a: PyArrayObj) -> int {
    return ((a.arr as Array)._n_items());
}

def array_obj_repr(a: PyArrayObj) -> PyObj {
    try {
        return PyStr(t="str", val=((a.arr as Array).__repr__()));
    } except BaseException as e {
        return py_error(type(e).__name__, str(e));
    }
}

def array_inplace_binop(lhs: PyArrayObj, kind: int, rhs: PyObj) -> PyObj {
    # NB_INPLACE_* arm for py_inplace_binop: mutate the receiver and return
    # it (aliases observe the update, like list *= / +=).
    if kind != NB_INPLACE_ADD and kind != NB_INPLACE_MULTIPLY {
        return PY_NOT_IMPLEMENTED;
    }
    a: Array = lhs.arr as Array;
    try {
        if kind == NB_INPLACE_ADD {
            if not isinstance(rhs, PyArrayObj) {
                return py_error(
                    "TypeError",
                    'can only extend array with array (not "'
                    + rhs.tp_type_name() + '")',
                );
            }
            ra: Array = (rhs as PyArrayObj).arr as Array;
            res: any = a.__iadd__(ra);
            if not isinstance(res, Array) {
                return _arr_wrap(res);
            }
            return lhs;
        }
        iv = rhs.to_index();
        if is_error(iv) {
            return py_error(
                "TypeError",
                "can't multiply sequence by non-int of type '" + rhs.t + "'",
            );
        }
        n: int = (iv as PyInt).val;
        grown = bytearray();
        k: int = 0;
        while k < n {
            grown += a.data;
            k += 1;
        }
        a.data = grown;
        return lhs;
    } except BaseException as e {
        return py_error(type(e).__name__, str(e));
    }
}


# ---------------------------------------------------------------------------
# Module namespace (CPython array module surface)
# ---------------------------------------------------------------------------

def array_module_attrs() -> dict[str, PyObj] {
    ctor = PyArrayCtor(t="function");
    attrs: dict[str, PyObj] = {
        "array": ctor,
        # CPython exposes ArrayType as a module-level alias of array.array.
        "ArrayType": ctor,
        # Generated from descriptors[] at modexec time (array_modexec).
        "typecodes": PyStr(t="str", val="bBuwhHiIlLqQfd"),
    };
    # Each typecode is exported as a module constant equal to itself.
    for tc in ["b", "B", "u", "w", "h", "H", "i", "I", "l", "L", "q", "Q", "f", "d"] {
        attrs[tc] = PyStr(t="str", val=tc);
    }
    return attrs;
}
