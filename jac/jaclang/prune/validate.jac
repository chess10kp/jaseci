import os;
import from time { time }


obj Diag {
    has code: str,
        module_path: str,
        message: str;

    def key -> str {
        return f"{self.code}|{self.module_path}|{self.message}";
    }
}


obj Baseline {
    has keys: set = set();

    def is_new(d: Diag) -> bool {
        return d.key() not in self.keys;
    }
}


obj StageResult {
    has stage: str,
        ok: bool,
        detail: str = "",
        artifacts: list[str] = [];
}


obj ValidationResult {
    has ok: bool,
        stages: list[StageResult] = [],
        new_diags: list[str] = [],
        culprits: list[str] = [],
        wall_ms: int = 0;

    def failed_stage -> str {
        for s in self.stages {
            if not s.ok {
                return s.stage;
            }
        }
        return "";
    }

    def as_dict -> dict {
        return {
            "ok": self.ok,
            "failed_stage": self.failed_stage(),
            "stages": [
                {"stage": s.stage, "ok": s.ok, "detail": s.detail} for s in self.stages
            ],
            "new_diags": self.new_diags,
            "culprits": self.culprits,
            "wall_ms": self.wall_ms
        };
    }
}


def _compile_diags(source_paths: list[str]) -> list[Diag] {
    import from jaclang.prune.pipeline { compile_source_paths }
    (prog, _, _, _) = compile_source_paths(source_paths);
    out: list[Diag] = [];
    for alert in list(prog.errors_had) + list(prog.warnings_had) {
        out.append(_alert_to_diag(alert));
    }
    return out;
}


def _alert_to_diag(alert: any) -> Diag {
    code = "";
    if alert.code is not None {
        code = str(alert.code.code);
    }
    mod = "";
    if alert.loc is not None {
        mod = str(alert.loc.mod_path);
    }
    return Diag(code=code, module_path=mod, message=str(alert.msg));
}


def snapshot_baseline(source_paths: list[str]) -> Baseline {
    keys: set = set();
    for d in _compile_diags(source_paths) {
        keys.add(d.key());
    }
    return Baseline(keys=keys);
}


def _reparse_errors(path: str) -> int {
    import from jaclang.jac0core.program { JacProgram }
    import from jaclang.jac0core.compile_options { CompileOptions }
    prog = JacProgram();
    try {
        prog.compile(
            file_path=path,
            options=CompileOptions(
                type_check=False, no_cgen=True, force_target_program=True
            )
        );
    } except Exception {
        return -1;
    }
    return len(prog.errors_had);
}


def _stage_parse(touched_paths: list[str]) -> StageResult {
    bad: list[str] = [];
    for path in touched_paths {
        if _reparse_errors(path) != 0 {
            bad.append(path);
        }
    }
    if bad {
        return StageResult(
            stage="parse",
            ok=False,
            detail=f"{len(bad)} file(s) failed to re-parse",
            artifacts=bad
        );
    }
    return StageResult(
        stage="parse", ok=True, detail=f"{len(touched_paths)} file(s) re-parse clean"
    );
}


def _stage_typecheck(
    source_paths: list[str], baseline: Baseline
) -> tuple[StageResult, list[str]] {
    new_keys: list[str] = [];
    for d in _compile_diags(source_paths) {
        if baseline.is_new(d) {
            new_keys.append(d.key());
        }
    }
    if new_keys {
        return (
            StageResult(
                stage="typecheck",
                ok=False,
                detail=f"{len(new_keys)} new diagnostic(s) vs baseline",
                artifacts=new_keys
            ),
            new_keys
        );
    }
    return (
        StageResult(
            stage="typecheck", ok=True, detail="no new diagnostics vs baseline"
        ),
        []
    );
}


def validate_batch(
    touched_paths: list[str],
    source_paths: list[str],
    baseline: Baseline,
    run_format: bool = True
) -> ValidationResult {
    start = time();
    stages: list[StageResult] = [];
    new_diags: list[str] = [];

    parse = _stage_parse(touched_paths);
    stages.append(parse);
    if not parse.ok {
        return _finish(stages, new_diags, start);
    }

    if run_format {
        stages.append(_stage_format(touched_paths));
        if not stages[-1].ok {
            return _finish(stages, new_diags, start);
        }
    }

    (tc, new_diags) = _stage_typecheck(source_paths, baseline);
    stages.append(tc);
    return _finish(stages, new_diags, start);
}


def _finish(
    stages: list[StageResult], new_diags: list[str], start: float
) -> ValidationResult {
    ok = all(s.ok for s in stages);
    return ValidationResult(
        ok=ok, stages=stages, new_diags=new_diags, wall_ms=int((time() - start) * 1000)
    );
}


def _stage_format(touched_paths: list[str]) -> StageResult {
    unstable: list[str] = [];
    for path in touched_paths {
        formatted = _format_source(path);
        if formatted is None {
            continue;
        }
        try {
            with open(path, "rb") as fh {
                current = fh.read();
            }
        } except Exception {
            continue;
        }
        if formatted != current {
            unstable.append(path);
        }
    }
    if unstable {
        return StageResult(
            stage="format",
            ok=False,
            detail=f"{len(unstable)} file(s) not format-stable",
            artifacts=unstable
        );
    }
    return StageResult(stage="format", ok=True, detail="format-stable");
}


def _format_source(path: str) -> (bytes | None) {
    try {
        import from jaclang.jac0core.program { JacProgram }
        with open(path) as fh {
            src = fh.read();
        }
        prog = JacProgram.jac_str_formatter(
            source_str=src, file_path=path, auto_lint=False
        );
        if prog.errors_had {
            return None;
        }
        return str(prog.mod.main.gen.jac).encode("utf-8");
    } except Exception {
        return None;
    }
}


def build_reverse_deps(module_deps: list[tuple[str, str]]) -> dict[str, set[str]] {
    rev: dict[str, set[str]] = {};
    for (frm, to) in module_deps {
        if to not in rev {
            rev[to] = set();
        }
        rev[to].add(frm);
    }
    return rev;
}


def select_affected_tests(
    module_deps: list[tuple[str, str]], touched: list[str], test_paths: list[str]
) -> list[str] {
    rev = build_reverse_deps(module_deps);
    dependents: set[str] = set();
    frontier: list[str] = list(touched);
    while frontier {
        cur = frontier.pop();
        for dep in rev.get(cur, set()) {
            if dep in dependents {
                continue;
            }
            dependents.add(dep);
            frontier.append(dep);
        }
    }
    affected: set = set();
    for t in test_paths {
        if t in dependents or t in touched {
            affected.add(t);
        }
    }
    return sorted(affected);
}


def select_affected_tests_from_prog(
    prog: any, touched: list[str], test_paths: list[str]
) -> list[str] {
    dependents: set = set();
    for t in touched {
        for dep in prog.transitive_dependents(t) {
            dependents.add(dep);
        }
    }
    affected: set = set();
    for tp in test_paths {
        if tp in dependents or tp in touched {
            affected.add(tp);
        }
    }
    return sorted(affected);
}


def bisect_culprit(items: list[str], validates: any) -> list[str] {
    if validates(items) {
        return [];
    }
    current = list(items);
    changed = True;
    while changed and len(current) > 1 {
        changed = False;
        mid = len(current) // 2;
        left = current[:mid];
        right = current[mid:];
        if left and not validates(left) {
            current = left;
            changed = True;
        } elif right and not validates(right) {
            current = right;
            changed = True;
        }
    }

    i = 0;
    while i < len(current) {
        candidate = current[:i] + current[i + 1:];
        if candidate and not validates(candidate) {
            current = candidate;
        } else {
            i += 1;
        }
    }
    return current;
}
