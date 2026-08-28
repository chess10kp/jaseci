# Triage report: `conv_xml_etree_pins.jac`

- source: /home/jac/repos/jac-python/reference/cpython/Lib/test/test_xml_etree.py
- guest leg: 0/2 marks
- pins: **0 passed** / 2 run (+223 quarantined of 225 extracted)

| pin | result | got |
|---|---|---|
| ModuleTest.test_sanity | VM-CRASH | jaclang/compiler/backends/native/na_ir_gen/gc_debug.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/generics.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/globals.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/hash_core.jac...   Compiling jaclang/compiler |
| ElementTreeTest.test_xpath_tokenizer | VM-CRASH | jaclang/compiler/backends/native/na_ir_gen/gc_debug.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/generics.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/globals.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/hash_core.jac...   Compiling jaclang/compiler |

## Shared failure signatures

These pins fail with a byte-identical detail, which usually means
one shared root cause (for example an import-time error in the
guest module) instead of per-test defects.

| count | classification | got | pins |
|---|---|---|---|
| 2 | VM-CRASH | jaclang/compiler/backends/native/na_ir_gen/gc_debug.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/generics.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/globals.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/hash_core.jac...   Compiling jaclang/compiler | ElementTreeTest.test_xpath_tokenizer, ModuleTest.test_sanity |

## Quarantined at conversion

| test | reason |
|---|---|
| ElementTreeTest.test_html_cdata_elems_serialization | decorator:support.subTests |
| XMLPullParserTest.test_flush_reparse_deferral_enabled | decorator:unittest.skipIf |
| BugsTest.test_bug_xmltoolkit63 | decorator:unittest.skipIf |
| BadElementTest.test_recursive_repr | decorator:support.infinite_recursion |
| BadElementTest.test_deeply_nested_deepcopy | decorator:support.skip_if_unlimited_stack_size |
| ElementTreeTest.test_custom_builder | uses-self.append |
| ElementTreeTest.test_custom_builder_only_end_ns | uses-self.append |
| ElementTreeTest.test_entity | unresolved-name:cm |
| IterparseTest.test_parsing_error | unresolved-name:cm |
| IterparseTest.test_resource_warnings_failed_iteration | self.addCleanup |
| XMLPullParserTest.test_simple_xml_chunk_1 | self.test_simple_xml |
| XMLPullParserTest.test_simple_xml_chunk_5 | self.test_simple_xml |
| XMLPullParserTest.test_simple_xml_chunk_22 | self.test_simple_xml |
| XMLPullParserTest.test_flush_reparse_deferral_disabled | self.skipTest |
| XIncludeTest.test_xinclude | unresolved-name:cm |
| XIncludeTest.test_xinclude_failures | unresolved-name:cm |
| BugsTest.test_bug_xmltoolkit21 | unresolved-name:cm |
| BugsTest.test_bug_xmltoolkit55 | unresolved-name:cm |
| BugsTest.test_bug_200709_default_namespace | unresolved-name:cm |
| BugsTest.test_lost_elem | self.skipTest |
| BasicElementTest.test_pickle | helper:assertEqualElements(helper:assertEqualElements(helper:assertEqualElements(helper:assertEqualElements(helper:assertEqualElements(helper:assertEqualElements(helper:assertEqualElements(helper:assertEqualElements(helper:assertEqualElements(helper:assertEqualElements(helper:assertEqualElements(helper:assertEqualElements(helper:assertEqualElements(helper:assertEqualElements(helper:assertEqualElements(helper:assertEqualElements(helper:assertEqualElements(helper:assertEqualElements(helper:assertEqualElements(helper:assertEqualElements(helper:assertEqualElements(helper:assertEqualElements(helper:assertEqualElements(helper:assertEqualElements(helper:assertEqualElements(helper:assertEqualElements(helper:assertEqualElements(helper:assertEqualElements(helper:assertEqualElements(helper:assertEqualElements(helper:assertEqualElements(helper:assertEqualElements(helper:assertEqualElements(helper:assertEqualElements(helper:assertEqualElements(helper:assertEqualElements(helper:assertEqualElements(helper:assertEqualElements(helper:assertEqualElements(helper:assertEqualElements(helper:assertEqualElements(helper:assertEqualElements(helper:assertEqualElements(helper:assertEqualElements(helper:assertEqualElements(helper:assertEqualElements(helper:assertEqualElements(helper:assertEqualElements(helper:assertEqualElements(helper:assertEqualElements(helper:assertEqualElements(helper:assertEqualElements(helper:assertEqualElements(helper:assertEqualElements(helper:assertEqualElements(helper:assertEqualElements(helper:assertEqualElements(helper:assertEqualElements(helper:assertEqualElements(helper:assertEqualElements(helper:assertEqualElements(helper:assertEqualElements(helper:assertEqualElements(helper:assertEqualElements(helper:assertEqualElements(helper:assertEqualElements(helper:assertEqualElements(helper:assertEqualElements(helper:assertEqualElements(helper:assertEqualElements(helper:assertEqualElements(helper:assertEqualElements(helper:assertEqualElements(helper:assertEqualElements(helper:assertEqualElements(helper:assertEqualElements(helper:assertEqualElements(helper:assertEqualElements(helper:assertEqualElements(helper:assertEqualElements(helper:assertEqualElements(helper:assertEqualElements(helper:assertEqualElements(helper:assertEqualElements(helper:assertEqualElements(helper:assertEqualElements(helper:assertEqualElements(helper:assertEqualElements(helper:assertEqualElements(helper:assertEqualElements(helper:assertEqualElements(helper:assertEqualElements(helper:assertEqualElements(helper:assertEqualElements(helper:assertEqualElements(helper:assertEqualElements(helper:assertEqualElements(helper:assertEqualElements(helper:assertEqualElements(helper:assertEqualElements(helper:assertEqualElements(helper:assertEqualElements(helper:assertEqualElements(helper:assertEqualElements(helper:assertEqualElements(helper:assertEqualElements(helper:assertEqualElements(helper:assertEqualElements(helper:assertEqualElements(helper:assertEqualElements(helper:assertEqualElements(helper:assertEqualElements(helper:assertEqualElements(helper:assertEqualElements(helper:assertEqualElements(helper:assertEqualElements(helper:assertEqualElements(helper:assertEqualElements(helper:assertEqualElements(helper:assertEqualElements(deepcopy-recursion)))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))) |
| BadElementTest.test_remove_with_clear_assume_missing | helper:do_test_remove_with_clear(self.enterContext) |
| BadElementTest.test_remove_with_clear_assume_existing | helper:do_test_remove_with_clear(self.enterContext) |
| BadElementTest.test_remove_with_mutate_root_assume_missing | helper:do_test_remove_with_mutate_root(uses-self.assertRaises) |
| BadElementTest.test_remove_with_mutate_root_assume_existing | helper:do_test_remove_with_mutate_root(uses-self.assertRaises) |
| ElementFindTest.test_find_through_ElementTree | uses-self.assertWarnsRegex |
| XMLParserTest.test_subclass_doctype | uses-self.assertWarnsRegex |
| IOTest.test_write_to_filename | self.addCleanup |
| IOTest.test_write_to_filename_with_encoding | self.addCleanup |
| IOTest.test_write_to_filename_as_unicode | self.addCleanup |
| IOTest.test_write_to_text_file | self.addCleanup |
| IOTest.test_write_to_binary_file | self.addCleanup |
| IOTest.test_write_to_binary_file_with_encoding | self.addCleanup |
| IOTest.test_write_to_binary_file_with_bom | self.addCleanup |
| IOTest.test_read_from_user_text_reader | uses-self.dummy |
| IOTest.test_write_to_user_text_writer | uses-self.dummy |
| IOTest.test_read_from_user_binary_reader | uses-self.dummy |
| IOTest.test_write_to_user_binary_writer | uses-self.dummy |
| IOTest.test_write_to_user_binary_writer_with_bom | uses-self.dummy |
| BoolTest.test_warning | uses-self.assertWarnsRegex |
| C14NTest.test_xml_c14n2 | self.skipTest |
| ModuleTest.test_all | host-raised:NameError: name 'self' is not defined |
| ElementTreeTest.test_constructor | host-raised:AttributeError: 'NoneType' object has no attribute 'ElementTree' |
| ElementTreeTest.test_setroot | host-raised:AttributeError: 'NoneType' object has no attribute 'ElementTree' |
| ElementTreeTest.test_interface | host-raised:AttributeError: 'NoneType' object has no attribute 'Element' |
| ElementTreeTest.test_set_attribute | host-raised:AttributeError: 'NoneType' object has no attribute 'Element' |
| ElementTreeTest.test_simpleops | host-raised:AttributeError: 'NoneType' object has no attribute 'XML' |
| ElementTreeTest.test_cdata | host-raised:AttributeError: 'NoneType' object has no attribute 'XML' |
| ElementTreeTest.test_file_init | host-raised:AttributeError: 'NoneType' object has no attribute 'ElementTree' |
| ElementTreeTest.test_path_cache | host-raised:AttributeError: 'NoneType' object has no attribute 'XML' |
| ElementTreeTest.test_copy | host-raised:AttributeError: 'NoneType' object has no attribute 'XML' |
| ElementTreeTest.test_attrib | host-raised:AttributeError: 'NoneType' object has no attribute 'Element' |
| ElementTreeTest.test_makeelement | host-raised:AttributeError: 'NoneType' object has no attribute 'Element' |
| ElementTreeTest.test_parsefile | host-raised:AttributeError: 'NoneType' object has no attribute 'parse' |
| ElementTreeTest.test_parseliteral | host-raised:AttributeError: 'NoneType' object has no attribute 'XML' |
| ElementTreeTest.test_writefile | host-raised:AttributeError: 'NoneType' object has no attribute 'Element' |
| ElementTreeTest.test_initialize_parser_without_target | host-raised:AttributeError: 'NoneType' object has no attribute 'XMLParser' |
| ElementTreeTest.test_children | host-raised:AttributeError: 'NoneType' object has no attribute 'parse' |
| ElementTreeTest.test_writestring | host-raised:AttributeError: 'NoneType' object has no attribute 'XML' |
| ElementTreeTest.test_indent | host-raised:AttributeError: 'NoneType' object has no attribute 'XML' |
| ElementTreeTest.test_indent_space | host-raised:AttributeError: 'NoneType' object has no attribute 'XML' |
| ElementTreeTest.test_indent_space_caching | host-raised:AttributeError: 'NoneType' object has no attribute 'XML' |
| ElementTreeTest.test_indent_level | host-raised:AttributeError: 'NoneType' object has no attribute 'XML' |
| ElementTreeTest.test_tostring_default_namespace | host-raised:AttributeError: 'NoneType' object has no attribute 'XML' |
| ElementTreeTest.test_tostring_default_namespace_different_namespace | host-raised:AttributeError: 'NoneType' object has no attribute 'XML' |
| ElementTreeTest.test_tostring_default_namespace_original_no_namespace | host-raised:AttributeError: 'NoneType' object has no attribute 'XML' |
| ElementTreeTest.test_tostring_no_xml_declaration | host-raised:AttributeError: 'NoneType' object has no attribute 'XML' |
| ElementTreeTest.test_tostring_xml_declaration | host-raised:AttributeError: 'NoneType' object has no attribute 'XML' |
| ElementTreeTest.test_tostring_xml_declaration_unicode_encoding | host-raised:AttributeError: 'NoneType' object has no attribute 'XML' |
| ElementTreeTest.test_tostring_xml_declaration_cases | host-raised:AttributeError: 'NoneType' object has no attribute 'XML' |
| ElementTreeTest.test_tostringlist_default_namespace | host-raised:AttributeError: 'NoneType' object has no attribute 'XML' |
| ElementTreeTest.test_tostringlist_xml_declaration | host-raised:AttributeError: 'NoneType' object has no attribute 'XML' |
| ElementTreeTest.test_encoding | host-raised:AttributeError: 'NoneType' object has no attribute 'XML' |
| ElementTreeTest.test_methods | host-raised:AttributeError: 'NoneType' object has no attribute 'XML' |
| ElementTreeTest.test_issue18347 | host-raised:AttributeError: 'NoneType' object has no attribute 'XML' |
| ElementTreeTest.test_namespace | host-raised:AttributeError: 'NoneType' object has no attribute 'XML' |
| ElementTreeTest.test_qname | host-raised:AttributeError: 'NoneType' object has no attribute 'Element' |
| ElementTreeTest.test_doctype_public | host-raised:AttributeError: 'NoneType' object has no attribute 'XML' |
| ElementTreeTest.test_comment_serialization | host-raised:AttributeError: 'NoneType' object has no attribute 'Comment' |
| ElementTreeTest.test_processinginstruction_serialization | host-raised:AttributeError: 'NoneType' object has no attribute 'tostring' |
| ElementTreeTest.test_html_empty_elems_serialization | host-raised:AttributeError: 'NoneType' object has no attribute 'XML' |
| ElementTreeTest.test_html_plaintext_serialization | host-raised:AttributeError: 'NoneType' object has no attribute 'Element' |
| ElementTreeTest.test_dump_attribute_order | host-raised:AttributeError: 'NoneType' object has no attribute 'Element' |
| ElementTreeTest.test_tree_write_attribute_order | host-raised:AttributeError: 'NoneType' object has no attribute 'Element' |
| ElementTreeTest.test_attlist_default | host-raised:AttributeError: 'NoneType' object has no attribute 'fromstring' |
| IterparseTest.test_basic | host-raised:AttributeError: 'NoneType' object has no attribute 'iterparse' |
| IterparseTest.test_external_file | host-raised:AttributeError: 'NoneType' object has no attribute 'iterparse' |
| IterparseTest.test_events | host-raised:AttributeError: 'NoneType' object has no attribute 'iterparse' |
| IterparseTest.test_namespace_events | host-raised:AttributeError: 'NoneType' object has no attribute 'iterparse' |
| IterparseTest.test_unknown_events | host-raised:AttributeError: 'NoneType' object has no attribute 'iterparse' |
| IterparseTest.test_non_utf8 | host-raised:AttributeError: 'NoneType' object has no attribute 'iterparse' |
| IterparseTest.test_nonexistent_file | host-raised:AttributeError: 'NoneType' object has no attribute 'iterparse' |
| IterparseTest.test_resource_warnings_not_exhausted | host-raised:AttributeError: 'NoneType' object has no attribute 'iterparse' |
| IterparseTest.test_resource_warnings_exhausted | host-raised:AttributeError: 'NoneType' object has no attribute 'iterparse' |
| IterparseTest.test_close_not_exhausted | host-raised:AttributeError: 'NoneType' object has no attribute 'iterparse' |
| IterparseTest.test_close_exhausted | host-raised:AttributeError: 'NoneType' object has no attribute 'iterparse' |
| XMLPullParserTest.test_simple_xml | host-raised:AttributeError: 'NoneType' object has no attribute 'XMLPullParser' |
| XMLPullParserTest.test_feed_while_iterating | host-raised:AttributeError: 'NoneType' object has no attribute 'XMLPullParser' |
| XMLPullParserTest.test_simple_xml_with_ns | host-raised:AttributeError: 'NoneType' object has no attribute 'XMLPullParser' |
| XMLPullParserTest.test_ns_events | host-raised:AttributeError: 'NoneType' object has no attribute 'XMLPullParser' |
| XMLPullParserTest.test_ns_events_start | host-raised:AttributeError: 'NoneType' object has no attribute 'XMLPullParser' |
| XMLPullParserTest.test_ns_events_start_end | host-raised:AttributeError: 'NoneType' object has no attribute 'XMLPullParser' |
| XMLPullParserTest.test_events | host-raised:AttributeError: 'NoneType' object has no attribute 'XMLPullParser' |
| XMLPullParserTest.test_events_comment | host-raised:AttributeError: 'NoneType' object has no attribute 'XMLPullParser' |
| XMLPullParserTest.test_events_pi | host-raised:AttributeError: 'NoneType' object has no attribute 'XMLPullParser' |
| XMLPullParserTest.test_events_sequence | host-raised:AttributeError: 'NoneType' object has no attribute 'XMLPullParser' |
| XMLPullParserTest.test_unknown_event | host-raised:AttributeError: 'NoneType' object has no attribute 'XMLPullParser' |
| XIncludeTest.test_xinclude_default | host-raised:OSError: resource not found |
| XIncludeTest.test_xinclude_repeated | host-raised:OSError: resource not found |
| BugsTest.test_bug_xmltoolkit25 | host-raised:AttributeError: 'NoneType' object has no attribute 'XML' |
| BugsTest.test_bug_xmltoolkit28 | host-raised:AttributeError: 'NoneType' object has no attribute 'XML' |
| BugsTest.test_bug_xmltoolkitX1 | host-raised:AttributeError: 'NoneType' object has no attribute 'XML' |
| BugsTest.test_bug_xmltoolkit39 | host-raised:AttributeError: 'NoneType' object has no attribute 'XML' |
| BugsTest.test_bug_xmltoolkit54 | host-raised:AttributeError: 'NoneType' object has no attribute 'XML' |
| BugsTest.test_bug_xmltoolkit60 | host-raised:AttributeError: 'NoneType' object has no attribute 'parse' |
| BugsTest.test_bug_xmltoolkit62 | host-raised:AttributeError: 'NoneType' object has no attribute 'XMLParser' |
| BugsTest.test_bug_200708_newline | host-raised:AttributeError: 'NoneType' object has no attribute 'Element' |
| BugsTest.test_bug_200708_close | host-raised:AttributeError: 'NoneType' object has no attribute 'XMLParser' |
| BugsTest.test_bug_200709_register_namespace | host-raised:AttributeError: 'NoneType' object has no attribute 'Element' |
| BugsTest.test_bug_200709_element_comment | host-raised:AttributeError: 'NoneType' object has no attribute 'Element' |
| BugsTest.test_bug_200709_element_insert | host-raised:AttributeError: 'NoneType' object has no attribute 'Element' |
| BugsTest.test_bug_200709_iter_comment | host-raised:AttributeError: 'NoneType' object has no attribute 'Element' |
| BugsTest.test_bug_1534630 | host-raised:AttributeError: 'NoneType' object has no attribute 'TreeBuilder' |
| BugsTest.test_issue6233 | host-raised:AttributeError: 'NoneType' object has no attribute 'XML' |
| BugsTest.test_issue6565 | host-raised:AttributeError: 'NoneType' object has no attribute 'XML' |
| BugsTest.test_issue10777 | host-raised:AttributeError: 'NoneType' object has no attribute 'register_namespace' |
| BugsTest.test_lost_text | host-raised:AttributeError: 'NoneType' object has no attribute 'Element' |
| BugsTest.test_lost_tail | host-raised:AttributeError: 'NoneType' object has no attribute 'Element' |
| BugsTest.test_expat224_utf8_bug | host-raised:AttributeError: 'NoneType' object has no attribute 'XML' |
| BugsTest.test_expat224_utf8_bug_file | host-raised:AttributeError: 'NoneType' object has no attribute 'fromstring' |
| BugsTest.test_39495_treebuilder_start | host-raised:AttributeError: 'NoneType' object has no attribute 'TreeBuilder' |
| BugsTest.test_issue123213_correct_extend_exception | host-raised:AttributeError: 'NoneType' object has no attribute 'Element' |
| BasicElementTest.test___init__ | host-raised:AttributeError: 'NoneType' object has no attribute 'Element' |
| BasicElementTest.test___copy__ | host-raised:AttributeError: 'NoneType' object has no attribute 'Element' |
| BasicElementTest.test___deepcopy__ | host-raised:AttributeError: 'NoneType' object has no attribute 'Element' |
| BasicElementTest.test_augmentation_type_errors | host-raised:AttributeError: 'NoneType' object has no attribute 'Element' |
| BasicElementTest.test_cyclic_gc | host-raised:AttributeError: 'NoneType' object has no attribute 'Element' |
| BasicElementTest.test_weakref | host-raised:AttributeError: 'NoneType' object has no attribute 'Element' |
| BasicElementTest.test_get_keyword_args | host-raised:AttributeError: 'NoneType' object has no attribute 'Element' |
| BasicElementTest.test_pickle_issue18997 | host-raised:AttributeError: '_SelfNS' object has no attribute 'modules' |
| BadElementTest.test_extend_mutable_list | host-raised:AttributeError: 'NoneType' object has no attribute 'Element' |
| BadElementTest.test_extend_mutable_list2 | host-raised:AttributeError: 'NoneType' object has no attribute 'Element' |
| BadElementTest.test_element_get_text | host-raised:AttributeError: 'NoneType' object has no attribute 'TreeBuilder' |
| BadElementTest.test_element_get_tail | host-raised:AttributeError: 'NoneType' object has no attribute 'TreeBuilder' |
| BadElementTest.test_subscr_with_clear | host-raised:AttributeError: 'NoneType' object has no attribute 'Element' |
| BadElementTest.test_subscr_with_delete | host-raised:AttributeError: 'NoneType' object has no attribute 'Element' |
| BadElementTest.test_ass_subscr_with_mutating_slice | host-raised:AttributeError: 'NoneType' object has no attribute 'Element' |
| BadElementTest.test_ass_subscr_with_mutating_iterable_value | host-raised:AttributeError: 'NoneType' object has no attribute 'Element' |
| BadElementTest.test_treebuilder_start | host-raised:AttributeError: 'NoneType' object has no attribute 'TreeBuilder' |
| BadElementTest.test_treebuilder_end | host-raised:AttributeError: 'NoneType' object has no attribute 'TreeBuilder' |
| BadElementTest.test_deepcopy_clear | host-raised:AttributeError: 'NoneType' object has no attribute 'Element' |
| BadElementTest.test_deepcopy_grow | host-raised:AttributeError: 'NoneType' object has no attribute 'Element' |
| BadElementPathTest.test_find_with_mutating | host-raised:RuntimeError: super(): no arguments |
| BadElementPathTest.test_find_with_error | host-raised:RuntimeError: super(): no arguments |
| BadElementPathTest.test_findtext_with_mutating | host-raised:RuntimeError: super(): no arguments |
| BadElementPathTest.test_findtext_with_mutating_non_none_text | host-raised:RuntimeError: super(): no arguments |
| BadElementPathTest.test_findtext_with_error | host-raised:RuntimeError: super(): no arguments |
| BadElementPathTest.test_findtext_with_falsey_text_attribute | host-raised:RuntimeError: super(): no arguments |
| BadElementPathTest.test_findtext_with_none_text_attribute | host-raised:RuntimeError: super(): no arguments |
| BadElementPathTest.test_findall_with_mutating | host-raised:RuntimeError: super(): no arguments |
| BadElementPathTest.test_findall_with_error | host-raised:RuntimeError: super(): no arguments |
| ElementTreeTypeTest.test_istype | host-raised:AttributeError: 'NoneType' object has no attribute 'ParseError' |
| ElementTreeTypeTest.test_Element_subclass_trivial | host-raised:AttributeError: 'NoneType' object has no attribute 'Element' |
| ElementTreeTypeTest.test_Element_subclass_constructor | host-raised:AttributeError: 'NoneType' object has no attribute 'Element' |
| ElementTreeTypeTest.test_Element_subclass_new_method | host-raised:AttributeError: 'NoneType' object has no attribute 'Element' |
| ElementTreeTypeTest.test_Element_subclass_find | host-raised:AttributeError: 'NoneType' object has no attribute 'Element' |
| ElementFindTest.test_find_simple | host-raised:AttributeError: 'NoneType' object has no attribute 'XML' |
| ElementFindTest.test_find_xpath | host-raised:AttributeError: 'NoneType' object has no attribute 'XML' |
| ElementFindTest.test_findall | host-raised:AttributeError: 'NoneType' object has no attribute 'XML' |
| ElementFindTest.test_test_find_with_ns | host-raised:AttributeError: 'NoneType' object has no attribute 'XML' |
| ElementFindTest.test_findall_different_nsmaps | host-raised:AttributeError: 'NoneType' object has no attribute 'XML' |
| ElementFindTest.test_findall_wildcard | host-raised:AttributeError: 'NoneType' object has no attribute 'XML' |
| ElementFindTest.test_bad_find | host-raised:AttributeError: 'NoneType' object has no attribute 'XML' |
| ElementIterTest.test_basic | host-raised:AttributeError: 'NoneType' object has no attribute 'XML' |
| ElementIterTest.test_comment | host-raised:AttributeError: 'NoneType' object has no attribute 'Element' |
| ElementIterTest.test_processinginstruction | host-raised:AttributeError: 'NoneType' object has no attribute 'Element' |
| ElementIterTest.test_corners | host-raised:AttributeError: 'NoneType' object has no attribute 'Element' |
| ElementIterTest.test_iter_by_tag | host-raised:AttributeError: 'NoneType' object has no attribute 'XML' |
| ElementIterTest.test_copy | host-raised:AttributeError: 'NoneType' object has no attribute 'Element' |
| ElementIterTest.test_pickle | host-raised:AttributeError: 'NoneType' object has no attribute 'Element' |
| TreeBuilderTest.test_dummy_builder | host-raised:AttributeError: 'NoneType' object has no attribute 'XMLParser' |
| TreeBuilderTest.test_treebuilder_comment | host-raised:AttributeError: 'NoneType' object has no attribute 'TreeBuilder' |
| TreeBuilderTest.test_treebuilder_pi | host-raised:AttributeError: 'NoneType' object has no attribute 'TreeBuilder' |
| TreeBuilderTest.test_late_tail | host-raised:AttributeError: 'NoneType' object has no attribute 'TreeBuilder' |
| TreeBuilderTest.test_late_tail_mix_pi_comments | host-raised:AttributeError: 'NoneType' object has no attribute 'TreeBuilder' |
| TreeBuilderTest.test_treebuilder_elementfactory_none | host-raised:AttributeError: 'NoneType' object has no attribute 'XMLParser' |
| TreeBuilderTest.test_subclass | host-raised:AttributeError: 'NoneType' object has no attribute 'TreeBuilder' |
| TreeBuilderTest.test_subclass_comment_pi | host-raised:AttributeError: 'NoneType' object has no attribute 'TreeBuilder' |
| TreeBuilderTest.test_element_factory | host-raised:AttributeError: 'NoneType' object has no attribute 'TreeBuilder' |
| TreeBuilderTest.test_element_factory_subclass | host-raised:AttributeError: 'NoneType' object has no attribute 'Element' |
| TreeBuilderTest.test_element_factory_pure_python_subclass | host-raised:AttributeError: 'NoneType' object has no attribute '_Element_Py' |
| TreeBuilderTest.test_doctype | host-raised:AttributeError: 'NoneType' object has no attribute 'XMLParser' |
| TreeBuilderTest.test_builder_lookup_errors | host-raised:AttributeError: 'NoneType' object has no attribute 'XMLParser' |
| XMLParserTest.test_constructor_args | host-raised:AttributeError: 'NoneType' object has no attribute 'XMLParser' |
| XMLParserTest.test_subclass | host-raised:AttributeError: 'NoneType' object has no attribute 'XMLParser' |
| XMLParserTest.test_doctype_warning | host-raised:AttributeError: 'NoneType' object has no attribute 'XMLParser' |
| XMLParserTest.test_inherited_doctype | host-raised:AttributeError: 'NoneType' object has no attribute 'XMLParser' |
| XMLParserTest.test_parse_string | host-raised:AttributeError: 'NoneType' object has no attribute 'XMLParser' |
| NamespaceParseTest.test_find_with_namespace | host-raised:AttributeError: 'NoneType' object has no attribute 'fromstring' |
| ElementSlicingTest.test_getslice_single_index | host-raised:AttributeError: 'NoneType' object has no attribute 'Element' |
| ElementSlicingTest.test_getslice_range | host-raised:AttributeError: 'NoneType' object has no attribute 'Element' |
| ElementSlicingTest.test_getslice_steps | host-raised:AttributeError: 'NoneType' object has no attribute 'Element' |
| ElementSlicingTest.test_getslice_negative_steps | host-raised:AttributeError: 'NoneType' object has no attribute 'Element' |
| ElementSlicingTest.test_delslice | host-raised:AttributeError: 'NoneType' object has no attribute 'Element' |
| ElementSlicingTest.test_setslice_single_index | host-raised:AttributeError: 'NoneType' object has no attribute 'Element' |
| ElementSlicingTest.test_setslice_range | host-raised:AttributeError: 'NoneType' object has no attribute 'Element' |
| ElementSlicingTest.test_setslice_steps | host-raised:AttributeError: 'NoneType' object has no attribute 'Element' |
| ElementSlicingTest.test_setslice_negative_steps | host-raised:AttributeError: 'NoneType' object has no attribute 'Element' |
| ElementSlicingTest.test_issue123213_setslice_exception | host-raised:AttributeError: 'NoneType' object has no attribute 'Element' |
| IOTest.test_encoding | host-raised:AttributeError: 'NoneType' object has no attribute 'Element' |
| IOTest.test_read_from_stringio | host-raised:AttributeError: 'NoneType' object has no attribute 'ElementTree' |
| IOTest.test_write_to_stringio | host-raised:AttributeError: 'NoneType' object has no attribute 'ElementTree' |
| IOTest.test_read_from_bytesio | host-raised:AttributeError: 'NoneType' object has no attribute 'ElementTree' |
| IOTest.test_write_to_bytesio | host-raised:AttributeError: 'NoneType' object has no attribute 'ElementTree' |
| IOTest.test_tostringlist_invariant | host-raised:AttributeError: 'NoneType' object has no attribute 'fromstring' |
| IOTest.test_short_empty_elements | host-raised:AttributeError: 'NoneType' object has no attribute 'fromstring' |
| ParseErrorTest.test_subclass | host-raised:AttributeError: 'NoneType' object has no attribute 'ParseError' |
| ParseErrorTest.test_error_position | host-raised:AttributeError: 'NoneType' object has no attribute 'ParseError' |
| ParseErrorTest.test_error_code | host-raised:AttributeError: 'NoneType' object has no attribute 'ParseError' |
| KeywordArgsTest.test_issue14818 | host-raised:AttributeError: 'NoneType' object has no attribute 'XML' |
| NoAcceleratorTest.test_correct_import_pyET | host-raised:AttributeError: 'NoneType' object has no attribute 'Element' |
| C14NTest.test_simple_roundtrip | host-raised:AttributeError: 'NoneType' object has no attribute 'canonicalize' |
| C14NTest.test_c14n_exclusion | host-raised:AttributeError: 'NoneType' object has no attribute 'canonicalize' |
