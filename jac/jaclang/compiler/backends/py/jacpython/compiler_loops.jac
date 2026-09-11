# Loop/if control-flow codegen (if, while, for, async for) extracted from
# compiler_codegen.jac. Pure mechanical move; see compiler_codegen.jac for the
# module-initialization ordering contract.

import from jaclang.runtime.python.opcode_meta {
    OP_END_ASYNC_FOR,
    OP_END_FOR,
    OP_FOR_ITER,
    OP_GET_AITER,
    OP_GET_ITER,
    OP_GET_YIELD_FROM_ITER,
    OP_JUMP_BACKWARD,
    OP_JUMP_FORWARD,
    OP_LOAD_CONST,
    OP_NOP,
    OP_NOT_TAKEN,
    OP_POP_ITER,
    OP_POP_JUMP_IF_FALSE,
    OP_POP_JUMP_IF_TRUE,
    OP_POP_TOP,
    OP_RETURN_VALUE,
    has_target,
    is_scope_exit_opcode,
    is_unconditional_jump_opcode,
}
import from jaclang.compiler.frontend.python.ast_nodes {
    AsyncFor,
    Constant,
    For,
    If,
    Name,
    While,
    stmt,
}
import from jaclang.compiler.backends.py.jacpython.compiler_ir {
    basicblock,
    break_site,
    cfg_builder,
    cloc,
    cinstr,
    except_region,
    loc,
    loop_frame,
    mk_instr,
    mk_jump,
    no_loc,
    pending_break_finish,
    same_loc,
    stmt_cont,
}
import from jaclang.runtime.python.objects { py_none }
import from jaclang.compiler.backends.py.jacpython.flowgraph {
    MAX_COPY_SIZE,
    copy_cinstr
}
import from jaclang.compiler.backends.py.jacpython.compiler_emit {
    codegen_busy,
    codegen_fail,
    emit_anext_send_loop_footer,
    emit_anext_send_loop_header,
    emit_branch_if_test_false,
    emit_branch_if_test_true,
    visit_expr,
    visit_test_expr,
}
import from jaclang.compiler.backends.py.jacpython.codegen_util {
    exec_tail_emits_code,
    expr_loc,
    loop_body_has_break,
    loop_body_has_try,
    nloc,
}
import from jaclang.compiler.backends.py.jacpython.compiler_annotations {
    ann_scope_plan
}
import from jaclang.compiler.backends.py.jacpython.compiler_codegen {
    emit_module_return,
    emit_tail_and_finish,
    visit_stmt_tail,
    visit_stmts,
    visit_store_target_tos
}
import from jaclang.compiler.backends.py.jacpython.compiler_dispatch { stmt_handlers }
import from jaclang.compiler.backends.py.jacpython.compiler_exc {
    emit_anext_send_except_regions
}
import from jaclang.compiler.backends.py.jacpython.compiler_context {
    append_pending_break_finish,
    current_pending_break_finishes,
    push_pending_break_finish,
    current_optimization_level,
}

# ---------------- break-edge tail duplication (CPython parity) ----------------
#
# CPython lowers `break` as an unwind plus a jump to the loop's exit anchor,
# which sits AFTER orelse (codegen.c codegen_break / codegen_for). Its flowgraph
# optimizer then tail-duplicates that anchor into each break edge when the
# anchor ends up a small scope-exit block (flowgraph.c
# inline_small_exit_blocks, MAX_COPY_SIZE) and prunes the artificial break NOP
# per line-number rules. We emit the post-optimizer shape directly: break sites
# record themselves in the loop frame, the shared continuation block is built
# once, then finish_break_sites copies it over each break jump when CPython
# would have.

# A loop compiled with a None tail (nested-loop context) cannot finish its
# break sites inline: its shared continuation is appended to by the CALLER
# after this visitor returns (the enclosing loop's back edge, following
# statements, or the driver epilogue). Those loops record a finish job; the
# enclosing visitor flushes the queue once the continuation block can receive
# no further instructions. Flushing drives the SAME finish_break_sites
# mechanism as the synchronous tail-present path -- there is one splicer, and
# deferral only changes WHEN it observes the finalized continuation.

# Does control fall out of the block (CPython BB_HAS_FALLTHROUGH)?
def block_is_terminated(b: basicblock) -> bool {
    n = len(b.instrs);
    if n == 0 {
        return False;
    }
    op = b.instrs[n - 1].opcode;
    return is_unconditional_jump_opcode(op) or is_scope_exit_opcode(op);
}

# Finish every job recorded since `from_idx`. Called only at points where all
# continuation blocks touched by those jobs are final: right after the owning
# visitor emitted its own trailing instructions (back edge) into the current
# block. Jobs are consumed even when neither inline predicate fires -- keeping
# the plain jump then matches CPython, whose pass simply does not rewrite.
def flush_pending_break_finishes(g: cfg_builder, from_idx: int) {
    jobs = current_pending_break_finishes();
    while from_idx < len(jobs) {
        job = jobs[from_idx];
        jobs.pop(from_idx);
        if not block_is_terminated(job.join) {
            # Falling-through continuations are finalized by the unit drivers
            # (epilogue synthesis needs tail context this lane does not have);
            # leaving the plain jump matches today's verified shapes.
            continue;
        }
        finish_break_sites(g, job.frame, job.join, no_loc(), True, job.allow_nop);
        if job.test_blk is not None
            and job.branch_idx >= 0
            and job.body_hdr is not None
            and join_artificial_tail(job.join) {
            # Thread the test's false edge through the artificial anchor
            # exactly as CPython's optimizer does: reverse the conditional
            # onto the body and inline the anchor copy after the test (the
            # NOT_TAKEN after the forward conditional is added later).
            br = job.test_blk.instrs[job.branch_idx];
            if br.opcode == OP_POP_JUMP_IF_FALSE {
                br.opcode = OP_POP_JUMP_IF_TRUE;
                hdr = job.body_hdr as basicblock;
                br.target_block = hdr.id;
                ci = 0;
                while ci < len(job.join.instrs) {
                    job.test_blk.instrs.append(copy_cinstr(job.join.instrs[ci]));
                    ci = ci + 1;
                }
            }
        }
    }
}

# Mirror inline_small_exit_blocks' target test for the continuation block.
# The driver-appended unit epilogue (LOAD_CONST None; RETURN_VALUE) counts
# toward MAX_COPY_SIZE when the tail itself falls through.
def join_inlinable(join: basicblock, tail_terminated: bool) -> bool {
    # Yield-from lowering leaves a short prefix on the join block while the
    # SEND/END_SEND sequence lives on deferred blocks. Inlining that prefix onto
    # break edges (plus a synthetic return) is not a complete continuation.
    if len(join.instrs) > 0 and join.instrs[0].opcode == OP_GET_YIELD_FROM_ITER {
        return False;
    }
    count = len(join.instrs);
    if not tail_terminated {
        count = count + 2;
    } else {
        if count == 0 {
            return False;
        }
        if not is_scope_exit_opcode(join.instrs[count - 1].opcode) {
            return False;
        }
    }
    if count > MAX_COPY_SIZE {
        return False;
    }
    ii = 0;
    while ii < len(join.instrs) {
        if has_target(join.instrs[ii].opcode) {
            # A branch inside the continuation means CPython's block would have
            # been split before the scope exit; no duplication happened there.
            return False;
        }
        ii = ii + 1;
    }
    return True;
}

# Mirror inline_small_or_no_lineno_blocks' second target test (flowgraph.c):
# a continuation consisting solely of artificial (line-less) instructions that
# does not fall through is appended to every jumping predecessor regardless of
# size -- this is the shape nested-loop continuations take (the enclosing loop's
# back edge, END_FOR/POP_ITER cleanups). No MAX_COPY_SIZE cap applies there.
def join_artificial_tail(join: basicblock) -> bool {
    n = len(join.instrs);
    if n == 0 {
        return False;
    }
    if not block_is_terminated(join) {
        return False;
    }
    ii = 0;
    while ii < n {
        if join.instrs[ii].loc.lineno >= 0 {
            return False;
        }
        ii = ii + 1;
    }
    return True;
}

# Would CPython's remove_redundant_nops keep the artificial NOP emitted before
# a break jump that was tail-duplicated? It survives only when it differs in
# line from both its predecessor and the first copied instruction.
def break_nop_kept(site: break_site, first_copy_loc: cloc) -> bool {
    if site.loc.lineno < 0 {
        return False;
    }
    instrs = site.blk.instrs;
    if site.instr_idx > 0
        and instrs[site.instr_idx - 1].loc.lineno == site.loc.lineno {
        return False;
    }
    if first_copy_loc.lineno == site.loc.lineno or first_copy_loc.lineno < 0 {
        return False;
    }
    return True;
}

def finish_break_sites(
    g: cfg_builder,
    frame: loop_frame,
    join: basicblock,
    tail_loc: cloc,
    tail_terminated: bool,
    allow_nop: bool
) {
    # CPython tries the small scope-exit copy first, then the artificial
    # no-lineno copy (optimize_cfg runs inline_small_or_no_lineno_blocks).
    copies: list[cinstr] | None = None;
    if join_inlinable(join, tail_terminated) {
        copies = [];
        ci = 0;
        while ci < len(join.instrs) {
            copies.append(copy_cinstr(join.instrs[ci]));
            ci = ci + 1;
        }
        if not tail_terminated {
            if g.fallthrough_target is not None {
                g.fallthrough_target.fallthrough_used = True;
                copies.append(
                    mk_jump(OP_JUMP_FORWARD, g.fallthrough_target.id, tail_loc)
                );
            } else {
                none_idx = g.u.add_const(py_none());
                copies.append(mk_instr(OP_LOAD_CONST, none_idx, tail_loc));
                copies.append(mk_instr(OP_RETURN_VALUE, 0, tail_loc));
            }
        }
    } elif join_artificial_tail(join) {
        copies = [];
        ci = 0;
        while ci < len(join.instrs) {
            copies.append(copy_cinstr(join.instrs[ci]));
            ci = ci + 1;
        }
    }
    if copies is None or len(copies) == 0 {
        return;
    }
    # Exit-per-block invariant (mirrors CPython flowgraph.c structure):
    # cfg_builder_maybe_start_new_block starts a fresh block after any
    # terminator, so a jump is always the LAST instruction of its block and
    # inline_small_or_no_lineno_blocks only ever rewrites
    # basicblock_last_instr -- one exit per block, structurally. Our break
    # sites record the index of their jump, which is last-instruction at
    # record time and stays last because visit_stmts halts at the
    # unconditional terminator. Several sites may still share a block; the
    # splice below therefore runs in DESCENDING index order, which keeps
    # lower indices valid while higher ones are rewritten. Enforce both
    # properties loudly instead of trusting callers.
    prev_blk_id = -1;
    prev_idx = -1;
    si = len(frame.break_sites) - 1;
    while si >= 0 {
        site = frame.break_sites[si];
        if site.instr_idx < 0 or site.instr_idx >= len(site.blk.instrs) {
            codegen_fail(
                g, "SystemError", "break site index out of range in finish_break_sites"
            );
            return;
        }
        if not is_unconditional_jump_opcode(site.blk.instrs[site.instr_idx].opcode) {
            codegen_fail(
                g, "SystemError", "break site does not point at its recorded jump"
            );
            return;
        }
        if site.blk.id == prev_blk_id and site.instr_idx >= prev_idx {
            # Same block as the site spliced just before us (higher index);
            # ours must sit strictly below it or the rebuild above would
            # drop instructions between the two exits.
            codegen_fail(
                g, "SystemError", "break sites in one block not in descending order"
            );
            return;
        }
        prev_blk_id = site.blk.id;
        prev_idx = site.instr_idx;
        si = si - 1;
    }
    first_loc = copies[0].loc as cloc;
    uniform_copy_locs = len(copies) > 0;
    if uniform_copy_locs {
        ci = 1;
        while ci < len(copies) {
            if not same_loc(copies[0].loc as cloc, copies[ci].loc as cloc) {
                uniform_copy_locs = False;
                break;
            }
            ci = ci + 1;
        }
    }
    si = len(frame.break_sites) - 1;
    while si >= 0 {
        site = frame.break_sites[si];
        old = site.blk.instrs;
        new_instrs: list[cinstr] = old[0:site.instr_idx];
        ci = 0;
        while ci < len(copies) {
            c = copy_cinstr(copies[ci]);
            if uniform_copy_locs and site.loc.lineno >= 0 {
                c.loc = site.loc;
            }
            new_instrs.append(c);
            ci = ci + 1;
        }
        ki = site.instr_idx + 1;
        while ki < len(old) {
            new_instrs.append(old[ki]);
            ki = ki + 1;
        }
        site.blk.instrs = new_instrs;
        if allow_nop and break_nop_kept(site, first_loc) {
            new_instrs.insert(site.instr_idx, mk_instr(OP_NOP, 0, site.loc));
        }
        si = si - 1;
    }
}

def visit_if(
    g: cfg_builder,
    i: If,
    more_code_follows: bool,
    tail: list[stmt],
    tail_idx: int,
    tail_join: basicblock | None = None,
    ann_ctx: ann_scope_plan | None = None
) -> stmt_cont {
    iloc = nloc(i.lineno, i.end_lineno, i.col_offset, i.end_col_offset);
    constant_test = None;
    if isinstance(i.`test, Constant) {
        constant_test = i.`test.value.tp_bool();
    } elif isinstance(i.`test, Name) and i.`test.id == "__debug__" {
        constant_test = current_optimization_level() == 0;
    }
    if constant_test is not None {
        chosen = i.body if constant_test else i.orelse;
        return stmt_handlers["visit_cleanup_stmts"](g, chosen, ann_ctx);
    }
    test_loc = expr_loc(i.`test);
    kind = visit_test_expr(g, i.`test, test_loc, True);
    false_blk = g.new_deferred_block();
    join = g.new_deferred_block();
    emit_branch_if_test_false(g, kind, false_blk.id, test_loc);
    body_cont = stmt_handlers["visit_cleanup_stmts"](g, i.body, ann_ctx);
    if not body_cont.terminated {
        g.emit_jump(OP_JUMP_FORWARD, join.id, iloc);
    }
    g.use(false_blk);
    else_cont = stmt_handlers["visit_cleanup_stmts"](g, i.orelse, ann_ctx);
    if body_cont.terminated and else_cont.terminated {
        return stmt_cont(loc=iloc, terminated=True);
    }
    if not else_cont.terminated and g.u.blocks[-1] is not g.cur {
        g.emit_jump(OP_JUMP_FORWARD, join.id, iloc);
    }
    g.use(join);
    return stmt_cont(loc=iloc);
}

def visit_while(
    g: cfg_builder,
    w: While,
    more_code_follows: bool,
    tail: list[stmt],
    tail_idx: int,
    ann_ctx: ann_scope_plan | None = None
) -> stmt_cont {
    wloc = nloc(w.lineno, w.end_lineno, w.col_offset, w.end_col_offset);
    test_loc = expr_loc(w.`test);
    head = g.new_block();
    g.use(head);
    kind = visit_test_expr(g, w.`test, test_loc, True);
    if codegen_busy(g) {
        return stmt_cont(loc=wloc);
    }
    has_break = loop_body_has_break(w.body);
    if more_code_follows {
        # Deferred: placed at first use AFTER the body is visited. Eager
        # placement would fix these blocks' layout position ahead of blocks
        # allocated while visiting the body (if/loop fragments), so the
        # join's fall-through and break-site splices would land inside body
        # code (infinite loops) instead of the post-loop continuation.
        exit_blk = g.new_deferred_block();
        # Break edges target the shared continuation AFTER orelse (CPython's
        # `end` label): break must skip the else clause.
        if has_break {
            join = g.new_deferred_block();
            g.push_loop(head, join, True);
            break_frame = g.current_loop() as loop_frame;
        } else {
            g.push_loop(head, exit_blk, False);
        }
        emit_branch_if_test_false(g, kind, exit_blk.id, test_loc);
        body_snap = len(current_pending_break_finishes());
        body_cont = visit_stmts(g, w.body, 0, False, None, 0, None, ann_ctx);
        if codegen_busy(g) {
            g.pop_loop();
            return stmt_cont(loc=body_cont.loc);
        }
        if not body_cont.terminated {
            g.emit_jump(OP_JUMP_BACKWARD, head.id, body_cont.loc);
        }
        g.pop_loop();
        # The back edge above is the last write into any nested loop's
        # continuation; finish its deferred break sites now.
        flush_pending_break_finishes(g, body_snap);
        tail_more = tail is not None and exec_tail_emits_code(tail, tail_idx + 1);
        g.use(exit_blk);
        else_terminated = False;
        if len(w.orelse) > 0 {
            else_snap = len(current_pending_break_finishes());
            else_cont = visit_stmts(g, w.orelse, 0, False, None, 0, None, ann_ctx);
            if codegen_busy(g) {
                return stmt_cont(loc=else_cont.loc);
            }
            flush_pending_break_finishes(g, else_snap);
            else_terminated = else_cont.terminated;
        }
        if else_terminated and not has_break {
            # Normal loop exit runs the else, which terminates; with no break
            # there is no path to the trailing statements, so they are
            # unreachable. CPython drops them (DCE); emitting them here would be
            # dead code after a terminator ("Invalid CFG").
            return stmt_cont(loc=wloc, next_si=len(tail), terminated=True);
        }
        if not has_break {
            if tail is None {
                # Nested-loop context: the caller emits the continuation into
                # the current block.
                return stmt_cont(loc=wloc);
            }
            tail_cont = visit_stmt_tail(
                g, tail, tail_idx, exec_tail_emits_code(tail, tail_idx + 1), ann_ctx
            );
            return stmt_cont(
                loc=tail_cont.loc, next_si=len(tail), terminated=tail_cont.terminated
            );
        }
        g.use(join);
        if tail is None {
            # Nested-loop context: the caller appends the continuation into
            # `join` after this returns. Defer finishing until the enclosing
            # visitor finalizes the block.
            push_pending_break_finish(break_frame, join, True);
            return stmt_cont(loc=wloc);
        }
        tail_cont = visit_stmt_tail(
            g, tail, tail_idx, exec_tail_emits_code(tail, tail_idx + 1), ann_ctx
        );
        if codegen_busy(g) {
            return stmt_cont(loc=tail_cont.loc);
        }
        # WHILE-loop unwind emits nothing before the jump, but CPython's
        # artificial break NOP survives tail duplication when its line differs
        # from the copied continuation's first line.
        finish_break_sites(
            g, break_frame, join, tail_cont.loc, tail_cont.terminated, True
        );
        return stmt_cont(
            loc=tail_cont.loc, next_si=len(tail), terminated=tail_cont.terminated
        );
    }
    if len(g.loop_stack) > 0 {
        # CPython lowers a nested trailing loop with its anchor as a shared
        # continuation: the enclosing loop's back edge is appended into it
        # once this visitor returns, and the optimizer threads BOTH the break
        # edges AND the test's false edge through that artificial block
        # (conditional reversal: jump-true to the body, continuation copy
        # inlined after the test; normalize_jumps adds NOT_TAKEN). body_hdr
        # reserves the body-start position the reversed conditional targets;
        # it stays an unreferenced (zero-byte) boundary when the continuation
        # ends up line-bearing and no threading happens.
        parent = g.current_loop();
        body_hdr = g.new_block();
        after_body = g.new_deferred_block();
        emit_branch_if_test_false(g, kind, after_body.id, test_loc);
        test_blk = g.cur;
        branch_idx = len(g.cur.instrs) - 1;
        if has_break {
            g.push_loop(head, after_body, True);
            break_frame = g.current_loop() as loop_frame;
        } else {
            g.push_loop(head, after_body, False);
        }
        body_snap = len(current_pending_break_finishes());
        g.use(body_hdr);
        body_cont = visit_stmts(g, w.body, 0, False, None, 0, None, ann_ctx);
        if codegen_busy(g) {
            g.pop_loop();
            return stmt_cont(loc=body_cont.loc);
        }
        if not body_cont.terminated {
            # Artificial like CPython's NO_LOCATION back edge: the copied jump
            # on each break edge must carry no line, and the all-artificial
            # predicate below keys off it.
            g.emit_jump(OP_JUMP_BACKWARD, head.id, no_loc());
        }
        g.pop_loop();
        flush_pending_break_finishes(g, body_snap);
        if has_break and parent is not None {
            # Our own continuation gains the caller's back edge after we
            # return; defer like the tail-is-None path above.
            job = pending_break_finish(
                frame=break_frame,
                join=after_body,
                allow_nop=True,
                test_blk=test_blk,
                branch_idx=branch_idx,
                body_hdr=body_hdr
            );
            append_pending_break_finish(job);
        }
        g.use(after_body);
        return stmt_cont(loc=wloc, terminated=False);
    }
    emit_branch_if_test_false(g, kind, 0, test_loc);
    pop_false_ins = g.cur.instrs[len(g.cur.instrs) - 1];
    exit_blk = g.new_deferred_block();
    try_in_body = loop_body_has_try(w.body);
    if try_in_body {
        g.loop_exit_before_try_handlers = exit_blk;
        g.loop_exit_return_loc = test_loc;
        g.loop_exit_emits_end_for = False;
        g.loop_except_depth_bump = 0;
    }
    pop_false_ins.target_block = exit_blk.id;
    if has_break and try_in_body {
        g.push_loop(head, exit_blk, True);
        break_frame = g.current_loop() as loop_frame;
    } elif has_break {
        g.push_loop(head, head, False);
    } else {
        g.push_loop(head, exit_blk, False);
    }
    body_snap = len(current_pending_break_finishes());
    body_cont = visit_stmts(g, w.body, 0, False, None, 0, None, ann_ctx);
    if codegen_busy(g) {
        g.pop_loop();
        return stmt_cont(loc=body_cont.loc);
    }
    if not body_cont.terminated {
        g.emit_jump(OP_JUMP_BACKWARD, head.id, body_cont.loc);
    }
    g.pop_loop();
    flush_pending_break_finishes(g, body_snap);
    if try_in_body {
        g.loop_exit_before_try_handlers = None;
        g.loop_exit_return_loc = None;
        g.loop_exit_emits_end_for = False;
        g.loop_except_depth_bump = 0;
    }
    epilogue_done = g.loop_exit_epilogue_complete;
    g.loop_exit_epilogue_complete = False;
    exit_epilogue_emitted = False;
    if not exit_blk.placed {
        g.use(exit_blk);
        if len(w.orelse) > 0 {
            else_snap = len(current_pending_break_finishes());
            else_cont = visit_stmts(g, w.orelse, 0, False, None, 0, None, ann_ctx);
            if codegen_busy(g) {
                return stmt_cont(loc=else_cont.loc);
            }
            flush_pending_break_finishes(g, else_snap);
            emit_module_return(g, else_cont.loc);
        } else {
            emit_module_return(g, test_loc);
        }
        exit_epilogue_emitted = True;
    }
    if has_break and try_in_body {
        finish_break_sites(
            g,
            break_frame,
            exit_blk,
            test_loc,
            epilogue_done or exit_epilogue_emitted,
            False
        );
    }
    return stmt_cont(loc=wloc, terminated=True);
}


def visit_for(
    g: cfg_builder,
    f: For,
    more_code_follows: bool,
    tail: list[stmt],
    tail_idx: int,
    ann_ctx: ann_scope_plan | None = None
) -> stmt_cont {
    floc = nloc(f.lineno, f.end_lineno, f.col_offset, f.end_col_offset);
    iter_loc = expr_loc(f.iter);
    visit_expr(g, f.iter);
    if codegen_busy(g) {
        return stmt_cont(loc=floc);
    }
    g.emit_op(OP_GET_ITER, 0, iter_loc);
    loop_hdr = g.new_block();
    g.use(loop_hdr);
    has_break = loop_body_has_break(f.body);
    # The iterator stays on the value stack across the whole body: every try
    # anywhere in the body (any nesting) must record it in its exception-table
    # depth. Without the bump the handler unwinds past the iterator and the
    # back edge re-enters FOR_ITER on an empty stack. The bump is only read
    # by try_protect_stack_depth / try_unwind_stack_depth during region
    # creation, so setting it for every for-loop is exact.
    g.loop_except_depth_bump = g.loop_except_depth_bump + 1;
    if more_code_follows {
        # Defer exhaustion cleanup until after the body is visited. Eager
        # placement left orphan blocks in layout when nested visit_for paths
        # reassigned `after`, breaking stackdepth on a trailing loop.
        after = g.new_deferred_block();
        # Break edges target the shared continuation AFTER orelse (CPython's
        # `end` label): break must skip the else clause.
        if has_break {
            join = g.new_deferred_block();
            g.push_loop(loop_hdr, join, True, True);
            break_frame = g.current_loop() as loop_frame;
            break_frame.pops_iter = True;
        } else {
            g.push_loop(loop_hdr, after, False, True);
        }
        g.emit_jump(OP_FOR_ITER, after.id, iter_loc);
        store = visit_store_target_tos(g, f.target);
        if codegen_busy(g) {
            g.pop_loop();
            return stmt_cont(loc=store.loc);
        }
        body_snap = len(current_pending_break_finishes());
        body_cont = visit_stmts(g, f.body, 0, False, None, 0, None, ann_ctx);
        if codegen_busy(g) {
            g.pop_loop();
            return stmt_cont(loc=body_cont.loc);
        }
        if not body_cont.terminated {
            g.emit_jump(OP_JUMP_BACKWARD, loop_hdr.id, body_cont.loc);
        }
        g.pop_loop();
        g.loop_except_depth_bump = g.loop_except_depth_bump - 1;
        # The back edge above is the last write into any nested loop's
        # continuation; finish its deferred break sites now.
        flush_pending_break_finishes(g, body_snap);
        tail_more = tail is not None and exec_tail_emits_code(tail, tail_idx + 1);
        g.use(after);
        g.emit_op(OP_END_FOR, 0, iter_loc);
        g.emit_op(OP_POP_ITER, 0, iter_loc);
        else_terminated = False;
        if len(f.orelse) > 0 {
            else_snap = len(current_pending_break_finishes());
            else_cont = visit_stmts(g, f.orelse, 0, False, None, 0, None, ann_ctx);
            if codegen_busy(g) {
                return stmt_cont(loc=else_cont.loc);
            }
            flush_pending_break_finishes(g, else_snap);
            else_terminated = else_cont.terminated;
        }
        if else_terminated and not has_break {
            # Normal loop exit runs the else, which terminates; with no break
            # there is no path to the trailing statements, so they are
            # unreachable. CPython drops them (DCE); emitting them here would be
            # dead code after a terminator ("Invalid CFG").
            return stmt_cont(loc=floc, next_si=len(tail), terminated=True);
        }
        if not has_break {
            # CPython's exhaustion cleanup and the trailing statement suffix share
            # one continuation label (`after`). Emit END_FOR/POP_ITER here, then
            # let visit_stmts resume the suffix in this same block — do not
            # recurse through visit_stmt_tail (that left tail=None on nested
            # visit_if calls and duplicated layout edges).
            return stmt_cont(loc=floc);
        }
        g.use(join);
        if tail is None {
            # Nested-loop context: the caller appends the continuation into
            # `join` after this returns. Defer finishing until the enclosing
            # visitor finalizes the block.
            push_pending_break_finish(break_frame, join, False);
            return stmt_cont(loc=floc);
        }
        tail_cont = visit_stmt_tail(
            g, tail, tail_idx, exec_tail_emits_code(tail, tail_idx + 1), ann_ctx
        );
        if codegen_busy(g) {
            return stmt_cont(loc=tail_cont.loc);
        }
        finish_break_sites(
            g, break_frame, join, tail_cont.loc, tail_cont.terminated, False
        );
        return stmt_cont(
            loc=tail_cont.loc, next_si=len(tail), terminated=tail_cont.terminated
        );
    }
    if len(g.loop_stack) > 0 {
        # Nested trailing loop: CPython emits the exhaustion target as the
        # END_FOR/POP_ITER cleanup, then continues IN THE SAME BLOCK STREAM into
        # the shared continuation (`end`, USE_LABEL after the cleanup) which
        # receives the enclosing loop's back edge once this visitor returns.
        # Break edges target that continuation; inline_small_or_no_lineno_blocks
        # then copies its artificial content over each break jump.
        after = g.new_deferred_block();
        join = after;
        g.loop_except_depth_bump = g.loop_except_depth_bump + 1;
        if has_break {
            join = g.new_deferred_block();
            g.push_loop(loop_hdr, join, True, True);
            break_frame = g.current_loop() as loop_frame;
            break_frame.pops_iter = True;
        } else {
            g.push_loop(loop_hdr, after, False, True);
        }
        g.emit_jump(OP_FOR_ITER, after.id, iter_loc);
        store = visit_store_target_tos(g, f.target);
        if codegen_busy(g) {
            g.pop_loop();
            return stmt_cont(loc=store.loc);
        }
        body_snap = len(current_pending_break_finishes());
        body_cont = visit_stmts(g, f.body, 0, False, None, 0, None, ann_ctx);
        if codegen_busy(g) {
            g.pop_loop();
            return stmt_cont(loc=body_cont.loc);
        }
        if not body_cont.terminated {
            # Artificial like CPython's NO_LOCATION back edge: the copied jump
            # on each break edge must carry no line, and the all-artificial
            # predicate in finish_break_sites keys off it.
            g.emit_jump(OP_JUMP_BACKWARD, loop_hdr.id, no_loc());
        }
        g.pop_loop();
        g.loop_except_depth_bump = g.loop_except_depth_bump - 1;
        flush_pending_break_finishes(g, body_snap);
        g.use(after);
        g.emit_op(OP_END_FOR, 0, iter_loc);
        g.emit_op(OP_POP_ITER, 0, iter_loc);
        if has_break {
            # Our own continuation gains the caller's back edge after we
            # return; defer like the tail-is-None path above.
            push_pending_break_finish(break_frame, join, False);
            g.use(join);
        }
        return stmt_cont(loc=floc);
    }
    # Module/unit-final loop (no enclosing loop, nothing follows): same shared
    # continuation shape as CPython. The unit driver appends its implicit
    # return into the continuation for the natural path; finish_break_sites
    # synthesizes that epilogue over each break edge now.
    after = g.new_deferred_block();
    # The unconditional bump at the loop head already counts this loop's
    # iterator exactly once; region depths must not double-count it.
    try_in_body = loop_body_has_try(f.body);
    try_exit_blk: basicblock | None = None;
    if try_in_body {
        tmp_blk: basicblock = g.new_deferred_block();
        # Pure splice source for finish_break_sites: every break edge inlines
        # its contents, so once breaks finish the block has no incoming edge.
        # exit_inline_ok lets remove_unreachable_blocks drop it (same idiom as
        # match's join/end blocks); without it the dead return bytes would
        # survive into co_code.
        tmp_blk.exit_inline_ok = True;
        try_exit_blk = tmp_blk;
        g.loop_exit_before_try_handlers = try_exit_blk;
        # Oracle contract (3.14): a break edge unwinds the iterator with its
        # own POP_TOP and then inlines the plain continuation return; the
        # END_FOR/POP_ITER pair belongs only to the FOR_ITER exhaustion path
        # (after). Mirrors visit_while, which never sets this flag.
        g.loop_exit_emits_end_for = False;
        if has_break and len(f.orelse) == 0 {
            g.unit_for_after = after;
            g.unit_for_after_loc = iter_loc;
        }
    }
    if has_break {
        if try_in_body {
            g.push_loop(loop_hdr, try_exit_blk as basicblock, True, True);
            break_frame = g.current_loop() as loop_frame;
            break_frame.pops_iter = True;
        } else {
            join = g.new_deferred_block();
            g.push_loop(loop_hdr, join, True, True);
            break_frame = g.current_loop() as loop_frame;
            break_frame.pops_iter = True;
        }
    } else {
        g.push_loop(loop_hdr, after, False, True);
        join = after;
    }
    g.emit_jump(OP_FOR_ITER, after.id, iter_loc);
    store = visit_store_target_tos(g, f.target);
    if codegen_busy(g) {
        g.pop_loop();
        return stmt_cont(loc=store.loc);
    }
    body_snap = len(current_pending_break_finishes());
    body_cont = visit_stmts(g, f.body, 0, False, None, 0, None, ann_ctx);
    if codegen_busy(g) {
        g.pop_loop();
        return stmt_cont(loc=body_cont.loc);
    }
    if not body_cont.terminated {
        g.emit_jump(OP_JUMP_BACKWARD, loop_hdr.id, body_cont.loc);
    }
    g.pop_loop();
    flush_pending_break_finishes(g, body_snap);
    if try_in_body {
        g.loop_exit_before_try_handlers = None;
        g.loop_exit_return_loc = None;
        g.loop_exit_emits_end_for = False;
        g.unit_for_after = None;
        g.unit_for_after_loc = None;
    }
    epilogue_done = g.loop_exit_epilogue_complete;
    g.loop_exit_epilogue_complete = False;
    if not after.placed {
        g.use(after);
        g.emit_op(OP_END_FOR, 0, iter_loc);
        g.emit_op(OP_POP_ITER, 0, iter_loc);
    }
    else_terminated = False;
    if len(f.orelse) > 0 and not epilogue_done {
        else_snap = len(current_pending_break_finishes());
        else_cont = visit_stmts(g, f.orelse, 0, False, None, 0, None, ann_ctx);
        if codegen_busy(g) {
            return stmt_cont(loc=else_cont.loc);
        }
        flush_pending_break_finishes(g, else_snap);
        else_terminated = else_cont.terminated;
    }
    if try_in_body and not (try_exit_blk as basicblock).placed {
        # visit_try never materialized the break exit (no protected span
        # ended at a break boundary). Place the bare continuation return so
        # finish_break_sites splices a terminated join instead of leaving a
        # dangling break target. Mirrors visit_while's exit_blk fallback.
        g.use(try_exit_blk as basicblock);
        emit_module_return(g, iter_loc);
    }
    if has_break {
        if try_in_body {
            break_join = try_exit_blk as basicblock;
        } else {
            g.use(join);
            break_join = join;
        }
        join_epilogue = break_join.placed and block_is_terminated(break_join);
        finish_break_sites(g, break_frame, break_join, iter_loc, join_epilogue, False);
        # The unit driver must append the natural-path return only when the
        # exhaustion block is still open: with the visit_try hook it is
        # already terminated, and a terminated back-edge block must not take
        # dead epilogue bytes.
        exhausted = after.placed and block_is_terminated(after);
        return stmt_cont(
            loc=iter_loc,
            terminated=else_terminated or exhausted or block_is_terminated(g.cur)
        );
    }
    if block_is_terminated(g.cur) {
        return stmt_cont(loc=iter_loc, terminated=True);
    }
    if else_terminated {
        return stmt_cont(loc=iter_loc, terminated=True);
    }
    return stmt_cont(loc=iter_loc, terminated=False);
}


def visit_async_for(
    g: cfg_builder,
    af: AsyncFor,
    more_code_follows: bool,
    tail: list[stmt],
    tail_idx: int,
    ann_ctx: ann_scope_plan | None = None
) -> stmt_cont {
    floc = nloc(af.lineno, af.end_lineno, af.col_offset, af.end_col_offset);
    iter_loc = expr_loc(af.iter);
    visit_expr(g, af.iter);
    if codegen_busy(g) {
        return stmt_cont(loc=floc);
    }
    g.emit_op(OP_GET_AITER, 0, iter_loc);
    loop_hdr = g.new_block();
    has_break = loop_body_has_break(af.body);
    als = emit_anext_send_loop_header(g, loop_hdr, 3, iter_loc);
    if more_code_follows {
        store_blk = g.new_block();
        g.use(store_blk);
        g.emit_op(OP_NOT_TAKEN, 0, iter_loc);
        break_tgt = loop_hdr;
        if has_break {
            break_tgt = g.new_block();
        }
        g.push_loop(loop_hdr, break_tgt, has_break, True);
        if has_break {
            # Break sites emit the iterator POP_TOP themselves (CPython unwind).
            af_frame = g.current_loop() as loop_frame;
            af_frame.pops_iter = True;
        }
        store = visit_store_target_tos(g, af.target);
        if codegen_busy(g) {
            g.pop_loop();
            return stmt_cont(loc=store.loc);
        }
        body_cont = visit_stmts(g, af.body, 0, False, None, 0, None, ann_ctx);
        if codegen_busy(g) {
            g.pop_loop();
            return stmt_cont(loc=body_cont.loc);
        }
        if not body_cont.terminated {
            g.emit_jump(OP_JUMP_BACKWARD, loop_hdr.id, body_cont.loc);
        }
        g.pop_loop();
        (cleanup_throw, cleanup_jump) = emit_anext_send_loop_footer(g, als, iter_loc);
        end_async_handler = g.new_block();
        emit_anext_send_except_regions(
            g, als, store_blk, cleanup_throw, cleanup_jump, end_async_handler
        );
        g.u.except_regions.append(
            except_region(
                start_block=store_blk.id,
                end_block=cleanup_throw.id,
                handler_block=-1,
                stack_depth=2,
                preserve_lasti=True
            )
        );
        g.u.pending_pep479_regions.append(len(g.u.except_regions) - 1);
        tail_more = exec_tail_emits_code(tail, tail_idx);
        after = g.new_block();
        if has_break {
            # The per-site iterator POP_TOP already ran at each break; this
            # convergence block only routes to the continuation.
            g.use(break_tgt);
            if tail_more {
                g.emit_jump(OP_JUMP_FORWARD, after.id, iter_loc);
            } else {
                br_cont = emit_tail_and_finish(g, tail, tail_idx, floc, ann_ctx);
                if codegen_busy(g) {
                    return br_cont;
                }
            }
        }
        g.use(end_async_handler);
        g.emit_jump(OP_END_ASYNC_FOR, als.end_send_blk.id, iter_loc);
        g.async_for_end_async_block = end_async_handler.id;
        g.u.except_regions.append(
            except_region(
                start_block=end_async_handler.id,
                end_block=-1,
                handler_block=-1,
                stack_depth=2,
                preserve_lasti=True
            )
        );
        g.u.pending_pep479_regions.append(len(g.u.except_regions) - 1);
        g.use(after);
        if len(af.orelse) > 0 {
            else_cont = visit_stmts(g, af.orelse, 0, False, None, 0, None, ann_ctx);
            if codegen_busy(g) {
                return stmt_cont(loc=else_cont.loc);
            }
        }
        if has_break and not tail_more {
            return stmt_cont(loc=floc, next_si=len(tail), terminated=True);
        }
        tail_cont = visit_stmt_tail(
            g, tail, tail_idx, exec_tail_emits_code(tail, tail_idx + 1), ann_ctx
        );
        return stmt_cont(
            loc=tail_cont.loc, next_si=len(tail), terminated=tail_cont.terminated
        );
    }
    needs_break_stub = has_break;
    store_blk = g.new_block();
    g.use(store_blk);
    g.emit_op(OP_NOT_TAKEN, 0, iter_loc);
    break_tgt = loop_hdr;
    if needs_break_stub {
        break_tgt = g.new_block();
    }
    g.push_loop(loop_hdr, break_tgt, needs_break_stub, True);
    if needs_break_stub {
        # Break sites emit the iterator POP_TOP themselves (CPython unwind).
        af_frame = g.current_loop() as loop_frame;
        af_frame.pops_iter = True;
    }
    store = visit_store_target_tos(g, af.target);
    if codegen_busy(g) {
        g.pop_loop();
        return stmt_cont(loc=store.loc);
    }
    body_cont = visit_stmts(g, af.body, 0, False, None, 0, None, ann_ctx);
    if codegen_busy(g) {
        g.pop_loop();
        return stmt_cont(loc=body_cont.loc);
    }
    if not body_cont.terminated {
        g.emit_jump(OP_JUMP_BACKWARD, loop_hdr.id, body_cont.loc);
    }
    g.pop_loop();
    (cleanup_throw, cleanup_jump) = emit_anext_send_loop_footer(g, als, iter_loc);
    end_async_handler = g.new_block();
    emit_anext_send_except_regions(
        g, als, store_blk, cleanup_throw, cleanup_jump, end_async_handler
    );
    g.u.except_regions.append(
        except_region(
            start_block=store_blk.id,
            end_block=cleanup_throw.id,
            handler_block=-1,
            stack_depth=2,
            preserve_lasti=True
        )
    );
    g.u.pending_pep479_regions.append(len(g.u.except_regions) - 1);
    if needs_break_stub {
        g.use(break_tgt);
        emit_module_return(g, iter_loc);
    }
    after = g.new_block();
    g.use(end_async_handler);
    g.emit_jump(OP_END_ASYNC_FOR, als.end_send_blk.id, iter_loc);
    g.async_for_end_async_block = end_async_handler.id;
    g.u.except_regions.append(
        except_region(
            start_block=end_async_handler.id,
            end_block=-1,
            handler_block=-1,
            stack_depth=2,
            preserve_lasti=True
        )
    );
    g.u.pending_pep479_regions.append(len(g.u.except_regions) - 1);
    g.use(after);
    if len(af.orelse) > 0 {
        else_cont = visit_stmts(g, af.orelse, 0, False, None, 0, None, ann_ctx);
        if codegen_busy(g) {
            return stmt_cont(loc=else_cont.loc);
        }
        emit_module_return(g, else_cont.loc);
    } else {
        emit_module_return(g, iter_loc);
    }
    return stmt_cont(loc=floc, terminated=True);
}

# Wire statement-dispatch handlers into the leaf registry (see
# compiler_dispatch.jac). Runs at module load via `with entry`; entry
# drivers (product_compile, compiler_slice) import this module so the
# registration always precedes the first compile. Dict item assignment
# mutates the holder in place (scalar-glob rebinding would be local).
with entry {
    stmt_handlers["visit_if"] = visit_if;
    stmt_handlers["visit_while"] = visit_while;
    stmt_handlers["visit_for"] = visit_for;
    stmt_handlers["visit_async_for"] = visit_async_for;
}
