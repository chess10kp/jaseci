glob
     # unicode characters
     items = [
         {"title": "1st", "due": True, "completed": True},
         {"title": "2nd", "due": False, "completed": False}
     ];

with entry {
    for (i, item) in enumerate(items) {
        status = "✓" if item["completed"] else "○";
        due = f" (due: {item['due']})" if item["due"] else "";
        print(f"{i + 1}. {status} {item['title']}{due}");
    }

    # unicode emojis and symbols
    print("🌟 Star");
}

glob
     # unicode in triple quoted strings
     multiline = """Multi-line with ✓ unicode and ○ symbols""";
with entry {
    print(multiline);
}

glob
     # unicode in raw strings
     raw_unicode = r"Raw string with ✓ and ○";
with entry {
    print(raw_unicode);
}

glob
     # mixed unicode and escape sequences
     mixed = "Tab ✓\nNewline ○";
with entry {
    print(mixed);
}
