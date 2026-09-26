import from c { def openat64(dirfd: i32, path: str, flags: i32, mode: i32) -> i32;  }
import from c { def mkdir(path: str, mode: i32) -> i32;  }
import from c { def read(fd: i32, buf: bytes, n: u64) -> i64;  }
import from c { def write(fd: i32, buf: bytes, n: u64) -> i64;  }
import from c { def close(fd: i32) -> i32;  }
import from c { def lseek(fd: i32, offset: i64, whence: i32) -> i64;  }
import from c { def fsync(fd: i32) -> i32;  }
import from c { def unlink(path: str) -> i32;  }
import from c { def access(path: str, mode: i32) -> i32;  }

glob _TF_AT_FDCWD: int = -100,
     _TF_RDWR: int = 2,
     _TF_CREAT: int = 64,
     _TF_EXCL: int = 128,
     _TF_RDONLY: int = 0;

def:pub tf_create_excl(path: str, mode: int) -> int {
    return int(
        openat64(
            i32(_TF_AT_FDCWD), path, i32(_TF_RDWR | _TF_CREAT | _TF_EXCL), i32(mode)
        )
    );
}

def:pub tf_mkdir(path: str, mode: int) -> int {
    return int(mkdir(path, i32(mode)));
}

def:pub tf_write(fd: int, data: bytes) -> int {
    total: int = len(data);
    off: int = 0;
    while off < total {
        n: int = int(write(i32(fd), data[off:total], u64(total - off)));
        if n <= 0 {
            return -1;
        }
        off += n;
    }
    return 0;
}

def:pub tf_read(fd: int, n: int) -> bytes {
    if n <= 0 {
        return b"";
    }
    buf = b"\x00" * n;
    got: int = int(read(i32(fd), buf, u64(n)));
    if got <= 0 {
        return b"";
    }
    return buf[0:got];
}

def:pub tf_seek(fd: int, offset: int, whence: int) -> int {
    return int(lseek(i32(fd), i64(offset), i32(whence)));
}

def:pub tf_tell(fd: int) -> int {
    return int(lseek(i32(fd), i64(0), i32(1)));
}

def:pub tf_fsync(fd: int) -> int {
    return int(fsync(i32(fd)));
}

def:pub tf_close(fd: int) -> int {
    return int(close(i32(fd)));
}

def:pub tf_unlink(path: str) -> int {
    return int(unlink(path));
}

def:pub tf_access(path: str, mode: int) -> int {
    return int(access(path, i32(mode)));
}

def:pub tf_stdin_read_all -> str {
    out = bytearray();
    buf = b"\x00" * 65536;
    while True {
        n: int = int(read(i32(0), buf, u64(len(buf))));
        if n <= 0 {
            break;
        }
        out.extend(buf[0:n]);
        if n < len(buf) {
            break;
        }
    }
    return bytes(out).decode("utf-8");
}
