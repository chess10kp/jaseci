def pystr_contains_c(hay: str, needle: str) -> int {
    i: int = 0;
    j: int = 0;
    if not hay {
        return 0;
    }

    if not needle {
        return 1;
    }

    i = 0;
    while i < len(hay) {
        j = 0;
        while (
            (j < len(needle))
            and (i + j < len(hay))
            and ((ord(hay[(i + j)]) & 255) == (ord(needle[j]) & 255))
        ) {
            j += 1;
        }

        if j == len(needle) {
            return 1;
        }

        i += 1;
    }

    return 0;
}
