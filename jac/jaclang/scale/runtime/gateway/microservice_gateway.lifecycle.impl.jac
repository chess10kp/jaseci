impl MicroserviceGateway.setup -> ServingApp {
    import time;
    self.app = ServingApp(title="Jac Gateway");
    gw = self;

    self.bootstrap_admin_ui();

    try {
        self._install_admin_api();
    } except Exception as e {
        self.server = None;
        logger.warning(
            "Admin JSON API not installed - admin UI will be read-only "
            f"static. Cause: {type(e).__name__}: {e}"
        );
    }

    import from jaclang.scale.runtime.context.trace_ctx {
        set_current_trace,
        reset_current_trace,
        ensure_trace_id
    }
    import from jaclang.scale.runtime.middleware.metrics { build_gateway_metrics }
    import from jaclang.scale.config.config_loader { get_scale_config }
    mon_cfg = get_scale_config().get_monitoring_config();
    import from jaclang.scale.runtime.context.log_emit { install_structured_logging }
    install_structured_logging();
    (self._metrics_registry, self._metrics_requests, self._metrics_duration) = (
        build_gateway_metrics(
            namespace=mon_cfg.get("namespace", "jaclang_scale"),
            histogram_buckets=mon_cfg.get("histogram_buckets")
        )
    );

    import from jaclang.scale.observability.factory { UtilityFactory }
    self._metrics = UtilityFactory.create_metrics('prometheus', mon_cfg);

    import from jaclang.scale.runtime.context.tracing {
        install_tracing,
        start_server_span,
        end_span
    }
    trc_cfg = get_scale_config().get_gateway_config().get("tracing", {});
    install_tracing(
        enabled=trc_cfg.get("enabled", False),
        endpoint=trc_cfg.get("endpoint"),
        sample_ratio=float(trc_cfg.get("sample_ratio", 1.0))
    );

    async def dispatcher(request: Request, call_next: object) -> Response {
        next_fn: any = call_next;
        path: str = request.url.path;

        trace_id = ensure_trace_id(request.headers.get("X-Trace-Id"));
        tok = set_current_trace(trace_id);

        span = start_server_span(
            f"{request.method} {path}",
            trace_id,
            request.headers.get("traceparent"),
            {"http.method": request.method, "http.target": path}
        );

        start = time.time();
        svc_label: str = "__unmatched__";
        try {
            resp: Response | None = None;

            import from jaclang.scale.runtime.gateway.dispatch {
                classify_route,
                ROUTE_BUILTIN,
                ROUTE_ADMIN,
                ROUTE_IDENTITY,
                ROUTE_PROXY,
                ROUTE_CLIENT_PAGE
            }
            service_prefixes: list[str] = [
                e.prefix for e in gw.registry.entries.values()
            ];
            decision = classify_route(
                path, service_prefixes, client_pages=gw.has_client_bundle()
            );

            if decision.kind == ROUTE_BUILTIN {
                if path == "/healthz/live" {
                    svc_label = "__health_live__";
                    resp = gw.handle_health_live();
                } elif path == "/healthz/ready" {
                    svc_label = "__health_ready__";
                    resp = gw.handle_health_ready();
                } elif path == "/health" or path == "/healthz" {
                    svc_label = "__health__";
                    resp = gw.handle_health();
                } elif path == "/metrics" {
                    svc_label = "__metrics__";
                    resp = gw.handle_metrics();
                } elif path == "/openapi.json" {
                    svc_label = "__openapi__";
                    resp = await gw.handle_openapi();
                } elif path == "/docs" {
                    svc_label = "__docs__";
                    resp = gw.handle_docs();
                }
            } elif decision.kind == ROUTE_CLIENT_PAGE {
                page_resp: Response | None = None;
                root_svc = gw.root_member();
                if request.method == "GET"
                    and (root_svc is None or not root_svc.owns_root()) {
                    page_resp = gw.serve_spa_fallback();
                    if page_resp is None {
                        import from jaclang.scale.runtime.context.errors { not_found }
                        page_resp = not_found(path);
                    }
                }
                if page_resp is not None {
                    svc_label = "__static__";
                    resp = page_resp;
                }
            } elif decision.kind == ROUTE_ADMIN {
                svc_label = "__admin__";
                admin_resp: Response | None = None;
                if gw.server is not None {
                    admin_resp = await next_fn(request);
                } else {
                    admin_resp = gw.handle_admin(path);
                }
                if admin_resp is None {
                    import from jaclang.scale.runtime.context.errors { not_found }
                    admin_resp = not_found(path);
                }
                resp = admin_resp;
            } elif decision.kind == ROUTE_IDENTITY {
                if gw.server is not None {
                    ident_resp = await next_fn(request);
                    if ident_resp.status_code not in (404, 405) {
                        svc_label = "__identity__";
                        resp = ident_resp;
                    }
                }
            } elif decision.kind == ROUTE_PROXY {
                matched = gw.registry.match_route(path);
                if matched {
                    svc_label = matched.name;
                    resp = await gw.handle_proxy(request, path);
                }
            }

            if resp is None {
                builtin = await gw.handle_builtin_passthrough(request, path);
                if builtin is not None {
                    svc_label = "__builtin__";
                    resp = builtin;
                }
            }
            if resp is None {
                static_resp = gw.handle_static(request, path);
                if static_resp is not None {
                    svc_label = "__static__";
                    resp = static_resp;
                }
            }
            if resp is None {
                app_resp = await gw.handle_app_route(request, path);
                if app_resp is not None {
                    svc_label = gw.route_table.owner(path) or "__app_route__";
                    resp = app_resp;
                }
            }
            if resp is None {
                served_by_root = await gw.forward_to_root(request, path);
                if served_by_root is not None {
                    svc_label = gw.registry.root_app or "__root__";
                    resp = served_by_root;
                }
            }
            if resp is None {
                static_from_root = await gw.forward_static_to_root(request, path);
                if static_from_root is not None {
                    svc_label = gw.registry.root_app or "__root__";
                    resp = static_from_root;
                }
            }
            if resp is None {
                spa_resp = gw.handle_spa_fallback(request, path);
                if spa_resp is not None {
                    svc_label = "__static__";
                    resp = spa_resp;
                }
            }
            if resp is None {
                import from jaclang.scale.runtime.context.errors { not_found }
                resp = not_found(path);
            }

            resp.headers["X-Trace-Id"] = trace_id;

            if span is not None {
                span.set_attribute("http.status_code", resp.status_code);
                span.set_attribute("jac.service", svc_label);
            }

            if gw._metrics_requests is not None {
                import from jaclang.scale.runtime.middleware.metrics {
                    classify_outcome
                }
                outcome = classify_outcome(resp.status_code);
                gw._metrics_requests.labels(
                    service=svc_label, method=request.method, outcome=outcome
                ).inc();
                gw._metrics_duration.labels(
                    service=svc_label, method=request.method
                ).observe(
                    time.time() - start
                );
            }
            if gw._metrics is not None and gw._metrics.is_enabled() {
                gw._metrics.record_request(
                    request.method, path, resp.status_code, time.time() - start
                );
            }
            return resp;
        } finally {
            end_span(span);
            reset_current_trace(tok);
        }
    }

    self.app.add_middleware(dispatcher);

    import from jaclang.scale.runtime.middleware.middleware {
        Middleware,
        MiddlewareRegistry
    }
    registry = MiddlewareRegistry();

    import from jaclang.server.serving.drain { drain_middleware }
    registry.register(
        Middleware(
            name="drain", priority=20, fn=drain_middleware(self.drain, "__gateway__")
        )
    );

    import from jaclang.scale.config.config_loader { get_scale_config }
    gw_cfg = get_scale_config().get_gateway_config();

    import from jaclang.scale.runtime.middleware.rate_limit {
        build_rate_limit_middleware
    }
    rl_mw = build_rate_limit_middleware(gw_cfg.get("rate_limit", {}));
    if rl_mw is not None {
        registry.register(Middleware(name="rate_limit", priority=10, fn=rl_mw));
    }

    registry.install(self.app);

    cors_cfg = gw_cfg.get("cors", {});
    if cors_cfg.get("allow_origins") {
        import from jaclang.server.serving.middleware { cors_middleware }
        self.app.add_middleware(
            cors_middleware(
                allow_origins=cors_cfg["allow_origins"],
                allow_methods=cors_cfg.get("allow_methods", ["*"]),
                allow_headers=cors_cfg.get("allow_headers", ["*"]),
                allow_credentials=cors_cfg.get("allow_credentials", False),
                expose_headers=cors_cfg.get("expose_headers", []),
                max_age=cors_cfg.get("max_age", 600)
            )
        );
    }
    _install_ws_catchall(self);

    return self.app;
}


def _log_gateway_ready(host: str, bound: int) {
    logger.info(f"Gateway starting on {host}:{bound}");
}


impl MicroserviceGateway.start(on_ready: any = None) -> None {
    import from jaclang.server.net { PORT_RETRY_LIMIT }
    import from jaclang.server.serving.server { ServingServer }
    import from jaclang.server.settings { ServeSettings }

    if self.app is None {
        self.setup();
    }
    settings = ServeSettings.load(
        self.base_path,
        {'host': self.host, 'port': self.port, 'strict_port': self.port_pinned}
    );
    self.drain.timeout = settings.timeouts.drain;
    serving = ServingServer(app=self.app, settings=settings, drain=self.drain);
    import from functools { partial }
    ready: any = on_ready;
    if ready is None {
        ready = partial(_log_gateway_ready, self.host);
    }
    serving.run(
        on_ready=ready, port_retries=0 if self.port_pinned else PORT_RETRY_LIMIT
    );
}


impl MicroserviceGateway.add_endpoint(ep: JEndPoint) -> None {
    self.app.add_endpoint(ep);
}


impl MicroserviceGateway.identity -> UserManager {
    if self.user_manager is None {
        self.user_manager = UserManager(base_path=self.base_path);
    }
    return self.user_manager;
}


impl MicroserviceGateway._install_admin_api -> None {
    import from jaclang.server.endpoints.auth { register_auth_endpoints }
    import from jaclang.server.middleware { jwt_middleware }
    import from jaclang.server.identity.config { configure_identity }
    import from jaclang.server.settings { ServeSettings }

    settings = ServeSettings.load(self.base_path);
    configure_identity(settings.auth, self.base_path);
    self.server = self;
    self.user_manager = self.identity();
    self.app.add_middleware(jwt_middleware(self.user_manager));

    self.register_admin_endpoints();
    self.register_logs_endpoints();
    self.register_llm_telemetry_endpoints();
    self.register_workloads_endpoints();

    self.register_traces_endpoints();
    self.register_ops_endpoints();
    self.register_deploy_health_endpoints();
    self.register_network_endpoints();
    self.register_podenv_endpoints();

    register_auth_endpoints(self);

    logger.info(
        "Admin JSON API installed on gateway "
        "(/admin/login, /admin/me, /admin/users, /admin/workloads/*, /admin/logs/*, ...)"
    );
    logger.info(
        "Gateway-owned identity installed "
        "(/user/register, /user/login, /user/me served by the gateway)"
    );
}
