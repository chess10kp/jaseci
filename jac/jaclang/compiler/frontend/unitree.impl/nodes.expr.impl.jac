impl NameAtom.bind_sym(
    name_of: AstSymbolNode, sym_name: str, sym_category: SymbolType
) -> None {
    self.name_of = name_of;
    self._sym_name = sym_name;
    self._sym_category = sym_category;
}

impl CfgExpr.postinit -> None {
    UniNode.postinit(self);
    Expr.postinit(self);
    ConditionalNode.postinit(self);
}

impl Expr.postinit -> None {
    self._type_sym_tab = None;
    self._type_cache = None;
    self._type_cache_ok = False;
    self.ct_value = None;
    self.coerce_to = None;
    self.fw = None;
    self.fw_safe = False;
    self.attached_tokens = None;
}

impl NameAtom.postinit -> None {
    self.name_of = self;
    self._sym_name = '';
    self._sym_category = SymbolType.UNKNOWN;
    self._expr_ctx = ExprCtx.LOAD;
    AtomExpr.postinit(self);
}

impl NameAtom.sym_name.getter -> str {
    return self._sym_name;
}

impl NameAtom.sym_category.getter -> SymbolType {
    return self._sym_category;
}

impl NameAtom.create_symbol(
    access: SymbolAccess,
    parent_tab: (UniScopeNode | None) = None,
    imported: bool = False
) -> Symbol {
    sym = Symbol(defn=self, access=access, parent_tab=parent_tab, imported=imported);
    return sym;
}

impl NameAtom.clean_type.getter -> str {
    if self.type {
        return str(self.type).replace('builtins.', '');
    }
    return '';
}

impl NameAtom.sem_token.getter -> (tuple[(SemTokType, SemTokMod)] | None) {
    if isinstance(self.name_of, BuiltinType) {
        return (SemTokType.CLASS, SemTokMod.DECLARATION);
    }
    name_of = self.sym.decl.name_of
        if (self.sym and not isinstance(self.sym.decl.name_of, Name))
        else self.name_of;
    if isinstance(name_of, ModulePath) {
        return (SemTokType.NAMESPACE, SemTokMod.DEFINITION);
    }
    if isinstance(name_of, Archetype) {
        return (SemTokType.CLASS, SemTokMod.DECLARATION);
    }
    if isinstance(name_of, Enum) {
        return (SemTokType.ENUM, SemTokMod.DECLARATION);
    }
    if (isinstance(name_of, Ability) and name_of.is_method) {
        return (SemTokType.METHOD, SemTokMod.DECLARATION);
    }
    if isinstance(name_of, (Ability, Test)) {
        return (SemTokType.FUNCTION, SemTokMod.DECLARATION);
    }
    if isinstance(name_of, ParamVar) {
        return (SemTokType.PARAMETER, SemTokMod.DECLARATION);
    }
    if (self.sym and self.sym_name.isupper()) {
        return (SemTokType.VARIABLE, SemTokMod.READONLY);
    }
    if (
        self.sym
        and (self.sym.decl.name_of == self.sym.decl)
        and (self.sym_name in BUILTIN_CALLABLE_NAMES)
    ) {
        return (SemTokType.FUNCTION, SemTokMod.DEFINITION);
    }
    if self.sym {
        if self.type is not None
            and type(self.type).__name__ in ('FunctionType', 'OverloadedType') {
            return (SemTokType.FUNCTION, SemTokMod.DEFINITION);
        }
        return (SemTokType.PROPERTY, SemTokMod.DEFINITION);
    }

    if self.is_getattr_resolved {
        return (SemTokType.PROPERTY, SemTokMod.DEFINITION);
    }
    return None;
}

impl TypedCtxBlock.postinit -> None {
    UniNode.postinit(self);
    UniScopeNode._init_scope(self, name=f"{self.__class__.__name__}");
    CodeBlockStmt.postinit(self);
    WalkerStmtOnlyNode.postinit(self);
}

impl ExprAsItem.postinit -> None {
    UniNode.postinit(self);
}

impl AwaitExpr.postinit -> None {
    UniNode.postinit(self);
    Expr.postinit(self);
}

impl CastExpr.postinit -> None {
    UniNode.postinit(self);
    Expr.postinit(self);
}

impl ConcurrentExpr.postinit -> None {
    UniNode.postinit(self);
    Expr.postinit(self);
}

impl BinaryExpr.postinit -> None {
    UniNode.postinit(self);
    Expr.postinit(self);
}

impl CompareExpr.postinit -> None {
    UniNode.postinit(self);
    Expr.postinit(self);
}

impl BoolExpr.postinit -> None {
    UniNode.postinit(self);
    Expr.postinit(self);
}

impl LambdaExpr.postinit -> None {
    UniNode.postinit(self);
    Expr.postinit(self);
    UniScopeNode._init_scope(self, name=f"{self.__class__.__name__}");
}

impl LambdaExpr.captures.getter -> list[Symbol] {
    return self.get_enclosing_captures();
}

impl LambdaExpr.tail_return_expr -> Expr | None {
    """Implicit return: a braced body consisting of a single expression
    statement returns that expression's value. Any other body (multiple
    statements, or a non-expression statement) uses an explicit `return`.""";
    if isinstance(self.body, Expr) or not isinstance(self.body, list) {
        return None;
    }
    body: Sequence[CodeBlockStmt] = self.body;
    stmts = [
        s
        for s in body
        if not isinstance(s, Semi)
    ];
    if (len(stmts) == 1 and isinstance(stmts[0], ExprStmt)) {
        return stmts[0].expr;
    }
    if (
        len(stmts) == 1
        and isinstance(stmts[0], ReturnStmt)
        and stmts[0].is_implicit
        and stmts[0].expr is not None
    ) {
        return stmts[0].expr;
    }
    return None;
}

impl UnaryExpr.postinit -> None {
    UniNode.postinit(self);
    Expr.postinit(self);
}

impl IfElseExpr.postinit -> None {
    UniNode.postinit(self);
    Expr.postinit(self);
}

impl MultiString.postinit -> None {
    UniNode.postinit(self);
    Expr.postinit(self);
    AstSymbolStubNode._init_stub(self, sym_type=SymbolType.STRING);
}

impl MultiString.lit_value.getter -> str | bytes {
    text_parts: list[str] = [];
    byte_parts: list[int] = [];
    saw_bytes = False;
    for s in self.strings {
        if isinstance(s, String) {
            part = s.lit_value;
            if isinstance(part, `bytes) {
                raw_bytes: bytes = part;
                saw_bytes = True;
                k = 0;
                while (k < len(raw_bytes)) {
                    byte_parts.append(raw_bytes[k]);
                    k += 1;
                }
            } else {
                raw_text: str = part;
                text_parts.append(raw_text);
            }
        }
    }
    if saw_bytes {
        if text_parts {
            raise ValueError('cannot concatenate bytes and str literals');
        }
        return bytes(byte_parts);
    }
    return ''.join(text_parts);
}

impl FString.postinit -> None {
    UniNode.postinit(self);
    Expr.postinit(self);
    AstSymbolStubNode._init_stub(self, sym_type=SymbolType.STRING);
}

impl FormattedValue.postinit -> None {
    UniNode.postinit(self);
    Expr.postinit(self);
}

impl ListVal.postinit -> None {
    UniNode.postinit(self);
    Expr.postinit(self);
    AstSymbolStubNode._init_stub(self, sym_type=SymbolType.SEQUENCE);
}

impl SetVal.postinit -> None {
    UniNode.postinit(self);
    Expr.postinit(self);
    AstSymbolStubNode._init_stub(self, sym_type=SymbolType.SEQUENCE);
}

impl TupleVal.postinit -> None {
    UniNode.postinit(self);
    Expr.postinit(self);
    AstSymbolStubNode._init_stub(self, sym_type=SymbolType.SEQUENCE);
}

impl DictVal.postinit -> None {
    UniNode.postinit(self);
    Expr.postinit(self);
    AstSymbolStubNode._init_stub(self, sym_type=SymbolType.SEQUENCE);
}

impl KVPair.postinit -> None {
    UniNode.postinit(self);
}

impl KWPair.postinit -> None {
    UniNode.postinit(self);
}

impl InnerCompr.postinit -> None {
    UniNode.postinit(self);
    UniScopeNode._init_scope(self, name=f"{self.__class__.__name__}");
    UniCFGNode.postinit(self);
}

impl ListCompr.postinit -> None {
    UniNode.postinit(self);
    Expr.postinit(self);
    AstSymbolStubNode._init_stub(self, sym_type=SymbolType.SEQUENCE);
    UniScopeNode._init_scope(self, name=f"{self.__class__.__name__}");
    UniCFGNode.postinit(self);
}

impl DictCompr.postinit -> None {
    UniNode.postinit(self);
    Expr.postinit(self);
    AstSymbolStubNode._init_stub(self, sym_type=SymbolType.SEQUENCE);
    UniScopeNode._init_scope(self, name=f"{self.__class__.__name__}");
    UniCFGNode.postinit(self);
}

impl AtomTrailer.postinit -> None {
    UniNode.postinit(self);
    Expr.postinit(self);
}

impl AtomTrailer.as_attr_list.getter -> list[AstSymbolNode] {
    left = self.right if isinstance(self.right, AtomTrailer) else self.target;
    right = self.target if isinstance(self.right, AtomTrailer) else self.right;
    trag_list: list[AstSymbolNode] = [];
    if isinstance(right, AstSymbolNode) {
        trag_list.append(right);
    }
    while (isinstance(left, AtomTrailer) and left.is_attr) {
        if isinstance(left.right, AstSymbolNode) {
            trag_list.insert(0, left.right);
        }
        left = left.target;
    }
    if isinstance(left, AstSymbolNode) {
        trag_list.insert(0, left);
    }
    return trag_list;
}

impl AtomUnit.postinit -> None {
    UniNode.postinit(self);
    Expr.postinit(self);
}

impl GraphExpr.postinit -> None {
    UniNode.postinit(self);
    Expr.postinit(self);
}

impl FuncCall.postinit -> None {
    UniNode.postinit(self);
    Expr.postinit(self);
}

impl Slice.postinit -> None {
    UniNode.postinit(self);
}

impl IndexSlice.postinit -> None {
    UniNode.postinit(self);
    Expr.postinit(self);
    AstSymbolStubNode._init_stub(self, sym_type=SymbolType.SEQUENCE);
}

impl EdgeRefTrailer.postinit -> None {
    UniNode.postinit(self);
    Expr.postinit(self);
}

impl EdgeOpRef.postinit -> None {
    UniNode.postinit(self);
    Expr.postinit(self);
    WalkerStmtOnlyNode.postinit(self);
    AstSymbolStubNode._init_stub(self, sym_type=SymbolType.SEQUENCE);
}

impl DisconnectOp.postinit -> None {
    UniNode.postinit(self);
    WalkerStmtOnlyNode.postinit(self);
}

impl ConnectOp.postinit -> None {
    UniNode.postinit(self);
}

impl FilterCompr.postinit -> None {
    UniNode.postinit(self);
    Expr.postinit(self);
    AstSymbolStubNode._init_stub(self, sym_type=SymbolType.SEQUENCE);
}

impl Name.init(
    orig_src: Source,
    name: str,
    value: str,
    line: int,
    end_line: int,
    col_start: int,
    col_end: int,
    pos_start: int,
    pos_end: int,
    is_enum_stmt: bool = False,
    is_kwesc: bool = False
) -> None {
    self.is_kwesc = is_kwesc;
    self.is_enum_stmt = is_enum_stmt;
    Token.init(
        self,
        orig_src=orig_src,
        name=name,
        value=value,
        line=line,
        end_line=end_line,
        col_start=col_start,
        col_end=col_end,
        pos_start=pos_start,
        pos_end=pos_end
    );
    self.name_of = self;
    self._sym_name = '';
    self._sym_category = SymbolType.UNKNOWN;
    self._expr_ctx = ExprCtx.LOAD;
    Expr.postinit(self);
    AstSymbolNode._init_symbol(
        self, sym_name=value, name_spec=self, sym_category=SymbolType.VAR
    );
}

impl SpecialVarRef.init(var: Name, is_enum_stmt: bool = False) -> None {
    self.orig = var;
    Name.init(
        self,
        orig_src=var.orig_src,
        name=var.name,
        value=self.py_resolve_name(),
        line=var.line_no,
        end_line=var.end_line,
        col_start=var.c_start,
        col_end=var.c_end,
        pos_start=var.pos_start,
        pos_end=var.pos_end,
        is_enum_stmt=is_enum_stmt
    );
    AstSymbolNode._init_symbol(
        self,
        sym_name=self.py_resolve_name(),
        name_spec=self,
        sym_category=SymbolType.VAR
    );
}

impl SpecialVarRef.py_resolve_name -> str {
    if (self.orig.name == Tok.KW_SELF) {
        return 'self';
    }
    if (self.orig.name == Tok.KW_PROPS) {
        return 'props';
    } elif (self.orig.name == Tok.KW_SUPER) {
        return 'super';
    } elif (self.orig.name == Tok.KW_ROOT) {
        return Con.ROOT.value;
    } elif (self.orig.name == Tok.KW_HERE) {
        return Con.HERE.value;
    } elif (self.orig.name == Tok.KW_VISITOR) {
        return Con.VISITOR.value;
    } elif (self.orig.name == Tok.KW_INIT) {
        return 'init';
    } elif (self.orig.name == Tok.KW_POST_INIT) {
        return '__post_init__';
    } else {
        raise NotImplementedError('ICE: Special var reference not implemented');
    }
}

impl Literal.init(
    orig_src: Source,
    name: str,
    value: str,
    line: int,
    end_line: int,
    col_start: int,
    col_end: int,
    pos_start: int,
    pos_end: int
) -> None {
    Token.init(
        self,
        orig_src=orig_src,
        name=name,
        value=value,
        line=line,
        end_line=end_line,
        col_start=col_start,
        col_end=col_end,
        pos_start=pos_start,
        pos_end=pos_end
    );
    AstSymbolStubNode._init_stub(self, sym_type=self.SYMBOL_TYPE);
    Expr.postinit(self);
}

impl Literal.lit_value.getter -> int | str | float | bool | None | type | object {
    raise NotImplementedError;
}

impl BuiltinType.lit_value.getter -> type {
    if (self.value not in Literal.type_map) {
        raise TypeError(f"ICE: {self.value} is not a callable builtin");
    }
    tval = Literal.type_map[self.value];
    if isinstance(tval, type) {
        return tval;
    }
    raise TypeError(f"ICE: {self.value} is not a callable builtin");
}

impl Float.lit_value.getter -> float {
    return float(self.value);
}

impl Int.lit_value.getter -> int {
    return int(self.value, 0);
}

impl String.lit_value.getter -> str | bytes {
    if (self.parent and isinstance(self.parent, FString)) {
        fstring_parent: FString = self.parent;
        is_raw = False;
        if (fstring_parent.start and fstring_parent.start.value) {
            prefix = fstring_parent.start.value.lower();
            is_raw = 'r' in prefix;
        }
        if is_raw {
            return self.value;
        }
        return _decode_str_escapes(self.value);
    }
    return decode_string_literal(self.value);
}

impl Bool.lit_value.getter -> bool {
    return (self.value == 'True');
}

impl Null.lit_value.getter -> None {
    return None;
}

impl Ellipsis.lit_value.getter -> object {
    return ...;
}

impl Semi.init(
    orig_src: Source,
    name: str,
    value: str,
    line: int,
    end_line: int,
    col_start: int,
    col_end: int,
    pos_start: int,
    pos_end: int
) -> None {
    Token.init(
        self,
        orig_src=orig_src,
        name=name,
        value=value,
        line=line,
        end_line=end_line,
        col_start=col_start,
        col_end=col_end,
        pos_start=pos_start,
        pos_end=pos_end
    );
    CodeBlockStmt.postinit(self);
}

impl Expr.type_sym_tab.getter -> (UniScopeNode | None) {
    return self._type_sym_tab;
}

impl Expr.type_sym_tab.setter(type_sym_tab: UniScopeNode) {
    self._type_sym_tab = type_sym_tab;
}

impl FuncCall.callee_decl.getter -> (Ability | None) {
    found = [self->:CalleeDecl:->];
    return found[0] if found else None;
}

impl FuncCall.callee_decl.setter(callee_decl: (Ability | None)) {
    del [edge self->:CalleeDecl:->];
    if callee_decl is not None {
        self +>:CalleeDecl:+> callee_decl;
    }
}

impl NameAtom.sym.getter -> (Symbol | None) {
    found = [self->:SymOf:->];
    return found[0] if found else None;
}

impl NameAtom.sym.setter(sym: Symbol | None) {
    del [edge self->:SymOf:->];
    if sym is not None {
        self +>:SymOf:+> sym;
    }
}

impl NameAtom.expr_ctx.getter -> ExprCtx {
    return self._expr_ctx;
}

impl NameAtom.expr_ctx.setter(expr_ctx: ExprCtx) {
    self._expr_ctx = expr_ctx;
}

impl Expr.type.getter -> (TypeBase | None) {
    if self._type_cache_ok {
        return self._type_cache;
    }
    found = [self->:TypeOf:->];
    self._type_cache = found[0] if found else None;
    self._type_cache_ok = True;
    return self._type_cache;
}

impl Expr.type.setter(type: (TypeBase | None)) -> None {
    del [edge self->:TypeOf:->];
    if type is not None {
        self +>:TypeOf:+> type;
    }
    self._type_cache = type;
    self._type_cache_ok = True;
}

impl Expr.narrowed_type.getter -> (TypeBase | None) {
    found = [self->:NarrowedTypeOf:->];
    return found[0] if found else None;
}

impl Expr.narrowed_type.setter(narrowed_type: (TypeBase | None)) -> None {
    del [edge self->:NarrowedTypeOf:->];
    if narrowed_type is not None {
        self +>:NarrowedTypeOf:+> narrowed_type;
    }
}
