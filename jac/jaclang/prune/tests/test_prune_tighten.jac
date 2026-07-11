"""Tier-3 tests: the visibility-tightening advisory detector.

Hand-built fact sets exercise the cross-module reference semantics precisely:
a public symbol used only within its own module is a demote candidate; a
cross-module reference or a barrel re-export suppresses it; private symbols and
lifecycle names are never candidates.
"""

import from jaclang.prune.extract {
    FactSet,
    ModuleFact,
    SymbolFact,
    ReferenceFact,
    ImportFact
}
import from jaclang.prune.factstore { FactStore }
import from jaclang.prune.veto { VetoIndex }
import from jaclang.prune.detectors { detect_visibility_tightening }
import from jaclang.prune.finding { classify }
import from jaclang.prune.campaign { RiskTier, Disposition }


glob _MOD_A = "/pkg/a.jac",
     _MOD_B = "/pkg/b.jac",
     _INIT = "/pkg/__init__.jac";


def _sym(id: str, name: str, access: str) -> SymbolFact {
    return SymbolFact(
        id=id,
        module_path=_MOD_A,
        name=name,
        kind="object",
        access=access,
        imported=False,
        parent_id="",
        decl_pos_start=0,
        decl_pos_end=10,
        decl_line=1,
        scope_chain="pkg.a"
    );
}


def _ref(used: str, mod: str) -> ReferenceFact {
    return ReferenceFact(
        used_id=used,
        using_id="caller",
        module_path=mod,
        pos_start=100,
        pos_end=110,
        line=5,
        kind="call"
    );
}


def _store -> FactStore {
    facts = FactSet(
        modules=[
            ModuleFact(
                path=_MOD_A, module_name="pkg.a", content_hash="a", role="source"
            ),
            ModuleFact(
                path=_MOD_B, module_name="pkg.b", content_hash="b", role="source"
            ),
            ModuleFact(path=_INIT, module_name="pkg", content_hash="c", role="source")
        ],
        symbols=[
            _sym("s_internal", "InternalOnly", "public"),
            _sym("s_cross", "CrossUsed", "public"),
            _sym("s_reexport", "Reexported", "public"),
            _sym("s_priv", "PrivThing", "private"),
            _sym("s_aliascross", "AliasCrossUsed", "public"),
            _sym("s_reexbridge", "ReexportBridged", "public")
        ],
        refs=[
            _ref("s_internal", _MOD_A),
            _ref("s_cross", _MOD_B),
            _ref("s_priv", _MOD_A),
            # Real extraction records the cross-module use against the local
            # import alias id ("alias_b"), never the declaring symbol.
            _ref("alias_b", _MOD_B)
        ],
        imports=[
            ImportFact(
                module_path=_INIT,
                item_name="Reexported",
                alias="",
                resolved_id="s_reexport",
                resolved_path="",
                source_module_path="",
                pos_start=0,
                pos_end=10,
                line=1,
                is_from=True
            ),
            # Alias bridge: a plain cross-module from-import of AliasCrossUsed
            # into b.jac, binding the local alias "alias_b".
            ImportFact(
                module_path=_MOD_B,
                item_name="AliasCrossUsed",
                alias="",
                resolved_id="alias_b",
                resolved_path="",
                source_module_path=_MOD_A,
                pos_start=0,
                pos_end=10,
                line=1,
                is_from=True
            ),
            # Alias bridge for a barrel re-export: __init__ re-exports
            # ReexportBridged from a.jac, binding the local alias "alias_init".
            ImportFact(
                module_path=_INIT,
                item_name="ReexportBridged",
                alias="",
                resolved_id="alias_init",
                resolved_path="",
                source_module_path=_MOD_A,
                pos_start=0,
                pos_end=10,
                line=1,
                is_from=True
            )
        ]
    );
    store = FactStore(db_path=":memory:");
    store.open();
    store.sync(facts);
    return store;
}


def _names -> dict {
    store = _store();
    fs = detect_visibility_tightening(store, VetoIndex());
    store.close();
    out: dict = {};
    for f in fs {
        out[f.name] = f;
    }
    return out;
}


test "visibility-tightening flags a public symbol used only within its module" {
    fs = _names();
    assert "InternalOnly" in fs , list(fs.keys());
    f = fs["InternalOnly"];
    assert f.detector == "visibility-tightening";
    assert f.citations == ["sym:s_internal"];
    assert int(f.plan_meta["internal_uses"]) == 1;
    cand = classify(f, RiskTier.RISKY);
    assert cand.disposition == Disposition.REPORT_ONLY;
    assert cand.risk == RiskTier.MODERATE;
}


test "a cross-module reference suppresses the demote candidate" {
    fs = _names();
    assert "CrossUsed" not in fs , list(fs.keys());
}


test "a barrel re-export suppresses the demote candidate" {
    fs = _names();
    assert "Reexported" not in fs , list(fs.keys());
}


test "private symbols are never demote candidates" {
    fs = _names();
    assert "PrivThing" not in fs , list(fs.keys());
}


test "store: cross_module_use_count and is_reexported" {
    store = _store();
    assert store.cross_module_use_count("s_internal") == 0;
    assert store.cross_module_use_count("s_cross") == 1;
    assert store.is_reexported("s_reexport");
    assert not store.is_reexported("s_internal");
    store.close();
}


# Alias bridge: a cross-module use recorded against the importing module's local
# import alias must be attributed back to the declaring symbol via
# (source_module_path, item_name), not lost. Regressing this re-opens the
# extraction gap that made a library's public API look dead.
test "an alias-recorded cross-module use suppresses the demote candidate" {
    fs = _names();
    assert "AliasCrossUsed" not in fs , list(fs.keys());
}


test "an alias-bridged barrel re-export suppresses the demote candidate" {
    fs = _names();
    assert "ReexportBridged" not in fs , list(fs.keys());
}


test "store: alias bridge attributes cross-module and re-export via source path" {
    store = _store();
    assert store.cross_module_use_count("s_aliascross") == 1;
    assert store.external_use_count("s_aliascross") == 1;
    assert store.is_reexported("s_reexbridge");
    assert not store.is_reexported("s_aliascross");
    store.close();
}
