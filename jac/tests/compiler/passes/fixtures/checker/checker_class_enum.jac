"""Tests for class-based enum type checking (StrEnum, IntEnum)."""
import from enum { StrEnum, IntEnum, auto }

class BaseClass(StrEnum) {}
class BaseClass2(IntEnum) {}
class Tokens(BaseClass) {
    with entry {
        FLOAT = '1';
        LSQUARE = 'LSQUARE';
        RSQUARE = 'RSQUARE';
    }
}

# StrEnum member assignments
glob a: Tokens = Tokens.FLOAT,  # OK: enum member to enum type
     c: str = Tokens.FLOAT,  # OK: StrEnum member is assignable to str
     d: int = Tokens.FLOAT;  # Error: StrEnum member is NOT assignable to int

class Tokens2(BaseClass2) {
    with entry {
        FLOAT = '1';  # Error: Cannot assign <class str> to enum member 'FLOAT' of type <class int>
        LSQUARE = 'LSQUARE';  # Error: Cannot assign <class str> to enum member 'LSQUARE' of type <class int>
        RSQUARE = 'RSQUARE';  # Error: Cannot assign <class str> to enum member 'RSQUARE' of type <class int>
    }
}

# Test: Static methods on class-based enums should return their declared return type
class AccessLevel(IntEnum) {
    with entry {
        READ = 1;
        WRITE = 2;
        ADMIN = 3;
    }

    static def cast(level: int | str | None) -> AccessLevel | None {
        return None;
    }

    static def get_default -> int {
        return 99;
    }
}

# Test: IntEnum member assignment to IntEnum typed variable
glob level: AccessLevel = AccessLevel.READ,
     level_int: int = AccessLevel.READ,
     level_str: str = AccessLevel.READ;  # OK: IntEnum member to IntEnum type

# OK: IntEnum member is assignable to int
# Error: IntEnum member is NOT assignable to str
def check_level(min_level: AccessLevel) -> bool {
    return True;
}

glob check_result = check_level(AccessLevel.WRITE),
     static_method_ref = AccessLevel.cast,
     cast_result: AccessLevel | None = AccessLevel.cast(1),
     default_val: int = AccessLevel.get_default(),
     cast_wrong: int = AccessLevel.cast(1),
     default_wrong: str = AccessLevel.get_default();  # OK: IntEnum member as argument

# Static method member access (no call) should return FunctionType

# Static method call should return the declared return type
# OK
# OK
# Error: Cannot assign AccessLevel | None to int
# Error: Cannot assign int to str
# Test: enum.auto() should return int type (similar to Pyright's handling)
class Priority(IntEnum) {
    with entry {
        LOW = auto();
        MEDIUM = auto();
        HIGH = auto();
    }
}

# auto() members should work like regular IntEnum members
glob priority: Priority = Priority.LOW,
     priority_int: int = Priority.MEDIUM,
     priority_str: str = Priority.HIGH;  # OK: IntEnum member to IntEnum type
# OK: IntEnum member is assignable to int
# Error: IntEnum member is NOT assignable to str
