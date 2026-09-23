"""Cross-backend `socketserver` equivalence over the bundled socket floor.

`import socketserver` binds the bundled `na_stdlib/socketserver.jac` module on
the na backend; the sv reference is CPython's real `socketserver`. Both sides
run a self-contained loopback echo: server bound on an ephemeral port, client
connect/send, one `handle_request()` pump, reply read -- the observable
results (bound port, reply bytes, source address) are pinned congruent.

Documented divergence: the bundled server takes a handler *instance*
(`TCPServer(addr, Echo())`) rather than CPython's handler *class*
(`TCPServer(addr, Echo)`) because native Jac cannot invoke a class object held
in a field. na handlers declare a no-arg `init`; the request is delivered via
`run`/`begin` inside `finish_request`.

The native functions return `int` counts of checks held, driven through the
JIT (`get_func`), mirroring `test_socket_equivalence`. ES/JS opts out (no
socket floor).
"""

import from jaclang.compiler.tests.xbackend_equiv {
    run_py_fixture,
    compile_native,
    get_func
}


"""Call a no-arg native `int`-returning fixture function through the JIT."""
def _call_na_int(eng: object, name: str) -> int {
    import ctypes;
    fn = get_func(eng, name, ctypes.c_int64);
    return int(fn());
}


test "socketserver TCP echo over the bundled floor (sv<->na congruent)" {
    py = run_py_fixture("prim_socketserver", "socketserver_py");
    assert py["port_ok"] == 1 , py;
    assert py["tcp"] == 1 , py;

    (eng, _) = compile_native("prim_socketserver.jac");
    assert _call_na_int(eng, "sserver_tcp_na") == 4 , (
        "TCP echo path (bind/accept/handler/reply/close)"
    );

    # serve_forever + handler-driven shutdown (na divergence: shutdown is a
    # flag, callable same-thread; CPython's blocks for an inter-thread ack).
    assert _call_na_int(eng, "sserver_forever_na") == 3 , (
        "serve_forever loop + handler shutdown"
    );
}


test "socketserver UDP echo over the bundled floor (sv<->na congruent)" {
    py = run_py_fixture("prim_socketserver", "socketserver_udp_py");
    assert py["port_ok"] == 1 , py;
    assert py["udp"] == 1 , py;
    assert py["addr"] == 1 , py;

    (eng, _) = compile_native("prim_socketserver.jac");
    assert _call_na_int(eng, "sserver_udp_na") == 3 , (
        "UDP echo path (bind/recvfrom/handler/sendto/source-addr)"
    );
}
