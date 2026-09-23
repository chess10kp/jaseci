import urllib.request;

with entry {
    op = urllib.request.build_opener();
    print("built");
    req = urllib.request.Request("http://127.0.0.1:8123/hello");
    resp = op.open(req);
    print("open req ok");
}
