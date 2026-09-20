import from jaclang.project.config_schema { opt, opt_group }


class JacByllmPluginConfig {
    static def get_plugin_metadata -> dict[str, any] {
        return {
            "name": "byllm",
            "version": "0.4.8",
            "description": "byLLM - Easy to use APIs for LLM providers with Jaclang"
        };
    }

    static def get_config_schema -> dict[str, any] {
        return {
            "section": "byllm",
            "options": {
                "model": opt_group(
                    "Default model configuration",
                    {
                        "default_model": opt(
                            "string",
                            "gpt-4o-mini",
                            "Default model name (e.g., 'gpt-4o', 'gpt-4o-mini', 'claude-3-sonnet')"
                        ),
                        "api_key": opt(
                            "string",
                            "",
                            "API key for the LLM provider (can also use OPENAI_API_KEY, ANTHROPIC_API_KEY env vars)"
                        ),
                        "base_url": opt(
                            "string",
                            "",
                            "Custom API endpoint URL (for proxy or self-hosted models)"
                        ),
                        "proxy": opt(
                            "bool",
                            False,
                            "Enable proxy mode (uses OpenAI client instead of LiteLLM)"
                        ),
                        "verbose": opt(
                            "bool", False, "Enable verbose logging of LLM calls"
                        )
                    }
                ),
                "call_params": opt_group(
                    "Default call parameters for LLM invocations",
                    {
                        "temperature": opt(
                            "float",
                            0.7,
                            "Model creativity/randomness (0.0-2.0, lower is more deterministic)"
                        ),
                        "max_tokens": opt(
                            "int",
                            0,
                            "Maximum response tokens (0 means no limit/model default)"
                        )
                    }
                ),
                "litellm": opt_group(
                    "LiteLLM-specific configuration",
                    {
                        "local_cost_map": opt(
                            "bool",
                            True,
                            "Use local cost map instead of fetching from remote"
                        ),
                        "drop_params": opt(
                            "bool",
                            True,
                            "Drop unsupported parameters for different providers"
                        ),
                        "include_cost_in_streaming_usage": opt(
                            "bool",
                            True,
                            "Let litellm compute the cost on streamed usage chunks itself, using its full internal response context, instead of byLLM recomputing it from a synthetic {model, usage} shape"
                        )
                    }
                ),
                "prompt_caching": opt_group(
                    "Anthropic prompt caching configuration — caches static prompt prefix (system prompt, tools) across ReAct iterations for ~90% input token savings",
                    {
                        "enabled": opt(
                            "bool",
                            True,
                            "Enable Anthropic prompt caching (auto-detected for Claude models, no effect on other providers)"
                        )
                    }
                ),
                "system_prompt": opt(
                    "string",
                    "",
                    "Override the default system prompt for LLM interactions. Leave empty to use built-in default."
                ),
                "local": opt_group(
                    "In-process local model runtime (llama.cpp via GGUF). Activated when default_model starts with 'local:' or when no API key is configured.",
                    {
                        "default_alias": opt(
                            "string",
                            "gemma-4-e4b",
                            "Bundled local-model alias to use when default_model is unset and no provider API key is detected"
                        ),
                        "n_ctx": opt(
                            "int",
                            0,
                            "Override context window in tokens (0 = use the alias's bundled default)"
                        ),
                        "n_gpu_layers": opt(
                            "int",
                            0,
                            "Number of transformer layers to offload to GPU (0 = pure CPU; -1 = all layers; requires a CUDA/Metal-enabled llama-cpp-python build)"
                        ),
                        "n_threads": opt(
                            "int",
                            0,
                            "CPU threads for inference (0 = let llama.cpp decide based on cores)"
                        ),
                        "verbose": opt(
                            "bool", False, "Enable llama.cpp verbose logging"
                        ),
                        "auto_download": opt(
                            "bool",
                            False,
                            "Skip the first-run download prompt and pull weights silently. Equivalent to BYLLM_AUTO_DOWNLOAD=1."
                        )
                    }
                ),
                "compaction": opt_group(
                    "Auto-compaction of ReAct loop message history when approaching context window limits",
                    {
                        "enabled": opt(
                            "bool",
                            True,
                            "Enable automatic message compaction when approaching the context window limit"
                        ),
                        "threshold_ratio": opt(
                            "float",
                            0.80,
                            "Fraction of the context window at which compaction triggers (e.g. 0.80 = 80%)"
                        ),
                        "keep_recent_iterations": opt(
                            "int",
                            3,
                            "Number of most-recent tool-call rounds to preserve verbatim; older rounds are summarised"
                        ),
                        "ctx_window": opt(
                            "int",
                            0,
                            "Global context window override in tokens (0 = auto-detect via LiteLLM). Useful for self-hosted or unknown models."
                        ),
                        "compaction_model": opt(
                            "string",
                            "",
                            "Model to use for the summarisation call (empty = use the same model as the active ReAct loop)"
                        )
                    }
                )
            }
        };
    }
}
