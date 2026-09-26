"""Bundled native ``tempfile`` cross-backend equivalence fixture.

The sv entry uses CPython's tempfile; the na entry the bundled
`na_stdlib/tempfile.jac` (mkstemp/mkdtemp/gettempdir + TempFile and
TemporaryDirectory objects over an openat64/mkdir/read/write/lseek FFI
floor). Both lanes drive the same /tmp workspace and pin names, flags,
contents and error classes as scalars. ES/JS opts out.
"""

import os;
import shutil;
import tempfile;


def tempfile_py -> dict[any, any] {
    base = "/tmp/jac_prim_tempfile_fix";
    if os.path.exists(base) {
        shutil.rmtree(base);
    }
    os.makedirs(base);
    d = {
        "tdir_ok": os.path.isdir(tempfile.gettempdir()),
        "tdir_stable": tempfile.gettempdir() == tempfile.gettempdir(),
        "tdirb": tempfile.gettempdirb().decode() == tempfile.gettempdir(),
        "tmp_max": tempfile.TMP_MAX,
        "template": tempfile.template,

    };
    (fd, path) = tempfile.mkstemp(suffix=".log", prefix="zz", dir=base);
    d["mkstemp_fd"] = fd >= 0;
    bn = os.path.basename(path);
    d["mkstemp_name"] = bn.startswith("zz") and bn.endswith(".log") and len(bn) == 14;
    d["mkstemp_exists"] = os.path.exists(path);
    w = open(path, "w");
    w.write("xy");
    w.close();
    r = open(path, "r");
    d["mkstemp_body"] = r.read();
    r.close();
    os.unlink(path);
    dpath = tempfile.mkdtemp(suffix=".d", prefix="pd", dir=base);
    dn = os.path.basename(dpath);
    d["mkdtemp"] = os.path.isdir(dpath) and dn.startswith("pd") and dn.endswith(".d");
    mp = tempfile.mktemp(suffix=".m", prefix="pm", dir=base);
    mn = os.path.basename(mp);
    d["mktemp"] = mn.startswith("pm") and mn.endswith(".m") and not os.path.exists(mp);
    nf = tempfile.NamedTemporaryFile(
        mode="w+b", suffix=".dat", prefix="pf", dir=base, delete=True
    );
    d["nf_write"] = nf.write(b"hello");
    d["nf_tell"] = nf.tell();
    d["nf_seek"] = nf.seek(0);
    d["nf_read"] = (nf.read() as bytes).decode();
    nb = os.path.basename(nf.name);
    d["nf_name"] = nb.startswith("pf") and nb.endswith(".dat");
    d["nf_present"] = os.path.exists(nf.name);
    nf.close();
    d["nf_deleted"] = not os.path.exists(nf.name);
    kf = tempfile.NamedTemporaryFile(
        mode="w+b", suffix=".k", prefix="pk", dir=base, delete=False
    );
    kname = kf.name;
    kf.write(b"k");
    kf.close();
    d["kf_kept"] = os.path.exists(kname);
    os.unlink(kname);
    tf = tempfile.TemporaryFile(mode="w+b", dir=base);
    tf.write(b"anon");
    tf.seek(0);
    d["tf_read"] = (tf.read() as bytes).decode();
    tf.close();
    xf = tempfile.TemporaryFile(mode="w", dir=base);
    xf.write("t1");
    xf.seek(0);
    d["xf_text"] = xf.read();
    xf.close();
    td = tempfile.TemporaryDirectory(suffix=".td", prefix="pt", dir=base);
    tn = os.path.basename(td.name);
    d["td_dir"] = os.path.isdir(td.name) and tn.startswith("pt") and tn.endswith(".td");
    tf_path = os.path.join(td.name, "inner.txt");
    tfh = open(tf_path, "w");
    tfh.write("i");
    tfh.close();
    td.cleanup();
    d["td_gone"] = not os.path.exists(td.name);
    try {
        tempfile.mkstemp(dir="/definitely/missing/jac_zz");
        d["mkstemp_err"] = "NO-RAISE";
    } except FileNotFoundError {
        d["mkstemp_err"] = "FileNotFoundError";
    }
    shutil.rmtree(base);
    return d;
}


def tempfile_cl -> dict[any, any] {
    return {};
}


def tempfile_na -> dict[str, any] {
    base = "/tmp/jac_prim_tempfile_fix";
    if os.path.exists(base) {
        shutil.rmtree(base);
    }
    os.makedirs(base);
    d: dict[str, any] = {};
    d["tdir_ok"] = os.path.isdir(tempfile.gettempdir());
    d["tdir_stable"] = tempfile.gettempdir() == tempfile.gettempdir();
    d["tdirb"] = tempfile.gettempdirb().decode() == tempfile.gettempdir();
    d["tmp_max"] = tempfile.TMP_MAX;
    d["template"] = tempfile.template;
    (fd, path) = tempfile.mkstemp(suffix=".log", prefix="zz", dir=base);
    d["mkstemp_fd"] = fd >= 0;
    bn = os.path.basename(path);
    d["mkstemp_name"] = bn.startswith("zz") and bn.endswith(".log") and len(bn) == 14;
    d["mkstemp_exists"] = os.path.exists(path);
    w = open(path, "w");
    w.write("xy");
    w.close();
    r = open(path, "r");
    d["mkstemp_body"] = r.read();
    r.close();
    os.unlink(path);
    dpath = tempfile.mkdtemp(suffix=".d", prefix="pd", dir=base);
    dn = os.path.basename(dpath);
    d["mkdtemp"] = os.path.isdir(dpath) and dn.startswith("pd") and dn.endswith(".d");
    mp = tempfile.mktemp(suffix=".m", prefix="pm", dir=base);
    mn = os.path.basename(mp);
    d["mktemp"] = mn.startswith("pm") and mn.endswith(".m") and not os.path.exists(mp);
    nf = tempfile.NamedTemporaryFile(
        mode="w+b", suffix=".dat", prefix="pf", dir=base, delete=True
    );
    d["nf_write"] = nf.write(b"hello");
    d["nf_tell"] = nf.tell();
    d["nf_seek"] = nf.seek(0);
    d["nf_read"] = (nf.read() as bytes).decode();
    nb = os.path.basename(nf.name);
    d["nf_name"] = nb.startswith("pf") and nb.endswith(".dat");
    d["nf_present"] = os.path.exists(nf.name);
    nf.close();
    d["nf_deleted"] = not os.path.exists(nf.name);
    kf = tempfile.NamedTemporaryFile(
        mode="w+b", suffix=".k", prefix="pk", dir=base, delete=False
    );
    kname = kf.name;
    kf.write(b"k");
    kf.close();
    d["kf_kept"] = os.path.exists(kname);
    os.unlink(kname);
    tf = tempfile.TemporaryFile(mode="w+b", dir=base);
    tf.write(b"anon");
    tf.seek(0);
    d["tf_read"] = (tf.read() as bytes).decode();
    tf.close();
    xf = tempfile.TemporaryFile(mode="w", dir=base);
    xf.write("t1");
    xf.seek(0);
    d["xf_text"] = xf.read();
    xf.close();
    td = tempfile.TemporaryDirectory(suffix=".td", prefix="pt", dir=base);
    tn = os.path.basename(td.name);
    d["td_dir"] = os.path.isdir(td.name) and tn.startswith("pt") and tn.endswith(".td");
    tf_path = os.path.join(td.name, "inner.txt");
    tfh = open(tf_path, "w");
    tfh.write("i");
    tfh.close();
    td.cleanup();
    d["td_gone"] = not os.path.exists(td.name);
    try {
        tempfile.mkstemp(dir="/definitely/missing/jac_zz");
        d["mkstemp_err"] = "NO-RAISE";
    } except FileNotFoundError {
        d["mkstemp_err"] = "FileNotFoundError";
    }
    shutil.rmtree(base);
    return d;
}
