# Product-path facade for pwd (Unix password database access).
# Semantics mirror CPython 3.14 ``Modules/pwdmodule.c``: the three clinic
# entry points (getpwuid/getpwnam/getpwall) and the struct_passwd record
# they build.
#
# REPRESENTATION CHOICE (divergence ledger candidate): the C original is a
# thin shell over libc's user database -- _Py_Uid_Converter argument
# discipline, the HAVE_GETPWUID_R/HAVE_GETPWNAM_R ERANGE buffer-retry loops
# under Py_BEGIN_ALLOW_THREADS, setpwent/getpwent/endpwent iteration in
# getpwall(), and mkpwent()'s structseq packing (pw_name, pw_passwd, pw_uid,
# pw_gid, pw_gecos, pw_dir, pw_shell). Every observable byte (field values,
# KeyError texts "getpwuid(): uid not found: %S" / "getpwnam(): name not
# found: %R", the OverflowError->KeyError rewrite for out-of-range uids,
# embedded-null ValueError and UnicodeEncodeError for names) is produced by
# that floor, and the host ``pwd`` extension IS that floor on every
# interpreter this VM rides on. The facade therefore delegates the database
# reads to the host extension -- exactly like C extensions stay host-proxied
# on the import path -- rather than re-parse /etc/passwd guest-side (which
# would silently drop NSS/LDAP entries and diverge from the reference build).
#
# Divergences:
# - struct_passwd instances are host PyStructSequence objects: dual
#   tuple/attribute access, repr, and field order come from the host type.
#   The type object itself is not re-exposed as a guest attribute; test
#   suites consume the entry points, not the constructor.
# - The non-reentrant getpwent()/setpwent()/endpwent() trio stays host-side:
#   guest calls serialize through the same host runtime the C module assumes.
# - The ERANGE buffer-doubling loop is invisible above the floor; only its
#   outcomes (entry found / KeyError / MemoryError) cross the bridge.

import from importlib { import_module }

# Host bridge (see header note). importlib indirection because a bare
# ``import pwd`` inside this package resolves same-directory first and would
# re-enter this very module now that jacpython/pwd.jac exists.
glob _hp: any = import_module("pwd");


def getpwuid(uidobj: any) -> any {
    # pwd_getpwuid: _Py_Uid_Converter (OverflowError -> KeyError
    # "getpwuid(): uid not found") -> getpwuid_r retry loop -> mkpwent;
    # missing uid raises KeyError "getpwuid(): uid not found: <uid>".
    return _hp.getpwuid(uidobj);
}


def getpwnam(name: any) -> any {
    # pwd_getpwnam_impl: EncodeFSDefault + embedded-null guard ->
    # getpwnam_r retry loop -> mkpwent; missing name raises KeyError
    # "getpwnam(): name not found: <name>".
    return _hp.getpwnam(name);
}


def getpwall -> list {
    # pwd_getpwall_impl: setpwent() / getpwent() loop / endpwent(), one
    # mkpwent per entry, arbitrary order.
    return _hp.getpwall();
}
