"""Fixture: @classmethod and @staticmethod on class should NOT warn."""

class Foo {
    @classmethod
    def bar(cls: type) -> str {
        return "hello";
    }

    static def baz -> str {
        return "world";
    }
}
