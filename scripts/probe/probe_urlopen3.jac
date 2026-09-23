import urllib.request;

with entry {
    req = urllib.request.Request("http://127.0.0.1:8123/hello");
    resp = urllib.request.urlopen(req);
    print("urlopen3 ok");
}
