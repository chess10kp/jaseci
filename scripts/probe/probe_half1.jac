import urllib.request;

with entry {
    op = urllib.request.OpenerDirector();
    op.add_handler(urllib.request.ProxyHandler());
    op.add_handler(urllib.request.UnknownHandler());
    op.add_handler(urllib.request.HTTPHandler());
    op.add_handler(urllib.request.HTTPDefaultErrorHandler());
    op.add_handler(urllib.request.HTTPRedirectHandler());
    print("built half1");
    req = urllib.request.Request("http://127.0.0.1:8123/hello");
    resp = op.open(req);
    print("open half1 ok");
}
