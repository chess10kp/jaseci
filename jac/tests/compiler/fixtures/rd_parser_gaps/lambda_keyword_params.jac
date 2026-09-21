"""Test unparenthesized lambda with special var ref keyword parameter names."""

glob a = lambda (props: any) -> any { return props; };
with entry {
    print(a("hello"));
}

glob b = lambda (`root: any) -> any { return `root; };
with entry {
    print(b("world"));
}

glob c = lambda (here: any) -> any { return here; };
with entry {
    print(c("!"));
}
