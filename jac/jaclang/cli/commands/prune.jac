import from jaclang.cli.command { Arg, ArgKind }
import from jaclang.cli.registry { get_registry }

glob registry = get_registry();

@registry.command(
    name="prune",
    help="Compiler-backed dead/redundant-code cleanup (report, facts, fix)",
    tier="core",
    args=[
        Arg.create(
            "action",
            kind=ArgKind.POSITIONAL,
            default="report",
            help="Action: report, facts, fix, analyze, reuse, list, show"
        ),
        Arg.create(
            "paths",
            kind=ArgKind.MULTI,
            default=[],
            help="Paths to analyze (default: project root)"
        ),
        Arg.create(
            "exclude",
            kind=ArgKind.MULTI,
            default=[],
            help="Glob patterns to exclude from analysis"
        ),
        Arg.create(
            "recipe",
            dest="recipes",
            kind=ArgKind.MULTI,
            default=[],
            help="Restrict to named recipes (default: all Tier-1)"
        ),
        Arg.create(
            "risk_ceiling",
            default="",
            short="",
            help="Max risk tier to act on: safe, moderate, risky"
        ),
        Arg.create(
            "output", default="", help="Output format: table, json, sarif", short="o"
        ),
        Arg.create(
            "preview",
            typ=bool,
            default=False,
            short="",
            help="With 'fix': print diffs without writing"
        ),
        Arg.create(
            "apply",
            typ=bool,
            default=False,
            short="",
            help="With 'fix': write changes, validate, revert on failure"
        ),
        Arg.create(
            "model",
            default="heuristic",
            short="",
            help="With 'analyze': redundancy judge (heuristic, none)"
        ),
        Arg.create(
            "group",
            default="",
            short="",
            help="With 'reuse': emit the full evidence packet for one group id"
        ),
        Arg.create(
            "probe",
            typ=bool,
            default=False,
            short="",
            help="With 'reuse': dry-run the consolidation (parse+typecheck, revert)"
        ),
        Arg.create(
            "history",
            typ=bool,
            default=False,
            short="",
            help="With 'reuse': add git tandem-edit + divergence evidence"
        ),
        Arg.create(
            "windows",
            typ=bool,
            default=False,
            short="",
            help="With 'reuse': also mine repeated statement-window blocks"
        ),
        Arg.create(
            "fuzzy",
            typ=bool,
            default=False,
            short="",
            help="With 'reuse': also surface fuzzy (token-overlap) near-clones"
        ),
        Arg.create(
            "limit",
            typ=int,
            default=200,
            short="",
            help="With 'list': max rows to show before rank-suppressing the tail"
        ),

    ],
    examples=[
        ("jac prune report", "Report findings for the project"),
        ("jac prune report jac/jaclang/prune", "Report findings under a path"),
        ("jac prune facts", "Extract and summarize the fact store"),
        ("jac prune fix --preview", "Preview safe fixes as diffs"),
        ("jac prune fix --apply", "Apply and validate safe fixes"),
        ("jac prune analyze", "Report agent redundancy findings (report-only)"),
        ("jac prune reuse -o json", "Rank structural-duplicate candidate groups"),
        ("jac prune reuse --group <id> -o json", "Full evidence packet for a group"),
        ("jac prune reuse --probe -o json", "Dry-run consolidation of the top groups"),
        (
            "jac prune reuse --fuzzy -o json",
            "Also surface fuzzy token-overlap near-clones"
        ),
        ("jac prune list", "Ranked one-line index of all findings"),
        ("jac prune list -o json --limit 50", "Top 50 findings as JSON"),
        (
            "jac prune show <fingerprint> -o json",
            "Full v2 packet for one finding or reuse group"
        ),

    ],
    group="analysis"
)
def prune(
    action: str = "report",
    paths: (list | None) = None,
    exclude: (list | None) = None,
    recipes: (list | None) = None,
    risk_ceiling: str = "",
    output: str = "",
    preview: bool = False,
    apply: bool = False,
    model: str = "heuristic",
    group: str = "",
    probe: bool = False,
    history: bool = False,
    windows: bool = False,
    fuzzy: bool = False,
    limit: int = 200
) -> int;
