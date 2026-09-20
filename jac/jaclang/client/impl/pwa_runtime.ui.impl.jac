impl __getPwaStyles -> str {
    return '''
/* PWA Install Banner - Glassmorphic Design */
@keyframes jac-pwa-slide-up {
  from { transform: translateY(100%) scale(0.95); opacity: 0; }
  to { transform: translateY(0) scale(1); opacity: 1; }
}

@keyframes jac-pwa-slide-down {
  to { transform: translateY(100%) scale(0.95); opacity: 0; }
}

@keyframes jac-pwa-fade-in {
  from { opacity: 0; transform: scale(0.95); }
  to { opacity: 1; transform: scale(1); }
}

.jac-pwa-banner {
  position: fixed;
  bottom: 16px;
  left: 16px;
  right: 16px;
  max-width: 480px;
  margin: 0 auto;
  background: rgba(15, 15, 25, 0.92);
  backdrop-filter: blur(20px);
  -webkit-backdrop-filter: blur(20px);
  border: 1px solid rgba(255, 255, 255, 0.12);
  border-radius: 20px;
  color: white;
  padding: 16px 20px;
  display: flex;
  align-items: center;
  gap: 14px;
  box-shadow: 0 8px 32px rgba(0, 0, 0, 0.4), 0 0 0 1px rgba(255, 255, 255, 0.05) inset;
  z-index: 9999;
  font-family: system-ui, -apple-system, BlinkMacSystemFont, sans-serif;
  animation: jac-pwa-slide-up 0.4s cubic-bezier(0.16, 1, 0.3, 1);
}

.jac-pwa-banner--dismissing {
  animation: jac-pwa-slide-down 0.3s cubic-bezier(0.4, 0, 1, 1) forwards;
}

.jac-pwa-banner--top {
  bottom: auto;
  top: 16px;
}

.jac-pwa-banner__icon {
  width: 52px;
  height: 52px;
  border-radius: 14px;
  object-fit: cover;
  flex-shrink: 0;
  box-shadow: 0 4px 12px rgba(0, 0, 0, 0.25);
  background: rgba(255, 255, 255, 0.1);
}

.jac-pwa-banner__content {
  flex: 1;
  min-width: 0;
}

.jac-pwa-banner__title {
  font-weight: 600;
  font-size: 15px;
  margin-bottom: 3px;
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
}

.jac-pwa-banner__description {
  font-size: 13px;
  opacity: 0.75;
  line-height: 1.35;
}

.jac-pwa-banner__actions {
  display: flex;
  gap: 8px;
  flex-shrink: 0;
}

.jac-pwa-banner__install {
  background: linear-gradient(135deg, #6366f1, #8b5cf6, #a855f7);
  color: white;
  border: none;
  padding: 10px 20px;
  border-radius: 12px;
  font-weight: 600;
  font-size: 14px;
  cursor: pointer;
  transition: all 0.2s ease;
  box-shadow: 0 4px 15px rgba(99, 102, 241, 0.4);
}

.jac-pwa-banner__install:hover {
  transform: translateY(-1px);
  box-shadow: 0 6px 20px rgba(99, 102, 241, 0.5);
}

.jac-pwa-banner__install:active {
  transform: translateY(0) scale(0.98);
}

.jac-pwa-banner__dismiss {
  background: rgba(255, 255, 255, 0.08);
  color: rgba(255, 255, 255, 0.85);
  border: 1px solid rgba(255, 255, 255, 0.12);
  padding: 10px 16px;
  border-radius: 12px;
  font-size: 14px;
  cursor: pointer;
  transition: all 0.2s ease;
}

.jac-pwa-banner__dismiss:hover {
  background: rgba(255, 255, 255, 0.12);
  color: white;
}

/* iOS Guide Modal */
.jac-pwa-ios-overlay {
  position: fixed;
  inset: 0;
  background: rgba(0, 0, 0, 0.4);
  backdrop-filter: blur(8px);
  -webkit-backdrop-filter: blur(8px);
  display: flex;
  align-items: center;
  justify-content: center;
  padding: 20px;
  z-index: 10000;
  animation: jac-pwa-fade-in 0.3s ease-out;
}

.jac-pwa-ios-guide {
  background: rgba(20, 20, 30, 0.95);
  backdrop-filter: blur(24px);
  -webkit-backdrop-filter: blur(24px);
  border: 1px solid rgba(255, 255, 255, 0.12);
  border-radius: 24px;
  padding: 28px 24px;
  max-width: 340px;
  width: 100%;
  text-align: center;
  color: white;
  box-shadow: 0 24px 48px rgba(0, 0, 0, 0.5);
  animation: jac-pwa-slide-up 0.4s cubic-bezier(0.16, 1, 0.3, 1);
}

.jac-pwa-ios-guide__title {
  font-size: 20px;
  font-weight: 700;
  margin-bottom: 8px;
}

.jac-pwa-ios-guide__subtitle {
  font-size: 14px;
  opacity: 0.7;
  margin-bottom: 24px;
}

.jac-pwa-ios-guide__steps {
  display: flex;
  flex-direction: column;
  gap: 8px;
  margin-bottom: 24px;
}

.jac-pwa-ios-guide__step {
  display: flex;
  align-items: center;
  gap: 14px;
  padding: 14px 16px;
  text-align: left;
  background: rgba(255, 255, 255, 0.06);
  border-radius: 14px;
  border: 1px solid rgba(255, 255, 255, 0.08);
}

.jac-pwa-ios-guide__step-num {
  width: 28px;
  height: 28px;
  border-radius: 50%;
  background: linear-gradient(135deg, #6366f1, #a855f7);
  display: flex;
  align-items: center;
  justify-content: center;
  font-weight: 600;
  font-size: 13px;
  flex-shrink: 0;
}

.jac-pwa-ios-guide__step-icon {
  font-size: 20px;
  width: 28px;
  text-align: center;
  flex-shrink: 0;
}

.jac-pwa-ios-guide__step-text {
  font-size: 14px;
  line-height: 1.4;
}

.jac-pwa-ios-guide__close {
  width: 100%;
  background: rgba(255, 255, 255, 0.1);
  border: 1px solid rgba(255, 255, 255, 0.15);
  color: white;
  padding: 14px;
  border-radius: 14px;
  font-size: 15px;
  font-weight: 600;
  cursor: pointer;
  transition: all 0.2s ease;
}

.jac-pwa-ios-guide__close:hover {
  background: rgba(255, 255, 255, 0.15);
}

/* Mobile responsive */
@media (max-width: 520px) {
  .jac-pwa-banner {
    bottom: 12px;
    left: 12px;
    right: 12px;
    flex-wrap: wrap;
    padding: 14px 16px;
    border-radius: 16px;
  }
  .jac-pwa-banner__icon {
    width: 44px;
    height: 44px;
  }
  .jac-pwa-banner__actions {
    width: 100%;
    margin-top: 14px;
  }
  .jac-pwa-banner__install,
  .jac-pwa-banner__dismiss {
    flex: 1;
    text-align: center;
    padding: 12px 16px;
  }
}
''';
}

impl PwaInstallBanner(
    title: str = "",
    description: str = "Add to home screen for the best experience",
    installText: str = "Install",
    dismissText: str = "Not now",
    showIcon: bool = True,
    iconSize: int = 52,
    showAfterMs: int = 3000,
    position: str = "bottom",
    className: str = "",
    style: (dict[str, object] | None) = None
) -> JsxElement {
    pwa = usePwaInstall();
    [visible, setVisible] = _useBool(False);
    [dismissing, setDismissing] = _useBool(False);

    bannerTitle = title or pwa.appName or "Install App";
    bannerStyle: dict[str, any] = style or {};

    reactUseEffect(
        lambda -> (Callable[[], None] | None) {
            if not pwa.shouldShowBanner or pwa.isInstalled {
                return None;
            }
            timer = setTimeout(lambda { setVisible(True); }, showAfterMs);
            return lambda { clearTimeout(timer); };
        },
        [pwa.shouldShowBanner, pwa.isInstalled]
    );

    def handleDismiss {
        setDismissing(True);
        setTimeout(
            lambda {
                pwa.dismiss();
                setVisible(False);
                setDismissing(False);
            },
            300
        );
    }

    async def handleInstall {
        result = await pwa.install();
        if result {
            setVisible(False);
        }
    }

    if not visible {
        return <></>;
    }

    bannerClass = "jac-pwa-banner";
    if dismissing {
        bannerClass = bannerClass + " jac-pwa-banner--dismissing";
    }
    if position == "top" {
        bannerClass = bannerClass + " jac-pwa-banner--top";
    }
    if className {
        bannerClass = bannerClass + " " + className;
    }

    return (
        <>
            <style>{__getPwaStyles()}</style>
            <div className={bannerClass} style={bannerStyle}>
                {showIcon
                    and pwa.appIcon
                    and (
                        <img
                            className="jac-pwa-banner__icon"
                            src={pwa.appIcon}
                            alt=""
                            style={{"width": iconSize, "height": iconSize}}
                        />
                    )}
                <div className="jac-pwa-banner__content">
                    <div className="jac-pwa-banner__title">{bannerTitle}</div>
                    <div className="jac-pwa-banner__description">{description}</div>
                </div>
                <div className="jac-pwa-banner__actions">
                    <button
                        className="jac-pwa-banner__install"
                        onClick={handleInstall}
                        disabled={pwa.isPending}
                    >
                        {pwa.isPending and "..." or installText}
                    </button>
                    <button className="jac-pwa-banner__dismiss" onClick={handleDismiss}>
                        {dismissText}
                    </button>
                </div>
            </div>
            {pwa.iosGuideOpen
                and (
                    <IosInstallGuide
                        isOpen={pwa.iosGuideOpen}
                        onClose={pwa.closeIosGuide}
                        appName={pwa.appName}
                    />
                )}
        </>
    );
}

impl PwaInstallButton(
    children: object = "Install",
    className: str = "jac-pwa-banner__install",
    style: (dict[str, object] | None) = None,
    onInstalled: (Callable[[], None] | None) = None
) -> JsxElement {
    pwa = usePwaInstall();
    buttonStyle: dict[str, any] = style or {};

    async def handleClick {
        result = await pwa.install();
        if result and onInstalled is not None {
            onInstalled();
        }
    }

    if not pwa.canInstall or pwa.isInstalled {
        return <></>;
    }

    return (
        <>
            <style>{__getPwaStyles()}</style>
            <button
                className={className}
                style={buttonStyle}
                onClick={handleClick}
                disabled={pwa.isPending}
            >
                {children}
            </button>
            {pwa.iosGuideOpen
                and (
                    <IosInstallGuide
                        isOpen={pwa.iosGuideOpen}
                        onClose={pwa.closeIosGuide}
                        appName={pwa.appName}
                    />
                )}
        </>
    );
}

impl IosInstallGuide(
    isOpen: bool = False,
    onClose: (Callable[[], None] | None) = None,
    appName: str = "",
    title: str = "",
    className: str = ""
) -> JsxElement {
    guideName = appName or "this app";
    guideTitle = title or f"Install {guideName}";

    def handleClose(e: MouseEvent) {
        if onClose is not None {
            onClose();
        }
    }

    if not isOpen {
        return <></>;
    }

    return (
        <>
            <style>{__getPwaStyles()}</style>
            <div className="jac-pwa-ios-overlay" onClick={handleClose}>
                <div
                    className={"jac-pwa-ios-guide " + className}
                    onClick={lambda (e: MouseEvent) { e.stopPropagation(); }}
                >
                    <div className="jac-pwa-ios-guide__title">{guideTitle}</div>
                    <div className="jac-pwa-ios-guide__subtitle">
                        Add to your home screen
                    </div>
                    <div className="jac-pwa-ios-guide__steps">
                        <div className="jac-pwa-ios-guide__step">
                            <span className="jac-pwa-ios-guide__step-num">1</span>
                            <span className="jac-pwa-ios-guide__step-icon">↑</span>
                            <span className="jac-pwa-ios-guide__step-text">
                                Tap the
                                <strong>Share</strong>
                                button
                            </span>
                        </div>
                        <div className="jac-pwa-ios-guide__step">
                            <span className="jac-pwa-ios-guide__step-num">2</span>
                            <span className="jac-pwa-ios-guide__step-icon">+</span>
                            <span className="jac-pwa-ios-guide__step-text">
                                Tap
                                <strong>Add to Home Screen</strong>
                            </span>
                        </div>
                        <div className="jac-pwa-ios-guide__step">
                            <span className="jac-pwa-ios-guide__step-num">3</span>
                            <span className="jac-pwa-ios-guide__step-icon">✓</span>
                            <span className="jac-pwa-ios-guide__step-text">
                                Tap
                                <strong>Add</strong>
                                to confirm
                            </span>
                        </div>
                    </div>
                    <button className="jac-pwa-ios-guide__close" onClick={handleClose}>
                        Got it
                    </button>
                </div>
            </div>
        </>
    );
}

impl __jacPwaInit -> None {
    captureInstallPrompt();
}
