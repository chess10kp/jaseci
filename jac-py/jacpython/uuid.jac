# Product-path facade for the _uuid accelerator module (native Jac).
#
# Lift of CPython 3.14 ``Modules/_uuidmodule.c`` (POSIX/libuuid build):
# the module surface guest ``Lib/uuid.py`` imports when it wants a system
# UUID generator -- ``generate_time_safe()`` plus the capability flags
# ``has_uuid_generate_time_safe`` / ``has_stable_extractable_node``.
#
# The C module is a thin shim over libuuid's uuid_generate_time_safe(3),
# which is not linkable from in-VM Jac. generate_time_safe therefore builds
# an RFC 9562 version-1 UUID natively: timestamp from the host clock,
# plus a per-process 14-bit clock sequence and multicast node seeded once
# from os.urandom (the same fallback Lib/uuid.py::_random_getnode
# documents). The C contract is kept: a ``(bytes, safely_generated)``
# tuple with 16 big-endian bytes and safely_generated == 0.
#
# Without libuuid there is no stable hardware MAC to extract, so
# has_stable_extractable_node is honestly 0 -- guest uuid.py then routes
# getnode() through its own getter chain instead of _unix_getnode().
# UuidCreate is Windows-only and absent from the POSIX C build; it is not
# exposed here either.

import from objects {
    PyObj,
    PyInt,
    PyBytes,
    PyTuple,
    PyModule,
    py_none,
    py_error,
}

import os as _host_os;
import time as _host_time;

# Capability flags (uuid_exec in Modules/_uuidmodule.c).
glob has_uuid_generate_time_safe: int = 1;
glob has_stable_extractable_node: int = 0;

# 100-ns intervals between the UUID epoch (1582-10-15) and the Unix epoch;
# shared by Lib/uuid.py and RFC 9562.
glob _UUID_EPOCH_DELTA: int = 0x01b21dd213814000;

# Per-process generator state: monotonic last timestamp, 14-bit clock
# sequence, and 6-byte multicast node, all seeded once from os.urandom.
# (The node bytes live in _node_bytes -- "node" itself is a Jac keyword.)
glob _last_timestamp: int = -1;
glob _clock_seq: int = -1;
glob _node_bytes: list[int] = [];


# Seed the clock sequence and node exactly once per process. A single
# urandom(8) draw covers both (2 bytes sequence + 6 bytes node), mirroring
# how libuuid initializes its sequence from stable storage once.
def _seed_generator_state {
    if _clock_seq >= 0 {
        return;
    }
    # One urandom(8) draw covers both: 2 bytes of clock sequence followed
    # by the 6 node bytes, mirroring how libuuid seeds its sequence from
    # stable storage once per boot.
    seed = _host_os.urandom(8);
    b0 = seed[0] as int;
    b1 = seed[1] as int;
    _clock_seq = ((b0 << 8) | b1) & 0x3FFF;
    buf: list[int] = [];
    k: int = 2;
    while k < 8 {
        buf.append(seed[k] as int);
        k = k + 1;
    }
    # RFC 9562 section 6.10-3: random nodes MUST set the multicast bit
    # (least significant bit of the first octet) so they can never collide
    # with a real IEEE 802 address.
    buf[0] = buf[0] | 1;
    _node_bytes = buf;
}


# Build the 16-byte big-endian v1 layout:
# time_low(4) time_mid(2) time_hi_version(2)
# clock_seq_hi_variant(1) clock_seq_low(1) node(6).
def _uuid1_bytes -> list[int] {
    nanoseconds = _host_time.time_ns();
    ts = nanoseconds // 100 + _UUID_EPOCH_DELTA;
    if ts <= _last_timestamp {
        # Monotonicity guard, matching Lib/uuid.py::uuid1: never emit two
        # UUIDs claiming the same 100-ns tick.
        ts = _last_timestamp + 1;
    }
    _last_timestamp = ts;

    time_low = ts & 0xFFFFFFFF;
    time_mid = (ts >> 32) & 0xFFFF;
    # Version 1 sits in the top nibble of time_hi_version.
    time_hi_version = ((ts >> 48) & 0x0FFF) | 0x1000;
    # Variant 10xx sits in the top two bits of clock_seq_hi_variant.
    clock_seq_hi_variant = ((_clock_seq >> 8) & 0x3F) | 0x80;
    clock_seq_low = _clock_seq & 0xFF;

    out: list[int] = [];
    shifts: list[int] = [24, 16, 8, 0];
    for sh in shifts {
        out.append((time_low >> sh) & 0xFF);
    }
    for sh in [8, 0] {
        out.append((time_mid >> sh) & 0xFF);
        out.append((time_hi_version >> sh) & 0xFF);
    }
    out.append(clock_seq_hi_variant);
    out.append(clock_seq_low);
    for b in _node_bytes {
        out.append(b);
    }
    return out;
}


obj PyUuidFn(PyObj) {
    has name: str;

    def tp_call(args: list[PyObj], kwargs: dict[str, PyObj]) -> PyObj {
        if self.name == "generate_time_safe" {
            # METH_NOARGS: refuse any positional or keyword argument with
            # CPython's clinic wording.
            given = len(args) + len(kwargs);
            if given > 0 {
                return py_error(
                    "TypeError",
                    self.name + "() takes no arguments (" + str(given) + " given)"
                );
            }
            _seed_generator_state();
            payload: list[PyObj] = [
                PyBytes(t="bytes", val=_uuid1_bytes()),
                # safely_generated == 0: the timestamp is guaranteed unique
                # by the monotonic guard above.
                PyInt(t="int", val=0),
            ];
            return PyTuple(t="tuple", items=payload);
        }
        return py_error(
            "SystemError", "unknown _uuid function '" + self.name + "'"
        );
    }
}


# Shim-module factory consumed by the ceval import sites; mirrors
# PyInit__uuid exposing uuid_methods + uuid_exec constants.
def build_uuid_module -> PyObj {
    _seed_generator_state();
    return PyModule(
        t="module",
        name="_uuid",
        attrs={
            "generate_time_safe": PyUuidFn(
                t="uuid_fn", name="generate_time_safe"
            ) as PyObj,
            "has_uuid_generate_time_safe": PyInt(
                t="int", val=has_uuid_generate_time_safe
            ),
            "has_stable_extractable_node": PyInt(
                t="int", val=has_stable_extractable_node
            ),
        },
    );
}
