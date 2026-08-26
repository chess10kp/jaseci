# Product-path binascii surface (Python module name) over the wave-16
# runtime facade.
#
# ``binasciimodule.jac`` carries the runtime truth for Modules/binascii.c
# semantics (hexlify/base64/uu/qp/crc); this module binds them under the
# stdlib-visible name ``binascii`` so guest code and converted suites can
# ``import from binascii { ... }`` without knowing the C-stem alias.
#
# Exception declaration: CPython defines ``binascii.Error`` (a ValueError
# subclass) and ``binascii.Incomplete``. New exception TYPES are unsupported
# from facades, so the hierarchy is declared here in the bridge-table
# module-exception registry (exceptions_core.jac) -- matching walks these
# parent links and boundary materialization mints host subclasses of the
# registered base.

import from binasciimodule {
    a2b_base64,
    a2b_hex,
    a2b_qp,
    a2b_uu,
    b2a_base64,
    b2a_hex,
    b2a_qp,
    b2a_uu,
    crc32,
    crc_hqx,
    hexlify,
    unhexlify,
}

import from exceptions_core { register_module_exception }

with entry {
    # CPython 3.14 Modules/binascii.c binascii_exec(): Error subclasses
    # ValueError; Incomplete derives directly from Exception.
    register_module_exception("binascii.Error", "ValueError");
    register_module_exception("binascii.Incomplete", "Exception");
}
