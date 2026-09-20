import mimetypes;
import subprocess;
import from jaclang.server.serving.datatypes { RedirectResponse }


impl JacAPIServerAdmin.get_admin_dist_dir -> Path {
    import os;

    cwd = Path(os.getcwd());
    return cwd / ".jac" / "admin";
}


def _copy_dir_contents(src: Path, dst: Path) {
    import shutil;
    dst.mkdir(parents=True, exist_ok=True);
    for item in src.iterdir() {
        dest = dst / item.name;
        if item.is_dir() {
            if dest.exists() {
                shutil.rmtree(dest);
            }
            shutil.copytree(item, dest);
        } else {
            shutil.copy2(item, dest);
        }
    }
}


impl JacAPIServerAdmin.build_admin_client(force: bool = False) -> bool {
    dist_dir = self.get_admin_dist_dir();
    index_file = dist_dir / "index.html";

    if not force and index_file.exists() {
        logger.debug("Admin client already built");
        return True;
    }

    import from jaclang.scale.admin { admin_portal }
    admin_dir = Path(admin_portal.__file__).parent;

    ui_dir = admin_dir / "ui";
    if not (ui_dir / "main.jac").exists() {
        logger.error(f"Admin UI source not found at {ui_dir}");
        return False;
    }
    logger.info("Building admin client from source...");
    try {
        result = subprocess.run(
            ["jac", "build", "--as", "client", "main.jac"],
            cwd=str(ui_dir),
            capture_output=True,
            text=True,
            timeout=300
        );

        if result.returncode != 0 {
            logger.error(f"Admin client build failed: {result.stderr}");
            return False;
        }

        ui_dist = ui_dir / ".jac" / "client" / "dist";
        if ui_dist.exists() {
            _copy_dir_contents(ui_dist, dist_dir);
        }

        logger.info("Admin client built successfully");
        return True;
    } except subprocess.TimeoutExpired {
        logger.error("Admin client build timed out");
        return False;
    } except Exception as e {
        logger.error(f"Admin client build error: {e}");
        return False;
    }
}


impl JacAPIServerAdmin.serve_admin_page -> Response {
    return RedirectResponse(url="/admin/", status_code=302);
}


impl JacAPIServerAdmin.serve_admin_index -> Response {
    dist_dir = self.get_admin_dist_dir();
    index_file = dist_dir / "index.html";

    if not index_file.exists() {
        if not self.build_admin_client() {
            return HTMLResponse(
                content='''<!DOCTYPE html>
<html>
<head><title>Admin Portal - Build Error</title></head>
<body style="background:#0f172a;color:#e2e8f0;font-family:system-ui;display:flex;justify-content:center;align-items:center;min-height:100vh;margin:0">
<div style="text-align:center">
<h1 style="color:#ef4444">Admin Portal Build Failed</h1>
<p>The admin client could not be built. Check the server logs for details.</p>
</div>
</body>
</html>''',
                status_code=503
            );
        }
    }
    return FileResponse(path=str(index_file), media_type="text/html");
}


impl JacAPIServerAdmin.serve_admin_asset(path: str) -> Response {
    dist_dir = self.get_admin_dist_dir();

    has_extension = '.' in path.split('/')[-1] if path else False;
    if has_extension {
        asset_path = dist_dir / path;

        try {
            asset_path = asset_path.resolve();
            dist_resolved = dist_dir.resolve();
            if not str(asset_path).startswith(str(dist_resolved)) {
                return Response(content="Forbidden", status_code=403);
            }
        } except Exception {
            return Response(content="Invalid path", status_code=400);
        }
        if asset_path.exists() {
            guess_result = mimetypes.guess_type(str(asset_path));
            content_type = guess_result[0]
                if guess_result[0]
                else "application/octet-stream";
            return FileResponse(path=str(asset_path), media_type=content_type);
        }
    }

    index_file = dist_dir / "index.html";
    if not index_file.exists() {
        if not self.build_admin_client() {
            return Response(content="Admin client not available", status_code=503);
        }
    }
    if index_file.exists() {
        return FileResponse(path=str(index_file), media_type="text/html");
    }
    return Response(content="Not found", status_code=404);
}
