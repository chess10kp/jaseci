import urllib.request;

with entry {
    op = urllib.request.OpenerDirector();
    op.add_handler(urllib.request.ProxyHandler());
    op.add_handler(urllib.request.UnknownHandler());
    op.add_handler(urllib.request.HTTPHandler());
    op.add_handler(urllib.request.HTTPDefaultErrorHandler());
    op.add_handler(urllib.request.HTTPRedirectHandler());
    op.add_handler(urllib.request.HTTPErrorProcessor());
    op.add_handler(urllib.request.DataHandler());
    op.add_handler(urllib.request.HTTPSHandler());
    print("built 8");
    req = urllib.request.Request("http://127.0.0.1:8123/hello");
    resp = op.open(req);
    if isinstance(resp, urllib.request.HTTPResp) {
        r: urllib.request.HTTPResp = resp;
        c = r.code;
        if c != None {
            ci: int = c;
            print("code " + str(ci));
        } else {
            print("code null");
        }
        u = r.url;
        print("url " + u);
        b = r.read();
        if isinstance(b, bytes) {
            bb: bytes = b;
            print("body " + bb.decode());
        } else {
            print("body non-bytes");
        }
    } else {
        print("not HTTPResp");
    }
}
