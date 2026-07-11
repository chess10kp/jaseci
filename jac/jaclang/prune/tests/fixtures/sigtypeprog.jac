"""Import-extraction edge fixture (dogfood Bug B, real-source).

Each imported type below is used ONLY in a type-annotation position, in a
different syntactic shape. The probe reveals which shapes the reference
extractor records (import stays live) and which it misses (import looks dead and
must be rescued by the signature-type veto). `sqrt` is never used -> a true dead
import; `getpid` is called -> a genuine live use.
"""

import from math { sqrt }
import from os { getpid }
import from typesupply { Payload }
import from typesupply { Retval }
import from typesupply { Elem }
import from typesupply { Optel }
import from typesupply { Unused }


def param_pos(p: Payload) -> int {
    return getpid();
}


def return_pos(r: Retval) -> Retval {
    return r;
}


def generic_pos(xs: list[Elem]) -> int {
    return len(xs);
}


def optional_pos(o: Optel | None) -> int {
    return 0;
}
