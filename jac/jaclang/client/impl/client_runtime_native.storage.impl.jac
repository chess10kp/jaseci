def _isNil(x: any) -> bool {
    return x is None or x is undefined;
}

impl __getApiBaseUrl -> str {
    build_time: any = globalThis.__JAC_API_BASE_URL__;
    if build_time {
        return build_time;
    }
    try {
        cfg = ExpoConstants.expoConfig;
        if cfg and cfg.extra and cfg.extra.apiBaseUrl {
            return cfg.extra.apiBaseUrl;
        }
    } except Exception {}
    if not globalThis.__jacWarnedMissingApiBaseUrl__ {
        globalThis.__jacWarnedMissingApiBaseUrl__ = True;
        console.warn(
            "[jac-native-runtime] Missing API base URL. Set expo.extra.apiBaseUrl "
            "or run jac run --dev <app> so it is injected."
        );
    }
    return "";
}

def _nativeStorageCache -> dict[str, any] {
    cache: any = globalThis.__jacNativeStorageCache__;
    if not cache {
        cache = {};
        globalThis.__jacNativeStorageCache__ = cache;
    }
    return cache;
}

impl __getLocalStorage(key: str) -> str {
    cache = _nativeStorageCache();
    if key in cache {
        return cache[key];
    }
    SecureStore.getItemAsync(key).then(
        lambda (val: any) { cache[key] = val or ""; }
    ).catch(
        lambda (e: any) { console.warn("SecureStore.getItemAsync failed", e); }
    );
    return "";
}

impl __setLocalStorage(key: str, value: str) -> None {
    _nativeStorageCache()[key] = value;
    SecureStore.setItemAsync(key, value).catch(
        lambda (e: any) { console.warn("SecureStore.setItemAsync failed", e); }
    );
}

impl __removeLocalStorage(key: str) -> None {
    _nativeStorageCache().pop(key, None);
    SecureStore.deleteItemAsync(key).catch(
        lambda (e: any) { console.warn("SecureStore.deleteItemAsync failed", e); }
    );
}

impl __getLocalStorageAsync(key: str) -> str {
    val = await SecureStore.getItemAsync(key);
    _nativeStorageCache()[key] = val or "";
    return val or "";
}

impl __setLocalStorageAsync(key: str, value: str) -> None {
    _nativeStorageCache()[key] = value;
    await SecureStore.setItemAsync(key, value);
}

impl __removeLocalStorageAsync(key: str) -> None {
    _nativeStorageCache().pop(key, None);
    await SecureStore.deleteItemAsync(key);
}

impl __primeNativeTokenCache -> None {
    cache = _nativeStorageCache();
    try {
        token = await SecureStore.getItemAsync("jac_token");
        cache["jac_token"] = token or "";
    } except Exception as e {
        console.warn("[jac-native-runtime] __primeNativeTokenCache failed", e);
    }

    globalThis.__jacNativeTokenPrimed__ = True;
}

impl __ensureNativeTokenPrimed -> any {
    if not globalThis.__jacNativeTokenPrimePromise__ {
        globalThis.__jacNativeTokenPrimePromise__ = __primeNativeTokenCache();
    }
    return globalThis.__jacNativeTokenPrimePromise__;
}

impl AuthGuard(redirect: str = "/login", children: any = None) -> (JsxElement | None) {
    [ready, setReady] = useState(globalThis.__jacNativeTokenPrimed__ == True);
    React.useEffect(
        lambda {
            if ready {
                return None;
            }
            mounted = {"v": True};
            __ensureNativeTokenPrimed().then(
                lambda (_: any) { if mounted["v"] { setReady(True); }}
            );
            return lambda { mounted["v"] = False; };
        },
        []
    );
    if not ready {
        return None;
    }
    if not jacIsLoggedIn() {
        return React.createElement(__nativeNavigate, {"to": redirect, "replace": True});
    }
    if children is not None {
        return React.createElement(React.Fragment, None, children);
    }
    return React.createElement(__nativeOutlet, None);
}
