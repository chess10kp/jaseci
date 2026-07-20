"""Drift detector: bridge_schema.jac constants must match bridge_schema.manifest.json."""

import importlib;
import json;
import os;


def _manifest_path -> str {
    here = os.path.dirname(os.path.abspath(__file__));
    cli_dir = os.path.abspath(os.path.join(here, "..", "..", "jaclang", "cli"));
    return os.path.join(cli_dir, "ai_tui", "bridge_schema.manifest.json");
}


def _load_manifest -> dict {
    return json.loads(open(_manifest_path()).read());
}


def _assert_section_matches(bridge: any, manifest: dict, section: str) -> list[str] {
    mismatches: list[str] = [];
    body = manifest.get(section, {});
    if not isinstance(body, dict) {
        mismatches.append(f"{section}: not a dict");
        return mismatches;
    }
    for name in body.keys() {
        value = body[name];
        if not hasattr(bridge, name) {
            mismatches.append(f"missing {name}");
            continue;
        }
        got = getattr(bridge, name);
        if str(got) != str(value) {
            mismatches.append(f"{name}: {got!r} != {value!r}");
        }
    }
    return mismatches;
}


test "managed bridge_schema constants match manifest" {
    manifest = _load_manifest();
    bridge = importlib.import_module("jaclang.cli.ai_tui.bridge_schema");
    assert str(bridge.SCHEMA_ID) == str(manifest.get("schema_id", ""));
    mismatches: list[str] = [];
    for section in ("cmd_kinds", "dispositions", "lifecycles", "mutations") {
        for msg in _assert_section_matches(bridge, manifest, section) {
            mismatches.append(msg);
        }
    }
    assert not mismatches , f"bridge_schema drift: {mismatches}";
}


test "native bridge_schema.na.jac defines every manifest wire value" {
    manifest = _load_manifest();
    here = os.path.dirname(os.path.abspath(__file__));
    cli_dir = os.path.abspath(os.path.join(here, "..", "..", "jaclang", "cli"));
    na_src = open(os.path.join(cli_dir, "ai_tui_na", "bridge_schema.na.jac")).read();
    missing: list[str] = [];
    for section in ("cmd_kinds", "dispositions", "lifecycles", "mutations") {
        body = manifest.get(section, {});
        if not isinstance(body, dict) {
            continue;
        }
        for value in body.values() {
            wire = str(value);
            if ('"' + wire + '"') not in na_src {
                missing.append(wire);
            }
        }
    }
    assert not missing , f"native bridge_schema missing manifest wire values: {missing}";
}
