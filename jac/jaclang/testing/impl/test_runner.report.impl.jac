impl Reporter.postinit -> None {
    import sys;
    if self.stream is None {
        self.stream = sys.stdout;
    }
    self.counts = {PASSED: 0, FAILED: 0, ERROR: 0, SKIPPED: 0, CRASHED: 0};
    self.failures = [];
}

impl Reporter.record(outcome: TestOutcome) -> None {
    self.counts[outcome.status] = self.counts.get(outcome.status, 0) + 1;
    if outcome.is_failure() {
        self.failures.append(outcome);
    }
    pct = self._pct_text();
    if self.verbose {
        line = f"{outcome.status.upper():8} {outcome.name}  [{outcome.file}]";
        if pct {
            line += " " * max(1, _PROGRESS_WIDTH - len(line)) + pct;
        }
        self.stream.write(line + "\n");
    } else {
        marks = {PASSED: ".", FAILED: "F", ERROR: "E", SKIPPED: "s", CRASHED: "!"};
        self.stream.write(marks.get(outcome.status, "?"));
        self.column += 1;
        if self.column >= _PROGRESS_WIDTH {
            if pct {
                self.stream.write(" " + pct);
            }
            self.stream.write("\n");
            self.column = 0;
        }
    }
    self.stream.flush();
}

impl Reporter.file_done -> None {
    self.files_done += 1;
}

impl Reporter._pct_text -> str {
    if self.total_files <= 0 {
        return "";
    }
    pct = (self.files_done * 100) // self.total_files;
    return f"[{min(pct, 100):3d}%]";
}

impl Reporter.file_crashed(filepath: str, detail: str) -> None {
    self.file_done();
    self.record(
        TestOutcome(
            file=filepath,
            name=os.path.basename(filepath),
            status=CRASHED,
            message=detail
        )
    );
}

impl Reporter.total_count -> int {
    return sum(self.counts.values());
}

impl Reporter.failure_count -> int {
    return (
        self.counts.get(FAILED, 0)
        + self.counts.get(ERROR, 0)
        + self.counts.get(CRASHED, 0)
    );
}

impl Reporter.summarize(elapsed: float) -> int {
    if self.column {
        pct = self._pct_text();
        if pct {
            self.stream.write(" " * max(1, _PROGRESS_WIDTH - self.column + 1) + pct);
        }
        self.stream.write("\n");
        self.column = 0;
    }
    for outcome in self.failures {
        self.stream.write(f"\nFAILED {outcome.file}::{outcome.name}\n");
        if outcome.message {
            self.stream.write(outcome.message.rstrip() + "\n");
        }
    }
    parts: list[str] = [];
    for key in (PASSED, FAILED, ERROR, SKIPPED, CRASHED) {
        count = self.counts.get(key, 0);
        if count {
            parts.append(f"{count} {key}");
        }
    }
    if not parts {
        parts.append("no tests ran");
    }
    self.stream.write(f"\n{', '.join(parts)} in {elapsed:.2f}s\n");
    self.stream.flush();
    return self.failure_count();
}

impl _parse_pct_range(expr: str) -> tuple[(int, int)] {
    parts = expr.split("-");
    bad = ValueError(f"bad --range '{expr}': expected N-M, N-, or -M (percents)");
    if len(parts) != 2 {
        raise bad;
    }
    try {
        lo = int(parts[0]) if parts[0] else 0;
        hi = int(parts[1]) if parts[1] else 100;
    } except ValueError {
        raise bad;
    }
    if not (0 <= lo <= hi <= 100) {
        raise bad;
    }
    return (lo, hi);
}
