glob
     # Test escaped double quotes
     s1 = "He said \"Hello World\"";
with entry {
    print(s1);
}

glob
     # Test escaped single quotes
     s2 = 'It\'s a beautiful day';
with entry {
    print(s2);
}

glob
     # Test mixed quotes
     s3 = "It's a \"great\" day";
with entry {
    print(s3);
}

glob
     # Test multiple escapes
     s4 = "She said \"Don't forget the \\backslash\\\"";
with entry {
    print(s4);
}

glob
     # Test newline and tab escapes
     s5 = "Line 1\nLine 2\tTabbed";
with entry {
    print(s5);
}

glob
     # Test backslash
     s6 = "Path: C:\\Users\\Documents\\file.txt";
with entry {
    print(s6);
}
