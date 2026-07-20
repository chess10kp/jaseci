"""Tests for typed session effect dispatch (session_dispatch.na.jac)."""

import jac.tests.cli.tui_selftest_harness as harness;


test "session_dispatch routes all effect kinds through session client" {
    na_dir = harness.na_dir();
    if not harness.shim_path(harness.repo_root(na_dir)).is_file() {
        import pytest;
        pytest.skip("libjacpyembed shim not built (run zig build in jac/)");
    }
    harness.ensure_selftest(na_dir, "selftest_session_dispatch");
    harness.assert_selftest_passes(na_dir, "selftest_session_dispatch");
}


test "native session client recorder selftest passes" {
    na_dir = harness.na_dir();
    if not harness.shim_path(harness.repo_root(na_dir)).is_file() {
        import pytest;
        pytest.skip("libjacpyembed shim not built (run zig build in jac/)");
    }
    harness.ensure_selftest(na_dir, "selftest_session_client");
    harness.assert_selftest_passes(na_dir, "selftest_session_client");
}
