import socket;

with entry {
    sock = socket.create_connection(("127.0.0.1", 8123));
    sock.sendall(b"GET /hello HTTP/1.1\r\nHost: x\r\nConnection: close\r\n\r\n");
    chunk = sock.recv(8192);
    raw = b"";
    while len(chunk) > 0 {
        raw += chunk;
        chunk = sock.recv(8192);
    }
    sock.close();
    print("socket ok", len(raw));
}
