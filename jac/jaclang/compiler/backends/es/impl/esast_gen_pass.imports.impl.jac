impl EsastGenPass._resolve_source_module(nd: uni.Import) -> (uni.Module | None) {
    import from jaclang.compiler.symbol_utils { resolve_import_source_module }
    return resolve_import_source_module(self.prog, nd);
}

impl EsastGenPass._record_sv_backend(nd: uni.Import) -> None {
    import from pathlib { Path }
    if not nd.from_loc {
        return;
    }
    resolved_path = nd.from_loc.resolve_relative_path();
    if not resolved_path {
        return;
    }
    abs_path = str(Path(resolved_path).resolve());
    if abs_path.endswith(".jac")
        and Path(abs_path).exists()
        and (abs_path not in self.client_manifest.server_imports) {
        self.client_manifest.server_imports.append(abs_path);
    }
}

impl EsastGenPass.exit_import(nd: uni.Import) -> None {
    if nd.is_typed {
        nd.gen.es_ast = None;
        return;
    }

    if nd.is_service_import {
        if (nd.from_loc and nd.items) {
            self._generate_sv_import_stubs(nd);
            self._record_sv_backend(nd);
        }
        return;
    }

    if self._is_client_native_import(nd) {
        if (nd.from_loc and nd.items) {
            self._generate_na_import_binding(nd);
        }
        nd.gen.es_ast = None;
        return;
    }
    emit_items: list = list(nd.items);
    if (nd.from_loc and nd.items) {
        resolved_path = nd.from_loc.resolve_relative_path();
        partition = self._partition_client_import_items(nd);
        if partition is not None {
            (emit_items, bridged_items) = partition;
            if bridged_items {
                self._generate_sv_import_stubs(nd, bridged_items);
                self._record_sv_backend(nd);
            }
            if not emit_items {
                nd.gen.es_ast = None;
                return;
            }
        }
        import_key = nd.from_loc.dot_path_str;
        self.client_manifest.imports[import_key] = resolved_path;
        self.client_manifest.has_client = True;

        import_path = nd.from_loc.dot_path_str;
        is_jac_runtime = nd.is_virtual_jac;
        if resolved_path.endswith('.jac')
            and not import_path.startswith('.')
            and not is_jac_runtime {
            js_import_path = relative_js_specifier(resolved_path, nd.loc.mod_path);
        } else {
            js_import_path = convert_to_js_import_path(import_path);
        }
    } elif (not nd.from_loc and nd.items) {
        self.client_manifest.has_client = True;
        first_item = nd.items[0];
        if (isinstance(first_item, uni.ModulePath) and first_item.path) {
            path_elem = first_item.path[0];
            import_key = path_elem.lit_value
                if isinstance(path_elem, uni.String)
                else path_elem.value;
        } else {
            import_key = '';
        }
        resolved_path = resolve_relative_path(
            import_key,
            nd.loc.mod_path,
            string_spec=isinstance(first_item, uni.ModulePath)
                and first_item.string_path_value is not None
        );
        self.client_manifest.imports[import_key] = resolved_path;
        import_path = import_key;
        if resolved_path.endswith('.jac') and not import_path.startswith('.') {
            js_import_path = relative_js_specifier(resolved_path, nd.loc.mod_path);
        } else {
            js_import_path = convert_to_js_import_path(import_path);
        }
    } else {
        return;
    }
    source = self.sync_loc(es.Literal(value=js_import_path), jac_node=nd.from_loc);
    specifiers:
        list[
            es.ImportSpecifier | es.ImportDefaultSpecifier | es.ImportNamespaceSpecifier
        ] = [];
    for item in emit_items {
        if isinstance(item, uni.ModuleItem) {
            if isinstance(item.name, uni.Name) {
                imported = self.sync_loc(
                    es.Identifier(name=item.name.sym_name), jac_node=item.name
                );
                local = self.sync_loc(
                    es.Identifier(
                        name=item.alias.sym_name if item.alias else item.name.sym_name
                    ),
                    jac_node=item.alias or item.name
                );
                specifiers.append(
                    self.sync_loc(
                        es.ImportSpecifier(imported=imported, local=local),
                        jac_node=item
                    )
                );
            } elif isinstance(item.name, uni.Token) {
                if (item.name.value == 'default') {
                    if not item.alias {
                        continue;
                    }
                    local = self.sync_loc(
                        es.Identifier(name=item.alias.sym_name), jac_node=item.alias
                    );
                    specifiers.append(
                        self.sync_loc(
                            es.ImportDefaultSpecifier(local=local), jac_node=item
                        )
                    );
                } elif (item.name.value == '*') {
                    if not item.alias {
                        continue;
                    }
                    local = self.sync_loc(
                        es.Identifier(name=item.alias.sym_name), jac_node=item.alias
                    );
                    specifiers.append(
                        self.sync_loc(
                            es.ImportNamespaceSpecifier(local=local), jac_node=item
                        )
                    );
                }
            }
        }
    }
    import_decl = self.sync_loc(
        es.ImportDeclaration(specifiers=specifiers, source=source), jac_node=nd
    );
    self.imports.append(import_decl);
    nd.gen.es_ast = None;
}


impl EsastGenPass._partition_client_import_items(
    nd: uni.Import
) -> (tuple[list, list] | None) {
    import from jaclang.compiler.symbol_utils {
        ClientImportVerdict,
        classify_client_import_item,
        decl_has_access,
        import_target_pinned_server,
        is_client_boundary_import,
        report_dead_client_import
    }
    if not is_client_boundary_import(nd) {
        return None;
    }
    pinned_server = import_target_pinned_server(nd);
    source_mod = self._resolve_source_module(nd);
    if source_mod is None {
        return ([], list(nd.items)) if pinned_server else None;
    }
    kept: list = [];
    bridged: list = [];
    for item in nd.items {
        verdict = classify_client_import_item(source_mod, item);
        if pinned_server and verdict != ClientImportVerdict.DEAD {
            bridged.append(item);
            continue;
        }
        if pinned_server
            and verdict == ClientImportVerdict.DEAD
            and decl_has_access(source_mod, item) {
            bridged.append(item);
            continue;
        }
        if verdict == ClientImportVerdict.BRIDGED {
            bridged.append(item);
        } elif verdict == ClientImportVerdict.DEAD {
            report_dead_client_import(self, nd, item);
        } else {
            kept.append(item);
        }
    }
    return (kept, bridged);
}

impl EsastGenPass._generate_sv_import_stubs(
    nd: uni.Import, items: (Sequence[uni.ModuleItem] | None) = None
) -> None {
    manifest = self.ir_in.gen.interop_manifest;
    boundary_types = manifest.boundary_types;
    stubs: list[es.Statement] = [];
    for item in (items if items is not None else nd.items) {
        if not isinstance(item, uni.ModuleItem)
            or not isinstance(item.name, uni.Name) {
            continue;
        }

        if self._sv_import_item_is_type(nd, item) {
            continue;
        }
        func_name = item.name.sym_name;
        local_name = item.alias.sym_name if item.alias else func_name;

        binding = manifest.bindings.get(local_name);
        if binding is not None and binding.kind != 'function' {
            continue;
        }
        param_names: list[str] = [];
        param_type_map: dict[str, str] = {};
        ret_type_name: str = '';
        if binding is not None {
            param_names = list(binding.param_names);
            for i in range(len(param_names)) {
                if i < len(binding.param_types) {
                    param_type_map[param_names[i]] = binding.param_types[i];
                }
            }
            ret_type_name = binding.ret_type;
            _src_mod = binding.ast_node.find_parent_of_type(uni.Module)
                if binding.ast_node is not None
                else None;
            if _src_mod is not None {
                src_effect = _src_mod.gen.interop_manifest.endpoint_effects.get(
                    f"func:{func_name}"
                );
                if src_effect is not None {
                    self.client_manifest.endpoint_effects[f"func:{func_name}"] = (
                        src_effect
                    );
                }
            }
        }

        js_params: list[es.Pattern] = [];
        for pname in param_names {
            js_params.append(self.sync_loc(es.Identifier(name=pname), jac_node=nd));
        }

        props: list[es.Property | es.SpreadElement] = [];
        for pname in param_names {
            key = self.sync_loc(es.Literal(value=pname), jac_node=nd);
            value: es.Expression = self._wrap_to_wire_if_boundary(
                self.sync_loc(es.Identifier(name=pname), jac_node=nd),
                param_type_map.get(pname, ''),
                boundary_types,
                nd
            );
            props.append(
                self.sync_loc(
                    es.Property(
                        key=key,
                        value=value,
                        kind='init',
                        method=False,
                        shorthand=False,
                        computed=False
                    ),
                    jac_node=nd
                )
            );
        }
        args_obj = self.sync_loc(es.ObjectExpression(properties=props), jac_node=nd);

        call_expr = self.sync_loc(
            es.CallExpression(
                callee=self.sync_loc(
                    es.Identifier(name='__jacCallFunction'), jac_node=nd
                ),
                arguments=[
                    self.sync_loc(es.Literal(value=func_name), jac_node=nd),
                    args_obj
                ]
            ),
            jac_node=nd
        );
        await_expr: es.Expression = self.sync_loc(
            es.AwaitExpression(argument=call_expr), jac_node=nd
        );
        await_expr = self._wrap_return_with_boundary(
            await_expr, ret_type_name, boundary_types, nd, pre_awaited=True
        );
        return_stmt = self.sync_loc(
            es.ReturnStatement(argument=await_expr), jac_node=nd
        );
        body = self.sync_loc(es.BlockStatement(body=[return_stmt]), jac_node=nd);
        func_id = self.sync_loc(es.Identifier(name=local_name), jac_node=nd);
        func_decl = self.sync_loc(
            es.FunctionDeclaration(
                id=func_id, params=js_params, body=body, generator=False, async_=True
            ),
            jac_node=nd
        );
        stubs.append(func_decl);
    }
    if stubs {
        self._inject_runtime_import('__jacCallFunction', nd);

        self.sv_import_stubs.extend(stubs);
    }
}

impl EsastGenPass._is_client_native_import(nd: uni.Import) -> bool {
    import from jaclang.compiler.driver.boundary_classify { import_binds_client_native }
    return import_binds_client_native(nd, self.ir_in.gen.interop_manifest);
}

impl EsastGenPass._generate_na_import_binding(nd: uni.Import) -> None {
    import from jaclang.compiler.frontend.codeinfo { native_wasm_stem }
    resolved_path = nd.from_loc.resolve_relative_path();
    stem = native_wasm_stem(resolved_path);

    if self.client_manifest {
        self.client_manifest.has_client = True;
    }

    bind_local = '__jac_na_bind';
    if bind_local not in self.injected_imports {
        host_module = '@jac/wasm_host';
        specifier = self.sync_loc(
            es.ImportSpecifier(
                imported=es.Identifier(name='__na_bind'),
                local=es.Identifier(name=bind_local)
            ),
            jac_node=nd
        );
        source = self.sync_loc(
            es.Literal(value=host_module, raw=f'"{host_module}"'), jac_node=nd
        );
        self.imports.append(
            self.sync_loc(
                es.ImportDeclaration(specifiers=[specifier], source=source), jac_node=nd
            )
        );
        self.injected_imports.add(bind_local);
        self._register_jac_virtual_import(host_module);
    }

    props: list[(es.AssignmentProperty | es.RestElement)] = [];
    export_names: list[(es.Expression | es.SpreadElement | None)] = [];
    for item in nd.items {
        if not isinstance(item, uni.ModuleItem)
            or not isinstance(item.name, uni.Name) {
            continue;
        }
        export_name = item.name.sym_name;
        local_name = item.alias.sym_name if item.alias else export_name;
        export_names.append(
            self.sync_loc(
                es.Literal(value=export_name, raw=f'"{export_name}"'), jac_node=item
            )
        );
        props.append(
            self.sync_loc(
                es.AssignmentProperty(
                    key=es.Identifier(name=export_name),
                    value=es.Identifier(name=local_name),
                    shorthand=(export_name == local_name)
                ),
                jac_node=item
            )
        );
    }
    if not props {
        return;
    }

    bind_call = self.sync_loc(
        es.CallExpression(
            callee=es.Identifier(name=bind_local),
            arguments=[
                self.sync_loc(es.Literal(value=stem, raw=f'"{stem}"'), jac_node=nd),
                self.sync_loc(es.ArrayExpression(elements=export_names), jac_node=nd),

            ]
        ),
        jac_node=nd
    );
    self.na_import_stubs.append(
        self.sync_loc(
            es.VariableDeclaration(
                kind='const',
                declarations=[
                    self.sync_loc(
                        es.VariableDeclarator(
                            id=self.sync_loc(
                                es.ObjectPattern(properties=props), jac_node=nd
                            ),
                            init=bind_call
                        ),
                        jac_node=nd
                    )
                ]
            ),
            jac_node=nd
        )
    );
}

impl EsastGenPass._sv_import_item_is_type(
    nd: uni.Import, item: uni.ModuleItem
) -> bool {
    type_kinds = {
        SymbolType.OBJECT_ARCH,
        SymbolType.NODE_ARCH,
        SymbolType.EDGE_ARCH,
        SymbolType.WALKER_ARCH,
        SymbolType.ENUM_ARCH
    };
    sym = item.name.sym;
    if sym and (sym.sym_type in type_kinds) {
        return True;
    }
    return item.name.sym_name in self.ir_in.gen.interop_manifest.boundary_types;
}
