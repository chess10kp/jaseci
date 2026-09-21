"""Test fixture for hasattr to null-safe (obj?.attr) conversion.

This file tests the auto-lint rule that converts:
- hasattr(obj, "attr") -> obj?.attr
- obj.attr if hasattr(obj, "attr") else default -> obj?.attr if obj?.attr else default
"""

obj SomeClass {
    has value: int = 0,
        name: str = "";
}

glob instance = SomeClass(),
     result1 = instance?.value or 0,
     result2 = instance?.name or "default",
     result3 = instance?.name,
     result4 = instance?.value and instance.value > 0,
     result5 = hasattr(instance, "name") or False,
     result6 = instance?.value or -1,
     result7 = instance?.value or (instance?.name or "none"),
     attr_name = "value",
     result8 = instance.value if hasattr(instance, attr_name) else 0;

# Basic hasattr in if-else expression

# hasattr with different attribute

# hasattr with None as else value

# hasattr in binary expression (and)

# hasattr in binary expression (or) — should NOT be converted
# (standalone boolean check with no matching attr access in other operand)

# hasattr with single quotes

# Nested hasattr - should only convert the hasattr calls

# hasattr that should NOT be converted (variable attribute name)
# hasattr that should NOT be converted (more than 2 args - invalid anyway)
# This would be a syntax error in real code, but the auto-lint should not touch it

# Regular function call that looks like hasattr but isn't
def hasattr_lookalike(`obj: object, attr: str) -> bool {
    return True;
}

glob result9 = hasattr_lookalike(instance, "value");
