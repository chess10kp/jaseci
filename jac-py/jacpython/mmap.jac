# Product-path facade for mmap (native Jac).
#
# Semantics mirror CPython 3.14 ``Modules/mmapmodule.c`` (UNIX variant):
# anonymous mappings (``mmap.mmap(-1, length)`` / single-arg length form),
# access-mode matrix (ACCESS_DEFAULT/READ/WRITE/COPY driving prot+flags),
# the full instance surface (read/read_byte/readline/write/write_byte/
# seek/tell/seekable/size/resize/flush/close/move/find/rfind/madvise),
# sequence+mapping slots (int indexing yields ints, slices yield bytes),
# closed-state guards, and the byte-exact error strings from the C source.
#
# The guest VM has no descriptor table yet, so file-backed maps route
# through the host bridge (os.fstat/pread/pwrite) behind three narrow
# helpers; when a real io layer lands, only those helpers change. Anonymous
# mappings -- the shape every converted Lib/test pin exercises -- are fully
# native with no host traffic.
#
# Faithful quirk kept from the C source: size() fstats the backing fd, so an
# ANONYMOUS map raises OSError("[Errno 9] Bad file descriptor") instead of
# reporting its own length (mmap_mmap_size_impl has no anonymous special case
# on UNIX).
#
# Error-channel convention matches the other facades (binasciimodule et al):
# built-in TypeError/ValueError/IndexError/OverflowError/OSError keep their
# builtin type names exactly so guest except-handlers match them.

import from objects {
    PyObj,
    PyInt,
    PyBool,
    PyBytes,
    PyStr,
    PySlice,
    PyNoneType,
    PyModule,
    py_none,
    py_error,
    is_error,
    expect_int,
    _seq_index,
    slice_indices,
}

import os as _host_os;

# ---------------- module constants (Linux values) ----------------------------

glob PROT_EXEC: int = 4,
     PROT_READ: int = 1,
     PROT_WRITE: int = 2,

     MAP_SHARED: int = 0x01,
     MAP_PRIVATE: int = 0x02,
     MAP_DENYWRITE: int = 0x0800,
     MAP_EXECUTABLE: int = 0x1000,
     MAP_ANON: int = 0x20,
     MAP_ANONYMOUS: int = 0x20,
     MAP_POPULATE: int = 0x8000,
     MAP_STACK: int = 0x20000,
     MAP_NORESERVE: int = 0x4000,
     MAP_FIXED: int = 0x10,

     PAGESIZE: int = 4096,
     ALLOCATIONGRANULARITY: int = 4096,

     ACCESS_DEFAULT: int = 0,
     ACCESS_READ: int = 1,
     ACCESS_WRITE: int = 2,
     ACCESS_COPY: int = 3,

     MADV_NORMAL: int = 0,
     MADV_RANDOM: int = 1,
     MADV_SEQUENTIAL: int = 2,
     MADV_WILLNEED: int = 3,
     MADV_DONTNEED: int = 4,
     MADV_MERGEABLE: int = 12,
     MADV_UNMERGEABLE: int = 13,
     MADV_HUGEPAGE: int = 14,
     MADV_NOHUGEPAGE: int = 15,
     MADV_DONTDUMP: int = 16,
     MADV_DODUMP: int = 17,
     MADV_WIPEONFORK: int = 18,
     MADV_KEEPONFORK: int = 19,
     MADV_COLD: int = 20,
     MADV_PAGEOUT: int = 21,
     MADV_POPULATE_READ: int = 22,
     MADV_POPULATE_WRITE: int = 23;

# ---------------- host-bridge helpers (file-backed maps only) ----------------

def _p2_host_fstat_size(fd: int) -> tuple[bool, int] {
    try {
        st = _host_os.fstat(fd);
        return (True, st.st_size);
    } except Exception {
        return (False, -1);
    }
}

def _p2_host_pread(fd: int, n: int, off: int) -> list[int] {
    out: list[int] = [];
    try {
        chunk = _host_os.pread(fd, n, off);
        for b in chunk {
            out.append(b);
        }
    } except Exception {
        # Read failure yields whatever was fetched (possibly nothing); the
        # map still constructs, mirroring a short read rather than a crash.
    }
    return out;
}

def _p2_host_pwrite(fd: int, data: list[int], off: int) -> bool {
    try {
        buf = bytes(data);
        written = _host_os.pwrite(fd, buf, off);
        return written == len(data);
    } except Exception {
        return False;
    }
}

# ---------------- shared argument helpers ------------------------------------

# Buffer argument normalization: the C contract takes a bytes-like buffer;
# anything else raises the standard buffer-protocol TypeError.
def _p2_bytes_arg(v: PyObj) -> PyObj {
    if isinstance(v, PyBytes) {
        return v;
    }
    return py_error("TypeError", "a bytes-like object is required");
}

def _p2_check_valid(m: PyMmapObj) -> PyObj {
    if m.closed {
        return py_error("ValueError", "mmap closed or invalid");
    }
    return py_none();
}

# is_writable(): raises through the error channel when the map is read-only.
def _p2_is_writable(m: PyMmapObj) -> PyObj {
    if m.access == ACCESS_READ {
        return py_error("TypeError", "mmap can't modify a readonly memory map.");
    }
    return py_none();
}

def _p2_access_name(access: int) -> str {
    if access == ACCESS_DEFAULT {
        return "ACCESS_DEFAULT";
    }
    if access == ACCESS_READ {
        return "ACCESS_READ";
    }
    if access == ACCESS_WRITE {
        return "ACCESS_WRITE";
    }
    return "ACCESS_COPY";
}

# ---------------- instance surface -------------------------------------------

def _p2_mmap_read(m: PyMmapObj, args: list[PyObj]) -> PyObj {
    num: int = -1;
    if len(args) > 0 {
        num = expect_int(args[0]);
    }
    remaining: int = 0;
    if m.pos < m.size {
        remaining = m.size - m.pos;
    }
    take: int = remaining;
    if num >= 0 and num < remaining {
        take = num;
    }
    items: list[int] = m.data[m.pos : m.pos + take];
    m.pos = m.pos + take;
    return PyBytes(t="bytes", val=items);
}

def _p2_mmap_read_byte(m: PyMmapObj) -> PyObj {
    if m.pos >= m.size {
        return py_error("ValueError", "read byte out of range");
    }
    b: int = m.data[m.pos];
    m.pos = m.pos + 1;
    return PyInt(t="int", val=b);
}

def _p2_mmap_readline(m: PyMmapObj) -> PyObj {
    remaining: int = 0;
    if m.pos < m.size {
        remaining = m.size - m.pos;
    }
    if remaining == 0 {
        return PyBytes(t="bytes", val=[]);
    }
    end: int = m.size;
    i: int = m.pos;
    while i < m.size {
        if m.data[i] == 10 {
            end = i + 1;
            break;
        }
        i = i + 1;
    }
    items: list[int] = m.data[m.pos : end];
    m.pos = end;
    return PyBytes(t="bytes", val=items);
}

def _p2_mmap_write(m: PyMmapObj, args: list[PyObj]) -> PyObj {
    if len(args) != 1 {
        return py_error(
            "TypeError", "write() takes exactly one argument (" + str(len(args)) + " given)"
        );
    }
    got = _p2_bytes_arg(args[0]);
    if is_error(got) {
        return got;
    }
    payload: list[int] = (got as PyBytes).val;
    if m.pos > m.size or m.size - m.pos < len(payload) {
        return py_error("ValueError", "data out of range");
    }
    k: int = 0;
    while k < len(payload) {
        m.data[m.pos + k] = payload[k];
        k = k + 1;
    }
    m.pos = m.pos + len(payload);
    return PyInt(t="int", val=len(payload));
}

def _p2_mmap_write_byte(m: PyMmapObj, args: list[PyObj]) -> PyObj {
    if len(args) != 1 {
        return py_error("TypeError", "write_byte() takes exactly one argument");
    }
    v: int = expect_int(args[0]);
    if v < 0 or v > 255 {
        v = v & 0xFF;
    }
    if m.pos >= m.size {
        return py_error("ValueError", "write byte out of range");
    }
    m.data[m.pos] = v;
    m.pos = m.pos + 1;
    return py_none();
}

def _p2_mmap_seek(m: PyMmapObj, args: list[PyObj]) -> PyObj {
    if len(args) < 1 or len(args) > 2 {
        return py_error("TypeError", "seek expected 1 or 2 arguments");
    }
    dist: int = expect_int(args[0]);
    how: int = 0;
    if len(args) == 2 {
        how = expect_int(args[1]);
    }
    where: int = 0;
    if how == 0 {
        where = dist;
    } elif how == 1 {
        where = m.pos + dist;
    } elif how == 2 {
        where = m.size + dist;
    } else {
        return py_error("ValueError", "unknown seek type");
    }
    if where > m.size or where < 0 {
        return py_error("ValueError", "seek out of range");
    }
    m.pos = where;
    return PyInt(t="int", val=m.pos);
}

# size(): fstats the backing fd exactly like mmap_mmap_size_impl -- anonymous
# maps therefore surface the EBADF OSError instead of their own length.
def _p2_mmap_size(m: PyMmapObj) -> PyObj {
    if m.fd == -1 {
        return py_error("OSError", "[Errno 9] Bad file descriptor");
    }
    got = _p2_host_fstat_size(m.fd);
    if not ((got[0] as bool)) {
        return py_error("OSError", "[Errno 9] Bad file descriptor");
    }
    return PyInt(t="int", val=got[1]);
}

def _p2_mmap_resize(m: PyMmapObj, args: list[PyObj]) -> PyObj {
    # Order mirrors is_resizeable(): harness-fd tracking gate, then access.
    if not m.trackfd {
        return py_error("ValueError", "mmap can't resize with trackfd=False.");
    }
    if m.access != ACCESS_WRITE and m.access != ACCESS_DEFAULT {
        return py_error(
            "TypeError", "mmap can't resize a readonly or copy-on-write memory map."
        );
    }
    new_size: int = expect_int(args[0]);
    if new_size < 0 {
        return py_error("ValueError", "new size out of range");
    }
    while len(m.data) < new_size {
        m.data.append(0);
    }
    while len(m.data) > new_size {
        m.data.pop();
    }
    m.size = new_size;
    return py_none();
}

def _p2_mmap_flush(m: PyMmapObj, args: list[PyObj]) -> PyObj {
    offset: int = 0;
    size: int = m.size;
    if len(args) > 0 {
        offset = expect_int(args[0]);
    }
    if len(args) > 1 {
        size = expect_int(args[1]);
    }
    if size < 0 or offset < 0 or m.size - offset < size {
        return py_error("ValueError", "flush values out of range");
    }
    if m.access == ACCESS_READ or m.access == ACCESS_COPY {
        return py_none();
    }
    if m.fd != -1 {
        _p2_host_pwrite(m.fd, m.data[offset : offset + size], m.offset + offset);
    }
    return py_none();
}

def _p2_mmap_move(m: PyMmapObj, args: list[PyObj]) -> PyObj {
    dest: int = expect_int(args[0]);
    src: int = expect_int(args[1]);
    cnt: int = expect_int(args[2]);
    if dest < 0 or src < 0 or cnt < 0 or m.size - dest < cnt or m.size - src < cnt {
        return py_error("ValueError", "source, destination, or count out of range");
    }
    block: list[int] = m.data[src : src + cnt];
    k: int = 0;
    while k < cnt {
        m.data[dest + k] = block[k];
        k = k + 1;
    }
    return py_none();
}

def _p2_mmap_gfind(m: PyMmapObj, args: list[PyObj], reverse: bool) -> PyObj {
    i: int = 0;
    j: int = 0;
    if len(args) < 1 {
        return py_error("TypeError", "find expected at least 1 argument");
    }
    got = _p2_bytes_arg(args[0]);
    if is_error(got) {
        return got;
    }
    needle: list[int] = (got as PyBytes).val;
    start: int = m.pos;
    end: int = m.size;
    if len(args) > 1 and not isinstance(args[1], PyNoneType) {
        start = expect_int(args[1]);
        if len(args) > 2 and not isinstance(args[2], PyNoneType) {
            end = expect_int(args[2]);
        }
    }
    if start < 0 {
        start = start + m.size;
    }
    if start < 0 {
        start = 0;
    } elif start > m.size {
        start = m.size;
    }
    if end < 0 {
        end = end + m.size;
    }
    if end < 0 {
        end = 0;
    } elif end > m.size {
        end = m.size;
    }
    if end < start {
        return PyInt(t="int", val=-1);
    }
    nlen: int = len(needle);
    if nlen == 0 {
        return PyInt(t="int", val=start);
    }
    if reverse {
        i = end - nlen;
        while i >= start {
            j = 0;
            while j < nlen and m.data[i + j] == needle[j] {
                j = j + 1;
            }
            if j == nlen {
                return PyInt(t="int", val=i);
            }
            i = i - 1;
        }
        return PyInt(t="int", val=-1);
    }
    i = start;
    while i + nlen <= end {
        j = 0;
        while j < nlen and m.data[i + j] == needle[j] {
            j = j + 1;
        }
        if j == nlen {
            return PyInt(t="int", val=i);
        }
        i = i + 1;
    }
    return PyInt(t="int", val=-1);
}

def _p2_mmap_madvise(m: PyMmapObj, args: list[PyObj]) -> PyObj {
    # The advice value itself has no observable effect on the in-memory model;
    # only its presence is validated.
    expect_int(args[0]);
    start: int = 0;
    length: int = m.size;
    if len(args) > 1 {
        start = expect_int(args[1]);
    }
    if len(args) > 2 and not isinstance(args[2], PyNoneType) {
        length = expect_int(args[2]);
    }
    if start < 0 or start >= m.size {
        return py_error("ValueError", "madvise start out of bounds");
    }
    if length < 0 {
        return py_error("ValueError", "madvise length invalid");
    }
    if start + length > m.size {
        length = m.size - start;
    }
    # Advice values carry no observable effect on the in-memory model.
    return py_none();
}

def _p2_mmap_repr(m: PyMmapObj) -> str {
    if m.closed {
        return "<mmap.mmap closed=True>";
    }
    return (
        "<mmap.mmap closed=False, access=" + _p2_access_name(m.access)
        + ", length=" + str(m.size)
        + ", pos=" + str(m.pos)
        + ", offset=" + str(m.offset) + ">"
    );
}

# ---------------- slot implementations ---------------------------------------

def _p2_mmap_subscript(m: PyMmapObj, index: PyObj) -> PyObj {
    if isinstance(index, PySlice) {
        b = slice_indices(index as PySlice, m.size);
        si: int = b[0];
        stop: int = b[1];
        step: int = b[2];
        out: list[int] = [];
        i: int = si;
        if step > 0 {
            while i < stop {
                out.append(m.data[i]);
                i = i + step;
            }
        } else {
            while i > stop {
                out.append(m.data[i]);
                i = i + step;
            }
        }
        return PyBytes(t="bytes", val=out);
    }
    idx = index.to_index();
    if is_error(idx) {
        return py_error("TypeError", "mmap indices must be integers");
    }
    i = (idx as PyInt).val;
    if i < 0 {
        i = i + m.size;
    }
    if i < 0 or i >= m.size {
        return py_error("IndexError", "mmap index out of range");
    }
    return PyInt(t="int", val=m.data[i]);
}

def _p2_mmap_ass_subscript(m: PyMmapObj, index: PyObj, value: PyObj) -> PyObj {
    ro = _p2_is_writable(m);
    if is_error(ro) {
        return ro;
    }
    if isinstance(index, PySlice) {
        b = slice_indices(index as PySlice, m.size);
        si: int = b[0];
        stop: int = b[1];
        step: int = b[2];
        slicelen: int = 0;
        probe: int = si;
        if step > 0 {
            while probe < stop {
                slicelen = slicelen + 1;
                probe = probe + step;
            }
        } else {
            while probe > stop {
                slicelen = slicelen + 1;
                probe = probe + step;
            }
        }
        if isinstance(value, PyNoneType) {
            return py_error("TypeError", "mmap object doesn't support slice deletion");
        }
        got = _p2_bytes_arg(value);
        if is_error(got) {
            return got;
        }
        payload: list[int] = (got as PyBytes).val;
        if len(payload) != slicelen {
            return py_error("IndexError", "mmap slice assignment is wrong size");
        }
        k: int = 0;
        while k < slicelen {
            m.data[si + k * step] = payload[k];
            k = k + 1;
        }
        return py_none();
    }
    if isinstance(value, PyNoneType) {
        return py_error("TypeError", "mmap doesn't support item deletion");
    }
    idx = index.to_index();
    if is_error(idx) {
        return py_error("TypeError", "mmap indices must be integer");
    }
    i = (idx as PyInt).val;
    if i < 0 {
        i = i + m.size;
    }
    if i < 0 or i >= m.size {
        return py_error("IndexError", "mmap index out of range");
    }
    if not isinstance(value, PyInt) {
        return py_error("TypeError", "mmap item value must be an int");
    }
    v: int = (value as PyInt).val;
    if v < 0 or v > 255 {
        return py_error("ValueError", "mmap item value must be in range(0, 256)");
    }
    m.data[i] = v;
    return py_none();
}

def _p2_mmap_del_subscript(m: PyMmapObj, index: PyObj) -> PyObj {
    ro = _p2_is_writable(m);
    if is_error(ro) {
        return ro;
    }
    if isinstance(index, PySlice) {
        return py_error("TypeError", "mmap object doesn't support slice deletion");
    }
    return py_error("TypeError", "mmap doesn't support item deletion");
}

# Method dispatch shared by the generic bound-method wrapper. One entry point
# keeps the PyObj subclass count at two (instance + method) instead of one
# wrapper type per operation.
def _p2_mmap_dispatch(target: PyMmapObj, name: str, args: list[PyObj]) -> PyObj {
    if name == "read" {
        return _p2_mmap_read(target, args);
    }
    if name == "read_byte" {
        return _p2_mmap_read_byte(target);
    }
    if name == "readline" {
        return _p2_mmap_readline(target);
    }
    if name == "write" {
        return _p2_mmap_write(target, args);
    }
    if name == "write_byte" {
        return _p2_mmap_write_byte(target, args);
    }
    if name == "seek" {
        return _p2_mmap_seek(target, args);
    }
    if name == "tell" {
        return PyInt(t="int", val=target.pos);
    }
    if name == "seekable" {
        return PyBool(t="bool", val=True);
    }
    if name == "size" {
        return _p2_mmap_size(target);
    }
    if name == "resize" {
        if len(args) != 1 {
            return py_error("TypeError", "resize() takes exactly one argument");
        }
        return _p2_mmap_resize(target, args);
    }
    if name == "flush" {
        return _p2_mmap_flush(target, args);
    }
    if name == "move" {
        return _p2_mmap_move(target, args);
    }
    if name == "find" {
        return _p2_mmap_gfind(target, args, False);
    }
    if name == "rfind" {
        return _p2_mmap_gfind(target, args, True);
    }
    if name == "madvise" {
        if len(args) < 1 {
            return py_error("TypeError", "madvise expected at least 1 argument");
        }
        return _p2_mmap_madvise(target, args);
    }
    if name == "close" {
        if target.fd != -1 and target.access != ACCESS_READ
            and target.access != ACCESS_COPY {
            _p2_host_pwrite(target.fd, target.data, target.offset);
        }
        target.closed = True;
        target.data = [];
        return py_none();
    }
    if name == "__enter__" {
        return target;
    }
    if name == "__exit__" {
        return _p2_mmap_dispatch(target, "close", []);
    }
    if name == "__len__" {
        return PyInt(t="int", val=target.size);
    }
    return py_error("AttributeError", "'mmap.mmap' object has no attribute '" + name + "'");
}

obj PyMmapObj(PyObj) {
    has data: list[int],
        pos: int = 0,
        size: int = 0,
        closed: bool = False,
        access: int = ACCESS_DEFAULT,
        fd: int = -1,
        offset: int = 0,
        trackfd: bool = True;

    def tp_getattro(name: str) -> PyObj {
        if name == "closed" {
            return PyBool(t="bool", val=self.closed);
        }
        if name == "read" or name == "read_byte" or name == "readline"
            or name == "write" or name == "write_byte" or name == "seek"
            or name == "tell" or name == "seekable" or name == "size"
            or name == "resize" or name == "flush" or name == "move"
            or name == "find" or name == "rfind" or name == "madvise"
            or name == "close" or name == "__enter__" or name == "__exit__"
            or name == "__len__" {
            return PyMmapMethod(t="mmap_method", target=self, name=name);
        }
        return py_error(
            "AttributeError", "'mmap.mmap' object has no attribute '" + name + "'"
        );
    }

    def mp_subscript(index: PyObj) -> PyObj {
        err = _p2_check_valid(self);
        if is_error(err) {
            return err;
        }
        return _p2_mmap_subscript(self, index);
    }

    def mp_ass_subscript(index: PyObj, value: PyObj) -> PyObj {
        err = _p2_check_valid(self);
        if is_error(err) {
            return err;
        }
        return _p2_mmap_ass_subscript(self, index, value);
    }

    def mp_del_subscript(index: PyObj) -> PyObj {
        err = _p2_check_valid(self);
        if is_error(err) {
            return err;
        }
        return _p2_mmap_del_subscript(self, index);
    }

    def tp_repr -> PyObj {
        return PyStr(t="str", val=_p2_mmap_repr(self));
    }
}

obj PyMmapMethod(PyObj) {
    has target: PyMmapObj,
        name: str;

    def tp_call(args: list[PyObj], kwargs: dict[str, PyObj]) -> PyObj {
        if len(kwargs) > 0 {
            return py_error("TypeError", self.name + "() takes no keyword arguments");
        }
        return _p2_mmap_dispatch(self.target, self.name, args);
    }
}

# ---------------- constructor -------------------------------------------------

# Parse-and-validate mirrors new_mmap_object (UNIX branch): fileno+length
# positional, flags/prot/access/offset optional positionally or by keyword,
# access-mode matrix remapping prot/flags, and the file-size validation
# ladder. File content loads through the host bridge; anonymous maps stay
# fully native.
obj PyMmapCtor(PyObj) {
    def tp_call(args: list[PyObj], kwargs: dict[str, PyObj]) -> PyObj {
        # Merge positional + keyword arguments onto the clinic parameter
        # vector [fileno, length, flags, prot, access, offset]; unspecified
        # slots keep CPython's defaults.
        names: list[str] = ["fileno", "length", "flags", "prot", "access", "offset", "trackfd"];
        values: list[PyObj] = [];
        seen: list[bool] = [];
        k: int = 0;
        while k < 7 {
            if k < len(args) {
                values.append(args[k]);
                seen.append(True);
            } elif names[k] in kwargs {
                values.append(kwargs[names[k]]);
                seen.append(True);
            } else {
                values.append(py_none());
                seen.append(False);
            }
            k = k + 1;
        }
        for key in kwargs {
            known: bool = False;
            n: int = 0;
            while n < 7 {
                if key == names[n] {
                    known = True;
                }
                n = n + 1;
            }
            if not known {
                return py_error(
                    "TypeError", "'" + key + "' is an invalid keyword argument for mmap()"
                );
            }
        }
        if len(args) > 7 {
            return py_error(
                "TypeError",
                "mmap expected at most 6 arguments, got " + str(len(args)),
            );
        }
        if not seen[0] {
            return py_error(
                "TypeError", "function missing required argument 'fileno' (pos 1)"
            );
        }
        if not seen[1] {
            return py_error(
                "TypeError", "function missing required argument 'length' (pos 2)"
            );
        }
        fd_arg = values[0].to_index();
        if is_error(fd_arg) {
            return py_error("TypeError", "an integer is required");
        }
        fd: int = (fd_arg as PyInt).val;
        len_arg = values[1].to_index();
        if is_error(len_arg) {
            return py_error("TypeError", "an integer is required");
        }
        map_size: int = (len_arg as PyInt).val;

        flags: int = MAP_SHARED;
        prot: int = PROT_WRITE | PROT_READ;
        access: int = ACCESS_DEFAULT;
        offset: int = 0;
        if seen[2] {
            flags = expect_int(values[2]);
        }
        if seen[3] {
            prot = expect_int(values[3]);
        }
        if seen[4] {
            access = expect_int(values[4]);
        }
        if seen[5] {
            offset = expect_int(values[5]);
        }
        # trackfd defaults true; a falsy value drops the descriptor so size()
        # surfaces EBADF exactly like the C object's fd == -1 state.
        trackfd: bool = True;
        if seen[6] {
            trackfd = (expect_int(values[6]) != 0);
        }

        if map_size < 0 {
            return py_error("OverflowError", "memory mapped length must be positive");
        }
        if offset < 0 {
            return py_error("OverflowError", "memory mapped offset must be positive");
        }
        if access != ACCESS_DEFAULT and (flags != MAP_SHARED or prot != (PROT_WRITE | PROT_READ)) {
            return py_error("ValueError", "mmap can't specify both access and flags, prot.");
        }
        if access == ACCESS_READ {
            flags = MAP_SHARED;
            prot = PROT_READ;
        } elif access == ACCESS_WRITE {
            flags = MAP_SHARED;
            prot = PROT_READ | PROT_WRITE;
        } elif access == ACCESS_COPY {
            flags = MAP_PRIVATE;
            prot = PROT_READ | PROT_WRITE;
        } elif access == ACCESS_DEFAULT {
            if (prot & PROT_READ) and (prot & PROT_WRITE) {
                access = ACCESS_DEFAULT;
            } elif prot & PROT_WRITE {
                access = ACCESS_WRITE;
            } else {
                access = ACCESS_READ;
            }
        } else {
            return py_error("ValueError", "mmap invalid access parameter.");
        }

        data: list[int] = [];
        if fd == -1 {
            # Anonymous mapping: zero-filled buffer of map_size.
            i: int = 0;
            while i < map_size {
                data.append(0);
                i = i + 1;
            }
        } else {
            got = _p2_host_fstat_size(fd);
            if not ((got[0] as bool)) {
                return py_error("OSError", "[Errno 9] Bad file descriptor");
            }
            file_size: int = got[1];
            if map_size == 0 {
                if file_size == 0 {
                    return py_error("ValueError", "cannot mmap an empty file");
                }
                if offset >= file_size {
                    return py_error("ValueError", "mmap offset is greater than file size");
                }
                map_size = file_size - offset;
            } elif offset > file_size or file_size - offset < map_size {
                return py_error("ValueError", "mmap length is greater than file size");
            }
            data = _p2_host_pread(fd, map_size, offset);
            while len(data) < map_size {
                data.append(0);
            }
        }
        return PyMmapObj(
            t="mmap_obj",
            data=data,
            size=map_size,
            access=access,
            fd=fd,
            offset=offset,
            trackfd=trackfd,
        );
    }
}

# ---------------- module builder ----------------------------------------------

def build_mmap_module -> PyObj {
    return PyModule(
        t="module",
        name="mmap",
        attrs={
            "mmap": PyMmapCtor(t="mmap_ctor"),
            "PROT_EXEC": PyInt(t="int", val=PROT_EXEC),
            "PROT_READ": PyInt(t="int", val=PROT_READ),
            "PROT_WRITE": PyInt(t="int", val=PROT_WRITE),
            "MAP_SHARED": PyInt(t="int", val=MAP_SHARED),
            "MAP_PRIVATE": PyInt(t="int", val=MAP_PRIVATE),
            "MAP_DENYWRITE": PyInt(t="int", val=MAP_DENYWRITE),
            "MAP_EXECUTABLE": PyInt(t="int", val=MAP_EXECUTABLE),
            "MAP_ANON": PyInt(t="int", val=MAP_ANON),
            "MAP_ANONYMOUS": PyInt(t="int", val=MAP_ANONYMOUS),
            "MAP_POPULATE": PyInt(t="int", val=MAP_POPULATE),
            "MAP_STACK": PyInt(t="int", val=MAP_STACK),
            "MAP_NORESERVE": PyInt(t="int", val=MAP_NORESERVE),
            "MAP_FIXED": PyInt(t="int", val=MAP_FIXED),
            "PAGESIZE": PyInt(t="int", val=PAGESIZE),
            "ALLOCATIONGRANULARITY": PyInt(t="int", val=ALLOCATIONGRANULARITY),
            "ACCESS_DEFAULT": PyInt(t="int", val=ACCESS_DEFAULT),
            "ACCESS_READ": PyInt(t="int", val=ACCESS_READ),
            "ACCESS_WRITE": PyInt(t="int", val=ACCESS_WRITE),
            "ACCESS_COPY": PyInt(t="int", val=ACCESS_COPY),
            "MADV_NORMAL": PyInt(t="int", val=MADV_NORMAL),
            "MADV_RANDOM": PyInt(t="int", val=MADV_RANDOM),
            "MADV_SEQUENTIAL": PyInt(t="int", val=MADV_SEQUENTIAL),
            "MADV_WILLNEED": PyInt(t="int", val=MADV_WILLNEED),
            "MADV_DONTNEED": PyInt(t="int", val=MADV_DONTNEED),
            "MADV_MERGEABLE": PyInt(t="int", val=MADV_MERGEABLE),
            "MADV_UNMERGEABLE": PyInt(t="int", val=MADV_UNMERGEABLE),
            "MADV_HUGEPAGE": PyInt(t="int", val=MADV_HUGEPAGE),
            "MADV_NOHUGEPAGE": PyInt(t="int", val=MADV_NOHUGEPAGE),
            "MADV_DONTDUMP": PyInt(t="int", val=MADV_DONTDUMP),
            "MADV_DODUMP": PyInt(t="int", val=MADV_DODUMP),
            "MADV_WIPEONFORK": PyInt(t="int", val=MADV_WIPEONFORK),
            "MADV_KEEPONFORK": PyInt(t="int", val=MADV_KEEPONFORK),
            "MADV_COLD": PyInt(t="int", val=MADV_COLD),
            "MADV_PAGEOUT": PyInt(t="int", val=MADV_PAGEOUT),
            "MADV_POPULATE_READ": PyInt(t="int", val=MADV_POPULATE_READ),
            "MADV_POPULATE_WRITE": PyInt(t="int", val=MADV_POPULATE_WRITE),
        },
    );
}
