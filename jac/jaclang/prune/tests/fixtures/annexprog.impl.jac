impl Alpha.scan(key: str) -> int {
    count = 0;
    for item in self.data {
        if item == key {
            count += 1;
        }
    }
    return count;
}

impl Beta.scan(key: str) -> int {
    count = 0;
    for item in self.data {
        if item == key {
            count += 1;
        }
    }
    return count;
}
