impl MicroserviceGateway.serve_static(file_path: str) -> Response | None {
    dist = Path(self.client_dist_dir);
    target = dist / file_path;

    try {
        resolved = target.resolve();
        dist_resolved = dist.resolve();

        if not resolved.is_relative_to(dist_resolved) {
            return None;
        }
    } except OSError {
        return None;
    }

    if not target.is_file() {
        return None;
    }

    (content_type, _) = mimetypes.guess_type(str(target));
    if content_type is None {
        content_type = "application/octet-stream";
    }

    if content_type.startswith("text/")
        or content_type in ("application/javascript", "application/json") {
        return Response(
            content=target.read_text(encoding="utf-8"), media_type=content_type
        );
    }
    return Response(content=target.read_bytes(), media_type=content_type);
}


impl MicroserviceGateway.serve_project_static(rest: str) -> Response | None {
    if not rest {
        return None;
    }
    project_root = Path(self.base_path);
    file_name: str = Path(rest).name;
    candidate_dirs: list[str] = [
        "assets",
        "dist",
        "public",
        ".jac/client/dist",
        ".jac/client/compiled",
        ".jac/client/compiled/assets"
    ];
    for d in candidate_dirs {
        local_dir: str = str(project_root / d);

        for candidate in (rest, file_name) {
            resp = self.serve_extra_static(local_dir, candidate);
            if resp {
                return resp;
            }
        }
    }
    return None;
}


impl MicroserviceGateway.serve_extra_static(
    local_dir: str, file_path: str
) -> Response | None {
    if not local_dir {
        return None;
    }
    base = Path(local_dir);
    target = base / file_path;

    try {
        resolved = target.resolve();
        base_resolved = base.resolve();
        if not resolved.is_relative_to(base_resolved) {
            return None;
        }
    } except OSError {
        return None;
    }

    if not target.is_file() {
        return None;
    }

    (content_type, _) = mimetypes.guess_type(str(target));
    if content_type is None {
        content_type = "application/octet-stream";
    }

    if content_type.startswith("text/")
        or content_type in ("application/javascript", "application/json") {
        return Response(
            content=target.read_text(encoding="utf-8"), media_type=content_type
        );
    }
    return Response(content=target.read_bytes(), media_type=content_type);
}


impl MicroserviceGateway.has_client_bundle -> bool {
    if (Path(self.client_dist_dir) / "index.html").is_file() {
        return True;
    }
    root_svc = self.root_member();
    return root_svc is not None and root_svc.owns_root();
}


impl MicroserviceGateway.serve_spa_fallback -> Response | None {
    index = Path(self.client_dist_dir) / "index.html";
    if index.is_file() {
        return HTMLResponse(content=index.read_text(encoding="utf-8"));
    }
    return None;
}


impl MicroserviceGateway.bootstrap_admin_ui -> None {
    if (Path(self.admin_dist_dir) / "index.html").is_file() {
        return;
    }
    logger.info(
        "No staged admin console; the first request to /admin builds it from source."
    );
}


impl MicroserviceGateway.serve_admin_asset(asset_path: str) -> Response | None {
    admin_dist = Path(self.admin_dist_dir);

    if not asset_path or asset_path == "/" {
        target = admin_dist / "index.html";
    } else {
        target = admin_dist / asset_path;
    }

    try {
        resolved = target.resolve();
        dist_resolved = admin_dist.resolve();
        if not resolved.is_relative_to(dist_resolved) {
            return None;
        }
    } except OSError {
        return None;
    }

    if not target.is_file() {
        index = admin_dist / "index.html";
        if index.is_file() {
            return HTMLResponse(content=index.read_text(encoding="utf-8"));
        }
        return None;
    }

    (content_type, _) = mimetypes.guess_type(str(target));
    if content_type is None {
        content_type = "application/octet-stream";
    }

    if content_type.startswith("text/")
        or content_type in ("application/javascript", "application/json") {
        return Response(
            content=target.read_text(encoding="utf-8"), media_type=content_type
        );
    }
    return Response(content=target.read_bytes(), media_type=content_type);
}


impl MicroserviceGateway.handle_static(request: Request, path: str) -> Response | None {
    if request.method != "GET" {
        return None;
    }

    file_path: str = path.lstrip("/");
    if not file_path {
        return None;
    }

    mount_matched = False;
    for mount in self.static_mounts {
        prefix = str(mount.get("url_prefix", "")).lstrip("/").rstrip("/");
        if not prefix or file_path == prefix {
            continue;
        }
        if file_path.startswith(prefix + "/") {
            mount_matched = True;
            sub_path = file_path[len(prefix) + 1:];
            local_dir = str(mount.get("local_path", ""));
            mounted_resp = self.serve_extra_static(local_dir, sub_path);
            if mounted_resp {
                return mounted_resp;
            }
            break;
        }
    }

    if not mount_matched {
        static_resp = self.serve_static(file_path);
        if static_resp {
            return static_resp;
        }
    }

    if file_path.startswith("static/") {
        return self.serve_project_static(file_path[len("static/"):]);
    }
    return None;
}


impl MicroserviceGateway.handle_spa_fallback(
    request: Request, path: str
) -> Response | None {
    if request.method != "GET" {
        return None;
    }
    if not path.lstrip("/") {
        return self.serve_spa_fallback();
    }
    if "text/html" in request.headers.get("accept", "") {
        return self.serve_spa_fallback();
    }
    return None;
}
