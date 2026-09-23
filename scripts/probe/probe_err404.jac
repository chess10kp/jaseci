import urllib.request;
import urllib.error;

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
    req = urllib.request.Request("http://127.0.0.1:8123/missing");
    try {
        resp = op.open(req);
        print("open ok (no raise)");
    } except urllib.error.HTTPError {
        print("caught HTTPError");
    } except Exception {
        print("caught other");
    }
}
