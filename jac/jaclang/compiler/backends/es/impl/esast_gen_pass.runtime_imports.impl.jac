impl EsastGenPass._has_import(name: str) -> bool {
    for import_decl in self.imports {
        for spec in import_decl.specifiers {
            if isinstance(spec, es.ImportSpecifier) {
                if spec.local and spec.local.name == name {
                    return True;
                }
            }
        }
    }
    return False;
}

impl EsastGenPass._register_jac_virtual_import(module_id: str) -> None {
    import from jaclang.compiler.driver.modresolver { resolve_jac_virtual_module_path }
    if not self.client_manifest or module_id in self.client_manifest.imports {
        return;
    }
    source_path = resolve_jac_virtual_module_path(module_id);
    if source_path {
        self.client_manifest.imports[module_id] = source_path;
    }
}

impl EsastGenPass._register_jac_runtime_import -> None {
    self._ensure_backend();
    backend = self.backend;
    assert backend is not None , "framework backend was not initialized";
    self._register_jac_virtual_import(backend.runtime_module());
}

impl EsastGenPass._inject_runtime_import(name: str, nd: uni.UniNode) -> None {
    import from jaclang.client.client_surface { runtime_import_source }
    self._ensure_backend();
    if name in self.injected_imports or self._has_import(name) {
        return;
    }
    src = runtime_import_source(name, self.backend);
    specifier = self.sync_loc(
        es.ImportSpecifier(
            imported=es.Identifier(name=name), local=es.Identifier(name=name)
        ),
        jac_node=nd
    );
    source = self.sync_loc(es.Literal(value=src, raw='"' + src + '"'), jac_node=nd);
    import_decl = self.sync_loc(
        es.ImportDeclaration(specifiers=[specifier], source=source), jac_node=nd
    );
    self.imports.append(import_decl);
    self.injected_imports.add(name);
    if src.startswith('@jac/') {
        self._register_jac_runtime_import();
    }
}
