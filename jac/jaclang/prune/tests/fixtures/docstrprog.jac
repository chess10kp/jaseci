"""Fixture module for the archetype-docstring arm of duplicate-docstrings (3.4).

`Widget` and `Gadget` carry a byte-identical leading docstring above the length
floor, so they form one duplicate group with kind "docstring". `Sprocket` gets a
distinct docstring and must never pair.
"""


"""A reusable component that participates in the assembly pipeline and reports its own status."""
obj Widget {
    has label: str = "widget";
}


"""A reusable component that participates in the assembly pipeline and reports its own status."""
obj Gadget {
    has label: str = "gadget";
}


"""An entirely separate component that stands alone and shares its description with nothing else."""
obj Sprocket {
    has label: str = "sprocket";
}
