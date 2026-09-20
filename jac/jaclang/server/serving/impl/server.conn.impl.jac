impl ServingServer._handle_connection(
    reader: asyncio.StreamReader, writer: asyncio.StreamWriter
) {
    task = asyncio.current_task();
    cap = self.settings.limits.max_connections;
    if cap > 0 and len(self._active) >= cap {
        await self._bare_error(
            writer, 503, 'Service Unavailable', extra={'Retry-After': '1'}
        );
        try {
            writer.close();
        } except Exception {}
        return;
    }
    self._active.add(task);
    try {
        await self._connection_loop(reader, writer);
    } except (ConnectionError, asyncio.IncompleteReadError, TimeoutError) {} except asyncio.CancelledError {
        raise;
    } except Exception {
        _logger.exception("connection handler failed");
    } finally {
        self._active.discard(task);
        self._busy.discard(task);
        try {
            writer.close();
        } except Exception {}
    }
}

impl ServingServer._connection_loop(
    reader: asyncio.StreamReader, writer: asyncio.StreamWriter
) {
    keep_alive = True;
    first = True;
    while keep_alive {
        timeout = self.settings.timeouts.header
            if first
            else self.settings.timeouts.keepalive;
        first = False;
        try {
            request_line: bytes = await asyncio.wait_for(
                reader.readuntil(b'\n'), timeout=timeout
            );
        } except asyncio.TimeoutError {
            return;
        } except asyncio.LimitOverrunError {
            await self._bare_error(writer, 414, 'URI Too Long');
            return;
        } except asyncio.IncompleteReadError as eof {
            if eof.partial.strip() {
                await self._bare_error(writer, 400, 'Bad Request');
            }
            return;
        }
        if request_line.strip() == b'' {
            continue;
        }
        started = time.perf_counter();
        try {
            request = await self._read_request(reader, writer, request_line);
        } except ProtocolError as pe {
            await self._bare_error(writer, pe.status, pe.reason);
            return;
        } except asyncio.TimeoutError {
            await self._bare_error(writer, 408, 'Request Timeout');
            return;
        }
        if self.drain.draining and request.url.path not in HEALTH_PATHS {
            await self._bare_error(
                writer, 503, 'Service Unavailable', extra={'Retry-After': '1'}
            );
            self._log_access(request, Response(status_code=503), 0, started);
            self._release_body(request);
            return;
        }
        if self._is_ws_upgrade(request) {
            ws_task = asyncio.current_task();
            self._busy.add(ws_task);
            try {
                await self._handle_ws(request, reader, writer);
            } finally {
                self._busy.discard(ws_task);
            }
            return;
        }
        task = asyncio.current_task();
        self._busy.add(task);
        wrote = False;
        bytes_sent = 0;
        try {
            response = await self._dispatch(request);
            keep_alive = self._should_keep_alive(request) and not self._stopping;
            (wrote, bytes_sent) = await self._write_response(
                writer, request, response, keep_alive
            );
        } finally {
            self._busy.discard(task);
            self._release_body(request);
        }
        self._log_access(request, response, bytes_sent, started);
        self.requests_served += 1;
        if self.request_budget > 0 and self.requests_served >= self.request_budget {
            _logger.info(f"worker served {self.requests_served} requests; recycling");
            self.request_stop(EXIT_RECYCLE);
            keep_alive = False;
        }
        if not wrote {
            return;
        }
    }
}

impl ServingServer._dispatch(request: Request) -> Response {
    budget = self.settings.workers.request_timeout;
    if budget <= 0 {
        return await self.app.dispatch(request);
    }
    try {
        return await asyncio.wait_for(self.app.dispatch(request), timeout=budget);
    } except asyncio.TimeoutError {
        _logger.warning(
            f"request {request.method} {request.url.path} exceeded "
            f"{budget:.1f}s; answering 504"
        );
        import from jaclang.server.serving.datatypes { JSONResponse }
        resp = JSONResponse(
            status_code=504, content={'detail': f"request exceeded {budget:.0f}s"}
        );
        resp.headers.set('Connection', 'close');
        return resp;
    }
}
