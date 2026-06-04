"""Web (React DOM) entry-script generator.

Registers jac-client's plugin-owned web entry generators.

The canonical `"web"` entry body now lives in `jaclang.runtimelib.react_entry`
and is owned by core. jac-client only contributes plugin-specific generators
such as `"web:error_overlay"`.
"""

import from jaclang.runtimelib.entry_generators { register_entry_generator }

"""Build the error-overlay entry script HMR writes when a `.cl.jac` file
fails to compile. Renders `errorOverlay(file_path, errors)` at the same
`#root` mount point so the developer sees the failure inline instead of a
stale page.
"""
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

"""Register jac-client's plugin-owned web entry generators."""
def register_web_entry_generators {
    register_entry_generator("web:error_overlay", build_web_error_overlay_entry_script);
}
