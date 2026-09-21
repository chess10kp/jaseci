obj Post {
    has title: str,
        author: str;

    def __repr__ -> str {
        return f"Post(title={self.title}, by={self.author})";
    }
}
