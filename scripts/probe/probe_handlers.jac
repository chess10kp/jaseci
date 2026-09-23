import urllib.request;

with entry {
    h = urllib.request.ProxyHandler();
    print("handler ok");
    op = urllib.request.OpenerDirector();
    print("director ok");
    op.add_handler(h);
    print("add_handler ok");
    op2 = urllib.request.build_opener();
    print("build_opener ok");
}
