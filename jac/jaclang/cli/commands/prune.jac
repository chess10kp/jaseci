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
            help="Action: report, facts, fix"
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

    ],
    examples=[
        ("jac prune report", "Report findings for the project"),
        ("jac prune report jac/jaclang/prune", "Report findings under a path"),
        ("jac prune facts", "Extract and summarize the fact store"),
        ("jac prune fix --preview", "Preview safe fixes as diffs"),
        ("jac prune fix --apply", "Apply and validate safe fixes"),

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
    apply: bool = False
) -> int;
