import from "@jac/runtime" { Outlet, useLocation }
import from core.site.ui.Navbar { Navbar }
import from core.site.ui.Footer { Footer }

def init_theme {
    dark = localStorage.getItem("jac-theme") != "light";
    document.documentElement.classList.toggle("dark", dark);
    document.documentElement.style.setProperty(
        "color-scheme", "dark" if dark else "light"
    );
    document.documentElement.style.backgroundColor = (
        "oklch(0.145 0 0)" if dark else "oklch(1 0 0)"
    );
}

def:pub SiteShell -> JsxElement {
    init_theme();
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
