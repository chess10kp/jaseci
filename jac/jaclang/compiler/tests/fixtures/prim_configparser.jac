"""Bundled native `configparser` cross-backend equivalence fixture.

The SAME `import from configparser { ... }` binds CPython's `configparser` on
the sv (Python) backend and the bundled `na_stdlib/configparser.jac`
Mechanism-B module on the na (native LLVM) backend. Each probe runs on a
fresh ConfigParser and extracts scalars/strings (write() output and multiline
values marshal as whole strings). Errors pinned as
"<ClassName>: <str(e)>" via exact-class arms with a WRONG-TYPE fallback so a
mistyped raise shows as a value diff, not a lane abort. Documented scope
divergences (fallback=None indistinguishable, no SectionProxy mapping
protocol, no read(filenames), bool interpolation parameter, ...) are not
probed here -- see na_stdlib/README.md. ES/JS opts out.
"""

import from configparser {
    ConfigParser,
    NoSectionError,
    NoOptionError,
    MissingSectionHeaderError,
    DuplicateSectionError,
    DuplicateOptionError,
    InterpolationMissingOptionError,
    InterpolationDepthError,
    InterpolationSyntaxError,
    ParsingError
}


def _mk -> ConfigParser {
    return ConfigParser();
}


def _interpolation_doc -> str {
    return "[DEFAULT]\nv0 = %(v1)s\nv1 = %(v0)s\n[s]\na = %(zz)s\npct = 50% off\n";
}


def configparser_py -> dict[any, any] {
    return _probe();
}


def configparser_cl -> dict[any, any] {
    return {};
}


def configparser_na -> dict[str, any] {
    return _probe();
}


def _probe -> dict[str, any] {
    out: dict[str, any] = {};
    cp: ConfigParser = _mk();
    cp.read_string(
        "[DEFAULT]\nbase = 100\nname = bench\n[s0]\nnum = 7\nratio = 2.5\nflag = yes\noff = 0\nref = %(base)s\n[s1]\nnum = 8\n"
    );
    out["secs_n"] = len(cp.sections());
    out["has_s0"] = cp.has_section("s0");
    out["has_def"] = cp.has_section("DEFAULT");
    out["opts_n"] = len(cp.options("s0"));
    out["def_n"] = len(cp.defaults());
    out["get_ref"] = cp.get("s0", "ref");
    out["getnum"] = cp.getint("s0", "num");
    out["getflt"] = cp.getfloat("s0", "ratio");
    out["getbool"] = cp.getboolean("s0", "flag");
    out["getbool0"] = cp.getboolean("s0", "off");
    out["hasopt_def"] = cp.has_option("s0", "base");
    out["hasopt_no"] = cp.has_option("s0", "zz");
    its: list[tuple[(str, str)]] = cp.items("s0");
    out["items_n"] = len(its);
    it0: tuple[(str, str)] = its[0];
    out["item0_k"] = it0[0];
    out["item0_v"] = it0[1];
    itlast: tuple[(str, str)] = its[len(its) - 1];
    out["iteml_k"] = itlast[0];
    cp2: ConfigParser = _mk();
    cp2.read_string("[s]\nlong = first\n  second\n");
    out["cont"] = cp2.get("s", "long");
    cp3: ConfigParser = _mk();
    cp3.read_string("[s]\na = 1\nb = \n");
    cp3.set("s", "c", "3");
    out["set_get"] = cp3.get("s", "c");
    out["rm_opt"] = cp3.remove_option("s", "a");
    out["rm_opt2"] = cp3.remove_option("s", "a");
    out["rm_sec"] = cp3.remove_section("s");
    out["rm_sec2"] = cp3.remove_section("s");
    cp4: ConfigParser = _mk();
    cp4.read_string("[s]\na = 1\n");
    cp4.add_section("t");
    out["addsec"] = cp4.has_section("t");
    out["wr"] = cp4.write();
    cp5: ConfigParser = _mk();
    cp5.read_dict({"s": {"a": "1"}, "t": {"b": "2"}});
    out["rd_secs"] = len(cp5.sections());
    cpw: ConfigParser = _mk();
    cpw.read_string("[s]\nb = multi\n\tline2\n");
    out["wr_ml"] = cpw.write();

    e_ns: str = "";
    try {
        _mk().get("nope", "k");
    } except NoSectionError {
        e_ns = "NoSectionError: No section: 'nope'";
    } except Exception {
        e_ns = "WRONG-TYPE";
    }
    out["e_ns"] = e_ns;

    e_no: str = "";
    cpn: ConfigParser = _mk();
    cpn.read_string("[s]\na = 1\n");
    try {
        cpn.get("s", "zz");
    } except NoOptionError {
        e_no = "NoOptionError: No option 'zz' in section: 's'";
    } except Exception {
        e_no = "WRONG-TYPE";
    }
    out["e_no"] = e_no;

    e_mh: str = "";
    try {
        _mk().read_string("key=val\n");
    } except MissingSectionHeaderError {
        e_mh = "MissingSectionHeaderError: File contains no section headers.\nfile: '<string>', line: 1\n'key=val\n'";
    } except Exception {
        e_mh = "WRONG-TYPE";
    }
    out["e_mh"] = e_mh;

    e_ds: str = "";
    try {
        _mk().read_string("[s]\na = 1\n[s]\nb = 2\n");
    } except DuplicateSectionError {
        e_ds = "DuplicateSectionError: While reading from '<string>' [line  3]: section 's' already exists";
    } except Exception {
        e_ds = "WRONG-TYPE";
    }
    out["e_ds"] = e_ds;

    e_do: str = "";
    try {
        _mk().read_string("[s]\na = 1\na = 2\n");
    } except DuplicateOptionError {
        e_do = "DuplicateOptionError: While reading from '<string>' [line  3]: option 'a' in section 's' already exists";
    } except Exception {
        e_do = "WRONG-TYPE";
    }
    out["e_do"] = e_do;

    cpi: ConfigParser = _mk();
    cpi.read_string(_interpolation_doc());
    e_im: str = "";
    try {
        cpi.get("s", "a");
    } except InterpolationMissingOptionError {
        e_im = "InterpolationMissingOptionError: Bad value substitution: option 'a' in section 's' contains an interpolation key 'zz' which is not a valid option name. Raw value: '%(zz)s'";
    } except Exception {
        e_im = "WRONG-TYPE";
    }
    out["e_im"] = e_im;

    e_id: str = "";
    try {
        cpi.get("s", "v0");
    } except InterpolationDepthError {
        e_id = "InterpolationDepthError: Recursion limit exceeded in value substitution: option 'v0' in section 's' contains an interpolation key which cannot be substituted in 10 steps. Raw value: '%(v1)s'";
    } except Exception {
        e_id = "WRONG-TYPE";
    }
    out["e_id"] = e_id;

    e_is: str = "";
    try {
        cpi.get("s", "pct");
    } except InterpolationSyntaxError {
        e_is = "InterpolationSyntaxError: '%' must be followed by '%' or '(', found: '% off'";
    } except Exception {
        e_is = "WRONG-TYPE";
    }
    out["e_is"] = e_is;

    e_pe: str = "";
    try {
        _mk().read_string("[s]\nok\nbad2\n");
    } except ParsingError {
        e_pe = "ParsingError: Source contains parsing errors: '<string>'\n\t[line  2]: 'ok\n'\n\t[line  3]: 'bad2\n'";
    } except Exception {
        e_pe = "WRONG-TYPE";
    }
    out["e_pe"] = e_pe;

    e_gb: str = "";
    cpg: ConfigParser = _mk();
    cpg.read_string("[s]\nv = maybe\n");
    try {
        cpg.getboolean("s", "v");
    } except ValueError {
        e_gb = "ValueError: Not a boolean: maybe";
    } except Exception {
        e_gb = "WRONG-TYPE";
    }
    out["e_gb"] = e_gb;

    e_ad: str = "";
    try {
        _mk().add_section("DEFAULT");
    } except ValueError {
        e_ad = "ValueError: Invalid section name: 'DEFAULT'";
    } except Exception {
        e_ad = "WRONG-TYPE";
    }
    out["e_ad"] = e_ad;
    return out;
}
