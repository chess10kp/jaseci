impl pack_jab(
    project_dir: str, seal_binary: bytes, pod_arch: str = "", fleet: any = None
) -> bytes {
    if not seal_binary {
        raise ValueError(
            "pack_jab requires a host-runnable jac binary to seal the app "
            "image; none given."
        );
    }
    base = Path(project_dir).resolve();
    if not base.is_dir() {
        raise ValueError(
            f"App project directory does not exist: {base}. A deploy seals "
            "the project tree; check the code_folder path."
        );
    }
    excluded = source_filter_for(base);
    assert_entry_module_ships(base, excluded);
    sources = bundle_source_files(base);
    check_fleet_entries(
        base, [path.relative_to(base).as_posix() for path in sources], excluded, fleet
    );
    if excluded.ignore_patterns {
        logger.info(
            f"Honoring {len(excluded.ignore_patterns)} .jacignore pattern(s) "
            f"while staging the app bundle."
        );
    }
    sanitized = sanitized_jac_toml(base);
    staged = _precompile_app(
        base, seal_binary, sanitized, seal_timeout_setting(project_dir)
    );

    try {
        (fat, fat_explicit) = fat_bundle_setting(project_dir);
        if fat {
            try {
                _vendor_stage(staged, seal_binary, _pod_wheel_platform(pod_arch));
            } except Exception as exc {
                if fat_explicit {
                    raise;
                }

                shutil.rmtree(str(staged / "_vendor"), ignore_errors=True);
                logger.warning(
                    f"Fat bundle vendoring failed; shipping a thin bundle "
                    f"(pods will install python deps from PyPI at boot). "
                    f"Set [scale] fat_bundle = true to make this fatal. {exc}"
                );
            }
        }
        if (
            not os.environ.get("JAC_SEAL_SKIP_VENV")
            and (staged / "_vendor" / "wheels").is_dir()
        ) {
            try {
                _venv_stage(staged, seal_binary, seal_timeout_setting(project_dir));
            } except Exception as exc {
                shutil.rmtree(str(staged / ".jac" / "venv"), ignore_errors=True);
                logger.warning(
                    f"Seal-time venv staging failed; pods will build the venv "
                    f"at boot instead. {exc}"
                );
            }
        }
        buf = io.BytesIO();
        (tar, gz) = open_det_tar(buf);
        try {
            with tar {
                add_source_members(tar, base, sources=sources);
                pre = staged / "_precompiled";
                count = 0;
                for path in sorted(pre.rglob("*")) {
                    if path.is_file() {
                        rel = path.relative_to(staged);
                        tar.add(str(path), arcname=str(rel), filter=det_tar_member);
                        count += 1;
                    }
                }
                logger.info(
                    f"Sealed {count} precompiled app-module artifacts into the .jab."
                );
                import from jaclang.server.sealed_serve { SERVE_MANIFEST_REL }
                serve_manifest = staged / SERVE_MANIFEST_REL;
                if serve_manifest.is_file() {
                    tar.add(
                        str(serve_manifest),
                        arcname=SERVE_MANIFEST_REL,
                        filter=det_tar_member
                    );
                }
                ven = staged / "_vendor";
                if ven.is_dir() {
                    wheel_count = 0;
                    for path in sorted(ven.rglob("*")) {
                        if path.is_file() {
                            rel = path.relative_to(staged);
                            tar.add(str(path), arcname=str(rel), filter=det_tar_member);
                            if path.suffix == ".whl" {
                                wheel_count += 1;
                            }
                        }
                    }
                    logger.info(
                        f"Fat bundle: vendored {wheel_count} wheel(s) into the "
                        f".jab; pods install python deps offline."
                    );
                }
                venv_files = staged_venv_files(staged);
                for path in venv_files {
                    rel = path.relative_to(staged);
                    tar.add(str(path), arcname=str(rel), filter=det_tar_member);
                }
                if venv_files {
                    logger.info(
                        f"Sealed a prebuilt venv ({len(venv_files)} files) "
                        f"into the .jab; pods skip the boot-time dependency "
                        f"install."
                    );
                }
                if sanitized is not None {
                    data = sanitized.encode("utf-8");
                    info = tarfile.TarInfo(name="jac.toml");
                    info.size = len(data);
                    tar.addfile(info, io.BytesIO(data));
                }
                for (toml_rel, toml_text) in nested_sanitized_tomls(base).items() {
                    data = toml_text.encode("utf-8");
                    info = tarfile.TarInfo(name=toml_rel);
                    info.size = len(data);
                    tar.addfile(info, io.BytesIO(data));
                }
            }
        } finally {
            gz.close();
        }
        return buf.getvalue();
    } finally {
        remove_stage_root(staged.parent);
    }
}


impl content_address(raw: bytes) -> str {
    return hashlib.sha256(raw).hexdigest();
}


impl bundle_object_key(app_name: str, digest: str) -> str {
    return f"bundles/{app_name}/{digest}.jab";
}


impl ensure_jac_toml_cmd -> str {
    return (
        f"[ -f {APP_MOUNT_PATH}/jac.toml ] || "
        f"printf '[project]\\nname = \"app\"\\n' > {APP_MOUNT_PATH}/jac.toml"
    );
}
