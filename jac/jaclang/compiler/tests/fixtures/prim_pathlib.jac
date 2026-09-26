"""Bundled native ``pathlib`` cross-backend equivalence fixture.

The sv entry uses CPython's pathlib; the na entry the bundled
`na_stdlib/pathlib.jac` (normalized POSIX `Path` over the os.path
intrinsics plus an lstat/readlink FFI floor). Both lanes drive the same
throwaway /tmp tree and pin observable facts as ints/strings. `parts` and
`suffixes` are pinned as "|"-joined strings because CPython returns a
tuple and the bundled Path returns a list[str] (documented divergence);
what is pinned is the sequence contents. ES/JS opts out.
"""

import os;
import pathlib;
import shutil;
import from pathlib { Path }


def pathlib_py -> dict[any, any] {
    base = "/tmp/jac_prim_pathlib_fix";
    if os.path.exists(base) {
        shutil.rmtree(base);
    }
    os.makedirs(os.path.join(base, "sub"));
    f = open(os.path.join(base, "a.txt"), "w");
    f.write("hello");
    f.close();
    f = open(os.path.join(base, "sub", "b.log"), "w");
    f.write("x");
    f.close();
    os.symlink("a.txt", os.path.join(base, "lnk"));
    p = Path(base);
    q = Path(os.path.join(base, "a.txt"));
    d = {
        "name": q.name,
        "stem": q.stem,
        "suffix": q.suffix,
        "suffixes": "|".join(Path("a.tar.gz").suffixes),
        "parts": "|".join(Path("/a/b/c").parts),
        "parts_rel": "|".join(Path("a/b").parts),
        "parts_dot": len(Path(".").parts),
        "anchor": Path("/a/b").anchor,
        "root": Path("/a/b").root,
        "drive": Path("/a/b").drive,
        "parent_base": Path("/a/b/c").parent.name,
        "isabs1": p.is_absolute(),
        "isabs2": Path("rel/x").is_absolute(),
        "abs_eq": str(Path("abc").absolute()) == os.path.join(os.getcwd(), "abc"),
        "joinp": str(Path("/a").joinpath("b", "c.txt")),
        "withname": str(Path("/a/b.txt").with_name("c.log")),
        "withsuf": str(Path("/a/b.txt").with_suffix(".log")),
        "match1": Path("/a/b.py").match("*.py"),
        "match2": Path("/a/b.py").match("*.log"),
        "match3": Path("/a/b.py").match("b/*.py"),
        "match4": Path("/a/b.py").match("/a/*.py"),
        "exists": p.exists(),
        "nofile_exists": Path(base + "/nope").exists(),
        "isdir": p.is_dir(),
        "isfile": q.is_file(),
        "isdir_as_file": p.is_file(),
        "link_islink": Path(base + "/lnk").is_symlink(),
        "file_islink": q.is_symlink(),
        "iterdir": "|".join(sorted([x.name for x in p.iterdir()])),
        "resolve": str(p.resolve()) == os.path.realpath(base),
        "txt": q.read_text(),
        "wt_n": q.write_text("roundtrip"),
        "wt_back": q.read_text(),
        "str_div": str(p / "inner"),
        "cwd_eq": str(Path.cwd()) == os.getcwd(),
        "home_eq": str(Path.home()) == os.getenv("HOME"),
        "glob_txt": "|".join(sorted(x.name for x in p.glob("*.txt"))),
        "glob_star": "|".join(sorted(x.name for x in p.glob("*"))),
        "rglob": "|".join(sorted(x.name for x in p.rglob("*.log"))),

    };
    try {
        Path("/a/b.txt").with_name("x/y");
        d["withname_err"] = "NO-RAISE";
    } except ValueError as e {
        d["withname_err"] = "ValueError";
    }
    try {
        Path("/a/b").with_suffix("x");
        d["withsuf_err"] = "NO-RAISE";
    } except ValueError as e {
        d["withsuf_err"] = "ValueError";
    }
    newdir = Path(base + "/newdir");
    newdir.mkdir();
    d["mkdir_ok"] = newdir.is_dir();
    try {
        newdir.mkdir();
        d["mkdir_exists"] = "NO-RAISE";
    } except FileExistsError {
        d["mkdir_exists"] = "FileExistsError";
    }
    newdir.mkdir(exist_ok=True);
    deep = Path(base + "/x/y/z");
    deep.mkdir(parents=True);
    d["parents_ok"] = deep.is_dir();
    victim = Path(base + "/victim.txt");
    victim.write_text("v");
    victim.unlink();
    d["unlink_gone"] = not victim.exists();
    try {
        victim.unlink();
        d["unlink_missing"] = "NO-RAISE";
    } except FileNotFoundError {
        d["unlink_missing"] = "FileNotFoundError";
    }
    victim.unlink(missing_ok=True);
    try {
        p.rmdir();
        d["rmdir_nonempty"] = "NO-RAISE";
    } except OSError {
        d["rmdir_nonempty"] = "OSError";
    }
    empty = Path(base + "/sub/empty");
    empty.mkdir();
    empty.rmdir();
    d["rmdir_ok"] = not empty.exists();
    missing = Path(base + "/missing.txt");
    try {
        missing.read_text();
        d["read_missing"] = "NO-RAISE";
    } except FileNotFoundError {
        d["read_missing"] = "FileNotFoundError";
    }
    shutil.rmtree(base);
    return d;
}


def pathlib_cl -> dict[any, any] {
    return {};
}


def pathlib_na -> dict[str, any] {
    base = "/tmp/jac_prim_pathlib_fix";
    if os.path.exists(base) {
        shutil.rmtree(base);
    }
    os.makedirs(os.path.join(base, "sub"));
    f = open(os.path.join(base, "a.txt"), "w");
    f.write("hello");
    f.close();
    f = open(os.path.join(base, "sub", "b.log"), "w");
    f.write("x");
    f.close();
    os.system("ln -s a.txt " + base + "/lnk");
    p = Path(base);
    q = Path(os.path.join(base, "a.txt"));
    d: dict[str, any] = {};
    d["name"] = q.name;
    d["stem"] = q.stem;
    d["suffix"] = q.suffix;
    d["suffixes"] = "|".join(Path("a.tar.gz").suffixes);
    d["parts"] = "|".join(Path("/a/b/c").parts);
    d["parts_rel"] = "|".join(Path("a/b").parts);
    d["parts_dot"] = len(Path(".").parts);
    d["anchor"] = Path("/a/b").anchor;
    d["root"] = Path("/a/b").root;
    d["drive"] = Path("/a/b").drive;
    d["parent_base"] = Path("/a/b/c").parent.name;
    d["isabs1"] = p.is_absolute();
    d["isabs2"] = Path("rel/x").is_absolute();
    d["abs_eq"] = str(Path("abc").absolute()) == os.path.join(os.getcwd(), "abc");
    d["joinp"] = str(Path("/a").joinpath("b", "c.txt"));
    d["withname"] = str(Path("/a/b.txt").with_name("c.log"));
    d["withsuf"] = str(Path("/a/b.txt").with_suffix(".log"));
    d["match1"] = Path("/a/b.py").match("*.py");
    d["match2"] = Path("/a/b.py").match("*.log");
    d["match3"] = Path("/a/b.py").match("b/*.py");
    d["match4"] = Path("/a/b.py").match("/a/*.py");
    d["exists"] = p.exists();
    d["nofile_exists"] = Path(base + "/nope").exists();
    d["isdir"] = p.is_dir();
    d["isfile"] = q.is_file();
    d["isdir_as_file"] = p.is_file();
    d["link_islink"] = Path(base + "/lnk").is_symlink();
    d["file_islink"] = q.is_symlink();
    names: list[str] = [];
    for x in p.iterdir() {
        names.append(x.name);
    }
    d["iterdir"] = "|".join(sorted(names));
    d["resolve"] = str(p.resolve()) == os.path.realpath(base);
    d["txt"] = q.read_text();
    d["wt_n"] = q.write_text("roundtrip");
    d["wt_back"] = q.read_text();
    d["str_div"] = str(p / "inner");
    d["cwd_eq"] = str(Path.cwd()) == os.getcwd();
    home_env: (str | None) = os.getenv("HOME");
    if isinstance(home_env, str) {
        d["home_eq"] = str(Path.home()) == home_env;
    } else {
        d["home_eq"] = str(Path.home()).startswith("/");
    }
    d["glob_txt"] = "|".join(sorted(x.name for x in p.glob("*.txt")));
    d["glob_star"] = "|".join(sorted(x.name for x in p.glob("*")));
    d["rglob"] = "|".join(sorted(x.name for x in p.rglob("*.log")));
    try {
        Path("/a/b.txt").with_name("x/y");
        d["withname_err"] = "NO-RAISE";
    } except ValueError as e {
        d["withname_err"] = "ValueError";
    }
    try {
        Path("/a/b").with_suffix("x");
        d["withsuf_err"] = "NO-RAISE";
    } except ValueError as e {
        d["withsuf_err"] = "ValueError";
    }
    newdir = Path(base + "/newdir");
    newdir.mkdir();
    d["mkdir_ok"] = newdir.is_dir();
    try {
        newdir.mkdir();
        d["mkdir_exists"] = "NO-RAISE";
    } except FileExistsError {
        d["mkdir_exists"] = "FileExistsError";
    }
    newdir.mkdir(exist_ok=True);
    deep = Path(base + "/x/y/z");
    deep.mkdir(parents=True);
    d["parents_ok"] = deep.is_dir();
    victim = Path(base + "/victim.txt");
    victim.write_text("v");
    victim.unlink();
    d["unlink_gone"] = not victim.exists();
    try {
        victim.unlink();
        d["unlink_missing"] = "NO-RAISE";
    } except FileNotFoundError {
        d["unlink_missing"] = "FileNotFoundError";
    }
    victim.unlink(missing_ok=True);
    try {
        p.rmdir();
        d["rmdir_nonempty"] = "NO-RAISE";
    } except OSError {
        d["rmdir_nonempty"] = "OSError";
    }
    empty = Path(base + "/sub/empty");
    empty.mkdir();
    empty.rmdir();
    d["rmdir_ok"] = not empty.exists();
    missing = Path(base + "/missing.txt");
    try {
        missing.read_text();
        d["read_missing"] = "NO-RAISE";
    } except FileNotFoundError {
        d["read_missing"] = "FileNotFoundError";
    }
    shutil.rmtree(base);
    return d;
}
