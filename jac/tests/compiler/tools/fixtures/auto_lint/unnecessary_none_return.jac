"""Fixture for W3037 auto-fix: unnecessary -> None return type."""

def no_return_with_none {
    print("hello");
}

def has_return_with_none -> None {
    return None;
}

def no_return_with_type -> int {
    print("hello");
}

def with_params(x: int, y: str) {
    print(x, y);
}

obj Foo {
    def method(self: Foo) {
        print("method");
    }
}

def handler {
    lambda (e: str) { print(e); };
    lambda (x: int, y: int) { print(x + y); };
    lambda { print("no params"); };
}
