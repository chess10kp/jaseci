node City {
    has name: str;
}

with entry {
    c: City = City("Metropolis");
    root ++> c;
}

glob x: str = root;  # <- error
