# Host runtime bundle. Screen/Diff stay for paint path; embed/session are bound by
# host_embed.na.jac at startup (host_dlopen.na.jac leaves them None).

import from .state { TuiState }
import from .diff { DiffEngine, PaintBuf }
import from .transport { EmbedPyTransport, CmdQueue }
import from .screen { Screen }
import from .tui { Tui }

obj TuiRuntime {
    has state: TuiState = TuiState(),
        diff: DiffEngine = DiffEngine(),
        transport: EmbedPyTransport = EmbedPyTransport(),
        cmd_queue: CmdQueue = CmdQueue(),
        paint_buf: PaintBuf = PaintBuf(),
        screen: Screen = Screen(),
        tui: Tui = Tui(),
        session: any = None,
        embed: any = None;
}
