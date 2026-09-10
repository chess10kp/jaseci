# Product-path facade for _curses (terminal-independent character-cell screens).
# Reference: CPython 3.14 ``Modules/_cursesmodule.c`` exercised by
# Lib/test/test_curses.py (suite_routing: test_curses -> QUARANTINE,
# facade-module:curses->_curses).
#
# REPRESENTATION CHOICE (divergence ledger candidate): the C original is a thin
# binding over the ncurses floor -- nearly every function is clinic argument
# parsing, one ncurses call, then ERR -> _curses.error. That floor cannot be
# reimplemented in pure Jac (terminfo queries, tty modes, cell updates), so
# this facade delegates it to the host ``_curses`` extension (the same libncurses
# build the interpreter ships), exactly like bz2.jac delegates to host _bz2.
# The facade owns the Python-visible module surface: exception identity, the
# window type handle and the full SetDictInt constant block from
# cursesmodule_exec, mirrored at import time so `import curses` observes every
# name the C exec slot installs before initscr().
#
# Known divergence: the C module injects ACS_* graphic-symbol constants into
# the module dict only after initscr() succeeds (they are undefined before
# terminfo setup). Jac modules cannot grow attributes post-import, so those
# names are intentionally absent here until a dynamic-attribute mechanism
# exists; all other constants are static and mirrored below.
#
# Callables are bound 1:1 to the host extension rather than wrapped in typed
# Jac defs: most of the API has flexible arity overloads (addstr(y, x, str),
# getstr with prompt/echo args) that fixed-arity Jac signatures cannot express
# without dropping real host behavior.

import _curses;


# ---------------- module identity (cursesmodule_exec) ----------------

# PyErr_NewException("_curses.error", NULL, NULL) -- host instance crosses the
# bridge with type and message intact, so guest except-handlers match it by
# this class proxy.
glob error = _curses.error;

# PyCursesWindow_Type handle; newwin/newpad/initscr hand back its instances.
glob window = _curses.window;

# PyCursesVersion bytes ("ncurses-experimental" lineage), set as both
# `version` and `__version__` by cursesmodule_exec.
glob version = _curses.version;
glob __version__ = _curses.__version__;

# ncurses_version structseq (NCURSES_VERSION build info).
glob ncurses_version = _curses.ncurses_version;


# ---------------- ERR / OK ----------------

glob ERR: int = -1;
glob OK: int = 0;


# ---------------- A_* attribute masks (SetDictInt block) ----------------

glob A_ATTRIBUTES = _curses.A_ATTRIBUTES;
glob A_NORMAL = _curses.A_NORMAL;
glob A_STANDOUT = _curses.A_STANDOUT;
glob A_UNDERLINE = _curses.A_UNDERLINE;
glob A_REVERSE = _curses.A_REVERSE;
glob A_BLINK = _curses.A_BLINK;
glob A_DIM = _curses.A_DIM;
glob A_BOLD = _curses.A_BOLD;
glob A_ALTCHARSET = _curses.A_ALTCHARSET;
glob A_INVIS = _curses.A_INVIS;
glob A_PROTECT = _curses.A_PROTECT;
glob A_CHARTEXT = _curses.A_CHARTEXT;
glob A_COLOR = _curses.A_COLOR;

# Strict-SYSV curses never has these; ncurses always does.
glob A_HORIZONTAL = _curses.A_HORIZONTAL;
glob A_LEFT = _curses.A_LEFT;
glob A_LOW = _curses.A_LOW;
glob A_RIGHT = _curses.A_RIGHT;
glob A_TOP = _curses.A_TOP;
glob A_VERTICAL = _curses.A_VERTICAL;

# ncurses extension (A_ITALIC gate: NCURSES_EXT_FUNCS).
glob A_ITALIC = _curses.A_ITALIC;


# ---------------- COLOR_* base palette ----------------

glob COLOR_BLACK = _curses.COLOR_BLACK;
glob COLOR_RED = _curses.COLOR_RED;
glob COLOR_GREEN = _curses.COLOR_GREEN;
glob COLOR_YELLOW = _curses.COLOR_YELLOW;
glob COLOR_BLUE = _curses.COLOR_BLUE;
glob COLOR_MAGENTA = _curses.COLOR_MAGENTA;
glob COLOR_CYAN = _curses.COLOR_CYAN;
glob COLOR_WHITE = _curses.COLOR_WHITE;


# ---------------- mouse constants (NCURSES_MOUSE_VERSION) ----------------

glob BUTTON1_PRESSED = _curses.BUTTON1_PRESSED;
glob BUTTON1_RELEASED = _curses.BUTTON1_RELEASED;
glob BUTTON1_CLICKED = _curses.BUTTON1_CLICKED;
glob BUTTON1_DOUBLE_CLICKED = _curses.BUTTON1_DOUBLE_CLICKED;
glob BUTTON1_TRIPLE_CLICKED = _curses.BUTTON1_TRIPLE_CLICKED;

glob BUTTON2_PRESSED = _curses.BUTTON2_PRESSED;
glob BUTTON2_RELEASED = _curses.BUTTON2_RELEASED;
glob BUTTON2_CLICKED = _curses.BUTTON2_CLICKED;
glob BUTTON2_DOUBLE_CLICKED = _curses.BUTTON2_DOUBLE_CLICKED;
glob BUTTON2_TRIPLE_CLICKED = _curses.BUTTON2_TRIPLE_CLICKED;

glob BUTTON3_PRESSED = _curses.BUTTON3_PRESSED;
glob BUTTON3_RELEASED = _curses.BUTTON3_RELEASED;
glob BUTTON3_CLICKED = _curses.BUTTON3_CLICKED;
glob BUTTON3_DOUBLE_CLICKED = _curses.BUTTON3_DOUBLE_CLICKED;
glob BUTTON3_TRIPLE_CLICKED = _curses.BUTTON3_TRIPLE_CLICKED;

glob BUTTON4_PRESSED = _curses.BUTTON4_PRESSED;
glob BUTTON4_RELEASED = _curses.BUTTON4_RELEASED;
glob BUTTON4_CLICKED = _curses.BUTTON4_CLICKED;
glob BUTTON4_DOUBLE_CLICKED = _curses.BUTTON4_DOUBLE_CLICKED;
glob BUTTON4_TRIPLE_CLICKED = _curses.BUTTON4_TRIPLE_CLICKED;

glob BUTTON5_PRESSED = _curses.BUTTON5_PRESSED;
glob BUTTON5_RELEASED = _curses.BUTTON5_RELEASED;
glob BUTTON5_CLICKED = _curses.BUTTON5_CLICKED;
glob BUTTON5_DOUBLE_CLICKED = _curses.BUTTON5_DOUBLE_CLICKED;
glob BUTTON5_TRIPLE_CLICKED = _curses.BUTTON5_TRIPLE_CLICKED;

glob BUTTON_SHIFT = _curses.BUTTON_SHIFT;
glob BUTTON_CTRL = _curses.BUTTON_CTRL;
glob BUTTON_ALT = _curses.BUTTON_ALT;

glob ALL_MOUSE_EVENTS = _curses.ALL_MOUSE_EVENTS;
glob REPORT_MOUSE_POSITION = _curses.REPORT_MOUSE_POSITION;


# ---------------- KEY_* codes (keyname() walk, KEY_MIN..KEY_MAX) ----------------

glob KEY_MIN = _curses.KEY_MIN;
glob KEY_BREAK = _curses.KEY_BREAK;
glob KEY_SRESET = _curses.KEY_SRESET;
glob KEY_RESET = _curses.KEY_RESET;
glob KEY_DOWN = _curses.KEY_DOWN;
glob KEY_UP = _curses.KEY_UP;
glob KEY_LEFT = _curses.KEY_LEFT;
glob KEY_RIGHT = _curses.KEY_RIGHT;
glob KEY_HOME = _curses.KEY_HOME;
glob KEY_BACKSPACE = _curses.KEY_BACKSPACE;
glob KEY_F0 = _curses.KEY_F0;
glob KEY_F1 = _curses.KEY_F1;
glob KEY_F2 = _curses.KEY_F2;
glob KEY_F3 = _curses.KEY_F3;
glob KEY_F4 = _curses.KEY_F4;
glob KEY_F5 = _curses.KEY_F5;
glob KEY_F6 = _curses.KEY_F6;
glob KEY_F7 = _curses.KEY_F7;
glob KEY_F8 = _curses.KEY_F8;
glob KEY_F9 = _curses.KEY_F9;
glob KEY_F10 = _curses.KEY_F10;
glob KEY_F11 = _curses.KEY_F11;
glob KEY_F12 = _curses.KEY_F12;
glob KEY_F13 = _curses.KEY_F13;
glob KEY_F14 = _curses.KEY_F14;
glob KEY_F15 = _curses.KEY_F15;
glob KEY_F16 = _curses.KEY_F16;
glob KEY_F17 = _curses.KEY_F17;
glob KEY_F18 = _curses.KEY_F18;
glob KEY_F19 = _curses.KEY_F19;
glob KEY_F20 = _curses.KEY_F20;
glob KEY_F21 = _curses.KEY_F21;
glob KEY_F22 = _curses.KEY_F22;
glob KEY_F23 = _curses.KEY_F23;
glob KEY_F24 = _curses.KEY_F24;
glob KEY_F25 = _curses.KEY_F25;
glob KEY_F26 = _curses.KEY_F26;
glob KEY_F27 = _curses.KEY_F27;
glob KEY_F28 = _curses.KEY_F28;
glob KEY_F29 = _curses.KEY_F29;
glob KEY_F30 = _curses.KEY_F30;
glob KEY_F31 = _curses.KEY_F31;
glob KEY_F32 = _curses.KEY_F32;
glob KEY_F33 = _curses.KEY_F33;
glob KEY_F34 = _curses.KEY_F34;
glob KEY_F35 = _curses.KEY_F35;
glob KEY_F36 = _curses.KEY_F36;
glob KEY_F37 = _curses.KEY_F37;
glob KEY_F38 = _curses.KEY_F38;
glob KEY_F39 = _curses.KEY_F39;
glob KEY_F40 = _curses.KEY_F40;
glob KEY_F41 = _curses.KEY_F41;
glob KEY_F42 = _curses.KEY_F42;
glob KEY_F43 = _curses.KEY_F43;
glob KEY_F44 = _curses.KEY_F44;
glob KEY_F45 = _curses.KEY_F45;
glob KEY_F46 = _curses.KEY_F46;
glob KEY_F47 = _curses.KEY_F47;
glob KEY_F48 = _curses.KEY_F48;
glob KEY_F49 = _curses.KEY_F49;
glob KEY_F50 = _curses.KEY_F50;
glob KEY_F51 = _curses.KEY_F51;
glob KEY_F52 = _curses.KEY_F52;
glob KEY_F53 = _curses.KEY_F53;
glob KEY_F54 = _curses.KEY_F54;
glob KEY_F55 = _curses.KEY_F55;
glob KEY_F56 = _curses.KEY_F56;
glob KEY_F57 = _curses.KEY_F57;
glob KEY_F58 = _curses.KEY_F58;
glob KEY_F59 = _curses.KEY_F59;
glob KEY_F60 = _curses.KEY_F60;
glob KEY_F61 = _curses.KEY_F61;
glob KEY_F62 = _curses.KEY_F62;
glob KEY_F63 = _curses.KEY_F63;
glob KEY_F64 = _curses.KEY_F64;
glob KEY_DL = _curses.KEY_DL;
glob KEY_IL = _curses.KEY_IL;
glob KEY_DC = _curses.KEY_DC;
glob KEY_IC = _curses.KEY_IC;
glob KEY_EIC = _curses.KEY_EIC;
glob KEY_CLEAR = _curses.KEY_CLEAR;
glob KEY_EOS = _curses.KEY_EOS;
glob KEY_EOL = _curses.KEY_EOL;
glob KEY_SF = _curses.KEY_SF;
glob KEY_SR = _curses.KEY_SR;
glob KEY_NPAGE = _curses.KEY_NPAGE;
glob KEY_PPAGE = _curses.KEY_PPAGE;
glob KEY_STAB = _curses.KEY_STAB;
glob KEY_CTAB = _curses.KEY_CTAB;
glob KEY_CATAB = _curses.KEY_CATAB;
glob KEY_ENTER = _curses.KEY_ENTER;
glob KEY_PRINT = _curses.KEY_PRINT;
glob KEY_LL = _curses.KEY_LL;
glob KEY_A1 = _curses.KEY_A1;
glob KEY_A3 = _curses.KEY_A3;
glob KEY_B2 = _curses.KEY_B2;
glob KEY_C1 = _curses.KEY_C1;
glob KEY_C3 = _curses.KEY_C3;
glob KEY_BTAB = _curses.KEY_BTAB;
glob KEY_BEG = _curses.KEY_BEG;
glob KEY_CANCEL = _curses.KEY_CANCEL;
glob KEY_CLOSE = _curses.KEY_CLOSE;
glob KEY_COMMAND = _curses.KEY_COMMAND;
glob KEY_COPY = _curses.KEY_COPY;
glob KEY_CREATE = _curses.KEY_CREATE;
glob KEY_END = _curses.KEY_END;
glob KEY_EXIT = _curses.KEY_EXIT;
glob KEY_FIND = _curses.KEY_FIND;
glob KEY_HELP = _curses.KEY_HELP;
glob KEY_MARK = _curses.KEY_MARK;
glob KEY_MESSAGE = _curses.KEY_MESSAGE;
glob KEY_MOVE = _curses.KEY_MOVE;
glob KEY_NEXT = _curses.KEY_NEXT;
glob KEY_OPEN = _curses.KEY_OPEN;
glob KEY_OPTIONS = _curses.KEY_OPTIONS;
glob KEY_PREVIOUS = _curses.KEY_PREVIOUS;
glob KEY_REDO = _curses.KEY_REDO;
glob KEY_REFERENCE = _curses.KEY_REFERENCE;
glob KEY_REFRESH = _curses.KEY_REFRESH;
glob KEY_REPLACE = _curses.KEY_REPLACE;
glob KEY_RESTART = _curses.KEY_RESTART;
glob KEY_RESUME = _curses.KEY_RESUME;
glob KEY_SAVE = _curses.KEY_SAVE;
glob KEY_SBEG = _curses.KEY_SBEG;
glob KEY_SCANCEL = _curses.KEY_SCANCEL;
glob KEY_SCOMMAND = _curses.KEY_SCOMMAND;
glob KEY_SCOPY = _curses.KEY_SCOPY;
glob KEY_SCREATE = _curses.KEY_SCREATE;
glob KEY_SDC = _curses.KEY_SDC;
glob KEY_SDL = _curses.KEY_SDL;
glob KEY_SELECT = _curses.KEY_SELECT;
glob KEY_SEND = _curses.KEY_SEND;
glob KEY_SEOL = _curses.KEY_SEOL;
glob KEY_SEXIT = _curses.KEY_SEXIT;
glob KEY_SFIND = _curses.KEY_SFIND;
glob KEY_SHELP = _curses.KEY_SHELP;
glob KEY_SHOME = _curses.KEY_SHOME;
glob KEY_SIC = _curses.KEY_SIC;
glob KEY_SLEFT = _curses.KEY_SLEFT;
glob KEY_SMESSAGE = _curses.KEY_SMESSAGE;
glob KEY_SMOVE = _curses.KEY_SMOVE;
glob KEY_SNEXT = _curses.KEY_SNEXT;
glob KEY_SOPTIONS = _curses.KEY_SOPTIONS;
glob KEY_SPREVIOUS = _curses.KEY_SPREVIOUS;
glob KEY_SPRINT = _curses.KEY_SPRINT;
glob KEY_SREDO = _curses.KEY_SREDO;
glob KEY_SREPLACE = _curses.KEY_SREPLACE;
glob KEY_SRIGHT = _curses.KEY_SRIGHT;
glob KEY_SRSUME = _curses.KEY_SRSUME;
glob KEY_SSAVE = _curses.KEY_SSAVE;
glob KEY_SSUSPEND = _curses.KEY_SSUSPEND;
glob KEY_UNDO = _curses.KEY_UNDO;
glob KEY_MOUSE = _curses.KEY_MOUSE;
glob KEY_RESIZE = _curses.KEY_RESIZE;
glob KEY_MAX = _curses.KEY_MAX;


# ---------------- module functions (cursesmodule_methods order) ----------------

# Filter-mode setup must precede initscr(); the C source enforces ordering via
# curses_module_loaded/curses_filter mode flags on the host side.
glob filter = _curses.filter;

glob baudrate = _curses.baudrate;
glob beep = _curses.beep;
glob can_change_color = _curses.can_change_color;
glob cbreak = _curses.cbreak;
glob color_content = _curses.color_content;
glob color_pair = _curses.color_pair;
glob curs_set = _curses.curs_set;
glob def_prog_mode = _curses.def_prog_mode;
glob def_shell_mode = _curses.def_shell_mode;
glob delay_output = _curses.delay_output;
glob doupdate = _curses.doupdate;
glob echo = _curses.echo;
glob endwin = _curses.endwin;
glob erasechar = _curses.erasechar;
glob flash = _curses.flash;
glob flushinp = _curses.flushinp;
glob getmouse = _curses.getmouse;
glob ungetmouse = _curses.ungetmouse;
glob getsyx = _curses.getsyx;
glob getwin = _curses.getwin;
glob has_colors = _curses.has_colors;
glob has_extended_color_support = _curses.has_extended_color_support;
glob has_ic = _curses.has_ic;
glob has_il = _curses.has_il;
glob has_key = _curses.has_key;
glob halfdelay = _curses.halfdelay;
glob init_color = _curses.init_color;
glob init_pair = _curses.init_pair;
glob initscr = _curses.initscr;
glob setupterm = _curses.setupterm;
glob get_escdelay = _curses.get_escdelay;
glob set_escdelay = _curses.set_escdelay;
glob get_tabsize = _curses.get_tabsize;
glob set_tabsize = _curses.set_tabsize;
glob intrflush = _curses.intrflush;
glob isendwin = _curses.isendwin;
glob is_term_resized = _curses.is_term_resized;
glob keyname = _curses.keyname;
glob killchar = _curses.killchar;
glob longname = _curses.longname;
glob meta = _curses.meta;
glob mouseinterval = _curses.mouseinterval;
glob mousemask = _curses.mousemask;
glob napms = _curses.napms;
glob newpad = _curses.newpad;
glob newwin = _curses.newwin;
glob nl = _curses.nl;
glob nocbreak = _curses.nocbreak;
glob noecho = _curses.noecho;
glob nonl = _curses.nonl;
glob noqiflush = _curses.noqiflush;
glob noraw = _curses.noraw;
glob pair_content = _curses.pair_content;
glob pair_number = _curses.pair_number;
glob putp = _curses.putp;
glob qiflush = _curses.qiflush;
glob update_lines_cols = _curses.update_lines_cols;
glob raw = _curses.raw;
glob reset_prog_mode = _curses.reset_prog_mode;
glob reset_shell_mode = _curses.reset_shell_mode;
glob resetty = _curses.resetty;
glob resizeterm = _curses.resizeterm;
glob resize_term = _curses.resize_term;
glob savetty = _curses.savetty;
glob setsyx = _curses.setsyx;
glob start_color = _curses.start_color;
glob termattrs = _curses.termattrs;
glob termname = _curses.termname;
glob tigetflag = _curses.tigetflag;
glob tigetnum = _curses.tigetnum;
glob tigetstr = _curses.tigetstr;
glob tparm = _curses.tparm;
glob typeahead = _curses.typeahead;
glob unctrl = _curses.unctrl;
glob ungetch = _curses.ungetch;
glob unget_wch = _curses.unget_wch;
glob use_env = _curses.use_env;
glob use_default_colors = _curses.use_default_colors;
glob assume_default_colors = _curses.assume_default_colors;
