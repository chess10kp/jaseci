obj User {
    has name: str,
        email: str;

    def __repr__ -> str {
        return f"User(name={self.name}, email={self.email})";
    }
}
