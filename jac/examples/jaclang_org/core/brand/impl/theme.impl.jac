impl useTheme -> Theme {
    has dark: bool = current_dark;
    def changed(value: bool) {
        dark = value;
    }
    can with entry {
        listeners.append(changed);
        return lambda { listeners = [
            listener
            for listener in listeners
            if listener != changed
        ]; };
    }
    def toggle {
        value = not current_dark;
        current_dark = value;
        try {
            __setLocalStorage("jac-theme", "dark" if value else "light");
        } except Exception {}
        for listener in listeners {
            listener(value);
        }
    }
    return Theme(
        dark=dark, colors=dark_palette() if dark else light_palette(), toggle=toggle
    );
}
