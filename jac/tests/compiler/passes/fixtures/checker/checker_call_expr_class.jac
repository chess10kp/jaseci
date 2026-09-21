node Foo {
    has i: int = 0;
}

glob cls = Foo;
with entry {
    inst = cls();  # <-- Call expression target of class type

    inst.i = 42;  # <-- Ok
    inst.i = 'str';  # <-- Error
}
