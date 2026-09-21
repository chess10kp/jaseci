import from "@jac/runtime" { __getLocalStorage, __setLocalStorage }

glob listeners: list[Callable[[bool], None]] = [];
glob current_dark: bool = read_dark();

def read_dark -> bool {
    try {
        return __getLocalStorage("jac-theme") != "light";
    } except Exception {
        return True;
    }
}

obj Theme {
    has dark: bool,
        colors: Colors,
        toggle: Callable[[], None];
}

def:pub useTheme -> Theme;
