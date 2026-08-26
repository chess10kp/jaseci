# Product-path facade for the Windows _winapi surface (native Jac).
# Semantics mirror CPython 3.14 ``Modules/_winapi.c`` for everything
# expressible against jacpython's runtime API:
#
# - The event family is implemented natively over a handle table:
#   CreateEventW/OpenEventW allocate opaque integer handles backed by
#   manual-reset/auto-reset signal state; SetEvent/ResetEvent mutate it;
#   CloseHandle retires the handle (further use -> OSError).
# - WaitForSingleObject / WaitForMultipleObjects /
#   BatchedWaitForMultipleObjects evaluate the same success/timeout/error
#   contract as the C code (index or [indices] lists for wait-any, None for
#   wait-all, TimeoutError on WAIT_TIMEOUT, OSError on bad handles and the
#   3969-handle batched cap). jacpython's ceval is single-threaded, so a
#   wait either completes immediately (a waited handle is already
#   signalled -- auto-reset handles are consumed by the wait, like the C
#   implementation) or could never complete; the latter surfaces as
#   WAIT_TIMEOUT instead of deadlocking the VM.
# - Constants mirror the WINAPI_CONSTANT table in winapi_exec() insertion
#   surface (DWORD values stored unsigned, HANDLE-typed ones signed).
# - Kernel calls with no Linux analogue (named pipes, file mapping,
#   process spawning, path conversion) register their names but raise
#   OSError(winerror=120, ERROR_CALL_NOT_IMPLEMENTED), the same failure
#   class Windows itself reports for unsupported APIs.

import from objects {
    PyObj,
    PyStr,
    PyInt,
    PyBool,
    PyList,
    PyTuple,
    PyNoneType,
    py_none,
    py_error,
}

glob _winapi_next_handle: int = 1;
# Handle tables: handle -> event state; name -> handle for named events.
glob _winapi_manual_reset: dict[int, bool] = {};
glob _winapi_signaled: dict[int, bool] = {};
glob _winapi_names: dict[str, int] = {};

# ERROR_CALL_NOT_IMPLEMENTED: what Windows reports for APIs the platform
# does not carry; used verbatim so callers see a genuine winerror class.
def _winapi_unavailable(fn_name: str) -> PyObj {
    return py_error(
        "OSError",
        "[WinError 120] This function is not supported on this system: "
        + fn_name,
    );
}

def _winapi_invalid_handle(fn_name: str) -> PyObj {
    return py_error("OSError", "[WinError 6] The handle is invalid: " + fn_name);
}

def _winapi_timeout_error -> PyObj {
    # PyErr_SetExcFromWindowsErr(PyExc_TimeoutError, WAIT_TIMEOUT) shape.
    return py_error("TimeoutError", "[WinError 258] The wait operation timed out.");
}

def _winapi_type_error(msg: str) -> PyObj {
    return py_error("TypeError", msg);
}

# Strict int read (bool folds like the int subclass it is); None signals
# "not an int" so callers raise clinic-shaped TypeErrors.
def _winapi_int_arg(v: PyObj) -> int | None {
    if isinstance(v, PyBool) {
        if (v as PyBool).val {
            return 1;
        }
        return 0;
    }
    if isinstance(v, PyInt) {
        return (v as PyInt).val;
    }
    return None;
}

def _winapi_bool_arg(v: PyObj) -> bool | None {
    if isinstance(v, PyBool) {
        return (v as PyBool).val;
    }
    if isinstance(v, PyInt) {
        return (v as PyInt).val != 0;
    }
    return None;
}

def _winapi_str_arg(v: PyObj) -> str | None {
    if isinstance(v, PyStr) {
        return (v as PyStr).val;
    }
    return None;
}

def _winapi_is_none(v: PyObj) -> bool {
    return isinstance(v, PyNoneType);
}

# Bind FASTCALL|METH_KEYWORDS arguments onto clinic keyword names:
# positionals first, keywords fill gaps, missing slots stay None.
def _winapi_bind(
    args: list[PyObj], kwargs: dict[str, PyObj], names: list[str]
) -> list[PyObj] | PyObj {
    if len(args) > len(names) {
        joined = names[0];
        for nm in names[1:] {
            joined = joined + ", " + nm;
        }
        return _winapi_type_error(
            "function takes at most " + str(len(names))
            + " arguments (" + str(len(args)) + " given)"
        );
    }
    bound: list[PyObj] = [];
    for i in range(len(names)) {
        if i < len(args) {
            bound.append(args[i]);
            continue;
        }
        nm = names[i];
        if nm in kwargs {
            bound.append(kwargs[nm]);
        } else {
            bound.append(py_none());
        }
    }
    return bound;
}

def _winapi_alloc_handle(manual: bool, initial: bool, name: str | None) -> int {
    h = _winapi_next_handle;
    _winapi_next_handle = h + 1;
    _winapi_manual_reset[h] = manual;
    _winapi_signaled[h] = initial;
    if name is not None {
        _winapi_names[name] = h;
    }
    return h;
}

# A waited handle consumes its signal unless it is manual-reset; mirrors
# WaitForMultipleObjects auto-reset semantics.
def _winapi_consume(h: int) {
    if not (_winapi_manual_reset[h]) {
        _winapi_signaled[h] = False;
    }
}

# Resolve one sequence element to a live handle; None -> bad handle.
def _winapi_live_handle(v: PyObj) -> int | None {
    h = _winapi_int_arg(v);
    if h is None {
        return None;
    }
    if h in _winapi_signaled {
        return h;
    }
    return None;
}

# Shared core for the three wait entry points. Returns:
#   - wait_all=True: None when every handle is signalled
#   - wait_all=False: sorted indices of signalled handles
# Bad handles -> error PyObj; empty result -> timeout error.
def _winapi_wait_core(handles: list[int], wait_all: bool) -> PyObj {
    ready: list[int] = [];
    for i in range(len(handles)) {
        h = handles[i];
        if _winapi_signaled[h] {
            if not (wait_all) {
                _winapi_consume(h);
            }
            ready.append(i);
        }
    }
    if wait_all {
        if len(ready) == len(handles) {
            for h in handles {
                _winapi_consume(h);
            }
            return py_none();
        }
        return _winapi_timeout_error();
    }
    if len(ready) == 0 {
        return _winapi_timeout_error();
    }
    items: list[PyObj] = [];
    for idx in ready {
        items.append(PyInt(t="int", val=idx));
    }
    return PyList(t="list", items=items);
}

obj PyWinapiFn(PyObj) {
    has name: str;

    def tp_call(args: list[PyObj], kwargs: dict[str, PyObj]) -> PyObj {
        if self.name == "CreateEventW" {
            b = _winapi_bind(
                args, kwargs,
                ["security_attributes", "manual_reset", "initial_state", "name"],
            );
            if isinstance(b, PyObj) {
                return b as PyObj;
            }
            params = b as list[PyObj];
            manual = _winapi_bool_arg(params[1]);
            initial = _winapi_bool_arg(params[2]);
            if manual is None or initial is None {
                return _winapi_type_error("an integer is required");
            }
            name: str | None = None;
            if not (_winapi_is_none(params[3])) {
                s = _winapi_str_arg(params[3]);
                if s is None {
                    return _winapi_type_error(
                        "a writable bytes-like object is required"
                    );
                }
                # Named events are singletons, like CreateEventW.
                if s in _winapi_names {
                    return PyInt(t="int", val=_winapi_names[s]);
                }
                name = s;
            }
            return PyInt(t="int", val=_winapi_alloc_handle(manual, initial, name));
        }
        if self.name == "OpenEventW" {
            b = _winapi_bind(
                args, kwargs, ["desired_access", "inherit_handle", "name"]
            );
            if isinstance(b, PyObj) {
                return b as PyObj;
            }
            params = b as list[PyObj];
            s = _winapi_str_arg(params[2]);
            if s is None {
                return _winapi_type_error("an integer is required");
            }
            if s in _winapi_names {
                return PyInt(t="int", val=_winapi_names[s]);
            }
            return py_error(
                "OSError", "[WinError 2] The system cannot find the file specified."
            );
        }
        if self.name == "SetEvent" or self.name == "ResetEvent" {
            if len(args) != 1 {
                return _winapi_type_error("function takes exactly one argument");
            }
            h: int | None = _winapi_live_handle(args[0]);
            if h is None {
                return _winapi_invalid_handle(self.name);
            }
            _winapi_signaled[h] = self.name == "SetEvent";
            return py_none();
        }
        if self.name == "CloseHandle" {
            if len(args) != 1 {
                return _winapi_type_error("function takes exactly one argument");
            }
            h = _winapi_live_handle(args[0]);
            if h is None {
                return _winapi_invalid_handle(self.name);
            }
            # Retire the handle everywhere it may be reachable.
            _winapi_signaled.pop(h);
            _winapi_manual_reset.pop(h);
            stale: str | None = None;
            for nm in _winapi_names.keys() {
                if _winapi_names[nm] == h {
                    stale = nm;
                    break;
                }
            }
            if stale is not None {
                _winapi_names.pop(stale);
            }
            return py_none();
        }
        if self.name == "WaitForSingleObject" {
            b = _winapi_bind(args, kwargs, ["handle", "milliseconds"]);
            if isinstance(b, PyObj) {
                return b as PyObj;
            }
            params = b as list[PyObj];
            h: int | None = _winapi_live_handle(params[0]);
            if h is None {
                return _winapi_invalid_handle(self.name);
            }
            # Success answers WAIT_OBJECT_0; auto-reset state is consumed.
            out = _winapi_wait_core([h], False);
            if isinstance(out, PyList) {
                return PyInt(t="int", val=0);
            }
            return out;
        }
        if self.name == "WaitForMultipleObjects" {
            b = _winapi_bind(args, kwargs, ["handle_seq", "wait_flag", "milliseconds"]);
            if isinstance(b, PyObj) {
                return b as PyObj;
            }
            resolved = self._resolve_seq((b as list[PyObj])[0]);
            if isinstance(resolved, PyObj) and not (isinstance(resolved, PyList)) {
                return resolved;
            }
            hs = (resolved as PyList).items;
            wait_all: bool | None = _winapi_bool_arg((b as list[PyObj])[1]);
            if wait_all is None {
                return _winapi_type_error("an integer is required");
            }
            if len(hs) == 0 {
                if wait_all {
                    return py_none();
                }
                return PyList(t="list", items=[]);
            }
            handles: list[int] = [];
            for v in hs {
                h: int | None = _winapi_live_handle(v);
                if h is None {
                    return _winapi_invalid_handle(self.name);
                }
                handles.append(h);
            }
            out = _winapi_wait_core(handles, wait_all);
            # wait-any contract: a single index, not a list.
            if wait_all is False and isinstance(out, PyList) {
                return (out as PyList).items[0];
            }
            return out;
        }
        if self.name == "BatchedWaitForMultipleObjects" {
            b = _winapi_bind(
                args, kwargs, ["handle_seq", "wait_all", "milliseconds"]
            );
            if isinstance(b, PyObj) {
                return b as PyObj;
            }
            params = b as list[PyObj];
            seq = params[0];
            if not (isinstance(seq, PyList)) and not (isinstance(seq, PyTuple)) {
                return _winapi_type_error("sequence type expected");
            }
            wait_all: bool | None = _winapi_bool_arg(params[1]);
            if wait_all is None {
                return _winapi_type_error("an integer is required");
            }
            n = len(seq.items);
            # MAXIMUM_BATCHED_WAIT_OBJECTS == (MAXIMUM_WAIT_OBJECTS - 1)**2.
            if n > 3969 {
                return py_error(
                    "ValueError",
                    "need at most 3969 handles, got a sequence of length "
                    + str(n),
                );
            }
            if n == 0 {
                if wait_all {
                    return py_none();
                }
                return PyList(t="list", items=[]);
            }
            handles: list[int] = [];
            for v in seq.items {
                h: int | None = _winapi_live_handle(v);
                if h is None {
                    return _winapi_invalid_handle(self.name);
                }
                handles.append(h);
            }
            return _winapi_wait_core(handles, wait_all);
        }
        if self.name == "GetLastError" {
            # Native waits never enter a Windows error state.
            return PyInt(t="int", val=0);
        }
        if self.name == "GetCurrentProcess" {
            # Pseudo-handle constant CURRENT_PROCESS_PERMISSIONS (-1 is the
            # real pseudo-handle; keep it distinct from event handles).
            return PyInt(t="int", val=-103);
        }
        if self.name == "GetVersion" {
            # 3.14 reference carries no version bits to report faithfully.
            return PyInt(t="int", val=0);
        }
        return _winapi_unavailable(self.name);
    }

    # Sequence -> PyObj error or PyList of raw elements (shared by both
    # multi-wait entry points).
    def _resolve_seq(v: PyObj) -> PyObj {
        if isinstance(v, PyList) or isinstance(v, PyTuple) {
            if isinstance(v, PyList) {
                return v;
            }
            return PyList(t="list", items=list((v as PyTuple).items));
        }
        return _winapi_type_error("sequence type expected");
    }
}

# Shim-module attribute table consumed by the ceval import sites. Function
# names follow the _WINAPI_*_METHODDEF registration block; the Overlapped
# type (registered via PyModule_AddType in C) is not part of this surface.
def winapi_module_attrs() -> dict[str, PyObj] {
    attrs: dict[str, PyObj] = {};
    native = [
        "BatchedWaitForMultipleObjects",
        "CloseHandle",
        "CreateEventW",
        "GetLastError",
        "GetCurrentProcess",
        "GetVersion",
        "OpenEventW",
        "ResetEvent",
        "SetEvent",
        "WaitForMultipleObjects",
        "WaitForSingleObject",
    ];
    for fname in native {
        attrs[fname] = PyWinapiFn(t="winapi_fn", name=fname) as PyObj;
    }
    # Registered in C but unimplementable without Win32 kernel objects.
    for fname in [
        "ConnectNamedPipe",
        "CopyFile2",
        "CreateFile",
        "CreateFileMapping",
        "CreateJunction",
        "CreateMutexW",
        "CreateNamedPipe",
        "CreatePipe",
        "CreateProcess",
        "DuplicateHandle",
        "ExitProcess",
        "GetACP",
        "GetExitCodeProcess",
        "GetFileType",
        "GetLongPathName",
        "GetModuleFileName",
        "GetShortPathName",
        "GetStdHandle",
        "LCMapStringEx",
        "MapViewOfFile",
        "NeedCurrentDirectoryForExePathW",
        "OpenFileMapping",
        "OpenMutexW",
        "OpenProcess",
        "PeekNamedPipe",
        "ReadFile",
        "ReleaseMutex",
        "SetNamedPipeHandleState",
        "TerminateProcess",
        "UnmapViewOfFile",
        "VirtualQuerySize",
        "WaitNamedPipe",
        "WriteFile",
        "_mimetypes_read_windows_registry",
        "sortenvironmentkey",
    ] {
        attrs[fname] = PyWinapiFn(t="winapi_fn", name=fname) as PyObj;
    }
    # WINAPI_CONSTANT(F_DWORD, ...) table, winapi_exec() order; DWORDs are
    # stored unsigned, the F_HANDLE entry signed.
    dwords: dict[str, int] = {
        "ABOVE_NORMAL_PRIORITY_CLASS": 32768,
        "BELOW_NORMAL_PRIORITY_CLASS": 16384,
        "CREATE_BREAKAWAY_FROM_JOB": 16777216,
        "CREATE_DEFAULT_ERROR_MODE": 67108864,
        "CREATE_NEW": 1,
        "CREATE_ALWAYS": 2,
        "CREATE_NO_WINDOW": 134217728,
        "DETACHED_PROCESS": 8,
        "ERROR_NO_DATA": 232,
        "ERROR_NO_SYSTEM_RESOURCES": 1450,
        "ERROR_OPERATION_ABORTED": 995,
        "ERROR_PIPE_BUSY": 231,
        "ERROR_PIPE_CONNECTED": 535,
        "ERROR_PRIVILEGE_NOT_HELD": 1314,
        "ERROR_SEM_TIMEOUT": 121,
        "FILE_FLAG_FIRST_PIPE_INSTANCE": 524288,
        "FILE_FLAG_OVERLAPPED": 1073741824,
        "FILE_MAP_ALL_ACCESS": 983071,
        "FILE_MAP_COPY": 1,
        "FILE_MAP_EXECUTE": 33554432,
        "FILE_MAP_READ": 4,
        "FILE_MAP_WRITE": 2,
        "GENERIC_READ": 2147483648,
        "GENERIC_WRITE": 1073741824,
        "INFINITE": 4294967295,
        "MEM_COMMIT": 4096,
        "MEM_FREE": 65536,
        "MEM_IMAGE": 16777216,
        "MEM_MAPPED": 262144,
        "MEM_PRIVATE": 131072,
        "MEM_RESERVE": 8192,
        "NMPWAIT_WAIT_FOREVER": 4294967295,
        "NMPWAIT_USE_DEFAULT_WAIT": 0,
        "OPEN_ALWAYS": 4,
        "OPEN_EXISTING": 3,
        "PAGE_EXECUTE": 16,
        "PAGE_EXECUTE_READ": 32,
        "PAGE_EXECUTE_READWRITE": 64,
        "PAGE_EXECUTE_WRITECOPY": 128,
        "PAGE_GUARD": 256,
        "PAGE_NOACCESS": 1,
        "PAGE_NOCACHE": 512,
        "PAGE_READONLY": 2,
        "PAGE_READWRITE": 4,
        "PAGE_WRITECOMBINE": 1024,
        "PAGE_WRITECOPY": 8,
        "PIPE_ACCESS_DUPLEX": 3,
        "PIPE_ACCESS_INBOUND": 1,
        "PIPE_ACCESS_OUTBOUND": 2,
        "PIPE_READMODE_BYTE": 0,
        "PIPE_READMODE_MESSAGE": 2,
        "PIPE_TYPE_BYTE": 0,
        "PIPE_TYPE_MESSAGE": 4,
        "PIPE_UNLIMITED_INSTANCES": 255,
        "PIPE_WAIT": 0,
        "PROCESS_ALL_ACCESS": 2097151,
        "PROCESS_DUP_HANDLE": 64,
        "REALTIME_PRIORITY_CLASS": 256,
        "HIGH_PRIORITY_CLASS": 128,
        "NORMAL_PRIORITY_CLASS": 32,
        "IDLE_PRIORITY_CLASS": 64,
        "SEC_COMMIT": 8388608,
        "SEC_IMAGE": 16777216,
        "SEC_LARGE_PAGES": 2147483648,
        "SEC_NOCACHE": 268435456,
        "SEC_RESERVE": 67108864,
        "SEC_WRITECOMBINE": 1073741824,
        "STARTF_USESHOWWINDOW": 1,
        "STARTF_USESIZE": 2,
        "STARTF_USEPOSITION": 4,
        "STARTF_USECOUNTCHARS": 8,
        "STARTF_USEFILLATTRIBUTE": 16,
        "STARTF_RUNFULLSCREEN": 32,
        "STARTF_FORCEONFEEDBACK": 64,
        "STARTF_FORCEOFFFEEDBACK": 128,
        "STARTF_USESTDHANDLES": 256,
        "STARTF_USEHOTKEY": 512,
        "STARTF_TITLEISLINKNAME": 2048,
        "STARTF_TITLEISAPPID": 4096,
        "STARTF_PREVENTPINNING": 8192,
        "STARTF_UNTRUSTEDSOURCE": 32768,
        "STD_INPUT_HANDLE": 4294967286,
        "STD_OUTPUT_HANDLE": 4294967287,
        "STD_ERROR_HANDLE": 4294967288,
        "STILL_ACTIVE": 259,
        "SYNCHRONIZE": 1048576,
        "SW_HIDE": 0,
        "WAIT_OBJECT_0": 0,
        "WAIT_ABANDONED_0": 128,
        "WAIT_TIMEOUT": 258,
        "FILE_TYPE_UNKNOWN": 0,
        "FILE_TYPE_DISK": 1,
        "FILE_TYPE_CHAR": 2,
        "FILE_TYPE_PIPE": 3,
        "FILE_TYPE_REMOTE": 32768,
        "LOCALE_NAME_MAX_LENGTH": 85,
        "LCMAP_FULLWIDTH": 8388608,
        "LCMAP_HALFWIDTH": 4194304,
        "LCMAP_HIRAGANA": 1048576,
        "LCMAP_KATAKANA": 2097152,
        "LCMAP_LINGUISTIC_CASING": 67108864,
        "LCMAP_LOWERCASE": 256,
        "LCMAP_SIMPLIFIED_CHINESE": 33554432,
        "LCMAP_TITLECASE": 768,
        "LCMAP_TRADITIONAL_CHINESE": 4194304,
        "LCMAP_UPPERCASE": 512,
        "COPY_FILE_ALLOW_DECRYPTED_DESTINATION": 8,
        "COPY_FILE_COPY_SYMLINK": 2048,
        "COPY_FILE_FAIL_IF_EXISTS": 1,
        "COPY_FILE_NO_BUFFERING": 4096,
        "COPY_FILE_NO_OFFLOAD": 262144,
        "COPY_FILE_OPEN_SOURCE_FOR_WRITE": 4,
        "COPY_FILE_REQUEST_SECURITY_PRIVILEGES": 131072,
        "COPY_FILE_RESUME_FROM_PAUSE": 16384,
        "COPY_FILE_RESTARTABLE": 2,
        "COPY_FILE_REQUEST_COMPRESSED_TRAFFIC": 268435456,
        "COPY_FILE_DIRECTORY": 128,
        "COPYFILE2_CALLBACK_CHUNK_STARTED": 1,
        "COPYFILE2_CALLBACK_CHUNK_FINISHED": 2,
        "COPYFILE2_CALLBACK_STREAM_STARTED": 3,
        "COPYFILE2_CALLBACK_STREAM_FINISHED": 4,
        "COPYFILE2_CALLBACK_POLL_CONTINUE": 5,
        "COPYFILE2_CALLBACK_ERROR": 6,
        "COPYFILE2_PROGRESS_CONTINUE": 0,
        "COPYFILE2_PROGRESS_CANCEL": 1,
        "COPYFILE2_PROGRESS_STOP": 2,
        "COPYFILE2_PROGRESS_QUIET": 3,
        "COPYFILE2_PROGRESS_PAUSE": 4,
        "TRUNCATE_EXISTING": 5,
    };
    for cname in dwords.keys() {
        attrs[cname] = PyInt(t="int", val=dwords[cname]);
    }
    attrs["INVALID_HANDLE_VALUE"] = PyInt(t="int", val=-1);
    attrs["LOCALE_NAME_INVARIANT"] = PyStr(t="str", val="");
    attrs["LOCALE_NAME_SYSTEM_DEFAULT"] = PyStr(
        t="str", val="!x-sys-default-locale"
    );
    attrs["LOCALE_NAME_USER_DEFAULT"] = PyStr(
        t="str", val="!x-user-default-locale"
    );
    return attrs;
}
