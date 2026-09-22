import from c { def fork -> i32;  }
import from c { def system(command: str) -> i32;  }
import from c { def _exit(status: i32);  }
import from c { def waitpid(pid: i32, status: bytes, options: i32) -> i32;  }
import from c { def kill(pid: i32, signum: i32) -> i32;  }
import from c { def setsid -> i32;  }
import from c { def pipe(fds: bytes) -> i32;  }
import from c { def dup2(oldfd: i32, newfd: i32) -> i32;  }
import from c { def open(path: str, flags: i32, mode: i32) -> i32;  }
import from c { def close(fd: i32) -> i32;  }
import from c { def read(fd: i32, buf: bytes, count: u64) -> i64;  }
import from c { def write(fd: i32, buf: bytes, count: u64) -> i64;  }
import from c { def usleep(usec: u32) -> i32;  }
import from c { def time(t: int) -> i64;  }
import from c { def setenv(name: str, value: str, overwrite: i32) -> i32;  }
import from c { def unsetenv(name: str) -> i32;  }
import from c { def clearenv -> i32;  }
import from c { def chdir(path: str) -> i32;  }
import from c { def getpid -> i32;  }
import from c { def execvp(file: str, argv: int) -> i32;  }
import from c { def strdup(s: str) -> int;  }
import from c { def malloc(size: int) -> int;  }
import from c { def free(p: int);  }
import from c {
    def posix_spawnp(
        pid: bytes, path: str, fa: int, attr: int, argv: int, envp: int
    ) -> i32;
}
import from c { def posix_spawn_file_actions_init(fa: int) -> i32;  }
import from c { def posix_spawn_file_actions_destroy(fa: int) -> i32;  }
import from c {
    def posix_spawn_file_actions_adddup2(fa: int, fd: i32, newfd: i32) -> i32;
}
import from c { def posix_spawn_file_actions_addclose(fa: int, fd: i32) -> i32;  }
import from c {
    def posix_spawn_file_actions_addopen(
        fa: int, fd: i32, path: str, flags: i32, mode: i32
    ) -> i32;
}
import from c { def posix_spawn_file_actions_addchdir_np(fa: int, path: str) -> i32;  }
import from c { def posix_spawnattr_init(at: int) -> i32;  }
import from c { def posix_spawnattr_setflags(at: int, flags: i32) -> i32;  }
import from c { def posix_spawnattr_destroy(at: int) -> i32;  }
import from _errno_native { last_errno, errno_message }

def _lo32(buf: bytes, off: int) -> int {
    return buf[off] | (buf[off + 1] << 8) | (buf[off + 2] << 16) | (buf[off + 3] << 24);
}

def:pub sp_fork -> int {
    return fork();
}

def:pub sp_system(command: str) -> int {
    return system(command);
}

def:pub sp_exit(status: int) {
    _exit(i32(status));
}

def:pub sp_waitpid(pid: int, options: int) -> list[int] {
    buf = b"\x00" * 8;
    rc = waitpid(i32(pid), buf, i32(options));
    return [int(rc), _lo32(buf, 0)];
}

def:pub sp_kill(pid: int, signum: int) -> int {
    return kill(i32(pid), i32(signum));
}

def:pub sp_setsid -> int {
    return setsid();
}

def:pub sp_pipe -> list[int] {
    buf = b"\x00" * 8;
    rc = pipe(buf);
    if rc != 0 {
        return [-1, -1];
    }
    return [_lo32(buf, 0), _lo32(buf, 4)];
}

def:pub sp_dup2(oldfd: int, newfd: int) -> int {
    return dup2(i32(oldfd), i32(newfd));
}

def:pub sp_open_devnull -> int {
    return open("/dev/null", i32(2), i32(0));
}

def:pub sp_close(fd: int) -> int {
    return close(i32(fd));
}

def:pub sp_read(fd: int, size: int) -> bytes {
    buf = b"\x00" * size;
    n = read(i32(fd), buf, u64(size));
    if n <= 0 {
        return b"";
    }
    return buf[:n];
}

def:pub sp_write(fd: int, data: bytes) -> int {
    return int(write(i32(fd), data, u64(len(data))));
}

def:pub sp_usleep(usec: int) -> int {
    return usleep(u32(usec));
}

def:pub sp_time -> int {
    return int(time(0));
}

def:pub sp_setenv(name: str, value: str) -> int {
    return setenv(name, value, i32(1));
}

def:pub sp_unsetenv(name: str) -> int {
    return unsetenv(name);
}

def:pub sp_clearenv -> int {
    return clearenv();
}

def:pub sp_chdir(path: str) -> int {
    return chdir(path);
}

def:pub sp_getpid -> int {
    return getpid();
}

def:pub sp_execvp(args: list[str]) -> int {
    n = len(args);
    if n == 0 {
        return -1;
    }
    buf = malloc((n + 1) * 8);
    i = 0;
    while i < n {
        __mem_store_i64(buf + i * 8, strdup(args[i]));
        i += 1;
    }
    __mem_store_i64(buf + n * 8, 0);
    return int(execvp(args[0], buf));
}

def:pub sp_strvec(items: list[str]) -> int {
    n = len(items);
    buf = malloc((n + 1) * 8);
    i = 0;
    while i < n {
        __mem_store_i64(buf + i * 8, strdup(items[i]));
        i += 1;
    }
    __mem_store_i64(buf + n * 8, 0);
    return buf;
}

def:pub sp_fa_new -> int {
    fa = malloc(256);
    posix_spawn_file_actions_init(fa);
    return fa;
}

def:pub sp_fa_dup2(fa: int, oldfd: int, newfd: int) -> int {
    return posix_spawn_file_actions_adddup2(fa, i32(oldfd), i32(newfd));
}

def:pub sp_fa_close(fa: int, fd: int) -> int {
    return posix_spawn_file_actions_addclose(fa, i32(fd));
}

def:pub sp_fa_open(fa: int, fd: int, path: str, flags: int) -> int {
    return posix_spawn_file_actions_addopen(fa, i32(fd), path, i32(flags), i32(438));
}

def:pub sp_fa_chdir(fa: int, path: str) -> int {
    return posix_spawn_file_actions_addchdir_np(fa, path);
}

def:pub sp_fa_free(fa: int) {
    posix_spawn_file_actions_destroy(fa);
    free(fa);
}

def:pub sp_attr_new(flags: int) -> int {
    at = malloc(512);
    posix_spawnattr_init(at);
    posix_spawnattr_setflags(at, i32(flags));
    return at;
}

def:pub sp_attr_free(at: int) {
    posix_spawnattr_destroy(at);
    free(at);
}

def:pub sp_spawn(path: str, fa: int, at: int, argv: int, envp: int) -> list[int] {
    pidb = b"\x00" * 8;
    rc = posix_spawnp(pidb, path, fa, at, argv, envp);
    return [int(rc), _lo32(pidb, 0)];
}

def:pub sp_errno -> int {
    return last_errno();
}

def:pub sp_errno_text -> str {
    return errno_message();
}
