impl _state_path -> str {
    return os.path.join(os.getcwd(), ".jac", "test_state.json");
}

impl _load_last_failed -> str {
    import json;
    try {
        with open(_state_path(), "r", encoding="utf-8") as f {
            payload = json.load(f);
        }
        return str(payload.get("first_failed", ""));
    } except Exception {
        return "";
    }
}

impl _store_run_state(plan: TestPlan, reporter: Reporter) -> None {
    import json;
    path = _state_path();
    if not reporter.failure_count() {
        try {
            os.remove(path);
        } except OSError {}
        return;
    }
    order = {p: i for (i, p) in enumerate(plan.files)};
    first = "";
    best = len(plan.files) + 1;
    for outcome in reporter.failures {
        idx = order.get(outcome.file, len(plan.files));
        if idx < best {
            best = idx;
            first = outcome.file;
        }
    }
    if not first {
        return;
    }
    try {
        os.makedirs(os.path.dirname(path), exist_ok=True);
        with open(path, "w", encoding="utf-8") as f {
            json.dump({"first_failed": first}, f);
        }
    } except Exception {}
}

impl run_tests(
    paths: (list[str] | None) = None,
    directory: (str | list[str]) = "",
    test_name: str = "",
    filter: str = "",
    xit: bool = False,
    maxfail: (int | None) = None,
    collect_only: bool = False,
    pct_range: str = "",
    resume: bool = False,
    verbose: bool = False,
    ignore: (list[str] | None) = None,
    jobs: (str | int | None) = None,
    isolate: (list[str] | None) = None,
    serial: (list[str] | None) = None
) -> int {
    import sys;
    import time;
    if pct_range and resume {
        raise ValueError("--range and --resume cannot be combined");
    }
    plan = discover(paths, directory, ignore);
    iso_set = _match_patterns(plan.files, isolate);
    ser_set = _match_patterns(plan.files, serial);
    if iso_set or ser_set {
        plan.files = (
            [
                f
                for f in plan.files
                if (f in iso_set) and (f not in ser_set)
            ]
            + [
                f
                for f in plan.files
                if (f not in iso_set) and (f not in ser_set)
            ]
            + [
                f
                for f in plan.files
                if f in ser_set
            ]
        );
    }
    if resume {
        last = _load_last_failed();
        if not last {
            sys.stdout.write(
                "nothing to resume (no failure recorded); running the full plan\n"
            );
        } elif last not in plan.files {
            sys.stdout.write(
                "recorded failure is not in the current plan; "
                "running the full plan\n"
            );
        } else {
            plan.files = plan.files[plan.files.index(last):];
        }
    }
    if pct_range {
        (lo, hi) = _parse_pct_range(pct_range);
        n = len(plan.files);
        plan.files = plan.files[(lo * n) // 100:-((-hi * n) // 100)];
    }
    reporter = Reporter(verbose=verbose, total_files=len(plan.files));
    if plan.is_empty() {
        sys.stdout.write("no tests ran (no test files collected)\n");
        sys.stdout.flush();
        return EXIT_NO_TESTS;
    }
    if collect_only {
        for path in plan.files {
            rel = os.path.relpath(path);
            sys.stdout.write((path if rel.startswith("..") else rel) + "\n");
        }
        count = len(plan.files);
        plural = "" if count == 1 else "s";
        sys.stdout.write(f"\n{count} test file{plural} collected\n");
        sys.stdout.flush();
        return EXIT_OK;
    }
    selector = _build_selector(test_name, filter);
    workers = resolve_jobs(jobs);
    started = time.perf_counter();
    raw_jobs = jobs
        if (jobs not in (None, ""))
        else os.environ.get("JAC_TEST_JOBS", "");
    forced_serial = str(raw_jobs).strip() == "0";
    use_pool = hasattr(os, "fork")
        and not forced_serial
        and ((workers > 1) or bool(iso_set) or bool(ser_set))
        and (len(plan.files) > 1 or bool(iso_set) or bool(ser_set));
    if not use_pool {
        _run_plan(
            plan, selector, reporter, xit, maxfail, jobs=1, isolate=None, inline=True
        );
    } else {
        par_files = [
            f
            for f in plan.files
            if f not in ser_set
        ];
        ser_files = [
            f
            for f in plan.files
            if f in ser_set
        ];
        if par_files {
            _run_plan(
                TestPlan(files=par_files, explicit=plan.explicit),
                selector,
                reporter,
                xit,
                maxfail,
                jobs=min(workers, len(par_files)),
                isolate=iso_set,
                inline=False
            );
        }
        fails = reporter.failure_count();
        blocked = (xit and (fails > 0)) or (maxfail and (fails >= maxfail));
        if ser_files and not blocked {
            _run_plan(
                TestPlan(files=ser_files, explicit=plan.explicit),
                selector,
                reporter,
                xit,
                maxfail,
                jobs=1,
                isolate=set(ser_files),
                inline=False
            );
        }
    }
    failures = reporter.summarize(time.perf_counter() - started);
    _store_run_state(plan, reporter);
    if reporter.total_count() == 0 {
        return EXIT_NO_TESTS;
    }
    if failures {
        return EXIT_FAILED;
    }
    return EXIT_OK;
}

impl resolve_jobs(requested: (str | int | None) = None) -> int {
    import from jaclang.cli.workpool { resolve_jobs as _resolve_pool_jobs }
    return _resolve_pool_jobs(requested, env_var="JAC_TEST_JOBS");
}

impl _test_retire(served: int, rss_mb: int) -> bool {
    import from jaclang.cli.workpool { env_int }
    return _should_retire(
        served,
        env_int("JAC_TEST_RECYCLE", 25),
        rss_mb,
        env_int("JAC_TEST_RECYCLE_MB", 8192)
    );
}

impl _run_plan(
    plan: TestPlan,
    selector: (NameFilter | None),
    reporter: Reporter,
    xit: bool,
    maxfail: (int | None),
    jobs: int,
    isolate: (set[str] | None),
    inline: bool
) -> None {
    def job(request: dict[(str, any)]) -> list[dict[(str, any)]] {
        _CRASH_LOG[0] = str(request.get("crashlog", ""));
        outcomes = run_file(
            request["path"],
            selector,
            bool(request.get("explicit")),
            xit=xit,
            maxfail=maxfail,
            seen_failures=int(request.get("seen", 0))
        );
        return [o.to_wire() for o in outcomes];
    }
    def request_extra(idx: int, path: str) -> dict[(str, any)] {
        return {"explicit": path in plan.explicit, "seen": reporter.failure_count()};
    }
    def should_stop -> bool {
        fails = reporter.failure_count();
        if xit and (fails > 0) {
            return True;
        }
        return bool(maxfail) and (fails >= int(maxfail or 0));
    }
    def on_record(idx: int, record: dict[(str, any)]) -> None {
        path = plan.files[idx];
        crash = record.get("crash");
        if crash is not None {
            reporter.file_crashed(path, str(crash));
            return;
        }
        reporter.file_done();
        error = record.get("error");
        if error is not None {
            reporter.record(
                TestOutcome(
                    file=path,
                    name=os.path.basename(path),
                    status=ERROR,
                    message=str(error)
                )
            );
            return;
        }
        for item in (record.get("result") or []) {
            reporter.record(TestOutcome.from_wire(item));
        }
    }
    pool = WorkPool(
        items=list(plan.files),
        job=job,
        on_record=on_record,
        jobs=jobs,
        request_extra=request_extra,
        should_stop=should_stop,
        retire=_test_retire,
        worker_init=install_warning_filters,
        worker_exit=_cleanup_test_bases,
        isolate=isolate,
        rss_log_env="JAC_TEST_RSS_LOG",
        crash_prefix="jac-test-crash-"
    );
    if inline {
        pool.run_inline();
    } else {
        pool.run();
    }
}
