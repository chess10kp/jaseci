impl ServingServer._release_body(request: Request) {
    spool = request.body_file;
    if spool is not None {
        try {
            spool.close();
        } except Exception {}
        request.body_file = None;
    }
    for uploads in request.upload_files.values() {
        for upload in uploads {
            try {
                upload.file.close();
            } except Exception {}
        }
    }
}

impl ServingServer._read_line(reader: asyncio.StreamReader, timeout: float) -> bytes {
    try {
        return await asyncio.wait_for(reader.readuntil(b'\n'), timeout=timeout);
    } except asyncio.LimitOverrunError {
        raise ProtocolError(status=431, reason='Request Header Fields Too Large');
    } except asyncio.IncompleteReadError {
        raise ProtocolError(status=400, reason='Bad Request');
    }
}

impl ServingServer._read_request(
    reader: asyncio.StreamReader, writer: asyncio.StreamWriter, request_line: bytes
) -> Request {
    limits = self.settings.limits;
    if len(request_line) > limits.max_request_line_bytes {
        raise ProtocolError(status=414, reason='URI Too Long');
    }
    line = request_line.decode('latin-1').rstrip('\r\n');
    parts = line.split(' ');
    if len(parts) != 3 {
        raise ProtocolError();
    }
    (method, target, http_version) = (parts[0], parts[1], parts[2]);
    if not _is_token(method) or not target {
        raise ProtocolError();
    }
    if http_version not in SUPPORTED_VERSIONS {
        raise ProtocolError(status=505, reason='HTTP Version Not Supported');
    }
    headers = Headers();
    count = 0;
    header_bytes = 0;
    header_timeout = self.settings.timeouts.header;
    while True {
        raw: bytes = await self._read_line(reader, header_timeout);
        if raw in (b'\r\n', b'\n') {
            break;
        }
        count += 1;
        header_bytes += len(raw);
        if count > limits.max_header_count or header_bytes > limits.max_header_bytes {
            raise ProtocolError(status=431, reason='Request Header Fields Too Large');
        }
        text = raw.decode('latin-1').rstrip('\r\n');
        if ':' not in text {
            raise ProtocolError();
        }
        (name, _, value) = text.partition(':');
        if not _is_token(name) {
            raise ProtocolError();
        }
        headers.append(name, value.strip());
    }
    if http_version == 'HTTP/1.1' and headers.get('Host') is None {
        raise ProtocolError();
    }
    expect = (headers.get('Expect') or '').lower();
    if expect == '100-continue' {
        writer.write(b'HTTP/1.1 100 Continue\r\n\r\n');
        await writer.drain();
    }
    (body, spool) = await self._read_body(reader, headers);
    split = urlsplit(target);
    peer = writer.get_extra_info('peername');
    peer_host = peer[0] if peer else '';
    forwarded = self._proxy.resolve(peer_host, headers);
    scheme = forwarded.scheme or self.scheme();
    netloc = forwarded.host or (headers.get('Host') or '');
    request_id = (headers.get('X-Request-Id') or '').strip()[:128] or uuid.uuid4().hex;
    return Request(
        method=method.upper(),
        url=URL(
            path=unquote(split.path) or '/',
            query=split.query,
            scheme=scheme,
            netloc=netloc
        ),
        headers=headers,
        query_params=QueryParams(raw=parse_query_string(split.query)),
        body=body,
        body_file=spool,
        client_host=forwarded.client,
        http_version=http_version,
        request_id=request_id
    );
}

impl ServingServer._declared_length(headers: Headers) -> (int | None) {
    values = headers.getlist('Content-Length');
    if not values {
        return None;
    }
    distinct = {v.strip() for v in values};
    if len(distinct) != 1 {
        raise ProtocolError();
    }
    text = distinct.pop();
    if not text.isdigit() {
        raise ProtocolError();
    }
    return int(text);
}

impl ServingServer._spool_sink(headers: Headers) -> any {
    content_type = (headers.get('Content-Type') or '').lower();
    if 'multipart/form-data' not in content_type {
        return None;
    }
    return tempfile.SpooledTemporaryFile(
        max_size=max(0, self.settings.limits.multipart_spool_bytes)
    );
}

impl ServingServer._read_body(
    reader: asyncio.StreamReader, headers: Headers
) -> tuple[bytes, any] {
    limits = self.settings.limits;
    body_timeout = self.settings.timeouts.body;
    transfer = [
        t.strip().lower() for raw in headers.getlist('Transfer-Encoding')
        for t in str(raw).split(',')
        if t.strip()
    ];
    length = self._declared_length(headers);
    if transfer {
        if length is not None {
            raise ProtocolError();
        }
        if transfer != ['chunked'] {
            raise ProtocolError(status=501, reason='Not Implemented');
        }
        sink = self._spool_sink(headers);
        chunks: list[bytes] = [];
        total = 0;
        while True {
            size_line: bytes = await self._read_line(reader, body_timeout);
            size_text = size_line.decode('latin-1').strip().split(';')[0];
            int_fn: any = int;
            try {
                size = int_fn(size_text, 16);
            } except ValueError {
                raise ProtocolError();
            }
            if size == 0 {
                while True {
                    trailer: bytes = await self._read_line(reader, body_timeout);
                    if trailer in (b'\r\n', b'\n') {
                        break;
                    }
                }
                break;
            }
            total += size;
            if total > limits.max_body_bytes {
                raise ProtocolError(status=413, reason='Payload Too Large');
            }
            piece: bytes = await asyncio.wait_for(
                reader.readexactly(size), timeout=body_timeout
            );
            await asyncio.wait_for(reader.readexactly(2), timeout=body_timeout);
            if sink is not None {
                sink.write(piece);
            } else {
                chunks.append(piece);
            }
        }
        if sink is not None {
            sink.seek(0);
            return (b'', sink);
        }
        return (b''.join(chunks), None);
    }
    size: int = length if length is not None else 0;
    if size <= 0 {
        return (b'', None);
    }
    if size > limits.max_body_bytes {
        raise ProtocolError(status=413, reason='Payload Too Large');
    }
    sink = self._spool_sink(headers);
    if sink is None {
        data: bytes = await asyncio.wait_for(
            reader.readexactly(size), timeout=body_timeout
        );
        return (data, None);
    }
    remaining: int = size;
    while remaining > 0 {
        step: int = min(65536, remaining);
        piece: bytes = await asyncio.wait_for(
            reader.readexactly(step), timeout=body_timeout
        );
        sink.write(piece);
        remaining -= step;
    }
    sink.seek(0);
    return (b'', sink);
}
