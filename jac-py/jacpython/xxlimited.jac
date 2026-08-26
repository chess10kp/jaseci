# Native xxlimited module facade (lift of reference/cpython/Modules/xxlimited.c,
# CPython 3.14.6).
#
# xxlimited.c is the extension-type template module: at multi-phase init
# (xx_modexec) it adds the ``Error`` exception, the ``Xxo`` type (attribute
# storage in a PRIVATE dict behind tp_getattro/tp_setattro, a ``demo`` method
# with defining-class typecheck, and an ``x_exports`` getset fed by the buffer
# protocol), the ``Str`` str-subclass, and the ``foo``/``new`` functions.
#
# Facade mapping notes (mirrors the binascii precedent):
# - ``Error``: custom exception types are unrepresentable in the native shim
#   world, so the attribute is the native Exception type; raising it produces a
#   plain Exception instance whose catch semantics (``except xxlimited.Error``
#   -> Exception family) match, while repr/name degrade to "Exception".
# - Buffer protocol: the VM has no bf_getbuffer seam, so ``x_exports`` always
#   reads 0 and memoryview(xxo) is unsupported; test_buffer pins quarantine.
# - ``Str``: subclass identity vs builtin str is not expressible for shim
#   attrs, so the constructor mirrors str() value semantics only.

import from objects {
    PyObj,
    PyStr,
    PyInt,
    is_error,
    py_none,
    py_error,
    py_exception_type,
    _uint_to_str,
}

import from ceval {
    PyModule,
    py_str,
    py_id,
}


# ---------------- Xxo ---------------------------------------------------------
#
# Instance state per XxoObject in the C source. The private attribute dict is
# created eagerly here where C creates it lazily on first setattro -- the NULL
# dict acts as an empty dict, so the observable surface is identical. The
# 10-byte export buffer exists only behind the VM's absent buffer protocol;
# the counter stays at its zero-initialized C value.

obj PyXxoObj(PyObj) {
    has x_attr: dict[str, PyObj] = {},
        x_exports_count: int = 0;

    def tp_type_name -> str {
        return "xxlimited.Xxo";
    }

    # Xxo_getattro: the private dict wins FIRST (it shadows even x_exports --
    # the C code checks x_attr before falling back to generic getattr), then
    # the type-level surface, then the generic AttributeError.
    def tp_getattro(name: str) -> PyObj {
        if name in self.x_attr {
            return self.x_attr[name];
        }
        if name == "x_exports" {
            return PyInt(t="int", val=self.x_exports_count);
        }
        if name == "demo" {
            return PyXxoMethod(t="xxo_method", target=self, name="demo");
        }
        if name == "__name__" {
            return PyStr(t="str", val="Xxo");
        }
        return _generic_attribute_error("xxlimited.Xxo", name);
    }

    # Xxo_setattro: EVERY assignment/delete lands in the private dict -- the C
    # code never reaches generic setattr, so even x_exports is writable into
    # the shadow dict.
    def tp_setattro(name: str, value: PyObj) -> PyObj {
        self.x_attr[name] = value;
        return py_none();
    }

    # Xxo_setattro delete arm: KeyError from PyDict_DelItem remaps to
    # AttributeError("delete non-existing Xxo attribute").
    def tp_del_attr(name: str) -> PyObj {
        if name in self.x_attr {
            del self.x_attr[name];
            return py_none();
        }
        return py_error("AttributeError", "delete non-existing Xxo attribute");
    }

    # object.__repr__ identity form with the full tp_name, matching the C
    # type's repr through the default slot.
    def tp_repr -> PyObj {
        return PyStr(t="str", val="<xxlimited.Xxo object at 0x"
            + _uint_to_str(py_id(self), 16, "0123456789abcdef") + ">");
    }
}

# Bound Xxo.demo. Xxo_demo validates kwargs/nargs byte-exact, returns the
# argument when it is a str or an Xxo of the DEFINING class, else None.
obj PyXxoMethod(PyObj) {
    has target: PyXxoObj,
        name: str;

    def tp_call(args: list[PyObj], kwargs: dict[str, PyObj]) -> PyObj {
        if len(kwargs) > 0 {
            return py_error("TypeError", "demo() takes no keyword arguments");
        }
        if len(args) != 1 {
            return py_error("TypeError", "demo() takes exactly 1 argument");
        }
        o = args[0];
        if isinstance(o, PyStr) {
            return o;
        }
        if isinstance(o, PyXxoObj) {
            return o;
        }
        return py_none();
    }
}

# object.__new__ rejection shape quoted by the generic AttributeError fallback
# (tp_name included, matching PyObject_GenericGetAttr).
def _generic_attribute_error(type_name: str, name: str) -> PyObj {
    return py_error(
        "AttributeError",
        "'" + type_name + "' object has no attribute '" + name + "'",
    );
}

# ---------------- constructors and module functions ---------------------------

# Xxo type call: the 3.14 spec defines no tp_new, so instances come through
# object.__new__, which rejects any arguments.
obj PyXxoCtor(PyObj) {
    def tp_call(args: list[PyObj], kwargs: dict[str, PyObj]) -> PyObj {
        if len(args) > 0 or len(kwargs) > 0 {
            return py_error("TypeError", "Xxo() takes no arguments");
        }
        return PyXxoObj(t="xxo_obj");
    }
}

# Str type call: empty-slot str subclass; construction inherits str_init, i.e.
# plain str() value semantics (PyObject_Str).
obj PyStrCtor(PyObj) {
    def tp_call(args: list[PyObj], kwargs: dict[str, PyObj]) -> PyObj {
        if len(kwargs) > 0 {
            return py_error("TypeError", "str() takes no keyword arguments");
        }
        if len(args) == 0 {
            return PyStr(t="str", val="");
        }
        if len(args) > 1 {
            return py_error(
                "TypeError", "str() takes at most 1 argument (" + str(len(args)) + " given)"
            );
        }
        return py_str(args[0]);
    }
}

# xx_foo: PyArg_ParseTuple "ll" -- exactly two positional ints combined with C
# long arithmetic.
obj PyXxFooFn(PyObj) {
    def tp_call(args: list[PyObj], kwargs: dict[str, PyObj]) -> PyObj {
        if len(kwargs) > 0 {
            return py_error("TypeError", "foo() takes no keyword arguments");
        }
        if len(args) != 2 {
            return py_error(
                "TypeError",
                "foo() takes exactly 2 arguments (" + str(len(args)) + " given)",
            );
        }
        i_r = args[0].to_index();
        if is_error(i_r) {
            return py_error("TypeError", "an integer is required");
        }
        j_r = args[1].to_index();
        if is_error(j_r) {
            return py_error("TypeError", "an integer is required");
        }
        i = (i_r as PyInt).val;
        j = (j_r as PyInt).val;
        if i < -9223372036854775808 or i > 9223372036854775807
            or j < -9223372036854775808 or j > 9223372036854775807 {
            return py_error("OverflowError", "Python int too large to convert to C long");
        }
        return PyInt(t="int", val=i + j);
    }
}

# xx_new: METH_NOARGS factory for a fresh XxoObject.
obj PyXxNewFn(PyObj) {
    def tp_call(args: list[PyObj], kwargs: dict[str, PyObj]) -> PyObj {
        if len(args) > 0 or len(kwargs) > 0 {
            msg = "new() takes no arguments";
            if len(args) > 0 {
                msg = msg + " (" + str(len(args)) + " given)";
            }
            return py_error("TypeError", msg);
        }
        return PyXxoObj(t="xxo_obj");
    }
}

# ---------------- module builder ----------------------------------------------

def build_xxlimited_module -> PyObj {
    # PyErr_NewException("xxlimited.Error", NULL, NULL) mapped onto the native
    # Exception family (see the facade notes in the header).
    error_type = py_exception_type("Exception");
    return PyModule(
        t="module",
        name="xxlimited",
        attrs={
            "Error": error_type,
            "Xxo": PyXxoCtor(t="xxo_ctor"),
            "Str": PyStrCtor(t="xx_str_ctor"),
            "foo": PyXxFooFn(t="xx_foo_fn"),
            "new": PyXxNewFn(t="xx_new_fn"),
            "__doc__": PyStr(
                t="str", val="This is a template module just for instruction."
            ),
        },
    );
}
