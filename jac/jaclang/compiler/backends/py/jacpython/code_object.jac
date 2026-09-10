import sys;
import os;
import operator;
import from types { CodeType }
import from jaclang.runtime.python.objects {
    PyObj, PyNoneType, PyBool, PyInt, PyFloat, PyComplex, PyStr,
    PyBytes, PyTuple, PySet, PySlice, PyCode, PyEllipsis
}

def constant_value(value: PyObj, constants: dict[str, any] | None = None) -> any {
    import from jaclang.compiler.backends.py.jacpython.compiler_ir { constant_key }
    if constants is None {
        constants = {};
    }
    key = constant_key(value);
    if key not in constants {
        constants[key] = _constant_value(value, constants);
    }
    return constants[key];
}

def _constant_value(value: PyObj, constants: dict[str, any]) -> any {
    if isinstance(value, PyNoneType) {
        return None;
    }
    if isinstance(value, PyEllipsis) {
        return ...;
    }
    if isinstance(value, PyBool) {
        return value.val;
    }
    if isinstance(value, PyInt) {
        return value.val;
    }
    if isinstance(value, PyFloat) {
        return value.val;
    }
    if isinstance(value, PyComplex) {
        return complex(value.real, value.imag);
    }
    if isinstance(value, PyStr) {
        return value.val;
    }
    if isinstance(value, PyBytes) {
        return bytes(value.val);
    }
    if isinstance(value, PyTuple) {
        return tuple(constant_value(item, constants) for item in value.items);
    }
    if isinstance(value, PySet) and value.frozen {
        return frozenset(constant_value(item, constants) for item in value.items.values());
    }
    if isinstance(value, PySlice) {
        return slice(
            constant_value(value.start, constants), constant_value(value.stop, constants),
            constant_value(value.step, constants)
        );
    }
    if isinstance(value, PyCode) {
        return code_object(value, constants);
    }
    raise TypeError(f"Unsupported Python compiler constant: {value.t}");
}

def code_object(code: PyCode, constants: dict[str, any] | None = None) -> CodeType {
    if sys.version_info[:2] != (3, 14) {
        raise RuntimeError("JacPython bytecode requires CPython 3.14");
    }
    if constants is None {
        constants = {};
    }
    return CodeType(
        code.argcount, code.posonlyargcount, code.kwonlyargcount,
        len(code.varnames), code.stacksize, code.flags,
        bytes(code.co_code),
        constant_value(PyTuple(t="tuple", items=code.consts), constants),
        tuple(code.names), tuple(code.varnames),
        code.filename, code.name, code.qualname, code.firstlineno,
        bytes(code.linetable), bytes(code.exceptiontable),
        tuple(code.freevars), tuple(code.cellvars)
    );
}

def compile_python(
    source: any, filename: any, mode: str, flags: int = 0,
    dont_inherit: bool = False, optimize: int = -1
) -> any {
    import ast;
    import builtins;
    import from jaclang.compiler.frontend.python.ast_bridge { from_python_ast, to_python_ast }
    import from jaclang.compiler.backends.py.jacpython.product_compile {
        compile_source, compile_ast
    }
    import from jaclang.runtime.python.objects { PyError }
    filename = os.fsdecode(os.fspath(filename));
    if "\x00" in filename {
        raise ValueError("embedded null character");
    }
    if not isinstance(mode, str) {
        raise TypeError("compile() argument 'mode' must be str");
    }
    flags = operator.index(flags);
    optimize = operator.index(optimize);
    if flags < -(1 << 31) or flags >= (1 << 31) or optimize < -(1 << 31) or optimize >= (1 << 31) {
        raise OverflowError("Python int too large to convert to C int");
    }
    dont_inherit = bool(dont_inherit);
    if mode not in ("exec", "eval", "single") {
        raise ValueError("compile() mode must be 'exec', 'eval' or 'single'");
    }
    if flags & ~ast.PyCF_ONLY_AST {
        raise NotImplementedError("JacPython compile flags are not implemented yet");
    }
    if optimize == -1 {
        optimize = sys.flags.optimize;
    }
    if optimize not in (0, 1, 2) {
        raise ValueError("compile(): invalid optimize value");
    }
    if isinstance(source, ast.AST) {
        if flags & ast.PyCF_ONLY_AST {
            return source;
        }
        result = compile_ast(from_python_ast(source), filename, mode, optimize);
    } else {
        if not isinstance(source, str) {
            try {
                raw = bytes(memoryview(source));
            } except TypeError {
                raise TypeError("compile() arg 1 must be a string, bytes or AST object");
            }
            if b"\x00" in raw {
                raise SyntaxError("source code string cannot contain null bytes");
            }
            # detect_encoding only reads the BOM and the first two coding-cookie
            # lines. It does not invoke CPython's C tokenizer or parser.
            import io;
            import tokenize;
            encoding = tokenize.detect_encoding(io.BytesIO(raw).readline)[0];
            try {
                source = raw.decode(encoding);
            } except UnicodeDecodeError as error {
                raise SyntaxError(str(error));
            }
        }
        if "\x00" in source {
            raise SyntaxError("source code string cannot contain null bytes");
        }
        if flags & ast.PyCF_ONLY_AST {
            import from jaclang.compiler.frontend.python.parser {
                parse_file, parse_eval_source, parse_interactive
            }
            if mode == "exec" {
                tree = parse_file(source, filename);
            } elif mode == "eval" {
                tree = parse_eval_source(source, filename);
            } else {
                tree = parse_interactive(source, filename);
            }
            if tree is None {
                raise SyntaxError("invalid syntax");
            }
            return to_python_ast(tree, constant_value);
        }
        result = compile_source(source, filename, mode, optimize);
    }
    if isinstance(result, PyError) {
        error_type = getattr(builtins, result.exception.type_name, RuntimeError);
        raise error_type(result.exception.message);
    }
    if not isinstance(result, PyCode) {
        raise SystemError("JacPython compiler returned no code object");
    }
    return code_object(result);
}
