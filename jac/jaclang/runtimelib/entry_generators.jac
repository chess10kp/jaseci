"""Pluggable client-app entry-script generators.

Core machinery (HMR, eject, the shared client compiler step) needs to write
an `_entry.js` that mounts the compiled `app` export. The exact body of that
script is target-specific: web uses `react-dom/client` + `createRoot`, while
React Native uses `AppRegistry.registerComponent`. Core stays target-neutral
by looking generators up by name; concrete generators ship with the active
jac-client plugin and register themselves at plugin load.

A built-in "web" generator is lazy-registered on first lookup from
`jaclang.runtimelib.react_entry` so core features (eject, HMR) work without
the jac-client plugin installed. When jac-client loads, it overrides the
registration with its own copy — last-write-wins.

This file deliberately contains no React, DOM, or HTML knowledge.
"""

import from typing { TypeAlias }

glob EntryGenerator: TypeAlias = Callable,
     _generators: dict[str, EntryGenerator] = {};

"""Register `fn` as the entry generator for `target` (e.g. 'web', 'native').

Called at plugin load time from `jac-client`. Re-registering the same target
overrides the previous generator; the last registration wins. This matches
the way the target registry behaves and lets tests swap in stubs.
"""
def register_entry_generator(target: str, fn: EntryGenerator) {
    _generators[target] = fn;
}

"""Look up the entry generator for `target`.

Raises `LookupError` with a clear message if no generator is registered.
The built-in "web" generator is always available; other targets (e.g.
"web:error_overlay", "native") require the jac-client plugin.
"""
def get_entry_generator(target: str = "web") -> EntryGenerator {
    _ensure_builtin_web();
    fn = _generators.get(target);
    if fn is None {
        raise LookupError(
            f"No entry generator registered for target '{target}'. "
            "Is the jac-client plugin loaded?"
        );
    }
    return fn;
}

"""Whether a generator is registered for `target`."""
def has_entry_generator(target: str) -> bool {
    return target in _generators;
}

"""Drop all registered generators. Test-only — production code should never
call this. Exposed so the test suite can isolate cases."""
def clear_entry_generators {
    _generators.clear();
}

"""Ensure the built-in web generator is registered.

Lazy-imported from `react_entry` at call time (not at module load) to avoid
circular bootstrap ordering with the Jac meta_importer. jac-client's
`register_entry_generator` call overrides this registration when the plugin
loads. The redundant import on subsequent calls is harmless — Python caches
module imports.
"""
def _ensure_builtin_web {
    if "web" not in _generators {
        import from jaclang.runtimelib.react_entry { build_simple_react_entry_script }
        register_entry_generator("web", build_simple_react_entry_script);
    }
}
