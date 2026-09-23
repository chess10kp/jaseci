import urllib.request;

with entry {
    r = urllib.request.Request("http://127.0.0.1:8123/hello");
    h = urllib.request.HTTPHandler();
    r2 = h.request_for("http", r);
    print("request_for ok", r2.get_method());
    e = urllib.request.HTTPErrorProcessor();
    resp = h.http_open(r2);
    print("http_open ok");
    out = e.http_response(r2, resp);
    print("http_response ok");
}
