# Product-path facade for _locale (POSIX locale access).
# Reference: CPython 3.14 ``Modules/_localemodule.c`` exercised by
# Lib/test/test_locale.py (suite_routing: test_locale -> QUARANTINE,
# forbidden-import:_locale; Lib/locale.py facade-module:locale->_locale).
#
# REPRESENTATION CHOICE (divergence ledger candidate): the C original is a thin
# binding over the libc locale floor -- setlocale()/localeconv()/
# nl_langinfo()/gettext family over process-global C locale state. That floor
# cannot be reimplemented in pure Jac (process-wide locale mutation, lconv
# struct reads, message catalogs), so this facade delegates it to the host
# ``_locale`` extension (the same glibc build the interpreter ships), exactly
# like curses.jac delegates to host _curses and bz2.jac to host _bz2.
# The facade owns the Python-visible module surface: exception identity, the
# full LC_* / CHAR_MAX constant block from _locale_exec, and the
# langinfo_constants table (Linux/glibc surface -- every #ifdef guard whose
# macro is defined on this platform; MS-Windows-only branches never fire).
#
# Wiring note: guest ``import _locale`` resolves through ceval's host-import
# path; native facades win automatically once this surface is registered as a
# shim, mirroring errno.jac/curses.jac precedence.

import _locale;


# ---------------- module exception (_locale_exec) ----------------

# PyErr_NewException("locale.Error", NULL, NULL) -- host instance crosses the
# bridge with type and message intact, so guest except-handlers match it by
# this class proxy ("unsupported locale setting", "locale query failed",
# "domain must be a non-empty string").
glob Error = _locale.Error;


# ---------------- LC_* category constants (_locale_exec ADD_INT order) ----------------

glob LC_CTYPE = _locale.LC_CTYPE;
glob LC_TIME = _locale.LC_TIME;
glob LC_COLLATE = _locale.LC_COLLATE;
glob LC_MONETARY = _locale.LC_MONETARY;

# ifdef LC_MESSAGES (glibc defines it)
glob LC_MESSAGES = _locale.LC_MESSAGES;

glob LC_NUMERIC = _locale.LC_NUMERIC;
glob LC_ALL = _locale.LC_ALL;
glob CHAR_MAX = _locale.CHAR_MAX;


# ---------------- langinfo constants (langinfo_constants[] table order) ----------------

# DAY_1..DAY_7 (LC_TIME)
glob DAY_1 = _locale.DAY_1;
glob DAY_2 = _locale.DAY_2;
glob DAY_3 = _locale.DAY_3;
glob DAY_4 = _locale.DAY_4;
glob DAY_5 = _locale.DAY_5;
glob DAY_6 = _locale.DAY_6;
glob DAY_7 = _locale.DAY_7;

# ABDAY_1..ABDAY_7 (LC_TIME)
glob ABDAY_1 = _locale.ABDAY_1;
glob ABDAY_2 = _locale.ABDAY_2;
glob ABDAY_3 = _locale.ABDAY_3;
glob ABDAY_4 = _locale.ABDAY_4;
glob ABDAY_5 = _locale.ABDAY_5;
glob ABDAY_6 = _locale.ABDAY_6;
glob ABDAY_7 = _locale.ABDAY_7;

# MON_1..MON_12 (LC_TIME)
glob MON_1 = _locale.MON_1;
glob MON_2 = _locale.MON_2;
glob MON_3 = _locale.MON_3;
glob MON_4 = _locale.MON_4;
glob MON_5 = _locale.MON_5;
glob MON_6 = _locale.MON_6;
glob MON_7 = _locale.MON_7;
glob MON_8 = _locale.MON_8;
glob MON_9 = _locale.MON_9;
glob MON_10 = _locale.MON_10;
glob MON_11 = _locale.MON_11;
glob MON_12 = _locale.MON_12;

# ABMON_1..ABMON_12 (LC_TIME)
glob ABMON_1 = _locale.ABMON_1;
glob ABMON_2 = _locale.ABMON_2;
glob ABMON_3 = _locale.ABMON_3;
glob ABMON_4 = _locale.ABMON_4;
glob ABMON_5 = _locale.ABMON_5;
glob ABMON_6 = _locale.ABMON_6;
glob ABMON_7 = _locale.ABMON_7;
glob ABMON_8 = _locale.ABMON_8;
glob ABMON_9 = _locale.ABMON_9;
glob ABMON_10 = _locale.ABMON_10;
glob ABMON_11 = _locale.ABMON_11;
glob ABMON_12 = _locale.ABMON_12;

# ifdef RADIXCHAR (present on any non-glibc-2.0 langinfo implementation)
glob RADIXCHAR = _locale.RADIXCHAR;
glob THOUSEP = _locale.THOUSEP;
glob CRNCYSTR = _locale.CRNCYSTR;

# XPG4 baseline
glob D_T_FMT = _locale.D_T_FMT;
glob D_FMT = _locale.D_FMT;
glob T_FMT = _locale.T_FMT;
glob AM_STR = _locale.AM_STR;
glob PM_STR = _locale.PM_STR;

# OpenBSD guards all defined on glibc
glob CODESET = _locale.CODESET;
glob T_FMT_AMPM = _locale.T_FMT_AMPM;
glob ERA = _locale.ERA;
glob ERA_D_FMT = _locale.ERA_D_FMT;
glob ERA_D_T_FMT = _locale.ERA_D_T_FMT;
glob ERA_T_FMT = _locale.ERA_T_FMT;
glob ALT_DIGITS = _locale.ALT_DIGITS;
glob YESEXPR = _locale.YESEXPR;
glob NOEXPR = _locale.NOEXPR;
glob _DATE_FMT = _locale._DATE_FMT;


# ---------------- module functions (PyLocale_Methods table order) ----------------

# setlocale(category, locale=None) -> str; raises Error("unsupported locale
# setting") / Error("locale query failed"). Flexible-arity clinic signature:
# bound 1:1 to the host extension rather than wrapped in a fixed-arity Jac def.
glob setlocale = _locale.setlocale;

# localeconv() -> dict (numeric + monetary parameters incl. grouping lists).
glob localeconv = _locale.localeconv;

# strcoll(os1, os2) -> int; wcscoll-based locale collation.
glob strcoll = _locale.strcoll;

# strxfrm(string) -> str; locale-aware comparison key (wcsxfrm).
glob strxfrm = _locale.strxfrm;

# nl_langinfo(key) -> str; ValueError("unsupported langinfo constant") for
# keys outside the langinfo_constants table.
glob nl_langinfo = _locale.nl_langinfo;

# gettext family (HAVE_LIBINTL_H): translation lookups over message catalogs.
glob gettext = _locale.gettext;
glob dgettext = _locale.dgettext;
glob dcgettext = _locale.dcgettext;
glob textdomain = _locale.textdomain;
glob bindtextdomain = _locale.bindtextdomain;
glob bind_textdomain_codeset = _locale.bind_textdomain_codeset;

# getencoding() -> str; current locale encoding (_Py_GetLocaleEncodingObject).
glob getencoding = _locale.getencoding;
