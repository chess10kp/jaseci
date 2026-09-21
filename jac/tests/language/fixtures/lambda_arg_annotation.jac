glob x = lambda (a: int, b: int) { b + a; };
with entry {
    print(x(5, 4));
}
glob y = lambda { 567; };
with entry {
    print(y());
}

with entry {
    f = lambda (x: any) { "even" if x % 2 == 0 else "odd"; };
    print(f(7));
}
