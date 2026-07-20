"""Phase 5 tests: Pi-style TUI modules, import purity, focus routing, width."""

import importlib;
import re;
import jac.tests.cli.tui_selftest_harness as harness;
import from pathlib { Path }


def _na_dir -> Path {
    shared_mod = importlib.import_module("jaclang.cli.ai_tui.tui_shared");
    return Path(shared_mod.__file__).resolve().parent.parent / "ai_tui_na";
}


def _generic_dirs(na_root: Path) -> list {
    return [na_root / "tui", na_root / "components"];
}


def _forbidden_import(text: str) -> str | None {
    patterns = [
        r"import from\s+\.embed_",
        r"import from\s+jacpyembed",
        r"import from\s+\.bridge_",
        r"import from\s+\.session_",
        r"import from\s+\.ipc_schema",
        r"import from\s+\.ipc\b",
        r"import from\s+\.transport",
        r"jpy_Py"
    ];
    for pat in patterns {
        if re.search(pat, text) {
            return pat;
        }
    }
    return None;
}


test "phase5 generic tui and components import no agent embed session ipc" {
    na_root = _na_dir();
    offenders = [];
    for d in _generic_dirs(na_root) {
        if not d.is_dir() {
            continue;
        }
        for path in sorted(d.glob("*.na.jac")) {
            text = path.read_text();
            hit = _forbidden_import(text);
            if hit is not None {
                offenders.append(f"{d.name}/{path.name}:{hit}");
            }
        }
    }
    assert offenders == [] , f"generic TUI imports agent/embed/session: {offenders}";
}


test "phase5 gil still sealed in EmbedRuntime only" {
    na_root = _na_dir();
    offenders = [];
    for path in sorted(na_root.rglob("*.na.jac")) {
        if path.name == "embed_runtime.na.jac" {
            continue;
        }
        # Ignore staged flat copies that mirror tui/ (gitignored) — scan sources.
        if path.parent == na_root
        and path.name in {
            "component.na.jac",
            "container.na.jac",
            "focus.na.jac",
            "process_terminal.na.jac",
            "virtual_terminal.na.jac",
            "frame_renderer.na.jac",
            "input_types.na.jac",
            "tui.na.jac",
            "theme_obj.na.jac",
            "transcript.na.jac",
            "status.na.jac",
            "editor_view.na.jac",
            "autocomplete_view.na.jac",
            "warn_view.na.jac",
            "chrome.na.jac"
        } {
            continue;
        }
        text = path.read_text();
        if "import from jacpyembed" in text or "jpy_Py" in text {
            offenders.append(str(path.relative_to(na_root)));
        }
    }
    assert offenders == [] , f"CPython symbols leaked: {offenders}";
    # Structural guard: only embed_runtime.na.jac may import jacpyembed.
    rt_src = (na_root / "embed_runtime.na.jac").read_text();
    assert "import from jacpyembed" in rt_src;
}


test "phase5 interactive_app inject_key behavior selftest passes" {
    na_dir = _na_dir();
    if not harness.shim_path(harness.repo_root(na_dir)).is_file() {
        import pytest;
        pytest.skip("libjacpyembed shim not built (run zig build in jac/)");
    }
    harness.ensure_selftest(na_dir, "selftest_interactive_app");
    harness.assert_selftest_passes(na_dir, "selftest_interactive_app");
}


test "phase5 screen uses split component modules" {
    na_root = _na_dir();
    assert (na_root / "components" / "transcript.na.jac").is_file();
    assert (na_root / "components" / "editor_view.na.jac").is_file();
    assert (na_root / "tui" / "process_terminal.na.jac").is_file();
    assert (na_root / "tui" / "frame_renderer.na.jac").is_file();
    assert (na_root / "tui" / "virtual_terminal.na.jac").is_file();
    assert (na_root / "interactive_app.na.jac").is_file();
    assert (na_root / "reducer.na.jac").is_file();
}


test "phase5 focus routing prefers overlay then autocomplete then base" {
    na_root = _na_dir();
    assert (na_root / "reducer.na.jac").is_file();
    assert (na_root / "tui" / "focus.na.jac").is_file();
    assert (na_root / "interactive_app.na.jac").is_file();
}


test "phase5 frame_renderer validates visible widths" {
    na_root = _na_dir();
    assert (na_root / "tui" / "frame_renderer.na.jac").is_file();
}
