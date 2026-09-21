"""Test with entry inside a class body.

The with entry block inside a class is used for instance initialization,
NOT module-level globals. These should NOT be extracted to glob since
glob is a module-level construct that doesn't work inside classes.
"""
import from typing { TYPE_CHECKING }

glob a = 5;
with entry {
    if TYPE_CHECKING {
        import from math { SupportsFloat }
    }
}

glob b = 6;
with entry {
    if TYPE_CHECKING {
        import from math { SupportsIndex }
    }
}

class MyClass {
    """A class with entry block for initialization."""
    has instance_var: int = 0,
        another_var: str = "",
        list_var: list[any] = [];

    with entry {
        instance_var = 42;
        another_var = "hello";
        list_var = [1, 2, 3];
    }

    def get_value(self: MyClass) -> int {
        return self.instance_var;
    }
}

# Module level with entry - this SHOULD be extracted
glob module_var = 100;
with entry {
    cls_obj = MyClass();
}
