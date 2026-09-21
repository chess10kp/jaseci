"""Test fixture for has statement combining inside abilities (functions)."""

# has statements inside a function should be combined
def app -> any {
    has count: int = 0,
        name: str = "test",
        enabled: bool = True;

    # Do something
    count = count + 1;

    return count;
}

# has statements in client-side function (typically in .jac files)

def:pub counter -> JsxElement {
    has value: int = 0,
        label: str = "Counter",
        visible: bool = True;

    return <div>{label}: {value}</div>;
}


# Method with has statements should also combine
obj Widget {
    has id: str;

    def render -> str {
        has prefix: str = "<",
            suffix: str = ">",
            content: str = "";

        return prefix + content + suffix;
    }
}
