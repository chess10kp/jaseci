impl _normalizeRoutePath(path: str) -> str {
    text = str(path or "").strip();
    if text == "" {
        return "/";
    }
    if not text.startswith("/") {
        text = "/" + text;
    }
    if len(text) > 1 and text.endswith("/") {
        text = text.rstrip("/");
    }
    return text;
}

impl _joinRoutePath(parent_path: str, child_path: str) -> str {
    child = str(child_path or "");
    if child == "" {
        return _normalizeRoutePath(parent_path);
    }
    if child.startswith("/") {
        return _normalizeRoutePath(child);
    }
    base = _normalizeRoutePath(parent_path);
    if base == "/" {
        return _normalizeRoutePath("/" + child);
    }
    return _normalizeRoutePath(base + "/" + child);
}

impl _splitRouteParts(path: str) -> list[str] {
    text = _normalizeRoutePath(path);
    if text == "/" {
        return [];
    }
    return [
        part
        for part in text.split("/")
        if part != ""
    ];
}

impl _buildRouteName(path: str) -> str {
    normalized = _normalizeRoutePath(path);
    if normalized == "/" {
        return "root";
    }

    return normalized[1:].replace(":", "$");
}

impl _cacheNativeRoutes(route_defs: list[RouteDef]) {
    globalThis.__jacNativeRouteDefs__ = [
        {"name": route.name, "path": route.path} for route in route_defs
    ];
}

impl _getNativeRoutes -> list[any] {
    routes = globalThis.__jacNativeRouteDefs__;
    if routes and isinstance(routes, list) {
        return routes;
    }
    return [];
}

impl _matchRoutePattern(
    pattern_path: str, actual_path: str
) -> (dict[str, any] | None) {
    pattern_parts = _splitRouteParts(pattern_path);
    actual_parts = _splitRouteParts(actual_path);
    if len(pattern_parts) != len(actual_parts) {
        return None;
    }
    params = {};
    for idx in range(len(pattern_parts)) {
        pattern_part = pattern_parts[idx];
        actual_part = actual_parts[idx];
        if pattern_part.startswith(":") {
            key = pattern_part[1:];
            params[key] = decodeURIComponent(actual_part);
        } elif pattern_part != actual_part {
            return None;
        }
    }
    return params;
}

impl _lookupRouteByPath(path: str) -> (RouteMatch | None) {
    normalized = _normalizeRoutePath(path);
    for route in _getNativeRoutes() {
        if route["path"] == normalized {
            return RouteMatch(name=route["name"], path=route["path"]);
        }
    }
    for route in _getNativeRoutes() {
        params = _matchRoutePattern(route["path"], normalized);
        if params is not None {
            return RouteMatch(name=route["name"], path=route["path"], params=params);
        }
    }
    return None;
}

impl _lookupRouteByName(name: str) -> (dict[str, any] | None) {
    for route in _getNativeRoutes() {
        if route["name"] == name {
            return route;
        }
    }
    return None;
}

impl _hydratePath(pattern_path: str, params: any) -> str {
    parts = _splitRouteParts(pattern_path);
    hydrated = [];
    for part in parts {
        if part.startswith(":") {
            key = part[1:];
            value = params[key] if params and params[key] is not None else "";
            hydrated.append(encodeURIComponent(str(value)));
        } else {
            hydrated.append(part);
        }
    }
    return _normalizeRoutePath("/" + "/".join(hydrated));
}

impl _stripMetaParams(params: any) -> dict[str, any] {
    if not params {
        return {};
    }
    return {
        key: value
        for (key, value) in params.items()
        if not str(key).startswith("__jac")
    };
}

impl _performNavigation(nav: any, target: any, options: dict[str, any] = {}) -> None {
    if nav is None {
        console.warn("[jac-native-runtime] navigation is unavailable.");
        return;
    }
    if typeof(target) == "number" {
        if target < 0 and nav.goBack {
            nav.goBack();
        }
        return;
    }
    to = str(target or "/");
    if to.startswith("http://") or to.startswith("https://") {
        RNLinking.openURL(to).catch(
            lambda (e: any) { console.warn("RNLinking.openURL failed", e); }
        );
        return;
    }
    normalized = to;
    query = "";
    fragment = "";
    hash_idx = normalized.find("#");
    if hash_idx >= 0 {
        fragment = normalized[hash_idx + 1:];
        normalized = normalized[:hash_idx];
    }
    q_idx = normalized.find("?");
    if q_idx >= 0 {
        query = normalized[q_idx + 1:];
        normalized = normalized[:q_idx];
    }
    route_match = _lookupRouteByPath(normalized);
    if route_match is None {
        console.warn(
            f"[jac-native-runtime] No native route matched '{normalized}'. "
            "Define it with <Route path=...>."
        );
        return;
    }
    params = {** (route_match.params or {})};
    if query != "" {
        params["__jacSearch"] = "?" + query;
    }
    if fragment != "" {
        params["__jacHash"] = "#" + fragment;
    }
    if options and options["state"] is not None {
        params["__jacState"] = options["state"];
    }
    if options and options["replace"] {
        nav.dispatch(
            JacCommonActions.reset(
                {"index": 0, "routes": [{"name": route_match.name, "params": params}]}
            )
        );
        return;
    }
    nav.navigate(route_match.name, params);
}

impl _collectNativeRoutes(
    children: any, parent_path: str, wrappers: list[any], out_routes: list[RouteDef]
) {
    for child in _toChildrenArray(children) {
        if not React.isValidElement(child) {
            continue;
        }
        if child.type != __nativeRoute {
            continue;
        }
        props: any = child.props or {};
        route_path = str(props.path) if props.path else "";
        route_element = props.element;
        full_path = _joinRoutePath(parent_path, route_path);
        if route_path != "" and route_element is not None {
            out_routes.append(
                RouteDef(
                    name=_buildRouteName(full_path),
                    path=full_path,
                    element=route_element,
                    wrappers=wrappers
                )
            );
        }
        next_wrappers = wrappers;
        if route_element is not None and props.children {
            next_wrappers = wrappers + [route_element];
        } elif route_element is not None and route_path == "" {
            next_wrappers = wrappers + [route_element];
        }
        next_parent = full_path if route_path != "" else parent_path;
        if props.children {
            _collectNativeRoutes(
                props.children, next_parent, next_wrappers, out_routes
            );
        }
    }
}

impl _makeNativeRouteScreen(route: RouteDef) -> any {
    wrappers = route.wrappers or [];
    element = route.element or React.createElement(RNView, None);
    return lambda -> JsxElement {
        content = element;
        idx = len(wrappers) - 1;
        while idx >= 0 {
            wrapper = wrappers[idx];
            content = React.createElement(
                _JAC_NATIVE_OUTLET_CONTEXT.Provider, {"value": content}, wrapper
            );
            idx -= 1;
        }
        return content;
    };
}

impl __nativeRouter(props: dict[str, any] = {}) -> JsxElement {
    nav_ref = React.useRef(None);
    React.useEffect(lambda { globalThis.__jacNativeNavigationRef__ = nav_ref; }, []);
    def _flushPendingNavigation {
        pending = globalThis.__jacPendingNavigation__;
        if pending {
            globalThis.__jacPendingNavigation__ = None;

            _performNavigation(nav_ref.current, pending, {"replace": True});
        }
    }
    return React.createElement(
        JacNavigationContainer,
        {"ref": nav_ref, "onReady": _flushPendingNavigation},
        props["children"]
    );
}

impl __nativeRoutes(props: dict[str, any] = {}) -> JsxElement {
    routes = React.useMemo(
        lambda -> list[RouteDef] {
            out: list[RouteDef] = [];
            _collectNativeRoutes(props["children"], "/", [], out);
            return out;
        },
        []
    );
    React.useEffect(lambda { _cacheNativeRoutes(routes); }, [routes]);

    screens = React.useMemo(
        lambda -> list[JsxElement] { return [
            React.createElement(
                _JAC_NATIVE_STACK.Screen,
                {
                    "key": route.name,
                    "name": route.name,
                    "component": _makeNativeRouteScreen(route)
                }
            ) for route in routes
        ]; },
        [routes]
    );
    if len(routes) == 0 {
        return React.createElement(
            RNView,
            {"style": {"padding": 16}},
            React.createElement(
                RNText,
                {"style": {"color": "#dc2626"}},
                "No native routes found. Add <Route path=... element=.../>."
            )
        );
    }
    return React.createElement(
        _JAC_NATIVE_STACK.Navigator, {"initialRouteName": routes[0].name}, *screens
    );
}

impl __nativeRoute(props: dict[str, any] = {}) -> (JsxElement | None) {
    return None;
}

impl __nativeLink(props: dict[str, any] = {}) -> JsxElement {
    to = props.get("to", None) or (props.get("href", None) or "/");
    rest = {** props};
    if rest["to"] {
        rest.pop("to", None);
    }
    if rest["href"] {
        rest.pop("href", None);
    }
    if rest["replace"] {
        rest.pop("replace", None);
    }
    user_press = rest["onPress"] if rest["onPress"] else None;
    nav_fn = useNavigate();
    rest["onPress"] = lambda {
        if user_press {
            user_press();
        }
        nav_fn(to, {"replace": props.get("replace", None) == True});
    };
    children = _toChildrenArray(props.get("children", None) or to);

    label = React.createElement(
        RNText, {"style": _textStyleFrom(rest["style"])}, *children
    );
    return React.createElement(RNPressable, rest, label);
}

impl __nativeNavigate(props: dict[str, any] = {}) -> (JsxElement | None) {
    opts: dict[str, any] = props or {};
    target = opts.get("to", None) or "/";
    should_replace = opts.get("replace", None) == True;
    nav_fn = useNavigate();
    reactUseEffect(
        lambda { nav_fn(
            target, {"replace": should_replace, "state": opts.get("state", None)}
        ); },
        [target, should_replace]
    );
    return None;
}

impl __nativeOutlet(props: dict[str, any] = {}) -> (JsxElement | None) {
    return React.useContext(_JAC_NATIVE_OUTLET_CONTEXT);
}

impl useRouter -> dict[str, any] {
    nav_fn = useNavigate();
    location = useLocation();
    params = useParams();
    return {
        "navigate": nav_fn,
        "location": location,
        "params": params,
        "pathname": location["pathname"],
        "search": location["search"],
        "hash": location["hash"]
    };
}

impl useNavigate -> any {
    nav = jacUseNavigation();
    def _navigate(target: any, options: (dict[str, any] | None) = None) {
        _performNavigation(nav, target, options or {});
    }
    return _navigate;
}

impl useLocation -> dict[str, any] {
    route = jacUseRoute();
    pathname = "/";
    search = "";
    hash = "";
    state = None;
    params = route.params if route and route.params else {};
    route_name = route.name if route and route.name else "";
    route_def = _lookupRouteByName(route_name);
    if route_def {
        pathname = _hydratePath(route_def["path"], params);
    }
    if params and params["__jacSearch"] {
        search = str(params["__jacSearch"]);
    }
    if params and params["__jacHash"] {
        hash = str(params["__jacHash"]);
    }
    if params and params["__jacState"] is not None {
        state = params["__jacState"];
    }
    return {"pathname": pathname, "search": search, "hash": hash, "state": state};
}

impl useParams -> dict[str, any] {
    route = jacUseRoute();
    params = route.params if route and route.params else {};
    return _stripMetaParams(params);
}

impl navigate(path: str) -> None {
    nav_ref = globalThis.__jacNativeNavigationRef__;
    nav = nav_ref.current if nav_ref and nav_ref.current else None;
    if nav is None {
        globalThis.__jacPendingNavigation__ = path;
        return;
    }
    _performNavigation(nav, path, {});
}
