"""Phase 7 tests: offline packaged fused host launch gates."""

import importlib;
import os;
import from pathlib { Path }


def _cli_root -> Path {
    shared_mod = importlib.import_module("jaclang.cli.ai_tui.tui_shared");
    return Path(shared_mod.__file__).resolve().parent;
}


def _na_dir -> Path {
    return _cli_root() / "ai_tui_na";
}


test "phase7 embed host artifact is bootable fused binary" {
    shared_mod = importlib.import_module("jaclang.cli.ai_tui.tui_shared");
    bootable = getattr(shared_mod, "_embed_host_bootable");
    na = _na_dir();
    artifact = na / "bin" / "jac-ai-tui";
    if not artifact.is_file() {
        import pytest;
        pytest.skip(
            "embed host not built (run jac/jaclang/cli/ai_tui_na/build_embed.sh)"
        );
    }
    assert bootable(str(artifact)) , "jac-ai-tui must include fused-runtime trailer payload";
    assert os.access(artifact, os.X_OK);
}


test "phase7 run_tui_embed exposes fused host entrypoint" {
    run_mod = importlib.import_module("jaclang.cli.ai_tui.run_tui_embed");
    assert callable(run_mod?.run_tui_embed);
    assert (_cli_root() / "impl" / "run_tui_embed.impl.jac").is_file();
}


test "phase7 fresh embed host skips compile at launch" {
    import pytest;
    shared_mod = importlib.import_module("jaclang.cli.ai_tui.tui_shared");
    ensure = getattr(shared_mod, "_ensure_embed_host");
    na = _na_dir();
    artifact = na / "bin" / "jac-ai-tui";
    if not artifact.is_file() {
        pytest.skip("embed host not built");
    }
    newest = getattr(shared_mod, "_embed_inputs_newest_mtime")(
        str(na), str(_cli_root().parent)
    );
    stamp_path = na / "bin" / ".embed_build_stamp";
    stamp_path.write_text(str(newest + 1.0));
    try {
        result = ensure(str(_cli_root()), force=False);
        assert result.ok , result.error;
        assert str(result.path) == str(artifact);
    } finally {
        if artifact.is_file() {
            stamp_path.write_text(str(artifact.stat().st_mtime));
        }
    }
}


test "phase7 no production legacy pipe renderer fallback" {
    shared_src = (_cli_root() / "tui_shared.jac").read_text();
    # Structural guard: legacy L:<n>/key:value frame encoder must not return.
    assert "_frame_blob" not in shared_src;
    assert "FIELD_EV:" not in shared_src;
}


test "phase7 packaged host help describes fused host flags" {
    import subprocess;
    na = _na_dir();
    host = na / "bin" / "jac-ai-tui";
    if not host.is_file() {
        import pytest;
        pytest.skip("embed host not built");
    }
    proc = subprocess.run(
        [str(host), "--help"], capture_output=True, text=True, timeout=30,
    );
    out = (proc.stdout or "") + (proc.stderr or "");
    assert proc.returncode == 0;
    assert "--stub" in out;
    assert "model" in out.lower() or "byllm" in out.lower();
}
