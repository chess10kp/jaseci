import from typing { cast }
import jaclang.jac0core.unitree as uni;


glob _EXTRACT_MIN_ARMS = 3,
     _ORDERED_OPS = {"<", "<=", ">", ">=", "is", "is not"},
     _SEQ_OPS = {"=="},
     _OR_OPS = {"==", "in"},
     _AND_OPS = {"!=", "not in"},
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


obj ChainFact {
    has module_path: str,
        owner_id: str,
        owner_name: str,
        shape: str,
        n_arms: int,
        n_total: int,
        selector: str,
        const_arms: int,
        uniform_returns: int,
        ordered_ops: int,
        mixed_selector: int,
        pos_start: int,
        pos_end: int,
        line: int;
}


def _expr_key(nd: any) -> str {
    try {
        return str(nd.unparse());
    } except Exception {
        return type(nd).__name__;
    }
}


def _is_const_operand(nd: any) -> bool {
    return isinstance(
        nd,
        (
            uni.Int,
            uni.Float,
            uni.String,
            uni.MultiString,
            uni.Bool,
            uni.Null,
            uni.Name,
            uni.ListVal,
            uni.SetVal,
            uni.TupleVal,
            uni.DictVal
        )
    );
}


def _cmp_arm(cond: any) -> (dict | None) {
    if not isinstance(cond, uni.CompareExpr) {
        return None;
    }
    ops = list(cond.ops or []);
    rights = list(cond.rights or []);
    if len(ops) != 1 or len(rights) != 1 {
        return None;
    }
    op_val = "";
    try {
        op_val = str(ops[0].value);
    } except Exception {
        return None;
    }
    return {
        "selector": _expr_key(cond.left),
        "op": op_val,
        "const": _is_const_operand(rights[0])
    };
}


def _single_return(body: any) -> bool {
    stmts = list(body or []);
    return len(stmts) == 1 and isinstance(stmts[0], uni.ReturnStmt);
}


def _owner_of(nd: any, sym_id_fn: any) -> tuple[str, str] {
    cur = nd.parent;
    while cur is not None {
        if isinstance(cur, uni.AstSymbolNode) {
            s = cur.sym;
            if s is not None and str(s.sym_type) in _OWNER_KINDS {
                return (str(sym_id_fn(cast(uni.Symbol, s))), str(s.sym_name));
            }
        }
        cur = cur.parent;
    }
    return ("", "");
}


def _emit(
    mod_path: str,
    sym_id_fn: any,
    anchor: any,
    shape: str,
    arms: list[dict],
    n_total: int,
    uniform_returns: bool,
    count_ops: set,
    out: list[ChainFact]
) {
    selectors: dict[str, int] = {};
    const_arms = 0;
    ordered = 0;
    for a in arms {
        opv = str(a["op"]);
        if opv in _ORDERED_OPS {
            ordered = 1;
            continue;
        }
        if opv not in count_ops {
            continue;
        }
        sel = str(a["selector"]);
        selectors[sel] = int(selectors.get(sel, 0)) + 1;
        if a["const"] {
            const_arms += 1;
        }
    }
    best_sel = "";
    best_n = 0;
    for (sel, cnt) in selectors.items() {
        if int(cnt) > best_n {
            best_n = int(cnt);
            best_sel = sel;
        }
    }
    if best_n < _EXTRACT_MIN_ARMS {
        return;
    }
    (owner_id, owner_name) = _owner_of(anchor, sym_id_fn);
    loc = anchor.loc;
    out.append(
        ChainFact(
            module_path=mod_path,
            owner_id=owner_id,
            owner_name=owner_name,
            shape=shape,
            n_arms=best_n,
            n_total=n_total,
            selector=best_sel,
            const_arms=const_arms,
            uniform_returns=1 if uniform_returns else 0,
            ordered_ops=ordered,
            mixed_selector=1 if len(selectors) > 1 else 0,
            pos_start=int(loc.pos_start),
            pos_end=int(loc.pos_end),
            line=int(loc.first_line)
        )
    );
}


def _seq_arm(stmt: any) -> (dict | None) {
    if not isinstance(stmt, uni.IfStmt) or isinstance(stmt, uni.ElseIf) {
        return None;
    }
    arm = _cmp_arm(stmt.condition);
    if arm is None or not _single_return(stmt.body) {
        return None;
    }
    return arm;
}


def _scan_seq_runs(stmts: list, mod_path: str, sym_id_fn: any, out: list[ChainFact]) {
    n = len(stmts);
    i = 0;
    while i < n {
        arm = _seq_arm(stmts[i]);
        if arm is None or str(arm["op"]) != "==" {
            i += 1;
            continue;
        }
        sel = str(arm["selector"]);
        arms: list[dict] = [arm];
        j = i + 1;
        while j < n {
            nxt = _seq_arm(stmts[j]);
            if (nxt is None or str(nxt["op"]) != "==" or str(nxt["selector"]) != sel) {
                break;
            }
            arms.append(nxt);
            j += 1;
        }
        _emit(
            mod_path,
            sym_id_fn,
            stmts[i],
            "seq-if",
            arms,
            len(arms),
            True,
            _SEQ_OPS,
            out
        );
        i = j;
    }
}


def _scan_elif_chain(ifs: any, mod_path: str, sym_id_fn: any, out: list[ChainFact]) {
    nodes: list = [ifs];
    cur = ifs;
    while isinstance(cur.else_body, uni.ElseIf) {
        cur = cur.else_body;
        nodes.append(cur);
    }
    if len(nodes) < _EXTRACT_MIN_ARMS {
        return;
    }
    arms: list[dict] = [];
    uniform = True;
    for nd in nodes {
        arm = _cmp_arm(nd.condition);
        if arm is not None {
            arms.append(arm);
        }
        if not _single_return(nd.body) {
            uniform = False;
        }
    }
    _emit(
        mod_path, sym_id_fn, ifs, "elif-chain", arms, len(nodes), uniform, _SEQ_OPS, out
    );
}


def _bool_leaves(be: any, op_val: str) -> list {
    leaves: list = [];
    for v in list(be.values or []) {
        inner = v.expr if isinstance(v, uni.CfgExpr) else v;
        if (
            isinstance(inner, uni.BoolExpr)
            and inner.op is not None
            and str(inner.op.value) == op_val
        ) {
            leaves.extend(_bool_leaves(inner, op_val));
        } else {
            leaves.append(inner);
        }
    }
    return leaves;
}


def _scan_bool_chain(
    be: any, op_val: str, mod_path: str, sym_id_fn: any, out: list[ChainFact]
) {
    p = be.parent;
    if (
        isinstance(p, uni.BoolExpr) and p.op is not None and str(p.op.value) == op_val
    ) {
        return;
    }
    leaves = _bool_leaves(be, op_val);
    arms: list[dict] = [];
    for leaf in leaves {
        arm = _cmp_arm(leaf);
        if arm is not None {
            arms.append(arm);
        }
    }
    _emit(
        mod_path,
        sym_id_fn,
        be,
        f"{op_val}-chain",
        arms,
        len(leaves),
        False,
        (_OR_OPS if op_val == "or" else _AND_OPS),
        out
    );
}


def extract_chains(mod: any, sym_id_fn: any) -> list[ChainFact] {
    out: list[ChainFact] = [];
    mod_path = str(mod.loc.mod_path);
    scanned_lists: set = set();
    for ifs in mod.get_all_sub_nodes(uni.IfStmt) {
        if isinstance(ifs, uni.ElseIf) {
            continue;
        }
        p = ifs.parent;
        stmts = p?.body if p is not None else None;
        if isinstance(stmts, (list, tuple)) and id(stmts) not in scanned_lists {
            scanned_lists.add(id(stmts));
            _scan_seq_runs(list(stmts), mod_path, sym_id_fn, out);
        }
        _scan_elif_chain(ifs, mod_path, sym_id_fn, out);
    }
    for be in mod.get_all_sub_nodes(uni.BoolExpr) {
        op_val = str(be.op.value) if be.op is not None else "";
        if op_val in {"or", "and"} {
            _scan_bool_chain(be, op_val, mod_path, sym_id_fn, out);
        }
    }
    return out;
}
