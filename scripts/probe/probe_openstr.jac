import urllib.request;

with entry {
    op = urllib.request.build_opener();
    print("built");
    resp = op.open("http://127.0.0.1:8123/hello");
    print("open str ok");
}
