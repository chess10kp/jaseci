import from .libc_tty { tty_write, tty_poll, tty_key_ready, tty_read_key }

# Phase 4: CPython/GIL ownership moved to embed_runtime.na.jac. This module is
# tty key I/O + command buffering only. The legacy L:<n> frame re-segmentation
# (split_frames / recv_blob / blob_reader) was removed with the text-frame bridge.


obj CmdQueue {
    has _items: list[str] = [];

    def send(fd: int, cmd: str) {
        if fd < 0 {
            self._items.append(cmd);
            return;
        }
        tty_write(fd, cmd + "\n");
    }

    def drain_all -> list[str] {
        pending: list[str] = self._items;
        self._items = [];
        return pending;
    }

    def clear {
        self._items = [];
    }
}


obj Transport {
    def poll(timeout_ms: int) { }
    def poll_gil(timeout_ms: int) { }

    def key_ready -> bool {
        return False;
    }

    def read_key -> str {
        return "";
    }

    def stdin_eof -> bool {
        return False;
    }

    def backend_dead -> bool {
        return False;
    }
}

obj TtyFdTransport(Transport) {
    has stdin_eof: bool = False;

    def poll(timeout_ms: int) {
        tty_poll(timeout_ms);
    }

    def poll_gil(timeout_ms: int) {
        # Call tty_poll directly — avoid Transport.poll_gil -> self.poll virtual
        # dispatch (segfault on some native builds right after alt-screen enter).
        tty_poll(timeout_ms);
    }

    def key_ready -> bool {
        return tty_key_ready();
    }

    def read_key -> str {
        return tty_read_key();
    }
}

obj EmbedPyTransport(TtyFdTransport) {
    # Concrete TUI transport type (tty keys + poll). Session poll/submit live on
    # EmbedSessionClient; this class no longer holds PyObject* or GIL state.
    has _backend_dead: bool = False;

    def backend_dead -> bool {
        return self._backend_dead;
    }

    def mark_backend_dead {
        self._backend_dead = True;
    }
}
