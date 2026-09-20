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


impl ArchSpec.decorators.getter -> (Sequence[Expr] | None) {
    return [self->:DecoratorsRole:->];
}

impl ArchSpec.__repr__ -> str {
    return f"{type(self).__name__}";
}

impl SubTag.__repr__ -> str {
    return f"{type(self).__name__}";
}

impl TypeParam.name.getter -> Name {
    return [self->:NameRole:->][0];
}

impl TypeParam.bound.getter -> (Expr | None) {
    found = [self->:BoundRole:->];
    return found[0] if found else None;
}

impl TypeParam.default_val.getter -> (Expr | None) {
    found = [self->:DefaultValRole:->];
    return found[0] if found else None;
}

impl TypeParam.__repr__ -> str {
    return f"{type(self).__name__}";
}

impl TypeAlias.name.getter -> Name {
    return [self->:NameRole:->][0];
}

impl TypeAlias.type_params.getter -> list[TypeParam] {
    return [self->:TypeParamsRole:->][?:TypeParam];
}

impl TypeAlias.value.getter -> Expr {
    return [self->:ValueRole:->][0];
}

impl TypeAlias.__repr__ -> str {
    return UniScopeNode.__repr__(self);
}

impl ModulePath.path.getter -> (Sequence[(Name | String)] | None) {
    return [self->:PathRole:->];
}

impl ModulePath.alias.getter -> (Name | None) {
    found = [self->:AliasRole:->];
    return found[0] if found else None;
}

impl ModulePath.__repr__ -> str {
    return f"{type(self).__name__}";
}

impl ModuleItem.name.getter -> (Name | Token) {
    return [self->:NameRole:->][0];
}

impl ModuleItem.alias.getter -> (Name | None) {
    found = [self->:AliasRole:->];
    return found[0] if found else None;
}

impl ModuleItem.__repr__ -> str {
    return f"{type(self).__name__}";
}

impl Archetype.name.getter -> Name {
    return [self->:NameRole:->][0];
}

impl Archetype.arch_type.getter -> Token {
    return [self->:ArchTypeRole:->][0];
}

impl Archetype.base_classes.getter -> list[Expr] {
    return [self->:BaseClassesRole:->][?:Expr];
}

impl Archetype.keywords.getter -> (Sequence[KWPair] | None) {
    return [self->:KeywordsRole:->];
}

impl Archetype.type_params.getter -> list[TypeParam] {
    return [self->:TypeParamsRole:->][?:TypeParam];
}

impl Archetype.src_endpoint.getter -> (Expr | None) {
    found = [self->:SrcEndpointRole:->];
    return found[0] if found else None;
}

impl Archetype.tgt_endpoint.getter -> (Expr | None) {
    found = [self->:TgtEndpointRole:->];
    return found[0] if found else None;
}

impl Archetype.__repr__ -> str {
    return UniScopeNode.__repr__(self);
}

impl ImplDef.decl_link.getter -> (UniNode | None) {
    found = [self<-:ImplOf:<-];
    return found[0] if found else None;
}

impl ImplDef.decorators.getter -> (Sequence[Expr] | None) {
    return [self->:DecoratorsRole:->];
}

impl ImplDef.target.getter -> Sequence[NameAtom] {
    return [self->:TargetRole:->];
}

impl ImplDef.spec.getter -> (Sequence[Expr] | FuncSignature | EventSignature | None) {
    return self._role_shaped(SpecRole, [self->:SpecRole:->]);
}

impl ImplDef.body.getter -> Sequence[CodeBlockStmt] | Sequence[EnumBlockStmt] | Expr {
    return self._role_shaped(BodyRole, [self->:BodyRole:->]);
}

impl ImplDef.__repr__ -> str {
    return UniScopeNode.__repr__(self);
}

impl SemDef.target.getter -> Sequence[NameAtom] {
    return [self->:TargetRole:->];
}

impl SemDef.value.getter -> MultiString {
    return [self->:ValueRole:->][0];
}

impl SemDef.__repr__ -> str {
    return UniScopeNode.__repr__(self);
}

impl Enum.name.getter -> Name {
    return [self->:NameRole:->][0];
}

impl Enum.value_type.getter -> (Expr | None) {
    found = [self->:ValueTypeRole:->];
    return found[0] if found else None;
}

impl Enum.base_classes.getter -> list[Expr] {
    return [self->:BaseClassesRole:->][?:Expr];
}

impl Enum.__repr__ -> str {
    return UniScopeNode.__repr__(self);
}

impl Ability.name_ref.getter -> (NameAtom | None) {
    found = [self->:NameRefRole:->];
    return found[0] if found else None;
}

impl Ability.signature.getter -> FuncSignature | EventSignature | None {
    found = [self->:SignatureRole:->];
    return found[0] if found else None;
}

impl Ability.decorators.getter -> (Sequence[Expr] | None) {
    return [self->:DecoratorsRole:->];
}

impl Ability.type_params.getter -> list[TypeParam] {
    return [self->:TypeParamsRole:->][?:TypeParam];
}

impl Ability.__repr__ -> str {
    return UniScopeNode.__repr__(self);
}

impl FuncSignature.posonly_params.getter -> Sequence[ParamVar] {
    return [self->:PosonlyParamsRole:->];
}

impl FuncSignature.params.getter -> (Sequence[ParamVar] | None) {
    return [self->:ParamsRole:->];
}

impl FuncSignature.varargs.getter -> (ParamVar | None) {
    found = [self->:VarargsRole:->];
    return found[0] if found else None;
}

impl FuncSignature.kwonlyargs.getter -> Sequence[ParamVar] {
    return [self->:KwonlyargsRole:->];
}

impl FuncSignature.kwargs.getter -> (ParamVar | None) {
    found = [self->:KwargsRole:->];
    return found[0] if found else None;
}

impl FuncSignature.return_type.getter -> (Expr | None) {
    found = [self->:ReturnTypeRole:->];
    return found[0] if found else None;
}

impl FuncSignature.__repr__ -> str {
    return f"{type(self).__name__}";
}

impl EventSignature.event.getter -> Token {
    return [self->:EventRole:->][0];
}

impl EventSignature.arch_tag_info.getter -> (Expr | None) {
    found = [self->:ArchTagInfoRole:->];
    return found[0] if found else None;
}

impl EventSignature.__repr__ -> str {
    return f"{type(self).__name__}";
}

impl ParamVar.name.getter -> Name {
    return [self->:NameRole:->][0];
}

impl ParamVar.unpack.getter -> (Token | None) {
    found = [self->:UnpackRole:->];
    return found[0] if found else None;
}

impl ParamVar.value.getter -> (Expr | None) {
    found = [self->:ValueRole:->];
    return found[0] if found else None;
}

impl ParamVar.__repr__ -> str {
    return f"{type(self).__name__}";
}

impl ArchHas.vars.getter -> Sequence[HasVar] {
    return [self->:VarsRole:->];
}

impl ArchHas.__repr__ -> str {
    return f"{type(self).__name__}";
}

impl HasVar.name.getter -> Name {
    return [self->:NameRole:->][0];
}

impl HasVar.value.getter -> (Expr | None) {
    found = [self->:ValueRole:->];
    return found[0] if found else None;
}

impl HasVar.accessors.getter -> (Sequence[Ability] | None) {
    return self._role_shaped(AccessorsRole, [self->:AccessorsRole:->]);
}

impl HasVar.__repr__ -> str {
    return f"{type(self).__name__}";
}

impl ArchSpec.init(
    *,
    doc: (String | None) = None,
    is_async: bool = False,
    decorators: (Sequence[Expr] | None),
    kid: Sequence[UniNode] = []
) -> None {
    self.is_async = is_async;
    self._link(kid, {DocRole: doc, DecoratorsRole: decorators});
    self.postinit();
}

impl SubTag.init(
    *,
    tag: T,
    ownership: OwnershipKind = OwnershipKind.NONE,
    linear: bool = False,
    kid: Sequence[UniNode] = []
) -> None {
    self.tag = tag;
    self.ownership = ownership;
    self.linear = linear;
    self._link(kid, {});
    self.postinit();
}

impl TypeParam.init(
    *,
    name: Name,
    bound: (Expr | None),
    default_val: (Expr | None),
    is_comptime: bool = False,
    kid: Sequence[UniNode] = []
) -> None {
    self.is_comptime = is_comptime;
    self._link(kid, {NameRole: name, BoundRole: bound, DefaultValRole: default_val});
    self.postinit();
}

impl TypeAlias.init(
    *,
    doc: (String | None) = None,
    access: (SubTag[Token] | None) = None,
    codespace_dual: bool = False,
    name: Name,
    type_params: (Sequence[TypeParam] | None),
    value: Expr,
    is_distinct: bool = False,
    kid: Sequence[UniNode] = []
) -> None {
    self.codespace_dual = codespace_dual;
    self.is_distinct = is_distinct;
    self._link(
        kid,
        {
            DocRole: doc,
            AccessRole: access,
            NameRole: name,
            TypeParamsRole: type_params,
            ValueRole: value
        }
    );
    self.postinit();
}

impl ModulePath.init(
    *,
    path: (Sequence[(Name | String)] | None),
    level: int,
    alias: (Name | None),
    kid: Sequence[UniNode] = []
) -> None {
    self.level = level;
    self._link(kid, {PathRole: path, AliasRole: alias});
    self.postinit();
}

impl ModuleItem.init(
    *, name: (Name | Token), alias: (Name | None), kid: Sequence[UniNode] = []
) -> None {
    self._link(kid, {NameRole: name, AliasRole: alias});
    self.postinit();
}

impl Archetype.init(
    *,
    doc: (String | None) = None,
    is_async: bool = False,
    body: (Sequence[UniNode] | UniNode | None),
    access: (SubTag[Token] | None) = None,
    decorators: (Sequence[Expr] | None),
    codespace_dual: bool = False,
    name: Name,
    arch_type: Token,
    base_classes: (Sequence[Expr] | None),
    keywords: (Sequence[KWPair] | None) = None,
    type_params: (Sequence[TypeParam] | None) = None,
    src_endpoint: (Expr | None) = None,
    tgt_endpoint: (Expr | None) = None,
    kid: Sequence[UniNode] = []
) -> None {
    self.is_async = is_async;
    self.codespace_dual = codespace_dual;
    self._link(
        kid,
        {
            DocRole: doc,
            BodyRole: body,
            AccessRole: access,
            DecoratorsRole: decorators,
            NameRole: name,
            ArchTypeRole: arch_type,
            BaseClassesRole: base_classes,
            KeywordsRole: keywords,
            TypeParamsRole: type_params,
            SrcEndpointRole: src_endpoint,
            TgtEndpointRole: tgt_endpoint
        }
    );
    self.postinit();
}

impl ImplDef.init(
    *,
    doc: (String | None) = None,
    codespace_dual: bool = False,
    decorators: (Sequence[Expr] | None),
    target: Sequence[NameAtom],
    spec: (Sequence[Expr] | FuncSignature | EventSignature | None),
    body: Sequence[CodeBlockStmt] | Sequence[EnumBlockStmt] | Expr,
    kid: Sequence[UniNode] = []
) -> None {
    self.codespace_dual = codespace_dual;
    self._link(
        kid,
        {
            DocRole: doc,
            DecoratorsRole: decorators,
            TargetRole: target,
            SpecRole: spec,
            BodyRole: body
        }
    );
    self.postinit();
}

impl SemDef.init(
    *,
    doc: (String | None) = None,
    target: Sequence[NameAtom],
    value: MultiString,
    kid: Sequence[UniNode] = []
) -> None {
    self._link(kid, {DocRole: doc, TargetRole: target, ValueRole: value});
    self.postinit();
}

impl Enum.init(
    *,
    doc: (String | None) = None,
    is_async: bool = False,
    body: (Sequence[UniNode] | UniNode | None),
    access: (SubTag[Token] | None) = None,
    decorators: (Sequence[Expr] | None),
    codespace_dual: bool = False,
    name: Name,
    value_type: (Expr | None),
    base_classes: (Sequence[Expr] | None),
    kid: Sequence[UniNode] = []
) -> None {
    self.is_async = is_async;
    self.codespace_dual = codespace_dual;
    self._link(
        kid,
        {
            DocRole: doc,
            BodyRole: body,
            AccessRole: access,
            DecoratorsRole: decorators,
            NameRole: name,
            ValueTypeRole: value_type,
            BaseClassesRole: base_classes
        }
    );
    self.postinit();
}

impl Ability.init(
    *,
    body: (Sequence[UniNode] | UniNode | None),
    is_async: bool = False,
    doc: (String | None) = None,
    access: (SubTag[Token] | None) = None,
    codespace_dual: bool = False,
    name_ref: (NameAtom | None),
    is_override: bool,
    is_static: bool,
    is_classmethod: bool,
    is_abstract: bool,
    signature: FuncSignature | EventSignature | None,
    decorators: (Sequence[Expr] | None) = None,
    type_params: (Sequence[TypeParam] | None) = None,
    accessor_kind: str = "",
    is_comptime: bool = False,
    event_triggers: (list[TypeBase] | None) = None,
    kid: Sequence[UniNode] = []
) -> None {
    self.is_async = is_async;
    self.codespace_dual = codespace_dual;
    self.is_override = is_override;
    self.is_static = is_static;
    self.is_classmethod = is_classmethod;
    self.is_abstract = is_abstract;
    self.accessor_kind = accessor_kind;
    self.is_comptime = is_comptime;
    self.event_triggers = event_triggers;
    self._link(
        kid,
        {
            BodyRole: body,
            DocRole: doc,
            AccessRole: access,
            NameRefRole: name_ref,
            SignatureRole: signature,
            DecoratorsRole: decorators,
            TypeParamsRole: type_params
        }
    );
    self.postinit();
}

impl FuncSignature.init(
    *,
    posonly_params: Sequence[ParamVar],
    params: (Sequence[ParamVar] | None),
    varargs: (ParamVar | None),
    kwonlyargs: Sequence[ParamVar],
    kwargs: (ParamVar | None),
    return_type: (Expr | None),
    kid: Sequence[UniNode] = []
) -> None {
    self._link(
        kid,
        {
            PosonlyParamsRole: posonly_params,
            ParamsRole: params,
            VarargsRole: varargs,
            KwonlyargsRole: kwonlyargs,
            KwargsRole: kwargs,
            ReturnTypeRole: return_type
        }
    );
    self.postinit();
}

impl EventSignature.init(
    *, event: Token, arch_tag_info: (Expr | None), kid: Sequence[UniNode] = []
) -> None {
    self._link(kid, {EventRole: event, ArchTagInfoRole: arch_tag_info});
    self.postinit();
}

impl ParamVar.init(
    *,
    type_tag: (SubTag[Expr] | None) = None,
    type: (TypeBase | None) = None,
    name: Name,
    unpack: (Token | None),
    value: (Expr | None),
    is_comptime: bool = False,
    kid: Sequence[UniNode] = []
) -> None {
    self.type = type;
    self.is_comptime = is_comptime;
    self._link(
        kid,
        {TypeTagRole: type_tag, NameRole: name, UnpackRole: unpack, ValueRole: value}
    );
    self.postinit();
}

impl ArchHas.init(
    *,
    doc: (String | None) = None,
    access: (SubTag[Token] | None) = None,
    is_static: bool,
    vars: Sequence[HasVar],
    is_frozen: bool,
    kid: Sequence[UniNode] = []
) -> None {
    self.is_static = is_static;
    self.is_frozen = is_frozen;
    self._link(kid, {DocRole: doc, AccessRole: access, VarsRole: vars});
    self.postinit();
}

impl HasVar.init(
    *,
    type_tag: (SubTag[Expr] | None) = None,
    type: (TypeBase | None) = None,
    name: Name,
    value: (Expr | None),
    defer: bool,
    accessors: (Sequence[Ability] | None) = None,
    kid: Sequence[UniNode] = []
) -> None {
    self.type = type;
    self.defer = defer;
    self._link(
        kid,
        {
            TypeTagRole: type_tag,
            NameRole: name,
            ValueRole: value,
            AccessorsRole: accessors
        }
    );
    self.postinit();
}
