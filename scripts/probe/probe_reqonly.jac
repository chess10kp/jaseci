import urllib.request;

with entry {
    r = urllib.request.Request("http://127.0.0.1:8123/hello");
    print("request ok", r.get_method());
}
