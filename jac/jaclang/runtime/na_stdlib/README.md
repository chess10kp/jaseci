# Bundled native standard library (`na_stdlib`)

Pure-Jac `.jac` modules shipped with jaclang that implement a
Python-congruent **standard library for the native (na) compiler pathway**
(issues [#6404] / [#6940]). This is **Mechanism B**: ordinary Jac compiled and
linked like user code, with zero per-module backend work.

## How resolution works

`jaclang.compiler.frontend.codeinfo.resolve_native_module` is the single shared resolver
used by `BoundaryAnalysisPass`, `NaIRGenPass`, and `NativeCompilePass`. It
searches **nearest-wins**:

1. the importing project's own tree (a flat sibling, then the dotted hierarchy
   walked up to the filesystem root), then
2. this bundled root (`native_stdlib_root()`), which is native **by
   location** -- its modules are plain `.jac` files. At either step a
   per-architecture variant `<name>.<arch>.jac` (e.g.
   `_math_fused.aarch64.jac`) is probed first, then a per-OS variant
   `<name>.<os>.jac` (e.g. `_dirent_native.darwin.jac`), then the plain
   `<name>.jac`.

So `import from os.path { normpath }` binds CPython's `posixpath` on the sv
(Python) pathway and `na_stdlib/os/path.jac` on the na (native) pathway (the
*same source* on both), while a user module of the same name always shadows the
bundled one. A bundled module links through the existing cross-module machinery
(binding population, then extern forward-decl, then `link_in`), on both the AOT
(`jac build --native`) and JIT execution paths.

Bundled library functions use module-qualified LLVM symbols derived from their
relative library paths. This keeps symbols stable across installations and
separates Jac functions from libc symbols and functions in other modules. The
native layout records the emitted name separately from its source-level key.

## Shipped modules

- **`os/path.jac`** (#6940 Phase 0, extended #8201) -- pure-string POSIX path
  helpers (`normpath`, `dirname`, `basename`, `split`, `splitext`, `isabs`,
  `join`, `abspath`, plus `relpath` and `normcase`). `relpath` is CPython's
  algorithm verbatim: absolutize both sides, drop empty components, walk off
  the shared prefix with `..` for each remaining `start` component, and answer
  `.` when nothing is left. `normcase` is the identity, which is what it is on
  POSIX. Filesystem operations (`exists`, `isfile`, `isdir`, `realpath`,
  `getsize`, and `getmtime`) expose typed entry points backed by the existing
  native OS primitives. These declarations keep direct and aliased imports
  consistent with calls through `os.path`.
  `expanduser` supports string paths on 64-bit Linux and Darwin: bare `~`
  honors `HOME` (including an empty value), falls back to the current user's
  account when unset, and `~name` looks up that user independently of `HOME`.
  Unknown users leave the path unchanged. The reentrant account lookup uses
  platform-specific `struct passwd` layouts and grows its buffer on `ERANGE`.
  Qualified `os.path` calls and direct/aliased imports use the same bundled
  implementation; no Python runtime is required.
- **`json.jac`** (#6940 Phase 1) -- a recursive-descent `loads` over boxed
  `any` (dict/list/str/int/float/bool/None) plus a `dumps` serializer matching
  CPython's default `(', ', ': ')` separators and insertion-ordered keys.
  One documented divergence: only the control set + JSON metacharacters are
  escaped, so congruence holds for ASCII payloads (`ensure_ascii` of
  non-ASCII is a follow-up). (`dumps` of floats now matches CPython: native
  `str(float)` produces the shortest-round-trip repr -- #6940 Phase 0.3,
  pinned byte-for-byte against CPython in the native suite.)
- **`datetime.jac`** (#6940 Phase 1 / #6951, extended to the full surface) --
  a faithful port of CPython's `_pydatetime.py`: `timedelta`, `date`,
  `tzinfo`, `time`, `datetime`, `timezone`, `struct_time`, and
  `IsoCalendarDate`, with the same class hierarchy (`datetime(date)`,
  `timezone(tzinfo)`). Civil-date math uses the proleptic-Gregorian ordinal
  algorithms; timezone-aware math rides the `tzinfo` protocol
  (`utcoffset`/`dst`/`tzname`/`fromutc`), `datetime.astimezone` performs the
  local-timeline conversion like CPython (including the fold probe), and
  `strptime` is a hand-rolled matcher port of `_strptime.py` since no regex
  engine exists natively. `_datetime_native.jac` is the FFI floor:
  `clock_gettime`/`localtime_r`/`gmtime_r`/`strftime`
  over shared `malloc`'d `struct tm`/`timeval` storage (glibc `tm_gmtoff`/
  `tm_zone` read at fixed offsets). SCOPE divergences: `datetime.date()` /
  `time()` / `timetz()` and `datetime.combine` return/accept `any` at the type
  level because method names shadow class names inside `obj datetime`
  (runtime behavior unchanged); `strftime` locale text comes from libc, like
  CPython's.
- **`calendar.jac`** -- a port of CPython's `calendar.py`: `Calendar` /
  `TextCalendar` (`formatweek`-`formatyear`, `prweek`-`pryear` via
  `sys.stdout.write` since `print` doesn't lower), the `itermonth*` iterators,
  `monthcalendar`-`yeardatescalendar` grids, `isleap`/`leapdays`/`weekday`/
  `monthrange`, `month_name`/`month_abbr`/`day_name`/`day_abbr`, and the
  `IllegalMonthError`/`IllegalWeekdayError` exceptions (no `super.init` -- it
  doesn't lower). SCOPE divergences: `weekday`/`monthrange` return plain
  `int`, not the 3.14 `Day`/`Month` `IntEnum`s, and the name tables are static
  English `list[str]` rather than locale-aware `_localized_*` objects.
- **`zoneinfo.jac`** -- a port of CPython's `zoneinfo/_zoneinfo.py`: a full
  TZif v1/v2+ parser (big-endian headers, transition/type arrays, POSIX TZ
  footer via `_TZStr` transition rules), `ZoneInfo` with module-level cache +
  `no_cache`/`from_file`/`clear_cache`, `TZPATH` filesystem discovery through
  `_file_native`/`_directory_native`, `available_timezones`, and
  `ZoneInfoNotFoundError`. `utcoffset`/`dst`/`tzname`/`fromutc` follow the
  `_ttinfo` transition logic including fold/gap handling, so
  `datetime.astimezone` conversion works end to end. SCOPE: TZif files only --
  no `datetime.tzfile`/`tzstr` fallbacks, and POSIX-footer parsing covers the
  common `EST5EDT,M3.2.0/2,M11.1.0` forms.
- **`gzip.jac`** (#6978 Phase 2) -- a Mechanism-B gzip framing over the
  bundled `zlib` floor (no new FFI): `compress(data, compresslevel=9, mtime=0)`
  and `decompress(data)`. gzip is zlib's DEFLATE engine plus an RFC 1952 header,
  CRC-32, and ISIZE trailer, so the surface reuses the `zlib` floor's
  `compress2` and shared streaming inflater. `compress` takes the raw DEFLATE
  body (the zlib stream with its 2-byte header + 4-byte adler32 stripped --
  the DEFLATE bytes are identical under either frame) and wraps it; the result
  is byte-identical to CPython's `gzip.compress` at the same level/`mtime` (XFL 2 for level 9,
  4 for level < 2, 0 otherwise -- zlib's gzip-header rule, which CPython
  reuses -- and OS byte 255; CPython 3.14 also defaults `mtime` to 0, so the
  defaults agree byte-for-byte). `decompress` walks the members of the stream
  exactly as CPython does: per member it parses the header (honoring the
  FEXTRA / FNAME / FCOMMENT skips; the 2 FHCRC bytes are skipped unverified,
  which is also CPython's behavior), then raw-inflates the DEFLATE body in a
  single streaming pass (`windowBits = -15`); the stream's `total_in` locates
  the member boundary, after which gzip's own CRC-32 and ISIZE are enforced
  (compared mod 2^32, per RFC 1952, so members over 4 GiB verify the same way
  CPython does) before concatenating the member outputs. The output buffer
  starts at the final-ISIZE hint and grows geometrically on `Z_BUF_ERROR` up
  to DEFLATE's ~1032x expansion ceiling. A member with no end-of-stream
  marker (including a bare header glued onto a trailer) raises, as does
  trailing garbage after the last member -- matching CPython. Error-type
  mapping: the native surface raises `ValueError` with static messages where
  CPython raises `gzip.BadGzipFile` (an `OSError` subclass: bad magic /
  unknown method / CRC / length), `EOFError` (truncation), or `zlib.error`
  (corrupt DEFLATE data). The `GzipFile` class and streaming file API are out
  of scope.
- **`base64.jac`** (#6978 Phase 3) -- self-contained RFC 4648
  base16/base32/base64 (`b16`/`b32`/`b64` encode+decode, `altchars`,
  `standard_`/`urlsafe_` variants) plus RFC 1924 base85 (`b85encode`/`b85decode`,
  the alphabet CPython's `base64.b85encode` uses). A big-endian bit-accumulator
  over `bytes` primitives -- no FFI floor, no big-int -- growing the result in a
  `list[int]` and converting once with `bytes(...)`. Encoding is byte-identical
  to CPython for all 256 byte values; decoding matches the embedded CPython
  3.14 semantics, probed case by case: `b64decode(validate=False)` (the
  default) discards non-alphabet bytes and applies 3.14's end-of-input padding
  rules (so newline-wrapped MIME/PEM input decodes, unpadded input raises
  `Incorrect padding`); `validate=True` implements strict mode with CPython's
  leading/excess/discontinuous-padding errors; `urlsafe_b64decode` accepts
  both the `+/` and `-_` alphabets (CPython translates then decodes); `b16`
  enforces digit-before-odd-length checks; `b32decode` takes `casefold` and
  `map01` and enforces `len % 8` plus CPython's valid pad-count set
  {0,1,3,4,6}; `b85decode` reports CPython's absolute error positions and the
  32-bit overflow check. Error messages match CPython text, raised as
  `ValueError` (CPython raises `binascii.Error`, itself a `ValueError`
  subclass, so `except ValueError` is congruent; the message text is
  identical). SCOPE: the CPython `None` sentinels for `altchars`/`map01` are
  `b""` here (na has no None-able `bytes` parameter), and bad `altchars`/
  `map01` lengths raise `ValueError` where CPython asserts; the Ascii85
  (`a85`) variant is a follow-up.
- **`textwrap.jac`** (#6978 Phase 3) -- the greedy line wrapper (`wrap`,
  `fill`) plus `dedent` and `indent`, a faithful port of CPython's
  `TextWrapper._wrap_chunks`/`_handle_long_word` over primitives (following
  CPython **>= 3.14** long-word semantics -- 3.14 stopped breaking a long word
  when `space_left == 0`, so 3.13-and-earlier output differs exactly there; the
  bundled sv runtime is 3.14 -- plus the `width <= 0` ->
  `ValueError("invalid width ... (must be > 0)")` error path). **WARNING -- default-call divergence:** this module implements
  `break_on_hyphens=False` semantics (words split on whitespace only), but
  CPython's default is `break_on_hyphens=True`; the *same* `wrap(text, width)`
  call therefore returns different lines on sv vs na whenever the text contains
  hyphenated words (e.g. `wrap("well-known", 6)` -> `['well-', 'known']` on sv,
  `['well-k', 'nown']` on na). Keep hyphenated text away from `wrap`/`fill`, or
  pass `break_on_hyphens=False` explicitly on the sv side. All other
  TextWrapper defaults matched (`expand_tabs`, `replace_whitespace`,
  `drop_whitespace`, `break_long_words`, empty indents, no `max_lines`);
  `indent` splits on `"\n"`; `shorten`/`TextWrapper` not provided.
- **`csv.jac`** (#6978 Phase 3) -- `reader` for the default **excel** dialect
  (delimiter `,`, quotechar `"`, `doublequote=True`, `skipinitialspace=False`,
  QUOTE_MINIMAL). Field parsing matches CPython exactly (quoted fields, doubled
  quotes, a quote opening a field only at its start, literal mid-field quotes,
  unterminated quotes, a `\n` inside a quoted region of a single input string,
  empty line -> `[]`). A NUL character parses as an ordinary character,
  matching CPython **>= 3.14** (3.13 and earlier raised
  `csv.Error("line contains NUL")`; the bundled sv runtime is 3.14) -- but the
  native string type drops an embedded NUL byte on concatenation, so while
  field *splitting* around a NUL is congruent, NUL-bearing field *content* is
  not (`"a\x00b"` comes back as `"ab"` on na). Note the native pathway has no
  `csv.Error` type anyway -- if a future error path is added it will surface as
  `ValueError`.
  SCOPE: eager `list[list[str]]` (congruent with `list(csv.reader(...))`), one
  record per input string -- a *record* cannot span two input strings, so
  feeding a file's raw split lines with multi-line quoted fields diverges from
  CPython's file-object mode; `writer`/`DictReader`/`DictWriter`/custom
  dialects not provided.
- **`pprint.jac`** (#6978 Phase 3) -- `pformat` rendering a single-line repr
  with dict keys sorted (CPython `sort_dicts=True`) and Python `repr`
  conventions for str/int/bool/None/list/dict, including full string escaping:
  backslash/quotes, `\n`/`\t`/`\r` short forms, and `\xNN` for the remaining
  C0 controls (0x00-0x1f) and DEL (0x7f). SCOPE: **single-line output only** --
  CPython wraps representations longer than `width=80` across lines, so any
  object whose repr exceeds one line diverges (width-driven wrapping not
  implemented); string dict keys; floats print with CPython's
  shortest-round-trip repr (#6940 Phase 0.3, so the old `%g` divergence is
  gone); bytes > 0x7f pass through unescaped, so *unicode* non-printables
  (e.g. U+00A0, U+200B) are NOT `\uXXXX`-escaped as CPython would -- congruent
  for ASCII and printable-unicode payloads. Out-of-scope value types: `set`
  raises `ValueError("pprint: unsupported value type on native")` instead of
  silently misrendering; other non-JSON values (e.g. object instances) cannot
  be type-discriminated from `None` by the native runtime today (JacVal tags 6
  vs 8 are both invisible to `isinstance`, and `any` truthiness/`is None` are
  not native-compilable), so they render as `"None"` -- a documented
  divergence.
- **`difflib.jac`** (#6978 Phase 3) -- `SequenceMatcher`
  (`ratio`/`get_matching_blocks`/`set_seq1`/`set_seq2`, full 4-arg constructor
  including `autojunk`) and `get_close_matches`, a port of CPython's
  longest-match DP, matching-block recursion, and `__chain_b` popular-element
  pruning (`autojunk=True` and `len(b) >= 200`: elements occurring more than
  `len(b) // 100 + 1` times cannot seed a match, exactly as their exclusion from
  CPython's `b2j`; they still participate in match extension since `bjunk` is
  empty). `get_close_matches` raises CPython's `ValueError`s for `n <= 0` and
  `cutoff` outside `[0.0, 1.0]`. SCOPE: string sequences; `isjunk` accepted but
  ignored (a non-None `isjunk` silently behaves as None -- the remaining
  error-path/behavior divergence); `ratio` is the same IEEE-double value (only
  its `str` rendering would differ);
  `get_opcodes`/`unified_diff`/`ndiff`/`Differ`/`HtmlDiff` not provided.

- **`statistics.jac`** (#7593 item 18) -- double-precision
  `fmean`/`mean`/`median`/`median_low`/`median_high`/`variance`/`pvariance`/
  `stdev`/`pstdev` over generic `[T]` defs, so int and float sequences both
  monomorphize without boxing. SCOPE/divergences: results always compute in
  float (CPython runs exact Fraction arithmetic internally and `median` of an
  odd-count sequence returns the element itself, preserving int), and errors
  raise `ValueError` directly (CPython's `StatisticsError` subclasses
  `ValueError`, so `except ValueError` behaves identically on both backends).

- **`shutil.jac`** (#7593 item 18) -- `which`/`copyfile`/`copy`/`copy2`/
  `move`/`rmtree` over the native os intrinsics (getenv, path.join,
  path.isdir, path.isfile, path.basename) plus direct libc (access, unlink,
  rmdir, rename, opendir/readdir/closedir). The dirent d_name offset follows
  the glibc x86-64/aarch64 layout (d_ino 8 + d_off 8 + d_reclen 2 + d_type 1
  = 19), matching the platform scope of the other libc-backed modules.
  SCOPE/divergences: copy/copy2 duplicate bytes but do not yet preserve
  mode/mtime metadata; rmtree follows the isdir predicate, so directory
  symlinks are recursed into rather than unlinked; errors raise `ValueError`
  rather than CPython's `OSError` subclasses.

- **`keyword.jac`** (#7593 item 18) -- `kwlist`/`softkwlist`/`iskeyword`/
  `issoftkeyword` mirroring CPython's lists verbatim, ordering included
  (stable since 3.10's soft-keyword additions).

- **`fractions.jac`** (#6978 Phase 2) -- a pure-Jac (Mechanism B) `Fraction`
  over native `int`, normalized on construction via Euclid's GCD with the sign
  carried by the numerator and the denominator kept positive (CPython's value
  model). Construction/reduction (`Fraction(n, d)`), `numerator` /
  `denominator`, and `str()` match CPython exactly. Arithmetic and ordering are
  the CPython dunder methods (`__add__` / `__sub__` / `__mul__` / `__truediv__`
  / `__eq__` / `__lt__`). The na fixture calls them directly (`a.__add__(b)`)
  where the sv fixture uses `+` / `<`, and the resulting *values* are
  congruent; the operator spellings lower too, since the backend now routes a
  binary operator over an archetype through `_emit_arch_dunder_binop`
  (forward magic, then the reflected one) against
  `type_system.operations.BINARY_OPERATOR_MAP`.
  Float/Decimal/string construction is out of scope. SCOPE: native `int` is a
  fixed-width i64, so the cross-multiplications in `__add__` / `__lt__` (and
  friends) silently overflow once intermediate products exceed 2^63, where
  CPython's bignum `Fraction` stays exact; keep components comfortably below
  ~3x10^9 (sqrt of i64 max).

- **`ipaddress.jac`** (#6978) -- a pure-Jac (Mechanism B) port of CPython
  3.14's `ipaddress`: `IPv4Address` / `IPv6Address` / `IPv4Network` /
  `IPv6Network`, the `ip_address` / `ip_network` factories, and
  `summarize_address_range`. IPv6 values are carried as two `u64` halves
  (`_hi` / `_lo`) with `wrapping_*` arithmetic, since native `int` is a
  checked i64 and `1 << 63`-style literals/overflows are runtime errors.
  Strings, ints, and packed `bytes` constructors; compressed/exploded forms,
  scope IDs, IPv4-mapped/6to4/Teredo lookups; netmask/hostmask parsing
  (dotted and prefix forms); strict/non-strict networks; `hosts()`,
  `subnets()`, `supernet()`, `address_exclude()`, iteration and indexing;
  `AddressValueError` / `NetmaskValueError` exception classes. SCOPE:
  `IPv6Address.__int__()` and `IPv6Network.num_addresses` past i64 max raise
  a native overflow error where CPython's bignum stays exact; comparisons,
  `in`, and indexing go through explicit dunder calls in the na fixture
  (archetype operator dispatch is a backend gap).

- **`urllib/parse.jac`** (#6978) -- a pure-Jac (Mechanism B) port of CPython
  3.14's `urllib.parse` str-path surface: `urlparse` / `urlsplit` /
  `urlunparse` / `urlunsplit` / `urljoin` / `urldefrag`, the quoting family
  (`quote` / `quote_plus` / `quote_from_bytes` / `unquote` / `unquote_plus` /
  `unquote_to_bytes`), `parse_qs` / `parse_qsl` / `urlencode`, `unwrap`, and
  the deprecated `split*` helpers (`splittype` / `splithost` / `splituser` /
  `splitpasswd` / `splitport` / `splitnport` / `splitquery` / `splittag` /
  `splitattr` / `splitvalue`). Result objects (`ParseResult` / `SplitResult` /
  `DefragResult`) expose the component fields plus `username` / `password` /
  `hostname` / `port` getters, `geturl()`, and `__getitem__`; CPython's
  bracketed-IPv4 and invalid/out-of-range port `ValueError`s match.
  `str.partition` / `str.rpartition` crash native codegen, so the module
  splits on `find` + slicing via local `_partition` / `_rpartition` helpers.
  SCOPE (boxed-`any` tag loss: an `any` parameter stores typed-container
  elements unboxed, so they read back as raw pointers):
  `urlunparse`/`urlunsplit` take `ParseResult | SplitResult | DefragResult |
  list[str]` (a union keeps element tags) rather than CPython's arbitrary
  sequence, and `urlencode` takes `dict[str, str | list[str]] |
  list[list[str]]` -- tuple component/pair sequences and `bytes`/
  non-`str` scalar values are native gaps. Pinned sv<->na congruent by
  `prim_urllib_parse.jac`.

- **`urllib/response.jac` + `urllib/error.jac`** (#6978) -- pure-Jac ports of
  CPython 3.14's response wrappers and error hierarchy. `response` provides
  `addbase` / `addclosehook` / `addinfo` / `addinfourl` over the bundled
  `io.BytesIO` / `io.StringIO` (`fp` is typed `BytesIO | StringIO`; arbitrary
  duck-typed file objects are a native gap since calls need a static receiver
  type). `error` provides `URLError(OSError)` with `reason` / `filename`,
  `HTTPError(URLError, addinfourl)` (exception + response in one, `fp=None`
  becomes an empty `BytesIO` as CPython does), and
  `ContentTooShortError`. `addclosehook` invokes hooks through a `CloseHook`
  archetype (`def call(args)`) because native first-class callables are a
  backend gap. SCOPE (backend bugs worked around, not fixed): `except`
  matching across module boundaries is exact-class only (a base-class
  handler does not catch a subclass raised elsewhere), method calls on a
  union-typed receiver mis-dispatch (all `fp` calls narrow through
  `isinstance` first), and a `(bytes | str)` union value holding `str` is
  corrupted when consumed -- callers read `StringIO` content through a
  narrowed `fp`. Pinned sv<->na congruent by `prim_urllib_resperr.jac`.

- **`urllib/request.jac`** (#6978) -- a pure-Jac port of CPython 3.14's
  `urllib.request` opener/handler architecture over the bundled `socket` +
  `ssl` floors (no libcurl): `Request` (computed `full_url` getter,
  `set_full_url`/`set_data`, `add_header`/`has_header`/`get_header`,
  redirect_dict), `OpenerDirector` + `BaseHandler` and the handler chain
  (`ProxyHandler`, `UnknownHandler`, `HTTPHandler`, `HTTPSHandler`,
  `HTTPDefaultErrorHandler`, `HTTPRedirectHandler`, `HTTPErrorProcessor`,
  `HTTPCookieProcessor`, `FileHandler`, `FTPHandler`, `DataHandler`), the
  password managers (`HTTPPasswordMgr` / `HTTPPasswordMgrWithDefaultRealm` /
  `HTTPPasswordMgrWithPriorAuth`, flat-row storage because tuple-keyed dicts
  do not lower), `HTTPBasicAuthHandler` / `ProxyBasicAuthHandler` and friends,
  `build_opener` / `install_opener` / `urlopen` / `urlretrieve` /
  `urlcleanup`, `pathname2url` / `url2pathname`, `parse_http_list` /
  `parse_keqv_list` helpers, and env-based
  `getproxies` / `proxy_bypass`. SCOPE (native gaps): handler discovery is
  explicit-dispatch tables (`open_kinds`/`req_kinds`/`resp_kinds`/
  `error_codes`) because `dir`/`getattr` reflection does not exist;
  `FTPHandler` raises `URLError` (no bundled `ftplib`); `CacheFTPHandler` is
  API-parity only; digest auth and macOS/Windows proxy discovery are out of
  scope; `urlretrieve` writes the whole body in one `write_file_bytes` call
  (reporthook still fires per 8 KiB block); `HTTPCookieProcessor` calls an
  arbitrary cookiejar through the bridge. The HTTP exchange is implemented
  directly over `socket`/`ssl`, parsing status + headers into an
  `addinfourl`-derived response. SCOPE (backend bug worked around, not
  fixed): fields set by an *inherited* `init` do not stick on the subclass
  instance natively (`HTTPResp(fp=..., code=...)` read back as defaults),
  so `_do_open` re-assigns every field explicitly after construction.

- **`urllib/robotparser.jac`** (#6978) -- a pure-Jac port of CPython 3.14's
  `urllib.robotparser` (RFC 9309): `RobotFileParser` (`set_url` / `read` /
  `parse` / `can_fetch` / `crawl_delay` / `request_rate` / `site_maps` /
  `mtime` / `modified`), the `RuleLine` / `Entry` helpers, `merge_entries`,
  and `normalize_uri` / `normalize_pattern`. There is no bundled `re`, so
  `*`/`$` patterns are matched by an equivalent manual scan (lazy `.*?`
  between segments, greedy trailing `.*` for prefix rules, end-anchored last
  segment for `$` rules) preserving match-length ordering;
  `translate_pattern` is omitted, and `RequestRate` is a plain object rather
  than a namedtuple. `modified()` uses a libc `time()` FFI. SCOPE: caught
  cross-module exception fields are a backend gap, so `read()`'s 401/403/4xx
  marking via `err.code` may be unreliable. Pinned sv<->na congruent by
  `prim_robotparser.jac` (pure-parse surface only; `read()` needs network).

- **`select.jac`** (#6978) + **`_select_native.jac`** -- a Mechanism F port of
  CPython 3.14's `select` over raw libc FFI: `select(rlist, wlist, xlist,
  timeout=None)` (fd_set bitmap + `timeval` packed into `bytes` buffers,
  `int.from_bytes` on the way back), `poll` (`register` / `modify` /
  `unregister` / `poll(timeout_ms)`; `pollfd` structs packed 8 bytes each),
  and Linux `epoll` (`register` / `modify` / `unregister` /
  `poll(timeout_s, maxevents)` / `close` / `fileno` / `closed`), plus the
  `POLL*` / `EPOLL*` constants and `PIPE_BUF`. Lists are typed `list[int]`
  -- CPython's fileno()-bearing objects are a native gap, callers pass
  `.fileno()`. Two FFI quirks shaped the floor: a clib extern lands in the
  shared native symbol table under its C name, so libc `select` is bound as
  `__select` to avoid shadowing the module's own `select` function, and
  `socketpair` has no glibc `__` alias so `_socket_native.sock_pair` goes
  through `syscall(53, ...)` (x86-64 `__NR_socketpair`; aarch64 would need
  199) for the same reason. SCOPE: `select.error` is `OSError` (CPython
  aliases it), `kqueue` / `devpoll` / `epoll.fromfd` and non-Linux targets
  are unimplemented. Pinned sv<->na congruent by `prim_select.jac` (ES opts
  out).

- **`socket.jac`** (#6978) + **`_socket_native.jac`** -- a Mechanism F BSD
  sockets surface over libc FFI (Phase 1 added the client side; Phase 2 the
  server/datagram side). `socket(family, socktype, proto, fileno=-1)` with
  `connect` / `send` / `sendall` / `recv` / `close` / `fileno`, module-level
  `create_connection` and `socketpair` (via `syscall(53)`, x86-64
  `__NR_socketpair`, because a libc `socketpair` extern would share a symbol
  name with the surface function), plus Phase-2 `bind` / `listen` / `accept` /
  `getsockname` / `setsockopt` (int options) / `sendto` / `recvfrom` /
  `shutdown`, `connect_path` / `bind_path` / `sendto_path` for `AF_UNIX`,
  `connect6` / `bind6` / `sendto6` for `AF_INET6` 4-tuples, and the
  `AF_*`/`SOCK_*`/`IPPROTO_*`/`SHUT_*`/`SOL_SOCKET`/`SO_*`/`SOMAXCONN`/
  `TCP_NODELAY` constants. Sockaddrs are packed as `bytes` in
  `_socket_native` (`inet_pton`/`inet_ntop`/`strncpy` FFI; dotted hosts parse
  directly, names fall back to `getaddrinfo` results). SCOPE: tuple-polymorphic
  parameters do not lower natively, so CPython's single `bind(address)` /
  `sendto(data, address)` split by family (`bind`/`bind6`/`bind_path`,
  `sendto`/`sendto6`/`sendto_path`), and peer/sock addresses come back as a
  normalized `(host, port, flowinfo, scopeid)` 4-tuple where CPython returns a
  2-tuple for `AF_INET` and a `str` for `AF_UNIX` (na returns `(path, 0, 0,
  0)`). `setsockopt` takes int values only, `getsockopt`/`setblocking`/timeouts
  and `sendmsg`/`recvmsg` are unimplemented. Pinned sv<->na congruent by
  `test_socket_equivalence.jac` / `prim_socket.jac`.

- **`socketserver.jac`** (#6978) + **`_socketserver_native.jac`** -- a
  Mechanism F port of CPython 3.14's `socketserver` over the bundled `socket`
  + `select` floors: `BaseServer` / `TCPServer` / `UDPServer` /
  `UnixStreamServer` / `UnixDatagramServer`, the `ThreadingMixIn` and
  `ForkingMixIn` variants, and `BaseRequestHandler` / `StreamRequestHandler`
  (`connection`/`rfile`/`wfile` via `SockFile`) / `DatagramRequestHandler`
  (`packet`/`socket`/`rfile`/`wfile` via `BytesIO`). `handle_request`,
  `serve_forever`, `shutdown`, `verify_request`, `process_request`,
  `finish_request`, `shutdown_request`, `close_request`, `handle_error`,
  `handle_timeout`, `fileno`, `server_bind`/`server_activate`/`server_close`,
  `enter`/`exit` (context-manager names are keywords), `request_queue_size`,
  `allow_reuse_address`/`allow_reuse_port`, `max_packet_size`, `timeout`, and
  `daemon_threads`/`block_on_close`/`max_children`/`active_children` fields.
  `ForkingMixIn` uses a real libc `fork`/`waitpid`/`_exit` floor
  (`_socketserver_native`); `ThreadingMixIn` executes inline because there is
  no native thread support. SCOPE divergences: **handlers are passed as
  instances, not classes** -- `TCPServer(addr, Echo())` rather than
  `TCPServer(addr, Echo)` -- because a class object held in a field cannot be
  invoked natively, so `finish_request` calls `RequestHandlerClass.run(...)`,
  which stores the request and drives `setup`/`handle`/`finish`; handler
  classes therefore declare a no-arg `init` (`def init() {}`) and read the
  request via `self.request` (typed `any` on `BaseRequestHandler`, unboxed to
  `Socket` / `(bytes, Socket)` in each `setup`). `shutdown()` only sets a
  flag (no inter-thread wait, so it is callable same-thread from a handler --
  CPython's would deadlock there); `serve_forever`/`shutdown` are
  single-threaded. Addresses are the normalized `(host, port, flowinfo,
  scopeid)` 4-tuples from `socket`. Bare `except:` is written `except
  Exception`; `handle_error` writes one stderr line instead of a traceback;
  `StreamRequestHandler` timeout/rbufsize/wbufsize buffering knobs exist but
  do not alter `SockFile` behavior; `BaseRequestHandler`'s `request` field is
  `any`, so handler code that touches it demotes to the bridge. Pinned
  sv<->na congruent by `test_socketserver_equivalence.jac` /
  `prim_socketserver.jac` (TCP echo, `serve_forever`+`shutdown`, UDP echo).

- **`pathlib.jac`** (#8201) -- a `Path` that carries one normalized POSIX
  string and derives every member from it, which is CPython's `PurePosixPath`
  value model: construction splits on `/`, drops empty and `.` components,
  keeps `..` (collapsing one lexically is not symlink-safe), and preserves the
  POSIX root -- `/`, or the special `//` a leading double slash denotes, which
  `///` does not. An all-empty result renders as `.`, so `str(Path(""))` is
  `"."`. Provided surface: `Path(str)`, `Path(Path)`, `str()` / f-string
  interpolation, truthiness, `.name`, `.stem`, `.parent`, `/`, `.resolve()`,
  `.exists()`, `.is_dir()`. Anything outside it does not exist on the type, so
  a native compile that reaches for one fails with "Type `Path` has no
  attribute ..." rather than silently answering wrong.
  `.stem` follows `os.path.splitext`, which is what CPython's own `stem`
  reduces to: the last `.` splits the name only when some non-`.` character
  precedes it, so `.bashrc` and `..` are entirely stem, while a trailing dot
  does split (`b.` has stem `b`) -- that last case is CPython **>= 3.14**
  behavior (3.13 and earlier answered `b.`) and the bundled sv runtime is 3.14.
  SCOPE: POSIX only (no Windows flavour, no drive letter, no
  `PureWindowsPath`). `.resolve()` absolutizes against `os.getcwd()`, resolves
  symlinks through the `realpath(3)` intercept, then collapses `.`/`..`
  lexically -- byte-identical to CPython for a path that exists, but for a path
  whose components do not all exist `realpath(3)` reports failure and the
  answer falls back to the lexical collapse, so a symlink sitting on an
  existing *prefix* of a missing path is not resolved the way CPython's
  component walk resolves it. Comparison, hashing, iteration, `.parts`,
  `.suffix`, `.glob`, `.open`, `.cwd()`, `.home()`, and the whole I/O surface
  are not provided.

- **`fnmatch.jac`** (#8201) -- `fnmatch` and `fnmatchcase` as a direct
  backtracking glob matcher (`*`, `?`, `[seq]`, `[!seq]`, ranges), since the
  native pathway has no regex engine to translate into. The bracket scanner
  reproduces CPython's `translate` rules exactly: a `]` immediately after `[`
  or `[!` is a literal member, an unterminated `[` degrades to a literal `[`,
  and a `-` first or last in a class is a literal `-`. Pinned against CPython
  over a 29-pattern by 14-name grid. `normcase` is the identity, which is what
  it is on POSIX, so `fnmatch` and `fnmatchcase` agree here; on Windows
  CPython's `fnmatch` would case-fold first. `filter` and `translate` are not
  provided.

- **`logging.jac`** (#8201) -- `basicConfig`, `getLogger(name)`, the level
  constants, and `.debug`/`.info`/`.warning`/`.error`/`.critical` on both the
  logger and the module. Records go to stderr, which is where CPython's
  last-resort/`basicConfig` handler puts them, rendered through the
  `%(levelname)s` / `%(name)s` / `%(message)s` fields of the active format
  (default `BASIC_FORMAT`, i.e. `LEVEL:name:message`). The WARNING default
  threshold is honored, so `.debug`/`.info` are dropped until `basicConfig`
  lowers it, matching CPython. SCOPE: no handlers, formatters, filters, or
  logger hierarchy -- there is one process-wide level and one format, so
  `Logger.setLevel` sets *the* level rather than that logger's, and
  `basicConfig` is not the once-only call it is on CPython (a second call
  reconfigures). `%(asctime)s` and the other `%`-fields are left in the output
  verbatim rather than substituted; `filename`/`filemode`/`stream`/`handlers`
  are accepted and ignored, so file logging silently stays on stderr.
  Lazy `%`-args (`log.info("x %s", y)`) and `exc_info` are not provided.

- **`contextvars.jac`** (#8201, held back by #8220 until #8229 and #8230
  landed) -- `ContextVar[T]` as a single process-wide cell: `ContextVar(name)`
  and `` ContextVar(name, `default=...) ``, `.name`, `.get()`, `.get(default)`
  and `.set(value)`. `get` walks CPython's precedence -- the value last `set`,
  else the default the call passed, else the default the constructor took,
  else `LookupError(name)`.
  SCOPE: `None` is the sentinel for *both* "no value" and "no default", where
  CPython keys the second step on whether the argument was **passed**, so an
  explicit `get(None)` reads as an omitted argument: on an unset variable it
  answers the constructor default, or raises, where CPython answers `None`.
  (A variadic `get(*fallback: T)` would carry the presence bit exactly, but a
  variadic parameter of the erased type segfaults the native binary, so this
  waits on that gap.) `None` is likewise the unset marker in the value slot,
  so `set(None)` on a `ContextVar[X | None]` reads back as unset.
  There is also one cell per variable rather than one per context, because
  the native pathway has neither asyncio tasks nor threads to separate them,
  so `copy_context`, `Context.run`, and the `Token` that `set` returns
  (with `reset`) are not provided -- `set` answers `None`. A reference type
  argument (an archetype, `list`, `dict`) lowers; a **scalar** one
  (`int`, `float`, `bool`, and `str`, which is a by-value descriptor
  natively) is refused at the construction site with `E5092` naming the
  instantiation, because a generic archetype is laid out once for every
  instantiation and its `T` slot is a raw pointer (#8229).

- **`io.jac`** (Mechanism B) -- `BytesIO` (the CPython `io.BytesIO` value
  model: `read`/`read1`/`write`/`seek`/`tell`/`getvalue`/`seek`-relative
  `whence`, growth-with-NUL-fill on a seek-past-end write, `close`, context
  manager) plus a `BufferedIOBase` name whose abstract methods raise, and the
  `SEEK_*` / `DEFAULT_BUFFER_SIZE` constants. On the sv pathway `import io`
  binds CPython's real `io` (same source, different binding), so the API
  names/semantics match. DIVERGENCE: `BytesIO` is a **standalone** class rather
  than a `BufferedIOBase` subclass -- the native pathway does not yet support
  cross-module vtable dispatch (calling an overridden method through a
  base-typed reference defined in another module aborts at run time), so the
  bundled readers avoid inheritance across the module boundary. SCOPE: binary
  streams only (no text `StringIO`, no `BufferedReader`/`BufferedWriter`
  wrappers).

- **`compression/zstd.jac`** (Mechanism F) + **`_zstd_native.jac`** (FFI
  floor over the bundled `libzstd`, zstd 1.5.7) -- the CPython 3.14
  `compression.zstd` read subset: `compress(data, level=3)` (one-shot
  `ZSTD_compress2` with `ZSTD_c_compressionLevel`; byte-identical to CPython at
  the same level, both over the same library), `decompress(data)` (loops
  `ZSTD_decompressStream` across MULTIPLE concatenated frames, exactly as
  CPython does), `ZstdDecompressor` (`decompress(data, max_length=-1)`, `eof`,
  `needs_input`, `unused_data` -- single-frame semantics with the remainder
  surfaced as `unused_data`, `d_windowLogMax` raised to 27), read-mode
  `ZstdFile(file: io.BytesIO, mode="rb")` that pulls 1 MiB compressed chunks
  and decodes incrementally, continuing seamlessly across concatenated frames
  (`read`/`read1`/`seek`/`tell`/`close`/context manager), `get_frame_info`
  (`ZSTD_getFrameContentSize`), the `ZstdError` exception, and the
  `zstd_version` string. A zstd error raises `ZstdError` (on sv the real one).
  DIVERGENCES: `ZstdFile` is read-only and, being standalone (see `io.jac`),
  types its source as a concrete `io.BytesIO` rather than a general file object
  (a path variant is not accepted); write/append modes raise `ValueError`. The
  floor also defines strong no-op `ZSTD_trace_{compress,decompress}_{begin,end}`
  symbols: `libzstd` is built with `ZSTD_TRACE` and references those four hooks
  weakly, which the dynamic loader binds to 0 (JIT path) but the AOT static
  linker emits as hard dynamic-undefined symbols -- the stubs satisfy them so a
  `jac build --native` binary links and runs. Native-host only (wasm gets a clean
  link error). Pinned sv<->na congruent by `test_zstd_equivalence.jac`.

- **`tarfile.jac`** (Mechanism B) + **`_tarfile_native.jac`** (tiny libc FFI
  floor: `chmod`/`symlink`/`link`/`utime`/`creat`/`write`) -- a streaming-read
  subset of CPython 3.14 `tarfile`: `open(name=None, mode="r", fileobj=None)`
  supporting `"r"`/`"r:"`/`"r|"`, `TarInfo`
  (`name`/`size`/`mtime`/`mode`/`type`/`linkname`/`uid`/`gid`/`uname`/`gname`
  plus `isfile`/`isdir`/`issym`/`islnk`/`isreg`), `TarFile`
  (`next`/`__iter__`/`__next__`/`getmembers`/`extractfile` returning an
  `io.BytesIO`/`extractall(path, filter="data")`/`close`/context manager).
  Header parsing is full POSIX ustar 512-byte blocks: octal fields **and** the
  GNU base-256 binary encoding for sizes > 8 GiB, unsigned+signed checksum
  verification, two zero blocks (or a truncated end) terminate, typeflags
  `0`/`\0`/`5`/`2`/`1`/`x` (pax `path`/`linkpath`/`size`/`mtime` records)/`g`
  (global pax, skipped)/`L`/`K` (GNU long name/link), padding to 512-byte
  blocks. `extractall` creates parent dirs, writes regular files, makes dirs,
  and applies `mode & 0o777` via a libc `chmod` plus the CPython `data`-filter
  permission rules (`mode & 0o755`, clear exec if not user-exec, `| 0o600` for
  files; directories/symlinks keep the system mode). The `data` filter's path
  containment, absolute-path, and absolute-link checks are enforced, raising the
  CPython `FilterError` subclasses. DIVERGENCES: read-only (`w`/`a`/`x` raise);
  the whole archive is materialized as `bytes` at `open()` (so `"r|"` diverges
  from CPython's incremental stream in memory profile only -- the extracted tree
  is identical); a compressed `fileobj` must be a `compression.zstd.ZstdFile`
  (a plain `io.BytesIO` fileobj is not accepted on na -- use `name=` for an
  uncompressed file), and it must be called **module-qualified**
  (`import tarfile; tarfile.open(...)`) because a bare unqualified `open(...)`
  collides with the native builtin `open`; GNU sparse members raise; hard/soft
  links are created via libc `link`/`symlink` when trivial. Native-host only.
  Pinned sv<->na congruent by `test_tarfile_equivalence.jac`.
- **`math.jac`** (#6404, Mechanism B) + **`_math_native.jac`** (FFI floor over
  the host `m`/libm) -- a pure-Jac surface of ~50 CPython-congruent endpoints
  replacing the old Mechanism-A compiler intercepts: constants
  (`pi`/`e`/`tau`/`inf`/`nan`), the trig/hyperbolic/exp/log family,
  rounding-to-int (`floor`/`ceil`/`trunc`), integer functions
  (`factorial`/`isqrt`/`gcd`/`lcm`/`comb`/`perm`), binary functions
  (`atan2`/`copysign`/`fmod`/`pow`/`remainder`/`fma`), predicates
  (`isnan`/`isinf`/`isfinite`/`isclose`), float-bit
  decomposition/recomposition (`frexp`/`modf`/`ldexp`/`nextafter`/`ulp`), and
  the iterable reducers (`prod`/`fsum`/`hypot`/`dist`/`sumprod`). Raises match
  CPython 3.14 **type-and-message** exactly (e.g. `sqrt(-1)` ->
  `ValueError: expected a nonnegative input, got -1.0`; `log(4, 1)` ->
  `ZeroDivisionError: division by zero`; `fsum([inf, -inf])` ->
  `ValueError: -inf + inf in fsum`), pinned in `prim_math.jac`.
  Results are CPython's, not merely close to them: the libm wrappers call the
  same host libm CPython calls, `gamma`/`lgamma` are ports of CPython's own
  Lanczos `m_tgamma`/`m_lgamma` (CPython does not use libm for these), and
  `hypot`/`dist` port its `vector_norm` and `sumprod` its triple-length
  accumulator. Where CPython's C build fuses a multiply-add (clang contracts
  `a*b + c` into one rounding on aarch64, never on baseline x86-64),
  `_math_fused.<arch>.jac` supplies the same fused or unfused `fmadd`. A
  randomized sv/na differential sweep over every real function is
  bit-identical on macOS arm64. `floor`/`ceil`/`trunc` return an `int`
  argument unchanged (no float round trip), `gcd`/`lcm`/`hypot` are truly
  variadic (bundled modules may export `*args`; see the capability check),
  and the reducers take any iterable (`list`, `tuple`, `range`) through
  `[C: Iterable]` type parameters. The reducers and `hypot` allocate nothing
  per element beyond their inputs. `isclose`'s tolerances and `prod`'s
  `start` are keyword-only. `frexp`, `modf`, `ldexp`, `nextafter`, and
  `ulp` are pure-Jac float-bit manipulation with no libm dependency, so
  they are wasm-portable; the remaining libm wrappers resolve through host
  libm on native and through the vendored musl bitcode on wasm -- musl
  1.2.5 `exp2` and `fma` are vendored in `wasm_rt/vendor/math` (`fma`
  inlines the generic `a_clz_64` from musl's `atomic.h` in place of the
  arch include), and `erfc` ships inside the vendored `erf.c`. SCOPE/divergences:
  integer results are i64-bounded -- `factorial`, `comb`, `perm`, and `lcm`
  raise `OverflowError` where CPython returns a bignum, and `prod`/`sumprod`
  raise at the i64 boundary instead of silently degrading to float; and
  parameters are statically typed rather than dispatched through
  `__index__`/`__float__`/`__trunc__`. Both plain `import math` and
  `import from math { ... }` bind it.
- **`cmath.jac`** (Mechanism B, over the same `_math_native` libm floor) --
  a pure-Jac port of CPython's `cmathmodule.c` complex algorithms: the full
  inverse-trig/hyperbolic family (`acos`/`acosh`/`asin`/`asinh`/`atan`/
  `atanh`), `cos`/`cosh`/`sin`/`sinh`/`tan`/`tanh`, `exp`, `sqrt`, `log`
  (incl. the two-arg base form), `log10`, `phase`, `polar`, `rect`,
  `isfinite`/`isinf`/`isnan`/`isclose`, and constants `pi`/`e`/`tau`/`inf`/
  `nan`/`infj`/`nanj`. CPython's special-value tables for every finite/
  infinite/zero/NaN real-imaginary combination are carried over verbatim, so
  branch cuts, signed zeros, and `inf`/`nan` propagation match; error paths
  raise the same type-and-message (`ValueError: math domain error`,
  `OverflowError: math range error`), pinned in `prim_cmath.jac`. SCOPE:
  parameters are `complex`-typed -- unlike CPython, a plain `float`/`int`
  argument is not implicitly coerced (pass `complex(x, 0.0)`); results are
  native `JacComplex` values; and results can differ from CPython's in the
  last one or two bits (the C build's optimizer reorders the same formulas).
  The complex operators themselves (`+ - * / **`, including mixed
  `complex`/real operands) are lowered by the compiler after CPython 3.14's
  `complexobject.c`: C99 Annex G mixed-mode rules (signed zeros and
  infinities survive `1.0 - z`, `z * 2.0`, ...), infinity recovery in `*`
  and `/`, `ZeroDivisionError("division by zero")`, and `_Py_c_pow` /
  `c_powi` with `OverflowError("complex exponentiation")`. The libm wrappers
  link against host libm on native and against the vendored musl bitcode on
  wasm.

- **`time.jac`** (Mechanism F surface) + **`_time_common.jac`** (shared
  `clock_gettime` / `clock_settime` FFI and timespec loads) +
  **`_time_native.linux.jac`** / **`_time_native.darwin.jac`** (per-OS clock
  ids and the sleep floor: `clock_nanosleep` on Linux, `nanosleep` on Darwin) -- the clock half of CPython's
  `time` module, replacing the former Mechanism-A intercept: `time`,
  `time_ns`, `monotonic`, `monotonic_ns`, `perf_counter`, `perf_counter_ns`,
  `process_time`, `process_time_ns`, `thread_time`, `thread_time_ns`,
  `clock_gettime_ns`, `clock_settime_ns`, `sleep`, and the clock-id constants
  `CLOCK_REALTIME` / `CLOCK_MONOTONIC` / `CLOCK_MONOTONIC_RAW` /
  `CLOCK_PROCESS_CPUTIME_ID` / `CLOCK_THREAD_CPUTIME_ID` (per-OS values via
  the floor). `sleep` parks on an absolute `clock_nanosleep(CLOCK_MONOTONIC,
  TIMER_ABSTIME)` deadline the way CPython's `pysleep` does (a relative
  `nanosleep` remainder loop on Darwin), retries on `EINTR`, and matches
  CPython's error behavior: `ValueError("sleep length must be
  non-negative")` on negative input, `ValueError` on NaN, and
  `OverflowError("timestamp out of range for platform time_t")` on inputs
  (including infinities) whose nanoseconds do not fit an i64. Clock
  failures route through `_errno_native.raise_errno`, so they carry
  CPython's `[Errno N]` message AND the mapped `OSError` subclass
  (`PermissionError` for `EPERM`/`EACCES`, ...).
  SCOPE/divergences: the calendar/`struct_time` family (`localtime`,
  `gmtime`, `mktime`, `ctime`, `asctime`, `strftime`, `strptime`, `tzset`,
  `get_clock_info`, `struct_time`, `thread_time` attributes like `tzname`)
  is out of scope and fails loudly; the float-seconds `clock_gettime`,
  `clock_getres`, and `clock_settime` are absent because their bare names
  collide with the floor's C externs in the shared native symbol table --
  use `clock_gettime_ns` / `clock_settime_ns`; `perf_counter` is
  `CLOCK_MONOTONIC`, matching CPython on POSIX; `sleep` takes float
  seconds. Each floor call packs the `timespec` into a 16-byte buffer it
  allocates for itself, so the module is safe to call from any thread
  (the native backend spawns real ones). Native-host only.
- **`sqlite3.jac`** (Mechanism F surface) + **`_sqlite3_native.jac`** (FFI
  floor over the system `libsqlite3`, 3.53.x) -- the DB-API 2.0 core of
  CPython 3.14 `sqlite3`: `connect()` (with the full CPython kwarg set --
  `database`/`timeout`/`detect_types`/`isolation_level`/`check_same_thread`/
  `factory`/`cached_statements`/`uri`/`autocommit`; `timeout`, `uri`,
  `isolation_level` and `autocommit` are honored, the rest are accepted for
  signature parity), `Connection` (`cursor`/`execute`/`executemany`/
  `executescript`/`commit`/`rollback`/`close`/`in_transaction`/
  `total_changes`/context manager), `Cursor` (`execute`/`executemany`/
  `executescript`/`fetchone`/`fetchmany`/`fetchall`/`description`/`rowcount`/
  `lastrowid`/`arraysize`/`connection`/`close`/iteration), `complete_statement`,
  `Binary`, `apilevel`/`paramstyle`/`threadsafety`/`sqlite_version`/
  `sqlite_version_info`, the `PARSE_*`/`LEGACY_TRANSACTION_CONTROL`/
  `SQLITE_*` constants, and the full CPython exception hierarchy (`Error` ->
  `InterfaceError`/`DatabaseError` -> `InternalError`/`OperationalError`/
  `ProgrammingError`/`IntegrityError`/`DataError`/`NotSupportedError`).
  Parameter binding covers positional `?`, numbered `?N`, named `:name`,
  `@name`, and `$name` (dict params), plus `NULL`/`bool`/`int`/`float`/`str`/
  `bytes`-blob values; params accept list, tuple, or dict; transaction
  semantics follow CPython's legacy mode (DML opens an implicit transaction,
  DDL does not; `executescript` commits first), plus the 3.12+ `autocommit`
  kwarg (`True` suppresses implicit BEGIN, `False` opens one before every
  statement, `LEGACY_TRANSACTION_CONTROL` keeps legacy mode).
  `isolation_level` is validated case-insensitively against
  `''`/`DEFERRED`/`IMMEDIATE`/`EXCLUSIVE`. A per-connection prepared
  statement pool (mirrors CPython's `cached_statements=128` LRU as plain
  FIFO-cap eviction) survives `execute`/`fetch` cycles; `reset` +
  `clear_bindings` re-arms pooled statements. The one-statement tail check
  inspects the raw `pzTail` bytes for non-whitespace via aligned
  `__mem_load_i64` reads (never prepares the tail, matching CPython's
  `*tail <= ' '` whitespace test). `Cursor.setinputsizes`/`setoutputsize`
  exist as no-ops. Error parity is class AND `sqlite3_errmsg` text,
  probed against CPython 3.14. DIVERGENCES: rows and `description` entries
  materialize as `list`, not `tuple` (the native boundary has no tuple
  boxing); `Binary()` returns `bytes`, not `memoryview`; `database` accepts
  `str`/`bytes` but not `os.PathLike`; `check_same_thread`, `factory`, and
  `detect_types` are accepted but inert; post-`connect()` assignment of an
  invalid `isolation_level`/`autocommit` is validated lazily at the next
  implicit `BEGIN` rather than at assignment (plain `has` fields have no
  setter hook); exceptions carry no `sqlite_errorcode`/`sqlite_errorname`
  attributes; CPython 3.12+ mixed-parameter-style `DeprecationWarning`s are
  not emitted (no warnings module natively); invalid-UTF-8 TEXT columns
  return the decode result of the bytes rather than falling back to
  `bytes`; `row_factory`/`text_factory`/`create_function`/
  `create_aggregate`/`create_collation`/`set_authorizer`/
  `set_progress_handler`/`set_trace_callback`/`interrupt`/`blobopen`/
  `backup`/`serialize`/`deserialize`/`iterdump`/`getlimit`/`setlimit`/
  `getconfig`/`setconfig`/`enable_load_extension`/`register_adapter`/
  `register_converter`/`Row`/`enable_shared_cache` are out of scope.
  Native-host only. Pinned sv<->na congruent by `prim_sqlite3.jac`. NOTE:
  the floor in `_socket_native.jac` binds `__connect` (glibc weak alias)
  instead of `connect` -- the image-wide clib-extern bare-name set would
  otherwise skip this module's `def:pub connect` body (SIGSEGV at
  JIT-execute).

The syscall-backed `os` / `os.path` entry points (`makedirs`, `realpath`,
`mkdir`, `exists`, `getmtime`, `normcase`, ...) are Mechanism-A/H compiler
intercepts, reached via the flat `import os`, not bundled here (see
`compiler/backends/native/na_ir_gen/os.impl.jac`). `os.sep` and its
sibling module attributes (`extsep`, `pardir`, `curdir`, `pathsep`, `linesep`,
`devnull`) resolve the same way; `os.altsep` is `None` on POSIX and is not
provided. Note that `getmtime` / `getsize` answer `-1` for a path that cannot
be stat'd, where CPython raises `OSError` -- the established native behavior
for this family.

The **pure-string** members are the bundled `os/path.jac` above and are
reached by importing them (`import from os.path { normpath, relpath }`).
`abspath`, `splitext`, `relpath` and `normpath` are *only* reachable that way:
they are not compiler intercepts, because each needs `normpath`'s component
stack (or, for `splitext`, a tuple return), which is the sort of work
Mechanism B exists to avoid writing twice. Reaching for one through the flat
`import os` fails loudly naming the member rather than answering wrong.

## Adding a module

1. Drop `<name>.jac` (or `<pkg>/<name>.jac` for a dotted import) here,
   exporting its API with `def:pub`. If a module needs platform-specific
   code, add a `<name>.<os>.jac` variant (e.g. `_dirent_native.darwin.jac`);
   it wins over the plain file on that OS.
2. Use only the native-supported subset; prefer typed containers
   (`list[str]`, `dict[str, any]`). A bare `list = []` defaults to `i64`
   elements. An empty `list[any] = []` then grown with `.append(x)` lowers and
   boxes correctly, but a `list[any]` *literal* with scalar elements
   (`[1, 2, 3]`) does not yet box them -- build `any`-lists via `.append` (or
   `json.loads`). `dict[str, any]` literals box their values fine. Unbox a
   boxed scalar before operating on it (`i: int = some_any; str(i)`), and check
   container/None branches with `isinstance` -- `x is None` does not lower to a
   branch condition on the native pathway.
3. Add a tri-backend equivalence fixture
   (`jac/jaclang/compiler/tests/fixtures/prim_<name>.jac`) and register it in
   `test_prim_equivalence.jac` with `require=["na"]` so sv/na congruence is
   enforced, not assumed. Keep the `na { }` block self-contained (a
   module-level helper called from native code lowers to an unregistered
   interop stub) and split a large case body across several small na helpers
   mutating one result dict -- one giant function is beyond what the na
   backend JITs reliably today.

## Mechanism / portability

- **B (here)**: pure-Jac on primitives; portable to every native target
  (ELF/Mach-O/PE/WASM). Preferred. Example: `os/path.jac`.
- **A**: compiler intrinsics over libm/libc/syscalls (`os`, `random`,
  `struct`); native-host only. (`math` moved to Mechanism B, above, over the
  `_math_native` libm FFI floor; `time` is a bundled Mechanism-F surface over
  `_time_native`, below.)
- **F**: thin FFI wrappers over a system C library; native-host only. Examples:
  `_ssl_native.jac` -- the floor the verifying TLS client `ssl` is built on,
  over OpenSSL `libssl`/`libcrypto` (issue #6978 Phase 1); `_socket_native.jac`
  over libc BSD sockets; `_hashlib_native.jac` over the bundled `libcrypto`.
  An F module declares its C entry points with `import from <lib> { def ...; }`.
  `urllib/request.jac` (`urlopen`) is a pure-Jac surface over the `socket` +
  `ssl` floors -- it links no foreign C beyond libc/libssl/libcrypto (no
  libcurl) -- pinned sv<->na congruent by `test_urllib_equivalence.jac` against a
  loopback HTTP server.

Functions that need a syscall (`os.path.realpath`, `exists`, ...) stay as
Mechanism-A intercepts, not here.

## Memory profile (`[memory]` in jac.toml)

Native code runs under a refcounted managed heap; the profile selects the
reclamation strategy:

- `managed` (default): refcounting + a cycle tracker. The tracker books every
  managed allocation -- on allocation-heavy workloads (parsing, slicing,
  object churn) it costs 40-60% of runtime (measured: `urlparse` -61%,
  `robotparser.can_fetch` -50%, `ipaddress.ip_address` -37% under `rc`).
- `rc`: plain refcounting, no cycle tracker. Drop-in, no code changes; fastest
  option when reference cycles are impossible or tolerable.
- `nogc`: ownership-enforced -- `own`/`borrow` annotations on heap-typed
  contract positions replace refcounting entirely. Largest win in principle,
  but requires annotating every public signature in the enforced module
  (`[memory] enforce = [...]` gates it per-module); these modules are not yet
  annotated.

## Mechanism F: FFI floor + pure-Jac surface (`zlib`)

`zlib` is the first Mechanism-F module (#6940 Phase 2): the DEFLATE engine is
never reimplemented; it is the system `libz`, reached through a thin FFI floor,
exactly as CPython's `zlib` wraps the same library. The split is deliberate:

- `_zlib_native.jac`: the **FFI floor**. An `import from z { def ... }` block
  binds `libz` by logical name (`z` → `libz.so` / `libz.dylib` / `z.dll`) and
  re-exports each entry behind a `z_`-prefixed wrapper.
- `zlib.jac`: the **pure-Jac surface**: the Python-shaped API
  (`compress` / `decompress` / `crc32` / `adler32`, CPython argument orders and
  defaults), layered on the floor.

Two conventions make foreign byte I/O work:

- A **`bytes` parameter on a foreign signature** lowers to a raw `i8*` to the
  element data (the C buffer-protocol convention), not the internal jacbytes
  `{ i64 len, [n x i8] }` struct pointer; the element count travels through a
  separate explicit length parameter.
- A clib extern is declared into the **shared native symbol table under its C
  symbol name**, so a libz symbol that collides with a public surface name (e.g.
  `crc32`) would shadow it. Bind the non-colliding variant instead; the floor
  uses `crc32_z` / `adler32_z`.

`decompress` does not use the one-shot `uncompress`: a zlib stream carries no
output-size field, so a buffer-too-small retry would re-inflate the whole
input. Instead `zlib.jac`, `gzip.jac`, and `zipfile.jac` call one shared
driver, `z_inflate_all(src, src_off, src_len, window_bits, cap, ceiling)`,
which owns the `z_stream` lifecycle end to end: it pokes `next_in`/`avail_in`
and `next_out`/`avail_out` into a `b"\x00" * 112` z_stream image through the
`__mem_store_i32/i64` intrinsics (the LP64 `z_stream` field offsets live in
the floor), streams `inflate` over a `malloc`/`realloc` arena, refeeds
`avail_in` between calls when a source larger than one `uInt` is clamped, and
copies the produced bytes once into the exact-size `bytes` result, returning
the final libz status (plus an `init_ok` flag distinguishing `inflateInit2_`
failure) in a `ZInflateResult`. Surfaces only map `status` to their own error
type. Payload addresses are recovered as `int` with `memchr(buf, buf[0], 1)`,
which always matches at offset 0 (empty input yields 0). Growth doubles the
arena up to a caller-supplied ceiling; every site derives that ceiling from
the floor's `z_inflate_bound(src_len, slack)` -- DEFLATE's ~1032x expansion
bound plus slack (64 MiB for zlib, the default 1 KiB for the gzip per-member
bound and the zipfile declared-size pre-check); empty or truncated input
surfaces as `Z_BUF_ERROR` and raises `ValueError`, matching CPython's
`error -5`.

`bz2` (#6978 Phase 2) follows the same two-file split: `_bz2_native.jac`
wraps the one-shot `BZ2_bzBuffToBuffCompress` / `BZ2_bzBuffToBuffDecompress`
buffer API (logical name `bz2` -> `libbz2`; the in-process JIT dlopens the
system library, while AOT `nacompile` consumes the bundled `libbz2.a`), and
`bz2.jac` is the Python-shaped `compress(data, compresslevel=9)` /
`decompress(data)` surface. `compress` produces a single bzip2 stream
byte-identical to CPython's (same default `workFactor`); note `libbz2`'s
one-shot API is 32-bit throughout -- `sourceLen` is a by-value C `unsigned int`
(lowered as `u32`, unlike zlib's LP64 8-byte `uLong`) and the in/out `destLen`
is an `unsigned int*` (a 4-byte cell) -- so both directions reject inputs
larger than 4 GiB with a `ValueError` (CPython, which streams internally, has
no such limit). SCOPE and divergences from CPython (3.14):

- One-shot buffer API only: incremental `BZ2Compressor` / `BZ2Decompressor`
  and the file API are out of scope.
- Multi-stream inputs return only the first stream's data (silent partial
  output); CPython concatenates every stream.
- Corrupt input raises `ValueError` (carrying the libbz2 error code) where
  CPython raises `OSError("Invalid data stream")`; truncated streams raise
  `ValueError` on both. Out-of-range compresslevels raise `ValueError` on both
  (the native surface reports libbz2's `BZ_PARAM_ERROR` rather than CPython's
  bounds message).
- `decompress` grows its output buffer on `BZ_OUTBUFF_FULL` up to a ceiling of
  `sourceLen * 1024 + 64 MiB` (clamped to 4 GiB); a valid stream that expands
  past that ceiling raises a distinct `ValueError` ("decompressed output
  exceeds the one-shot API limit") where CPython, which streams, would succeed.

Mechanism-F modules are native-host only: a wasm target gets a clean link error
rather than silent breakage.

[#6404]: https://github.com/jaseci-labs/jaseci/issues/6404
[#6940]: https://github.com/jaseci-labs/jaseci/issues/6940

## ZIP archives (`zipfile`)

`zipfile.jac` adds a read-only, path-based `ZipFile(file, mode="r")` for ZIP32
archives, including PK3 files. Its public surface is `namelist`, `infolist`,
`getinfo(name)`, `read(name)`, `close`, and the context-manager protocol.
`ZipInfo` exposes `filename`, `compress_type`, `flag_bits`, `CRC`,
`compress_size`, `file_size`, `header_offset`, `extra`, `comment`, and `is_dir`.
The archive's `comment` is also available. Duplicate names remain in listing
order; name lookup selects the last entry, matching CPython.

The parser follows the [PKWARE ZIP specification](https://pkware.cachefly.net/webdocs/casestudies/APPNOTE.TXT).
It accepts stored and DEFLATE entries, data descriptors, archive comments,
prepended data, UTF-8 names, and CP437 names. It checks central-directory and
local-header bounds, overlapping entries, header agreement, decompressed
length, and CRC-32. Malformed archives raise `BadZipFile`; missing names raise
`KeyError`; reading a closed archive raises `ValueError`. Invalid UTF-8 names
raise `BadZipFile` (CPython raises `UnicodeDecodeError`).

The DEFLATE decoder drives the shared `z_inflate_all` streaming inflater
(`windowBits = -15`, since ZIP stores the raw DEFLATE body). Output is bounded
by the declared member size plus one byte of headroom; a member is valid only
when inflate reaches `Z_STREAM_END` having produced exactly the declared size
and consumed exactly the declared `compress_size` -- trailing bytes inside the
compressed field are rejected. Integrity comes from the central-directory
CRC-32 check (verified separately against the decoded bytes), so no
verification re-decode is needed. The declared size is also pre-checked
against `z_inflate_bound` (DEFLATE's ~1032x expansion bound).

Scope: archives are loaded into memory, and `read` returns a complete member.
ZIP64, encryption, other compression methods, writing, streaming member
handles, extraction, file-like constructor arguments, `Path` arguments, and
`read(ZipInfo)` are not implemented. Unsupported archive features raise
explicit errors rather than returning partial data. As with the bundled zlib
floor, this requires a native host with libz; it is not a WASM implementation.

Native context-manager lowering also runs `__exit__` for `return`, `break`,
`continue`, and propagated exceptions, closing resources acquired by this API.
It retains the native pathway's existing null exception-argument convention;
Python exception type/value/traceback objects are not materialized for
`__exit__`. A truthy return from `__exit__` suppresses the pending exception.
