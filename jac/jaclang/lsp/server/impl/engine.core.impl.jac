impl Task.postinit -> None {
    self.task_id = Task._task_id;
    self.cancel_token = threading.Event();
    Task._task_id += 1;
}

impl JacLangServer.postinit -> None {
    self.name = 'jac-lsp';
    self.version = 'v0.1';
    self._write_lock = threading.Lock();
    self.program = JacProgram();

    self.program.deps.tracking = True;
    self._state_lock = ReadWriteLock();
    self.module_manager = ModuleManager(self.program, self.sem_managers);

    self._idle_event = threading.Event();
    self._idle_event.set();

    self.worker_future = flow self.dispatcher() ;
}

impl JacLangServer.type_check(file_uri: str) -> None {
    DEBOUNCE_DELAY = 0.3;
    with self._state_lock.write_lock() {
        if self._debounce_timer {
            self._debounce_timer.cancel();
            self._debounce_timer = None;
        }
        if self.last_task and not self.last_task.cancel_token.is_set() {
            self.last_task.cancel_token.set();
            if file_uri != self.last_task.file_uri {
                self.dirty_files[self.last_task.file_uri] = True;
            }
            self.debug(
                " Cancelling id: "
                    + str(self.last_task.task_id)
                    + " "
                    + str(time.time())
            );
        }
        self._debounce_timer = threading.Timer(
            DEBOUNCE_DELAY, self._do_type_check, args=[file_uri]
        );
        self._debounce_timer.start();
    }
}

impl JacLangServer._do_type_check(file_uri: str) -> None {
    self._fanout_dependents(file_uri);
    with self._state_lock.write_lock() {
        self._debounce_timer = None;
        self._idle_event.clear();
        self.debug("Debounce triggered, starting type check for " + file_uri);
        self.last_task = Task(file_uri);
        self.pipe.append(self.last_task);
        self._work_event.set();
    }
}

impl JacLangServer._fanout_dependents(file_uri: str) -> None {
    import from pathlib { Path }
    fs_path = uris.to_fs_path(file_uri);
    if fs_path is None {
        return;
    }
    try {
        resolved = str(Path(fs_path).resolve());
    } except OSError {
        return;
    }

    if not self._dep_edges_seeded {
        self._dep_edges_seeded = True;
        try {
            ws_root = self.workspace?.root_path;
            if isinstance(ws_root, str) and ws_root {
                import from jaclang.compiler.driver.ifacecache { seed_dep_edges }
                seed_dep_edges(self.program, ws_root);
            }
        } except Exception {}
    }
    self.program.invalidate_module(resolved);
    dependents = self.program.transitive_dependents(resolved);
    if not dependents {
        return;
    }
    with self._state_lock.write_lock() {
        open_by_real: dict[str, str] = {};
        for open_uri in self.workspace._text_documents {
            open_fs = uris.to_fs_path(open_uri);
            if open_fs is None {
                continue;
            }
            try {
                open_by_real[str(Path(open_fs).resolve())] = open_uri;
            } except OSError {
                continue;
            }
        }
        for dep_path in dependents {
            dep_uri = open_by_real.get(dep_path);
            if dep_uri is None {
                try {
                    dep_uri = open_by_real.get(str(Path(dep_path).resolve()));
                } except OSError {
                    dep_uri = None;
                }
            }
            if dep_uri is None or dep_uri == file_uri {
                continue;
            }
            self.dirty_files[dep_uri] = True;
            self._idle_event.clear();
        }
        if self.dirty_files {
            self._work_event.set();
        }
    }
}

impl JacLangServer.type_check_file(
    file_uri: str, cancel_token: threading.Event | None = None
) -> bool {
    if cancel_token and cancel_token.is_set() {
        return False;
    }
    try {
        document = self.workspace.get_text_document(file_uri);
        fs_path = document.path;

        base = discover_base_file(fs_path);
        main_path = base or fs_path;

        files_to_check = [main_path];
        files_to_check.extend(discover_annex_files(main_path, '.impl.jac'));
        files_to_check.extend(discover_annex_files(main_path, '.test.jac'));

        for f in files_to_check {
            self._clear_alerts_for_file(f);
        }

        import from jaclang.compiler.driver.compile_options { CompileOptions }
        main_doc = self.workspace.get_text_document(_uri_of(main_path));

        import from jaclang.compiler.frontend.parser.frontend {
            parse_diags,
            _replay_diags
        }
        import from jaclang.compiler.frontend.parser.lexer { Lexer as _Lexer }
        import from jaclang.compiler.frontend.parser.parser { Parser as _SyntaxParser }
        import from jaclang.compiler.frontend.unitree { Source as _Src }
        (_syn_had, _pd, _ld) = parse_diags(main_doc.source, main_path);
        if _pd or _ld {
            _dsrc = _Src(main_doc.source, mod_path=main_path);
            _replay_diags(_ld, _Lexer, self.program, _dsrc);
            _replay_diags(_pd, _SyntaxParser, self.program, _dsrc);
            _syn_errors = list(self.program.errors_had);
            _syn_warnings = list(self.program.warnings_had);
            self.publish_diagnostics(
                _uri_of(main_path),
                utils.gen_diagnostics(main_path, _syn_errors, _syn_warnings)
            );
            for f in files_to_check {
                self._clear_alerts_for_file(f);
            }
        }
        if cancel_token and cancel_token.is_set() {
            return False;
        }
        import from jaclang.project.workspace { workspace_for_path }
        ws = workspace_for_path(main_path);
        app = ws.app_for_path(main_path) if ws is not None else None;
        proj_root = ws.project_root if ws is not None else None;
        targets: list[tuple[str, str]] = [];
        if ws is None or app is not None {
            targets = [(app.name if app else '', app.kind if app else '')];
        } else {
            targets = [
                (a.name, a.kind) for a in list(ws.apps.values())[:LSP_SHARED_APP_LIMIT]
            ];
        }
        multi = len(targets) > 1;
        collected: list[tuple[str, list[Alert], list[Alert]]] = [];
        build: (uni.Module | None) = None;
        for (app_name, app_kind) in targets {
            build = self.program.compile(
                file_path=main_path,
                use_str=main_doc.source,
                options=CompileOptions(
                    no_cgen=True,
                    force_target_program=True,
                    cancel_token=cancel_token,
                    target_app=app_name,
                    app_kind=app_kind,
                    entry_point=ws.apps[app_name].`entry
                        if ws is not None and app_name in ws.apps
                        else main_path,
                    project_root=proj_root
                )
            );
            if cancel_token and cancel_token.is_set() {
                return False;
            }
            if multi {
                collected.append(
                    (
                        app_name,
                        [
                            e
                            for e in self.program.errors_had
                            if e.loc.mod_path in files_to_check
                        ],
                        [
                            w
                            for w in self.program.warnings_had
                            if w.loc.mod_path in files_to_check
                        ]
                    )
                );
                for f in files_to_check {
                    self._clear_alerts_for_file(f);
                }
            }
        }
        if multi {
            (merged_errs, merged_warns) = _merge_app_alerts(collected, len(targets));
            self.program.errors_had.extend(merged_errs);
            self.program.warnings_had.extend(merged_warns);
        }
        assert build is not None;
        self.update_modules(main_path, build, files=files_to_check);

        all_errors = list(self.program.errors_had);
        all_warnings = list(self.program.warnings_had);
        for f in files_to_check {
            self.publish_diagnostics(
                _uri_of(f), utils.gen_diagnostics(f, all_errors, all_warnings)
            );
        }
    } except Exception as e {
        self.log_error(f"Error during type check: {e}");
        return False;
    }
    return True;
}

impl JacLangServer.dispatcher -> None {
    while True {
        start_time = time.time();
        self.debug("Dispatcher waiting for work...");

        self._work_event.`wait();

        task: Task | None = None;
        should_exit = False;
        with self._state_lock.write_lock() {
            if self._shutdown_called {
                should_exit = True;
            } elif self.pipe {
                task = self.pipe.popleft();
            } elif self.dirty_files {
                (file_uri, _) = self.dirty_files.popitem();
                task = Task(file_uri);
            } else {
                self._work_event.clear();
                self._idle_event.set();
            }
        }
        if should_exit {
            self.debug("Shutting down dispatcher");
            break;
        }
        if not task {
            continue;
        }

        self.debug("Dispatching task id: " + str(task.task_id));
        try {
            self.type_check_file(task.file_uri, cancel_token=task.cancel_token);
            self.lsp.send_request(lspt.WORKSPACE_SEMANTIC_TOKENS_REFRESH);
        } finally {}
        if task.cancel_token.is_set() {
            self.debug(
                "Task cancelled id: " + str(task.task_id) + " " + str(time.time())
            );
        } else {
            task.cancel_token.set();
            elapsed = time.time() - start_time;
            self.debug(
                f"Task completed id: {str(task.task_id)}, took: {elapsed:.4f}s {str(
                    task.file_uri
                )}"
            );
        }

        with self._state_lock.read_lock() {
            has_more = bool(self.pipe) or bool(self.dirty_files);
        }
        if not has_more {
            self._idle_event.set();
        }
    }
}

impl JacLangServer.shutdown -> None {
    with self._state_lock.write_lock() {
        if self._shutdown_called {
            return;
        }
        self._shutdown_called = True;
        if self._debounce_timer {
            self._debounce_timer.cancel();
            self._debounce_timer = None;
        }
    }

    try {
        if self?.worker_future and not self?.worker_future.done() {
            self._work_event.set();
            wait self.worker_future ;
        }
    } finally {
        super.shutdown();
    }
}

impl JacLangServer.close_module(uri: str) -> None {
    fs_path = uris.to_fs_path(uri);
    with self._state_lock.write_lock() {
        if fs_path in self.sem_managers {
            del self.sem_managers[fs_path];
        }
    }
}

impl JacLangServer.delete_module(uri: str) -> None {
    with self._state_lock.write_lock() {
        if uri in self.program.mod.hub {
            self.program.mod.hub.pop(uri);
        }
        if uri in self.sem_managers {
            del self.sem_managers[uri];
        }
    }
}

impl JacLangServer.rename_module(old_path: str, new_path: str) -> None {
    with self._state_lock.write_lock() {
        if old_path in self.program.mod.hub and new_path != old_path {
            self.program.mod.hub[new_path] = self.program.mod.hub[old_path];
            self.sem_managers[new_path] = self.sem_managers[old_path];

            self.program.mod.hub.pop(old_path);
            del self.sem_managers[old_path];
        }
    }
}

impl JacLangServer.wait_till_idle_sync(file_uri: str) -> None {
    self.debug("Waiting for server to be idle (sync)...");

    with self._state_lock.write_lock() {
        if self._debounce_timer {
            self._debounce_timer.cancel();
            self._debounce_timer = None;
        }
    }
    self._do_type_check(file_uri);

    while True {
        self._idle_event.`wait();
        with self._state_lock.read_lock() {
            has_pending_work = bool(
                self.pipe or self.dirty_files or self._debounce_timer
            );
        }
        if not has_pending_work {
            break;
        }
        self._idle_event.clear();
        self._work_event.set();
    }
    self.debug("Server is now idle");
}

impl JacLangServer.update_modules(
    file_path: str,
    build: uni.Module,
    need: bool = True,
    files: (list[str] | None) = None
) -> None {
    self.log_py(f"Updating modules for {file_path}");
    with self._state_lock.write_lock() {
        self.module_manager.update(file_path, build, update_annexed=need, files=files);
    }
}

impl JacLangServer._clear_alerts_for_file(file_path: str) -> None {
    with self._state_lock.write_lock() {
        self.module_manager.clear_alerts_for_file(file_path);
    }
}

impl JacLangServer.diagnostics.getter -> dict[str, list[lspt.Diagnostic]] {
    with self._state_lock.read_lock() {
        all_errors = list(self.program.errors_had);
        all_warnings = list(self.program.warnings_had);
        result = {};
        for file_path in self.program.mod.hub {
            uri = uris.from_fs_path(file_path);
            result[uri] = utils.gen_diagnostics(file_path, all_errors, all_warnings);
        }
        return result;
    }
}
