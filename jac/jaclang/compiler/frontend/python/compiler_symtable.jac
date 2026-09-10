# Symbol table for the P4 front track (INTEGRATION_PLAN Phase 5).
#
# Two-pass scope analysis over validated AST: raw def/use collection, then
# LOCAL/GLOBAL/FREE/CELL classification matching CPython 3.14 symtable.c.
# Codegen consumes sym_facts; product_compile runs this after validation.

import from jaclang.compiler.frontend.python.ast_nodes {
    Module,
    expr,
    stmt,
    Name,
    Attribute,
    Subscript,
    Slice,
    Tuple,
    List,
    Starred,
    BinOp,
    UnaryOp,
    Call,
    Compare,
    BoolOp,
    IfExp,
    JoinedStr,
    FormattedValue,
    TemplateStr,
    Interpolation,
    Assign,
    Expr,
    Pass,
    Return,
    AugAssign,
    AnnAssign,
    Delete,
    Raise,
    Assert,
    Global,
    Nonlocal,
    For,
    While,
    If,
    Try,
    With,
    FunctionDef,
    ClassDef,
    AsyncFunctionDef,
    TypeAlias,
    TypeVar,
    AsyncFor,
    AsyncWith,
    Set,
    Dict,
    ListComp,
    SetComp,
    DictComp,
    GeneratorExp,
    NamedExpr,
    Lambda,
    comprehension,
    Yield,
    YieldFrom,
    Await,
    Import,
    ImportFrom,
    alias,
    Load,
    Store,
    Del,
    arg,
    arguments,
    Match,
    match_case,
    pattern,
    MatchValue,
    MatchSingleton,
    MatchAs,
    MatchOr,
    MatchSequence,
    MatchStar,
    MatchMapping,
    MatchClass,
}
import from jaclang.compiler.frontend.python.compiler_diagnostics {
    symbol_diagnostic,
    compiler_diagnostic,
    compiler_diag_kind,
    compiler_diag_message
}

# CPython symtable flag bits (Include/internal/pycore_symtable.h).
glob DEF_GLOBAL: int = 1,
     DEF_LOCAL: int = 2,
     DEF_PARAM: int = 4,
     DEF_NONLOCAL: int = 8,
     SYM_USE: int = 16,
     DEF_BOUND: int = 70,
     DEF_COMP_ITER: int = 512,
     SCOPE_OFFSET: int = 12,
     SCOPE_LOCAL: int = 1,
     SCOPE_GLOBAL_EXPLICIT: int = 2,
     SCOPE_GLOBAL_IMPLICIT: int = 3,
     SCOPE_FREE: int = 4,
     SCOPE_CELL: int = 5;

obj sym_block {
    has block_type: str,
        name: str,
        lineno: int,
        col_offset: int = -1,
        nested: bool = False,
        generator: bool = False,
        coroutine: bool = False,
        can_see_class_scope: bool = False,
        # Class scopes only: a child scope referenced __class__ (directly or via
        # a super load), so the body needs the implicit __class__ cell
        # (CPython symtable.c drop_class_free -> ste_needs_class_closure).
        needs_class_closure: bool = False,
        # Any module-top symbol entry for "super" (CPython codegen.c checks
        # _PyST_GetScope(st_top, "super") != 0 before optimizing super calls).
        top_has_super: bool = False,
        comprehension: str | None = None,
        symbols: dict[str, int] = {},
        varnames: list[str] = [],
        local_varnames: list[str] = [],
        directive_lineno: dict[str, int] = {},
        directive_col: dict[str, int] = {},
        children: list[sym_block] = [];
}

obj symtable_result {
    has top: sym_block | None = None,
        diag: compiler_diagnostic | None = None;
}

def symtable_ok(top: sym_block) -> symtable_result {
    return symtable_result(top=top);
}

def symtable_error(
    kind: str, message: str, lineno: int = -1, col_offset: int = -1
) -> symtable_result {
    return symtable_result(
        diag=symbol_diagnostic(
            kind=kind, message=message, lineno=lineno, col_offset=col_offset
        )
    );
}

def sym_flag_set(flags: int, bit: int) -> bool {
    return (flags & bit) != 0;
}

def sym_flag_add(flags: int, bit: int) -> int {
    return flags | bit;
}

def sym_scope_of(flags: int) -> int {
    return (flags >> SCOPE_OFFSET) & 31;
}

def sym_set_scope(flags: int, scope: int) -> int {
    cleared = flags & ((1 << SCOPE_OFFSET) - 1);
    return cleared | (scope << SCOPE_OFFSET);
}

def sym_dict_get(d: dict[str, int], key: str, fallback: int = 0) -> int {
    if key in d {
        return d[key];
    }
    return fallback;
}

def sym_set_add(s: dict[str, int], name: str) {
    s[name] = 1;
}

def sym_set_contains(s: dict[str, int], name: str) -> bool {
    return name in s;
}

def sym_set_keys(s: dict[str, int]) -> list[str] {
    return list(s.keys());
}

def sym_set_union(a: dict[str, int], b: dict[str, int]) -> dict[str, int] {
    out: dict[str, int] = {};
    for k in a.keys() {
        out[k] = 1;
    }
    for k in b.keys() {
        out[k] = 1;
    }
    return out;
}

def sym_set_discard(s: dict[str, int], name: str) {
    if name in s {
        del s[name];
    }
}

def sym_sorted_names(d: dict[str, int]) -> list[str] {
    return sorted(list(d.keys()));
}

def sym_block_tuple_names(d: dict[str, int], pred_scope: int) -> list[str] {
    return [
        name
        for name in sym_sorted_names(d)
        if sym_scope_of(d[name]) == pred_scope
    ];
}

def mangle_name(private: str | None, name: str) -> str {
    # CPython _Py_Mangle: only __spam forms (>=2 leading underscores, at most 1
    # trailing underscore) mangle inside a class scope; dunders (__x__) and
    # dotted names never do, and leading underscores are stripped from the
    # class name itself.
    if private is None {
        return name;
    }
    n = len(name);
    if n < 2 or name[0] != "_" or name[1] != "_" {
        return name;
    }
    if (name[n - 1] == "_" and name[n - 2] == "_") or "." in name {
        return name;
    }
    ip = 0;
    while ip < len(private) and private[ip] == "_" {
        ip = ip + 1;
    }
    if ip == len(private) {
        return name;
    }
    return "_" + private[ip:] + name;
}

obj sym_builder {
    has cur: sym_block,
        stack: list[sym_block],
        module_global: dict[str, int] = {},
        private: str | None = None,
        diag: compiler_diagnostic | None = None;

    def fail(kind: str, message: str, lineno: int = -1, col_offset: int = -1) -> bool {
        if self.diag is None {
            self.diag = symbol_diagnostic(
                kind=kind, message=message, lineno=lineno, col_offset=col_offset
            );
        }
        return False;
    }

    def lookup(name: str) -> int {
        return sym_dict_get(self.cur.symbols, name, 0);
    }

    def add_def(name: str, flags: int, lineno: int, col_offset: int) -> bool {
        if name == "__debug__" and (flags & (DEF_LOCAL | DEF_PARAM)) != 0 {
            return self.fail(
                "SyntaxError", "cannot assign to __debug__", lineno, col_offset
            );
        }
        mangled = mangle_name(self.private, name);
        cur_flags = self.lookup(mangled);
        if sym_flag_set(cur_flags, DEF_PARAM) and sym_flag_set(flags, DEF_PARAM) {
            return self.fail(
                "SyntaxError",
                "duplicate argument '" + name + "' in function definition",
                lineno,
                col_offset
            );
        }
        if sym_flag_set(cur_flags, DEF_PARAM) and sym_flag_set(flags, DEF_GLOBAL) {
            return self.fail(
                "SyntaxError",
                "name '" + name + "' is parameter and global",
                lineno,
                col_offset
            );
        }
        if sym_flag_set(cur_flags, DEF_PARAM) and sym_flag_set(flags, DEF_NONLOCAL) {
            return self.fail(
                "SyntaxError",
                "name '" + name + "' is parameter and nonlocal",
                lineno,
                col_offset
            );
        }
        self.cur.symbols[mangled] = sym_flag_add(cur_flags, flags);
        if sym_flag_set(flags, DEF_GLOBAL) or sym_flag_set(flags, DEF_NONLOCAL) {
            self.cur.directive_lineno[mangled] = lineno;
            self.cur.directive_col[mangled] = col_offset;
        }
        if self.cur.block_type == "module" {
            self.module_global[mangled] = self.cur.symbols[mangled];
        }
        if sym_flag_set(flags, DEF_PARAM) {
            self.cur.varnames.append(mangled);
        } elif self.cur.block_type == "function" and sym_flag_set(flags, DEF_LOCAL) {
            if not sym_flag_set(cur_flags, DEF_LOCAL)
                and not sym_flag_set(cur_flags, DEF_PARAM) {
                self.cur.local_varnames.append(mangled);
            }
        }
        return True;
    }

    def add_use(name: str) -> bool {
        mangled = mangle_name(self.private, name);
        cur_flags = self.lookup(mangled);
        self.cur.symbols[mangled] = sym_flag_add(cur_flags, SYM_USE);
        return True;
    }

    def push_block(
        block_type: str,
        name: str,
        lineno: int,
        nested: bool,
        can_see_class_scope: bool = False,
        col_offset: int = -1
    ) -> bool {
        child = sym_block(
            block_type=block_type,
            name=name,
            lineno=lineno,
            col_offset=col_offset,
            nested=nested,
            can_see_class_scope=can_see_class_scope
        );
        self.cur.children.append(child);
        self.stack.append(self.cur);
        self.cur = child;
        return True;
    }

    def pop_block -> bool {
        if len(self.stack) == 0 {
            return False;
        }
        self.cur = self.stack.pop();
        return True;
    }
}

def sym_visit_comprehension_generators(
    b: sym_builder, generators: list[comprehension]
) -> bool {
    if len(generators) == 0 {
        return True;
    }
    outer = generators[0];
    if not sym_visit_load_expr(b, outer.iter) {
        return False;
    }
    gi = 0;
    while gi < len(generators) {
        g = generators[gi];
        if gi > 0 {
            if not sym_visit_load_expr(b, g.iter) {
                return False;
            }
        }
        if not sym_visit_comp_store_target(b, g.target) {
            return False;
        }
        fi = 0;
        while fi < len(g.ifs) {
            if not sym_visit_load_expr(b, g.ifs[fi]) {
                return False;
            }
            fi = fi + 1;
        }
        gi = gi + 1;
    }
    return True;
}

def sym_visit_inline_comprehension(
    b: sym_builder, generators: list[comprehension], elt: expr, value: expr | None
) -> bool {
    if not sym_visit_comprehension_generators(b, generators) {
        return False;
    }
    if value is not None and not sym_visit_load_expr(b, value) {
        return False;
    }
    return sym_visit_load_expr(b, elt);
}

def sym_visit_genexp(b: sym_builder, e: GeneratorExp) -> bool {
    if len(e.generators) == 0 {
        return True;
    }
    outer = e.generators[0];
    if not sym_visit_load_expr(b, outer.iter) {
        return False;
    }
    nested = sym_compute_nested(b);
    in_class = b.cur.block_type == "class" or b.cur.can_see_class_scope;
    if not b.push_block(
        "function", "genexpr", e.lineno, nested, in_class, e.col_offset
    ) {
        return False;
    }
    b.cur.comprehension = "gen";
    dot0 = arg(
        arg=".0",
        annotation=None,
        type_comment=None,
        lineno=e.lineno,
        col_offset=e.col_offset,
        end_lineno=e.end_lineno,
        end_col_offset=e.end_col_offset
    );
    if not b.add_def(".0", DEF_PARAM, dot0.lineno, dot0.col_offset) {
        return False;
    }
    if not sym_visit_store_target(b, outer.target) {
        return False;
    }
    fi = 0;
    while fi < len(outer.ifs) {
        if not sym_visit_load_expr(b, outer.ifs[fi]) {
            return False;
        }
        fi = fi + 1;
    }
    gi = 1;
    while gi < len(e.generators) {
        g = e.generators[gi];
        if not sym_visit_load_expr(b, g.iter) {
            return False;
        }
        if not sym_visit_store_target(b, g.target) {
            return False;
        }
        fj = 0;
        while fj < len(g.ifs) {
            if not sym_visit_load_expr(b, g.ifs[fj]) {
                return False;
            }
            fj = fj + 1;
        }
        gi = gi + 1;
    }
    if not sym_visit_load_expr(b, e.elt) {
        return False;
    }
    b.cur.generator = True;
    return b.pop_block();
}

def sym_visit_load_expr(b: sym_builder, e: expr) -> bool {
    if b.diag is not None {
        return False;
    }
    if isinstance(e, Name) {
        ok = b.add_use((e as Name).id);
        # Special-case super: it counts as a use of __class__
        # (CPython symtable.c Name_kind Load rule).
        if ok and (e as Name).id == "super" and sym_is_function_like(b.cur) {
            ok = b.add_use("__class__");
        }
        return ok;
    }
    if isinstance(e, Attribute) {
        return sym_visit_load_expr(b, (e as Attribute).value);
    }
    if isinstance(e, Subscript) {
        s = e as Subscript;
        if not sym_visit_load_expr(b, s.value) {
            return False;
        }
        return sym_visit_load_expr(b, s.slice);
    }
    if isinstance(e, Slice) {
        sl = e as Slice;
        if sl.lower is not None and not sym_visit_load_expr(b, sl.lower) {
            return False;
        }
        if sl.upper is not None and not sym_visit_load_expr(b, sl.upper) {
            return False;
        }
        if sl.step is not None and not sym_visit_load_expr(b, sl.step) {
            return False;
        }
        return True;
    }
    if isinstance(e, BinOp) {
        bo = e as BinOp;
        if not sym_visit_load_expr(b, bo.left) {
            return False;
        }
        return sym_visit_load_expr(b, bo.right);
    }
    if isinstance(e, UnaryOp) {
        return sym_visit_load_expr(b, (e as UnaryOp).operand);
    }
    if isinstance(e, Compare) {
        c = e as Compare;
        if not sym_visit_load_expr(b, c.left) {
            return False;
        }
        ci = 0;
        while ci < len(c.comparators) {
            if not sym_visit_load_expr(b, c.comparators[ci]) {
                return False;
            }
            ci = ci + 1;
        }
        return True;
    }
    if isinstance(e, Call) {
        ca = e as Call;
        if not sym_visit_load_expr(b, ca.func) {
            return False;
        }
        call_args = ca.args;
        if call_args is None {
            call_args = [];
        }
        ai = 0;
        while ai < len(call_args) {
            if not sym_visit_load_expr(b, call_args[ai]) {
                return False;
            }
            ai = ai + 1;
        }
        for kw in ca.keywords {
            if not sym_visit_load_expr(b, kw.value) {
                return False;
            }
        }
        return True;
    }
    if isinstance(e, BoolOp) {
        bop = e as BoolOp;
        vi = 0;
        while vi < len(bop.values) {
            if not sym_visit_load_expr(b, bop.values[vi]) {
                return False;
            }
            vi = vi + 1;
        }
        return True;
    }
    if isinstance(e, IfExp) {
        return sym_visit_load_expr(b, e.test)
            and sym_visit_load_expr(b, e.body)
            and sym_visit_load_expr(b, e.orelse);
    }
    if isinstance(e, JoinedStr) or isinstance(e, TemplateStr) {
        for value in e.values {
            if not sym_visit_load_expr(b, value) {
                return False;
            }
        }
        return True;
    }
    if isinstance(e, FormattedValue) or isinstance(e, Interpolation) {
        if not sym_visit_load_expr(b, e.value) {
            return False;
        }
        return e.format_spec is None or sym_visit_load_expr(b, e.format_spec);
    }
    if isinstance(e, Tuple) or isinstance(e, List) {
        elts: list[expr];
        if isinstance(e, Tuple) {
            elts = (e as Tuple).elts;
        } else {
            le = (e as List).elts;
            elts = le if le is not None else [];
        }
        ei = 0;
        while ei < len(elts) {
            if not sym_visit_load_expr(b, elts[ei]) {
                return False;
            }
            ei = ei + 1;
        }
        return True;
    }
    if isinstance(e, Starred) {
        return sym_visit_load_expr(b, (e as Starred).value);
    }
    if isinstance(e, Set) {
        selts = (e as Set).elts;
        si = 0;
        while si < len(selts) {
            if not sym_visit_load_expr(b, selts[si]) {
                return False;
            }
            si = si + 1;
        }
        return True;
    }
    if isinstance(e, Dict) {
        d = e as Dict;
        di = 0;
        while di < len(d.keys) {
            k = d.keys[di];
            if k is not None {
                if not sym_visit_load_expr(b, k) {
                    return False;
                }
            }
            if not sym_visit_load_expr(b, d.values[di]) {
                return False;
            }
            di = di + 1;
        }
        return True;
    }
    if isinstance(e, NamedExpr) {
        ne = e as NamedExpr;
        # PEP 572: the walrus target binds in the current scope (for inlined
        # comprehensions that is the enclosing function, matching the shared
        # fast-local slots); the value side is an ordinary load.
        if not sym_visit_store_target(b, ne.target) {
            return False;
        }
        return sym_visit_load_expr(b, ne.value);
    }
    if isinstance(e, ListComp) {
        lc = e as ListComp;
        return sym_visit_inline_comprehension(b, lc.generators, lc.elt, None);
    }
    if isinstance(e, SetComp) {
        sc = e as SetComp;
        return sym_visit_inline_comprehension(b, sc.generators, sc.elt, None);
    }
    if isinstance(e, DictComp) {
        dc = e as DictComp;
        if not sym_visit_inline_comprehension(b, dc.generators, dc.key, dc.value) {
            return False;
        }
        return True;
    }
    if isinstance(e, GeneratorExp) {
        return sym_visit_genexp(b, e as GeneratorExp);
    }
    if isinstance(e, Lambda) {
        lam = e as Lambda;
        if not sym_visit_arg_defaults(b, lam.args) {
            return False;
        }
        nested = sym_compute_nested(b);
        in_class = b.cur.block_type == "class" or b.cur.can_see_class_scope;
        if not b.push_block(
            "function", "lambda", lam.lineno, nested, in_class, lam.col_offset
        ) {
            return False;
        }
        if not sym_visit_params(b, lam.args) {
            return False;
        }
        if not sym_visit_load_expr(b, lam.body) {
            return False;
        }
        return b.pop_block();
    }
    if isinstance(e, Yield) {
        b.cur.generator = True;
        y = e as Yield;
        if y.value is not None {
            return sym_visit_load_expr(b, y.value);
        }
        return True;
    }
    if isinstance(e, YieldFrom) {
        b.cur.generator = True;
        return sym_visit_load_expr(b, (e as YieldFrom).value);
    }
    if isinstance(e, Await) {
        return sym_visit_load_expr(b, (e as Await).value);
    }
    return True;
}

def sym_visit_store_target(b: sym_builder, t: expr) -> bool {
    if b.diag is not None {
        return False;
    }
    if isinstance(t, Name) {
        n = t as Name;
        return b.add_def(n.id, DEF_LOCAL, n.lineno, n.col_offset);
    }
    if isinstance(t, Attribute) {
        return sym_visit_load_expr(b, (t as Attribute).value);
    }
    if isinstance(t, Subscript) {
        s = t as Subscript;
        if not sym_visit_load_expr(b, s.value) {
            return False;
        }
        return sym_visit_load_expr(b, s.slice);
    }
    if isinstance(t, Tuple) or isinstance(t, List) {
        elts: list[expr];
        if isinstance(t, Tuple) {
            elts = (t as Tuple).elts;
        } else {
            le = (t as List).elts;
            elts = le if le is not None else [];
        }
        ei = 0;
        while ei < len(elts) {
            if not sym_visit_store_target(b, elts[ei]) {
                return False;
            }
            ei = ei + 1;
        }
        return True;
    }
    if isinstance(t, Starred) {
        return sym_visit_store_target(b, (t as Starred).value);
    }
    return True;
}

def sym_visit_comp_store_target(b: sym_builder, t: expr) -> bool {
    if b.diag is not None {
        return False;
    }
    if isinstance(t, Tuple) {
        elts = (t as Tuple).elts;
        ei = 0;
        while ei < len(elts) {
            if not sym_visit_comp_store_target(b, elts[ei]) {
                return False;
            }
            ei = ei + 1;
        }
        return True;
    }
    if isinstance(t, Name) {
        n = t as Name;
        flags = DEF_LOCAL;
        if b.cur.block_type == "module" {
            flags = DEF_LOCAL | DEF_COMP_ITER;
        }
        return b.add_def(n.id, flags, n.lineno, n.col_offset);
    }
    return sym_visit_store_target(b, t);
}

def sym_visit_delete_target(b: sym_builder, t: expr) -> bool {
    if b.diag is not None {
        return False;
    }
    if isinstance(t, Name) {
        return b.add_use((t as Name).id);
    }
    if isinstance(t, Attribute) {
        return sym_visit_load_expr(b, (t as Attribute).value);
    }
    if isinstance(t, Subscript) {
        s = t as Subscript;
        if not sym_visit_load_expr(b, s.value) {
            return False;
        }
        return sym_visit_load_expr(b, s.slice);
    }
    return True;
}

# Default expressions are evaluated in the enclosing scope at definition time.
def sym_visit_arg_defaults(b: sym_builder, args: arguments) -> bool {
    di = 0;
    while di < len(args.defaults) {
        if not sym_visit_load_expr(b, args.defaults[di]) {
            return False;
        }
        di = di + 1;
    }
    ki = 0;
    while ki < len(args.kw_defaults) {
        kd = args.kw_defaults[ki];
        if kd is not None {
            if not sym_visit_load_expr(b, kd) {
                return False;
            }
        }
        ki = ki + 1;
    }
    return True;
}

def sym_visit_params(b: sym_builder, args: arguments) -> bool {
    pi = 0;
    while pi < len(args.posonlyargs) {
        a = args.posonlyargs[pi];
        if not b.add_def(a.arg, DEF_PARAM, a.lineno, a.col_offset) {
            return False;
        }
        pi = pi + 1;
    }
    pi = 0;
    while pi < len(args.args) {
        a = args.args[pi];
        if not b.add_def(a.arg, DEF_PARAM, a.lineno, a.col_offset) {
            return False;
        }
        pi = pi + 1;
    }
    pi = 0;
    while pi < len(args.kwonlyargs) {
        a = args.kwonlyargs[pi];
        if not b.add_def(a.arg, DEF_PARAM, a.lineno, a.col_offset) {
            return False;
        }
        pi = pi + 1;
    }
    if args.vararg is not None {
        va = args.vararg as arg;
        if not b.add_def(va.arg, DEF_PARAM, va.lineno, va.col_offset) {
            return False;
        }
    }
    if args.kwarg is not None {
        ka = args.kwarg as arg;
        if not b.add_def(ka.arg, DEF_PARAM, ka.lineno, ka.col_offset) {
            return False;
        }
    }
    return True;
}

def sym_is_function_like(block: sym_block) -> bool {
    return block.block_type == "function";
}

def sym_compute_nested(b: sym_builder) -> bool {
    if b.cur.block_type == "module" {
        return False;
    }
    if sym_is_function_like(b.cur) {
        return True;
    }
    if b.cur.nested {
        return True;
    }
    return False;
}

def sym_import_bind_name(a: alias) -> str {
    if a.asname is not None {
        return a.asname;
    }
    parts = a.name.split(".");
    return parts[0];
}

def sym_visit_pattern(b: sym_builder, p: pattern) -> bool {
    if b.diag is not None {
        return False;
    }
    p = sym_match_pattern_unwrap_or(p);
    if isinstance(p, MatchValue) {
        return sym_visit_load_expr(b, (p as MatchValue).value);
    }
    if isinstance(p, MatchSingleton) {
        return True;
    }
    if isinstance(p, MatchSequence) {
        ms = p as MatchSequence;
        pi = 0;
        while pi < len(ms.patterns) {
            if not sym_visit_pattern(b, ms.patterns[pi]) {
                return False;
            }
            pi = pi + 1;
        }
        return True;
    }
    if isinstance(p, MatchStar) {
        mst = p as MatchStar;
        if mst.name is not None and mst.name != "_" {
            if not b.add_def(mst.name, DEF_LOCAL, mst.lineno, mst.col_offset) {
                return False;
            }
        }
        return True;
    }
    if isinstance(p, MatchOr) {
        mo = p as MatchOr;
        pi = 0;
        while pi < len(mo.patterns) {
            if not sym_visit_pattern(b, mo.patterns[pi]) {
                return False;
            }
            pi = pi + 1;
        }
        return True;
    }
    if isinstance(p, MatchAs) {
        ma = p as MatchAs;
        if ma.pattern is not None {
            if not sym_visit_pattern(b, ma.pattern) {
                return False;
            }
        }
        if ma.name is not None and ma.name != "_" {
            if not b.add_def(ma.name, DEF_LOCAL, ma.lineno, ma.col_offset) {
                return False;
            }
        }
        return True;
    }
    if isinstance(p, MatchMapping) {
        mm = p as MatchMapping;
        if mm.keys is not None {
            ki = 0;
            while ki < len(mm.keys) {
                if not sym_visit_load_expr(b, mm.keys[ki]) {
                    return False;
                }
                ki = ki + 1;
            }
        }
        if mm.patterns is not None {
            pi = 0;
            while pi < len(mm.patterns) {
                if not sym_visit_pattern(b, mm.patterns[pi]) {
                    return False;
                }
                pi = pi + 1;
            }
        }
        if mm.rest is not None and mm.rest != "_" {
            if not b.add_def(mm.rest, DEF_LOCAL, mm.lineno, mm.col_offset) {
                return False;
            }
        }
        return True;
    }
    if isinstance(p, MatchClass) {
        mc = p as MatchClass;
        if not sym_visit_load_expr(b, mc.cls) {
            return False;
        }
        if mc.patterns is not None {
            pi = 0;
            while pi < len(mc.patterns) {
                if not sym_visit_pattern(b, mc.patterns[pi]) {
                    return False;
                }
                pi = pi + 1;
            }
        }
        if mc.kwd_patterns is not None {
            ki = 0;
            while ki < len(mc.kwd_patterns) {
                if not sym_visit_pattern(b, mc.kwd_patterns[ki]) {
                    return False;
                }
                ki = ki + 1;
            }
        }
        return True;
    }
    return b.fail(
        "NotImplementedError", "unsupported match pattern", p.lineno, p.col_offset
    );
}

def sym_match_pattern_unwrap_or(p: pattern) -> pattern {
    if isinstance(p, MatchOr) {
        mo = p as MatchOr;
        if len(mo.patterns) == 1 {
            return mo.patterns[0];
        }
    }
    return p;
}

def sym_visit_stmt(b: sym_builder, s: stmt) -> bool {
    if b.diag is not None {
        return False;
    }
    if isinstance(s, Assign) {
        a = s as Assign;
        # CPython's symtable defines the value side before the assignment
        # targets, so a PEP 572 walrus target inside the value lands in
        # co_varnames ahead of the statement's own targets.
        if not sym_visit_load_expr(b, a.value) {
            return False;
        }
        ti = 0;
        while ti < len(a.targets) {
            if not sym_visit_store_target(b, a.targets[ti]) {
                return False;
            }
            ti = ti + 1;
        }
        return True;
    }
    if isinstance(s, AugAssign) {
        aa = s as AugAssign;
        if not sym_visit_store_target(b, aa.target) {
            return False;
        }
        return sym_visit_load_expr(b, aa.value);
    }
    if isinstance(s, AnnAssign) {
        an = s as AnnAssign;
        if isinstance(an.target, Name) {
            tn = (an.target as Name).id;
            if not b.add_def(tn, DEF_LOCAL, an.lineno, an.col_offset) {
                return False;
            }
        } else {
            if not sym_visit_store_target(b, an.target) {
                return False;
            }
        }
        if an.value is not None {
            return sym_visit_load_expr(b, an.value);
        }
        return True;
    }
    if isinstance(s, Expr) {
        return sym_visit_load_expr(b, (s as Expr).value);
    }
    if isinstance(s, Pass) {
        return True;
    }
    if isinstance(s, Return) {
        r = s as Return;
        if r.value is not None {
            return sym_visit_load_expr(b, r.value);
        }
        return True;
    }
    if isinstance(s, Yield) {
        b.cur.generator = True;
        y = s as Yield;
        if y.value is not None {
            return sym_visit_load_expr(b, y.value);
        }
        return True;
    }
    if isinstance(s, YieldFrom) {
        b.cur.generator = True;
        return sym_visit_load_expr(b, (s as YieldFrom).value);
    }
    if isinstance(s, Delete) {
        d = s as Delete;
        ti = 0;
        while ti < len(d.targets) {
            if not sym_visit_delete_target(b, d.targets[ti]) {
                return False;
            }
            ti = ti + 1;
        }
        return True;
    }
    if isinstance(s, Raise) {
        raise_stmt = s as Raise;
        if raise_stmt.exc is not None {
            if not sym_visit_load_expr(b, raise_stmt.exc) {
                return False;
            }
        }
        if raise_stmt.cause is not None {
            if not sym_visit_load_expr(b, raise_stmt.cause) {
                return False;
            }
        }
        return True;
    }
    if isinstance(s, Assert) {
        assert_stmt = s as Assert;
        if not sym_visit_load_expr(b, assert_stmt.`test) {
            return False;
        }
        if assert_stmt.msg is not None {
            if not sym_visit_load_expr(b, assert_stmt.msg) {
                return False;
            }
        }
        return True;
    }
    if isinstance(s, Global) {
        g = s as Global;
        ni = 0;
        while ni < len(g.names) {
            if not b.add_def(g.names[ni], DEF_GLOBAL, g.lineno, g.col_offset) {
                return False;
            }
            ni = ni + 1;
        }
        return True;
    }
    if isinstance(s, Nonlocal) {
        nl = s as Nonlocal;
        if b.cur.block_type == "module" {
            return b.fail(
                "SyntaxError",
                "nonlocal declaration not allowed at module level",
                nl.lineno,
                nl.col_offset
            );
        }
        ni = 0;
        while ni < len(nl.names) {
            if not b.add_def(nl.names[ni], DEF_NONLOCAL, nl.lineno, nl.col_offset) {
                return False;
            }
            ni = ni + 1;
        }
        return True;
    }
    if isinstance(s, For)
        or isinstance(s, AsyncFor)
        or isinstance(s, While)
        or isinstance(s, If)
        or isinstance(s, Try) {
        body: list[stmt];
        orelse: list[stmt] = [];
        if isinstance(s, For) {
            fo = s as For;
            if not sym_visit_store_target(b, fo.target) {
                return False;
            }
            if not sym_visit_load_expr(b, fo.iter) {
                return False;
            }
            body = fo.body;
            orelse = fo.orelse;
        } elif isinstance(s, AsyncFor) {
            afo = s as AsyncFor;
            if not sym_visit_store_target(b, afo.target) {
                return False;
            }
            if not sym_visit_load_expr(b, afo.iter) {
                return False;
            }
            body = afo.body;
            orelse = afo.orelse;
        } elif isinstance(s, While) {
            wh = s as While;
            if not sym_visit_load_expr(b, wh.`test) {
                return False;
            }
            body = wh.body;
            orelse = wh.orelse;
        } elif isinstance(s, If) {
            iff = s as If;
            if not sym_visit_load_expr(b, iff.`test) {
                return False;
            }
            body = iff.body;
            orelse = iff.orelse;
        } else {
            tr = s as Try;
            body = tr.body;
            orelse = tr.orelse;
            if tr.handlers is not None {
                hi = 0;
                while hi < len(tr.handlers) {
                    h = tr.handlers[hi];
                    if h.type is not None {
                        if not sym_visit_load_expr(b, h.type) {
                            return False;
                        }
                    }
                    if h.name is not None {
                        if not b.add_def(h.name, DEF_LOCAL, h.lineno, h.col_offset) {
                            return False;
                        }
                    }
                    bi = 0;
                    while bi < len(h.body) {
                        if not sym_visit_stmt(b, h.body[bi]) {
                            return False;
                        }
                        bi = bi + 1;
                    }
                    hi = hi + 1;
                }
            }
            fi = 0;
            if tr.finalbody is not None {
                while fi < len(tr.finalbody) {
                    if not sym_visit_stmt(b, tr.finalbody[fi]) {
                        return False;
                    }
                    fi = fi + 1;
                }
            }
        }
        bi = 0;
        while bi < len(body) {
            if not sym_visit_stmt(b, body[bi]) {
                return False;
            }
            bi = bi + 1;
        }
        oi = 0;
        if orelse is not None {
            while oi < len(orelse) {
                if not sym_visit_stmt(b, orelse[oi]) {
                    return False;
                }
                oi = oi + 1;
            }
        }
        return True;
    }
    if isinstance(s, With) {
        wi = s as With;
        ii = 0;
        while ii < len(wi.items) {
            item = wi.items[ii];
            if not sym_visit_load_expr(b, item.context_expr) {
                return False;
            }
            if item.optional_vars is not None {
                if not sym_visit_store_target(b, item.optional_vars) {
                    return False;
                }
            }
            ii = ii + 1;
        }
        bi = 0;
        while bi < len(wi.body) {
            if not sym_visit_stmt(b, wi.body[bi]) {
                return False;
            }
            bi = bi + 1;
        }
        return True;
    }
    if isinstance(s, AsyncWith) {
        async_with_stmt = s as AsyncWith;
        ii = 0;
        while ii < len(async_with_stmt.items) {
            item = async_with_stmt.items[ii];
            if not sym_visit_load_expr(b, item.context_expr) {
                return False;
            }
            if item.optional_vars is not None {
                if not sym_visit_store_target(b, item.optional_vars) {
                    return False;
                }
            }
            ii = ii + 1;
        }
        bi = 0;
        while bi < len(async_with_stmt.body) {
            if not sym_visit_stmt(b, async_with_stmt.body[bi]) {
                return False;
            }
            bi = bi + 1;
        }
        return True;
    }
    if isinstance(s, FunctionDef) {
        fd = s as FunctionDef;
        if not b.add_def(fd.name, DEF_LOCAL, fd.lineno, fd.col_offset) {
            return False;
        }
        decs = fd.decorator_list;
        if decs is None {
            decs = [];
        }
        di = 0;
        while di < len(decs) {
            if not sym_visit_load_expr(b, decs[di]) {
                return False;
            }
            di = di + 1;
        }
        if not sym_visit_arg_defaults(b, fd.args) {
            return False;
        }
        nested = sym_compute_nested(b);
        in_class = b.cur.block_type == "class" or b.cur.can_see_class_scope;
        if not b.push_block(
            "function", fd.name, fd.lineno, nested, in_class, fd.col_offset
        ) {
            return False;
        }
        if not sym_visit_params(b, fd.args) {
            return False;
        }
        bi = 0;
        while bi < len(fd.body) {
            if not sym_visit_stmt(b, fd.body[bi]) {
                return False;
            }
            bi = bi + 1;
        }
        return b.pop_block();
    }
    if isinstance(s, AsyncFunctionDef) {
        afd = s as AsyncFunctionDef;
        if not b.add_def(afd.name, DEF_LOCAL, afd.lineno, afd.col_offset) {
            return False;
        }
        decs = afd.decorator_list;
        if decs is None {
            decs = [];
        }
        di = 0;
        while di < len(decs) {
            if not sym_visit_load_expr(b, decs[di]) {
                return False;
            }
            di = di + 1;
        }
        if not sym_visit_arg_defaults(b, afd.args) {
            return False;
        }
        nested = sym_compute_nested(b);
        in_class = b.cur.block_type == "class" or b.cur.can_see_class_scope;
        if not b.push_block(
            "function", afd.name, afd.lineno, nested, in_class, afd.col_offset
        ) {
            return False;
        }
        b.cur.coroutine = True;
        if not sym_visit_params(b, afd.args) {
            return False;
        }
        bi = 0;
        while bi < len(afd.body) {
            if not sym_visit_stmt(b, afd.body[bi]) {
                return False;
            }
            bi = bi + 1;
        }
        return b.pop_block();
    }
    if isinstance(s, ClassDef) {
        cd = s as ClassDef;
        if not b.add_def(cd.name, DEF_LOCAL, cd.lineno, cd.col_offset) {
            return False;
        }
        # Decorators evaluate in the ENCLOSING scope (CPython symtable.c
        # ClassDef_kind visits decorator_list before entering the class block).
        decs = cd.decorator_list;
        if decs is None {
            decs = [];
        }
        di = 0;
        while di < len(decs) {
            if not sym_visit_load_expr(b, decs[di]) {
                return False;
            }
            di = di + 1;
        }
        if cd.bases is not None {
            for base in cd.bases {
                if not sym_visit_load_expr(b, base) {
                    return False;
                }
            }
        }
        if cd.keywords is not None {
            for kw in cd.keywords {
                if not sym_visit_load_expr(b, kw.value) {
                    return False;
                }
            }
        }
        saved_private = b.private;
        nested = b.cur.block_type != "module";
        if not b.push_block(
            "class", cd.name, cd.lineno, nested, False, cd.col_offset
        ) {
            return False;
        }
        b.private = cd.name;
        bi = 0;
        while bi < len(cd.body) {
            if not sym_visit_stmt(b, cd.body[bi]) {
                b.private = saved_private;
                return False;
            }
            bi = bi + 1;
        }
        b.private = saved_private;
        return b.pop_block();
    }
    if isinstance(s, TypeAlias) {
        ta = s as TypeAlias;
        if not isinstance(ta.name, Name) {
            return b.fail(
                "SyntaxError", "invalid type alias target", ta.lineno, ta.col_offset
            );
        }
        type_alias_name = ta.name as Name;
        tps = ta.type_params;
        if tps is None {
            tps = [];
        }
        if not b.add_def(type_alias_name.id, DEF_LOCAL, ta.lineno, ta.col_offset) {
            return False;
        }
        pi = 0;
        while pi < len(tps) {
            if not isinstance(tps[pi], TypeVar)
                or (tps[pi] as TypeVar).bound is not None
                or (tps[pi] as TypeVar).default_value is not None {
                return b.fail(
                    "NotImplementedError",
                    "type parameter bounds/defaults/ParamSpec/TypeVarTuple "
                        + "are not supported in type aliases yet",
                    ta.lineno,
                    ta.col_offset
                );
            }
            pi = pi + 1;
        }
        nested = sym_compute_nested(b);
        in_class = b.cur.block_type == "class" or b.cur.can_see_class_scope;
        if len(tps) > 0 {
            # PEP 695: the hidden <generic parameters of X> scope binds each
            # type var as a cell; the lazy value function closes over them.
            if not b.push_block(
                "function",
                "<generic parameters of " + type_alias_name.id + ">",
                ta.lineno,
                nested,
                in_class,
                ta.col_offset
            ) {
                return False;
            }
            pi = 0;
            while pi < len(tps) {
                tv = tps[pi] as TypeVar;
                if not b.add_def(tv.name, DEF_LOCAL, tv.lineno, tv.col_offset) {
                    return False;
                }
                pi = pi + 1;
            }
            if not b.push_block(
                "function", type_alias_name.id, ta.lineno, True, in_class, ta.col_offset
            ) {
                return False;
            }
            if not sym_visit_load_expr(b, ta.value) {
                return False;
            }
            if not b.pop_block() {
                return False;
            }
            return b.pop_block();
        }
        # Non-generic: the lazy value scope's only parameter is .format.
        if not b.push_block(
            "function", type_alias_name.id, ta.lineno, nested, in_class, ta.col_offset
        ) {
            return False;
        }
        if not b.add_def(".format", DEF_PARAM, ta.lineno, ta.col_offset) {
            return False;
        }
        if not sym_visit_load_expr(b, ta.value) {
            return False;
        }
        return b.pop_block();
    }
    if isinstance(s, Import) {
        imp = s as Import;
        ni = 0;
        while ni < len(imp.names) {
            bind = sym_import_bind_name(imp.names[ni]);
            if not b.add_def(bind, DEF_LOCAL, imp.lineno, imp.col_offset) {
                return False;
            }
            ni = ni + 1;
        }
        return True;
    }
    if isinstance(s, ImportFrom) {
        imp_from = s as ImportFrom;
        ni = 0;
        while ni < len(imp_from.names) {
            bind = sym_import_bind_name(imp_from.names[ni]);
            if not b.add_def(bind, DEF_LOCAL, imp_from.lineno, imp_from.col_offset) {
                return False;
            }
            ni = ni + 1;
        }
        return True;
    }
    if isinstance(s, Match) {
        m = s as Match;
        if not sym_visit_load_expr(b, m.subject) {
            return False;
        }
        ci = 0;
        while ci < len(m.cases) {
            mc = m.cases[ci];
            if mc.guard is not None {
                if not sym_visit_load_expr(b, mc.guard) {
                    return False;
                }
            }
            if not sym_visit_pattern(b, mc.pattern) {
                return False;
            }
            bi = 0;
            while bi < len(mc.body) {
                if not sym_visit_stmt(b, mc.body[bi]) {
                    return False;
                }
                bi = bi + 1;
            }
            ci = ci + 1;
        }
        return True;
    }
    return True;
}

def sym_directive_loc(block: sym_block, name: str) -> tuple[int, int] {
    if name in block.directive_lineno {
        col = 0;
        if name in block.directive_col {
            col = block.directive_col[name];
        }
        return (block.directive_lineno[name], col);
    }
    return (block.lineno, 0);
}

def sym_analyze_name(
    block: sym_block,
    name: str,
    flags: int,
    bound: dict[str, int] | None,
    local: dict[str, int],
    free: dict[str, int],
    global_set: dict[str, int],
    scopes: dict[str, int],
    class_entry: sym_block | None
) -> compiler_diagnostic | None {
    if sym_flag_set(flags, DEF_GLOBAL) {
        if sym_flag_set(flags, DEF_NONLOCAL) {
            loc = sym_directive_loc(block, name);
            return symbol_diagnostic(
                kind="SyntaxError",
                message="name '" + name + "' is nonlocal and global",
                lineno=loc[0],
                col_offset=loc[1]
            );
        }
        scopes[name] = SCOPE_GLOBAL_EXPLICIT;
        sym_set_add(global_set, name);
        if bound is not None {
            sym_set_discard(bound, name);
        }
        return None;
    }
    if sym_flag_set(flags, DEF_NONLOCAL) {
        if bound is None {
            loc = sym_directive_loc(block, name);
            return symbol_diagnostic(
                kind="SyntaxError",
                message="nonlocal declaration not allowed at module level",
                lineno=loc[0],
                col_offset=loc[1]
            );
        }
        if not sym_set_contains(bound, name) {
            loc = sym_directive_loc(block, name);
            return symbol_diagnostic(
                kind="SyntaxError",
                message="no binding for nonlocal '" + name + "' found",
                lineno=loc[0],
                col_offset=loc[1]
            );
        }
        scopes[name] = SCOPE_FREE;
        sym_set_add(free, name);
        return None;
    }
    if sym_flag_set(flags, DEF_LOCAL) or sym_flag_set(flags, DEF_PARAM) {
        scopes[name] = SCOPE_LOCAL;
        sym_set_add(local, name);
        sym_set_discard(global_set, name);
        return None;
    }
    if class_entry is not None {
        class_flags = sym_dict_get(class_entry.symbols, name, 0);
        if sym_flag_set(class_flags, DEF_GLOBAL) {
            scopes[name] = SCOPE_GLOBAL_EXPLICIT;
            return None;
        }
        if sym_flag_set(class_flags, DEF_BOUND)
            and not sym_flag_set(class_flags, DEF_NONLOCAL) {
            scopes[name] = SCOPE_GLOBAL_IMPLICIT;
            return None;
        }
    }
    if bound is not None and sym_set_contains(bound, name) {
        scopes[name] = SCOPE_FREE;
        sym_set_add(free, name);
        return None;
    }
    if sym_set_contains(global_set, name) {
        scopes[name] = SCOPE_GLOBAL_IMPLICIT;
        return None;
    }
    if block.block_type == "module" {
        scopes[name] = SCOPE_GLOBAL_IMPLICIT;
        return None;
    }
    scopes[name] = SCOPE_GLOBAL_IMPLICIT;
    return None;
}

def sym_analyze_block(
    block: sym_block,
    bound: dict[str, int] | None,
    inherited_global: dict[str, int],
    class_entry: sym_block | None
) -> tuple[dict[str, int], compiler_diagnostic | None] {
    local: dict[str, int] = {};
    free: dict[str, int] = {};
    global_set: dict[str, int] = sym_set_union({}, inherited_global);
    scopes: dict[str, int] = {};
    names = sym_sorted_names(block.symbols);
    ni = 0;
    while ni < len(names) {
        name = names[ni];
        raw = block.symbols[name];
        ad = sym_analyze_name(
            block, name, raw, bound, local, free, global_set, scopes, class_entry
        );
        if ad is not None {
            return ({}, ad);
        }
        ni = ni + 1;
    }
    # Match CPython symtable.c analyze_block: only function-like blocks add their
    # locals to newbound; module/class locals are not closure parents for
    # top-level functions (self-recursion uses LOAD_GLOBAL, not LOAD_DEREF).
    # Class scopes additionally bind the implicit closure names so children
    # resolve them FREE (CPython's special-case before analyzing children).
    newbound: dict[str, int] = {};
    if sym_is_function_like(block) {
        newbound = sym_set_union(newbound, local);
    } elif block.block_type == "class" {
        for dunder in ["__class__", "__classdict__", "__conditional_annotations__"] {
            sym_set_add(newbound, dunder);
        }
    }
    if bound is not None {
        newbound = sym_set_union(newbound, bound);
    }
    child_free: dict[str, int] = {};
    ci = 0;
    while ci < len(block.children) {
        child = block.children[ci];
        child_class: sym_block | None = class_entry;
        if child.can_see_class_scope {
            if block.block_type == "class" {
                child_class = block;
            }
        }
        cf_result = sym_analyze_block(child, newbound, global_set, child_class);
        if cf_result[1] is not None {
            return ({}, cf_result[1]);
        }
        cf = cf_result[0];
        child_free = sym_set_union(child_free, cf);
        ci = ci + 1;
    }
    child_free = sym_set_union(child_free, free);
    if block.block_type == "class" {
        # CPython drop_class_free: the implicit class-scope names never pass a
        # class boundary as free variables; __class__ instead becomes the
        # implicit cell (needs_class_closure) consumed by the body prologue and
        # returned as __classcell__. __classdict__/__conditional_annotations__
        # get their own implicit cells at compile time.
        for dunder in ["__class__", "__classdict__", "__conditional_annotations__"] {
            if sym_set_contains(child_free, dunder) {
                sym_set_discard(child_free, dunder);
                if dunder == "__class__" {
                    block.needs_class_closure = True;
                }
            }
        }
    }
    fk_names = sym_set_keys(child_free);
    fi = 0;
    while fi < len(fk_names) {
        fname = fk_names[fi];
        if sym_set_contains(local, fname) {
            scopes[fname] = SCOPE_CELL;
            sym_set_discard(child_free, fname);
        } elif not sym_set_contains(local, fname)
            and sym_set_contains(newbound, fname) {
            if fname in scopes {
                scopes[fname] = SCOPE_FREE;
            } else {
                block.symbols[fname] = sym_set_scope(
                    sym_flag_add(sym_dict_get(block.symbols, fname, 0), SYM_USE),
                    SCOPE_FREE
                );
            }
        }
        fi = fi + 1;
    }
    for name in scopes.keys() {
        scope = scopes[name];
        raw = sym_dict_get(block.symbols, name, 0);
        block.symbols[name] = sym_set_scope(raw, scope);
    }
    return (child_free, None);
}

def sym_propagate_module_globals(top: sym_block) {
    ci = 0;
    while ci < len(top.children) {
        child = top.children[ci];
        if child.block_type == "function" {
            for name in child.symbols.keys() {
                flags = child.symbols[name];
                if sym_flag_set(flags, DEF_GLOBAL) {
                    cur = sym_dict_get(top.symbols, name, 0);
                    top.symbols[name] = sym_flag_add(cur, DEF_GLOBAL);
                }
            }
        }
        ci = ci + 1;
    }
}

def build_module_symtable(body: list[stmt]) -> symtable_result {
    top = sym_block(block_type="module", name="top", lineno=0, nested=False);
    b = sym_builder(cur=top, stack=[], module_global={}, private=None, diag=None);
    si = 0;
    while si < len(body) {
        if not sym_visit_stmt(b, body[si]) {
            if b.diag is not None {
                return symtable_result(diag=b.diag);
            }
            return symtable_error("SystemError", "symtable visit failed");
        }
        si = si + 1;
    }
    sym_result = sym_analyze_block(top, None, {}, None);
    if sym_result[1] is not None {
        return symtable_result(diag=sym_result[1]);
    }
    sym_propagate_module_globals(top);
    # CPython codegen.c super-call optimization requires 'super' to be unknown
    # at the module top; record that fact on every block so nested units can
    # check it without parent links.
    if sym_dict_get(top.symbols, "super", 0) != 0 {
        sym_mark_top_has_super(top);
    }
    return symtable_ok(top);
}

# Recursively flag every block with the module-top "super" shadowing fact.
def sym_mark_top_has_super(block: sym_block) {
    block.top_has_super = True;
    for child in block.children {
        sym_mark_top_has_super(child);
    }
}
