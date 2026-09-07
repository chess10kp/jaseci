"""The worker pool budgets each worker at the ceiling it may reach.

`default_jobs` sizes a pool from available memory. It used to divide by a
typical footprint (WORKER_MEM_BYTES) while the pools that recycle workers on
an RSS ceiling let each worker grow to that ceiling first, so a cold `jac
check` sweep on a 16 GB runner ran four workers that were each allowed 4 GB:
17 GB with the parent, and the runner died before any of them retired. A
caller that recycles at a ceiling now passes it, and the pool is sized so
every worker can sit at the ceiling at once and still fit.
"""

import os;
import from unittest.mock { mock_open, patch }
import from jaclang.cli.workpool { MAX_AUTO_JOBS, WORKER_MEM_BYTES, default_jobs }
import from jaclang.testing.test_runner { resolve_jobs as resolve_test_jobs }

glob GB: int = 1024 * 1024 * 1024;

test "default_jobs sizes the pool by the per-worker ceiling" {
    cpus = os.cpu_count() or 1;
    # 16 GB box, workers recycled at 4 GB: 16 * 0.6 / 4 = 2, never 4.
    assert default_jobs(worker_bytes=4 * GB, avail_bytes=16 * GB) == min(cpus, 2) , "four 4 GB workers plus the parent do not fit a 16 GB box";
    # Without a ceiling the typical footprint still sizes the pool.
    assert default_jobs(avail_bytes=16 * GB)
        == min(cpus, int((16 * GB * 0.6) // WORKER_MEM_BYTES), MAX_AUTO_JOBS);
    # A ceiling below the typical footprint does not grow the pool.
    assert default_jobs(worker_bytes=1 * GB, avail_bytes=16 * GB)
        == default_jobs(avail_bytes=16 * GB);
    # A ceiling the box cannot hold even once still yields one worker.
    assert default_jobs(worker_bytes=64 * GB, avail_bytes=16 * GB) == 1;
}

test "automatic test workers fit their configured memory ceiling" {
    with patch("os.cpu_count", return_value=4), patch(
        "builtins.open", mock_open(read_data="MemAvailable: 16777216 kB\n")
    ), patch.dict(os.environ, {"JAC_TEST_JOBS": "auto", "JAC_TEST_RECYCLE_MB": ""}) {
        # Four workers allowed 8 GB each cannot share a 16 GB runner.
        assert resolve_test_jobs() == 1;
        with patch.dict(os.environ, {"JAC_TEST_RECYCLE_MB": "4096"}) {
            assert resolve_test_jobs() == 2;
        }
        with patch.dict(os.environ, {"JAC_TEST_RECYCLE_MB": "0"}) {
            assert resolve_test_jobs() == 4;
        }
        # An explicit count remains an operator override.
        assert resolve_test_jobs("3") == 3;
    }
}
