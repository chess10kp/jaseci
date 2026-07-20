"""Tests snapshot apply preserves part_type/role as distinct native Events."""

import jac.tests.cli.tui_selftest_harness as harness;


test "native snapshot apply selftest preserves part kinds" {
    na_dir = harness.na_dir();
    if not harness.shim_path(harness.repo_root(na_dir)).is_file() {
        import pytest;
        pytest.skip("libjacpyembed shim not built (run zig build in jac/)");
    }
    harness.ensure_selftest(na_dir, "selftest_snapshot_apply");
    harness.assert_selftest_passes(na_dir, "selftest_snapshot_apply");
}
