# P3.2a — type core helpers (name, repr, identity richcompare, ready stub).
#
# c2jac-assisted from ``jac-py/tools/p3_object_core/corpus/typeobject_core.c``
# (lift: ``jac-py/Objects/_lifted/typeobject_core.jac``).
#
# ``type_ready`` lives in ``type_slots.jac`` (import-free leaf); re-import here
# so existing ``import from typeobject { type_ready, ... }`` call sites stay valid.
import from objects { PyObj, PyStr, PyBool, is_error, py_error, Py_EQ, Py_NE, }
import from type_slots {
    type_ready,
    Py_TPFLAGS_READY,
    Py_TPFLAGS_READYING,
}


# ``_PyType_Name`` — short name after the last ``.`` in ``tp_name``.
def type_short_name(tp_name: str) -> str {
    if tp_name == "" {
        return "";
    }
    dot = tp_name.rfind(".");
    if dot < 0 {
        return tp_name;
    }
    return tp_name[dot + 1:];
}

# ``type_repr`` — ``<class 'name'>`` (module prefix deferred).
def type_repr(tp_name: str) -> PyObj {
    if tp_name == "" {
        return PyStr(t="str", val="<class at 0x0>");
    }
    return PyStr(t="str", val="<class '" + tp_name + "'>");
}

# Build ``tp_name`` for repr: ``module.Class`` unless module is ``builtins``.
def type_tp_name(class_name: str, module_name: str) -> str {
    if module_name != "" and module_name != "builtins" {
        return module_name + "." + class_name;
    }
    return class_name;
}

# ``type_richcompare`` — types compare by identity for ``==`` / ``!=`` only.
def type_richcompare(op: int, a: PyObj, b: PyObj) -> PyObj {
    return type_richcompare_same(op, a is b);
}

def type_richcompare_same(op: int, same: bool) -> PyObj {
    if op == Py_EQ {
        return PyBool(t="bool", val=same);
    }
    if op == Py_NE {
        return PyBool(t="bool", val=not same);
    }
    return py_error("TypeError", "unsupported comparison between classes");
}

# ``type_hash`` — types are unhashable (``PyObject_HashNotImplemented``).
def type_hash_unimplemented(v: PyObj) -> PyObj {
    label = type_short_name(v.t);
    if label == "" {
        label = v.t;
    }
    return py_error("TypeError", "unhashable type: '" + label + "'");
}
