import urllib.request;
import from urllib.request { HTTPResp }
import from io { BytesIO }

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
    if isinstance(resp, HTTPResp) {
        r: HTTPResp = resp;
        c = r.code;
        if c != None {
            ci: int = c;
            print("code " + str(ci));
        } else {
            print("code null");
        }
        print("url " + r.url);
        print("blen " + str(r.body_length));
        f = r.fp;
        if isinstance(f, BytesIO) {
            print("fp is BytesIO");
            bb: BytesIO = f;
            print("body " + bb.read().decode());
        } else {
            print("fp not BytesIO");
        }
    } else {
        print("not HTTPResp");
    }
}
