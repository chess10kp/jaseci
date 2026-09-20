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


impl Expr.__repr__ -> str {
    return f"{type(self).__name__}";
}

impl CfgExpr.expr.getter -> Expr {
    return [self->:ExprRole:->][0];
}

impl CfgExpr.__repr__ -> str {
    return f"{type(self).__name__}";
}

impl NameAtom.__repr__ -> str {
    return f"{type(self).__name__}";
}

impl TypedCtxBlock.type_ctx.getter -> Expr {
    return [self->:TypeCtxRole:->][0];
}

impl TypedCtxBlock.body.getter -> Sequence[CodeBlockStmt] {
    return [self->:BodyRole:->];
}

impl TypedCtxBlock.__repr__ -> str {
    return UniScopeNode.__repr__(self);
}

impl ExprAsItem.expr.getter -> Expr {
    return [self->:ExprRole:->][0];
}

impl ExprAsItem.alias.getter -> (Expr | None) {
    found = [self->:AliasRole:->];
    return found[0] if found else None;
}

impl ExprAsItem.__repr__ -> str {
    return f"{type(self).__name__}";
}

impl AwaitExpr.target.getter -> Expr {
    return [self->:TargetRole:->][0];
}

impl AwaitExpr.__repr__ -> str {
    return f"{type(self).__name__}";
}

impl CastExpr.value.getter -> Expr {
    return [self->:ValueRole:->][0];
}

impl CastExpr.cast_type.getter -> Expr {
    return [self->:CastTypeRole:->][0];
}

impl CastExpr.__repr__ -> str {
    return f"{type(self).__name__}";
}

impl ConcurrentExpr.tok.getter -> (Token | None) {
    found = [self->:TokRole:->];
    return found[0] if found else None;
}

impl ConcurrentExpr.target.getter -> Expr {
    return [self->:TargetRole:->][0];
}

impl ConcurrentExpr.__repr__ -> str {
    return f"{type(self).__name__}";
}

impl BinaryExpr.left.getter -> Expr {
    return [self->:LeftRole:->][0];
}

impl BinaryExpr.right.getter -> Expr {
    return [self->:RightRole:->][0];
}

impl BinaryExpr.op.getter -> Token | DisconnectOp | ConnectOp {
    return [self->:OpRole:->][0];
}

impl BinaryExpr.__repr__ -> str {
    return f"{type(self).__name__}";
}

impl CompareExpr.left.getter -> Expr {
    return [self->:LeftRole:->][0];
}

impl CompareExpr.rights.getter -> list[Expr] {
    return [self->:RightsRole:->];
}

impl CompareExpr.ops.getter -> list[Token] {
    return [self->:OpsRole:->];
}

impl CompareExpr.__repr__ -> str {
    return f"{type(self).__name__}";
}

impl BoolExpr.op.getter -> Token {
    return [self->:OpRole:->][0];
}

impl BoolExpr.values.getter -> list[CfgExpr] {
    return [self->:ValuesRole:->];
}

impl BoolExpr.__repr__ -> str {
    return f"{type(self).__name__}";
}

impl LambdaExpr.body.getter -> (Expr | Sequence[CodeBlockStmt]) {
    return self._role_shaped(BodyRole, [self->:BodyRole:->]);
}

impl LambdaExpr.signature.getter -> (FuncSignature | None) {
    found = [self->:SignatureRole:->];
    return found[0] if found else None;
}

impl LambdaExpr.__repr__ -> str {
    return UniScopeNode.__repr__(self);
}

impl UnaryExpr.operand.getter -> Expr {
    return [self->:OperandRole:->][0];
}

impl UnaryExpr.op.getter -> Token {
    return [self->:OpRole:->][0];
}

impl UnaryExpr.__repr__ -> str {
    return f"{type(self).__name__}";
}

impl IfElseExpr.condition.getter -> CfgExpr {
    return [self->:ConditionRole:->][0];
}

impl IfElseExpr.value.getter -> CfgExpr {
    return [self->:ValueRole:->][0];
}

impl IfElseExpr.else_value.getter -> CfgExpr {
    return [self->:ElseValueRole:->][0];
}

impl IfElseExpr.__repr__ -> str {
    return f"{type(self).__name__}";
}

impl MultiString.strings.getter -> Sequence[(String | FString)] {
    return [self->:StringsRole:->];
}

impl MultiString.__repr__ -> str {
    return f"{type(self).__name__}";
}

impl FString.start.getter -> (Token | None) {
    found = [self->:StartRole:->];
    return found[0] if found else None;
}

impl FString.parts.getter -> Sequence[(String | FormattedValue)] {
    return [self->:PartsRole:->];
}

impl FString.end.getter -> (Token | None) {
    found = [self->:EndRole:->];
    return found[0] if found else None;
}

impl FString.__repr__ -> str {
    return f"{type(self).__name__}";
}

impl FormattedValue.format_part.getter -> Expr {
    return [self->:FormatPartRole:->][0];
}

impl FormattedValue.format_spec.getter -> (Expr | None) {
    found = [self->:FormatSpecRole:->];
    return found[0] if found else None;
}

impl FormattedValue.__repr__ -> str {
    return f"{type(self).__name__}";
}

impl ListVal.values.getter -> Sequence[Expr] {
    return [self->:ValuesRole:->];
}

impl ListVal.__repr__ -> str {
    return f"{type(self).__name__}";
}

impl SetVal.values.getter -> (Sequence[Expr] | None) {
    return [self->:ValuesRole:->];
}

impl SetVal.__repr__ -> str {
    return f"{type(self).__name__}";
}

impl TupleVal.values.getter -> Sequence[(Expr | KWPair)] {
    return [self->:ValuesRole:->];
}

impl TupleVal.__repr__ -> str {
    return f"{type(self).__name__}";
}

impl DictVal.kv_pairs.getter -> Sequence[KVPair] {
    return [self->:KvPairsRole:->];
}

impl DictVal.__repr__ -> str {
    return f"{type(self).__name__}";
}

impl KVPair.key.getter -> (Expr | None) {
    found = [self->:KeyRole:->];
    return found[0] if found else None;
}

impl KVPair.value.getter -> Expr {
    return [self->:ValueRole:->][0];
}

impl KVPair.__repr__ -> str {
    return f"{type(self).__name__}";
}

impl KWPair.key.getter -> (NameAtom | None) {
    found = [self->:KeyRole:->];
    return found[0] if found else None;
}

impl KWPair.value.getter -> Expr {
    return [self->:ValueRole:->][0];
}

impl KWPair.__repr__ -> str {
    return f"{type(self).__name__}";
}

impl InnerCompr.target.getter -> Expr {
    return [self->:TargetRole:->][0];
}

impl InnerCompr.collection.getter -> Expr {
    return [self->:CollectionRole:->][0];
}

impl InnerCompr.conditional.getter -> (list[Expr] | None) {
    return [self->:ConditionalRole:->];
}

impl InnerCompr.__repr__ -> str {
    return UniScopeNode.__repr__(self);
}

impl ListCompr.out_expr.getter -> Expr {
    return [self->:OutExprRole:->][0];
}

impl ListCompr.compr.getter -> list[InnerCompr] {
    return [self->:ComprRole:->];
}

impl ListCompr.__repr__ -> str {
    return UniScopeNode.__repr__(self);
}

impl GenCompr.__repr__ -> str {
    return UniScopeNode.__repr__(self);
}

impl SetCompr.__repr__ -> str {
    return UniScopeNode.__repr__(self);
}

impl DictCompr.kv_pair.getter -> KVPair {
    return [self->:KvPairRole:->][0];
}

impl DictCompr.compr.getter -> list[InnerCompr] {
    return [self->:ComprRole:->];
}

impl DictCompr.__repr__ -> str {
    return UniScopeNode.__repr__(self);
}

impl AtomTrailer.target.getter -> Expr {
    return [self->:TargetRole:->][0];
}

impl AtomTrailer.right.getter -> (AtomExpr | Expr) {
    return [self->:RightRole:->][0];
}

impl AtomTrailer.__repr__ -> str {
    return f"{type(self).__name__}";
}

impl AtomUnit.value.getter -> Expr | YieldExpr | Ability {
    return [self->:ValueRole:->][0];
}

impl AtomUnit.__repr__ -> str {
    return f"{type(self).__name__}";
}

impl FuncCall.target.getter -> Expr {
    return [self->:TargetRole:->][0];
}

impl FuncCall.params.getter -> (Sequence[(Expr | KWPair)] | None) {
    return [self->:ParamsRole:->];
}

impl FuncCall.__repr__ -> str {
    return f"{type(self).__name__}";
}

impl Slice.start.getter -> (Expr | None) {
    found = [self->:StartRole:->];
    return found[0] if found else None;
}

impl Slice.stop.getter -> (Expr | None) {
    found = [self->:StopRole:->];
    return found[0] if found else None;
}

impl Slice.step.getter -> (Expr | None) {
    found = [self->:StepRole:->];
    return found[0] if found else None;
}

impl Slice.__repr__ -> str {
    return f"{type(self).__name__}";
}

impl IndexSlice.slices.getter -> list[Slice] {
    return [self->:SlicesRole:->];
}

impl IndexSlice.__repr__ -> str {
    return f"{type(self).__name__}";
}

impl EdgeRefTrailer.chain.getter -> list[(Expr | FilterCompr)] {
    return [self->:ChainRole:->];
}

impl EdgeRefTrailer.__repr__ -> str {
    return f"{type(self).__name__}";
}

impl EdgeOpRef.filter_cond.getter -> (FilterCompr | None) {
    found = [self->:FilterCondRole:->];
    return found[0] if found else None;
}

impl EdgeOpRef.__repr__ -> str {
    return f"{type(self).__name__}";
}

impl DisconnectOp.edge_spec.getter -> EdgeOpRef {
    return [self->:EdgeSpecRole:->][0];
}

impl DisconnectOp.__repr__ -> str {
    return f"{type(self).__name__}";
}

impl ConnectOp.conn_type.getter -> (Expr | None) {
    found = [self->:ConnTypeRole:->];
    return found[0] if found else None;
}

impl ConnectOp.conn_assign.getter -> (AssignCompr | None) {
    found = [self->:ConnAssignRole:->];
    return found[0] if found else None;
}

impl ConnectOp.__repr__ -> str {
    return f"{type(self).__name__}";
}

impl FilterCompr.f_type.getter -> (Expr | None) {
    found = [self->:FTypeRole:->];
    return found[0] if found else None;
}

impl FilterCompr.compares.getter -> Sequence[Expr] {
    return [self->:ComparesRole:->];
}

impl FilterCompr.__repr__ -> str {
    return f"{type(self).__name__}";
}

impl Name.__repr__ -> str {
    return Token.__repr__(self);
}

impl SpecialVarRef.__repr__ -> str {
    return Token.__repr__(self);
}

impl Literal.__repr__ -> str {
    return Token.__repr__(self);
}

impl BuiltinType.__repr__ -> str {
    return Token.__repr__(self);
}

impl Float.__repr__ -> str {
    return Token.__repr__(self);
}

impl Int.__repr__ -> str {
    return Token.__repr__(self);
}

impl String.__repr__ -> str {
    return Token.__repr__(self);
}

impl Bool.__repr__ -> str {
    return Token.__repr__(self);
}

impl Null.__repr__ -> str {
    return Token.__repr__(self);
}

impl Ellipsis.__repr__ -> str {
    return Token.__repr__(self);
}

impl Semi.__repr__ -> str {
    return Token.__repr__(self);
}

impl Expr.init(*, kid: Sequence[UniNode] = []) -> None {
    self._link(kid, {});
    self.postinit();
}

impl CfgExpr.init(
    *,
    sc_true_target: (UniCFGNode | None) = None,
    sc_false_target: (UniCFGNode | None) = None,
    expr: Expr,
    kid: Sequence[UniNode] = []
) -> None {
    self.sc_true_target = sc_true_target;
    self.sc_false_target = sc_false_target;
    self._link(kid, {ExprRole: expr});
    self.postinit();
}

impl NameAtom.init(
    *,
    is_enum_stmt: bool = False,
    is_getattr_resolved: bool = False,
    kid: Sequence[UniNode] = []
) -> None {
    self.is_enum_stmt = is_enum_stmt;
    self.is_getattr_resolved = is_getattr_resolved;
    self._link(kid, {});
    self.postinit();
}

impl TypedCtxBlock.init(
    *, type_ctx: Expr, body: Sequence[CodeBlockStmt], kid: Sequence[UniNode] = []
) -> None {
    self._link(kid, {TypeCtxRole: type_ctx, BodyRole: body});
    self.postinit();
}

impl ExprAsItem.init(
    *, expr: Expr, alias: (Expr | None), kid: Sequence[UniNode] = []
) -> None {
    self._link(kid, {ExprRole: expr, AliasRole: alias});
    self.postinit();
}

impl AwaitExpr.init(*, target: Expr, kid: Sequence[UniNode] = []) -> None {
    self._link(kid, {TargetRole: target});
    self.postinit();
}

impl CastExpr.init(
    *, value: Expr, cast_type: Expr, kid: Sequence[UniNode] = []
) -> None {
    self._link(kid, {ValueRole: value, CastTypeRole: cast_type});
    self.postinit();
}

impl ConcurrentExpr.init(
    *, tok: (Token | None), target: Expr, kid: Sequence[UniNode] = []
) -> None {
    self._link(kid, {TokRole: tok, TargetRole: target});
    self.postinit();
}

impl BinaryExpr.init(
    *,
    left: Expr,
    right: Expr,
    op: Token | DisconnectOp | ConnectOp,
    kid: Sequence[UniNode] = []
) -> None {
    self._link(kid, {LeftRole: left, RightRole: right, OpRole: op});
    self.postinit();
}

impl CompareExpr.init(
    *, left: Expr, rights: list[Expr], ops: list[Token], kid: Sequence[UniNode] = []
) -> None {
    self._link(kid, {LeftRole: left, RightsRole: rights, OpsRole: ops});
    self.postinit();
}

impl BoolExpr.init(
    *, op: Token, values: list[CfgExpr], kid: Sequence[UniNode] = []
) -> None {
    self._link(kid, {OpRole: op, ValuesRole: values});
    self.postinit();
}

impl LambdaExpr.init(
    *,
    body: (Expr | Sequence[CodeBlockStmt]),
    signature: (FuncSignature | None) = None,
    kid: Sequence[UniNode] = []
) -> None {
    self._link(kid, {BodyRole: body, SignatureRole: signature});
    self.postinit();
}

impl UnaryExpr.init(
    *,
    operand: Expr,
    op: Token,
    ownership: OwnershipKind = OwnershipKind.NONE,
    kid: Sequence[UniNode] = []
) -> None {
    self.ownership = ownership;
    self._link(kid, {OperandRole: operand, OpRole: op});
    self.postinit();
}

impl IfElseExpr.init(
    *,
    condition: CfgExpr,
    value: CfgExpr,
    else_value: CfgExpr,
    kid: Sequence[UniNode] = []
) -> None {
    self._link(
        kid, {ConditionRole: condition, ValueRole: value, ElseValueRole: else_value}
    );
    self.postinit();
}

impl MultiString.init(
    *, strings: Sequence[(String | FString)], kid: Sequence[UniNode] = []
) -> None {
    self._link(kid, {StringsRole: strings});
    self.postinit();
}

impl FString.init(
    *,
    start: (Token | None),
    parts: Sequence[(String | FormattedValue)],
    end: (Token | None),
    kid: Sequence[UniNode] = []
) -> None {
    self._link(kid, {StartRole: start, PartsRole: parts, EndRole: end});
    self.postinit();
}

impl FormattedValue.init(
    *,
    format_part: Expr,
    conversion: int,
    format_spec: (Expr | None),
    kid: Sequence[UniNode] = []
) -> None {
    self.conversion = conversion;
    self._link(kid, {FormatPartRole: format_part, FormatSpecRole: format_spec});
    self.postinit();
}

impl ListVal.init(*, values: Sequence[Expr], kid: Sequence[UniNode] = []) -> None {
    self._link(kid, {ValuesRole: values});
    self.postinit();
}

impl SetVal.init(
    *, values: (Sequence[Expr] | None), kid: Sequence[UniNode] = []
) -> None {
    self._link(kid, {ValuesRole: values});
    self.postinit();
}

impl TupleVal.init(
    *, values: Sequence[(Expr | KWPair)], kid: Sequence[UniNode] = []
) -> None {
    self._link(kid, {ValuesRole: values});
    self.postinit();
}

impl DictVal.init(*, kv_pairs: Sequence[KVPair], kid: Sequence[UniNode] = []) -> None {
    self._link(kid, {KvPairsRole: kv_pairs});
    self.postinit();
}

impl KVPair.init(
    *, key: (Expr | None), value: Expr, kid: Sequence[UniNode] = []
) -> None {
    self._link(kid, {KeyRole: key, ValueRole: value});
    self.postinit();
}

impl KWPair.init(
    *, key: (NameAtom | None), value: Expr, kid: Sequence[UniNode] = []
) -> None {
    self._link(kid, {KeyRole: key, ValueRole: value});
    self.postinit();
}

impl InnerCompr.init(
    *,
    is_async: bool = False,
    target: Expr,
    collection: Expr,
    conditional: (list[Expr] | None),
    kid: Sequence[UniNode] = []
) -> None {
    self.is_async = is_async;
    self._link(
        kid,
        {TargetRole: target, CollectionRole: collection, ConditionalRole: conditional}
    );
    self.postinit();
}

impl ListCompr.init(
    *, out_expr: Expr, compr: list[InnerCompr], kid: Sequence[UniNode] = []
) -> None {
    self._link(kid, {OutExprRole: out_expr, ComprRole: compr});
    self.postinit();
}

impl GenCompr.init(
    *, out_expr: Expr, compr: list[InnerCompr], kid: Sequence[UniNode] = []
) -> None {
    self._link(kid, {OutExprRole: out_expr, ComprRole: compr});
    self.postinit();
}

impl SetCompr.init(
    *, out_expr: Expr, compr: list[InnerCompr], kid: Sequence[UniNode] = []
) -> None {
    self._link(kid, {OutExprRole: out_expr, ComprRole: compr});
    self.postinit();
}

impl DictCompr.init(
    *, kv_pair: KVPair, compr: list[InnerCompr], kid: Sequence[UniNode] = []
) -> None {
    self._link(kid, {KvPairRole: kv_pair, ComprRole: compr});
    self.postinit();
}

impl AtomTrailer.init(
    *,
    target: Expr,
    right: (AtomExpr | Expr),
    is_attr: bool,
    is_null_ok: bool,
    is_genai: bool = False,
    kid: Sequence[UniNode] = []
) -> None {
    self.is_attr = is_attr;
    self.is_null_ok = is_null_ok;
    self.is_genai = is_genai;
    self._link(kid, {TargetRole: target, RightRole: right});
    self.postinit();
}

impl AtomUnit.init(
    *, value: Expr | YieldExpr | Ability, kid: Sequence[UniNode] = []
) -> None {
    self._link(kid, {ValueRole: value});
    self.postinit();
}

impl GraphExpr.init(*, exprs: Sequence[Expr], kid: Sequence[UniNode] = []) -> None {
    self._link(kid, {ExprsRole: exprs});
    self.postinit();
}

impl GraphExpr.exprs.getter -> Sequence[Expr] {
    return [self->:ExprsRole:->];
}

impl GraphExpr.__repr__ -> str {
    return f"GraphExpr(exprs={self.exprs!r})";
}

impl FuncCall.init(
    *,
    target: Expr,
    params: (Sequence[(Expr | KWPair)] | None),
    genai_call: (Expr | None),
    call_kind: (str | None) = None,
    chunks_recv_type: (str | None) = None,
    kid: Sequence[UniNode] = []
) -> None {
    self.genai_call = genai_call;
    self.call_kind = call_kind;
    self.chunks_recv_type = chunks_recv_type;
    self._link(kid, {TargetRole: target, ParamsRole: params});
    self.postinit();
}

impl Slice.init(
    *,
    start: (Expr | None),
    stop: (Expr | None),
    step: (Expr | None),
    kid: Sequence[UniNode] = []
) -> None {
    self._link(kid, {StartRole: start, StopRole: stop, StepRole: step});
    self.postinit();
}

impl IndexSlice.init(
    *, slices: list[Slice], is_range: bool, kid: Sequence[UniNode] = []
) -> None {
    self.is_range = is_range;
    self._link(kid, {SlicesRole: slices});
    self.postinit();
}

impl EdgeRefTrailer.init(
    *,
    chain: list[(Expr | FilterCompr)],
    edges_only: bool,
    is_async: bool,
    kid: Sequence[UniNode] = []
) -> None {
    self.edges_only = edges_only;
    self.is_async = is_async;
    self._link(kid, {ChainRole: chain});
    self.postinit();
}

impl EdgeOpRef.init(
    *, filter_cond: (FilterCompr | None), edge_dir: EdgeDir, kid: Sequence[UniNode] = []
) -> None {
    self.edge_dir = edge_dir;
    self._link(kid, {FilterCondRole: filter_cond});
    self.postinit();
}

impl DisconnectOp.init(*, edge_spec: EdgeOpRef, kid: Sequence[UniNode] = []) -> None {
    self._link(kid, {EdgeSpecRole: edge_spec});
    self.postinit();
}

impl ConnectOp.init(
    *,
    conn_type: (Expr | None),
    conn_assign: (AssignCompr | None),
    edge_dir: EdgeDir,
    kid: Sequence[UniNode] = []
) -> None {
    self.edge_dir = edge_dir;
    self._link(kid, {ConnTypeRole: conn_type, ConnAssignRole: conn_assign});
    self.postinit();
}

impl FilterCompr.init(
    *, f_type: (Expr | None), compares: Sequence[Expr], kid: Sequence[UniNode] = []
) -> None {
    self._link(kid, {FTypeRole: f_type, ComparesRole: compares});
    self.postinit();
}
