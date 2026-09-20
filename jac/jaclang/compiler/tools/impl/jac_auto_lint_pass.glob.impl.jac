impl JacAutoLintPass.combine_consecutive_glob(
    body: list[uni.ElementStmt | uni.String | uni.EmptyToken]
) -> list[uni.ElementStmt | uni.String | uni.EmptyToken] {
    if len(body) <= 1 {
        return body;
    }
    new_body: list[uni.ElementStmt | uni.String | uni.EmptyToken] = [];
    i = 0;
    while i < len(body) {
        stmt = body[i];

        if isinstance(stmt, uni.GlobalVars) {
            base_glob = stmt;
            merged_globs: list[uni.GlobalVars] = [base_glob];
            j = i + 1;
            while j < len(body) {
                next_stmt = body[j];

                if isinstance(next_stmt, uni.GlobalVars)
                    and self.can_combine_glob(base_glob, next_stmt) {
                    merged_globs.append(next_stmt);
                    j += 1;
                } else {
                    break;
                }
            }
            all_single = all(len(g.assignments) == 1 for g in merged_globs);
            if len(merged_globs) > 1
                and all_single
                and self.ctx.emit(W3003, node_override=base_glob) {
                combined_assignments: list[uni.Assignment] = [];
                for `glob in merged_globs {
                    combined_assignments.extend(`glob.assignments);
                }
                new_kid: list[uni.UniNode] = [];
                for kid in base_glob.kid {
                    if kid in base_glob.assignments {
                        break;
                    }
                    new_kid.append(kid);
                }
                for (idx, assign) in enumerate(combined_assignments) {
                    if idx > 0 {
                        new_kid.append(base_glob.gen_token(Tok.COMMA));
                    }

                    if assign.kid and isinstance(assign.kid[-1], uni.Semi) {
                        assign_kids = list(assign.kid[:-1]);
                        assign.set_kids(nodes=assign_kids);
                    }
                    new_kid.append(assign);
                }
                new_kid.append(base_glob.gen_token(Tok.SEMI));
                base_glob._role_set(AssignmentsRole, combined_assignments);
                base_glob.set_kids(nodes=new_kid);
                new_body.append(base_glob);
            } else {
                for g in merged_globs {
                    new_body.append(g);
                }
            }
            i = j;
        } else {
            new_body.append(stmt);
            i += 1;
        }
    }
    return new_body;
}

impl JacAutoLintPass.combine_consecutive_has(
    body: list[uni.UniNode]
) -> list[uni.UniNode] {
    if len(body) <= 1 {
        return body;
    }
    new_body: list[uni.UniNode] = [];
    i = 0;
    while i < len(body) {
        stmt = body[i];

        if isinstance(stmt, uni.ArchHas) {
            base_has = stmt;
            merged_has_list: list[uni.ArchHas] = [base_has];
            j = i + 1;
            while j < len(body) {
                next_stmt = body[j];

                if isinstance(next_stmt, uni.ArchHas)
                    and self.can_combine_has(base_has, next_stmt) {
                    merged_has_list.append(next_stmt);
                    j += 1;
                } else {
                    break;
                }
            }
            if len(merged_has_list) > 1 {
                combined_vars: list[uni.HasVar] = [];
                for has_stmt in merged_has_list {
                    combined_vars.extend(has_stmt.vars);
                }
                new_kid: list[uni.UniNode] = [];
                for kid in base_has.kid {
                    if kid in base_has.vars {
                        break;
                    }
                    new_kid.append(kid);
                }
                for (idx, var) in enumerate(combined_vars) {
                    if idx > 0 {
                        new_kid.append(base_has.gen_token(Tok.COMMA));
                    }
                    new_kid.append(var);
                }
                new_kid.append(base_has.gen_token(Tok.SEMI));
                base_has._role_set(VarsRole, combined_vars);
                base_has.set_kids(nodes=new_kid);
                new_body.append(base_has);
            } else {
                new_body.append(stmt);
            }
            i = j;
        } else {
            new_body.append(stmt);
            i += 1;
        }
    }
    return new_body;
}

impl JacAutoLintPass._combine_has_in_node(
    nd: uni.Archetype | uni.Enum | uni.Ability
) -> None {
    if nd.body is not None and isinstance(nd.body, list) {
        old_body = list(nd.body);
        new_body = self.combine_consecutive_has(old_body);
        if len(new_body) != len(old_body) and self.ctx.emit(W3002, node_override=nd) {
            nd._role_set(BodyRole, new_body);
            nd._invalidate_sub_node_tab();
            new_body_set = set(id(s) for s in new_body);
            new_kid: list[uni.UniNode] = [];
            for kid in nd.kid {
                if not isinstance(kid, uni.ArchHas) or id(kid) in new_body_set {
                    new_kid.append(kid);
                }
            }
            nd.set_kids(new_kid);
            nd._invalidate_sub_node_tab();
        }
    }
}

impl JacAutoLintPass.can_combine_glob(
    glob1: uni.GlobalVars, glob2: uni.GlobalVars
) -> bool {
    if glob1.doc or glob2.doc {
        return False;
    }
    if glob1.is_frozen != glob2.is_frozen {
        return False;
    }
    access1 = glob1.access.tag.name if glob1.access else None;
    access2 = glob2.access.tag.name if glob2.access else None;
    if access1 != access2 {
        return False;
    }
    return True;
}

impl JacAutoLintPass.can_combine_has(has1: uni.ArchHas, has2: uni.ArchHas) -> bool {
    for hv in list(has1.vars) + list(has2.vars) {
        if hv.accessors is not None {
            return False;
        }
    }
    if has1.is_static != has2.is_static {
        return False;
    }
    if has1.is_frozen != has2.is_frozen {
        return False;
    }
    access1 = has1.access.tag.name if has1.access else None;
    access2 = has2.access.tag.name if has2.access else None;
    if access1 != access2 {
        return False;
    }
    return True;
}

impl JacAutoLintPass.create_entry_block(
    stmts: list[uni.CodeBlockStmt]
) -> uni.ModuleCode {
    entry_block = uni.ModuleCode(name=None, body=stmts, kid=stmts, doc=None);
    new_kid: list[uni.UniNode] = [];
    new_kid.append(entry_block.gen_token(Tok.KW_WITH));
    new_kid.append(entry_block.gen_token(Tok.KW_ENTRY));
    new_kid.append(entry_block.gen_token(Tok.LBRACE));
    for stmt in stmts {
        new_kid.append(stmt);
    }
    new_kid.append(entry_block.gen_token(Tok.RBRACE));
    entry_block.set_kids(nodes=new_kid);
    return entry_block;
}

impl JacAutoLintPass.create_glob_from_assignment(
    assignment: uni.Assignment
) -> uni.GlobalVars {
    glob_node = uni.GlobalVars(
        access=None,
        assignments=[assignment],
        is_frozen=False,
        kid=[assignment],
        doc=None
    );
    new_kid: list[uni.UniNode] = [];
    new_kid.append(glob_node.gen_token(Tok.KW_GLOBAL));
    new_kid.append(assignment);
    glob_node.set_kids(nodes=new_kid);
    return glob_node;
}

impl JacAutoLintPass.is_module_level_construct(stmt: uni.UniNode) -> bool {
    return isinstance(
        stmt,
        (
            uni.Import,
            uni.Archetype,
            uni.Ability,
            uni.Enum,
            uni.GlobalVars,
            uni.Test,
            uni.PyInlineCode
        )
    );
}

impl JacAutoLintPass.can_convert_to_glob(assignment: uni.Assignment) -> bool {
    if assignment.value is None {
        return False;
    }
    if assignment.aug_op is not None {
        return False;
    }
    for target in assignment.target {
        if not isinstance(target, uni.Name) {
            return False;
        }
    }
    if isinstance(assignment.value, uni.FuncCall)
        or len(assignment.value.get_all_sub_nodes(uni.FuncCall)) > 0 {
        return False;
    }
    return True;
}

impl JacAutoLintPass.names_unsafe_to_globalize(module: uni.Module) -> set[str] {
    counts: dict[str, int] = {};
    for stmt in module.body {
        target_lists: list[Sequence[uni.Expr]] = [];
        if isinstance(stmt, uni.GlobalVars) {
            for assign in stmt.assignments {
                target_lists.append(assign.target);
            }
        } elif isinstance(stmt, uni.ModuleCode) and stmt.name is None {
            for inner_stmt in stmt.body {
                for assign in inner_stmt.get_all_sub_nodes(uni.Assignment) {
                    target_lists.append(assign.target);
                }
                if isinstance(inner_stmt, uni.Assignment) {
                    target_lists.append(inner_stmt.target);
                }
            }
        }
        for targets in target_lists {
            for target in targets {
                if isinstance(target, uni.Name) {
                    counts[target.value] = counts.get(target.value, 0) + 1;
                }
            }
        }
    }
    return {
        name
        for (name, count) in counts.items()
        if count > 1
    };
}

impl JacAutoLintPass.entry_written_names(module: uni.Module) -> set[str] {
    written: set[str] = set();
    for stmt in module.body {
        if isinstance(stmt, uni.ModuleCode) and stmt.name is None {
            for assign in stmt.get_all_sub_nodes(uni.Assignment) {
                for target in assign.target {
                    if isinstance(target, uni.Name) {
                        written.add(target.value);
                    }
                }
            }
        }
    }
    return written;
}

impl JacAutoLintPass.enter_module with uni.Module entry {
    if not self.lint_enabled or self.report_only {
        return;
    }
    module = here;
    if self.main_module is None {
        self.main_module = module;
    }
    unsafe_globalize = self.names_unsafe_to_globalize(module);
    entry_written = self.entry_written_names(module);
    new_body: list[(uni.ElementStmt | uni.String | uni.EmptyToken)] = [];
    for stmt in module.body {
        if self._is_future_annotations_import(stmt)
            and self.ctx.emit(W3009, node_override=stmt) {
            continue;
        }

        if isinstance(stmt, uni.ModuleCode) and stmt.name is None {
            pending_entry_stmts: list[uni.CodeBlockStmt] = [];
            for inner_stmt in stmt.body {
                extracted_stmt: (uni.ElementStmt | None) = None;
                assign_value: (uni.Expr | uni.YieldExpr | None) = (
                    inner_stmt.value if isinstance(inner_stmt, uni.Assignment) else None
                );
                if isinstance(inner_stmt, uni.Assignment)
                    and (assign_value is not None)
                    and self.can_convert_to_glob(inner_stmt)
                    and not any(
                        isinstance(target, uni.Name)
                            and (target.value in unsafe_globalize)
                        for target in inner_stmt.target
                    )
                    and not (
                        isinstance(assign_value, uni.Name)
                        and (assign_value.value in entry_written)
                    )
                    and not any(
                        nm.value in entry_written
                        for nm in assign_value.get_all_sub_nodes(uni.Name)
                    ) {
                    extracted_stmt = self.create_glob_from_assignment(inner_stmt);
                } elif isinstance(inner_stmt, uni.ElementStmt)
                    and self.is_module_level_construct(inner_stmt) {
                    extracted_stmt = inner_stmt;
                }

                if extracted_stmt is not None {
                    if pending_entry_stmts {
                        new_body.append(self.create_entry_block(pending_entry_stmts));
                        pending_entry_stmts = [];
                    }
                    new_body.append(extracted_stmt);
                } elif not isinstance(inner_stmt, uni.Semi) {
                    pending_entry_stmts.append(inner_stmt);
                }
            }
            if pending_entry_stmts {
                new_body.append(self.create_entry_block(pending_entry_stmts));
            }
        } else {
            new_body.append(stmt);
        }
    }
    if not self.ctx._is_suppressed(W3003) {
        new_body = self.combine_consecutive_glob(new_body);
    }
    module._role_set(BodyRole, new_body);
    module._invalidate_sub_node_tab();
    new_kid: list[uni.UniNode] = [];
    if module.doc {
        new_kid.append(module.doc);
    }
    new_kid.extend(new_body);
    module.set_kids(nodes=new_kid if len(new_kid) else [uni.EmptyToken()]);
}
