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


impl UniNode.__repr__ -> str {
    return f"{type(self).__name__}";
}

impl AstSymbolNode.__repr__ -> str {
    return f"{type(self).__name__}";
}

impl AstSymbolStubNode.__repr__ -> str {
    return f"{type(self).__name__}";
}

impl AstAccessNode.access.getter -> (SubTag[Token] | None) {
    found = [self->:AccessRole:->];
    return found[0] if found else None;
}

impl AstAccessNode.__repr__ -> str {
    return f"{type(self).__name__}";
}

impl ContextAwareNode.__repr__ -> str {
    return f"{type(self).__name__}";
}

impl AstDocNode.doc.getter -> (String | None) {
    found = [self->:DocRole:->];
    return found[0] if found else None;
}

impl AstDocNode.__repr__ -> str {
    return f"{type(self).__name__}";
}

impl AstAsyncNode.__repr__ -> str {
    return f"{type(self).__name__}";
}

impl AstElseBodyNode.else_body.getter -> (ElseStmt | ElseIf | None) {
    found = [self->:ElseBodyRole:->];
    return found[0] if found else None;
}

impl AstElseBodyNode.__repr__ -> str {
    return f"{type(self).__name__}";
}

impl AstTypedVarNode.type_tag.getter -> (SubTag[Expr] | None) {
    found = [self->:TypeTagRole:->];
    return found[0] if found else None;
}

impl AstTypedVarNode.__repr__ -> str {
    return f"{type(self).__name__}";
}

impl UniCFGNode.__repr__ -> str {
    return f"{type(self).__name__}";
}

impl ConditionalNode.__repr__ -> str {
    return f"{type(self).__name__}";
}

impl AstImplNeedingNode.body.getter -> (Sequence[UniNode] | UniNode | None) {
    impl_of = [self->:ImplOf:->];
    if impl_of {
        return impl_of[0];
    }
    return self._role_shaped(BodyRole, [self->:BodyRole:->]);
}

impl AstImplNeedingNode.__repr__ -> str {
    return f"{type(self).__name__}";
}

impl Module.body.getter -> Sequence[ElementStmt | String | EmptyToken] {
    return [self->:BodyRole:->];
}

impl Module.__repr__ -> str {
    return UniScopeNode.__repr__(self);
}

impl ProgramModule.main.getter -> Module {
    return [self->:MainRole:->][0];
}

impl ProgramModule.__repr__ -> str {
    return f"{type(self).__name__}";
}

impl EmptyToken.__repr__ -> str {
    return Token.__repr__(self);
}

impl CommentToken.__repr__ -> str {
    return Token.__repr__(self);
}

impl Source.__repr__ -> str {
    return Token.__repr__(self);
}

impl PythonModuleAst.__repr__ -> str {
    return Token.__repr__(self);
}

impl UniScopeNode.init(*, kid: Sequence[UniNode] = []) -> None {
    self._link(kid, {});
    self.postinit();
}

impl AstSymbolNode.init(*, kid: Sequence[UniNode] = []) -> None {
    self._link(kid, {});
    self.postinit();
}

impl AstSymbolStubNode.init(*, kid: Sequence[UniNode] = []) -> None {
    self._link(kid, {});
    self.postinit();
}

impl AstAccessNode.init(
    *, access: (SubTag[Token] | None) = None, kid: Sequence[UniNode] = []
) -> None {
    self._link(kid, {AccessRole: access});
    self.postinit();
}

impl ContextAwareNode.init(
    *, codespace_dual: bool = False, kid: Sequence[UniNode] = []
) -> None {
    self.codespace_dual = codespace_dual;
    self._link(kid, {});
    self.postinit();
}

impl AstDocNode.init(
    *, doc: (String | None) = None, kid: Sequence[UniNode] = []
) -> None {
    self._link(kid, {DocRole: doc});
    self.postinit();
}

impl AstAsyncNode.init(*, is_async: bool = False, kid: Sequence[UniNode] = []) -> None {
    self.is_async = is_async;
    self._link(kid, {});
    self.postinit();
}

impl AstElseBodyNode.init(
    *, else_body: (ElseStmt | ElseIf | None) = None, kid: Sequence[UniNode] = []
) -> None {
    self._link(kid, {ElseBodyRole: else_body});
    self.postinit();
}

impl AstTypedVarNode.init(
    *,
    type_tag: (SubTag[Expr] | None) = None,
    type: (TypeBase | None) = None,
    kid: Sequence[UniNode] = []
) -> None {
    self.type = type;
    self._link(kid, {TypeTagRole: type_tag});
    self.postinit();
}

impl UniCFGNode.init(*, kid: Sequence[UniNode] = []) -> None {
    self._link(kid, {});
    self.postinit();
}

impl ConditionalNode.init(
    *,
    sc_true_target: (UniCFGNode | None) = None,
    sc_false_target: (UniCFGNode | None) = None,
    kid: Sequence[UniNode] = []
) -> None {
    self.sc_true_target = sc_true_target;
    self.sc_false_target = sc_false_target;
    self._link(kid, {});
    self.postinit();
}

impl AstImplNeedingNode.init(
    *, body: (Sequence[UniNode] | UniNode | None), kid: Sequence[UniNode] = []
) -> None {
    self._link(kid, {BodyRole: body});
    self.postinit();
}

impl Module.init(
    *,
    doc: (String | None) = None,
    name: str,
    source: Source,
    body: Sequence[ElementStmt | String | EmptyToken],
    terminals: list[Token],
    stub_only: bool = False,
    src_terminals: list[Token] = [],
    is_raised_from_py: bool = False,
    parse_failed: bool = False,
    mobui_enforced_root: (str | None) = None,
    jac_project_root: (str | None) = None,
    access_enforced: bool = False,
    ct_resolved: bool = False,
    native_viols_reported: bool = False,
    client_viols_reported: bool = False,
    kid: Sequence[UniNode] = []
) -> None {
    self.name = name;
    self.source = source;
    self.terminals = terminals;
    self.stub_only = stub_only;
    self.src_terminals = src_terminals;
    self.is_raised_from_py = is_raised_from_py;
    self.parse_failed = parse_failed;
    self.mobui_enforced_root = mobui_enforced_root;
    self.jac_project_root = jac_project_root;
    self.access_enforced = access_enforced;
    self.ct_resolved = ct_resolved;
    self.native_viols_reported = native_viols_reported;
    self.client_viols_reported = client_viols_reported;
    self._link(kid, {DocRole: doc, BodyRole: body});
    self.postinit();
}

impl ProgramModule.init(
    *, main_mod: (Module | None) = None, kid: Sequence[UniNode] = []
) -> None {
    target = main_mod or Module.make_stub();
    self._link([*kid, target], {MainRole: target});
    self.postinit();
}

impl ProgramModule.main_mod.getter -> (Module | None) {
    found = [self->:MainRole:->][?:Module];
    if not found {
        return None;
    }
    return None if found[0].stub_only else found[0];
}

impl ProgramModule.main_mod.setter(main_mod: (Module | None)) {
    self._role_set(MainRole, main_mod or Module.make_stub());
}
