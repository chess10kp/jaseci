import json;
import subprocess;
import tempfile;
import tomllib;
import from pathlib { Path }
import from tests.support { TESTS_DIR }
import from jaclang.client.bun_installer { get_bun }
import from jaclang.compiler.driver.program { JacProgram }
import from jaclang.compiler.driver.compile_options { CompileOptions }
import from jaclang.project.config { JacConfig, get_config, set_config }

test "site theme persists in memory when browser storage is unavailable" {
    site = Path(TESTS_DIR).parent / "examples" / "jaclang_org";
    previous = get_config();
    try {
        set_config(JacConfig.discover(start_path=site));
        program = JacProgram();
        module = program.compile(
            str(site / "core" / "brand" / "theme.jac"),
            options=CompileOptions(force_target_program=True)
        );
        assert not program.errors_had , str(program.errors_had);
        js = module.gen.js;
    } finally {
        set_config(previous);
    }
    config = tomllib.loads((site / "jac.toml").read_text());
    bootstrap = config["client"]["app_meta_data"]["scripts"][0]["content"];
    runtime = get_bun();
    assert runtime is not None;
    harness = Path(TESTS_DIR)
        / "compiler"
        / "backends"
        / "es"
        / "fixtures"
        / "site_theme_harness.mjs";
    with tempfile.TemporaryDirectory() as tmp {
        target = Path(tmp);
        (target / "theme.json").write_text(
            json.dumps({"module": js, "bootstrap": bootstrap})
        );
        (target / "run.mjs").write_text(harness.read_text());
        result = subprocess.run(
            [runtime, str(target / "run.mjs")],
            capture_output=True,
            text=True,
            timeout=30
        );
        assert result.returncode == 0 , result.stderr;
        assert result.stdout.strip() == "site theme checks passed";
    }
}
