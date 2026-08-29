# Product-path facade for signal (lift of reference/cpython/Modules/signalmodule.c).
# Guest-native constants and synchronous dispatch core; OS-bound members delegate
# to host signal (alarm, itimers, pthread_sigmask, sigwait family, enums).

import signal as host_signal;

glob NSIG: int = 65,
     SIG_BLOCK: int = 0,
     SIG_UNBLOCK: int = 1,
     SIG_SETMASK: int = 2,
     SIGHUP: int = 1,
     SIGINT: int = 2,
     SIGQUIT: int = 3,
     SIGILL: int = 4,
     SIGTRAP: int = 5,
     SIGIOT: int = 6,
     SIGABRT: int = 6,
     SIGFPE: int = 8,
     SIGKILL: int = 9,
     SIGBUS: int = 7,
     SIGSEGV: int = 11,
     SIGSYS: int = 31,
     SIGPIPE: int = 13,
     SIGALRM: int = 14,
     SIGTERM: int = 15,
     SIGUSR1: int = 10,
     SIGUSR2: int = 12,
     SIGCLD: int = 17,
     SIGCHLD: int = 17,
     SIGPWR: int = 30,
     SIGIO: int = 29,
     SIGURG: int = 23,
     SIGWINCH: int = 28,
     SIGPOLL: int = 29,
     SIGSTOP: int = 19,
     SIGSTKFLT: int = 16,
     SIGTSTP: int = 20,
     SIGCONT: int = 18,
     SIGTTIN: int = 21,
     SIGTTOU: int = 22,
     SIGVTALRM: int = 26,
     SIGPROF: int = 27,
     SIGXCPU: int = 24,
     SIGXFSZ: int = 25,
     SIGRTMIN: int = 34,
     SIGRTMAX: int = 64,
     ITIMER_REAL: int = 0,
     ITIMER_VIRTUAL: int = 1,
     ITIMER_PROF: int = 2,
     SIG_DFL: int = 0,
     SIG_IGN: int = 1;

def signal(signum: any, handler: any) -> any {
    return host_signal.signal(signum, handler);
}

def getsignal(signum: any) -> any {
    return host_signal.getsignal(signum);
}

def raise_signal(signum: any) -> any {
    return host_signal.raise_signal(signum);
}

def default_int_handler(signum: any, frame: any) -> None {
    host_signal.default_int_handler(signum, frame);
}

def alarm(seconds: any) -> any {
    return host_signal.alarm(seconds);
}

def pause() -> any {
    return host_signal.pause();
}

def siginterrupt(signum: any, flag: any) -> any {
    return host_signal.siginterrupt(signum, flag);
}

def setitimer(which: any, seconds: any, interval: any = 0.0) -> any {
    return host_signal.setitimer(which, seconds, interval);
}

def getitimer(which: any) -> any {
    return host_signal.getitimer(which);
}

def pthread_sigmask(how: any, mask: any) -> any {
    return host_signal.pthread_sigmask(how, mask);
}

def sigpending() -> any {
    return host_signal.sigpending();
}

def sigwait(sigset: any) -> any {
    return host_signal.sigwait(sigset);
}

def valid_signals() -> any {
    return host_signal.valid_signals();
}

def strsignal(signum: any) -> any {
    return host_signal.strsignal(signum);
}
