impl _uri_of(path: str) -> str {
    return uris.from_fs_path(path) or "";
}

impl _path_of(uri: str) -> str {
    return uris.to_fs_path(uri) or "";
}

impl _merge_app_alerts(
    collected: list[tuple[str, list[Alert], list[Alert]]], app_count: int
) -> tuple[list[Alert], list[Alert]] {
    def key_of(alert: any) -> tuple[str, int, int, str, str] {
        code = alert.code.code if alert.code else '';
        return (
            alert.loc.mod_path,
            alert.loc.first_line,
            alert.loc.col_start,
            code,
            alert.msg
        );
    }

    def merge(index: int) -> list[Alert] {
        seen_apps: dict[tuple[str, int, int, str, str], set[str]] = {};
        first: dict[tuple[str, int, int, str, str], any] = {};
        order: list[tuple[str, int, int, str, str]] = [];
        tagged: list[tuple[str, any]] = [];
        for entry_item in collected {
            app_name = entry_item[0];
            for alert in entry_item[index] {
                key = key_of(alert);
                if key not in seen_apps {
                    seen_apps[key] = set();
                    first[key] = alert;
                    order.append(key);
                }
                seen_apps[key].add(app_name);
                tagged.append((app_name, alert));
            }
        }
        shared = {
            key
            for key in order
            if len(seen_apps[key]) >= app_count
        };
        out: list[Alert] = [];
        emitted: set[tuple[str, int, int, str, str]] = set();
        for (app_name, alert) in tagged {
            key = key_of(alert);
            if key in shared {
                if key not in emitted {
                    emitted.add(key);
                    out.append(first[key]);
                }
                continue;
            }
            alert.msg = f"[app:{app_name}] {alert.msg}";
            out.append(alert);
        }
        return out;
    }

    return (merge(1), merge(2));
}

impl JacLangServer.log_py(message: str) -> None {
    logging.info(message);
}

impl JacLangServer.log_info(message: str) -> None {
    self.show_message_log(message, lspt.MessageType.Info);
    self.show_message(message, lspt.MessageType.Info);
}

impl JacLangServer.log_warning(message: str) -> None {
    self.show_message_log(message, lspt.MessageType.Warning);
    self.show_message(message, lspt.MessageType.Warning);
}

impl JacLangServer.log_error(message: str) -> None {
    self.show_message_log(message, lspt.MessageType.Error);
    self.show_message(message, lspt.MessageType.Error);
}

impl JacLangServer.format_document(
    file_path: str, auto_lint: bool = False
) -> list[lspt.TextEdit] {
    document = self.workspace.get_text_document(file_path);
    try {
        prog = JacProgram.jac_str_formatter(
            source_str=document.source, file_path=document.path, auto_lint=auto_lint
        );
        formatted_text = prog.mod.main.gen.jac
            if not prog.errors_had
            else document.source;
    } except Exception as e {
        self.log_error(
            f"Error during {'lintfix ' if auto_lint else ''}formatting: {e}"
        );
        formatted_text = document.source;
    }
    return [
        lspt.TextEdit(
            range=lspt.Range(
                start=lspt.Position(line=0, character=0),
                end=lspt.Position(
                    line=(len(document.source.splitlines()) + 1), character=0
                )
            ),
            new_text=formatted_text
        )
    ];
}

impl JacLangServer.debug(msg: str) -> None {
    console.error(f"[Engine] {msg}");
}
