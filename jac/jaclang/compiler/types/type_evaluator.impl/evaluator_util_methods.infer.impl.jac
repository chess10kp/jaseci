impl TypeEvaluator._literal_type_from_expr(val: Expr) -> TypeBase | None {
    if not self.prefetch {
        return None;
    }

    if isinstance(val, Null) and self.prefetch.none_type_class {
        return self._convert_to_instance(self.prefetch.none_type_class);
    }
    base: ClassType | None = None;
    value: str | int | bool | None = None;

    if isinstance(val, Bool) {
        base = self.prefetch.bool_class;
        value = val.lit_value;
    } elif isinstance(val, Int) {
        base = self.prefetch.int_class;
        value = val.lit_value;
    } elif (
        isinstance(val, UnaryExpr)
        and val.op.name == Tok.MINUS
        and isinstance(val.operand, Int)
    ) {
        base = self.prefetch.int_class;
        value = -val.operand.lit_value;
    } elif isinstance(val, String) and isinstance(val.lit_value, str) {
        base = self.prefetch.str_class;
        value = val.lit_value;
    } elif isinstance(val, MultiString) {
        text = "";
        for s in val.strings {
            if not (isinstance(s, String) and isinstance(s.lit_value, str)) {
                return None;
            }
            text += s.lit_value;
        }
        base = self.prefetch.str_class;
        value = text;
    }
    if base is None {
        return None;
    }
    return self._convert_to_instance(base.clone_with_literal(value));
}

impl TypeEvaluator._type_in_list(ty: TypeBase, type_list: list[TypeBase]) -> bool {
    import from jaclang.compiler.types.type_utils { types_equivalent }
    for existing in type_list {
        if isinstance(ty, ClassType) and isinstance(existing, ClassType) {
            if ty.shared.same_class(existing.shared) {
                return True;
            }
        } elif ty is existing {
            return True;
        } elif (
            not isinstance(ty, ClassType)
            and not isinstance(existing, ClassType)
            and types_equivalent(ty, existing)
        ) {
            return True;
        }
    }
    return False;
}

impl TypeEvaluator._collect_unique_types(ty: TypeBase, result: list[TypeBase]) -> None {
    if isinstance(ty, UnionType) {
        for member in ty.types {
            self._collect_unique_types(member, result);
        }
    } else {
        if not self._type_in_list(ty, result) {
            result.append(ty);
        }
    }
}

impl TypeEvaluator._get_expected_container_type(
    expected_type: TypeBase | None, container_class: TypeBase
) -> ClassType | None {
    if not isinstance(container_class, ClassType) {
        return None;
    }
    candidates: list[TypeBase] = [];
    if isinstance(expected_type, UnionType) {
        candidates = expected_type.types or [];
    } elif expected_type is not None {
        candidates = [expected_type];
    }
    found: ClassType | None = None;
    for candidate in candidates {
        if isinstance(candidate, ClassType)
            and candidate.shared.same_class(container_class.shared) {
            if found is not None {
                return None;
            }
            found = candidate;
        }
    }
    return found;
}

impl TypeEvaluator._get_expected_element_type(
    expected_type: TypeBase | None, container_class: TypeBase
) -> TypeBase | None {
    expected = self._get_expected_container_type(expected_type, container_class);
    if expected is not None and expected.private.type_args {
        return self._convert_to_instance(expected.private.type_args[0]);
    }
    return None;
}

impl TypeEvaluator._get_expected_kv_types(
    expected_type: TypeBase | None, dict_class: TypeBase
) -> tuple[TypeBase, TypeBase] | None {
    expected = self._get_expected_container_type(expected_type, dict_class);
    if expected is not None
        and expected.private.type_args
        and len(expected.private.type_args) >= 2 {
        return (
            self._convert_to_instance(expected.private.type_args[0]),
            self._convert_to_instance(expected.private.type_args[1])
        );
    }
    return None;
}

impl TypeEvaluator._infer_list_elem_from_mutations(expr: ListVal) -> TypeBase | None {
    asg = expr.parent;
    if (
        not isinstance(asg, Assignment)
        or asg.value is not expr
        or asg.aug_op is not None
    ) {
        return None;
    }
    refs: list[NameAtom] = [];
    for tgt in asg.target {
        if isinstance(tgt, Name) and tgt.sym is not None {
            refs.extend(tgt.sym.uses);
            refs.extend(tgt.sym.defn);
        }
    }
    if not refs {
        return None;
    }
    elem_types: list[TypeBase] = [];
    seen_refs: set[int] = set();
    saw_none = False;
    for ref in refs {
        if id(ref) in seen_refs {
            continue;
        }
        seen_refs.add(id(ref));
        contrib = self._list_mutation_elem_contrib(ref);
        if contrib is None {
            continue;
        }
        widened = self._widen_literal_for_declaration(contrib);
        if (
            isinstance(widened, ClassType) and widened.is_builtin(["NoneType", "None"])
        ) {
            saw_none = True;
            continue;
        }
        if not (
            isinstance(widened, ClassType)
            and widened.is_builtin(["int", "float", "str", "bool"])
        ) {
            return None;
        }
        if not self._type_in_list(widened, elem_types) {
            elem_types.append(widened);
        }
    }
    if not elem_types {
        return None;
    }
    if len(elem_types) == 1 and not saw_none {
        return elem_types[0];
    }
    if self.prefetch and self.prefetch.any_class {
        return self._convert_to_instance(self.prefetch.any_class);
    }
    return None;
}

impl TypeEvaluator._list_mutation_elem_contrib(ref: NameAtom) -> TypeBase | None {
    tr = ref.parent;
    if isinstance(tr, AtomTrailer) and tr.target is ref {
        if (
            tr.is_attr
            and isinstance(tr.right, Name)
            and isinstance(tr.parent, FuncCall)
            and tr.parent.target is tr
        ) {
            args = [
                p
                for p in (tr.parent.params or [])
                if not isinstance(p, KWPair)
            ];
            if tr.right.value in ("append", "insert") {
                arg_idx = 0 if tr.right.value == "append" else 1;
                if len(args) > arg_idx {
                    return self.get_type_of_expression(args[arg_idx]);
                }
                return None;
            }
            if tr.right.value == "extend" and args {
                if not (self.prefetch and self.prefetch.list_class) {
                    return None;
                }
                return self._get_expected_element_type(
                    self.get_type_of_expression(args[0]), self.prefetch.list_class
                );
            }
            return None;
        }
        if (
            not tr.is_attr
            and isinstance(tr.right, IndexSlice)
            and not tr.right.is_range
            and isinstance(tr.parent, Assignment)
            and tr.parent.aug_op is None
            and tr.parent.value is not None
            and any(t is tr for t in tr.parent.target)
        ) {
            return self.get_type_of_expression(tr.parent.value);
        }
        return None;
    }
    if (
        isinstance(tr, Assignment)
        and tr.aug_op is not None
        and tr.aug_op.name == Tok.ADD_EQ
        and tr.value is not None
        and any(t is ref for t in tr.target)
    ) {
        if not (self.prefetch and self.prefetch.list_class) {
            return None;
        }
        return self._get_expected_element_type(
            self.get_type_of_expression(tr.value), self.prefetch.list_class
        );
    }
    return None;
}
