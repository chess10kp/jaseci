# Product-path facade for ``collections`` (CPython 3.14:
# ``Modules/_collectionsmodule.c`` accelerator + ``Lib/collections/__init__.py``
# pure-Python layer), exercised by CPython's ``test_collections``.
#
# The per-type implementations are the wave-19 facades:
#   * ``_collectionsmodule.jac`` -- deque, defaultdict (accelerator port)
#   * ``_collections_pylib.jac`` -- Counter, OrderedDict, namedtuple
# This module is the public-name assembly point: every factory is re-exported
# under the exact name guest code and converted Lib/test pins reference.
# ChainMap and the User* classes have no facade yet and are intentionally
# absent; add them here only together with their implementation module.

import from _collectionsmodule {
    _p2_deque as deque,
    _p2_defaultdict as defaultdict,
}
import from _collections_pylib {
    _p2_counter as Counter,
    _p2_ordereddict as OrderedDict,
    _p2_namedtuple as namedtuple,
}
