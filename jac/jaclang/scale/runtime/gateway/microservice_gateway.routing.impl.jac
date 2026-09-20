import from jaclang.server.serving.ws { WebSocket }
import from jaclang.server.serving.endpoint { WSEndPoint }
import from jaclang.scale.runtime.routing {
    GATEWAY_BUILTIN_PREFIXES,
    GATEWAY_BARE_API_PATHS,
    GATEWAY_DISCOVERY_SEGMENTS,
    GATEWAY_REPLICATED_SEGMENTS
}


glob _BUILTIN_PREFIXES: tuple[str, ...] = GATEWAY_BUILTIN_PREFIXES,
     _BUILTIN_EXACT: set[str] = GATEWAY_BARE_API_PATHS,
     _DISCOVERY_SEGMENTS: set[str] = set(GATEWAY_DISCOVERY_SEGMENTS),
     _REPLICATED_SEGMENTS: set[str] = set(GATEWAY_REPLICATED_SEGMENTS);


def _install_ws_catchall(gw: MicroserviceGateway) {
    import from jaclang.scale.runtime.middleware.ws_forward { websocket_forward }
    import from jaclang.scale.runtime.gateway.service_registry { ServiceStatus }

    async def ws_proxy(websocket: WebSocket) -> None {
        ws_path: str = websocket.path_params.get('ws_path', '');
        if gw.drain.draining {
            await websocket.close(code=1012);
            return;
        }
        full_path: str = "/" + ws_path;
        matched = gw.registry.match_route(full_path);
        if not matched {
            await gw.refresh_app_routes();
            matched = gw.registry.entries.get(gw.route_table.owner(full_path));
        }
        page_base: str = "";
        if not matched {
            matched = gw.root_member();
            if matched is not None and matched.owns_root() {
                page_base = matched.page_url;
            }
        }
        if not matched or not (page_base or matched.url) {
            await websocket.accept();
            await websocket.close(code=1008);
            return;
        }
        if matched.status not in (ServiceStatus.HEALTHY, ServiceStatus.STARTING) {
            await websocket.accept();
            await websocket.close(code=1013);
            return;
        }
        remaining: str = full_path;
        if not matched.is_root and full_path.startswith(matched.prefix) {
            remaining = full_path[len(matched.prefix):];
        }
        remaining = remaining or "/";
        query: str = str(websocket.url.query);
        target_http: str = f"{page_base or matched.url}{remaining}";
        if query {
            target_http = f"{target_http}?{query}";
        }

        async def _accept_as_upstream_did(selected: str) {
            await websocket.accept(subprotocol=selected);
        }
        req_headers: dict[str, str] = dict(websocket.headers.items());
        logger.debug(f"ws proxy: {full_path} -> {target_http}");
        await websocket_forward(
            websocket, target_http, req_headers, on_upstream=_accept_as_upstream_did
        );
    }
    gw.app.add_ws_endpoint(WSEndPoint(path="/{ws_path:path}", handler=ws_proxy));
}


impl MicroserviceGateway.service_base_url(service_entry: ServiceEntry) -> str {
    import jaclang;

    registry: dict[str, str] = jaclang.JacRuntime.get_sv_registry();
    return registry.get(service_entry.name, service_entry.url);
}


impl MicroserviceGateway.resolve_target_url(
    service_entry: ServiceEntry, path: str, query: str
) -> str {
    base_url: str = self.service_base_url(service_entry);

    remaining: str = path[len(service_entry.prefix):];
    if not remaining {
        remaining = "/";
    }
    target: str = f"{base_url}{remaining}";
    if query {
        target = f"{target}?{query}";
    }
    return target;
}


impl MicroserviceGateway.build_forward_headers(request: Request) -> dict[str, str] {
    import from jaclang.scale.runtime.context.trace_ctx {
        get_current_trace,
        ensure_trace_id
    }
    fwd: dict[str, str] = {};
    for (key, value) in request.headers.items() {
        if key.lower() not in HOP_BY_HOP_HEADERS and key.lower() != "x-forwarded-for" {
            fwd[key] = value;
        }
    }

    peer: str = request.client_host or "unknown";
    fwd["X-Forwarded-For"] = ", ".join(
        request.headers.getlist("X-Forwarded-For") + [peer]
    );

    trace = get_current_trace() or ensure_trace_id(request.headers.get("X-Trace-Id"));
    fwd["X-Trace-Id"] = trace;

    import from jaclang.scale.runtime.context.tracing { current_traceparent }
    tp = current_traceparent(trace);
    if tp {
        fwd["traceparent"] = tp;
    }
    return fwd;
}


impl MicroserviceGateway.handle_health -> Response {
    statuses = [e.status for e in self.registry.entries.values()];
    degraded = `any(
        s in (ServiceStatus.UNHEALTHY, ServiceStatus.STOPPED) for s in statuses
    );
    if not statuses or all(s == ServiceStatus.HEALTHY for s in statuses) {
        overall = "healthy";
    } elif degraded {
        overall = "degraded";
    } else {
        overall = "starting";
    }
    return JSONResponse(
        status_code=503 if degraded else 200,
        content={"status": overall, "services": self.registry.health_summary()}
    );
}


impl MicroserviceGateway.handle_health_live -> Response {
    return JSONResponse(status_code=200, content={"status": "alive"});
}


impl MicroserviceGateway.handle_health_ready -> Response {
    if self.drain.draining {
        return JSONResponse(
            status_code=503, content={"status": "draining", "ready": False}
        );
    }
    return JSONResponse(status_code=200, content={"status": "ready"});
}


impl MicroserviceGateway.aggregate_graph_data(request: Request) -> Response | None {
    import json;
    import from jaclang.scale.runtime.context.util { http_forward_timeout }
    import from jaclang.scale.runtime.transport.http_forward { raw_forward }

    fwd_headers = self.build_forward_headers(request);
    query: str = str(request.url.query);

    merged_nodes: dict[str, dict[str, any]] = {};
    edge_keys: set = set();
    merged_edges: list[dict[str, any]] = [];
    fragments: int = 0;

    for (svc_name, svc_entry) in self.eligible_services() {
        target_url = f"{self.service_base_url(svc_entry)}/graph/data";
        if query {
            target_url = f"{target_url}?{query}";
        }
        result = await raw_forward(
            "GET",
            target_url,
            fwd_headers,
            b"",
            timeout=int(http_forward_timeout(svc_name))
        );
        if result is None {
            continue;
        }
        (status, _headers, body) = result;
        if status != 200 {
            continue;
        }
        try {
            frag = json.loads(body);
        } except ValueError {
            continue;
        }
        if not isinstance(frag, dict) {
            continue;
        }
        fragments += 1;
        for n in (frag.get("nodes") or []) {
            nid = str(n.get("id"));
            if nid not in merged_nodes {
                merged_nodes[nid] = n;
            }
        }
        for e in (frag.get("edges") or []) {
            key = (str(e.get("from")), str(e.get("to")), str(e.get("label", "")));
            if key not in edge_keys {
                edge_keys.add(key);
                merged_edges.append(e);
            }
        }
    }

    if fragments == 0 {
        return None;
    }
    return JSONResponse(
        status_code=200,
        content={
            "version": "1.0",
            "nodes": list(merged_nodes.values()),
            "edges": merged_edges
        }
    );
}


impl MicroserviceGateway.handle_builtin_passthrough(
    request: Request, path: str
) -> Response | None {
    is_builtin = path.startswith(_BUILTIN_PREFIXES) or path in _BUILTIN_EXACT;
    if not is_builtin {
        return None;
    }

    if request.method == "GET" and path == "/graph/data" {
        agg = await self.aggregate_graph_data(request);
        if agg is not None {
            return agg;
        }
    }

    stripped: str = path.strip("/");
    first_seg: str = stripped.split("/")[0] if stripped else "";
    root_svc = self.root_member();
    if first_seg in _DISCOVERY_SEGMENTS {
        return await self.probe_services(request, path, self.eligible_services());
    }
    if first_seg in _REPLICATED_SEGMENTS {
        return await self.deliver_once(request, path);
    }

    owner = await self.resolve_learned_owner(path);
    if owner is not None {
        return await self.forward_root_path(request, owner, path);
    }
    unknown: list[tuple[str, ServiceEntry]] = [
        (name, svc)
        for (name, svc) in self.eligible_services()
        if not self.route_table.is_learned(name)
    ];
    if not unknown {
        if root_svc is not None {
            return None;
        }
        import from jaclang.scale.runtime.context.errors { not_found }
        return not_found(path, message="No service declares");
    }
    return await self.probe_services(request, path, unknown);
}


impl MicroserviceGateway.eligible_services -> list[tuple[str, ServiceEntry]] {
    return [
        (name, svc)
        for (name, svc) in self.registry.entries.items()
        if svc.is_routable()
    ];
}


impl MicroserviceGateway.root_member -> ServiceEntry | None {
    return self.registry.root_entry();
}


impl MicroserviceGateway.shell_answers(request: Request, path: str) -> bool {
    if request.method != "GET" {
        return False;
    }
    if not (Path(self.client_dist_dir) / "index.html").is_file() {
        return False;
    }
    return not path.lstrip("/") or "text/html" in request.headers.get("accept", "");
}


impl MicroserviceGateway.forward_to_root(
    request: Request, path: str
) -> Response | None {
    root_svc = self.root_member();
    if root_svc is None {
        return None;
    }
    if not root_svc.is_routable() {
        if self.shell_answers(request, path) {
            return None;
        }
        import from jaclang.scale.runtime.context.errors { service_unavailable }
        return service_unavailable(root_svc.name, "not accepting traffic");
    }
    if not root_svc.owns_root() {
        return None;
    }
    if root_svc.page_url {
        page_resp = await self.forward_root_path(
            request, root_svc, path, root_svc.page_url
        );
        if page_resp is not None and page_resp.status_code not in (502, 504) {
            return page_resp;
        }
        logger.warning(
            f"client dev server at {root_svc.page_url} did not answer {path}; "
            f"falling back to {root_svc.name}'s own page rendering"
        );
    }
    return await self.forward_root_path(request, root_svc, path);
}


impl MicroserviceGateway.forward_static_to_root(
    request: Request, path: str
) -> Response | None {
    if request.method != "GET" or not path.startswith("/static/") {
        return None;
    }
    root_svc = self.root_member();
    if root_svc is None or not root_svc.is_routable() {
        return None;
    }
    return await self.forward_root_path(request, root_svc, path);
}


impl MicroserviceGateway.resolve_learned_owner(path: str) -> ServiceEntry | None {
    svc_name: str = self.route_table.owner(path);
    if svc_name and svc_name not in self.registry.entries {
        self.route_table.forget(svc_name);
        svc_name = "";
    }
    if not svc_name {
        if not await self.refresh_app_routes() {
            return None;
        }
        svc_name = self.route_table.owner(path);
    }
    return self.registry.entries.get(svc_name) if svc_name else None;
}


impl MicroserviceGateway.forward_root_path(
    request: Request, service_entry: ServiceEntry, path: str, base_url: str = ""
) -> Response | None {
    if not service_entry.is_routable() {
        import from jaclang.scale.runtime.context.errors { service_unavailable }
        return service_unavailable(service_entry.name, "not accepting traffic");
    }
    query: str = str(request.url.query);
    base: str = base_url or self.service_base_url(service_entry);
    target_url: str = f"{base}{path}";
    if query {
        target_url = f"{target_url}?{query}";
    }
    logger.info(f"Forward: {request.method} {path} -> {target_url}");
    return await self.forward_to(request, service_entry, target_url);
}


impl MicroserviceGateway.deliver_once(request: Request, path: str) -> Response | None {
    eligible = self.eligible_services();
    if not eligible {
        import from jaclang.scale.runtime.context.errors { not_found }
        return not_found(path, message="Not found on any service");
    }

    ready = [
        (name, svc)
        for (name, svc) in eligible
        if svc.status == ServiceStatus.HEALTHY
    ];
    pool = ready or eligible;
    for (_app_name, candidate) in pool {
        if candidate.owns_root() {
            return await self.forward_root_path(request, candidate, path);
        }
    }
    (_name, svc) = pool[0];
    return await self.forward_root_path(request, svc, path);
}


impl MicroserviceGateway.probe_services(
    request: Request, path: str, candidates: list[tuple[str, ServiceEntry]]
) -> Response {
    import from jaclang.scale.runtime.context.util { http_forward_timeout }
    import from jaclang.scale.runtime.transport.http_forward { stream_forward }

    fwd_headers = self.build_forward_headers(request);
    body: bytes = request.body;
    query: str = str(request.url.query);

    ordered: list[tuple[str, ServiceEntry]] = sorted(
        candidates,
        key=lambda (pair: tuple[str, ServiceEntry]) { (
            0 if pair[1].is_root else 1,
            0 if pair[1].status == ServiceStatus.HEALTHY else 1
        ); }
    );
    for (svc_name, svc_entry) in ordered {
        base: str = svc_entry.page_url
            if (svc_entry.owns_root() and svc_entry.page_url)
            else self.service_base_url(svc_entry);
        target_url = f"{base}{path}";
        if query {
            target_url = f"{target_url}?{query}";
        }
        logger.info(f"Probe: {request.method} {path} -> {target_url}");

        fr = await stream_forward(
            request.method,
            target_url,
            fwd_headers,
            body,
            timeout=int(http_forward_timeout(svc_name))
        );
        if fr is None {
            import from jaclang.scale.runtime.context.errors { service_unavailable }
            return service_unavailable(svc_name, "transport_error");
        }
        if fr.status in (404, 405) {
            await fr.cleanup();
            continue;
        }
        return fr.to_response();
    }
    import from jaclang.scale.runtime.context.errors { not_found }
    return not_found(path, message="Not found on any service");
}


impl MicroserviceGateway.handle_admin(path: str) -> Response | None {
    if path == "/admin" {
        import from jaclang.server.serving.datatypes { RedirectResponse }
        return RedirectResponse(url="/admin/", status_code=302);
    }
    if path.startswith("/admin/") {
        asset_path: str = path[7:];
        return self.serve_admin_asset(asset_path);
    }
    return None;
}


impl MicroserviceGateway.forward_to(
    request: Request, service_entry: ServiceEntry, target_url: str
) -> Response | None {
    import from jaclang.scale.runtime.context.errors {
        service_unavailable,
        gateway_timeout
    }
    import from jaclang.scale.runtime.transport.http_forward { stream_forward }
    import from jaclang.scale.runtime.context.util { http_forward_timeout }

    if service_entry.status not in (ServiceStatus.HEALTHY, ServiceStatus.STARTING) {
        return service_unavailable(service_entry.name, service_entry.status.value);
    }

    fwd_headers = self.build_forward_headers(request);
    body: bytes = request.body;

    timeout = http_forward_timeout(service_entry.name);
    fr = await stream_forward(
        request.method, target_url, fwd_headers, body, timeout=int(timeout)
    );
    if fr is None {
        return gateway_timeout(service_entry.name);
    }
    return fr.to_response();
}


impl MicroserviceGateway.handle_proxy(request: Request, path: str) -> Response | None {
    svc = self.registry.match_route(path);
    if not svc {
        return None;
    }
    target_url = self.resolve_target_url(svc, path, str(request.url.query));
    logger.info(f"Proxy: {request.method} {path} -> {target_url}");
    return await self.forward_to(request, svc, target_url);
}


impl MicroserviceGateway.refresh_app_routes -> bool {
    import asyncio;
    import time;
    import from jaclang.scale.runtime.gateway.route_table { learn_service_routes }
    import from jaclang.scale.runtime.context.util { route_refresh_seconds }

    crawl = self._spec_crawl;
    if crawl is None or crawl.done() {
        crawl = asyncio.ensure_future(
            learn_service_routes(
                self.registry,
                self.route_table,
                time.monotonic(),
                route_refresh_seconds()
            )
        );
        self._spec_crawl = crawl;
    }
    try {
        attempted: int = await asyncio.shield(crawl);
    } except asyncio.CancelledError {
        raise;
    } except Exception as e {
        logger.warning(f"Route learning failed: {type(e).__name__}: {e}");
        return False;
    }
    if attempted {
        logger.info(
            f"Learned {len(self.route_table.prefixes())} root route(s) "
            f"after asking {attempted} service(s)"
        );
    }
    return attempted > 0;
}


impl MicroserviceGateway.handle_app_route(
    request: Request, path: str
) -> Response | None {
    svc = await self.resolve_learned_owner(path);
    if svc is None {
        return None;
    }
    return await self.forward_root_path(request, svc, path);
}


impl MicroserviceGateway.handle_openapi -> Response {
    import from jaclang.scale.runtime.gateway.openapi_agg { aggregate_openapi }
    doc = await aggregate_openapi(self.registry);
    return JSONResponse(status_code=200, content=doc);
}


impl MicroserviceGateway.handle_docs -> Response {
    import from jaclang.server.serving.openapi { swagger_ui_html }
    return HTMLResponse(content=swagger_ui_html("/openapi.json", "Jac Gateway - API"));
}


impl MicroserviceGateway.handle_metrics -> Response {
    import from jaclang.scale.runtime.middleware.metrics { render_metrics }
    import from jaclang.scale.runtime.context.errors { error_response }
    (body, ctype) = render_metrics(self._metrics_registry);
    if not body {
        return error_response(
            code="METRICS_UNAVAILABLE",
            message="metrics not available (install prometheus_client)",
            status=503
        );
    }
    return Response(content=body, media_type=ctype);
}
