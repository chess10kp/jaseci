"""Fixture for W3042 auto-fix: map(lambda -> JSX) to list comprehension.

Covers both the convertible single-param case (HourGrid) and a multi-param
lambda that must be left alone (MultiParamMap), since list comprehensions
only bind a single iteration variable per `for` clause.
"""

def:pub HourGrid(hours: list[any], items: list[any]) -> JsxElement {
    hourLabels = [<div className="text-xs text-center">{hour}</div> for hour in hours];

    return (
        <div>
            <div className="hour-grid">{hourLabels}</div>
            <ul>{itemRows}</ul>
        </div>
    );
}

def:pub MultiParamMap(items: list[any]) -> JsxElement {
    rendered = items.map(lambda (a: any, b: any) -> any { return <li>{a + b}</li>; });
    return <ul>{rendered}</ul>;
}
