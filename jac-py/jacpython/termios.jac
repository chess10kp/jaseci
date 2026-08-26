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

# Host extension fetched by string name through importlib (the same
# convention as ceval's _jac_host_import): a literal ``import termios`` here
# would resolve to THIS facade module and form an import cycle.
::py::
def _termios_host(name):
    # Fetch one attribute off the HOST termios extension by string name via
    # importlib (the same convention as ceval's _jac_host_import): a literal
    # ``import termios`` here would resolve to THIS facade module and form an
    # import cycle. Returns the raw host value; guest ints/strs cross the
    # bridge with identity intact.
    import importlib
    return getattr(importlib.import_module("termios"), name)
::py::


# ---------------- module identity (termios_exec / module docstring) ----------

# PyErr_NewException("termios.error", NULL, NULL); raised by every entry
# point's PyErr_SetFromErrno on syscall failure. Host instances cross the
# bridge with type and message intact, so guest except-handlers match by this
# class proxy.
glob error = _termios_host("error");


# ---------------- baud rates (cfgetospeed/cfsetospeed) ----------------

glob B0 = _termios_host("B0");
glob B50 = _termios_host("B50");
glob B75 = _termios_host("B75");
glob B110 = _termios_host("B110");
glob B134 = _termios_host("B134");
glob B150 = _termios_host("B150");
glob B200 = _termios_host("B200");
glob B300 = _termios_host("B300");
glob B600 = _termios_host("B600");
glob B1200 = _termios_host("B1200");
glob B1800 = _termios_host("B1800");
glob B2400 = _termios_host("B2400");
glob B4800 = _termios_host("B4800");
glob B9600 = _termios_host("B9600");
glob B19200 = _termios_host("B19200");
glob B38400 = _termios_host("B38400");
glob B57600 = _termios_host("B57600");
glob B115200 = _termios_host("B115200");
glob B230400 = _termios_host("B230400");
glob B460800 = _termios_host("B460800");
glob B500000 = _termios_host("B500000");
glob B576000 = _termios_host("B576000");
glob B921600 = _termios_host("B921600");
glob B1000000 = _termios_host("B1000000");
glob B1152000 = _termios_host("B1152000");
glob B1500000 = _termios_host("B1500000");
glob B2000000 = _termios_host("B2000000");
glob B2500000 = _termios_host("B2500000");
glob B3000000 = _termios_host("B3000000");
glob B3500000 = _termios_host("B3500000");
glob B4000000 = _termios_host("B4000000");
glob CBAUDEX = _termios_host("CBAUDEX");

# ---------------- tcsetattr() when-constants ----------------

glob TCSANOW = _termios_host("TCSANOW");
glob TCSADRAIN = _termios_host("TCSADRAIN");
glob TCSAFLUSH = _termios_host("TCSAFLUSH");

# ---------------- tcflush() queue selectors ----------------

glob TCIFLUSH = _termios_host("TCIFLUSH");
glob TCOFLUSH = _termios_host("TCOFLUSH");
glob TCIOFLUSH = _termios_host("TCIOFLUSH");

# ---------------- tcflow() actions ----------------

glob TCOOFF = _termios_host("TCOOFF");
glob TCOON = _termios_host("TCOON");
glob TCIOFF = _termios_host("TCIOFF");
glob TCION = _termios_host("TCION");

# ---------------- c_iflag bits ----------------

glob IGNBRK = _termios_host("IGNBRK");
glob BRKINT = _termios_host("BRKINT");
glob IGNPAR = _termios_host("IGNPAR");
glob PARMRK = _termios_host("PARMRK");
glob INPCK = _termios_host("INPCK");
glob ISTRIP = _termios_host("ISTRIP");
glob INLCR = _termios_host("INLCR");
glob IGNCR = _termios_host("IGNCR");
glob ICRNL = _termios_host("ICRNL");
glob IUCLC = _termios_host("IUCLC");
glob IXON = _termios_host("IXON");
glob IXANY = _termios_host("IXANY");
glob IXOFF = _termios_host("IXOFF");
glob IMAXBEL = _termios_host("IMAXBEL");
glob IUTF8 = _termios_host("IUTF8");

# ---------------- c_oflag bits ----------------

glob OPOST = _termios_host("OPOST");
glob OLCUC = _termios_host("OLCUC");
glob ONLCR = _termios_host("ONLCR");
glob OCRNL = _termios_host("OCRNL");
glob ONOCR = _termios_host("ONOCR");
glob ONLRET = _termios_host("ONLRET");
glob OFILL = _termios_host("OFILL");
glob OFDEL = _termios_host("OFDEL");
glob NLDLY = _termios_host("NLDLY");
glob CRDLY = _termios_host("CRDLY");
glob TABDLY = _termios_host("TABDLY");
glob BSDLY = _termios_host("BSDLY");
glob VTDLY = _termios_host("VTDLY");
glob FFDLY = _termios_host("FFDLY");

# ---------------- c_oflag delay values ----------------

glob NL0 = _termios_host("NL0");
glob NL1 = _termios_host("NL1");
glob CR0 = _termios_host("CR0");
glob CR1 = _termios_host("CR1");
glob CR2 = _termios_host("CR2");
glob CR3 = _termios_host("CR3");
glob TAB0 = _termios_host("TAB0");
glob TAB1 = _termios_host("TAB1");
glob TAB2 = _termios_host("TAB2");
glob TAB3 = _termios_host("TAB3");
glob XTABS = _termios_host("XTABS");
glob BS0 = _termios_host("BS0");
glob BS1 = _termios_host("BS1");
glob VT0 = _termios_host("VT0");
glob VT1 = _termios_host("VT1");
glob FF0 = _termios_host("FF0");
glob FF1 = _termios_host("FF1");

# ---------------- c_cflag bits ----------------

glob CSIZE = _termios_host("CSIZE");
glob CSTOPB = _termios_host("CSTOPB");
glob CREAD = _termios_host("CREAD");
glob PARENB = _termios_host("PARENB");
glob PARODD = _termios_host("PARODD");
glob HUPCL = _termios_host("HUPCL");
glob CLOCAL = _termios_host("CLOCAL");
glob CIBAUD = _termios_host("CIBAUD");
glob CRTSCTS = _termios_host("CRTSCTS");

# ---------------- character sizes ----------------

glob CS5 = _termios_host("CS5");
glob CS6 = _termios_host("CS6");
glob CS7 = _termios_host("CS7");
glob CS8 = _termios_host("CS8");

# ---------------- c_lflag bits ----------------

glob ISIG = _termios_host("ISIG");
glob ICANON = _termios_host("ICANON");
glob XCASE = _termios_host("XCASE");
glob ECHO = _termios_host("ECHO");
glob ECHOE = _termios_host("ECHOE");
glob ECHOK = _termios_host("ECHOK");
glob ECHONL = _termios_host("ECHONL");
glob ECHOCTL = _termios_host("ECHOCTL");
glob ECHOPRT = _termios_host("ECHOPRT");
glob ECHOKE = _termios_host("ECHOKE");
glob FLUSHO = _termios_host("FLUSHO");
glob NOFLSH = _termios_host("NOFLSH");
glob TOSTOP = _termios_host("TOSTOP");
glob PENDIN = _termios_host("PENDIN");
glob IEXTEN = _termios_host("IEXTEN");
glob EXTPROC = _termios_host("EXTPROC");

# ---------------- c_cc indexes (control-char slots) ----------------

glob VINTR = _termios_host("VINTR");
glob VQUIT = _termios_host("VQUIT");
glob VERASE = _termios_host("VERASE");
glob VKILL = _termios_host("VKILL");
glob VEOF = _termios_host("VEOF");
glob VTIME = _termios_host("VTIME");
glob VMIN = _termios_host("VMIN");
glob VSWTC = _termios_host("VSWTC");
glob VSWTCH = _termios_host("VSWTCH");
glob VSTART = _termios_host("VSTART");
glob VSTOP = _termios_host("VSTOP");
glob VSUSP = _termios_host("VSUSP");
glob VEOL = _termios_host("VEOL");
glob VREPRINT = _termios_host("VREPRINT");
glob VDISCARD = _termios_host("VDISCARD");
glob VWERASE = _termios_host("VWERASE");
glob VLNEXT = _termios_host("VLNEXT");
glob VEOL2 = _termios_host("VEOL2");

# ---------------- BSD/extended baud rates and ioctl extras (second table block) ----------------

glob B7200 = _termios_host("B7200");
glob B14400 = _termios_host("B14400");
glob B28800 = _termios_host("B28800");
glob B76800 = _termios_host("B76800");
glob CBAUD = _termios_host("CBAUD");
glob CDSUSP = _termios_host("CDSUSP");
glob CEOF = _termios_host("CEOF");
glob CEOL = _termios_host("CEOL");
glob CEOT = _termios_host("CEOT");
glob CERASE = _termios_host("CERASE");
glob CFLUSH = _termios_host("CFLUSH");
glob CINTR = _termios_host("CINTR");
glob CKILL = _termios_host("CKILL");
glob CLNEXT = _termios_host("CLNEXT");
glob CQUIT = _termios_host("CQUIT");
glob CRPRNT = _termios_host("CRPRNT");
glob CSTART = _termios_host("CSTART");
glob CSTOP = _termios_host("CSTOP");
glob CSUSP = _termios_host("CSUSP");
glob CWERASE = _termios_host("CWERASE");
glob EXTA = _termios_host("EXTA");
glob EXTB = _termios_host("EXTB");

# ---------------- ioctl request codes (linux-specific tail) ----------------

glob FIOASYNC = _termios_host("FIOASYNC");
glob FIOCLEX = _termios_host("FIOCLEX");
glob FIONBIO = _termios_host("FIONBIO");
glob FIONCLEX = _termios_host("FIONCLEX");
glob FIONREAD = _termios_host("FIONREAD");
glob IBSHIFT = _termios_host("IBSHIFT");
glob IOCSIZE_MASK = _termios_host("IOCSIZE_MASK");
glob IOCSIZE_SHIFT = _termios_host("IOCSIZE_SHIFT");
glob NCCS = _termios_host("NCCS");
glob N_MOUSE = _termios_host("N_MOUSE");
glob N_PPP = _termios_host("N_PPP");
glob N_SLIP = _termios_host("N_SLIP");
glob N_STRIP = _termios_host("N_STRIP");
glob N_TTY = _termios_host("N_TTY");
glob TCFLSH = _termios_host("TCFLSH");
glob TCGETA = _termios_host("TCGETA");
glob TCGETS = _termios_host("TCGETS");
glob TCSBRK = _termios_host("TCSBRK");
glob TCSBRKP = _termios_host("TCSBRKP");
glob TCSETA = _termios_host("TCSETA");
glob TCSETAF = _termios_host("TCSETAF");
glob TCSETAW = _termios_host("TCSETAW");
glob TCSETS = _termios_host("TCSETS");
glob TCSETSF = _termios_host("TCSETSF");
glob TCSETSW = _termios_host("TCSETSW");
glob TCXONC = _termios_host("TCXONC");
glob TIOCCONS = _termios_host("TIOCCONS");
glob TIOCEXCL = _termios_host("TIOCEXCL");
glob TIOCGETD = _termios_host("TIOCGETD");
glob TIOCGICOUNT = _termios_host("TIOCGICOUNT");
glob TIOCGLCKTRMIOS = _termios_host("TIOCGLCKTRMIOS");
glob TIOCGPGRP = _termios_host("TIOCGPGRP");
glob TIOCGSERIAL = _termios_host("TIOCGSERIAL");
glob TIOCGSOFTCAR = _termios_host("TIOCGSOFTCAR");
glob TIOCGWINSZ = _termios_host("TIOCGWINSZ");
glob TIOCINQ = _termios_host("TIOCINQ");
glob TIOCLINUX = _termios_host("TIOCLINUX");
glob TIOCMBIC = _termios_host("TIOCMBIC");
glob TIOCMBIS = _termios_host("TIOCMBIS");
glob TIOCMGET = _termios_host("TIOCMGET");
glob TIOCMIWAIT = _termios_host("TIOCMIWAIT");
glob TIOCMSET = _termios_host("TIOCMSET");
glob TIOCM_CAR = _termios_host("TIOCM_CAR");
glob TIOCM_CD = _termios_host("TIOCM_CD");
glob TIOCM_CTS = _termios_host("TIOCM_CTS");
glob TIOCM_DSR = _termios_host("TIOCM_DSR");
glob TIOCM_DTR = _termios_host("TIOCM_DTR");
glob TIOCM_LE = _termios_host("TIOCM_LE");
glob TIOCM_RI = _termios_host("TIOCM_RI");
glob TIOCM_RNG = _termios_host("TIOCM_RNG");
glob TIOCM_RTS = _termios_host("TIOCM_RTS");
glob TIOCM_SR = _termios_host("TIOCM_SR");
glob TIOCM_ST = _termios_host("TIOCM_ST");
glob TIOCNOTTY = _termios_host("TIOCNOTTY");
glob TIOCNXCL = _termios_host("TIOCNXCL");
glob TIOCOUTQ = _termios_host("TIOCOUTQ");
glob TIOCPKT = _termios_host("TIOCPKT");
glob TIOCPKT_DATA = _termios_host("TIOCPKT_DATA");
glob TIOCPKT_DOSTOP = _termios_host("TIOCPKT_DOSTOP");
glob TIOCPKT_FLUSHREAD = _termios_host("TIOCPKT_FLUSHREAD");
glob TIOCPKT_FLUSHWRITE = _termios_host("TIOCPKT_FLUSHWRITE");
glob TIOCPKT_NOSTOP = _termios_host("TIOCPKT_NOSTOP");
glob TIOCPKT_START = _termios_host("TIOCPKT_START");
glob TIOCPKT_STOP = _termios_host("TIOCPKT_STOP");
glob TIOCSCTTY = _termios_host("TIOCSCTTY");
glob TIOCSERCONFIG = _termios_host("TIOCSERCONFIG");
glob TIOCSERGETLSR = _termios_host("TIOCSERGETLSR");
glob TIOCSERGETMULTI = _termios_host("TIOCSERGETMULTI");
glob TIOCSERGSTRUCT = _termios_host("TIOCSERGSTRUCT");
glob TIOCSERGWILD = _termios_host("TIOCSERGWILD");
glob TIOCSERSETMULTI = _termios_host("TIOCSERSETMULTI");
glob TIOCSERSWILD = _termios_host("TIOCSERSWILD");
glob TIOCSER_TEMT = _termios_host("TIOCSER_TEMT");
glob TIOCSETD = _termios_host("TIOCSETD");
glob TIOCSLCKTRMIOS = _termios_host("TIOCSLCKTRMIOS");
glob TIOCSPGRP = _termios_host("TIOCSPGRP");
glob TIOCSSERIAL = _termios_host("TIOCSSERIAL");
glob TIOCSSOFTCAR = _termios_host("TIOCSSOFTCAR");
glob TIOCSTI = _termios_host("TIOCSTI");
glob TIOCSWINSZ = _termios_host("TIOCSWINSZ");
glob _POSIX_VDISABLE = _termios_host("_POSIX_VDISABLE");


# ---------------- callables (termios_methods[], 1:1 host-bound) --------------

# tcgetattr(fd) -> [iflag, oflag, cflag, lflag, ispeed, ospeed, cc]; cc is an
# NCCS-list of length-1 bytes, with VMIN/VTIME slots as ints in noncanonical
# mode (termios_tcgetattr_impl).
glob tcgetattr = _termios_host("tcgetattr");

# tcsetattr(fd, when, attributes): attributes must be a 7-element list like
# tcgetattr()'s result; hidden tty fields are preserved from a fresh
# tcgetattr of the same fd (termios_tcsetattr_impl).
glob tcsetattr = _termios_host("tcsetattr");

# tcsendbreak(fd, duration) / tcdrain(fd) / tcflush(fd, queue) /
# tcflow(fd, action): None on success, termios.error from errno on -1.
glob tcsendbreak = _termios_host("tcsendbreak");
glob tcdrain = _termios_host("tcdrain");
glob tcflush = _termios_host("tcflush");
glob tcflow = _termios_host("tcflow");

# tcgetwinsize(fd) -> (ws_row, ws_col) via TIOCGWINSZ;
# tcsetwinsize(fd, winsize) validates the two-item sequence and range-checks
# unsigned-short truncation before TIOCSWINSZ (termios_tcsetwinsize_impl).
glob tcgetwinsize = _termios_host("tcgetwinsize");
glob tcsetwinsize = _termios_host("tcsetwinsize");
