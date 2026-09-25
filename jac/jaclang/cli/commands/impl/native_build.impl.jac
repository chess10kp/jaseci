import from jaclang.compiler.backends.native.floor {
    collect_floor_archives,
    floor_lib_dir,
    resolve_floor_dir,
    clib_to_archive_name,
    clib_needed_libs,
    clib_symbol_lib_map
}
import os;
import sys;

import from jaclang.cli.console { console }

import from jaclang.compiler.backends.native.entry_points {
    finalize_native_ir,
    validate_native_application,
    NativeIrOptions
}

impl native_build(
    filename: str,
    output: str = "",
    lib: bool = False,
    target: str = "",
    debug: bool = False,
    memory: str = "",
    no_ir_cache: bool = False
) -> int {
    import from jaclang.jac0core.ext_registry { base_stem }

    ctx = _build_context(filename, target, memory, debug, no_ir_cache);
    if ctx is None {
        return 1;
    }
    shared = lib;

    if not output {
        output = base_stem(filename);
        if shared {
            import from jaclang.server.sealed_serve { shared_lib_ext }
            output = "lib" + output + shared_lib_ext(ctx.is_windows, ctx.is_macos);
        } elif ctx.is_wasm {
            output = output + ".wasm";
        } elif ctx.is_windows {
            output = output + ".exe";
        }
    }

    if not _compile_native_module(ctx) {
        return 1;
    }
    ir_module = ctx.ir_module;

    if ctx.is_wasm {
        import from jaclang.compiler.backends.native.na_compile_pass {
            native_linked_ir_text
        }
        import from jaclang.compiler.backends.native.wasm_build {
            emit_wasm_from_ir,
            app_declared_imports
        }
        try {
            wasm_bytes = emit_wasm_from_ir(
                native_linked_ir_text(ir_module),
                app_imports=app_declared_imports(ir_module),
            );
        } except Exception as e {
            console.error(f"Wasm emit/link failed: {e}");
            import traceback;
            traceback.print_exc();
            return 1;
        }
        with open(output, "wb") as _wf {
            _wf.write(wasm_bytes);
        }
        console.print(f"  Wasm module written to {output} ({len(wasm_bytes)} bytes).");
        console.print(
            "  Instantiate with the `jac_host1` host object (see @jac/wasm_host)"
            " plus an `env` object for any FFI the app declares."
        );
        return 0;
    }

    return _link_native_artifact(ctx, output, shared);
}

def _link_native_artifact(
    ctx: NativeBuildContext, output: str, shared: bool, entry_lib: bool = False
) -> int {
    ir_module = ctx.ir_module;
    options = ctx.options;
    is_windows = ctx.is_windows;
    is_macos = ctx.is_macos;
    try {
        llvm_ir_str = validate_native_application(ir_module, shared, ctx.memory);
    } except ValueError as error {
        console.error(str(error));
        return 1;
    }

    console.print("  LLVM IR generated successfully.");

    import jaclang.compiler.backends.native.llvm.binding as llvm;
    import jaclang.compiler.backends.native.shared_emit as _shared_emit;
    import from jaclang.compiler.backends.native.shared_emit { init_object_codegen }
    init_object_codegen();

    triple = (options.native_target or "") or str(llvm.get_default_triple());
    console.print(f"  Target: {triple}");

    export_symbols: list[str] = [];
    init_funcs: list[str] = [];

    clib_paths = ir_module.gen._clib_paths;
    (archive_members, _floor_handled) = collect_floor_archives(
        clib_paths or [], ir_module.gen._clib_symbol_lib, triple, is_macos
    );
    if archive_members {
        console.print(
            f"  Static-linking {len(archive_members)} floor archive member(s)."
        );
    }

    if is_windows {
        needed_libs: list[str] = ["msvcrt.dll"];
    } elif is_macos {
        needed_libs: list[str] = ["/usr/lib/libSystem.B.dylib"];
    } else {
        needed_libs: list[str] = [];
    }
    _lib_norm = clib_needed_libs(needed_libs, clib_paths or [], _floor_handled);

    _is_linux_exec = (not shared) and (not is_windows) and (not is_macos);
    _static_musl = _is_linux_exec and (len(needed_libs) == 0);

    (llvm_ir_str, _extra_exports) = finalize_native_ir(
        llvm_ir_str,
        triple,
        clib_paths or [],
        ir_module.gen.interop_manifest,
        NativeIrOptions(
            shared=shared,
            is_windows=is_windows,
            is_macos=is_macos,
            static_musl=_static_musl,
            emit_entry_stub=entry_lib
        )
    );
    _bound_callbacks: list[any] = [];
    if entry_lib {
        import from jaclang.compiler.backends.native.shared_emit {
            bind_shared_callbacks
        }
        (llvm_ir_str, _bound_callbacks) = bind_shared_callbacks(
            llvm_ir_str,
            ctx.ir_module.gen.interop_manifest.callable_native_imports or []
        );
        ctx.bound_callbacks = _bound_callbacks;
    }
    if shared {
        if entry_lib and "jac_entry" in _extra_exports {
            console.print(
                "  No 'with entry { }' block; synthesized an empty jac_entry"
                " for the entry-lib host protocol."
            );
        }

        init_funcs = [] if entry_lib else ["__jac_shared_init"];
        for _s in ir_module.gen._exported_symbols {
            if _s not in export_symbols {
                export_symbols.append(_s);
            }
        }
        for _s in _extra_exports {
            if _s not in export_symbols {
                export_symbols.append(_s);
            }
        }
        if entry_lib {
            llvm_ir_str = _shared_emit.ensure_argv_globals(llvm_ir_str);
            for _s in ["jac_entry", "__jac_argc", "__jac_argv", "__jac_shared_init"] {
                if _s not in export_symbols {
                    export_symbols.append(_s);
                }
            }
            for _cb in _bound_callbacks {
                _bind_name = "__jac_bind_" + _cb.name;
                if _bind_name not in export_symbols {
                    export_symbols.append(_bind_name);
                }
            }
        }
        if not export_symbols {
            console.error(
                "Nothing to export from a shared library: no `:pub` functions "
                "or globals found. Mark exports with `def:pub` / `glob:pub`."
            );
            return 1;
        }
        console.print(
            f"  Exporting {len(export_symbols)} C-ABI symbol(s): "
                + ", ".join(export_symbols)
        );
    }

    if (shared or (_is_linux_exec and not _static_musl))
        and not is_macos
        and not is_windows {
        if "libc.so.6" not in needed_libs {
            needed_libs.append("libc.so.6");
        }
        if "libm.so.6" not in needed_libs {
            needed_libs.append("libm.so.6");
        }
    }

    symbol_lib_map = clib_symbol_lib_map(
        ir_module.gen._clib_symbol_lib, _floor_handled, _lib_norm, shared, is_macos
    );

    try {
        mod = llvm.parse_assembly(llvm_ir_str);
        if shared {
            import from jaclang.compiler.backends.native.shared_emit {
                internalize_native_implementation
            }
            internalize_native_implementation(
                mod, export_symbols + ["__jac_shared_init"]
            );
        }
        mod.verify();
    } except Exception as e {
        console.error(f"LLVM IR verification failed: {e}");
        return 1;
    }

    _target_ovr = options.native_target or "";
    _llvm_target = (
        llvm.Target.from_triple(_target_ovr)
            if _target_ovr
            else llvm.Target.from_default_triple()
    );
    assert isinstance(_llvm_target, llvm.Target);

    if shared {
        _tm = _llvm_target.create_target_machine(opt=2, reloc="pic", codemodel="small");
    } else {
        _tm = _llvm_target.create_target_machine(opt=2, codemodel="large");
    }
    assert isinstance(_tm, llvm.TargetMachine);
    target_machine = _tm;

    _opt_level = int(options.opt_level or 0);
    _dump_path = options.dump_ir_path or "";

    import from jaclang.compiler.backends.native.shared_emit { optimize_native_module }
    optimize_native_module(mod, target_machine, _opt_level, internalize=not shared);

    if _dump_path {
        with open(_dump_path, "w") as _df {
            _df.write(str(mod));
        }
    }

    obj_bytes = target_machine.emit_object(mod);
    assert isinstance(obj_bytes, bytes);
    console.print(f"  Object code emitted ({len(obj_bytes)} bytes).");

    _spec = _shared_emit._shared_linker_spec(is_windows, is_macos);
    _crt_objects: list[bytes] = [];
    if _static_musl {
        _musl = _collect_musl_static(obj_bytes, triple);
        if _musl is None {
            console.error(
                "Static musl runtime not found. Expected a vendored musl "
                "libc.a under .pbs-build/<arch>/musl/lib (run `zig build "
                "vendor-musl`) or set JAC_NATIVE_MUSL_DIR."
            );
            return 1;
        }
        (_musl_members, _crt_objects) = _musl;
        archive_members = archive_members + _musl_members;
        console.print(
            f"  Static-linking musl: {len(_musl_members)} libc member(s) + "
            f"{len(_crt_objects)} crt object(s)."
        );
    }
    try {
        if shared {
            success = _shared_emit._link_shared_artifact(
                _spec,
                _shared_emit._SharedLinkRequest(
                    obj_bytes=obj_bytes,
                    output_path=output,
                    exports=export_symbols,
                    init_funcs=init_funcs,
                    soname=os.path.basename(output),
                    symbol_lib_map=symbol_lib_map,
                    archive_members=archive_members,
                    needed_libs=needed_libs
                )
            );
        } elif _spec.platform == "windows" {
            success = _spec.linker.link(
                obj_bytes=obj_bytes,
                output_path=output,
                needed_libs=needed_libs,
                symbol_lib_map=symbol_lib_map,
                shared=False,
                export_symbols=export_symbols,
                init_funcs=init_funcs,
                soname=os.path.basename(output)
            );
        } elif _spec.platform == "macos" {
            success = _spec.linker.link(
                obj_bytes=obj_bytes,
                output_path=output,
                needed_libs=needed_libs,
                symbol_lib_map=symbol_lib_map,
                shared=False,
                export_symbols=export_symbols,
                init_funcs=init_funcs,
                soname=os.path.basename(output),
                archive_members=archive_members
            );
        } else {
            success = _spec.linker.link(
                obj_bytes=obj_bytes,
                output_path=output,
                needed_libs=needed_libs,
                crt_objects=_crt_objects,
                shared=False,
                export_symbols=export_symbols,
                init_funcs=init_funcs,
                soname=os.path.basename(output),
                archive_members=archive_members,
                static_link=_static_musl
            );
        }
    } except Exception as e {
        console.error(f"Native linking failed ({_spec.platform}): {e}");
        import traceback;
        traceback.print_exc();
        return 1;
    }
    if not success {
        console.error(
            f"Native linking failed ({_spec.platform}): could not parse object file."
        );
        return 1;
    }

    file_size = os.path.getsize(output);
    if shared {
        console.print(f"  Shared library written to {output} ({file_size} bytes).");
        if ir_module.gen.jc_layout is not None {
            _lay_path = f"{output}.layout.json";
            with open(_lay_path, "w") as _lf {
                _lf.write(ir_module.gen.jc_layout);
            }
            console.print(f"  Class layout written to {_lay_path}.");
        }
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


obj NativeBuildContext {
    has filename: str = "",
        triple: str = "",
        is_wasm: bool = False,
        is_windows: bool = False,
        is_macos: bool = False,
        auto_promote: bool = False,
        memory: str = "managed",
        debug: bool = False,
        no_ir_cache: bool = False,
        ir_module: any = None,
        options: any = None,
        bound_callbacks: list[any] = [];
}

def _compile_native_module(ctx: NativeBuildContext) -> bool {
    import from jaclang.compiler.driver.program { JacProgram }
    import from jaclang.compiler.driver.pipeline_runner { native_application }

    console.print(f"Compiling {ctx.filename} to native binary");
    try {
        prog = JacProgram();
        (_ir_module, _options) = native_application(
            prog, ctx.filename, ctx.triple or '', ctx.memory, ctx.debug, ctx.no_ir_cache
        );
        ctx.ir_module = _ir_module;
        ctx.options = _options;
    } except Exception as e {
        console.error(f"Jac compilation failed: {e}");
        import traceback;
        traceback.print_exc();
        return False;
    }

    if prog.errors_had {
        for _err in prog.errors_had {
            console.print(_err.pretty_print());
        }
        return False;
    }

    if ctx.ir_module is None or ctx.ir_module.gen.llvm_ir is None {
        if ctx.auto_promote
            and not (ctx.ir_module and ctx.ir_module.decided_codespace == 'native') {
            console.error(
                "This .jac file is not compatible with native compilation.\n"
                "  It may use walkers, nodes, edges, async, lambdas, or other\n"
                "  constructs not supported by the native backend.\n"
                "  Remove the incompatible constructs it names."
            );
        } else {
            console.error(
                f"Native compilation produced no LLVM IR for {ctx.filename} "
                "and no\n  diagnostic explains why; this is a compiler bug -- "
                "please report it."
            );
        }
        for _warn in prog.warnings_had {
            console.print(_warn.pretty_print());
        }
        return False;
    }

    if ctx.auto_promote {
        console.print("  Auto-promoted to native compilation.");
    }
    return True;
}


def _resolve_ca_bundle(pkg_root: str) -> (str | None) {
    import os;

    cand = os.path.join(os.path.dirname(pkg_root), "python", "floor", "cacert.pem");
    if os.path.isfile(cand) {
        return cand;
    }

    import glob;
    bundles = sorted(
        `glob.`glob(
            os.path.join(
                pkg_root, ".python-build", "*", "*", "python", "build", "cacert.pem"
            )
        )
    );
    if bundles {
        return bundles[0];
    }
    source_bundles = sorted(
        `glob.`glob(
            os.path.join(
                pkg_root, ".python-build", "*", "python", "build", "cacert.pem"
            )
        )
    );
    if source_bundles {
        return source_bundles[0];
    }
    hits = sorted(
        `glob.`glob(
            os.path.join(
                pkg_root,
                ".python-build",
                "*",
                "python",
                "install",
                "lib",
                "python*",
                "site-packages",
                "pip",
                "_vendor",
                "certifi",
                "cacert.pem"
            )
        )
    );
    return hits[0] if hits else None;
}


def _floor_ca_bundle -> (str | None) {
    import os;
    env = os.environ.get("JAC_NATIVE_CA_BUNDLE", "");
    if env and os.path.isfile(env) {
        return env;
    }
    import jaclang;
    pkg_root = os.path.dirname(os.path.dirname(os.path.abspath(jaclang.__file__)));
    return _resolve_ca_bundle(pkg_root);
}


def _musl_lib_dir(triple: str) -> (str | None) {
    import os;
    import from jaclang.runtime.graph_utils { triple_arch }
    env = os.environ.get("JAC_NATIVE_MUSL_DIR", "");
    if env and os.path.isdir(env) {
        return env;
    }
    import jaclang;
    pkg_root = os.path.dirname(os.path.dirname(os.path.abspath(jaclang.__file__)));
    want = triple_arch(triple);
    pbs = os.path.join(pkg_root, ".pbs-build");
    if os.path.isdir(pbs) {
        for d in sorted(os.listdir(pbs)) {
            libdir = os.path.join(pbs, d, "musl", "lib");
            if os.path.isdir(libdir)
                and os.path.isfile(os.path.join(libdir, "libc.a"))
                and (want in d) {
                return libdir;
            }
        }
    }

    import from jaclang.dist.fused_binary { bundled_floor_roots }
    for floor in bundled_floor_roots(pkg_root) {
        if not os.path.isdir(floor) {
            continue;
        }
        for d in sorted(os.listdir(floor)) {
            cand = os.path.join(floor, d, "musl");
            if os.path.isdir(cand)
                and os.path.isfile(os.path.join(cand, "libc.a"))
                and (want in d) {
                return cand;
            }
        }
    }
    return None;
}


def _collect_musl_static(
    obj_bytes: bytes, triple: str
) -> (tuple[list[bytes], list[bytes]] | None) {
    import os;
    import from jaclang.compiler.backends.native.linker_common {
        select_ar_members,
        _ar_member_undefs
    }
    lib_dir = _musl_lib_dir(triple);
    if lib_dir is None {
        return None;
    }
    libc_a = os.path.join(lib_dir, "libc.a");
    if not os.path.isfile(libc_a) {
        return None;
    }

    crt_objects: list[bytes] = [];
    _have_crt1 = False;
    for crt_name in ["crt1.o", "crti.o", "crtn.o"] {
        p = os.path.join(lib_dir, crt_name);
        if os.path.isfile(p) {
            with open(p, "rb") as _cf {
                crt_objects.append(_cf.read());
            }
            if crt_name == "crt1.o" {
                _have_crt1 = True;
            }
        }
    }
    if not _have_crt1 {
        return None;
    }

    archives_data: list[bytes] = [];
    for af in ["libc.a", "libzigc.a", "libcompiler_rt.a"] {
        p = os.path.join(lib_dir, af);
        if os.path.isfile(p) {
            with open(p, "rb") as _af {
                archives_data.append(_af.read());
            }
        }
    }

    work_roots: list[str] = [];
    known: set[str] = set();
    for blob in [obj_bytes] + crt_objects {
        for u in _ar_member_undefs(blob) {
            if u not in known {
                known.add(u);
                work_roots.append(u);
            }
        }
    }

    import hashlib;
    member_bytes: list[bytes] = [];
    seen_members: set[bytes] = set();
    changed = True;
    while changed {
        changed = False;
        for data in archives_data {
            for m in select_ar_members(data, work_roots) {
                key = hashlib.sha256(m.data).digest();
                if key in seen_members {
                    continue;
                }
                seen_members.add(key);
                member_bytes.append(m.data);
                changed = True;
                for u in _ar_member_undefs(m.data) {
                    if u not in known {
                        known.add(u);
                        work_roots.append(u);
                    }
                }
            }
        }
    }

    return (member_bytes, crt_objects);
}


def _build_context(
    filename: str,
    target: str = "",
    memory: str = "",
    debug: bool = False,
    no_ir_cache: bool = False
) -> (NativeBuildContext | None) {
    import sys;
    import from jaclang.jac0core.ext_registry {
        is_jac,
        is_retired_native_marker,
        base_stem
    }
    import from jaclang.project { get_config }
    import from jaclang.cli.console { console }

    _cfg = get_config();
    _mem_cfg = _cfg.memory if _cfg else None;
    if not memory {
        memory = _mem_cfg.profile if _mem_cfg else "managed";
    }
    if memory not in ("managed", "rc", "nogc") {
        console.error(
            f"Invalid --memory profile '{memory}' (expected: managed, rc, nogc)"
        );
        return None;
    }
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

    is_wasm = target in ["wasm", "wasm32", "wasm32-unknown-unknown"];
    _triple = "wasm32-unknown-unknown" if is_wasm else "";

    is_windows = (sys.platform == "win32")
        or ("windows" in target)
        or (target in ["win", "win64", "mingw"]);
    if is_windows {
        _triple = target if "-" in target else "x86_64-pc-windows-msvc";
    }

    is_macos_target = (target in ["macos", "darwin", "osx", "macosx"])
        or ("apple" in target)
        or ("darwin" in target);
    if is_macos_target {
        _triple = target if "-" in target else "arm64-apple-darwin";
    }

    is_linux_target = (target in ["linux", "elf"])
        or ("linux-gnu" in target)
        or ("linux-musl" in target);
    if is_linux_target {
        _triple = target if "-" in target else "x86_64-unknown-linux-gnu";
    }

    is_macos = ((sys.platform == "darwin") and not is_windows and not is_linux_target)
        or is_macos_target;

    return NativeBuildContext(
        filename=filename,
        triple=_triple,
        is_wasm=is_wasm,
        is_windows=is_windows,
        is_macos=is_macos,
        auto_promote=is_jac(filename),
        memory=memory,
        debug=debug,
        no_ir_cache=no_ir_cache
    );
}

def _build_native_entry_lib(filename: str, output: str) -> int {
    ctx = _build_context(filename);
    if ctx is None {
        return 1;
    }
    if not _compile_native_module(ctx) {
        return 1;
    }
    return _link_native_artifact(ctx, output, shared=True, entry_lib=True);
}

def _callback_source_path(binding: any, proj_dir: str) -> str {
    nd = binding.ast_node;
    if nd is not None {
        import from jaclang.compiler.frontend.unitree { Module }
        mod = nd.find_parent_of_type(Module);
        if mod is not None and mod.loc.mod_path {
            return os.path.relpath(mod.loc.mod_path, proj_dir);
        }
    }
    return binding.source_module or "";
}

impl native_build_sealed_pair(filename: str, exe_output: str, lib_output: str) -> int {
    import json;
    import from jaclang.server.sealed_serve { interop_record_path }
    import from jaclang.cli.console { console }

    ctx = _build_context(filename);
    if ctx is None {
        return 1;
    }
    if not _compile_native_module(ctx) {
        return 1;
    }
    _mf = ctx.ir_module.gen.interop_manifest;
    _interop_record = interop_record_path(lib_output);
    if _mf is not None and _mf.native_imports {
        console.warning(
            "App calls from native code into Python (native_imports): "
            "dropping the standalone executable (it cannot be "
            "self-contained) and sealing the host-driven native library only."
        );
        lib_rc = _link_native_artifact(ctx, lib_output, shared=True, entry_lib=True);
        if lib_rc != 0 {
            console.error(
                "Host-driven native library compilation failed; seal aborted."
            );
            return lib_rc;
        }
        _proj_dir = os.path.dirname(os.path.abspath(filename));
        _interop_record.parent.mkdir(parents=True, exist_ok=True);
        _interop_record.write_text(
            json.dumps(
                {
                    "interop": True,
                    "unresolved": [b.name for b in ctx.bound_callbacks],
                    "callbacks": [
                        {
                            "name": b.name,
                            "ret_type": b.ret_type,
                            "param_types": list(b.param_types),
                            "source_module": _callback_source_path(b, _proj_dir)
                        } for b in ctx.bound_callbacks
                    ]
                },
                sort_keys=True
            )
                + "\n",
            encoding="utf-8"
        );
    } else {
        if _interop_record.exists() {
            _interop_record.unlink();
        }
        rc = _link_native_artifact(ctx, exe_output, shared=False);
        if rc != 0 {
            console.error("Native compilation failed; seal aborted.");
            return rc;
        }
        lib_rc = _link_native_artifact(ctx, lib_output, shared=True, entry_lib=True);
        if lib_rc != 0 {
            console.warning(
                "In-process native library compilation failed; the sealed bundle "
                "will run via the standalone binary only."
            );
        }
    }
    return 0;
}
