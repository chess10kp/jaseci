"""Mixed complex-scalar operator equivalence fixture.

CPython promotes a numeric operand against `complex` through the reflected
slot ((1+2j) + 1, 3 - 1j, ...); the native backend lowers the same shape by
boxing the scalar operand into a complex first. ES/JS has no comparable
lowering and opts out (returns {}).
"""

obj CBox {
    has f: complex;
}

def cmixed_py -> dict[any, any] {
    c1 = complex(3, 4);
    c2 = complex(3, 4);
    c2 += 1;
    box_add = CBox();
    box_add.f = complex(1, 1);
    box_add.f += 2;
    box_mul = CBox();
    box_mul.f = complex(1, 1);
    box_mul.f *= 3;
    box_pow = CBox();
    box_pow.f = complex(1, 1);
    box_pow.f **= 2;
    box_div = CBox();
    box_div.f = complex(1, 1);
    box_div.f /= 2;
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
        "pow_scalar": (c1 ** 2) == complex(-7, 24),
        "aug_field_add": box_add.f == complex(3, 1),
        "aug_field_mul": box_mul.f == complex(3, 3),
        "aug_field_pow": box_pow.f == complex(0, 2),
        "aug_field_div": box_div.f == complex(0.5, 0.5)
    };
}

def cmixed_cl -> dict[any, any] {
    return {};
}

def cmixed_na -> dict[str, any] {
    c1 = complex(3, 4);
    c2 = complex(3, 4);
    c2 += 1;
    box_add = CBox();
    box_add.f = complex(1, 1);
    box_add.f += 2;
    box_mul = CBox();
    box_mul.f = complex(1, 1);
    box_mul.f *= 3;
    box_pow = CBox();
    box_pow.f = complex(1, 1);
    box_pow.f **= 2;
    box_div = CBox();
    box_div.f = complex(1, 1);
    box_div.f /= 2;
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
        "pow_scalar": (c1 ** 2) == complex(-7, 24),
        "aug_field_add": box_add.f == complex(3, 1),
        "aug_field_mul": box_mul.f == complex(3, 3),
        "aug_field_pow": box_pow.f == complex(0, 2),
        "aug_field_div": box_div.f == complex(0.5, 0.5)
    };
    return r;
}
