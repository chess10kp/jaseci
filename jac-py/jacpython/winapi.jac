# Product-path facade for _winapi.
# Semantics mirror CPython 3.14 ``Modules/_winapi.c`` exercised by
# Lib/test/test_winapi.py (suite_routing: test_winapi -> QUARANTINE,
# forbidden-import:_winapi).
#
# REPRESENTATION CHOICE (divergence ledger candidate): the C original is a
# thin binding over the Win32 floor -- processes, named pipes, file mappings
# -- that has no host equivalent on the Linux farm (unlike bz2/_curses, there
# is no ``_winapi`` extension to delegate to). This facade lifts everything
# _winapi.c exports that is a pure compile-time value (the full
# WINAPI_CONSTANT block from winapi_exec, byte-exact SDK values) and models
# the synchronization core natively: named/auto-reset/manual-reset events and
# the three wait entry points, including BatchedWaitForMultipleObjects'
# batch-chunking algorithm over MAXIMUM_WAIT_OBJECTS-1-sized groups.
#
# Wait semantics in the single-threaded guest: waits never block. A signaled
# object completes immediately (auto-reset events consume their signal, as
# WaitForMultipleObjects does); an unsignaled object expires the wait --
# nothing in a single-threaded guest can signal mid-wait, so every timeout
# value (including INFINITE) behaves as WAIT_TIMEOUT. This preserves all
# behavior reachable without threads and cannot hang the VM where real
# Win32 would deadlock forever.
#
# Error-channel convention matches the other facades (binasciimodule et al):
# OSError/TimeoutError/TypeError/ValueError keep their builtin types exactly;
# messages carry the canonical "[WinError <n>] <message>" text of
# PyErr_SetFromWindowsErr, and GetLastError() observes the last recorded
# code like its Win32 namesake.
#
# Out of scope by design (needs the Win32 kernel-object floor, absent from
# every farm platform): ConnectNamedPipe, CreateFile, CreateFileMapping,
# CreateMutexW/OpenMutexW/ReleaseMutex, CreateNamedPipe, CreatePipe,
# CreateProcess, CreateJunction, DuplicateHandle, ExitProcess/Terminate-
# Process, GetCurrentProcess, GetExitCodeProcess, GetLongPathName/
# GetShortPathName, GetModuleFileName, GetStdHandle, GetVersion, MapViewOf-
# File/UnmapViewOfFile, PeekNamedPipe, LCMAPSTRINGEX, ReadFile,
# SetNamedPipeHandleState, VirtualQuerySize, WaitNamedPipe, WriteFile,
# GetACP, GetFileType, _mimetypes_read_windows_registry,
# NeedCurrentDirectoryForExePathW, CopyFile2, the Overlapped type.


# ---------------- module constants (winapi_exec WINAPI_CONSTANT block) ------

glob CREATE_NEW_CONSOLE: int = 0x00000010,
     CREATE_NEW_PROCESS_GROUP: int = 0x00000200,
     DUPLICATE_SAME_ACCESS: int = 0x00000002,
     DUPLICATE_CLOSE_SOURCE: int = 0x00000001,
     ERROR_ACCESS_DENIED: int = 5,
     ERROR_ALREADY_EXISTS: int = 183,
     ERROR_BROKEN_PIPE: int = 109,
     ERROR_IO_PENDING: int = 997,
     ERROR_MORE_DATA: int = 234,
     ERROR_NETNAME_DELETED: int = 64,
     ERROR_NO_SYSTEM_RESOURCES: int = 1450,
     ERROR_NO_DATA: int = 232,
     ERROR_OPERATION_ABORTED: int = 995,
     ERROR_PIPE_BUSY: int = 231,
     ERROR_PIPE_CONNECTED: int = 535,
     ERROR_PRIVILEGE_NOT_HELD: int = 1314,
     ERROR_SEM_TIMEOUT: int = 121,
     FILE_FLAG_FIRST_PIPE_INSTANCE: int = 0x00080000,
     FILE_FLAG_OVERLAPPED: int = 0x40000000,
     FILE_GENERIC_READ: int = 0x00120089,
     FILE_GENERIC_WRITE: int = 0x00120116,
     FILE_MAP_ALL_ACCESS: int = 0x000F003F,
     FILE_MAP_COPY: int = 0x00000001,
     FILE_MAP_EXECUTE: int = 0x00000020,
     FILE_MAP_READ: int = 0x00000004,
     FILE_MAP_WRITE: int = 0x00000002,
     GENERIC_READ: int = 0x80000000,
     GENERIC_WRITE: int = 0x40000000,
     INFINITE: int = 0xFFFFFFFF,
     INVALID_HANDLE_VALUE: int = 0xFFFFFFFFFFFFFFFF,
     MEM_COMMIT: int = 0x00001000,
     MEM_FREE: int = 0x00010000,
     MEM_IMAGE: int = 0x01000000,
     MEM_MAPPED: int = 0x00040000,
     MEM_PRIVATE: int = 0x00020000,
     MEM_RESERVE: int = 0x00002000,
     NMPWAIT_WAIT_FOREVER: int = 0xFFFFFFFF,
     OPEN_EXISTING: int = 3,
     PAGE_EXECUTE: int = 0x10,
     PAGE_EXECUTE_READ: int = 0x20,
     PAGE_EXECUTE_READWRITE: int = 0x40,
     PAGE_EXECUTE_WRITECOPY: int = 0x80,
     PAGE_GUARD: int = 0x100,
     PAGE_NOACCESS: int = 0x01,
     PAGE_NOCACHE: int = 0x200,
     PAGE_READONLY: int = 0x02,
     PAGE_READWRITE: int = 0x04,
     PAGE_WRITECOMBINE: int = 0x400,
     PAGE_WRITECOPY: int = 0x08,
     PIPE_ACCESS_DUPLEX: int = 0x3,
     PIPE_ACCESS_INBOUND: int = 0x1,
     PIPE_READMODE_MESSAGE: int = 0x2,
     PIPE_TYPE_MESSAGE: int = 0x4,
     PIPE_UNLIMITED_INSTANCES: int = 255,
     PIPE_WAIT: int = 0x0,
     PROCESS_ALL_ACCESS: int = 0x1FFFFF,
     SYNCHRONIZE: int = 0x00100000,
     PROCESS_DUP_HANDLE: int = 0x0040,
     SEC_COMMIT: int = 0x8000000,
     SEC_IMAGE: int = 0x1000000,
     SEC_LARGE_PAGES: int = 0x80000000,
     SEC_NOCACHE: int = 0x10000000,
     SEC_RESERVE: int = 0x4000000,
     SEC_WRITECOMBINE: int = 0x40000000,
     STARTF_USESHOWWINDOW: int = 0x00000001,
     STARTF_USESIZE: int = 0x00000002,
     STARTF_USEPOSITION: int = 0x00000004,
     STARTF_USECOUNTCHARS: int = 0x00000008,
     STARTF_USEFILLATTRIBUTE: int = 0x00000010,
     STARTF_RUNFULLSCREEN: int = 0x00000020,
     STARTF_FORCEONFEEDBACK: int = 0x00000040,
     STARTF_FORCEOFFFEEDBACK: int = 0x00000080,
     STARTF_USESTDHANDLES: int = 0x00000100,
     STARTF_USEHOTKEY: int = 0x00000200,
     STARTF_TITLEISLINKNAME: int = 0x00000800,
     STARTF_TITLEISAPPID: int = 0x00001000,
     STARTF_PREVENTPINNING: int = 0x00002000,
     STARTF_UNTRUSTEDSOURCE: int = 0x00008000,
     # STD_* are ((DWORD)-10..-12); F_DWORD builds them unsigned ("k").
     STD_INPUT_HANDLE: int = 0xFFFFFFF6,
     STD_OUTPUT_HANDLE: int = 0xFFFFFFF5,
     STD_ERROR_HANDLE: int = 0xFFFFFFF4,
     STILL_ACTIVE: int = 0x103,
     SW_HIDE: int = 0,
     WAIT_OBJECT_0: int = 0,
     WAIT_ABANDONED_0: int = 0x80,
     WAIT_TIMEOUT: int = 258,
     ABOVE_NORMAL_PRIORITY_CLASS: int = 0x00008000,
     BELOW_NORMAL_PRIORITY_CLASS: int = 0x00004000,
     HIGH_PRIORITY_CLASS: int = 0x00000080,
     IDLE_PRIORITY_CLASS: int = 0x00000040,
     NORMAL_PRIORITY_CLASS: int = 0x00000020,
     REALTIME_PRIORITY_CLASS: int = 0x00000100,
     CREATE_NO_WINDOW: int = 0x08000000,
     DETACHED_PROCESS: int = 0x00000008,
     CREATE_DEFAULT_ERROR_MODE: int = 0x04000000,
     CREATE_BREAKAWAY_FROM_JOB: int = 0x01000000,
     FILE_TYPE_UNKNOWN: int = 0,
     FILE_TYPE_DISK: int = 1,
     FILE_TYPE_CHAR: int = 2,
     FILE_TYPE_PIPE: int = 3,
     FILE_TYPE_REMOTE: int = 0x8000,
     LOCALE_NAME_INVARIANT: str = "",
     LOCALE_NAME_MAX_LENGTH: int = 85,
     LOCALE_NAME_SYSTEM_DEFAULT: str = "!x-sys-default-locale",
     LOCALE_NAME_USER_DEFAULT: str = "!x-user-default-locale",
     LCMAP_FULLWIDTH: int = 0x00800000,
     LCMAP_HALFWIDTH: int = 0x00400000,
     LCMAP_HIRAGANA: int = 0x00100000,
     LCMAP_KATAKANA: int = 0x00200000,
     LCMAP_LINGUISTIC_CASING: int = 0x01000000,
     LCMAP_LOWERCASE: int = 0x00000100,
     LCMAP_SIMPLIFIED_CHINESE: int = 0x00000002,
     LCMAP_TITLECASE: int = 0x00000300,
     LCMAP_TRADITIONAL_CHINESE: int = 0x00000004,
     LCMAP_UPPERCASE: int = 0x00000200,
     COPY_FILE_ALLOW_DECRYPTED_DESTINATION: int = 0x0008,
     COPY_FILE_COPY_SYMLINK: int = 0x0800,
     COPY_FILE_FAIL_IF_EXISTS: int = 0x0001,
     COPY_FILE_NO_BUFFERING: int = 0x0010,
     COPY_FILE_NO_OFFLOAD: int = 0x00040000,
     COPY_FILE_OPEN_SOURCE_FOR_WRITE: int = 0x0002,
     COPY_FILE_RESTARTABLE: int = 0x0020,
     COPY_FILE_REQUEST_SECURITY_PRIVILEGES: int = 0x00200000,
     COPY_FILE_RESUME_FROM_PAUSE: int = 0x0040,
     COPY_FILE_REQUEST_COMPRESSED_TRAFFIC: int = 0x10000000,
     COPY_FILE_DIRECTORY: int = 0x00000080,
     COPYFILE2_CALLBACK_CHUNK_STARTED: int = 1,
     COPYFILE2_CALLBACK_CHUNK_FINISHED: int = 2,
     COPYFILE2_CALLBACK_STREAM_STARTED: int = 3,
     COPYFILE2_CALLBACK_STREAM_FINISHED: int = 4,
     COPYFILE2_CALLBACK_POLL_CONTINUE: int = 5,
     COPYFILE2_CALLBACK_ERROR: int = 6,
     COPYFILE2_PROGRESS_CONTINUE: int = 0,
     COPYFILE2_PROGRESS_CANCEL: int = 1,
     COPYFILE2_PROGRESS_STOP: int = 2,
     COPYFILE2_PROGRESS_QUIET: int = 3,
     COPYFILE2_PROGRESS_PAUSE: int = 4;

# Internal layout limits (_winapi.c #defines; not exported).
glob _MAXIMUM_WAIT_OBJECTS: int = 64;


# ---------------- module state ----------------

# Module state boxed in a dict so rebinding stays unnecessary (same
# convention as readline.jac / _csvmodule.jac).
#   events: handle -> {"manual": bool, "signaled": bool, "name": str | None}
#   named:  name -> handle (CreateEventW/OpenEventW namespace)
glob _state: dict = {
    "events": {},
    "named": {},
    "next_handle": 1,
    "last_error": 0,
};


# ---------------- error channel ----------------

def _winerror_message(err: int) -> str {
    # Canonical FormatMessage texts for the codes this facade can produce.
    if err == 2 {
        return "The system cannot find the file specified.";
    }
    if err == 6 {
        return "The handle is invalid.";
    }
    if err == 183 {
        return "Cannot create a file when that file already exists.";
    }
    if err == 258 {
        return "The wait operation timed out.";
    }
    return "The specified resource is unavailable.";
}


def _raise_winerror(err: int) {
    # PyErr_SetFromWindowsErr family: record GetLastError() state, then
    # raise with the canonical "[WinError n] message" text.
    _state["last_error"] = err;
    msg = "[WinError " + str(err) + "] " + _winerror_message(err);
    if err == 258 {
        # oserror_init special-cases winerror WAIT_TIMEOUT to TimeoutError.
        raise TimeoutError(msg);
    }
    raise OSError(msg);
}


def _type_name(v: any) -> str {
    return type(v).__name__;
}


def _parse_handle(v: any) -> int {
    # F_HANDLE parses with "K" (unsigned long long): ints wrap modulo 2**64,
    # everything else is a TypeError.
    if not isinstance(v, int) {
        raise TypeError(
            "integer argument expected, got '" + _type_name(v) + "'");
    }
    return (v as int) % 0x10000000000000000;
}


def _event_or_fail(handle: int) -> dict {
    ev = _state["events"].get(handle);
    if ev is None {
        _raise_winerror(6);
    }
    return ev;
}


def _parse_handle_seq(handle_seq: any) -> list[int] {
    # PySequence_Check + F_HANDLE per element (str/bytes are sequences too).
    if not isinstance(handle_seq, (list, tuple, str, bytes)) {
        raise TypeError(
            "sequence type expected, got '" + _type_name(handle_seq) + "'");
    }
    out: list[int] = [];
    for i in range(len(handle_seq)) {
        out.append(_parse_handle(handle_seq[i]));
    }
    return out;
}


def _consume(ev: dict) {
    # Auto-reset events drop their signal when a wait completes on them.
    if not ev["manual"] {
        ev["signaled"] = False;
    }
}


# ---------------- event core (CreateEventW/SetEvent/ResetEvent) -------------

def CreateEventW(security_attributes: any, manual_reset: any,
                 initial_state: any, name: any) -> int {
    # Named events: reopening an existing name hands back its handle and
    # leaves ERROR_ALREADY_EXISTS in GetLastError(), exactly as CreateEventW.
    if name is not None and not isinstance(name, str) {
        raise TypeError("expected str, got '" + _type_name(name) + "'");
    }
    if not isinstance(manual_reset, int) or not isinstance(initial_state, int) {
        raise TypeError("an integer is required");
    }
    if name is not None {
        existing = _state["named"].get(name);
        if existing is not None {
            _state["last_error"] = 183;
            return existing;
        }
    }
    handle = _state["next_handle"];
    _state["next_handle"] = handle + 1;
    _state["events"][handle] = {
        "manual": bool(manual_reset),
        "signaled": bool(initial_state),
        "name": name,
    };
    if name is not None {
        _state["named"][name] = handle;
    }
    return handle;
}


def OpenEventW(desired_access: any, inherit_handle: any, name: any) -> int {
    if not isinstance(name, str) {
        raise TypeError("expected str, got '" + _type_name(name) + "'");
    }
    existing = _state["named"].get(name);
    if existing is None {
        _raise_winerror(2);
    }
    return existing;
}


def SetEvent(event: any) {
    ev = _event_or_fail(_parse_handle(event));
    ev["signaled"] = True;
}


def ResetEvent(event: any) {
    ev = _event_or_fail(_parse_handle(event));
    ev["signaled"] = False;
}


def CloseHandle(handle: any) {
    # Events are the only handles this module issues; anything else is an
    # invalid handle, as CloseHandle would report for a foreign value.
    h = _parse_handle(handle);
    ev = _state["events"].pop(h, None);
    if ev is None {
        _raise_winerror(6);
    }
    if ev["name"] is not None {
        if _state["named"].get(ev["name"]) == h {
            _state["named"].pop(ev["name"]);
        }
    }
}


# ---------------- waits ----------------

def WaitForSingleObject(handle: any, milliseconds: any) -> int {
    ev = _event_or_fail(_parse_handle(handle));
    if ev["signaled"] {
        _consume(ev);
        return WAIT_OBJECT_0;
    }
    # Single-threaded guest: no other thread can signal mid-wait, so the
    # timeout interval always elapses (see header note).
    return WAIT_TIMEOUT;
}


def WaitForMultipleObjects(handle_seq: any, wait_flag: any,
                           milliseconds: any = INFINITE) -> int {
    handles = _parse_handle_seq(handle_seq);
    if len(handles) > _MAXIMUM_WAIT_OBJECTS - 1 {
        raise ValueError(
            "need at most " + str(_MAXIMUM_WAIT_OBJECTS - 1)
            + " handles, got a sequence of length " + str(len(handles)));
    }
    events: list[dict] = [];
    for h in handles {
        events.append(_event_or_fail(h));
    }
    if wait_flag {
        for ev in events {
            if not ev["signaled"] {
                return WAIT_TIMEOUT;
            }
        }
        # All signaled: commit the consumption only now (a failed
        # wait-all leaves auto-reset events signaled).
        for ev in events {
            _consume(ev);
        }
        return WAIT_OBJECT_0;
    }
    for ev in events {
        if ev["signaled"] {
            _consume(ev);
            return WAIT_OBJECT_0;
        }
    }
    return WAIT_TIMEOUT;
}


def BatchedWaitForMultipleObjects(handle_seq: any, wait_all: any,
                                  milliseconds: any = INFINITE)
                                  -> list[int] | None {
    # Chunking algorithm from _winapi_BatchedWaitForMultipleObjects_impl:
    # handles split into groups of at most MAXIMUM_WAIT_OBJECTS-1; wait-all
    # walks the groups sequentially, wait-any reports one triggered index
    # per group (each group's wait-any scan consumes its first signaled
    # object). WAIT_TIMEOUT surfaces as TimeoutError through the
    # PyErr_SetExcFromWindowsErr(OSError, 258) path.
    handles = _parse_handle_seq(handle_seq);
    max_total = (_MAXIMUM_WAIT_OBJECTS - 1) * (_MAXIMUM_WAIT_OBJECTS - 1);
    if len(handles) > max_total {
        raise ValueError(
            "need at most " + str(max_total)
            + " handles, got a sequence of length " + str(len(handles)));
    }
    if len(handles) == 0 {
        if wait_all {
            return None;
        }
        return [];
    }

    batch_size = _MAXIMUM_WAIT_OBJECTS - 1;
    if wait_all {
        i = 0;
        while i < len(handles) {
            batch = handles[i:i + batch_size];
            events: list[dict] = [];
            for h in batch {
                events.append(_event_or_fail(h));
            }
            for ev in events {
                if not ev["signaled"] {
                    _raise_winerror(WAIT_TIMEOUT);
                }
            }
            for ev in events {
                _consume(ev);
            }
            i += batch_size;
        }
        return None;
    }

    triggered: list[int] = [];
    base = 0;
    while base < len(handles) {
        batch = handles[base:base + batch_size];
        found = -1;
        for j in range(len(batch)) {
            ev = _event_or_fail(batch[j]);
            if found < 0 and ev["signaled"] {
                _consume(ev);
                found = j;
            }
        }
        if found >= 0 {
            triggered.append(base + found);
        }
        base += batch_size;
    }
    if len(triggered) == 0 {
        _raise_winerror(WAIT_TIMEOUT);
    }
    return triggered;
}


# ---------------- misc ----------------

def GetLastError() -> int {
    return _state["last_error"];
}
