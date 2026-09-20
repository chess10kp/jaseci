import base64;
import hashlib;
import os;
import struct;


impl WebSocket._handshake(host: str, port: int) {
    key = base64.b64encode(os.urandom(16)).decode();
    req = (
        f"GET {self.path} HTTP/1.1\r\n"
        f"Host: {host}:{port}\r\n"
        "Upgrade: websocket\r\n"
        "Connection: Upgrade\r\n"
        f"Sec-WebSocket-Key: {key}\r\n"
        "Sec-WebSocket-Version: 13\r\n\r\n"
    );
    self.sock.sendall(req.encode());
    header = self._read_until("\r\n\r\n".encode());
    status = header.split("\r\n".encode(), 1)[0];
    if "101".encode() not in status {
        raise ConnectionError(f"WebSocket upgrade failed: {status}");
    }

    guid = "258EAFA5-E914-47DA-95CA-C5AB0DC85B11";
    expected = base64.b64encode(hashlib.sha1((key + guid).encode()).digest()).decode();
    if expected.encode() not in header {
        raise ConnectionError("WebSocket Sec-WebSocket-Accept mismatch");
    }
}

impl WebSocket._read_until(delim: bytes) -> bytes {
    while delim not in self._buf {
        chunk = self.sock.recv(4096);
        if not chunk {
            raise ConnectionError("connection closed during handshake");
        }
        self._buf.extend(chunk);
    }
    idx = self._buf.index(delim) + len(delim);
    head = bytes(self._buf[:idx]);
    self._buf = self._buf[idx:];
    return head;
}

impl WebSocket._recv_exact(n: int) -> bytes {
    while len(self._buf) < n {
        chunk = self.sock.recv(65536);
        if not chunk {
            raise ConnectionError("connection closed mid-frame");
        }
        self._buf.extend(chunk);
    }
    out = bytes(self._buf[:n]);
    self._buf = self._buf[n:];
    return out;
}

impl WebSocket.send(data: (str | bytes), opcode: int = OP_TEXT) {
    payload = data.encode() if isinstance(data, str) else data;
    b0 = 0x80 | opcode;
    header = bytearray([b0]);
    ln = len(payload);
    if ln < 126 {
        header.append(0x80 | ln);
    } elif ln < 65536 {
        header.append(0x80 | 126);
        header.extend(struct.pack("!H", ln));
    } else {
        header.append(0x80 | 127);
        header.extend(struct.pack("!Q", ln));
    }
    mask = os.urandom(4);
    header.extend(mask);
    masked = bytes([payload[i] ^ mask[i % 4] for i in range(ln)]);
    self.sock.sendall(bytes(header) + masked);
}

impl WebSocket._read_frame -> tuple[bool, int, bytes] {
    (b0, b1) = self._recv_exact(2);
    fin = (b0 & 0x80) != 0;
    opcode = b0 & 0x0F;
    masked = (b1 & 0x80) != 0;
    ln = b1 & 0x7F;
    if ln == 126 {
        ln = struct.unpack("!H", self._recv_exact(2))[0];
    } elif ln == 127 {
        ln = struct.unpack("!Q", self._recv_exact(8))[0];
    }
    mask = self._recv_exact(4) if masked else bytes();
    payload = self._recv_exact(ln);
    if masked {
        payload = bytes([payload[i] ^ mask[i % 4] for i in range(ln)]);
    }
    return (fin, opcode, payload);
}

impl WebSocket.recv -> (str | bytes) {
    chunks = bytearray();
    op_started = 0;
    while True {
        (fin, opcode, payload) = self._read_frame();
        if opcode == OP_PING {
            self.send(payload, opcode=OP_PONG);
            continue;
        }
        if opcode == OP_PONG {
            continue;
        }
        if opcode == OP_CLOSE {
            raise ConnectionError("server closed WebSocket");
        }
        if opcode != 0 {
            op_started = opcode;
        }
        chunks.extend(payload);
        if fin {
            return chunks.decode() if op_started == OP_TEXT else bytes(chunks);
        }
    }
}

impl WebSocket.close{
    try {
        self.send(bytes(), opcode=OP_CLOSE);
    } except OSError {}
    self.sock.close();
}
