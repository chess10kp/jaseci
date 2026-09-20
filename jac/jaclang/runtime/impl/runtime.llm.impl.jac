impl JacLLM.get_mtir(
    caller: Callable,
    args: dict[((int | str), object)],
    call_params: dict[(str, object)]
) -> MTRuntime {
    import from jaclang.runtime.semantic { fetch_mtir }
    import from jaclang.byllm.mtir { MTIR }
    return MTIR(caller, args, call_params, fetch_mtir(caller)).runtime;
}

impl JacLLM.`sem(semstr: str, inner_semstr: dict[(str, str)]) -> Callable {
    def decorator(`obj: object) -> object {
        setattr(`obj, '_jac_semstr', semstr);
        setattr(`obj, '_jac_semstr_inner', inner_semstr);
        return `obj;
    }
    return decorator;
}

impl JacLLM.call_llm(model: LLMModel, mt_run: MTRuntime) -> any {
    return model.invoke(mt_run=mt_run);
}

impl JacLLM.acall_llm(model: LLMModel, mt_run: MTRuntime) -> any {
    return await model.ainvoke(mt_run=mt_run);
}

impl JacLLM.`by(model: LLMModel) -> Callable {
    def _decorator(caller: Callable) -> Callable {
        def _wrapped_caller(*args: object, **kwargs: object) -> object {
            import from jaclang.runtime.semantic { fetch_mtir }
            import from jaclang.byllm.mtir { MTIR }
            invoke_args: dict[((int | str), object)] = {};
            for (i, arg) in enumerate(args) {
                invoke_args[i] = arg;
            }
            for (key, value) in kwargs.items() {
                invoke_args[key] = value;
            }
            mt_run = MTIR(
                caller, invoke_args, model.call_params, fetch_mtir(caller)
            ).runtime;
            return model.invoke(mt_run=mt_run);
        }
        return _wrapped_caller;
    }
    return _decorator;
}

impl JacLLM.by_operator(lhs: any, rhs: any) -> any {
    import from jaclang.byllm.llm { BaseLLM }
    import from jaclang.runtime.archetype { NodeArchetype, EdgeArchetype }

    lhs_list = lhs if isinstance(lhs, list) else [lhs];
    if all(isinstance(element, (NodeArchetype, EdgeArchetype)) for element in lhs_list)
        and isinstance(rhs, BaseLLM) {
        import from jaclang.byllm.visit_routing { route_visit }
        return route_visit(lhs_list, rhs);
    }
    raise NotImplementedError(
        "The 'by' operator requires visitable nodes on the left and an LLM model on the right."
    );
}

impl JacLLM.default_llm -> LLMModel {
    import os;
    _cache = JacLLM._default_llm_instance;
    if (_cache is not None) {
        return _cache;
    }
    import from jaclang.byllm.llm { Model }
    import from jaclang.byllm.config_loader { get_byllm_config }
    import from jaclang.byllm.exceptions { ConfigurationError }
    config = get_byllm_config();
    model_config = config.get_model_config();
    call_params_config = config.get_call_params_config();
    local_config = config.get_local_config();

    configured = model_config.get("default_model", "");
    env_override = os.environ.get("BYLLM_DEFAULT_MODEL", "");
    chosen = env_override or configured;
    if not chosen {
        has_cloud_key = any(
            bool(os.environ.get(k))
            for k in (
                "OPENAI_API_KEY",
                "ANTHROPIC_API_KEY",
                "GEMINI_API_KEY",
                "GOOGLE_API_KEY",
                "MISTRAL_API_KEY",
                "GROQ_API_KEY",
                "TOGETHER_API_KEY",
                "DEEPSEEK_API_KEY"
            )
        );
        if has_cloud_key {
            chosen = "openai/gpt-4o-mini";
        } else {
            try {
                import llama_cpp;
                local_alias = local_config.get("default_alias", "gemma-4-e4b");
                chosen = f"local:{local_alias}";
            } except ImportError {
                raise ConfigurationError(
                    "byLLM has no model configured and no provider API key "
                    "is set. Pick one of:\n"
                    "  - Set OPENAI_API_KEY / ANTHROPIC_API_KEY / GEMINI_API_KEY / etc.\n"
                    "  - Run a local model via Ollama (recommended for "
                    "local-first deployments): install Ollama, then set "
                    "[byllm.model].default_model = \"ollama/<model>\" "
                    "in jac.toml.\n"
                    "  - Use byLLM's bundled in-process runtime: "
                    "pip install 'byllm[local]'  then "
                    "default_model = \"local:gemma-4-e4b\"."
                );
            }
        }
    }

    merged_config: dict[str, any] = dict(model_config);
    if chosen.startswith("local:") {
        for (k, v) in local_config.items() {
            merged_config[k] = v;
        }
    }

    instance = Model(
        model_name=chosen, config=merged_config, call_params=call_params_config
    );
    JacLLM._default_llm_instance = instance;
    return instance;
}

impl JacLLM.add_mtir_to_map(scope: str, mtir: Info) -> None {
    if (JacRuntime.program is None) {
        raise AttributeError('JacRuntime.program is not initialized');
    }
    JacRuntime.program.mtir_map[scope] = mtir;
}

impl JacLLM.get_mtir_from_map(scope: str) -> (Info | None) {
    import from jaclang.runtime.prepared { semantic_for_scope }
    prepared = semantic_for_scope(scope);
    if prepared is not None {
        return prepared;
    }
    if (JacRuntime.program is None) {
        raise AttributeError('JacRuntime.program is not initialized');
    }
    if (scope not in JacRuntime.program.mtir_map) {
        raise KeyError(f"MTIR not found for scope {scope}");
    }
    return JacRuntime.program.mtir_map[scope];
}
