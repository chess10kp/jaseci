# P3.1c — slice core runtime (``PySlice_AdjustIndices`` lane).
# Hand runtime mirrors ``Objects/_lifted/sliceobject.jac`` and ``objects.jac``.
# Slicing behavior lives in ``objects.jac`` (slice_indices); this module is
# kept as the manifest-declared jacpython_module for the sliceobject lift wave.
