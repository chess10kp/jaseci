# Product-path facade for the csv PYTHON layer (CPython 3.14 ``Lib/csv.py``).
# ``_csvmodule.jac`` carries the C-accelerator truth (Modules/_csv.c wave 17);
# this module lifts everything csv.py itself owns on top of it: the Dialect
# carrier hierarchy, the excel / excel-tab / unix registrations, the
# DictReader/DictWriter views and the Sniffer format guesser.
#
# REPRESENTATION CHOICE (divergence ledger candidate):
# - csv.Error identity stays bridge-table name matching ("csv.Error" is
#   registered against Exception in _csvmodule.jac at import). This module
#   raises through the registry convention instead of exporting a class
#   object; ``class Foo(csv.Error)`` has no surface to subclass yet.
# - Jac objs have no constructor hook, so Lib/csv.py's Dialect.__init__
#   auto-validation is exposed as ``Dialect.validate()``. Validation also
#   runs at every facade entry point (reader/writer/register_dialect),
#   which is where each registration path meets the checks anyway.
# - DictReader/DictWriter are factory functions over private carriers
#   (_DictReader/_DictWriter); construction-time argument handling lives in
#   the factory because objs take only has-field kwargs.
# - Sniffer.sniff returns a configured Dialect instance rather than a fresh
#   locally-declared subclass; the attribute surface is identical.
# - ``__class_getitem__ = classmethod(types.GenericAlias)`` is omitted.
# - ``re``/``io`` delegate to the host stdlib -- the same floor delegation
#   policy as codecs.jac (`import _codecs`) and bz2.jac (`import _bz2`).

import re as _re;
import io as _host_io;

import from _csvmodule {
    QUOTE_MINIMAL,
    QUOTE_ALL,
    QUOTE_NONNUMERIC,
    QUOTE_NONE,
    QUOTE_STRINGS,
    QUOTE_NOTNULL,
    reader,
    writer,
    register_dialect,
    unregister_dialect,
    get_dialect,
    list_dialects,
    field_size_limit,
    _build_dialect,
    _UNSET,
}


# ---------------------------------------------------------------------------
# Errors
#
# Lib/csv.py re-raises TypeError from _csv.Dialect(self) as Error(str(e));
# ValueError (bad char values) propagates unchanged, byte-exact with what
# the 3.14 oracle pins expect.

def _error(msg: str) {
    # Identity is bridge-table name matching ("csv.Error"), declared in
    # _csvmodule.jac at import.
    raise Exception(msg);
}


# max(d, key=d.get): the first key holding the maximum count.
def _mode_key(counts: dict) -> any {
    keys = list(counts.keys());
    best = keys[0];
    for k in keys {
        if counts[k] > counts[best] {
            best = k;
        }
    }
    return best;
}


def _validate_dialect(src: any) {
    # Dialect._validate(): run the C-side DIASET validation over the
    # carrier's attributes; only TypeError converts to Error.
    try {
        _build_dialect(src, _UNSET, _UNSET, _UNSET, _UNSET, _UNSET, _UNSET, _UNSET, _UNSET);
        src._valid = True;
    } except TypeError as e {
        raise Exception(str(e));
    }
}


# ---------------------------------------------------------------------------
# Dialect carriers (Lib/csv.py class hierarchy, placeholder defaults)

obj Dialect {
    has delimiter: any = None;
    has doublequote: any = None;
    has escapechar: any = None;
    has lineterminator: any = None;
    has quotechar: any = None;
    has quoting: any = None;
    has skipinitialspace: any = None;
    has strict: any = None;
    has _name: str = "";
    has _valid: bool = False;

    def validate {
        _validate_dialect(self);
    }
}

obj excel(Dialect) {
    has delimiter: any = ",";
    has doublequote: any = True;
    has quotechar: any = "\"";
    has skipinitialspace: any = False;
    has lineterminator: any = "\r\n";
    has quoting: any = QUOTE_MINIMAL;
}

obj excel_tab(excel) {
    has delimiter: any = "\t";
}

obj unix_dialect(Dialect) {
    has delimiter: any = ",";
    has doublequote: any = True;
    has quotechar: any = "\"";
    has skipinitialspace: any = False;
    has lineterminator: any = "\n";
    has quoting: any = QUOTE_ALL;
}


with entry {
    register_dialect("excel", excel);
    register_dialect("excel-tab", excel_tab);
    register_dialect("unix", unix_dialect);
}


# ---------------------------------------------------------------------------
# Dict views (Lib/csv.py DictReader / DictWriter)

obj _DictReader {
    has fieldnames: any = None;
    has restkey: any = None;
    has restval: any = None;
    has reader: any = None;
    has dialect: any = None;
    has line_num: int = 0;

    def __iter__ -> any {
        return self;
    }

    # Lazy pull arm of Lib/csv.py's fieldnames property.
    def _pull_fieldnames -> any {
        if self.fieldnames is None {
            got: any = None;
            try {
                got = self.reader.__next__();
            } except StopIteration {
                got = None;
            }
            if got is not None {
                self.fieldnames = got;
            }
        }
        self.line_num = self.reader.line_num;
        return self.fieldnames;
    }

    def __next__ -> any {
        if self.line_num == 0 {
            # Used only for its side effect.
            self._pull_fieldnames();
        }
        row = self.reader.__next__();
        self.line_num = self.reader.line_num;

        # Unlike the basic reader we skip blank rows: they would land as
        # dict entries full of None values.
        while row == [] {
            row = self.reader.__next__();
        }
        d = dict(zip(self.fieldnames, row));
        lf = len(self.fieldnames);
        lr = len(row);
        if lf < lr {
            d[self.restkey] = row[lf:];
        } elif lf > lr {
            for key in self.fieldnames[lr:] {
                d[key] = self.restval;
            }
        }
        return d;
    }
}

def DictReader(f: any, fieldnames: any = None, restkey: any = None,
               restval: any = None, dialect: any = "excel",
               *args: list, **kwds: dict) -> _DictReader {
    dr = _DictReader();
    if fieldnames is not None and iter(fieldnames) is fieldnames {
        fieldnames = list(fieldnames);
    }
    dr.fieldnames = fieldnames;
    dr.restkey = restkey;
    dr.restval = restval;
    dr.reader = reader(f, dialect, *args, **kwds);
    dr.dialect = dialect;
    dr.line_num = 0;
    return dr;
}

obj _DictWriter {
    has fieldnames: any = None;
    has restval: any = "";
    has extrasaction: str = "";
    has writer: any = None;

    def writeheader -> any {
        header = dict(zip(self.fieldnames, self.fieldnames));
        return self.writerow(header);
    }

    def _dict_to_list(rowdict: any) -> list {
        if self.extrasaction == "raise" {
            wrong_fields = rowdict.keys() - self.fieldnames;
            if wrong_fields {
                names = [repr(x) for x in wrong_fields];
                raise ValueError(
                    "dict contains fields not in fieldnames: "
                    + ", ".join(names));
            }
        }
        return [rowdict.get(key, self.restval) for key in self.fieldnames];
    }

    def writerow(rowdict: any) -> any {
        return self.writer.writerow(self._dict_to_list(rowdict));
    }

    def writerows(rowdicts: any) -> any {
        rows: list = [];
        for rowdict in rowdicts {
            rows.append(self._dict_to_list(rowdict));
        }
        return self.writer.writerows(rows);
    }
}

def DictWriter(f: any, fieldnames: any, restval: any = "",
               extrasaction: any = "raise", dialect: any = "excel",
               *args: list, **kwds: dict) -> _DictWriter {
    dw = _DictWriter();
    if fieldnames is not None and iter(fieldnames) is fieldnames {
        fieldnames = list(fieldnames);
    }
    dw.fieldnames = fieldnames;
    dw.restval = restval;
    extrasaction = extrasaction.lower();
    if extrasaction != "raise" and extrasaction != "ignore" {
        raise ValueError(
            "extrasaction (" + extrasaction + ") must be 'raise' or 'ignore'");
    }
    dw.extrasaction = extrasaction;
    dw.writer = writer(f, dialect, *args, **kwds);
    return dw;
}


# ---------------------------------------------------------------------------
# Sniffer (Lib/csv.py Sniffer)

obj Sniffer {
    # In case there is more than one possible delimiter.
    has preferred: list = [",", "\t", ";", " ", ":"];

    def sniff(sample: str, delimiters: any = None) -> any {
        guessed = self._guess_quote_and_delimiter(sample, delimiters);
        quotechar = guessed[0];
        doublequote = guessed[1];
        delimiter = guessed[2];
        skipinitialspace = guessed[3];
        if not delimiter {
            guessed = self._guess_delimiter(sample, delimiters);
            delimiter = guessed[0];
            skipinitialspace = guessed[1];
        }

        if not delimiter {
            _error("Could not determine delimiter");
        }

        # Lib/csv.py declares a local Dialect subclass here; the carrier
        # instance presents the identical attribute surface.
        dia = Dialect();
        dia._name = "sniffed";
        dia.lineterminator = "\r\n";
        dia.quoting = QUOTE_MINIMAL;
        dia.doublequote = doublequote;
        dia.delimiter = delimiter;
        # _csv.reader won't accept a quotechar of ''.
        dia.quotechar = quotechar or "\"";
        dia.skipinitialspace = skipinitialspace;
        return dia;
    }

    def _guess_quote_and_delimiter(data: str, delimiters: any) -> tuple {
        # Looks for text enclosed between two identical quotes preceded and
        # followed by the same character (the probable delimiter), e.g.
        # ,'some text',. Most wins; no quotechar means no delimiter here.
        patterns: list[str] = [
            r'(?P<delim>[^\w\n"\'])(?P<space> ?)(?P<quote>["\']).*?(?P=quote)(?P=delim)',
            r'(?:^|\n)(?P<quote>["\']).*?(?P=quote)(?P<delim>[^\w\n"\'])(?P<space> ?)',
            r'(?P<delim>[^\w\n"\'])(?P<space> ?)(?P<quote>["\']).*?(?P=quote)(?:$|\n)',
            r'(?:^|\n)(?P<quote>["\']).*?(?P=quote)(?:$|\n)',
        ];
        matches: list = [];
        regexp: any = None;
        for restr in patterns {
            regexp = _re.compile(restr, _re.DOTALL | _re.MULTILINE);
            matches = regexp.findall(data);
            if matches {
                break;
            }
        }

        if not matches {
            # (quotechar, doublequote, delimiter, skipinitialspace)
            return ("", False, None, 0);
        }
        quotes: dict = {};
        delims: dict = {};
        spaces = 0;
        groupindex = regexp.groupindex;
        for m in matches {
            n = groupindex["quote"] - 1;
            key = m[n];
            if key {
                quotes[key] = quotes.get(key, 0) + 1;
            }
            try {
                n = groupindex["delim"] - 1;
                key = m[n];
            } except KeyError {
                continue;
            }
            if key and (delimiters is None or key in delimiters) {
                delims[key] = delims.get(key, 0) + 1;
            }
            try {
                n = groupindex["space"] - 1;
            } except KeyError {
                continue;
            }
            if m[n] {
                spaces += 1;
            }
        }

        quotechar = _mode_key(quotes);

        if delims {
            delim = _mode_key(delims);
            skipinitialspace = delims[delim] == spaces;
            if delim == "\n" {
                # Most likely a file with a single column.
                delim = "";
            }
        } else {
            # There is *no* delimiter: a single column of quoted data.
            delim = "";
            skipinitialspace = False;
        }

        # An extra quote between delimiters means a double-quoted format.
        dq_regexp = _re.compile(
            r"((%(delim)s)|^)\W*%(quote)s[^%(delim)s\n]*%(quote)s"
            r"[^%(delim)s\n]*%(quote)s\W*((%(delim)s)|$)"
                % {"delim": _re.escape(delim), "quote": quotechar},
            _re.MULTILINE);

        if dq_regexp.search(data) {
            doublequote = True;
        } else {
            doublequote = False;
        }

        return (quotechar, doublequote, delim, skipinitialspace);
    }

    def _guess_delimiter(data: str, delimiters: any) -> tuple {
        # The delimiter /should/ occur the same number of times per row;
        # malformed data earns small variations. Build per-character
        # frequency tables chunk-wise, take the mode of the meta-frequency
        # and pick the character that best meets its expected frequency.
        lines: list[str] = [ln for ln in data.split("\n") if ln];

        ascii_chars = [chr(c) for c in range(127)];

        chunkLength = min(10, len(lines));
        iteration = 0;
        charFrequency: dict = {};
        modes: dict = {};
        delims: dict = {};
        start = 0;
        end = chunkLength;
        while start < len(data) {
            iteration += 1;
            for line in lines[start:end] {
                for char in ascii_chars {
                    metaFrequency = charFrequency.get(char, {});
                    # Must count even if frequency is 0.
                    freq = line.count(char);
                    metaFrequency[freq] = metaFrequency.get(freq, 0) + 1;
                    charFrequency[char] = metaFrequency;
                }
            }

            for char in charFrequency.keys() {
                items = list(charFrequency[char].items());
                if len(items) == 1 and items[0][0] == 0 {
                    continue;
                }
                if len(items) > 1 {
                    # Mode of the frequencies minus the sum of all other
                    # frequencies.
                    modes[char] = max(items, key=lambda (x: any) { return x[1]; });
                    items.remove(modes[char]);
                    others = 0;
                    for item in items {
                        others += item[1];
                    }
                    modes[char] = (modes[char][0], modes[char][1] - others);
                } else {
                    modes[char] = items[0];
                }
            }

            modeList = modes.items();
            total = float(min(chunkLength * iteration, len(lines)));
            # (rows of consistent data) / (number of rows) = 100%
            consistency = 1.0;
            # Minimum consistency threshold.
            threshold = 0.9;
            while len(delims) == 0 and consistency >= threshold {
                for kv in modeList {
                    k = kv[0];
                    v = kv[1];
                    if v[0] > 0 and v[1] > 0 {
                        if (
                            (v[1] / total) >= consistency
                            and (delimiters is None or k in delimiters)
                        ) {
                            delims[k] = v;
                        }
                    }
                }
                consistency -= 0.01;
            }

            if len(delims) == 1 {
                delim = list(delims.keys())[0];
                skipinitialspace = (
                    lines[0].count(delim) == lines[0].count(delim + " "));
                return (delim, skipinitialspace);
            }

            # Analyze another chunkLength lines.
            start = end;
            end += chunkLength;
        }

        if not delims {
            return ("", 0);
        }

        # More than one candidate: fall back to the preferred list.
        if len(delims) > 1 {
            for d in self.preferred {
                if d in delims.keys() {
                    skipinitialspace = (
                        lines[0].count(d) == lines[0].count(d + " "));
                    return (d, skipinitialspace);
                }
            }
        }

        # Nothing indicates a preference; pick the dominating character.
        pairs: list = [];
        for kv in delims.items() {
            pairs.append((kv[1], kv[0]));
        }
        pairs.sort();
        delim = pairs[-1][1];

        skipinitialspace = (
            lines[0].count(delim) == lines[0].count(delim + " "));
        return (delim, skipinitialspace);
    }

    def has_header(sample: str) -> bool {
        # Type-probe every column past the first row; single-typed columns
        # whose first-row member differs vote the first row a header.
        rdr = reader(_host_io.StringIO(sample), self.sniff(sample));

        header: list = rdr.__next__() as list;

        columns = len(header);
        columnTypes: dict = {};
        for i in range(columns) {
            columnTypes[i] = None;
        }

        checked = 0;
        for rowobj in rdr {
            # Arbitrary sanity cap on rows checked.
            if checked > 20 {
                break;
            }
            checked += 1;
            row: list = rowobj as list;

            if len(row) != columns {
                continue;
            }

            for col in list(columnTypes.keys()) {
                cell: any = row[col];
                thisType: any = complex;
                try {
                    thisType = complex(cell);
                } except ValueError {
                    thisType = len(cell);
                } except OverflowError {
                    thisType = len(cell);
                }

                if thisType != columnTypes[col] {
                    if columnTypes[col] is None {
                        columnTypes[col] = thisType;
                    } else {
                        # Inconsistent typing: drop the column.
                        del columnTypes[col];
                    }
                }
            }
        }

        hasHeader = 0;
        for kv in columnTypes.items() {
            col = kv[0];
            colType: any = kv[1];
            if isinstance(colType, int) {
                head_cell: any = header[col];
                if len(head_cell) != colType {
                    hasHeader += 1;
                } else {
                    hasHeader -= 1;
                }
            } else {
                target: any = header[col];
                voted = False;
                try {
                    colType(target);
                } except ValueError {
                    hasHeader += 1;
                    voted = True;
                } except TypeError {
                    hasHeader += 1;
                    voted = True;
                }
                if not voted {
                    hasHeader -= 1;
                }
            }
        }

        return hasHeader > 0;
    }
}
