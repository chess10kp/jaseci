"""Test fixture for getattr(obj, "attr", None) to null-safe (obj?.attr) conversion.

This file tests the auto-lint rule W3039 that converts:
- getattr(obj, "attr", None) -> obj?.attr
"""

obj SomeClass {
    has value: int = 0,
        name: str = "";
}

glob instance = SomeClass(),
     basic = instance?.value,
     basic_sq = instance?.name,
     is_missing = instance?.value is None,
     guarded = instance?.value and True,
     ternary = instance?.value if True else 0;

# Basic assignment context

# Single-quoted attribute

# Inside a comparison

# Inside a boolean expression

# Inside a ternary
# As an argument to another function call
def echo(x: object) -> object {
    return x;
}
glob echoed = echo(instance?.name);

# As return value
def fetch_name(o: SomeClass) -> (str | None) {
    return o?.name;
}

# As a standalone expression statement
with entry {
    instance?.value;
}

# Inside an if-statement condition
with entry {
    if instance?.value {
        print("has value");
    }
}

# Should NOT be converted: non-None default
glob not_none_default = getattr(instance, "value", 0),
     two_arg = getattr(instance, "value"),
     attr_name = "value",
     dynamic = getattr(instance, attr_name, None),
     invalid_id = getattr(instance, "not-an-ident", None),
     keyword_attr = getattr(instance, "class", None);

# Should NOT be converted: 2-arg form (raises AttributeError on miss)

# Should NOT be converted: non-string attribute name

# Should NOT be converted: attribute name is not a valid identifier

# Should NOT be converted: attribute name is a Python keyword
# Should NOT be converted: lookalike function with same-shaped call
def getattr_lookalike(target: object, name_: str, fallback: object) -> object {
    return fallback;
}

glob lookalike = getattr_lookalike(instance, "value", None);
