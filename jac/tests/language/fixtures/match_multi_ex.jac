glob Num = 10;
with entry {
    match Num {
        case 2:
            print("Two");

        case 10:
            print("Ten");
            print("ten");

        case _:
            print("nothing");

    }
}
