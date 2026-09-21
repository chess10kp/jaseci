glob hello_world_bytes = b"\x48\x65\x6C\x6C\x6F\x20\x57\x6F\x72\x6C\x64";
with entry {
    print(hello_world_bytes);
    print(type(hello_world_bytes));
}

glob ret_str = r"Hello\\nWorld";
with entry {
    print(ret_str);
}

glob br = br"Hello\\nWorld";
with entry {
    print(br);
    print(type(br));
}

glob rb = rb"Hello\\nWorld";
with entry {
    print(rb);
    print(type(rb));
}
