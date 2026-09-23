import urllib.request;

with entry {
    host = "127.0.0.1";
    url = "http://" + host + ":8123/hello";
    resp = urllib.request.urlopen(url);
    print("urlopen2 ok");
}
