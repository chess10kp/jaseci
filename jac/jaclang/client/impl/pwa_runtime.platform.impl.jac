impl _useBool(initial: bool) -> tuple[bool, Callable[[bool], None]] {
    state = reactUseState(initial);
    return (state[0], state[1]);
}

impl _useStr(initial: str) -> tuple[str, Callable[[str], None]] {
    state = reactUseState(initial);
    return (state[0], state[1]);
}

impl getPlatform -> str {
    ua = navigator.userAgent;

    iosPattern = new(RegExp, "iPad|iPhone|iPod");
    maxTouchPoints: float = getattr(navigator, "maxTouchPoints", 0.0);
    if iosPattern.`test(ua)
        or (navigator.platform == "MacIntel" and maxTouchPoints > 1) {
        return "ios";
    }

    if "Android" in ua {
        return "android";
    }

    return "desktop";
}

impl isIos -> bool {
    return getPlatform() == "ios";
}

impl isAndroid -> bool {
    return getPlatform() == "android";
}

impl isSafari -> bool {
    ua = navigator.userAgent;

    return ("Safari" in ua) and not ("Chrome" in ua) and not ("CriOS" in ua);
}

impl isMobile -> bool {
    platform = getPlatform();
    return platform == "ios" or platform == "android";
}

impl isStandalone -> bool {
    displayMode = window.matchMedia("(display-mode: standalone)");
    standaloneDisplay: bool = getattr(displayMode, "matches", False);
    if standaloneDisplay {
        return True;
    }

    iosStandalone: bool = getattr(navigator, "standalone", False);
    if iosStandalone {
        return True;
    }

    referrer: str = getattr(document, "referrer", "");
    return "android-app://" in referrer;
}

impl useIsStandalone -> bool {
    [standalone, setStandalone] = _useBool(isStandalone());

    reactUseEffect(
        lambda -> (Callable[[], None] | None) {
            mediaQuery = window.matchMedia("(display-mode: standalone)");
            if isinstance(mediaQuery, EventTarget) {
                target: EventTarget = mediaQuery;
                handler = lambda (e: Event) {
                    matched: bool = getattr(e, "matches", False);
                    setStandalone(matched);
                };
                target.addEventListener("change", handler);
                return lambda { target.removeEventListener("change", handler); };
            }
            return None;
        },
        []
    );

    return standalone;
}

impl _dispatchPwaEvent(name: str) -> None {
    if isinstance(window, EventTarget) {
        window.dispatchEvent(new(Event, name));
    }
}
