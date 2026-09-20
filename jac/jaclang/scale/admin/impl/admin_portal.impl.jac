import logging;
import from jaclang.server.serving.datatypes {
    FileResponse,
    HTMLResponse,
    JSONResponse,
    RedirectResponse,
    Response
}
import mimetypes;
import subprocess;
import from pathlib { Path }
import from jaclang.server.transport { TransportResponse, Meta }
import from jaclang.server.serving.endpoint {
    HTTPMethod,
    ep,
    path_param,
    query_param,
    body_param
}
import from jaclang.scale.config.config_loader { get_scale_config }
import from jaclang.scale.admin.auth_wrap { authed }
import from jaclang.server.identity.user_manager { UserManager }
import from jaclang.runtime.runtime { JacRuntime as Jac }
import from jaclang.runtime.constants { Constants as Con }

glob logger = logging.getLogger(__name__);

impl JacAPIServerAdmin._require_user_manager -> UserManager {
    manager = self.user_manager;
    if manager is None {
        raise RuntimeError(
            "Admin portal is not attached to a server with a user manager"
        );
    }
    return manager;
}

impl JacAPIServerAdmin.register_admin_endpoints -> None {
    admin_config = get_scale_config().get_admin_config();
    if not admin_config.get('enabled', True) {
        logger.info("Admin portal is disabled");
        return;
    }

    self.bootstrap_admin();

    server = self.server;
    if server is None {
        return;
    }

    for endpoint in [
        ep(
            HTTPMethod.POST,
            '/admin/login',
            self.admin_login,
            parameters=[
                body_param('username', 'Admin username'),
                body_param('password', 'Admin password')
            ],
            summary='Admin login',
            description='Authenticate as admin user'
        ),
        ep(
            HTTPMethod.POST,
            '/admin/reset-password',
            authed(self.reset_password),
            parameters=[
                body_param('current_password', 'Current password'),
                body_param('new_password', 'New password')
            ],
            summary='Reset password',
            description='Reset password for users requiring password change'
        ),
        ep(
            HTTPMethod.GET,
            '/admin/users',
            authed(self.admin_list_users),
            parameters=[
                query_param('limit', 'Max users to return', 'integer', 100),
                query_param('offset', 'Offset for pagination', 'integer', 0)
            ],
            summary='List users',
            description='List all users (admin only)'
        ),
        ep(
            HTTPMethod.GET,
            '/admin/users/{username}',
            authed(self.admin_get_user),
            parameters=[path_param('username', 'Username to get')],
            summary='Get user',
            description='Get user details (admin only)'
        ),
        ep(
            HTTPMethod.POST,
            '/admin/users',
            authed(self.admin_create_user),
            parameters=[
                body_param('username', 'Username for new user'),
                body_param('password', 'Password for new user'),
                body_param(
                    'role', 'Role for new user (admin, user)', default_value='user'
                )
            ],
            summary='Create user',
            description='Create a new user (admin only). User will be required to reset password on first login.'
        ),
        ep(
            HTTPMethod.PUT,
            '/admin/users/{username}',
            authed(self.admin_update_user),
            parameters=[
                path_param('username', 'Username to update'),
                body_param('role', 'New role (admin, user)', default_value=None),
                body_param(
                    'requires_password_reset',
                    'Force password reset on next login',
                    'boolean',
                    default_value=None
                )
            ],
            summary='Update user',
            description='Update user role or settings (admin only)'
        ),
        ep(
            HTTPMethod.DELETE,
            '/admin/users/{username}',
            authed(self.admin_delete_user),
            parameters=[path_param('username', 'Username to delete')],
            summary='Delete user',
            description='Delete a user (admin only)'
        ),
        ep(
            HTTPMethod.POST,
            '/admin/users/expire-legacy-credentials',
            authed(self.admin_expire_legacy_credentials),
            parameters=[
                body_param(
                    'username',
                    'Limit to one user; omit to sweep every account',
                    default_value=None
                )
            ],
            summary='Expire pre-scrypt credentials',
            description=(
                'Flag accounts whose stored password hash predates the 0.36 '
                'scrypt migration (bcrypt format) as requiring a password '
                'reset, so operators can drive the reset flow instead of '
                'users silently failing to log in. Bulk by default; pass '
                'username to target one account (admin only).'
            )
        ),
        ep(
            HTTPMethod.GET,
            '/admin/sso/providers',
            authed(self.admin_list_sso_providers),
            summary='List SSO providers',
            description='List configured SSO providers (admin only)'
        ),
        ep(
            HTTPMethod.GET,
            '/admin/users/{username}/sso',
            authed(self.admin_get_user_sso_accounts),
            parameters=[path_param('username', 'Username')],
            summary='Get user SSO accounts',
            description='Get SSO accounts linked to a user (admin only)'
        ),
        ep(
            HTTPMethod.GET,
            '/admin/config',
            authed(self.admin_get_config),
            parameters=[
                query_param(
                    'profile',
                    'Config profile (default, development, production)',
                    default_value='default'
                )
            ],
            summary='Get configuration',
            description='Get jac.toml configuration content (admin only)'
        ),
        ep(
            HTTPMethod.POST,
            '/admin/config',
            authed(self.admin_update_config),
            parameters=[
                body_param('content', 'TOML configuration content'),
                query_param(
                    'profile',
                    'Config profile (default, development, production)',
                    default_value='default'
                )
            ],
            summary='Update configuration',
            description='Update jac.toml configuration content (admin only)'
        ),
        ep(
            HTTPMethod.GET,
            '/admin/graph',
            authed(self.admin_graph_data),
            parameters=[
                query_param(
                    'username',
                    'Username to view graph for (defaults to all users)',
                    default_value=None
                )
            ],
            summary='Admin graph data',
            description='Get graph data for any user (admin only)'
        ),
        ep(
            HTTPMethod.GET,
            '/admin/metrics',
            authed(self.admin_get_metrics),
            summary='Get metrics data',
            description='Get parsed Prometheus metrics as JSON (admin only)'
        ),
        ep(
            HTTPMethod.GET,
            '/admin',
            self.serve_admin_page,
            summary='Admin Portal Redirect',
            description='Redirect to /admin/'
        ),
        ep(
            HTTPMethod.GET,
            '/admin/',
            self.serve_admin_index,
            summary='Admin Portal',
            description='Admin portal UI'
        ),
        ep(
            HTTPMethod.GET,
            '/admin/{path:path}',
            self.serve_admin_asset,
            parameters=[path_param('path', 'Asset path')],
            summary='Admin static assets',
            description='Serve admin portal static assets'
        )
    ] {
        endpoint.tags = ['Admin'];
        endpoint.forward_undeclared_query_params = False;
        server.add_endpoint(endpoint);
    }
    logger.info("Admin portal endpoints registered at /admin");
}

impl JacAPIServerAdmin.bootstrap_admin -> None {
    admin_config = get_scale_config().get_admin_config();
    if not admin_config.get('enabled', True) {
        return;
    }
    result = self._require_user_manager().bootstrap_admin_user(
        admin_username=str(admin_config.get('username', 'admin')),
        default_password=str(admin_config.get('default_password', 'changeme'))
    );
    if 'error' not in result {
        if 'created' in result.get('message', '').lower() {
            logger.warning(
                f"Admin user created with default credentials. "
                "Please change the password immediately!"
            );
        }
    }
}

impl JacAPIServerAdmin.validate_admin_token(Authorization: str | None) -> (str | None) {
    if not Authorization or not Authorization.startswith('Bearer ') {
        return None;
    }
    token = Authorization[7:];
    user_id = self._require_user_manager().validate_jwt_token(token);
    if not user_id {
        return None;
    }
    if not self._require_user_manager().is_admin(user_id) {
        return None;
    }
    return user_id;
}

impl JacAPIServerAdmin.require_admin(
    Authorization: str | None
) -> TransportResponse | None {
    admin_user = self.validate_admin_token(Authorization);
    if not admin_user {
        return TransportResponse.fail(
            code='FORBIDDEN',
            message='Admin access required',
            meta=Meta(extra={'http_status': 403})
        );
    }
    return None;
}

impl JacAPIServerAdmin.require_admin_json(
    Authorization: str | None
) -> JSONResponse | None {
    auth_error = self.require_admin(Authorization);
    if auth_error {
        return JSONResponse(
            status_code=auth_error.meta.extra.get("http_status", 403),
            content={"ok": False, "error": {"message": "Unauthorized"}}
        );
    }
    return None;
}

impl JacAPIServerAdmin.admin_login(username: str, password: str) -> TransportResponse {
    if not username or not password {
        return TransportResponse.fail(
            code='VALIDATION_ERROR',
            message='Username and password required',
            meta=Meta(extra={'http_status': 400})
        );
    }
    result = self._require_user_manager().authenticate(username, password);
    if not result {
        return TransportResponse.fail(
            code='UNAUTHORIZED',
            message='Invalid credentials',
            meta=Meta(extra={'http_status': 401})
        );
    }
    user_id = result.get('user_id', '');

    if not self._require_user_manager().is_admin(user_id) {
        return TransportResponse.fail(
            code='FORBIDDEN',
            message='Admin access required',
            meta=Meta(extra={'http_status': 403})
        );
    }
    requires_reset = self._require_user_manager().requires_password_reset(user_id);
    token = self._require_user_manager().create_jwt_token(user_id);
    return TransportResponse.success(
        data={
            'message': 'Login successful',
            'token': token,
            'user_id': user_id,
            'username': username,
            'role': 'admin',
            'requires_password_reset': requires_reset
        },
        meta=Meta(extra={'http_status': 200})
    );
}

impl JacAPIServerAdmin.reset_password(
    current_password: str, new_password: str, Authorization: str | None = None
) -> TransportResponse {
    if not Authorization or not Authorization.startswith('Bearer ') {
        return TransportResponse.fail(
            code='UNAUTHORIZED',
            message='Authentication required',
            meta=Meta(extra={'http_status': 401})
        );
    }
    token = Authorization[7:];
    user_id = self._require_user_manager().validate_jwt_token(token);
    if not user_id {
        return TransportResponse.fail(
            code='UNAUTHORIZED',
            message='Invalid or expired token',
            meta=Meta(extra={'http_status': 401})
        );
    }
    if not current_password or not new_password {
        return TransportResponse.fail(
            code='VALIDATION_ERROR',
            message='Current and new password required',
            meta=Meta(extra={'http_status': 400})
        );
    }
    if len(new_password) < 8 {
        return TransportResponse.fail(
            code='VALIDATION_ERROR',
            message='Password must be at least 8 characters',
            meta=Meta(extra={'http_status': 400})
        );
    }

    result = self._require_user_manager().update_password(
        user_id, current_password, new_password
    );
    if 'error' in result {
        return TransportResponse.fail(
            code='UPDATE_FAILED',
            message=result.get('error', 'Password update failed'),
            meta=Meta(extra={'http_status': 400})
        );
    }

    self._require_user_manager().set_requires_password_reset(user_id, False);

    new_token = self._require_user_manager().create_jwt_token(user_id);
    return TransportResponse.success(
        data={'message': 'Password updated successfully', 'token': new_token},
        meta=Meta(extra={'http_status': 200})
    );
}

impl JacAPIServerAdmin.admin_list_users(
    limit: int = 100, offset: int = 0, Authorization: str | None = None
) -> TransportResponse {
    error = self.require_admin(Authorization);
    if error {
        return error;
    }
    users = self._require_user_manager().list_all_users(limit, offset);

    for user in users {
        identities = user.get('identities', []);
        username = next(
            (
                identity.get('value_raw', '')
                for identity in identities
                if identity.get('type') == 'username'
            ),
            identities[0].get('value_raw', '') if identities else ''
        );
        user['username'] = username;
    }
    return TransportResponse.success(
        data={'users': users, 'count': len(users), 'limit': limit, 'offset': offset},
        meta=Meta(extra={'http_status': 200})
    );
}

impl JacAPIServerAdmin.admin_get_user(
    username: str, Authorization: str | None = None
) -> TransportResponse {
    error = self.require_admin(Authorization);
    if error {
        return error;
    }
    user = self._require_user_manager().get_user(username);
    if not user {
        return TransportResponse.fail(
            code='NOT_FOUND',
            message='User not found',
            meta=Meta(extra={'http_status': 404})
        );
    }
    user_id = user.get('user_id', username);

    role = self._require_user_manager().get_user_role(user_id);
    requires_reset = self._require_user_manager().requires_password_reset(user_id);
    is_pwd_required = self._require_user_manager().is_password_required(user_id);
    sso_accounts = self._require_user_manager().get_sso_accounts(user_id);
    return TransportResponse.success(
        data={
            'username': username,
            'root_id': user.get('root_id'),
            'role': role or 'user',
            'requires_password_reset': requires_reset,
            'is_password_required': is_pwd_required,
            'sso_accounts': sso_accounts
        },
        meta=Meta(extra={'http_status': 200})
    );
}

impl JacAPIServerAdmin.admin_create_user(
    username: str, password: str, role: str = 'user', Authorization: str | None = None
) -> TransportResponse {
    error = self.require_admin(Authorization);
    if error {
        return error;
    }
    if not username or not password {
        return TransportResponse.fail(
            code='VALIDATION_ERROR',
            message='Username and password required',
            meta=Meta(extra={'http_status': 400})
        );
    }
    result = self._require_user_manager().create_user_as_admin(
        username=username, password=password, role=role, requires_password_reset=True
    );
    if 'error' in result {
        return TransportResponse.fail(
            code='CREATE_FAILED',
            message=result.get('error', 'User creation failed'),
            meta=Meta(extra={'http_status': 400})
        );
    }
    return TransportResponse.success(
        data=result, meta=Meta(extra={'http_status': 201})
    );
}

impl JacAPIServerAdmin.admin_update_user(
    username: str,
    role: str | None = None,
    requires_password_reset: bool | None = None,
    Authorization: str | None = None
) -> TransportResponse {
    error = self.require_admin(Authorization);
    if error {
        return error;
    }
    user = self._require_user_manager().get_user(username);
    if not user {
        return TransportResponse.fail(
            code='NOT_FOUND',
            message='User not found',
            meta=Meta(extra={'http_status': 404})
        );
    }
    user_id = user.get('user_id', username);
    updates = [];
    if role is not None {
        result = self._require_user_manager().set_user_role(user_id, role);
        if 'error' in result {
            return TransportResponse.fail(
                code='UPDATE_FAILED',
                message=result.get('error', 'Role update failed'),
                meta=Meta(extra={'http_status': 400})
            );
        }
        updates.append(f"role set to '{role}'");
    }
    if requires_password_reset is not None {
        result = self._require_user_manager().set_requires_password_reset(
            user_id, requires_password_reset
        );
        if 'error' in result {
            return TransportResponse.fail(
                code='UPDATE_FAILED',
                message=result.get('error', 'Password reset flag update failed'),
                meta=Meta(extra={'http_status': 400})
            );
        }
        updates.append(f"requires_password_reset set to {requires_password_reset}");
    }
    if not updates {
        return TransportResponse.fail(
            code='VALIDATION_ERROR',
            message='No updates provided',
            meta=Meta(extra={'http_status': 400})
        );
    }
    return TransportResponse.success(
        data={'message': 'User updated', 'updates': updates, 'username': username},
        meta=Meta(extra={'http_status': 200})
    );
}

impl JacAPIServerAdmin.admin_expire_legacy_credentials(
    username: str | None = None, Authorization: str | None = None
) -> TransportResponse {
    error = self.require_admin(Authorization);
    if error {
        return error;
    }
    result = self._require_user_manager().expire_legacy_credentials(username);
    if 'error' in result {
        return TransportResponse.fail(
            code='NOT_FOUND',
            message=str(result.get('error', 'User not found')),
            meta=Meta(extra={'http_status': 404})
        );
    }
    return TransportResponse.success(
        data=result, meta=Meta(extra={'http_status': 200})
    );
}

impl JacAPIServerAdmin.admin_delete_user(
    username: str, Authorization: str | None = None
) -> TransportResponse {
    error = self.require_admin(Authorization);
    if error {
        return error;
    }
    user = self._require_user_manager().get_user(username);
    user_id = user.get('user_id', username) if user else username;
    result = self._require_user_manager().delete_user(user_id);
    if 'error' in result {
        return TransportResponse.fail(
            code='DELETE_FAILED',
            message=result.get('error', 'User deletion failed'),
            meta=Meta(extra={'http_status': 400})
        );
    }
    return TransportResponse.success(
        data=result, meta=Meta(extra={'http_status': 200})
    );
}

impl JacAPIServerAdmin.admin_list_sso_providers(
    Authorization: str | None = None
) -> TransportResponse {
    error = self.require_admin(Authorization);
    if error {
        return error;
    }
    sso_config = get_scale_config().get_sso_config();
    providers = [];

    for platform in ['google', 'apple', 'github', 'firebase'] {
        platform_config = sso_config.get(platform, {});
        if platform == 'firebase' {
            project_id = platform_config.get('project_id', '');
            is_configured = bool(project_id);
            project_id_set = is_configured;
            client_id_set = False;
            client_secret_set = False;
        } else {
            client_id = platform_config.get('client_id', '');
            client_secret = platform_config.get('client_secret', '');
            is_configured = bool(client_id and client_secret);
            client_id_set = bool(client_id);
            client_secret_set = bool(client_secret);
            project_id_set = False;
        }
        providers.append(
            {
                'platform': platform,
                'configured': is_configured,
                'client_id_set': client_id_set,
                'client_secret_set': client_secret_set,
                'project_id_set': project_id_set
            }
        );
    }
    return TransportResponse.success(
        data={
            'providers': providers,
            'sso_host': sso_config.get('host', ''),
            'client_auth_callback_url': sso_config.get('client_auth_callback_url', '')
        },
        meta=Meta(extra={'http_status': 200})
    );
}

impl JacAPIServerAdmin.admin_get_user_sso_accounts(
    username: str, Authorization: str | None = None
) -> TransportResponse {
    error = self.require_admin(Authorization);
    if error {
        return error;
    }
    user = self._require_user_manager().get_user(username);
    if not user {
        return TransportResponse.fail(
            code='NOT_FOUND',
            message='User not found',
            meta=Meta(extra={'http_status': 404})
        );
    }
    user_id = user.get('user_id', username);
    accounts = self._require_user_manager().get_sso_accounts(user_id);
    return TransportResponse.success(
        data={'username': username, 'sso_accounts': accounts},
        meta=Meta(extra={'http_status': 200})
    );
}

impl JacAPIServerAdmin.admin_get_config(
    profile: str = "default", Authorization: str | None = None
) -> TransportResponse {
    error = self.require_admin(Authorization);
    if error {
        return error;
    }
    import os;
    cwd = Path(os.getcwd());

    if profile == "default" {
        config_path = cwd / "jac.toml";
    } else {
        config_path = cwd / f"jac.{profile}.toml";
    }
    if not config_path.exists() {
        return TransportResponse.success(
            data={
                'profile': profile,
                'content': f"# Configuration file not found: {config_path.name}\n# Create this file to configure {profile} profile.",
                'exists': False
            },
            meta=Meta(extra={'http_status': 200})
        );
    }
    try {
        content = config_path.read_text(encoding='utf-8');
        return TransportResponse.success(
            data={'profile': profile, 'content': content, 'exists': True},
            meta=Meta(extra={'http_status': 200})
        );
    } except Exception as e {
        return TransportResponse.fail(
            code='READ_ERROR',
            message=f'Failed to read config: {str(e)}',
            meta=Meta(extra={'http_status': 500})
        );
    }
}

impl JacAPIServerAdmin.admin_update_config(
    content: str, profile: str = "default", Authorization: str | None = None
) -> TransportResponse {
    error = self.require_admin(Authorization);
    if error {
        return error;
    }
    import os;
    import toml;
    cwd = Path(os.getcwd());

    if profile == "default" {
        config_path = cwd / "jac.toml";
    } else {
        config_path = cwd / f"jac.{profile}.toml";
    }

    try {
        toml.loads(content);
    } except Exception as e {
        return TransportResponse.fail(
            code='VALIDATION_ERROR',
            message=f'Invalid TOML syntax: {str(e)}',
            meta=Meta(extra={'http_status': 400})
        );
    }
    try {
        config_path.write_text(content, encoding='utf-8');
        return TransportResponse.success(
            data={'profile': profile, 'message': 'Configuration saved successfully'},
            meta=Meta(extra={'http_status': 200})
        );
    } except Exception as e {
        return TransportResponse.fail(
            code='WRITE_ERROR',
            message=f'Failed to save config: {str(e)}',
            meta=Meta(extra={'http_status': 500})
        );
    }
}

impl JacAPIServerAdmin.admin_graph_data(
    username: str | None = None, Authorization: str | None = None
) -> JSONResponse {
    error = self.require_admin(Authorization);
    if error {
        return JSONResponse(
            status_code=403,
            content={'error': 'Forbidden', 'message': 'Admin access required'}
        );
    }
    import from jaclang.runtime.graph_utils { collect_node_connections }
    target_username = username or Con.GUEST.value;
    root_id = self._require_user_manager().get_root_id(target_username);
    if not root_id {
        return JSONResponse(
            status_code=404,
            content={
                'error': 'Not found',
                'message': f"User '{target_username}' not found or has no graph"
            }
        );
    }
    ctx = Jac.get_context();
    ctx.set_user_root(root_id);
    try {
        user_root = ctx.get_root();
        visited_nodes: set = set();
        connections: set = set();
        edge_ids: set = set();
        nodes: list[dict[str, str]] = [];
        edges: list[dict[str, str]] = [];

        collect_node_connections(user_root, visited_nodes, connections, edge_ids);

        nodes.append({'id': Jac.object_ref(user_root), 'label': 'root'});
        for node_arch in visited_nodes {
            if node_arch != user_root {
                nodes.append(
                    {'id': Jac.object_ref(node_arch), 'label': repr(node_arch)}
                );
            }
        }
        for (_, source_node, target_node, edge_arch) in connections {
            edge_data: dict[str, str] = {
                'from': Jac.object_ref(source_node),
                'to': Jac.object_ref(target_node)
            };
            if repr(edge_arch) != 'GenericEdge()' {
                edge_data['label'] = repr(edge_arch);
            }
            edges.append(edge_data);
        }

        return JSONResponse(
            status_code=200,
            content={
                'version': '1.0',
                'username': target_username,
                'nodes': nodes,
                'edges': edges
            }
        );
    } except Exception as e {
        return JSONResponse(
            status_code=500, content={'error': 'Internal error', 'message': str(e)}
        );
    }
}

impl JacAPIServerAdmin.admin_get_metrics(
    Authorization: str | None = None
) -> TransportResponse {
    error = self.require_admin(Authorization);
    if error {
        return error;
    }
    if not self._metrics or not self._metrics.is_enabled() {
        return TransportResponse.success(
            data={
                'enabled': False,
                'message': 'Prometheus metrics are not enabled',
                'metrics': []
            },
            meta=Meta(extra={'http_status': 200})
        );
    }
    try {
        raw_metrics = self._metrics.expose().decode('utf-8');
        metrics_data = _parse_prometheus_text(raw_metrics);
        summary = _calculate_metrics_summary(metrics_data);

        return TransportResponse.success(
            data={
                'enabled': True,
                'summary': summary,
                'metrics': metrics_data,
                'raw_available': True
            },
            meta=Meta(extra={'http_status': 200})
        );
    } except Exception as e {
        return TransportResponse.fail(
            code='METRICS_ERROR',
            message=f'Failed to retrieve metrics: {str(e)}',
            meta=Meta(extra={'http_status': 500})
        );
    }
}

def _parse_prometheus_text(raw_metrics: str) -> list[dict[str, any]] {
    import re;

    metrics_data: list[dict[str, any]] = [];
    current_metric: (dict[str, any] | None) = None;
    metric_line_re = re.compile(
        r'^([a-zA-Z_:][a-zA-Z0-9_:]*)((?:\{[^}]*\})?)[ \t]+(.+)$'
    );
    label_re = re.compile(r'([a-zA-Z_][a-zA-Z0-9_]*)="([^"]*)"');

    for line in raw_metrics.split('\n') {
        line = line.strip();
        if not line {
            continue;
        }

        if line.startswith('# HELP ') {
            parts = line[7:].split(' ', 1);
            current_metric = {
                'name': parts[0],
                'description': parts[1] if len(parts) > 1 else '',
                'type': 'unknown',
                'values': []
            };
            metrics_data.append(current_metric);
        } elif line.startswith('# TYPE ') {
            parts = line[7:].split(' ', 1);
            if current_metric and parts[0] == current_metric['name'] {
                current_metric['type'] = parts[1] if len(parts) > 1 else 'unknown';
            }
        } elif line.startswith('#') {
            continue;
        } else {
            regex_match = metric_line_re.`match(line);
            if regex_match {
                metric_name = regex_match.group(1);
                labels_str = regex_match.group(2);
                value_str = regex_match.group(3);
                labels: dict[str, str] = {};
                if labels_str
                    and labels_str.startswith('{')
                    and labels_str.endswith('}') {
                    for lm in label_re.finditer(labels_str[1:-1]) {
                        labels[lm.group(1)] = lm.group(2);
                    }
                }
                value: (float | str) = value_str;
                try {
                    value = float(value_str);
                } except ValueError {
                    value = value_str;
                }
                found_metric: (dict[str, any] | None) = None;
                for m in metrics_data {
                    m_name: str = m['name'];
                    if m_name == metric_name or metric_name.startswith(m_name + '_') {
                        found_metric = m;
                        break;
                    }
                }
                suffix = '';
                if found_metric {
                    found_name: str = found_metric['name'];
                    if metric_name.startswith(found_name) {
                        suffix = metric_name[len(found_name):];
                    }
                    found_metric['values'].append(
                        {'labels': labels, 'value': value, 'suffix': suffix}
                    );
                } else {
                    metrics_data.append(
                        {
                            'name': metric_name,
                            'description': '',
                            'type': 'unknown',
                            'values': [{'labels': labels, 'value': value, 'suffix': ''}]
                        }
                    );
                }
            }
        }
    }
    return metrics_data;
}

glob _LATENCY_CUTS: list[float] = [0.025, 0.1, 0.5, 2.5];


def _classify_path(path: str) -> str {
    import from jaclang.scale.runtime.routing { GATEWAY_WELLKNOWN_SEGMENTS }
    head: str = path.strip('/').split('/')[0];
    if head == 'health' or head == 'healthz' {
        return 'health';
    }
    if head == 'admin' {
        return 'admin';
    }
    if head in GATEWAY_WELLKNOWN_SEGMENTS {
        return 'system';
    }
    return 'app';
}


def _sorted_buckets(acc: dict[float, float]) -> list[dict[str, float]] {
    return [{'le': le, 'count': acc[le]} for le in sorted(acc.keys())];
}


def _percentile_from_buckets(
    buckets: list[dict[str, float]], q: float
) -> dict[str, float | bool] {
    total: float = buckets[-1]['count'] if buckets else 0.0;
    if total <= 0 {
        return {'value': 0.0, 'over': False, 'known': False};
    }
    rank: float = q * total;
    lo: float = 0.0;
    lo_edge: float = 0.0;
    for b in buckets {
        upper: float = b['le'];
        count: float = b['count'];
        if count >= rank {
            if upper == float('inf') {
                return {'value': lo_edge, 'over': True, 'known': True};
            }
            span: float = count - lo;
            frac: float = (rank - lo) / span if span > 0 else 0.0;
            return {
                'value': round(lo_edge + frac * (upper - lo_edge), 6),
                'over': False,
                'known': True
            };
        }
        lo = count;
        lo_edge = upper;
    }
    return {'value': lo_edge, 'over': True, 'known': True};
}


def _format_seconds(secs: float) -> str {
    unit: str = 'ms' if secs < 1.0 else 's';
    value: float = round(secs * 1000.0, 6) if unit == 'ms' else round(secs, 6);
    text: str = str(int(value)) if value == int(value) else str(value);
    return text + unit;
}


def _range_label(lo: float, hi: float) -> str {
    lo_text: str = _format_seconds(lo);
    hi_text: str = _format_seconds(hi);
    lo_unit: str = 'ms' if lo_text.endswith('ms') else 's';
    hi_unit: str = 'ms' if hi_text.endswith('ms') else 's';
    if lo_unit == hi_unit {
        return lo_text[:-len(lo_unit)] + ' - ' + hi_text;
    }
    return lo_text + ' - ' + hi_text;
}


def _band_edges(edges: list[float]) -> list[float] {
    chosen: list[float] = [];
    for cut in _LATENCY_CUTS {
        nearest: float = edges[0];
        for le in edges {
            if abs(le - cut) < abs(nearest - cut) {
                nearest = le;
            }
        }
        if nearest not in chosen {
            chosen.append(nearest);
        }
    }
    return chosen;
}


def _latency_groups(buckets: list[dict[str, float]]) -> list[dict[str, str | int]] {
    edges: list[float] = [
        b['le']
        for b in buckets
        if b['le'] != float('inf')
    ];
    if not edges {
        return [];
    }
    counts: dict[float, float] = {b['le']: b['count'] for b in buckets};
    total: float = buckets[-1]['count'];
    out: list[dict[str, str | int]] = [];
    prev: float = 0.0;
    lo: float = 0.0;
    for (i, hi) in enumerate(_band_edges(edges)) {
        seen: float = counts[hi];
        label: str = ('under ' + _format_seconds(hi))
            if i == 0
            else _range_label(lo, hi);
        out.append({'label': label, 'count': int(seen - prev)});
        prev = seen;
        lo = hi;
    }
    out.append({'label': 'over ' + _format_seconds(lo), 'count': int(total - prev)});
    return out;
}


def _endpoint_sort_key(row: dict[str, any]) -> tuple[float, int] {
    return (-row['p95']['value'], -row['count']);
}


def _calculate_metrics_summary(metrics_data: list[dict[str, any]]) -> dict[str, any] {
    active: int = 0;
    rows: dict[str, dict[str, any]] = {};
    hist: dict[str, dict[float, float]] = {};

    for metric in metrics_data {
        name: str = metric['name'];
        if 'http_requests_total' in name {
            for v in metric['values'] {
                if not isinstance(v['value'], (int, float)) {
                    continue;
                }
                labels: dict[str, str] = v['labels'];
                method: str = labels.get('method', '?');
                path: str = labels.get('path', '?');
                key: str = method + ' ' + path;
                if key not in rows {
                    rows[key] = {
                        'method': method,
                        'path': path,
                        'kind': _classify_path(path),
                        'count': 0,
                        'server_errors': 0,
                        'client_errors': 0
                    };
                }
                row: dict[str, any] = rows[key];
                n: int = int(v['value']);
                row['count'] += n;
                status: str = labels.get('status_code', '');
                if status.startswith('5') {
                    row['server_errors'] += n;
                } elif status.startswith('4') {
                    row['client_errors'] += n;
                }
            }
        } elif 'requests_in_progress' in name {
            for v in metric['values'] {
                if isinstance(v['value'], (int, float)) {
                    active = int(v['value']);
                }
            }
        } elif 'request_duration_seconds' in name {
            for v in metric['values'] {
                if v['suffix'] != '_bucket'
                    or not isinstance(v['value'], (int, float)) {
                    continue;
                }
                labels: dict[str, str] = v['labels'];
                le_raw: str = labels.get('le', '');
                if not le_raw {
                    continue;
                }
                le: float = float('inf') if le_raw == '+Inf' else float(le_raw);
                key: str = labels.get('method', '?') + ' ' + labels.get('path', '?');
                acc: dict[float, float] = hist.setdefault(key, {});
                acc[le] = acc.get(le, 0.0) + float(v['value']);
            }
        }
    }

    endpoints: list[dict[str, any]] = [];
    for (key, row) in rows.items() {
        buckets = _sorted_buckets(hist.get(key, {}));
        endpoints.append(
            {
                'method': row['method'],
                'path': row['path'],
                'kind': row['kind'],
                'count': row['count'],
                'failed': row['server_errors'] + row['client_errors'],
                'p50': _percentile_from_buckets(buckets, 0.5),
                'p95': _percentile_from_buckets(buckets, 0.95)
            }
        );
    }
    endpoints.sort(key=_endpoint_sort_key);

    scopes: dict[str, dict[str, any]] = {};
    for scope_name in ('app', 'other', 'all') {
        requests: int = 0;
        server_errors: int = 0;
        client_errors: int = 0;
        merged: dict[float, float] = {};
        for (key, row) in rows.items() {
            is_app: bool = row['kind'] == 'app';
            if scope_name == 'app' and not is_app {
                continue;
            }
            if scope_name == 'other' and is_app {
                continue;
            }
            requests += row['count'];
            server_errors += row['server_errors'];
            client_errors += row['client_errors'];
            for (le, count) in hist.get(key, {}).items() {
                merged[le] = merged.get(le, 0.0) + count;
            }
        }
        buckets = _sorted_buckets(merged);
        scopes[scope_name] = {
            'requests': requests,
            'server_errors': server_errors,
            'client_errors': client_errors,
            'p50': _percentile_from_buckets(buckets, 0.5),
            'p95': _percentile_from_buckets(buckets, 0.95),
            'p99': _percentile_from_buckets(buckets, 0.99),
            'distribution': _latency_groups(buckets)
        };
    }

    return {'active_requests': active, 'scopes': scopes, 'endpoints': endpoints};
}

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
