import hashlib;
import from typing { cast }
import jaclang.jac0core.unitree as uni;


obj BodyFact {
    has symbol_id: str,
        name: str,
        module_path: str,
        owner_id: str,
        owner_name: str,
        body_file: str,
        body_pos_start: int,
        body_pos_end: int,
        stmt_pos_start: int,
        stmt_pos_end: int,
        exact_hash: str,
        structural_hash: str,
        arity: int,
        is_async: bool,
        is_gen: bool,
        stmt_count: int,
        line_count: int,
        size_band: int,
        completeness: str = "complete",
        vector: str = "";
}


def _resolved_body(ab: any) -> (list | None) {
    b = ab.body;
    if b is None {
        return None;
    }
    if isinstance(b, uni.ImplDef) {
        ib = b.body;
        if isinstance(ib, (list, tuple)) {
            return list(ib);
        }
        return [ib];
    }
    if isinstance(b, (list, tuple)) {
        return list(b);
    }
    return [b];
}


def _local_ids(ab: any) -> set {
    ids: set = set();
    stack: list = [ab];
    while stack {
        scope = stack.pop();
        names = scope.names_in_scope;
        for (nm, s) in names.items() {
            ids.add(id(s));
        }
        for kid in scope.kid_scope {
            stack.append(kid);
        }
    }
    return ids;
}


def _lit_value(nd: any) -> str {
    return repr(nd.lit_value);
}


def _walk(nd: any, local_ids: set, dbru: dict, ex: list, st: list, vec: list) {
    kids = list(nd.kid);
    if not kids {
        if isinstance(nd, (uni.Int, uni.Float, uni.String, uni.Bool, uni.Null)) {
            v = _lit_value(nd);
            ex.append("LIT:" + v);
            st.append("<lit>");
            vec.append(v);
            return;
        }
        if isinstance(nd, uni.Name) {
            nm = str(nd.sym_name);
            s = nd.sym;
            is_local = (s is not None and id(s) in local_ids)
            or nm == "self"
            or nm == "here";
            ex.append("N:" + nm);
            if is_local {
                if nm in dbru {
                    idx = dbru[nm];
                } else {
                    idx = len(dbru);
                    dbru[nm] = idx;
                }
                st.append("<L" + str(idx) + ">");
                vec.append(nm);
            } else {
                st.append("N:" + nm);
            }
            return;
        }
        txt = "";
        try {
            txt = str(nd.value);
        } except Exception {
            txt = type(nd).__name__;
        }
        ex.append(txt);
        st.append(txt);
        return;
    }
    for k in kids {
        _walk(k, local_ids, dbru, ex, st, vec);
    }
}


def _size_band(stmt_count: int) -> int {
    if stmt_count <= 2 {
        return 0;
    }
    if stmt_count <= 5 {
        return 1;
    }
    if stmt_count <= 10 {
        return 2;
    }
    if stmt_count <= 20 {
        return 3;
    }
    if stmt_count <= 40 {
        return 4;
    }
    return 5;
}


def _arity(ab: any) -> int {
    sig = ab.signature;
    if isinstance(sig, uni.FuncSignature) {
        return len(sig.get_parameters());
    }
    return 0;
}


def _is_gen(body: list) -> bool {
    for stmt in body {
        if stmt.get_all_sub_nodes(uni.YieldExpr) {
            return True;
        }
    }
    return False;
}


def _body_span(ab: any) -> tuple[str, int, int, int] {
    bnode = ab.body;
    if isinstance(bnode, uni.ImplDef) {
        loc = bnode.loc;
    } else {
        loc = ab.loc;
    }
    lines = int(loc.last_line) - int(loc.first_line) + 1;
    return (str(loc.mod_path), int(loc.pos_start), int(loc.pos_end), lines);
}


def _stmt_span(body: list) -> tuple[int, int] {
    first = body[0].loc;
    last = body[-1].loc;
    return (int(first.pos_start), int(last.pos_end));
}


def extract_bodies(mod: any, sym_id_fn: any) -> list[BodyFact] {
    out: list[BodyFact] = [];
    for ab in mod.get_all_sub_nodes(uni.Ability) {
        sym = ab.sym;
        if sym is None {
            continue;
        }
        body = _resolved_body(ab);
        if body is None or len(body) == 0 {
            continue;
        }
        local_ids = _local_ids(ab);
        dbru: dict = {};
        ex: list = [];
        st: list = [];
        vec: list = [];
        for stmt in body {
            _walk(stmt, local_ids, dbru, ex, st, vec);
        }
        exact = hashlib.sha256("".join(ex).encode("utf-8")).hexdigest()[:16];
        struct = hashlib.sha256("".join(st).encode("utf-8")).hexdigest()[:16];
        (bfile, bstart, bend, blines) = _body_span(ab);
        (sstart, send) = _stmt_span(body);
        owner = ab.method_owner;
        owner_id = "";
        owner_name = "";
        if owner is not None and owner.sym is not None {
            owner_id = str(sym_id_fn(cast(uni.Symbol, owner.sym)));
            owner_name = str(owner.sym_name);
        }
        stmt_count = len(body);
        out.append(
            BodyFact(
                symbol_id=str(sym_id_fn(cast(uni.Symbol, sym))),
                name=str(ab.sym_name),
                module_path=str(ab.loc.mod_path),
                owner_id=owner_id,
                owner_name=owner_name,
                body_file=bfile,
                body_pos_start=bstart,
                body_pos_end=bend,
                stmt_pos_start=sstart,
                stmt_pos_end=send,
                exact_hash=exact,
                structural_hash=struct,
                arity=_arity(ab),
                is_async=bool(ab.is_async),
                is_gen=_is_gen(body),
                stmt_count=stmt_count,
                line_count=blines,
                size_band=_size_band(stmt_count),
                vector="\n".join(vec)
            )
        );
    }
    return out;
}
