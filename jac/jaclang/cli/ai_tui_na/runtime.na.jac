# Host runtime bundle. Tui owns screen/frame/terminal; embed/session bound at startup.

import from .state { TuiState }
import from .transport { EmbedPyTransport, CmdQueue }
import from .tui { Tui }
import from .embed_session_client { EmbedSessionClient }
import from .embed_runtime { EmbedRuntime }

obj TuiRuntime {
    has state: TuiState = TuiState(),
        tui: Tui = Tui(),
        session: EmbedSessionClient | None = None,
        embed: EmbedRuntime | None = None,
        transport: EmbedPyTransport = EmbedPyTransport(),
        cmd_queue: CmdQueue = CmdQueue();
}
