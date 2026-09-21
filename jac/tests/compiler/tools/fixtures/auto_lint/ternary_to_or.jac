"""Test fixture for ternary to or expression conversion.

This file tests the auto-lint rule that converts:
- x if x else default -> x or default
- x?.attr if x?.attr else default -> x?.attr or default
"""

obj SomeClass {
    has value: int = 0,
        name: str = "";
}

glob instance = SomeClass(),
     result1 = instance.value or 0,
     result2 = instance?.name or "default",
     result3 = instance.value if instance.name else 0;

# Basic ternary with identical value and condition (should be converted)

# Null-safe ternary with identical value and condition (should be converted)

# Different value and condition (should NOT be converted)
# Function call in ternary (should be converted if identical)
def get_value -> int {
    return 42;
}

glob result4 = get_value() if get_value() else -1,
     result5 = (instance.value + 1) if (instance.value + 1) else 0,
     result6 = instance?.value or -1,
     result7 = instance?.name or "",
     result8 = instance?.value;
# Complex expression (should be converted if identical)

# Nested null-safe access (should be converted)

# Different types of defaults
