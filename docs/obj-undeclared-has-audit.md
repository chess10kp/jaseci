# Audit: obj/class init assigning fields not declared in `has` (native-seal E5092 class)

Context: jac0core CModuleAst.init assigned `self.ast` without `has ast`, which
aborted the whole sealed native build (E5092). That one is fixed. This audit
hunts the same class elsewhere.

Method: static scan of every `.jac` decl file for `obj|class X(...)` bodies,
extracting `has`-declared fields (incl. one-level+ base resolution) and every
`self.<f> = ...` assignment inside `def/can init|postinit` bodies (inline or in
`.impl.jac` files). Assigned-but-not-declared = latent native-lowering abort.

## Result

**jac-py/jacpython/**: CLEAN. Zero `init`/`postinit` methods exist anywhere
under jac-py/; objects are constructed purely via `has` declarations. No fixes
needed.

**jac/jaclang/ (core-owned, NOT fixed here)**: 71 findings. Grouped:

### llvm binding + ir backends (py2jac-lifted, no has decls at all) - 52

See full list below under compiler/backends/native/llvm/.

### client tooling - 4

- ViteCompiler.init: _has_pages, compiled_dir, jac_client_compiler, jac_compiler, project_dir, runtime_path, vite_bundler, vite_package_json
- JacClientCompiler.init: _has_pages, asset_processor, compiled_dir, import_processor, jac_compiler, na_wasm_modules, project_dir, runtime_path
- ViteBundler.init: config_loader, config_path, minify, output_dir, project_dir
- ViteClientBundleBuilder.init: vite_minify, vite_output_dir, vite_package_json

### compiler passes/tools - 2

- EsJsxProcessor.init: _view_by_node, es, pass_ref
- SymbolTree.init: kid, name (parent IS declared)

### data - 2

- LazyRefs.init: _done,_query, _resolve
- SessionConflictError.init: blockers, database

### runtime/scale/server/testing - 7

- Jdb.init: prompt (base pdb.Pdb is Python)
- JacAPIServerCore.postinit: server, _metrics (_metrics declared only on composing JacAPIServer, not on this obj)
- S3Storage.init: _public_client
- FileResponse.init: path
- Response.init: content, headers, media_type, status_code, stream
- StreamingResponse.init: stream
- JacTextTestRunner.init: max_failures (base unittest.TextTestRunner is Python)

### test doubles (lower priority) - 4

- FakeNode.init: metadata, spec (scale/tests/deploy/test_cluster_provider.jac)
- Node.init: metadata, provider_id, spec (scale/tests/test_k8s_utils.jac)
- Response.init: items (scale/tests/test_k8s_utils.jac)
- SessionStore.init / _PendingAuth.init (client/targets/desktop/native/oauth_broker.jac)

Note: `_McpState.postinit` (byllm/impl/mcp.impl.jac) assigns `_lock` but its
decl was not found in any .jac file (likely Python-side or local class).

## Full raw list

jac/jaclang/client/impl/compiler.impl.jac:229: ViteCompiler (init): _has_pages, compiled_dir, jac_client_compiler, jac_compiler, project_dir, runtime_path, vite_bundler, vite_package_json
jac/jaclang/client/impl/jac_client_compiler.impl.jac:644: JacClientCompiler (init):_has_pages, asset_processor, compiled_dir, import_processor, jac_compiler, na_wasm_modules, project_dir, runtime_path
jac/jaclang/client/impl/vite_bundler.impl.jac:606: ViteBundler (init): config_loader, config_path, minify, output_dir, project_dir
jac/jaclang/client/impl/vite_client_bundle.impl.jac:82: ViteClientBundleBuilder (init): vite_minify, vite_output_dir, vite_package_json
jac/jaclang/client/targets/desktop/native/oauth_broker.jac:0: SessionStore (inline-init): path
jac/jaclang/client/targets/desktop/native/oauth_broker.jac:0:_PendingAuth (inline-init): max_entries, states, ttl
jac/jaclang/compiler/backends/native/llvm/binding/executionengine.jac:0: ExecutionEngine (inline-init):_modules, static_init_chained, static_init_symbols
jac/jaclang/compiler/backends/native/llvm/binding/ffi.jac:0: ObjectRef (inline-init): _as_parameter_, _capi,_closed, _owned,_ptr
jac/jaclang/compiler/backends/native/llvm/binding/ffi.jac:0: OutputString (inline-init): _as_parameter_, _owned,_ptr
jac/jaclang/compiler/backends/native/llvm/binding/module.jac:0: ModuleRef (inline-init): _context
jac/jaclang/compiler/backends/native/llvm/binding/module.jac:0:_Iterator (inline-init): _parents
jac/jaclang/compiler/backends/native/llvm/binding/newpassmanagers.jac:0: PassBuilder (inline-init):_pto, _time_passes_handler,_tm
jac/jaclang/compiler/backends/native/llvm/binding/newpassmanagers.jac:0: PipelineTuningOptions (inline-init): _speed_level, speed_level
jac/jaclang/compiler/backends/native/llvm/binding/orcjit.jac:0: JITLibraryBuilder (inline-init): __imports
jac/jaclang/compiler/backends/native/llvm/binding/orcjit.jac:0: ResourceTracker (inline-init):__addresses, __name
jac/jaclang/compiler/backends/native/llvm/binding/value.jac:0: ValueRef (inline-init):_kind, _parents
jac/jaclang/compiler/backends/native/llvm/binding/value.jac:0:_ValueIterator (inline-init): _parents
jac/jaclang/compiler/backends/native/llvm/ir/_utils.jac:0: NameScope (inline-init): _basenamemap,_useset
jac/jaclang/compiler/backends/native/llvm/ir/builder.jac:0: IRBuilder (inline-init): _anchor,_block, debug_metadata
jac/jaclang/compiler/backends/native/llvm/ir/context.jac:0: Context (inline-init): identified_types, scope
jac/jaclang/compiler/backends/native/llvm/ir/instructions.jac:0: AllocaInstr (inline-init): align, allocated_type
jac/jaclang/compiler/backends/native/llvm/ir/instructions.jac:0: AtomicRMW (inline-init): operation, ordering
jac/jaclang/compiler/backends/native/llvm/ir/instructions.jac:0: CallInstr (inline-init): arg_attributes, attributes, cconv, fastmath, tail
jac/jaclang/compiler/backends/native/llvm/ir/instructions.jac:0: CompareInstr (inline-init): op
jac/jaclang/compiler/backends/native/llvm/ir/instructions.jac:0: ExtractValue (inline-init): aggregate, indices
jac/jaclang/compiler/backends/native/llvm/ir/instructions.jac:0: GEPInstr (inline-init): inbounds, indices, pointer, source_etype
jac/jaclang/compiler/backends/native/llvm/ir/instructions.jac:0: InlineAsm (inline-init): asm, constraint, function_type, side_effect, type
jac/jaclang/compiler/backends/native/llvm/ir/instructions.jac:0: InsertValue (inline-init): aggregate, indices, value
jac/jaclang/compiler/backends/native/llvm/ir/instructions.jac:0: Instruction (inline-init): flags, operands, opname
jac/jaclang/compiler/backends/native/llvm/ir/instructions.jac:0: LoadInstr (inline-init): align
jac/jaclang/compiler/backends/native/llvm/ir/instructions.jac:0: PhiInstr (inline-init): incomings
jac/jaclang/compiler/backends/native/llvm/ir/instructions.jac:0: StoreInstr (inline-init): align
jac/jaclang/compiler/backends/native/llvm/ir/instructions.jac:0: SwitchInstr (inline-init): cases, default_bb
jac/jaclang/compiler/backends/native/llvm/ir/module.jac:0: Module (inline-init): _metadatacache, context, data_layout, globals, metadata, namedmetadata, scope, triple
jac/jaclang/compiler/backends/native/llvm/ir/types.jac:0: ArrayType (inline-init): count, element
jac/jaclang/compiler/backends/native/llvm/ir/types.jac:0: FunctionType (inline-init): args, var_arg
jac/jaclang/compiler/backends/native/llvm/ir/types.jac:0: IdentifiedStructType (inline-init): context, elements, name
jac/jaclang/compiler/backends/native/llvm/ir/types.jac:0: LiteralStructType (inline-init): elements
jac/jaclang/compiler/backends/native/llvm/ir/types.jac:0: PointerType (inline-init): addrspace
jac/jaclang/compiler/backends/native/llvm/ir/types.jac:0: VectorType (inline-init): count, element
jac/jaclang/compiler/backends/native/llvm/ir/types.jac:0:_Repeat (inline-init): size, value
jac/jaclang/compiler/backends/native/llvm/ir/types.jac:0: _TypedPointerType (inline-init): is_opaque, pointee
jac/jaclang/compiler/backends/native/llvm/ir/values.jac:0: ArgumentAttributes (inline-init): _align,_dereferenceable, _dereferenceable_or_null
jac/jaclang/compiler/backends/native/llvm/ir/values.jac:0: Block (inline-init): instructions, scope, terminator
jac/jaclang/compiler/backends/native/llvm/ir/values.jac:0: Constant (inline-init): constant
jac/jaclang/compiler/backends/native/llvm/ir/values.jac:0: DIToken (inline-init): value
jac/jaclang/compiler/backends/native/llvm/ir/values.jac:0: DIValue (inline-init): is_distinct, kind, operands
jac/jaclang/compiler/backends/native/llvm/ir/values.jac:0: Function (inline-init): args, attributes, blocks, calling_convention, ftype, return_value, scope
jac/jaclang/compiler/backends/native/llvm/ir/values.jac:0: FunctionAttributes (inline-init): _alignstack,_personality
jac/jaclang/compiler/backends/native/llvm/ir/values.jac:0: GlobalValue (inline-init): linkage, section, storage_class
jac/jaclang/compiler/backends/native/llvm/ir/values.jac:0: GlobalVariable (inline-init): addrspace, align, global_constant, initializer, unnamed_addr, value_type
jac/jaclang/compiler/backends/native/llvm/ir/values.jac:0: MDValue (inline-init): operands
jac/jaclang/compiler/backends/native/llvm/ir/values.jac:0: MetaDataArgument (inline-init): wrapped_value
jac/jaclang/compiler/backends/native/llvm/ir/values.jac:0: MetaDataString (inline-init): string
jac/jaclang/compiler/backends/native/llvm/ir/values.jac:0: NamedMetaData (inline-init): operands, parent
jac/jaclang/compiler/backends/native/llvm/ir/values.jac:0: NamedValue (inline-init): parent
jac/jaclang/compiler/backends/native/llvm/ir/values.jac:0:_BaseArgument (inline-init): attributes, parent
jac/jaclang/compiler/passes/ast_gen/impl/jsx_processor.impl.jac:1: EsJsxProcessor (init): _view_by_node, es, pass_ref
jac/jaclang/compiler/tools/impl/treeprinter.impl.jac:1: SymbolTree (init): kid, name
jac/jaclang/data/impl/query_planner.impl.jac:503: LazyRefs (init):_done, _query,_resolve
jac/jaclang/data/impl/store.impl.jac:118: SessionConflictError (init): blockers, database
jac/jaclang/runtime/impl/debugger.impl.jac:1: Jdb (init): prompt
jac/jaclang/scale/server/impl/serve.core.impl.jac:45: JacAPIServerCore (postinit): _metrics, server
jac/jaclang/scale/storage/impl/s3_storage.impl.jac:6: S3Storage (init): _public_client
jac/jaclang/scale/tests/deploy/test_cluster_provider.jac:0: FakeNode (inline-init): metadata, spec
jac/jaclang/scale/tests/test_k8s_utils.jac:0: Node (inline-init): metadata, provider_id, spec
jac/jaclang/scale/tests/test_k8s_utils.jac:0: Response (inline-init): items
jac/jaclang/server/serving/datatypes.jac:0: FileResponse (inline-init): path
jac/jaclang/server/serving/datatypes.jac:0: Response (inline-init): content, headers, media_type, status_code, stream
jac/jaclang/server/serving/datatypes.jac:0: StreamingResponse (inline-init): stream
jac/jaclang/testing/impl/test.impl.jac:78: JacTextTestRunner (init): max_failures
TOTAL: 71

--- impl hits where obj decl NOT found (python bases / local classes) ---
jac/jaclang/byllm/impl/mcp.impl.jac:20: _McpState (postinit): decl-not-found-in-jac, assigns:_lock
