import from "@jac/runtime" { Outlet, useLocation }
import from core.site.ui.Navbar { Navbar }
import from core.site.ui.Footer { Footer }

def:pub SiteShell -> JsxElement {
    location = useLocation();
    in_app = (
        location.pathname.startswith("/jacyac")
        or location.pathname.startswith("/socialize")
    );
    return
        <div
            className="min-h-screen overflow-x-clip bg-background text-foreground antialiased"
        >
            <Navbar/>
            <main>
                <Outlet/>
            </main>
            {if not in_app {
                <Footer/>
            }}
        </div>;
}
