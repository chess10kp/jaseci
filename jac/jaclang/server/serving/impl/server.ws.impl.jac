impl ServingServer._is_ws_upgrade(request: Request) -> bool {
    upgrade = (request.headers.get('Upgrade') or '').lower();
    connection = (request.headers.get('Connection') or '').lower();
    return upgrade == 'websocket' and 'upgrade' in connection;
}

impl ServingServer._ws_origin_allowed(request: Request) -> bool {
    origin = (request.headers.get('Origin') or '').strip();
    if not origin {
        return True;
    }
    allowed = self.settings.websocket.allowed_origins;
    if '*' in allowed or origin in allowed {
        return True;
    }
    origin_host = urlsplit(origin).netloc.lower();
    request_host = (request.headers.get('Host') or '').strip().lower();
    return bool(origin_host) and origin_host == request_host;
}

impl ServingServer._handle_ws(
    request: Request, reader: asyncio.StreamReader, writer: asyncio.StreamWriter
) {
    started = time.perf_counter();
    if not self._ws_origin_allowed(request) {
        await self._bare_error(writer, 403, 'Forbidden');
        self._log_access(request, Response(status_code=403), 0, started);
        return;
    }
    (ep, path_params) = self.app.router.resolve_ws(request.url.path);
    key = request.headers.get('Sec-WebSocket-Key') or '';
    if ep is None or not key {
        await self._bare_error(writer, 404, 'Not Found');
        self._log_access(request, Response(status_code=404), 0, started);
        return;
    }
    self._log_access(request, Response(status_code=101), 0, started);
    ws = WebSocket(
        reader=reader,
        writer=writer,
        headers=request.headers,
        url=request.url,
        query_params=request.query_params,
        path_params=path_params,
        client_host=request.client_host,
        accept_key=compute_accept_key(key)
    );
    ws_settings = self.settings.websocket;
    if ws_settings.max_message_bytes > 0 {
        ws.max_message_bytes = ws_settings.max_message_bytes;
    }
    ws.start_keepalive(ws_settings.ping_interval, ws_settings.ping_timeout);
    handler_fn: any = ep.handler;
    try {
        result = handler_fn(ws);
        if inspect.isawaitable(result) {
            await result;
        }
    } except Exception {
        _logger.exception(f"websocket handler failed: {ep.path}");
    } finally {
        ws.stop_keepalive();
        if not ws.closed {
            await ws.close(1000);
        }
    }
}
