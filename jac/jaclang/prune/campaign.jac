import os;


enum RiskTier { SAFE = 1, MODERATE = 2, RISKY = 3, FORBIDDEN = 4, }


enum Disposition { AUTO_FIX = 1, PR_ONLY = 2, REPORT_ONLY = 3, }


enum OutputFormat { TABLE = 1, JSON = 2, SARIF = 3, }


enum PruneAction { REPORT = 1, FACTS = 2, FIX = 3, ANALYZE = 4, REUSE = 5, }


def parse_prune_action(name: str) -> (PruneAction | None) {
    key = name.strip().lower();
    table = {
        "report": PruneAction.REPORT,
        "facts": PruneAction.FACTS,
        "fix": PruneAction.FIX,
        "analyze": PruneAction.ANALYZE,
        "reuse": PruneAction.REUSE,

    };
    return table.get(key);
}


glob RISK_TIER_LABELS: dict[RiskTier, str] = {
         RiskTier.SAFE: "safe",
         RiskTier.MODERATE: "moderate",
         RiskTier.RISKY: "risky",
         RiskTier.FORBIDDEN: "forbidden",

     };


def risk_tier_label(tier: RiskTier) -> str {
    return RISK_TIER_LABELS.get(tier, "safe");
}


def parse_risk_tier(name: str) -> RiskTier {
    key = name.strip().lower();
    table = {
        "safe": RiskTier.SAFE,
        "moderate": RiskTier.MODERATE,
        "risky": RiskTier.RISKY,
        "forbidden": RiskTier.FORBIDDEN,

    };
    return table.get(key, RiskTier.SAFE);
}


def parse_output_format(name: str) -> OutputFormat {
    key = name.strip().lower();
    table = {
        "table": OutputFormat.TABLE,
        "json": OutputFormat.JSON,
        "sarif": OutputFormat.SARIF,

    };
    return table.get(key, OutputFormat.TABLE);
}


obj Campaign {
    has project_root: str,
        paths: list[str] = [],
        include_globs: list[str] = [],
        exclude: list[str] = [],
        recipes: list[str] = [],
        generated_globs: list[str] = [],
        risk_ceiling: RiskTier = RiskTier.SAFE,
        output_format: OutputFormat = OutputFormat.TABLE,
        suppression_file: str = "";

    def scope_paths -> list[str] {
        if self.paths {
            return [os.path.abspath(p) for p in self.paths];
        }
        return [self.project_root];
    }
}


glob DEFAULT_RECIPES = [
         "unused-imports",
         "private-dead-defs",
         "write-only-fields",
         "literal-dead-branch",

     ],
     DEFAULT_GENERATED_GLOBS = ["*_gen.jac", "gen_*.jac", "*.gen.jac"];


def resolve_campaign(
    paths: list[str],
    project_root: str,
    toml_config: dict | None = None,
    include_globs: list[str] | None = None,
    exclude: list[str] | None = None,
    recipes: list[str] | None = None,
    risk_ceiling: str = "",
    output_format: str = ""
) -> Campaign {
    cfg = toml_config or {};

    def pick_list(flag: list[str] | None, key: str, fallback: list[str]) -> list[str] {
        if flag {
            return flag;
        }
        val = cfg.get(key);
        if isinstance(val, list) {
            return [str(v) for v in val];
        }
        return fallback;
    }

    resolved_ceiling = risk_ceiling or str(cfg.get("risk_ceiling", "safe"));
    resolved_output = output_format or str(cfg.get("output", "table"));

    return Campaign(
        project_root=project_root,
        paths=paths,
        include_globs=pick_list(include_globs, "include", []),
        exclude=pick_list(exclude, "exclude", []),
        recipes=pick_list(recipes, "recipes", DEFAULT_RECIPES),
        generated_globs=pick_list(None, "generated", DEFAULT_GENERATED_GLOBS),
        risk_ceiling=parse_risk_tier(resolved_ceiling),
        output_format=parse_output_format(resolved_output),
        suppression_file=str(cfg.get("suppression_file", ""))
    );
}


def load_prune_config(project_root: str) -> dict {
    import from jaclang.jac0core.helpers { read_toml_with_encoding }
    toml_path = os.path.join(project_root, "jac.toml");
    if not os.path.exists(toml_path) {
        return {};
    }
    try {
        data = read_toml_with_encoding(toml_path);
    } except Exception {
        return {};
    }
    section = data.get("prune", {});
    return section if isinstance(section, dict) else {};
}
