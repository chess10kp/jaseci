import from _socketserver_native { proc_fork, proc_waitpid, proc_exit }
import from socket {
    socket as Socket,
    SockFile,
    SOL_SOCKET,
    SO_REUSEADDR,
    SO_REUSEPORT,
    IPPROTO_TCP,
    TCP_NODELAY,
    SHUT_WR
}
import from select { select as _select }
import from io { BytesIO }
import sys;


obj:pub BaseServer {
    has socket: Socket,
        server_address: tuple[(str, int, int, int)],
        RequestHandlerClass: BaseRequestHandler,
        timeout: (int | float | None) = None,
        address_family: int = 2,
        socket_type: int = 1,
        request_queue_size: int = 5,
        allow_reuse_address: bool = False,
        allow_reuse_port: bool = False,
        _shutdown_request: bool = False,
        _is_shut_down: bool = True;

    def server_setup(
        server_address: tuple[(str, int, int, int)], handler: BaseRequestHandler
    ) {
        self.server_address = server_address;
        self.RequestHandlerClass = handler;
    }

    def fileno -> int {
        return self.socket.fileno();
    }

    def handle_request {
        r = _select([self.socket.fileno()], [], [], self.timeout);
        if len(r[0]) == 0 {
            self.handle_timeout();
            return;
        }
        self.handle_request_noblock();
    }

    def handle_request_noblock {}

    def serve_forever(poll_interval: float = 0.5) {
        self._is_shut_down = False;
        try {
            while not self._shutdown_request {
                r = _select([self.socket.fileno()], [], [], poll_interval);
                if self._shutdown_request {
                    break;
                }
                if len(r[0]) > 0 {
                    self.handle_request_noblock();
                }
                self.service_actions();
            }
        } finally {
            self._shutdown_request = False;
            self._is_shut_down = True;
        }
    }

    def shutdown {
        self._shutdown_request = True;
    }

    def service_actions {}

    def handle_timeout {}

    def verify_request(
        request: Socket, client_address: tuple[(str, int, int, int)]
    ) -> bool {
        return True;
    }

    def process_request(request: Socket, client_address: tuple[(str, int, int, int)]) {
        self.finish_request(request, client_address);
        self.shutdown_request(request);
    }

    def finish_request(request: Socket, client_address: tuple[(str, int, int, int)]) {
        ok = self.RequestHandlerClass.run(request, client_address, self);
    }

    def shutdown_request(request: Socket) {
        self.close_request(request);
    }

    def close_request(request: Socket) {}

    def handle_error(request: Socket, client_address: tuple[(str, int, int, int)]) {
        sys.stderr.write("Exception occurred during processing of request\n");
    }

    def server_close {}

    def server_bind {}

    def server_activate {}

    def enter -> BaseServer {
        return self;
    }

    def `exit {
        self.server_close();
    }
}


obj:pub TCPServer(BaseServer) {
    def:pub boot(
        server_address: tuple[(str, int, int, int)],
        handler_class: BaseRequestHandler,
        bind_and_activate: bool
    ) {
        self.server_setup(server_address, handler_class);
        self.socket = Socket(family=self.address_family, socktype=self.socket_type);
        if bind_and_activate {
            try {
                self.server_bind();
                self.server_activate();
            } except OSError as e {
                self.server_close();
                raise e;
            }
        }
    }

    def init(
        server_address: tuple[(str, int)],
        RequestHandlerClass: BaseRequestHandler,
        bind_and_activate: bool = True
    ) {
        self.boot(
            (server_address[0], server_address[1], 0, 0),
            RequestHandlerClass,
            bind_and_activate
        );
    }

    def handle_request {
        r = _select([self.socket.fileno()], [], [], self.timeout);
        if len(r[0]) == 0 {
            self.handle_timeout();
            return;
        }
        self.handle_request_noblock();
    }

    def serve_forever(poll_interval: float = 0.5) {
        self._is_shut_down = False;
        try {
            while not self._shutdown_request {
                r = _select([self.socket.fileno()], [], [], poll_interval);
                if self._shutdown_request {
                    break;
                }
                if len(r[0]) > 0 {
                    self.handle_request_noblock();
                }
                self.service_actions();
            }
        } finally {
            self._shutdown_request = False;
            self._is_shut_down = True;
        }
    }

    def server_bind {
        if self.allow_reuse_address {
            self.socket.setsockopt(SOL_SOCKET, SO_REUSEADDR, 1);
        }
        if self.allow_reuse_port
            and (self.address_family == 2 or self.address_family == 10) {
            self.socket.setsockopt(SOL_SOCKET, SO_REUSEPORT, 1);
        }
        self.socket.bind_addr(self.server_address);
        self.server_address = self.socket.getsockname();
    }

    def server_activate {
        self.socket.listen(self.request_queue_size);
    }

    def server_close {
        self.socket.close();
    }

    def get_request -> tuple[(Socket, tuple[(str, int, int, int)])] {
        return self.socket.accept();
    }

    def handle_request_noblock {
        request: Socket = self.socket;
        client_address: tuple[(str, int, int, int)] = ("", 0, 0, 0);
        try {
            gr = self.get_request();
            request = gr[0];
            client_address = gr[1];
        } except OSError {
            return;
        }
        if not self.verify_request(request, client_address) {
            self.shutdown_request(request);
            return;
        }
        try {
            self.process_request(request, client_address);
        } except Exception {
            self.handle_error(request, client_address);
            self.shutdown_request(request);
        }
    }

    def process_request(request: Socket, client_address: tuple[(str, int, int, int)]) {
        self.finish_request(request, client_address);
        self.shutdown_request(request);
    }

    def shutdown_request(request: Socket) {
        try {
            request.shutdown(SHUT_WR);
        } except OSError {}
        self.close_request(request);
    }

    def close_request(request: Socket) {
        request.close();
    }
}


obj:pub UDPServer(TCPServer) {
    has max_packet_size: int = 8192;

    def init(
        server_address: tuple[(str, int)],
        RequestHandlerClass: BaseRequestHandler,
        bind_and_activate: bool = True
    ) {
        self.boot(
            (server_address[0], server_address[1], 0, 0),
            RequestHandlerClass,
            bind_and_activate
        );
    }

    def:pub boot(
        server_address: tuple[(str, int, int, int)],
        handler_class: BaseRequestHandler,
        bind_and_activate: bool
    ) {
        self.socket_type = 2;
        self.server_setup(server_address, handler_class);
        self.socket = Socket(family=self.address_family, socktype=self.socket_type);
        if bind_and_activate {
            try {
                self.server_bind();
                self.server_activate();
            } except OSError as e {
                self.server_close();
                raise e;
            }
        }
    }

    def server_activate {}

    def handle_request {
        r = _select([self.socket.fileno()], [], [], self.timeout);
        if len(r[0]) == 0 {
            self.handle_timeout();
            return;
        }
        self.handle_request_noblock();
    }

    def serve_forever(poll_interval: float = 0.5) {
        self._is_shut_down = False;
        try {
            while not self._shutdown_request {
                r = _select([self.socket.fileno()], [], [], poll_interval);
                if self._shutdown_request {
                    break;
                }
                if len(r[0]) > 0 {
                    self.handle_request_noblock();
                }
                self.service_actions();
            }
        } finally {
            self._shutdown_request = False;
            self._is_shut_down = True;
        }
    }

    def get_request -> tuple[(tuple[(bytes, Socket)], tuple[(str, int, int, int)])] {
        pr = self.socket.recvfrom(self.max_packet_size);
        return ((pr[0], self.socket), pr[1]);
    }

    def handle_request_noblock {
        request: tuple[(bytes, Socket)] = (b"", self.socket);
        client_address: tuple[(str, int, int, int)] = ("", 0, 0, 0);
        try {
            gr = self.get_request();
            request = gr[0];
            client_address = gr[1];
        } except OSError {
            return;
        }
        if not self.verify_request(request, client_address) {
            self.shutdown_request(request);
            return;
        }
        try {
            self.process_request(request, client_address);
        } except Exception {
            self.handle_error(request, client_address);
            self.shutdown_request(request);
        }
    }

    def verify_request(
        request: tuple[(bytes, Socket)], client_address: tuple[(str, int, int, int)]
    ) -> bool {
        return True;
    }

    def process_request(
        request: tuple[(bytes, Socket)], client_address: tuple[(str, int, int, int)]
    ) {
        self.finish_request(request, client_address);
        self.shutdown_request(request);
    }

    def finish_request(
        request: tuple[(bytes, Socket)], client_address: tuple[(str, int, int, int)]
    ) {
        ok = self.RequestHandlerClass.run(request, client_address, self);
    }

    def shutdown_request(request: tuple[(bytes, Socket)]) {
        self.close_request(request);
    }

    def close_request(request: tuple[(bytes, Socket)]) {}

    def handle_error(
        request: tuple[(bytes, Socket)], client_address: tuple[(str, int, int, int)]
    ) {
        sys.stderr.write("Exception occurred during processing of request\n");
    }
}


obj:pub UnixStreamServer(TCPServer) {
    def init(
        server_address: str,
        RequestHandlerClass: BaseRequestHandler,
        bind_and_activate: bool = True
    ) {
        self.address_family = 1;
        self.boot((server_address, 0, 0, 0), RequestHandlerClass, bind_and_activate);
    }
}


obj:pub UnixDatagramServer(UDPServer) {
    def init(
        server_address: str,
        RequestHandlerClass: BaseRequestHandler,
        bind_and_activate: bool = True
    ) {
        self.address_family = 1;
        self.socket_type = 2;
        self.boot((server_address, 0, 0, 0), RequestHandlerClass, bind_and_activate);
    }
}


obj:pub ThreadingMixIn {
    has daemon_threads: bool = False,
        block_on_close: bool = True;
}


obj:pub ThreadingTCPServer(ThreadingMixIn, TCPServer) {
    def process_request_thread(
        request: Socket, client_address: tuple[(str, int, int, int)]
    ) {
        try {
            self.finish_request(request, client_address);
        } except Exception {
            self.handle_error(request, client_address);
        } finally {
            self.shutdown_request(request);
        }
    }

    def process_request(request: Socket, client_address: tuple[(str, int, int, int)]) {
        self.process_request_thread(request, client_address);
    }

    def server_close {
        self.socket.close();
    }
}


obj:pub ThreadingUDPServer(ThreadingMixIn, UDPServer) {
    def process_request_thread(
        request: tuple[(bytes, Socket)], client_address: tuple[(str, int, int, int)]
    ) {
        try {
            self.finish_request(request, client_address);
        } except Exception {
            self.handle_error(request, client_address);
        } finally {
            self.shutdown_request(request);
        }
    }

    def process_request(
        request: tuple[(bytes, Socket)], client_address: tuple[(str, int, int, int)]
    ) {
        self.process_request_thread(request, client_address);
    }

    def server_close {
        self.socket.close();
    }
}


obj:pub ThreadingUnixStreamServer(ThreadingMixIn, UnixStreamServer) {
    def init(
        server_address: str,
        RequestHandlerClass: BaseRequestHandler,
        bind_and_activate: bool = True
    ) {
        self.address_family = 1;
        self.boot((server_address, 0, 0, 0), RequestHandlerClass, bind_and_activate);
    }

    def process_request_thread(
        request: Socket, client_address: tuple[(str, int, int, int)]
    ) {
        try {
            self.finish_request(request, client_address);
        } except Exception {
            self.handle_error(request, client_address);
        } finally {
            self.shutdown_request(request);
        }
    }

    def process_request(request: Socket, client_address: tuple[(str, int, int, int)]) {
        self.process_request_thread(request, client_address);
    }

    def server_close {
        self.socket.close();
    }
}


obj:pub ThreadingUnixDatagramServer(ThreadingMixIn, UnixDatagramServer) {
    def init(
        server_address: str,
        RequestHandlerClass: BaseRequestHandler,
        bind_and_activate: bool = True
    ) {
        self.address_family = 1;
        self.socket_type = 2;
        self.boot((server_address, 0, 0, 0), RequestHandlerClass, bind_and_activate);
    }

    def process_request_thread(
        request: tuple[(bytes, Socket)], client_address: tuple[(str, int, int, int)]
    ) {
        try {
            self.finish_request(request, client_address);
        } except Exception {
            self.handle_error(request, client_address);
        } finally {
            self.shutdown_request(request);
        }
    }

    def process_request(
        request: tuple[(bytes, Socket)], client_address: tuple[(str, int, int, int)]
    ) {
        self.process_request_thread(request, client_address);
    }

    def server_close {
        self.socket.close();
    }
}


obj:pub ForkingMixIn {
    has active_children: list[int],
        max_children: int = 40,
        block_on_close: bool = True;

    def fork_init {
        self.active_children = [];
    }

    def collect_children(blocking: bool = False) {
        while len(self.active_children) >= self.max_children {
            pid = proc_waitpid(-1, 0);
            if pid <= 0 {
                self.active_children = [];
                break;
            }
            rest: list[int] = [];
            for p in self.active_children {
                if p != pid {
                    rest.append(p);
                }
            }
            self.active_children = rest;
        }
        rest2: list[int] = [];
        for p in self.active_children {
            fl = 1;
            if blocking {
                fl = 0;
            }
            r = proc_waitpid(p, fl);
            if r == 0 {
                rest2.append(p);
            }
        }
        self.active_children = rest2;
    }
}


obj:pub ForkingTCPServer(ForkingMixIn, TCPServer) {
    def init(
        server_address: tuple[(str, int)],
        RequestHandlerClass: BaseRequestHandler,
        bind_and_activate: bool = True
    ) {
        self.fork_init();
        self.boot(
            (server_address[0], server_address[1], 0, 0),
            RequestHandlerClass,
            bind_and_activate
        );
    }

    def service_actions {
        self.collect_children();
    }

    def handle_timeout {
        self.collect_children();
    }

    def process_request(request: Socket, client_address: tuple[(str, int, int, int)]) {
        pid = proc_fork();
        if pid > 0 {
            self.active_children.append(pid);
            self.close_request(request);
            return;
        }
        status = 1;
        try {
            self.finish_request(request, client_address);
            status = 0;
        } except Exception {
            self.handle_error(request, client_address);
        }
        try {
            self.shutdown_request(request);
        } finally {
            proc_exit(status);
        }
    }

    def server_close {
        self.socket.close();
        self.collect_children(self.block_on_close);
    }
}


obj:pub ForkingUDPServer(ForkingMixIn, UDPServer) {
    def init(
        server_address: tuple[(str, int)],
        RequestHandlerClass: BaseRequestHandler,
        bind_and_activate: bool = True
    ) {
        self.fork_init();
        self.socket_type = 2;
        self.boot(
            (server_address[0], server_address[1], 0, 0),
            RequestHandlerClass,
            bind_and_activate
        );
    }

    def service_actions {
        self.collect_children();
    }

    def handle_timeout {
        self.collect_children();
    }

    def process_request(
        request: tuple[(bytes, Socket)], client_address: tuple[(str, int, int, int)]
    ) {
        pid = proc_fork();
        if pid > 0 {
            self.active_children.append(pid);
            self.close_request(request);
            return;
        }
        status = 1;
        try {
            self.finish_request(request, client_address);
            status = 0;
        } except Exception {
            self.handle_error(request, client_address);
        }
        try {
            self.shutdown_request(request);
        } finally {
            proc_exit(status);
        }
    }

    def server_close {
        self.socket.close();
        self.collect_children(self.block_on_close);
    }
}


obj:pub ForkingUnixStreamServer(ForkingMixIn, UnixStreamServer) {
    def init(
        server_address: str,
        RequestHandlerClass: BaseRequestHandler,
        bind_and_activate: bool = True
    ) {
        self.fork_init();
        self.address_family = 1;
        self.boot((server_address, 0, 0, 0), RequestHandlerClass, bind_and_activate);
    }

    def service_actions {
        self.collect_children();
    }

    def handle_timeout {
        self.collect_children();
    }

    def process_request(request: Socket, client_address: tuple[(str, int, int, int)]) {
        pid = proc_fork();
        if pid > 0 {
            self.active_children.append(pid);
            self.close_request(request);
            return;
        }
        status = 1;
        try {
            self.finish_request(request, client_address);
            status = 0;
        } except Exception {
            self.handle_error(request, client_address);
        }
        try {
            self.shutdown_request(request);
        } finally {
            proc_exit(status);
        }
    }

    def server_close {
        self.socket.close();
        self.collect_children(self.block_on_close);
    }
}


obj:pub ForkingUnixDatagramServer(ForkingMixIn, UnixDatagramServer) {
    def init(
        server_address: str,
        RequestHandlerClass: BaseRequestHandler,
        bind_and_activate: bool = True
    ) {
        self.fork_init();
        self.address_family = 1;
        self.socket_type = 2;
        self.boot((server_address, 0, 0, 0), RequestHandlerClass, bind_and_activate);
    }

    def service_actions {
        self.collect_children();
    }

    def handle_timeout {
        self.collect_children();
    }

    def process_request(
        request: tuple[(bytes, Socket)], client_address: tuple[(str, int, int, int)]
    ) {
        pid = proc_fork();
        if pid > 0 {
            self.active_children.append(pid);
            self.close_request(request);
            return;
        }
        status = 1;
        try {
            self.finish_request(request, client_address);
            status = 0;
        } except Exception {
            self.handle_error(request, client_address);
        }
        try {
            self.shutdown_request(request);
        } finally {
            proc_exit(status);
        }
    }

    def server_close {
        self.socket.close();
        self.collect_children(self.block_on_close);
    }
}


obj:pub BaseRequestHandler {
    has server: BaseServer,
        client_address: tuple[(str, int, int, int)],
        request: any;

    def run(
        request: any, client_address: tuple[(str, int, int, int)], server: BaseServer
    ) -> bool {
        self.request = request;
        self.begin(client_address, server);
        return True;
    }

    def begin(client_address: tuple[(str, int, int, int)], server: BaseServer) {
        self.client_address = client_address;
        self.server = server;
        self.setup();
        try {
            self.handle();
        } finally {
            self.finish();
        }
    }

    def setup {}

    def handle {}

    def finish {}
}


obj:pub StreamRequestHandler(BaseRequestHandler) {
    has connection: Socket,
        rfile: SockFile,
        wfile: SockFile,
        rbufsize: int = -1,
        wbufsize: int = 0,
        disable_nagle_algorithm: bool = False,
        timeout: (int | float | None) = None;

    def init(
        request: Socket, client_address: tuple[(str, int, int, int)], server: BaseServer
    ) {
        self.request = request;
        self.begin(client_address, server);
    }

    def setup {
        req: Socket = self.request;
        self.connection = req;
        if self.disable_nagle_algorithm {
            self.connection.setsockopt(IPPROTO_TCP, TCP_NODELAY, 1);
        }
        self.rfile = self.connection.makefile("rb");
        self.wfile = self.connection.makefile("wb");
    }

    def finish {
        if not self.wfile.closed {
            try {
                self.wfile.flush();
            } except OSError {}
        }
        self.wfile.close();
        self.rfile.close();
    }
}


obj:pub DatagramRequestHandler(BaseRequestHandler) {
    has packet: bytes,
        socket: Socket,
        rfile: BytesIO,
        wfile: BytesIO;

    def init(
        request: tuple[(bytes, Socket)],
        client_address: tuple[(str, int, int, int)],
        server: BaseServer
    ) {
        self.request = request;
        self.begin(client_address, server);
    }

    def setup {
        req: tuple[(bytes, Socket)] = self.request;
        self.packet = req[0];
        self.socket = req[1];
        self.rfile = BytesIO(self.packet);
        self.wfile = BytesIO();
    }

    def finish {
        self.socket.sendto_addr(self.wfile.getvalue(), self.client_address);
    }
}
