# Product-path facade for termios (POSIX terminal I/O control).
# Reference: CPython 3.14 ``Modules/termios.c`` exercised by
# Lib/test/test_termios.py (suite_routing: test_termios -> QUARANTINE).
#
# REPRESENTATION CHOICE (divergence ledger candidate): the C original is a thin
# binding over the POSIX tty floor -- tcgetattr/tcsetattr/tcsendbreak/tcdrain/
# tcflush/tcflow plus two TIOCGWINSZ/TIOCSWINSZ ioctls, each one clinic parse,
# one syscall and -1 -> PyErr_SetFromErrno(TermiosError). That floor cannot be
# reimplemented in pure Jac (kernel tty state), so this facade delegates it to
# the host ``termios`` extension (the same glibc build the interpreter ships),
# exactly like curses.jac delegates to host _curses.
#
# The facade owns the Python-visible module surface: exception identity and the
# full int-constant block from the termios_constants[] table in the C file,
# mirrored at import time so `import termios` observes every name the C exec
# slot installs. The glob list below is that table's Linux/glibc surface --
# every entry whose guard macro is defined here -- in C insertion order
# (verified against the host interpreter's own termios module at authoring
# time; NCCS=32 on Linux).
#
# Unlike curses (flexible-arity API needing untyped binding), all eight
# termios entry points have fixed clinic arity, but they stay 1:1 host-bound
# globs for the same reason: their semantics ARE the syscalls, and wrapping
# would only re-type arguments the bridge already checks.
#
# Guest-import wiring: ceval.jac delegate_modules carries "termios" -> "full",
# so guest `import termios` resolves through the delegation snapshot (native
# int constants, proxy-free) instead of a raw PyHostProxy module whose
# constants leak host int identity into guest arithmetic -- same rationale as
# errno's native facade.

import termios as _host;


# ---------------- module identity (termios_exec / module docstring) ----------

# PyErr_NewException("termios.error", NULL, NULL); raised by every entry
# point's PyErr_SetFromErrno on syscall failure. Host instances cross the
# bridge with type and message intact, so guest except-handlers match by this
# class proxy.
glob error = _host.error;


# ---------------- baud rates (cfgetospeed/cfsetospeed) ----------------

glob B0 = _host.B0;
glob B50 = _host.B50;
glob B75 = _host.B75;
glob B110 = _host.B110;
glob B134 = _host.B134;
glob B150 = _host.B150;
glob B200 = _host.B200;
glob B300 = _host.B300;
glob B600 = _host.B600;
glob B1200 = _host.B1200;
glob B1800 = _host.B1800;
glob B2400 = _host.B2400;
glob B4800 = _host.B4800;
glob B9600 = _host.B9600;
glob B19200 = _host.B19200;
glob B38400 = _host.B38400;
glob B57600 = _host.B57600;
glob B115200 = _host.B115200;
glob B230400 = _host.B230400;
glob B460800 = _host.B460800;
glob B500000 = _host.B500000;
glob B576000 = _host.B576000;
glob B921600 = _host.B921600;
glob B1000000 = _host.B1000000;
glob B1152000 = _host.B1152000;
glob B1500000 = _host.B1500000;
glob B2000000 = _host.B2000000;
glob B2500000 = _host.B2500000;
glob B3000000 = _host.B3000000;
glob B3500000 = _host.B3500000;
glob B4000000 = _host.B4000000;
glob CBAUDEX = _host.CBAUDEX;

# ---------------- tcsetattr() when-constants ----------------

glob TCSANOW = _host.TCSANOW;
glob TCSADRAIN = _host.TCSADRAIN;
glob TCSAFLUSH = _host.TCSAFLUSH;

# ---------------- tcflush() queue selectors ----------------

glob TCIFLUSH = _host.TCIFLUSH;
glob TCOFLUSH = _host.TCOFLUSH;
glob TCIOFLUSH = _host.TCIOFLUSH;

# ---------------- tcflow() actions ----------------

glob TCOOFF = _host.TCOOFF;
glob TCOON = _host.TCOON;
glob TCIOFF = _host.TCIOFF;
glob TCION = _host.TCION;

# ---------------- c_iflag bits ----------------

glob IGNBRK = _host.IGNBRK;
glob BRKINT = _host.BRKINT;
glob IGNPAR = _host.IGNPAR;
glob PARMRK = _host.PARMRK;
glob INPCK = _host.INPCK;
glob ISTRIP = _host.ISTRIP;
glob INLCR = _host.INLCR;
glob IGNCR = _host.IGNCR;
glob ICRNL = _host.ICRNL;
glob IUCLC = _host.IUCLC;
glob IXON = _host.IXON;
glob IXANY = _host.IXANY;
glob IXOFF = _host.IXOFF;
glob IMAXBEL = _host.IMAXBEL;
glob IUTF8 = _host.IUTF8;

# ---------------- c_oflag bits ----------------

glob OPOST = _host.OPOST;
glob OLCUC = _host.OLCUC;
glob ONLCR = _host.ONLCR;
glob OCRNL = _host.OCRNL;
glob ONOCR = _host.ONOCR;
glob ONLRET = _host.ONLRET;
glob OFILL = _host.OFILL;
glob OFDEL = _host.OFDEL;
glob NLDLY = _host.NLDLY;
glob CRDLY = _host.CRDLY;
glob TABDLY = _host.TABDLY;
glob BSDLY = _host.BSDLY;
glob VTDLY = _host.VTDLY;
glob FFDLY = _host.FFDLY;

# ---------------- c_oflag delay values ----------------

glob NL0 = _host.NL0;
glob NL1 = _host.NL1;
glob CR0 = _host.CR0;
glob CR1 = _host.CR1;
glob CR2 = _host.CR2;
glob CR3 = _host.CR3;
glob TAB0 = _host.TAB0;
glob TAB1 = _host.TAB1;
glob TAB2 = _host.TAB2;
glob TAB3 = _host.TAB3;
glob XTABS = _host.XTABS;
glob BS0 = _host.BS0;
glob BS1 = _host.BS1;
glob VT0 = _host.VT0;
glob VT1 = _host.VT1;
glob FF0 = _host.FF0;
glob FF1 = _host.FF1;

# ---------------- c_cflag bits ----------------

glob CSIZE = _host.CSIZE;
glob CSTOPB = _host.CSTOPB;
glob CREAD = _host.CREAD;
glob PARENB = _host.PARENB;
glob PARODD = _host.PARODD;
glob HUPCL = _host.HUPCL;
glob CLOCAL = _host.CLOCAL;
glob CIBAUD = _host.CIBAUD;
glob CRTSCTS = _host.CRTSCTS;

# ---------------- character sizes ----------------

glob CS5 = _host.CS5;
glob CS6 = _host.CS6;
glob CS7 = _host.CS7;
glob CS8 = _host.CS8;

# ---------------- c_lflag bits ----------------

glob ISIG = _host.ISIG;
glob ICANON = _host.ICANON;
glob XCASE = _host.XCASE;
glob ECHO = _host.ECHO;
glob ECHOE = _host.ECHOE;
glob ECHOK = _host.ECHOK;
glob ECHONL = _host.ECHONL;
glob ECHOCTL = _host.ECHOCTL;
glob ECHOPRT = _host.ECHOPRT;
glob ECHOKE = _host.ECHOKE;
glob FLUSHO = _host.FLUSHO;
glob NOFLSH = _host.NOFLSH;
glob TOSTOP = _host.TOSTOP;
glob PENDIN = _host.PENDIN;
glob IEXTEN = _host.IEXTEN;
glob EXTPROC = _host.EXTPROC;

# ---------------- c_cc indexes (control-char slots) ----------------

glob VINTR = _host.VINTR;
glob VQUIT = _host.VQUIT;
glob VERASE = _host.VERASE;
glob VKILL = _host.VKILL;
glob VEOF = _host.VEOF;
glob VTIME = _host.VTIME;
glob VMIN = _host.VMIN;
glob VSWTC = _host.VSWTC;
glob VSWTCH = _host.VSWTCH;
glob VSTART = _host.VSTART;
glob VSTOP = _host.VSTOP;
glob VSUSP = _host.VSUSP;
glob VEOL = _host.VEOL;
glob VREPRINT = _host.VREPRINT;
glob VDISCARD = _host.VDISCARD;
glob VWERASE = _host.VWERASE;
glob VLNEXT = _host.VLNEXT;
glob VEOL2 = _host.VEOL2;

# ---------------- BSD/extended baud rates and ioctl extras (second table block) ----------------

glob B7200 = _host.B7200;
glob B14400 = _host.B14400;
glob B28800 = _host.B28800;
glob B76800 = _host.B76800;
glob CBAUD = _host.CBAUD;
glob CDSUSP = _host.CDSUSP;
glob CEOF = _host.CEOF;
glob CEOL = _host.CEOL;
glob CEOT = _host.CEOT;
glob CERASE = _host.CERASE;
glob CFLUSH = _host.CFLUSH;
glob CINTR = _host.CINTR;
glob CKILL = _host.CKILL;
glob CLNEXT = _host.CLNEXT;
glob CQUIT = _host.CQUIT;
glob CRPRNT = _host.CRPRNT;
glob CSTART = _host.CSTART;
glob CSTOP = _host.CSTOP;
glob CSUSP = _host.CSUSP;
glob CWERASE = _host.CWERASE;
glob EXTA = _host.EXTA;
glob EXTB = _host.EXTB;

# ---------------- ioctl request codes (linux-specific tail) ----------------

glob FIOASYNC = _host.FIOASYNC;
glob FIOCLEX = _host.FIOCLEX;
glob FIONBIO = _host.FIONBIO;
glob FIONCLEX = _host.FIONCLEX;
glob FIONREAD = _host.FIONREAD;
glob IBSHIFT = _host.IBSHIFT;
glob IOCSIZE_MASK = _host.IOCSIZE_MASK;
glob IOCSIZE_SHIFT = _host.IOCSIZE_SHIFT;
glob NCCS = _host.NCCS;
glob N_MOUSE = _host.N_MOUSE;
glob N_PPP = _host.N_PPP;
glob N_SLIP = _host.N_SLIP;
glob N_STRIP = _host.N_STRIP;
glob N_TTY = _host.N_TTY;
glob TCFLSH = _host.TCFLSH;
glob TCGETA = _host.TCGETA;
glob TCGETS = _host.TCGETS;
glob TCSBRK = _host.TCSBRK;
glob TCSBRKP = _host.TCSBRKP;
glob TCSETA = _host.TCSETA;
glob TCSETAF = _host.TCSETAF;
glob TCSETAW = _host.TCSETAW;
glob TCSETS = _host.TCSETS;
glob TCSETSF = _host.TCSETSF;
glob TCSETSW = _host.TCSETSW;
glob TCXONC = _host.TCXONC;
glob TIOCCONS = _host.TIOCCONS;
glob TIOCEXCL = _host.TIOCEXCL;
glob TIOCGETD = _host.TIOCGETD;
glob TIOCGICOUNT = _host.TIOCGICOUNT;
glob TIOCGLCKTRMIOS = _host.TIOCGLCKTRMIOS;
glob TIOCGPGRP = _host.TIOCGPGRP;
glob TIOCGSERIAL = _host.TIOCGSERIAL;
glob TIOCGSOFTCAR = _host.TIOCGSOFTCAR;
glob TIOCGWINSZ = _host.TIOCGWINSZ;
glob TIOCINQ = _host.TIOCINQ;
glob TIOCLINUX = _host.TIOCLINUX;
glob TIOCMBIC = _host.TIOCMBIC;
glob TIOCMBIS = _host.TIOCMBIS;
glob TIOCMGET = _host.TIOCMGET;
glob TIOCMIWAIT = _host.TIOCMIWAIT;
glob TIOCMSET = _host.TIOCMSET;
glob TIOCM_CAR = _host.TIOCM_CAR;
glob TIOCM_CD = _host.TIOCM_CD;
glob TIOCM_CTS = _host.TIOCM_CTS;
glob TIOCM_DSR = _host.TIOCM_DSR;
glob TIOCM_DTR = _host.TIOCM_DTR;
glob TIOCM_LE = _host.TIOCM_LE;
glob TIOCM_RI = _host.TIOCM_RI;
glob TIOCM_RNG = _host.TIOCM_RNG;
glob TIOCM_RTS = _host.TIOCM_RTS;
glob TIOCM_SR = _host.TIOCM_SR;
glob TIOCM_ST = _host.TIOCM_ST;
glob TIOCNOTTY = _host.TIOCNOTTY;
glob TIOCNXCL = _host.TIOCNXCL;
glob TIOCOUTQ = _host.TIOCOUTQ;
glob TIOCPKT = _host.TIOCPKT;
glob TIOCPKT_DATA = _host.TIOCPKT_DATA;
glob TIOCPKT_DOSTOP = _host.TIOCPKT_DOSTOP;
glob TIOCPKT_FLUSHREAD = _host.TIOCPKT_FLUSHREAD;
glob TIOCPKT_FLUSHWRITE = _host.TIOCPKT_FLUSHWRITE;
glob TIOCPKT_NOSTOP = _host.TIOCPKT_NOSTOP;
glob TIOCPKT_START = _host.TIOCPKT_START;
glob TIOCPKT_STOP = _host.TIOCPKT_STOP;
glob TIOCSCTTY = _host.TIOCSCTTY;
glob TIOCSERCONFIG = _host.TIOCSERCONFIG;
glob TIOCSERGETLSR = _host.TIOCSERGETLSR;
glob TIOCSERGETMULTI = _host.TIOCSERGETMULTI;
glob TIOCSERGSTRUCT = _host.TIOCSERGSTRUCT;
glob TIOCSERGWILD = _host.TIOCSERGWILD;
glob TIOCSERSETMULTI = _host.TIOCSERSETMULTI;
glob TIOCSERSWILD = _host.TIOCSERSWILD;
glob TIOCSER_TEMT = _host.TIOCSER_TEMT;
glob TIOCSETD = _host.TIOCSETD;
glob TIOCSLCKTRMIOS = _host.TIOCSLCKTRMIOS;
glob TIOCSPGRP = _host.TIOCSPGRP;
glob TIOCSSERIAL = _host.TIOCSSERIAL;
glob TIOCSSOFTCAR = _host.TIOCSSOFTCAR;
glob TIOCSTI = _host.TIOCSTI;
glob TIOCSWINSZ = _host.TIOCSWINSZ;
glob _POSIX_VDISABLE = _host._POSIX_VDISABLE;


# ---------------- callables (termios_methods[], 1:1 host-bound) --------------

# tcgetattr(fd) -> [iflag, oflag, cflag, lflag, ispeed, ospeed, cc]; cc is an
# NCCS-list of length-1 bytes, with VMIN/VTIME slots as ints in noncanonical
# mode (termios_tcgetattr_impl).
glob tcgetattr = _host.tcgetattr;

# tcsetattr(fd, when, attributes): attributes must be a 7-element list like
# tcgetattr()'s result; hidden tty fields are preserved from a fresh
# tcgetattr of the same fd (termios_tcsetattr_impl).
glob tcsetattr = _host.tcsetattr;

# tcsendbreak(fd, duration) / tcdrain(fd) / tcflush(fd, queue) /
# tcflow(fd, action): None on success, termios.error from errno on -1.
glob tcsendbreak = _host.tcsendbreak;
glob tcdrain = _host.tcdrain;
glob tcflush = _host.tcflush;
glob tcflow = _host.tcflow;

# tcgetwinsize(fd) -> (ws_row, ws_col) via TIOCGWINSZ;
# tcsetwinsize(fd, winsize) validates the two-item sequence and range-checks
# unsigned-short truncation before TIOCSWINSZ (termios_tcsetwinsize_impl).
glob tcgetwinsize = _host.tcgetwinsize;
glob tcsetwinsize = _host.tcsetwinsize;
