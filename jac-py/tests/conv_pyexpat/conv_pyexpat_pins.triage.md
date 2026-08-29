# Triage report: `conv_pyexpat_pins.jac`

- source: reference/cpython/Lib/test/test_pyexpat.py
- guest leg: 0/34 marks
- pins: **0 passed** / 34 run (+70 quarantined of 104 extracted)

| pin | result | got |
|---|---|---|
| SetAttributeTest.test_buffer_text | VM-CRASH | jaclang/compiler/backends/native/na_ir_gen/gc_debug.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/generics.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/globals.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/hash_core.jac...   Compiling jaclang/compiler |
| SetAttributeTest.test_namespace_prefixes | VM-CRASH | jaclang/compiler/backends/native/na_ir_gen/gc_debug.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/generics.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/globals.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/hash_core.jac...   Compiling jaclang/compiler |
| SetAttributeTest.test_ordered_attributes | VM-CRASH | jaclang/compiler/backends/native/na_ir_gen/gc_debug.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/generics.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/globals.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/hash_core.jac...   Compiling jaclang/compiler |
| SetAttributeTest.test_specified_attributes | VM-CRASH | jaclang/compiler/backends/native/na_ir_gen/gc_debug.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/generics.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/globals.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/hash_core.jac...   Compiling jaclang/compiler |
| SetAttributeTest.test_invalid_attributes | VM-CRASH | jaclang/compiler/backends/native/na_ir_gen/gc_debug.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/generics.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/globals.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/hash_core.jac...   Compiling jaclang/compiler |
| ParseTest.test_undefined_encoding | VM-CRASH | jaclang/compiler/backends/native/na_ir_gen/gc_debug.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/generics.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/globals.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/hash_core.jac...   Compiling jaclang/compiler |
| ParseTest.test_unknown_encoding | VM-CRASH | jaclang/compiler/backends/native/na_ir_gen/gc_debug.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/generics.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/globals.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/hash_core.jac...   Compiling jaclang/compiler |
| NamespaceSeparatorTest.test_legal | VM-CRASH | jaclang/compiler/backends/native/na_ir_gen/gc_debug.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/generics.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/globals.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/hash_core.jac...   Compiling jaclang/compiler |
| NamespaceSeparatorTest.test_illegal | VM-CRASH | jaclang/compiler/backends/native/na_ir_gen/gc_debug.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/generics.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/globals.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/hash_core.jac...   Compiling jaclang/compiler |
| NamespaceSeparatorTest.test_zero_length | VM-CRASH | jaclang/compiler/backends/native/na_ir_gen/gc_debug.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/generics.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/globals.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/hash_core.jac...   Compiling jaclang/compiler |
| InterningTest.test | VM-CRASH | jaclang/compiler/backends/native/na_ir_gen/gc_debug.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/generics.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/globals.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/hash_core.jac...   Compiling jaclang/compiler |
| InterningTest.test_issue9402 | VM-CRASH | jaclang/compiler/backends/native/na_ir_gen/gc_debug.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/generics.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/globals.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/hash_core.jac...   Compiling jaclang/compiler |
| sf1296433Test.test_parse_only_xml_data | VM-CRASH | jaclang/compiler/backends/native/na_ir_gen/gc_debug.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/generics.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/globals.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/hash_core.jac...   Compiling jaclang/compiler |
| ChardataBufferTest.test_wrong_size | VM-CRASH | jaclang/compiler/backends/native/na_ir_gen/gc_debug.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/generics.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/globals.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/hash_core.jac...   Compiling jaclang/compiler |
| ElementDeclHandlerTest.test_trigger_leak | VM-CRASH | jaclang/compiler/backends/native/na_ir_gen/gc_debug.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/generics.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/globals.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/hash_core.jac...   Compiling jaclang/compiler |
| MalformedInputTest.test1 | VM-CRASH | jaclang/compiler/backends/native/na_ir_gen/gc_debug.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/generics.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/globals.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/hash_core.jac...   Compiling jaclang/compiler |
| MalformedInputTest.test2 | VM-CRASH | jaclang/compiler/backends/native/na_ir_gen/gc_debug.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/generics.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/globals.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/hash_core.jac...   Compiling jaclang/compiler |
| ErrorMessageTest.test_codes | VM-CRASH | jaclang/compiler/backends/native/na_ir_gen/gc_debug.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/generics.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/globals.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/hash_core.jac...   Compiling jaclang/compiler |
| ErrorMessageTest.test_expaterror | VM-CRASH | jaclang/compiler/backends/native/na_ir_gen/gc_debug.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/generics.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/globals.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/hash_core.jac...   Compiling jaclang/compiler |
| ForeignDTDTests.test_use_foreign_dtd | VM-CRASH | jaclang/compiler/backends/native/na_ir_gen/gc_debug.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/generics.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/globals.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/hash_core.jac...   Compiling jaclang/compiler |
| ForeignDTDTests.test_ignore_use_foreign_dtd | VM-CRASH | jaclang/compiler/backends/native/na_ir_gen/gc_debug.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/generics.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/globals.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/hash_core.jac...   Compiling jaclang/compiler |
| ParentParserLifetimeTest.test_parent_parser_outlives_its_subparsers__single | VM-CRASH | jaclang/compiler/backends/native/na_ir_gen/gc_debug.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/generics.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/globals.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/hash_core.jac...   Compiling jaclang/compiler |
| ParentParserLifetimeTest.test_parent_parser_outlives_its_subparsers__multiple | VM-CRASH | jaclang/compiler/backends/native/na_ir_gen/gc_debug.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/generics.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/globals.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/hash_core.jac...   Compiling jaclang/compiler |
| ParentParserLifetimeTest.test_parent_parser_outlives_its_subparsers__chain | VM-CRASH | jaclang/compiler/backends/native/na_ir_gen/gc_debug.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/generics.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/globals.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/hash_core.jac...   Compiling jaclang/compiler |
| ReparseDeferralTest.test_getter_setter_round_trip | VM-CRASH | jaclang/compiler/backends/native/na_ir_gen/gc_debug.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/generics.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/globals.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/hash_core.jac...   Compiling jaclang/compiler |
| ReparseDeferralTest.test_reparse_deferral_disabled | VM-CRASH | jaclang/compiler/backends/native/na_ir_gen/gc_debug.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/generics.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/globals.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/hash_core.jac...   Compiling jaclang/compiler |
| ExpansionProtectionTest.test_set_activation_threshold__threshold_reached | VM-CRASH | jaclang/compiler/backends/native/na_ir_gen/gc_debug.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/generics.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/globals.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/hash_core.jac...   Compiling jaclang/compiler |
| MemoryProtectionTest.test_set_activation_threshold__threshold_reached | VM-CRASH | jaclang/compiler/backends/native/na_ir_gen/gc_debug.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/generics.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/globals.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/hash_core.jac...   Compiling jaclang/compiler |
| ExpansionProtectionTest.test_set_activation_threshold__threshold_not_reached | VM-CRASH | jaclang/compiler/backends/native/na_ir_gen/gc_debug.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/generics.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/globals.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/hash_core.jac...   Compiling jaclang/compiler |
| MemoryProtectionTest.test_set_activation_threshold__threshold_not_reached | VM-CRASH | jaclang/compiler/backends/native/na_ir_gen/gc_debug.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/generics.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/globals.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/hash_core.jac...   Compiling jaclang/compiler |
| ExpansionProtectionTest.test_set_maximum_amplification__amplification_exceeded | VM-CRASH | jaclang/compiler/backends/native/na_ir_gen/gc_debug.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/generics.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/globals.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/hash_core.jac...   Compiling jaclang/compiler |
| MemoryProtectionTest.test_set_maximum_amplification__amplification_exceeded | VM-CRASH | jaclang/compiler/backends/native/na_ir_gen/gc_debug.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/generics.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/globals.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/hash_core.jac...   Compiling jaclang/compiler |
| ExpansionProtectionTest.test_set_maximum_amplification__amplification_not_exceeded | VM-CRASH | jaclang/compiler/backends/native/na_ir_gen/gc_debug.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/generics.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/globals.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/hash_core.jac...   Compiling jaclang/compiler |
| MemoryProtectionTest.test_set_maximum_amplification__amplification_not_exceeded | VM-CRASH | jaclang/compiler/backends/native/na_ir_gen/gc_debug.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/generics.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/globals.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/hash_core.jac...   Compiling jaclang/compiler |

## Shared failure signatures

These pins fail with a byte-identical detail, which usually means
one shared root cause (for example an import-time error in the
guest module) instead of per-test defects.

| count | classification | got | pins |
|---|---|---|---|
| 34 | VM-CRASH | jaclang/compiler/backends/native/na_ir_gen/gc_debug.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/generics.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/globals.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/hash_core.jac...   Compiling jaclang/compiler | ChardataBufferTest.test_wrong_size, ElementDeclHandlerTest.test_trigger_leak, ErrorMessageTest.test_codes, ErrorMessageTest.test_expaterror, ExpansionProtectionTest.test_set_activation_threshold__threshold_not_reached, ExpansionProtectionTest.test_set_activation_threshold__threshold_reached, ExpansionProtectionTest.test_set_maximum_amplification__amplification_exceeded, ExpansionProtectionTest.test_set_maximum_amplification__amplification_not_exceeded, ForeignDTDTests.test_ignore_use_foreign_dtd, ForeignDTDTests.test_use_foreign_dtd, InterningTest.test, InterningTest.test_issue9402, MalformedInputTest.test1, MalformedInputTest.test2, MemoryProtectionTest.test_set_activation_threshold__threshold_not_reached, MemoryProtectionTest.test_set_activation_threshold__threshold_reached, MemoryProtectionTest.test_set_maximum_amplification__amplification_exceeded, MemoryProtectionTest.test_set_maximum_amplification__amplification_not_exceeded, NamespaceSeparatorTest.test_illegal, NamespaceSeparatorTest.test_legal, NamespaceSeparatorTest.test_zero_length, ParentParserLifetimeTest.test_parent_parser_outlives_its_subparsers__chain, ParentParserLifetimeTest.test_parent_parser_outlives_its_subparsers__multiple, ParentParserLifetimeTest.test_parent_parser_outlives_its_subparsers__single, ParseTest.test_undefined_encoding, ParseTest.test_unknown_encoding, ReparseDeferralTest.test_getter_setter_round_trip, ReparseDeferralTest.test_reparse_deferral_disabled, SetAttributeTest.test_buffer_text, SetAttributeTest.test_invalid_attributes, SetAttributeTest.test_namespace_prefixes, SetAttributeTest.test_ordered_attributes, SetAttributeTest.test_specified_attributes, sf1296433Test.test_parse_only_xml_data |

## Quarantined at conversion

| test | reason |
|---|---|
| ParseTest.test_supported_encodings | decorator:support.subTests |
| ParseTest.test_supported_encodings2 | decorator:support.subTests |
| ParseTest.test_unsupported_encodings | decorator:support.subTests |
| ParseTest.test_incompatible_encodings | decorator:support.subTests |
| ParseTest.test_non_text_encodings | decorator:support.subTests |
| ChardataBufferTest.test_large_character_data_does_not_crash | decorator:support.requires_resource |
| ElementDeclHandlerTest.test_deeply_nested_content_model | decorator:support.skip_if_unlimited_stack_size |
| ExternalEntityParserCreateErrorTest.test_error_path_no_crash | decorator:unittest.skipIf |
| MemoryProtectionTest.test_set_activation_threshold__threshold_reached | skipped-on-host |
| MemoryProtectionTest.test_set_activation_threshold__threshold_not_reached | skipped-on-host |
| MemoryProtectionTest.test_set_maximum_amplification__amplification_exceeded | skipped-on-host |
| MemoryProtectionTest.test_set_maximum_amplification__amplification_not_exceeded | skipped-on-host |
| MemoryProtectionTest.test_payload_generation | skipped-on-host |
| MemoryProtectionTest.test_set_activation_threshold__invalid_threshold_type | skipped-on-host |
| MemoryProtectionTest.test_set_activation_threshold__invalid_threshold_range | skipped-on-host |
| MemoryProtectionTest.test_set_activation_threshold__fail_for_subparser | skipped-on-host |
| MemoryProtectionTest.test_set_maximum_amplification__infinity | skipped-on-host |
| MemoryProtectionTest.test_set_maximum_amplification__invalid_max_factor_type | skipped-on-host |
| MemoryProtectionTest.test_set_maximum_amplification__invalid_max_factor_range | skipped-on-host |
| MemoryProtectionTest.test_set_maximum_amplification__fail_for_subparser | skipped-on-host |
| ParseTest.test_parse_again | unresolved-name:cm |
| BufferTextTest.test_default_to_disabled | uses-self.CharacterDataHandler |
| BufferTextTest.test_buffering_enabled | uses-self.CharacterDataHandler |
| BufferTextTest.test1 | uses-self.CharacterDataHandler |
| BufferTextTest.test2 | uses-self.CharacterDataHandler |
| BufferTextTest.test3 | uses-self.CharacterDataHandler |
| BufferTextTest.test4 | uses-self.CharacterDataHandler |
| BufferTextTest.test5 | uses-self.CharacterDataHandler |
| BufferTextTest.test6 | uses-self.CharacterDataHandler |
| BufferTextTest.test7 | uses-self.CharacterDataHandler |
| HandlerExceptionTest.test_exception | uses-self.StartElementHandler |
| PositionTest.test | uses-self.EndElementHandler |
| ChardataBufferTest.test_1025_bytes | uses-self.counting_handler |
| ChardataBufferTest.test_1000_bytes | uses-self.counting_handler |
| ChardataBufferTest.test_unchanged_size | uses-self.counting_handler |
| ChardataBufferTest.test_disabling_buffer | uses-self.counting_handler |
| ChardataBufferTest.test_change_size_1 | uses-self.counting_handler |
| ChardataBufferTest.test_change_size_2 | uses-self.counting_handler |
| ReparseDeferralTest.test_reparse_deferral_enabled | self.skipTest |
| ExpansionProtectionTest.test_payload_generation | helper:exponential_expansion_payload(decorated-helper) |
| MemoryProtectionTest.test_payload_generation | helper:exponential_expansion_payload(decorated-helper) |
| ExpansionProtectionTest.test_set_activation_threshold__invalid_threshold_type | uses-self.set_activation_threshold |
| MemoryProtectionTest.test_set_activation_threshold__invalid_threshold_type | uses-self.set_activation_threshold |
| ExpansionProtectionTest.test_set_activation_threshold__invalid_threshold_range | uses-self.set_activation_threshold |
| MemoryProtectionTest.test_set_activation_threshold__invalid_threshold_range | uses-self.set_activation_threshold |
| ExpansionProtectionTest.test_set_activation_threshold__fail_for_subparser | uses-self.set_activation_threshold |
| MemoryProtectionTest.test_set_activation_threshold__fail_for_subparser | uses-self.set_activation_threshold |
| ExpansionProtectionTest.test_set_maximum_amplification__invalid_max_factor_type | uses-self.set_maximum_amplification |
| MemoryProtectionTest.test_set_maximum_amplification__invalid_max_factor_type | uses-self.set_maximum_amplification |
| ExpansionProtectionTest.test_set_maximum_amplification__invalid_max_factor_range | uses-self.set_maximum_amplification |
| MemoryProtectionTest.test_set_maximum_amplification__invalid_max_factor_range | uses-self.set_maximum_amplification |
| ExpansionProtectionTest.test_set_maximum_amplification__fail_for_subparser | uses-self.set_maximum_amplification |
| MemoryProtectionTest.test_set_maximum_amplification__fail_for_subparser | uses-self.set_maximum_amplification |
| ExpansionProtectionTest.test_set_activation_threshold__threshold_reached | helper:exponential_expansion_payload(decorated-helper) |
| ExpansionProtectionTest.test_set_activation_threshold__threshold_not_reached | helper:exponential_expansion_payload(decorated-helper) |
| ExpansionProtectionTest.test_set_maximum_amplification__amplification_exceeded | helper:exponential_expansion_payload(decorated-helper) |
| ExpansionProtectionTest.test_set_maximum_amplification__amplification_not_exceeded | helper:exponential_expansion_payload(decorated-helper) |
| ExpansionProtectionTest.test_payload_generation | helper:exponential_expansion_payload(decorated-helper) |
| ExpansionProtectionTest.test_set_activation_threshold__invalid_threshold_type | uses-self.set_activation_threshold |
| ExpansionProtectionTest.test_set_activation_threshold__invalid_threshold_range | uses-self.set_activation_threshold |
| ExpansionProtectionTest.test_set_activation_threshold__fail_for_subparser | uses-self.set_activation_threshold |
| ExpansionProtectionTest.test_set_maximum_amplification__invalid_max_factor_type | uses-self.set_maximum_amplification |
| ExpansionProtectionTest.test_set_maximum_amplification__invalid_max_factor_range | uses-self.set_maximum_amplification |
| ExpansionProtectionTest.test_set_maximum_amplification__fail_for_subparser | uses-self.set_maximum_amplification |
| ParseTest.test_parse_bytes | harness-error:SyntaxError: invalid syntax |
| ParseTest.test_parse_str | harness-error:SyntaxError: invalid syntax |
| ParseTest.test_parse_file | harness-error:SyntaxError: invalid syntax |
| ExpansionProtectionTest.test_set_maximum_amplification__infinity | host-raised:AttributeError: 'pyexpat.xmlparser' object has no attribute 'SetBillionLaughsAttackProtectionMaximumAmplification' |
| MemoryProtectionTest.test_set_maximum_amplification__infinity | host-raised:AttributeError: 'pyexpat.xmlparser' object has no attribute 'SetAllocTrackerMaximumAmplification' |
| ExpansionProtectionTest.test_set_maximum_amplification__infinity | host-raised:AttributeError: 'pyexpat.xmlparser' object has no attribute 'SetBillionLaughsAttackProtectionMaximumAmplification' |
