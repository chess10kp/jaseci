import from pathlib { Path }
import from jaclang.cli.console { console }
import from jaclang.cli.check_report {
    print_file_progress,
    print_failures,
    print_failed_summary,
    print_final_summary,
    print_native_coverage,
    print_placement_report
}


def _maybe_malloc_trim {
    import from jaclang.cli.workpool { maybe_malloc_trim }
    maybe_malloc_trim();
}

glob _CHECK_STATE: dict[(str, any)] = {"prog": None, "coverage_on": False};

def _wire_list(value: any) -> list[any] {
    return value if isinstance(value, list) else [];
}

def _wire_dict(value: any) -> dict[str, any] {
    return value if isinstance(value, dict) else {};
}

def _message_diag(text: str, path: str) -> dict[(str, any)] {
    return {
        'text': text,
        'pretty': text,
        'code': None,
        'category': None,
        'mod_path': path
    };
}

def _diag_wire(alert: any) -> dict[(str, any)] {
    info = alert.code;
    return {
        'text': str(alert),
        'pretty': alert.pretty_print(),
        'code': info.code if info is not None else None,
        'category': info.category.value if info is not None else None,
        'mod_path': alert.loc.mod_path if alert.loc else ''
    };
}

def _check_rss_cap_mb -> int {
    import from jaclang.cli.workpool { env_int }
    return env_int("JAC_CHECK_RECYCLE_MB", 3072);
}

def _check_retire(served: int, rss_mb: int) -> bool {
    import from jaclang.cli.workpool { env_int, should_retire }
    return should_retire(
        served, env_int("JAC_CHECK_RECYCLE", 0), rss_mb, _check_rss_cap_mb()
    );
}

def _check_unit(
    path: str,
    app_name: str,
    kind: str,
    target: str,
    root_dir: str,
    closure: bool = False
) -> dict[(str, any)] {
    return {
        'path': path,
        'app': app_name,
        'kind': kind,
        'target': target,
        'root_dir': root_dir,
        'label': app_name or 'shared',
        'closure': closure
    };
}

def _is_app_name(target: str) -> bool {
    return bool(target)
        and not target.endswith('.jac')
        and '/' not in target
        and '\\' not in target;
}

def _check_file_job(request: dict[(str, any)]) -> dict[(str, any)] {
    import os;
    import from jaclang.compiler.driver.program { JacProgram }
    import from jaclang.compiler.driver.bccache { discover_base_file }
    import from jaclang.compiler.driver.compile_options { CompileOptions }
    opts = _wire_dict(request.get("opts"));
    file_path = str(request["path"]);
    result: dict[(str, any)] = {
        'path': file_path,
        'success': False,
        'errors': [],
        'warnings': [],
        'placements': {},
        'coverage': {},
        'reached': []
    };
    if not Path(file_path).exists() {
        result['errors'] = [
            _message_diag(f"File '{file_path}' does not exist.", file_path)
        ];
        return result;
    }
    prog = _CHECK_STATE["prog"];
    if prog is None {
        prog = JacProgram();
        _CHECK_STATE["prog"] = prog;
    }
    if opts.get("native_coverage") and not _CHECK_STATE["coverage_on"] {
        import from jaclang.compiler.driver.na_coverage { na_coverage_begin }
        na_coverage_begin();
        _CHECK_STATE["coverage_on"] = True;
    }
    ignore_list = _wire_list(opts.get("ignore"));
    annex_filter_path: (str | None) = None;
    base_path = discover_base_file(file_path);
    if base_path is not None {
        annex_filter_path = os.path.realpath(file_path);
        file_path = base_path;
    }
    try {
        (err_start, warn_start) = (len(prog.errors_had), len(prog.warnings_had));
        if opts.get("parse_only") {
            import from jaclang.compiler.frontend.parser.frontend {
                parse_diags,
                _replay_diags
            }
            import from jaclang.compiler.frontend.parser.lexer { Lexer }
            import from jaclang.compiler.frontend.parser.parser {
                Parser as _SyntaxParser
            }
            import from jaclang.compiler.frontend.unitree { Source as _Src }
            import from jaclang.project.source { read_file_with_encoding as _read_src }
            _src_txt = _read_src(file_path);
            (_had, _pd, _ld) = parse_diags(_src_txt, file_path);
            if _pd or _ld {
                _dsrc = _Src(_src_txt, mod_path=file_path);
                _replay_diags(_ld, Lexer, prog, _dsrc);
                _replay_diags(_pd, _SyntaxParser, prog, _dsrc);
            }
        } else {
            compile_options = CompileOptions(
                no_cgen=not bool(opts.get("native_coverage")),
                native_parity=True,
                force_target_program=True,
                iface_ok=True,
                suppress_codes=list(opts.get("suppress_codes") or []),
                target_app=str(opts.get("target_app") or ""),
                app_kind=str(opts.get("app_kind") or ""),
                project_root=(
                    str(opts["project_root"]) if opts.get("project_root") else None
                )
            );
            compile_options.entry_point = file_path;
            if opts.get('closure') {
                import from jaclang.compiler.driver.pipeline { compile_application }
                compile_application(prog, file_path, compile_options);
            } else {
                prog.compile(file_path, options=compile_options);
            }
        }
        if opts.get("placements") {
            import from jaclang.compiler.placement.placement { collect_placement_rows }
            result['placements'] = collect_placement_rows(prog);
        }
        if opts.get("native_coverage") {
            import from jaclang.compiler.driver.na_coverage { _na_coverage }
            result['coverage'] = dict(_na_coverage);
        }
        for m in prog.mod.hub.values() {
            m.terminals = [];
            m.src_terminals = [];
        }
        new_errors = prog.errors_had[err_start:];
        new_warnings = prog.warnings_had[warn_start:];

        def keep(issue: any) -> bool {
            return bool(
                issue.loc
                    and issue.loc.mod_path
                    and issue.loc.mod_path.endswith(".jac")
                    and not _should_ignore(issue.loc.mod_path, ignore_list)
                    and (
                        annex_filter_path is None
                        or issue.loc.mod_path == annex_filter_path
                    )
            );
        }
        result['errors'] = [
            _diag_wire(e)
            for e in new_errors
            if keep(e)
        ];
        result['warnings'] = [
            _diag_wire(w)
            for w in new_warnings
            if keep(w)
        ];
        result['success'] = len(result['errors']) == 0;
        return result;
    } except Exception as e {
        result['errors'] = [
            _message_diag(f"Error checking '{file_path}': {e}", file_path)
        ];
        result['success'] = False;
        return result;
    } finally {
        prog.release_compile_closure(collect=bool(request.get("collect")));
        _maybe_malloc_trim();
    }
}

impl check(
    paths: list[str],
    print_errs: bool = True,
    ignore: (list[str] | None) = None,
    disable_error_code: (list[str] | None) = None,
    parse_only: bool = False,
    nowarn: bool = False,
    lint_only: bool = False,
    fix: bool = False,
    native_coverage: bool = False,
    placements: bool = False,
    jobs: str = "",
    app: str = ""
) -> int {
    import from jaclang.compiler.frontend.diagnostic_utils { resolve_diagnostic_tokens }
    import from jaclang.cli.workpool {
        WorkPool,
        forced_serial,
        jobs_setting,
        pool_available,
        resolve_jobs
    }
    import from jaclang.project.config { get_config }
    import from time { time }
    if lint_only {
        return lint(paths=paths, fix=fix, ignore=ignore);
    }
    import gc;
    import os;
    import from jaclang.compiler.driver.compiler { COMPILE_GC_THRESHOLDS }
    if (
        not os.environ.get('JAC_GC_NO_COMPILE_BOOST')
        and gc.get_threshold()[0] < COMPILE_GC_THRESHOLDS[0]
    ) {
        gc.set_threshold(*COMPILE_GC_THRESHOLDS);
    }
    if isinstance(paths, str) {
        paths = [paths];
    }
    start_time = time();
    ignore_list = _normalize_ignore_patterns(ignore or []);
    (suppressed_codes, unknown_codes) = resolve_diagnostic_tokens(
        disable_error_code or []
    );
    if unknown_codes {
        console.warning(
            "Ignoring unknown diagnostic codes in --disable-error-code: "
                + ", ".join(unknown_codes)
        );
    }

    import from jaclang.project.workspace { workspace_for_path }
    ws = workspace_for_path(os.getcwd()) if not paths else None;
    units: list[dict[(str, any)]] = [];
    had_path_errors = False;
    if ws is not None {
        selected = [
            a
            for a in ws.apps.values()
            if (not app) or a.name == app
        ];
        if app and not selected {
            console.error(
                f"Error: no app named '{app}' in {ws.toml_path} "
                f"(apps: {', '.join(ws.apps)})."
            );
            return 2;
        }
        for a in selected {
            if not os.path.isfile(a.`entry) {
                console.error(
                    f"Error: entry '{a.`entry}' of app '{a.name}' does not exist."
                );
                had_path_errors = True;
                continue;
            }
            units.append(
                _check_unit(a.`entry, a.name, a.kind, a.name, ws.project_root, True)
            );
        }
    } else {
        (explicit_files, had_path_errors) = _iter_jac_files(
            paths, ignore_list, include_annex=False
        );
        named_files = {
            os.path.realpath(str(p))
            for p in paths
            if os.path.isfile(str(p))
        };
        planned_workspaces: set[str] = set();
        directory_roots = [
            os.path.realpath(str(p))
            for p in paths
            if os.path.isdir(str(p))
        ];
        for f in explicit_files {
            f_ws = workspace_for_path(f);
            selected_app: any = None;
            if f_ws is not None
                and f_ws.explicit
                and os.path.realpath(f) not in named_files
                and any(
                    f_ws.project_root == directory
                        or f_ws.project_root.startswith(directory + os.sep)
                    for directory in directory_roots
                ) {
                if f_ws.project_root not in planned_workspaces {
                    planned_workspaces.add(f_ws.project_root);
                    for declared in f_ws.apps.values() {
                        if (not app or declared.name == app)
                            and not _should_ignore(declared.entry, ignore_list) {
                            units.append(
                                _check_unit(
                                    declared.entry,
                                    declared.name,
                                    declared.kind,
                                    declared.name,
                                    f_ws.project_root,
                                    True
                                )
                            );
                        }
                    }
                }
                continue;
            }
            if f_ws is not None {
                selected_app = f_ws.app(app) if app else f_ws.app_for_path(f);
                if selected_app is None and not f_ws.explicit {
                    selected_app = next(iter(f_ws.apps.values()), None);
                }
            }
            units.append(
                _check_unit(
                    f,
                    selected_app.name if selected_app is not None else '',
                    selected_app.kind if selected_app is not None else '',
                    selected_app.name if selected_app is not None else '',
                    f_ws.project_root if f_ws is not None else ''
                )
            );
        }
    }
    cfg = get_config();
    raw_jobs = jobs_setting("check", jobs, cfg.dev if cfg else None);

    workers = resolve_jobs(
        raw_jobs,
        env_var="JAC_CHECK_JOBS",
        worker_bytes=_check_rss_cap_mb() * 1024 * 1024
    );
    opts: dict[(str, any)] = {
        'parse_only': parse_only,
        'native_coverage': native_coverage,
        'placements': placements,
        'suppress_codes': list(suppressed_codes),
        'ignore': list(ignore_list)
    };

    results: list[dict[(str, any)]] = [];
    plan: dict[(str, int)] = {'total': len(units)};
    placement_report: dict[str, any] = {};
    coverage_report: dict[str, any] = {};

    def run_units(batch: list[dict[(str, any)]]) -> None {
        if not batch {
            return;
        }
        total = len(batch);
        use_pool = (
            pool_available()
            and not forced_serial(raw_jobs)
            and workers > 1
            and total > 1
        );

        def request_extra(idx: int, path: str) -> dict[(str, any)] {
            unit = batch[idx];
            job_opts = dict(opts);
            job_opts['target_app'] = unit['target'];
            job_opts['app_kind'] = unit['kind'];
            job_opts['project_root'] = unit['root_dir'];
            job_opts['closure'] = unit['closure'];
            return {'opts': job_opts, 'collect': (not use_pool) and (idx < total - 1)};
        }

        def on_dispatch(idx: int, path: str) {
            console.print(f"  Checking {path}...");
        }

        def on_record(idx: int, record: dict[(str, any)]) {
            unit = batch[idx];
            path = unit['path'];
            res = _wire_dict(record.get('result'));
            if not res {
                detail = record.get('crash') or record.get('error') or 'no result';
                res = {
                    'path': path,
                    'success': False,
                    'errors': [
                        _message_diag(f"Error checking '{path}': {detail}", path)
                    ],
                    'warnings': [],
                    'placements': {},
                    'coverage': {},
                    'reached': []
                };
            }
            res['label'] = unit['label'];
            res['_unit'] = unit;
            results.append(res);
            print_file_progress(
                path, bool(res.get('success')), len(results), plan['total']
            );
            if placements {
                placement_report.update(_wire_dict(res.get('placements')));
            }
            if native_coverage {
                coverage_report.update(_wire_dict(res.get('coverage')));
            }
        }

        pool = WorkPool(
            items=[u['path'] for u in batch],
            job=_check_file_job,
            on_record=on_record,
            jobs=min(workers, max(1, total)),
            request_extra=request_extra,
            retire=_check_retire,
            on_dispatch=on_dispatch,
            rss_log_env="JAC_CHECK_RSS_LOG",
            crash_prefix="jac-check-crash-"
        );
        if use_pool {
            import from jaclang.runtime.runtime { JacRuntime }
            try {
                JacRuntime.get_compiler().ensure_stub_catalog();
            } except Exception {}
            pool.run();
        } else {
            pool.run_inline();
        }
    }

    run_units(units);
    if native_coverage {
        import from jaclang.compiler.driver.na_coverage { na_coverage_end }
        coverage_report.update(na_coverage_end());
        _CHECK_STATE["coverage_on"] = False;
    }

    multi = len({r['label'] for r in results}) > 1;
    failed_results: list[dict[str, any]] = [];
    total_errors = failed_files=0;
    for res in results {
        errs = _wire_list(res.get('errors'));
        warns = _wire_list(res.get('warnings'));
        if multi {
            prefix = f"[{res['label']}] ";
            for d in errs + warns {
                if isinstance(d, dict) {
                    d['pretty'] = prefix + str(d.get('pretty') or '');
                    d['text'] = prefix + str(d.get('text') or '');
                }
            }
        }
        total_errors += len(errs);
        if not res.get('success') {
            failed_files += 1;
        }
        if not res.get('success') or (len(warns) > 0 and not nowarn) {
            failed_results.append(
                {
                    'path': (f"[{res['label']}] " if multi else '')
                        + str(res.get('path')),
                    'errors': errs,
                    'warnings': warns
                }
            );
        }
    }
    if native_coverage {
        print_native_coverage(coverage_report);
    }
    if placements {
        print_placement_report(placement_report);
    }
    if print_errs and len(failed_results) > 0 {
        print_failures(failed_results, nowarn);
    }
    if failed_files > 0 {
        print_failed_summary(failed_results);
    }

    elapsed = time() - start_time;
    print_final_summary(len(results) - failed_files, failed_files, elapsed);
    return 1 if (total_errors > 0 or had_path_errors) else 0;
}
