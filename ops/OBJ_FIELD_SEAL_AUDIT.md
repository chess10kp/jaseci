# Audit: obj init assigning fields not declared in `has` (native-seal E5092 class)

Base: origin/jac-python @ dbd8e55a426326d6995782c0d0aa63d4d20a89b1
Tool: ops/audit_fields.py (in-obj init/postinit) + ops/audit_fields2.py (adds
`impl X.init` / `impl X.postinit` blocks and transitive inherited has-fields).

## jac-py/jacpython/*.jac (181 files, 406 obj decls)

**CLEAN - zero findings.** Every `self.<f> = ...` in an init/postinit targets a
field declared in the obj's own `has` block or inherited from a base. Augmented
(`+=`) self-assignments inside inits: also zero.

## Core-owned (jac/jaclang/compiler/** + jac0core, 476 .jac files)

| Finding | Status |
|---|---|
| CModuleAst.init assigns `self.ast` without `has ast` | Already fixed on this tip by dbd8e55a4 ("declare CModuleAst.ast field so native seal lowers it"); was one commit after prior worktree base 3f4717f92 |
| EsJsxProcessor: pass_ref/es/_view_by_node in init@jsx_processor.impl.jac | False positive - Python `class EsJsxProcessor` (ast_gen/jsx_processor.jac:16), not a Jac `obj`; py-native attrs are exempt from obj-field sealing |
| TypeCheckPass: prog in init@type_checker_pass.impl.jac | False positive - Python `class TypeCheckPass(UniPass)` (passes/type_checker_pass.jac:134), not a Jac `obj` |

**No open core-owned obj findings remain on origin/jac-python tip.**

## Method note

The E5092 seal-break class only applies to Jac `obj`/archetype field storage;
Python `class` decls keep dynamic attribute semantics. The audit therefore keys
on `obj X(...)` declarations and resolves inheritance transitively across files.
