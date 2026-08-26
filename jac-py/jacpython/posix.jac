# Product-path facade for posix (native Jac).
#
# Semantics mirror CPython 3.14 ``Modules/posixmodule.c`` on the Linux/glibc
# build of the pinned reference tree. The module surface splits three ways:
#
# 1. CONSTANT SURFACE -- every int constant ``all_ins()`` inserts on this
#    platform (access modes, O_* open flags, EX_* exit codes, wait/waitid
#    selectors and flags, CLONE_*, sched/prio selectors, POSIX_FADV_*,
#    ST_* statvfs flags, RWF/XATTR/RTLD/EFD/TFD/MFD/PIDFD/SPLICE/GRND
#    families). Values are pinned byte-exact against the host CPython
#    3.14 linux-x86_64 build at authoring time, mirroring how the C module
#    bakes platform macro values in at compile time. Insertion order is NOT
#    semantic here (unlike errno's errorcode dict): these are independent
#    names, so the table is grouped by C-source family instead.
#
# 2. PURE-JAC FUNCTIONS -- the wait-status macro family (WIFEXITED et al,
#    glibc sys/wait.h bit layouts), waitstatus_to_exitcode, and the
#    device-number macros (major/minor/makedev, glibc sys/sysmacros.h).
#    These are bit arithmetic over the caller's status/dev ints; no OS
#    traffic, fully native.
#
# 3. HOST-BRIDGED FUNCTIONS -- identity/process queries with no guest-side
#    state (getpid/getppid/getuid/geteuid/getgid/getegid/getcwd/getcwdb/
#    cpu_count/getlogin/ctermid/strerror) route through the host bridge
#    exactly like mmap.jac's file-backed helpers. When a real descriptor
#    table / libc floor lands in the VM, only those one-line wrappers change.
#
# Out of scope by design (needs live fd table or structured result types):
# the file-descriptor I/O family (open/read/write/lseek/fstat/...),
# stat/scandir/DirEntry and the *_result tuple subclasses, process
# lifecycle (fork/exec/wait*/posix_spawn), and the terminal/pty family.
# Error-channel convention matches the other facades: builtin
# TypeError/ValueError/OSError keep their builtin type identities so guest
# except-handlers match them.

import os as _host_os;

# ---------------- access modes ------------------------------------------------

glob F_OK: int = 0,
     R_OK: int = 4,
     W_OK: int = 2,
     X_OK: int = 1;

# ---------------- O_* open flags (linux/glibc values) -------------------------

glob O_RDONLY: int = 0,
     O_WRONLY: int = 1,
     O_RDWR: int = 2,
     O_ACCMODE: int = 3,

     O_APPEND: int = 1024,
     O_ASYNC: int = 8192,
     O_CLOEXEC: int = 524288,
     O_CREAT: int = 64,
     O_DIRECT: int = 16384,
     O_DIRECTORY: int = 65536,
     O_DSYNC: int = 4096,
     O_EXCL: int = 128,
     O_FSYNC: int = 1052672,
     O_LARGEFILE: int = 0,
     O_NDELAY: int = 2048,
     O_NOATIME: int = 262144,
     O_NOCTTY: int = 256,
     O_NOFOLLOW: int = 131072,
     O_NONBLOCK: int = 2048,
     O_PATH: int = 2097152,
     O_RSYNC: int = 1052672,
     O_SYNC: int = 1052672,
     O_TMPFILE: int = 4259840,
     O_TRUNC: int = 512;

glob SEEK_DATA: int = 3,
     SEEK_HOLE: int = 4;

# ---------------- sysexits.h ---------------------------------------------------

glob EX_OK: int = 0,
     EX_USAGE: int = 64,
     EX_DATAERR: int = 65,
     EX_NOINPUT: int = 66,
     EX_NOUSER: int = 67,
     EX_NOHOST: int = 68,
     EX_UNAVAILABLE: int = 69,
     EX_SOFTWARE: int = 70,
     EX_OSERR: int = 71,
     EX_OSFILE: int = 72,
     EX_CANTCREAT: int = 73,
     EX_IOERR: int = 74,
     EX_TEMPFAIL: int = 75,
     EX_PROTOCOL: int = 76,
     EX_NOPERM: int = 77,
     EX_CONFIG: int = 78,
     EX_NOTFOUND: int = 79;

# ---------------- wait / waitid ------------------------------------------------

glob WCONTINUED: int = 8,
     WNOHANG: int = 1,
     WUNTRACED: int = 2,
     WEXITED: int = 4,
     WSTOPPED: int = 2,
     WNOWAIT: int = 16777216,

     P_ALL: int = 0,
     P_PID: int = 1,
     P_PGID: int = 2,
     P_PIDFD: int = 3;

# si_code CLD_* values
glob CLD_EXITED: int = 1,
     CLD_KILLED: int = 2,
     CLD_DUMPED: int = 3,
     CLD_TRAPPED: int = 4,
     CLD_STOPPED: int = 5,
     CLD_CONTINUED: int = 6;

# ---------------- clone(2) flags -----------------------------------------------

glob CLONE_VM: int = 256,
     CLONE_FS: int = 512,
     CLONE_FILES: int = 1024,
     CLONE_SIGHAND: int = 2048,
     CLONE_NEWTIME: int = 128,
     CLONE_THREAD: int = 65536,
     CLONE_SYSVSEM: int = 262144,
     CLONE_NEWNS: int = 131072,
     CLONE_NEWCGROUP: int = 33554432,
     CLONE_NEWUTS: int = 67108864,
     CLONE_NEWIPC: int = 134217728,
     CLONE_NEWUSER: int = 268435456,
     CLONE_NEWPID: int = 536870912,
     CLONE_NEWNET: int = 1073741824;

# ---------------- scheduling / priority ----------------------------------------

glob SCHED_OTHER: int = 0,
     SCHED_NORMAL: int = 0,
     SCHED_FIFO: int = 1,
     SCHED_RR: int = 2,
     SCHED_BATCH: int = 3,
     SCHED_IDLE: int = 5,
     SCHED_DEADLINE: int = 6,
     SCHED_RESET_ON_FORK: int = 1073741824,

     PRIO_PROCESS: int = 0,
     PRIO_PGRP: int = 1,
     PRIO_USER: int = 2;

# ---------------- posix_fadvise -------------------------------------------------

glob POSIX_FADV_NORMAL: int = 0,
     POSIX_FADV_RANDOM: int = 1,
     POSIX_FADV_SEQUENTIAL: int = 2,
     POSIX_FADV_WILLNEED: int = 3,
     POSIX_FADV_DONTNEED: int = 4,
     POSIX_FADV_NOREUSE: int = 5;

# ---------------- statvfs flag bits --------------------------------------------

glob ST_RDONLY: int = 1,
     ST_NOSUID: int = 2,
     ST_NODEV: int = 4,
     ST_NOEXEC: int = 8,
     ST_SYNCHRONOUS: int = 16,
     ST_MANDLOCK: int = 64,
     ST_WRITE: int = 128,
     ST_APPEND: int = 256,
     ST_NOATIME: int = 1024,
     ST_NODIRATIME: int = 2048,
     ST_RELATIME: int = 4096;

# ---------------- misc kernel-interface constants -------------------------------

glob NGROUPS_MAX: int = 65536,
     TMP_MAX: int = 238328,

     GRND_NONBLOCK: int = 1,
     GRND_RANDOM: int = 2,

     RWF_HIPRI: int = 1,
     RWF_DSYNC: int = 2,
     RWF_SYNC: int = 4,
     RWF_NOWAIT: int = 8,
     RWF_APPEND: int = 16,

     SPLICE_F_MOVE: int = 1,
     SPLICE_F_NONBLOCK: int = 2,
     SPLICE_F_MORE: int = 4,

     XATTR_CREATE: int = 1,
     XATTR_REPLACE: int = 2,
     XATTR_SIZE_MAX: int = 65536;

# eventfd / timerfd / memfd / pidfd creation+behavior flags
glob EFD_CLOEXEC: int = 524288,
     EFD_NONBLOCK: int = 2048,
     EFD_SEMAPHORE: int = 1,

     TFD_CLOEXEC: int = 524288,
     TFD_NONBLOCK: int = 2048,
     TFD_TIMER_ABSTIME: int = 1,
     TFD_TIMER_CANCEL_ON_SET: int = 2,

     PIDFD_NONBLOCK: int = 2048;

# memfd_create seals (MFD_HUGE_* encode log2 hugepage size in high bits)
glob MFD_CLOEXEC: int = 1,
     MFD_ALLOW_SEALING: int = 2,
     MFD_HUGETLB: int = 4,
     MFD_HUGE_SHIFT: int = 26,
     MFD_HUGE_MASK: int = 63,
     MFD_HUGE_64KB: int = 1073741824,
     MFD_HUGE_512KB: int = 1275068416,
     MFD_HUGE_1MB: int = 1342177280,
     MFD_HUGE_2MB: int = 1409286144,
     MFD_HUGE_8MB: int = 1543503872,
     MFD_HUGE_16MB: int = 1610612736,
     MFD_HUGE_32MB: int = 1677721600,
     MFD_HUGE_256MB: int = 1879048192,
     MFD_HUGE_512MB: int = 1946157056,
     MFD_HUGE_1GB: int = 2013265920,
     MFD_HUGE_2GB: int = 2080374784,
     MFD_HUGE_16GB: int = 2281701376;

# dlopen mode bits (RTLD_* surface inserted by all_ins)
glob RTLD_LAZY: int = 1,
     RTLD_NOW: int = 2,
     RTLD_GLOBAL: int = 256,
     RTLD_LOCAL: int = 0,
     RTLD_NODELETE: int = 4096,
     RTLD_NOLOAD: int = 4,
     RTLD_DEEPBIND: int = 8;

# posix_spawn file-action opcodes
glob POSIX_SPAWN_OPEN: int = 0,
     POSIX_SPAWN_CLOSE: int = 1,
     POSIX_SPAWN_DUP2: int = 2,
     POSIX_SPAWN_CLOSEFROM: int = 3;

# ---------------- wait-status macros (glibc sys/wait.h) -------------------------
# Bit layout of a waitpid status word on Linux: low byte carries the signal
# (0x7f means stopped), bit 7 the core flag, high byte the exit code;
# 0xffff is the continued sentinel.

def WIFEXITED(status: int) -> bool {
    return status & 0x7f == 0;
}

def WEXITSTATUS(status: int) -> int {
    return (status >> 8) & 0xff;
}

def WTERMSIG(status: int) -> int {
    return status & 0x7f;
}

def WSTOPSIG(status: int) -> int {
    return (status >> 8) & 0xff;
}

def WCOREDUMP(status: int) -> bool {
    return status & 0x80 != 0;
}

def WIFSIGNALED(status: int) -> bool {
    s = status & 0x7f;
    return s != 0 and s != 0x7f;
}

def WIFSTOPPED(status: int) -> bool {
    return status & 0xff == 0x7f;
}

def WIFCONTINUED(status: int) -> bool {
    # glibc __W_CONTINUED sentinel (Linux).
    return status == 0xffff;
}

def waitstatus_to_exitcode(status: int) -> int {
    # Mirror of os_waitstatus_to_exitcode_impl (UNIX arm): exited ->
    # WEXITSTATUS, signaled -> -WTERMSIG, anything else raises ValueError.
    if WIFEXITED(status) {
        exitcode = WEXITSTATUS(status);
        if exitcode < 0 {
            raise ValueError("invalid WEXITSTATUS: " + str(exitcode));
        }
        return exitcode;
    }
    if WIFSIGNALED(status) {
        signum = WTERMSIG(status);
        if signum <= 0 {
            raise ValueError("invalid WTERMSIG: " + str(signum));
        }
        return -signum;
    }
    if WIFSTOPPED(status) {
        raise ValueError(
            "process stopped by delivery of signal " + str(WSTOPSIG(status))
        );
    }
    raise ValueError("invalid wait status: " + str(status));
}

# ---------------- device numbers (glibc sys/sysmacros.h) ------------------------

def major(dev: int) -> int {
    return ((dev >> 8) & 0xfff) | ((dev >> 32) & ~0xfff);
}

def minor(dev: int) -> int {
    return (dev & 0xff) | ((dev >> 12) & ~0xff);
}

def makedev(major_num: int, minor_num: int) -> int {
    return (
        (minor_num & 0xff)
        | ((major_num & 0xfff) << 8)
        | ((minor_num & ~0xff) << 12)
        | ((major_num & ~0xfff) << 32)
    );
}

# ---------------- host-bridged identity / process floor --------------------------
# One-line pass-throughs over the host bridge; no guest-visible state to
# snapshot, so the wrappers stay total (host OSError propagates unchanged).

def getcwd() -> str {
    return _host_os.getcwd();
}

def getcwdb() -> bytes {
    return _host_os.getcwdb();
}

def getpid() -> int {
    return _host_os.getpid();
}

def getppid() -> int {
    return _host_os.getppid();
}

def getuid() -> int {
    return _host_os.getuid();
}

def geteuid() -> int {
    return _host_os.geteuid();
}

def getgid() -> int {
    return _host_os.getgid();
}

def getegid() -> int {
    return _host_os.getegid();
}

def cpu_count() -> int | None {
    # Host may report an undetectable count; posix.cpu_count is Optional.
    return _host_os.cpu_count();
}

def getlogin() -> str {
    return _host_os.getlogin();
}

def ctermid() -> str {
    return _host_os.ctermid();
}

def strerror(code: int) -> str {
    # errnomodule.c lift owns errno's constant table; this maps code -> text
    # through the same libc strerror the C module calls.
    return _host_os.strerror(code);
}
