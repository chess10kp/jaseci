#!/usr/bin/env bash
# Benchmark lanes for the bundled select/socket/socketserver/urllib/
# ipaddress/robotparser modules.
#
#   LANE 1  native Jac -> C `sqrt` directly (FFI `import from c`)
#   LANE 2  CPython loop -> `math.sqrt` + module rows
#   LANE 3  Jac on the sv backend -> CPython bridge (same source)
#   LANE 4  Jac on the native backend -> bundled na_stdlib (same source)
#
# Rows print name|n|ns_per_op|acc; acc must agree across lanes.
#
# Usage:  scripts/bench/run_na_socket_bench.sh   (JAC env var overrides the binary)
set -euo pipefail
cd "$(dirname "$0")/../.."
JAC="${JAC:-jac/zig-out/bin/jac}"

echo "=== lane 1: native jac -> C sqrt directly ==="
"$JAC" run scripts/bench/na_sqrt_native.jac --native
echo
echo "=== lane 2: cpython reference ==="
python3 scripts/bench/bench_na_socket.py
echo
echo "=== lane 3: jac sv backend -> cpython bridge ==="
"$JAC" run -b python scripts/bench/bench_na_socket.jac
echo
echo "=== lane 4: jac native backend -> bundled na_stdlib ==="
"$JAC" run -b native scripts/bench/bench_na_socket.jac
