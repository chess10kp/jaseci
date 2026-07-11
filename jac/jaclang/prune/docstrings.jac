import hashlib;
import from typing { cast }
import jaclang.jac0core.unitree as uni;


glob _MIN_DOC_CHARS = 16;


obj DocstringFact {
    has symbol_id: str,
        name: str,
        module_path: str,
        kind: str,
        text_hash: str,
        text: str,
        length: int,
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


def _normalize(text: str) -> str {
    return " ".join(text.split());
}


def _emit(
    text: str,
    kind: str,
    sym: any,
    name: str,
    nd: any,
    sym_id_fn: any,
    out: list[DocstringFact]
) {
    norm = _normalize(text);
    if len(norm) < _MIN_DOC_CHARS {
        return;
    }
    text_hash = hashlib.sha256(norm.encode("utf-8")).hexdigest()[:16];
    symbol_id = "";
    if sym is not None {
        symbol_id = str(sym_id_fn(cast(uni.Symbol, sym)));
    }
    loc = nd.loc;
    out.append(
        DocstringFact(
            symbol_id=symbol_id,
            name=name,
            module_path=str(loc.mod_path),
            kind=kind,
            text_hash=text_hash,
            text=norm[:200],
            length=len(norm),
            pos_start=int(loc.pos_start),
            pos_end=int(loc.pos_end),
            line=int(loc.first_line)
        )
    );
}


def _target_symbol(sd: any) -> any {
    for nm in reversed(cast(list, sd.target)) {
        s = nm.sym;
        if s is not None {
            return s;
        }
    }
    return sd.sym;
}


def extract_docstrings(mod: any, sym_id_fn: any) -> list[DocstringFact] {
    out: list[DocstringFact] = [];

    mod_doc = _text_of(mod.doc) if mod.doc is not None else None;
    if mod_doc is not None {
        _emit(
            mod_doc,
            "docstring",
            mod?.sym,
            str(getattr(mod, "sym_name", "")),
            mod.doc,
            sym_id_fn,
            out
        );
    }

    for typ in [uni.Archetype, uni.Enum, uni.Ability] {
        for nd in mod.get_all_sub_nodes(typ) {
            doc = nd.doc;
            if doc is None {
                continue;
            }
            txt = _text_of(doc);
            if txt is None {
                continue;
            }
            _emit(txt, "docstring", nd.sym, str(nd.sym_name), doc, sym_id_fn, out);
        }
    }

    for sd in mod.get_all_sub_nodes(uni.SemDef) {
        txt = _text_of(sd.value);
        if txt is None {
            continue;
        }
        name = ".".join([str(t.sym_name) for t in sd.target]);
        _emit(txt, "sem", _target_symbol(sd), name, sd.value, sym_id_fn, out);
    }
    return out;
}
