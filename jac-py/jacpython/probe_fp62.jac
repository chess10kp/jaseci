import from layer9_product_exec { product_exec }

glob R1 = (
    "caught = ''\n"
    "try:\n"
    "    raise ValueError('v')\n"
    "except 42:\n"
    "    caught = 'wrong'\n"
);
glob R2 = (
    "caught = ''\n"
    "try:\n"
    "    raise ValueError('v')\n"
    "except 'str':\n"
    "    caught = 'wrong'\n"
);
glob R3 = (
    "caught = ''\n"
    "try:\n"
    "    raise ValueError('v')\n"
    "except [ValueError]:\n"
    "    caught = 'wrong'\n"
);
glob R4 = (
    "out = []\n"
    "try:\n"
    "    try:\n"
    "        raise ValueError('v')\n"
    "    except (TypeError, 42):\n"
    "        out.append('wrong')\n"
    "except TypeError as e:\n"
    "    out.append('outer-caught:' + type(e).__name__)\n"
    "r = '|'.join(out)\n"
);
glob R5 = (
    "out = []\n"
    "try:\n"
    "    raise ValueError('v')\n"
    "except (ValueError, TypeError):\n"
    "    out.append('matched')\n"
    "r = '|'.join(out)\n"
);

test "fp62 r1 int" { product_exec(R1); }
test "fp62 r2 str" { product_exec(R2); }
test "fp62 r3 list" { product_exec(R3); }
test "fp62 r4 tuple-mixed outer-catch" { product_exec(R4); }
test "fp62 r5 valid-tuple still matches" { product_exec(R5); }
