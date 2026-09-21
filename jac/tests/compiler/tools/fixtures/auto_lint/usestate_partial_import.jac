"""Fixture for W3038: useState is NOT the only import — partial removal, comma edge cases."""

import from "react" { JsxElement, useEffect }

def:pub NameInput -> JsxElement {
    has name: str = "";

    def handleChange(e: any) {
        name = str(e.target.value);
    }

    return (
        <div>
            <input type="text" value={name} onChange={handleChange}/>
            <p>Hello, {name}</p>
        </div>
    );
}
