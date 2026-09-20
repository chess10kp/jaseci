def validate_against_schema(
    raw: dict[str, any] | None, options: dict[str, any], section: str
) -> list[str];

def report_schema_findings(
    findings: list[str], section: str, strict_env: str = ""
) -> None;

def schema_strict_enabled(strict_env: str) -> bool;

def _walk_schema(
    table: dict[str, any], options: dict[str, any], path: str, findings: list[str]
) -> None;

def _unknown_key_message(path: str, key: str, known: list[str]) -> str;

def opt(type: str, default_value: any, description: str) -> dict[str, any];

def opt_group(description: str, nested: dict[str, any]) -> dict[str, any];
