# Product-path facade for ``struct`` (CPython 3.14 ``Lib/struct.py``),
# exercised by CPython's ``test_struct``.
#
# ``_structmodule.jac`` carries the accelerator truth (Modules/_struct.c,
# wave 13); this module is the public-name assembly point: every name guest
# code and converted Lib/test pins reference is re-exported here under its
# exact CPython spelling, including the ``_struct.Struct`` type as
# ``struct.Struct``.
#
# Lib/struct.py itself adds no semantics over _struct -- it only re-exports
# -- so this module stays a pure re-export layer; anything semantic belongs
# in _structmodule.jac.
#
# Error surface: ``struct.error`` identity stays bridge-table name matching
# ("struct.error" is registered against Exception in _structmodule.jac at
# import); there is no class object to subclass yet, same convention as
# csv.Error.

import from _structmodule {
    _StructObj as Struct,
    calcsize,
    pack,
    pack_into,
    unpack,
    unpack_from,
    iter_unpack,
    compile,
    _clearcache,
}
