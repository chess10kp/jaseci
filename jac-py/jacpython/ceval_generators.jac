# ceval generator/async opcode handlers (jac-py/PLAN.md §4).
# ceval_exec_frame.jac dispatches via try_dispatch_generators.

import from objects {
    PyObj, PyFrame, PyYield, PyGenStop, PyException, py_none, is_error,
}
import from opcode_meta {
    OP_END_ASYNC_FOR, OP_GET_AITER, OP_GET_ANEXT, OP_RETURN_GENERATOR,
    OP_SEND, OP_YIELD_VALUE,
}
import from ceval_exceptions { recover_exception, dispatch_exception, }
import from ceval {
    py_aiter, py_anext, py_raise_value, send_into, send_throw_into,
    _handled_stack_remove_each,
}

def try_dispatch_generators(
    op: int,
    arg: int,
    stack: list[PyObj],
    frame: PyFrame,
    co: PyCode,
    offset: int,
    ip: int,
    exc_handling: list[PyObj],
) -> tuple[bool, tuple[int, PyObj]] {
    if op == OP_GET_AITER {
        iterable = stack.pop();
        aiter = py_aiter(iterable);
        if is_error(aiter) {
            target = recover_exception(co, aiter, offset, stack);
            if target >= 0 {
                return (True, (target, py_none()));
            }
            return (True, (-2, aiter));
        }
        stack.append(aiter);
        return (True, (-1, py_none()));
    }
    if op == OP_GET_ANEXT {
        aiter = stack[len(stack) - 1];
        awaitable = py_anext(aiter);
        if is_error(awaitable) {
            target = recover_exception(co, awaitable, offset, stack);
            if target >= 0 {
                return (True, (target, py_none()));
            }
            return (True, (-2, awaitable));
        }
        stack.append(awaitable);
        return (True, (-1, py_none()));
    }
    if op == OP_END_ASYNC_FOR {
        exc = stack.pop();
        stack.pop();
        exc_name = "";
        if exc.t == "exception" {
            exc_name = (exc as PyException).type_name;
        }
        if exc_name == "StopAsyncIteration" {
            return (True, (-1, py_none()));
        }
        reraised = py_raise_value(exc);
        target = dispatch_exception(co, reraised, offset, offset, stack);
        if target >= 0 {
            return (True, (target, py_none()));
        }
        return (True, (-2, reraised));
    }
    if op == OP_SEND {
        sent = stack[len(stack) - 1];
        receiver = stack[len(stack) - 2];
        if frame.pending_throw is not None {
            thrown_err = frame.pending_throw as PyObj;
            frame.pending_throw = None;
            step = send_throw_into(receiver, thrown_err);
        } else {
            step = send_into(receiver, sent);
        }
        if is_error(step) {
            target = recover_exception(co, step, offset, stack);
            if target >= 0 {
                return (True, (target, py_none()));
            }
            return (True, (-2, step));
        }
        if step.t == "genstop" {
            stack[len(stack) - 1] = (step as PyGenStop).val;
            return (True, (ip + 2 * arg, py_none()));
        }
        stack[len(stack) - 1] = step;
        return (True, (-1, py_none()));
    }
    if op == OP_RETURN_GENERATOR {
        stack.append(py_none());
        return (True, (-1, py_none()));
    }
    if op == OP_YIELD_VALUE {
        value = stack.pop();
        frame.ip = ip;
        frame.yf = arg == 1;
        frame.exc_state = exc_handling;
        _handled_stack_remove_each(exc_handling);
        return (True, (-2, PyYield(t="yield", val=value)));
    }
    return (False, (-1, py_none()));
}
