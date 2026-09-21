obj math_mod {
    def divide(x: int, y: int) -> int {
        if y == 0 {
            return 0;
        } else {
            return x // y;
        }
    }

    def multiply(x: int, y: int) -> int {
        return x * y;
    }
}

glob x = 5,
     y = 0;

with entry {
    math = math_mod();
    z = math.divide(x, y);
    print(z);
}
