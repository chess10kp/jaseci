"""Test that root resolves correctly as a special var ref."""

node Item {
    has name: str;
}

glob
     # bare root reference
     r = root;
with entry {
    print(type(r).__name__);

    # root in graph operations
    root ++> Item(name="a");
    root ++> Item(name="b");
    print(len([root-->]));
}
