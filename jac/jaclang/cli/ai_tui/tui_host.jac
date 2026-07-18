import from jaclang.cli.ai_tui.tui_shared {
    EmbedHostResult,
    _ensure_tui_lib as _shared_ensure_tui_lib
}


obj TuiHost {
    has lib: any = None;

    def load(lib_path: str) {
        import ctypes;
        import os;

        abs_path = os.path.abspath(lib_path);
        self.lib = ctypes.CDLL(abs_path);

        self.lib.tui_init.restype = ctypes.c_int64;
        self.lib.tui_init.argtypes = [
            ctypes.c_char_p,
            ctypes.c_char_p,
            ctypes.c_char_p,
            ctypes.c_char_p
        ];
        self.lib.tui_apply_batch.restype = ctypes.c_int64;
        self.lib.tui_apply_batch.argtypes = [ctypes.c_char_p];
        self.lib.tui_apply_snapshot.restype = ctypes.c_int64;
        self.lib.tui_apply_snapshot.argtypes = [ctypes.c_char_p];
        self.lib.tui_wait_key.restype = ctypes.c_int64;
        self.lib.tui_wait_key.argtypes = [ctypes.c_int64];
        self.lib.tui_handle_key.restype = ctypes.c_int64;
        self.lib.tui_handle_key.argtypes = [];
        self.lib.tui_next_command.restype = ctypes.c_char_p;
        self.lib.tui_next_command.argtypes = [];
        self.lib.tui_quit_requested.restype = ctypes.c_int64;
        self.lib.tui_quit_requested.argtypes = [];
        self.lib.tui_render.restype = ctypes.c_int64;
        self.lib.tui_render.argtypes = [];
        self.lib.tui_shutdown.restype = ctypes.c_int64;
        self.lib.tui_shutdown.argtypes = [];
    }

    def start(project: str, files_env: str, presets_env: str, tty_dev: str) -> int {
        return int(
            self.lib.tui_init(
                project.encode("utf-8"),
                files_env.encode("utf-8"),
                presets_env.encode("utf-8"),
                tty_dev.encode("utf-8")
            )
        );
    }

    def apply_batch(blob: str) -> int {
        return int(self.lib.tui_apply_batch(blob.encode("utf-8")));
    }

    def apply_snapshot(blob: str) -> int {
        return int(self.lib.tui_apply_snapshot(blob.encode("utf-8")));
    }

    def wait_key(timeout_ms: int) -> int {
        return int(self.lib.tui_wait_key(int(timeout_ms)));
    }

    def handle_key -> int {
        return int(self.lib.tui_handle_key());
    }

    def next_command -> str {
        raw = self.lib.tui_next_command();
        if raw is None {
            return "";
        }
        decoded: str = str(raw.decode("utf-8", "replace"));
        return decoded;
    }

    def quit_requested -> int {
        return int(self.lib.tui_quit_requested());
    }

    def render -> int {
        return int(self.lib.tui_render());
    }

    def shutdown -> int {
        return int(self.lib.tui_shutdown());
    }
}


def _tui_lib_path(cli_root: any) -> str {
    import os;
    import sys;

    name: str = "libtui.so";
    if sys.platform == "darwin" {
        name = "libtui.dylib";
    } elif sys.platform == "win32" {
        name = "tui.dll";
    }
    return os.path.join(str(cli_root), "ai_tui_na", "bin", name);
}


def _ensure_tui_lib(cli_root: any, force: bool = False) -> EmbedHostResult {
    return _shared_ensure_tui_lib(cli_root, force=force);
}
