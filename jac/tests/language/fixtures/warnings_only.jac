"""Test file with only warnings (no errors) for jac check output testing."""

glob
     # This unused variable should trigger a warning
     unused_var = 42,
     # Another unused variable
     another_unused = "hello";

with entry {
    print("This file has warnings but no errors");
}
