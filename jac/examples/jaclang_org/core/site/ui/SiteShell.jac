import from "@jac/runtime" { Outlet, useLocation }
import from core.brand.theme { useTheme }
import from core.site.ui.Navbar { Navbar }
import from core.site.ui.Footer { Footer }

def:pub SiteShell -> JsxElement {
    theme = useTheme();
    dark = theme.dark;
    can with [dark] entry {
        document.documentElement.classList.toggle("dark", dark);
        document.documentElement.style.removeProperty("color-scheme");
        document.documentElement.style.removeProperty("background-color");
    }
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
