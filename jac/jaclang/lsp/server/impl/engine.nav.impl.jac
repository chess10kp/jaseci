import from jaclang.compiler.tools.unparse_pass { unparse_node }

impl JacLangServer.get_semantic_tokens(file_path: str) -> lspt.SemanticTokens {
    fs_path = _path_of(file_path);
    with self._state_lock.read_lock() {
        sem_mgr = self.sem_managers.get(fs_path);
        if not sem_mgr {
            return lspt.SemanticTokens(data=[]);
        }
        return lspt.SemanticTokens(data=list(sem_mgr.sem_tokens));
    }
}

impl JacLangServer.rename_symbol(
    file_path: str, position: lspt.Position, new_name: str
) -> Optional[lspt.WorkspaceEdit] {
    node_selected = self.get_token_at_position(file_path, position);
    if node_selected and node_selected.sym {
        changes: dict[(str, list[lspt.TextEdit])] = {};
        for nd in [*node_selected.sym.uses, node_selected.sym.defn[0]] {
            key = _uri_of(nd.loc.mod_path);
            new_edit = lspt.TextEdit(
                range=utils.create_range(nd.loc), new_text=new_name
            );
            utils.add_unique_text_edit(changes, key, new_edit);
        }
        return lspt.WorkspaceEdit(changes=changes);
    }
    return None;
}

impl JacLangServer.get_references(
    file_path: str, position: lspt.Position
) -> list[lspt.Location] {
    node_selected = self.get_token_at_position(file_path, position);
    if node_selected and node_selected.sym {
        occurrences: list[uni.NameAtom] = [
            *node_selected.sym.defn,
            *node_selected.sym.uses
        ];
        list_of_references: list[lspt.Location] = [
            lspt.Location(
                uri=_uri_of(cur_node.loc.mod_path),
                range=utils.create_range(cur_node.loc)
            ) for cur_node in [*node_selected.sym.defn, *node_selected.sym.uses]
        ];
        return list_of_references;
    }
    return [];
}

def _definition_symbol(sym: any) -> any {
    cur = sym;
    seen: set[int] = set();
    while cur is not None and cur.provider is not None and id(cur) not in seen {
        seen.add(id(cur));
        target = cur.provider.definition();
        if target is None or target is cur {
            break;
        }
        cur = target;
    }
    return cur;
}

impl JacLangServer.get_definition(
    file_path: str, position: lspt.Position
) -> Optional[lspt.Location] {
    import from pathlib { Path }

    def make_location(node_: uni.UniNode, is_module: bool = False) -> lspt.Location {
        mod_path: str = node_.loc.mod_path;
        if is_module
            and isinstance(node_, uni.Expr)
            and isinstance(node_.type, ModuleType) {
            mod_path = str(node_.type.file_uri);
        }
        decl_range = (
            utils.create_range(node_.loc)
                if not is_module
                else lspt.Range(
                    start=lspt.Position(line=0, character=0),
                    end=lspt.Position(line=0, character=0)
                )
        );
        return lspt.Location(uri=_uri_of(str(mod_path)), range=decl_range);
    }
    def make_module_location(file_path_str: str) -> lspt.Location {
        return lspt.Location(
            uri=_uri_of(file_path_str),
            range=lspt.Range(
                start=lspt.Position(line=0, character=0),
                end=lspt.Position(line=0, character=0)
            )
        );
    }
    node_selected = self.get_token_at_position(file_path, position);
    if not node_selected {
        return self._string_import_definition(file_path, position);
    }
    node_type: (TypeBase | None) = (
        node_selected.type if isinstance(node_selected, uni.Expr) else None
    );
    parent = node_selected.parent;

    if isinstance(parent, uni.AstImplNeedingNode) and parent.body {
        body_nd = parent.body;
        if isinstance(body_nd, uni.ImplDef) and body_nd.sym {
            return make_location(body_nd.sym.decl);
        }
    }

    if isinstance(parent, uni.ModulePath) {
        if node_type and isinstance(node_type, ModuleType) {
            return make_location(node_selected, is_module=True);
        }

        import_node = parent.parent_of_type(uni.Import) if parent else None;
        if import_node and parent.path {
            try {
                idx = (
                    `list(parent.path).index(node_selected)
                        if isinstance(node_selected, (uni.Name, uni.String))
                        else -1
                );
                path_list = parent.resolve_relative_path_list();
                if idx >= 0 and idx < len(path_list) {
                    resolved = path_list[idx];
                    if Path(resolved).exists() {
                        return make_module_location(resolved);
                    }
                }
            } except (ValueError, Exception) as e {
                self.log_py(f"Error resolving module path segment: {e}");
            }
        }
    }
    if isinstance(parent, uni.ModuleItem) and isinstance(node_selected, uni.Name) {
        if node_type and isinstance(node_type, ModuleType) {
            return make_location(node_selected, is_module=True);
        }

        if (
            node_selected.sym
            and node_selected.sym.defn
            and node_selected.sym.defn[0].loc.mod_path != node_selected.loc.mod_path
        ) {
            decl = node_selected.sym.defn[0];
            return make_location(decl);
        }

        import_node = parent.parent_of_type(uni.Import) if parent else None;
        if import_node and import_node.from_loc {
            try {
                mod_path = import_node.from_loc.resolve_relative_path();
                if Path(mod_path).exists() and not Path(mod_path).is_dir() {
                    resolved_path = str(Path(mod_path).resolve());
                    with self._state_lock.read_lock() {
                        target_mod = self.program.mod.hub.get(resolved_path);
                    }
                    if target_mod {
                        sym = target_mod.lookup(
                            node_selected.value, deep=True, incl_inner_scope=True
                        );
                        if sym and sym.defn {
                            return make_location(sym.defn[0]);
                        }
                    }

                    return make_module_location(mod_path);
                }

                npm_loc = self._npm_item_location(
                    import_node.from_loc, parent.name.value
                );
                if npm_loc {
                    return npm_loc;
                }
            } except Exception as e {
                self.log_py(f"Error resolving imported item: {e}");
            }
        }
    }

    if node_type {
        if isinstance(node_type, ModuleType) {
            return make_location(node_selected, is_module=True);
        } elif isinstance(node_type, ClassType) and node_selected.sym {
            return make_location(_definition_symbol(node_selected.sym).decl);
        } elif isinstance(node_type, (FunctionType, OverloadedType))
            and node_selected.sym {
            return make_location(_definition_symbol(node_selected.sym).decl);
        }
    }

    if not parent {
        return None;
    }
    if isinstance(parent, uni.ImplDef) and parent.decl_link {
        decl_link = parent.decl_link;
        if isinstance(decl_link, uni.AstSymbolNode) and decl_link.sym {
            return make_location(decl_link.sym.decl);
        }
    }

    if node_selected.sym and node_selected.sym.defn {
        defn0 = _definition_symbol(node_selected.sym).defn[0];

        if defn0 is node_selected
            or (
                defn0.loc.mod_path == node_selected.loc.mod_path
                and defn0.loc.first_line == node_selected.loc.first_line
                and defn0.loc.col_start == node_selected.loc.col_start
            ) {
            return None;
        }
        try {
            return make_location(defn0);
        } except Exception as e {
            self.log_py(f"Error navigating to definition: {e}");
        }
    }
    return None;
}

impl JacLangServer._string_import_definition(
    file_path: str, position: lspt.Position
) -> Optional[lspt.Location] {
    fs_path = uris.to_fs_path(file_path);
    if fs_path is None {
        return None;
    }
    tok = self.get_node_at_position(fs_path, position.line, position.character);
    if not isinstance(tok, uni.String) or not isinstance(tok.parent, uni.ModulePath) {
        return None;
    }
    target = self._module_spec_target(tok.parent);
    if target is None {
        return None;
    }
    target_uri = uris.from_fs_path(target);
    if target_uri is None {
        return None;
    }
    return lspt.Location(
        uri=target_uri,
        range=lspt.Range(
            start=lspt.Position(line=0, character=0),
            end=lspt.Position(line=0, character=0)
        )
    );
}

impl JacLangServer._module_spec_target(mp: uni.ModulePath) -> Optional[str] {
    import os;
    import from jaclang.project.modresolver {
        resolve_client_npm_declarations,
        resolve_client_npm_package
    }
    import from jaclang.compiler.placement.placement_pins { is_client_npm_import }
    try {
        resolved = mp.resolve_relative_path();
        if os.path.isfile(resolved) {
            return resolved;
        }
    } except Exception as e {
        self.log_py(f"Error resolving module path: {e}");
    }
    spec = mp.string_path_value or mp.dot_path_str;
    src_path = mp.loc.mod_path if mp.loc else None;
    if not spec or not src_path {
        return None;
    }
    try {
        if is_client_npm_import(spec, src_path) {
            return (
                resolve_client_npm_declarations(spec, src_path)
                or resolve_client_npm_package(spec, src_path)
            );
        }
    } except Exception as e {
        self.log_py(f"Error resolving npm module path: {e}");
    }
    return None;
}

impl JacLangServer._npm_item_location(
    from_loc: uni.ModulePath, item_name: str
) -> Optional[lspt.Location] {
    import from jaclang.project.modresolver {
        resolve_client_npm_declarations,
        resolve_client_npm_package
    }
    import from jaclang.compiler.placement.placement_pins { is_client_npm_import }
    def at_file(path_: str, rng: Optional[lspt.Range]) -> Optional[lspt.Location] {
        path_uri = uris.from_fs_path(path_);
        if path_uri is None {
            return None;
        }
        return lspt.Location(
            uri=path_uri,
            range=rng
                or lspt.Range(
                    start=lspt.Position(line=0, character=0),
                    end=lspt.Position(line=0, character=0)
                )
        );
    }
    spec = from_loc.string_path_value or from_loc.dot_path_str;
    src_path = from_loc.loc.mod_path if from_loc.loc else None;
    if not spec or not src_path or not is_client_npm_import(spec, src_path) {
        return None;
    }
    dts = resolve_client_npm_declarations(spec, src_path);
    if dts {
        return at_file(dts, utils.find_dts_decl_range(dts, item_name));
    }
    `entry = resolve_client_npm_package(spec, src_path);
    if `entry {
        return at_file(`entry, None);
    }
    return None;
}

impl JacLangServer.get_outline(file_path: str) -> list[lspt.DocumentSymbol] {
    fs_path = _path_of(file_path);
    with self._state_lock.read_lock() {
        if fs_path in self.program.mod.hub
            and (root_node := self.program.mod.hub[fs_path].sym_tab) {
            return utils.get_symbols_for_outline(root_node);
        }
    }
    return [];
}

impl JacLangServer.get_node_info(sym_node: uni.AstSymbolNode) -> Optional[str] {
    node_info: Optional[str] = None;
    try {
        if isinstance(sym_node, uni.NameAtom) {
            if sym_node.is_getattr_resolved {
                return f"(dynamic attribute) {sym_node?.value}: {sym_node.type}";
            }
            sym_node = sym_node.name_of;
        }
        access = (sym_node.sym.access.value + ' ') if sym_node.sym else None;
        node_info = f"({(access or '')}{sym_node.sym_category.value}) {sym_node.sym_name}";

        if not isinstance(sym_node, uni.Ability) {
            if sym_node?.type {
                node_info += f": {sym_node?.type}";
            } elif sym_node.name_spec.clean_type {
                node_info += f": {sym_node.name_spec.clean_type}";
            } elif (
                isinstance(sym_node, uni.AstSymbolNode)
                and isinstance(sym_node.name_spec.type, ClassType)
            ) {
                node_info += f": {sym_node.name_spec.type.shared.class_name}";
            }
        }
        if sym_node.sym and (doc := doc_of_sym(sym_node.sym)) {
            node_info += f"\n{doc}";
        }
        if isinstance(sym_node, uni.Ability) and sym_node.signature {
            node_info += f"\n{unparse_node(sym_node.signature)}";
        }
        try {
            top: (uni.UniNode | None) = sym_node;
            while (
                top is not None
                and not isinstance(top.parent, uni.Module)
                and top.parent is not None
            ) {
                top = top.parent;
            }
            if isinstance(top, uni.ContextAwareNode) {
                space = sym_node.codespace().value;
                tags: list[str] = [];
                if top.codespace_dual {
                    tags.append('dual');
                }
                tags.append('inferred');
                node_info += f"\nplacement: {space} ({', '.join(tags)})";
            }
        } except Exception {}
    } except AttributeError as e {
        self.log_warning(f"Attribute error when accessing node attributes: {e}");
    }
    return node_info.strip() if node_info else None;
}

impl JacLangServer.get_inlay_hints(
    file_path: str, range: lspt.Range
) -> list[lspt.InlayHint] {
    import from jaclang.compiler.passes.ownership_hints { inferred_hints }
    fs_path = _path_of(file_path);
    mod = self.program.mod.hub.get(fs_path);
    if mod is None {
        return [];
    }
    out: list[lspt.InlayHint] = [];
    for h in inferred_hints(mod) {
        line = h.line - 1;
        if line < range.start.line or line > range.end.line {
            continue;
        }
        out.append(
            lspt.InlayHint(
                position=lspt.Position(line=line, character=h.col),
                label=h.label,
                kind=(
                    lspt.InlayHintKind.Parameter
                        if h.kind == "parameter"
                        else lspt.InlayHintKind.Type
                ),
                padding_left=h.label.startswith("(") or h.label.startswith(" raises")
            )
        );
    }
    return out;
}

impl JacLangServer.get_hover_info(
    file_path: str, position: lspt.Position
) -> Optional[lspt.Hover] {
    node_selected = self.get_token_at_position(file_path, position);
    value = self.get_node_info(node_selected) if node_selected else None;
    if value {
        return lspt.Hover(
            contents=lspt.MarkupContent(
                kind=lspt.MarkupKind.PlainText, value=f"{value}"
            )
        );
    }
    return None;
}

impl JacLangServer.get_ast_of_file(file_path: str) -> Optional[uni.UniNode] {
    with self._state_lock.read_lock() {
        if file_path in self.program.mod.hub {
            return self.program.mod.hub[file_path];
        }
    }
    return None;
}

impl JacLangServer.get_token_at_position(
    file_path: str, position: lspt.Position
) -> Optional[uni.AstSymbolNode] {
    fs_path = _path_of(file_path);
    with self._state_lock.read_lock() {
        sem_mgr = self.sem_managers.get(fs_path);
        if not sem_mgr {
            return None;
        }
        token_index = utils.find_index(
            sem_mgr.sem_tokens, position.line, position.character
        );
        if token_index is None {
            return None;
        }
        if token_index < len(sem_mgr.static_sem_tokens) {
            return sem_mgr.static_sem_tokens[token_index][3];
        }
        return None;
    }
}
