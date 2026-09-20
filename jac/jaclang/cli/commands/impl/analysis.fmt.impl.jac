import from pathlib { Path }
import from jaclang.cli.console { console }
import from jaclang.cli.check_report { print_failed_summary }


impl lint(
    paths: list[str], fix: bool = False, ignore: (list[str] | None) = None
) -> int {
    import from jaclang.compiler.driver.program { JacProgram }
    if isinstance(paths, str) {
        paths = [paths];
    }
    ignore_list = _normalize_ignore_patterns(ignore or []);
    def lint_report_file(file_path: str) -> tuple[bool, int] {
        path_obj = Path(file_path);
        if not path_obj.exists() {
            console.error(f"File '{file_path}' does not exist.");
            return (False, 1);
        }
        console.print(f"  Linting {file_path}...");
        try {
            prog = JacProgram.jac_file_linter(str(path_obj));
            error_count = 0;
            for warning in prog.warnings_had {
                console.warning(f"{warning}");
            }
            for error in prog.errors_had {
                console.error(f"{error}");
                error_count += 1;
            }
            return (True, error_count);
        } except Exception as e {
            console.error(f"Error linting '{file_path}': {e}");
            return (False, 1);
        }
    }
    def lint_fix_file(file_path: str, covered: set[str]) -> tuple[bool, int, int] {
        path_obj = Path(file_path);
        if not path_obj.exists() {
            console.error(f"File '{file_path}' does not exist.");
            return (False, 1, 1);
        }
        console.print(f"  Lint-fixing {file_path}...");
        try {
            prog = JacProgram.jac_file_formatter(str(path_obj), auto_lint=True);
            try {
                formatted_code = prog.mod.main.gen.jac;
                original_code = prog.mod.main.source.code;
            } except Exception {
                for error in prog.errors_had {
                    console.error(f"{error}");
                }
                err_count = len(prog.errors_had) or 1;
                return (False, err_count, err_count);
            }

            has_format_error = any(
                e.code is not None and e.code.code == "E5051" for e in prog.errors_had
            );
            if has_format_error {
                for error in prog.errors_had {
                    console.error(f"{error}");
                }
                err_count = len(prog.errors_had);
                return (False, err_count, err_count);
            }

            fixed_count = 0;
            unfixable_count = 0;
            for warning in prog.warnings_had {
                console.warning(f"{warning}");
                fixed_count += 1;
            }
            for error in prog.errors_had {
                console.error(f"{error}");
                unfixable_count += 1;
            }
            error_count = fixed_count + unfixable_count;

            if fixed_count > 0 {
                changed = formatted_code != original_code;
                if changed {
                    with open(str(path_obj), 'w', encoding='utf-8') as f {
                        f.write(formatted_code);
                    }
                }
            }

            import from jaclang.compiler.driver.bccache { discover_annex_files }
            import os;
            annex_paths = (
                discover_annex_files(str(path_obj), '.impl.jac')
                + discover_annex_files(str(path_obj), '.test.jac')
            );
            for annex_path in annex_paths {
                if os.path.realpath(annex_path) in covered {
                    continue;
                }
                try {
                    annex_prog = JacProgram.jac_file_formatter(
                        annex_path, auto_lint=True
                    );
                    annex_formatted = annex_prog.mod.main.gen.jac;
                    annex_original = annex_prog.mod.main.source.code;
                } except Exception {
                    continue;
                }
                for warning in annex_prog.warnings_had {
                    console.warning(f"{warning}");
                    error_count += 1;
                }
                for error in annex_prog.errors_had {
                    console.error(f"{error}");
                    error_count += 1;
                    unfixable_count += 1;
                }
                if (annex_formatted and annex_formatted != annex_original) {
                    with open(annex_path, 'w', encoding='utf-8') as f {
                        f.write(annex_formatted);
                    }
                }
            }
            return (True, error_count, unfixable_count);
        } except Exception as e {
            console.error(f"Error linting '{file_path}': {e}");
            return (False, 1, 1);
        }
    }
    total_files = 0;
    failed_files = 0;
    total_errors = 0;
    total_unfixable = 0;
    (all_files, had_path_errors) = _iter_jac_files(paths, ignore_list);
    import os;
    covered: set[str] = {os.path.realpath(f) for f in all_files};
    for file_path in all_files {
        total_files += 1;
        if fix {
            (success, errors, unfixable) = lint_fix_file(file_path, covered);
            total_unfixable += unfixable;
        } else {
            (success, errors) = lint_report_file(file_path);
        }
        total_errors += errors;
        if not success {
            failed_files += 1;
        }
    }
    failing_errors = total_unfixable if fix else total_errors;
    if fix and total_errors > 0 {
        fixed_count = total_errors - total_unfixable;
        parts: list[str] = [];
        if fixed_count > 0 {
            parts.append(f"{fixed_count} fixed");
        }
        if total_unfixable > 0 {
            parts.append(f"{total_unfixable} unfixable");
        }
        detail = ", ".join(parts);
        summary_msg = f"Linted {total_files} '.jac' files: {total_errors} errors ({detail}).";
    } else {
        summary_msg = f"Linted {total_files} '.jac' files: {total_errors} errors found.";
    }
    if failing_errors > 0 or had_path_errors {
        console.error(summary_msg);
        return 1;
    }
    console.success(summary_msg);
    return 0;
}

def _format_single_file_worker(
    file_path: str,
    lintfix: bool,
    check: bool,
    covered: (set[str] | None) = None,
    cache_stamp: str = "",
    cache_anchor: str = "",
    logical_path: str = ""
) -> dict[str, any] {
    import os;
    import from jaclang.compiler.driver.program { JacProgram }
    import from jaclang.project.source { read_file_with_encoding }
    path_obj = Path(file_path);

    effective_logical = logical_path or file_path;
    result: dict[str, any] = {
        'path': file_path,
        'success': False,
        'changed': False,
        'errors': 0,
        'syntax_errors': [],
        'warnings_strs': [],
        'errors_strs': [],
        'formatted_code': None,
        'impl_results': [],
        'cache_status': 'off'
    };
    if not path_obj.exists() {
        result['syntax_errors'] = [f"File '{file_path}' does not exist."];
        return result;
    }

    fcache = None;
    cache_key = "";
    cfg_fp = "";
    cfg: any = None;
    key_logical = "";
    annex_ok = True;
    annex_error_count = 0;

    annex_paths: list[str] = [];
    annex_formatted_map: dict[str, str] = {};
    annex_logical_map: dict[str, str] = {};
    if lintfix {
        import from jaclang.compiler.driver.bccache { discover_annex_files }

        annex_paths = (
            discover_annex_files(file_path, '.impl.jac')
            + discover_annex_files(file_path, '.test.jac')
        );
        if logical_path {
            phys_parent = str(Path(file_path).resolve().parent);
            log_parent = str(Path(logical_path).parent);
            for ap in annex_paths {
                try {
                    rel = os.path.relpath(ap, phys_parent);
                    annex_logical_map[ap] = str(Path(log_parent) / rel);
                } except ValueError {
                    annex_logical_map[ap] = ap;
                }
            }
        }
    }
    if cache_stamp {
        try {
            import from jaclang.cli.format_cache {
                FormatCache,
                config_fingerprint,
                frame_unit,
                canonical_logical_path,
                default_format_cache_dir
            }
            import from jaclang.project.config { get_config_for_path }

            cfg = get_config_for_path(Path(effective_logical));
            if cfg is not None {
                cache_dir = cfg.get_cache_dir();
            } else {
                anchor = Path(cache_anchor) if cache_anchor else path_obj;
                cache_dir = default_format_cache_dir(anchor);
                cfg = None;
            }

            fcache = FormatCache(cache_dir, enabled=True, formatter_stamp=cache_stamp);

            unit_parts = [path_obj.read_bytes()];
            for ap in annex_paths {
                ap_obj = Path(ap);
                if ap_obj.exists() {
                    unit_parts.append(ap_obj.read_bytes());
                }
            }
            unit_bytes = frame_unit(unit_parts);
            cfg_fp = config_fingerprint(cfg, lintfix);
            project_root = str(cfg.project_root)
                if (cfg is not None and cfg.project_root)
                else (cache_anchor);
            key_logical = (
                canonical_logical_path(effective_logical, project_root)
                    if lintfix
                    else ""
            );
            cache_key = fcache.make_key(
                unit_bytes,
                lintfix=lintfix,
                config_fingerprint=cfg_fp,
                logical_path=key_logical
            );
            if fcache.is_clean(cache_key) {
                result['cache_status'] = 'hit';
                result['success'] = True;
                result['changed'] = False;
                result['errors'] = 0;
                return result;
            }
            result['cache_status'] = 'miss';
        } except (OSError, ValueError, TypeError, ImportError, AttributeError) {
            fcache = None;
            cache_key = "";
        }
    }

    try {
        if logical_path {
            source_str = read_file_with_encoding(str(path_obj));
            prog = JacProgram.jac_str_formatter(
                source_str, effective_logical, auto_lint=lintfix
            );
        } else {
            prog = JacProgram.jac_file_formatter(str(path_obj), auto_lint=lintfix);
        }
        if prog.errors_had {
            has_format_error = any(
                e.code is not None and e.code.code == "E5051" for e in prog.errors_had
            );
            if has_format_error or not lintfix {
                result['syntax_errors'] = [str(e) for e in prog.errors_had];
                return result;
            }
        }
        try {
            formatted_code = prog.mod.main.gen.jac;
            original_code = prog.mod.main.source.code;
            if not formatted_code or len(formatted_code.strip()) == 0 {
                if prog.errors_had {
                    result['syntax_errors'] = [str(e) for e in prog.errors_had];
                    return result;
                }
            }
            changed = formatted_code != original_code;
            result['changed'] = changed;

            if changed and not check {
                result['formatted_code'] = formatted_code;
            }

            if lintfix {
                for annex_path in annex_paths {
                    if covered is not None
                        and (os.path.realpath(annex_path) in covered) {
                        continue;
                    }
                    annex_logical = annex_logical_map.get(annex_path, annex_path);
                    try {
                        if logical_path {
                            annex_src = read_file_with_encoding(annex_path);
                            annex_prog = JacProgram.jac_str_formatter(
                                annex_src, annex_logical, auto_lint=True
                            );
                        } else {
                            annex_prog = JacProgram.jac_file_formatter(
                                annex_path, auto_lint=True
                            );
                        }
                        annex_formatted = annex_prog.mod.main.gen.jac;
                        annex_original = annex_prog.mod.main.source.code;
                    } except (OSError, ValueError, TypeError, AttributeError) as e {
                        annex_ok = False;
                        annex_error_count += 1;
                        result['errors_strs'].append(
                            f"Error formatting annex '{annex_path}': {e}"
                        );
                        continue;
                    }
                    for warning in annex_prog.warnings_had {
                        result['warnings_strs'].append(str(warning));
                    }
                    for error in annex_prog.errors_had {
                        result['errors_strs'].append(str(error));
                        annex_ok = False;
                        annex_error_count += 1;
                    }
                    annex_formatted_map[annex_path] = (
                        annex_formatted if annex_formatted is not None else ""
                    );
                    if (annex_formatted and annex_formatted != annex_original) {
                        result['changed'] = True;
                        if not check {
                            result['impl_results'].append(
                                (annex_path, annex_formatted)
                            );
                        }
                    }
                }
            }
        } except (OSError, ValueError, TypeError, AttributeError) {
            result['syntax_errors'] = [str(e) for e in prog.errors_had];
            return result;
        }

        lint_errors = 0;
        if lintfix {
            for warning in prog.warnings_had {
                result['warnings_strs'].append(str(warning));
            }
            for error in prog.errors_had {
                result['errors_strs'].append(str(error));
                lint_errors += 1;
            }
            lint_errors += annex_error_count;
        }
        result['success'] = True;
        result['errors'] = lint_errors;

        if (
            fcache is not None
            and cache_key
            and result['success']
            and not result['syntax_errors']
            and result['errors'] == 0
            and annex_ok
        ) {
            try {
                import from jaclang.cli.format_cache { frame_unit }

                if not result['changed'] {
                    fcache.mark_clean(cache_key);
                } elif not check {
                    main_clean = (
                        formatted_code.encode() if changed else path_obj.read_bytes()
                    );
                    new_parts = [main_clean];
                    for ap in annex_paths {
                        if ap in annex_formatted_map {
                            new_parts.append(annex_formatted_map[ap].encode());
                        } elif Path(ap).exists() {
                            new_parts.append(Path(ap).read_bytes());
                        } else {
                            annex_ok = False;
                            break;
                        }
                    }
                    if annex_ok {
                        new_unit = frame_unit(new_parts);
                        fcache.mark_clean(
                            fcache.make_key(
                                new_unit,
                                lintfix=lintfix,
                                config_fingerprint=cfg_fp,
                                logical_path=key_logical
                            )
                        );
                    }
                }
            } except (OSError, ValueError, TypeError, AttributeError) {}
        }

        return result;
    } except Exception as e {
        result['syntax_errors'] = [f"Error formatting '{file_path}': {e}"];
        return result;
    }
}

impl format(
    paths: list[str],
    to_screen: bool = False,
    lintfix: bool = False,
    check: bool = False,
    cache: bool = False,
    cache_anchor: str = "",
    path_map: dict[str, str] | None = None,
    cache_stats: dict[str, int] | None = None,
    jobs: str = ""
) -> int {
    import os;
    import from jaclang.cli.workpool {
        WorkPool,
        forced_serial,
        jobs_setting,
        pool_available,
        resolve_jobs
    }
    import from jaclang.project.config { get_config }
    if isinstance(paths, str) {
        paths = [paths];
    }

    cache_stamp = "";

    if cache and not to_screen {
        import from jaclang.cli.format_cache {
            FORMAT_CACHE_SCHEMA_VERSION,
            formatter_pipeline_revision
        }
        import from jaclang.cli.cli { jac_version }
        try {
            rev = formatter_pipeline_revision();
            cache_stamp = f"jfmt:{FORMAT_CACHE_SCHEMA_VERSION}:{jac_version()}:{rev}";
        } except (OSError, ValueError, TypeError, ImportError, AttributeError) {
            cache_stamp = "";
        }
    }

    unformatted_files: list[str] = [];
    failed_results: list[dict[str, any]] = [];

    (all_files, had_path_errors) = _iter_jac_files(paths);
    total_files = len(all_files);

    if total_files == 0 {
        if cache_stats is not None {
            cache_stats["changed"] = 0;
        }
        return 1 if had_path_errors else 0;
    }

    remap = path_map if path_map is not None else {};
    covered: set[str] = {os.path.realpath(f) for f in all_files};

    cfg = get_config();
    raw_jobs = jobs_setting("fmt", jobs, cfg.dev if cfg else None);
    workers = resolve_jobs(raw_jobs, env_var="JAC_FMT_JOBS");
    use_pool = (
        pool_available()
        and not to_screen
        and not forced_serial(raw_jobs)
        and workers > 1
        and total_files > 1
    );

    results_by_idx: dict[int, dict[str, any]] = {};

    progress: dict[(str, any)] = {"pooled": use_pool, "done": 0};

    def fmt_job(request: dict[(str, any)]) -> dict[str, any] {
        fp = str(request["path"]);
        return _format_single_file_worker(
            fp, lintfix, check, covered, cache_stamp, cache_anchor, remap.get(fp, "")
        );
    }

    def on_dispatch(idx: int, path: str) {
        if not progress["pooled"] {
            console.print(f"Formatting {path}");
        }
    }

    def on_record(idx: int, record: dict[(str, any)]) -> None {
        if progress["pooled"] {
            progress["done"] += 1;
            console.print(
                f"Formatting [{progress['done']}/{total_files}] completed..."
            );
        }
        res = _wire_dict(record.get('result'));
        if res {
            results_by_idx[idx] = res;
            return;
        }
        detail = record.get('crash') or record.get('error') or 'no result';
        results_by_idx[idx] = {
            'path': all_files[idx],
            'success': False,
            'changed': False,
            'errors': 0,
            'syntax_errors': [f"Worker error: {detail}"],
            'warnings_strs': [],
            'errors_strs': [],
            'formatted_code': None,
            'impl_results': [],
            'cache_status': 'off'
        };
    }

    pool = WorkPool(
        items=list(all_files),
        job=fmt_job,
        on_record=on_record,
        jobs=min(workers, total_files),
        on_dispatch=on_dispatch,
        rss_log_env="JAC_FMT_RSS_LOG",
        crash_prefix="jac-fmt-crash-"
    );
    if use_pool {
        try {
            pool.run();
        } except Exception as e {
            console.print(
                f"Parallel formatting unavailable ({type(e).__name__}: {e}); "
                "falling back to serial."
            );
            results_by_idx.clear();
            progress["pooled"] = False;
            pool.run_inline();
        }
    } else {
        pool.run_inline();
    }
    results: list[dict[str, any]] = [];
    for idx in range(total_files) {
        if idx not in results_by_idx {
            on_record(idx, {'error': 'no result'});
        }
        results.append(results_by_idx[idx]);
    }

    if cache_stamp {
        hits = sum(
            1
            for r in results
            if r.get('cache_status') == 'hit'
        );
        misses = sum(
            1
            for r in results
            if r.get('cache_status') == 'miss'
        );
        if cache_stats is not None {
            cache_stats["hits"] = hits;
            cache_stats["misses"] = misses;
            cache_stats["examined"] = hits + misses;
        }
    }

    failed_files = 0;
    changed_files = 0;
    total_errors = 0;

    for res in results {
        for w in res['warnings_strs'] {
            console.warning(w);
        }
        for e in res['errors_strs'] {
            console.error(e);
        }

        total_errors += res['errors'];

        if not res['success'] {
            failed_files += 1;
            failed_results.append(
                {'path': res['path'], 'errors': res['syntax_errors'], 'warnings': []}
            );
        } elif res['changed'] {
            changed_files += 1;
            if check {
                unformatted_files.append(res['path']);
            } else {
                if res['formatted_code'] is not None {
                    try {
                        if to_screen {
                            console.print(
                                res['formatted_code'], markup=False, highlight=False
                            );
                        } else {
                            with open(res['path'], 'w', encoding='utf-8') as f {
                                f.write(res['formatted_code']);
                            }
                        }
                    } except Exception as e {
                        console.error(f"Error writing to '{res['path']}': {e}");
                    }
                }
                impl_pairs: list[tuple[str, str]] = res['impl_results'];
                for (impl_path, impl_code) in impl_pairs {
                    try {
                        if to_screen {
                            console.print(impl_code, markup=False, highlight=False);
                        } else {
                            with open(impl_path, 'w', encoding='utf-8') as f {
                                f.write(impl_code);
                            }
                        }
                    } except Exception as e {
                        console.error(f"Error writing to '{impl_path}': {e}");
                    }
                }
            }
        }
    }

    if cache_stats is not None {
        cache_stats["changed"] = changed_files;
    }

    if failed_results {
        import from jaclang.cli.check_report { separator }
        console.print("");
        console.print(separator("FAILURES"));
        for r in failed_results {
            console.print(separator(str(r['path']), char='_'));
            for e in r['errors'] {
                console.error(e);
            }
            console.print("");
        }
        print_failed_summary(failed_results);
    }

    if check {
        has_errors = False;
        if len(unformatted_files) > 0 {
            console.error("The following files are not properly formatted:");
            for file in unformatted_files {
                console.error(f"  jac fmt --lintfix {file}");
            }
            has_errors = True;
        }
        if failed_files > 0 {
            console.error(
                f"\n{failed_files} file(s) have syntax errors (see errors above)."
            );
            console.error(
                "Fix the syntax errors or rename files with '*_err.jac' suffix to exclude them."
            );
            has_errors = True;
        }
        if has_errors {
            return 1;
        }
        if (len(paths) == 1) and Path(paths[0]).is_dir() {
            console.success(
                f"Checked {total_files}/{total_files} '.jac' files - all formatted correctly."
            );
        }
        return 0;
    }

    if (((len(paths) == 1) and Path(paths[0]).is_dir()) or (failed_files > 0)) {
        summary_msg = f"Formatted {(total_files - failed_files)}/{total_files} '.jac' files ({changed_files} changed).";
        if failed_files > 0 {
            console.error(summary_msg);
        } else {
            console.success(summary_msg);
        }
    }

    if failed_files > 0 or had_path_errors {
        return 1;
    }
    if total_errors > 0 {
        return 1;
    }
    return 0;
}
