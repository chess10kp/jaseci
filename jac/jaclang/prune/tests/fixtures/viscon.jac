"""Consumer module: makes a real cross-module call into `vislib.jac`.

`exported_used` is imported and called here -- a genuine cross-module use. That
this use is recorded against the local import alias (not the declaring symbol in
vislib) is the extraction gap the real-source visibility test characterizes.
"""

import from vislib { exported_used }


def run() -> int {
    return exported_used(5);
}
