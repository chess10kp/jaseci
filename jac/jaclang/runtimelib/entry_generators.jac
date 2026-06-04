"""Pluggable client-app entry-script generators.

Core machinery (HMR, eject, the shared client compiler step) needs to write
an `_entry.js` that mounts the compiled `app` export. The exact body of that
script is target-specific: web uses `react-dom/client` + `createRoot`, while
React Native uses `AppRegistry.registerComponent`. Core stays target-neutral
by looking generators up by name; concrete generators ship with the active
jac-client plugin and register themselves at plugin load.

When jac-client is installed, built-in web generators lazy-register from
``jac_client.plugin.src.entry_generators.web_entry`` on first lookup so core
features (eject, HMR) work. When jac-client loads, it re-registers the same
implementations at plugin bootstrap.

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
The built-in "web" and "web:error_overlay" generators lazy-register from
jac-client when available; other targets (e.g. "react-native") require the
jac-client plugin.
"""
def get_entry_generator(target: str = "web") -> EntryGenerator {
    if target == "web" {
        _ensure_builtin_web();
    } elif target == "web:error_overlay" {
        _ensure_builtin_web_error_overlay();
    }
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

"""Ensure the built-in web generator is registered from jac-client."""
def _ensure_builtin_web {
    if "web" not in _generators {
        import from jac_client.plugin.src.entry_generators.web_entry {
            build_simple_react_entry_script
        }
        register_entry_generator("web", build_simple_react_entry_script);
    }
}

"""Ensure the built-in web error-overlay generator is registered from jac-client."""
def _ensure_builtin_web_error_overlay {
    if "web:error_overlay" not in _generators {
        import from jac_client.plugin.src.entry_generators.web_entry {
            build_web_error_overlay_entry_script
        }
        register_entry_generator(
            "web:error_overlay", build_web_error_overlay_entry_script
        );
    }
}
