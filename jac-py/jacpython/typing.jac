# Product-path facade for the _typing accelerator (native Jac).
# Lift of reference/cpython ``Modules/_typingmodule.c``: the C module's
# multi-phase exec (_typing_exec) exports the interpreter's cached type-object
# singletons (typevarobject.c / unionobject.c / TypeAliasType / NoDefaultStruct)
# plus the ``_idfunc`` helper that Lib/typing.py binds as NewType.__call__.
#
# This facade mirrors that exact export surface over jacpython's existing
# runtime stand-ins:
#
# - TypeVar builds the na-clean ``PyTypeVar`` (objects.jac) that the PEP 695
#   CALL_INTRINSIC arms mint. Explicitly-constructed bounds/constraints/
#   defaults are wrapped as zero-arg const evaluators so they reuse ceval's
#   lazy resolution seam (typevar_bound_value and siblings) unchanged.
# - Generic and NoDefault are NOT built here: they must be the single objects
#   the intrinsic arms answer with (identity across __mro_entries__ class-base
#   resolution and __default__), and those builders live in ceval -- importing
#   them here would create an import cycle. The registration arm in ceval.jac
#   installs them after building this module.
# - Union stands in for _PyUnion_Type: subscripting mints a data alias with
#   CPython's __origin__/__args__ surface and bit-or merges aliases.
# - TypeAliasType wraps the VM's ``PyTypeAlias`` (the INTRINSIC_TYPEALIAS
#   product). Known divergence (runtime unverified locally -- CI gates it):
#   ceval's typealias_value invokes the stored value callable with one
#   format argument (the PEP 749 hidden-function shape), while the public
#   typing.TypeAliasType contract calls a user value function with none.
#
# Error strings mirror typevarobject.c verbatim where the constructor
# validates ("Bivariant types are not supported.", et al).

import from objects {
    PyObj,
    PyStr,
    PyBool,
    PyNoneType,
    PyTuple,
    PyTypeVar,
    PyTypeAlias,
    PY_NOT_IMPLEMENTED,
    py_none,
    py_error,
    is_error,
}
import from opcode_meta { NB_OR, NB_INPLACE_OR }

# ---------------- _idfunc ----------------------------------------------------
# _typing._idfunc(x) -> x: the whole body of typing.NewType.__call__.

obj PyTypingIdFunc(PyObj) {
    def tp_call(args: list[PyObj], kwargs: dict[str, PyObj]) -> PyObj {
        if len(args) == 1 and len(kwargs) == 0 {
            return args[0];
        }
        # Positional-only per the clinic signature.
        return py_error(
            "TypeError",
            "_idfunc() takes exactly one argument (" + str(len(args)) + " given)"
        );
    }
}

# ---------------- TypeVar ----------------------------------------------------

# Zero-arg evaluator wrapper shaped like a PEP 749 const-evaluator: lets an
# explicitly-constructed TypeVar carry a plain bound/constraints/default while
# reusing ceval's lazy __bound__/__constraints__/__default__ seam unchanged.
obj PyTypingConstEvaluator(PyObj) {
    has val: PyObj;

    def tp_call(args: list[PyObj], kwargs: dict[str, PyObj]) -> PyObj {
        return self.val;
    }
}

def _typing_const_evaluator(val: PyObj) -> PyObj {
    return PyTypingConstEvaluator(t="const_evaluator", val=val);
}

obj PyTypeVarCtor(PyObj) {
    # Mirrors typevar_new_impl: name, *constraints, bound=None,
    # default=<NoDefault>, covariant/contravariant/infer_variance flags.
    def tp_call(args: list[PyObj], kwargs: dict[str, PyObj]) -> PyObj {
        if len(args) < 1 {
            return py_error(
                "TypeError", "TypeVar() missing required argument 'name' (pos 1)"
            );
        }
        if not isinstance(args[0], PyStr) {
            return py_error("TypeError", "TypeVar() argument 'name' must be str");
        }
        constraints: list[PyObj] = args[1:];

        covariant = self._flag(kwargs, "covariant");
        if is_error(covariant) {
            return covariant;
        }
        contravariant = self._flag(kwargs, "contravariant");
        if is_error(contravariant) {
            return contravariant;
        }
        infer_variance = self._flag(kwargs, "infer_variance");
        if is_error(infer_variance) {
            return infer_variance;
        }
        if (covariant as PyBool).val and (contravariant as PyBool).val {
            return py_error("ValueError", "Bivariant types are not supported.");
        }
        if (infer_variance as PyBool).val
            and ((covariant as PyBool).val or (contravariant as PyBool).val) {
            return py_error(
                "ValueError", "Variance cannot be specified with infer_variance."
            );
        }

        bound: PyObj = py_none();
        if "bound" in kwargs {
            bound = kwargs["bound"];
        }
        if not isinstance(bound, PyNoneType) and len(constraints) > 0 {
            return py_error(
                "TypeError", "Constraints cannot be combined with bound=..."
            );
        }
        if len(constraints) == 1 {
            return py_error("TypeError", "A single constraint is not allowed");
        }

        tv = PyTypeVar(t="TypeVar", name=(args[0] as PyStr).val);
        if not isinstance(bound, PyNoneType) {
            tv.evaluate_bound = _typing_const_evaluator(bound);
        }
        if len(constraints) > 0 {
            tv.evaluate_constraints = _typing_const_evaluator(
                PyTuple(t="tuple", items=constraints)
            );
        }
        if "default" in kwargs and not isinstance(kwargs["default"], PyNoneType)
            and kwargs["default"].t != "nodefault" {
            # A default equal to the NoDefault sentinel means "absent"
            # (typevarobject stores &_Py_NoDefaultStruct); anything else --
            # including None -- is a real default.
            tv.evaluate_default = _typing_const_evaluator(kwargs["default"]);
        }
        return tv;
    }

    # Keyword flag probe defaulting to False; non-bool values are accepted
    # truthiness-style like CPython's bool converter.
    def _flag(kwargs: dict[str, PyObj], key: str) -> PyObj {
        if key not in kwargs or isinstance(kwargs[key], PyNoneType) {
            return PyBool(t="bool", val=False);
        }
        return PyBool(t="bool", val=kwargs[key].tp_bool());
    }
}

# ---------------- ParamSpec family -------------------------------------------

obj PyParamSpecArgs(PyObj) {
    has origin: PyObj;

    def tp_getattro(name: str) -> PyObj {
        if name == "__origin__" {
            return self.origin;
        }
        if name == "__module__" {
            return PyStr(t="str", val="typing");
        }
        if name == "__mro_entries__" {
            return py_error("AttributeError", name);
        }
        return py_error(
            "AttributeError",
            "'typing.ParamSpecArgs' object has no attribute '" + name + "'"
        );
    }
}

obj PyParamSpecKwargs(PyObj) {
    has origin: PyObj;

    def tp_getattro(name: str) -> PyObj {
        if name == "__origin__" {
            return self.origin;
        }
        if name == "__module__" {
            return PyStr(t="str", val="typing");
        }
        return py_error(
            "AttributeError",
            "'typing.ParamSpecKwargs' object has no attribute '" + name + "'"
        );
    }
}

obj PyParamSpec(PyObj) {
    has name: str,
        # Cached .args/.kwargs so repeated access keeps object identity
        # (paramspecobject.c caches them on the instance).
        args_inst: PyObj = py_none(),
        kwargs_inst: PyObj = py_none();

    def tp_getattro(name2: str) -> PyObj {
        if name2 == "__name__" {
            return PyStr(t="str", val=self.name);
        }
        if name2 == "__module__" {
            return PyStr(t="str", val="typing");
        }
        if name2 == "__bound__" {
            return py_none();
        }
        if name2 == "args" {
            if isinstance(self.args_inst, PyNoneType) {
                self.args_inst = PyParamSpecArgs(
                    t="ParamSpecArgs", origin=self as PyObj
                );
            }
            return self.args_inst;
        }
        if name2 == "kwargs" {
            if isinstance(self.kwargs_inst, PyNoneType) {
                self.kwargs_inst = PyParamSpecKwargs(
                    t="ParamSpecKwargs", origin=self as PyObj
                );
            }
            return self.kwargs_inst;
        }
        return py_error(
            "AttributeError",
            "'typing.ParamSpec' object has no attribute '" + name2 + "'"
        );
    }
}

obj PyParamSpecCtor(PyObj) {
    def tp_call(args: list[PyObj], kwargs: dict[str, PyObj]) -> PyObj {
        if len(args) < 1 {
            return py_error(
                "TypeError", "ParamSpec() missing required argument 'name' (pos 1)"
            );
        }
        if not isinstance(args[0], PyStr) {
            return py_error("TypeError", "ParamSpec() argument 'name' must be str");
        }
        return PyParamSpec(t="ParamSpec", name=(args[0] as PyStr).val);
    }
}

obj PyParamSpecArgsCtor(PyObj) {
    # Exposed as a type per CPython's surface; instances normally come from
    # ParamSpec.args, so construction without an origin stays legal-but-inert.
    def tp_call(args: list[PyObj], kwargs: dict[str, PyObj]) -> PyObj {
        origin: PyObj = py_none();
        if len(args) > 0 {
            origin = args[0];
        }
        return PyParamSpecArgs(t="ParamSpecArgs", origin=origin);
    }
}

obj PyParamSpecKwargsCtor(PyObj) {
    def tp_call(args: list[PyObj], kwargs: dict[str, PyObj]) -> PyObj {
        origin: PyObj = py_none();
        if len(args) > 0 {
            origin = args[0];
        }
        return PyParamSpecKwargs(t="ParamSpecKwargs", origin=origin);
    }
}

# ---------------- TypeVarTuple ------------------------------------------------

obj PyTypeVarTuple(PyObj) {
    has name: str;

    def tp_getattro(name2: str) -> PyObj {
        if name2 == "__name__" {
            return PyStr(t="str", val=self.name);
        }
        if name2 == "__module__" {
            return PyStr(t="str", val="typing");
        }
        return py_error(
            "AttributeError",
            "'typing.TypeVarTuple' object has no attribute '" + name2 + "'"
        );
    }

    # Bare TypeVarTuple substitution is rejected exactly like the C original
    # (typevarobject.c typevartuple_subscript).
    def mp_subscript(index: PyObj) -> PyObj {
        return py_error(
            "TypeError", "Substitution of bare TypeVarTuple is not supported"
        );
    }
}

obj PyTypeVarTupleCtor(PyObj) {
    def tp_call(args: list[PyObj], kwargs: dict[str, PyObj]) -> PyObj {
        if len(args) < 1 {
            return py_error(
                "TypeError",
                "TypeVarTuple() missing required argument 'name' (pos 1)"
            );
        }
        if not isinstance(args[0], PyStr) {
            return py_error(
                "TypeError", "TypeVarTuple() argument 'name' must be str"
            );
        }
        return PyTypeVarTuple(t="TypeVarTuple", name=(args[0] as PyStr).val);
    }
}

# ---------------- TypeAliasType -----------------------------------------------

obj PyTypeAliasTypeCtor(PyObj) {
    # typing.TypeAliasType(name, value, /, *, type_params=()): wraps the same
    # PyTypeAlias stand-in INTRINSIC_TYPEALIAS produces, so `type X = ...`
    # aliases and explicitly-constructed ones share one runtime shape.
    def tp_call(args: list[PyObj], kwargs: dict[str, PyObj]) -> PyObj {
        if len(args) < 2 {
            return py_error(
                "TypeError",
                "TypeAliasType() missing required argument 'value' (pos 2)"
            );
        }
        if not isinstance(args[0], PyStr) {
            return py_error(
                "TypeError", "TypeAliasType() argument 'name' must be str"
            );
        }
        params: PyObj = PyTuple(t="tuple", items=[]);
        if "type_params" in kwargs {
            params = kwargs["type_params"];
        }
        return PyTypeAlias(
            t="TypeAliasType",
            name=(args[0] as PyStr).val,
            type_params=params,
            value_fn=args[1],
        );
    }
}

# ---------------- Union --------------------------------------------------------

# typing.Union itself: the _PyUnion_Type marker. Subscripting mints a union
# alias; bit-or merges aliases back into one (unionobject.c _union_or_impl).
obj PyUnionForm(PyObj) {
    def mp_subscript(index: PyObj) -> PyObj {
        items: list[PyObj];
        if isinstance(index, PyTuple) {
            items = (index as PyTuple).items;
        } else {
            items = [index];
        }
        return PyUnionAlias(t="UnionType", args=PyTuple(t="tuple", items=items));
    }

    def tp_getattro(name: str) -> PyObj {
        if name == "__module__" {
            return PyStr(t="str", val="typing");
        }
        return py_error(
            "AttributeError",
            "type object 'typing.Union' has no attribute '" + name + "'"
        );
    }
}

obj PyUnionAlias(PyObj) {
    has args: PyObj;

    def tp_getattro(name: str) -> PyObj {
        if name == "__origin__" {
            return _UNION_FORM;
        }
        if name == "__args__" or name == "__parameters__" {
            return self.args;
        }
        if name == "__module__" {
            return PyStr(t="str", val="typing");
        }
        return py_error(
            "AttributeError",
            "'typing.Union' object has no attribute '" + name + "'"
        );
    }

    def nb_binop(kind: int, other: PyObj) -> PyObj {
        if kind != NB_OR and kind != NB_INPLACE_OR {
            return PY_NOT_IMPLEMENTED;
        }
        return _union_merge(self.args, other);
    }

    def tp_richcompare(kind: int, other: PyObj) -> PyObj {
        if kind != 2 and kind != 3 {
            return PY_NOT_IMPLEMENTED;
        }
        eq = isinstance(other, PyUnionAlias)
            and self.args.tp_richcompare(2, (other as PyUnionAlias).args).tp_bool();
        return PyBool(t="bool", val=(kind == 2) == eq);
    }
}

# Module-level singleton so every alias's __origin__ is the identical object.
glob _UNION_FORM: PyObj = PyUnionForm(t="Union");

# Merge a union alias's args with one more argument (an alias expands to its
# own args; anything else appends once). Dedup by identity-preserving == like
# CPython's unionobject make_union.
def _union_merge(left: PyObj, other: PyObj) -> PyObj {
    merged: list[PyObj] = [];
    for item in (left as PyTuple).items {
        merged.append(item);
    }
    if isinstance(other, PyUnionAlias) {
        for item in ((other as PyUnionAlias).args as PyTuple).items {
            merged.append(item);
        }
    } else {
        merged.append(other);
    }
    unique: list[PyObj] = [];
    for item in merged {
        dup = False;
        for kept in unique {
            cmp = item.tp_richcompare(2, kept);
            if cmp.tp_bool() {
                dup = True;
                break;
            }
        }
        if not dup {
            unique.append(item);
        }
    }
    return PyUnionAlias(t="UnionType", args=PyTuple(t="tuple", items=unique));
}

# ---------------- module assembly ----------------------------------------------

# The _typingmodule.c export surface (EXPORT_TYPE table + method table), keyed
# by the names Lib/typing.py imports from _typing. Generic and NoDefault are
# installed by the ceval registration arm from the intrinsic singletons.
def typing_module_attrs() -> dict[str, PyObj] {
    return {
        "_idfunc": PyTypingIdFunc(t="idfunc"),
        "TypeVar": PyTypeVarCtor(t="TypeVar_ctor"),
        "ParamSpec": PyParamSpecCtor(t="ParamSpec_ctor"),
        "ParamSpecArgs": PyParamSpecArgsCtor(t="ParamSpecArgs_ctor"),
        "ParamSpecKwargs": PyParamSpecKwargsCtor(t="ParamSpecKwargs_ctor"),
        "TypeVarTuple": PyTypeVarTupleCtor(t="TypeVarTuple_ctor"),
        "TypeAliasType": PyTypeAliasTypeCtor(t="TypeAliasType_ctor"),
        "Union": _UNION_FORM,
    };
}
