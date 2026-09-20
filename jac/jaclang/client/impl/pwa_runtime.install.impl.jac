impl _installPrompt -> (InstallPromptEvent | None) {
    raw = getattr(window, "__jacPwaPrompt", "");
    if isinstance(raw, str) or not raw {
        return None;
    }
    return raw;
}

impl captureInstallPrompt -> None {
    captured: bool = getattr(window, "__jacPwaPromptCaptured", False);
    if captured {
        return;
    }

    setattr(window, "__jacPwaPrompt", None);
    setattr(window, "__jacPwaPromptCaptured", True);

    window.addEventListener(
        "beforeinstallprompt",
        lambda (e: Event) {
            e.preventDefault();
            setattr(window, "__jacPwaPrompt", e);
            _dispatchPwaEvent("jac:pwa:promptready");
        }
    );

    window.addEventListener(
        "appinstalled",
        lambda {
            setattr(window, "__jacPwaInstalled", True);
            setattr(window, "__jacPwaPrompt", None);
            recordInstallSuccess();
            _dispatchPwaEvent("jac:pwa:installed");
        }
    );
}

impl hasInstallPrompt -> bool {
    return _installPrompt() is not None;
}

impl triggerInstallPrompt -> bool {
    promptEvent = _installPrompt();

    if promptEvent is None {
        return False;
    }

    recordInstallAttempt();
    promptEvent.prompt();

    result = await promptEvent.userChoice;

    if result.outcome == "accepted" {
        setattr(window, "__jacPwaPrompt", None);
        return True;
    }

    return False;
}

impl shouldShowInstallBanner -> bool {
    if isStandalone() {
        return False;
    }

    prefs = getPwaUserPrefs();

    if prefs.installed {
        return False;
    }

    if not prefs.dismissed {
        return True;
    }

    if prefs.dismissCount >= PWA_MAX_REPROMPTS {
        return False;
    }

    baseDelay = PWA_DEFAULT_REPROMPT_DAYS;
    multiplier = Math.pow(PWA_BACKOFF_MULTIPLIER, prefs.dismissCount - 1);
    requiredDelayDays = baseDelay * multiplier;

    daysSinceDismiss = (Date.now() - prefs.dismissedAt) / (1000 * 60 * 60 * 24);

    return daysSinceDismiss >= requiredDelayDays;
}

impl recordDismiss -> None {
    prefs = getPwaUserPrefs();
    setPwaUserPrefs(
        {
            "dismissed": True,
            "dismissedAt": Date.now(),
            "dismissCount": prefs.dismissCount + 1
        }
    );
}

impl recordInstallAttempt -> None {
    setPwaUserPrefs({"installAttempted": True, "installAttemptedAt": Date.now()});
}

impl recordInstallSuccess -> None {
    setPwaUserPrefs({"installed": True, "installedAt": Date.now()});
}

impl usePwaInstall -> PwaInstallState {
    [canInstall, setCanInstall] = _useBool(hasInstallPrompt() or isIos());
    [isInstalled, setIsInstalled] = _useBool(isStandalone());
    [isPending, setIsPending] = _useBool(False);
    [showBanner, setShowBanner] = _useBool(shouldShowInstallBanner());
    [appName, setAppName] = _useStr("");
    [appIcon, setAppIcon] = _useStr("");
    [iosGuideOpen, setIosGuideOpen] = _useBool(False);

    prefs = getPwaUserPrefs();
    platform = getPlatform();

    reactUseEffect(
        lambda {
            async def loadManifest {
                name = await getAppName();
                icon = await getAppIcon();
                setAppName(name);
                setAppIcon(icon);
            }
            loadManifest();
        },
        []
    );

    reactUseEffect(
        lambda -> (Callable[[], None] | None) {
            handler = lambda {
                setCanInstall(True);
                setShowBanner(shouldShowInstallBanner());
            };
            window.addEventListener("jac:pwa:promptready", handler);
            return lambda { window.removeEventListener(
                "jac:pwa:promptready", handler
            ); };
        },
        []
    );

    reactUseEffect(
        lambda -> (Callable[[], None] | None) {
            handler = lambda {
                setIsInstalled(True);
                setCanInstall(False);
                setShowBanner(False);
            };
            window.addEventListener("jac:pwa:installed", handler);
            return lambda { window.removeEventListener("jac:pwa:installed", handler); };
        },
        []
    );

    async def install -> bool {
        if isIos() {
            setIosGuideOpen(True);
            return False;
        }

        if not hasInstallPrompt() {
            return False;
        }

        setIsPending(True);

        try {
            result = await triggerInstallPrompt();
            return result;
        } finally {
            setIsPending(False);
        }
    }

    def showIosGuide {
        setIosGuideOpen(True);
        setPwaUserPrefs({"iosGuideShown": True, "iosGuideShownAt": Date.now()});
    }

    def dismiss {
        recordDismiss();
        setShowBanner(False);
    }

    def closeIosGuide {
        setIosGuideOpen(False);
    }

    return PwaInstallState(
        canInstall=canInstall,
        isInstalled=isInstalled,
        platform=platform,
        shouldShowBanner=showBanner,
        appName=appName,
        appIcon=appIcon,
        install=install,
        showIosGuide=showIosGuide,
        closeIosGuide=closeIosGuide,
        iosGuideOpen=iosGuideOpen,
        dismiss=dismiss,
        isPending=isPending,
        dismissCount=prefs.dismissCount
    );
}
