"""Blob fixture module B for the duplicated-constant-blobs cross-module detector."""


def query_b() -> str {
    return 'SELECT id, module_path, name, kind, access FROM symbols WHERE module_path = ? ORDER BY id';
}


def tiny_b() -> str {
    return "ok";
}
