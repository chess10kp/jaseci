# Product-path facade for _winapi (lift of reference/cpython/Modules/_winapi.c).
#
# Windows-only C extension backing subprocess, multiprocessing, and mimetypes.
# The full syscall surface (handles, events, pipes, processes, overlapped I/O)
# lives in the host ``_winapi`` extension; this facade forwards every clinic
# entry point through the ceval host bridge so argument validation, Win32 error
# mapping, and handle coercion stay byte-exact with CPython.
#
# Constants and the Overlapped type are snapshotted from the connected host
# module at attrs-build time (fcntl.jac convention) so values always match the
# extension executing the syscalls. On non-Windows hosts the module is not
# registered (import stays ModuleNotFoundError) so Lib/test import_helper's
# required_on=["win"] contract keeps skipping these suites on Linux.

import from objects {
    PyObj,
    PyStr,
    PyList,
    py_error,
}
import from ceval {
    _jac_host_import,
    _jac_dir_names,
    _jac_host_getattr,
    _jac_host_call,
    to_host,
    from_host,
}

def _wa_host_module() -> tuple[bool, any] {
    star: list[PyObj] = [PyStr(t="str", val="*")];
    res = _jac_host_import("_winapi", to_host(PyList(t="list", items=star)));
    if res[0] as bool {
        return (True, res[1]);
    }
    return (False, py_error(str(res[1]), str(res[2])));
}

def winapi_host_available() -> bool {
    mod = _wa_host_module();
    return mod[0] as bool;
}

def _wa_bridge_call(fn_name: str, args: list[PyObj], kwargs: dict[str, PyObj]) -> PyObj {
    mod = _wa_host_module();
    if not ((mod[0] as bool)) {
        return mod[1] as PyObj;
    }
    fn_res = _jac_host_getattr(mod[1], fn_name);
    if not ((fn_res[0] as bool)) {
        return py_error(str(fn_res[1]), str(fn_res[2]));
    }
    host_args: list[any] = [];
    for a in args {
        host_args.append(to_host(a));
    }
    host_kwargs: dict[str, any] = {};
    for k in kwargs {
        host_kwargs[k] = to_host(kwargs[k]);
    }
    res = _jac_host_call(fn_res[1], host_args, host_kwargs);
    if res[0] as bool {
        return from_host(res[1]);
    }
    return py_error(str(res[1]), str(res[2]));
}

obj WinapiFn(PyObj) {
    has name: str;

    def tp_call(args: list[PyObj], kwargs: dict[str, PyObj]) -> PyObj {
        return _wa_bridge_call(self.name, args, kwargs);
    }
}

def _wa_fn(name: str) -> PyObj {
    return WinapiFn(t="winapi_fn", name=name);
}

def _winapi_function_names() -> list[str] {
    return [
        "CloseHandle",
        "ConnectNamedPipe",
        "CreateEventW",
        "CreateFile",
        "CreateFileMapping",
        "CreateJunction",
        "CreateMutexW",
        "CreateNamedPipe",
        "CreatePipe",
        "CreateProcess",
        "DuplicateHandle",
        "ExitProcess",
        "GetCurrentProcess",
        "GetExitCodeProcess",
        "GetLastError",
        "GetLongPathName",
        "GetModuleFileName",
        "GetShortPathName",
        "GetStdHandle",
        "GetVersion",
        "MapViewOfFile",
        "UnmapViewOfFile",
        "OpenEventW",
        "OpenMutexW",
        "OpenFileMapping",
        "OpenProcess",
        "PeekNamedPipe",
        "LCMapStringEx",
        "ReadFile",
        "ReleaseMutex",
        "ResetEvent",
        "SetEvent",
        "SetNamedPipeHandleState",
        "TerminateProcess",
        "VirtualQuerySize",
        "WaitNamedPipe",
        "BatchedWaitForMultipleObjects",
        "WaitForMultipleObjects",
        "WaitForSingleObject",
        "WriteFile",
        "GetACP",
        "GetFileType",
        "_mimetypes_read_windows_registry",
        "NeedCurrentDirectoryForExePath",
        "CopyFile2",
    ];
}

def winapi_module_attrs() -> dict[str, PyObj] {
    attrs: dict[str, PyObj] = {};
    for fn_name in _winapi_function_names() {
        attrs[fn_name] = _wa_fn(fn_name);
    }
    mod = _wa_host_module();
    if mod[0] as bool {
        names_res = _jac_dir_names(mod[1]);
        if names_res[0] as bool {
            for attr_name in names_res[1] {
                if attr_name in attrs {
                    continue;
                }
                got = _jac_host_getattr(mod[1], attr_name);
                if got[0] as bool {
                    attrs[attr_name] = from_host(got[1]);
                }
            }
        }
    }
    return attrs;
}

