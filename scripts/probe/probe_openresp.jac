import urllib.request;

with entry {
    op = urllib.request.OpenerDirector();
    op.add_handler(urllib.request.HTTPHandler());
    op.add_handler(urllib.request.HTTPErrorProcessor());
    print("built resp");
    req = urllib.request.Request("http://127.0.0.1:8123/hello");
    resp = op.open(req);
    print("open resp ok");
}
