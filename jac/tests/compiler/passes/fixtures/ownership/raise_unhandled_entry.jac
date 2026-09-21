"""E1407 (enforced): a call to a raising function from an entry block that neither handles nor declares the raise."""

def parse_port(s: &str) -> int {
    if len(s) == 0 {
        raise ValueError("empty port");
    }
    return int(s);
}

def load(s: &str) -> int {
    return parse_port(s) + 1;
}

glob p: own str = "80";
with entry {
    print(load(&p));
}
