"""Tests for mobile target registration and discovery."""

import os;
import from pathlib { Path }

glob _plugin_dir = Path(os.path.dirname(__file__)).parent / "plugin";

test "mobile target files exist" {
    mobile_target_jac = _plugin_dir / "src" / "targets" / "mobile_target.jac";
    mobile_target_impl = (
        _plugin_dir / "src" / "targets" / "impl" / "mobile_target.impl.jac"
    );

    assert mobile_target_jac.exists() , (
        f"mobile_target.jac not found at {mobile_target_jac}"
    );
    assert mobile_target_impl.exists() , (
        f"mobile_target.impl.jac not found at {mobile_target_impl}"
    );

    mobile_content = mobile_target_jac.read_text();
    assert "obj MobileTarget" in mobile_content;
    assert "def setup" in mobile_content;
    assert "def build" in mobile_content;
    assert "def dev" in mobile_content;
    assert "def start" in mobile_content;
}

test "target type parser supports mobile" {
    registry_path = _plugin_dir / "src" / "targets" / "registry.jac";
    content = registry_path.read_text();

    assert 'MOBILE = "mobile"' in content;
    assert 'if name_lower == "mobile"' in content;
    assert "return TargetType.MOBILE" in content;
}

test "target factory supports mobile target" {
    impl_path = _plugin_dir / "src" / "targets" / "impl" / "registry.impl.jac";
    content = impl_path.read_text();

    assert "elif target_type == TargetType.MOBILE" in content;
    assert "MobileTarget" in content;
    assert "TargetType.MOBILE" in content;
}

test "mobile_dev_host helper module exists" {
    decl_path = _plugin_dir / "src" / "mobile_dev_host.jac";
    assert decl_path.exists();
    d = decl_path.read_text();
    assert "def detect_lan_ipv4" in d;
    assert "def resolve_mobile_dev_host" in d;
    assert "def resolve_mobile_vite_port" in d;
    assert "JAC_MOBILE_VITE_PORT" in d;
    assert "8.8.8.8" in d;
}

test "JacCmd create_cmd has hookimpl on create_cmd" {
    # Regression: @hookimpl must decorate static def create_cmd (not a docstring).
    # Otherwise pluggy never registers the hook, extend_command never runs, and
    # jac setup / jac build / jac start client integration silently no-op.
    cli = (_plugin_dir / "cli.jac").read_text().replace("\r\n", "\n");
    assert "@hookimpl\n    static def create_cmd" in cli;
}

test "cli exposes mobile dev flags and cap live-reload" {
    cli = _plugin_dir / "cli.jac";
    c = cli.read_text();
    assert 'Arg.create(\n                        "host"' in c;
    assert "Mobile start/dev: android or ios" in c;
    assert "JAC_MOBILE_DEV_HOST" in c;
    assert 'ctx.get_arg("platform", "auto")' in c;
    mt = (
        _plugin_dir / "src" / "targets" / "impl" / "mobile_target.impl.jac"
    ).read_text();
    assert "--live-reload" in mt;
    assert "_mobile_start_backend_server" in mt;
    assert "def _mobile_setup_android_port_reverse" in mt;
    assert '["adb", "reverse"' in mt;
    assert "resolve_mobile_dev_host(plat, host_override)" in mt;
    assert "resolve_mobile_vite_port(project_dir, port)" in mt;
    assert "_mobile_setup_android_port_reverse(vite_port, server_port)" in mt;
    assert 'os.environ.get("JAC_MOBILE_PLATFORM", "auto")' in mt;
}

test "cli exposes mobile setup platform selector" {
    cli = (_plugin_dir / "cli.jac").read_text();
    assert "Platform for mobile setup (android, ios, all)" in cli;
    assert "JAC_MOBILE_SETUP_PLATFORM" in cli;
    mt = (
        _plugin_dir / "src" / "targets" / "impl" / "mobile_target.impl.jac"
    ).read_text();
    assert "MOBILE_SETUP_PLATFORM_ENV" in mt;
    assert "_resolve_mobile_setup_mode" in mt;
}
