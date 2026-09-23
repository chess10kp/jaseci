import urllib.request;

with entry {
    resp = urllib.request.urlopen("http://127.0.0.1:8123/hello");
    print("urlopen ok");
}
