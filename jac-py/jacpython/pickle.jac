# Product-path facade for Modules/_pickle.c (CPython 3.14).
# Implements the binary pickle wire formats (protocols 2-5) end to end: an
# encoder mirroring _Pickler.save dispatch and a stack-machine decoder
# mirroring _Unpickler.load's opcode loop, with memoization, framing-tolerant
# reads, persistent id/load hooks and dynamic find_class resolution.
#
# REPRESENTATION CHOICE (divergence ledger candidates):
# - No FRAME emission: frames are optional in every consumer; streams are
#   emitted frameless even for protocol >= 4 (the decoder skips frames).
# - Pickler.memo persists across dump() calls keyed by id(), matching the C
#   pickler's identity-keyed memo; the sequential index counter restarts at
#   each dump exactly like CPython's framer-free fast path would not -- this
#   is safe because indices are assigned in save order within one payload.
# - dispatch_table / copyreg extension registry (EXT1-4) are not supported;
#   REDUCE/NEWOBJ carry whatever callables reach the stack (find_class uses
#   importlib.import_module under the floor-delegation policy).
# - Text-mode protocol 0/1 opcodes are decoded only where trivial (INT, LONG,
#   UNICODE lines); STRING/INST/OBJ raise UnpicklingError.
# - Buffers are list[int] internally (the same convention as _structmodule);
#   out-of-band buffers (NEXT_BUFFER/READONLY_BUFFER) are unsupported.

import importlib as _importlib;

import from exceptions_core { register_module_exception }
import from _structmodule { _f64_bits, _bits_f64 }

glob DEFAULT_PROTOCOL: int = 5;
glob HIGHEST_PROTOCOL: int = 5;

# ---------------------------------------------------------------------------
# Shared byte plumbing

def _type_name(v: any) -> str {
    if isinstance(v, bool) {
        return "bool";
    }
    if isinstance(v, int) {
        return "int";
    }
    if isinstance(v, float) {
        return "float";
    }
    if isinstance(v, str) {
        return "str";
    }
    if isinstance(v, bytes) {
        return "bytes";
    }
    if isinstance(v, bytearray) {
        return "bytearray";
    }
    if isinstance(v, list) {
        return "list";
    }
    if isinstance(v, tuple) {
        return "tuple";
    }
    if isinstance(v, dict) {
        return "dict";
    }
    if isinstance(v, set) {
        return "set";
    }
    if v is None {
        return "NoneType";
    }
    return "object";
}

# Duck-typed bytes-like -> list[int] (bytes, bytearray, memoryview, list).
def _as_byte_list(data: any) -> list[int] {
    if isinstance(data, str) {
        return _str_latin1_bytes(data as str);
    }
    try {
        n = len(data);
    } except Exception {
        raise TypeError(
            "a bytes-like object is required, not '" + _type_name(data)
            + "'");
    }
    out: list[int] = [];
    for k in range(n) {
        out.append((data as any)[k] as int);
    }
    return out;
}

def _str_latin1_bytes(s: str) -> list[int] {
    out2: list[int] = [];
    for ch in s {
        out2.append(ord(ch));
    }
    return out2;
}

def _check_protocol(protocol: int) {
    if protocol < 0 {
        raise ValueError("pickle protocol must be >= 0");
    }
    if protocol > HIGHEST_PROTOCOL {
        raise ValueError(
            "pickle protocol must be <= " + str(HIGHEST_PROTOCOL));
    }
}

# ---------------------------------------------------------------------------
# Encoder (_Pickler.save side)

obj _Encoder {
    has buf: any = None;
    has memo: any = None;
    has proto: int = 5;
    has next_idx: int = 0;
    has persistent_id_hook: any = None;
    has depth: int = 0;

    def _w(b: int) {
        (self.buf as list).append(b & 255);
    }

    def _wb(data: list[int]) {
        for b in data {
            (self.buf as list).append(b & 255);
        }
    }

    def _wn(n: int, width: int) {
        # Little-endian unsigned n in `width` bytes.
        for k in range(width) {
            (self.buf as list).append((n >> (8 * k)) & 255);
        }
    }

    def _text_line(s: str) {
        for ch in s {
            (self.buf as list).append(ord(ch) & 255);
        }
        (self.buf as list).append(10);
    }

    # Store obj in the memo and emit the store opcode for the stream's
    # protocol level (BINPUT/LONG_BINPUT below 4, MEMOIZE from 4 up).
    def _memo_store(obj_: any) {
        idx = self.next_idx;
        self.next_idx = idx + 1;
        if idx < 256 {
            self._w(0x71);  # BINPUT
            self._w(idx);
        } else {
            self._w(0x72);  # LONG_BINPUT
            self._wn(idx, 4);
        }
        (self.memo as dict)[id(obj_)] = idx;
    }

    # MEMOIZE form (protocol >= 4): decoder assigns the sequential index,
    # which matches this counter because every store goes through here.
    def _memo_store_p4(obj_: any) {
        (self.memo as dict)[id(obj_)] = self.next_idx;
        self.next_idx = self.next_idx + 1;
        self._w(0x94);  # MEMOIZE
    }

    def _memo_get_op(idx: int) {
        if idx < 256 {
            self._w(0x68);  # BINGET
            self._w(idx);
        } else {
            self._w(0x6A);  # LONG_BINGET
            self._wn(idx, 4);
        }
    }

    def _save_str(s: str) {
        enc = (s.encode("utf-8"));
        raw = _as_byte_list(enc);
        n = len(raw);
        if n < 256 {
            self._w(0x8C);  # SHORT_BINUNICODE
            self._w(n);
        } elif n <= 0xFFFFFFFF {
            self._w(0x58);  # BINUNICODE
            self._wn(n, 4);
        } else {
            self._w(0x8D);  # BINUNICODE8
            self._wn(n, 8);
        }
        self._wb(raw);
    }

    def _save_float(v: float) {
        bits = _f64_bits(v);
        self._w(0x47);  # BINFLOAT
        for k in range(8) {
            (self.buf as list).append((bits >> (56 - 8 * k)) & 255);
        }
    }

    def _save_int(v: int) {
        # BININT covers the signed 32-bit window like C's W_BININT; LONG1
        # carries everything else (CPython also emits LONG4 past 256 bytes,
        # unreachable for practical payloads here).
        if v >= -2147483648 and v <= 2147483647 {
            self._w(0x4A);  # BININT
            self._wn(v & 0xFFFFFFFF, 4);
            return;
        }
        neg = v < 0;
        mag = -v if neg else v;
        nb = mag.bit_length() // 8 + 1;
        self._w(0x8A);  # LONG1
        self._w(nb);
        magc = mag;
        if neg {
            # Two's complement over nb bytes: 2^(8nb) - mag.
            magc = (1 << (8 * nb)) - mag;
        }
        for k in range(nb) {
            (self.buf as list).append((magc >> (8 * k)) & 255);
        }
    }

    def _save_bytes(b: bytes) {
        raw = _as_byte_list(b);
        n = len(raw);
        if n < 256 {
            self._w(0x43);  # SHORT_BINBYTES
            self._w(n);
        } elif n <= 0xFFFFFFFF {
            self._w(0x42);  # BINBYTES
            self._wn(n, 4);
        } else {
            self._w(0x8E);  # BINBYTES8
            self._wn(n, 8);
        }
        self._wb(raw);
    }

    def _save_bytearray(b: bytearray) {
        raw = _as_byte_list(b);
        self._w(0x96);  # BYTEARRAY8
        self._wn(len(raw), 8);
        self._wb(raw);
    }

    def _save_list(v: list) {
        self._w(0x5D);  # EMPTY_LIST
        self._memo_put_for_proto(v);
        self._save_batch_items(v);
    }

    def _save_batch_items(items: any) {
        seq = items as list;
        if len(seq) > 0 {
            self._w(0x28);  # MARK
            for item in seq {
                self.save(item);
            }
            self._w(0x65);  # APPENDS
        }
    }

    def _save_dict(v: dict) {
        self._w(0x7D);  # EMPTY_DICT
        self._memo_put_for_proto(v);
        keys = list(v.keys());
        if len(keys) > 0 {
            self._w(0x28);  # MARK
            for k in keys {
                self.save(k);
                self.save(v[k]);
            }
            self._w(0x75);  # SETITEMS
        }
    }

    def _save_set(v: set, frozen: bool) {
        members = list(v);
        if frozen {
            # FROZENSET builds from the mark slice; elements precede the set
            # itself so recursion through frozensets is unsupported.
            if len(members) > 0 {
                self._w(0x28);  # MARK
                for m in members {
                    self.save(m);
                }
            }
            self._w(0x91);  # FROZENSET
            self._memo_put_for_proto(v);
        } else {
            self._w(0x8F);  # EMPTY_SET
            self._memo_put_for_proto(v);
            if len(members) > 0 {
                self._w(0x28);  # MARK
                for m in members {
                    self.save(m);
                }
                self._w(0x90);  # ADDITEMS
            }
        }
    }

    def _save_tuple(v: tuple) {
        seq = v as list;
        n = len(seq);
        if n == 0 {
            self._w(0x29);  # EMPTY_TUPLE
            return;
        }
        if n <= 3 {
            for item in seq {
                self.save(item);
            }
            self._w(0x84 + n);  # TUPLE1..TUPLE3
            self._memo_put_for_proto(v);
            return;
        }
        self._w(0x28);  # MARK
        for item in seq {
            self.save(item);
        }
        self._w(0x74);  # TUPLE
        self._memo_put_for_proto(v);
    }

    def _memo_put_for_proto(obj_: any) {
        if self.proto >= 4 {
            self._memo_store_p4(obj_);
        } else {
            self._memo_store(obj_);
        }
    }

    def save(v: any) {
        if self.depth > 2000 {
            raise RecursionError(
                "maximum recursion depth exceeded while pickling");
        }
        pid: any = None;
        if self.persistent_id_hook is not None {
            self.depth = self.depth + 1;
            try {
                pid = (self.persistent_id_hook as any)(v);
            } finally {
                self.depth = self.depth - 1;
            }
            if pid is not None {
                self.save(pid);
                self._w(0x51);  # BINPERSID
                return;
            }
        }
        if v is None {
            self._w(0x4E);  # NONE
            return;
        }
        if isinstance(v, bool) {
            self._w(0x88 if (v as bool) else 0x89);  # NEWTRUE / NEWFALSE
            return;
        }
        if isinstance(v, int) {
            self._save_int(v as int);
            return;
        }
        if isinstance(v, float) {
            self._save_float(v as float);
            return;
        }
        if isinstance(v, str) {
            self._save_str(v as str);
            return;
        }
        if isinstance(v, bytes) {
            self._save_bytes(v as bytes);
            return;
        }
        if isinstance(v, bytearray) {
            self._save_bytearray(v as bytearray);
            return;
        }
        # Memoizable shapes: reuse via BINGET/LONG_BINGET on second sight.
        got = (self.memo as dict).get(id(v));
        if got is not None {
            self._memo_get_op(got as int);
            return;
        }
        if isinstance(v, list) {
            self._save_list(v as list);
            return;
        }
        if isinstance(v, tuple) {
            self._save_tuple(v as tuple);
            return;
        }
        if isinstance(v, dict) {
            self._save_dict(v as dict);
            return;
        }
        if isinstance(v, set) {
            self._save_set(v as set, False);
            return;
        }
        if isinstance(v, frozenset) {
            self._save_set(set(v as any), True);
            return;
        }
        raise Exception(
            "cannot pickle '" + _type_name(v) + "' object");
    }
}

def _new_encoder(proto: int, persistent_id_hook: any, memo: any) -> _Encoder {
    enc = _Encoder();
    enc.buf = [];
    enc.memo = memo;
    enc.proto = proto;
    enc.persistent_id_hook = persistent_id_hook;
    return enc;
}

def _encode_payload(obj_: any, proto: int, persistent_id_hook: any,
                    memo: any) -> bytes {
    _check_protocol(proto);
    enc = _new_encoder(proto, persistent_id_hook, memo);
    if proto >= 2 {
        enc._w(0x80);  # PROTO
        enc._w(proto);
    }
    enc.save(obj_);
    enc._w(0x2E);  # STOP
    return bytes(enc.buf as list);
}

# ---------------------------------------------------------------------------
# Decoder (_Unpickler.load side)

obj _Decoder {
    has data: any = None;
    has pos: int = 0;
    has stack: any = None;
    has marks: any = None;
    has memo: any = None;
    has next_idx: int = 0;
    has persistent_load_hook: any = None;
    has text_stack: any = None;

    def _read_byte -> int {
        d = self.data as list;
        if self.pos >= len(d) {
            raise EOFError("unexpected end of data");
        }
        b = (d[self.pos] as int) & 255;
        self.pos = self.pos + 1;
        return b;
    }

    def _read_n(n: int) -> list[int] {
        d = self.data as list;
        end = self.pos + n;
        if end > len(d) {
            raise EOFError("unexpected end of data");
        }
        out: list[int] = [];
        for k in range(self.pos, end) {
            out.append((d[k] as int) & 255);
        }
        self.pos = end;
        return out;
    }

    def _read_uint(width: int) -> int {
        raw = self._read_n(width);
        v = 0;
        for k in range(width) {
            v = v | ((raw[k] as int) << (8 * k));
        }
        return v;
    }

    def _read_sint(width: int) -> int {
        v = self._read_uint(width);
        signbit = 1 << (8 * width - 1);
        if v & signbit {
            v = v - (signbit << 1);
        }
        return v;
    }

    def _read_line -> str {
        d = self.data as list;
        start = self.pos;
        while self.pos < len(d) and ((d[self.pos] as int) & 255) != 10 {
            self.pos = self.pos + 1;
        }
        if self.pos >= len(d) {
            raise EOFError("unexpected end of data");
        }
        chars: list[str] = [];
        for k in range(start, self.pos) {
            chars.append(chr((d[k] as int) & 255));
        }
        self.pos = self.pos + 1;  # consume the newline
        return "".join(chars);
    }

    def _push(v: any) {
        (self.stack as list).append(v);
    }

    def _pop -> any {
        st = self.stack as list;
        if len(st) == 0 {
            raise Exception("unpickling stack empty");
        }
        top = st[len(st) - 1];
        st.pop();
        return top;
    }

    def _pop_mark -> list {
        st = self.stack as list;
        mk = self.marks as list;
        if len(mk) == 0 {
            raise Exception("unpickling mark stack empty");
        }
        k = mk[len(mk) - 1] as int;
        mk.pop();
        items: list = [];
        for i in range(k, len(st)) {
            items.append(st[i]);
        }
        while len(st) > k {
            st.pop();
        }
        return items;
    }

    def _memo_write(obj_: any, idx: int) {
        (self.memo as dict)[idx] = obj_;
    }

    def _memo_read(idx: int) -> any {
        got = (self.memo as dict).get(idx);
        if got is None and idx not in (self.memo as dict) {
            raise Exception("could not find memo index " + str(idx));
        }
        return got;
    }

    def find_class(modname: str, name: str) -> any {
        mod = _importlib.import_module(modname);
        return getattr(mod, name);
    }

    def _persistent_load(pid: any) -> any {
        if self.persistent_load_hook is not None {
            return (self.persistent_load_hook as any)(pid);
        }
        raise Exception(
            "unsupported persistent ID encountered: " + str(pid));
    }

    def _decode_str(raw: list[int]) -> str {
        payload = bytes(raw);
        return (payload.decode("utf-8")) as str;
    }

    # One dispatch step; returns True at STOP.
    def step -> bool {
        op = self._read_byte();
        if op == 0x80 {  # PROTO
            v = self._read_byte();
            if v > HIGHEST_PROTOCOL {
                raise Exception(
                    "unsupported pickle protocol: " + str(v));
            }
            return False;
        }
        if op == 0x95 {  # FRAME
            self._read_uint(8);
            return False;
        }
        if op == 0x2E {  # STOP
            return True;
        }
        if op == 0x28 {  # MARK
            (self.marks as list).append(len(self.stack as list));
            return False;
        }
        if op == 0x30 {  # POP
            self._pop();
            return False;
        }
        if op == 0x31 {  # POP_MARK
            self._pop_mark();
            return False;
        }
        if op == 0x32 {  # DUP
            top = self._pop();
            self._push(top);
            self._push(top);
            return False;
        }
        if op == 0x4E {  # NONE
            self._push(None);
            return False;
        }
        if op == 0x88 {  # NEWTRUE
            self._push(True);
            return False;
        }
        if op == 0x89 {  # NEWFALSE
            self._push(False);
            return False;
        }
        if op == 0x49 {  # INT (text)
            line = self._read_line();
            if line == "01" {
                self._push(True);
            } elif line == "00" {
                self._push(False);
            } else {
                self._push(int(line));
            }
            return False;
        }
        if op == 0x4C {  # LONG (text)
            line = self._read_line();
            if line.endswith("L") or line.endswith("l") {
                line = line[:len(line) - 1];
            }
            self._push(int(line));
            return False;
        }
        if op == 0x4A {  # BININT
            self._push(self._read_sint(4));
            return False;
        }
        if op == 0x4B {  # BININT1
            self._push(self._read_byte());
            return False;
        }
        if op == 0x4D {  # BININT2
            self._push(self._read_uint(2));
            return False;
        }
        if op == 0x47 {  # BINFLOAT (big-endian bits)
            raw = self._read_n(8);
            bits = 0;
            for k in range(8) {
                bits = (bits << 8) | (raw[k] as int);
            }
            self._push(_bits_f64(bits));
            return False;
        }
        if op == 0x8C {  # SHORT_BINUNICODE
            n = self._read_byte();
            self._push(self._decode_str(self._read_n(n)));
            return False;
        }
        if op == 0x58 {  # BINUNICODE
            self._push(self._decode_str(self._read_n(self._read_uint(4))));
            return False;
        }
        if op == 0x8D {  # BINUNICODE8
            self._push(self._decode_str(self._read_n(self._read_uint(8))));
            return False;
        }
        if op == 0x56 {  # UNICODE (raw-unicode-escaped line)
            line = self._read_line();
            self._push("".join(chr(ord(c)) for c in line));
            return False;
        }
        if op == 0x55 {  # SHORT_BINSTRING
            raw = self._read_n(self._read_byte());
            chars: list[str] = [];
            for b in raw {
                chars.append(chr(b as int));
            }
            self._push("".join(chars));
            return False;
        }
        if op == 0x54 {  # BINSTRING
            raw = self._read_n(self._read_uint(4));
            chars2: list[str] = [];
            for b2 in raw {
                chars2.append(chr(b2 as int));
            }
            self._push("".join(chars2));
            return False;
        }
        if op == 0x43 {  # SHORT_BINBYTES
            self._push(bytes(self._read_n(self._read_byte())));
            return False;
        }
        if op == 0x42 {  # BINBYTES
            self._push(bytes(self._read_n(self._read_uint(4))));
            return False;
        }
        if op == 0x8E {  # BINBYTES8
            self._push(bytes(self._read_n(self._read_uint(8))));
            return False;
        }
        if op == 0x96 {  # BYTEARRAY8
            self._push(bytearray(self._read_n(self._read_uint(8))));
            return False;
        }
        if op == 0x5D {  # EMPTY_LIST
            self._push([]);
            return False;
        }
        if op == 0x6C {  # LIST
            items = self._pop_mark();
            self._push(items);
            return False;
        }
        if op == 0x61 {  # APPEND
            v = self._pop();
            target = self._pop();
            (target as list).append(v);
            self._push(target);
            return False;
        }
        if op == 0x65 {  # APPENDS
            items = self._pop_mark();
            target = self._pop();
            for item in items {
                (target as list).append(item);
            }
            self._push(target);
            return False;
        }
        if op == 0x29 {  # EMPTY_TUPLE
            self._push(tuple([]));
            return False;
        }
        if op == 0x85 {  # TUPLE1
            a = self._pop();
            self._push(tuple([a]));
            return False;
        }
        if op == 0x86 {  # TUPLE2
            b = self._pop();
            a = self._pop();
            self._push(tuple([a, b]));
            return False;
        }
        if op == 0x87 {  # TUPLE3
            c = self._pop();
            b = self._pop();
            a = self._pop();
            self._push(tuple([a, b, c]));
            return False;
        }
        if op == 0x74 {  # TUPLE
            items = self._pop_mark();
            self._push(tuple(items));
            return False;
        }
        if op == 0x7D {  # EMPTY_DICT
            self._push({});
            return False;
        }
        if op == 0x64 {  # DICT
            items = self._pop_mark();
            d: dict = {};
            for i in range(0, len(items) - 1, 2) {
                d[items[i]] = items[i + 1];
            }
            self._push(d);
            return False;
        }
        if op == 0x73 {  # SETITEM
            v = self._pop();
            k = self._pop();
            target = self._pop();
            (target as dict)[k] = v;
            self._push(target);
            return False;
        }
        if op == 0x75 {  # SETITEMS
            items = self._pop_mark();
            target = self._pop();
            for i in range(0, len(items) - 1, 2) {
                (target as dict)[items[i]] = items[i + 1];
            }
            self._push(target);
            return False;
        }
        if op == 0x8F {  # EMPTY_SET
            self._push(set());
            return False;
        }
        if op == 0x90 {  # ADDITEMS
            items = self._pop_mark();
            target = self._pop();
            for item in items {
                (target as set).add(item);
            }
            self._push(target);
            return False;
        }
        if op == 0x91 {  # FROZENSET
            items = self._pop_mark();
            self._push(frozenset(items));
            return False;
        }
        if op == 0x94 {  # MEMOIZE
            self._memo_write(self._pop(), self.next_idx);
            self.next_idx = self.next_idx + 1;
            return False;
        }
        if op == 0x70 {  # PUT (text)
            self._memo_write(self._pop(), int(self._read_line()));
            return False;
        }
        if op == 0x71 {  # BINPUT
            self._memo_write(self._pop(), self._read_byte());
            return False;
        }
        if op == 0x72 {  # LONG_BINPUT
            self._memo_write(self._pop(), self._read_uint(4));
            return False;
        }
        if op == 0x67 {  # GET (text)
            self._push(self._memo_read(int(self._read_line())));
            return False;
        }
        if op == 0x68 {  # BINGET
            self._push(self._memo_read(self._read_byte()));
            return False;
        }
        if op == 0x6A {  # LONG_BINGET
            self._push(self._memo_read(self._read_uint(4)));
            return False;
        }
        if op == 0x50 {  # PERSID (text)
            self._push(self._persistent_load(self._read_line()));
            return False;
        }
        if op == 0x51 {  # BINPERSID
            self._push(self._persistent_load(self._pop()));
            return False;
        }
        if op == 0x63 {  # GLOBAL (module\nname\n)
            modname = self._read_line();
            name = self._read_line();
            self._push(self.find_class(modname, name));
            return False;
        }
        if op == 0x93 {  # STACK_GLOBAL
            name = self._pop();
            modname = self._pop();
            self._push(self.find_class(modname as str, name as str));
            return False;
        }
        if op == 0x52 {  # REDUCE
            args = self._pop();
            func = self._pop();
            self._push((func as any)(*tuple(args)));
            return False;
        }
        if op == 0x81 {  # NEWOBJ
            args = self._pop();
            cls = self._pop();
            newf = getattr(cls, "__new__");
            self._push((newf as any)(cls, *tuple(args)));
            return False;
        }
        if op == 0x62 {  # BUILD
            state = self._pop();
            obj_ = self._pop();
            hook = None;
            try {
                hook = getattr(obj_, "__setstate__");
            } except Exception {
                hook = None;
            }
            if hook is not None {
                (hook as any)(state);
            } elif isinstance(state, dict) {
                for k in state.keys() {
                    setattr(obj_, k, state[k]);
                }
            }
            self._push(obj_);
            return False;
        }
        key = chr(op);
        raise Exception("invalid load key, '" + key + "'.");
    }

    def run -> any {
        while True {
            if self.step() {
                return self._pop();
            }
        }
    }
}

def _new_decoder(data: list[int], persistent_load_hook: any,
                 memo: any) -> _Decoder {
    dec = _Decoder();
    dec.data = data;
    dec.stack = [];
    dec.marks = [];
    dec.memo = memo;
    dec.persistent_load_hook = persistent_load_hook;
    return dec;
}

def _decode_payload(data: any, persistent_load_hook: any, memo: any) -> any {
    dec = _new_decoder(_as_byte_list(data), persistent_load_hook, memo);
    return dec.run();
}

# ---------------------------------------------------------------------------
# Module API (Modules/_pickle.c exports)

def dump(obj_: any, file: any, protocol: any = None) {
    p = DEFAULT_PROTOCOL if protocol is None else (protocol as int);
    payload = _encode_payload(obj_, p, None, {});
    (file as any).write(payload);
}

def dumps(obj_: any, protocol: any = None) -> bytes {
    p = DEFAULT_PROTOCOL if protocol is None else (protocol as int);
    return _encode_payload(obj_, p, None, {}) as bytes;
}

def load(file: any) -> any {
    return _decode_payload((file as any).read(), None, {});
}

def loads(data: any) -> any {
    return _decode_payload(data, None, {});
}


# ---------------------------------------------------------------------------
# Pickler / Unpickler carriers

obj _PicklerObj {
    has file: any = None;
    has protocol: int = 0;
    has memo: any = None;
    has persistent_id: any = None;
    has dispatch_table: any = None;

    def dump(obj_: any) {
        payload = _encode_payload(
            obj_, self.protocol, self.persistent_id, self.memo);
        (self.file as any).write(payload);
    }
}

def Pickler(file: any, protocol: any = None) -> _PicklerObj {
    p = DEFAULT_PROTOCOL if protocol is None else (protocol as int);
    _check_protocol(p);
    pk = _PicklerObj();
    pk.file = file;
    pk.protocol = p;
    pk.memo = {};
    return pk;
}

obj _UnpicklerObj {
    has file: any = None;
    has memo: any = None;
    has persistent_load: any = None;
    has _payload: any = None;
    has _consumed: bool = False;

    def find_class(modname: str, name: str) -> any {
        mod = _importlib.import_module(modname);
        return getattr(mod, name);
    }

    def load -> any {
        if not self._consumed {
            self._payload = (self.file as any).read();
            self._consumed = True;
        }
        return _decode_payload(
            self._payload, self.persistent_load, self.memo);
    }
}

def Unpickler(file: any) -> _UnpicklerObj {
    up = _UnpicklerObj();
    up.file = file;
    up.memo = {};
    return up;
}


# ---------------------------------------------------------------------------
# PickleBuffer (minimal: wraps the underlying object)

obj _PickleBufferObj {
    has _obj: any = None;
    has released: bool = False;

    # CPython PickleBuffer.raw(): a memoryview over the underlying buffer;
    # ValueError once released.
    def raw -> any {
        if self.released {
            raise ValueError(
                "operation forbidden on released PickleBuffer object");
        }
        return memoryview(self._obj);
    }

    def release {
        self.released = True;
    }
}

def PickleBuffer(obj_: any) -> _PickleBufferObj {
    # Constructor requires a bytes-like object (TypeError otherwise).
    len(obj_);
    pb = _PickleBufferObj();
    pb._obj = obj_;
    return pb;
}


with entry {
    # Module-exception declarations (bridge-table registry, exceptions_core):
    # declared AT IMPORT so boundary matching/minting knows these hierarchies
    # without bare getattr(builtins, ...) lookups.
    register_module_exception("pickle.PicklingError", "Exception");
    register_module_exception("pickle.UnpicklingError", "Exception");
}
