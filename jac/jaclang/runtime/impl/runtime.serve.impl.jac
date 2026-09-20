impl JacServe.get_client_bundle_builder -> ClientBundleBuilder {
    import from jaclang.runtime.build_services { build_services }
    return build_services().client_builder();
}

impl JacServe.build_client_bundle(
    module: types.ModuleType, force: bool = False
) -> ClientBundle {
    builder = JacRuntimeInterface.get_client_bundle_builder();
    return builder.build(module, force=force);
}

impl JacServe.get_api_server_class -> type {
    import from jaclang.server.server { JacAPIServer }
    return JacAPIServer;
}

impl JacServe.get_server_extensions -> list[ServerExtension] {
    _sp = _scale_provider();
    if _sp is None {
        return [];
    }
    return list(_sp.get_server_extensions());
}

impl JacServe.get_sv_registry -> dict[str, str] {
    _sp = _scale_provider();
    if _sp is not None {
        return _sp.get_sv_registry();
    }
    import from jaclang.server { sv_client }
    return dict(sv_client._registry);
}

impl JacServe.create_server(
    jac_server: JacServer, host: str, port: int, max_retries: int = 10
) -> any {
    _sp = _scale_provider();
    if _sp is not None {
        _scaled = _sp.create_server(jac_server, host, port);
        if _scaled is not None {
            return _scaled;
        }
    }
    raise RuntimeError(
        "create_server is retired: JacAPIServer.start binds the Jac-native "
        "serving core directly"
    );
}

impl JacServe.render_page(
    introspector: ModuleIntrospector,
    function_name: str,
    args: dict[(str, any)],
    username: str
) -> dict[(str, any)] {
    import from jaclang.client.serving { JacClient }
    return JacClient.render_page(introspector, function_name, args, username);
}

impl JacServe.get_client_js(introspector: ModuleIntrospector) -> str {
    import from jaclang.client.serving { JacClient }
    return JacClient.get_client_js(introspector);
}
