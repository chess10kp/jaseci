"""Phase-1 unit tests: role classification + campaign config precedence."""

import from jaclang.prune.manifest { FileRole, ManifestEntry, classify, role_label }
import from jaclang.prune.campaign {
    resolve_campaign,
    parse_risk_tier,
    RiskTier,
    DEFAULT_RECIPES
}

glob GLOBS = ["*_gen.jac", "gen_*.jac"];

test "impl annex is classified as impl-annex" {
    assert classify("/proj/jaclang/cli/foo.impl.jac", GLOBS) == FileRole.IMPL_ANNEX;
}

test "fixtures directory is a fixture" {
    assert classify("/proj/tests/fixtures/sample.jac", GLOBS) == FileRole.FIXTURE;
}

test "test files are classified as test" {
    assert classify("/proj/foo.test.jac", GLOBS) == FileRole.TEST;
    assert classify("/proj/tests/test_bar.jac", GLOBS) == FileRole.TEST;
}

test "vendored code is classified as vendored" {
    assert classify("/proj/jaclang/vendor/typeshed/x.jac", GLOBS) == FileRole.VENDORED;
}

test "generated glob is classified as generated" {
    assert classify("/proj/gen_parser.jac", GLOBS) == FileRole.GENERATED;
    assert classify("/proj/table_gen.jac", GLOBS) == FileRole.GENERATED;
}

test "plain source is source" {
    assert classify("/proj/jaclang/prune/manifest.jac", GLOBS) == FileRole.SOURCE;
}

test "impl-annex fixture beats test/generated ordering" {
    # a .impl.jac under tests/ must still be impl-annex (more specific)
    assert classify("/proj/tests/foo.impl.jac", GLOBS) == FileRole.IMPL_ANNEX;
}

test "only source and impl-annex are live" {
    src = ManifestEntry(
        path="a.jac", role=FileRole.SOURCE, content_hash="", module_name="a"
    );
    annex = ManifestEntry(
        path="a.impl.jac", role=FileRole.IMPL_ANNEX, content_hash="", module_name="a"
    );
    fix = ManifestEntry(
        path="f.jac", role=FileRole.FIXTURE, content_hash="", module_name="f"
    );
    assert src.is_live();
    assert annex.is_live();
    assert not fix.is_live();
}

test "role labels are stable kebab strings" {
    assert role_label(FileRole.IMPL_ANNEX) == "impl-annex";
    assert role_label(FileRole.SOURCE) == "source";
}

test "cli flags override toml config" {
    toml_cfg = {"recipes": ["from-toml"], "risk_ceiling": "risky"};
    c = resolve_campaign(
        paths=["/proj"],
        project_root="/proj",
        toml_config=toml_cfg,
        recipes=["from-cli"],
        risk_ceiling="moderate"
    );
    assert c.recipes == ["from-cli"];
    assert c.risk_ceiling == RiskTier.MODERATE;
}

test "toml config used when no cli override" {
    toml_cfg = {"recipes": ["only-toml"]};
    c = resolve_campaign(paths=["/proj"], project_root="/proj", toml_config=toml_cfg);
    assert c.recipes == ["only-toml"];
}

test "defaults apply with empty config" {
    c = resolve_campaign(paths=["/proj"], project_root="/proj", toml_config={});
    assert c.recipes == DEFAULT_RECIPES;
    assert c.risk_ceiling == RiskTier.SAFE;
}

test "parse_risk_tier is case-insensitive and defaults safe" {
    assert parse_risk_tier("MODERATE") == RiskTier.MODERATE;
    assert parse_risk_tier("bogus") == RiskTier.SAFE;
}
