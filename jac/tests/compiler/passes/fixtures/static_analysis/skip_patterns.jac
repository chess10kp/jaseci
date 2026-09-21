"""Test: patterns that should NOT trigger warnings."""
obj Foo {
    has name: str,
        count: int = 0;

    def bar(_unused: int) {
        print(self.name);
    }
}
