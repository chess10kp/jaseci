import from pathlib { Path }
import from jaclang.cli.console { console }
import from jaclang.cli.check_report { print_placement_report }


impl `test(
    target: str = "",
    paths: list[str] = [],
    test_name: str = "",
    filter: str = "",
    xit: bool = False,
    maxfail: int = None,
    directory: str = "",
    collect_only: bool = False,
    pct_range: str = "",
    resume: bool = False,
    verbose: bool = False,
    ignore: (list[str] | None) = None,
    jobs: str = ""
) -> int {
    import os;
    import from jaclang.project.config { get_config }
    import from jaclang.testing.test_runner { run_tests }
    import from jaclang.cli.workpool { jobs_setting }
    if isinstance(paths, str) {
        paths = [paths];
    }
    cfg = get_config();
    cfg_root = str(cfg.project_root) if (cfg and cfg.project_root) else "";
    app_root = "";
    app_cfg: any = None;
    explicit_app = False;
    if target {
        if cfg is not None and _is_app_name(target) and target in cfg.apps {
            app_cfg = cfg.app(target);
            explicit_app = True;
        } elif _is_app_name(target) and not Path(target).exists() {
            console.error(
                f"Error: '{target}' is neither an app of jac.toml nor a path."
            );
            return 1;
        } else {
            paths = [target] + list(paths);
        }
    } elif cfg is not None and not paths and not directory {
        try {
            app_cfg = cfg.resolve_app("");
        } except ValueError {
            app_cfg = None;
        }
    }
    re_root = explicit_app
        or (app_cfg is not None and cfg is not None and cfg.is_workspace);
    if app_cfg is not None and cfg is not None and app_cfg.name in cfg.apps {
        cfg = cfg.effective_for_app(app_cfg.name);
        app_root = os.path.dirname(app_cfg.entry_path(cfg_root));
        if not paths
            and not directory
            and not app_cfg.implicit
            and not (cfg.`test.directory or cfg.`test.directories) {
            paths = [app_cfg.entry_path(cfg_root)];
        }
    }
    def _rooted(raw: str) -> str {
        base = app_root or cfg_root;
        if base and not os.path.isabs(raw) {
            return os.path.join(base, raw);
        }
        return raw;
    }
    if (test_name and not paths) {
        console.error(
            "Error: --test_name requires a filepath. "
            "Running by name across all files is ambiguous.\n"
            "Usage: jac test <file.jac> --test_name <name>"
        );
        return 1;
    }

    roots: (str | list[str]) = directory;
    if (not paths and not directory and re_root and app_root) {
        roots = [app_root];
    }
    if (not paths and not directory) {
        cfg_dirs: list[str] = [];
        if cfg {
            cfg_dirs = cfg.`test.directories
                or ([cfg.`test.directory] if cfg.`test.directory else []);
        }
        resolved: list[str] = [];
        for raw in cfg_dirs {
            rt = _rooted(raw);
            if (
                app_root
                and cfg_root
                and not os.path.isabs(raw)
                and not Path(rt).is_dir()
                and Path(os.path.join(cfg_root, raw)).is_dir()
            ) {
                rt = os.path.join(cfg_root, raw);
            }
            if not Path(rt).is_dir() {
                console.error(
                    f"Error: [test] directory '{raw}' "
                    f"(resolved to '{rt}') does not exist."
                );
                return 1;
            }
            resolved.append(rt);
        }
        if resolved {
            roots = resolved;
        } elif not roots {
            paths = [cfg_root or os.getcwd()];
        }
    }
    iso_pats = [_rooted(p) for p in (cfg.`test.isolate if cfg else [])];
    ser_pats = [_rooted(p) for p in (cfg.`test.serial if cfg else [])];
    for fp in paths {
        if not Path(fp).exists() {
            console.error(
                f"Error: File not found: '{fp}'\n"
                "Make sure you are in the correct directory or provide the "
                f"full path.\nUsage: jac test /full/path/to/{fp}"
            );
            return 1;
        }
    }
    jobs = jobs_setting("test", jobs, cfg.dev if cfg else None);
    rc = 0;
    try {
        rc = run_tests(
            paths=paths,
            directory=roots,
            test_name=test_name,
            filter=filter,
            xit=xit,
            maxfail=maxfail,
            collect_only=collect_only,
            pct_range=pct_range,
            resume=resume,
            verbose=verbose,
            ignore=[
                p
                for p in (ignore or [])
                if p
            ],
            jobs=jobs,
            isolate=iso_pats,
            serial=ser_pats
        );
    } except (ValueError, FileNotFoundError) as exc {
        console.error(f"Error: {exc}");
        return 1;
    }
    if rc == 5 {
        console.error("No tests ran.");
    } elif rc {
        console.error("Tests failed.");
    }
    return rc;
}

impl gen_parser -> int {
    import from jaclang.compiler { gen_all_parsers }
    gen_all_parsers();
    console.success('Parser generated.');
    return 0;
}

impl grammar(output: str = "", strict: bool = False) -> int {
    import from jaclang.compiler.driver.program { JacProgram }
    import from jaclang.compiler.driver.compile_options { CompileOptions }
    import from jaclang.compiler.tools.grammar_extract_pass { GrammarExtractPass }
    import jaclang;
    parser_path = str(
        Path(jaclang.__file__).parent
            / "compiler"
            / "frontend"
            / "parser"
            / "parser.jac"
    );
    prog = JacProgram();
    mod = prog.compile(
        parser_path,
        options=CompileOptions(
            symtab_ir_only=True,
            no_cgen=True,
            need_full_ast=True,
            force_target_program=True
        )
    );
    if prog.errors_had {
        console.error("Failed to compile parser module.");
        for e in prog.errors_had {
            console.error(f"  {e}");
        }
        return 1;
    }
    import from jaclang.compiler.driver.pipeline { run_utility, UtilityProduct }
    import from typing { cast }
    pass_ = cast(GrammarExtractPass, run_utility(UtilityProduct.GRAMMAR, mod, prog));
    if len(pass_.rules) == 0 {
        console.error("No grammar rules extracted.");
        return 1;
    }
    text = pass_.emit_ebnf();
    if output {
        banner = (
            "# Auto-generated EBNF snapshot of the Jac grammar.\n"
            + "# DO NOT EDIT MANUALLY - regenerate with"
            + " `jac tool grammar -o <path>`.\n\n"
        );
        with open(output, "w", encoding="utf-8") as f {
            f.write(banner);
            f.write(text);
            f.write("\n");
        }
        console.success(f"EBNF grammar ({len(pass_.rules)} rules) written to {output}");
    } elif not strict {
        console.print(text);
    }
    if strict {
        console.print(pass_.emit_diagnostics());
    }
    return 0;
}

def _iter_jac_files(
    paths: list[str], ignore_list: (list[str] | None) = None, include_annex: bool = True
) -> tuple[list[str], bool] {
    import os;
    ignore_list: list[str] = ignore_list or [];
    result: list[str] = [];
    explicit: set[str] = set();
    had_errors = False;
    for path in paths {
        path_obj = Path(path);
        if path.endswith('.jac') {
            if not _should_ignore(path, ignore_list) {
                result.append(path);
                explicit.add(os.path.realpath(path));
            }
        } elif path_obj.is_dir() {
            walked: list[str] = [];
            for jac_file in path_obj.`glob('**/*.jac') {
                if not jac_file.is_file() {
                    continue;
                }
                if not _should_ignore(str(jac_file), ignore_list) {
                    walked.append(str(jac_file));
                }
            }
            if _drop_git_ignored([str(path_obj)]) {
                result.extend(_drop_git_ignored(walked));
            } else {
                result.extend(walked);
            }
        } else {
            console.error(f"'{path}' is not a .jac file or directory.");
            had_errors = True;
        }
    }
    if not include_annex {
        result = _drop_covered_annexes(result, explicit);
    }
    return (result, had_errors);
}

def _drop_covered_annexes(files: list[str], explicit: set[str]) -> list[str] {
    import os;
    import from jaclang.compiler.driver.bccache { discover_base_file }
    import from jaclang.jac0core.ext_registry { is_annex }
    modules = {
        os.path.realpath(f)
        for f in files
        if not is_annex(f)
    };
    kept: list[str] = [];
    for f in files {
        if is_annex(f) and (os.path.realpath(f) not in explicit) {
            base = discover_base_file(f);
            if (base is not None) and (os.path.realpath(base) in modules) {
                continue;
            }
        }
        kept.append(f);
    }
    return kept;
}

def _normalize_ignore_patterns(ignore: list[str]) -> list[str] {
    import from jaclang.project.source { normalize_exclude_patterns }
    return normalize_exclude_patterns(ignore);
}

def _drop_git_ignored(paths: list[str]) -> list[str] {
    import subprocess;
    if not paths {
        return paths;
    }
    try {
        proc = subprocess.run(
            ['git', 'check-ignore', '--stdin'],
            input="\n".join(paths),
            capture_output=True,
            text=True,
            check=False
        );
    } except (OSError, ValueError) {
        return paths;
    }

    if proc.returncode not in (0, 1) {
        return paths;
    }
    ignored = {
        line
        for line in proc.stdout.splitlines()
        if line
    };
    if not ignored {
        return paths;
    }
    return [
        p
        for p in paths
        if p not in ignored
    ];
}

def _should_ignore(file_path: str, ignore_patterns: list[str]) -> bool {
    import from jaclang.project.source { path_matches_exclude }
    return path_matches_exclude(file_path, ignore_patterns);
}

impl explain(topic: str, filename: str, output: str = "", memory: str = "") -> int {
    import os;
    import from jaclang.cli.console { console }
    import from jaclang.compiler.driver.program { JacProgram }
    import from jaclang.compiler.driver.compile_options { CompileOptions }
    if not os.path.isfile(filename) {
        console.error(f"File not found: {filename}");
        return 1;
    }
    path = os.path.abspath(filename);
    prog = JacProgram();
    if topic == "memory" {
        import from jaclang.compiler.passes.ownership_hints { inferred_hints }
        mod = prog.compile(
            file_path=path,
            options=CompileOptions(
                rc_stats=True, nogc_debug=True, memory_profile=(memory or None)
            )
        );
        for err in prog.errors_had {
            console.print(err.pretty_print());
        }
        if mod is None {
            return 1;
        }
        console.print(
            f"memory profile: {prog.options.memory_profile
                if prog.options
                else 'managed'}"
        );
        hints = inferred_hints(mod);
        console.print(f"inferred facts: {len(hints)}");
        for h in sorted(hints, key=lambda (h) { (h.line, h.col); }) {
            console.print(
                f"  {os.path.basename(path)}:{h.line}:{h.col}  {h.label.strip()}"
            );
        }
        console.print(f"move sites: {len(mod.own_move_sites)}");
        console.print(
            f"last-use releases: {sum([len(v) for v in mod.rc_last_use.values()])}"
        );
        return 0;
    }
    if topic == "placement" {
        import from jaclang.compiler.placement.placement { collect_placement_rows }
        import from jaclang.cli.check_report { print_placement_report }
        prog.compile(file_path=path);
        for err in prog.errors_had {
            console.print(err.pretty_print());
        }
        print_placement_report(collect_placement_rows(prog));
        return 0;
    }
    import re;
    import from jaclang.compiler.backends.native.na_compile_pass {
        native_linked_ir_text
    }
    mod = prog.compile(
        file_path=path,
        options=CompileOptions(
            aot_mode=True, default_codespace="native", force_target_program=True
        )
    );
    for err in prog.errors_had {
        console.print(err.pretty_print());
    }
    if mod is None or mod.gen.llvm_ir is None {
        console.error(
            "No native IR was produced for this module; see the diagnostics above."
        );
        return 1;
    }
    ir_text = native_linked_ir_text(mod);
    out_path = output or (os.path.splitext(path)[0] + ".ll");
    with open(out_path, "w", encoding="utf-8") as fh {
        fh.write(ir_text);
    }
    console.print(f"wrote {out_path} ({len(ir_text)} bytes)");
    console.print("symbols:");
    for m in re.finditer(r"^define [^@]*@([A-Za-z0-9_.$]+)\(", ir_text, re.M) {
        console.print(f"  {m.group(1)}");
    }
    return 0;
}
