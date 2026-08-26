# Product-path facade for the _typing accelerator (Modules/_typingmodule.c).
#
# CPython's _typing module is a tiny exec hook that re-exports interpreter-
# cached type machinery: TypeVar / TypeVarTuple / ParamSpec (+ ParamSpecArgs /
# ParamSpecKwargs / Generic from interp->cached_objects) plus TypeAliasType,
# Union and the NoDefault singleton, with one method (_idfunc, the identity
# accelerator behind typing.NewType.__call__). Lib/typing.py does
# ``from _typing import ...`` at top level, so this surface IS typing's
# type-parameter substrate.
#
# jacpython already builds the same stand-ins natively for PEP 695 source
# parameters (CALL_INTRINSIC_1 TYPEVAR/TYPEALIAS/SUBSCRIPT_GENERIC arms):
# PyTypeVar / PyTypeAlias in objects.jac, Generic and NoDefault in ceval.jac.
# Explicit ``T = TypeVar('T')``-style construction must produce those SAME
# objects so identity and attribute semantics hold across both paths -- this
# facade constructs them directly instead of keeping a second representation.
# Eager bound/constraints/default arguments seed the first-access caches the
# py_attr seam consults, so __bound__/__constraints__/__default__/has_default
# answer through the identical code path as the lazy PEP 695 form.
#
# Gap ledger vs the C module: Union stand-ins carry __args__/nesting but their
# repr does not route through py_repr's native arms yet ('int | str' prints
# via the host fallback); ParamSpec/TypeVarTuple/ParamSpecArgs/ParamSpecKwargs
# are typed here because no intrinsic produces them natively.

import from objects {
    PyObj,
    PyStr,
    PyInt,
    PyBool,
    PyTuple,
    py_none,
    py_error,
    is_error,
    PyTypeVar,
    PyTypeAlias,
}
import from ceval { no_default_sentinel, typing_generic_class }

# ---------------- explicit-construction stand-ins ----------------

# CPython paramspecobject: ParamSpec('P') with its stable .args/.kwargs pair
# (CPython caches both per spec so P.args is P.args holds identity).
obj PyParamSpec(PyObj) {
    has name: str,
        args_inst: PyObj = py_none(),
        kwargs_inst: PyObj = py_none();

    def tp_getattro(name: str) -> PyObj {
        if name == "__name__" {
            return PyStr(t="str", val=self.name);
        }
        if name == "__module__" {
            return PyStr(t="str", val="typing");
        }
        if name == "args" {
            return self.args_inst;
        }
        if name == "kwargs" {
            return self.kwargs_inst;
        }
        return py_error("AttributeError", name);
    }
}

obj PyTypeVarTuple(PyObj) {
    has name: str;

    def tp_getattro(name: str) -> PyObj {
        if name == "__name__" {
            return PyStr(t="str", val=self.name);
        }
        if name == "__module__" {
            return PyStr(t="str", val="typing");
        }
        return py_error("AttributeError", name);
    }
}

# CPython paramspecattr: the object behind P.args / P.kwargs; carries its
# origin spec as __origin__ (typevarobject.c paramspec_attr).
obj PyParamSpecAttr(PyObj) {
    has origin: PyTypeVarTuple | PyParamSpec,
        mode: str;

    def tp_getattro(name: str) -> PyObj {
        if name == "__origin__" {
            return self.origin;
        }
        if name == "__module__" {
            return PyStr(t="str", val="typing");
        }
        return py_error("AttributeError", name);
    }
}

# typing.Union itself: subscripting collapses to the sole argument for one
# entry and otherwise yields the union stand-in below (Lib/typing.py
# _UnionGenericAlias semantics for the direct-subscript path).
obj TypingUnionMark(PyObj) {
    def mp_subscript(index: PyObj) -> PyObj {
        items: list[PyObj] = [];
        if isinstance(index, PyTuple) {
            items = (index as PyTuple).items;
        } else {
            items.append(index);
        }
        if len(items) == 0 {
            return py_error("TypeError", "Cannot take a Union of no types.");
        }
        if len(items) == 1 {
            return items[0];
        }
        return PyTypingUnion(t="typing_union", args=PyTuple(t="tuple", items=items));
    }
}

glob TYPING_UNION: TypingUnionMark = TypingUnionMark(t="typing_union");

obj PyTypingUnion(PyObj) {
    has args: PyObj;

    def mp_subscript(index: PyObj) -> PyObj {
        inner = TYPING_UNION.mp_subscript(index);
        return inner;
    }

    def tp_getattro(name: str) -> PyObj {
        if name == "__args__" {
            return self.args;
        }
        return py_error("AttributeError", name);
    }
}

# ---------------- method surface ----------------

obj TypingFn(PyObj) {
    has name: str;

    def tp_call(args: list[PyObj], kwargs: dict[str, PyObj]) -> PyObj {
        if self.name == "_idfunc" {
            # _typing._idfunc: pure identity (NewType.__call__ accelerator).
            if len(args) != 1 or len(kwargs) > 0 {
                return py_error(
                    "TypeError", "_idfunc() takes exactly one argument (" + str(len(args)) + " given)"
                );
            }
            return args[0];
        }
        if self.name == "TypeVar" {
            return typing_make_typevar(args, kwargs);
        }
        if self.name == "ParamSpec" {
            return typing_make_paramspec(args);
        }
        if self.name == "TypeVarTuple" {
            return typing_make_typevartuple(args);
        }
        if self.name == "ParamSpecArgs" or self.name == "ParamSpecKwargs" {
            if len(args) != 1 or not isinstance(args[0], PyParamSpec) {
                return py_error(
                    "TypeError", self.name + " expected a ParamSpec instance"
                );
            }
            mode = "args";
            if self.name == "ParamSpecKwargs" {
                mode = "kwargs";
            }
            return PyParamSpecAttr(
                t="paramspec_attr", origin=args[0], mode=mode
            ) as PyObj;
        }
        # self.name == "TypeAliasType"
        return typing_make_typealias(args, kwargs);
    }
}

def typing_name_arg(fname: str, args: list[PyObj]) -> PyObj {
    # Shared first-positional-name validation with CPython's clinic messages
    # (typevar()/paramspec()/typevartuple() argument 'name' must be str ...).
    if len(args) == 0 {
        return py_error(
            "TypeError", fname + "() missing required argument 'name' (pos 1)"
        );
    }
    if not isinstance(args[0], PyStr) {
        return py_error(
            "TypeError",
            fname + "() argument 'name' must be str, not " + args[0].tp_type_name(),
        );
    }
    return py_none();
}

def typing_make_typevar(args: list[PyObj], kwargs: dict[str, PyObj]) -> PyObj {
    ok = typing_name_arg("typevar", args);
    if is_error(ok) {
        return ok;
    }
    name = (args[0] as PyStr).val;
    constraints: list[PyObj] = [];
    if len(args) > 1 {
        constraints.extend(args[1:len(args)]);
    }
    bound = py_none();
    if "bound" in kwargs {
        bound = kwargs["bound"];
    }
    if len(constraints) > 0 and not (bound is py_none()) {
        return py_error(
            "TypeError", "Constraints cannot be combined with bound=..."
        );
    }
    tv: PyTypeVar = PyTypeVar(t="TypeVar", name=name);
    tv.infer_variance = False;
    if "infer_variance" in kwargs {
        tv.infer_variance = kwargs["infer_variance"].tp_bool();
    }
    tv.covariant = False;
    if "covariant" in kwargs {
        tv.covariant = kwargs["covariant"].tp_bool();
    }
    tv.contravariant = False;
    if "contravariant" in kwargs {
        tv.contravariant = kwargs["contravariant"].tp_bool();
    }
    # Eager construction seeds the first-access caches directly: the py_attr
    # seam then answers __bound__/__constraints__/__default__ without
    # evaluators, exactly like CPython's eager typevar_alloc fields.
    tv.cached_bound = bound;
    tv.bound_resolved = True;
    tv.cached_constraints = PyTuple(t="tuple", items=constraints);
    tv.constraints_resolved = True;
    dflt = no_default_sentinel();
    if "default" in kwargs {
        dflt = kwargs["default"];
    }
    tv.cached_default = dflt;
    tv.default_resolved = True;
    return tv;
}

def typing_make_paramspec(args: list[PyObj]) -> PyObj {
    ok = typing_name_arg("paramspec", args);
    if is_error(ok) {
        return ok;
    }
    spec: PyParamSpec = PyParamSpec(t="ParamSpec", name=(args[0] as PyStr).val);
    spec.args_inst = PyParamSpecAttr(
        t="paramspec_attr", origin=spec, mode="args"
    ) as PyObj;
    spec.kwargs_inst = PyParamSpecAttr(
        t="paramspec_attr", origin=spec, mode="kwargs"
    ) as PyObj;
    return spec;
}

def typing_make_typevartuple(args: list[PyObj]) -> PyObj {
    ok = typing_name_arg("typevartuple", args);
    if is_error(ok) {
        return ok;
    }
    return PyTypeVarTuple(t="TypeVarTuple", name=(args[0] as PyStr).val);
}

def typing_make_typealias(args: list[PyObj], kwargs: dict[str, PyObj]) -> PyObj {
    # types.TypeAliasType(name, value, *, type_params=()): the eager-value
    # form of CALL_INTRINSIC_1 TYPEALIAS, so the alias is born computed.
    if len(args) < 2 {
        return py_error(
            "TypeError", "typealias() missing required argument 'value' (pos 2)"
        );
    }
    if not isinstance(args[0], PyStr) {
        return py_error(
            "TypeError",
            "typealias() argument 'name' must be str, not " + args[0].tp_type_name(),
        );
    }
    params = py_none();
    if "type_params" in kwargs {
        params = kwargs["type_params"];
    }
    ta: PyTypeAlias = PyTypeAlias(
        t="TypeAliasType",
        name=(args[0] as PyStr).val,
        type_params=params,
        value_fn=py_none(),
    );
    ta.computed = True;
    ta.cached_value = args[1];
    return ta;
}

def typing_module_attrs() -> dict[str, PyObj] {
    # Mirror of _typing_exec + typing_methods: every name Lib/typing.py
    # imports from _typing, served over the shared native stand-ins.
    attrs: dict[str, PyObj] = {};
    for fname in [
        "_idfunc",
        "TypeVar",
        "ParamSpec",
        "TypeVarTuple",
        "ParamSpecArgs",
        "ParamSpecKwargs",
        "TypeAliasType",
    ] {
        attrs[fname] = TypingFn(t="typing_fn", name=fname) as PyObj;
    }
    attrs["Generic"] = typing_generic_class() as PyObj;
    attrs["Union"] = TYPING_UNION as PyObj;
    attrs["NoDefault"] = no_default_sentinel();
    return attrs;
}
