import urllib.request;

with entry {
    print("u2p", urllib.request.url2pathname("/tmp/a%20b"));
    print("p2u", urllib.request.pathname2url("/tmp/a b"));
    pb = urllib.request.proxy_bypass_environment("ex.com", {"no": "ex.com,sub.ex.com"});
    print("pb1", pb);
    pb2 = urllib.request.proxy_bypass_environment("other.com", {"no": "ex.com"});
    print("pb2", pb2);
    gp = urllib.request.getproxies_environment();
    print("gp", len(gp));
}
