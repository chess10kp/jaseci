# Trailing comma in dict, set, and spread dict literals
glob d = {"a": 1, "b": 2,},
     s = {1, 2, 3, },
     base = {"x": 10};

with entry {
    merged = {** base, "y": 20,};
}
