# Product-path facade for heapq (native list algorithms).
# Per-type implementations live in ``_heapqmodule.jac``; this module is the
# public-name assembly point for guest code and converted Lib/test pins.

import from _heapqmodule {
    _p2_heappush as heappush,
    _p2_heappop as heappop,
    _p2_heapify as heapify,
    _p2_heapreplace as heapreplace,
    _p2_heappushpop as heappushpop,
    _p2_heappush_max as heappush_max,
    _p2_heappop_max as heappop_max,
    _p2_heapify_max as heapify_max,
    _p2_heapreplace_max as heapreplace_max,
    _p2_heappushpop_max as heappushpop_max,
}
