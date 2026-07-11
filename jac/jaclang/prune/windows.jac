import hashlib;
import from jaclang.prune.factstore { FactStore }
import from jaclang.prune.factquery { cite_index }
import from jaclang.prune.finding { reuse_verify_questions }


glob WINDOW_QUERY_VERSION = "1",
     MIN_WINDOW = 4;


obj WindowSite {
    has symbol_id: str,
        name: str,
        owner_id: str,
        owner_name: str,
        module_path: str,
        body_file: str,
        start_idx: int,
        pos_start: int,
        pos_end: int,
        line_start: int,
        line_end: int;
}


obj WindowGroup {
    has window_id: str,
        length: int,
        block_hashes: list[str],
        sites: list[WindowSite],
        distinct_functions: int,
        distinct_owners: int,
        same_owner_only: bool,
        payoff: float;
}


def _parse_seq(s: str) -> list[dict] {
    out: list[dict] = [];
    for line in s.split("\n") {
        if not line {
            continue;
        }
        f = line.split("\x1f");
        if len(f) < 5 {
            continue;
        }
        out.append(
            {
                "hash": f[0],
                "pos_start": int(f[1]),
                "pos_end": int(f[2]),
                "line1": int(f[3]),
                "line2": int(f[4])
            }
        );
    }
    return out;
}


def _owner_key(seq: dict) -> str {
    if seq["owner_id"] {
        return "cls:" + str(seq["owner_id"]);
    }
    return "mod:" + str(seq["module_path"]);
}


def _maximal(seqs: list, occ: list, base_len: int) -> tuple[list, int] {
    length = base_len;
    while True {
        nxts: set = set();
        ok = True;
        for (si, start) in occ {
            j = start + length;
            if j >= len(seqs[si]["stmts"]) {
                ok = False;
                break;
            }
            nxts.add(seqs[si]["stmts"][j]["hash"]);
        }
        if not ok or len(nxts) != 1 {
            break;
        }
        length += 1;
    }
    left = 0;
    while True {
        prevs: set = set();
        ok = True;
        for (si, start) in occ {
            j = start - left - 1;
            if j < 0 {
                ok = False;
                break;
            }
            prevs.add(seqs[si]["stmts"][j]["hash"]);
        }
        if not ok or len(prevs) != 1 {
            break;
        }
        left += 1;
    }
    new_occ = [(si, start - left) for (si, start) in occ];
    return (new_occ, length + left);
}


def _build_site(seq: dict, start: int, length: int) -> WindowSite {
    stmts = seq["stmts"];
    first = stmts[start];
    last = stmts[start + length - 1];
    return WindowSite(
        symbol_id=str(seq["symbol_id"]),
        name=str(seq["name"]),
        owner_id=str(seq["owner_id"]),
        owner_name=str(seq["owner_name"]),
        module_path=str(seq["module_path"]),
        body_file=str(seq["body_file"]),
        start_idx=start,
        pos_start=int(first["pos_start"]),
        pos_end=int(last["pos_end"]),
        line_start=int(first["line1"]),
        line_end=int(last["line2"])
    );
}


def _sat(x: float, cap: float) -> float {
    if cap <= 0.0 {
        return 0.0;
    }
    return min(x, cap) / cap;
}


def find_stmt_windows(store: FactStore, min_window: int = 0) -> list[WindowGroup] {
    mw = min_window if min_window > 0 else MIN_WINDOW;
    rows = store.stmt_sequences();
    seqs: list = [];
    for r in rows {
        r["stmts"] = _parse_seq(str(r["stmt_seq"]));
        seqs.append(r);
    }

    index: dict[str, list] = {};
    order: list[str] = [];
    for si in range(len(seqs)) {
        stmts = seqs[si]["stmts"];
        hs = [st["hash"] for st in stmts];
        n = len(hs);
        i = 0;
        while i + mw <= n {
            gkey = "\x1f".join(hs[i:i + mw]);
            if gkey not in index {
                index[gkey] = [];
                order.append(gkey);
            }
            index[gkey].append((si, i));
            i += 1;
        }
    }

    groups: list[WindowGroup] = [];
    emitted: set = set();
    for gkey in order {
        occ = index[gkey];
        if len(occ) < 2 {
            continue;
        }
        (new_occ, length) = _maximal(seqs, occ, mw);
        distinct_si = {si for (si, _s) in new_occ};
        if len(distinct_si) < 2 {
            continue;
        }
        dedup = "|".join(
            sorted([f"{si}:{start}" for (si, start) in new_occ]) + [str(length)]
        );
        if dedup in emitted {
            continue;
        }
        emitted.add(dedup);

        sites = [_build_site(seqs[si], start, length) for (si, start) in new_occ];
        owner_keys = {_owner_key(seqs[si]) for (si, _s) in new_occ};
        sym_ids = sorted({s.symbol_id for s in sites});
        canon_si = new_occ[0][0];
        canon_start = new_occ[0][1];
        block = [
            str(seqs[canon_si]["stmts"][canon_start + k]["hash"]) for k in range(length)
        ];
        same_owner = len(owner_keys) == 1;
        base = float(length) * float(len(sites) - 1);
        payoff = _sat(base, 60.0);
        if same_owner {
            payoff = payoff * 0.5;
        }
        wid = "reuse:win:" + hashlib.sha256(
            ("|".join([WINDOW_QUERY_VERSION] + block + sym_ids)).encode("utf-8")
        ).hexdigest()[:16];
        groups.append(
            WindowGroup(
                window_id=wid,
                length=length,
                block_hashes=block,
                sites=sites,
                distinct_functions=len(distinct_si),
                distinct_owners=len(owner_keys),
                same_owner_only=same_owner,
                payoff=payoff
            )
        );
    }

    groups.sort(key=(lambda g : (-g.payoff, -g.length, g.window_id)));
    return groups;
}


def window_summary(w: WindowGroup) -> dict {
    return {
        "window_id": w.window_id,
        "length": w.length,
        "site_count": len(w.sites),
        "distinct_functions": w.distinct_functions,
        "distinct_owners": w.distinct_owners,
        "same_owner_only": w.same_owner_only,
        "payoff": w.payoff,
        "sites": [
            {
                "name": s.name,
                "owner": s.owner_name,
                "module_path": s.module_path,
                "line_start": s.line_start,
                "line_end": s.line_end
            } for s in w.sites
        ]
    };
}


def window_packet(w: WindowGroup, store: FactStore | None = None) -> dict {
    citations: list[str] = [];
    sites: list[dict] = [];
    for s in w.sites {
        cites = ["sym:" + s.symbol_id, "body:" + s.symbol_id];
        citations.extend(cites);
        sites.append(
            {
                "symbol_id": s.symbol_id,
                "name": s.name,
                "owner_id": s.owner_id,
                "owner_name": s.owner_name,
                "module_path": s.module_path,
                "body_file": s.body_file,
                "pos_start": s.pos_start,
                "pos_end": s.pos_end,
                "line_start": s.line_start,
                "line_end": s.line_end,
                "citations": cites
            }
        );
    }
    return {
        "window_id": w.window_id,
        "length": w.length,
        "block_hashes": w.block_hashes,
        "distinct_functions": w.distinct_functions,
        "distinct_owners": w.distinct_owners,
        "same_owner_only": w.same_owner_only,
        "payoff": w.payoff,
        "verify": reuse_verify_questions("window"),
        "sites": sites,
        "citations": citations,
        "cite_index": cite_index(store, citations) if store is not None else {}
    };
}
