"""Blob fixture module A for the duplicated-constant-blobs cross-module detector."""


def query_a() -> str {
    return "SELECT id, module_path, name, kind, access FROM symbols WHERE module_path = ? ORDER BY id";
}


def unique_a() -> str {
    return "a single unique payload string that shows up exactly one time across the whole fixture pair";
}
