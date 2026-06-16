"""Pluggable client-app entry-script generators.

Core machinery (HMR, eject, the shared client compiler step) needs to write
an `_entry.js` that mounts the compiled `app` export. The exact body of that
script is target-specific: web uses `react-dom/client` + `createRoot`, while
React Native uses `AppRegistry.registerComponent`. Core stays target-neutral
by looking generators up by name; concrete generators ship with the active
jac-client plugin and register themselves at plugin load.

Core ships fallback built-in web generators so eject/HMR keep working even
when jac-client is not installed (for example in core-runtime CI). When
jac-client is available, first lookup lazy-imports its canonical web generator
module and registers those implementations instead. When jac-client loads, it
re-registers the same targets at plugin bootstrap.

To avoid a hard runtime dependency on jac-client, this file also carries a
small fallback copy of the canonical web bootstrap strings.
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

"""Core fallback for the standard web entry bootstrap."""
def _build_simple_react_entry_script(
    entry_module: str, install_global_handlers: bool = True
) -> str {
    runtime_imports: list[str] = ['JacClientErrorBoundary', 'ErrorFallback'];
    if install_global_handlers {
        runtime_imports.append('__jacInstallErrorHandlers');
    }
    runtime_imports.append('__jacReactErrorHandler');

    lines: list[str] = [
        'import React from "react";',
        'import { createRoot } from "react-dom/client";',
        f'import {{ app as App }} from "./{entry_module}.js";',
        f'import {{ {", ".join(runtime_imports)} }} from "@jac/runtime";',
        ''
    ];
    if install_global_handlers {
        lines.append('__jacInstallErrorHandlers();');
    }
    lines.extend(
        [
            'const root = createRoot(document.getElementById("root"));',
            'root.render(',
            '\tReact.createElement(',
            '\t\tJacClientErrorBoundary,',
            '\t\t{ FallbackComponent: ErrorFallback, onError: __jacReactErrorHandler },',
            '\t\tReact.createElement(App, null)',
            '\t)',
            ');',
            ''
        ]
    );
    return "\n".join(lines);
}

"""Core fallback for the web HMR error-overlay entry bootstrap."""
def _build_web_error_overlay_entry_script(file_path: str, errors: str) -> str {
    return (
        'import React from "react";\n'
        'import { createRoot } from "react-dom/client";\n'
        'import { errorOverlay } from "@jac/runtime";\n'
        '\n'
        'const root = createRoot(document.getElementById("root"));\n'
        f'root.render(errorOverlay("{file_path} ", ` {errors}`), null);\n'
    );
}

"""Ensure the built-in web generator is registered."""
def _ensure_builtin_web {
    if "web" not in _generators {
        try {
            import from jac_client.plugin.src.entry_generators.web_entry {
                build_simple_react_entry_script
            }
            register_entry_generator("web", build_simple_react_entry_script);
        } except ImportError {
            register_entry_generator("web", _build_simple_react_entry_script);
        }
    }
}

"""Ensure the built-in web error-overlay generator is registered."""
def _ensure_builtin_web_error_overlay {
    if "web:error_overlay" not in _generators {
        try {
            import from jac_client.plugin.src.entry_generators.web_entry {
                build_web_error_overlay_entry_script
            }
            register_entry_generator(
                "web:error_overlay", build_web_error_overlay_entry_script
            );
        } except ImportError {
            register_entry_generator(
                "web:error_overlay", _build_web_error_overlay_entry_script
            );
        }
    }
}
