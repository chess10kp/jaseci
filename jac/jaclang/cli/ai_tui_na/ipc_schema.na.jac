# Command + receipt vocabulary shared across the native command-dispatch path.
# The legacy L:<n> / EV / EVA frame-field schema (FIELD_*, FTYPE_*, FRAME_SEP)
# was removed with the text-frame bridge (PLAN.md Phase 4); only the live
# command verbs and receipt strings remain, mirroring ai_tui/ipc_schema.jac.

glob CMD_SEND: str = "SEND",
     CMD_STOP: str = "STOP",
     CMD_RESET: str = "RESET",
     CMD_QUIT: str = "QUIT",
     CMD_APPLY: str = "APPLY",
     RECEIPT_ACCEPTED: str = "ACCEPTED",
     RECEIPT_REJECTED_BUSY: str = "REJECTED:busy",
     RECEIPT_REJECTED_EMPTY: str = "REJECTED:empty",
     RECEIPT_REJECTED_ERROR: str = "REJECTED:error",
     RECEIPT_OK: str = "OK";
