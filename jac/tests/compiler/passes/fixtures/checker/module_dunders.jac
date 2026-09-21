"""Tests that module-level dunder variables are typed correctly.

__name__, __file__, __doc__, __package__, and __spec__ are injected by
Python's import system.  The type checker must know their types so that
uses like getLogger(__name__) do not produce false E1053 errors.
"""

import from logging { getLogger }

# __name__: str — must be assignable to str parameter
glob logger = getLogger(__name__),
     current_file: str | None = __file__,
     module_doc: str | None = __doc__,
     pkg: str | None = __package__,
     spec: object = __spec__;
# __file__: str | None

# __doc__: str | None

# __package__: str | None

# __spec__: object
