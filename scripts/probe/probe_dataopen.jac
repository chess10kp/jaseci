import urllib.request;

with entry {
    resp = urllib.request.urlopen("data:,hello%20world");
    print("data urlopen ok");
}
