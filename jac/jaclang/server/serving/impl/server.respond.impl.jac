impl ServingServer._log_access(
    request: Request, response: Response, bytes_sent: int, started: float
) {
    record = AccessRecord(
        client=request.client_host or '-',
        method=request.method,
        path=request.url.path,
        query=request.url.query,
        version=request.http_version,
        status=response.status_code,
        bytes_sent=bytes_sent,
        duration_ms=(time.perf_counter() - started) * 1000.0,
        request_id=request.request_id,
        user_agent=request.headers.get('User-Agent') or '',
        referer=request.headers.get('Referer') or '',
        scheme=request.url.scheme,
        ts=time.time()
    );
    emit_access(record);
}

impl ServingServer._should_keep_alive(request: Request) -> bool {
    connection = (request.headers.get('Connection') or '').lower();
    if 'close' in connection {
        return False;
    }
    if request.http_version == 'HTTP/1.0' {
        return 'keep-alive' in connection;
    }
    return True;
}

impl ServingServer._standard_headers(
    request: Request, response: Response
) -> list[str] {
    lines: list[str] = [];
    if response.headers.get('Date') is None {
        lines.append(f"Date: {formatdate(usegmt=True)}");
    }
    if response.headers.get('Server') is None {
        lines.append(f"Server: {SERVER_HEADER}");
    }
    if request.request_id and response.headers.get('X-Request-Id') is None {
        lines.append(f"X-Request-Id: {request.request_id}");
    }
    return lines;
}

impl ServingServer._write_response(
    writer: asyncio.StreamWriter, request: Request, response: Response, keep_alive: bool
) -> tuple[bool, int] {
    is_head = request.method == 'HEAD';
    bodiless = response.status_code in (204, 304) or 100 <= response.status_code < 200;
    body: (bytes | None) = None;
    if not bodiless and response.stream is None {
        body = response.body_bytes();
    }
    if not bodiless {
        body = self._compression.apply(request, response, body);
    }
    stream = response.stream;
    legacy = request.http_version == 'HTTP/1.0';
    chunked = stream is not None and not is_head and not bodiless and not legacy;
    if stream is not None and legacy {
        keep_alive = False;
    }
    reason = _REASONS.get(response.status_code, 'OK');
    head_lines = [f"HTTP/1.1 {response.status_code} {reason}"];
    head_lines.extend(self._standard_headers(request, response));
    if response.headers.get('Content-Type') is None and not bodiless {
        head_lines.append(f"Content-Type: {response.content_type_header()}");
    }
    if chunked {
        head_lines.append('Transfer-Encoding: chunked');
    } elif bodiless {
        if response.headers.get('Content-Length') is None {
            head_lines.append('Content-Length: 0');
        }
    } elif stream is None {
        response.headers.remove('Content-Length');
        head_lines.append(f"Content-Length: {len(body or b'')}");
    }
    conn_override = (response.headers.get('Connection') or '').lower();
    if not conn_override {
        head_lines.append(
            'Connection: keep-alive' if keep_alive else 'Connection: close'
        );
    }
    for (name, value) in response.headers.items() {
        head_lines.append(f"{name}: {value}");
    }
    blob = ('\r\n'.join(head_lines) + '\r\n\r\n').encode('latin-1');
    sent = 0;
    try {
        writer.write(blob);
        if chunked {
            sent = await self._write_stream(writer, stream, chunked=True);
            writer.write(b'0\r\n\r\n');
        } elif bodiless or is_head {
            if stream is not None {
                await self._discard_stream(stream);
            }
        } elif stream is not None {
            sent = await self._write_stream(writer, stream, chunked=False);
        } else {
            writer.write(body or b'');
            sent = len(body or b'');
        }
        await writer.drain();
        return (keep_alive and conn_override != 'close', sent);
    } except (ConnectionError, OSError) {
        return (False, sent);
    }
}

impl ServingServer._discard_stream(stream: any) {
    try {
        if inspect.isasyncgen(stream) or hasattr(stream, '__aiter__') {
            async for _chunk in stream {
                continue;
            }
        } else {
            for _chunk in stream {
                continue;
            }
        }
    } except Exception {}
}

impl ServingServer._write_stream(
    writer: asyncio.StreamWriter, stream: any, chunked: bool
) -> int {
    sent = 0;
    if inspect.isasyncgen(stream) or hasattr(stream, '__aiter__') {
        async for chunk in stream {
            sent += self._write_chunk(writer, chunk, chunked);
            await writer.drain();
        }
    } else {
        for chunk in stream {
            sent += self._write_chunk(writer, chunk, chunked);
            await writer.drain();
        }
    }
    return sent;
}

impl ServingServer._write_chunk(
    writer: asyncio.StreamWriter, chunk: any, chunked: bool
) -> int {
    data = chunk if isinstance(chunk, bytes) else str(chunk).encode('utf-8');
    if not data {
        return 0;
    }
    if chunked {
        writer.write(f"{len(data):X}\r\n".encode('latin-1'));
        writer.write(data);
        writer.write(b'\r\n');
    } else {
        writer.write(data);
    }
    return len(data);
}

impl ServingServer._bare_error(
    writer: asyncio.StreamWriter,
    status: int,
    reason: str,
    extra: (dict[str, str] | None) = None
) {
    body = f'{{"detail": "{reason}"}}'.encode('utf-8');
    lines = [
        f"HTTP/1.1 {status} {reason}",
        f"Date: {formatdate(usegmt=True)}",
        f"Server: {SERVER_HEADER}",
        "Content-Type: application/json",
        f"Content-Length: {len(body)}",
        "Connection: close"
    ];
    for (k, v) in (extra or {}).items() {
        lines.append(f"{k}: {v}");
    }
    blob = ('\r\n'.join(lines) + '\r\n\r\n').encode('latin-1');
    try {
        writer.write(blob + body);
        await writer.drain();
    } except (ConnectionError, OSError) {}
}
