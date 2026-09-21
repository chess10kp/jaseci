import time

N = 1_000_000

acc = 0
t0 = time.monotonic_ns()
for i in range(N):
    acc += i % 65536
t1 = time.monotonic_ns()
print("bare_loop_ns_per_iter:", (t1 - t0) / N)

acc = 0
t0 = time.monotonic_ns()
for i in range(N):
    acc += time.monotonic_ns() % 65536
t1 = time.monotonic_ns()
print("cpython_monotonic_ns_per_iter:", (t1 - t0) / N, "acc:", acc)

acc = 0
f0 = time.monotonic()
for i in range(N):
    acc += int(time.monotonic() * 1000000.0) % 65536
f1 = time.monotonic()
print("cpython_monotonic_ns_per_iter:", (f1 - f0) * 1e9 / N, "acc:", acc)
