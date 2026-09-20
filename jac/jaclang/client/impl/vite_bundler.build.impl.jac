import from jaclang.cli.console { console }
import from jaclang.client.client_bundle { ClientBundleError, MissingBunError }


impl ViteBundler.read_bundle(self: ViteBundler) -> tuple[str, str] {
    bundle_file = self.find_bundle();
    if not bundle_file {
        raise ClientBundleError('Vite build completed but no bundle file found');
    }
    bundle_code = bundle_file.read_text(encoding='utf-8');
    bundle_hash = hashlib.sha256(bundle_code.encode('utf-8')).hexdigest();
    return (bundle_code, bundle_hash);
}

impl ViteBundler.find_css(self: ViteBundler) -> Optional[Path] {
    css_file = self.output_dir / 'styles.css';
    return css_file if css_file.exists() else None;
}

impl ViteBundler.find_bundle(self: ViteBundler) -> Optional[Path] {
    for file in self.output_dir.`glob('client.*.js') {
        return file;
    }
    return None;
}

impl ViteBundler.build(self: ViteBundler, entry_file: Optional[Path] = None) -> None {
    import time;
    import from jaclang.client { ensure_client_deps }

    bun = _require_bun();

    if not ensure_client_deps(self.config_loader) {
        raise ClientBundleError(
            'Client dependencies not configured. Add [dependencies.npm] to jac.toml '
            'or create a project with: jac create --kind web-app'
        ) from None;
    }
    self.output_dir.mkdir(parents=True, exist_ok=True);

    self.create_package_json();
    build_dir = self._get_client_dir();

    self.install_packages(install_dir=build_dir, capture_output=True, clean_stale=True);
    if self.config_path {
        try {
            config_arg = str(self.config_path.relative_to(build_dir));
        } except ValueError {
            config_arg = str(self.config_path);
        }
        command = _build_vite_command(build_dir, ['build', '--config', config_arg]);
    } elif entry_file {
        generated_config = self.create_vite_config(entry_file);
        config_rel = generated_config.relative_to(build_dir);
        command = _build_vite_command(
            build_dir, ['build', '--config', str(config_rel)]
        );
    } else {
        command = [bun, 'run', 'build'];
    }

    console.print("\n  ⏳ Building client bundle...\n");
    start_time = time.time();
    result = subprocess.run(
        command, cwd=build_dir, check=False, text=True, capture_output=True
    );
    elapsed = time.time() - start_time;
    if result.returncode != 0 {
        error_output = result.stderr or result.stdout;
        error_msg = f"Vite build failed after {elapsed:.1f}s\n\n{error_output}\nCommand: {' '.join(
            command
        )}";
        raise ClientBundleError(error_msg) from None;
    }
    console.print(f"\n  ✔ Client bundle built ({elapsed:.1f}s)");
}
