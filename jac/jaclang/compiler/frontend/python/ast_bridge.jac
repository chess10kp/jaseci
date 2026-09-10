import ast;
import jaclang.compiler.frontend.python.ast_nodes as nodes;
import from jaclang.runtime.python.objects {
    PyObj, PyBool, PyInt, PyFloat, PyComplex, PyStr, PyBytes,
    PyTuple, PySet, PyEllipsis, py_none
}

def constant_from_python(value: any) -> PyObj {
    if value is None {
        return py_none();
    }
    if value is ... {
        return PyEllipsis(t="ellipsis");
    }
    if isinstance(value, bool) {
        return PyBool(t="bool", val=value);
    }
    if isinstance(value, int) {
        return PyInt(t="int", val=value);
    }
    if isinstance(value, float) {
        return PyFloat(t="float", val=value);
    }
    if isinstance(value, complex) {
        return PyComplex(t="complex", real=value.real, imag=value.imag);
    }
    if isinstance(value, str) {
        return PyStr(t="str", val=value);
    }
    if isinstance(value, bytes) {
        return PyBytes(t="bytes", val=list(value));
    }
    if isinstance(value, tuple) {
        return PyTuple(t="tuple", items=[constant_from_python(item) for item in value]);
    }
    if isinstance(value, frozenset) {
        return PySet(
            t="frozenset", frozen=True,
            items={str(i): constant_from_python(item) for (i, item) in enumerate(value)}
        );
    }
    raise TypeError(f"Invalid AST constant: {type(value).__name__}");
}

def from_python_ast(value: any) -> any {
    if isinstance(value, list) {
        return [from_python_ast(item) for item in value];
    }
    if not isinstance(value, ast.AST) {
        return value;
    }
    if isinstance(value, ast.NamedExpr) and not isinstance(value.target, ast.Name) {
        raise TypeError("NamedExpr target must be a Name");
    }
    if isinstance(value, ast.TypeAlias) and not isinstance(value.name, ast.Name) {
        raise TypeError("TypeAlias with non-Name name");
    }
    name = type(value).__name__;
    constructor = getattr(nodes, name, None);
    if constructor is None {
        raise TypeError(f"Unsupported Python AST node: {name}");
    }
    fields: dict[str, any] = {};
    for (key, child) in ast.iter_fields(value) {
        if isinstance(value, ast.Constant) and key == "value" {
            fields[key] = constant_from_python(child);
        } elif isinstance(value, ast.MatchSingleton) and key == "value" {
            fields[key] = constant_from_python(child);
        } else {
            fields[key] = from_python_ast(child);
        }
    }
    for key in value._attributes {
        fields[key] = getattr(value, key, None);
    }
    return constructor(**fields);
}

def to_python_ast(value: any, convert_constant: any) -> any {
    if isinstance(value, list) {
        return [to_python_ast(item, convert_constant) for item in value];
    }
    if isinstance(value, PyObj) {
        return convert_constant(value);
    }
    if not isinstance(value, nodes.ast_node) {
        return value;
    }
    constructor = getattr(ast, type(value).__name__);
    fields: dict[str, any] = {};
    for key in constructor._fields {
        fields[key] = to_python_ast(getattr(value, key), convert_constant);
    }
    for key in constructor._attributes {
        child = getattr(value, key, None);
        if child is not None {
            fields[key] = child;
        }
    }
    return constructor(**fields);
}
