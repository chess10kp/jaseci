# Native facade for the time stdlib module (lift of
# reference/cpython/Modules/timemodule.c, CPython 3.14 surface).
#
# The C module is a thin OS boundary (clock_gettime/strftime/localtime); the
# runtime has no direct OS clock API, so this facade owns its own host bridge
# (::py:: helpers below) and mirrors the C file's surface on top of it:
#
# - Every callable is a PyTimeFn that marshals guest args to host values,
#   calls the host time module's same-named function, converts scalar results
#   back natively, and re-raises host failures as GUEST-native exceptions via
#   py_error -- so ``except OverflowError`` in guest code matches VM-raised
#   errors instead of dying at the bridge-table boundary.
# - gmtime/localtime return native PyStructTime carriers (objects.jac), not
#   host proxies: tuple()/indexing/iteration run in-VM and tm_* reads never
#   cross the boundary. asctime/mktime/strftime marshal them back through a
#   real host tuple (the three tuple-hungry entry points).
# - get_clock_info returns a native PyClockInfo with CPython's four fields.
# - Constants (timezone/altzone/daylight/tzname + CLOCK_*) are snapshotted
#   through from-scalar conversion at registration; names absent on the host
#   platform are omitted, mirroring the C #ifdef guards exactly.
#
# Wiring: ceval.jac registers this surface as lazy shims in both import_native
# and host_import so guest ``import time`` resolves proxy-free (the delegated
# snapshot leaks host float/int identity through every clock read).
#
# The bridge lives here rather than reusing ceval's _jac_host_call because
# ceval imports THIS module for shim wiring and Jac forbids import cycles.

import from objects {
    PyObj,
    PyInt,
    PyFloat,
    PyBool,
    PyStr,
    PyBytes,
    PyTuple,
    PyNoneType,
    PyStructTime,
    py_none,
    py_error,
}

::py::
def _time_host_call(name, args):
    # Bridge to the host CPython time module: args is already plain host
    # data (ints/floats/strs/lists). Returns (True, result) or
    # (False, exc_type_name, message).
    import time as _host_time
    try:
        fn = getattr(_host_time, name)
    except AttributeError:
        return (False, "AttributeError",
                "module 'time' has no attribute '" + name + "'")
    try:
        return (True, fn(*args))
    except BaseException as exc:
        return (False, type(exc).__name__, str(exc))

def _time_host_struct(name, args):
    # gmtime/localtime arm: flatten the host struct_time into [tm_year..
    # tm_isdst] plus optional [tm_gmtoff, tm_zone] so no host object ever
    # crosses back into the guest.
    import time as _host_time
    try:
        st = getattr(_host_time, name)(*args)
        vals = [int(st.tm_year), int(st.tm_mon), int(st.tm_mday),
                int(st.tm_hour), int(st.tm_min), int(st.tm_sec),
                int(st.tm_wday), int(st.tm_yday), int(st.tm_isdst)]
        if getattr(st, "tm_gmtoff", None) is not None:
            vals.append(int(st.tm_gmtoff))
            vals.append(st.tm_zone)
        return (True, vals)
    except BaseException as exc:
        return (False, type(exc).__name__, str(exc))

def _time_clock_info(name):
    # get_clock_info arm: the host namedtuple flattened to its four fields.
    import time as _host_time
    try:
        info = _host_time.get_clock_info(name)
        return (True, str(info.implementation), bool(info.monotonic),
                float(info.resolution), bool(info.adjustable))
    except BaseException as exc:
        return (False, type(exc).__name__, str(exc))

def _time_host_hasattr(name):
    import time as _host_time
    return hasattr(_host_time, name)

def _time_host_getattr(name):
    import time as _host_time
    try:
        return (True, getattr(_host_time, name))
    except BaseException as exc:
        return (False, type(exc).__name__, str(exc))

def _time_totuple(seq):
    # asctime/mktime/strftime require real host tuples ("Tuple or
    # struct_time argument required"), not lists.
    return tuple(seq)
::py::

# Module functions mirroring time_methods[] order; each name is served only
# when the host platform has it, matching the C #ifdef surface.
glob _TIME_FUNCTIONS: list[str] = [
    "time", "time_ns",
    "clock_gettime", "clock_gettime_ns", "clock_settime", "clock_settime_ns",
    "clock_getres", "pthread_getcpuclockid",
    "sleep", "gmtime", "localtime", "asctime", "ctime", "mktime",
    "strftime", "strptime", "tzset",
    "monotonic", "monotonic_ns", "process_time", "process_time_ns",
    "thread_time", "thread_time_ns",
    "perf_counter", "perf_counter_ns", "get_clock_info",
];

# init_timezone() variables plus the CLOCK_* IntMacro adds, Linux/glibc set.
glob _TIME_CONSTANTS: list[str] = [
    "timezone", "altzone", "daylight", "tzname",
    "CLOCK_REALTIME", "CLOCK_MONOTONIC", "CLOCK_MONOTONIC_RAW", "CLOCK_HIGHRES",
    "CLOCK_PROCESS_CPUTIME_ID", "CLOCK_THREAD_CPUTIME_ID", "CLOCK_PROF",
    "CLOCK_BOOTTIME", "CLOCK_TAI", "CLOCK_UPTIME", "CLOCK_UPTIME_RAW",
    "CLOCK_MONOTONIC_RAW_APPROX", "CLOCK_UPTIME_RAW_APPROX",
];


obj PyTimeFn(PyObj) {
    has name: str;

    # Identity hash (builtin-style callable; stdlib stores these in sets).
    def tp_hashkey -> PyObj {
        return PyStr(t="str", val="obj:" + str(id(self)));
    }

    def tp_call(args: list[PyObj], kwargs: dict[str, PyObj]) -> PyObj {
        if len(kwargs) > 0 {
            return py_error(
                "TypeError", self.name + "() takes no keyword arguments"
            );
        }
        n = self.name;
        # METH_NOARGS family: clocks and tzset.
        if n == "time" or n == "time_ns" or n == "monotonic"
            or n == "monotonic_ns" or n == "perf_counter"
            or n == "perf_counter_ns" or n == "process_time"
            or n == "process_time_ns" or n == "thread_time"
            or n == "thread_time_ns" or n == "tzset" {
            if len(args) != 0 {
                return py_error(
                    "TypeError",
                    n + "() takes no arguments (" + str(len(args)) + " given)",
                );
            }
            return _time_bridge(n, []);
        }
        if n == "sleep" {
            if len(args) != 1 {
                return _time_arity(n, len(args), 1, 1);
            }
            return _time_bridge(n, [_time_arg_to_host(args[0])]);
        }
        if n == "gmtime" or n == "localtime" {
            if len(args) > 1 {
                return _time_arity(n, len(args), 0, 1);
            }
            secs: list[any] = [];
            if len(args) == 1 {
                secs.append(_time_arg_to_host(args[0]));
            }
            res = _time_host_struct(n, secs);
            if not ((res[0] as bool)) {
                return py_error(str(res[1]), str(res[2]));
            }
            return _time_struct_from_flat(res[1] as list);
        }
        if n == "ctime" {
            if len(args) > 1 {
                return _time_arity(n, len(args), 0, 1);
            }
            secs2: list[any] = [];
            if len(args) == 1 {
                secs2.append(_time_arg_to_host(args[0]));
            }
            return _time_bridge(n, secs2);
        }
        # The three tuple-hungry entry points ("Tuple or struct_time
        # argument required"): marshal any sequence arg into a real host
        # tuple before crossing.
        if n == "asctime" {
            if len(args) > 1 {
                return _time_arity(n, len(args), 0, 1);
            }
            tup: list[any] = [];
            if len(args) == 1 {
                conv = _time_conv_args([args[0]]);
                if not ((conv[0] as bool)) {
                    return py_error("TypeError", str(conv[1]));
                }
                tup.append(_time_totuple(conv[1][0]));
            }
            return _time_bridge(n, tup);
        }        if n == "mktime" {
            if len(args) != 1 {
                return _time_arity(n, len(args), 1, 1);
            }
            conv2 = _time_conv_args([args[0]]);
            if not ((conv2[0] as bool)) {
                return py_error("TypeError", str(conv2[1]));
            }
            return _time_bridge(n, [_time_totuple(conv2[1][0])]);
        }
        if n == "strftime" {
            if len(args) > 2 {
                return _time_arity(n, len(args), 1, 2);
            }
            call_args: list[any] = [];
            for arg in args {
                conv3 = _time_conv_args([arg]);
                if not ((conv3[0] as bool)) {
                    return py_error("TypeError", str(conv3[1]));
                }
                call_args.append(_time_totuple(conv3[1][0]));
            }
            return _time_bridge(n, call_args);
        }
        if n == "strftime" {
            if len(args) > 2 {
                return _time_arity(n, len(args), 1, 2);
            }
            # Only the struct_time slot marshals as a host tuple; the format
            # stays a plain string.
            fmt = _time_conv_args([args[0]]);
            if not ((fmt[0] as bool)) {
                return py_error("TypeError", str(fmt[1]));
            }
            call_args: list[any] = [fmt[1][0]];
            if len(args) == 2 {
                tt = _time_conv_args([args[1]]);
                if not ((tt[0] as bool)) {
                    return py_error("TypeError", str(tt[1]));
                }
                call_args.append(_time_totuple(tt[1][0]));
            }
            return _time_bridge(n, call_args);
        }
        if n == "strptime" {
            if len(args) > 2 {
                return _time_arity(n, len(args), 1, 2);
            }
            conv = _time_conv_args(args);
            if not ((conv[0] as bool)) {
                return py_error("TypeError", str(conv[1]));
            }
            return _time_bridge(n, conv[1]);
        }
        if n == "clock_gettime" or n == "clock_gettime_ns" or n == "clock_getres" {
            if len(args) != 1 {
                return _time_arity(n, len(args), 1, 1);
            }
            conv_clk = _time_conv_args(args);
            if not ((conv_clk[0] as bool)) {
                return py_error("TypeError", str(conv_clk[1]));
            }
            return _time_bridge(n, conv_clk[1]);
        }
        if n == "clock_settime" or n == "clock_settime_ns" {
            if len(args) != 2 {
                return _time_arity(n, len(args), 2, 2);
            }
            conv_set = _time_conv_args(args);
            if not ((conv_set[0] as bool)) {
                return py_error("TypeError", str(conv_set[1]));
            }
            return _time_bridge(n, conv_set[1]);
        }
        if n == "pthread_getcpuclockid" {
            if len(args) != 1 {
                return _time_arity(n, len(args), 1, 1);
            }
            conv_tid = _time_conv_args(args);
            if not ((conv_tid[0] as bool)) {
                return py_error("TypeError", str(conv_tid[1]));
            }
            return _time_bridge(n, conv_tid[1]);
        }
        if n == "get_clock_info" {
            if len(args) != 1 or not isinstance(args[0], PyStr) {
                return _time_arity(n, len(args), 1, 1);
            }
            ci = _time_clock_info((args[0] as PyStr).val);
            if not ((ci[0] as bool)) {
                return py_error(str(ci[1]), str(ci[2]));
            }
            return PyClockInfo(
                t="clock_info",
                implementation=str(ci[1]),
                monotonic=(ci[2] as bool),
                resolution=(ci[3] as float),
                adjustable=(ci[4] as bool),
            );
        }
        return py_error(
            "AttributeError", "module 'time' has no attribute '" + n + "'"
        );
    }
}


# Native carrier for get_clock_info results (CPython namedtuple fields).
obj PyClockInfo(PyObj) {
    has implementation: str,
        monotonic: bool,
        adjustable: bool,
        resolution: float;

    def tp_hashkey -> PyObj {
        return PyStr(t="str", val="obj:" + str(id(self)));
    }

    def tp_getattro(name: str) -> PyObj {
        if name == "implementation" {
            return PyStr(t="str", val=self.implementation);
        }
        if name == "monotonic" {
            return PyBool(t="bool", val=self.monotonic);
        }
        if name == "adjustable" {
            return PyBool(t="bool", val=self.adjustable);
        }
        if name == "resolution" {
            return PyFloat(t="float", val=self.resolution);
        }
        return py_error(
            "AttributeError",
            "'time.get_clock_info' object has no attribute '" + name + "'",
        );
    }

    def tp_repr -> PyObj {
        return PyStr(
            t="str",
            val="namespace.get_clock_info(implementation="
                + "'" + self.implementation + "', monotonic="
                + _time_bool_name(self.monotonic) + ", adjustable="
                + _time_bool_name(self.adjustable) + ", resolution="
                + str(self.resolution) + ")",
        );
    }
}


def _time_bool_name(b: bool) -> str {
    if b {
        return "True";
    }
    return "False";
}


def _time_arity(n: str, given: int, lo: int, hi: int) -> PyObj {
    if lo == hi {
        return py_error(
            "TypeError",
            n + "() takes exactly " + str(lo) + " argument ("
                + str(given) + " given)",
        );
    }
    return py_error(
        "TypeError",
        n + "() takes at most " + str(hi) + " argument ("
            + str(given) + " given)",
    );
}


# Guest arg -> host value. Sequence types flatten recursively; anything else
# fails loudly rather than degrading to None at the bridge.
def _time_conv_one(v: PyObj) -> tuple[bool, any] {
    if isinstance(v, PyInt) {
        return (True, (v as PyInt).val);
    }
    if isinstance(v, PyFloat) {
        return (True, (v as PyFloat).val);
    }
    if isinstance(v, PyBool) {
        return (True, (v as PyBool).val);
    }
    if isinstance(v, PyStr) {
        return (True, (v as PyStr).val);
    }
    if isinstance(v, PyBytes) {
        return (True, bytes((v as PyBytes).val));
    }
    if isinstance(v, PyNoneType) {
        return (True, None);
    }
    if isinstance(v, PyStructTime) {
        return _time_conv_seq((v as PyStructTime).items);
    }
    if isinstance(v, PyTuple) {
        return _time_conv_seq((v as PyTuple).items);
    }
    return (False, "unconvertible argument type '" + v.t + "'");
}


def _time_conv_seq(items: list[PyObj]) -> tuple[bool, any] {
    out: list[any] = [];
    for item in items {
        r = _time_conv_one(item);
        if not ((r[0] as bool)) {
            return (False, r[1]);
        }
        out.append(r[1]);
    }
    return (True, out);
}


# Convert a whole positional list, failing with the first bad type.
def _time_conv_args(vals: list[PyObj]) -> tuple[bool, any] {
    out: list[any] = [];
    for v in vals {
        r = _time_conv_one(v);
        if not ((r[0] as bool)) {
            return (False, r[1]);
        }
        out.append(r[1]);
    }
    return (True, out);
}



# Host result -> guest scalar (clocks return floats/ints, ctime a str).
def _time_scalar(raw: any) -> PyObj {
    if raw is None {
        return py_none();
    }
    if isinstance(raw, bool) {
        return PyBool(t="bool", val=raw);
    }
    if isinstance(raw, int) {
        return PyInt(t="int", val=raw);
    }
    if isinstance(raw, float) {
        return PyFloat(t="float", val=raw);
    }
    if isinstance(raw, str) {
        return PyStr(t="str", val=raw);
    }
    return py_error("TypeError", "unsupported bridge result type");
}


# Call the host function and convert the scalar result; host failures become
# guest-native exceptions of the same type name.
def _time_bridge(name: str, args_py: list[any]) -> PyObj {
    res = _time_host_call(name, args_py);
    if not ((res[0] as bool)) {
        return py_error(str(res[1]), str(res[2]));
    }
    return _time_scalar(res[1]);
}


# [tm_year..tm_isdst(, tm_gmtoff, tm_zone)] flat list -> native struct_time.
def _time_struct_from_flat(flat: list) -> PyObj {
    items: list[PyObj] = [];
    for v in flat {
        items.append(_time_scalar(v));
    }
    return PyStructTime(t="tuple", items=items);
}


# tzname-style constant: scalars pass through; tuples convert element-wise.
def _time_constant_from_host(raw: any) -> PyObj {
    if isinstance(raw, tuple) or isinstance(raw, list) {
        items: list[PyObj] = [];
        for v in raw {
            items.append(_time_scalar(v));
        }
        return PyTuple(t="tuple", items=items);
    }
    return _time_scalar(raw);
}


# Module attribute table consumed by the ceval shim registration sites.
def time_module_attrs -> dict[str, PyObj] {
    attrs: dict[str, PyObj] = {};
    for name in _TIME_FUNCTIONS {
        if not ((_time_host_hasattr(name) as bool)) {
            # Absent on this platform: mirrors the C #ifdef omission.
            continue;
        }
        attrs[name] = PyTimeFn(t="time_fn", name=name);
    }
    for cname in _TIME_CONSTANTS {
        got = _time_host_getattr(cname);
        if not ((got[0] as bool)) {
            continue;
        }
        attrs[cname] = _time_constant_from_host(got[1]);
    }
    attrs["_STRUCT_TM_ITEMS"] = PyInt(t="int", val=11);
    return attrs;
}
