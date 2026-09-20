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


impl JsxElement.name.getter -> (JsxElementName | None) {
    found = [self->:NameRole:->];
    return found[0] if found else None;
}

impl JsxElement.attributes.getter -> (Sequence[JsxAttribute] | None) {
    return [self->:AttributesRole:->];
}

impl JsxElement.children.getter -> (Sequence[(JsxChild | JsxElement)] | None) {
    return [self->:ChildrenRole:->];
}

impl JsxElement.dynamic_tag.getter -> (Expr | None) {
    found = [self->:DynamicTagRole:->];
    return found[0] if found else None;
}

impl JsxElement.__repr__ -> str {
    return f"{type(self).__name__}";
}

impl JsxElementName.parts.getter -> Sequence[(Name | Token)] {
    return [self->:PartsRole:->];
}

impl JsxElementName.__repr__ -> str {
    return f"{type(self).__name__}";
}

impl JsxAttribute.__repr__ -> str {
    return f"{type(self).__name__}";
}

impl JsxSpreadAttribute.expr.getter -> Expr {
    return [self->:ExprRole:->][0];
}

impl JsxSpreadAttribute.__repr__ -> str {
    return f"{type(self).__name__}";
}

impl JsxNormalAttribute.name.getter -> (Name | Token) {
    return [self->:NameRole:->][0];
}

impl JsxNormalAttribute.value.getter -> String | Expr | None {
    found = [self->:ValueRole:->];
    return found[0] if found else None;
}

impl JsxNormalAttribute.__repr__ -> str {
    return f"{type(self).__name__}";
}

impl JsxChild.__repr__ -> str {
    return f"{type(self).__name__}";
}

impl JsxText.__repr__ -> str {
    return f"{type(self).__name__}";
}

impl JsxExpression.expr.getter -> Expr {
    return [self->:ExprRole:->][0];
}

impl JsxExpression.__repr__ -> str {
    return f"{type(self).__name__}";
}

impl JsxSlot.body.getter -> list[UniNode] {
    return [self->:BodyRole:->];
}

impl JsxSlot.__repr__ -> str {
    return f"{type(self).__name__}";
}

impl JsxComment.value.getter -> Token {
    return [self->:ValueRole:->][0];
}

impl JsxComment.__repr__ -> str {
    return f"{type(self).__name__}";
}

impl JsxElement.init(
    *,
    name: (JsxElementName | None),
    attributes: (Sequence[JsxAttribute] | None),
    children: (Sequence[(JsxChild | JsxElement)] | None),
    is_self_closing: bool,
    is_fragment: bool,
    dynamic_tag: (Expr | None) = None,
    kid: Sequence[UniNode] = []
) -> None {
    self.is_self_closing = is_self_closing;
    self.is_fragment = is_fragment;
    self._link(
        kid,
        {
            NameRole: name,
            AttributesRole: attributes,
            ChildrenRole: children,
            DynamicTagRole: dynamic_tag
        }
    );
    self.postinit();
}

impl JsxElementName.init(
    *, parts: Sequence[(Name | Token)], kid: Sequence[UniNode] = []
) -> None {
    self._link(kid, {PartsRole: parts});
    self.postinit();
}

impl JsxAttribute.init(*, kid: Sequence[UniNode] = []) -> None {
    self._link(kid, {});
    self.postinit();
}

impl JsxSpreadAttribute.init(*, expr: Expr, kid: Sequence[UniNode] = []) -> None {
    self._link(kid, {ExprRole: expr});
    self.postinit();
}

impl JsxNormalAttribute.init(
    *,
    name: (Name | Token),
    value: String | Expr | None,
    is_shorthand: bool = False,
    kid: Sequence[UniNode] = []
) -> None {
    self.is_shorthand = is_shorthand;
    self._link(kid, {NameRole: name, ValueRole: value});
    self.postinit();
}

impl JsxChild.init(*, kid: Sequence[UniNode] = []) -> None {
    self._link(kid, {});
    self.postinit();
}

impl JsxText.init(*, value: (str | Token), kid: Sequence[UniNode] = []) -> None {
    self.value = value;
    self._link(kid, {});
    self.postinit();
}

impl JsxExpression.init(*, expr: Expr, kid: Sequence[UniNode] = []) -> None {
    self._link(kid, {ExprRole: expr});
    self.postinit();
}

impl JsxSlot.init(*, body: list[UniNode], kid: Sequence[UniNode] = []) -> None {
    self._link(kid, {BodyRole: body});
    self.postinit();
}

impl JsxComment.init(*, value: Token, kid: Sequence[UniNode] = []) -> None {
    self._link(kid, {ValueRole: value});
    self.postinit();
}
