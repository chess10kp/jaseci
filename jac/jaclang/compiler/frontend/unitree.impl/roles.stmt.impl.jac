import from jaclang.compiler.frontend.roles {
    ImplOf,
    AccessRole,
    AccessorsRole,
    AliasRole,
    ArchTagInfoRole,
    ArchTypeRole,
    ArgPatternsRole,
    AssignmentsRole,
    AssignsRole,
    AttributesRole,
    AugOpRole,
    AwaitingBodyRole,
    BaseClassesRole,
    BodyRole,
    BoundRole,
    CasesRole,
    CastTypeRole,
    CauseRole,
    ChainRole,
    ChildrenRole,
    ClibDeclsRole,
    CodeRole,
    CollectionRole,
    ComparesRole,
    ComprRole,
    ConditionRole,
    ConditionalRole,
    ConnAssignRole,
    ConnTypeRole,
    CountByRole,
    CtrlRole,
    DecoratorsRole,
    DefaultValRole,
    DescriptionRole,
    DocRole,
    DynamicTagRole,
    EdgeSpecRole,
    ElseBodyRole,
    ElseValueRole,
    EndRole,
    ErrorMsgRole,
    EventRole,
    ExTypeRole,
    ExceptsRole,
    ExprRole,
    ExprsRole,
    FTypeRole,
    FilterCondRole,
    FinallyBodyRole,
    FormatPartRole,
    FormatSpecRole,
    FromLocRole,
    FromTargetRole,
    GuardRole,
    HintRole,
    InsertLocRole,
    ItemsRole,
    IterRole,
    KeyRole,
    KeywordsRole,
    KvPairRole,
    KvPairsRole,
    KwPatternsRole,
    KwargsRole,
    KwonlyargsRole,
    LeftRole,
    MainRole,
    NameRole,
    NameRefRole,
    OpRole,
    OperandRole,
    OpsRole,
    OutExprRole,
    ParamsRole,
    PartsRole,
    PathRole,
    PatternRole,
    PatternsRole,
    PosonlyParamsRole,
    ReturnTypeRole,
    RightRole,
    RightsRole,
    SignatureRole,
    SlicesRole,
    SpecRole,
    SrcEndpointRole,
    StartRole,
    StepRole,
    StopRole,
    StringsRole,
    TargetRole,
    TgtEndpointRole,
    TokRole,
    TypeCtxRole,
    TypeParamsRole,
    TypeTagRole,
    UnpackRole,
    ValueRole,
    ValueTypeRole,
    ValuesRole,
    VarargsRole,
    VarsRole
}


impl WalkerStmtOnlyNode.__repr__ -> str {
    return f"{type(self).__name__}";
}

impl EnumBlockStmt.__repr__ -> str {
    return f"{type(self).__name__}";
}

impl CodeBlockStmt.__repr__ -> str {
    return f"{type(self).__name__}";
}

impl GlobalVars.assignments.getter -> Sequence[Assignment] {
    return [self->:AssignmentsRole:->];
}

impl GlobalVars.__repr__ -> str {
    return f"{type(self).__name__}";
}

impl Test.name.getter -> Name {
    return [self->:NameRole:->][0];
}

impl Test.body.getter -> Sequence[CodeBlockStmt] {
    return [self->:BodyRole:->];
}

impl Test.description.getter -> (String | None) {
    found = [self->:DescriptionRole:->];
    return found[0] if found else None;
}

impl Test.decorators.getter -> (Sequence[Expr] | None) {
    return [self->:DecoratorsRole:->];
}

impl Test.__repr__ -> str {
    return UniScopeNode.__repr__(self);
}

impl ModuleCode.name.getter -> (Name | None) {
    found = [self->:NameRole:->];
    return found[0] if found else None;
}

impl ModuleCode.body.getter -> Sequence[CodeBlockStmt] {
    return [self->:BodyRole:->];
}

impl ModuleCode.__repr__ -> str {
    return f"{type(self).__name__}";
}

impl PyInlineCode.code.getter -> Token {
    return [self->:CodeRole:->][0];
}

impl PyInlineCode.__repr__ -> str {
    return f"{type(self).__name__}";
}

impl Import.from_loc.getter -> (ModulePath | None) {
    found = [self->:FromLocRole:->];
    return found[0] if found else None;
}

impl Import.items.getter -> Sequence[(ModuleItem | ModulePath)] {
    return [self->:ItemsRole:->];
}

impl Import.clib_decls.getter -> (Sequence[UniNode] | None) {
    return [self->:ClibDeclsRole:->];
}

impl Import.hint.getter -> (SubTag[Token] | None) {
    found = [self->:HintRole:->];
    return found[0] if found else None;
}

impl Import.__repr__ -> str {
    return f"{type(self).__name__}";
}

impl OpenStmt.target.getter -> Expr {
    return [self->:TargetRole:->][0];
}

impl OpenStmt.body.getter -> Sequence[CodeBlockStmt] {
    return [self->:BodyRole:->];
}

impl OpenStmt.__repr__ -> str {
    return UniScopeNode.__repr__(self);
}

impl IfStmt.condition.getter -> Expr {
    return [self->:ConditionRole:->][0];
}

impl IfStmt.body.getter -> Sequence[CodeBlockStmt] {
    return [self->:BodyRole:->];
}

impl IfStmt.__repr__ -> str {
    return UniScopeNode.__repr__(self);
}

impl ElseIf.__repr__ -> str {
    return UniScopeNode.__repr__(self);
}

impl ElseStmt.body.getter -> Sequence[CodeBlockStmt] {
    return [self->:BodyRole:->];
}

impl ElseStmt.__repr__ -> str {
    return UniScopeNode.__repr__(self);
}

impl ExprStmt.expr.getter -> Expr {
    return [self->:ExprRole:->][0];
}

impl ExprStmt.__repr__ -> str {
    return f"{type(self).__name__}";
}

impl TryStmt.body.getter -> Sequence[CodeBlockStmt] {
    return [self->:BodyRole:->];
}

impl TryStmt.excepts.getter -> Sequence[Except] {
    return [self->:ExceptsRole:->];
}

impl TryStmt.awaiting_body.getter -> (AwaitingClause | None) {
    found = [self->:AwaitingBodyRole:->];
    return found[0] if found else None;
}

impl TryStmt.finally_body.getter -> (FinallyStmt | None) {
    found = [self->:FinallyBodyRole:->];
    return found[0] if found else None;
}

impl TryStmt.__repr__ -> str {
    return UniScopeNode.__repr__(self);
}

impl AwaitingClause.body.getter -> Sequence[CodeBlockStmt] {
    return [self->:BodyRole:->];
}

impl AwaitingClause.__repr__ -> str {
    return UniScopeNode.__repr__(self);
}

impl Except.ex_type.getter -> Expr {
    return [self->:ExTypeRole:->][0];
}

impl Except.name.getter -> (Name | None) {
    found = [self->:NameRole:->];
    return found[0] if found else None;
}

impl Except.body.getter -> Sequence[CodeBlockStmt] {
    return [self->:BodyRole:->];
}

impl Except.__repr__ -> str {
    return UniScopeNode.__repr__(self);
}

impl FinallyStmt.body.getter -> Sequence[CodeBlockStmt] {
    return [self->:BodyRole:->];
}

impl FinallyStmt.__repr__ -> str {
    return UniScopeNode.__repr__(self);
}

impl IterForStmt.iter.getter -> Assignment {
    return [self->:IterRole:->][0];
}

impl IterForStmt.condition.getter -> Expr {
    return [self->:ConditionRole:->][0];
}

impl IterForStmt.count_by.getter -> Assignment {
    return [self->:CountByRole:->][0];
}

impl IterForStmt.body.getter -> Sequence[CodeBlockStmt] {
    return [self->:BodyRole:->];
}

impl IterForStmt.__repr__ -> str {
    return UniScopeNode.__repr__(self);
}

impl InForStmt.target.getter -> Expr {
    return [self->:TargetRole:->][0];
}

impl InForStmt.collection.getter -> Expr {
    return [self->:CollectionRole:->][0];
}

impl InForStmt.body.getter -> Sequence[CodeBlockStmt] {
    return [self->:BodyRole:->];
}

impl InForStmt.__repr__ -> str {
    return UniScopeNode.__repr__(self);
}

impl WhileStmt.condition.getter -> Expr {
    return [self->:ConditionRole:->][0];
}

impl WhileStmt.body.getter -> Sequence[CodeBlockStmt] {
    return [self->:BodyRole:->];
}

impl WhileStmt.__repr__ -> str {
    return UniScopeNode.__repr__(self);
}

impl ForeverStmt.body.getter -> Sequence[CodeBlockStmt] {
    return [self->:BodyRole:->];
}

impl ForeverStmt.__repr__ -> str {
    return UniScopeNode.__repr__(self);
}

impl WithStmt.exprs.getter -> Sequence[ExprAsItem] {
    return [self->:ExprsRole:->];
}

impl WithStmt.body.getter -> Sequence[CodeBlockStmt] {
    return [self->:BodyRole:->];
}

impl WithStmt.__repr__ -> str {
    return UniScopeNode.__repr__(self);
}

impl RaiseStmt.cause.getter -> (Expr | None) {
    found = [self->:CauseRole:->];
    return found[0] if found else None;
}

impl RaiseStmt.from_target.getter -> (Expr | None) {
    found = [self->:FromTargetRole:->];
    return found[0] if found else None;
}

impl RaiseStmt.__repr__ -> str {
    return f"{type(self).__name__}";
}

impl AssertStmt.condition.getter -> Expr {
    return [self->:ConditionRole:->][0];
}

impl AssertStmt.error_msg.getter -> (Expr | None) {
    found = [self->:ErrorMsgRole:->];
    return found[0] if found else None;
}

impl AssertStmt.__repr__ -> str {
    return f"{type(self).__name__}";
}

impl CtrlStmt.ctrl.getter -> Token {
    return [self->:CtrlRole:->][0];
}

impl CtrlStmt.__repr__ -> str {
    return f"{type(self).__name__}";
}

impl DeleteStmt.targets.getter -> list[Expr] {
    return [self->:TargetRole:->];
}

impl DeleteStmt.__repr__ -> str {
    return f"{type(self).__name__}";
}

impl ReportStmt.expr.getter -> Expr {
    return [self->:ExprRole:->][0];
}

impl ReportStmt.__repr__ -> str {
    return f"{type(self).__name__}";
}

impl ReturnStmt.expr.getter -> (Expr | None) {
    found = [self->:ExprRole:->];
    return found[0] if found else None;
}

impl ReturnStmt.__repr__ -> str {
    return f"{type(self).__name__}";
}

impl VisitStmt.insert_loc.getter -> (Expr | None) {
    found = [self->:InsertLocRole:->];
    return found[0] if found else None;
}

impl VisitStmt.target.getter -> Expr {
    return [self->:TargetRole:->][0];
}

impl VisitStmt.__repr__ -> str {
    return f"{type(self).__name__}";
}

impl DisengageStmt.__repr__ -> str {
    return f"{type(self).__name__}";
}

impl Assignment.target.getter -> Sequence[Expr] {
    return [self->:TargetRole:->];
}

impl Assignment.value.getter -> Expr | YieldExpr | None {
    found = [self->:ValueRole:->];
    return found[0] if found else None;
}

impl Assignment.aug_op.getter -> (Token | None) {
    found = [self->:AugOpRole:->];
    return found[0] if found else None;
}

impl Assignment.__repr__ -> str {
    return f"{type(self).__name__}";
}

impl YieldExpr.expr.getter -> (Expr | None) {
    found = [self->:ExprRole:->];
    return found[0] if found else None;
}

impl YieldExpr.__repr__ -> str {
    return f"{type(self).__name__}";
}

impl AssignCompr.assigns.getter -> Sequence[KWPair] {
    return [self->:AssignsRole:->];
}

impl AssignCompr.__repr__ -> str {
    return f"{type(self).__name__}";
}

impl MatchStmt.target.getter -> Expr {
    return [self->:TargetRole:->][0];
}

impl MatchStmt.cases.getter -> list[MatchCase] {
    return [self->:CasesRole:->];
}

impl MatchStmt.__repr__ -> str {
    return f"{type(self).__name__}";
}

impl MatchCase.pattern.getter -> MatchPattern {
    return [self->:PatternRole:->][0];
}

impl MatchCase.guard.getter -> (Expr | None) {
    found = [self->:GuardRole:->];
    return found[0] if found else None;
}

impl MatchCase.body.getter -> list[CodeBlockStmt] {
    return [self->:BodyRole:->];
}

impl MatchCase.__repr__ -> str {
    return UniScopeNode.__repr__(self);
}

impl SwitchStmt.target.getter -> Expr {
    return [self->:TargetRole:->][0];
}

impl SwitchStmt.cases.getter -> list[SwitchCase] {
    return [self->:CasesRole:->];
}

impl SwitchStmt.__repr__ -> str {
    return f"{type(self).__name__}";
}

impl SwitchCase.pattern.getter -> (MatchPattern | None) {
    found = [self->:PatternRole:->];
    return found[0] if found else None;
}

impl SwitchCase.body.getter -> list[CodeBlockStmt] {
    return [self->:BodyRole:->];
}

impl SwitchCase.__repr__ -> str {
    return UniScopeNode.__repr__(self);
}

impl MatchOr.patterns.getter -> list[MatchPattern] {
    return [self->:PatternsRole:->];
}

impl MatchOr.__repr__ -> str {
    return f"{type(self).__name__}";
}

impl MatchAs.name.getter -> NameAtom {
    return [self->:NameRole:->][0];
}

impl MatchAs.pattern.getter -> (MatchPattern | None) {
    found = [self->:PatternRole:->];
    return found[0] if found else None;
}

impl MatchAs.__repr__ -> str {
    return f"{type(self).__name__}";
}

impl MatchWild.__repr__ -> str {
    return f"{type(self).__name__}";
}

impl MatchValue.value.getter -> Expr {
    return [self->:ValueRole:->][0];
}

impl MatchValue.__repr__ -> str {
    return f"{type(self).__name__}";
}

impl MatchSingleton.value.getter -> (Bool | Null) {
    return [self->:ValueRole:->][0];
}

impl MatchSingleton.__repr__ -> str {
    return f"{type(self).__name__}";
}

impl MatchSequence.values.getter -> list[MatchPattern] {
    return [self->:ValuesRole:->];
}

impl MatchSequence.__repr__ -> str {
    return f"{type(self).__name__}";
}

impl MatchMapping.values.getter -> list[(MatchKVPair | MatchStar)] {
    return [self->:ValuesRole:->];
}

impl MatchMapping.__repr__ -> str {
    return f"{type(self).__name__}";
}

impl MatchKVPair.key.getter -> MatchPattern | NameAtom | AtomExpr {
    return [self->:KeyRole:->][0];
}

impl MatchKVPair.value.getter -> MatchPattern {
    return [self->:ValueRole:->][0];
}

impl MatchKVPair.__repr__ -> str {
    return f"{type(self).__name__}";
}

impl MatchStar.name.getter -> NameAtom {
    return [self->:NameRole:->][0];
}

impl MatchStar.__repr__ -> str {
    return f"{type(self).__name__}";
}

impl MatchArch.name.getter -> (AtomTrailer | NameAtom) {
    return [self->:NameRole:->][0];
}

impl MatchArch.arg_patterns.getter -> (Sequence[MatchPattern] | None) {
    return [self->:ArgPatternsRole:->];
}

impl MatchArch.kw_patterns.getter -> (Sequence[MatchKVPair] | None) {
    return [self->:KwPatternsRole:->];
}

impl MatchArch.__repr__ -> str {
    return f"{type(self).__name__}";
}

impl WalkerStmtOnlyNode.init(*, kid: Sequence[UniNode] = []) -> None {
    self._link(kid, {});
    self.postinit();
}

impl EnumBlockStmt.init(
    *, is_enum_stmt: bool = False, kid: Sequence[UniNode] = []
) -> None {
    self.is_enum_stmt = is_enum_stmt;
    self._link(kid, {});
    self.postinit();
}

impl CodeBlockStmt.init(*, kid: Sequence[UniNode] = []) -> None {
    self._link(kid, {});
    self.postinit();
}

impl GlobalVars.init(
    *,
    access: (SubTag[Token] | None) = None,
    doc: (String | None) = None,
    codespace_dual: bool = False,
    assignments: Sequence[Assignment],
    is_frozen: bool,
    kid: Sequence[UniNode] = []
) -> None {
    self.codespace_dual = codespace_dual;
    self.is_frozen = is_frozen;
    self._link(kid, {AccessRole: access, DocRole: doc, AssignmentsRole: assignments});
    self.postinit();
}

impl Test.init(
    *,
    doc: (String | None) = None,
    codespace_dual: bool = False,
    name: Name,
    body: Sequence[CodeBlockStmt],
    description: (String | None) = None,
    decorators: (Sequence[Expr] | None) = None,
    kid: Sequence[UniNode] = []
) -> None {
    self.codespace_dual = codespace_dual;
    self._link(
        kid,
        {
            DocRole: doc,
            NameRole: name,
            BodyRole: body,
            DescriptionRole: description,
            DecoratorsRole: decorators
        }
    );
    self.postinit();
}

impl ModuleCode.init(
    *,
    is_enum_stmt: bool = False,
    doc: (String | None) = None,
    codespace_dual: bool = False,
    name: (Name | None),
    body: Sequence[CodeBlockStmt],
    kid: Sequence[UniNode] = []
) -> None {
    self.is_enum_stmt = is_enum_stmt;
    self.codespace_dual = codespace_dual;
    self._link(kid, {DocRole: doc, NameRole: name, BodyRole: body});
    self.postinit();
}

impl PyInlineCode.init(
    *,
    is_enum_stmt: bool = False,
    doc: (String | None) = None,
    code: Token,
    kid: Sequence[UniNode] = []
) -> None {
    self.is_enum_stmt = is_enum_stmt;
    self._link(kid, {DocRole: doc, CodeRole: code});
    self.postinit();
}

impl Import.init(
    *,
    doc: (String | None) = None,
    codespace_dual: bool = False,
    from_loc: (ModulePath | None),
    items: Sequence[(ModuleItem | ModulePath)],
    is_absorb: bool,
    is_typed: bool = False,
    clib_decls: (Sequence[UniNode] | None) = None,
    is_comptime: bool = False,
    kid: Sequence[UniNode] = []
) -> None {
    self.codespace_dual = codespace_dual;
    self.is_absorb = is_absorb;
    self.is_typed = is_typed;
    self.is_comptime = is_comptime;
    self._link(
        kid,
        {
            DocRole: doc,
            FromLocRole: from_loc,
            ItemsRole: items,
            ClibDeclsRole: clib_decls
        }
    );
    self.postinit();
}

impl OpenStmt.init(
    *, target: Expr, body: Sequence[CodeBlockStmt], kid: Sequence[UniNode] = []
) -> None {
    self._link(kid, {TargetRole: target, BodyRole: body});
    self.postinit();
}

impl IfStmt.init(
    *,
    else_body: (ElseStmt | ElseIf | None) = None,
    condition: Expr,
    body: Sequence[CodeBlockStmt],
    is_comptime: bool = False,
    ct_taken: (bool | None) = None,
    kid: Sequence[UniNode] = []
) -> None {
    self.is_comptime = is_comptime;
    self.ct_taken = ct_taken;
    self._link(
        kid, {ElseBodyRole: else_body, ConditionRole: condition, BodyRole: body}
    );
    self.postinit();
}

impl ElseIf.init(
    *,
    else_body: (ElseStmt | ElseIf | None) = None,
    condition: Expr,
    body: Sequence[CodeBlockStmt],
    kid: Sequence[UniNode] = []
) -> None {
    self._link(
        kid, {ElseBodyRole: else_body, ConditionRole: condition, BodyRole: body}
    );
    self.postinit();
}

impl ElseStmt.init(
    *, body: Sequence[CodeBlockStmt], kid: Sequence[UniNode] = []
) -> None {
    self._link(kid, {BodyRole: body});
    self.postinit();
}

impl ExprStmt.init(
    *, expr: Expr, in_fstring: bool, has_semi: bool = True, kid: Sequence[UniNode] = []
) -> None {
    self.in_fstring = in_fstring;
    self.has_semi = has_semi;
    self._link(kid, {ExprRole: expr});
    self.postinit();
}

impl TryStmt.init(
    *,
    else_body: (ElseStmt | ElseIf | None) = None,
    body: Sequence[CodeBlockStmt],
    excepts: Sequence[Except],
    awaiting_body: (AwaitingClause | None),
    finally_body: (FinallyStmt | None),
    kid: Sequence[UniNode] = []
) -> None {
    self._link(
        kid,
        {
            ElseBodyRole: else_body,
            BodyRole: body,
            ExceptsRole: excepts,
            AwaitingBodyRole: awaiting_body,
            FinallyBodyRole: finally_body
        }
    );
    self.postinit();
}

impl AwaitingClause.init(
    *, body: Sequence[CodeBlockStmt], kid: Sequence[UniNode] = []
) -> None {
    self._link(kid, {BodyRole: body});
    self.postinit();
}

impl Except.init(
    *,
    ex_type: Expr,
    name: (Name | None),
    body: Sequence[CodeBlockStmt],
    kid: Sequence[UniNode] = []
) -> None {
    self._link(kid, {ExTypeRole: ex_type, NameRole: name, BodyRole: body});
    self.postinit();
}

impl FinallyStmt.init(
    *, body: Sequence[CodeBlockStmt], kid: Sequence[UniNode] = []
) -> None {
    self._link(kid, {BodyRole: body});
    self.postinit();
}

impl IterForStmt.init(
    *,
    else_body: (ElseStmt | ElseIf | None) = None,
    is_async: bool = False,
    iter: Assignment,
    condition: Expr,
    count_by: Assignment,
    body: Sequence[CodeBlockStmt],
    kid: Sequence[UniNode] = []
) -> None {
    self.is_async = is_async;
    self._link(
        kid,
        {
            ElseBodyRole: else_body,
            IterRole: iter,
            ConditionRole: condition,
            CountByRole: count_by,
            BodyRole: body
        }
    );
    self.postinit();
}

impl InForStmt.init(
    *,
    else_body: (ElseStmt | ElseIf | None) = None,
    is_async: bool = False,
    target: Expr,
    collection: Expr,
    body: Sequence[CodeBlockStmt],
    is_comptime: bool = False,
    kid: Sequence[UniNode] = []
) -> None {
    self.is_async = is_async;
    self.is_comptime = is_comptime;
    self._link(
        kid,
        {
            ElseBodyRole: else_body,
            TargetRole: target,
            CollectionRole: collection,
            BodyRole: body
        }
    );
    self.postinit();
}

impl WhileStmt.init(
    *,
    else_body: (ElseStmt | ElseIf | None) = None,
    condition: Expr,
    body: Sequence[CodeBlockStmt],
    kid: Sequence[UniNode] = []
) -> None {
    self._link(
        kid, {ElseBodyRole: else_body, ConditionRole: condition, BodyRole: body}
    );
    self.postinit();
}

impl ForeverStmt.init(
    *, body: Sequence[CodeBlockStmt], kid: Sequence[UniNode] = []
) -> None {
    self._link(kid, {BodyRole: body});
    self.postinit();
}

impl WithStmt.init(
    *,
    is_async: bool = False,
    exprs: Sequence[ExprAsItem],
    body: Sequence[CodeBlockStmt],
    kid: Sequence[UniNode] = []
) -> None {
    self.is_async = is_async;
    self._link(kid, {ExprsRole: exprs, BodyRole: body});
    self.postinit();
}

impl RaiseStmt.init(
    *, cause: (Expr | None), from_target: (Expr | None), kid: Sequence[UniNode] = []
) -> None {
    self._link(kid, {CauseRole: cause, FromTargetRole: from_target});
    self.postinit();
}

impl AssertStmt.init(
    *,
    condition: Expr,
    error_msg: (Expr | None),
    is_comptime: bool = False,
    kid: Sequence[UniNode] = []
) -> None {
    self.is_comptime = is_comptime;
    self._link(kid, {ConditionRole: condition, ErrorMsgRole: error_msg});
    self.postinit();
}

impl CtrlStmt.init(*, ctrl: Token, kid: Sequence[UniNode] = []) -> None {
    self._link(kid, {CtrlRole: ctrl});
    self.postinit();
}

impl DeleteStmt.init(*, targets: list[Expr], kid: Sequence[UniNode] = []) -> None {
    self._link(kid, {TargetRole: targets});
    self.postinit();
}

impl ReportStmt.init(*, expr: Expr, kid: Sequence[UniNode] = []) -> None {
    self._link(kid, {ExprRole: expr});
    self.postinit();
}

impl ReturnStmt.init(
    *, expr: (Expr | None), is_implicit: bool = False, kid: Sequence[UniNode] = []
) -> None {
    self.is_implicit = is_implicit;
    self._link(kid, {ExprRole: expr});
    self.postinit();
}

impl VisitStmt.init(
    *,
    else_body: (ElseStmt | ElseIf | None) = None,
    insert_loc: (Expr | None),
    target: Expr,
    kid: Sequence[UniNode] = []
) -> None {
    self._link(
        kid, {ElseBodyRole: else_body, InsertLocRole: insert_loc, TargetRole: target}
    );
    self.postinit();
}

impl DisengageStmt.init(*, kid: Sequence[UniNode] = []) -> None {
    self._link(kid, {});
    self.postinit();
}

impl Assignment.init(
    *,
    is_enum_stmt: bool = False,
    type_tag: (SubTag[Expr] | None) = None,
    type: (TypeBase | None) = None,
    target: Sequence[Expr],
    value: Expr | YieldExpr | None,
    mutable: bool = True,
    aug_op: (Token | None) = None,
    na_move_lowerable: bool = False,
    na_overwrite_consumed: bool = False,
    na_flow_reduce: str = "",
    is_comptime: bool = False,
    kid: Sequence[UniNode] = []
) -> None {
    self.is_enum_stmt = is_enum_stmt;
    self.type = type;
    self.mutable = mutable;
    self.na_move_lowerable = na_move_lowerable;
    self.na_overwrite_consumed = na_overwrite_consumed;
    self.na_flow_reduce = na_flow_reduce;
    self.is_comptime = is_comptime;
    self._link(
        kid,
        {TypeTagRole: type_tag, TargetRole: target, ValueRole: value, AugOpRole: aug_op}
    );
    self.postinit();
}

impl YieldExpr.init(
    *, expr: (Expr | None), with_from: bool, kid: Sequence[UniNode] = []
) -> None {
    self.with_from = with_from;
    self._link(kid, {ExprRole: expr});
    self.postinit();
}

impl AssignCompr.init(
    *, assigns: Sequence[KWPair], kid: Sequence[UniNode] = []
) -> None {
    self._link(kid, {AssignsRole: assigns});
    self.postinit();
}

impl MatchStmt.init(
    *, target: Expr, cases: list[MatchCase], kid: Sequence[UniNode] = []
) -> None {
    self._link(kid, {TargetRole: target, CasesRole: cases});
    self.postinit();
}

impl MatchCase.init(
    *,
    pattern: MatchPattern,
    guard: (Expr | None),
    body: list[CodeBlockStmt],
    kid: Sequence[UniNode] = []
) -> None {
    self._link(kid, {PatternRole: pattern, GuardRole: guard, BodyRole: body});
    self.postinit();
}

impl SwitchStmt.init(
    *, target: Expr, cases: list[SwitchCase], kid: Sequence[UniNode] = []
) -> None {
    self._link(kid, {TargetRole: target, CasesRole: cases});
    self.postinit();
}

impl SwitchCase.init(
    *,
    pattern: (MatchPattern | None),
    body: list[CodeBlockStmt],
    kid: Sequence[UniNode] = []
) -> None {
    self._link(kid, {PatternRole: pattern, BodyRole: body});
    self.postinit();
}

impl MatchOr.init(
    *, patterns: list[MatchPattern], kid: Sequence[UniNode] = []
) -> None {
    self._link(kid, {PatternsRole: patterns});
    self.postinit();
}

impl MatchAs.init(
    *, name: NameAtom, pattern: (MatchPattern | None), kid: Sequence[UniNode] = []
) -> None {
    self._link(kid, {NameRole: name, PatternRole: pattern});
    self.postinit();
}

impl MatchWild.init(*, kid: Sequence[UniNode] = []) -> None {
    self._link(kid, {});
    self.postinit();
}

impl MatchValue.init(*, value: Expr, kid: Sequence[UniNode] = []) -> None {
    self._link(kid, {ValueRole: value});
    self.postinit();
}

impl MatchSingleton.init(*, value: (Bool | Null), kid: Sequence[UniNode] = []) -> None {
    self._link(kid, {ValueRole: value});
    self.postinit();
}

impl MatchSequence.init(
    *, values: list[MatchPattern], kid: Sequence[UniNode] = []
) -> None {
    self._link(kid, {ValuesRole: values});
    self.postinit();
}

impl MatchMapping.init(
    *, values: list[(MatchKVPair | MatchStar)], kid: Sequence[UniNode] = []
) -> None {
    self._link(kid, {ValuesRole: values});
    self.postinit();
}

impl MatchKVPair.init(
    *,
    key: MatchPattern | NameAtom | AtomExpr,
    value: MatchPattern,
    kid: Sequence[UniNode] = []
) -> None {
    self._link(kid, {KeyRole: key, ValueRole: value});
    self.postinit();
}

impl MatchStar.init(
    *, name: NameAtom, is_list: bool, kid: Sequence[UniNode] = []
) -> None {
    self.is_list = is_list;
    self._link(kid, {NameRole: name});
    self.postinit();
}

impl MatchArch.init(
    *,
    name: (AtomTrailer | NameAtom),
    arg_patterns: (Sequence[MatchPattern] | None),
    kw_patterns: (Sequence[MatchKVPair] | None),
    kid: Sequence[UniNode] = []
) -> None {
    self._link(
        kid,
        {NameRole: name, ArgPatternsRole: arg_patterns, KwPatternsRole: kw_patterns}
    );
    self.postinit();
}
