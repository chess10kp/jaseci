import json;
import time;


impl CDP.call(
    method: str, params: (dict[str, any] | None) = None, timeout: float = 30.0
) -> dict[str, any] {
    self._id += 1;
    msg_id = self._id;
    self.ws.send(json.dumps({"id": msg_id, "method": method, "params": params or {}}));
    deadline = time.time() + timeout;
    while time.time() < deadline {
        msg = json.loads(self.ws.recv());
        if msg.get("id") == msg_id {
            if "error" in msg {
                raise RuntimeError(f"{method}: {msg['error']}");
            }
            return msg.get("result", {});
        }
        if "method" in msg {
            self.events.append(msg);
        }
    }
    raise TimeoutError(f"CDP call timed out: {method}");
}

impl CDP.drain_events(idle: float = 0.25) -> list[dict[str, any]] {
    self.ws.sock.settimeout(idle);
    try {
        while True {
            try {
                msg = json.loads(self.ws.recv());
            } except OSError {
                break;
            }
            if "method" in msg {
                self.events.append(msg);
            }
        }
    } finally {
        self.ws.sock.settimeout(self.ws.timeout);
    }
    out = self.events;
    self.events = [];
    return out;
}

impl CDP.close{
    self.ws.close();
}
