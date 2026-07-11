"""Fixture module for the `sem`-string arm of the duplicate-docstrings detector.

`make_alpha` and `make_beta` are given byte-identical `sem` annotations above
the length floor, so they form one duplicate group with kind "sem".
`make_gamma` gets a distinct `sem` string and must never group.
"""


def make_alpha() -> int {
    return 1;
}


def make_beta() -> int {
    return 2;
}


def make_gamma() -> int {
    return 3;
}


sem make_alpha = "Produce the canonical seed value consumed by every downstream stage of the widget assembly pipeline.";
sem make_beta = "Produce the canonical seed value consumed by every downstream stage of the widget assembly pipeline.";
sem make_gamma = "Produce an entirely different, single-use value that appears exactly once and must never be paired here.";
