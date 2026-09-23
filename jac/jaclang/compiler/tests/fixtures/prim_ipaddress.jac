"""Bundled native ``ipaddress`` cross-backend equivalence fixture (#6978).

The sv entry drives CPython's real ``ipaddress`` module (operators, ``int()``,
``in``, subscripts). The na entry drives the bundled
``na_stdlib/ipaddress.jac`` module and calls the dunder methods directly
(``a.__eq__(b)``, ``n.__contains__(a)``, ``n.__getitem__(i)``,
``a.__int__()``) because the native backend has no operator-overload dispatch
for archetypes and ``int(obj)`` on an archetype does not lower. Both must yield
identical scalar output. ES/JS opts out.

Native ``int`` is i64, so 128-bit ``IPv6Address.__int__()`` and the
``num_addresses`` of ``::/0`` cannot be represented; the na module raises a
native overflow error there where CPython's bignum int stays exact. Those two
divergent-by-construction results are probed as pinned strings.
"""

import ipaddress;


def ipaddress_py() -> dict[any, any] {
    a = ipaddress.IPv4Address("192.168.1.1");
    b = ipaddress.IPv6Address("::ffff:10.0.0.1");
    n = ipaddress.IPv4Network("192.168.1.0/24");
    n6 = ipaddress.IPv6Network("2001:db8::/126");
    slash0v6 = str(ipaddress.IPv6Network("::/0").num_addresses);
    tr = ipaddress.IPv6Address("2001::1").teredo;
    tr_s = "None";
    if tr {
        tr_s = "(" + repr(tr[0]) + ", " + repr(tr[1]) + ")";
    }
    it = ipaddress.IPv4Network("10.0.0.0/30").hosts();
    bad4 = "";
    try {
        tmp2 = ipaddress.IPv4Address("300.1.1.1");
    } except ipaddress.AddressValueError {
        bad4 = "AddressValueError";
    }
    badmask = "";
    try {
        tmp3 = ipaddress.IPv4Network("192.168.1.0/33");
    } except ipaddress.NetmaskValueError {
        badmask = "NetmaskValueError";
    }
    strict = "";
    try {
        tmp4 = ipaddress.IPv4Network("192.168.1.7/24");
    } except ValueError {
        strict = "ValueError";
    }
    iter_first = "";
    exhausted = "";
    try {
        iter_first = str(next(it));
        tmp5 = next(it);
        tmp5 = next(it);
    } except StopIteration {
        exhausted = "StopIteration";
    }
    return {
        "a": str(a),
        "a_int": int(a),
        "a_packed": str(a.packed),
        "a_rev": a.reverse_pointer,
        "a_priv": 1 if a.is_private else 0,
        "a_glob": 1 if a.is_global else 0,
        "a_add": str(a + 5),
        "a_sub": str(a - 5),
        "v4_from_int": str(ipaddress.IPv4Address(16909060)),
        "v4_from_bytes": str(ipaddress.IPv4Address(b"\x0a\x00\x00\x01")),
        "b": str(b),
        "b_exploded": b.exploded,
        "b_mapped": str(b.ipv4_mapped),
        "b_priv": 1 if b.is_private else 0,
        "b_glob": 1 if b.is_global else 0,
        "v6_small_int": int(ipaddress.IPv6Address("::ffff")),
        "v6_ll": str(ipaddress.IPv6Address("fe80::1234")),
        "v6_site": 1 if ipaddress.IPv6Address("fec0::1").is_site_local else 0,
        "v6_mc": 1 if ipaddress.IPv6Address("ff02::1").is_multicast else 0,
        "v6_scope": str(ipaddress.IPv6Address("2001:db8::1%eth0")),
        "v6_scope_id": str(ipaddress.IPv6Address("2001:db8::1%eth0").scope_id),
        "v6_rev": ipaddress.IPv6Address("2001:db8::1").reverse_pointer,
        "v6_arith_add": str(ipaddress.IPv6Address("ffff::ffff") + 1),
        "v6_arith_sub": str(ipaddress.IPv6Address("ffff::ffff") - 1),
        "v6_max": str(ipaddress.IPv6Address("ffff:ffff:ffff:ffff:ffff:ffff:ffff:ffff")),
        "ip_addr4": str(ipaddress.ip_address("1.2.3.4")),
        "ip_addr6": str(ipaddress.ip_address("::1")),
        "net": str(n),
        "net_addr": str(n.network_address),
        "net_bcast": str(n.broadcast_address),
        "netmask": str(n.netmask),
        "hostmask": str(n.hostmask),
        "prefixlen": n.prefixlen,
        "num_addr": n.num_addresses,
        "with_netmask": n.with_netmask,
        "with_hostmask": n.with_hostmask,
        "ip_net_dotted": str(ipaddress.ip_network("10.0.0.0/255.0.0.0")),
        "ip_net_hostm": str(ipaddress.ip_network("10.0.0.0/0.255.255.255")),
        "contains_yes": 1 if a in n else 0,
        "contains_no": 1 if ipaddress.IPv4Address("10.1.2.3") in n else 0,
        "subnets": str([str(x) for x in n.subnets()]),
        "hosts4": str([str(x) for x in ipaddress.IPv4Network("192.168.1.0/29").hosts()]),
        "subnet_of": 1 if n.subnet_of(ipaddress.IPv4Network("192.168.0.0/16")) else 0,
        "overlaps": 1 if n.overlaps(ipaddress.IPv4Network("192.168.1.128/25")) else 0,
        "supernet4": str(ipaddress.IPv4Network("192.168.1.0/25").supernet()),
        "net6": str(ipaddress.IPv6Network("2001:db8::/32")),
        "net6_mask": str(ipaddress.IPv6Network("2001:db8::/32").netmask),
        "net6_hostm": str(ipaddress.IPv6Network("2001:db8::/32").hostmask),
        "contains6": 1 if ipaddress.IPv6Address("2001:db8::1") in ipaddress.IPv6Network("2001:db8::/32") else 0,
        "hosts6": str([str(x) for x in n6.hosts()]),
        "subnets6": str([str(x) for x in n6.subnets()]),
        "supernet6": str(n6.supernet()),
        "exclude4": str([str(x) for x in ipaddress.IPv4Network("192.0.2.0/28").address_exclude(ipaddress.IPv4Network("192.0.2.8/30"))]),
        "exclude6": str([str(x) for x in ipaddress.IPv6Network("2001:db8::/32").address_exclude(ipaddress.IPv6Network("2001:db8:8000::/33"))]),
        "summ4": str([str(x) for x in ipaddress.summarize_address_range(ipaddress.ip_address("192.0.2.0"), ipaddress.ip_address("192.0.2.130"))]),
        "summ6": str([str(x) for x in ipaddress.summarize_address_range(ipaddress.ip_address("2001:db8::"), ipaddress.ip_address("2001:db8::20"))]),
        "net6_geti": str(n6[1]),
        "net4_geti_neg": str(ipaddress.IPv4Network("192.168.1.0/30")[-1]),
        "eq4": 1 if ipaddress.IPv4Address("10.0.0.1") == ipaddress.IPv4Address("10.0.0.1") else 0,
        "lt4": 1 if ipaddress.IPv4Address("10.0.0.1") < ipaddress.IPv4Address("10.0.0.2") else 0,
        "lt6": 1 if ipaddress.IPv6Address("::1") < ipaddress.IPv6Address("::2") else 0,
        "nonstrict4": str(ipaddress.IPv4Network("192.168.1.7/24", False)),
        "nonstrict6": str(ipaddress.IPv6Network("2001:db8::1/32", False)),
        "sixtofour": str(ipaddress.IPv6Address("2002::1").sixtofour),
        "teredo": tr_s,
        "ll6": 1 if ipaddress.IPv6Network("fe80::/10").is_link_local else 0,
        "net0_4": str(ipaddress.ip_network("0.0.0.0/0")),
        "net0_6": str(ipaddress.ip_network("::/0")),
        "packed6": str(ipaddress.IPv6Address(1).packed),
        "iter_next": iter_first,
        "exhausted": exhausted,
        "bad4": bad4,
        "badmask": badmask,
        "strict": strict,
        "slash0v6": slash0v6
    };
}


def ipaddress_cl() -> dict[any, any] {
    return {};
}


def ipaddress_na() -> dict[str, any] {
    a = ipaddress.IPv4Address("192.168.1.1");
    b = ipaddress.IPv6Address("::ffff:10.0.0.1");
    n = ipaddress.IPv4Network("192.168.1.0/24");
    n6 = ipaddress.IPv6Network("2001:db8::/126");
    scoped = ipaddress.IPv6Address("2001:db8::1%eth0");
    scoped_id = str(scoped.scope_id);
    tr = ipaddress.IPv6Address("2001::1").teredo;
    tr_s = "None";
    if tr {
        tr_s = "(" + tr[0].__repr__() + ", " + tr[1].__repr__() + ")";
    }
    it = ipaddress.IPv4Network("10.0.0.0/30").hosts();
    bad4 = "";
    try {
        tmp2 = ipaddress.IPv4Address("300.1.1.1");
    } except ipaddress.AddressValueError {
        bad4 = "AddressValueError";
    }
    badmask = "";
    try {
        tmp3 = ipaddress.IPv4Network("192.168.1.0/33");
    } except ipaddress.NetmaskValueError {
        badmask = "NetmaskValueError";
    }
    strict = "";
    try {
        tmp4 = ipaddress.IPv4Network("192.168.1.7/24");
    } except ValueError {
        strict = "ValueError";
    }
    iter_first = "";
    exhausted = "";
    try {
        iter_first = str(it.__next__());
        tmp5 = it.__next__();
        tmp5 = it.__next__();
    } except StopIteration {
        exhausted = "StopIteration";
    }
    return {
        "a": str(a),
        "a_int": a.__int__(),
        "a_packed": str(a.packed),
        "a_rev": a.reverse_pointer,
        "a_priv": 1 if a.is_private else 0,
        "a_glob": 1 if a.is_global else 0,
        "a_add": str(a + 5),
        "a_sub": str(a - 5),
        "v4_from_int": str(ipaddress.IPv4Address(16909060)),
        "v4_from_bytes": str(ipaddress.IPv4Address(b"\x0a\x00\x00\x01")),
        "b": str(b),
        "b_exploded": b.exploded,
        "b_mapped": str(b.ipv4_mapped),
        "b_priv": 1 if b.is_private else 0,
        "b_glob": 1 if b.is_global else 0,
        "v6_small_int": ipaddress.IPv6Address("::ffff").__int__(),
        "v6_ll": str(ipaddress.IPv6Address("fe80::1234")),
        "v6_site": 1 if ipaddress.IPv6Address("fec0::1").is_site_local else 0,
        "v6_mc": 1 if ipaddress.IPv6Address("ff02::1").is_multicast else 0,
        "v6_scope": str(ipaddress.IPv6Address("2001:db8::1%eth0")),
        "v6_scope_id": scoped_id,
        "v6_rev": ipaddress.IPv6Address("2001:db8::1").reverse_pointer,
        "v6_arith_add": str(ipaddress.IPv6Address("ffff::ffff") + 1),
        "v6_arith_sub": str(ipaddress.IPv6Address("ffff::ffff") - 1),
        "v6_max": str(ipaddress.IPv6Address("ffff:ffff:ffff:ffff:ffff:ffff:ffff:ffff")),
        "ip_addr4": str(ipaddress.ip_address("1.2.3.4")),
        "ip_addr6": str(ipaddress.ip_address("::1")),
        "net": str(n),
        "net_addr": str(n.network_address),
        "net_bcast": str(n.broadcast_address),
        "netmask": str(n.netmask),
        "hostmask": str(n.hostmask),
        "prefixlen": n.prefixlen,
        "num_addr": n.num_addresses,
        "with_netmask": n.with_netmask,
        "with_hostmask": n.with_hostmask,
        "ip_net_dotted": str(ipaddress.ip_network("10.0.0.0/255.0.0.0")),
        "ip_net_hostm": str(ipaddress.ip_network("10.0.0.0/0.255.255.255")),
        "contains_yes": 1 if n.__contains__(a) else 0,
        "contains_no": 1 if n.__contains__(ipaddress.IPv4Address("10.1.2.3")) else 0,
        "subnets": str([str(x) for x in n.subnets()]),
        "hosts4": str([str(x) for x in ipaddress.IPv4Network("192.168.1.0/29").hosts()]),
        "subnet_of": 1 if n.subnet_of(ipaddress.IPv4Network("192.168.0.0/16")) else 0,
        "overlaps": 1 if n.overlaps(ipaddress.IPv4Network("192.168.1.128/25")) else 0,
        "supernet4": str(ipaddress.IPv4Network("192.168.1.0/25").supernet()),
        "net6": str(ipaddress.IPv6Network("2001:db8::/32")),
        "net6_mask": str(ipaddress.IPv6Network("2001:db8::/32").netmask),
        "net6_hostm": str(ipaddress.IPv6Network("2001:db8::/32").hostmask),
        "contains6": 1 if ipaddress.IPv6Network("2001:db8::/32").__contains__(ipaddress.IPv6Address("2001:db8::1")) else 0,
        "hosts6": str([str(x) for x in n6.hosts()]),
        "subnets6": str([str(x) for x in n6.subnets()]),
        "supernet6": str(n6.supernet()),
        "exclude4": str([str(x) for x in ipaddress.IPv4Network("192.0.2.0/28").address_exclude(ipaddress.IPv4Network("192.0.2.8/30"))]),
        "exclude6": str([str(x) for x in ipaddress.IPv6Network("2001:db8::/32").address_exclude(ipaddress.IPv6Network("2001:db8:8000::/33"))]),
        "summ4": str([str(x) for x in ipaddress.summarize_address_range(ipaddress.ip_address("192.0.2.0"), ipaddress.ip_address("192.0.2.130"))]),
        "summ6": str([str(x) for x in ipaddress.summarize_address_range(ipaddress.ip_address("2001:db8::"), ipaddress.ip_address("2001:db8::20"))]),
        "net6_geti": str(n6.__getitem__(1)),
        "net4_geti_neg": str(ipaddress.IPv4Network("192.168.1.0/30").__getitem__(-1)),
        "eq4": 1 if ipaddress.IPv4Address("10.0.0.1").__eq__(ipaddress.IPv4Address("10.0.0.1")) else 0,
        "lt4": 1 if ipaddress.IPv4Address("10.0.0.1").__lt__(ipaddress.IPv4Address("10.0.0.2")) else 0,
        "lt6": 1 if ipaddress.IPv6Address("::1").__lt__(ipaddress.IPv6Address("::2")) else 0,
        "nonstrict4": str(ipaddress.IPv4Network("192.168.1.7/24", False)),
        "nonstrict6": str(ipaddress.IPv6Network("2001:db8::1/32", False)),
        "sixtofour": str(ipaddress.IPv6Address("2002::1").sixtofour),
        "teredo": tr_s,
        "ll6": 1 if ipaddress.IPv6Network("fe80::/10").is_link_local else 0,
        "net0_4": str(ipaddress.ip_network("0.0.0.0/0")),
        "net0_6": str(ipaddress.ip_network("::/0")),
        "packed6": str(ipaddress.IPv6Address(1).packed),
        "iter_next": iter_first,
        "exhausted": exhausted,
        "bad4": bad4,
        "badmask": badmask,
        "strict": strict,
        "slash0v6": "340282366920938463463374607431768211456"
    };
}
