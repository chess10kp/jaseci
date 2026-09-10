# Product-path facade for ``datetime`` (CPython 3.14:
# ``Modules/_datetimemodule.c``), exercised by CPython's ``test_datetime``
# (Lib/test/datetimetester.py).
#
# The C module is almost entirely PyObject type glue (date/datetime/time/
# timedelta/tzinfo/timezone objects, their constructors, rich comparisons,
# strftime/pickle surfaces). That floor stays host-delegated -- guest
# ``import datetime`` snapshots the host module through the stdlib
# delegation registry in ceval.jac ("datetime": "full"), exactly like C
# extensions stay host-proxied on the import path.
#
# This facade lifts natively what the module FILE owns inline and carries
# no PyObject dependencies -- the integer calendrical algorithms every
# date/datetime arithmetic path funnels into:
#   * proleptic Gregorian calendar core (is_leap, days_in_month/
#     days_before_month tables, days_before_year, ymd_to_ord, ord_to_ymd's
#     400/100/4/1-year divmod decomposition with the month
#     estimate-and-correct tail),
#   * weekday / ISO week derivations (iso_week1_monday, iso_to_ymd),
#   * mixed-radix normalization utilities (normalize_pair,
#     normalize_d_s_us, normalize_y_m_d, normalize_datetime),
#   * argument range checkers with byte-exact error texts,
#   * the fromisoformat string parsers (parse_digits, parse_isoformat_date,
#     parse_hh_mm_ss_ff, parse_isoformat_time).
#
# REPRESENTATION CHOICE (divergence ledger candidate): the C originals
# return multiple results through int* out-params; here every such function
# returns a tuple (or a leading status code where C returned one). C's
# NUL-terminated pointer walks become index-based scans over ``str`` with a
# virtual terminator: reading past the end yields "\x00", mirroring the
# NUL sentinel the UTF-8 views give the C code.

glob MINYEAR: int = 1;
glob MAXYEAR: int = 9999;
glob MAXORDINAL: int = 3652059;  # date(9999,12,31).toordinal()
glob MAX_DELTA_DAYS: int = 999999999;

# Days in 4, 100, and 400 year cycles.
glob DI4Y: int = 1461;
glob DI100Y: int = 36524;
glob DI400Y: int = 146097;

# For each month ordinal in 1..12, the number of days in that month, and
# the number of days before that month in the same year. Correct for
# non-leap years only ([0] is unused padding).
glob _days_in_month: list[int] = [
    0, 31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31
];
glob _days_before_month: list[int] = [
    0, 0, 31, 59, 90, 120, 151, 181, 212, 243, 273, 304, 334
];


# ---------------------------------------------------------------------------
# Proleptic Gregorian calendar core
#

def is_leap(year: int) -> bool {
    # C casts to unsigned for cheaper mod; the value is identical either way.
    return (year % 4 == 0) and ((year % 100 != 0) or (year % 400 == 0));
}

def days_in_month(year: int, month: int) -> int {
    if (month == 2) and is_leap(year) {
        return 29;
    }
    return _days_in_month[month];
}

def days_before_month(year: int, month: int) -> int {
    days: int = _days_before_month[month];
    if (month > 2) and is_leap(year) {
        days = days + 1;
    }
    return days;
}

def days_before_year(year: int) -> int {
    # year -> days before January 1st of year; days_before_year(1) == 0.
    y: int = year - 1;
    return (y * 365) + (y // 4) - (y // 100) + (y // 400);
}

def ymd_to_ord(year: int, month: int, day: int) -> int {
    # year, month, day -> ordinal, considering 01-Jan-0001 as day 1.
    return days_before_year(year) + days_before_month(year, month) + day;
}

def ord_to_ymd(ordinal: int) -> tuple[int, int, int] {
    # ordinal -> (year, month, day), considering 01-Jan-0001 as day 1.
    # Pattern of leap years repeats every 400 years: find the closest
    # 400-year boundary at or before the (decremented) ordinal, then work
    # with the offset from that boundary.
    o: int = ordinal - 1;
    n400: int = o // DI400Y;
    n: int = o % DI400Y;
    year: int = (n400 * 400) + 1;

    n100: int = n // DI100Y;
    n = n % DI100Y;

    n4: int = n // DI4Y;
    n = n % DI4Y;

    n1: int = n // 365;
    n = n % 365;

    year = year + (n100 * 100) + (n4 * 4) + n1;
    if (n1 == 4) or (n100 == 4) {
        # December 31 at the end of a 400- or 4-year cycle.
        return (year - 1, 12, 31);
    }

    # Year is correct; find the month via an estimate that is either exact
    # or one too large.
    leapyear: bool = (n1 == 3) and ((n4 != 24) or (n100 == 3));
    month: int = (n + 50) >> 5;
    preceding: int = _days_before_month[month] + (
        1 if (month > 2) and leapyear else 0
    );
    if preceding > n {
        # Estimate is too large.
        month = month - 1;
        preceding = preceding - days_in_month(year, month);
    }
    n = n - preceding;
    return (year, month, n + 1);
}

def weekday(year: int, month: int, day: int) -> int {
    # Day of week, Monday==0 .. Sunday==6. 1/1/1 was a Monday.
    return (ymd_to_ord(year, month, day) + 6) % 7;
}

def iso_week1_monday(year: int) -> int {
    # Ordinal of the Monday starting week 1 of the ISO year (the first
    # calendar week containing a Thursday).
    first_day: int = ymd_to_ord(year, 1, 1);
    first_weekday: int = (first_day + 6) % 7;
    week1_monday: int = first_day - first_weekday;
    if first_weekday > 3 {
        week1_monday = week1_monday + 7;
    }
    return week1_monday;
}

def iso_to_ymd(iso_year: int, iso_week: int, iso_day: int) -> tuple[int, int, int, int] {
    # ISO (year, week, day) -> (status, year, month, day).
    # Status mirrors the C return codes: 0 success, -4 bad iso_year,
    # -2 bad iso_week, -3 bad iso_day. Year is bounded to
    # 0 < year < 10000 because 9999-12-31 is (9999, 52, 5).
    if (iso_year < MINYEAR) or (iso_year > MAXYEAR) {
        return (-4, 0, 0, 0);
    }
    if (iso_week <= 0) or (iso_week >= 53) {
        out_of_range: bool = True;
        if iso_week == 53 {
            # ISO years have 53 weeks when they start on a Thursday, or on
            # a Wednesday in a leap year.
            first_weekday: int = weekday(iso_year, 1, 1);
            if (first_weekday == 3) or ((first_weekday == 2) and is_leap(iso_year)) {
                out_of_range = False;
            }
        }
        if out_of_range {
            return (-2, 0, 0, 0);
        }
    }
    if (iso_day <= 0) or (iso_day >= 8) {
        return (-3, 0, 0, 0);
    }

    # Convert (Y, W, D) to (Y, M, D).
    day_1: int = iso_week1_monday(iso_year);
    day_offset: int = ((iso_week - 1) * 7) + iso_day - 1;
    ymd: tuple[int, int, int] = ord_to_ymd(day_1 + day_offset);
    return (0, ymd[0], ymd[1], ymd[2]);
}


# ---------------------------------------------------------------------------
# Range checkers (byte-exact error texts)
#

def check_delta_day_range(days: int) {
    # Raise OverflowError unless -MAX_DELTA_DAYS <= days <= MAX_DELTA_DAYS.
    if (days < -MAX_DELTA_DAYS) or (days > MAX_DELTA_DAYS) {
        raise OverflowError(
            "days=" + str(days)
            + "; must have magnitude <= " + str(MAX_DELTA_DAYS)
        );
    }
}

def check_date_args(year: int, month: int, day: int) {
    if (year < MINYEAR) or (year > MAXYEAR) {
        raise ValueError(
            "year must be in " + str(MINYEAR) + ".." + str(MAXYEAR)
            + ", not " + str(year)
        );
    }
    if (month < 1) or (month > 12) {
        raise ValueError("month must be in 1..12, not " + str(month));
    }
    dim: int = days_in_month(year, month);
    if (day < 1) or (day > dim) {
        raise ValueError(
            "day " + str(day) + " must be in range 1.." + str(dim)
            + " for month " + str(month) + " in year " + str(year)
        );
    }
}

def check_time_args(h: int, m: int, s: int, us: int, fold: int) {
    if (h < 0) or (h > 23) {
        raise ValueError("hour must be in 0..23, not " + str(h));
    }
    if (m < 0) or (m > 59) {
        raise ValueError("minute must be in 0..59, not " + str(m));
    }
    if (s < 0) or (s > 59) {
        raise ValueError("second must be in 0..59, not " + str(s));
    }
    if (us < 0) or (us > 999999) {
        raise ValueError("microsecond must be in 0..999999, not " + str(us));
    }
    if (fold != 0) and (fold != 1) {
        raise ValueError("fold must be either 0 or 1, not " + str(fold));
    }
}


# ---------------------------------------------------------------------------
# Mixed-radix normalization
#

def normalize_pair(hi: int, lo: int, factor: int) -> tuple[int, int] {
    # One step of a mixed-radix conversion: a "hi" unit equals ``factor``
    # "lo" units. If lo is out of 0..factor-1, enough of it converts into
    # hi units so 0 <= lo < factor.
    if (lo < 0) or (lo >= factor) {
        hi = hi + (lo // factor);
        lo = lo % factor;
    }
    return (hi, lo);
}

def normalize_d_s_us(d: int, s: int, us: int) -> tuple[int, int, int] {
    # Fiddle days/seconds/microseconds so 0 <= s < 24*3600, 0 <= us < 1e6.
    if (us < 0) or (us >= 1000000) {
        pair: tuple[int, int] = normalize_pair(s, us, 1000000);
        s = pair[0];
        us = pair[1];
    }
    if (s < 0) or (s >= (24 * 3600)) {
        pair2: tuple[int, int] = normalize_pair(d, s, 24 * 3600);
        d = pair2[0];
        s = pair2[1];
    }
    return (d, s, us);
}

def normalize_y_m_d(y: int, m: int, d: int) -> tuple[int, int, int] {
    # Fiddle years/months/days so 1 <= m <= 12 and
    # 1 <= d <= days_in_month(y, m). Raises OverflowError when the adjusted
    # date escapes MINYEAR..MAXYEAR.
    dim: int = days_in_month(y, m);
    if (d < 1) or (d > dim) {
        if d == 0 {
            # Step back one day.
            m = m - 1;
            if m > 0 {
                d = days_in_month(y, m);
            } else {
                y = y - 1;
                m = 12;
                d = 31;
            }
        } elif d == (dim + 1) {
            # Move forward one day.
            m = m + 1;
            d = 1;
            if m > 12 {
                m = 1;
                y = y + 1;
            }
        } else {
            ordinal: int = ymd_to_ord(y, m, 1) + d - 1;
            if (ordinal < 1) or (ordinal > MAXORDINAL) {
                raise OverflowError("date value out of range");
            }
            ymd: tuple[int, int, int] = ord_to_ymd(ordinal);
            return (ymd[0], ymd[1], ymd[2]);
        }
    }
    if (y < MINYEAR) or (y > MAXYEAR) {
        raise OverflowError("date value out of range");
    }
    return (y, m, d);
}

def normalize_datetime(
    year: int, month: int, day: int,
    hour: int, minute: int, second: int, microsecond: int,
) -> tuple[int, int, int, int, int, int, int] {
    # Force all datetime fields into range.
    p_us: tuple[int, int] = normalize_pair(second, microsecond, 1000000);
    second = p_us[0];
    microsecond = p_us[1];
    p_s: tuple[int, int] = normalize_pair(minute, second, 60);
    minute = p_s[0];
    second = p_s[1];
    p_m: tuple[int, int] = normalize_pair(hour, minute, 60);
    hour = p_m[0];
    minute = p_m[1];
    p_h: tuple[int, int] = normalize_pair(day, hour, 24);
    day = p_h[0];
    hour = p_h[1];
    ymd: tuple[int, int, int] = normalize_y_m_d(year, month, day);
    return (ymd[0], ymd[1], ymd[2], hour, minute, second, microsecond);
}


# ---------------------------------------------------------------------------
# fromisoformat string parsers
#
# The C originals walk NUL-terminated char pointers. Here strings are
# scanned by index; _dt_at mirrors the C terminator: reads past the end
# yield "\x00".
#

def _dt_at(s: str, i: int) -> str {
    if i < 0 {
        return "\x00";
    }
    if i >= len(s) {
        return "\x00";
    }
    return s[i];
}

def:priv _is_digit(c: str) -> bool {
    return ("0" <= c) and (c <= "9");
}

def _parse_digits(s: str, pos: int, num_digits: int) -> tuple[bool, int, int] {
    # C parse_digits: consume exactly num_digits ASCII digits starting at
    # pos. Returns (ok, new_pos, value); ok=False leaves pos unmoved.
    var: int = 0;
    for i in range(num_digits) {
        c: str = _dt_at(s, pos + i);
        if not _is_digit(c) {
            return (False, pos, 0);
        }
        var = (var * 10) + (ord(c) - ord("0"));
    }
    return (True, pos + num_digits, var);
}

def parse_isoformat_date(s: str, pos: int) -> tuple[int, int, int, int, int] {
    # Parse the date component of an isoformat() string starting at pos.
    # Returns (rv, year, month, day, new_pos); rv mirrors the C codes:
    #   0 success, -1 bad date component, -2 inconsistent separator usage,
    #   -3/-4/-5 ISO week/day conversion failures (from iso_to_ymd).
    r4: tuple[bool, int, int] = _parse_digits(s, pos, 4);
    if not r4[0] {
        return (-1, 0, 0, 0, pos);
    }
    year: int = r4[2];
    p: int = r4[1];

    uses_separator: bool = _dt_at(s, p) == "-";
    if uses_separator {
        p = p + 1;
    }

    if _dt_at(s, p) == "W" {
        # Isocalendar-style date string: YYYY-Www-D or YYYYWwwD.
        p = p + 1;
        rw: tuple[bool, int, int] = _parse_digits(s, p, 2);
        if not rw[0] {
            return (-3, 0, 0, 0, pos);
        }
        iso_week: int = rw[2];
        p = rw[1];

        iso_day: int = 1;
        if p < len(s) {
            if uses_separator {
                if _dt_at(s, p) != "-" {
                    return (-2, 0, 0, 0, pos);
                }
                p = p + 1;
            }
            rd: tuple[bool, int, int] = _parse_digits(s, p, 1);
            if not rd[0] {
                return (-4, 0, 0, 0, pos);
            }
            iso_day = rd[2];
            p = rd[1];
        }

        rv_ymd: tuple[int, int, int, int] = iso_to_ymd(year, iso_week, iso_day);
        rv: int = rv_ymd[0];
        if rv != 0 {
            return (rv - 3, 0, 0, 0, pos);
        }
        return (0, rv_ymd[1], rv_ymd[2], rv_ymd[3], p);
    }

    rm: tuple[bool, int, int] = _parse_digits(s, p, 2);
    if not rm[0] {
        return (-1, 0, 0, 0, pos);
    }
    month: int = rm[2];
    p = rm[1];

    if uses_separator {
        if _dt_at(s, p) != "-" {
            return (-2, 0, 0, 0, pos);
        }
        p = p + 1;
    }
    rd2: tuple[bool, int, int] = _parse_digits(s, p, 2);
    if not rd2[0] {
        return (-1, 0, 0, 0, pos);
    }
    day: int = rd2[2];
    p = rd2[1];
    return (0, year, month, day, p);
}

def parse_hh_mm_ss_ff(tstr: str, start: int, end: int) -> tuple[int, int, int, int, int, int, int] {
    # Parse [HH[:?MM[:?SS]][.ffff...]] between start and end.
    # Returns (rv, hour, minute, second, microsecond, new_pos, unused):
    #   rv mirrors C: 0 clean end-of-input, 1 trailing content remains,
    #   -3 bad time component, -4 malformed separator.
    hour: int = 0;
    minute: int = 0;
    second: int = 0;
    microsecond: int = 0;
    p: int = start;
    has_separator: bool = True;

    vals: list[int] = [hour, minute, second];
    i: int = 0;
    while i < 3 {
        rd: tuple[bool, int, int] = _parse_digits(tstr, p, 2);
        if not rd[0] {
            return (-3, 0, 0, 0, 0, p, 0);
        }
        vals[i] = rd[2];
        p = rd[1];

        c: str = _dt_at(tstr, p);
        p = p + 1;
        if i == 0 {
            has_separator = c == ":";
        }

        if p >= end {
            # C returns c != '\0': terminator means clean end.
            done: int = 0 if c == "\x00" else 1;
            return (done, vals[0], vals[1], vals[2], 0, p, 0);
        } elif has_separator and (c == ":") {
            if i == 2 {
                return (-4, 0, 0, 0, 0, p, 0);  # Malformed microsecond sep
            }
            i = i + 1;
            continue;
        } elif (c == ".") or (c == ",") {
            if i < 2 {
                # Decimal mark on hour or minute.
                return (-3, 0, 0, 0, 0, p, 0);
            }
            break;
        } elif not has_separator {
            p = p - 1;
        } else {
            return (-4, 0, 0, 0, 0, p, 0);  # Malformed time separator
        }
        i = i + 1;
    }

    # Parse fractional components: up to 6 digits, right-padded to
    # microseconds; further digits are skipped as truncated.
    len_remains: int = end - p;
    to_parse: int = len_remains;
    if len_remains >= 6 {
        to_parse = 6;
    }
    rf: tuple[bool, int, int] = _parse_digits(tstr, p, to_parse);
    if not rf[0] {
        return (-3, 0, 0, 0, 0, p, 0);
    }
    microsecond = rf[2];
    p = rf[1];

    correction: list[int] = [100000, 10000, 1000, 100, 10];
    if to_parse < 6 {
        microsecond = microsecond * correction[to_parse - 1];
    }

    while _is_digit(_dt_at(tstr, p)) {
        p = p + 1;  # skip truncated digits
    }

    trailing: int = 0 if p >= end else 1;
    return (
        trailing, vals[0], vals[1], vals[2], microsecond, p, 0
    );
}

def parse_isoformat_time(s: str, pos: int) -> tuple[int, int, int, int, int, int, int] {
    # Parse the time portion of an isoformat() string starting at pos.
    # Returns (rv, hour, minute, second, microsecond, tzoffset,
    # tzmicrosecond); rv mirrors the C codes: 0 success without tzoffset,
    # 1 success with tzoffset, -3 bad component, -4 bad separator,
    # -5 malformed timezone.
    end: int = len(s);

    # Locate the tzinfo marker: first Z/+/- scanning forward.
    tzinfo_pos: int = pos;
    while tzinfo_pos < end {
        c: str = _dt_at(s, tzinfo_pos);
        if (c == "Z") or (c == "+") or (c == "-") {
            break;
        }
        tzinfo_pos = tzinfo_pos + 1;
    }

    base: tuple[int, int, int, int, int, int, int] = parse_hh_mm_ss_ff(
        s, pos, tzinfo_pos
    );
    rv: int = base[0];
    hour: int = base[1];
    minute: int = base[2];
    second: int = base[3];
    microsecond: int = base[4];

    if rv < 0 {
        return (rv, hour, minute, second, microsecond, 0, 0);
    }
    if tzinfo_pos >= end {
        # No timezone marker: any trailing content is an error.
        if rv == 1 {
            return (-5, hour, minute, second, microsecond, 0, 0);
        }
        return (0, hour, minute, second, microsecond, 0, 0);
    }

    # Special case UTC / Zulu time.
    if _dt_at(s, tzinfo_pos) == "Z" {
        if (tzinfo_pos + 1) < end {
            return (-5, hour, minute, second, microsecond, 0, 0);
        }
        return (1, hour, minute, second, microsecond, 0, 0);
    }

    tzsign: int = -1 if _dt_at(s, tzinfo_pos) == "-" else 1;
    tz_start: int = tzinfo_pos + 1;
    tzmicrosecond: int = 0;
    tz: tuple[int, int, int, int, int, int, int] = parse_hh_mm_ss_ff(
        s, tz_start, end
    );
    tzhour: int = tz[1];
    tzminute: int = tz[2];
    tzsecond: int = tz[3];
    tzmicrosecond = tz[4] * tzsign;

    tzoffset: int = tzsign * ((tzhour * 3600) + (tzminute * 60) + tzsecond);
    tz_rv: int = -5 if tz[0] != 0 else 1;
    return (
        tz_rv, hour, minute, second, microsecond, tzoffset, tzmicrosecond
    );
}
