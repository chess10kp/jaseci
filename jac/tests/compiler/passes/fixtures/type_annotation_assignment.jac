glob should_pass1: int = 42,
     should_fail1: int = "foo",
     should_pass2: str = "bar",
     should_fail2: str = 42,
     should_be_fine = "baz";
# This is without any explicit type annotation.
# was failing after the first PR.
