import os;
import sys;


def _scan_rc_machinery(llvm_ir_str: str) -> tuple[list[str], list[str]] {
    import re;
    syms: set[str] = set();
    for m in re.finditer(r"__rc_[A-Za-z0-9_]*", llvm_ir_str) {
        syms.add(m.group(0));
    }
    probes: list[str] = [];
    for probe in ["JAC_GC"] {
        if probe in llvm_ir_str {
            probes.append(probe);
        }
    }
    return (sorted(syms), probes);
}


def _application_ir(plan: LinkPlan) -> str {
    registry = plan.prog.native_units();
    parts: list[str] = [];
    for u in plan.units {
        if is_toolchain_unit(u.path) {
            continue;
        }
        bc = registry.bitcode_for(u.path, plan.options);
        if bc is None {
            continue;
        }
        parts.append(str(llvm.parse_bitcode(bc)));
    }
    return "\n".join(parts);
}


impl native_build(
    filename: str,
    output: str = "",
    lib: bool = False,
    link_mode: str = "",
    target: str = "",
    debug: bool = False,
    memory: str = "",
    no_ir_cache: bool = False
) -> int {
    def _target_triple(target: str) -> str {
        if target in ["wasm", "wasm32", "wasm32-unknown-unknown"] {
            return "wasm32-unknown-unknown";
        }
        if ("windows" in target) or (target in ["win", "win64", "mingw"]) {
            return target if "-" in target else "x86_64-pc-windows-msvc";
        }
        if (target in ["macos", "darwin", "osx", "macosx"])
            or ("apple" in target)
            or ("darwin" in target) {
            return target if "-" in target else "arm64-apple-darwin";
        }
        if (target in ["linux", "elf"])
            or ("linux-gnu" in target)
            or ("linux-musl" in target) {
            return target if "-" in target else "x86_64-unknown-linux-gnu";
        }
        return "" if target in ("", "host") else target;
    }

    _cfg = get_config();
    _mem_cfg = _cfg.memory if _cfg else None;
    if not memory {
        memory = _mem_cfg.profile if _mem_cfg else "managed";
    }
    if memory not in ("managed", "rc", "nogc") {
        console.error(
            f"Invalid --memory profile '{memory}' (expected: managed, rc, nogc)"
        );
        return 1;
    }
    if link_mode and link_mode not in NATIVE_LINK_MODES {
        console.error(
            f"Invalid --link-mode '{link_mode}' (expected: {', '.join(
                NATIVE_LINK_MODES
            )})"
        );
        return 1;
    }
    shared = lib;
    assert_no_rc = memory == "nogc";
    if not is_jac(filename) {
        console.error("Input must be a .jac file.");
        return 1;
    }
    if not os.path.exists(filename) {
        console.error(f"File not found: {filename}");
        return 1;
    }
    if is_retired_native_marker(filename) {
        console.error(
            f"{filename}: the .na.jac marker was retired in 0.35 -- rename the "
            "file to .jac; 'jac build --native' compiles plain .jac natively."
        );
        return 1;
    }

    triple = _target_triple(target or (_cfg.native.target if _cfg else ""));
    is_wasm = triple.startswith("wasm32");
    is_windows = (sys.platform == "win32" and not triple) or ("windows" in triple);
    is_macos = (
        (sys.platform == "darwin" and not triple)
        or ("apple" in triple)
        or ("darwin" in triple)
    );
    _prev_target = push_native_target(triple);

    if not output {
        output = base_stem(filename);
        if shared {
            _so_ext = ".dll" if is_windows else (".dylib" if is_macos else ".so");
            output = "lib" + output + _so_ext;
        } elif is_wasm {
            output = output + ".wasm";
        } elif is_windows {
            output = output + ".exe";
        }
    }

    console.print(f"Compiling {filename} to native binary");

    try {
        prog = JacProgram();
        options = CompileOptions(
            aot_mode=True,
            default_codespace="native",
            skip_native_engine=True,
            memory_profile=memory,
            native_target=triple,
            native_debug=(True if debug else None),
            native_link_mode=(link_mode or None),
            no_ir_cache=debug or no_ir_cache
        );
        prog.options = options;
        ir_module = (
            prog.compile(file_path=os.path.abspath(filename), options=options)
                if is_wasm
                else None
        );
        plan = build_link_plan(
            prog, [os.path.abspath(filename)], options, mode=link_mode
        );
    } except LinkPlanError as e {
        console.print(str(e));
        _restore_target(_prev_target);
        return 1;
    } except Exception as e {
        console.error(f"Jac compilation failed: {e}");
        import traceback;
        traceback.print_exc();
        _restore_target(_prev_target);
        return 1;
    }

    if prog.errors_had {
        for _err in prog.errors_had {
            console.print(_err.pretty_print());
        }
        _restore_target(_prev_target);
        return 1;
    }

    if is_wasm and (ir_module is None or ir_module.gen.native_iface is None) {
        if not (ir_module and ir_module.decided_codespace == 'native') {
            console.error(
                "This .jac file is not compatible with native compilation.\n"
                "  It may use walkers, nodes, edges, async, lambdas, or other\n"
                "  constructs not supported by the native backend.\n"
                "  Remove the incompatible constructs it names."
            );
        } else {
            console.error(
                f"Native compilation produced no native unit for {filename} and no\n"
                "  diagnostic explains why; this is a compiler bug -- please report it."
            );
        }
        for _warn in prog.warnings_had {
            console.print(_warn.pretty_print());
        }
        _restore_target(_prev_target);
        return 1;
    }
    console.print("  Auto-promoted to native compilation.");

    python_imports = sorted(
        {name for unit in plan.units for name in unit.iface.python_imports}
    );
    if not lib and not is_wasm and python_imports {
        console.error(
            "Cannot compile to standalone binary: "
            "file has Python/server dependencies (native_imports)."
        );
        for name in python_imports {
            console.error(f"  - {name}");
        }
        _restore_target(_prev_target);
        return 1;
    }

    console.print(
        f"  Link plan: {len(plan.units)} unit(s), mode={plan.mode}, target={plan.triple}"
    );

    if not lib {
        _demoted = plan.demoted_symbols();
        if _demoted {
            console.error(
                f"{len(_demoted)} function(s) in the native closure were demoted to "
                "Python-only: "
                    + ", ".join(_demoted),
                hint="A self-contained binary cannot run a demoted function. Run `jac explain placement` on the file to see why each one failed to lower."
            );
            _restore_target(_prev_target);
            return 1;
        }
    }

    if assert_no_rc {
        (_rc_syms, _rc_probes) = _scan_rc_machinery(_application_ir(plan));
        if _rc_syms or _rc_probes {
            _parts: list[str] = [];
            if _rc_syms {
                _parts.append("RC/collector symbols: " + ", ".join(_rc_syms));
            }
            if _rc_probes {
                _parts.append("entry-point env probes: " + ", ".join(_rc_probes));
            }
            console.error(
                "nogc invariant violated (compiler bug): emitted IR contains "
                    + "; ".join(_parts)
                    + "\n  (module has managed heap types or RC-emitting code;"
                    + " see rc-stats coverage)"
            );
            _restore_target(_prev_target);
            return 1;
        }
        console.print(
            "  nogc invariant ok: 0 __rc_* symbols · 0 trace fns"
            " · no roots buffer · no entry-point env probes"
        );
    }

    if not shared and not is_wasm and not plan.root_unit().iface.entry_symbol {
        console.error(
            "No entry point found. " "The file must have a 'with entry { }' block."
        );
        _restore_target(_prev_target);
        return 1;
    }

    kind = ArtifactKind.SHARED
        if shared
        else (ArtifactKind.WASM if is_wasm else ArtifactKind.EXECUTABLE);
    plan.library_api = shared;
    app_imports: (set | None) = None;
    if is_wasm {
        import from jaclang.compiler.backends.native.wasm_build { app_declared_imports }
        assert ir_module is not None;
        app_imports = app_declared_imports(ir_module);
    }
    try {
        result = link_artifact(
            plan, output, kind, log=console.print, app_imports=app_imports
        );
    } except Exception as e {
        console.error(f"Native link failed: {e}");
        import traceback;
        traceback.print_exc();
        return 1;
    } finally {
        _restore_target(_prev_target);
    }

    file_size = os.path.getsize(output);
    lowered = len(prog.native_units().compiled_paths);
    compiled = set(prog.native_units().compiled_paths);
    reused_units = len(
        [
            u
            for u in plan.units
            if u.path not in compiled
        ]
    );
    console.print(f"  Recompiled {lowered} unit(s); reused {reused_units}.");
    if result.reused {
        console.print(f"  Up to date: {output} ({file_size} bytes).");
        return 0;
    }
    if is_wasm {
        console.print(f"  Wasm module written to {output} ({file_size} bytes).");
        console.print(
            "  Instantiate with the `jac_host1` host object (see @jac/wasm_host)"
            " plus an `env` object for any FFI the app declares."
        );
    } elif shared {
        console.print(f"  Shared library written to {output} ({file_size} bytes).");
        console.print(f"  Class layout written to {output}.layout.json.");
        console.print(f"  Plan digest: {result.plan_digest[:16]}");
        console.print(
            "  Load it from C/ctypes (dlopen + dlsym); the C ABI surface is the "
            "exported `:pub` symbols plus jac_retain/jac_release."
        );
    } else {
        console.print(f"  Binary written to {output} ({file_size} bytes).");
        console.print(f"  Run with: ./{output}");
    }
    return 0;
}


def _restore_target(prev_target: (str | None)) {
    pop_native_target(prev_target);
}


def _sealed_native_plan(filename: str) -> (tuple[object, LinkPlan, any] | None) {
    if not is_jac(filename) {
        console.error("Input must be a .jac file.");
        return None;
    }
    if not os.path.exists(filename) {
        console.error(f"File not found: {filename}");
        return None;
    }
    if is_retired_native_marker(filename) {
        console.error(
            f"{filename}: the .na.jac marker was retired in 0.35 -- rename the "
            "file to .jac; 'jac build --native' compiles plain .jac natively."
        );
        return None;
    }
    prog = JacProgram();
    options = CompileOptions(
        aot_mode=True, default_codespace="native", skip_native_engine=True
    );
    prog.options = options;
    try {
        ir_module = prog.compile(file_path=os.path.abspath(filename), options=options);
        plan = build_link_plan(prog, [os.path.abspath(filename)], options);
    } except Exception as e {
        console.error(f"Jac compilation failed: {e}");
        import traceback;
        traceback.print_exc();
        return None;
    }
    if prog.errors_had {
        for _err in prog.errors_had {
            console.print(_err.pretty_print());
        }
        return None;
    }
    return (prog, plan, ir_module);
}


def _entry_lib_link(plan: LinkPlan, output: str) -> int {
    try {
        link_artifact(plan, output, ArtifactKind.ENTRY_LIB, log=console.print);
    } except LinkPlanError as e {
        console.error(str(e));
        return 1;
    } except Exception as e {
        console.error(f"Entry-library link failed: {e}");
        import traceback;
        traceback.print_exc();
        return 1;
    }
    return 0;
}


def _build_native_entry_lib(filename: str, output: str) -> int {
    built = _sealed_native_plan(filename);
    if built is None {
        return 1;
    }
    (prog, plan, ir_module) = built;
    plan.callback_bindings = _all_callback_bindings(plan, prog, ir_module);
    return _entry_lib_link(plan, output);
}


def _record_proj_dir(filename: str) -> str {
    """The root the interop record's paths are relative to.

    The runner resolves them against the sealed image root, which preserves
    the project tree, so the record must hold project-root-relative paths --
    not paths relative to the entry file's directory (a nested entry at
    `src/main.jac` with a provider at `src/helper.jac` must record
    `src/helper.jac`). Falls back to the entry's directory outside a project.
    """;

    proj_root = project_root_of(os.path.abspath(filename));
    if proj_root {
        return os.path.realpath(proj_root);
    }
    return os.path.dirname(os.path.abspath(filename));
}


def _callback_source_path(binding: any, proj_dir: str) -> str {
    nd = binding.ast_node;
    if nd is not None {
        mod = nd.find_parent_of_type(Module);
        if mod is not None and mod.loc.mod_path {
            return os.path.relpath(
                os.path.realpath(mod.loc.mod_path), proj_dir
            ).replace(
                os.sep, "/"
            );
        }
    }
    return binding.source_module or "";
}


def _type_name_of(expr: any) -> str {
    if expr is None {
        return "int";
    }
    if isinstance(expr, Name) or isinstance(expr, Token) {
        return expr.value;
    }
    return "int";
}


def _callback_binding_from_module(mod: any, name: str) -> (any | None) {
    """Synthesize the na->sv binding for `name` from its defining module.

    A dependency's callback is often absent from every recorded manifest
    (e.g. a function-scoped server import), so the seal derives the binding
    from the module that defines the function.
    """;
    if mod is None or mod.loc is None {
        return None;
    }
    for nd in mod.body {
        if not isinstance(nd, Ability) or nd.name_ref.sym_name != name {
            continue;
        }
        ret_type = "int";
        param_types: list[str] = [];
        if isinstance(nd.signature, FuncSignature) {
            if nd.signature.return_type is not None {
                ret_type = _type_name_of(nd.signature.return_type);
            }
            for p in nd.signature.get_parameters() {
                if p.type_tag {
                    param_types.append(_type_name_of(p.type_tag.tag));
                } else {
                    param_types.append("int");
                }
            }
        }
        return InteropBinding(
            name=name,
            source_context=InteropContext.SERVER,
            callers={InteropContext.NATIVE},
            ret_type=ret_type,
            param_types=param_types,
            ast_node=nd,
            source_module=mod.loc.mod_path or None
        );
    }
    return None;
}


def _all_callback_bindings(plan: any, prog: any, entry_module: any) -> list {
    """Union the na->sv callback bindings of every native unit in the plan,
    not just the entry's.

    `link_artifact` refuses a shared/entry-lib link when ANY unit's Python
    imports lack a callback binding, and `native_build`'s own
    standalone-binary check already aggregates `iface.python_imports` across
    all units. Collecting entry-only let a dependency's callbacks reach
    neither the lane choice nor the interop record.
    """;
    wanted: list[str] = [];
    seen: set = set();
    for unit in plan.units {
        for name in unit.iface.python_imports {
            if name not in seen {
                seen.add(name);
                wanted.append(name);
            }
        }
    }
    if not wanted {
        return [];
    }
    mods: list = [];
    if entry_module is not None {
        mods.append(entry_module);
    }
    for mod in prog.mod.hub.values() {
        if mod is not entry_module {
            mods.append(mod);
        }
    }
    bindings: dict = {};
    for mod in mods {
        manifest = mod.gen.interop_manifest if mod.gen else None;
        if manifest is None {
            continue;
        }
        for binding in manifest.native_imports {
            if binding.name in seen and binding.name not in bindings {
                bindings[binding.name] = binding;
            }
        }
    }
    for name in wanted {
        if name in bindings {
            continue;
        }
        for mod in mods {
            binding = _callback_binding_from_module(mod, name);
            if binding is not None {
                bindings[name] = binding;
                break;
            }
        }
    }
    return [
        bindings[name]
        for name in wanted
        if name in bindings
    ];
}


impl native_build_sealed_pair(filename: str, exe_output: str, lib_output: str) -> int {
    import json;

    built = _sealed_native_plan(filename);
    if built is None {
        return 1;
    }
    (prog, plan, ir_module) = built;
    plan.callback_bindings = _all_callback_bindings(plan, prog, ir_module);
    (glue_bindings, _) = resolved_callback_bindings(plan);
    _interop_record = interop_record_path(lib_output);
    _proj_dir = _record_proj_dir(filename);
    if plan.callback_bindings {
        console.warning(
            "App calls from native code into Python (native_imports): "
            "dropping the standalone executable (it cannot be "
            "self-contained) and sealing the host-driven native library only."
        );
        lib_rc = _entry_lib_link(plan, lib_output);
        if lib_rc != 0 {
            console.error(
                "Host-driven native library compilation failed; seal aborted."
            );
            return lib_rc;
        }
        _interop_record.parent.mkdir(parents=True, exist_ok=True);
        _interop_record.write_text(
            json.dumps(
                {
                    "interop": True,
                    "unresolved": [b.name for b in glue_bindings],
                    "callbacks": [
                        {
                            "name": b.name,
                            "ret_type": b.ret_type,
                            "param_types": list(b.param_types),
                            "source_module": _callback_source_path(b, _proj_dir)
                        } for b in glue_bindings
                    ]
                },
                sort_keys=True
            )
                + "\n",
            encoding="utf-8"
        );
    } else {
        import from jaclang.compiler.backends.native.link_plan {
            ArtifactKind,
            LinkPlanError,
            link_artifact
        }
        if _interop_record.exists() {
            _interop_record.unlink();
        }
        try {
            link_artifact(plan, exe_output, ArtifactKind.EXECUTABLE, log=console.print);
        } except LinkPlanError as e {
            console.error(str(e));
            console.error("Native compilation failed; seal aborted.");
            return 1;
        } except Exception as e {
            console.error(f"Native link failed: {e}");
            import traceback;
            traceback.print_exc();
            return 1;
        }
        lib_rc = _entry_lib_link(plan, lib_output);
        if lib_rc != 0 {
            console.warning(
                "In-process native library compilation failed; the sealed bundle "
                "will run via the standalone binary only."
            );
        }
    }
    return 0;
}
