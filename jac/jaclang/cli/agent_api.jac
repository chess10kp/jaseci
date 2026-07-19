import os;
import from jaclang.cli.console { console }
import from jaclang.compiler.code_intel { CodeIntelligence }


obj AgentRequest {
    has prompt: str = "",
        model: str = "",
        n_ctx: int = 0,
        safe: bool = False,
        quiet: bool = False,
        ui: bool = False,
        tui: bool = False,
        rebuild_tui: bool = False,
        stub: bool = False,
        no_stub: bool = False,
        cwd: str = "",
        code_intel: CodeIntelligence | None = None;
}


def _argv_has_no_stub -> bool {
    import sys;

    for arg in sys.argv {
        if arg == "--no-stub" {
            return True;
        }
    }
    return False;
}


def build_agent_request(
    prompt: str = "",
    model: str = "",
    n_ctx: int = 0,
    safe: bool = False,
    quiet: bool = False,
    ui: bool = False,
    tui: bool = False,
    rebuild_tui: bool = False,
    stub: bool = False
) -> AgentRequest {
    cwd = os.getcwd();
    no_stub = _argv_has_no_stub();
    return AgentRequest(
        prompt=prompt,
        model=model,
        n_ctx=n_ctx,
        safe=safe,
        quiet=quiet,
        ui=ui,
        tui=tui,
        rebuild_tui=rebuild_tui,
        stub=stub,
        no_stub=no_stub,
        cwd=cwd,
        code_intel=CodeIntelligence(proj_dir=cwd, lazy=True)
    );
}


def validate_agent_request(req: AgentRequest) -> int {
    if req.ui and req.tui {
        console.error("`jac ai`: `--ui` and `--tui` are mutually exclusive.");
        return 1;
    }
    if req.stub and req.no_stub {
        console.error("`jac ai`: `--stub` and `--no-stub` are mutually exclusive.");
        return 1;
    }
    return 0;
}
