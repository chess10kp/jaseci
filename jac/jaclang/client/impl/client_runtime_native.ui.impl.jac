impl __jacWirePlatformAdapters -> None {
    globalThis.__jacGetRenderer__ = __jacGetRenderer;
    globalThis.__jacGetApiBaseUrl__ = __getApiBaseUrl;

    globalThis.__jacPlatformReady__ = __ensureNativeTokenPrimed();
    globalThis.__jacGetLocalStorage__ = __getLocalStorage;
    globalThis.__jacSetLocalStorage__ = __setLocalStorage;
    globalThis.__jacRemoveLocalStorage__ = __removeLocalStorage;
    globalThis.__jacSeedEndpointEffects__ = lambda -> dict[str, any] {
        seed = globalThis.__JAC_INIT__;
        effects: any = seed.endpointEffects if seed else None;
        if effects {
            return effects;
        }
        return {};
    };
    globalThis.__jacHandleWalkerUnauthorized__ = lambda {
        console.warn(
            "[jac-native-runtime] Walker returned 401; cleared token. "
            "Redirecting to login."
        );
        navigate("/login");
    };
    globalThis.__jacDefaultErrorReportUrl__ = lambda -> str { return ""; };
}

impl __jacGetRenderer -> any {
    if not globalThis.__jacRenderer__ {
        globalThis.__jacRenderer__ = {"create": __jacNativeCreate};
    }
    return globalThis.__jacRenderer__;
}

impl __jacNativeCreate(
    tag: any, props: dict[str, any] = {}, children: any = []
) -> JsxElement {
    if tag is None {
        tag = React.Fragment;
    }
    flat = [
        c
        for c in _toChildrenArray(children)
        if not _isNil(c)
    ];
    if not isinstance(tag, str) {
        return React.createElement(tag, props, *flat);
    }
    adapted = _adaptProps(tag, props);
    if tag in _VIEW_TAGS {
        return React.createElement(RNView, adapted, *flat);
    }
    if tag in _TEXT_TAGS {
        return React.createElement(RNText, adapted, *flat);
    }
    if tag == "button" {
        textChild = React.createElement(
            RNText, {"style": _textStyleFrom(adapted["style"])}, *flat
        );
        return React.createElement(RNPressable, adapted, textChild);
    }
    if tag == "input" or tag == "textarea" {
        if tag == "textarea" {
            adapted["multiline"] = True;
        }
        return React.createElement(RNTextInput, adapted);
    }
    if tag == "img" {
        return React.createElement(RNImage, _adaptImageProps(adapted));
    }
    if tag == "a" {
        return _makeNativeLink(adapted, flat);
    }
    if tag not in _UNMAPPED_WARNED {
        _UNMAPPED_WARNED[tag] = True;
        console.warn(
            f"[jac-native-runtime] Unmapped HTML tag <{tag}>. Rendering as "
            "<View> with a debug border."
        );
    }
    debug_adapted = adapted;
    if globalThis.__DEV__ {
        existing_style = adapted["style"] if adapted["style"] else None;
        unmapped_style = {
            "borderWidth": 1,
            "borderColor": "red",
            "borderStyle": "dashed"
        };
        debug_adapted = {** adapted};
        debug_adapted["style"] = [unmapped_style, existing_style]
            if existing_style
            else unmapped_style;
    }
    return React.createElement(RNView, debug_adapted, *flat);
}

impl _adaptProps(tag: str, props: dict[str, any]) -> dict[str, any] {
    if not props {
        return {};
    }
    out = {};
    for (key, value) in props.items() {
        if _isNil(value) {
            continue;
        }
        if key == "class" or key == "className" {
            out["accessibilityLabel"] = str(value);
        } elif key == "onClick" {
            out["onPress"] = value;
        } elif key == "onChange" {
            user_on_change = value;
            out["onChangeText"] = lambda (text: any) { user_on_change(
                {"target": {"value": text}}
            ); };
        } elif key.startswith("data-") or key.startswith("aria-") {
            continue;
        } else {
            out[key] = value;
        }
    }
    return out;
}

impl _textStyleFrom(style: any) -> dict[str, any] {
    out = {};
    if _isNil(style) {
        return out;
    }
    text_keys = [
        "color",
        "fontSize",
        "fontWeight",
        "fontFamily",
        "fontStyle",
        "lineHeight",
        "letterSpacing",
        "textAlign",
        "textDecorationLine",
        "textTransform"
    ];
    sources = style if isinstance(style, list) else [style];
    for src in sources {
        if _isNil(src) {
            continue;
        }
        for key in text_keys {
            value = src[key];
            if not _isNil(value) {
                out[key] = value;
            }
        }
    }
    return out;
}

impl _isAbsoluteImageUri(src: str) -> bool {
    lower = src.lower();
    return (
        lower.startswith("http://")
        or lower.startswith("https://")
        or lower.startswith("data:")
        or lower.startswith("file://")
        or lower.startswith("content://")
        or lower.startswith("asset:/")
    );
}

impl _adaptImageProps(props: dict[str, any]) -> dict[str, any] {
    out: dict[str, any] = {** (props or {})};
    src = out["src"] if out["src"] else None;
    if out["alt"] and not out["accessibilityLabel"] {
        out["accessibilityLabel"] = str(out["alt"]);
    }
    cur_source: any = out["source"];
    if src is not None and cur_source is None {
        if typeof(src) == "number" {
            out["source"] = src;
        } else {
            uri = str(src);
            asset_map = globalThis.__JAC_RN_ASSET_MAP__ or {};
            mapped_asset = asset_map[uri] if asset_map else None;
            if mapped_asset is not None {
                out["source"] = mapped_asset;
            } elif uri.startswith("__jac_rn_asset__:") {
                if uri not in _RELATIVE_IMG_SRC_WARNED {
                    _RELATIVE_IMG_SRC_WARNED[uri] = True;
                    console.warn(
                        "[jac-native-runtime] Missing Metro asset mapping for token "
                            + str(uri)
                            + ". Re-run jac build <app>."
                    );
                }
                out["source"] = {"uri": uri};
            } elif uri.startswith("/") and not _isAbsoluteImageUri(uri) {
                base = __getApiBaseUrl();
                if base {
                    uri = str(base).rstrip("/") + uri;
                }
                out["source"] = {"uri": uri};
            } elif not _isAbsoluteImageUri(uri) {
                if uri not in _RELATIVE_IMG_SRC_WARNED {
                    _RELATIVE_IMG_SRC_WARNED[uri] = True;
                    console.warn(
                        "[jac-native-runtime] Relative <img src> path "
                            + str(uri)
                            + " cannot be bundled reliably on React Native. "
                            + "Use imported assets, /static/... URLs, absolute URLs, "
                            + "or pass source={{uri: ...}}."
                    );
                }
                out["source"] = {"uri": uri};
            } else {
                out["source"] = {"uri": uri};
            }
        }
    }
    if out["src"] is not None {
        out.pop("src", None);
    }
    if out["alt"] is not None {
        out.pop("alt", None);
    }
    return out;
}

impl _makeNativeLink(link_props: dict[str, any], children: list[any]) -> JsxElement {
    href = link_props["href"] if link_props["href"] else None;
    rest = {** link_props};
    if rest["href"] {
        rest.pop("href", None);
    }
    if href {
        target_url = str(href);
        rest["onPress"] = lambda { if target_url.startswith("http://")
            or target_url.startswith("https://")
            or target_url.startswith("mailto:")
            or target_url.startswith("tel:") {
            RNLinking.openURL(target_url).catch(
                lambda (e: any) { console.warn("RNLinking.openURL failed", e); }
            );
        } else {
            navigate(target_url);
        } };
    }
    return React.createElement(RNText, rest, *children);
}

impl _toChildrenArray(children: any) -> list[any] {
    if _isNil(children) {
        return [];
    }
    if isinstance(children, list) {
        return children;
    }
    return [children];
}

impl ErrorFallback(error: any, resetErrorBoundary: any) -> JsxElement {
    err_obj = error.error if error and error.error else error;
    msg = err_obj.message if err_obj and err_obj.message else str(err_obj);
    reset_fn = error.resetErrorBoundary
        if error and error.resetErrorBoundary
        else resetErrorBoundary;
    return React.createElement(
        RNView,
        {"style": {"padding": 24, "flex": 1, "justifyContent": "center"}},
        React.createElement(
            RNText,
            {
                "style": {
                    "fontWeight": "bold",
                    "color": "#dc2626",
                    "fontSize": 18,
                    "marginBottom": 12
                }
            },
            "Something went wrong"
        ),
        React.createElement(
            RNText, {"style": {"color": "#374151", "marginBottom": 16}}, msg
        ),
        React.createElement(
            RNPressable,
            {
                "onPress": reset_fn,
                "style": {
                    "backgroundColor": "#2563eb",
                    "padding": 12,
                    "borderRadius": 8,
                    "alignSelf": "flex-start"
                }
            },
            React.createElement(
                RNText, {"style": {"color": "white", "fontWeight": "600"}}, "Try again"
            )
        )
    );
}

impl errorOverlay(filePath: str, errors: str) -> JsxElement {
    return React.createElement(
        RNView,
        {"style": {"padding": 24, "flex": 1, "backgroundColor": "#1e1e1e"}},
        React.createElement(
            RNText,
            {
                "style": {
                    "color": "#ff6b6b",
                    "fontWeight": "bold",
                    "fontSize": 16,
                    "marginBottom": 12
                }
            },
            "Compilation Error"
        ),
        React.createElement(
            RNText, {"style": {"color": "#64b5f6", "marginBottom": 8}}, filePath
        ),
        React.createElement(
            RNText, {"style": {"color": "#ff6b6b", "fontFamily": "monospace"}}, errors
        )
    );
}

def _unwrapZodSchema(schema_obj: any, depth: int = 0) -> any {
    max_depth = 10;
    if not schema_obj or not schema_obj._def or depth >= max_depth {
        return schema_obj;
    }
    type_value = schema_obj._def.type;
    if type_value == "optional" and schema_obj._def.innerType {
        return _unwrapZodSchema(schema_obj._def.innerType, depth + 1);
    }
    if type_value == "default" and schema_obj._def.innerType {
        return _unwrapZodSchema(schema_obj._def.innerType, depth + 1);
    }
    if schema_obj._def.checks and schema_obj._def.schema {
        return _unwrapZodSchema(schema_obj._def.schema, depth + 1);
    }
    return schema_obj;
}

def _getEnumOptions(field_schema: any) -> list[str] {
    unwrapped = _unwrapZodSchema(field_schema);
    if unwrapped and unwrapped._def and unwrapped._def.entries {
        return Object.keys(unwrapped._def.entries);
    }
    if unwrapped and unwrapped.`def and unwrapped.`def.entries {
        return Object.keys(unwrapped.`def.entries);
    }
    return [];
}

def _setFormField(form: any, field_name: str, value: any) {
    form.setValue(
        field_name,
        value,
        {"shouldDirty": True, "shouldTouch": True, "shouldValidate": True}
    );
}

def _fieldErrorMessage(errors: any, field_name: str) -> str {
    err = errors[field_name] if errors and errors[field_name] else None;
    if not err {
        return "";
    }
    if err.message {
        return str(err.message);
    }
    return "Invalid value";
}

def _renderSelectField(
    form: any,
    field_name: str,
    selected_value: str,
    options: list[str],
    placeholder: str
) -> JsxElement {
    option_children = [];
    if placeholder and selected_value == "" {
        option_children.append(
            React.createElement(
                RNText,
                {
                    "key": "__placeholder__",
                    "style": {
                        "marginBottom": 8,
                        "color": "#6b7280",
                        "fontStyle": "italic"
                    }
                },
                placeholder
            )
        );
    }
    for opt in options {
        opt_value = str(opt);
        is_selected = selected_value == opt_value;
        option_children.append(
            React.createElement(
                RNPressable,
                {
                    "key": f"{field_name}:{opt_value}",
                    "onPress": lambda { _setFormField(form, field_name, opt_value); },
                    "style": {
                        "borderWidth": 1,
                        "borderColor": ("#2563eb" if is_selected else "#d1d5db"),
                        "paddingVertical": 10,
                        "paddingHorizontal": 12,
                        "borderRadius": 6,
                        "marginBottom": 6,
                        "backgroundColor": ("#eff6ff" if is_selected else "#ffffff")
                    }
                },
                React.createElement(RNText, {"style": {"color": "#111827"}}, opt_value)
            )
        );
    }
    return React.createElement(RNView, {"style": {"marginTop": 2}}, *option_children);
}

def _renderRadioField(
    form: any, field_name: str, selected_value: str, options: list[str]
) -> JsxElement {
    option_children = [];
    for opt in options {
        opt_value = str(opt);
        is_selected = selected_value == opt_value;
        option_children.append(
            React.createElement(
                RNPressable,
                {
                    "key": f"{field_name}:{opt_value}",
                    "onPress": lambda { _setFormField(form, field_name, opt_value); },
                    "style": {
                        "flexDirection": "row",
                        "alignItems": "center",
                        "paddingVertical": 8
                    }
                },
                React.createElement(
                    RNText,
                    {
                        "style": {
                            "fontSize": 16,
                            "color": "#2563eb" if is_selected else "#9ca3af",
                            "marginRight": 8
                        }
                    },
                    "◉" if is_selected else "○"
                ),
                React.createElement(RNText, {"style": {"color": "#111827"}}, opt_value)
            )
        );
    }
    return React.createElement(RNView, {"style": {"marginTop": 2}}, *option_children);
}

def _renderTextField(
    field: any,
    placeholder: str,
    value: str,
    on_change: any,
    secure: bool,
    has_error: bool
) -> JsxElement {
    return React.createElement(
        RNTextInput,
        {
            "placeholder": placeholder,
            "value": value,
            "onChangeText": on_change,
            "onBlur": field.onBlur,
            "secureTextEntry": secure,
            "style": {
                "borderWidth": 1,
                "borderColor": "#ef4444" if has_error else "#e5e7eb",
                "padding": 10,
                "borderRadius": 6,
                "backgroundColor": "#ffffff",
                "flex": 1
            }
        }
    );
}

def _renderPasswordRow(
    input_row: JsxElement, is_visible: bool, on_toggle: any
) -> JsxElement {
    toggle = React.createElement(
        RNPressable,
        {
            "onPress": on_toggle,
            "style": {"marginLeft": 8, "paddingVertical": 8, "paddingHorizontal": 10}
        },
        React.createElement(
            RNText,
            {"style": {"color": "#2563eb", "fontWeight": "600"}},
            "Hide" if is_visible else "Show"
        )
    );
    return React.createElement(
        RNView,
        {"style": {"flexDirection": "row", "alignItems": "center"}},
        input_row,
        toggle
    );
}

def _renderSubmitButton(
    is_submitting: bool, is_dirty: bool, submit_label: str, on_press: any
) -> JsxElement {
    return React.createElement(
        RNPressable,
        {
            "onPress": on_press,
            "disabled": is_submitting or not is_dirty,
            "style": {
                "backgroundColor": "#2563eb"
                    if (is_dirty and not is_submitting)
                    else "#9ca3af",
                "padding": 12,
                "borderRadius": 6,
                "marginTop": 12
            }
        },
        React.createElement(
            RNText,
            {"style": {"color": "white", "textAlign": "center", "fontWeight": "600"}},
            "Submitting..." if is_submitting else submit_label
        )
    );
}

impl JacForm(props: dict[str, any]) -> JsxElement {
    schema = props["schema"];
    onSubmit = props["onSubmit"];
    validate_mode = props.get("validateMode", None) or "onTouched";
    submitLabel = props.get("submitLabel", None) or "Submit";
    field_config: any = props.get("field_config", None) or {};
    actualSchema = schema;
    try {
        if schema._def and schema._def.schema {
            actualSchema = schema._def.schema;
        }
    } except Exception {}
    schemaShape: dict[str, any] = actualSchema.shape or {};
    fieldNames = Object.keys(schemaShape);
    form = useJacForm(validate_mode, schema);
    errors = form.formState.errors;
    isSubmitting = form.formState.isSubmitting;
    isDirty = form.formState.isDirty;
    [passwordVisible, setPasswordVisible] = useState({});
    fields = [];
    for fieldName in fieldNames {
        config: any = field_config.get(fieldName, None) or {};
        label = config.get("label", None) or fieldName;
        placeholder = str(config.get("placeholder", None) or "");
        field_type = str(config.get("type", None) or config.get("key", None) or "text");
        field_options = _getEnumOptions(schemaShape[fieldName]);
        if field_type == "text"
            and ("password" in fieldName.lower() or "pass" in fieldName.lower()) {
            field_type = "password";
        }
        current_value = form.watch(fieldName);
        selected_value = "" if current_value is None else str(current_value);
        message = _fieldErrorMessage(errors, fieldName);
        is_password = field_type == "password";
        is_visible = passwordVisible[fieldName] == True if passwordVisible else False;
        field = form.register(fieldName, {});
        input_row: JsxElement;
        if field_type == "select" {
            input_row = _renderSelectField(
                form, fieldName, selected_value, field_options, placeholder
            );
        } elif field_type == "radio" {
            input_row = _renderRadioField(
                form, fieldName, selected_value, field_options
            );
        } else {
            input_row = _renderTextField(
                field,
                placeholder,
                selected_value,
                lambda (text: any) { _setFormField(form, fieldName, text); },
                is_password and not is_visible,
                message != ""
            );
        }
        if field_type == "password" {
            input_row = _renderPasswordRow(
                input_row,
                is_visible,
                lambda {
                    next_visible = {** passwordVisible};
                    next_visible[fieldName] = not is_visible;
                    setPasswordVisible(next_visible);
                }
            );
        }
        error_view = None;
        if message != "" {
            error_view = React.createElement(
                RNText,
                {"style": {"marginTop": 4, "color": "#ef4444", "fontSize": 12}},
                message
            );
        }
        fields.append(
            React.createElement(
                RNView,
                {"key": fieldName, "style": {"marginBottom": 12}},
                React.createElement(
                    RNText, {"style": {"marginBottom": 4, "color": "#374151"}}, label
                ),
                input_row,
                error_view
            )
        );
    }
    submit_button = _renderSubmitButton(
        isSubmitting, isDirty, submitLabel, lambda { form.handleSubmit(onSubmit)(); }
    );
    return React.createElement(
        RNView, {"style": {"padding": 12}}, *(fields + [submit_button])
    );
}

impl __jacInstallErrorHandlers -> None {
    __jacWirePlatformAdapters();
    if globalThis.__jacErrorHandlersInstalled {
        return;
    }
    globalThis.__jacErrorHandlersInstalled = True;
    try {
        __ensureNativeTokenPrimed();
    } except Exception {}
    try {
        prev = globalThis.ErrorUtils.getGlobalHandler();
        globalThis.ErrorUtils.setGlobalHandler(
            lambda (error: any, isFatal: any) {
                message = error.message if error else "Unknown error";
                stack = error.stack if error else "";
                __jacReportError(message, stack, "", "ErrorUtils");
                if prev {
                    prev(error, isFatal);
                }
            }
        );
    } except Exception as e {
        console.warn("[jac-native-runtime] Failed to install ErrorUtils handler", e);
    }
}
