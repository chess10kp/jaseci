impl JacBuiltin.printgraph(
    nd: NodeArchetype,
    depth: int,
    traverse: bool,
    edge_type: (list[str] | None),
    bfs: bool,
    edge_limit: int,
    node_limit: int,
    file: (str | None),
    format: str
) -> str {
    import from jaclang.runtime.graph_utils { traverse_graph }
    edge_type: list[type] = edge_type or [];
    visited_nodes: list[NodeArchetype] = [];
    node_depths: dict[(NodeArchetype, int)] = {nd: 0};
    queue: list[tuple[NodeArchetype, int]] = [(nd, 0)];
    connections: list[tuple[(NodeArchetype, NodeArchetype, EdgeArchetype)]] = [];
    """Depth first search.""";
    def dfs(nd: NodeArchetype, cur_depth: int) {
        if (nd not in visited_nodes) {
            visited_nodes.append(nd);
            traverse_graph(
                nd,
                cur_depth,
                depth,
                edge_type,
                traverse,
                connections,
                node_depths,
                visited_nodes,
                queue,
                bfs,
                dfs,
                node_limit,
                edge_limit
            );
        }
    }
    if bfs {
        cur_depth = 0;
        while queue {
            (current_node, cur_depth) = queue.pop(0);
            if (current_node not in visited_nodes) {
                visited_nodes.append(current_node);
                traverse_graph(
                    current_node,
                    cur_depth,
                    depth,
                    edge_type,
                    traverse,
                    connections,
                    node_depths,
                    visited_nodes,
                    queue,
                    bfs,
                    dfs,
                    node_limit,
                    edge_limit
                );
            }
        }
    } else {
        dfs(nd, cur_depth=0);
    }
    dot_content = 'digraph {\nnode [style="filled", shape="ellipse", fillcolor="invis", fontcolor="black"];\n';
    mermaid_content = 'flowchart LR\n';
    for (source, target, `edge) in connections {
        edge_label = html.escape(str(`edge.__jac__.archetype));
        dot_content += (
            f"{visited_nodes.index(source)} -> {visited_nodes.index(target)} "
            + f'[label="{edge_label if "GenericEdge" not in edge_label else ""}"];\n'
        );
        if (('GenericEdge' in edge_label) or not edge_label.strip()) {
            mermaid_content += (
                f"{visited_nodes.index(source)} -->{visited_nodes.index(target)}\n"
            );
        } else {
            mermaid_content += (
                f'{visited_nodes.index(source)} -->|"{edge_label}"| {visited_nodes.index(
                    target
                )}\n'
            );
        }
    }
    for node_ in visited_nodes {
        color = colors[node_depths[node_]] if (node_depths[node_] < 25) else colors[24];
        label = html.escape(str(node_.__jac__.archetype));
        dot_content += (
            f'{visited_nodes.index(node_)} [label="{label}"fillcolor="{color}"];\n'
        );
        mermaid_content += f'{visited_nodes.index(node_)}["{label}"]\n';
    }
    output = (dot_content + '}') if (format == 'dot') else mermaid_content;
    if file {
        with open(file, 'w') as f {
            f.write(output);
        }
    }
    return output;
}

impl JacModule.impl_patch_filename(
    file_loc: str
) -> Callable[([Callable[(P, T)]], Callable[(P, T)])] {
    def decorator(func: Callable[(P, T)]) -> Callable[(P, T)] {
        try {
            code = func.__code__;
            import from jaclang.jac0core.ext_registry { is_jac }
            import from jaclang.runtime.prepared { application_for }
            application = application_for(code.co_filename, func.__module__ or '');

            if application is not None
                and is_jac(application.origins.get(code.co_filename, '')) {
                return func;
            }
            new_code = types.CodeType(
                code.co_argcount,
                code.co_posonlyargcount,
                code.co_kwonlyargcount,
                code.co_nlocals,
                code.co_stacksize,
                code.co_flags,
                code.co_code,
                code.co_consts,
                code.co_names,
                code.co_varnames,
                file_loc,
                code.co_name,
                code.co_qualname,
                code.co_firstlineno,
                code.co_linetable,
                code.co_exceptiontable,
                code.co_freevars,
                code.co_cellvars
            );
            func.__code__ = new_code;
        } except AttributeError {}
        return func;
    }
    return decorator;
}

impl JacModule.jac_import(
    target: str,
    base_path: str,
    absorb: bool = False,
    override_name: (str | None) = None,
    items: (dict[(str, str | str | None)] | None) = None,
    reload_module: (bool | None) = False,
    lng: (str | None) = None
) -> tuple[(types.ModuleType, ...)] {
    import importlib;
    import importlib.util;
    if (lng is None) {
        lng = infer_language(target, base_path);
    }
    if target.startswith('.') {
        caller_dir = base_path
            if os.path.isdir(base_path)
            else os.path.dirname(base_path);
        chomp_target = target;
        while chomp_target.startswith('.') {
            if ((len(chomp_target) > 1) and (chomp_target[1] == '.')) {
                caller_dir = os.path.dirname(caller_dir);
                chomp_target = chomp_target[1:];
            } else {
                chomp_target = chomp_target[1:];
                break;
            }
        }
        module_name = chomp_target;
    } else {
        module_name = target;
    }
    caller_dir = base_path if os.path.isdir(base_path) else os.path.dirname(base_path);

    project_root = find_jac_project_root(caller_dir);
    roots_to_add = [];
    for d in [caller_dir, project_root] {
        if (d and (d not in sys.path) and (d not in roots_to_add)) {
            roots_to_add.append(d);
        }
    }
    original_path = None;
    if roots_to_add {
        original_path = sys.path.copy();
        for d in reversed(roots_to_add) {
            sys.path.insert(0, d);
        }
    }

    pushed_base = bool(caller_dir);
    if pushed_base {
        push_import_base(caller_dir);
    }
    try {
        if (override_name == '__main__') {
            spec = importlib.util.find_spec(module_name);
            if (
                spec and spec.origin and spec.origin.endswith('.jac') and (lng == 'py')
            ) {
                spec = None;
            }
            if ((not spec or not spec.origin) and (lng == 'py')) {
                file_path = os.path.join(caller_dir, f"{module_name}.py");
                if os.path.isfile(file_path) {
                    spec_name = '__main__'
                        if (override_name == '__main__')
                        else module_name;
                    spec = importlib.util.spec_from_file_location(spec_name, file_path);
                }
            }
            if (not spec or not spec.origin) {
                raise ImportError(f"Cannot find module {module_name}");
            }
            if (('__main__' in sys.modules) and not reload_module) {
                module = sys.modules['__main__'];
                to_keep = {
                    k: v
                    for (k, v) in module.__dict__.items()
                    if k.startswith('__')
                };
                module.__dict__.update(to_keep);
            } else {
                module = types.ModuleType('__main__');
                sys.modules['__main__'] = module;
            }
            module.__file__ = spec.origin;
            module.__name__ = '__main__';
            module.__spec__ = spec;
            if spec.submodule_search_locations {
                module.__path__ = spec.submodule_search_locations;
            }
            JacRuntimeInterface.load_module('__main__', module);

            if spec.origin and spec.origin.endswith('.py') {
                with open(spec.origin, encoding='utf-8') as stream {
                    codeobj = compile(stream.read(), spec.origin, 'exec');
                }
                exec(codeobj, module.__dict__);
            } elif spec.loader {
                spec.loader.exec_module(module);
            }
        } elif (reload_module and (module_name in sys.modules)) {
            module = importlib.reload(sys.modules[module_name]);
            JacRuntimeInterface.load_module(module_name, module, force=True);
        } else {
            module = importlib.import_module(module_name);
            JacRuntimeInterface.load_module(
                module_name, module, force=bool(reload_module)
            );
        }
        if items {
            imported_items = [];
            for (item_name, _) in items.items() {
                if hasattr(module, item_name) {
                    item = getattr(module, item_name);
                    imported_items.append(item);
                } else {
                    raise ImportError(
                        f"Cannot import name '{item_name}' from '{module_name}'"
                    );
                }
            }
            return `tuple(imported_items) if not absorb else (module, );
        }
        return (module, );
    } finally {
        if pushed_base {
            pop_import_base();
        }
        if (original_path is not None) {
            sys.path[:] = original_path;
        }
    }
}

impl JacTest.jac_test(description: str = "") -> Callable {
    import from jaclang.testing.test { JacTestCheck }
    def decorator(test_fun: Callable) -> Callable {
        file_path = getfile(test_fun);
        func_name = test_fun.__name__;
        def test_deco {
            test_fun();
        }
        test_deco.__name__ = test_fun.__name__;
        JacTestCheck.add_test(
            file_path, func_name, test_deco, display_name=description
        );
        return test_deco;
    }
    return decorator;
}

impl JacBuiltin.jsx(
    tag: object,
    attributes: (Mapping[(str, object)] | None) = None,
    children: (Sequence[object] | None) = None
) -> JsxElement {
    `props: dict[(str, object)] = `dict(attributes) if attributes else {};
    child_list = `list(children) if children else [];
    return JsxElement(tag=tag, `props=`props, children=child_list);
}

impl JacTest.run_test(
    filepath: str,
    func_name: (str | None) = None,
    filter: (str | None) = None,
    xit: bool = False,
    maxfail: (int | None) = None,
    directory: (str | None) = None,
    verbose: bool = False
) -> int {
    import from jaclang.runtime.build_services { build_services }
    return build_services().run_test(
        filepath, func_name, filter, xit, maxfail, directory, verbose
    );
}

impl JacBuiltin.log_report(expr: any, custom: bool = False) -> None {
    import from jaclang.runtime.osp_kernel { osp_report, _current_scope }
    if custom {
        JacRuntimeInterface.get_context().custom = expr;
    } else {
        JacRuntimeInterface.get_console().print(expr);
        if _current_scope() is not None {
            osp_report(expr);
        } else {
            cs = JacRuntimeInterface.get_context().call_state.get(None);
            if cs is not None {
                cs.reports.put_nowait(expr);
            }
        }
    }
}

impl JacBuiltin.safe_subscript(`obj: any, key: any) -> any {
    try {
        return `obj[key];
    } except (KeyError, IndexError, TypeError) {
        return None;
    }
}

impl JacBuiltin.get_console -> ConsoleImpl {
    import from jaclang.cli.console { JacConsole }
    return JacConsole();
}

impl JacModule.load_module(
    module_name: str, module: types.ModuleType, force: bool = False
) -> None {
    if ((module_name not in JacRuntime.loaded_modules) or force) {
        JacRuntime.loaded_modules[module_name] = module;
        sys.modules[module_name] = module;
    }
}

impl JacIntrospection.list_modules -> list[str] {
    return `list(JacRuntime.loaded_modules.keys());
}

impl JacIntrospection._list_members_of(
    module_name: str, archetype_cls: type
) -> list[str] {
    module = JacRuntime.loaded_modules.get(module_name);
    if module {
        members = [];
        for (name, `obj) in inspect.getmembers(module) {
            if (
                isinstance(`obj, `type)
                and issubclass(`obj, archetype_cls)
                and (`obj.__module__ == module_name)
            ) {
                members.append(name);
            }
        }
        return members;
    }
    return [];
}

impl JacIntrospection.list_walkers(module_name: str) -> list[str] {
    return JacIntrospection._list_members_of(module_name, WalkerArchetype);
}

impl JacIntrospection.list_nodes(module_name: str) -> list[str] {
    return JacIntrospection._list_members_of(module_name, NodeArchetype);
}

impl JacIntrospection.list_edges(module_name: str) -> list[str] {
    return JacIntrospection._list_members_of(module_name, EdgeArchetype);
}

impl JacModule.create_archetype_from_source(
    source_code: str,
    module_name: (str | None) = None,
    base_path: (str | None) = None,
    cachable: bool = False,
    keep_temporary_files: bool = False
) -> (types.ModuleType | None) {
    resolved_base: str = base_path or JacRuntime.get_base_path_dir() or os.getcwd();
    if not os.path.exists(resolved_base) {
        os.makedirs(resolved_base);
    }
    if not module_name {
        module_name = f"_dynamic_module_{len(JacRuntime.loaded_modules)}";
    }
    import tempfile;
    with tempfile.NamedTemporaryFile(
        mode='w',
        suffix='.jac',
        prefix=(module_name + '_'),
        dir=resolved_base,
        delete=False
    ) as tmp_file {
        tmp_file_path = tmp_file.name;
        tmp_file.write(source_code);
    }
    try {
        tmp_file_basename = os.path.basename(tmp_file_path);
        (tmp_module_name, _) = os.path.splitext(tmp_file_basename);
        result = JacRuntimeInterface.jac_import(
            target=tmp_module_name,
            base_path=resolved_base,
            override_name=module_name,
            lng='jac'
        );
        module = result[0] if result else None;
        if module {
            JacRuntime.loaded_modules[module_name] = module;
        }
        return module;
    } except Exception as e {
        logger.error(f"Error importing dynamic module '{module_name}':{e}");
        return None;
    } finally {
        if (not keep_temporary_files and os.path.exists(tmp_file_path)) {
            os.remove(tmp_file_path);
        }
    }
}

impl JacModule.update_walker(
    module_name: str, items: (dict[(str, str | str | None)] | None)
) -> tuple[(types.ModuleType, ...)] {
    if (module_name in JacRuntime.loaded_modules) {
        try {
            old_module = JacRuntime.loaded_modules[module_name];
            result = JacRuntimeInterface.jac_import(
                target=module_name,
                base_path=(JacRuntime.get_base_path_dir() or os.getcwd()),
                items=items,
                reload_module=True,
                lng='jac'
            );
            if items {
                ret_items = [];
                for (idx, item_name) in enumerate(items.keys()) {
                    if (hasattr(old_module, item_name) and (idx < len(result))) {
                        new_attr = result[idx];
                        ret_items.append(new_attr);
                        setattr(old_module, item_name, new_attr);
                    }
                }
                return `tuple(ret_items);
            }
            return (old_module, );
        } except Exception as e {
            logger.error(f"Failed to update module {module_name}: {e}");
        }
    } else {
        logger.warning(f"Module {module_name} not found in loadedmodules.");
    }
    return ();
}

impl JacIntrospection.spawn_node(
    node_name: str,
    attributes: (dict[str, any] | None) = None,
    module_name: str = '__main__'
) -> NodeArchetype {
    node_class = JacRuntimeInterface.get_archetype(module_name, node_name);
    if (isinstance(node_class, `type) and issubclass(node_class, NodeArchetype)) {
        if (attributes is None) {
            attributes = {};
        }
        node_instance = node_class(**attributes);
        return node_instance;
    } else {
        raise ValueError(f"Node {node_name} not found.");
    }
}

impl JacIntrospection.spawn_walker(
    walker_name: str,
    attributes: (dict[str, any] | None) = None,
    module_name: str = '__main__'
) -> WalkerArchetype {
    walker_class = JacRuntimeInterface.get_archetype(module_name, walker_name);
    if (
        isinstance(walker_class, `type) and issubclass(walker_class, WalkerArchetype)
    ) {
        if (attributes is None) {
            attributes = {};
        }
        walker_instance = walker_class(**attributes);
        return walker_instance;
    } else {
        raise ValueError(f"Walker {walker_name} not found.");
    }
}

impl JacIntrospection.get_archetype(
    module_name: str, archetype_name: str
) -> (Archetype | None) {
    module = JacRuntime.loaded_modules.get(module_name);
    if module {
        return getattr(module, archetype_name, None);
    }
    return None;
}
