# Product-path facade for the _sysconfig stdlib accelerator (native Jac).
#
# Semantics mirror CPython 3.14 ``Modules/_sysconfig.c``. Implementation lives
# in sysconfig_shim.jac (shared with ceval's import fallback); this module
# file exports the same surface natively so guest ``import _sysconfig`` resolves
# here.

import from objects { PyObj }
import from sysconfig_shim { PySysconfigConfigVarsFn }

glob config_vars: PyObj = PySysconfigConfigVarsFn(t="sysconfig_fn") as PyObj;
