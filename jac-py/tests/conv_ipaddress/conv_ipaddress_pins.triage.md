# Triage report: `conv_ipaddress_pins.jac`

- source: /home/jac/repos/jac-python/reference/cpython/Lib/test/test_ipaddress.py
- guest leg: 0/83 marks
- pins: **62 passed** / 83 run (+128 quarantined of 211 extracted)

| pin | result | got |
|---|---|---|
| AddressTestCase_v4.test_format | PASS | |
| AddressTestCase_v4.test_ipv6_mapped | PASS | |
| AddressTestCase_v6.test_format | PASS | |
| NetworkTestCase_v4.test_subnet_of_mixed_types | PASS | |
| ComparisonTests.test_incompatible_versions | PASS | |
| IpaddrUnitTest.testRepr | PASS | |
| IpaddrUnitTest.testIPv4Tuple | PASS | |
| IpaddrUnitTest.testIPv6Tuple | PASS | |
| IpaddrUnitTest.testAddressIntMath | PASS | |
| IpaddrUnitTest.testInvalidIntToBytes | PASS | |
| IpaddrUnitTest.testInternals | PASS | |
| IpaddrUnitTest.testGetNetwork | GUEST-WRONG-OUTPUT | GOT<'ORACLE_EXC AssertionError "(\'assertEqual\', \'<functools.cached_property object at 0x7fc970eb16e0>\', \'::ffff:ffff:ffff:ffff\')"'> |
| IpaddrUnitTest.testIpFromInt | PASS | |
| IpaddrUnitTest.testIpFromPacked | PASS | |
| IpaddrUnitTest.testGetIp | PASS | |
| IpaddrUnitTest.testIPv6IPv4MappedStringRepresentation | PASS | |
| IpaddrUnitTest.testGetScopeId | PASS | |
| IpaddrUnitTest.testGetNetmask | PASS | |
| IpaddrUnitTest.testZeroNetmask | PASS | |
| IpaddrUnitTest.testIPv4Net | PASS | |
| IpaddrUnitTest.testGetBroadcast | GUEST-WRONG-OUTPUT | GOT<'ORACLE_EXC TypeError "int() argument must be a string, a bytes-like object or a real number, not \'cached_property\'"'> |
| IpaddrUnitTest.testGetPrefixlen | PASS | |
| IpaddrUnitTest.testGetSupernet | PASS | |
| IpaddrUnitTest.testGetSupernet3 | PASS | |
| IpaddrUnitTest.testGetSupernet4 | PASS | |
| IpaddrUnitTest.testHosts | GUEST-WRONG-OUTPUT | GOT<'ORACLE_EXC TypeError "int() argument must be a string, a bytes-like object or a real number, not \'cached_property\'"'> |
| IpaddrUnitTest.testFancySubnetting | GUEST-WRONG-OUTPUT | GOT<'ORACLE_EXC TypeError "int() argument must be a string, a bytes-like object or a real number, not \'cached_property\'"'> |
| IpaddrUnitTest.testGetSubnets | GUEST-WRONG-OUTPUT | GOT<'ORACLE_EXC TypeError "int() argument must be a string, a bytes-like object or a real number, not \'cached_property\'"'> |
| IpaddrUnitTest.testGetSubnetForSingle32 | PASS | |
| IpaddrUnitTest.testGetSubnetForSingle128 | PASS | |
| IpaddrUnitTest.testSubnet2 | GUEST-WRONG-OUTPUT | GOT<'ORACLE_EXC TypeError "int() argument must be a string, a bytes-like object or a real number, not \'cached_property\'"'> |
| IpaddrUnitTest.testGetSubnets3 | GUEST-WRONG-OUTPUT | GOT<'ORACLE_EXC TypeError "int() argument must be a string, a bytes-like object or a real number, not \'cached_property\'"'> |
| IpaddrUnitTest.testSubnetFailsForLargeCidrDiff | PASS | |
| IpaddrUnitTest.testSupernetFailsForLargeCidrDiff | PASS | |
| IpaddrUnitTest.testSubnetFailsForNegativeCidrDiff | PASS | |
| IpaddrUnitTest.testGetNum_Addresses | GUEST-WRONG-OUTPUT | GOT<'ORACLE_EXC TypeError "int() argument must be a string, a bytes-like object or a real number, not \'cached_property\'"'> |
| IpaddrUnitTest.testContains | PASS | |
| IpaddrUnitTest.testNth | GUEST-WRONG-OUTPUT | GOT<'ORACLE_EXC TypeError "int() argument must be a string, a bytes-like object or a real number, not \'cached_property\'"'> |
| IpaddrUnitTest.testGetitem | GUEST-WRONG-OUTPUT | GOT<'ORACLE_EXC TypeError "int() argument must be a string, a bytes-like object or a real number, not \'cached_property\'"'> |
| IpaddrUnitTest.testEqual | PASS | |
| IpaddrUnitTest.testNotEqual | PASS | |
| IpaddrUnitTest.testSlash32Constructor | PASS | |
| IpaddrUnitTest.testSlash128Constructor | PASS | |
| IpaddrUnitTest.testSlash0Constructor | PASS | |
| IpaddrUnitTest.testCollapsing | GUEST-WRONG-OUTPUT | GOT<'ORACLE_EXC AssertionError "(\'assertEqual\', [], [IPv4Network(\'1.1.1.0/30\'), IPv4Network(\'1.1.1.4/32\')])"'> |
| IpaddrUnitTest.testSummarizing | PASS | |
| IpaddrUnitTest.testAddressComparison | PASS | |
| IpaddrUnitTest.testInterfaceComparison | PASS | |
| IpaddrUnitTest.testNetworkComparison | PASS | |
| IpaddrUnitTest.testStrictNetworks | PASS | |
| IpaddrUnitTest.testOverlaps | GUEST-WRONG-OUTPUT | GOT<"ORACLE_EXC AttributeError 'version'"> |
| IpaddrUnitTest.testEmbeddedIpv4 | PASS | |
| IpaddrUnitTest.testIPv6AddressTooLarge | PASS | |
| IpaddrUnitTest.testIPVersion | PASS | |
| IpaddrUnitTest.testMaxPrefixLength | PASS | |
| IpaddrUnitTest.testPacked | PASS | |
| IpaddrUnitTest.testIpType | PASS | |
| IpaddrUnitTest.testReservedIpv4 | GUEST-WRONG-OUTPUT | GOT<"ORACLE_EXC AttributeError 'is_reserved'"> |
| IpaddrUnitTest.testPrivateNetworks | GUEST-WRONG-OUTPUT | GOT<"ORACLE_EXC AttributeError 'version'"> |
| IpaddrUnitTest.testReservedIpv6 | GUEST-WRONG-OUTPUT | GOT<"ORACLE_EXC AttributeError 'is_multicast'"> |
| IpaddrUnitTest.testIpv4Mapped | PASS | |
| IpaddrUnitTest.testIpv4MappedProperties | PASS | |
| IpaddrUnitTest.testIpv4MappedPrivateCheck | PASS | |
| IpaddrUnitTest.testIpv4MappedLoopbackCheck | GUEST-WRONG-OUTPUT | GOT<"ORACLE_EXC AttributeError 'is_loopback'"> |
| IpaddrUnitTest.testAddrExclude | GUEST-WRONG-OUTPUT | GOT<'ORACLE_EXC TypeError "\'>=\' not supported between instances of \'cached_property\' and \'cached_property\'"'> |
| IpaddrUnitTest.testHash | PASS | |
| IpaddrUnitTest.testIPBases | PASS | |
| IpaddrUnitTest.testIPv6NetworkHelpers | GUEST-WRONG-OUTPUT | GOT<'ORACLE_EXC AssertionError "(\'assertEqual\', \'2001:658:22a:cafe::/::ffff:ffff:ffff:ffff\', \'2001:658:22a:cafe::/<functools.cached_property object at 0x7fc970eb16e0>\')"'> |
| IpaddrUnitTest.testIPv4NetworkHelpers | GUEST-WRONG-OUTPUT | GOT<'ORACLE_EXC AssertionError "(\'assertEqual\', \'1.2.3.0/0.0.0.255\', \'1.2.3.0/<functools.cached_property object at 0x7fc970eb16e0>\')"'> |
| IpaddrUnitTest.testCopyConstructor | PASS | |
| IpaddrUnitTest.testCompressIPv6Address | PASS | |
| IpaddrUnitTest.testExplodeShortHandIpStr | PASS | |
| IpaddrUnitTest.testReversePointer | PASS | |
| IpaddrUnitTest.testIntRepresentation | PASS | |
| IpaddrUnitTest.testForceVersion | PASS | |
| IpaddrUnitTest.testWithStar | GUEST-WRONG-OUTPUT | GOT<'ORACLE_EXC AssertionError "(\'assertEqual\', \'1.2.3.4/<functools.cached_property object at 0x7fc970eb1cd0>\', \'1.2.3.4/0.0.0.255\')"'> |
| IpaddrUnitTest.testNetworkElementCaching | GUEST-WRONG-OUTPUT | GOT<'ORACLE_EXC AssertionError "(\'assertEqual\', <functools.cached_property object at 0x7fc97033a850>, IPv4Address(\'1.2.3.255\'))"'> |
| IpaddrUnitTest.testTeredo | PASS | |
| IpaddrUnitTest.testsixtofour | PASS | |
| IpaddrUnitTest.testV4HashIsNotConstant | PASS | |
| IpaddrUnitTest.testV6HashIsNotConstant | PASS | |
| IpaddrUnitTest.testNetworkV4HashCollisions | PASS | |
| IpaddrUnitTest.testNetworkV6HashCollisions | PASS | |

## Quarantined at conversion

| test | reason |
|---|---|
| AddressTestCase_v4.test_empty_address | helper:assertAddressError(helper:assertCleanError(decorated-helper)) |
| InterfaceTestCase_v4.test_empty_address | helper:assertAddressError(helper:assertCleanError(decorated-helper)) |
| NetworkTestCase_v4.test_empty_address | helper:assertAddressError(helper:assertCleanError(decorated-helper)) |
| AddressTestCase_v6.test_empty_address | helper:assertAddressError(helper:assertCleanError(decorated-helper)) |
| InterfaceTestCase_v6.test_empty_address | helper:assertAddressError(helper:assertCleanError(decorated-helper)) |
| NetworkTestCase_v6.test_empty_address | helper:assertAddressError(helper:assertCleanError(decorated-helper)) |
| AddressTestCase_v4.test_floats_rejected | helper:assertAddressError(helper:assertCleanError(decorated-helper)) |
| InterfaceTestCase_v4.test_floats_rejected | helper:assertAddressError(helper:assertCleanError(decorated-helper)) |
| NetworkTestCase_v4.test_floats_rejected | helper:assertAddressError(helper:assertCleanError(decorated-helper)) |
| AddressTestCase_v6.test_floats_rejected | helper:assertAddressError(helper:assertCleanError(decorated-helper)) |
| InterfaceTestCase_v6.test_floats_rejected | helper:assertAddressError(helper:assertCleanError(decorated-helper)) |
| NetworkTestCase_v6.test_floats_rejected | helper:assertAddressError(helper:assertCleanError(decorated-helper)) |
| AddressTestCase_v4.test_not_an_index_issue15559 | helper:factory(decorated-helper) |
| InterfaceTestCase_v4.test_not_an_index_issue15559 | helper:factory(decorated-helper) |
| NetworkTestCase_v4.test_not_an_index_issue15559 | helper:factory(decorated-helper) |
| AddressTestCase_v6.test_not_an_index_issue15559 | helper:factory(decorated-helper) |
| InterfaceTestCase_v6.test_not_an_index_issue15559 | helper:factory(decorated-helper) |
| NetworkTestCase_v6.test_not_an_index_issue15559 | helper:factory(decorated-helper) |
| AddressTestCase_v4.test_leading_zeros | helper:assertAddressError(helper:assertCleanError(decorated-helper)) |
| InterfaceTestCase_v4.test_leading_zeros | helper:assertAddressError(helper:assertCleanError(decorated-helper)) |
| NetworkTestCase_v4.test_leading_zeros | helper:assertAddressError(helper:assertCleanError(decorated-helper)) |
| AddressTestCase_v4.test_int | helper:assertInstancesEqual(helper:factory(decorated-helper)) |
| InterfaceTestCase_v4.test_int | helper:assertInstancesEqual(helper:factory(decorated-helper)) |
| NetworkTestCase_v4.test_int | helper:assertInstancesEqual(helper:factory(decorated-helper)) |
| AddressTestCase_v4.test_packed | helper:assertInstancesEqual(helper:factory(decorated-helper)) |
| InterfaceTestCase_v4.test_packed | helper:assertInstancesEqual(helper:factory(decorated-helper)) |
| NetworkTestCase_v4.test_packed | helper:assertInstancesEqual(helper:factory(decorated-helper)) |
| AddressTestCase_v4.test_negative_ints_rejected | helper:assertAddressError(helper:assertCleanError(decorated-helper)) |
| InterfaceTestCase_v4.test_negative_ints_rejected | helper:assertAddressError(helper:assertCleanError(decorated-helper)) |
| NetworkTestCase_v4.test_negative_ints_rejected | helper:assertAddressError(helper:assertCleanError(decorated-helper)) |
| AddressTestCase_v4.test_large_ints_rejected | helper:assertAddressError(helper:assertCleanError(decorated-helper)) |
| InterfaceTestCase_v4.test_large_ints_rejected | helper:assertAddressError(helper:assertCleanError(decorated-helper)) |
| NetworkTestCase_v4.test_large_ints_rejected | helper:assertAddressError(helper:assertCleanError(decorated-helper)) |
| AddressTestCase_v4.test_bad_packed_length | helper:assertAddressError(helper:assertCleanError(decorated-helper)) |
| InterfaceTestCase_v4.test_bad_packed_length | helper:assertAddressError(helper:assertCleanError(decorated-helper)) |
| NetworkTestCase_v4.test_bad_packed_length | helper:assertAddressError(helper:assertCleanError(decorated-helper)) |
| AddressTestCase_v6.test_leading_zeros | helper:assertInstancesEqual(helper:factory(decorated-helper)) |
| InterfaceTestCase_v6.test_leading_zeros | helper:assertInstancesEqual(helper:factory(decorated-helper)) |
| NetworkTestCase_v6.test_leading_zeros | helper:assertInstancesEqual(helper:factory(decorated-helper)) |
| AddressTestCase_v6.test_int | helper:assertInstancesEqual(helper:factory(decorated-helper)) |
| InterfaceTestCase_v6.test_int | helper:assertInstancesEqual(helper:factory(decorated-helper)) |
| NetworkTestCase_v6.test_int | helper:assertInstancesEqual(helper:factory(decorated-helper)) |
| AddressTestCase_v6.test_packed | helper:assertInstancesEqual(helper:factory(decorated-helper)) |
| InterfaceTestCase_v6.test_packed | helper:assertInstancesEqual(helper:factory(decorated-helper)) |
| NetworkTestCase_v6.test_packed | helper:assertInstancesEqual(helper:factory(decorated-helper)) |
| AddressTestCase_v6.test_negative_ints_rejected | helper:assertAddressError(helper:assertCleanError(decorated-helper)) |
| InterfaceTestCase_v6.test_negative_ints_rejected | helper:assertAddressError(helper:assertCleanError(decorated-helper)) |
| NetworkTestCase_v6.test_negative_ints_rejected | helper:assertAddressError(helper:assertCleanError(decorated-helper)) |
| AddressTestCase_v6.test_large_ints_rejected | helper:assertAddressError(helper:assertCleanError(decorated-helper)) |
| InterfaceTestCase_v6.test_large_ints_rejected | helper:assertAddressError(helper:assertCleanError(decorated-helper)) |
| NetworkTestCase_v6.test_large_ints_rejected | helper:assertAddressError(helper:assertCleanError(decorated-helper)) |
| AddressTestCase_v6.test_bad_packed_length | helper:assertAddressError(helper:assertCleanError(decorated-helper)) |
| InterfaceTestCase_v6.test_bad_packed_length | helper:assertAddressError(helper:assertCleanError(decorated-helper)) |
| NetworkTestCase_v6.test_bad_packed_length | helper:assertAddressError(helper:assertCleanError(decorated-helper)) |
| AddressTestCase_v6.test_blank_scope_id | helper:assertAddressError(helper:assertCleanError(decorated-helper)) |
| InterfaceTestCase_v6.test_blank_scope_id | helper:assertAddressError(helper:assertCleanError(decorated-helper)) |
| NetworkTestCase_v6.test_blank_scope_id | helper:assertAddressError(helper:assertCleanError(decorated-helper)) |
| AddressTestCase_v6.test_invalid_scope_id_with_percent | helper:assertAddressError(helper:assertCleanError(decorated-helper)) |
| InterfaceTestCase_v6.test_invalid_scope_id_with_percent | helper:assertAddressError(helper:assertCleanError(decorated-helper)) |
| NetworkTestCase_v6.test_invalid_scope_id_with_percent | helper:assertAddressError(helper:assertCleanError(decorated-helper)) |
| AddressTestCase_v4.test_network_passed_as_address | helper:assertAddressError(helper:assertCleanError(decorated-helper)) |
| AddressTestCase_v4.test_bad_address_split | helper:assertAddressError(helper:assertCleanError(decorated-helper)) |
| AddressTestCase_v4.test_empty_octet | helper:assertAddressError(helper:assertCleanError(decorated-helper)) |
| AddressTestCase_v4.test_invalid_characters | helper:assertAddressError(helper:assertCleanError(decorated-helper)) |
| AddressTestCase_v4.test_octet_length | helper:assertAddressError(helper:assertCleanError(decorated-helper)) |
| AddressTestCase_v4.test_octet_limit | helper:assertAddressError(helper:assertCleanError(decorated-helper)) |
| AddressTestCase_v4.test_pickle | helper:pickle_test(helper:factory(decorated-helper)) |
| AddressTestCase_v4.test_weakref | helper:factory(decorated-helper) |
| AddressTestCase_v6.test_network_passed_as_address | helper:assertAddressError(helper:assertCleanError(decorated-helper)) |
| AddressTestCase_v6.test_bad_address_split_v6_not_enough_parts | helper:assertAddressError(helper:assertCleanError(decorated-helper)) |
| AddressTestCase_v6.test_bad_address_split_v6_too_many_colons | helper:assertAddressError(helper:assertCleanError(decorated-helper)) |
| AddressTestCase_v6.test_bad_address_split_v6_too_long | helper:assertAddressError(helper:assertCleanError(decorated-helper)) |
| AddressTestCase_v6.test_bad_address_split_v6_too_many_parts | helper:assertAddressError(helper:assertCleanError(decorated-helper)) |
| AddressTestCase_v6.test_bad_address_split_v6_too_many_parts_with_double_colon | helper:assertAddressError(helper:assertCleanError(decorated-helper)) |
| AddressTestCase_v6.test_bad_address_split_v6_repeated_double_colon | helper:assertAddressError(helper:assertCleanError(decorated-helper)) |
| AddressTestCase_v6.test_bad_address_split_v6_leading_colon | helper:assertAddressError(helper:assertCleanError(decorated-helper)) |
| AddressTestCase_v6.test_bad_address_split_v6_trailing_colon | helper:assertAddressError(helper:assertCleanError(decorated-helper)) |
| AddressTestCase_v6.test_bad_v4_part_in | helper:assertAddressError(helper:assertCleanError(decorated-helper)) |
| AddressTestCase_v6.test_invalid_characters | helper:assertAddressError(helper:assertCleanError(decorated-helper)) |
| AddressTestCase_v6.test_part_length | helper:assertAddressError(helper:assertCleanError(decorated-helper)) |
| AddressTestCase_v6.test_pickle | helper:pickle_test(helper:factory(decorated-helper)) |
| AddressTestCase_v6.test_weakref | helper:factory(decorated-helper) |
| AddressTestCase_v6.test_copy | helper:factory(decorated-helper) |
| InterfaceTestCase_v4.test_no_mask | helper:factory(decorated-helper) |
| NetworkTestCase_v4.test_no_mask | helper:factory(decorated-helper) |
| InterfaceTestCase_v4.test_split_netmask | helper:assertAddressError(helper:assertCleanError(decorated-helper)) |
| NetworkTestCase_v4.test_split_netmask | helper:assertAddressError(helper:assertCleanError(decorated-helper)) |
| InterfaceTestCase_v4.test_address_errors | helper:assertAddressError(helper:assertCleanError(decorated-helper)) |
| NetworkTestCase_v4.test_address_errors | helper:assertAddressError(helper:assertCleanError(decorated-helper)) |
| InterfaceTestCase_v4.test_valid_netmask | helper:factory(decorated-helper) |
| NetworkTestCase_v4.test_valid_netmask | helper:factory(decorated-helper) |
| InterfaceTestCase_v4.test_netmask_errors | helper:assertNetmaskError(helper:assertCleanError(decorated-helper)) |
| NetworkTestCase_v4.test_netmask_errors | helper:assertNetmaskError(helper:assertCleanError(decorated-helper)) |
| InterfaceTestCase_v4.test_netmask_in_tuple_errors | helper:assertNetmaskError(helper:assertCleanError(decorated-helper)) |
| NetworkTestCase_v4.test_netmask_in_tuple_errors | helper:assertNetmaskError(helper:assertCleanError(decorated-helper)) |
| InterfaceTestCase_v4.test_pickle | helper:pickle_test(helper:factory(decorated-helper)) |
| NetworkTestCase_v4.test_pickle | helper:pickle_test(helper:factory(decorated-helper)) |
| NetworkTestCase_v4.test_subnet_of | helper:factory(decorated-helper) |
| NetworkTestCase_v4.test_supernet_of | helper:factory(decorated-helper) |
| InterfaceTestCase_v6.test_no_mask | helper:factory(decorated-helper) |
| NetworkTestCase_v6.test_no_mask | helper:factory(decorated-helper) |
| InterfaceTestCase_v6.test_split_netmask | helper:assertAddressError(helper:assertCleanError(decorated-helper)) |
| NetworkTestCase_v6.test_split_netmask | helper:assertAddressError(helper:assertCleanError(decorated-helper)) |
| InterfaceTestCase_v6.test_address_errors | helper:assertAddressError(helper:assertCleanError(decorated-helper)) |
| NetworkTestCase_v6.test_address_errors | helper:assertAddressError(helper:assertCleanError(decorated-helper)) |
| InterfaceTestCase_v6.test_valid_netmask | helper:factory(decorated-helper) |
| NetworkTestCase_v6.test_valid_netmask | helper:factory(decorated-helper) |
| InterfaceTestCase_v6.test_netmask_errors | helper:assertNetmaskError(helper:assertCleanError(decorated-helper)) |
| NetworkTestCase_v6.test_netmask_errors | helper:assertNetmaskError(helper:assertCleanError(decorated-helper)) |
| InterfaceTestCase_v6.test_netmask_in_tuple_errors | helper:assertNetmaskError(helper:assertCleanError(decorated-helper)) |
| NetworkTestCase_v6.test_netmask_in_tuple_errors | helper:assertNetmaskError(helper:assertCleanError(decorated-helper)) |
| InterfaceTestCase_v6.test_pickle | helper:pickle_test(helper:factory(decorated-helper)) |
| NetworkTestCase_v6.test_pickle | helper:pickle_test(helper:factory(decorated-helper)) |
| NetworkTestCase_v6.test_subnet_of | helper:factory(decorated-helper) |
| NetworkTestCase_v6.test_supernet_of | helper:factory(decorated-helper) |
| FactoryFunctionErrors.test_ip_address | helper:assertFactoryError(helper:assertCleanError(decorated-helper)) |
| FactoryFunctionErrors.test_ip_interface | helper:assertFactoryError(helper:assertCleanError(decorated-helper)) |
| FactoryFunctionErrors.test_ip_network | helper:assertFactoryError(helper:assertCleanError(decorated-helper)) |
| ComparisonTests.test_foreign_type_equality | unresolved-name:objects |
| ComparisonTests.test_mixed_type_equality | unresolved-name:objects |
| ComparisonTests.test_scoped_ipv6_equality | unresolved-name:objects |
| ComparisonTests.test_v4_with_v6_scoped_equality | unresolved-name:objects |
| ComparisonTests.test_same_type_equality | unresolved-name:objects |
| ComparisonTests.test_same_type_ordering | unresolved-name:objects |
| ComparisonTests.test_containment | unresolved-name:objects |
| ComparisonTests.test_mixed_type_ordering | unresolved-name:objects |
| ComparisonTests.test_foreign_type_ordering | unresolved-name:objects |
| ComparisonTests.test_mixed_type_key | unresolved-name:objects |

## Expected vs got

### IpaddrUnitTest.testAddrExclude (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<'ORACLE_EXC TypeError "\'>=\' not supported between instances of \'cached_property\' and \'cached_property\'"'>

### IpaddrUnitTest.testCollapsing (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<'ORACLE_EXC AssertionError "(\'assertEqual\', [], [IPv4Network(\'1.1.1.0/30\'), IPv4Network(\'1.1.1.4/32\')])"'>

### IpaddrUnitTest.testFancySubnetting (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<'ORACLE_EXC TypeError "int() argument must be a string, a bytes-like object or a real number, not \'cached_property\'"'>

### IpaddrUnitTest.testGetBroadcast (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<'ORACLE_EXC TypeError "int() argument must be a string, a bytes-like object or a real number, not \'cached_property\'"'>

### IpaddrUnitTest.testGetNetwork (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<'ORACLE_EXC AssertionError "(\'assertEqual\', \'<functools.cached_property object at 0x7fc970eb16e0>\', \'::ffff:ffff:ffff:ffff\')"'>

### IpaddrUnitTest.testGetNum_Addresses (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<'ORACLE_EXC TypeError "int() argument must be a string, a bytes-like object or a real number, not \'cached_property\'"'>

### IpaddrUnitTest.testGetSubnets (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<'ORACLE_EXC TypeError "int() argument must be a string, a bytes-like object or a real number, not \'cached_property\'"'>

### IpaddrUnitTest.testGetSubnets3 (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<'ORACLE_EXC TypeError "int() argument must be a string, a bytes-like object or a real number, not \'cached_property\'"'>

### IpaddrUnitTest.testGetitem (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<'ORACLE_EXC TypeError "int() argument must be a string, a bytes-like object or a real number, not \'cached_property\'"'>

### IpaddrUnitTest.testHosts (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<'ORACLE_EXC TypeError "int() argument must be a string, a bytes-like object or a real number, not \'cached_property\'"'>

### IpaddrUnitTest.testIPv4NetworkHelpers (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<'ORACLE_EXC AssertionError "(\'assertEqual\', \'1.2.3.0/0.0.0.255\', \'1.2.3.0/<functools.cached_property object at 0x7fc970eb16e0>\')"'>

### IpaddrUnitTest.testIPv6NetworkHelpers (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<'ORACLE_EXC AssertionError "(\'assertEqual\', \'2001:658:22a:cafe::/::ffff:ffff:ffff:ffff\', \'2001:658:22a:cafe::/<functools.cached_property object at 0x7fc970eb16e0>\')"'>

### IpaddrUnitTest.testIpv4MappedLoopbackCheck (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<"ORACLE_EXC AttributeError 'is_loopback'">

### IpaddrUnitTest.testNetworkElementCaching (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<'ORACLE_EXC AssertionError "(\'assertEqual\', <functools.cached_property object at 0x7fc97033a850>, IPv4Address(\'1.2.3.255\'))"'>

### IpaddrUnitTest.testNth (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<'ORACLE_EXC TypeError "int() argument must be a string, a bytes-like object or a real number, not \'cached_property\'"'>

### IpaddrUnitTest.testOverlaps (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<"ORACLE_EXC AttributeError 'version'">

### IpaddrUnitTest.testPrivateNetworks (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<"ORACLE_EXC AttributeError 'version'">

### IpaddrUnitTest.testReservedIpv4 (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<"ORACLE_EXC AttributeError 'is_reserved'">

### IpaddrUnitTest.testReservedIpv6 (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<"ORACLE_EXC AttributeError 'is_multicast'">

### IpaddrUnitTest.testSubnet2 (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<'ORACLE_EXC TypeError "int() argument must be a string, a bytes-like object or a real number, not \'cached_property\'"'>

### IpaddrUnitTest.testWithStar (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<'ORACLE_EXC AssertionError "(\'assertEqual\', \'1.2.3.4/<functools.cached_property object at 0x7fc970eb1cd0>\', \'1.2.3.4/0.0.0.255\')"'>
