import urllib.request;

with entry {
    r = urllib.request.Request("http://127.0.0.1:8123/hello");
    print("host:", r.host, "sel:", r.selector);
    h = urllib.request.HTTPHandler();
    resp = h.http_open(r);
    print("http_open ok");
}
