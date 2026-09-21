import math as alias;

glob
     # math module imports sys so it has the symbol
     # we're not using math.pi since it's a Final[float]
     # and we haven't implemented generic types yet.
     m = alias;

with entry {
    i: int = m.sys.prefix;  # <-- Error
    s: str = m.sys.prefix;  # <-- Ok
}
