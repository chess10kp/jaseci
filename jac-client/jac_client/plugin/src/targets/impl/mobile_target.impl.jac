"""Implementation of MobileTarget methods."""
import json;
import re;
import subprocess;
import shutil;
import os;
import stat;
import platform as platform_mod;
import from pathlib { Path }
import from typing { Any, Optional, cast }
import from jaclang.cli.console { console }
import from jaclang.runtimelib.watcher { FileChangeEvent }
import from jac_client.plugin.src.config_loader { JacClientConfig }
import from jac_client.plugin.src.mobile_dev_host {
    resolve_mobile_dev_host,
    resolve_mobile_server_port
}

# ===============================================================================
# Constants
# ===============================================================================
glob DEFAULT_APP_ID = "com.jac.app",
     DEFAULT_APP_NAME = "Jac App",
     SUBPROCESS_TIMEOUT_SHORT: int = 5,
     SUBPROCESS_TIMEOUT_MEDIUM: int = 60,
     SUBPROCESS_TIMEOUT_BUILD: int = 600,
     MOBILE_SETUP_PLATFORM_ENV = "JAC_MOBILE_SETUP_PLATFORM",
     MOBILE_SETUP_MODES: list[str] = ["android", "ios", "all"],
     SUPPORTED_PLATFORMS: list[str] = ["android", "ios"];

# ===============================================================================
# Helper Functions
# ===============================================================================
"""Check if a command is available and optionally return its version."""
def _check_command_available(
    cmd: list[str], timeout: int = SUBPROCESS_TIMEOUT_SHORT
) -> tuple[bool, str | None] {
    try {
        result = subprocess.run(cmd, capture_output=True, text=True, timeout=timeout);
        if result.returncode == 0 {
            return (True, result.stdout.strip());
        }
    } except Exception { }
    return (False, None);
}

"""Parse major Java version from `java -version` / `javac -version` output.
"""
def _parse_java_major_from_version_output(text: str) -> int | None {
    m = re.search(r'version "([^"]+)"', text);
    if not m {
        return None;
    }
    v = m.group(1);
    parts = v.split(".");
    if parts[0] == "1" and len(parts) > 1 {
        try {
            return int(parts[1]);
        } except ValueError {
            return None;
        }
    }
    try {
        return int(parts[0]);
    } except (ValueError, IndexError) {
        return None;
    }
}

"""Return (ok, first_line, major) for the default java on PATH.
"""
def _get_java_runtime_details -> tuple[bool, str | None, int | None] {
    try {
        result = subprocess.run(
            ["java", "-version"],
            capture_output=True,
            text=True,
            timeout=SUBPROCESS_TIMEOUT_SHORT
        );
        out = (result.stderr or "") + (result.stdout or "");
        if not out.strip() {
            return (False, None, None);
        }
        first_line = out.strip().split("\n")[0];
        major = _parse_java_major_from_version_output(out);
        return (True, first_line, major);
    } except Exception {
        return (False, None, None);
    }
}

"""Normalize and validate mobile platform string.

Defaults to 'android'. Accepts 'android' or 'ios'.
"""
def _normalize_mobile_platform(platform: Optional[str] = None) -> str {
    if (platform is None) or (platform.strip() == "") {
        return "android";
    }
    value = platform.lower().strip();
    if value in SUPPORTED_PLATFORMS {
        return value;
    }
    raise ValueError(
        f"Unsupported mobile platform '{platform}'. "
        f"Supported: {', '.join(SUPPORTED_PLATFORMS)}"
    );
}

"""Resolve npx command prefix."""
def _resolve_npx -> str {
    (ok, _) = _check_command_available(["npx", "--version"]);
    if ok {
        return "npx";
    }
    (ok, _) = _check_command_available(["bunx", "--version"]);
    if ok {
        return "bunx";
    }
    raise RuntimeError(
        "npx or bunx not found. Install Node.js (https://nodejs.org) "
        "or Bun (https://bun.sh)."
    );
}

"""Run a Capacitor CLI command from project root."""
def _run_cap_cmd(project_dir: Path, args: list[str], label: str) {
    npx = _resolve_npx();
    cmd = [npx, "cap"] + args;
    console.print(f"  Running {label}: {' '.join(cmd)}", style="muted");
    subprocess.run(cmd, cwd=project_dir, check=True, capture_output=False);
}

"""Run an npm/bun install command."""
def _run_install_cmd(project_dir: Path, packages: list[str], dev: bool = False) {
    pkg_json = project_dir / "package.json";
    if not pkg_json.exists() {
        pkg_data = {
            "name": "jac-mobile-app",
            "version": "1.0.0",
            "private": True,
            "type": "module"
        };
        pkg_json.write_text(json.dumps(pkg_data, indent=2), encoding="utf-8");
        console.print("  ✔ Created package.json", style="success");
    }
    (npm_ok, _) = _check_command_available(["npm", "--version"]);
    if npm_ok {
        cmd = ["npm", "install"];
        if dev {
            cmd.append("--save-dev");
        }
        cmd.extend(packages);
    } else {
        cmd = ["bun", "add"];
        if dev {
            cmd.append("--dev");
        }
        cmd.extend(packages);
    }
    console.print(f"  Installing: {' '.join(packages)}", style="muted");
    subprocess.run(cmd, cwd=project_dir, check=True, capture_output=False);
}

"""Allow http:// LAN dev URLs in the WebView (Android 9+ blocks cleartext by default)."""
def _ensure_android_cleartext_for_lan_dev(project_dir: Path) -> None {
    man = project_dir / "android" / "app" / "src" / "main" / "AndroidManifest.xml";
    if not man.exists() {
        return;
    }
    t = man.read_text(encoding="utf-8");
    if "usesCleartextTraffic" in t {
        return;
    }
    new_t = re.sub(
        r"([ \t]*<application[ \t]*\r?\n)([ \t]+)(android:)",
        r'\1\2android:usesCleartextTraffic="true"\n\2\3',
        t,
        count=1
    );
    if new_t != t {
        man.write_text(new_t, encoding="utf-8");
        console.print(
            "  ✔ Android: allowed cleartext HTTP for dev (usesCleartextTraffic); "
            "rebuild applies on cap run",
            style="success"
        );
    } else {
        console.warning(
            "  Could not auto-patch AndroidManifest for cleartext HTTP. "
            "If the WebView will not load http://<PC-LAN-IP>:<port>, set "
            "android:usesCleartextTraffic=\"true\" on <application>."
        );
    }
}

# ===============================================================================
# Dependency Checking
# ===============================================================================
"""Check and report on Android build prerequisites."""
def _check_android_dependencies {
    # Java / JDK (Capacitor Android Gradle modules target Java 21+)
    (java_ok, java_line, java_major) = _get_java_runtime_details();
    java_exe = shutil.which("java");
    java_home = os.environ.get("JAVA_HOME", "");
    if java_ok {
        console.print(f"  ✔ Java runtime: {java_line}", style="success");
        if java_exe {
            console.print(f"    java binary: {java_exe}", style="muted");
        }
        if java_home {
            console.print(f"    JAVA_HOME: {java_home}", style="muted");
        } else {
            console.print(
                "    JAVA_HOME: (not set — using java on PATH)", style="muted"
            );
        }
        if java_major is not None {
            if java_major < 21 {
                console.print(
                    f"  Java {java_major} is below 21. Capacitor Android / Gradle "
                    "needs JDK 21+ to compile.",
                    style="warning"
                );
                console.print(
                    "    Set JAVA_HOME to a JDK 21 install, e.g. "
                    "/usr/lib/jvm/java-21-openjdk (Linux).",
                    style="muted"
                );
            } else {
                console.print(
                    f"    (JDK major {java_major} — OK for current Capacitor Android builds)",
                    style="muted"
                );
            }
        } else {
            console.print(
                "    (Could not parse Java version — ensure JDK 21+ for native Android builds)",
                style="muted"
            );
        }
    } else {
        console.warning("  ✖ Java runtime not found on PATH");
        console.print(
            "    Install JDK 21+ (e.g. OpenJDK 21): https://adoptium.net or your package manager",
            style="muted"
        );
    }

    # Android SDK (ANDROID_HOME or ANDROID_SDK_ROOT)
    android_home = os.environ.get("ANDROID_HOME") or os.environ.get("ANDROID_SDK_ROOT");
    if android_home and Path(android_home).is_dir() {
        console.print(f"  ✔ Android SDK found: {android_home}", style="success");
    } else {
        console.warning(
            "  ✖ Android SDK not found (ANDROID_HOME / ANDROID_SDK_ROOT not set)"
        );
        console.print(
            "    Install Android Studio or the command-line tools:\n"
            "    https://developer.android.com/studio",
            style="muted"
        );
    }

    # ADB (optional, needed for on-device deployment)
    (adb_ok, adb_ver) = _check_command_available(["adb", "--version"]);
    if adb_ok {
        first_line = (adb_ver or "").split("\n")[0];
        console.print(f"  ✔ ADB found: {first_line}", style="success");
    } else {
        console.print(
            "  ⚠ ADB not found (needed for on-device deployment)", style="warning"
        );
        console.print("    ADB ships with Android SDK platform-tools", style="muted");
    }

    # Gradle (optional, gradlew in android/ is preferred)
    (gradle_ok, gradle_ver) = _check_command_available(["gradle", "--version"]);
    if gradle_ok {
        first_line = (gradle_ver or "").split("\n")[0];
        console.print(f"  ✔ Gradle found: {first_line}", style="success");
    } else {
        console.print(
            "  ⚠ Gradle not found globally (will use android/gradlew wrapper if available)",
            style="muted"
        );
    }
}

"""Check and report on iOS build prerequisites."""
def _check_ios_dependencies -> None {
    if platform_mod.system() != "Darwin" {
        console.warning("  ⚠ iOS builds require macOS — current OS is not macOS");
        console.print(
            "    You can still scaffold the project, but building requires a Mac.",
            style="muted"
        );
        return;
    }

    # Xcode Command Line Tools
    (xcode_ok, xcode_ver) = _check_command_available(["xcode-select", "-p"]);
    if xcode_ok {
        console.print(f"  ✔ Xcode CLI tools found: {xcode_ver}", style="success");
    } else {
        console.warning("  ✖ Xcode Command Line Tools not found");
        console.print("    Install with: xcode-select --install", style="muted");
    }

    # xcodebuild
    (xcbuild_ok, xcbuild_ver) = _check_command_available(["xcodebuild", "-version"]);
    if xcbuild_ok {
        first_line = (xcbuild_ver or "").split("\n")[0];
        console.print(f"  ✔ Xcode build: {first_line}", style="success");
    } else {
        console.warning("  ✖ xcodebuild not found");
        console.print(
            "    Install Xcode from the App Store: https://apps.apple.com/app/xcode/id497799835",
            style="muted"
        );
    }

    # CocoaPods (used by Capacitor iOS)
    (pod_ok, pod_ver) = _check_command_available(["pod", "--version"]);
    if pod_ok {
        console.print(f"  ✔ CocoaPods found: {pod_ver}", style="success");
    } else {
        console.warning("  ✖ CocoaPods not found (required by Capacitor iOS)");
        console.print("    Install with: sudo gem install cocoapods", style="muted");
    }

    # ios-deploy (optional, for on-device deployment)
    (iosdep_ok, _) = _check_command_available(["ios-deploy", "--version"]);
    if iosdep_ok {
        console.print("  ✔ ios-deploy found", style="success");
    } else {
        console.print(
            "  ⚠ ios-deploy not found (needed for on-device deployment)",
            style="warning"
        );
        console.print("    Install with: brew install ios-deploy", style="muted");
    }

    # iOS Simulator CLI (xcrun simctl) — for simulator dev/build
    (simctl_ok, _) = _check_command_available(
        ["xcrun", "simctl", "help"], timeout=SUBPROCESS_TIMEOUT_SHORT
    );
    if simctl_ok {
        console.print(
            "  ✔ iOS Simulator tools (xcrun simctl) available", style="success"
        );
    } else {
        console.print(
            "  ⚠ xcrun simctl not available (install full Xcode, not only CLT, "
            "for the iOS Simulator)",
            style="warning"
        );
    }
}

"""Check and report on all mobile build prerequisites for a given platform."""
def _check_and_report_dependencies(plat: str = "android") {
    console.print("\n📦 Checking mobile build dependencies...", style="bold");

    # Common: Node.js / Bun (required for Capacitor CLI)
    (node_ok, node_ver) = _check_command_available(["node", "--version"]);
    if node_ok {
        console.print(f"  ✔ Node.js found: {node_ver}", style="success");
    } else {
        (bun_ok, bun_ver) = _check_command_available(["bun", "--version"]);
        if bun_ok {
            console.print(f"  ✔ Bun found: {bun_ver}", style="success");
        } else {
            console.warning("  ✖ Node.js or Bun not found");
            console.print(
                "    Install Node.js (https://nodejs.org) or Bun (https://bun.sh)",
                style="muted"
            );
        }
    }

    # Platform-specific checks
    if plat == "android" {
        _check_android_dependencies();
    } elif plat == "ios" {
        _check_ios_dependencies();
    }
}

"""Run platform dependency check; log and continue on internal errors."""
def _try_check_mobile_dependencies(plat: str) {
    try {
        _check_and_report_dependencies(plat);
    } except Exception as e {
        console.warning(f"  Dependency check encountered an issue: {e}");
    }
}

"""iOS native workflows need macOS; fail fast on other hosts."""
def _require_macos_for_ios(plat: str) -> None {
    if _normalize_mobile_platform(plat) != "ios" {
        return;
    }
    if platform_mod.system() == "Darwin" {
        return;
    }
    raise RuntimeError(
        "iOS native builds and `cap run ios` require macOS with Xcode. "
        "Use a Mac or a macOS CI runner for the iOS target."
    );
}

# ===============================================================================
# Config Helpers
# ===============================================================================
"""Load mobile config from jac.toml."""
def _load_mobile_config(project_dir: Path) -> dict {
    try {
        import tomllib;
        toml_path = project_dir / "jac.toml";
        if toml_path.exists() {
            content = toml_path.read_text(encoding="utf-8");
            config = tomllib.loads(content);
            return config.get("plugins", {}).get("client", {}).get("mobile", {});
        }
    } except Exception {
        ;
    }
    return {};
}

"""Resolve mobile setup mode (android, ios, all).

Priority: explicit env override -> jac.toml default_platform -> host default.
"""
def _resolve_mobile_setup_mode(project_dir: Path, is_macos: bool) -> tuple[str, bool] {
    requested = os.environ.get(MOBILE_SETUP_PLATFORM_ENV, "").strip().lower();
    if requested in MOBILE_SETUP_MODES {
        return (requested, True);
    }
    mobile_cfg = _load_mobile_config(project_dir);
    default_platform = str(mobile_cfg.get("default_platform", "")).strip().lower();
    if default_platform in SUPPORTED_PLATFORMS {
        return (default_platform, False);
    }
    return ("ios", False) if is_macos else ("android", False);
}

"""Add [plugins.client.mobile] section to jac.toml if not present."""
def _add_mobile_config(project_dir: Path, app_name: str, app_id: str) -> None {
    toml_path = project_dir / "jac.toml";
    if not toml_path.exists() {
        return;
    }
    content = toml_path.read_text(encoding="utf-8");
    if "[plugins.client.mobile]" in content {
        console.print("  ✔ [plugins.client.mobile] already in jac.toml", style="muted");
        return;
    }

    mobile_section = (
        "\n[plugins.client.mobile]\n"
        f'app_name = "{app_name}"\n'
        f'app_id = "{app_id}"\n'
    );
    content += mobile_section;
    toml_path.write_text(content, encoding="utf-8");
    console.print("  ✔ Added [plugins.client.mobile] to jac.toml", style="success");
}

"""Write capacitor.config.json pointing webDir at the Vite output."""
def _write_capacitor_config(project_dir: Path, web_dist_dir: Path) {
    mobile_cfg = _load_mobile_config(project_dir);
    app_id = mobile_cfg.get("app_id", DEFAULT_APP_ID);
    app_name = mobile_cfg.get("app_name", DEFAULT_APP_NAME);

    try {
        web_dir_rel = str(web_dist_dir.relative_to(project_dir));
    } except ValueError {
        web_dir_rel = str(web_dist_dir);
    }

    config = {
        "appId": app_id,
        "appName": app_name,
        "webDir": web_dir_rel,
        "server": {"androidScheme": "https", "iosScheme": "capacitor"}
    };
    config_path = project_dir / "capacitor.config.json";
    config_path.write_text(json.dumps(config, indent=2), encoding="utf-8");
    console.print("  ✔ Wrote capacitor.config.json", style="success");
}

# ===============================================================================
# Scaffold Helpers
# ===============================================================================
"""Ensure Capacitor dependencies are installed."""
def _ensure_capacitor_deps(project_dir: Path) -> None {
    node_modules = project_dir / "node_modules" / "@capacitor" / "cli";
    if node_modules.exists() {
        console.print("  ✔ Capacitor dependencies already installed", style="muted");
        return;
    }
    _run_install_cmd(project_dir, ["@capacitor/core"]);
    _run_install_cmd(project_dir, ["@capacitor/cli"], dev=True);
}

"""Ensure Capacitor config exists."""
def _ensure_capacitor_config(project_dir: Path, web_dist_dir: Path) -> None {
    config_path = project_dir / "capacitor.config.json";
    if config_path.exists() {
        try {
            existing = json.loads(config_path.read_text(encoding="utf-8"));
            web_dir_rel = str(web_dist_dir.relative_to(project_dir));
            if existing.get("webDir") != web_dir_rel {
                existing["webDir"] = web_dir_rel;
                config_path.write_text(
                    json.dumps(existing, indent=2), encoding="utf-8"
                );
                console.print(
                    "  ✔ Updated capacitor.config.json webDir", style="muted"
                );
            } else {
                console.print(
                    "  ✔ capacitor.config.json already exists", style="muted"
                );
            }
        } except Exception {
            console.print("  ✔ capacitor.config.json already exists", style="muted");
        }
        return;
    }
    _write_capacitor_config(project_dir, web_dist_dir);
}

"""Ensure web dist directory has at least a placeholder index.html.

Capacitor's 'add' and 'sync' commands require an index.html in webDir.
"""
def _ensure_placeholder_index(web_dist_dir: Path) -> None {
    index_html = web_dist_dir / "index.html";
    if index_html.exists() {
        return;
    }
    web_dist_dir.mkdir(parents=True, exist_ok=True);
    index_html.write_text(
        '<!DOCTYPE html><html><head></head><body></body></html>', encoding="utf-8"
    );
}

"""Ensure Android platform is added."""
def _ensure_android_platform(project_dir: Path, web_dist_dir: Path) -> None {
    android_dir = project_dir / "android";
    if android_dir.exists() {
        console.print("  ✔ Android platform already added", style="muted");
        return;
    }
    _run_install_cmd(project_dir, ["@capacitor/android"]);
    _ensure_placeholder_index(web_dist_dir);
    _run_cap_cmd(project_dir, ["add", "android"], "cap add android");
    console.print("  ✔ Android platform added", style="success");
}

"""Ensure iOS platform is added."""
def _ensure_ios_platform(project_dir: Path, web_dist_dir: Path) -> None {
    ios_dir = project_dir / "ios";
    if ios_dir.exists() {
        console.print("  ✔ iOS platform already added", style="muted");
        return;
    }
    _run_install_cmd(project_dir, ["@capacitor/ios"]);
    _ensure_placeholder_index(web_dist_dir);
    _run_cap_cmd(project_dir, ["add", "ios"], "cap add ios");
    console.print("  ✔ iOS platform added", style="success");
}

# ===============================================================================
# Android Build Helpers
# ===============================================================================
"""Find newest Android APK or AAB artifact."""
def _find_android_artifact(project_dir: Path) -> Path {
    outputs_root = project_dir / "android" / "app" / "build" / "outputs";
    if not outputs_root.exists() {
        return outputs_root;
    }
    artifacts: list = [];
    for ext in [".apk", ".aab"] {
        artifacts.extend(
            [
                f
                for f in outputs_root.rglob(f"*{ext}")
                if f.is_file()
            ]
        );
    }
    if artifacts {
        artifacts.sort(key=lambda p : p.stat().st_mtime, reverse=True);
        return artifacts[0];
    }
    return outputs_root;
}

"""Resolve gradlew path and ensure it is executable."""
def _resolve_gradlew(project_dir: Path) -> str {
    gradlew = project_dir / "android" / "gradlew";
    if gradlew.exists() {
        st = os.stat(gradlew);
        os.chmod(gradlew, st.st_mode | stat.S_IEXEC);
        return str(gradlew);
    }
    return "gradle";
}

"""Determine the Gradle task based on build mode.

Returns the Gradle task name: assembleDebug, assembleRelease, or bundleRelease.
"""
def _get_gradle_task(release: bool = False, bundle: bool = False) -> str {
    if bundle {
        return "bundleRelease";
    }
    if release {
        return "assembleRelease";
    }
    return "assembleDebug";
}

"""Build Android APK/AAB via Gradle."""
def _build_android(project_dir: Path, mobile_cfg: dict) -> Path {
    release = mobile_cfg.get("release", False);
    bundle_aab = mobile_cfg.get("bundle", False);
    gradle_task = _get_gradle_task(release=release, bundle=bundle_aab);

    console.print(f"  Step 3: Running {gradle_task}...", style="muted");
    gradlew = _resolve_gradlew(project_dir);
    android_dir = project_dir / "android";
    subprocess.run(
        [gradlew, gradle_task],
        cwd=android_dir,
        check=True,
        capture_output=False,
        timeout=SUBPROCESS_TIMEOUT_BUILD
    );

    artifact = _find_android_artifact(project_dir);
    return artifact;
}

# ===============================================================================
# iOS Build Helpers
# ===============================================================================
"""Find the Xcode workspace path in ios/App/."""
def _find_xcode_workspace(project_dir: Path) -> Path | None {
    ios_app = project_dir / "ios" / "App";
    if not ios_app.exists() {
        return None;
    }
    workspaces = list(ios_app.glob("*.xcworkspace"));
    if workspaces {
        return workspaces[0];
    }
    projects = list(ios_app.glob("*.xcodeproj"));
    if projects {
        return projects[0];
    }
    return None;
}

"""Build iOS app via xcodebuild.

Produces a debug build for the iOS Simulator by default.
For device builds or release archives, the user should open Xcode:
  npx cap open ios
"""
def _build_ios(project_dir: Path, mobile_cfg: dict) -> Path {
    release = mobile_cfg.get("release", False);
    ios_dir = project_dir / "ios" / "App";

    workspace = _find_xcode_workspace(project_dir);
    if workspace is None {
        raise RuntimeError(
            "Xcode workspace not found in ios/App/. Run 'jac setup mobile' first."
        );
    }

    # Determine build configuration and destination
    configuration = "Release" if release else "Debug";
    # Default to simulator; device builds require provisioning and are best done via Xcode
    sdk = mobile_cfg.get("ios_sdk", "iphonesimulator");
    destination = mobile_cfg.get(
        "ios_destination", "platform=iOS Simulator,name=iPhone 16,OS=latest"
    );

    console.print(f"  Step 3: Building iOS ({configuration}, {sdk})...", style="muted");

    build_cmd = [
        "xcodebuild",
        "-workspace",
        str(workspace),
        "-scheme",
        "App",
        "-configuration",
        configuration,
        "-sdk",
        sdk,
        "-destination",
        destination,
        "build"
    ];

    console.print(f"  Running: {' '.join(build_cmd)}", style="muted");
    result = subprocess.run(
        build_cmd,
        cwd=ios_dir,
        check=False,
        capture_output=False,
        timeout=SUBPROCESS_TIMEOUT_BUILD
    );

    if result.returncode != 0 {
        console.warning(
            "  xcodebuild failed. For device builds or provisioning issues, "
            "open the project in Xcode:"
        );
        console.print("    npx cap open ios", style="muted");
        raise RuntimeError("xcodebuild failed — see output above");
    }

    # Return the DerivedData or build products path
    build_output = project_dir / "ios" / "App" / "build";
    console.print(f"  ✔ iOS build complete ({configuration})", style="success");
    return build_output;
}

# ===============================================================================
# Mobile dev helpers (Vite HMR + Capacitor live-reload)
# ===============================================================================
"""Read [plugins.client.api] base_url for warnings and port resolution."""
def _get_api_base_url_str(project_dir: Path) -> str {
    loader = JacClientConfig(project_dir);
    return loader.get_api_config().get("base_url", "") or "";
}

"""API connectivity for mobile dev."""
def _warn_mobile_dev_api_url(project_dir: Path) {
    base = _get_api_base_url_str(project_dir);
    if base {
        console.print(
            f"  API mode: fixed base_url from jac.toml ({base})", style="muted"
        );
        if ("localhost" in base.lower()) or ("127.0.0.1" in base) {
            console.warning(
                "  Physical devices cannot reach localhost on your PC. "
                "Clear [plugins.client.api] base_url for same-origin dev proxy, "
                "or set base_url to your machine's LAN URL."
            );
        }
    } else {
        console.print(
            "  API mode: same-origin — Vite proxies API routes to the Jac server",
            style="muted"
        );
    }
}

"""Read mobile dev options set by jac-client CLI (see cli.jac)."""
def _mobile_read_dev_env -> tuple[str, int, str] {
    host_ov = os.environ.get("JAC_MOBILE_DEV_HOST", "");
    vite_port = 5173;
    plat_mode = os.environ.get("JAC_MOBILE_PLATFORM", "auto");
    return (host_ov, vite_port, plat_mode);
}

"""Best-effort ADB reverse for Android mobile dev connectivity."""
def _mobile_setup_android_port_reverse(vite_port: int, server_port: int) {
    attempted = str(vite_port);
    if server_port != vite_port {
        attempted = attempted + ", " + str(server_port);
    }
    console.print(
        f"  Android: checking adb reverse for ports {attempted}", style="muted"
    );

    def _try_adb_reverse_port(port: int) {
        cmd = ["adb", "reverse", f"tcp:{port}", f"tcp:{port}"];
        try {
            result = subprocess.run(
                cmd,
                capture_output=True,
                text=True,
                timeout=SUBPROCESS_TIMEOUT_SHORT,
                check=False
            );
            if result.returncode == 0 {
                console.print(
                    f"  ✔ adb reverse tcp:{port} tcp:{port}", style="success"
                );
            } else {
                err = (result.stderr or "").strip() or "unknown adb error";
                console.warning(f"  ⚠ adb reverse failed for tcp:{port} ({err})");
            }
        } except Exception as e {
            console.warning(f"  ⚠ adb reverse failed for tcp:{port} ({e})");
        }
    }

    _try_adb_reverse_port(vite_port);
    if server_port != vite_port {
        _try_adb_reverse_port(server_port);
    }
}

"""Return True if watchdog is available (required for .jac → client HMR)."""
def _mobile_ensure_watchdog -> bool {
    try {
        import watchdog;
        return True;
    } except ImportError {
        console.warning(
            "  watchdog not installed — saving .jac files will not refresh the WebView. "
            "Install with: pip install 'watchdog>=3.0.0' (or add to [dev-dependencies]).",
            style="muted"
        );
        return False;
    }
}

"""Remove stale Jac modules from JacRuntime hub before mobile dev recompiles.

The client bundle compiler reuses JacRuntime.program.mod.hub entries; without
evicting changed modules, compile_module() may return stale JS and Vite reloads
the same bytes.
"""
def _mobile_invalidate_runtime_module_cache(paths: list[str]) -> None {
    try {
        import from jaclang { JacRuntime as Jac }
        program = Jac.program;
        if not program or not program.mod or not program.mod.hub {
            return;
        }
        hub = program.mod.hub;
        norm_targets: set[str] = set();
        for p in paths {
            if not p {
                continue;
            }
            try {
                norm_targets.add(os.path.normcase(str(Path(p).resolve())));
            } except Exception {
                norm_targets.add(os.path.normcase(str(p)));
            }
        }
        if not norm_targets {
            return;
        }
        to_delete: list[str] = [];
        for k in list(hub.keys()) {
            if os.path.normcase(str(k)) in norm_targets {
                to_delete.append(k);
            }
        }
        for k in to_delete {
            del hub[k];
        }
    } except Exception {
        # Cache eviction is best-effort; compile still proceeds if this fails.
        return;
    }
}

"""Recompile the Vite client graph after a .jac file change (runs on watchdog thread).
"""
def _mobile_hmr_on_jac_changed(
    event: FileChangeEvent, compiler: Any, entry_file: Path, project_dir: Path
) -> None {
    try {
        pth = event.path or "";
        if not pth {
            return;
        }
        if not pth.endswith(".jac") {
            return;
        }
        try {
            Path(pth).resolve().relative_to(project_dir.resolve());
        } except ValueError {
            return;
        }
        _mobile_invalidate_runtime_module_cache([pth, str(entry_file)]);
        (_, mod2, _) = compiler.jac_compiler.compile_module(entry_file);
        if not mod2 {
            return;
        }
        compiler.compile(mod2, entry_file);
        try {
            console.print("  ✔ Client recompiled after save", style="success");
        } except Exception { }
    } except Exception as e {
        try {
            console.error(f"  HMR recompile failed: {e}");
        } except Exception { }
    }
}

"""Forward HMR events from JacFileWatcher into the recompile helper."""
impl _MobileHmrHandler.on_event(evt: FileChangeEvent) -> None {
    _mobile_hmr_on_jac_changed(evt, self.compiler, self.entry_file, self.project_dir);
}

"""Start Jac API only for mobile dev."""
def _mobile_start_backend_server(
    entry_file: Path, project_dir: Path, port: int
) -> Any {
    import sys;
    return subprocess.Popen(
        [
            sys.executable,
            "-m",
            "jaclang",
            "start",
            str(entry_file),
            "--port",
            str(port),
            "--no_client"
        ],
        cwd=str(project_dir),
        stdout=None,
        stderr=None
    );
}

"""Write server.url into capacitor.config.json for live-reload.

During dev, the Capacitor WebView loads directly from the Vite dev server
instead of the static webDir. We save the original config and restore it on exit.
"""
def _inject_capacitor_dev_url(project_dir: Path, dev_url: str) -> str | None {
    config_path = project_dir / "capacitor.config.json";
    if not config_path.exists() {
        return None;
    }
    t = config_path.read_text(encoding="utf-8");
    original = t;
    try {
        cfg = json.loads(t);
    } except Exception {
        return None;
    }
    server = cfg.get("server", {});
    server["url"] = dev_url;
    server["cleartext"] = True;
    cfg["server"] = server;
    config_path.write_text(json.dumps(cfg, indent=2), encoding="utf-8");
    console.print(
        f"  ✔ capacitor.config.json → server.url = {dev_url}", style="success"
    );
    return original;
}

"""Restore capacitor.config.json to its pre-dev state."""
def _restore_capacitor_config(project_dir: Path, original: str | None) -> None {
    if original is None {
        return;
    }
    config_path = project_dir / "capacitor.config.json";
    config_path.write_text(original, encoding="utf-8");
    console.print("  ✔ Restored capacitor.config.json", style="muted");
}

"""Run cap run (no --live-reload; server.url in config points to Vite)."""
def _run_cap_run_live_reload(
    project_dir: Path, plat: str, lr_host: str, lr_port: int
) -> int {
    npx = _resolve_npx();
    cmd = [npx, "cap", "run", plat];
    console.print(f"  Running: {' '.join(cmd)}", style="muted");
    console.print("  (Press Ctrl+C to stop)\n", style="muted");
    result = subprocess.run(cmd, cwd=project_dir, check=False);
    return result.returncode;
}

# ===============================================================================
# Target Implementation
# ===============================================================================
"""Setup mobile target - install Capacitor and scaffold platform project.

Scaffolds selected platform(s):
- explicit via JAC_MOBILE_SETUP_PLATFORM=android|ios|all
- otherwise from [plugins.client.mobile].default_platform
- otherwise host default (ios on macOS, android elsewhere)
"""
impl MobileTarget.setup(project_dir: Path) -> None {
    android_dir = project_dir / "android";
    ios_dir = project_dir / "ios";
    is_macos = platform_mod.system() == "Darwin";
    (setup_mode, explicit_setup_mode) = _resolve_mobile_setup_mode(
        project_dir, is_macos
    );
    platforms: list[str] = [];
    if setup_mode == "all" {
        if not is_macos and explicit_setup_mode {
            console.warning(
                "  iOS scaffold in --platform all requires macOS; using Android."
            );
        }
        platforms = ["android", "ios"] if is_macos else ["android"];
    } elif setup_mode == "android" {
        platforms = ["android"];
    } elif setup_mode == "ios" {
        if is_macos {
            platforms = ["ios"];
        } elif explicit_setup_mode {
            raise RuntimeError(
                "iOS scaffold setup requires macOS. "
                "Use --platform android on Linux/Windows."
            );
        } else {
            console.warning(
                "  default_platform is ios but host is not macOS; using Android scaffold."
            );
            platforms = ["android"];
        }
    } else {
        raise ValueError(
            f"Unsupported setup platform '{setup_mode}'. "
            f"Supported: {', '.join(MOBILE_SETUP_MODES)}"
        );
    }
    needs_android = "android" in platforms;
    needs_ios = "ios" in platforms;

    # Early return when required platform scaffolds already exist.
    if (not needs_android or android_dir.exists())
    and (not needs_ios or ios_dir.exists()) {
        console.print("\n📱 Mobile target already set up. Skipping...", style="muted");
        return;
    }

    console.print("\n📱 Setting up mobile target (Capacitor)", style="bold");
    console.print(f"  Project directory: {project_dir}", style="muted");

    # Check prerequisites for selected platforms
    try {
        checked: set[str] = set();
        for plat in platforms {
            if plat not in checked {
                _check_and_report_dependencies(plat);
                checked.add(plat);
            }
        }
    } except Exception as e {
        console.warning(f"  Dependency check encountered an issue: {e}");
        console.print(
            "  Setup will continue, but some dependencies may be missing.",
            style="muted"
        );
    }

    import from jac_client.plugin.src.vite_bundler { ViteBundler }
    bundler = ViteBundler(project_dir=project_dir);
    web_dist_dir = Path(bundler.output_dir).resolve();
    web_dist_dir.mkdir(parents=True, exist_ok=True);

    _ensure_capacitor_deps(project_dir);
    _ensure_capacitor_config(project_dir, web_dist_dir);

    # Scaffold selected platforms.
    if needs_android {
        _ensure_android_platform(project_dir, web_dist_dir);
    }
    if needs_ios {
        _ensure_ios_platform(project_dir, web_dist_dir);
    }

    # Write [plugins.client.mobile] into jac.toml
    mobile_cfg = _load_mobile_config(project_dir);
    app_name = mobile_cfg.get("app_name", DEFAULT_APP_NAME);
    app_id = mobile_cfg.get("app_id", DEFAULT_APP_ID);
    try {
        _add_mobile_config(project_dir, app_name, app_id);
    } except Exception as e {
        console.warning(f"  Failed to add [plugins.client.mobile] to jac.toml: {e}");
    }

    setup_label = ", ".join(platforms);
    console.success(f"Mobile target setup complete ({setup_label}).");
    console.print("\nNext steps:", style="bold");
    if needs_android {
        console.print("  Android:");
        console.print(
            "    Dev:   jac start main.jac --client mobile --dev", style="muted"
        );
        console.print("    Build: jac build --client mobile --platform android");
    }
    if needs_ios {
        console.print("  iOS:");
        console.print(
            "    Dev:   jac start main.jac --client mobile --dev --platform ios",
            style="muted"
        );
        console.print("    Build: jac build --client mobile --platform ios");
    }
}

"""Build mobile app - build web bundle first, then sync and build native app."""
impl MobileTarget.build(
    entry_file: Path, project_dir: Path, platform: Optional[str] = None
) -> Path {
    import from jac_client.plugin.src.vite_bundler { ViteBundler }
    selected_platform = _normalize_mobile_platform(platform);
    mobile_cfg = _load_mobile_config(project_dir);

    console.print(
        f"\n📱 Building mobile app (Capacitor {selected_platform.capitalize()})",
        style="bold"
    );

    _try_check_mobile_dependencies(selected_platform);
    _require_macos_for_ios(selected_platform);

    # Ensure Capacitor scaffold exists
    prev_setup_platform = os.environ.get(MOBILE_SETUP_PLATFORM_ENV, None);
    os.environ[MOBILE_SETUP_PLATFORM_ENV] = selected_platform;
    try {
        self.setup(project_dir);
    } finally {
        if prev_setup_platform is None {
            os.environ.pop(MOBILE_SETUP_PLATFORM_ENV, None);
        } else {
            os.environ[MOBILE_SETUP_PLATFORM_ENV] = prev_setup_platform;
        }
    }

    console.print("  Step 1: Building web bundle...", style="muted");
    web_bundle_path = super.build(entry_file, project_dir, None);
    console.print(f"  ✔ Web bundle built: {web_bundle_path}", style="success");

    # Ensure webDir is up to date in config
    bundler = ViteBundler(project_dir=project_dir);
    web_dist_dir = Path(bundler.output_dir).resolve();
    _ensure_capacitor_config(project_dir, web_dist_dir);

    console.print(
        f"  Step 2: Syncing with Capacitor ({selected_platform})...", style="muted"
    );
    _run_cap_cmd(
        project_dir, ["sync", selected_platform], f"cap sync {selected_platform}"
    );
    console.print("  ✔ Capacitor sync complete", style="success");

    # Platform-specific build
    if selected_platform == "android" {
        artifact = _build_android(project_dir, mobile_cfg);
    } else {
        artifact = _build_ios(project_dir, mobile_cfg);
    }

    console.success(f"Mobile build complete: {artifact}");
    return artifact;
}

"""Start mobile dev: Vite HMR + Jac API + Capacitor live-reload."""
impl MobileTarget.dev(
    entry_file: Path, project_dir: Path, api_port: int = 8000
) -> None {
    import from jac_client.plugin.src.vite_bundler { ViteBundler }
    import from jac_client.plugin.client { JacClient }
    import signal;
    import sys;

    hot_watcher: Any = None;
    if api_port is None {
        api_port = 8000;
    }

    (host_override, vite_port, plat_mode) = _mobile_read_dev_env();
    mobile_cfg = _load_mobile_config(project_dir);
    if plat_mode and plat_mode != "auto" {
        plat = _normalize_mobile_platform(plat_mode);
    } else {
        plat = _normalize_mobile_platform(
            mobile_cfg.get("default_platform", "android")
        );
    }

    console.print(
        f"\nMobile dev (Capacitor + Vite HMR) — {plat.capitalize()}", style="bold"
    );
    _try_check_mobile_dependencies(plat);
    _require_macos_for_ios(plat);
    _warn_mobile_dev_api_url(project_dir);
    prev_setup_platform = os.environ.get(MOBILE_SETUP_PLATFORM_ENV, None);
    os.environ[MOBILE_SETUP_PLATFORM_ENV] = plat;
    try {
        self.setup(project_dir);
    } finally {
        if prev_setup_platform is None {
            os.environ.pop(MOBILE_SETUP_PLATFORM_ENV, None);
        } else {
            os.environ[MOBILE_SETUP_PLATFORM_ENV] = prev_setup_platform;
        }
    }

    visible_host = cast(str, resolve_mobile_dev_host(plat, host_override));

    console.print(f"  Live-reload host: {visible_host}:{vite_port}", style="muted");
    if plat == "android" {
        _ensure_android_cleartext_for_lan_dev(project_dir);
    }

    console.print("  Preparing compilation for Vite dev…", style="muted");
    bundler = ViteBundler(
        project_dir=project_dir, output_dir=None, minify=False, config_path=None
    );
    package_json_path = bundler._get_client_dir() / "configs" / "package.json";
    if not package_json_path.exists() {
        bundler.create_package_json();
    }
    builder = JacClient.get_client_bundle_builder();
    if not builder.vite_package_json or not builder.vite_package_json.exists() {
        builder.vite_package_json = package_json_path;
    }
    compiler = builder._get_compiler();
    compiler.compiled_dir.mkdir(parents=True, exist_ok=True);
    # Full compile graph (entry + all .jac deps) with add_runtime_imports per file,
    # matching production dev — compiling only the entry leaves imported modules
    # (e.g. components/*.js) without __jacJsx and causes "__jacJsx is not defined".
    (_, mod, _) = compiler.jac_compiler.compile_module(entry_file);
    if not mod {
        raise RuntimeError(f"Failed to compile client entry module: {entry_file}");
    }
    compiler.compile(mod, entry_file);
    console.print("  ✔ Client modules compiled for dev mode", style="success");

    toml_base_url = _get_api_base_url_str(project_dir);
    server_port = cast(int, resolve_mobile_server_port(toml_base_url, api_port));
    if plat == "android" {
        _mobile_setup_android_port_reverse(vite_port, server_port);
    }

    cast(Any, bundler).create_vite_config(
        entry_file,
        api_base_url_override="",
        is_dev=True,
        api_port=server_port,
        for_mobile_dev=True,
        mobile_hmr_host=visible_host,
        mobile_hmr_port=vite_port
    );

    console.print(f"  Starting Vite dev server (port {vite_port})…", style="muted");
    vite_process = bundler.start_dev_server(
        port=vite_port, suppress_initial_output=True, host=visible_host
    );
    if not vite_process {
        raise RuntimeError("Failed to start Vite dev server");
    }
    console.print(
        f"  ✔ Vite HMR — WebView loads http://{visible_host}:{vite_port}",
        style="success"
    );

    # `jac start --dev` normally starts HotReloader, but the mobile pre-hook cancels that
    # handler — so we watch .jac here and re-run the same ViteCompiler.compile graph Vite serves.
    if _mobile_ensure_watchdog() {
        import from jaclang.runtimelib.watcher { JacFileWatcher }

        hmr_handler = _MobileHmrHandler(
            compiler=compiler, entry_file=entry_file, project_dir=project_dir
        );
        hot_watcher = JacFileWatcher(watch_paths=[str(project_dir.resolve())]);
        hot_watcher.add_callback(hmr_handler.on_event);
        hot_watcher.start();
        console.print(
            "  👀 Watching **/*.jac — save to trigger recompile + reload", style="muted"
        );
    }

    console.print(f"  Starting Jac API on port {server_port}…", style="muted");
    server_process = _mobile_start_backend_server(entry_file, project_dir, server_port);

    vite_p = vite_process;
    srv_p = server_process;

    def cleanup_servers {
        console.print("\n  Stopping Vite and API server…", style="muted");
        if hot_watcher {
            try {
                hot_watcher.stop();
            } except Exception { }
        }
        if vite_p {
            try {
                vite_p.terminate();
                vite_p.wait(timeout=SUBPROCESS_TIMEOUT_SHORT);
            } except Exception {
                vite_p.kill();
            }
        }
        if srv_p {
            try {
                srv_p.terminate();
                srv_p.wait(timeout=SUBPROCESS_TIMEOUT_SHORT);
            } except Exception {
                srv_p.kill();
            }
        }
        console.print("  ✔ Stopped", style="success");
    }

    def on_signal(signum: int, frame: Any) {
        sys.exit(0);
    }
    signal.signal(cast(int, signal.SIGINT), on_signal);
    signal.signal(cast(int, signal.SIGTERM), on_signal);

    web_dist_dir = Path(bundler.output_dir).resolve();
    _ensure_capacitor_config(project_dir, web_dist_dir);
    _ensure_placeholder_index(web_dist_dir);

    dev_url = f"http://{visible_host}:{vite_port}";
    original_cap_config = _inject_capacitor_dev_url(project_dir, dev_url);

    try {
        _run_cap_cmd(project_dir, ["sync", plat], f"cap sync {plat}");
        rc = _run_cap_run_live_reload(project_dir, plat, visible_host, vite_port);
        if rc != 0 {
            console.warning(f"  cap run exited with code {rc}");
        }
        console.print(
            f"\n  📱 App deployed. Vite + API servers running.", style="bold green"
        );
        console.print(f"  WebView loads: {dev_url}", style="muted");
        console.print("  Press Ctrl+C to quit.\n", style="muted");
        import from time { sleep }
        while True {
            sleep(1);
        }
    } except KeyboardInterrupt {
        console.print("\n  Interrupted.", style="muted");
    } finally {
        _restore_capacitor_config(project_dir, original_cap_config);
        cleanup_servers();
    }
}

"""Start mobile app: production web bundle, sync, run (no Vite HMR)."""
impl MobileTarget.start(
    entry_file: Path, project_dir: Path, api_port: int = 8000
) -> None {
    import from jac_client.plugin.src.vite_bundler { ViteBundler }

    if api_port != 8000 {
        console.print(
            f"  Note: --port {api_port} applies to `jac start` flows; "
            "`cap run` uses the baked web bundle only.",
            style="muted"
        );
    }
    plat_mode = os.environ.get("JAC_MOBILE_PLATFORM", "auto");
    mobile_cfg = _load_mobile_config(project_dir);
    if plat_mode and plat_mode != "auto" {
        plat = _normalize_mobile_platform(plat_mode);
    } else {
        plat = mobile_cfg.get("default_platform", "android");
        plat = _normalize_mobile_platform(plat);
    }

    console.print(
        f"\n📱 Starting mobile app (Capacitor {plat.capitalize()})", style="bold"
    );
    _try_check_mobile_dependencies(plat);
    _require_macos_for_ios(plat);
    prev_setup_platform = os.environ.get(MOBILE_SETUP_PLATFORM_ENV, None);
    os.environ[MOBILE_SETUP_PLATFORM_ENV] = plat;
    try {
        self.setup(project_dir);
    } finally {
        if prev_setup_platform is None {
            os.environ.pop(MOBILE_SETUP_PLATFORM_ENV, None);
        } else {
            os.environ[MOBILE_SETUP_PLATFORM_ENV] = prev_setup_platform;
        }
    }
    console.print("  Building web bundle…", style="muted");
    web_bundle_path = super.build(entry_file, project_dir, None);
    console.print(f"  ✔ Web bundle: {web_bundle_path}", style="success");

    bundler = ViteBundler(project_dir=project_dir);
    web_dist_dir = Path(bundler.output_dir).resolve();
    _ensure_capacitor_config(project_dir, web_dist_dir);

    _run_cap_cmd(project_dir, ["sync", plat], f"cap sync {plat}");
    _run_cap_cmd(project_dir, ["run", plat], f"cap run {plat}");
}
