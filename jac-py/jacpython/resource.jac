# Product-path facade for resource (native Jac).
#
# Semantics mirror CPython 3.14 ``Modules/resource.c`` (UNIX variant):
# the rlimit get/set/prlimit syscall surface, the getrusage accounting
# surface, and the RLIMIT_*/RUSAGE_*/RLIM_INFINITY constant block.
#
# The C module is a thin clinic wrapper over getrlimit(2)/setrlimit(2)/
# prlimit(2)/getrusage(2) with an int-conversion discipline ('i' for the
# who/resource selectors, rlim_t round-trip for the limit pairs). There is
# no in-VM syscall path, so -- exactly like math.jac's libm surface --
# every function trampolines onto the host resource module through a
# guarded bridge: arity, argument coercion, OverflowError/ValueError/
# OSError channels, and struct_rusage stay byte-exact with CPython because
# the host IS that C code.
#
# Constants are lifted natively as Linux values (the mmap.jac convention):
# guest code reads them without any host round-trip, and the values match
# the kernel ABI the host delegates to. FreeBSD-only names (RLIMIT_SWAP,
# RLIMIT_SBSIZE, RLIMIT_NPTS, RLIMIT_KQUEUES, RUSAGE_BOTH) are absent on a
# Linux build and therefore absent here, mirroring the #ifdef gates in
# resource.c. The ``error`` attribute (PyExc_OSError) is not re-exposed:
# guest handlers catch builtin OSError directly.

import from objects {
    PyObj,
    PyInt,
    PyModule,
    py_error,
}

import from ceval { to_host, from_host }

import from importlib { import_module }

# Host bridge (see header note). importlib indirection because a bare
# ``import resource`` inside this package resolves same-directory first
# and would re-enter this very module now that jacpython/resource.jac
# exists.
glob _hr: any = import_module("resource");

# ---------------- module constants (Linux values) ----------------------------

glob RLIMIT_CPU: int = 0,
     RLIMIT_FSIZE: int = 1,
     RLIMIT_DATA: int = 2,
     RLIMIT_STACK: int = 3,
     RLIMIT_CORE: int = 4,
     RLIMIT_RSS: int = 5,
     RLIMIT_NPROC: int = 6,
     RLIMIT_NOFILE: int = 7,
     RLIMIT_MEMLOCK: int = 8,
     RLIMIT_AS: int = 9,
     RLIMIT_MSGQUEUE: int = 14,
     RLIMIT_NICE: int = 15,
     RLIMIT_RTPRIO: int = 16,
     RLIMIT_RTTIME: int = 17,
     RLIMIT_SIGPENDING: int = 18,

     RUSAGE_SELF: int = 0,
     RUSAGE_CHILDREN: int = -1,
     RUSAGE_THREAD: int = 1,

     RLIM_INFINITY: int = 18446744073709551615;

# ---------------- guarded host bridge -----------------------------------------

# Exception-ladder order matters: ProcessLookupError/PermissionError are
# OSError subclasses CPython's prlimit raises deliberately, and they must
# keep their own identity when crossing into the guest error channel so
# ``except ProcessLookupError`` handlers match (test_resource pins both).
def _p2_resource_bridge(name: str, args: list[PyObj]) -> PyObj {
    host_args: list = [];
    i: int = 0;
    while i < len(args) {
        host_args.append(to_host(args[i]));
        i += 1;
    }
    try {
        raw: any = _p2_host_dispatch(name, host_args);
    } except ProcessLookupError as e {
        return py_error("ProcessLookupError", str(e));
    } except PermissionError as e {
        return py_error("PermissionError", str(e));
    } except OverflowError as e {
        return py_error("OverflowError", str(e));
    } except TypeError as e {
        return py_error("TypeError", str(e));
    } except ValueError as e {
        return py_error("ValueError", str(e));
    } except OSError as e {
        return py_error("OSError", str(e));
    }
    return from_host(raw);
}

def _p2_host_dispatch(name: str, a: list) -> any {
    if name == "getrusage" {
        return _hr.getrusage(*a);
    }
    if name == "getrlimit" {
        return _hr.getrlimit(*a);
    }
    if name == "setrlimit" {
        return _hr.setrlimit(*a);
    }
    if name == "prlimit" {
        return _hr.prlimit(*a);
    }
    if name == "getpagesize" {
        return _hr.getpagesize();
    }
    raise AttributeError("module 'resource' has no attribute '" + name + "'");
}

# ---------------- callable wrapper --------------------------------------------

obj PyResourceFn(PyObj) {
    has name: str;

    def tp_call(args: list[PyObj], kwargs: dict[str, PyObj]) -> PyObj {
        if len(kwargs) > 0 {
            return py_error(
                "TypeError", self.name + "() takes no keyword arguments"
            );
        }
        return _p2_resource_bridge(self.name, args);
    }
}

def build_resource_module -> PyObj {
    return PyModule(
        t="module",
        name="resource",
        attrs={
            "getrusage": PyResourceFn(t="resource_fn", name="getrusage"),
            "getrlimit": PyResourceFn(t="resource_fn", name="getrlimit"),
            "setrlimit": PyResourceFn(t="resource_fn", name="setrlimit"),
            "prlimit": PyResourceFn(t="resource_fn", name="prlimit"),
            "getpagesize": PyResourceFn(t="resource_fn", name="getpagesize"),

            "RLIMIT_CPU": PyInt(t="int", val=RLIMIT_CPU),
            "RLIMIT_FSIZE": PyInt(t="int", val=RLIMIT_FSIZE),
            "RLIMIT_DATA": PyInt(t="int", val=RLIMIT_DATA),
            "RLIMIT_STACK": PyInt(t="int", val=RLIMIT_STACK),
            "RLIMIT_CORE": PyInt(t="int", val=RLIMIT_CORE),
            "RLIMIT_RSS": PyInt(t="int", val=RLIMIT_RSS),
            "RLIMIT_NPROC": PyInt(t="int", val=RLIMIT_NPROC),
            "RLIMIT_NOFILE": PyInt(t="int", val=RLIMIT_NOFILE),
            "RLIMIT_MEMLOCK": PyInt(t="int", val=RLIMIT_MEMLOCK),
            "RLIMIT_AS": PyInt(t="int", val=RLIMIT_AS),
            "RLIMIT_MSGQUEUE": PyInt(t="int", val=RLIMIT_MSGQUEUE),
            "RLIMIT_NICE": PyInt(t="int", val=RLIMIT_NICE),
            "RLIMIT_RTPRIO": PyInt(t="int", val=RLIMIT_RTPRIO),
            "RLIMIT_RTTIME": PyInt(t="int", val=RLIMIT_RTTIME),
            "RLIMIT_SIGPENDING": PyInt(t="int", val=RLIMIT_SIGPENDING),

            "RUSAGE_SELF": PyInt(t="int", val=RUSAGE_SELF),
            "RUSAGE_CHILDREN": PyInt(t="int", val=RUSAGE_CHILDREN),
            "RUSAGE_THREAD": PyInt(t="int", val=RUSAGE_THREAD),

            "RLIM_INFINITY": PyInt(t="int", val=RLIM_INFINITY),
        },
    );
}
