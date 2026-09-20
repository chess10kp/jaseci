import from jaclang.cli.console { console }
import from jaclang.client { get_bun }
import from jaclang.client.bun_installer { bun_unavailable_message }
import from jaclang.client.client_bundle { ClientBundleError, MissingBunError }


def _require_bun -> str {
    bun = get_bun();
    if not bun {
        raise MissingBunError(bun_unavailable_message()) from None;
    }
    return bun;
}

impl client_deps_stale(build_dir: Path) -> bool {
    import hashlib;
    node_modules = build_dir / 'node_modules';
    if not node_modules.exists() {
        return True;
    }
    manifest = build_dir / 'configs' / 'package.json';
    if not manifest.exists() {
        return False;
    }

    marker = node_modules / '.jac-deps-hash';
    current = hashlib.sha256(manifest.read_bytes()).hexdigest();
    if not marker.exists() {
        return True;
    }
    return marker.read_text(encoding='utf-8').strip() != current;
}

impl ViteBundler.install_packages(
    self: ViteBundler,
    install_dir: Optional[Path] = None,
    force: bool = False,
    capture_output: bool = False,
    clean_stale: bool = False
) -> None {
    import time;
    import shutil;
    import subprocess;
    bun = _require_bun();
    build_dir = install_dir if install_dir is not None else self._get_client_dir();
    node_modules = build_dir / 'node_modules';

    if not force {
        if clean_stale {
            vite_bin = node_modules / '.bin' / 'vite';
            if node_modules.exists() and not vite_bin.exists() {
                shutil.rmtree(node_modules);
            }
        }
        if node_modules.exists() and not client_deps_stale(build_dir) {
            return;
        }
    }

    configs_package_json = build_dir / 'configs' / 'package.json';
    if not configs_package_json.exists() {
        self.create_package_json();
    }
    build_package_json = build_dir / 'package.json';
    if configs_package_json.exists() {
        shutil.copy2(configs_package_json, build_package_json);
    }
    configs_npmrc = build_dir / 'configs' / '.npmrc';
    build_npmrc = build_dir / '.npmrc';
    if configs_npmrc.exists() and not build_npmrc.exists() {
        shutil.copy2(configs_npmrc, build_npmrc);
    }

    try {
        console.print("\n  ⏳ Installing dependencies...\n");
        start_time = time.time();
        result = subprocess.run(
            [bun, 'install'],
            cwd=build_dir,
            check=False,
            text=True,
            capture_output=capture_output
        );
        elapsed = time.time() - start_time;
        if result.returncode != 0 {
            if capture_output {
                error_output = result.stderr or result.stdout;
                raise ClientBundleError(
                    f"Dependency installation failed after {elapsed:.1f}s\n\n{error_output}\nCommand: bun install"
                ) from None;
            }
            console.error(f"\n  ✖ bun install failed after {elapsed:.1f}s");
            raise ClientBundleError("Failed to install dependencies") from None;
        }
        console.print(f"\n  ✔ Dependencies installed ({elapsed:.1f}s)");
        if configs_package_json.exists() and (build_dir / 'node_modules').exists() {
            import hashlib;
            (build_dir / 'node_modules' / '.jac-deps-hash').write_text(
                hashlib.sha256(configs_package_json.read_bytes()).hexdigest(),
                encoding='utf-8'
            );
        }
    } finally {
        if build_package_json.exists() {
            build_package_json.unlink();
        }
        if build_npmrc.exists() {
            build_npmrc.unlink();
        }

        build_bun_lockb = build_dir / 'bun.lockb';
        if build_bun_lockb.exists() {
            configs_bun_lockb = build_dir / 'configs' / 'bun.lockb';
            if configs_bun_lockb.exists() {
                configs_bun_lockb.unlink();
            }
            shutil.move(str(build_bun_lockb), str(configs_bun_lockb));
        }
    }
}

impl ViteBundler.add_packages(
    self: ViteBundler,
    packages: list[str],
    install_dir: Optional[Path] = None,
    dev: bool = False
) -> None {
    import json;
    import subprocess;
    import from jaclang.client { get_bun }
    target_dir = install_dir if install_dir is not None else self.project_dir;
    pkg_json = target_dir / 'package.json';
    if not pkg_json.exists() {
        pkg_data = {
            'name': 'jac-mobile-app',
            'version': '1.0.0',
            'private': True,
            'type': 'module'
        };
        pkg_json.write_text(json.dumps(pkg_data, indent=2), encoding='utf-8');
        console.print("  ✔ Created package.json");
    }

    bun = get_bun();
    if bun is None {
        raise RuntimeError("bun unavailable: cannot install client dependencies");
    }
    cmd = [bun, 'add'];
    if dev {
        cmd.append('--dev');
    }
    cmd.extend(packages);
    console.print(f"  Installing: {' '.join(packages)}");
    subprocess.run(cmd, cwd=target_dir, check=True, capture_output=False);
}

impl ViteBundler.init(
    self: ViteBundler,
    project_dir: Path,
    output_dir: Optional[Path] = None,
    minify: bool = False,
    config_path: Optional[Path] = None,
    entry_path: str = ""
) {
    import from jaclang.project.config { find_project_root }
    project_root = find_project_root(project_dir);
    self.project_dir = project_root[0] if project_root else project_dir;
    self.minify = minify;
    self.config_path = config_path;
    self.config_loader = JacClientConfig(self.project_dir, entry_path=entry_path);

    self.output_dir = output_dir or (self._client_app_dir() / 'dist');

    self.dev_server_port = 0;
}

impl ViteBundler._ensure_dev_dependencies(self: ViteBundler, build_dir: Path) -> None {
    self.install_packages(install_dir=build_dir);
}
