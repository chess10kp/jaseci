import from c { def strerror(errnum: i32) -> str;  }
import from _errno_platform { errno_address }

glob EINTR: int = 4;

def:pub last_errno -> int {
    return int(__mem_load_i32(errno_address()));
}

def:pub clear_errno {
    __mem_store_i32(errno_address(), 0);
}

def:pub errno_message -> str {
    return strerror(i32(last_errno()));
}

def _raise_for_errno(code: int, message: imm str) {
    if code == 2 {
        raise FileNotFoundError(message);
    }
    if code == 21 {
        raise IsADirectoryError(message);
    }
    if code == 20 {
        raise NotADirectoryError(message);
    }
    if code == 13 or code == 1 {
        raise PermissionError(message);
    }
    raise OSError(message);
}

def:pub raise_os_error(operation: imm str, path: imm str, code: int) {
    _raise_for_errno(code, operation + ": " + strerror(i32(code)) + ": " + path);
}

def:pub raise_errno(code: int) {
    _raise_for_errno(code, "[Errno " + str(code) + "] " + strerror(i32(code)));
}
