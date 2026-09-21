import from typing { Final }

glob x: Final[int] = 10;  # <-- Ok
with entry {
    y: int = x;  # <-- Ok
    z: str = x;  # <-- Error: incompatible types
}
