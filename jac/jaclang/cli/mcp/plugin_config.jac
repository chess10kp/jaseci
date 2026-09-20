import from jaclang.project.config_schema { opt, opt_group }


class JacMcpPluginConfig {
    static def get_plugin_metadata -> dict[str, any] {
        return {
            "name": "mcp",
            "version": "0.1.0",
            "description": "MCP server for AI-assisted Jac development"
        };
    }

    static def get_config_schema -> dict[str, any] {
        return {
            "section": "mcp",
            "options": {
                "transport": opt(
                    "string",
                    "stdio",
                    "Transport protocol: stdio, sse, or streamable-http"
                ),
                "port": opt("int", 3001, "Port for SSE/HTTP transports (1-65535)"),
                "host": opt(
                    "string", "127.0.0.1", "Bind address for SSE/HTTP transports"
                ),
                "expose_grammar": opt(
                    "bool", True, "Expose jac.spec language grammar as resource"
                ),
                "expose_guides": opt(
                    "bool",
                    True,
                    "Expose the jac://guide/* reference guides as resources"
                ),
                "expose_examples": opt(
                    "bool", True, "Expose example code from jaclang/examples"
                ),
                "expose_pitfalls": opt(
                    "bool", True, "Expose curated pitfalls/gotchas guide"
                ),
                "enable_validate": opt("bool", True, "Enable parse + type-check tools"),
                "enable_format": opt("bool", True, "Enable Jac code formatting tool"),
                "enable_py2jac": opt(
                    "bool", True, "Enable Python to Jac conversion tool"
                ),
                "enable_ast": opt(
                    "bool", False, "Enable AST introspection tool (verbose)"
                ),
                "project_root": opt(
                    "string", ".", "Root directory for project-aware tools"
                ),
                "mode": opt(
                    "string",
                    "full",
                    "Tool/prompt exposure mode: lite, standard, or full"
                )
            }
        };
    }
}
