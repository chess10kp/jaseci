import hashlib;

import from jaclang.prune.factquery { ToolSurface }
import from jaclang.prune.factstore { FactStore }
import from jaclang.prune.finding { Finding, Evidence, Polarity }


obj Hypothesis {
    has task: str,
        summary: str,
        anchor_id: str,
        cited: list[str],
        bundle: dict;

    def key -> str {
        payload = self.task + "|" + "|".join(sorted(self.cited));
        return hashlib.sha256(payload.encode("utf-8")).hexdigest()[:16];
    }
}


obj Verdict {
    has decision: str,
        rationale: str = "",
        citations: list[str] = [];
}


obj AgentModel {
    def judge(hyp: Hypothesis) -> Verdict {
        return Verdict(decision="abstain", rationale="no model configured");
    }
}


obj HeuristicModel(AgentModel) {
    def judge(hyp: Hypothesis) -> Verdict {
        b: any = hyp.bundle;
        if hyp.task == "redundant-layer" {
            return Verdict(
                decision="confirm",
                rationale="fan-in-1 forwarding chain of "
                f"{int(b.get('chain_len', 0))} links",
                citations=hyp.cited
            );
        }
        if hyp.task == "single-use-wrapper" {
            return Verdict(
                decision="abstain",
                rationale="single call site, but body-shape unconfirmed"
            );
        }
        if hyp.task == "parallel-impl" {
            shared = int(b.get("shared_callees", 0));
            if shared >= 1 {
                return Verdict(
                    decision="confirm",
                    rationale="same-name symbols, disjoint callers, "
                    f"{shared} shared callee(s)",
                    citations=hyp.cited
                );
            }
            return Verdict(decision="abstain", rationale="no shared callees");
        }
        if hyp.task == "finding-cluster" {
            n = int(b.get("member_count", 0));
            if n >= 3 {
                return Verdict(
                    decision="confirm",
                    rationale=f"{n} detector findings co-located in one module",
                    citations=hyp.cited
                );
            }
            return Verdict(decision="abstain", rationale="cluster too small");
        }
        return Verdict(decision="abstain", rationale="unknown task");
    }
}


obj ReplayModel(AgentModel) {
    has scripted: dict[str, Verdict] = {};

    def judge(hyp: Hypothesis) -> Verdict {
        v = self.scripted.get(hyp.key());
        if v is not None {
            return v;
        }
        return Verdict(decision="abstain", rationale="no scripted verdict");
    }
}


def _callable_ids(tools: ToolSurface) -> set {
    store: FactStore = tools.store;
    return {str(s["id"]) for s in store.callable_symbols()};
}


def _sole_forward_edges(tools: ToolSurface) -> dict[str, str] {
    store: FactStore = tools.store;
    callable_ids = _callable_ids(tools);

    def fn_callers(sid: str) -> list[str] {
        return [
            c
            for c in store.callers_of(sid)
            if c in callable_ids
        ];
    }
    def fn_callees(sid: str) -> list[str] {
        return [
            c
            for c in store.callees_of(sid)
            if c in callable_ids
        ];
    }

    out: dict[str, str] = {};
    for (caller, callee) in store.call_edges() {
        if caller not in callable_ids or callee not in callable_ids {
            continue;
        }
        callers_b = fn_callers(callee);
        callees_a = fn_callees(caller);
        if len(callers_b) == 1
        and len(callees_a) == 1
        and callers_b[0] == caller
        and callees_a[0] == callee {
            out[caller] = callee;
        }
    }
    return out;
}


def _chain_from(start: str, forward: dict[str, str]) -> list[str] {
    chain: list[str] = [start];
    seen = {start};
    cur = start;
    while cur in forward {
        nxt = forward[cur];
        if nxt in seen {
            break;
        }
        chain.append(nxt);
        seen.add(nxt);
        cur = nxt;
    }
    return chain;
}


def gen_wrapper_chains(tools: ToolSurface) -> list[Hypothesis] {
    forward = _sole_forward_edges(tools);
    targets = set(forward.values());
    heads = sorted(
        [
            a
            for a in forward.keys()
            if a not in targets
        ]
    );
    out: list[Hypothesis] = [];
    for head in heads {
        chain = _chain_from(head, forward);
        names = [_name_of(tools, sid) for sid in chain];
        if len(chain) >= 3 {
            out.append(
                Hypothesis(
                    task="redundant-layer",
                    summary="pass-through wrapper chain "
                    f"({' -> '.join(names)}) collapses to one function",
                    anchor_id=head,
                    cited=chain,
                    bundle={"chain_len": len(chain), "names": names}
                )
            );
        } elif len(chain) == 2 {
            out.append(
                Hypothesis(
                    task="single-use-wrapper",
                    summary=f"'{names[0]}' is a single-use wrapper forwarding to "
                    f"'{names[1]}'",
                    anchor_id=head,
                    cited=chain,
                    bundle={"names": names}
                )
            );
        }
    }
    return out;
}


def gen_parallel_impls(tools: ToolSurface) -> list[Hypothesis] {
    store: FactStore = tools.store;
    callable_ids = _callable_ids(tools);
    by_name: dict[str, list] = {};
    for s in store.callable_symbols() {
        d: any = s;
        by_name.setdefault(str(d["name"]), []).append(d);
    }
    out: list[Hypothesis] = [];
    for (name, group) in sorted(by_name.items()) {
        if len(group) < 2 {
            continue;
        }
        n = len(group);
        i = 0;
        while i < n {
            j = i + 1;
            while j < n {
                a = group[i];
                b = group[j];
                if str(a["module_path"]) == str(b["module_path"]) {
                    j += 1;
                    continue;
                }
                aid = str(a["id"]);
                bid = str(b["id"]);
                callers_a = set(store.callers_of(aid));
                callers_b = set(store.callers_of(bid));
                callees_a = {
                    c
                    for c in store.callees_of(aid)
                    if c in callable_ids
                };
                callees_b = {
                    c
                    for c in store.callees_of(bid)
                    if c in callable_ids
                };
                shared_callees = callees_a & callees_b;
                disjoint = len(callers_a & callers_b) == 0;
                if disjoint and len(shared_callees) >= 1 {
                    cited = sorted([aid, bid] + list(shared_callees));
                    out.append(
                        Hypothesis(
                            task="parallel-impl",
                            summary=f"'{name}' has two parallel implementations "
                            "with disjoint callers and shared callees",
                            anchor_id=aid,
                            cited=cited,
                            bundle={
                                "name": name,
                                "shared_callees": len(shared_callees),
                                "impl_a": aid,
                                "impl_b": bid
                            }
                        )
                    );
                }
                j += 1;
            }
            i += 1;
        }
    }
    return out;
}


def gen_finding_clusters(
    tools: ToolSurface, findings: list[Finding], min_size: int = 3
) -> list[Hypothesis] {
    by_mod: dict[str, list[Finding]] = {};
    for f in findings {
        if f.symbol_id {
            by_mod.setdefault(f.module_path, []).append(f);
        }
    }
    out: list[Hypothesis] = [];
    for (mod, members) in sorted(by_mod.items()) {
        if len(members) < min_size {
            continue;
        }
        cited = sorted([m.symbol_id for m in members]);
        names = sorted([m.name for m in members]);
        out.append(
            Hypothesis(
                task="finding-cluster",
                summary=f"{len(members)} detector findings in "
                f"{tools.store.module_name(mod) or mod} likely share one "
                "root cause (obsolete subsystem)",
                anchor_id=members[0].symbol_id,
                cited=cited,
                bundle={"member_count": len(members), "names": names}
            )
        );
    }
    return out;
}


def _name_of(tools: ToolSurface, symbol_id: str) -> str {
    view = tools.query_symbol(symbol_id);
    return view.name if view is not None else symbol_id;
}


obj AgentAnalyzer {
    has tools: ToolSurface,
        model: AgentModel,
        max_findings: int = 50,
        max_hypotheses: int = 500,
        ledger: list[dict] = [],
        _cache: dict[str, Verdict] = {};

    def _judge_cached(hyp: Hypothesis) -> Verdict {
        k = hyp.key();
        cached = self._cache.get(k);
        if cached is not None {
            return cached;
        }
        v = self.model.judge(hyp);
        self._cache[k] = v;
        return v;
    }

    def _generate(findings: list[Finding]) -> list[Hypothesis] {
        hyps: list[Hypothesis] = [];
        hyps.extend(gen_wrapper_chains(self.tools));
        hyps.extend(gen_parallel_impls(self.tools));
        hyps.extend(gen_finding_clusters(self.tools, findings));

        seen: set = set();
        uniq: list[Hypothesis] = [];
        for h in hyps {
            k = h.key();
            if k in seen {
                continue;
            }
            seen.add(k);
            uniq.append(h);
        }
        uniq.sort(key=lambda h: Hypothesis : (h.task, h.key()));
        return uniq[:self.max_hypotheses];
    }

    def _to_finding(hyp: Hypothesis, v: Verdict) -> (Finding | None) {
        view = self.tools.query_symbol(hyp.anchor_id);
        if view is None {
            return None;
        }
        cited = v.citations or hyp.cited;

        if not self.tools.verify_citations(cited) {
            return None;
        }
        related = sorted(
            [
                c
                for c in cited
                if c != hyp.anchor_id
            ]
        );
        f = Finding(
            detector=f"agent-{hyp.task}",
            symbol_id=hyp.anchor_id,
            name=view.name,
            module_path=view.module_path,
            kind=view.kind,
            message=hyp.summary,
            pos_start=view.decl_line,
            pos_end=view.decl_line,
            line=view.decl_line,
            access=view.access,
            scope_chain=view.scope_chain,
            source="agent",
            citations=cited,
            related=related
        );
        f.add(
            Evidence(
                kind="agent-hypothesis",
                polarity=Polarity.SUPPORTS,
                detail=v.rationale or hyp.summary
            )
        );
        return f;
    }

    def analyze(findings: list[Finding]) -> list[Finding] {
        hyps = self._generate(findings);
        out: list[Finding] = [];
        for hyp in hyps {
            if len(out) >= self.max_findings {
                break;
            }
            v = self._judge_cached(hyp);
            entry: dict = {
                "task": hyp.task,
                "key": hyp.key(),
                "decision": v.decision,
                "rationale": v.rationale,
                "cited": len(hyp.cited)
            };
            if v.decision != "confirm" {
                entry["kept"] = False;
                self.ledger.append(entry);
                continue;
            }
            f = self._to_finding(hyp, v);
            if f is None {
                entry["kept"] = False;
                entry["dropped"] = "citation-verification-failed";
                self.ledger.append(entry);
                continue;
            }
            entry["kept"] = True;
            self.ledger.append(entry);
            out.append(f);
        }
        return out;
    }
}


enum AgentJudge { HEURISTIC = 1, NONE = 2, }


def parse_agent_judge(name: str) -> AgentJudge {
    key = name.strip().lower();
    table = {"heuristic": AgentJudge.HEURISTIC, "none": AgentJudge.NONE};
    return table.get(key, AgentJudge.HEURISTIC);
}


def build_judge(judge: AgentJudge) -> AgentModel {
    if judge == AgentJudge.HEURISTIC {
        return HeuristicModel();
    }
    return AgentModel();
}
