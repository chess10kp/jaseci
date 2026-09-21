"""Test: JS-specific keywords should produce portability warnings."""

def use_undefined {
    x = undefined;
}

def use_typeof {
    t = typeof(x);
}

def use_void {
    v = void;
}
