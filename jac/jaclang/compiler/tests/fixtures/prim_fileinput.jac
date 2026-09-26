"""Bundled native ``fileinput`` cross-backend equivalence fixture.

The sv entry uses CPython's fileinput; the na entry the bundled
`na_stdlib/fileinput.jac` (FileInput iterating pre-split line buffers
plus the module-level state helpers). Both lanes read the same /tmp
files and pin per-line (lineno, filelineno, filename, isfirstline,
isstdin) tuples flattened to strings. stdin ('-') is not exercised:
the JIT harness has no readable fd 0 data and CPython would consume it
nondeterministically. ES/JS opts out.
"""

import os;
import shutil;
import fileinput;


def _tree_py(base: str) -> list[str] {
    f1 = base + "/one.txt";
    f2 = base + "/two.txt";
    f3 = base + "/three.txt";
    for (p, body) in [(f1, "l1\nl2\n"), (f2, "m1\nm2\nm3\n"), (f3, "")] {
        f = open(p, "w");
        f.write(body);
        f.close();
    }
    return [f1, f2, f3];
}


def fileinput_py -> dict[any, any] {
    base = "/tmp/jac_prim_fileinput_fix";
    if os.path.exists(base) {
        shutil.rmtree(base);
    }
    os.makedirs(base);
    files = _tree_py(base);
    d = {};
    lines: list[str] = [];
    marks: list[str] = [];
    try {
        fileinput.lineno();
        d["pre_err"] = "NO-RAISE";
    } except RuntimeError as e {
        d["pre_err"] = str(e);
    }
    inp = fileinput.input(files);
    d["pre_filename_none"] = inp.filename() is None;
    seen_skip = False;
    for line in inp {
        lines.append(line);
        fn = fileinput.filename();
        marks.append(
            str(fileinput.lineno())
                + ":"
                + str(fileinput.filelineno())
                + ":"
                + (os.path.basename(fn) if fn is not None else "?")
                + ":"
                + ("F" if fileinput.isfirstline() else "-")
                + ("S" if fileinput.isstdin() else "-")
        );
        if fileinput.filelineno() == 1 and not seen_skip {
            seen_skip = True;
            fileinput.nextfile();
        }
    }
    d["lines"] = "|".join(lines);
    d["marks"] = "|".join(marks);
    d["post_filename"] = os.path.basename(fileinput.filename());
    fileinput.close();
    try {
        fileinput.lineno();
        d["post_err"] = "NO-RAISE";
    } except RuntimeError as e {
        d["post_err"] = str(e);
    }
    fi = fileinput.input([files[0]]);
    fi.readline();
    try {
        fileinput.input([files[1]]);
        d["double_input"] = "NO-RAISE";
    } except RuntimeError as e {
        d["double_input"] = str(e);
    }
    fileinput.close();
    rl = fileinput.FileInput(files[1]);
    d["fi_l1"] = rl.readline();
    d["fi_l2"] = rl.readline();
    rl.close();
    try {
        fileinput.FileInput(files[0], mode="w");
        d["bad_mode"] = "NO-RAISE";
    } except ValueError as e {
        d["bad_mode"] = str(e);
    }
    try {
        miss = fileinput.FileInput(base + "/missing.txt");
        miss.readline();
        d["missing"] = "NO-RAISE";
    } except FileNotFoundError {
        d["missing"] = "FileNotFoundError";
    }
    shutil.rmtree(base);
    return d;
}


def fileinput_cl -> dict[any, any] {
    return {};
}


def fileinput_na -> dict[str, any] {
    base = "/tmp/jac_prim_fileinput_fix";
    if os.path.exists(base) {
        shutil.rmtree(base);
    }
    os.makedirs(base);
    f1 = base + "/one.txt";
    f2 = base + "/two.txt";
    f3 = base + "/three.txt";
    f = open(f1, "w");
    f.write("l1\nl2\n");
    f.close();
    f = open(f2, "w");
    f.write("m1\nm2\nm3\n");
    f.close();
    f = open(f3, "w");
    f.write("");
    f.close();
    files: list[str] = [f1, f2, f3];
    d: dict[str, any] = {};
    try {
        fileinput.lineno();
        d["pre_err"] = "NO-RAISE";
    } except RuntimeError as e {
        d["pre_err"] = str(e);
    }
    inp = fileinput.input(files);
    d["pre_filename_none"] = inp.filename() is None;
    lines: list[str] = [];
    marks: list[str] = [];
    seen_skip = False;
    for line in inp {
        lines.append(line);
        fn = fileinput.filename();
        marks.append(
            str(fileinput.lineno())
                + ":"
                + str(fileinput.filelineno())
                + ":"
                + (os.path.basename(fn) if fn is not None else "?")
                + ":"
                + ("F" if fileinput.isfirstline() else "-")
                + ("S" if fileinput.isstdin() else "-")
        );
        if fileinput.filelineno() == 1 and not seen_skip {
            seen_skip = True;
            fileinput.nextfile();
        }
    }
    d["lines"] = "|".join(lines);
    d["marks"] = "|".join(marks);
    fn2 = fileinput.filename();
    d["post_filename"] = os.path.basename(fn2) if fn2 is not None else "?";
    fileinput.close();
    try {
        fileinput.lineno();
        d["post_err"] = "NO-RAISE";
    } except RuntimeError as e {
        d["post_err"] = str(e);
    }
    fi = fileinput.input([files[0]]);
    fi.readline();
    try {
        fileinput.input([files[1]]);
        d["double_input"] = "NO-RAISE";
    } except RuntimeError as e {
        d["double_input"] = str(e);
    }
    fileinput.close();
    rl = fileinput.FileInput(files[1]);
    d["fi_l1"] = rl.readline();
    d["fi_l2"] = rl.readline();
    rl.close();
    try {
        fileinput.FileInput(files[0], mode="w");
        d["bad_mode"] = "NO-RAISE";
    } except ValueError as e {
        d["bad_mode"] = str(e);
    }
    try {
        miss = fileinput.FileInput(base + "/missing.txt");
        miss.readline();
        d["missing"] = "NO-RAISE";
    } except FileNotFoundError {
        d["missing"] = "FileNotFoundError";
    }
    shutil.rmtree(base);
    return d;
}
