"""Reuse refactorability gate (contract-v2 step 4): a structural clone group is
scored by how cleanly its members collapse into one definition. Members differ
only in literal values and local names (the struct hash keeps callees/shape), so
literal divergence = parameters, name divergence = pure alpha-rename. These tests
drive find_clone_groups over hand-built bodies with controlled vectors and pin
suggested_shape, param_count, refactorability, and the adjusted-payoff ordering.
"""

import from jaclang.prune.extract { FactSet, ModuleFact }
import from jaclang.prune.bodies { BodyFact }
import from jaclang.prune.factstore { FactStore }
import from jaclang.prune.clones { find_clone_groups, group_summary }


glob _MOD = "/proj/a.jac";


def _body(
    sid: str,
    name: str,
    struct_hash: str,
    exact_hash: str,
    vector: str,
    owner_id: str = "",
    line_count: int = 8
) -> BodyFact {
    return BodyFact(
        symbol_id=sid,
        name=name,
        module_path=_MOD,
        owner_id=owner_id,
        owner_name=("C" + owner_id) if owner_id else "",
        body_file=_MOD,
        body_pos_start=0,
        body_pos_end=80,
        stmt_pos_start=5,
        stmt_pos_end=75,
        exact_hash=exact_hash,
        structural_hash=struct_hash,
        arity=1,
        is_async=False,
        is_gen=False,
        stmt_count=5,
        line_count=line_count,
        size_band=1,
        completeness="complete",
        vector=vector,
        stmt_seq=""
    );
}


def _groups(bodies: list[BodyFact]) -> list {
    facts = FactSet(
        modules=[
            ModuleFact(path=_MOD, module_name="a", content_hash="h", role="source")
        ],
        bodies=bodies
    );
    s = FactStore(db_path=":memory:");
    s.open();
    s.sync(facts);
    gs = find_clone_groups(s);
    s.close();
    return gs;
}


def _by_name(groups: list, name: str) -> any {
    for g in groups {
        if name in {m.name for m in g.members} {
            return g;
        }
    }
    return None;
}


test "refactor: byte-identical members hoist verbatim at refactorability 1.0" {
    g = _by_name(
        _groups(
            [
                _body("x1", "ex1", "SE", "EE", "handler\n'x'\npayload"),
                _body("x2", "ex2", "SE", "EE", "handler\n'x'\npayload")
            ]
        ),
        "ex1"
    );
    assert g is not None;
    assert g.kind == "exact";
    assert g.refactorability == 1.0;
    assert g.param_count == 0;
    assert g.suggested_shape == "hoist-shared-helper";
}


test "refactor: one divergent literal slot suggests parametrize" {
    g = _by_name(
        _groups(
            [
                _body("p1", "send_css", "SP", "EP1", "handler\n'text/css'\npayload"),
                _body("p2", "send_js", "SP", "EP2", "handler\n'app/js'\npayload")
            ]
        ),
        "send_css"
    );
    assert g is not None;
    assert g.kind == "structural";
    assert g.param_count == 1;
    assert g.suggested_shape == "parametrize";
    assert g.refactorability > 0.5;
}


# Members differing only in local NAMES are alpha-equivalent: no parameter is
# needed, so the shape is a verbatim hoist even though the bytes differ.
test "refactor: local-name-only divergence is a rename, not a parameter" {
    g = _by_name(
        _groups(
            [
                _body("r1", "r1fn", "SR", "ER1", "css\n'x'\nout"),
                _body("r2", "r2fn", "SR", "ER2", "code\n'x'\nresult")
            ]
        ),
        "r1fn"
    );
    assert g is not None;
    assert g.param_count == 0;
    assert g.suggested_shape == "hoist-shared-helper";
    assert g.refactorability >= 0.85;
}


# Vectors that share no tokens are a coincidental structural match: merging just
# relocates complexity, so the gate floors refactorability and flags a template.
test "refactor: zero token overlap floors refactorability to a template" {
    g = _by_name(
        _groups(
            [
                _body("n1", "n1fn", "SN", "EN1", "'a'\n'b'\n'c'"),
                _body("n2", "n2fn", "SN", "EN2", "'x'\n'y'\n'z'")
            ]
        ),
        "n1fn"
    );
    assert g is not None;
    assert g.lcs_ratio == 0.0;
    assert g.refactorability == 0.1;
    assert g.suggested_shape == "extract-template";
}


test "refactor: identical methods on distinct classes hoist to a base" {
    g = _by_name(
        _groups(
            [
                _body("b1", "m", "SB", "EB", "self\n'k'", owner_id="1"),
                _body("b2", "m", "SB", "EB", "self\n'k'", owner_id="2")
            ]
        ),
        "m"
    );
    assert g is not None;
    assert g.kind == "exact";
    assert g.suggested_shape == "hoist-to-base";
}


# The adjusted payoff downweights low-refactorability groups: with equal raw
# payoff, the clean exact hoist must outrank the coincidental template so the
# harvestable candidate floats to the top.
test "refactor: adjusted payoff ranks a clean hoist above an equal-raw template" {
    groups = _groups(
        [
            _body("e1", "ex1", "SE", "EE", "handler\n'x'\npayload", line_count=8),
            _body("e2", "ex2", "SE", "EE", "handler\n'x'\npayload", line_count=8),
            _body("t1", "t1fn", "SN", "ET1", "'a'\n'b'\n'c'", line_count=8),
            _body("t2", "t2fn", "SN", "ET2", "'x'\n'y'\n'z'", line_count=8)
        ]
    );
    assert len(groups) == 2;
    exact = _by_name(groups, "ex1");
    template = _by_name(groups, "t1fn");
    assert abs(exact.payoff - template.payoff) < 1e-9;
    assert groups[0].group_id == exact.group_id;
    summ = group_summary(exact);
    # refactorability 1.0 leaves the adjusted payoff equal to the raw payoff
    assert summ["adjusted_payoff"] == round(exact.payoff, 4);
    assert group_summary(template)["adjusted_payoff"] < template.payoff;
}
