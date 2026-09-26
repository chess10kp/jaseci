"""Bundled native ``filecmp`` cross-backend equivalence fixture.

The sv entry uses CPython's filecmp; the na entry the bundled
`na_stdlib/filecmp.jac` (cmp/cmpfiles/dircmp over a stat(2) FFI floor
that digests the (S_IFMT, size, mtime) signature CPython's _sig uses).
Both lanes drive the same /tmp two-directory tree and pin lists as
"|"-joined strings. A hardlink between the trees is used to exercise
the shallow-hit path (identical stat signatures). ES/JS opts out.
"""

import os;
import shutil;
import filecmp;


def _mk_tree_py(base: str) {
    a = base + "/a";
    b = base + "/b";
    os.makedirs(os.path.join(a, "common_dir"));
    os.makedirs(os.path.join(b, "common_dir"));
    os.makedirs(os.path.join(b, "funny"));
    for (path, body) in [
        (a + "/same.txt", "same\n"),
        (b + "/same.txt", "same\n"),
        (a + "/diff.txt", "aaaa"),
        (b + "/diff.txt", "bbbb"),
        (a + "/a_only.txt", "a"),
        (b + "/b_only.txt", "b"),
        (a + "/funny", "file"),
        (a + "/common_dir/inner.txt", "in"),
        (b + "/common_dir/inner.txt", "in")
    ] {
        f = open(path, "w");
        f.write(body);
        f.close();
    }
    os.link(a + "/same.txt", b + "/link.txt");
}


def filecmp_py -> dict[any, any] {
    base = "/tmp/jac_prim_filecmp_fix";
    if os.path.exists(base) {
        shutil.rmtree(base);
    }
    os.makedirs(base);
    _mk_tree_py(base);
    a = base + "/a";
    b = base + "/b";
    d: dict[any, any] = {
        "cmp_same": filecmp.cmp(a + "/same.txt", b + "/same.txt", False),
        "cmp_diff": filecmp.cmp(a + "/diff.txt", b + "/diff.txt", False),
        "cmp_hardlink_shallow": filecmp.cmp(a + "/same.txt", b + "/link.txt", True),
        "cmp_diff_shallow": filecmp.cmp(a + "/diff.txt", b + "/diff.txt", True),
        "cmp_self": filecmp.cmp(a + "/same.txt", a + "/same.txt", True),
        "cmp_dir": filecmp.cmp(a, b, False),

    };
    (same, miss, errs) = filecmp.cmpfiles(
        a, b, ["same.txt", "diff.txt", "link.txt", "a_only.txt", "nope.txt"], False
    );
    d["cmpfiles_same"] = "|".join(same);
    d["cmpfiles_miss"] = "|".join(miss);
    d["cmpfiles_err"] = "|".join(errs);
    dc = filecmp.dircmp(a, b, ignore=[], hide=[]);
    d["left_list"] = "|".join(dc.left_list);
    d["right_list"] = "|".join(dc.right_list);
    d["common"] = "|".join(dc.common);
    d["left_only"] = "|".join(dc.left_only);
    d["right_only"] = "|".join(dc.right_only);
    d["common_dirs"] = "|".join(dc.common_dirs);
    d["common_files"] = "|".join(sorted(dc.common_files));
    d["common_funny"] = "|".join(dc.common_funny);
    d["same_files"] = "|".join(dc.same_files);
    d["diff_files"] = "|".join(dc.diff_files);
    d["funny_files"] = "|".join(dc.funny_files);
    sd = dc.subdirs["common_dir"];
    d["sub_same"] = "|".join(sd.same_files);
    d["sub_diff"] = "|".join(sd.diff_files);
    try {
        filecmp.cmp(a + "/same.txt", a + "/missing.txt", False);
        d["cmp_missing"] = "NO-RAISE";
    } except FileNotFoundError {
        d["cmp_missing"] = "FileNotFoundError";
    }
    filecmp.clear_cache();
    d["after_clear"] = filecmp.cmp(a + "/same.txt", b + "/same.txt", False);
    shutil.rmtree(base);
    return d;
}


def filecmp_cl -> dict[any, any] {
    return {};
}


def _mk_tree_na(base: str) {
    a = base + "/a";
    b = base + "/b";
    os.makedirs(os.path.join(a, "common_dir"));
    os.makedirs(os.path.join(b, "common_dir"));
    os.makedirs(os.path.join(b, "funny"));
    paths: list[str] = [
        a + "/common_dir/inner.txt",
        b + "/common_dir/inner.txt",
        a + "/same.txt",
        b + "/same.txt",
        a + "/diff.txt",
        b + "/diff.txt",
        a + "/a_only.txt",
        b + "/b_only.txt",
        a + "/funny"
    ];
    bodies: list[str] = [
        "in",
        "in",
        "same\n",
        "same\n",
        "aaaa",
        "bbbb",
        "a",
        "b",
        "file"
    ];
    i: int = 0;
    while i < len(paths) {
        f = open(paths[i], "w");
        f.write(bodies[i]);
        f.close();
        i += 1;
    }
    os.system("ln " + a + "/same.txt " + b + "/link.txt");
}


def filecmp_na -> dict[str, any] {
    base = "/tmp/jac_prim_filecmp_fix";
    if os.path.exists(base) {
        shutil.rmtree(base);
    }
    os.makedirs(base);
    _mk_tree_na(base);
    a = base + "/a";
    b = base + "/b";
    d: dict[str, any] = {};
    d["cmp_same"] = filecmp.cmp(a + "/same.txt", b + "/same.txt", False);
    d["cmp_diff"] = filecmp.cmp(a + "/diff.txt", b + "/diff.txt", False);
    d["cmp_hardlink_shallow"] = filecmp.cmp(a + "/same.txt", b + "/link.txt", True);
    d["cmp_diff_shallow"] = filecmp.cmp(a + "/diff.txt", b + "/diff.txt", True);
    d["cmp_self"] = filecmp.cmp(a + "/same.txt", a + "/same.txt", True);
    d["cmp_dir"] = filecmp.cmp(a, b, False);
    (same, miss, errs) = filecmp.cmpfiles(
        a, b, ["same.txt", "diff.txt", "link.txt", "a_only.txt", "nope.txt"], False
    );
    d["cmpfiles_same"] = "|".join(same);
    d["cmpfiles_miss"] = "|".join(miss);
    d["cmpfiles_err"] = "|".join(errs);
    dc = filecmp.dircmp(a, b, ignore=[], hide=[]);
    d["left_list"] = "|".join(dc.left_list);
    d["right_list"] = "|".join(dc.right_list);
    d["common"] = "|".join(dc.common);
    d["left_only"] = "|".join(dc.left_only);
    d["right_only"] = "|".join(dc.right_only);
    d["common_dirs"] = "|".join(dc.common_dirs);
    d["common_files"] = "|".join(sorted(dc.common_files));
    d["common_funny"] = "|".join(dc.common_funny);
    d["same_files"] = "|".join(dc.same_files);
    d["diff_files"] = "|".join(dc.diff_files);
    d["funny_files"] = "|".join(dc.funny_files);
    sd = dc.subdirs["common_dir"];
    d["sub_same"] = "|".join(sd.same_files);
    d["sub_diff"] = "|".join(sd.diff_files);
    try {
        filecmp.cmp(a + "/same.txt", a + "/missing.txt", False);
        d["cmp_missing"] = "NO-RAISE";
    } except FileNotFoundError {
        d["cmp_missing"] = "FileNotFoundError";
    }
    filecmp.clear_cache();
    d["after_clear"] = filecmp.cmp(a + "/same.txt", b + "/same.txt", False);
    shutil.rmtree(base);
    return d;
}
