"""A `lin` parameter consumed by an own-taking call before return is clean."""

obj Handle {
    has id: int = 0;
}

def close(h: own Handle) {
    print(h.id);
}

def finish(h: lin Handle) {
    print("finishing");
    close(h);
}
