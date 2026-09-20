import from jaclang.server.transport { Meta }


impl JacAPIServerAdmin._require_user_manager -> UserManager {
    manager = self.user_manager;
    if manager is None {
        raise RuntimeError(
            "Admin portal is not attached to a server with a user manager"
        );
    }
    return manager;
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
