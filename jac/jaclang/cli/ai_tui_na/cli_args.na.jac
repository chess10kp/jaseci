"""Native argv parsing for the embed TUI host.

`sys.argv` is the supported native-stdlib way to read the process command line
(jac://guide/jac-native: `sys` provides `argv`/`exit`/...). All launch
configuration travels as flags — no JAC_AI_UI_* env vars.

Keep this module free of CPython/embed imports: it runs before any agent start,
and the renderer links it statically. See PLAN.md §5.4.
"""

import sys;
import os;

import from .util { parse_int_or }


glob g_tty_path: str = "";


def set_tty_path(path: str) {
    g_tty_path = path;
}


def get_tty_path -> str {
    return g_tty_path;
}


# stub_mode tri-state: -1 = not given on argv, 1 = --stub, 0 = --no-stub.
obj CliArgs {
    has model: str = "",
        stub_mode: int = -1,
        cwd: str = "",
        project: str = "",
        n_ctx: int = 0,
        byllm_src: str = "",
        byllm_deps: str = "",
        debug_log: str = "",
        tty: str = "",
        show_help: bool = False,
        bad: str = "";

    def want_stub -> bool {
        if self.stub_mode == 1 { return True; }
        if self.stub_mode == 0 { return False; }
        return False;
    }
}


def parse_argv(argv: list[str]) -> CliArgs {
    # Pure function over the given argv (default sys.argv). Returns a CliArgs
    # with `bad` set to the first unknown / missing-value token ("" = ok).
    args = CliArgs();
    i: int = 1;                 # argv[0] is the binary name
    n = len(argv);
    while i < n {
        a = argv[i];

        if a == "-h" or a == "--help" {
            args.show_help = True;
            i += 1;
            continue;
        }
        if a == "--stub" {
            args.stub_mode = 1;
            i += 1;
            continue;
        }
        if a == "--no-stub" {
            args.stub_mode = 0;
            i += 1;
            continue;
        }

        # value-taking flags: separated form "--flag value"
        if a == "-m" or a == "--model" {
            if i + 1 < n {
                args.model = argv[i + 1];
                i += 2;
                continue;
            }
            args.bad = a;
            return args;
        }
        if a == "--cwd" {
            if i + 1 < n {
                args.cwd = argv[i + 1];
                i += 2;
                continue;
            }
            args.bad = a;
            return args;
        }
        if a == "--project" {
            if i + 1 < n {
                args.project = argv[i + 1];
                i += 2;
                continue;
            }
            args.bad = a;
            return args;
        }
        if a == "--n-ctx" {
            if i + 1 < n {
                args.n_ctx = parse_int_or(argv[i + 1], 0);
                i += 2;
                continue;
            }
            args.bad = a;
            return args;
        }
        if a == "--byllm-src" {
            if i + 1 < n {
                args.byllm_src = argv[i + 1];
                i += 2;
                continue;
            }
            args.bad = a;
            return args;
        }
        if a == "--byllm-deps" {
            if i + 1 < n {
                args.byllm_deps = argv[i + 1];
                i += 2;
                continue;
            }
            args.bad = a;
            return args;
        }
        if a == "--debug-log" {
            if i + 1 < n {
                args.debug_log = argv[i + 1];
                i += 2;
                continue;
            }
            args.bad = a;
            return args;
        }
        if a == "--tty" {
            if i + 1 < n {
                args.tty = argv[i + 1];
                i += 2;
                continue;
            }
            args.bad = a;
            return args;
        }

        # attached form "--flag=value" (and the -m=... convenience)
        if a.startswith("--model=") {
            args.model = a[8:];
            i += 1;
            continue;
        }
        if a.startswith("-m=") {
            args.model = a[3:];
            i += 1;
            continue;
        }
        if a.startswith("--cwd=") {
            args.cwd = a[6:];
            i += 1;
            continue;
        }
        if a.startswith("--project=") {
            args.project = a[10:];
            i += 1;
            continue;
        }
        if a.startswith("--n-ctx=") {
            args.n_ctx = parse_int_or(a[8:], 0);
            i += 1;
            continue;
        }
        if a.startswith("--byllm-src=") {
            args.byllm_src = a[12:];
            i += 1;
            continue;
        }
        if a.startswith("--byllm-deps=") {
            args.byllm_deps = a[13:];
            i += 1;
            continue;
        }
        if a.startswith("--debug-log=") {
            args.debug_log = a[12:];
            i += 1;
            continue;
        }
        if a.startswith("--tty=") {
            args.tty = a[6:];
            i += 1;
            continue;
        }

        args.bad = a;
        return args;
    }
    return args;
}


def _usage_line(bin_name: str) -> str {
    return (
        "Usage: "
        + bin_name
        + " [-m <model>] [--project <dir>] [--n-ctx <n>]"
        + " [--byllm-src <dir>] [--byllm-deps <paths>] [--debug-log <path>] [--tty <dev>]"
        + " [--stub|--no-stub] [--cwd <dir>] [-h]"
    );
}


# `print(some_list)` emits garbage in native, so print scalars one line at a time.
def print_help(bin_name: str) {
    print(_usage_line(bin_name));
    print("");
    print("Options:");
    print("  -m, --model <name>    Model to use (e.g. openai/gpt-4o, local:gemma-4-e2b)");
    print("  --project <path>      Project root for @file autocomplete (default: cwd)");
    print("  --n-ctx <n>           Context window size for local models");
    print("  --byllm-src <dir>     byLLM checkout for the real agent");
    print("  --byllm-deps <paths>  Extra dep dirs (pathsep-separated)");
    print("  --debug-log <path>    Redacted debug sink (default: off)");
    print("  --tty <dev>           TTY device (default: /dev/tty)");
    print("  --stub                Force the stub agent (no real LLM)");
    print("  --no-stub             Force the real agent (fail instead of stub fallback)");
    print("  --cwd <path>          Working directory (default: $PWD)");
    print("  -h, --help            Show this help and exit");
}


def print_error(bin_name: str, bad: str) {
    # bad holds either the unknown token or the flag missing its value.
    print(_usage_line(bin_name));
    print("error: bad or incomplete argument: " + bad);
    print("       see `" + bin_name + " --help`");
}
