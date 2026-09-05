"""grammar2jac - emit Jac PEG parser rules from CPython's python.gram.

P0.7 backend for the pegen grammar model (PLAN.md). Reuses
reference/cpython/Tools/peg_generator to parse the frozen grammar, then emits
checked-in Jac rule functions that call peg_runtime + parser_actions.

Usage:
    python jac-py/tools/grammar2jac.py
    python jac-py/tools/grammar2jac.py --check
    python jac-py/tools/grammar2jac.py --stdout
"""

from __future__ import annotations

import argparse
import ast as py_ast
import os
import re
import sys
from collections.abc import Sequence
from io import StringIO
from typing import IO, Any

_HERE = os.path.dirname(os.path.abspath(__file__))
_REPO = os.path.dirname(os.path.dirname(_HERE))
_PEGEN = os.path.join(_REPO, "reference", "cpython", "Tools", "peg_generator")
sys.path.insert(0, _PEGEN)
sys.path.insert(0, _HERE)

from action_translate import ActionTranslationError, ActionTranslator  # noqa: E402
from pegen.build import build_parser, generate_token_definitions  # noqa: E402
from pegen.grammar import (  # noqa: E402
    Alt,
    Cut,
    Forced,
    Gather,
    Grammar,
    GrammarVisitor,
    Group,
    Lookahead,
    NamedItem,
    NameLeaf,
    NegativeLookahead,
    Opt,
    PositiveLookahead,
    Repeat0,
    Repeat1,
    Rhs,
    Rule,
    StringLeaf,
)
from pegen.parser_generator import (  # noqa: E402
    KeywordCollectorVisitor,
    ParserGenerator,
    RuleCollectorVisitor,
)

GRAMMAR_PATH = os.path.join(_REPO, "reference", "cpython", "Grammar", "python.gram")
TOKENS_PATH = os.path.join(_REPO, "reference", "cpython", "Grammar", "Tokens")
OUT_PATH = os.path.join(_REPO, "jac-py", "jacpython", "parser.jac")
GRAMMAR_PROVENANCE = "reference/cpython/Grammar/python.gram"
START_RULES: list[str] = ["eval", "file"]


class GrammarTypeError(ValueError):
    """Raised when a grammar return type is not in the pinned type registry."""


JAC_TYPES: dict[str, str] = {
    "expr_ty": "expr",
    "mod_ty": "mod",
    "stmt_ty": "stmt",
    "pattern_ty": "pattern",
    "arguments_ty": "arguments",
    "alias_ty": "alias",
    "arg_ty": "arg",
    "keyword_ty": "keyword",
    "comprehension_ty": "comprehension",
    "excepthandler_ty": "excepthandler",
    "match_case_ty": "match_case",
    "type_param_ty": "type_param",
    "withitem_ty": "withitem",
    "AugOperator*": "operator",
    "CmpopExprPair*": "pa_cmpop_expr_pair",
    "KeyValuePair*": "kv_pair",
    "KeyPatternPair*": "kp_pair",
    "KeywordOrStarred*": "keyword_or_starred_node",
    "NameDefaultPair*": "name_default_pair",
    "ResultTokenWithMetadata*": "peg_token",
    "SlashWithDefault*": "object",
    "StarEtc*": "object",
    "Token*": "peg_token",
    "asdl_alias_seq*": "list[alias]",
    "asdl_arg_seq*": "list[arg]",
    "asdl_comprehension_seq*": "list[comprehension]",
    "asdl_expr_seq*": "list[expr]",
    "asdl_identifier_seq*": "list[str]",
    "asdl_int_seq*": "list[cmpop]",
    "asdl_keyword_seq*": "list[keyword]",
    "asdl_kvpair_seq*": "list[kv_pair]",
    "asdl_kvpattern_seq*": "list[kp_pair]",
    "asdl_keyword_or_starred_seq*": "list[keyword_or_starred_node]",
    "asdl_pattern_seq*": "list[pattern]",
    "asdl_seq*": "list[object]",
    "asdl_stmt_seq*": "list[stmt]",
    "asdl_type_param_seq*": "list[type_param]",
    "asdl_withitem_seq*": "list[withitem]",
}

BINOP_OPSBINOP_OPS = {
    "Add": "Add",
    "Sub": "Sub",
    "Mult": "Mult",
    "Div": "Div",
    "FloorDiv": "FloorDiv",
    "Mod": "Mod",
    "MatMult": "MatMult",
    "Pow": "Pow",
    "LShift": "LShift",
    "RShift": "RShift",
    "BitOr": "BitOr",
    "BitXor": "BitXor",
    "BitAnd": "BitAnd",
}

UNARY_OPS = {"UAdd": "UAdd", "USub": "USub", "Invert": "Invert", "Not": "Not"}
BOOL_OPS = {"And": "And", "Or": "Or"}
CMP_OPS = {
    "Eq": "Eq",
    "NotEq": "NotEq",
    "Lt": "Lt",
    "LtE": "LtE",
    "Gt": "Gt",
    "GtE": "GtE",
    "Is": "Is",
    "IsNot": "IsNot",
    "In": "In",
    "NotIn": "NotIn",
}

TOKEN_CALLS = {
    "NAME": ("name_var", "pa_name_from_token(peg_expect_token(p, NAME))"),
    "NUMBER": ("number_var", "pa_number_from_token(peg_expect_token(p, NUMBER))"),
    "STRING": ("string_var", "peg_expect_token(p, STRING)"),
    "OP": ("op_var", "peg_expect_token(p, OP)"),
}


def _refs_in_node(node: Any) -> set[str]:
    names: set[str] = set()

    def walk(n: Any) -> None:
        if isinstance(n, NameLeaf):
            names.add(n.value)
        elif hasattr(n, "__dict__"):
            for v in n.__dict__.values():
                if isinstance(v, list):
                    for x in v:
                        walk(x)
                elif v is not None and not isinstance(v, (str, int, bool)):
                    walk(v)

    walk(node)
    return names


def _alt_uses_rule(alt: Alt, name: str) -> bool:
    return name in _refs_in_node(alt)


def jac_type(c_type: str | None, *, is_seq: bool = False) -> str:
    if c_type is None:
        return "object"
    if c_type in JAC_TYPES:
        inner = JAC_TYPES[c_type]
        if (
            is_seq
            and c_type.endswith("*")
            and not inner.startswith("list[")
        ):
            return f"list[{inner}]"
        return inner
    if c_type.startswith("asdl_") and c_type.endswith("_seq*"):
        inner_name = c_type[len("asdl_") : -len("_seq*")]
        if inner_name in JAC_TYPES:
            inner = JAC_TYPES[inner_name]
        elif f"{inner_name}_ty" in JAC_TYPES:
            inner = JAC_TYPES[f"{inner_name}_ty"]
        else:
            return "list[object]"
        if inner.startswith("list["):
            return inner
        return f"list[{inner}]"
    if c_type.endswith("*"):
        inner_name = c_type[:-1]
        if inner_name in JAC_TYPES:
            inner = JAC_TYPES[inner_name]
        elif inner_name.endswith("_ty"):
            inner = inner_name[: -len("_ty")]
        else:
            raise GrammarTypeError(f"unknown pointer grammar type: {c_type!r}")
        if inner.startswith("list["):
            return inner
        return f"list[{inner}]"
    raise GrammarTypeError(f"unknown grammar type: {c_type!r}")


def jac_cast_type(ret: str) -> str:
    return ret.replace(" | None", "").strip()


def jac_return_type(c_type: str | None, *, is_seq: bool = False) -> str:
    base = jac_type(c_type, is_seq=is_seq)
    if base.endswith("| None"):
        return base
    return f"{base} | None"


def jac_list_elem_type(c_type: str | None) -> str:
    """Element type T for a grammar sequence typed as list[T] / asdl_*_seq*."""
    if c_type is None:
        return "object"
    if c_type.endswith("*") and c_type in JAC_TYPES:
        inner = JAC_TYPES[c_type]
        if not inner.startswith("list["):
            return inner
    jac = jac_type(c_type, is_seq=True)
    if jac.startswith("list[") and jac.endswith("]"):
        return jac[5:-1]
    single = jac_type(c_type, is_seq=False)
    if single.endswith(" | None"):
        single = single[: -len(" | None")]
    return single


RULE_JAC_RET_OVERRIDES: dict[str, str] = {
    "kwargs": "list[keyword_or_starred_node] | None",
    "double_starred_kvpairs": "list[kv_pair] | None",
    "open_sequence_pattern": "list[pattern] | None",
    "maybe_sequence_pattern": "list[pattern] | None",
    "items_pattern": "list[pattern] | None",
    "keyword_patterns": "list[pattern] | None",
}


SEQ_INSERT_HELPERS: dict[str, str] = {
    "expr": "pa_seq_insert_front_expr",
    "pattern": "pa_seq_insert_front_pattern",
    "stmt": "pa_seq_insert_front_stmt",
    "alias": "pa_seq_insert_front_alias",
    "type_param": "pa_seq_insert_front_type_param",
    "withitem": "pa_seq_insert_front_withitem",
    "arg": "pa_seq_insert_front_arg",
    "pa_keyword_or_starred": "pa_seq_insert_front_kw_or_starred",
    "keyword_or_starred_node": "pa_seq_insert_front_kw_or_starred",
    "kv_pair": "pa_seq_insert_front_kvpair",
    "kp_pair": "pa_seq_insert_front_kvpattern",
}


def _rule_fn(name: str) -> str:
    return f"rule_{name}"


class JacCallMakerVisitor(GrammarVisitor):
    def __init__(self, gen: "JacParserGenerator", exact_tokens: dict[str, int]) -> None:
        self.gen = gen
        self.exact_tokens = exact_tokens
        self.cache: dict[str, tuple[str, str]] = {}

    def visit_NameLeaf(self, node: NameLeaf) -> tuple[str | None, str]:
        name = node.value
        if name == "SOFT_KEYWORD":
            return "soft_kw", "peg_expect_soft_keyword(p, \"\")"
        if name in TOKEN_CALLS:
            var, call = TOKEN_CALLS[name]
            return var, call
        if name in ("NEWLINE", "DEDENT", "INDENT", "ENDMARKER"):
            return f"_{name.lower()}", f"peg_expect_token(p, {name})"
        if name in self.gen.tokens:
            return f"{name.lower()}_tok", f"peg_expect_token(p, {name})"
        return name, f"{_rule_fn(name)}(p)"

    def visit_StringLeaf(self, node: StringLeaf) -> tuple[str, str]:
        val = py_ast.literal_eval(node.value)
        if re.match(r"[a-zA-Z_]\w*\Z", val):
            if node.value.endswith("'"):
                kw = self.gen.keywords[val]
                return "kw", f"peg_expect_token(p, {kw})"
            return "soft", f"peg_expect_soft_keyword(p, {node.value})"
        tok = self.exact_tokens[val]
        return "lit", f"peg_expect_token(p, {tok})"

    def visit_NamedItem(self, node: NamedItem) -> tuple[str | None, str]:
        name, call = self.visit(node.item)
        if node.name:
            name = node.name
        return name, call

    def _lookahead_token_expr(self, node: Any) -> str | None:
        if isinstance(node, NameLeaf):
            name = node.value
            if name in TOKEN_CALLS:
                _, call = TOKEN_CALLS[name]
                return call
            if name in ("NEWLINE", "DEDENT", "INDENT", "ENDMARKER"):
                return f"peg_expect_token(p, {name})"
            if name in self.gen.tokens:
                return f"peg_expect_token(p, {name})"
            return None
        if isinstance(node, StringLeaf):
            _, inner = self.visit(node)
            if "peg_expect_token(p," in inner:
                tok = inner.split("peg_expect_token(p, ")[1].rstrip(")")
                return f"peg_expect_token(p, {tok})"
            return None
        if isinstance(node, Group):
            return self._lookahead_token_expr(node.rhs)
        if isinstance(node, Rhs):
            parts: list[str] = []
            for alt in node.alts:
                if len(alt.items) != 1:
                    return None
                part = self._lookahead_token_expr(alt.items[0].item)
                if part is None:
                    return None
                parts.append(part)
            if not parts:
                return None
            if len(parts) == 1:
                return parts[0]
            return "(" + " or ".join(parts) + ")"
        return None

    def visit_PositiveLookahead(self, node: PositiveLookahead) -> tuple[None, str]:
        token_expr = self._lookahead_token_expr(node.node)
        if token_expr is not None:
            if token_expr.startswith("(") and " or " in token_expr:
                parts = token_expr[1:-1].split(" or ")
                checks = [
                    "peg_positive_lookahead_token(p, "
                    + p.split("peg_expect_token(p, ")[1].rstrip(")")
                    + ")"
                    for p in parts
                ]
                return None, "(" + " or ".join(checks) + ")"
            tok = token_expr.split("peg_expect_token(p, ")[1].rstrip(")")
            return None, f"peg_positive_lookahead_token(p, {tok})"
        _, inner = self.visit(node.node)
        if "peg_expect_token(p," in inner:
            tok = inner.split("peg_expect_token(p, ")[1].rstrip(")")
            return None, f"peg_positive_lookahead_token(p, {tok})"
        return None, f"({inner} is not None)"

    def visit_NegativeLookahead(self, node: NegativeLookahead) -> tuple[None, str]:
        token_expr = self._lookahead_token_expr(node.node)
        if token_expr is not None:
            if token_expr.startswith("(") and " or " in token_expr:
                parts = token_expr[1:-1].split(" or ")
                checks = [
                    "peg_negative_lookahead_token(p, "
                    + p.split("peg_expect_token(p, ")[1].rstrip(")")
                    + ")"
                    for p in parts
                ]
                return None, "(" + " and ".join(checks) + ")"
            tok = token_expr.split("peg_expect_token(p, ")[1].rstrip(")")
            return None, f"peg_negative_lookahead_token(p, {tok})"
        _, inner = self.visit(node.node)
        if "peg_expect_token(p," in inner:
            tok = inner.split("peg_expect_token(p, ")[1].rstrip(")")
            return None, f"peg_negative_lookahead_token(p, {tok})"
        return None, f"({inner} is None)"

    def visit_Opt(self, node: Opt) -> tuple[str, str]:
        name, call = self.visit(node.node)
        return name or "opt", call

    def _artificial(
        self, node: Any, prefix: str, maker: Any, trailing_comma: bool = False
    ) -> tuple[str, str]:
        key = f"{prefix}_{node}"
        if key in self.cache:
            return self.cache[key]
        rule_name = maker()
        call = f"{_rule_fn(rule_name)}(p)" + ("," if trailing_comma else "")
        self.cache[key] = (rule_name, call)
        return rule_name, call

    def visit_Rhs(self, node: Rhs) -> tuple[str, str]:
        if len(node.alts) == 1 and len(node.alts[0].items) == 1:
            return self.visit(node.alts[0].items[0])
        _, call = self._artificial(node, "rhs", lambda: self.gen.artificial_rule_from_rhs(node))
        return "rhs", call

    def visit_Repeat0(self, node: Repeat0) -> tuple[str, str]:
        _, call = self._artificial(
            node,
            "repeat0",
            lambda: self.gen.artificial_rule_from_repeat(node.node, is_repeat1=False),
            trailing_comma=False,
        )
        return "seq", call

    def visit_Repeat1(self, node: Repeat1) -> tuple[str, str]:
        _, call = self._artificial(
            node,
            "repeat1",
            lambda: self.gen.artificial_rule_from_repeat(node.node, is_repeat1=True),
        )
        return "seq", call

    def visit_Gather(self, node: Gather) -> tuple[str, str]:
        _, call = self._artificial(
            node, "gather", lambda: self.gen.artificial_rule_from_gather(node)
        )
        return "gather", call

    def visit_Group(self, node: Group) -> tuple[str | None, str]:
        return self.visit(node.rhs)

    def visit_Cut(self, node: Cut) -> tuple[str, str]:
        return "cut", "True"

    def visit_Forced(self, node: Forced) -> tuple[str, str]:
        if isinstance(node.node, StringLeaf):
            val = py_ast.literal_eval(node.node.value)
            tok = self.exact_tokens[val]
            return (
                "forced",
                f"peg_expect_forced_token(p, {tok}, '{val}')",
            )
        if isinstance(node.node, Group):
            _, inner = self.visit(node.node.rhs)
            rhs_s = str(node.node.rhs).replace('"', '\\"')
            return (
                "forced",
                f'peg_expect_forced_result(p, {inner}, "{rhs_s}")',
            )
        raise NotImplementedError(f"forced node {node.node!r}")


class JacParserGenerator(ParserGenerator, GrammarVisitor):
    def __init__(
        self,
        grammar: Grammar,
        tokens: set[str],
        file: IO[str] | None,
        *,
        allowed_rules: set[str] | None = None,
    ) -> None:
        super().__init__(grammar, tokens, file)
        self.allowed_rules = allowed_rules
        self.exact_token_map: dict[str, int] = {}
        self.callmakervisitor = JacCallMakerVisitor(self, self.exact_token_map)
        self.action_translator = ActionTranslator()
        self.rule_ids: dict[str, int] = {}
        self._rule_name = ""
        self._rule_ret = "object | None"
        self._rule_memo = False
        self._alt_conflict_renames: list[dict[str, str]] = []
        self._alt_renames: dict[str, str] = {}
        self._alt_type_env: dict[str, str] = {}

    def set_exact_tokens(self, exact: dict[str, int]) -> None:
        self.exact_token_map = exact
        self.callmakervisitor.exact_tokens = exact

    def _item_element_c_type(self, item: Any) -> str | None:
        if isinstance(item, Rule):
            return item.type
        if isinstance(item, NameLeaf):
            if item.value == "NAME":
                return "expr_ty"
            ref = self.all_rules.get(item.value)
            if ref is not None:
                return ref.type or self._infer_artificial_rule_c_type(ref)
            return None
        if isinstance(item, Group):
            return self._infer_rhs_c_type(item.rhs)
        if isinstance(item, Rhs):
            return self._infer_rhs_c_type(item)
        return None

    def _rule_jac_ret(self, rule: Rule) -> str:
        if rule.name in RULE_JAC_RET_OVERRIDES:
            return RULE_JAC_RET_OVERRIDES[rule.name]
        if rule.type is not None:
            return jac_return_type(
                rule.type, is_seq=rule.is_loop() or rule.is_gather()
            )
        if rule.rhs.alts:
            alt_types = [self._alt_result_jac_type(alt) for alt in rule.rhs.alts]
            if alt_types and len(set(alt_types)) == 1 and alt_types[0] != "object | None":
                return alt_types[0]
        inferred = self._infer_artificial_rule_c_type(rule)
        if inferred is not None:
            return jac_return_type(
                inferred, is_seq=rule.is_loop() or rule.is_gather()
            )
        return "object | None"

    def _loop_element_jac_type(self, rule: Rule) -> str:
        if not rule.rhs.alts:
            return "object"
        alt = rule.rhs.alts[0]
        items = [item for item in alt.items if item.name == "elem"]
        if not items:
            items = list(alt.items)
        for item in items:
            _, call = self.callmakervisitor.visit(item)
            call = call.rstrip(",").strip()
            m = re.fullmatch(r"rule_(\w+)\(p\)", call)
            if m is not None:
                ref = self.all_rules.get(m.group(1))
                if ref is not None:
                    base = self._rule_jac_ret(ref).replace(" | None", "")
                    if base.startswith("list[") and base.endswith("]"):
                        inner = base[5:-1]
                        if inner and inner != "object":
                            return inner
                    elif base != "object":
                        return base
            if isinstance(item, NamedItem):
                cap = self._infer_capture_jac_type(item).replace(" | None", "")
                if cap and cap != "object" and not cap.startswith("list["):
                    return cap
        return "object"

    def _alt_result_jac_type(self, alt: Alt) -> str:
        if alt.action:
            action = " ".join(alt.action.split())
            if re.fullmatch(r"[A-Za-z_]\w*", action):
                for name, typ in self._alt_capture_types(alt):
                    if name == action:
                        return typ
            if re.search(
                r"_PyPegen_seq_insert_in_front|_PyPegen_seq_append_to_end", action
            ):
                for _name, typ in self._alt_capture_types(alt):
                    base = typ.replace(" | None", "")
                    if base not in ("object", "peg_token") and not base.startswith(
                        "list["
                    ):
                        return f"list[{base}] | None"
                return "list[expr] | None"
            return "object | None"
        captures = self._alt_capture_types(alt)
        semantic = [(n, t) for n, t in captures if not n.startswith("lit")]
        if len(semantic) > 1:
            return "object | None"
        if len(semantic) == 1:
            return semantic[0][1]
        if len(captures) == 1:
            return captures[0][1]
        elem = self._infer_alt_element_c_type(alt)
        if elem is not None:
            return jac_return_type(elem)
        return "object | None"

    def _infer_rhs_unified_jac_ret(
        self, rhs: Rhs, *, is_loop: bool, is_gather: bool
    ) -> str | None:
        if is_loop or is_gather:
            return None
        first_types: dict[str, str] = {}
        capture_conflict = False
        for alt in rhs.alts:
            for name, typ in self._alt_capture_types(alt):
                if name in first_types and first_types[name] != typ:
                    capture_conflict = True
                else:
                    first_types.setdefault(name, typ)
        if not capture_conflict:
            return None
        types = [self._alt_result_jac_type(alt) for alt in rhs.alts]
        if not types:
            return None
        if len(set(types)) == 1:
            return types[0]
        return "object | None"

    def _infer_rhs_c_type(self, rhs: Rhs) -> str | None:
        jac_types = [self._alt_result_jac_type(alt) for alt in rhs.alts]
        if jac_types and len(set(jac_types)) > 1:
            return None
        types: list[str] = []
        for alt in rhs.alts:
            got = self._infer_alt_element_c_type(alt)
            if got is not None:
                types.append(got)
        if not types:
            return None
        if len(set(types)) == 1:
            return types[0]
        # Alternatives that all lower to expr (e.g. slice | starred_expression).
        jac_types = {jac_list_elem_type(t) for t in types}
        if len(jac_types) == 1:
            only = next(iter(jac_types))
            if only == "expr":
                return "expr_ty"
        return None

    def _infer_alt_element_c_type(self, alt: Alt) -> str | None:
        if alt.action:
            return None
        for item in reversed(alt.items):
            if isinstance(item, NamedItem):
                got = self._item_element_c_type(item.item)
                if got is not None:
                    return got
        if alt.items:
            return self._item_element_c_type(alt.items[-1].item)
        return None

    def _elem_c_to_seq_c_type(self, elem_c: str | None) -> str | None:
        if elem_c is None:
            return "asdl_seq*"
        custom_seq = {
            "KeywordOrStarred*": "asdl_keyword_or_starred_seq*",
            "KeyValuePair*": "asdl_kvpair_seq*",
            "KeyPatternPair*": "asdl_kvpattern_seq*",
        }
        if elem_c in custom_seq:
            return custom_seq[elem_c]
        if elem_c.startswith("asdl_") and elem_c.endswith("_seq*"):
            return elem_c
        if elem_c.endswith("_ty"):
            return f"asdl_{elem_c[:-3]}_seq*"
        if elem_c.endswith("*") and elem_c in JAC_TYPES:
            inner = JAC_TYPES[elem_c]
            if inner.startswith("list["):
                return elem_c
            return elem_c
        return "asdl_seq*"

    def _infer_artificial_rule_c_type(self, rule: Rule) -> str | None:
        if rule.type is not None:
            return rule.type
        if not rule.rhs.alts:
            return None
        alt = rule.rhs.alts[0]
        if rule.name.startswith("_gather_"):
            for item in alt.items:
                if item.name == "elem":
                    elem_c = self._item_element_c_type(item.item)
                    return self._elem_c_to_seq_c_type(elem_c)
            return None
        if rule.name.startswith("_loop0_") or rule.name.startswith("_loop1_"):
            for item in alt.items:
                elem_c = self._item_element_c_type(item.item)
                if elem_c is not None:
                    return self._elem_c_to_seq_c_type(elem_c)
            return None
        if rule.name.startswith("_loop"):
            for item in alt.items:
                if item.name == "elem":
                    elem_c = self._item_element_c_type(item.item)
                    return self._elem_c_to_seq_c_type(elem_c)
            if len(alt.items) == 1:
                elem_c = self._item_element_c_type(alt.items[0].item)
                return self._elem_c_to_seq_c_type(elem_c)
        if rule.name.startswith("_tmp_"):
            return self._infer_rhs_c_type(rule.rhs)
        return None

    def _loop_element_capture_type(self, rule: Rule) -> str | None:
        if not rule.rhs.alts:
            return None
        alt = rule.rhs.alts[0]
        for item in alt.items:
            if isinstance(item, NamedItem):
                return self._infer_capture_jac_type(item)
        return None

    def _rule_list_elem_jac_type(self, rule: Rule) -> str:
        inferred = self._infer_artificial_rule_c_type(rule)
        c_type = inferred or rule.type
        return jac_list_elem_type(c_type)

    def _gather_elem_jac_type(self, rule: Rule) -> str:
        if not rule.rhs.alts:
            return "object"
        alt = rule.rhs.alts[0]
        for item in alt.items:
            if item.name == "elem":
                elem_c = self._item_element_c_type(item.item)
                if elem_c is not None and elem_c in JAC_TYPES:
                    inner = JAC_TYPES[elem_c]
                    if not inner.startswith("list["):
                        return inner
                if elem_c is not None and elem_c.endswith("_ty"):
                    return jac_type(elem_c, is_seq=False)
        return self._rule_list_elem_jac_type(rule)

    def _gather_return_type(self, rule: Rule) -> str:
        elem_jac = self._gather_elem_jac_type(rule)
        if elem_jac != "object":
            return f"list[{elem_jac}] | None"
        c_type = rule.type or self._infer_artificial_rule_c_type(rule)
        return jac_return_type(c_type, is_seq=True)

    def _seq_insert_helper(self, rule_name: str) -> str:
        elem = self._gather_elem_jac_type(self.all_rules[rule_name])
        return SEQ_INSERT_HELPERS.get(elem, "pa_seq_insert_front_expr")

    def _alt_capture_types(self, alt: Alt) -> list[tuple[str, str]]:
        captures: list[tuple[str, str]] = []
        for item in alt.items:
            self._collect_alt_capture_types(item, captures)
        return captures

    def _collect_alt_capture_types(self, item: NamedItem, captures: list[tuple[str, str]]) -> None:
        inner = item.item
        if isinstance(inner, Cut):
            return
        name, _ = self.callmakervisitor.visit(item)
        if not name or name == "cut":
            return
        captures.append((name, self._infer_capture_jac_type(item)))

    def _infer_capture_jac_type(self, item: NamedItem) -> str:
        _, call = self.callmakervisitor.visit(item)
        call = call.rstrip(",").strip()
        if call.startswith("pa_name_from_token("):
            return "Name | None"
        if call.startswith("pa_number_from_token("):
            return "expr | None"
        if call.startswith("peg_expect_token(") or call.startswith("peg_expect_soft_keyword("):
            return "peg_token | None"
        m = re.fullmatch(r"rule_(\w+)\(p\)", call)
        if m is not None:
            rule = self.all_rules.get(m.group(1))
            if rule is not None:
                return self._rule_jac_ret(rule)
        return "object | None"

    def _compute_alt_conflict_renames(self, rhs: Rhs) -> list[dict[str, str]]:
        first_types: dict[str, str] = {}
        per_alt: list[dict[str, str]] = []
        for alt_idx, alt in enumerate(rhs.alts, start=1):
            renames: dict[str, str] = {}
            for name, typ in self._alt_capture_types(alt):
                if name not in first_types:
                    first_types[name] = typ
                elif first_types[name] != typ:
                    renames[name] = f"{name}_{alt_idx}"
            per_alt.append(renames)
        return per_alt

    def _emit_capture_name(self, grammar_name: str) -> str:
        base = self._alt_renames.get(grammar_name, grammar_name)
        return self.dedupe(base)

    def _rewrite_action_names(self, action: str, renames: dict[str, str]) -> str:
        if not renames:
            return action
        out = action
        for old, new in sorted(renames.items(), key=lambda kv: -len(kv[0])):
            pattern = rf"(?<![.\w`]){re.escape(old)}(?![=\w`])"
            out = re.sub(pattern, new, out)
        return out

    def _needs_result_cast(self, local: str, ret: str) -> bool:
        if local == ret:
            return False
        local_base = local.replace(" | None", "")
        ret_base = ret.replace(" | None", "")
        if local_base == ret_base:
            return False
        if local_base == "object" or ret_base == "object":
            return True
        if local_base.startswith("list[object]") or ret_base.startswith("list[object]"):
            return True
        return local != ret

    def _format_action_result(self, action: str) -> str:
        action = self._rewrite_action_names(action, self._alt_renames)
        cast_ret = jac_cast_type(self._rule_ret)
        if re.fullmatch(r"[A-Za-z_]\w*", action.strip()):
            local = self._alt_type_env.get(action.strip())
            if local is not None and self._needs_result_cast(local, self._rule_ret):
                return f"{action} as {cast_ret}"
        return action

    def artificial_rule_from_rhs(self, rhs: Rhs) -> str:
        self.counter += 1
        name = f"_tmp_{self.counter}"
        inferred = self._infer_rhs_c_type(rhs)
        self.all_rules[name] = Rule(name, inferred, rhs)
        return name

    def artificial_rule_from_repeat(self, node: Plain, is_repeat1: bool) -> str:
        self.counter += 1
        prefix = "_loop1_" if is_repeat1 else "_loop0_"
        name = f"{prefix}{self.counter}"
        elem_c = self._item_element_c_type(node)
        seq_c = self._elem_c_to_seq_c_type(elem_c)
        self.all_rules[name] = Rule(name, seq_c, Rhs([Alt([NamedItem(None, node)])]))
        return name

    def artificial_rule_from_gather(self, node: Gather) -> str:
        self.counter += 1
        extra_function_name = f"_loop0_{self.counter}"
        extra_function_alt = Alt(
            [NamedItem(None, node.separator), NamedItem("elem", node.node)],
            action="elem",
        )
        elem_c = self._item_element_c_type(node.node)
        seq_c = self._elem_c_to_seq_c_type(elem_c)
        self.all_rules[extra_function_name] = Rule(
            extra_function_name,
            seq_c,
            Rhs([extra_function_alt]),
        )
        self.counter += 1
        name = f"_gather_{self.counter}"
        alt = Alt(
            [NamedItem("elem", node.node), NamedItem("seq", NameLeaf(extra_function_name))],
        )
        self.all_rules[name] = Rule(name, seq_c, Rhs([alt]))
        return name

    def collect_rules(self) -> None:
        """Collect artificial rules in stable order for deterministic output."""
        keyword_collector = KeywordCollectorVisitor(
            self, self.keywords, self.soft_keywords
        )
        for rule in sorted(self.all_rules.values(), key=lambda r: r.name):
            keyword_collector.visit(rule)

        rule_collector = RuleCollectorVisitor(self.rules, self.callmakervisitor)
        done: set[str] = set()
        while True:
            todo = sorted(n for n in self.all_rules if n not in done)
            if not todo:
                break
            done = set(self.all_rules)
            for rulename in todo:
                rule_collector.visit(self.all_rules[rulename])

    def generate(self, filename: str) -> None:
        self.collect_rules()
        rules_to_emit = sorted(
            (r for r in self.all_rules.values() if self._emit_rule(r.name)),
            key=lambda r: r.name,
        )
        for i, rule in enumerate(rules_to_emit):
            self.rule_ids[rule.name] = i
        self._emit_header(filename)
        self._emit_rule_constants(rules_to_emit)
        for rule in rules_to_emit:
            self.visit(rule)
        self._emit_keywords()
        self._emit_entry_points()

    def _emit_rule(self, name: str) -> bool:
        # Artificial helpers (_loop*, _gather*, _tmp*) are created during
        # collect_rules() and must always be emitted (cpython pegen does the same).
        if name.startswith("_"):
            return True
        if self.allowed_rules is None:
            return True
        return name in self.allowed_rules

    def _emit_header(self, filename: str) -> None:
        base = os.path.basename(filename)
        self.print('"""jacpython generated PEG parser (unified eval + file profile).')
        self.print("")
        self.print(
            f"GENERATED by jac-py/tools/grammar2jac.py from {GRAMMAR_PROVENANCE}"
        )
        self.print(f"(starts: eval, file; source tag: {base}). Do not edit by hand.")
        self.print('"""')
        self.print("")
        self.print("import from token_model {")
        self.print(
            "    ENDMARKER, NAME, NUMBER, STRING, OP, NT_OFFSET, NEWLINE, TYPE_COMMENT,"
        )
        self.print(
            "    INDENT, DEDENT, FSTRING_START, FSTRING_MIDDLE, FSTRING_END,"
        )
        self.print(
            "    TSTRING_START, TSTRING_MIDDLE, TSTRING_END,"
        )
        self.print("}")
        self.print("import from peg_runtime {")
        self.print("    peg_parser, peg_parser_from_source, peg_set_keywords,")
        self.print("    peg_set_soft_keywords, peg_keyword_entry, peg_mark, peg_reset,")
        self.print("    peg_check_memo, peg_insert_memo, peg_update_memo,")
        self.print("    peg_expect_token, peg_expect_soft_keyword, peg_expect_forced_token,")
        self.print("    peg_expect_forced_result, peg_has_error, peg_fill_token,")
        self.print("    peg_get_last_nonnwhitespace_token,")
        self.print("    peg_positive_lookahead_token, peg_negative_lookahead_token,")
        self.print("    peg_left_rec_finish, peg_token,")
        self.print("}")
        self.print("import from parser_actions {")
        self.print("    kv_pair, kp_pair, keyword_or_starred_node, name_default_pair,")
        self.print("    pa_cmpop_expr_pair, pa_key_value_pair, pa_key_pattern_pair, pa_keyword_or_starred,")
        self.print("    pa_name_default_pair, pa_make_cmpop_pair, pa_name_from_token, pa_name_id, pa_number_from_token,")
        self.print("    pa_ast_expression, pa_ast_binop, pa_ast_unaryop, pa_ast_boolop, pa_ast_compare, pa_ast_call,")
        self.print("    pa_ast_ifexp, pa_constant_bool, pa_constant_none, pa_constant_from_expr, pa_match_singleton, pa_pattern_list, pa_singleton_seq, pa_singleton_seq_expr, pa_singleton_seq_stmt, pa_singleton_seq_alias, pa_stmt_list_or_empty,")
        self.print("    pa_seq_insert_front_expr, pa_seq_insert_front_pattern, pa_seq_insert_front_stmt,")
        self.print("    pa_seq_insert_front_alias, pa_seq_insert_front_type_param, pa_seq_insert_front_withitem,")
        self.print("    pa_seq_insert_front_arg, pa_seq_insert_front_kw_or_starred, pa_seq_insert_front_kvpair,")
        self.print("    pa_seq_insert_front_kvpattern, pa_seq_insert_front, pa_seq_append_to_end, pa_seq_append_to_end_expr, pa_seq_append_to_end_stmt, pa_get_cmpops, pa_get_exprs, pa_get_keys, pa_get_values,")
        self.print("    pa_get_patterns, pa_get_pattern_keys, pa_collect_call_seqs, pa_call_from_optional_args,")
        self.print("    pa_ast_starred, pa_check, pa_make_module, pa_seq_flatten, pa_set_context, pa_map_names_to_ids,")
        self.print("    pa_ast_expr_stmt, pa_ast_assign, pa_ast_annassign, pa_ast_return, pa_ast_pass, pa_ast_break,")
        self.print("    pa_ast_continue, pa_ast_tuple, pa_ast_attribute, pa_ast_subscript, pa_ast_slice, pa_ast_augassign,")
        self.print("    pa_ast_delete, pa_raise_syntax, pa_raise_syntax_known_expr, pa_raise_syntax_known_range,")
        self.print("    pa_raise_invalid_target, pa_aug_op, pa_call_args, pa_call_keywords, pa_comp_field,")
        self.print("    pa_empty_arguments, pa_dummy_name, pa_interactive_exit, pa_seq_count_dots, pa_seq_first,")
        self.print("    pa_seq_last, pa_seq_len, pa_seq_get, pa_or_pattern_singleton, pa_check_legacy_stmt_or_raise,")
        self.print("    pa_raise_type_param_error, pa_raise_kvpair_error, pa_checked_future_import, pa_nonparen_genexp_in_call,")
        self.print("    pa_arguments_parsing_error, pa_check_legacy_stmt, pa_concatenate_strings, pa_concatenate_tstrings,")
        self.print("    pa_constant_from_string, pa_constant_from_token, pa_decoded_constant_from_token, pa_ensure_imaginary,")
        self.print("    pa_ensure_real, pa_get_expr_name, pa_get_last_comprehension_item, pa_join_names_with_dot,")
        self.print("    pa_join_sequences, pa_join_sequences_kw_or_starred, pa_alias_for_star, pa_add_type_comment_to_arg, pa_seq_delete_starred_exprs,")
        self.print("    pa_seq_extract_starred_exprs, pa_setup_full_format_spec, pa_check_fstring_conversion,")
        self.print("    pa_function_def_decorators, pa_class_def_decorators, pa_make_arguments, pa_star_etc, pa_slash_with_default,")
        self.print("    pa_joined_str, pa_template_str, pa_formatted_value, pa_interpolation, pa_err_occurred,")
        self.print("    pa_expr_lineno, pa_expr_end_col_offset, pa_expr_end_lineno,")
        self.print("}")
        self.print("import from ast_nodes {")
        self.print("    ast_node, expr, mod, stmt, pattern, operator, cmpop, expr_context,")
        self.print("    arguments, alias, arg, keyword, comprehension, excepthandler, match_case, type_param, withitem,")
        self.print("    Expression, Interactive, FunctionType, Module, Name, Load, Store, Del,")
        self.print("    Assign, AnnAssign, AugAssign, Expr, Return, Pass, Break, Continue, Delete, Raise,")
        self.print("    Import, ImportFrom, Global, Nonlocal, Assert, If, For, AsyncFor, While, With, AsyncWith,")
        self.print("    FunctionDef, AsyncFunctionDef, ClassDef, Try, TryStar, ExceptHandler, Match, TypeAlias,")
        self.print("    Attribute, Subscript, Slice, Tuple, List, Dict, Set, Starred, NamedExpr, Lambda,")
        self.print("    BinOp, UnaryOp, BoolOp, Compare, Call, IfExp, Await, Yield, YieldFrom,")
        self.print("    ListComp, SetComp, DictComp, GeneratorExp, Constant, JoinedStr, TemplateStr,")
        self.print("    FormattedValue, Interpolation, MatchAs, MatchOr, MatchSequence, MatchMapping, MatchClass,")
        self.print("    MatchStar, MatchSingleton, MatchValue,")
        self.print("    Add, Sub, Mult, Div, FloorDiv, Mod, MatMult, Pow, LShift, RShift, BitOr, BitXor, BitAnd,")
        self.print("    USub, UAdd, Not, Invert, Or, And, Lt, LtE, Gt, GtE, Eq, NotEq, In, IsNot, Is, NotIn,")
        self.print("    TypeVar, TypeVarTuple, ParamSpec,")
        self.print("}")
        self.print("")

    def _emit_rule_constants(self, rules: Sequence[Rule]) -> None:
        parts = [f"RULE_{r.name}: int = NT_OFFSET + {i}" for i, r in enumerate(rules)]
        self.print("glob " + parts[0] + ",")
        for part in parts[1:-1]:
            self.print(f"     {part},")
        if len(parts) > 1:
            self.print(f"     {parts[-1]};")
        else:
            self.print(";")
        self.print("")

    def _emit_keywords(self) -> None:
        self.print("def _build_keyword_lists() -> list[list[peg_keyword_entry]] {")
        with self.indent():
            max_len = 0
            for spelling in self.keywords:
                max_len = max(max_len, len(spelling))
            self.print(f"lists: list[list[peg_keyword_entry]] = [];")
            self.print(f"i = 0;")
            self.print(f"while i <= {max_len} {{")
            with self.indent():
                self.print("lists.append([]);")
                self.print("i = i + 1;")
            self.print("}")
            for spelling, tok_id in sorted(self.keywords.items(), key=lambda x: len(x[0])):
                self.print(
                    f'lists[{len(spelling)}].append(peg_keyword_entry(spelling="{spelling}", tok_type={tok_id}));'
                )
            self.print("return lists;")
        self.print("}")
        soft = sorted(self.soft_keywords)
        soft_quoted = ", ".join(f'"{s}"' for s in soft)
        self.print(f"glob SOFT_KEYWORDS: list[str] = [{soft_quoted}];")
        self.print("")

    def _emit_entry_points(self) -> None:
        self.print("def parse_eval_module(p: peg_parser) -> mod | None {")
        with self.indent():
            self.print("res = rule_eval(p);")
            self.print("if res is None {")
            with self.indent():
                self.print("return None;")
            self.print("}")
            self.print("if peg_expect_token(p, ENDMARKER) is None {")
            with self.indent():
                self.print("return None;")
            self.print("}")
            self.print("return res;")
        self.print("}")
        self.print("")
        self.print("def parse_eval_source(source: str, filename: str) -> mod | None {")
        with self.indent():
            self.print("p = peg_parser_from_source(source, filename, True);")
            self.print("peg_set_keywords(p, _build_keyword_lists());")
            self.print("peg_set_soft_keywords(p, SOFT_KEYWORDS);")
            self.print("return parse_eval_module(p);")
        self.print("}")
        self.print("")
        self.print("def parse_eval_expr(source: str, filename: str) -> expr | None {")
        with self.indent():
            self.print("mod = parse_eval_source(source, filename);")
            self.print("if mod is None {")
            with self.indent():
                self.print("return None;")
            self.print("}")
            self.print("if isinstance(mod, Expression) {")
            with self.indent():
                self.print("return (mod as Expression).body;")
            self.print("}")
            self.print("return None;")
        self.print("}")
        self.print("")
        self.print("def parse_file_module(p: peg_parser) -> mod | None {")
        with self.indent():
            self.print("res = rule_file(p);")
            self.print("if res is None {")
            with self.indent():
                self.print("return None;")
            self.print("}")
            self.print("if peg_expect_token(p, ENDMARKER) is None {")
            with self.indent():
                self.print("return None;")
            self.print("}")
            self.print("return res;")
        self.print("}")
        self.print("")
        self.print("def parse_file_source(source: str, filename: str) -> mod | None {")
        with self.indent():
            self.print("p = peg_parser_from_source(source, filename, True);")
            self.print("peg_set_keywords(p, _build_keyword_lists());")
            self.print("peg_set_soft_keywords(p, SOFT_KEYWORDS);")
            self.print("return parse_file_module(p);")
        self.print("}")
        self.print("")
        self.print("def parse_file(source: str, filename: str) -> Module | None {")
        with self.indent():
            self.print("mod = parse_file_source(source, filename);")
            self.print("if mod is None {")
            with self.indent():
                self.print("return None;")
            self.print("}")
            self.print("if isinstance(mod, Module) {")
            with self.indent():
                self.print("return mod as Module;")
            self.print("}")
            self.print("return None;")
        self.print("}")

    def _alt_starts_with_rule(self, alt: Alt, rule_name: str) -> bool:
        if not alt.items:
            return False
        item = alt.items[0].item
        if isinstance(item, Rule):
            return item.name == rule_name
        if isinstance(item, NameLeaf):
            return item.value == rule_name
        return False

    def _function_def_raw_rhs(self, rhs: Rhs) -> Rhs:
        invalid: list[Alt] = []
        rest: list[Alt] = []
        for alt in rhs.alts:
            if self._alt_starts_with_rule(alt, "invalid_def_raw"):
                invalid.append(alt)
            else:
                rest.append(alt)
        return Rhs(alts=rest + invalid)

    def visit_Rule(self, node: Rule) -> None:
        is_loop = node.is_loop()
        is_gather = node.is_gather()
        rhs = node.flatten()
        if node.name == "function_def_raw":
            rhs = self._function_def_raw_rhs(rhs)
        inferred = self._infer_artificial_rule_c_type(node)
        if node.name.startswith("_loop"):
            loop_elem = self._loop_element_jac_type(node)
            if loop_elem != "object":
                ret = f"list[{loop_elem}] | None"
            elif inferred:
                ret = jac_return_type(inferred, is_seq=is_loop or is_gather)
            else:
                ret = "list[object] | None"
        elif is_gather and not node.name.startswith("_loop"):
            ret = self._gather_return_type(node)
        elif node.name in RULE_JAC_RET_OVERRIDES:
            ret = RULE_JAC_RET_OVERRIDES[node.name]
        elif node.type == "asdl_seq*":
            elem_c = self._infer_rhs_c_type(rhs) or self._infer_artificial_rule_c_type(
                node
            )
            ret = jac_return_type(
                self._elem_c_to_seq_c_type(elem_c) if elem_c else node.type,
                is_seq=True,
            )
        else:
            if node.name.startswith("_tmp_"):
                alt_types = [self._alt_result_jac_type(alt) for alt in rhs.alts]
                if alt_types and len(set(alt_types)) == 1:
                    ret = alt_types[0]
                elif alt_types and len(set(alt_types)) > 1:
                    ret = "object | None"
                else:
                    ret = jac_return_type(
                        inferred or node.type, is_seq=is_loop or is_gather
                    )
            elif node.type is not None:
                ret = jac_return_type(
                    node.type, is_seq=is_loop or is_gather
                )
            else:
                unified = self._infer_rhs_unified_jac_ret(
                    rhs, is_loop=is_loop, is_gather=is_gather
                )
                if unified is not None:
                    ret = unified
                else:
                    ret = jac_return_type(
                        inferred or node.type, is_seq=is_loop or is_gather
                    )
        if (
            node.name.startswith("_loop")
            and ret == "list[object] | None"
        ):
            cap = self._loop_element_capture_type(node)
            if cap is not None:
                cap_base = cap.replace(" | None", "")
                if cap_base and cap_base != "object" and not cap_base.startswith(
                    "list["
                ):
                    ret = f"list[{cap_base}] | None"
        rule_id = self.rule_ids[node.name]
        if node.left_recursive and node.leader:
            self._emit_left_rec_leader(node, rhs, ret, rule_id)
            return
        if node.left_recursive:
            self.print(f"def {_rule_fn(node.name)}(p: peg_parser) -> {ret} {{")
            with self.indent():
                self.print(f"return {_rule_fn(node.name)}_raw(p);")
            self.print("}")
            self.print("")
            self._emit_left_rec_raw(node, rhs, ret)
            return
        memo = node.memo and not node.left_recursive
        self.print(f"def {_rule_fn(node.name)}(p: peg_parser) -> {ret} {{")
        with self.indent():
            if memo:
                self.print(f"hit = peg_check_memo(p, RULE_{node.name});")
                self.print("if hit.hit {")
                with self.indent():
                    self.print(f"return hit.result as {jac_cast_type(ret)};")
                self.print("}")
            self.print("mark = peg_mark(p);")
            if self._uses_extra(rhs):
                self.print("start_lineno = 1;")
                self.print("start_col_offset = 0;")
                self.print("end_lineno = 1;")
                self.print("end_col_offset = 0;")
                self.print("if peg_fill_token(p) {")
                with self.indent():
                    self.print("t0 = p.tokens[p.mark];")
                    self.print("start_lineno = t0.lineno;")
                    self.print("start_col_offset = t0.col_offset;")
                self.print("}")
            if is_loop:
                loop_cap = self._loop_element_capture_type(node)
                loop_cap_base = (
                    loop_cap.replace(" | None", "") if loop_cap is not None else ""
                )
                loop_elem = jac_cast_type(ret)
                if loop_elem.startswith("list[") and loop_elem.endswith("]"):
                    loop_elem = loop_elem[5:-1]
                if loop_cap_base.startswith("list["):
                    self._loop_elem_jac = loop_elem
                    self.print("children: list[object] = [];")
                else:
                    self._loop_elem_jac = loop_elem
                    self.print(f"children: list[{loop_elem}] = [];")
            else:
                self.print(f"res: {ret} = None;")
            self._alt_conflict_renames = self._compute_alt_conflict_renames(rhs)
            self._rule_name = node.name
            self._rule_ret = ret
            self._rule_memo = memo
            self.visit(rhs, is_loop=is_loop, is_gather=is_gather)
            if is_loop:
                if node.name.startswith("_loop1"):
                    self.print("if len(children) == 0 {")
                    with self.indent():
                        self.print("return None;")
                    self.print("}")
                cast_ty = jac_cast_type(ret)
                self.print(f"return children as {cast_ty};")
            else:
                if memo:
                    self.print(f"peg_insert_memo(p, mark, RULE_{node.name}, None);")
                self.print("return None;")
        self.print("}")
        self.print("")

    def _emit_left_rec_leader(self, node: Rule, rhs: Rhs, ret: str, rule_id: int) -> None:
        self.print(f"def {_rule_fn(node.name)}(p: peg_parser) -> {ret} {{")
        with self.indent():
            self.print(f"hit = peg_check_memo(p, RULE_{node.name});")
            self.print("if hit.hit {")
            with self.indent():
                self.print(f"return hit.result as {ret};")
            self.print("}")
            self.print("mark = peg_mark(p);")
            self.print(f"res: {ret} = None;")
            self.print("resmark = mark;")
            self.print("while True {")
            with self.indent():
                self.print(f"peg_update_memo(p, mark, RULE_{node.name}, res);")
                self.print("peg_reset(p, mark);")
                self.print(f"raw = {_rule_fn(node.name)}_raw(p);")
                self.print("if peg_has_error(p) {")
                with self.indent():
                    self.print("return None;")
                self.print("}")
                self.print("if raw is None or peg_mark(p) <= resmark {")
                with self.indent():
                    self.print("break;")
                self.print("}")
                self.print("resmark = peg_mark(p);")
                self.print("res = raw;")
            self.print("}")
            self.print(f"return peg_left_rec_finish(p, resmark, res) as {jac_cast_type(ret)};")
        self.print("}")
        self.print("")
        self._emit_left_rec_raw(node, rhs, ret)

    def _emit_left_rec_raw(self, node: Rule, rhs: Rhs, ret: str) -> None:
        self.print(f"def {_rule_fn(node.name)}_raw(p: peg_parser) -> {ret} {{")
        with self.indent():
            self._rule_name = node.name
            self._rule_memo = False
            self.print("mark = peg_mark(p);")
            if self._uses_extra(rhs):
                # Mirror pegen: the raw body of a left-recursive leader still
                # extracts start metadata from the first token. The caller's
                # loop resets p.mark to the rule entry before each attempt,
                # so tokens[p.mark] is the first token of the full chain
                # (e.g. 'self' in self.a.b), matching CPython positions.
                self.print("start_lineno = 1;")
                self.print("start_col_offset = 0;")
                self.print("end_lineno = 1;")
                self.print("end_col_offset = 0;")
                self.print("if peg_fill_token(p) {")
                with self.indent():
                    self.print("t0 = p.tokens[p.mark];")
                    self.print("start_lineno = t0.lineno;")
                    self.print("start_col_offset = t0.col_offset;")
                self.print("}")
            self.print(f"res: {ret} = None;")
            self._alt_conflict_renames = self._compute_alt_conflict_renames(rhs)
            self._rule_ret = ret
            self.visit(rhs, is_loop=False, is_gather=False)
            self.print("return None;")
        self.print("}")
        self.print("")

    def _uses_extra(self, rhs: Rhs) -> bool:
        # Actions that emit start_lineno/col_offset/end_* via action_translate LOC.
        loc_actions = (
            "_PyPegen_dummy_name",
            "_PyPegen_collect_call_seqs",
            "_PyPegen_key_value_pair",
            "_PyPegen_key_pattern_pair",
            "_PyPegen_name_default_pair",
            "_PyPegen_keyword_or_starred",
            "_PyPegen_make_arguments",
            "_PyPegen_star_etc",
            "_PyPegen_slash_with_default",
            "_PyPegen_joined_str",
            "_PyPegen_template_str",
            "_PyPegen_formatted_value",
            "_PyPegen_interpolation",
            "_PyAST_Call",
            "_PyAST_Constant",
            "_PyAST_AnnAssign",
            "_PyAST_Pass",
            "_PyAST_Break",
            "_PyAST_Continue",
            "_PyAST_Return",
            "_PyAST_Tuple",
            "_PyAST_Attribute",
            "_PyAST_Subscript",
            "_PyAST_Slice",
            "_PyAST_AugAssign",
            "_PyAST_Delete",
        )
        for alt in rhs.alts:
            if alt.action and (
                "EXTRA" in alt.action
                or any(marker in alt.action for marker in loc_actions)
            ):
                return True
        return False

    def visit_Rhs(
        self,
        node: Rhs,
        *,
        is_loop: bool = False,
        is_gather: bool = False,
    ) -> None:
        for alt_idx, alt in enumerate(node.alts, start=1):
            self._alt_renames = (
                self._alt_conflict_renames[alt_idx - 1]
                if self._alt_conflict_renames
                else {}
            )
            self._alt_type_env = {}
            self.visit(alt, is_loop=is_loop, is_gather=is_gather)
            if not is_loop:
                self.print("peg_reset(p, mark);")

    def visit_Alt(self, node: Alt, is_loop: bool = False, is_gather: bool = False) -> None:
        if is_loop:
            self._alt_type_env = {}
            self._alt_renames = (
                self._alt_conflict_renames[0] if self._alt_conflict_renames else {}
            )
            self._visit_alt_loop(node, is_gather)
            return
        has_cut = any(isinstance(i.item, Cut) for i in node.items)
        with self.local_variable_context():
            self._emit_alt_body_nested(node.items, 0, node, is_gather, has_cut)

    def _wrap_rule_call(self, call: str) -> str:
        call_clean = call.rstrip(",").strip()
        m = re.fullmatch(r"rule_(\w+)\(p\)", call_clean)
        if m is None:
            return call
        rule_name = m.group(1)
        if rule_name not in RULE_JAC_RET_OVERRIDES:
            return call
        ret = RULE_JAC_RET_OVERRIDES[rule_name]
        if ret.startswith("list[pattern]"):
            return f"pa_pattern_list({call_clean})"
        return call

    def _emit_alt_body_nested(
        self,
        items: list,
        idx: int,
        node: Alt,
        is_gather: bool,
        has_cut: bool,
    ) -> None:
        if idx >= len(items):
            if node.action and "EXTRA" in node.action:
                # Mirror pegen's _set_up_token_end_metadata_extraction: the end
                # position comes from the last non-whitespace token (NEWLINE,
                # INDENT, DEDENT, NL and COMMENT carry no usable positions).
                self.print("end_tok = peg_get_last_nonnwhitespace_token(p);")
                self.print("if end_tok is None {")
                self.print("    p.error_indicator = True;")
                self.print("    peg_reset(p, mark);")
                self.print("    return None;")
                self.print("}")
                self.print("end_lineno = end_tok.end_lineno;")
                self.print("end_col_offset = end_tok.end_col_offset;")
            action = self._emit_action(node, is_gather)
            self.print(f"res = {self._format_action_result(action)};")
            if self._rule_memo:
                self.print(f"peg_insert_memo(p, mark, RULE_{self._rule_name}, res);")
            cast_ret = jac_cast_type(self._rule_ret)
            if self._rule_name in RULE_JAC_RET_OVERRIDES:
                self.print(f"return res as {cast_ret};")
            else:
                self.print("return res;")
            return
        item = items[idx]
        if isinstance(item.item, Cut):
            self.print("cut = True;")
            self._emit_alt_body_nested(items, idx + 1, node, is_gather, has_cut)
            return
        if isinstance(item.item, Opt):
            name, call = self.callmakervisitor.visit(item)
            v = self._emit_capture_name(name if name else "opt")
            if name:
                self._alt_type_env[name] = self._infer_capture_jac_type(item)
            call_clean = call[:-1] if call.endswith(",") else call
            call_clean = self._wrap_rule_call(call_clean)
            self.print(f"{v} = {call_clean};")
            self._emit_alt_body_nested(items, idx + 1, node, is_gather, has_cut)
            return
        name, call = self.callmakervisitor.visit(item)
        if name == "cut":
            self._emit_alt_body_nested(items, idx + 1, node, is_gather, has_cut)
            return
        if name:
            v = self._emit_capture_name(name)
            self._alt_type_env[name] = self._infer_capture_jac_type(item)
            call_clean = call[:-1] if call.endswith(",") else call
            call_clean = self._wrap_rule_call(call_clean)
            self.print(f"{v} = {call_clean};")
            self.print(f"if {v} is not None {{")
            with self.indent():
                self._emit_alt_body_nested(items, idx + 1, node, is_gather, has_cut)
            self.print("}")
            return
        self.print(f"if ({call}) {{")
        with self.indent():
            self._emit_alt_body_nested(items, idx + 1, node, is_gather, has_cut)
        self.print("}")

    def _visit_alt_loop(self, node: Alt, is_gather: bool) -> None:
        has_cut = any(isinstance(i.item, Cut) for i in node.items)
        if has_cut:
            self.print("cut = False;")
        self.print("while True {")
        with self.indent():
            self.print("comma_mark = peg_mark(p);")
            with self.local_variable_context():
                self._emit_loop_body_nested(node.items, 0, node, is_gather, has_cut)
        self.print("}")

    def _emit_loop_body_nested(
        self,
        items: list,
        idx: int,
        node: Alt,
        is_gather: bool,
        has_cut: bool,
    ) -> None:
        if idx >= len(items):
            if node.action and "EXTRA" in node.action:
                # Same pegen parity as _emit_alt_body_nested above.
                self.print("end_tok = peg_get_last_nonnwhitespace_token(p);")
                self.print("if end_tok is None {")
                self.print("    p.error_indicator = True;")
                self.print("    return None;")
                self.print("}")
                self.print("end_lineno = end_tok.end_lineno;")
                self.print("end_col_offset = end_tok.end_col_offset;")
            action = self._emit_action(node, is_gather)
            loop_elem = getattr(self, "_loop_elem_jac", None)
            if (
                loop_elem
                and loop_elem != "object"
                and re.fullmatch(r"[A-Za-z_]\w*", action.strip())
            ):
                action = f"{action} as {loop_elem}"
            self.print(f"children.append({action});")
            self.print("mark = peg_mark(p);")
            return
        item = items[idx]
        if isinstance(item.item, Cut):
            self.print("cut = True;")
            self._emit_loop_body_nested(items, idx + 1, node, is_gather, has_cut)
            return
        name, call = self.callmakervisitor.visit(item)
        if name == "cut":
            self._emit_loop_body_nested(items, idx + 1, node, is_gather, has_cut)
            return
        if name:
            v = self._emit_capture_name(name)
            self._alt_type_env[name] = self._infer_capture_jac_type(item)
            call_clean = call[:-1] if call.endswith(",") else call
            self.print(f"{v} = {call_clean};")
            self.print(f"if {v} is None {{")
            with self.indent():
                if idx > 0:
                    self.print("peg_reset(p, comma_mark);")
                self.print("break;")
            self.print("}")
            self._emit_loop_body_nested(items, idx + 1, node, is_gather, has_cut)
            return
        self.print(f"if not ({call}) {{")
        with self.indent():
            if idx > 0:
                self.print("peg_reset(p, comma_mark);")
            self.print("break;")
        self.print("}")
        self._emit_loop_body_nested(items, idx + 1, node, is_gather, has_cut)

    def _emit_action(self, node: Alt, is_gather: bool) -> str:
        if node.action:
            try:
                return _escape_jac_kwargs(
                    self.action_translator.translate(
                        node.action, type_env=self._alt_type_env
                    )
                )
            except ActionTranslationError as err:
                raise ActionTranslationError(f"in alt {node!s}: {err}") from err
        names = list(self.local_variable_names)
        if is_gather:
            helper = self._seq_insert_helper(self._rule_name)
            cast_ty = jac_cast_type(self._rule_ret)
            elem_ty = self._gather_elem_jac_type(self.all_rules[self._rule_name])
            head = names[0]
            if elem_ty != "object":
                head = f"{head} as {elem_ty}"
            return f"{helper}({head}, {names[1]}) as {cast_ty}"
        # Trailing peg_expect_token captures (lit, lit_1, ...) are not semantic
        # values; match CPython gather/repeat element actions that return only z.
        semantic = [n for n in names if not n.startswith("lit")]
        if len(semantic) == 1:
            return semantic[0]
        if len(names) == 1:
            return names[0]
        return f"[{', '.join(names)}]"


# Jac reserved identifiers that collide with AST constructor kwarg names
# (e.g. Assert(test=...), If(test=...)). Mirrors jaclang's RESERVED_IDENT_NAMES
# (jac/jaclang/jac0core/constant.jac TOKEN_MAP values minus the escaped-type
# names float/int/str/bool/self). Emitted kwargs for these get backtick-escaped
# so regenerated parser.jac compiles without a hand post-pass.
_JAC_RESERVED_IDENTS = frozenset(
    {
        "None", "True", "abst", "and", "any", "as", "assert", "async", "await",
        "awaiting", "break", "by", "bytes", "can", "case", "class", "continue",
        "def", "default", "del", "dict", "disengage", "edge", "elif", "else",
        "entry", "enum", "except", "exit", "finally", "flow", "for", "forever",
        "from", "glob", "has", "here", "if", "impl", "import", "in", "include",
        "init", "is", "lambda", "list", "match", "node", "not", "obj",
        "override", "postinit", "priv", "props", "protect", "pub", "raise",
        "report", "return", "root", "sem", "set", "skip", "spawn", "static",
        "super", "switch", "test", "try", "tuple", "type", "visit", "visitor",
        "wait", "walker", "while", "with", "yield",
    }
)
_KWARG_RE = re.compile(r"(?<![\w`=!<>+\-*/%&|^~])([A-Za-z_][A-Za-z0-9_]*)(=(?!=))")


def _escape_jac_kwargs(action: str) -> str:
    return _KWARG_RE.sub(
        lambda m: f"`{m.group(1)}{m.group(2)}"
        if m.group(1) in _JAC_RESERVED_IDENTS
        else m.group(0),
        action,
    )


def load_token_sets() -> tuple[set[str], dict[str, int]]:
    with open(TOKENS_PATH) as fh:
        _, exact, non_exact = generate_token_definitions(fh)
    tokens = set(non_exact) | set(exact.keys())
    return tokens, exact


def _reorder_simple_stmt(rule: Rule) -> Rule:
    # type_alias before del_stmt and star_expressions: otherwise `type X = int`
    # is misparsed as an expression statement.
    order = (
        "assignment",
        "return_stmt",
        "pass_stmt",
        "type_alias",
        "del_stmt",
        "star_expressions",
    )
    buckets: dict[str, list[Alt]] = {name: [] for name in order}
    other: list[Alt] = []
    for alt in rule.rhs.alts:
        refs = _refs_in_node(alt)
        placed = False
        for name in order:
            if name in refs:
                buckets[name].append(alt)
                placed = True
                break
        if not placed:
            other.append(alt)
    kept: list[Alt] = []
    for name in order:
        kept.extend(buckets[name])
    kept.extend(other)
    return Rule(rule.name, rule.type, Rhs(kept), rule.memo)


def prepare_grammar(grammar: Grammar) -> Grammar:
    rules = dict(grammar.rules)
    if "simple_stmt" in rules:
        rules["simple_stmt"] = _reorder_simple_stmt(rules["simple_stmt"])
    return Grammar(rules.values(), grammar.metas.items())


def generate_text() -> str:
    grammar, _, _ = build_parser(GRAMMAR_PATH)
    grammar = prepare_grammar(grammar)
    tokens, exact = load_token_sets()
    buf = StringIO()
    gen = JacParserGenerator(grammar, tokens, buf, allowed_rules=None)
    gen.set_exact_tokens(exact)
    gen.generate(OUT_PATH)
    return _patch_parser_rules(buf.getvalue())


def _patch_patterns_rule(source: str) -> str:
    """open_sequence_pattern must be null-checked before pa_pattern_list.

    pa_pattern_list(None) returns [] which is truthy for `is not None`, so
    inlining pa_pattern_list(rule_open_sequence_pattern(p)) breaks the
    patterns-rule fallback to rule_pattern.
    """
    old = (
        "    patterns = pa_pattern_list(rule_open_sequence_pattern(p));\n"
        "    if patterns is not None {"
    )
    new = (
        "    open_patterns = rule_open_sequence_pattern(p);\n"
        "    if open_patterns is not None {\n"
        "        patterns = pa_pattern_list(open_patterns);"
    )
    if old not in source:
        raise RuntimeError("patterns-rule patch anchor missing in generated parser")
    return source.replace(old, new, 1)


def _patch_store_target_rules(source: str) -> str:
    """Store/delete targets use atom, not t_primary (see CPython t_lookahead).

    Chained subscript targets (``sys.modules['x']``) use the ``rule_t_primary``
    fallback injected into ``rule_target_with_star_atom``.
    """
    rules = (
        "def rule_target_with_star_atom",
        "def rule_single_subscript_attribute_target",
        "def rule_del_target",
    )
    out: list[str] = []
    in_rule = False
    for line in source.splitlines(keepends=True):
        if any(line.startswith(f"{r}(p:") for r in rules):
            in_rule = True
        elif in_rule and line.startswith("def rule_"):
            in_rule = False
        if in_rule and "a = rule_t_primary(p)" in line:
            line = line.replace("a = rule_t_primary(p)", "a = rule_atom(p)")
        out.append(line)
    return "".join(out)


_TARGET_WITH_STAR_ATOM_FALLBACK = '''
    peg_reset(p, mark);
    prim = rule_primary(p);
    if prim is not None {
        if ((peg_negative_lookahead_token(p, 12))) {
            res = pa_set_context(prim, Store());
            peg_insert_memo(p, mark, RULE_target_with_star_atom, res);
            return res;
        }
    }
    peg_reset(p, mark);
'''


def _inject_target_with_star_atom_fallback(source: str) -> str:
    if "prim = rule_primary(p)" in source and "pa_set_context(prim, Store())" in source:
        return source
    anchor = "    peg_reset(p, mark);\n    star_atom = rule_star_atom(p);"
    if anchor not in source:
        raise RuntimeError("target_with_star_atom fallback anchor missing")
    return source.replace(anchor, _TARGET_WITH_STAR_ATOM_FALLBACK + anchor, 1)


def _patch_type_alias_simple_stmt(source: str) -> str:
    """rule_type_alias already expects the soft keyword; duplicating it at
    simple_stmt breaks nested aliases and multi-line suites."""
    old = (
        "    if ((peg_expect_soft_keyword(p, \"type\") is not None)) {\n"
        "        type_alias = rule_type_alias(p);\n"
        "        if type_alias is not None {\n"
        "            res = type_alias;\n"
        "            peg_insert_memo(p, mark, RULE_simple_stmt, res);\n"
        "            return res;\n"
        "        }\n"
        "    }\n"
        "    peg_reset(p, mark);"
    )
    new = (
        "    type_alias = rule_type_alias(p);\n"
        "    if type_alias is not None {\n"
        "        res = type_alias;\n"
        "        peg_insert_memo(p, mark, RULE_simple_stmt, res);\n"
        "        return res;\n"
        "    }\n"
        "    peg_reset(p, mark);"
    )
    if old not in source:
        raise RuntimeError("type_alias simple_stmt patch anchor missing")
    return source.replace(old, new, 1)


def _patch_parser_rules(source: str) -> str:
    source = _patch_patterns_rule(source)
    source = _patch_type_alias_simple_stmt(source)
    source = _patch_store_target_rules(source)
    return _inject_target_with_star_atom_fallback(source)


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(description="Emit Jac parser from python.gram")
    parser.add_argument("--stdout", action="store_true")
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args(argv)
    text = generate_text()
    if args.stdout:
        sys.stdout.write(text)
        return 0
    if args.check:
        try:
            on_disk = open(OUT_PATH).read()
        except FileNotFoundError:
            print(f"{OUT_PATH} missing; run grammar2jac.py", file=sys.stderr)
            return 1
        if on_disk != text:
            print(f"{OUT_PATH} is stale; regenerate with grammar2jac.py", file=sys.stderr)
            return 1
        print(f"{OUT_PATH} up to date")
        return 0
    with open(OUT_PATH, "w") as fh:
        fh.write(text)
    print(f"wrote {OUT_PATH} ({len(text.splitlines())} lines)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
