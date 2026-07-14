import from typing { Any }

class DatabaseProvider {
    def deploy(self: DatabaseProvider, config: dict[str, any]) -> dict[str, any];
    def get_connection_string(self: DatabaseProvider) -> str;
    def is_available(self: DatabaseProvider) -> bool;
    def cleanup(self: DatabaseProvider) -> None;
    def get_init_container(
        self: DatabaseProvider, app_name: str, wait_image: str
    ) -> (dict[(str, Any)] | None);
}

def build_wait_init_container(
    app_name: str, wait_image: str, kind: str, port: int
) -> (dict[(str, Any)] | None) {
    return {
        'name': f'wait-for-{kind}',
        'image': wait_image,
        'securityContext': {
            'runAsNonRoot': True,
            'runAsUser': 1000,
            'readOnlyRootFilesystem': True,
            'allowPrivilegeEscalation': False,
            'capabilities': {'drop': ['ALL']}
        },
        'command': [
            'sh',
            '-c',
            f"until nc -z {app_name}-{kind}-service {port}; do echo waiting for {kind}; sleep 3; done"
        ]
    };
}
