node A {}
node B {}

def foo(a: A) {}

with entry {
    foo(A());  # <-- Ok
    foo(B());  # <-- Error
}
