"""Fixture for W3038 auto-fix: useState hook to has declaration (Multiple useState hooks)."""

def:pub Counter -> JsxElement {
    has count: int = 0,
        label: str = "hello";

    def handleClick(e: any) {
        count = count + 1;
        label = "clicked";
    }

    return (
        <div>
            <p>{label}: {count}</p>
            <button onClick={handleClick}>Click</button>
        </div>
    );
}
