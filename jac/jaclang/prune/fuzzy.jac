import hashlib;
import from jaclang.prune.factstore { FactStore }
import from jaclang.prune.factquery { cite_index }
import from jaclang.prune.finding { reuse_verify_questions }
import from jaclang.prune.clones {
    CloneMember,
    _build_member,
    _is_lifecycle,
    _distinct_key,
    _median,
    _sat,
    _reach
}


glob FUZZY_QUERY_VERSION = "1",
     DEFAULT_THRESHOLD = 0.8,
     DEFAULT_K = 3,
     DEFAULT_MAX_BUCKET = 400;


obj FuzzyGroup {
    has group_id: str,
        kind: str,
        arity: int,
        is_async: bool,
        is_gen: bool,
        size_band: int,
        threshold: float,
        members: list[CloneMember],
        structural_hashes: list[str],
        min_similarity: float,
        mean_similarity: float,
        copies_saved: int,
        lines_saved: int,
        reach: int,
        payoff: float;
}


def _shingles(tokens: list[str], k: int) -> set {
    if not tokens {
        return set();
    }
    if len(tokens) < k {
        return {"\x1f".join(tokens)};
    }
    out: set = set();
    for i in range(len(tokens) - k + 1) {
        out.add("\x1f".join(tokens[i:i + k]));
    }
    return out;
}


def _jaccard(a: set, b: set) -> float {
    if not a or not b {
        return 0.0;
    }
    inter = len(a & b);
    uni = len(a | b);
    if uni == 0 {
        return 0.0;
    }
    return inter / uni;
}


def _find(parent: dict[int, int], x: int) -> int {
    cur = x;
    while parent[cur] != cur {
        parent[cur] = parent[parent[cur]];
        cur = parent[cur];
    }
    return cur;
}


def _union(parent: dict[int, int], a: int, b: int) {
    ra = _find(parent, a);
    rb = _find(parent, b);
    if ra == rb {
        return;
    }
    if ra < rb {
        parent[rb] = ra;
    } else {
        parent[ra] = rb;
    }
}


def _bucket_key(row: dict) -> str {
    return "\x1f".join(
        [
            str(row["arity"]),
            "1" if row["is_async"] else "0",
            "1" if row["is_gen"] else "0",
            str(row["size_band"])
        ]
    );
}


def _group_id(member_ids: list[str], threshold: float) -> str {
    key = "|".join([FUZZY_QUERY_VERSION, f"{threshold:.3f}"] + sorted(member_ids));
    return "reuse:fzy:" + hashlib.sha256(key.encode("utf-8")).hexdigest()[:16];
}


def find_fuzzy_clone_groups(
    store: FactStore, threshold: float = 0.0, k: int = 0, max_bucket: int = 0
) -> tuple[list[FuzzyGroup], list[dict]] {
    thr = threshold if threshold > 0.0 else DEFAULT_THRESHOLD;
    kk = k if k > 0 else DEFAULT_K;
    cap = max_bucket if max_bucket > 0 else DEFAULT_MAX_BUCKET;

    rows = store.candidate_bodies();
    buckets: dict[str, list[dict]] = {};
    order: list[str] = [];
    for row in rows {
        if _is_lifecycle(str(row["name"])) {
            continue;
        }
        bkey = _bucket_key(row);
        if bkey not in buckets {
            buckets[bkey] = [];
            order.append(bkey);
        }
        buckets[bkey].append(row);
    }

    groups: list[FuzzyGroup] = [];
    skipped: list[dict] = [];
    for bkey in order {
        rowset: list[dict] = list(buckets[bkey]);
        rowset.sort(key=(lambda r: dict : str(r["symbol_id"])));
        if len(rowset) < 2 {
            continue;
        }
        if len(rowset) > cap {
            skipped.append({"bucket": bkey, "size": len(rowset)});
            continue;
        }
        shs: list[set] = [
            _shingles(
                str(r["struct_tokens"]).split("\x1f") if r["struct_tokens"] else [], kk
            ) for r in rowset
        ];
        n = len(rowset);
        parent: dict[int, int] = {i: i for i in range(n)};
        for i in range(n) {
            for j in range(i + 1, n) {
                sim = _jaccard(shs[i], shs[j]);
                if sim >= thr {
                    _union(parent, i, j);
                }
            }
        }
        comps: dict[int, list[int]] = {};
        comp_order: list[int] = [];
        for i in range(n) {
            cr = _find(parent, i);
            if cr not in comps {
                comps[cr] = [];
                comp_order.append(cr);
            }
            comps[cr].append(i);
        }
        for croot in comp_order {
            idxs = comps[croot];
            if len(idxs) < 2 {
                continue;
            }
            struct_hashes = {str(rowset[i]["structural_hash"]) for i in idxs};
            if len(struct_hashes) < 2 {
                continue;
            }
            sites = {_distinct_key(rowset[i]) for i in idxs};
            if len(sites) < 2 {
                continue;
            }
            idx_list = sorted(idxs);
            sim_vals: list[float] = [];
            for ai in range(len(idx_list)) {
                for bj in range(ai + 1, len(idx_list)) {
                    sim_vals.append(_jaccard(shs[idx_list[ai]], shs[idx_list[bj]]));
                }
            }
            min_sim = min(sim_vals) if sim_vals else thr;
            mean_sim = (sum(sim_vals) / len(sim_vals)) if sim_vals else thr;

            members = [_build_member(store, rowset[i]) for i in idxs];
            member_ids = [m.symbol_id for m in members];
            copies_saved = len(members) - 1;
            lines_saved = int(
                round(copies_saved * _median([m.line_count for m in members]))
            );
            reach = _reach(members);

            base = (
                0.6 * _sat(float(lines_saved), 200.0) + 0.25 * _sat(
                    float(copies_saved), 6.0
                ) + 0.15 * _sat(float(reach), 40.0)
            );
            payoff = base * mean_sim;
            groups.append(
                FuzzyGroup(
                    group_id=_group_id(member_ids, thr),
                    kind="fuzzy",
                    arity=int(rowset[idxs[0]]["arity"]),
                    is_async=bool(rowset[idxs[0]]["is_async"]),
                    is_gen=bool(rowset[idxs[0]]["is_gen"]),
                    size_band=int(rowset[idxs[0]]["size_band"]),
                    threshold=thr,
                    members=members,
                    structural_hashes=sorted(struct_hashes),
                    min_similarity=min_sim,
                    mean_similarity=mean_sim,
                    copies_saved=copies_saved,
                    lines_saved=lines_saved,
                    reach=reach,
                    payoff=payoff
                )
            );
        }
    }

    groups.sort(key=(lambda g: FuzzyGroup : (-g.payoff, g.group_id)));
    return (groups, skipped);
}


def fuzzy_summary(g: FuzzyGroup) -> dict {
    return {
        "group_id": g.group_id,
        "kind": g.kind,
        "arity": g.arity,
        "is_async": g.is_async,
        "size_band": g.size_band,
        "threshold": g.threshold,
        "min_similarity": g.min_similarity,
        "mean_similarity": g.mean_similarity,
        "member_count": len(g.members),
        "members": [
            {"name": m.name, "owner": m.owner_name, "module_path": m.module_path}
            for m in g.members
        ],
        "copies_saved": g.copies_saved,
        "lines_saved": g.lines_saved,
        "reach": g.reach,
        "payoff": g.payoff
    };
}


def fuzzy_packet(store: FactStore, g: FuzzyGroup) -> dict {
    members: list[dict] = [];
    citations: list[str] = [];
    for m in g.members {
        row = store.symbol_row(m.symbol_id);
        access = str(row["access"]) if row is not None else "";
        cites = ["sym:" + m.symbol_id, "body:" + m.symbol_id];
        citations.extend(cites);
        members.append(
            {
                "symbol_id": m.symbol_id,
                "name": m.name,
                "owner_id": m.owner_id,
                "owner_name": m.owner_name,
                "module_path": m.module_path,
                "body_file": m.body_file,
                "body_pos_start": m.body_pos_start,
                "body_pos_end": m.body_pos_end,
                "stmt_pos_start": m.stmt_pos_start,
                "stmt_pos_end": m.stmt_pos_end,
                "visibility": access,
                "completeness": m.completeness,
                "line_count": m.line_count,
                "stmt_count": m.stmt_count,
                "exact_hash": m.exact_hash,
                "vector": m.vector,
                "callers": m.callers,
                "callees": store.callees_of(m.symbol_id),
                "citations": cites
            }
        );
    }
    return {
        "group_id": g.group_id,
        "kind": g.kind,
        "tier": g.kind,
        "arity": g.arity,
        "is_async": g.is_async,
        "is_gen": g.is_gen,
        "size_band": g.size_band,
        "structural_hashes": g.structural_hashes,
        "canonical_member": g.members[0].symbol_id if g.members else "",
        "canonical_vector": g.members[0].vector if g.members else [],
        "members": members,
        "evidence": {
            "tier": "fuzzy",
            "threshold": g.threshold,
            "min_similarity": g.min_similarity,
            "mean_similarity": g.mean_similarity,
            "structural_hashes": g.structural_hashes,
            "chained": g.min_similarity < g.threshold
        },
        "verify": reuse_verify_questions("fuzzy"),
        "payoff": {
            "score": g.payoff,
            "copies_saved": g.copies_saved,
            "lines_saved": g.lines_saved,
            "reach": g.reach
        },
        "citations": citations,
        "cite_index": cite_index(store, citations)
    };
}
