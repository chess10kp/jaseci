import time

N = 500000
NSLEEP0 = 20000
NSLEEP = 2000
NERR = 10000
REPS = 3


def main():
    acc = 0

    i = 0
    while i < 1000:
        acc += time.monotonic_ns() % 65536
        acc += time.time_ns() % 65536
        acc += time.perf_counter_ns() % 65536
        acc += time.process_time_ns() % 65536
        acc += time.thread_time_ns() % 65536
        acc += time.clock_gettime_ns(time.CLOCK_MONOTONIC) % 65536
        acc += int(time.time() * 1000000.0) % 65536
        acc += int(time.monotonic() * 1000000.0) % 65536
        acc += int(time.perf_counter() * 1000000.0) % 65536
        acc += int(time.process_time() * 1000000.0) % 65536
        acc += int(time.thread_time() * 1000000.0) % 65536
        time.sleep(0.0)
        i += 1

    best = -1
    for _ in range(REPS):
        i = 0
        t0 = time.monotonic_ns()
        while i < N:
            acc += i % 65536
            i += 1
        dt = time.monotonic_ns() - t0
        if best < 0 or dt < best:
            best = dt
    print("bare_loop", best / N, "acc:", acc)

    best = -1
    for _ in range(REPS):
        i = 0
        t0 = time.monotonic_ns()
        while i < N:
            acc += int(time.time() * 1000000.0) % 65536
            i += 1
        dt = time.monotonic_ns() - t0
        if best < 0 or dt < best:
            best = dt
    print("time", best / N, "acc:", acc)

    best = -1
    for _ in range(REPS):
        i = 0
        t0 = time.monotonic_ns()
        while i < N:
            acc += time.time_ns() % 65536
            i += 1
        dt = time.monotonic_ns() - t0
        if best < 0 or dt < best:
            best = dt
    print("time_ns", best / N, "acc:", acc)

    best = -1
    for _ in range(REPS):
        i = 0
        t0 = time.monotonic_ns()
        while i < N:
            acc += int(time.monotonic() * 1000000.0) % 65536
            i += 1
        dt = time.monotonic_ns() - t0
        if best < 0 or dt < best:
            best = dt
    print("monotonic", best / N, "acc:", acc)

    best = -1
    for _ in range(REPS):
        i = 0
        t0 = time.monotonic_ns()
        while i < N:
            acc += time.monotonic_ns() % 65536
            i += 1
        dt = time.monotonic_ns() - t0
        if best < 0 or dt < best:
            best = dt
    print("monotonic_ns", best / N, "acc:", acc)

    best = -1
    for _ in range(REPS):
        i = 0
        t0 = time.monotonic_ns()
        while i < N:
            acc += int(time.perf_counter() * 1000000.0) % 65536
            i += 1
        dt = time.monotonic_ns() - t0
        if best < 0 or dt < best:
            best = dt
    print("perf_counter", best / N, "acc:", acc)

    best = -1
    for _ in range(REPS):
        i = 0
        t0 = time.monotonic_ns()
        while i < N:
            acc += time.perf_counter_ns() % 65536
            i += 1
        dt = time.monotonic_ns() - t0
        if best < 0 or dt < best:
            best = dt
    print("perf_counter_ns", best / N, "acc:", acc)

    best = -1
    for _ in range(REPS):
        i = 0
        t0 = time.monotonic_ns()
        while i < N:
            acc += int(time.process_time() * 1000000.0) % 65536
            i += 1
        dt = time.monotonic_ns() - t0
        if best < 0 or dt < best:
            best = dt
    print("process_time", best / N, "acc:", acc)

    best = -1
    for _ in range(REPS):
        i = 0
        t0 = time.monotonic_ns()
        while i < N:
            acc += time.process_time_ns() % 65536
            i += 1
        dt = time.monotonic_ns() - t0
        if best < 0 or dt < best:
            best = dt
    print("process_time_ns", best / N, "acc:", acc)

    best = -1
    for _ in range(REPS):
        i = 0
        t0 = time.monotonic_ns()
        while i < N:
            acc += int(time.thread_time() * 1000000.0) % 65536
            i += 1
        dt = time.monotonic_ns() - t0
        if best < 0 or dt < best:
            best = dt
    print("thread_time", best / N, "acc:", acc)

    best = -1
    for _ in range(REPS):
        i = 0
        t0 = time.monotonic_ns()
        while i < N:
            acc += time.thread_time_ns() % 65536
            i += 1
        dt = time.monotonic_ns() - t0
        if best < 0 or dt < best:
            best = dt
    print("thread_time_ns", best / N, "acc:", acc)

    best = -1
    for _ in range(REPS):
        i = 0
        t0 = time.monotonic_ns()
        while i < N:
            acc += time.clock_gettime_ns(time.CLOCK_MONOTONIC) % 65536
            i += 1
        dt = time.monotonic_ns() - t0
        if best < 0 or dt < best:
            best = dt
    print("clock_gettime_ns", best / N, "acc:", acc)

    best = -1
    for _ in range(REPS):
        i = 0
        t0 = time.monotonic_ns()
        while i < NERR:
            try:
                time.clock_settime_ns(time.CLOCK_MONOTONIC, 0)
            except Exception:
                acc += 1
            i += 1
        dt = time.monotonic_ns() - t0
        if best < 0 or dt < best:
            best = dt
    print("clock_settime_ns_err", best / NERR, "acc:", acc)

    best = -1
    for _ in range(REPS):
        i = 0
        t0 = time.monotonic_ns()
        while i < NSLEEP0:
            time.sleep(0.0)
            acc += 1
            i += 1
        dt = time.monotonic_ns() - t0
        if best < 0 or dt < best:
            best = dt
    print("sleep_0", best / NSLEEP0, "acc:", acc)

    best = -1
    for _ in range(REPS):
        i = 0
        t0 = time.monotonic_ns()
        while i < NSLEEP:
            time.sleep(0.0001)
            acc += 1
            i += 1
        dt = time.monotonic_ns() - t0
        if best < 0 or dt < best:
            best = dt
    print("sleep_100us", best / NSLEEP, "acc:", acc)


if __name__ == "__main__":
    main()
