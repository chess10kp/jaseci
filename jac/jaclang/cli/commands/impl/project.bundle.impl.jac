import os;
import sys;
import shutil;
import subprocess;
import tempfile;
import importlib.metadata;
import from pathlib { Path }
import from jaclang.cli.console { console }
import from jaclang.dist.seal {
    make_sealed_image as _make_sealed_image,
    tar_gz_dir as _tar_gz_dir,
    vendor_jab_deps as _vendor_jab_deps,
    build_jab
}


def _bundle_wheel(config: any, output: str) -> int {
    import from jaclang.dist.publish.builder { WheelBuilder }

    out_dir = Path(output);
    out_dir.mkdir(parents=True, exist_ok=True);
    builder = WheelBuilder(config=config, project_root=config.project_root);

    console.print("\n  Transpiling Jac → Python and building wheel", style="muted");
    try {
        whl_path = builder.build_to(out_dir);
    } except Exception as e {
        console.error(f"Wheel build failed: {e}");
        return 1;
    }
    if builder.skipped_codespace {
        console.print(
            f"  ⚠ skipped {len(builder.skipped_codespace)} client "
            "client codespace file(s) — not part of a Python wheel",
            style="warning"
        );
    }
    if builder.vendored_runtime_modules {
        console.print(
            f"  ✔ vendored jac runtime ({builder.vendored_runtime_modules} modules) "
            "— wheel runs without jaclang installed",
            style="success"
        );
    }
    console.print(
        f"  ✔ Built {whl_path.name} ({whl_path.stat().st_size:,} bytes)",
        style="success"
    );

    console.print("  Building sdist", style="muted");
    try {
        sdist_path = builder.build_sdist_to(out_dir);
    } except Exception as e {
        console.error(f"Sdist build failed: {e}");
        return 1;
    }
    console.print(
        f"  ✔ {sdist_path.name} ({sdist_path.stat().st_size:,} bytes)", style="success"
    );

    console.print(
        f"\n  Distributions written to: [cyan]{out_dir}[/cyan]", style="bold"
    );
    console.print("  Upload with: twine upload dist/*", style="muted");
    return 0;
}

def _bundle_sealed(config: any, output: str, app: str = "") -> int {
    name = config.project.name;
    Path(output).mkdir(parents=True, exist_ok=True);
    console.print(f"\n  Sealing {name}", style="muted");
    dest = _make_sealed_image(
        config, Path(output), f"{name}-sealed", out_dir=Path(output), app=app
    );
    if dest is None {
        return 1;
    }
    console.print(
        f"  ✔ Sealed image at [cyan]{dest}[/cyan] (JIR-authoritative; _precompiled/MANIFEST.json; sources retained for tracebacks)",
        style="success"
    );
    console.print(
        "  Load in a host jac via jaclang.jac0core.sealed.register_image(<dir>/_precompiled).",
        style="muted"
    );
    return 0;
}

def _bundle_jab(config: any, output: str, fat: bool = False, app: str = "") -> int {
    name = config.project.name;
    out_jab = Path(output) / f"{name}.jab";
    console.print(f"\n  Sealing {name}", style="muted");
    try {
        build_jab(config, out_jab, app=app, fat=fat);
    } except RuntimeError as e {
        console.error(str(e));
        return 1;
    }
    console.print(
        f"  ✔ Built [cyan]{out_jab}[/cyan] ({out_jab.stat().st_size:,} bytes)",
        style="success"
    );
    console.print(f"  Run it anywhere: jac run {out_jab.name}", style="muted");
    return 0;
}

def _bundle_binary(config: any, output: str, fat: bool = False, app: str = "") -> int {
    import sys;
    import os;
    import shutil;
    import subprocess;
    import tempfile;
    import from jaclang.jac0core.sealed { MANIFEST_NAME }
    import from jaclang.dist.jab { jab_app_meta }

    name = config.project.name;
    jac_bin = os.path.realpath(sys.executable);

    import from jaclang.dist.fused_binary { has_runtime, append_overlay }
    if not has_runtime(jac_bin) {
        console.error(
            "jac build --as binary needs a bundled single-file jac to carry the "
            "runtime; the current interpreter is not one (source / pip install).",
            hint="Run it with an installed single-file jac binary."
        );
        return 1;
    }

    Path(output).mkdir(parents=True, exist_ok=True);
    work = Path(tempfile.mkdtemp(prefix="jacbin-", dir=output));
    out_bin = Path(output) / name;
    try {
        console.print(f"\n  Sealing {name} for binary", style="muted");
        img = _make_sealed_image(config, work, name, out_dir=Path(output), app=app);
        if img is None {
            return 1;
        }
        if not (img / "_precompiled" / MANIFEST_NAME).is_file() {
            console.error("Seal produced no manifest; aborting binary.");
            return 1;
        }

        if not (jab_app_meta(img).get("entry") or {}).get("path") {
            console.error(
                f"No runnable entry for '{name}'; a --as binary app needs an entry "
                "(main.jac at the package root, or [project] entry-point in jac.toml).",
                hint="Package-only projects have nothing to run as a binary."
            );
            return 1;
        }

        if fat and not _vendor_jab_deps(config, img) {
            return 1;
        }

        jab_path = work / f"{name}.jab";
        jab_path.write_bytes(_tar_gz_dir(img));

        console.print("  Appending app image onto the jac runtime", style="muted");

        if not append_overlay(jac_bin, str(jab_path), str(out_bin))
            or not out_bin.is_file() {
            console.error("Failed to append the app image onto the jac runtime.");
            return 1;
        }
    } finally {
        shutil.rmtree(work, ignore_errors=True);
    }
    console.print(
        f"  ✔ Built self-contained binary [cyan]{out_bin}[/cyan] "
        f"({out_bin.stat().st_size:,} bytes)",
        style="success"
    );
    console.print(f"  Run it directly: {out_bin.resolve()}", style="muted");
    return 0;
}

def _bundle_npm(config: any, output: str) -> int {
    import from jaclang.dist.publish.npm_builder { NpmBuilder }
    import from jaclang.dist.publish.npm_sources { NpmBoundaryError }

    out_dir = Path(output);
    out_dir.mkdir(parents=True, exist_ok=True);
    console.print("\n  Building npm tarball", style="muted");
    try {
        builder = NpmBuilder(config=config, project_root=config.project_root);
        tgz_path = builder.build_to(out_dir);
    } except NpmBoundaryError as e {
        console.error(f"npm build failed: {e}");
        return 1;
    } except Exception as e {
        console.error(f"npm build failed: {e}");
        return 1;
    }
    console.print(
        f"  ✔ Built {tgz_path.name} ({tgz_path.stat().st_size:,} bytes)",
        style="success"
    );
    console.print(f"  Tarball written to: {tgz_path}", style="cyan");
    console.print("  Publish with: npm publish", style="muted");
    return 0;
}

def _bundle_npm_runtime(output: str, framework: str = "") -> int {
    import from jaclang.dist.publish.runtime_npm { build_runtime_to, runtime_pkg_name }
    import importlib.metadata;

    version = importlib.metadata.version("jaclang");
    pkg_name = runtime_pkg_name(framework);
    out_dir = Path(output);
    console.print(f"\nBuilding {pkg_name} v{version}", style="bold");
    console.print("\n  Compiling runtime → npm tarball", style="muted");
    try {
        path = build_runtime_to(out_dir, version, framework=framework);
    } except Exception as e {
        console.error(f"runtime build failed: {e}");
        return 1;
    }
    console.print(
        f"  ✔ Built {path.name} ({path.stat().st_size:,} bytes)", style="success"
    );
    console.print(f"  Tarball written to: {path}", style="cyan");
    console.print("  Publish with: npm publish", style="muted");
    return 0;
}

impl bundle(
    output: str = "dist", target: str = "wheel", fat: bool = False, app: str = ""
) -> int {
    import from jaclang.project.config { get_config }

    if target == "npm-runtime" {
        return _bundle_npm_runtime(output);
    }

    config = get_config();
    if config is None {
        console.error(
            "No jac.toml found", hint="Run 'jac create' to create a project."
        );
        return 1;
    }
    if config.project.name is None {
        console.error(
            "No project name in jac.toml",
            hint="Add 'name' under [project] to use jac bundle."
        );
        return 1;
    }
    if target == "sealed" {
        return _bundle_sealed(config, output, app=app);
    }
    if target == "jab" {
        return _bundle_jab(config, output, fat=fat, app=app);
    }
    if target == "binary" {
        return _bundle_binary(config, output, fat=fat, app=app);
    }
    if target not in ("wheel", "npm", "all") {
        console.error(
            f"Unknown bundle target: '{target}'",
            hint="Use --target wheel, npm, sealed, binary, or all."
        );
        return 1;
    }

    console.print(
        f"\nBundling {config.project.name} " f"v{config.project.version} ({target})",
        style="bold"
    );

    if target in ("wheel", "all") {
        if _bundle_wheel(config, output) != 0 {
            return 1;
        }
    }
    if target in ("npm", "all") {
        if _bundle_npm(config, output) != 0 {
            return 1;
        }
    }
    return 0;
}
