glob node_export = {"blah": "blah"};
with entry {
    big_export = {"blah": node_export};
    del big_export["blah"];

    print(big_export);
}
