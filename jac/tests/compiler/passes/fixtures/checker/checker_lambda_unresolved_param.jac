glob nums: list[int] = [3, 1, 2];

with entry {
    # OK: seeded from context / annotated / no params.
    ok_callback = sorted(nums, key=lambda (x) { -x; });
}
glob ok_callable: Callable[[int], int] = lambda (x) { x + 1; };
with entry {
    ok_annot = (lambda (x: int) { x / 2; })(10);
}
glob ok_noargs = lambda { 567; },
     # E1119: no annotation, no context to seed the param(s).
     bad_bare = lambda (y) { -y; },
     bad_two = lambda (a, b) { a + b; };

with entry {
    # A body that is more than its return is checked in place, so a bad call in
    # it still reports (E1053) rather than being deferred and never revisited.
    checked_inline = sorted(
        nums,
        key=lambda (x) {
            len(1);
            return x;
        }
    );

    _ = (
        ok_callback,
        ok_callable,
        ok_annot,
        ok_noargs,
        bad_bare,
        bad_two,
        checked_inline
    );
}
