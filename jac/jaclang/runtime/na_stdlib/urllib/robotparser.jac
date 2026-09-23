"""urllib.robotparser — robots.txt parser (RFC 9309), native Jac port.

Mirrors CPython's ``urllib.robotparser`` API: ``RobotFileParser`` plus the
``RuleLine`` / ``Entry`` helpers and ``RequestRate``.

Native-scope divergences:

- CPython compiles ``*`` patterns with ``re``; there is no bundled ``re``,
  so wildcard rules are matched by an equivalent manual scan (lazy ``.*?``
  between segments, greedy trailing ``.*`` for prefix rules, suffix anchor
  for ``$`` rules). Match-length semantics are preserved.
- ``translate_pattern`` is omitted (it exists only to build that regex).
- ``RequestRate`` is a plain object with ``requests`` / ``seconds`` fields,
  not a ``collections.namedtuple``; index/unpack access is unsupported.
- ``read()`` reads ``err.code`` / ``err.close()`` through the caught
  ``HTTPError`` binding; cross-module caught-exception field access is a
  known backend gap, so 401/403/4xx marking may be unreliable natively.
"""

import from c { def time(t: i64) -> i64;  }
import from urllib.parse { urlsplit, unquote, quote }
import from urllib.error { HTTPError }
import from urllib.response { addinfourl }
import from urllib.request { urlopen }


obj:pub RequestRate {
    has:pub requests: int = 0,
        seconds: int = 0;

    def init(requests: int, seconds: int) {
        self.requests = requests;
        self.seconds = seconds;
    }
}


def _collapse_stars(path: str) -> str {
    # re.sub(r'[*]{2,}', '*', path)
    out = "";
    prev = False;
    for i in range(len(path)) {
        ch = path[i];
        if ch == "*" {
            if prev {
                continue;
            }
            prev = True;
        } else {
            prev = False;
        }
        out += ch;
    }
    return out;
}


def _collapse_dollar(path: str) -> str {
    # re.sub(r'[$][$*]+', '$', path)
    out = "";
    i = 0;
    n = len(path);
    while i < n {
        ch = path[i];
        if ch == "$" {
            j = i + 1;
            while j < n and (path[j] == "$" or path[j] == "*") {
                j += 1;
            }
            if j > i + 1 {
                out += "$";
                i = j;
                continue;
            }
        }
        out += ch;
        i += 1;
    }
    return out;
}


def normalize(path: str) -> str {
    un = unquote(path, "utf-8", "surrogateescape");
    return quote(un, "/", None, "surrogateescape");
}


def _norm_runs(s: str, keep: str) -> str {
    # re.sub on the runs of characters NOT in ``keep``: normalize each run,
    # pass kept characters through untouched.
    out = "";
    run = "";
    for i in range(len(s)) {
        ch = s[i];
        if ch in keep {
            if len(run) > 0 {
                out += normalize(run);
                run = "";
            }
            out += ch;
        } else {
            run += ch;
        }
    }
    if len(run) > 0 {
        out += normalize(run);
    }
    return out;
}


def normalize_uri(path: str) -> str {
    i = path.find("?");
    if i < 0 {
        return normalize(path);
    }
    p = normalize(path[:i]);
    q = _norm_runs(path[i + 1:], "=&");
    return p + "?" + q;
}


def normalize_pattern(path: str) -> str {
    i = path.find("?");
    if i < 0 {
        return _norm_runs(path, "*$");
    }
    p = _norm_runs(path[:i], "*$");
    q = _norm_runs(path[i + 1:], "=&*$");
    return p + "?" + q;
}


def _star_match_end(segments: list[str], s: str, fullm: bool) -> int {
    # Equivalent of ``translate_pattern`` + ``re.match``/``fullmatch``:
    # segment 0 must be a prefix, middle segments are found lazily in order,
    # and the last segment follows a greedy ``.*`` (its last occurrence for a
    # prefix match; end-anchored for a full match). Returns ``m.end()`` or -1.
    pos = 0;
    first = segments[0];
    if not s.startswith(first) {
        return -1;
    }
    pos = len(first);
    i = 1;
    while i < len(segments) - 1 {
        seg = segments[i];
        j = s.find(seg, pos);
        if j < 0 {
            return -1;
        }
        pos = j + len(seg);
        i += 1;
    }
    last = segments[len(segments) - 1];
    if len(last) == 0 {
        # trailing ``*``: ``.*`` consumes to the end of the string
        if fullm and len(s) < pos {
            return -1;
        }
        return len(s);
    }
    if fullm {
        if len(s) - len(last) < pos {
            return -1;
        }
        if not s.endswith(last) {
            return -1;
        }
        return len(s);
    }
    # greedy ``.*`` backtracks to the last occurrence of ``last``
    k = s.rfind(last);
    if k < pos {
        return -1;
    }
    return k + len(last);
}


obj:pub RuleLine {
    """A single ``Allow:`` / ``Disallow:`` rule line."""
    has:pub path: str = "",
        allowance: bool = False,
        fullmatch: bool = False,
        has_star: bool = False,
        segments: list[str] = [];

    def init(path: str, allowance: bool) {
        al = allowance;
        p = path;
        if len(p) == 0 and not al {
            # an empty value means allow all
            al = True;
        }
        p = _collapse_stars(p);
        p = _collapse_dollar(p);
        p = normalize_pattern(p);
        self.fullmatch = p.endswith("$");
        p = p.rstrip("$");
        if "$" in p {
            raise ValueError("$ not at the end of path");
        }
        self.has_star = "*" in p;
        if self.has_star {
            self.segments = p.split("*");
        }
        self.path = p;
        self.allowance = al;
    }

    def applies_to(filename: str) -> int {
        # If the filename matches the rule, return the matching length plus 1.
        # If it does not match, return 0.
        if self.has_star {
            e = _star_match_end(self.segments, filename, self.fullmatch);
            if e >= 0 {
                return e + 1;
            }
        } else {
            if self.fullmatch {
                if filename == self.path {
                    return len(self.path) + 1;
                }
            } else {
                if filename.startswith(self.path) {
                    return len(self.path) + 1;
                }
            }
        }
        return 0;
    }

    def __str__ -> str {
        return (("Allow" if self.allowance else "Disallow") + ": " + self.path
            + ("$" if self.fullmatch else ""));
    }
}


obj:pub Entry {
    """One or more user-agents plus zero or more rule lines."""
    has:pub useragents: list[str] = [],
        rulelines: list[RuleLine] = [],
        delay: (int | None) = None,
        req_rate: (RequestRate | None) = None;

    def __str__ -> str {
        if len(self.useragents) == 0 {
            return "";
        }
        ret: list[str] = [];
        for agent in self.useragents {
            ret.append("User-agent: " + agent);
        }
        if self.delay != None {
            d: int = self.delay;
            ret.append("Crawl-delay: " + str(d));
        }
        if self.req_rate != None {
            rr: RequestRate = self.req_rate;
            ret.append(
                "Request-rate: " + str(rr.requests) + "/" + str(rr.seconds)
            );
        }
        if len(self.rulelines) > 0 {
            for rl in self.rulelines {
                ret.append(str(rl));
            }
        } else {
            ret.append("Allow:");
        }
        return "\n".join(ret);
    }

    def applies_to(useragent: (str | None)) -> bool {
        # check if this entry applies to the specified agent
        if useragent == None {
            return "*" in self.useragents;
        }
        ua: str = useragent;
        # split the name token and make it lower case
        ua = ua.split("/")[0].lower();
        for agent in self.useragents {
            if agent != "*" {
                ag = agent.lower();
                if ag in ua {
                    return True;
                }
            }
        }
        return False;
    }

    def allowance(filename: str) -> bool {
        # Preconditions:
        # - our agent applies to this entry
        # - filename is URL encoded
        best_match = -1;
        allow = True;
        for line in self.rulelines {
            m = line.applies_to(filename);
            if m > 0 {
                if m > best_match {
                    best_match = m;
                    allow = line.allowance;
                } elif m == best_match and not allow {
                    allow = line.allowance;
                }
            }
        }
        return allow;
    }
}


def merge_entries(e1: Entry, e2: Entry) -> Entry {
    ent = Entry();
    for agent in e1.useragents {
        if agent in e2.useragents {
            ent.useragents.append(agent);
        }
    }
    ent.rulelines = e1.rulelines + e2.rulelines;
    if e2.delay == None {
        ent.delay = e1.delay;
    } else {
        ent.delay = e2.delay;
    }
    if e2.req_rate == None {
        ent.req_rate = e1.req_rate;
    } else {
        ent.req_rate = e2.req_rate;
    }
    return ent;
}


def _splitlines(s: str) -> list[str] {
    lines: list[str] = [];
    cur = "";
    i = 0;
    n = len(s);
    while i < n {
        ch = s[i];
        if ch == "\r" {
            lines.append(cur);
            cur = "";
            if i + 1 < n and s[i + 1] == "\n" {
                i += 1;
            }
        } elif ch == "\n" {
            lines.append(cur);
            cur = "";
        } else {
            cur += ch;
        }
        i += 1;
    }
    if len(cur) > 0 {
        lines.append(cur);
    }
    return lines;
}


obj:pub RobotFileParser {
    """Reads, parses and answers questions about a single robots.txt file."""
    has:pub entries: list[Entry] = [],
        groups: dict[str, Entry] = {},
        sitemaps: list[str] = [],
        default_entry: (Entry | None) = None,
        disallow_all: bool = False,
        allow_all: bool = False,
        url: str = "",
        host: str = "",
        path: str = "",
        last_checked: float = 0;

    def init(url: str = "") {
        self.set_url(url);
    }

    def mtime -> float {
        # Returns the time the robots.txt file was last fetched.
        return self.last_checked;
    }

    def modified {
        # Sets the last-fetched time to now.
        self.last_checked = float(time(0));
    }

    def set_url(url: str) {
        # Sets the URL referring to a robots.txt file.
        self.url = url;
        sp = urlsplit(url);
        self.host = sp.netloc;
        self.path = sp.path;
    }

    def read {
        # Reads the robots.txt URL and feeds it to the parser.
        f: (addinfourl | None) = None;
        try {
            r = urlopen(self.url);
            f = r;
        } except HTTPError as err {
            c = err.code;
            if c != None {
                ci: int = c;
                if ci == 401 or ci == 403 {
                    self.disallow_all = True;
                } elif ci >= 400 and ci < 500 {
                    self.allow_all = True;
                }
            }
            err.close();
        }
        if f != None {
            fp: addinfourl = f;
            raw = fp.read();
            if isinstance(raw, bytes) {
                rb: bytes = raw;
                self.parse(_splitlines(rb.decode("utf-8")));
            } else {
                rs: str = raw;
                self.parse(_splitlines(rs));
            }
        }
    }

    def _add_entry(ent: Entry) {
        self.entries.append(ent);
        for agent in ent.useragents {
            ag = agent.lower();
            cur = self.groups.get(ag, None);
            if cur == None {
                self.groups[ag] = ent;
            } else {
                e1: Entry = cur;
                self.groups[ag] = merge_entries(e1, ent);
            }
        }
    }

    def parse(lines: list[str]) {
        # Parse the input lines from a robots.txt file.
#
        # We allow that a user-agent: line is not preceded by
        # one or more blank lines.
        #
        # states:
        #   0: start state
        #   1: saw user-agent line
        #   2: saw an allow or disallow line
        state = 0;
        ent = Entry();

        self.modified();
        for raw_line in lines {
            # remove optional comment and strip line
            line = raw_line;
            i = line.find("#");
            if i >= 0 {
                line = line[:i];
            }
            line = line.strip();
            if len(line) == 0 {
                continue;
            }
            kv = line.split(":", 1);
            if len(kv) == 2 {
                key = kv[0].strip().lower();
                val = kv[1].strip();
                if key == "user-agent" {
                    if state == 2 {
                        self._add_entry(ent);
                        ent = Entry();
                    }
                    ent.useragents.append(val);
                    state = 1;
                } elif key == "disallow" {
                    if state != 0 {
                        state = 2;
                        try {
                            ent.rulelines.append(RuleLine(val, False));
                        } except ValueError {
                        }
                    }
                } elif key == "allow" {
                    if state != 0 {
                        state = 2;
                        try {
                            ent.rulelines.append(RuleLine(val, True));
                        } except ValueError {
                        }
                    }
                } elif key == "crawl-delay" {
                    if state != 0 {
                        # before trying to convert to int we need to make
                        # sure that robots.txt has valid syntax otherwise
                        # it will crash
                        if val.isdigit() {
                            ent.delay = int(val);
                        }
                        state = 2;
                    }
                } elif key == "request-rate" {
                    if state != 0 {
                        numbers = val.split("/");
                        # check if all values are sane
                        if len(numbers) == 2
                            and numbers[0].strip().isdigit()
                            and numbers[1].strip().isdigit() {
                            ent.req_rate = RequestRate(
                                int(numbers[0]), int(numbers[1])
                            );
                        }
                        state = 2;
                    }
                } elif key == "sitemap" {
                    # This directive is independent of the user-agent line,
                    # so it doesn't matter where you place it in your file.
                    # Therefore we do not change the state of the parser.
                    self.sitemaps.append(val);
                }
            }
        }
        if state != 0 {
            self._add_entry(ent);
        }
    }

    def _find_entry(useragent: str) -> (Entry | None) {
        g = self.groups.get(useragent.lower(), None);
        if g != None {
            ge: Entry = g;
            return ge;
        }
        for (k, ent) in self.groups.items() {
            if ent.applies_to(useragent) {
                return ent;
            }
        }
        g2 = self.groups.get("*", None);
        if g2 != None {
            gstar: Entry = g2;
            return gstar;
        }
        return None;
    }

    def can_fetch(useragent: str, url: str) -> bool {
        # using the parsed robots.txt decide if useragent can fetch url
        if self.disallow_all {
            return False;
        }
        if self.allow_all {
            return True;
        }
        # Until the robots.txt file has been read or found not
        # to exist, we must assume that no url is allowable.
        # This prevents false positives when a user erroneously
        # calls can_fetch() before calling read().
        if self.last_checked == 0 {
            return False;
        }
        sp = urlsplit(url);
        u = sp.path;
        qpos = url.find("?");
        fpos = url.find("#");
        if len(sp.query) > 0 or (qpos >= 0 and (fpos < 0 or qpos < fpos)) {
            u += "?" + sp.query;
        }
        if len(sp.fragment) > 0 {
            u += "#" + sp.fragment;
        }
        u = normalize_uri(u);
        if len(u) == 0 {
            u = "/";
        }
        if u == "/robots.txt" {
            # The /robots.txt URI is implicitly allowed.
            return True;
        }
        ent = self._find_entry(useragent);
        if ent == None {
            return True;
        }
        ee: Entry = ent;
        return ee.allowance(u);
    }

    def crawl_delay(useragent: str) -> (int | None) {
        if self.mtime() == 0 {
            return None;
        }
        ent = self._find_entry(useragent);
        if ent == None {
            return None;
        }
        ee: Entry = ent;
        return ee.delay;
    }

    def request_rate(useragent: str) -> (RequestRate | None) {
        if self.mtime() == 0 {
            return None;
        }
        ent = self._find_entry(useragent);
        if ent == None {
            return None;
        }
        ee: Entry = ent;
        return ee.req_rate;
    }

    def site_maps -> (list[str] | None) {
        if len(self.sitemaps) == 0 {
            return None;
        }
        return self.sitemaps;
    }

    def __str__ -> str {
        ents = self.entries;
        if self.default_entry != None {
            de: Entry = self.default_entry;
            ents = ents + [de];
        }
        parts: list[str] = [];
        for e in ents {
            s = str(e);
            if len(s) > 0 {
                parts.append(s);
            }
        }
        return "\n\n".join(parts);
    }
}
