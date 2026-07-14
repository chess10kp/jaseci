"""{{name}} - Entry Point.

Combines server-side endpoints with the client-side UI.
"""

import from endpoints { Message }

# Client-side UI
cl {
    import from .frontend { app as ClientApp }

    def:pub app -> JsxElement {
        return <ClientApp/>;
    }
}
