"""Fixture for W3042 auto-fix: filter-map lambda chain to filtered list comprehension."""

def:pub ActiveItems(items: list[any]) -> JsxElement {
    activeRows = [
        <li className="active">{item.name}</li>
        for item in items
        if item.active
    ];
    return <ul>{activeRows}</ul>;
}
