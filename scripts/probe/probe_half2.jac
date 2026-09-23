import urllib.request;

with entry {
    op = urllib.request.OpenerDirector();
    op.add_handler(urllib.request.HTTPHandler());
    op.add_handler(urllib.request.FTPHandler());
    op.add_handler(urllib.request.FileHandler());
    op.add_handler(urllib.request.HTTPErrorProcessor());
    op.add_handler(urllib.request.DataHandler());
    op.add_handler(urllib.request.HTTPSHandler());
    print("built half2");
    req = urllib.request.Request("http://127.0.0.1:8123/hello");
    resp = op.open(req);
    print("open half2 ok");
}
