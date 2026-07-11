import hashlib;
import from jaclang.prune.factstore { FactStore }
import from jaclang.prune.finding { reuse_verify_questions }


glob REUSE_QUERY_VERSION = "1",
     _LIFECYCLE_NAMES = {"init", "postinit"};


obj CloneMember {
    has symbol_id: str,
        name: str,
        owner_id: str,
        owner_name: str,
        module_path: str,
        body_file: str,
        body_pos_start: int,
        body_pos_end: int,
        stmt_pos_start: int,
        stmt_pos_end: int,
        exact_hash: str,
        line_count: int,
        stmt_count: int,
        completeness: str,
        vector: list[str],
        callers: list[str];
}


obj CloneGroup {
    has group_id: str,
        kind: str,
        arity: int,
        is_async: bool,
        size_band: int,
        structural_hash: str,
        members: list[CloneMember],
        exact_subgroups: list[list[str]],
        copies_saved: int,
        lines_saved: int,
        reach: int,
        payoff: float;
}


obj ClassRollup {
    has rollup_id: str,
        class_ids: list[str],
        class_names: list[str],
        group_ids: list[str],
        shared_method_count: int,
        lines_saved: int,
        payoff: float,
        recommendation: str;
}


def _is_lifecycle(name: str) -> bool {
    if name in _LIFECYCLE_NAMES {
        return True;
    }
    return name.startswith("__") and name.endswith("__");
}


def _owner_key(row: dict) -> str {
    oid = str(row["owner_id"]);
    if oid {
        return "cls:" + oid;
    }
    return "mod:" + str(row["module_path"]);
}


def _distinct_key(row: dict) -> str {
    return _owner_key(row) + "::" + str(row["name"]);
}


def _median(vals: list[int]) -> float {
    if not vals {
        return 0.0;
    }
    s = sorted(vals);
    n = len(s);
    mid = n // 2;
    if n % 2 == 1 {
        return float(s[mid]);
    }
    return (s[mid - 1] + s[mid]) / 2.0;
}


def _sat(x: float, cap: float) -> float {
    if cap <= 0.0 {
        return 0.0;
    }
    return min(x, cap) / cap;
}


def _group_id(structural_hash: str, member_ids: list[str]) -> str {
    key = "|".join([REUSE_QUERY_VERSION, structural_hash] + sorted(member_ids));
    return "reuse:grp:" + hashlib.sha256(key.encode("utf-8")).hexdigest()[:16];
}


def _build_member(store: FactStore, row: dict) -> CloneMember {
    vec = str(row["vector"]).split("\n") if row["vector"] else [];
    return CloneMember(
        symbol_id=str(row["symbol_id"]),
        name=str(row["name"]),
        owner_id=str(row["owner_id"]),
        owner_name=str(row["owner_name"]),
        module_path=str(row["module_path"]),
        body_file=str(row["body_file"]),
        body_pos_start=int(row["body_pos_start"]),
        body_pos_end=int(row["body_pos_end"]),
        stmt_pos_start=int(row["stmt_pos_start"]),
        stmt_pos_end=int(row["stmt_pos_end"]),
        exact_hash=str(row["exact_hash"]),
        line_count=int(row["line_count"]),
        stmt_count=int(row["stmt_count"]),
        completeness=str(row["completeness"]),
        vector=vec,
        callers=store.callers_of(str(row["symbol_id"]))
    );
}


def _exact_subgroups(members: list[CloneMember]) -> list[list[str]] {
    order: list[str] = [];
    buckets: dict[str, list[str]] = {};
    for m in members {
        if m.exact_hash not in buckets {
            buckets[m.exact_hash] = [];
            order.append(m.exact_hash);
        }
        buckets[m.exact_hash].append(m.symbol_id);
    }
    out: list[list[str]] = [];
    for h in order {
        if len(buckets[h]) >= 2 {
            out.append(buckets[h]);
        }
    }
    return out;
}


def _reach(members: list[CloneMember]) -> int {
    callers: set = set();
    for m in members {
        for c in m.callers {
            callers.add(c);
        }
    }
    return len(callers);
}


def find_clone_groups(store: FactStore) -> list[CloneGroup] {
    rows = store.candidate_bodies();
    order: list[str] = [];
    by_struct: dict[str, list[dict]] = {};
    for row in rows {
        if _is_lifecycle(str(row["name"])) {
            continue;
        }
        sh = str(row["structural_hash"]);
        if sh not in by_struct {
            by_struct[sh] = [];
            order.append(sh);
        }
        by_struct[sh].append(row);
    }

    groups: list[CloneGroup] = [];
    for sh in order {
        rowset = by_struct[sh];
        if len(rowset) < 2 {
            continue;
        }
        sites: set = set();
        for r in rowset {
            sites.add(_distinct_key(r));
        }
        if len(sites) < 2 {
            continue;
        }
        members = [_build_member(store, r) for r in rowset];
        subgroups = _exact_subgroups(members);
        all_exact = len(subgroups) == 1 and len(subgroups[0]) == len(members);
        kind = "exact" if all_exact else "structural";
        member_ids = [m.symbol_id for m in members];
        copies_saved = len(members) - 1;
        lines_saved = int(
            round(copies_saved * _median([m.line_count for m in members]))
        );
        reach = _reach(members);
        payoff = (
            0.6 * _sat(float(lines_saved), 200.0) + 0.25 * _sat(
                float(copies_saved), 6.0
            ) + 0.15 * _sat(float(reach), 40.0)
        );
        groups.append(
            CloneGroup(
                group_id=_group_id(sh, member_ids),
                kind=kind,
                arity=int(rowset[0]["arity"]),
                is_async=bool(rowset[0]["is_async"]),
                size_band=int(rowset[0]["size_band"]),
                structural_hash=sh,
                members=members,
                exact_subgroups=subgroups,
                copies_saved=copies_saved,
                lines_saved=lines_saved,
                reach=reach,
                payoff=payoff
            )
        );
    }

    groups.sort(key=(lambda g : (-g.payoff, g.group_id)));
    return groups;
}


def _class_set_key(group: CloneGroup) -> (str | None) {
    ids: set = set();
    for m in group.members {
        if not m.owner_id {
            return None;
        }
        ids.add(m.owner_id);
    }
    if len(ids) < 2 {
        return None;
    }
    return "|".join(sorted(ids));
}


def find_class_rollups(groups: list[CloneGroup]) -> list[ClassRollup] {
    order: list[str] = [];
    by_set: dict[str, list[CloneGroup]] = {};
    names_by_set: dict[str, list[str]] = {};
    for g in groups {
        key = _class_set_key(g);
        if key is None {
            continue;
        }
        if key not in by_set {
            by_set[key] = [];
            order.append(key);
            names: list[str] = [];
            seen: set = set();
            for m in g.members {
                if m.owner_id not in seen {
                    seen.add(m.owner_id);
                    names.append(m.owner_name);
                }
            }
            names_by_set[key] = sorted(names);
        }
        by_set[key].append(g);
    }

    rollups: list[ClassRollup] = [];
    for key in order {
        gs = by_set[key];
        if len(gs) < 2 {
            continue;
        }
        class_ids = key.split("|");
        gids = sorted([g.group_id for g in gs]);
        lines_saved = 0;
        for g in gs {
            lines_saved += g.lines_saved;
        }
        payoff = 0.0;
        for g in gs {
            payoff += g.payoff;
        }
        rid = "reuse:roll:" + hashlib.sha256(
            ("|".join([REUSE_QUERY_VERSION, key] + gids)).encode("utf-8")
        ).hexdigest()[:16];
        rollups.append(
            ClassRollup(
                rollup_id=rid,
                class_ids=class_ids,
                class_names=names_by_set[key],
                group_ids=gids,
                shared_method_count=len(gs),
                lines_saved=lines_saved,
                payoff=payoff,
                recommendation="hoist-shared-methods-to-common-base"
            )
        );
    }
    rollups.sort(key=(lambda r : (-r.payoff, r.rollup_id)));
    return rollups;
}


def _member_citations(m: CloneMember) -> list[str] {
    return ["sym:" + m.symbol_id, "body:" + m.symbol_id];
}


def group_summary(
    g: CloneGroup, probe: dict | None = None, history: dict | None = None
) -> dict {
    out = {
        "group_id": g.group_id,
        "kind": g.kind,
        "arity": g.arity,
        "is_async": g.is_async,
        "structural_hash": g.structural_hash,
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
    if probe is not None {
        out["probe"] = probe.get("status", "");
    }
    if history is not None and history.get("available") {
        out["tandem_commits"] = history.get("tandem_commits", 0);
        out["tandem_ratio"] = history.get("tandem_ratio", 0.0);
    }
    return out;
}


def group_packet(
    store: FactStore,
    g: CloneGroup,
    probe: dict | None = None,
    history: dict | None = None
) -> dict {
    members: list[dict] = [];
    citations: list[str] = [];
    for m in g.members {
        row = store.symbol_row(m.symbol_id);
        access = str(row["access"]) if row is not None else "";
        cites = _member_citations(m);
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
    canonical = g.members[0].vector if g.members else [];
    evidence = {"tier": g.kind, "structural_hash": g.structural_hash};
    if probe is not None {
        evidence["probe"] = probe;
    }
    if history is not None {
        evidence["history"] = history;
    }
    return {
        "group_id": g.group_id,
        "kind": g.kind,
        "tier": g.kind,
        "structural_hash": g.structural_hash,
        "arity": g.arity,
        "is_async": g.is_async,
        "size_band": g.size_band,
        "exact_subgroups": g.exact_subgroups,
        "canonical_vector": canonical,
        "canonical_member": g.members[0].symbol_id if g.members else "",
        "members": members,
        "evidence": evidence,
        "verify": reuse_verify_questions(g.kind),
        "payoff": {
            "score": g.payoff,
            "copies_saved": g.copies_saved,
            "lines_saved": g.lines_saved,
            "reach": g.reach
        },
        "citations": citations
    };
}


def rollup_summary(r: ClassRollup) -> dict {
    return {
        "rollup_id": r.rollup_id,
        "recommendation": r.recommendation,
        "class_ids": r.class_ids,
        "class_names": r.class_names,
        "group_ids": r.group_ids,
        "shared_method_count": r.shared_method_count,
        "lines_saved": r.lines_saved,
        "payoff": r.payoff
    };
}
