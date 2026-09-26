import math
import time

N = 1_000_000
REPS = 4


def lane(n):
    acc = 0.0
    i = 0
    t0 = time.monotonic_ns()
    while i < n:
        acc += math.sqrt(float(i % 1000))
        i += 1
    return acc, time.monotonic_ns() - t0


def main():
    best_t = -1
    acc = 0.0
    for k in range(REPS + 1):
        acc, el = lane(N)
        if k > 0 and (best_t < 0 or el < best_t):
            best_t = el
    print("cpython", best_t / N, str(acc))


if __name__ == "__main__":
    main()
