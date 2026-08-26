# Product-path facade for _symtable (Modules/symtablemodule.c).
#
# Semantics mirror CPython 3.14 ``Modules/symtablemodule.c`` plus the flag
# bits of ``Include/internal/pycore_symtable.h``. The C module has exactly
# one entry point, ``_symtable.symtable(source, filename, startstr)``,
# which parses *source* and returns its top-level symtable entry
# (``st->st_top``, a PySTEntryObject). This facade runs the same pipeline
# on the native front end (parse_file / parse_eval_expr ->
# build_module_symtable) and returns that entry surface as a plain dict
# tree so Python-level wrappers can consume raw def-use flag bits:
#
#     {"name": str, "type": int, "lineno": int, "nested": bool,
#      "symbols": {name: flags:int}, "varnames": [str],
#      "children": [<same shape>]}
#
# The C entry also carries an ``id`` member (object identity used only
# for Lib/symtable.py memoization); a dict tree cannot reproduce
# identity, so it is intentionally omitted.
#
# Module constants match PyModule_AddIntMacro/IntConstant order in
# symtable_init_constants.

import from ast_nodes { stmt, Expr }
import from compiler_diagnostics { symbol_diagnostic }
import from parser { parse_file, parse_eval_expr }
import from compiler_symtable { build_module_symtable, sym_block }


glob USE: int = 16,
     DEF_GLOBAL: int = 1,
     DEF_NONLOCAL: int = 8,
     DEF_LOCAL: int = 2,
     DEF_PARAM: int = 4,
     DEF_TYPE_PARAM: int = 1024,
     DEF_FREE_CLASS: int = 64,
     DEF_IMPORT: int = 128,
     DEF_BOUND: int = 130,
     DEF_ANNOT: int = 256,
     DEF_COMP_ITER: int = 512,
     DEF_COMP_CELL: int = 2048,

     TYPE_FUNCTION: int = 0,
     TYPE_CLASS: int = 1,
     TYPE_MODULE: int = 2,
     TYPE_ANNOTATION: int = 3,
     TYPE_TYPE_ALIAS: int = 4,
     TYPE_TYPE_PARAMETERS: int = 5,
     TYPE_TYPE_VARIABLE: int = 6,

     LOCAL: int = 1,
     GLOBAL_EXPLICIT: int = 2,
     GLOBAL_IMPLICIT: int = 3,
     FREE: int = 4,
     CELL: int = 5,

     SCOPE_OFF: int = 12,
     SCOPE_MASK: int = 15;


def _block_type_code(block_type: str) -> int {
    # _Py_block_ty enum ordering (pycore_symtable.h).
    if block_type == "function" {
        return TYPE_FUNCTION;
    }
    if block_type == "class" {
        return TYPE_CLASS;
    }
    if block_type == "module" {
        return TYPE_MODULE;
    }
    if block_type == "annotation" {
        return TYPE_ANNOTATION;
    }
    if block_type == "type_alias" {
        return TYPE_TYPE_ALIAS;
    }
    if block_type == "type_parameters" {
        return TYPE_TYPE_PARAMETERS;
    }
    if block_type == "type_variable" {
        return TYPE_TYPE_VARIABLE;
    }
    return TYPE_MODULE;
}


def _entry_to_dict(b: sym_block) -> dict[str, any] {
    symbols: dict[str, any] = {};
    for name in sorted(list(b.symbols.keys())) {
        symbols[name] = b.symbols[name];
    }
    children: list[any] = [];
    for ch in b.children {
        children.append(_entry_to_dict(ch));
    }
    return {
        "name": b.name,
        "type": _block_type_code(b.block_type),
        "lineno": b.lineno,
        "nested": b.nested,
        "symbols": symbols,
        "varnames": list(b.varnames),
        "children": children,
    };
}


def _start_input(startstr: str) -> int {
    # Mirrors the strcmp chain in _symtable_symtable_impl.
    if startstr == "exec" {
        return 0;
    }
    if startstr == "eval" {
        return 1;
    }
    if startstr == "single" {
        return 2;
    }
    raise ValueError(
        "symtable() arg 3 must be 'exec' or 'eval' or 'single'"
    );
}


def _source_as_str(source: any) -> str {
    # _Py_SourceAsString accepts str and bytes; bytes decode as UTF-8
    # (cf.cf_flags carries PyCF_SOURCE_IS_UTF8).
    if isinstance(source, str) {
        return source as str;
    }
    if isinstance(source, bytes) {
        return (source as bytes).decode("utf-8");
    }
    raise TypeError("symtable(): source must be string or bytes");
}


def symtable(source: any, filename: str, startstr: str) -> dict[str, any] {
    src = _source_as_str(source);
    start = _start_input(startstr);
    body: list[stmt];
    if start == 0 {
        m = parse_file(src, filename);
        if m is None {
            raise SyntaxError("invalid syntax");
        }
        body = m.body;
    } else {
        # eval/single inputs parse as one expression node; symtable.c still
        # analyzes them over a module block wrapping that expression.
        e = parse_eval_expr(src, filename);
        if e is None {
            raise SyntaxError("invalid syntax");
        }
        # The wrapper statement carries no source location of its own; the
        # expression node inside keeps whatever positions the parser recorded.
        body = [
            Expr(
                value=e,
                lineno=1,
                col_offset=0,
                end_lineno=None,
                end_col_offset=None,
            ),
        ];
    }
    sr = build_module_symtable(body);
    if sr.diag is not None {
        d = sr.diag as symbol_diagnostic;
        raise SyntaxError(d.message);
    }
    if sr.top is None {
        raise SyntaxError("invalid syntax");
    }
    return _entry_to_dict(sr.top);
}
