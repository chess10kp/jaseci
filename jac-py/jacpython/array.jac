# Product-path module surface for array (wave 14 module entry).
#
# ``jac-py/jacpython/arrayobject.jac`` carries the runtime truth (byte-faithful
# storage, construction, access, mutation); staged ``jac-py/Modules/arraymodule.{c,jac}``
# remain the wave-14 c2jac corpus oracle pair. This module is the user-facing
# entry point mirroring CPython 3.14 ``Modules/arraymodule.c``'s module-level
# surface: the ``array`` constructor and the ``typecodes`` constant.
#
# Not exported here (diverges from CPython by design):
# - ``_array_reconstructor``: pickle reconstruction helper; the guest has no
#   pickle path for arrays yet, so the machine-format codes have no consumer.
# - ``ArrayType``: removed in CPython 3.13 (gh-90562 deprecated-alias sweep).

import from arrayobject {
    Array,
    ArrayIter,
    _p2_array,
}

# array.typecodes: the descriptor table order from Modules/arraymodule.c
# (LP64: 'u'/'w' are 4 bytes, 'l'/'L' are 8).
glob typecodes: str = "bBuwhHiIlLqQfd";

def array(typecode: any, initializer: any = None) -> Array {
    return _p2_array(typecode, initializer);
}
