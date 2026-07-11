"""Dogfood follow-up: the two unused-import precision vetoes surfaced by the
first prune-campaign against upstream jaclang/cli.

  Bug A — import-for-side-effect (`_side_effect_import`): a bare `import a.b.c;`
          or a from-import of a submodule is imported for registration, not as a
          used name. Removing it passes typecheck but breaks runtime, so it must
          be vetoed out of auto-fix. Single dead stdlib bare imports stay
          auto-fixable.
  Bug B — decl-signature type annotations (`_used_as_type`): a name used only as
          a type (`x: T`, `-> T`, `list[T]`, `T | None`) is missed by the ref
          extractor; scanning for it in a type position vetoes the false auto-fix.

Pure over the helpers (no compilation).
"""

import from jaclang.prune.detectors { _side_effect_import, _used_as_type }


# ---------------------------------------------------------------------------
# Bug A — _side_effect_import
# ---------------------------------------------------------------------------
test "side-effect: a bare dotted package import is a registration side effect" {
    # `import jaclang.scale.plugin;`  -> is_from False, dotted name
    assert _side_effect_import("jaclang.scale.plugin", "", False, set());
}


test "side-effect: a bare single stdlib import stays auto-fixable when dead" {
    # `import sys;`  -> is_from False, no dot, not an in-scope module
    assert not _side_effect_import("sys", "", False, set());
}


test "side-effect: a bare import of an in-scope module is a side effect" {
    assert _side_effect_import("mymod", "", False, {"mymod", "other"});
}


test "side-effect: a from-import of a submodule (leaf in module set) is vetoed" {
    # `import from jaclang.cli.commands { execution }` with commands/execution.jac
    assert _side_effect_import("execution", "", True, {"execution", "cli"});
}


test "side-effect: a from-import of a real symbol is NOT a side effect" {
    # `import from jaclang.cli.command { CommandSpec }` — CommandSpec is no module
    assert not _side_effect_import("CommandSpec", "", True, {"command", "cli"});
}


test "side-effect: resolved_path pointing at a module file is a side effect" {
    assert _side_effect_import(
        "execution", "/proj/cli/commands/execution.jac", True, set()
    );
    assert _side_effect_import("pkg", "/proj/cli/pkg/__init__.jac", True, set());
}


# ---------------------------------------------------------------------------
# Bug B — _used_as_type
# ---------------------------------------------------------------------------
test "type-use: a parameter annotation counts as a use" {
    assert _used_as_type("CommandSpec", "def run(spec: CommandSpec) -> int { }");
}


test "type-use: a return annotation counts as a use" {
    assert _used_as_type("Widget", "def make() -> Widget { }");
}


test "type-use: a generic type argument counts as a use" {
    assert _used_as_type("Arg", "has args: list[Arg] = [];");
    assert _used_as_type("Arg", "def f(xs: dict[str, Arg]) -> None;");
}


test "type-use: a union member counts as a use" {
    assert _used_as_type("Node", "has n: Node | None = None;");
    assert _used_as_type("Node", "def f() -> None | Node;");
}


test "type-use: a name only in a string or comment does NOT count" {
    assert not _used_as_type("CommandSpec", "x = \"CommandSpec is nice\";");
    assert not _used_as_type("CommandSpec", "# CommandSpec used to live here");
}


test "type-use: an absent name does not count" {
    assert not _used_as_type("Ghost", "def run(spec: CommandSpec) -> int { }");
    assert not _used_as_type("", "anything");
}
