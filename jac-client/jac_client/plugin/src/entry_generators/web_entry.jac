"""Web (React DOM) entry-script generator.

Registers jac-client's web-specific entry generators.

The default "web" entry body now lives in
`jaclang.runtimelib.react_entry.build_simple_react_entry_script` so the core
fallback and plugin registration paths stay in lockstep. This module still
owns jac-client-only generators such as `"web:error_overlay"` and
self-registers them at plugin load.
"""

import from jaclang.runtimelib.entry_generators { register_entry_generator }
import from jaclang.runtimelib.react_entry { build_simple_react_entry_script }

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

# Self-register at module load. The plugin's target-registration flow
# imports this module specifically so the side effect runs once per process.
with entry {
    register_entry_generator("web", build_simple_react_entry_script);
    register_entry_generator("web:error_overlay", build_web_error_overlay_entry_script);
}
