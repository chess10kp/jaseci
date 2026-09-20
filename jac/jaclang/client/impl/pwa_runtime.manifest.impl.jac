glob PWA_STORAGE_KEY = "__jac_pwa_prefs__",
     PWA_DEFAULT_REPROMPT_DAYS = 7,
     PWA_MAX_REPROMPTS = 3,
     PWA_BACKOFF_MULTIPLIER = 2;

impl getManifest -> WebAppManifest {
    try {
        manifestLink = document.querySelector('link[rel="manifest"]');
        if not manifestLink {
            return WebAppManifest();
        }

        href: str = getattr(manifestLink, "href", "");
        response = await fetch(href);
        if not response.ok {
            return WebAppManifest();
        }

        data = await response.json();
        icons: list[ManifestIcon] = getattr(data, "icons", []);
        return WebAppManifest(
            name=getattr(data, "name", ""),
            short_name=getattr(data, "short_name", ""),
            icons=icons
        );
    } except Exception as e {
        console.warn("[jac-pwa] Failed to fetch manifest:", e);
        return WebAppManifest();
    }
}

impl getAppIcon -> str {
    try {
        manifest = await getManifest();
        icons = manifest.icons;

        if not icons or len(icons) == 0 {
            return "";
        }

        for icon in icons {
            if icon.sizes == "192x192" {
                return icon.src;
            }
        }

        return icons[0].src or "";
    } except Exception as e {
        console.warn("[jac-pwa] Failed to get app icon:", e);
        return "";
    }
}

impl getAppName -> str {
    try {
        manifest = await getManifest();
        return manifest.name or manifest.short_name or "";
    } except Exception as e {
        console.warn("[jac-pwa] Failed to get app name:", e);
        return "";
    }
}

impl getPwaUserPrefs -> PwaUserPrefs {
    try {
        stored = localStorage.getItem(PWA_STORAGE_KEY);
        if stored {
            parsed = JSON.parse(stored);
            return PwaUserPrefs(
                dismissed=getattr(parsed, "dismissed", False),
                dismissedAt=getattr(parsed, "dismissedAt", 0.0),
                dismissCount=getattr(parsed, "dismissCount", 0),
                installAttempted=getattr(parsed, "installAttempted", False),
                installAttemptedAt=getattr(parsed, "installAttemptedAt", 0.0),
                installed=getattr(parsed, "installed", False),
                installedAt=getattr(parsed, "installedAt", 0.0),
                platform=getattr(parsed, "platform", getPlatform()),
                iosGuideShown=getattr(parsed, "iosGuideShown", False),
                iosGuideShownAt=getattr(parsed, "iosGuideShownAt", 0.0)
            );
        }
    } except Exception as e {
        console.warn(
            "[jac-pwa] Failed to read PWA user preferences from localStorage:", e
        );
    }

    return PwaUserPrefs(platform=getPlatform());
}

impl setPwaUserPrefs(prefs: dict[str, object]) -> None {
    try {
        current = getPwaUserPrefs();
        merged = Object.assign({}, current, prefs);
        localStorage.setItem(PWA_STORAGE_KEY, JSON.stringify(merged));
    } except Exception as e {
        console.warn(
            "[jac-pwa] Failed to save PWA user preferences to localStorage:", e
        );
    }
}

impl resetPwaUserPrefs -> None {
    try {
        localStorage.removeItem(PWA_STORAGE_KEY);
    } except Exception as e {
        console.warn("[jac-pwa] Failed to reset PWA user preferences:", e);
    }
}
