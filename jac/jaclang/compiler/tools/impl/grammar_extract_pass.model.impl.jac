impl GExpr.__eq__(other: object) -> bool {
    return type(self) == type(other);
}

impl GExpr.__repr__ -> str {
    return "GExpr()";
}

impl GSeq.__eq__(other: object) -> bool {
    return isinstance(other, GSeq) and self.items == other.items;
}

impl GSeq.__repr__ -> str {
    return f"GSeq({self.items!r})";
}

impl GAlt.__eq__(other: object) -> bool {
    return isinstance(other, GAlt) and self.choices == other.choices;
}

impl GAlt.__repr__ -> str {
    return f"GAlt({self.choices!r})";
}

impl GOpt.__eq__(other: object) -> bool {
    return isinstance(other, GOpt) and self.inner == other.inner;
}

impl GOpt.__repr__ -> str {
    return f"GOpt({self.inner!r})";
}

impl GStar.__eq__(other: object) -> bool {
    return isinstance(other, GStar) and self.inner == other.inner;
}

impl GStar.__repr__ -> str {
    return f"GStar({self.inner!r})";
}

impl GPlus.__eq__(other: object) -> bool {
    return isinstance(other, GPlus) and self.inner == other.inner;
}

impl GPlus.__repr__ -> str {
    return f"GPlus({self.inner!r})";
}

impl GTok.__eq__(other: object) -> bool {
    return isinstance(other, GTok) and self.name == other.name;
}

impl GTok.__repr__ -> str {
    return f"GTok({self.name!r})";
}

impl GTok.__hash__ -> int {
    return hash(("GTok", self.name));
}

impl GRef.__eq__(other: object) -> bool {
    return isinstance(other, GRef) and self.name == other.name;
}

impl GRef.__repr__ -> str {
    return f"GRef({self.name!r})";
}

impl GRef.__hash__ -> int {
    return hash(("GRef", self.name));
}

impl GrammarRule.to_ebnf -> str {
    return f"{self.name} ::= {GrammarExtractPass.format_ebnf(self.body)}";
}

impl GrammarRule.__repr__ -> str {
    return f"GrammarRule({self.name!r}, {self.body!r})";
}
