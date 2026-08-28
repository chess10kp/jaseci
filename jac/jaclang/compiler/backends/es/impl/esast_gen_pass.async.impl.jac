import from jaclang.compiler.backends.es.reactive_intent { AsyncBoundary }

impl EsastGenPass.exit_await_expr(nd: uni.AwaitExpr) -> None {
    argument = cast(
        es.Expression,
        nd.target.gen.es_ast
            or self.sync_loc(es.Identifier(name='undefined'), jac_node=nd.target)
    );
    await_expr = self.sync_loc(es.AwaitExpression(argument=argument), jac_node=nd);
    nd.gen.es_ast = await_expr;
}

impl EsastGenPass._try_exit_except_view_awaiting(nd: uni.Except) -> bool {
    parent_try = nd.find_parent_of_type(uni.TryStmt);
    if parent_try is not None and id(parent_try) in self._view_awaiting_tries {
        acc = self._view_stack.pop() if self._view_stack else VIEW_ACC;
        nd.gen.es_ast = self._build_view_iife(
            nd.body, acc if isinstance(acc, str) else VIEW_ACC, nd
        );
        return True;
    }
    return False;
}

impl EsastGenPass.enter_try_stmt(nd: uni.TryStmt) -> None {
    if self._cur_view_acc() is not None and nd.awaiting_body is not None {
        self._view_awaiting_tries.add(id(nd));
        self._push_view_acc();
    }
}

impl EsastGenPass.enter_awaiting_clause(nd: uni.AwaitingClause) -> None {
    parent_try = nd.find_parent_of_type(uni.TryStmt);
    if parent_try is not None and id(parent_try) in self._view_awaiting_tries {
        self._push_view_acc();
    }
}

impl EsastGenPass.exit_awaiting_clause(nd: uni.AwaitingClause) -> None {
    parent_try = nd.find_parent_of_type(uni.TryStmt);
    if parent_try is not None and id(parent_try) in self._view_awaiting_tries {
        acc = self._view_stack.pop() if self._view_stack else VIEW_ACC;
        nd.gen.es_ast = self._build_view_iife(
            nd.body, acc if isinstance(acc, str) else VIEW_ACC, nd
        );
    }
}

impl EsastGenPass.enter_except(nd: uni.Except) -> None {
    parent_try = nd.find_parent_of_type(uni.TryStmt);
    if parent_try is not None and id(parent_try) in self._view_awaiting_tries {
        self._push_view_acc();
    }
}

impl EsastGenPass._try_exit_try_stmt_view_awaiting(nd: uni.TryStmt) -> bool {
    if id(nd) not in self._view_awaiting_tries {
        return False;
    }
    self._view_awaiting_tries.discard(id(nd));
    try_acc = self._view_stack.pop() if self._view_stack else VIEW_ACC;
    try_iife = self._build_view_iife(
        nd.body, try_acc if isinstance(try_acc, str) else VIEW_ACC, nd
    );
    awaiting_iife: es.Expression = (
        cast(es.Expression, nd.awaiting_body.gen.es_ast)
            if (nd.awaiting_body is not None and nd.awaiting_body.gen.es_ast)
            else self._build_view_iife([], VIEW_ACC, nd)
    );
    except_iifes: list[es.Expression] = [];
    if nd.excepts {
        except_iifes = [
            cast(es.Expression, ex.gen.es_ast)
            for ex in nd.excepts
            if ex.gen.es_ast is not None
        ];
    }
    async_boundary = AsyncBoundary(
        try_expr=try_iife, awaiting_expr=awaiting_iife, except_exprs=except_iifes
    );
    self._ensure_backend();
    for sym in self.backend.async_boundary_symbols(async_boundary) {
        self._inject_runtime_import(sym, nd);
    }
    wrapper = self.sync_loc(
        self.backend.lower_async_boundary(async_boundary), jac_node=nd
    );
    outer = self._cur_view_acc();
    if outer is not None {
        nd.gen.es_ast = self._view_emit_child(outer, wrapper, nd);
    } else {
        nd.gen.es_ast = self.sync_loc(
            es.ExpressionStatement(expression=wrapper), jac_node=nd
        );
    }
    return True;
}
