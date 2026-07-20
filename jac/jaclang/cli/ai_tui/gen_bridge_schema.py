#!/usr/bin/env python3
"""Generate bridge_schema.jac and bridge_schema.na.jac from bridge_schema.manifest.json."""

from __future__ import annotations

import json
from pathlib import Path

HERE = Path(__file__).resolve().parent
MANIFEST = HERE / "bridge_schema.manifest.json"
MANAGED_OUT = HERE / "bridge_schema.jac"
NATIVE_OUT = HERE.parent / "ai_tui_na" / "bridge_schema.na.jac"
MANAGED_HELPERS = HERE / "bridge_schema.helpers.jac.tpl"
NATIVE_HELPERS = HERE / "bridge_schema.helpers.na.jac.tpl"

NATIVE_DOC = '''"""Native mirror of the dual-code-space bridge contract (PLAN.md §5.3).

Complete owned JSON strings per embed call. Array construction uses list[any]
+ .append(). Never use str()/int()/bool() on decoded `any` values — native IR
returns the value's tag; use as_str()/as_int()/as_bool() instead.
"""

'''


def _glob_block(section: dict[str, str]) -> str:
    names = list(section.keys())
    if not names:
        return ""
    lines: list[str] = []
    for i, name in enumerate(names):
        value = section[name]
        suffix = "," if i < len(names) - 1 else ";"
        if i == 0:
            lines.append(f'glob {name}: str = "{value}"{suffix}')
        else:
            lines.append(f'     {name}: str = "{value}"{suffix}')
    return "\n".join(lines)


def _render_managed(manifest: dict) -> str:
    parts = [
        "import json;",
        "",
        f'glob SCHEMA_ID: str = "{manifest["schema_id"]}";',
        "",
        _glob_block(manifest["cmd_kinds"]),
        "",
        _glob_block(manifest["dispositions"]),
        "",
        _glob_block(manifest["lifecycles"]),
        "",
        _glob_block(manifest["mutations"]),
    ]
    body = "\n".join(parts) + "\n\n\n" + MANAGED_HELPERS.read_text().lstrip("\n")
    if not body.endswith("\n"):
        body += "\n"
    return body


def _render_native(manifest: dict) -> str:
    parts = [
        NATIVE_DOC.rstrip(),
        "import json;",
        "",
        f'glob SCHEMA_ID: str = "{manifest["schema_id"]}";',
        "",
        _glob_block(manifest["cmd_kinds"]),
        "",
        _glob_block(manifest["dispositions"]),
        "",
        _glob_block(manifest["lifecycles"]),
        "",
        _glob_block(manifest["mutations"]),
    ]
    body = "\n".join(parts) + "\n\n" + NATIVE_HELPERS.read_text().lstrip("\n")
    if not body.endswith("\n"):
        body += "\n"
    return body


def main() -> None:
    manifest = json.loads(MANIFEST.read_text(encoding="utf-8"))
    managed = _render_managed(manifest)
    native = _render_native(manifest)
    MANAGED_OUT.write_text(managed, encoding="utf-8")
    NATIVE_OUT.write_text(native, encoding="utf-8")


if __name__ == "__main__":
    main()
