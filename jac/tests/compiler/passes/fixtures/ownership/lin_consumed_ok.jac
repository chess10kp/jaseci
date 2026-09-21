"""A `lin` binding consumed exactly once by an own-taking call is clean."""

obj Handle {
    has id: int = 0;
}

def close(h: own Handle) {
    print(h.id);
}

def run {
    h: lin Handle = Handle(id=1);
    close(h);
}
