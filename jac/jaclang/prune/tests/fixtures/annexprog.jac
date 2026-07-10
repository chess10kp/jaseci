"""Fixture: clone bodies that live in a .impl.jac annex (R-A impl-annex path).

`Alpha.scan` and `Beta.scan` are declared here but implemented in
annexprog.impl.jac with byte-identical bodies, so the exact body hash must
collide even though the body bytes live in the annex file.
"""

obj Alpha {
    has data: list = [];

    def scan(key: str) -> int;
}

obj Beta {
    has data: list = [];

    def scan(key: str) -> int;
}
