"""Property setter / getter / deleter must not be flagged as duplicate methods.

`@<name>.setter`, `@<name>.deleter`, and `@<name>.getter` decorators extend
an existing `@property` by reusing the same method name. This is the canonical
Python property pattern and must not trigger E0076 (Duplicate method).
"""

obj Container {
    has _val: int = 0,
        _name: str = "x";

    has val: int {
        getter {
            return self._val;
        }
        setter(new_val: int) {
            self._val = new_val;
        }
        deleter {
            self._val = 0;
        }
    }

    has name: str {
        getter {
            return self._name;
        }
        setter(new_name: str) {
            self._name = new_name;
        }
    }
}
