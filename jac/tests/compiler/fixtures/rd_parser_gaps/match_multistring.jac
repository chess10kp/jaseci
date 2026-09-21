# Test multistring (concatenated string literals) in match patterns.
# Lark grammar: literal_pattern: (INT | FLOAT | multistring)
# where multistring: (fstring | STRING)+
glob x = "hello world";
with entry {
    match x {
        case "hello" " " "world":
            print("matched concat");

        case "foo" "bar":
            print("matched foobar");

        case "single":
            print("matched single");

    }
}
