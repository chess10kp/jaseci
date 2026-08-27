# Product-path facade for grp (Unix group database access).
# Semantics mirror CPython 3.14 ``Modules/grpmodule.c``: the three clinic
# entry points (getgrgid/getgrnam/getgrall) and the struct_group record
# they build.
#
# REPRESENTATION CHOICE (divergence ledger candidate): the C original is a
# thin shell over libc's group database -- _Py_Gid_Converter argument
# discipline, the HAVE_GETGRGID_R/HAVE_GETGRNAM_R ERANGE buffer-retry
# loops under Py_BEGIN_ALLOW_THREADS, setgrent/getgrent/endgrent iteration
# under group_db_mutex, and mkgrent() packing a raw ``struct group`` into
# the PyStructSequence. Every observable byte (field values, KeyError texts
# "getgrgid(): gid not found: %S" / "getgrnam(): name not found: %R", the
# TypeError/OverflowError converter texts, embedded-null rejection for
# names) is produced by that floor, and the host ``grp`` extension IS that
# floor on every interpreter this VM rides on. The facade therefore
# delegates the database reads to the host extension -- exactly like C
# extensions stay host-proxied on the import path -- rather than re-parse
# /etc/group guest-side (which would silently drop NSS/YP entries and
# diverge from the reference build).
#
# Divergences:
# - struct_group instances are host PyStructSequence objects: dual
#   tuple/attribute access, repr, and field order (gr_name, gr_passwd,
#   gr_gid, gr_mem) come from the host type. The type object itself is not
#   re-exposed as a guest attribute; test suites consume the entry points,
#   not the constructor.
# - The group_db_mutex discipline around the non-reentrant getgrent()/
#   setgrent()/endgrent() trio stays host-side: guest calls serialize
#   through the same host runtime the C module assumes.
# - The ERANGE buffer-doubling loop is invisible above the floor; only its
#   outcomes (entry found / KeyError / MemoryError) cross the bridge.

import from importlib { import_module }

# Host bridge (see header note). importlib indirection because a bare
# ``import grp`` inside this package resolves same-directory first and would
# re-enter this very module now that jacpython/grp.jac exists.
glob _hg: any = import_module("grp");


def getgrgid(id: any) -> any {
    # grp_getgrgid_impl: gid converter -> getgrgid_r retry loop -> mkgrent;
    # missing gid raises KeyError "getgrgid(): gid not found: <gid>".
    return _hg.getgrgid(id);
}


def getgrnam(name: any) -> any {
    # grp_getgrnam_impl: EncodeFSDefault + embedded-null guard ->
    # getgrnam_r retry loop -> mkgrent; missing name raises KeyError
    # "getgrnam(): name not found: <name>".
    return _hg.getgrnam(name);
}


def getgrall() -> list {
    # grp_getgrall_impl: setgrent() / getgrent() loop / endgrent(), one
    # mkgrent per entry, arbitrary order.
    return _hg.getgrall();
}
