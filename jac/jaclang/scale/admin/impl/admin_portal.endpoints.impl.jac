import from jaclang.server.serving.endpoint { ep, path_param, query_param, body_param }
import from jaclang.scale.admin.auth_wrap { authed }


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
