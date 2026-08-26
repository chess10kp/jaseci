# Obj-decl seal audit: init assigning fields not declared in `has`

Branch: `worker2/050-obj-field-seal-audit` (off origin/jac-python @ 8481147fa)

## Why

Root cause of the 2026-08-25 CI outage: `CModuleAst.init` did `self.ast = ast` without
`has ast`, so the native seal could not lower the field assignment (E5092 at
`jac/jaclang/jac0core/impl/unitree.impl.jac:2652`) and aborted the whole sealed build
(fixed in dbd8e55a4 / 77ef99776). This audit hunts the same class repo-wide.

## Method

Structural scan of every `obj|node|edge|walker|class` decl: collect declared `has` fields
(incl. `postinit` and property-style decls), resolve bases (same-file first, then unique
cross-file name), diff against every `self.<f> = ...` inside `init`/`postinit` bodies and
top-level `impl X.init/postinit` blocks. Validator run against the pre-fix tree flags exactly
the original CModuleAst bug (`unitree.impl.jac:2652`) and nothing else.

## Result: jac-py is CLEAN

**`jac-py/jacpython/*.jac`: 0 findings** (417 objs scanned). No fixes needed on this lane.
jac-py objs declare all fields via `has` and initialize through factory functions + `has`
defaults; there are zero init/postinit bodies doing field assignment. The Python-style
`class:` host bridges in ceval.jac etc. are transitional host-compile bridges (already
allowlisted from the seal) and use CPython colon-syntax bodies, out of E5092 scope.

## Core-owned findings (126 non-LLVM + 126 LLVM binding hits)

Each row is a latent E5092-class native-lowering abort if the containing module ever joins
the native seal. Fix pattern mirrors dbd8e55a4: add the missing `has <f>: <type>` (mirror a
sibling field). Spot-verified genuine at call site: `SessionConflictError.database/blockers`,
`Response.content/status_code/media_type/headers/stream`, `ExecutionContext.base_path_dir/
full_target_path`, `Model.supports_native_tools/api_key`, `TypeEvaluator.*_module` family,
`SymbolTree.kid/name`.

### byllm/impl/mcp.impl.jac (1)

| location | obj | undeclared field assigned |
|---|---|---|
| `jac/jaclang/byllm/impl/mcp.impl.jac:104` | `McpClient` | `_id` |

### byllm/llm.impl/local.impl.jac (1)

| location | obj | undeclared field assigned |
|---|---|---|
| `jac/jaclang/byllm/llm.impl/local.impl.jac:27` | `LocalLLM` | `supports_native_tools` |

### byllm/llm.impl/model.impl.jac (3)

| location | obj | undeclared field assigned |
|---|---|---|
| `jac/jaclang/byllm/llm.impl/model.impl.jac:38` | `Model` | `supports_native_tools` |
| `jac/jaclang/byllm/llm.impl/model.impl.jac:40` | `Model` | `supports_native_tools` |
| `jac/jaclang/byllm/llm.impl/model.impl.jac:8` | `Model` | `api_key` |

### client/impl/compiler.impl.jac (10)

| location | obj | undeclared field assigned |
|---|---|---|
| `jac/jaclang/client/impl/compiler.impl.jac:268` | `ViteCompiler` | `vite_package_json` |
| `jac/jaclang/client/impl/compiler.impl.jac:275` | `ViteCompiler` | `project_dir` |
| `jac/jaclang/client/impl/compiler.impl.jac:277` | `ViteCompiler` | `project_dir` |
| `jac/jaclang/client/impl/compiler.impl.jac:279` | `ViteCompiler` | `project_dir` |
| `jac/jaclang/client/impl/compiler.impl.jac:281` | `ViteCompiler` | `runtime_path` |
| `jac/jaclang/client/impl/compiler.impl.jac:282` | `ViteCompiler` | `jac_client_compiler` |
| `jac/jaclang/client/impl/compiler.impl.jac:293` | `ViteCompiler` | `compiled_dir` |
| `jac/jaclang/client/impl/compiler.impl.jac:294` | `ViteCompiler` | `jac_compiler` |
| `jac/jaclang/client/impl/compiler.impl.jac:297` | `ViteCompiler` | `vite_bundler` |
| `jac/jaclang/client/impl/compiler.impl.jac:298` | `ViteCompiler` | `_has_pages` |

### client/impl/jac_client_compiler.impl.jac (8)

| location | obj | undeclared field assigned |
|---|---|---|
| `jac/jaclang/client/impl/jac_client_compiler.impl.jac:703` | `JacClientCompiler` | `project_dir` |
| `jac/jaclang/client/impl/jac_client_compiler.impl.jac:704` | `JacClientCompiler` | `runtime_path` |
| `jac/jaclang/client/impl/jac_client_compiler.impl.jac:705` | `JacClientCompiler` | `compiled_dir` |
| `jac/jaclang/client/impl/jac_client_compiler.impl.jac:708` | `JacClientCompiler` | `jac_compiler` |
| `jac/jaclang/client/impl/jac_client_compiler.impl.jac:711` | `JacClientCompiler` | `import_processor` |
| `jac/jaclang/client/impl/jac_client_compiler.impl.jac:712` | `JacClientCompiler` | `asset_processor` |
| `jac/jaclang/client/impl/jac_client_compiler.impl.jac:713` | `JacClientCompiler` | `_has_pages` |
| `jac/jaclang/client/impl/jac_client_compiler.impl.jac:715` | `JacClientCompiler` | `na_wasm_modules` |

### client/impl/vite_bundler.impl.jac (5)

| location | obj | undeclared field assigned |
|---|---|---|
| `jac/jaclang/client/impl/vite_bundler.impl.jac:1157` | `ViteBundler` | `project_dir` |
| `jac/jaclang/client/impl/vite_bundler.impl.jac:1158` | `ViteBundler` | `minify` |
| `jac/jaclang/client/impl/vite_bundler.impl.jac:1159` | `ViteBundler` | `config_path` |
| `jac/jaclang/client/impl/vite_bundler.impl.jac:1160` | `ViteBundler` | `config_loader` |
| `jac/jaclang/client/impl/vite_bundler.impl.jac:1162` | `ViteBundler` | `output_dir` |

### client/impl/vite_client_bundle.impl.jac (3)

| location | obj | undeclared field assigned |
|---|---|---|
| `jac/jaclang/client/impl/vite_client_bundle.impl.jac:97` | `ViteClientBundleBuilder` | `vite_output_dir` |
| `jac/jaclang/client/impl/vite_client_bundle.impl.jac:98` | `ViteClientBundleBuilder` | `vite_package_json` |
| `jac/jaclang/client/impl/vite_client_bundle.impl.jac:99` | `ViteClientBundleBuilder` | `vite_minify` |

### client/targets/desktop/native/oauth_broker.jac (4)

| location | obj | undeclared field assigned |
|---|---|---|
| `jac/jaclang/client/targets/desktop/native/oauth_broker.jac:33` | `SessionStore` | `path` |
| `jac/jaclang/client/targets/desktop/native/oauth_broker.jac:70` | `_PendingAuth` | `ttl` |
| `jac/jaclang/client/targets/desktop/native/oauth_broker.jac:71` | `_PendingAuth` | `max_entries` |
| `jac/jaclang/client/targets/desktop/native/oauth_broker.jac:73` | `_PendingAuth` | `states` |

### compiler/backends/es/impl/scoped_styles.impl.jac (1)

| location | obj | undeclared field assigned |
|---|---|---|
| `jac/jaclang/compiler/backends/es/impl/scoped_styles.impl.jac:10` | `ScopedStyleSheet` | `scoped_css` |

### compiler/backends/native/impl/na_compile_pass.impl.jac (1)

| location | obj | undeclared field assigned |
|---|---|---|
| `jac/jaclang/compiler/backends/native/impl/na_compile_pass.impl.jac:649` | `_DepBinding` | `source_module` |

### compiler/backends/native/na_ir_gen/core.impl.jac (5)

| location | obj | undeclared field assigned |
|---|---|---|
| `jac/jaclang/compiler/backends/native/na_ir_gen/core.impl.jac:12` | `NaIRGenCore` | `_rc_debug_codegen` |
| `jac/jaclang/compiler/backends/native/na_ir_gen/core.impl.jac:35` | `NaIRGenCore` | `di_file` |
| `jac/jaclang/compiler/backends/native/na_ir_gen/core.impl.jac:38` | `NaIRGenCore` | `di_cu` |
| `jac/jaclang/compiler/backends/native/na_ir_gen/core.impl.jac:52` | `NaIRGenCore` | `di_file` |
| `jac/jaclang/compiler/backends/native/na_ir_gen/core.impl.jac:53` | `NaIRGenCore` | `di_cu` |

### compiler/driver/progstate.jac (2)

| location | obj | undeclared field assigned |
|---|---|---|
| `jac/jaclang/compiler/driver/progstate.jac:192` | `BuildScratch` | `na_dep_inflight` |
| `jac/jaclang/compiler/driver/progstate.jac:193` | `BuildScratch` | `na_verdict_resolving` |

### compiler/passes/ast_gen/impl/jsx_processor.impl.jac (3)

| location | obj | undeclared field assigned |
|---|---|---|
| `jac/jaclang/compiler/passes/ast_gen/impl/jsx_processor.impl.jac:2` | `EsJsxProcessor` | `pass_ref` |
| `jac/jaclang/compiler/passes/ast_gen/impl/jsx_processor.impl.jac:4` | `EsJsxProcessor` | `es` |
| `jac/jaclang/compiler/passes/ast_gen/impl/jsx_processor.impl.jac:6` | `EsJsxProcessor` | `_view_by_node` |

### compiler/passes/impl/layout_pass.impl.jac (2)

| location | obj | undeclared field assigned |
|---|---|---|
| `jac/jaclang/compiler/passes/impl/layout_pass.impl.jac:5` | `LayoutPass` | `registry` |
| `jac/jaclang/compiler/passes/impl/layout_pass.impl.jac:6` | `LayoutPass` | `isinstance_targets` |

### compiler/tools/impl/treeprinter.impl.jac (2)

| location | obj | undeclared field assigned |
|---|---|---|
| `jac/jaclang/compiler/tools/impl/treeprinter.impl.jac:8` | `SymbolTree` | `kid` |
| `jac/jaclang/compiler/tools/impl/treeprinter.impl.jac:9` | `SymbolTree` | `name` |

### compiler/types/type_evaluator.impl/type_evaluator.impl.jac (13)

| location | obj | undeclared field assigned |
|---|---|---|
| `jac/jaclang/compiler/types/type_evaluator.impl/type_evaluator.impl.jac:4149` | `TypeEvaluator` | `_ENUM_STUB_FILE_PATH` |
| `jac/jaclang/compiler/types/type_evaluator.impl/type_evaluator.impl.jac:4153` | `TypeEvaluator` | `prefetch` |
| `jac/jaclang/compiler/types/type_evaluator.impl/type_evaluator.impl.jac:4154` | `TypeEvaluator` | `_flow_pending_symbols` |
| `jac/jaclang/compiler/types/type_evaluator.impl/type_evaluator.impl.jac:4155` | `TypeEvaluator` | `_flow_pending_keys` |
| `jac/jaclang/compiler/types/type_evaluator.impl/type_evaluator.impl.jac:4156` | `TypeEvaluator` | `_modules_in_compile` |
| `jac/jaclang/compiler/types/type_evaluator.impl/type_evaluator.impl.jac:4158` | `TypeEvaluator` | `typing_module` |
| `jac/jaclang/compiler/types/type_evaluator.impl/type_evaluator.impl.jac:4159` | `TypeEvaluator` | `types_module` |
| `jac/jaclang/compiler/types/type_evaluator.impl/type_evaluator.impl.jac:4160` | `TypeEvaluator` | `enum_module` |
| `jac/jaclang/compiler/types/type_evaluator.impl/type_evaluator.impl.jac:4171` | `TypeEvaluator` | `builtins_module` |
| `jac/jaclang/compiler/types/type_evaluator.impl/type_evaluator.impl.jac:4172` | `TypeEvaluator` | `jac_builtins_module` |
| `jac/jaclang/compiler/types/type_evaluator.impl/type_evaluator.impl.jac:4175` | `TypeEvaluator` | `dom_types_module` |
| `jac/jaclang/compiler/types/type_evaluator.impl/type_evaluator.impl.jac:4177` | `TypeEvaluator` | `na_builtins_module` |
| `jac/jaclang/compiler/types/type_evaluator.impl/type_evaluator.impl.jac:4179` | `TypeEvaluator` | `js_globals_module` |

### data/impl/query_planner.impl.jac (3)

| location | obj | undeclared field assigned |
|---|---|---|
| `jac/jaclang/data/impl/query_planner.impl.jac:514` | `LazyRefs` | `_resolve` |
| `jac/jaclang/data/impl/query_planner.impl.jac:515` | `LazyRefs` | `_query` |
| `jac/jaclang/data/impl/query_planner.impl.jac:516` | `LazyRefs` | `_done` |

### data/impl/store.impl.jac (15)

| location | obj | undeclared field assigned |
|---|---|---|
| `jac/jaclang/data/impl/store.impl.jac:159` | `PgStore` | `_conn` |
| `jac/jaclang/data/impl/store.impl.jac:160` | `PgStore` | `_side_conn` |
| `jac/jaclang/data/impl/store.impl.jac:161` | `PgStore` | `_lock` |
| `jac/jaclang/data/impl/store.impl.jac:162` | `PgStore` | `_server_version` |
| `jac/jaclang/data/impl/store.impl.jac:163` | `PgStore` | `_in_txn` |
| `jac/jaclang/data/impl/store.impl.jac:164` | `PgStore` | `_isolation` |
| `jac/jaclang/data/impl/store.impl.jac:165` | `PgStore` | `_known_types` |
| `jac/jaclang/data/impl/store.impl.jac:166` | `PgStore` | `_listeners` |
| `jac/jaclang/data/impl/store.impl.jac:167` | `PgStore` | `_listen_thread` |
| `jac/jaclang/data/impl/store.impl.jac:168` | `PgStore` | `_listen_stop` |
| `jac/jaclang/data/impl/store.impl.jac:169` | `PgStore` | `_booted` |
| `jac/jaclang/data/impl/store.impl.jac:170` | `PgStore` | `_ready` |
| `jac/jaclang/data/impl/store.impl.jac:171` | `PgStore` | `_readying` |
| `jac/jaclang/data/impl/store.impl.jac:207` | `SessionConflictError` | `database` |
| `jac/jaclang/data/impl/store.impl.jac:208` | `SessionConflictError` | `blockers` |

### lsp/protocol/impl/server.impl.jac (4)

| location | obj | undeclared field assigned |
|---|---|---|
| `jac/jaclang/lsp/protocol/impl/server.impl.jac:279` | `Workspace` | `_position_codec` |
| `jac/jaclang/lsp/protocol/impl/server.impl.jac:281` | `Workspace` | `_root_path` |
| `jac/jaclang/lsp/protocol/impl/server.impl.jac:283` | `Workspace` | `_root_path` |
| `jac/jaclang/lsp/protocol/impl/server.impl.jac:316` | `LanguageServer` | `_write_lock` |

### lsp/server/impl/engine.impl.jac (5)

| location | obj | undeclared field assigned |
|---|---|---|
| `jac/jaclang/lsp/server/impl/engine.impl.jac:20` | `JacLangServer` | `_write_lock` |
| `jac/jaclang/lsp/server/impl/engine.impl.jac:24` | `JacLangServer` | `_state_lock` |
| `jac/jaclang/lsp/server/impl/engine.impl.jac:25` | `JacLangServer` | `module_manager` |
| `jac/jaclang/lsp/server/impl/engine.impl.jac:27` | `JacLangServer` | `_idle_event` |
| `jac/jaclang/lsp/server/impl/engine.impl.jac:30` | `JacLangServer` | `worker_future` |

### runtime/impl/context.impl.jac (4)

| location | obj | undeclared field assigned |
|---|---|---|
| `jac/jaclang/runtime/impl/context.impl.jac:15` | `ExecutionContext` | `base_path_dir` |
| `jac/jaclang/runtime/impl/context.impl.jac:16` | `ExecutionContext` | `full_target_path` |
| `jac/jaclang/runtime/impl/context.impl.jac:21` | `ExecutionContext` | `base_path_dir` |
| `jac/jaclang/runtime/impl/context.impl.jac:24` | `ExecutionContext` | `full_target_path` |

### runtime/impl/debugger.impl.jac (1)

| location | obj | undeclared field assigned |
|---|---|---|
| `jac/jaclang/runtime/impl/debugger.impl.jac:3` | `Jdb` | `prompt` |

### scale/admin/impl/llm_telemetry.impl.jac (1)

| location | obj | undeclared field assigned |
|---|---|---|
| `jac/jaclang/scale/admin/impl/llm_telemetry.impl.jac:557` | `JacLLMLogger` | `store` |

### scale/deploy/database/kubernetes_postgres.jac (1)

| location | obj | undeclared field assigned |
|---|---|---|
| `jac/jaclang/scale/deploy/database/kubernetes_postgres.jac:20` | `KubernetesPostgresProvider` | `app_name` |

### scale/events/streams/local.jac (2)

| location | obj | undeclared field assigned |
|---|---|---|
| `jac/jaclang/scale/events/streams/local.jac:28` | `LocalEventStream` | `_default_group` |
| `jac/jaclang/scale/events/streams/local.jac:31` | `LocalEventStream` | `_default_retry` |

### scale/events/streams/postgres.jac (1)

| location | obj | undeclared field assigned |
|---|---|---|
| `jac/jaclang/scale/events/streams/postgres.jac:61` | `PgEventStream` | `_consumer_name` |

### scale/identity/impl/user_manager.impl.jac (2)

| location | obj | undeclared field assigned |
|---|---|---|
| `jac/jaclang/scale/identity/impl/user_manager.impl.jac:40` | `JacScaleUserManager` | `_identity_storage` |
| `jac/jaclang/scale/identity/impl/user_manager.impl.jac:41` | `JacScaleUserManager` | `_gateway_owned_identity` |

### scale/observability/prometheus_metrics.jac (10)

| location | obj | undeclared field assigned |
|---|---|---|
| `jac/jaclang/scale/observability/prometheus_metrics.jac:103` | `PrometheusMetricsCollector` | `_ws_connections_active` |
| `jac/jaclang/scale/observability/prometheus_metrics.jac:109` | `PrometheusMetricsCollector` | `_ws_broadcasts_total` |
| `jac/jaclang/scale/observability/prometheus_metrics.jac:42` | `PrometheusMetricsCollector` | `_enabled` |
| `jac/jaclang/scale/observability/prometheus_metrics.jac:43` | `PrometheusMetricsCollector` | `_namespace` |
| `jac/jaclang/scale/observability/prometheus_metrics.jac:44` | `PrometheusMetricsCollector` | `_include_walker_metrics` |
| `jac/jaclang/scale/observability/prometheus_metrics.jac:51` | `PrometheusMetricsCollector` | `_registry` |
| `jac/jaclang/scale/observability/prometheus_metrics.jac:72` | `PrometheusMetricsCollector` | `_request_count` |
| `jac/jaclang/scale/observability/prometheus_metrics.jac:79` | `PrometheusMetricsCollector` | `_request_latency` |
| `jac/jaclang/scale/observability/prometheus_metrics.jac:87` | `PrometheusMetricsCollector` | `_active_requests` |
| `jac/jaclang/scale/observability/prometheus_metrics.jac:94` | `PrometheusMetricsCollector` | `_walker_latency` |

### scale/server/impl/serve.core.impl.jac (2)

| location | obj | undeclared field assigned |
|---|---|---|
| `jac/jaclang/scale/server/impl/serve.core.impl.jac:62` | `JacAPIServerCore` | `server` |
| `jac/jaclang/scale/server/impl/serve.core.impl.jac:96` | `JacAPIServerCore` | `_metrics` |

### scale/storage/impl/s3_storage.impl.jac (1)

| location | obj | undeclared field assigned |
|---|---|---|
| `jac/jaclang/scale/storage/impl/s3_storage.impl.jac:28` | `S3Storage` | `_public_client` |

### server/impl/server.impl.jac (2)

| location | obj | undeclared field assigned |
|---|---|---|
| `jac/jaclang/server/impl/server.impl.jac:600` | `ModuleIntrospector` | `_bundle_builder` |
| `jac/jaclang/server/impl/server.impl.jac:601` | `ModuleIntrospector` | `_bundle_lock` |

### server/serving/datatypes.jac (7)

| location | obj | undeclared field assigned |
|---|---|---|
| `jac/jaclang/server/serving/datatypes.jac:233` | `Response` | `content` |
| `jac/jaclang/server/serving/datatypes.jac:234` | `Response` | `status_code` |
| `jac/jaclang/server/serving/datatypes.jac:235` | `Response` | `media_type` |
| `jac/jaclang/server/serving/datatypes.jac:236` | `Response` | `headers` |
| `jac/jaclang/server/serving/datatypes.jac:237` | `Response` | `stream` |
| `jac/jaclang/server/serving/datatypes.jac:330` | `FileResponse` | `path` |
| `jac/jaclang/server/serving/datatypes.jac:360` | `StreamingResponse` | `stream` |

### testing/impl/test.impl.jac (1)

| location | obj | undeclared field assigned |
|---|---|---|
| `jac/jaclang/testing/impl/test.impl.jac:83` | `JacTextTestRunner` | `max_failures` |

### compiler/backends/native/llvm/** (126 hits)

The llvmlite port classes (`ir/values.jac`, `ir/instructions.jac`, `ir/types.jac`,
`ir/module.jac`, `binding/*.jac`) systematically assign init fields with no `has` decls.
These look like wholesale py-to-jac lifts of llvmlite; if they are meant to stay
CPython-hosted they should be explicitly excluded from any future seal expansion, otherwise
each needs its has-block authored. Full list:

| location | obj | undeclared field assigned |
|---|---|---|
| `jac/jaclang/compiler/backends/native/llvm/binding/executionengine.jac:77` | `ExecutionEngine` | `_modules` |
| `jac/jaclang/compiler/backends/native/llvm/binding/executionengine.jac:79` | `ExecutionEngine` | `static_init_symbols` |
| `jac/jaclang/compiler/backends/native/llvm/binding/executionengine.jac:80` | `ExecutionEngine` | `static_init_chained` |
| `jac/jaclang/compiler/backends/native/llvm/binding/ffi.jac:153` | `OutputString` | `_ptr` |
| `jac/jaclang/compiler/backends/native/llvm/binding/ffi.jac:154` | `OutputString` | `_as_parameter_` |
| `jac/jaclang/compiler/backends/native/llvm/binding/ffi.jac:155` | `OutputString` | `_owned` |
| `jac/jaclang/compiler/backends/native/llvm/binding/ffi.jac:228` | `ObjectRef` | `_closed` |
| `jac/jaclang/compiler/backends/native/llvm/binding/ffi.jac:229` | `ObjectRef` | `_owned` |
| `jac/jaclang/compiler/backends/native/llvm/binding/ffi.jac:230` | `ObjectRef` | `_ptr` |
| `jac/jaclang/compiler/backends/native/llvm/binding/ffi.jac:231` | `ObjectRef` | `_as_parameter_` |
| `jac/jaclang/compiler/backends/native/llvm/binding/ffi.jac:232` | `ObjectRef` | `_capi` |
| `jac/jaclang/compiler/backends/native/llvm/binding/module.jac:231` | `_Iterator` | `_parents` |
| `jac/jaclang/compiler/backends/native/llvm/binding/module.jac:64` | `ModuleRef` | `_context` |
| `jac/jaclang/compiler/backends/native/llvm/binding/newpassmanagers.jac:602` | `PipelineTuningOptions` | `_speed_level` |
| `jac/jaclang/compiler/backends/native/llvm/binding/newpassmanagers.jac:603` | `PipelineTuningOptions` | `speed_level` |
| `jac/jaclang/compiler/backends/native/llvm/binding/newpassmanagers.jac:692` | `PassBuilder` | `_pto` |
| `jac/jaclang/compiler/backends/native/llvm/binding/newpassmanagers.jac:693` | `PassBuilder` | `_tm` |
| `jac/jaclang/compiler/backends/native/llvm/binding/newpassmanagers.jac:694` | `PassBuilder` | `_time_passes_handler` |
| `jac/jaclang/compiler/backends/native/llvm/binding/orcjit.jac:219` | `ResourceTracker` | `__addresses` |
| `jac/jaclang/compiler/backends/native/llvm/binding/orcjit.jac:220` | `ResourceTracker` | `__name` |
| `jac/jaclang/compiler/backends/native/llvm/binding/orcjit.jac:43` | `JITLibraryBuilder` | `__imports` |
| `jac/jaclang/compiler/backends/native/llvm/binding/value.jac:439` | `_ValueIterator` | `_parents` |
| `jac/jaclang/compiler/backends/native/llvm/binding/value.jac:95` | `ValueRef` | `_kind` |
| `jac/jaclang/compiler/backends/native/llvm/binding/value.jac:96` | `ValueRef` | `_parents` |
| `jac/jaclang/compiler/backends/native/llvm/ir/_utils.jac:5` | `NameScope` | `_useset` |
| `jac/jaclang/compiler/backends/native/llvm/ir/_utils.jac:6` | `NameScope` | `_basenamemap` |
| `jac/jaclang/compiler/backends/native/llvm/ir/builder.jac:67` | `IRBuilder` | `_block` |
| `jac/jaclang/compiler/backends/native/llvm/ir/builder.jac:68` | `IRBuilder` | `_anchor` |
| `jac/jaclang/compiler/backends/native/llvm/ir/builder.jac:69` | `IRBuilder` | `debug_metadata` |
| `jac/jaclang/compiler/backends/native/llvm/ir/context.jac:5` | `Context` | `scope` |
| `jac/jaclang/compiler/backends/native/llvm/ir/context.jac:6` | `Context` | `identified_types` |
| `jac/jaclang/compiler/backends/native/llvm/ir/instructions.jac:124` | `CallInstr` | `cconv` |
| `jac/jaclang/compiler/backends/native/llvm/ir/instructions.jac:134` | `CallInstr` | `tail` |
| `jac/jaclang/compiler/backends/native/llvm/ir/instructions.jac:135` | `CallInstr` | `fastmath` |
| `jac/jaclang/compiler/backends/native/llvm/ir/instructions.jac:136` | `CallInstr` | `attributes` |
| `jac/jaclang/compiler/backends/native/llvm/ir/instructions.jac:137` | `CallInstr` | `arg_attributes` |
| `jac/jaclang/compiler/backends/native/llvm/ir/instructions.jac:31` | `Instruction` | `opname` |
| `jac/jaclang/compiler/backends/native/llvm/ir/instructions.jac:320` | `SwitchInstr` | `default_bb` |
| `jac/jaclang/compiler/backends/native/llvm/ir/instructions.jac:321` | `SwitchInstr` | `cases` |
| `jac/jaclang/compiler/backends/native/llvm/ir/instructions.jac:32` | `Instruction` | `operands` |
| `jac/jaclang/compiler/backends/native/llvm/ir/instructions.jac:33` | `Instruction` | `flags` |
| `jac/jaclang/compiler/backends/native/llvm/ir/instructions.jac:436` | `CompareInstr` | `op` |
| `jac/jaclang/compiler/backends/native/llvm/ir/instructions.jac:541` | `LoadInstr` | `align` |
| `jac/jaclang/compiler/backends/native/llvm/ir/instructions.jac:566` | `StoreInstr` | `align` |
| `jac/jaclang/compiler/backends/native/llvm/ir/instructions.jac:595` | `AllocaInstr` | `allocated_type` |
| `jac/jaclang/compiler/backends/native/llvm/ir/instructions.jac:596` | `AllocaInstr` | `align` |
| `jac/jaclang/compiler/backends/native/llvm/ir/instructions.jac:626` | `GEPInstr` | `source_etype` |
| `jac/jaclang/compiler/backends/native/llvm/ir/instructions.jac:645` | `GEPInstr` | `source_etype` |
| `jac/jaclang/compiler/backends/native/llvm/ir/instructions.jac:650` | `GEPInstr` | `pointer` |
| `jac/jaclang/compiler/backends/native/llvm/ir/instructions.jac:651` | `GEPInstr` | `indices` |
| `jac/jaclang/compiler/backends/native/llvm/ir/instructions.jac:652` | `GEPInstr` | `inbounds` |
| `jac/jaclang/compiler/backends/native/llvm/ir/instructions.jac:676` | `PhiInstr` | `incomings` |
| `jac/jaclang/compiler/backends/native/llvm/ir/instructions.jac:719` | `ExtractValue` | `aggregate` |
| `jac/jaclang/compiler/backends/native/llvm/ir/instructions.jac:720` | `ExtractValue` | `indices` |
| `jac/jaclang/compiler/backends/native/llvm/ir/instructions.jac:762` | `InsertValue` | `aggregate` |
| `jac/jaclang/compiler/backends/native/llvm/ir/instructions.jac:763` | `InsertValue` | `value` |
| `jac/jaclang/compiler/backends/native/llvm/ir/instructions.jac:764` | `InsertValue` | `indices` |
| `jac/jaclang/compiler/backends/native/llvm/ir/instructions.jac:796` | `InlineAsm` | `type` |
| `jac/jaclang/compiler/backends/native/llvm/ir/instructions.jac:797` | `InlineAsm` | `function_type` |
| `jac/jaclang/compiler/backends/native/llvm/ir/instructions.jac:798` | `InlineAsm` | `asm` |
| `jac/jaclang/compiler/backends/native/llvm/ir/instructions.jac:799` | `InlineAsm` | `constraint` |
| `jac/jaclang/compiler/backends/native/llvm/ir/instructions.jac:800` | `InlineAsm` | `side_effect` |
| `jac/jaclang/compiler/backends/native/llvm/ir/instructions.jac:833` | `AtomicRMW` | `operation` |
| `jac/jaclang/compiler/backends/native/llvm/ir/instructions.jac:834` | `AtomicRMW` | `ordering` |
| `jac/jaclang/compiler/backends/native/llvm/ir/module.jac:10` | `Module` | `scope` |
| `jac/jaclang/compiler/backends/native/llvm/ir/module.jac:11` | `Module` | `triple` |
| `jac/jaclang/compiler/backends/native/llvm/ir/module.jac:12` | `Module` | `globals` |
| `jac/jaclang/compiler/backends/native/llvm/ir/module.jac:13` | `Module` | `metadata` |
| `jac/jaclang/compiler/backends/native/llvm/ir/module.jac:14` | `Module` | `namedmetadata` |
| `jac/jaclang/compiler/backends/native/llvm/ir/module.jac:15` | `Module` | `_metadatacache` |
| `jac/jaclang/compiler/backends/native/llvm/ir/module.jac:7` | `Module` | `context` |
| `jac/jaclang/compiler/backends/native/llvm/ir/module.jac:8` | `Module` | `name` |
| `jac/jaclang/compiler/backends/native/llvm/ir/module.jac:9` | `Module` | `data_layout` |
| `jac/jaclang/compiler/backends/native/llvm/ir/types.jac:118` | `_TypedPointerType` | `pointee` |
| `jac/jaclang/compiler/backends/native/llvm/ir/types.jac:119` | `_TypedPointerType` | `is_opaque` |
| `jac/jaclang/compiler/backends/native/llvm/ir/types.jac:168` | `FunctionType` | `return_type` |
| `jac/jaclang/compiler/backends/native/llvm/ir/types.jac:169` | `FunctionType` | `args` |
| `jac/jaclang/compiler/backends/native/llvm/ir/types.jac:170` | `FunctionType` | `var_arg` |
| `jac/jaclang/compiler/backends/native/llvm/ir/types.jac:366` | `_Repeat` | `value` |
| `jac/jaclang/compiler/backends/native/llvm/ir/types.jac:367` | `_Repeat` | `size` |
| `jac/jaclang/compiler/backends/native/llvm/ir/types.jac:389` | `VectorType` | `element` |
| `jac/jaclang/compiler/backends/native/llvm/ir/types.jac:390` | `VectorType` | `count` |
| `jac/jaclang/compiler/backends/native/llvm/ir/types.jac:483` | `ArrayType` | `element` |
| `jac/jaclang/compiler/backends/native/llvm/ir/types.jac:484` | `ArrayType` | `count` |
| `jac/jaclang/compiler/backends/native/llvm/ir/types.jac:600` | `LiteralStructType` | `elements` |
| `jac/jaclang/compiler/backends/native/llvm/ir/types.jac:632` | `IdentifiedStructType` | `context` |
| `jac/jaclang/compiler/backends/native/llvm/ir/types.jac:633` | `IdentifiedStructType` | `name` |
| `jac/jaclang/compiler/backends/native/llvm/ir/types.jac:634` | `IdentifiedStructType` | `elements` |
| `jac/jaclang/compiler/backends/native/llvm/ir/types.jac:93` | `PointerType` | `addrspace` |
| `jac/jaclang/compiler/backends/native/llvm/ir/values.jac:1051` | `FunctionAttributes` | `_alignstack` |
| `jac/jaclang/compiler/backends/native/llvm/ir/values.jac:1052` | `FunctionAttributes` | `_personality` |
| `jac/jaclang/compiler/backends/native/llvm/ir/values.jac:1112` | `Function` | `ftype` |
| `jac/jaclang/compiler/backends/native/llvm/ir/values.jac:1113` | `Function` | `scope` |
| `jac/jaclang/compiler/backends/native/llvm/ir/values.jac:1114` | `Function` | `blocks` |
| `jac/jaclang/compiler/backends/native/llvm/ir/values.jac:1115` | `Function` | `attributes` |
| `jac/jaclang/compiler/backends/native/llvm/ir/values.jac:1116` | `Function` | `args` |
| `jac/jaclang/compiler/backends/native/llvm/ir/values.jac:1117` | `Function` | `return_value` |
| `jac/jaclang/compiler/backends/native/llvm/ir/values.jac:1119` | `Function` | `calling_convention` |
| `jac/jaclang/compiler/backends/native/llvm/ir/values.jac:1250` | `ArgumentAttributes` | `_align` |
| `jac/jaclang/compiler/backends/native/llvm/ir/values.jac:1251` | `ArgumentAttributes` | `_dereferenceable` |
| `jac/jaclang/compiler/backends/native/llvm/ir/values.jac:1252` | `ArgumentAttributes` | `_dereferenceable_or_null` |
| `jac/jaclang/compiler/backends/native/llvm/ir/values.jac:1318` | `_BaseArgument` | `parent` |
| `jac/jaclang/compiler/backends/native/llvm/ir/values.jac:1319` | `_BaseArgument` | `attributes` |
| `jac/jaclang/compiler/backends/native/llvm/ir/values.jac:1373` | `Block` | `scope` |
| `jac/jaclang/compiler/backends/native/llvm/ir/values.jac:1374` | `Block` | `instructions` |
| `jac/jaclang/compiler/backends/native/llvm/ir/values.jac:1375` | `Block` | `terminator` |
| `jac/jaclang/compiler/backends/native/llvm/ir/values.jac:482` | `Constant` | `constant` |
| `jac/jaclang/compiler/backends/native/llvm/ir/values.jac:589` | `NamedValue` | `parent` |
| `jac/jaclang/compiler/backends/native/llvm/ir/values.jac:661` | `MetaDataString` | `string` |
| `jac/jaclang/compiler/backends/native/llvm/ir/values.jac:705` | `MetaDataArgument` | `wrapped_value` |
| `jac/jaclang/compiler/backends/native/llvm/ir/values.jac:726` | `NamedMetaData` | `parent` |
| `jac/jaclang/compiler/backends/native/llvm/ir/values.jac:727` | `NamedMetaData` | `operands` |
| `jac/jaclang/compiler/backends/native/llvm/ir/values.jac:747` | `MDValue` | `operands` |
| `jac/jaclang/compiler/backends/native/llvm/ir/values.jac:796` | `DIToken` | `value` |
| `jac/jaclang/compiler/backends/native/llvm/ir/values.jac:819` | `DIValue` | `is_distinct` |
| `jac/jaclang/compiler/backends/native/llvm/ir/values.jac:820` | `DIValue` | `kind` |
| `jac/jaclang/compiler/backends/native/llvm/ir/values.jac:821` | `DIValue` | `operands` |
| `jac/jaclang/compiler/backends/native/llvm/ir/values.jac:893` | `GlobalValue` | `linkage` |
| `jac/jaclang/compiler/backends/native/llvm/ir/values.jac:894` | `GlobalValue` | `storage_class` |
| `jac/jaclang/compiler/backends/native/llvm/ir/values.jac:895` | `GlobalValue` | `section` |
| `jac/jaclang/compiler/backends/native/llvm/ir/values.jac:913` | `GlobalVariable` | `value_type` |
| `jac/jaclang/compiler/backends/native/llvm/ir/values.jac:914` | `GlobalVariable` | `initializer` |
| `jac/jaclang/compiler/backends/native/llvm/ir/values.jac:915` | `GlobalVariable` | `unnamed_addr` |
| `jac/jaclang/compiler/backends/native/llvm/ir/values.jac:916` | `GlobalVariable` | `global_constant` |
| `jac/jaclang/compiler/backends/native/llvm/ir/values.jac:917` | `GlobalVariable` | `addrspace` |
| `jac/jaclang/compiler/backends/native/llvm/ir/values.jac:918` | `GlobalVariable` | `align` |
