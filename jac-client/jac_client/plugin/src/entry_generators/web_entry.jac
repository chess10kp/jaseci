"""Web (React DOM) entry-script generators.

Owns the canonical web entry bodies (R2). Core machinery resolves these via
``entry_generators.get_entry_generator`` — either through lazy bootstrap when
jac-client is importable, or through explicit ``register_web_entry_generators``
at plugin load.
"""

import from jaclang.runtimelib.entry_generators { register_entry_generator }

def build_simple_react_entry_script(
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

"""Build the error-overlay entry script HMR writes when a client file fails to compile."""
def build_web_error_overlay_entry_script(file_path: str, errors: str) -> str {
    return (
        'import React from "react";\n'
        'import { createRoot } from "react-dom/client";\n'
        'import { errorOverlay } from "@jac/runtime";\n'
        '\n'
        'const root = createRoot(document.getElementById("root"));\n'
        f'root.render(errorOverlay("{file_path} ", ` {errors}`), null);\n'
    );
}

"""Register jac-client's web entry generators (canonical when plugin is loaded)."""
def register_web_entry_generators {
    register_entry_generator("web", build_simple_react_entry_script);
    register_entry_generator("web:error_overlay", build_web_error_overlay_entry_script);
}
