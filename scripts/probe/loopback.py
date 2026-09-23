from http.server import BaseHTTPRequestHandler, HTTPServer
class H(BaseHTTPRequestHandler):
    def do_GET(self):
        if self.path == "/hello":
            body = b"hello world"
            self.send_response(200); self.send_header("Content-Type","text/plain; charset=utf-8")
            self.send_header("Content-Length", str(len(body))); self.end_headers(); self.wfile.write(body)
        elif self.path == "/redirect":
            self.send_response(301); self.send_header("Location","/hello")
            self.send_header("Content-Length","0"); self.end_headers()
        else:
            self.send_response(404); self.send_header("Content-Length","0"); self.end_headers()
    def log_message(self, *a): pass
import sys; HTTPServer(("127.0.0.1", int(sys.argv[1])), H).serve_forever()
