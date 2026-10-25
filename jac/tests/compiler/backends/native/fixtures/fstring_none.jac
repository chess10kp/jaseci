def run_cases {
    print("start");
    n = None;
    print(f"{n}");
    print(f"x{n}y");
    print(f"{n!r}");
    print(f"{None}");
    print(f"{None:>6}");
    s: (str | None) = None;
    print(f"{s}");
    print("end");
}

with entry {
    run_cases();
}
