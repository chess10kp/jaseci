# P3.1c — slice core runtime (``PySlice_AdjustIndices`` lane).
# CPython source: Objects/sliceobject.c; storage lives in objects.jac.
import from objects { PySlice, slice_indices, }

# Re-export for runtime probes; slicing behavior lives in ``objects.jac``.
def slice_adjust_indices(sl: PySlice, length: int) -> list[int] {
    return slice_indices(sl, length);
}
