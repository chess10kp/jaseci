import from checker_imported { some_int as alias }

glob i: int = alias,
     s: str = alias;  # <-- Ok
# <-- Error
