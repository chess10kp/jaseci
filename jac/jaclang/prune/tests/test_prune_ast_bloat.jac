"""AST-derived bloat detector tests.

The detector is report-only and works from persisted compiler body facts:
normalized equivalent callable bodies and unusually large callable ASTs.
"""

import from jaclang.prune.extract { FactSet, ModuleFact, SymbolFact }
import from jaclang.prune.bodies { BodyFact }
import from jaclang.prune.factstore { FactStore }
import from jaclang.prune.veto { VetoIndex }
import from jaclang.prune.detectors { detect_ast_bloat }
import from jaclang.prune.finding { classify }
import from jaclang.prune.campaign { RiskTier, Disposition }


glob _MOD = "/pkg/dispatch.jac";


def _sym(sid: str, name: str, pos: int) -> SymbolFact {
    return SymbolFact(
        id=sid,
        module_path=_MOD,
        name=name,
        kind="ability",
        access="public",
        imported=False,
        parent_id="",
        decl_pos_start=pos,
        decl_pos_end=pos + 10,
        decl_line=pos + 1,
        scope_chain=""
    );
}


def _body(
    sid: str,
    name: str,
    structural_hash: str,
    stmt_count: int,
    line_count: int,
    pos: int
) -> BodyFact {
    return BodyFact(
        symbol_id=sid,
        name=name,
        module_path=_MOD,
        owner_id="",
        owner_name="",
        body_file=_MOD,
        body_pos_start=pos,
        body_pos_end=pos + line_count * 10,
        stmt_pos_start=pos + 1,
        stmt_pos_end=pos + line_count * 10 - 1,
        exact_hash=structural_hash,
        structural_hash=structural_hash,
        arity=1,
        is_async=False,
        is_gen=False,
        stmt_count=stmt_count,
        line_count=line_count,
        size_band=1,
        completeness="complete"
    );
}


def _store -> FactStore {
    facts = FactSet(
        modules=[
            ModuleFact(
                path=_MOD, module_name="pkg.dispatch", content_hash="a", role="source"
            )
        ],
        symbols=[
            _sym("s1", "attach_role", 1),
            _sym("s2", "attach_access", 20),
            _sym("s3", "attach_alias", 40),
            _sym("s4", "dispatch", 60)
        ],
        bodies=[
            _body("s1", "attach_role", "same", 2, 4, 1),
            _body("s2", "attach_access", "same", 2, 4, 20),
            _body("s3", "attach_alias", "same", 2, 4, 40),
            _body("s4", "dispatch", "large", 32, 8, 60)
        ]
    );
    store = FactStore(db_path=":memory:");
    store.open();
    store.sync(facts);
    return store;
}


test "ast-bloat reports repeated normalized body families" {
    store = _store();
    findings = detect_ast_bloat(store, VetoIndex());
    store.close();
    family = [
        f
        for f in findings
        if f.plan_meta.get("shape") == "duplicate-ast-family"
    ];
    assert len(family) == 1 , [f.name for f in findings];
    f = family[0];
    assert f.module_path == _MOD;
    assert int(f.plan_meta["member_count"]) == 3;
    assert int(f.plan_meta["copies_saved"]) == 2;
    assert f.related == ["sym:s1", "sym:s2", "sym:s3"];
}


test "ast-bloat reports oversized AST bodies separately" {
    store = _store();
    findings = detect_ast_bloat(store, VetoIndex());
    store.close();
    large = [
        f
        for f in findings
        if f.plan_meta.get("shape") == "large-ast-body"
    ];
    assert len(large) == 1 , [f.name for f in findings];
    assert large[0].symbol_id == "s4";
    assert int(large[0].plan_meta["stmt_count"]) == 32;
}


test "ast-bloat is report-only under every risk ceiling" {
    store = _store();
    findings = detect_ast_bloat(store, VetoIndex());
    store.close();
    for f in findings {
        candidate = classify(f, RiskTier.SAFE);
        assert candidate.disposition == Disposition.REPORT_ONLY , f.name;
        assert candidate.risk == RiskTier.MODERATE , f.name;
    }
}
