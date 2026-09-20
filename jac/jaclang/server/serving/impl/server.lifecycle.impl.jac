impl ServingServer.postinit{
    if not self.host {
        self.host = self.settings.host;
    }
    if self.port is None {
        self.port = self.settings.port;
    }
    self.drain.timeout = self.settings.timeouts.drain;
    self._compression = CompressionPolicy(
        enabled=self.settings.compression.enabled,
        min_bytes=self.settings.compression.min_bytes,
        level=self.settings.compression.level
    );
    self._proxy = ProxyResolver(trusted=list(self.settings.proxy.trusted));
    self.app.state['drain'] = self.drain;
}

impl ServingServer.scheme -> str {
    return self.settings.scheme();
}

impl ServingServer._serve(
    on_ready: (Callable[[int], None] | None) = None,
    port_retries: int = PORT_RETRY_LIMIT
) {
    self._loop = asyncio.get_running_loop();
    self._stop_event = asyncio.Event();
    self._executor = SyncExecutor(threads=self.settings.workers.threads);
    self._executor.install(self._loop);
    listener = self.sock;
    if listener is None {
        listener = bind_listener(
            self.host,
            int(self.port or 0),
            backlog=self.settings.limits.backlog,
            port_retries=port_retries
        );
    }
    ssl_ctx = self.settings.tls.build_context();
    self._server = await asyncio.start_server(
        self._handle_connection,
        sock=listener,
        ssl=ssl_ctx,
        limit=max(4096, self.settings.limits.max_header_bytes),
        backlog=self.settings.limits.backlog
    );
    try {
        self.bound_port = int(listener.getsockname()[1]);
    } except Exception {
        self.bound_port = int(self.port or 0);
    }
    self.port = self.bound_port;
    if self.install_signals {
        self._install_signal_handlers();
    }
    pulse: any = None;
    if self.heartbeat is not None {
        pulse = self._loop.create_task(self._heartbeat_loop());
    }
    if on_ready is not None {
        on_ready(self.bound_port);
    }
    try {
        await self._stop_event.`wait();
    } finally {
        self.drain.start(self.drain.reason or 'shutdown');
        self._server.close();
        await self._drain();
        try {
            await asyncio.wait_for(
                self._server.wait_closed(), timeout=self.settings.timeouts.close
            );
        } except asyncio.TimeoutError {}
        await self.app.shutdown();
        if pulse is not None {
            pulse.cancel();
        }
        if self._executor is not None {
            self._executor.shutdown(`wait=False);
        }
    }
}

impl ServingServer._install_signal_handlers{
    def _on_signal(name: str) {
        self.drain.start(f"signal {name}");
        self.request_stop();
    }
    for sig_name in ('SIGTERM', 'SIGINT') {
        sig = getattr(signal, sig_name, None);
        if sig is None {
            continue;
        }
        try {
            self._loop.add_signal_handler(sig, _on_signal, sig_name);
        } except (NotImplementedError, RuntimeError, ValueError) {}
    }
}

impl ServingServer._heartbeat_loop{
    beat: any = self.heartbeat;
    while not self._stopping {
        try {
            beat();
        } except Exception {
            _logger.debug('heartbeat failed', exc_info=True);
        }
        await asyncio.sleep(HEARTBEAT_SECONDS);
    }
}

impl ServingServer._drain{
    self._stopping = True;
    for t in list(self._active) {
        if t not in self._busy and not t.done() {
            t.cancel();
        }
    }
    pending = [
        t
        for t in self._busy
        if not t.done()
    ];
    if not pending {
        return;
    }
    try {
        await asyncio.wait_for(
            asyncio.gather(*pending, return_exceptions=True),
            timeout=self.drain.remaining()
        );
    } except asyncio.TimeoutError {
        _logger.warning(
            f"drain: {len(pending)} request(s) still running after "
            f"{self.drain.timeout:.1f}s; cancelling"
        );
        for t in pending {
            t.cancel();
        }
    }
}

impl ServingServer.request_stop(exit_code: int = EXIT_OK) {
    if exit_code != EXIT_OK {
        self.exit_code = exit_code;
    }
    if self._loop is None or self._stop_event is None {
        return;
    }
    self._loop.call_soon_threadsafe(self._stop_event.set);
}

impl ServingServer.run(
    on_ready: (Callable[[int], None] | None) = None,
    port_retries: int = PORT_RETRY_LIMIT
) -> int {
    main_coro: any = self._serve(on_ready=on_ready, port_retries=port_retries);
    try {
        asyncio.run(main_coro);
    } except KeyboardInterrupt {}
    return self.exit_code;
}

impl ServingServer.serve_background(
    on_ready: (Callable[[int], None] | None) = None,
    port_retries: int = PORT_RETRY_LIMIT
) -> Callable[[], None] {
    ready = threading.Event();
    self.install_signals = False;

    def _notify(port: int) {
        ready.set();
        if on_ready is not None {
            on_ready(port);
        }
    }

    notify_fn: any = _notify;

    def _target {
        self.run(on_ready=notify_fn, port_retries=port_retries);
    }
    thread = threading.Thread(target=_target, daemon=True);
    thread.start();
    ready.`wait(timeout=30);

    def _stop {
        self.request_stop();
        thread.join(timeout=self.drain.timeout + 5);
    }
    return _stop;
}
