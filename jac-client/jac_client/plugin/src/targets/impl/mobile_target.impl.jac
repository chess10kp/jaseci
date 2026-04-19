"""Implementation of MobileTarget methods."""
import json;
import subprocess;
import shutil;
import os;
import stat;
import platform as platform_mod;
import from pathlib { Path }
import from typing { Optional }
import from jaclang.cli.console { console }

# ===============================================================================
# Constants
# ===============================================================================
glob DEFAULT_APP_ID = "com.jac.app",
     DEFAULT_APP_NAME = "Jac App",
     SUBPROCESS_TIMEOUT_SHORT: int = 5,
     SUBPROCESS_TIMEOUT_MEDIUM: int = 60,
     SUBPROCESS_TIMEOUT_BUILD: int = 600,
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

# ===============================================================================
# Dependency Checking
# ===============================================================================
"""Check and report on Android build prerequisites."""
def _check_android_dependencies {
    # Java / JDK (required for Gradle / Android builds)
    (java_ok, java_ver) = _check_command_available(["java", "-version"]);
    if not java_ok {
        (java_ok, java_ver) = _check_command_available(["javac", "-version"]);
    }
    if java_ok {
        console.print(f"  ✔ Java found: {java_ver or 'available'}", style="success");
    } else {
        console.warning("  ✖ Java/JDK not found");
        console.print(
            "    Install JDK 17+: https://adoptium.net or via your package manager",
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
# Target Implementation
# ===============================================================================
"""Setup mobile target - install Capacitor and scaffold platform project.

Sets up both Android and iOS platforms so the project is ready for either.
"""
impl MobileTarget.setup(project_dir: Path) -> None {
    android_dir = project_dir / "android";
    ios_dir = project_dir / "ios";

    # Early return if both platforms already set up
    if android_dir.exists() and ios_dir.exists() {
        console.print(
            "\n📱 Mobile target already set up (Android + iOS). Skipping...",
            style="muted"
        );
        return;
    }

    console.print("\n📱 Setting up mobile target (Capacitor)", style="bold");
    console.print(f"  Project directory: {project_dir}", style="muted");

    # Check prerequisites for both platforms
    try {
        _check_and_report_dependencies("android");
        _check_and_report_dependencies("ios");
    } except Exception as e {
        console.warning(f"  Dependency check encountered an issue: {e}");
        console.print(
            "  Setup will continue, but some dependencies may be missing.",
            style="muted"
        );
    }

    # Wrap in try/finally to guarantee platform dirs exist even if later steps fail
    try {
        import from jac_client.plugin.src.vite_bundler { ViteBundler }
        bundler = ViteBundler(project_dir=project_dir);
        web_dist_dir = Path(bundler.output_dir).resolve();
        web_dist_dir.mkdir(parents=True, exist_ok=True);

        _ensure_capacitor_deps(project_dir);
        _ensure_capacitor_config(project_dir, web_dist_dir);

        # Scaffold both platforms
        _ensure_android_platform(project_dir, web_dist_dir);
        _ensure_ios_platform(project_dir, web_dist_dir);

        # Write [plugins.client.mobile] into jac.toml
        mobile_cfg = _load_mobile_config(project_dir);
        app_name = mobile_cfg.get("app_name", DEFAULT_APP_NAME);
        app_id = mobile_cfg.get("app_id", DEFAULT_APP_ID);
        try {
            _add_mobile_config(project_dir, app_name, app_id);
        } except Exception as e {
            console.warning(
                f"  Failed to add [plugins.client.mobile] to jac.toml: {e}"
            );
        }

        console.success("Mobile target setup complete!");
        console.print("\nNext steps:", style="bold");
        console.print("  Android:");
        console.print("    Dev:   jac start main.jac --client mobile");
        console.print("    Build: jac build --client mobile --platform android");
        console.print("  iOS:");
        console.print("    Dev:   jac start main.jac --client mobile --platform ios");
        console.print("    Build: jac build --client mobile --platform ios");
    } finally {
        # Guarantee at least android/ dir exists even if something failed
        if not android_dir.exists() {
            try {
                android_dir.mkdir(parents=True, exist_ok=True);
                console.print(f"  ✔ Ensured {android_dir} exists", style="success");
            } except Exception as e {
                console.error(f"  CRITICAL: Could not create android directory: {e}");
            }
        }
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

    # Ensure Capacitor scaffold exists
    self.setup(project_dir);

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

"""Start mobile dev flow - build web bundle and launch on device/simulator."""
impl MobileTarget.dev(
    entry_file: Path, project_dir: Path, api_port: int = 8000
) -> None {
    # Determine platform from config, default to android
    mobile_cfg = _load_mobile_config(project_dir);
    plat = mobile_cfg.get("default_platform", "android");
    plat = _normalize_mobile_platform(plat);

    console.print(
        f"\n📱 Starting mobile dev flow (Capacitor {plat.capitalize()})", style="bold"
    );

    # Ensure scaffold
    self.setup(project_dir);

    # Build web bundle
    web_bundle_path = super.build(entry_file, project_dir, None);

    # Sync and run
    _run_cap_cmd(project_dir, ["sync", plat], f"cap sync {plat}");
    _run_cap_cmd(project_dir, ["run", plat], f"cap run {plat}");
}

"""Start mobile app - build then run on device/simulator."""
impl MobileTarget.start(
    entry_file: Path, project_dir: Path, api_port: int = 8000
) -> None {
    self.dev(entry_file, project_dir, api_port);
}
