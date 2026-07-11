import hashlib;
import from typing { cast }
import jaclang.jac0core.unitree as uni;


glob _MIN_LITERAL_CHARS = 16,
     _OWNER_KINDS = {
         "ability",
         "method",
         "constructor",
         "object",
         "node",
         "edge",
         "walker",
         "enum"
     };


obj LiteralFact {
    has module_path: str,
        value_hash: str,
        value_repr: str,
        literal_kind: str,
        size: int,
        owner_id: str,
        owner_name: str,
        pos_start: int,
        pos_end: int,
        line: int;
}


def _text_of(nd: any) -> (str | None) {
    try {
        v = nd.lit_value;
    } except Exception {
        return None;
    }
    return v if isinstance(v, str) else None;
}


def _has_fstring(ms: any) -> bool {
    for part in ms.strings {
        if isinstance(part, uni.FString) {
            return True;
        }
    }
    return False;
}


def _render(nd: any) -> str {
    if isinstance(nd, (uni.String, uni.MultiString)) {
        t = _text_of(nd);
        return repr(t) if t is not None else "BYTES";
    }
    if isinstance(nd, (uni.Int, uni.Float, uni.Bool, uni.Null)) {
        return repr(nd.lit_value);
    }
    if isinstance(nd, uni.ListVal) {
        return "[" + ",".join([_render(v) for v in nd.values]) + "]";
    }
    if isinstance(nd, uni.SetVal) {
        return "{" + ",".join([_render(v) for v in (nd.values or [])]) + "}";
    }
    if isinstance(nd, uni.TupleVal) {
        return "(" + ",".join([_render(v) for v in nd.values]) + ")";
    }
    if isinstance(nd, uni.DictVal) {
        parts: list[str] = [];
        for kv in nd.kv_pairs {
            k = _render(kv.key) if kv.key is not None else "**";
            parts.append(k + ":" + _render(kv.value));
        }
        return "{" + ",".join(parts) + "}";
    }
    if isinstance(nd, uni.KWPair) {
        key = str(nd.key.sym_name) if nd.key is not None else "";
        return key + "=" + _render(nd.value);
    }
    if isinstance(nd, uni.Name) {
        return "N:" + str(nd.sym_name);
    }
    txt = "";
    try {
        txt = str(nd.value);
    } except Exception {
        txt = type(nd).__name__;
    }
    return "T:" + txt;
}


def _coll_kind(nd: any) -> str {
    if isinstance(nd, uni.ListVal) {
        return "list";
    }
    if isinstance(nd, uni.SetVal) {
        return "set";
    }
    if isinstance(nd, uni.TupleVal) {
        return "tuple";
    }
    return "dict";
}


def _append(
    canon: str,
    kind: str,
    nd: any,
    owners: list,
    sym_id_fn: any,
    mod_path: str,
    out: list[LiteralFact]
) {
    value_hash = hashlib.sha256(canon.encode("utf-8")).hexdigest()[:16];
    owner_id = "";
    owner_name = "";
    if owners {
        owner = owners[-1];
        owner_id = str(sym_id_fn(cast(uni.Symbol, owner)));
        owner_name = str(owner.sym_name);
    }
    loc = nd.loc;
    out.append(
        LiteralFact(
            module_path=mod_path,
            value_hash=value_hash,
            value_repr=canon[:120],
            literal_kind=kind,
            size=len(canon),
            owner_id=owner_id,
            owner_name=owner_name,
            pos_start=int(loc.pos_start),
            pos_end=int(loc.pos_end),
            line=int(loc.first_line)
        )
    );
}


def _try_emit(
    nd: any,
    excl: set,
    owners: list,
    sym_id_fn: any,
    mod_path: str,
    out: list[LiteralFact]
) -> bool {
    if isinstance(nd, uni.FString) {
        return True;
    }
    if isinstance(nd, uni.MultiString) {
        if id(nd) in excl or _has_fstring(nd) {
            return True;
        }
        val = _text_of(nd);
        if val is not None and len(val) >= _MIN_LITERAL_CHARS {
            _append(val, "str", nd, owners, sym_id_fn, mod_path, out);
        }
        return True;
    }
    if isinstance(nd, uni.String) {
        if id(nd) in excl {
            return True;
        }
        val = _text_of(nd);
        if val is not None and len(val) >= _MIN_LITERAL_CHARS {
            _append(val, "str", nd, owners, sym_id_fn, mod_path, out);
        }
        return True;
    }
    if isinstance(nd, (uni.ListVal, uni.SetVal, uni.TupleVal, uni.DictVal)) {
        canon = _render(nd);
        if len(canon) >= _MIN_LITERAL_CHARS {
            _append(canon, _coll_kind(nd), nd, owners, sym_id_fn, mod_path, out);
            return True;
        }
        return False;
    }
    return False;
}


def _walk_lits(
    nd: any,
    excl: set,
    owners: list,
    sym_id_fn: any,
    mod_path: str,
    out: list[LiteralFact]
) {
    pushed = False;
    if isinstance(nd, uni.AstSymbolNode) {
        s = nd.sym;
        if s is not None and str(s.sym_type) in _OWNER_KINDS {
            owners.append(s);
            pushed = True;
        }
    }
    if not _try_emit(nd, excl, owners, sym_id_fn, mod_path, out) {
        for k in nd.kid {
            _walk_lits(k, excl, owners, sym_id_fn, mod_path, out);
        }
    }
    if pushed {
        owners.pop();
    }
}


def _excluded_string_ids(mod: any) -> set {
    excl: set = set();
    if mod.doc is not None {
        excl.add(id(mod.doc));
    }
    for typ in [uni.Archetype, uni.Enum, uni.Ability, uni.ArchHas] {
        for nd in mod.get_all_sub_nodes(typ) {
            if nd.doc is not None {
                excl.add(id(nd.doc));
            }
        }
    }
    for sd in mod.get_all_sub_nodes(uni.SemDef) {
        v = sd.value;
        excl.add(id(v));
        for s in v.strings {
            excl.add(id(s));
        }
    }
    return excl;
}


def extract_literals(mod: any, sym_id_fn: any) -> list[LiteralFact] {
    out: list[LiteralFact] = [];
    excl = _excluded_string_ids(mod);
    owners: list = [];
    _walk_lits(mod, excl, owners, sym_id_fn, str(mod.loc.mod_path), out);
    return out;
}
