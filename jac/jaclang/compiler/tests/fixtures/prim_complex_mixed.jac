"""Mixed complex-scalar operator equivalence fixture.

CPython promotes a numeric operand against `complex` through the reflected
slot ((1+2j) + 1, 3 - 1j, ...); the native backend lowers the same shape by
boxing the scalar operand into a complex first. ES/JS has no comparable
lowering and opts out (returns {}).
"""

def cmixed_py -> dict[any, any] {
    c1 = complex(3, 4);
    c2 = complex(3, 4);
    c2 += 1;
    return {
        "add_scalar": (c1 + 1) == complex(4, 4),
        "sub_scalar": (c1 - 2) == complex(1, 4),
        "mul_scalar": (c1 * 2) == complex(6, 8),
        "div_scalar": (c1 / 2) == complex(1.5, 2),
        "scalar_add": (1 + c1) == complex(4, 4),
        "scalar_sub": (10 - c1) == complex(7, -4),
        "scalar_mul": (2 * c1) == complex(6, 8),
        "scalar_div": (complex(6, 8) / 2) == complex(3, 4),
        "aug_add": c2 == complex(4, 4),
        "pow_scalar": (c1 ** 2) == complex(-7, 24)
    };
}

def cmixed_cl -> dict[any, any] {
    return {};
}

def cmixed_na -> dict[str, any] {
    c1 = complex(3, 4);
    c2 = complex(3, 4);
    c2 += 1;
    r: dict[str, any] = {
        "add_scalar": (c1 + 1) == complex(4, 4),
        "sub_scalar": (c1 - 2) == complex(1, 4),
        "mul_scalar": (c1 * 2) == complex(6, 8),
        "div_scalar": (c1 / 2) == complex(1.5, 2),
        "scalar_add": (1 + c1) == complex(4, 4),
        "scalar_sub": (10 - c1) == complex(7, -4),
        "scalar_mul": (2 * c1) == complex(6, 8),
        "scalar_div": (complex(6, 8) / 2) == complex(3, 4),
        "aug_add": c2 == complex(4, 4),
        "pow_scalar": (c1 ** 2) == complex(-7, 24)
    };
    return r;
}
