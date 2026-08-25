# Triage report: `conv_property_pins.jac`

- source: /home/jac/repos/jac-python/reference/cpython/Lib/test/test_property.py
- guest leg: 0/9 marks
- pins: **3 passed** / 9 run (+22 quarantined of 31 extracted)

| pin | result | got |
|---|---|---|
| PropertyTests.test_property_decorator_baseclass | PASS | |
| PropertyTests.test_property_decorator_subclass | PASS | |
| PropertyTests.test_property_decorator_doc | GUEST-WRONG-OUTPUT | GOT<'ORACLE_EXC AssertionError "(\'assertEqual\', None, \'spam spam spam\')"'> |
| PropertyTests.test_property___isabstractmethod__descriptor | GUEST-WRONG-OUTPUT | GOT<'ORACLE_EXC AssertionError "(\'assertIs\', False, True)"'> |
| PropertyTests.test_property_name | GUEST-WRONG-OUTPUT | `GOT<"ORACLE_EXC AttributeError '__name__'">` |
| PropertyTests.test_property_set_name_incorrect_args | GUEST-WRONG-OUTPUT | `GOT<"ORACLE_EXC AttributeError '__set_name__'">` |
| PropertyTests.test_property_setname_on_property_subclass | GUEST-WRONG-OUTPUT | `GOT<"ORACLE_EXC AttributeError '__set_name__'">` |
| PropertySubclassTests.test_property_with_slots_no_docstring | PASS | |
| PropertySubclassTests.test_property_no_doc_on_getter | GUEST-WRONG-OUTPUT | GOT<'ORACLE_EXC AssertionError "(\'assertEqual\', \'This is a subclass of property\', None)"'> |

## Quarantined at conversion

| test | reason |
|---|---|
| PropertyTests.test_property_decorator_subclass_doc | decorator:unittest.skipIf |
| PropertyTests.test_property_decorator_baseclass_doc | decorator:unittest.skipIf |
| PropertyTests.test_property_getter_doc_override | decorator:unittest.skipIf |
| PropertyTests.test_property_builtin_doc_writable | decorator:unittest.skipIf |
| PropertyTests.test_property_decorator_doc_writable | decorator:unittest.skipIf |
| PropertyTests.test_refleaks_in___init__ | decorator:support.refcount_test |
| PropertyTests.test_gh_115618 | decorator:support.refcount_test |
| PropertySubclassTests.test_slots_docstring_copy_exception | decorator:support.requires_docstrings |
| PropertySubclassTests.test_property_with_slots_docstring_silently_dropped | decorator:unittest.skipIf |
| PropertySubclassTests.test_property_with_slots_and_doc_slot_docstring_present | decorator:unittest.skipIf |
| PropertySubclassTests.test_issue41287 | decorator:unittest.skipIf |
| PropertySubclassTests.test_docstring_copy | decorator:unittest.skipIf |
| PropertySubclassTests.test_docstring_copy2 | decorator:unittest.skipIf |
| PropertySubclassTests.test_prefer_explicit_doc | decorator:unittest.skipIf |
| PropertySubclassTests.test_property_setter_copies_getter_docstring | decorator:unittest.skipIf |
| PropertySubclassTests.test_property_new_getter_new_docstring | decorator:unittest.skipIf |
| PropertyUnreachableAttributeNoName.test_get_property | unresolved-name:_format_exc_msg |
| PropertyUnreachableAttributeNoName.test_set_property | unresolved-name:_format_exc_msg |
| PropertyUnreachableAttributeNoName.test_del_property | unresolved-name:_format_exc_msg |
| PropertyUnreachableAttributeWithName.test_get_property | host-raised:NameError: name 'self' is not defined |
| PropertyUnreachableAttributeWithName.test_set_property | host-raised:NameError: name 'self' is not defined |
| PropertyUnreachableAttributeWithName.test_del_property | host-raised:NameError: name 'self' is not defined |

## Expected vs got

### PropertySubclassTests.test_property_no_doc_on_getter (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<'ORACLE_EXC AssertionError "(\'assertEqual\', \'This is a subclass of property\', None)"'>

### PropertyTests.test_property___isabstractmethod__descriptor (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<'ORACLE_EXC AssertionError "(\'assertIs\', False, True)"'>

### PropertyTests.test_property_decorator_doc (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<'ORACLE_EXC AssertionError "(\'assertEqual\', None, \'spam spam spam\')"'>

### PropertyTests.test_property_name (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: `GOT<"ORACLE_EXC AttributeError '__name__'">`

### PropertyTests.test_property_set_name_incorrect_args (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: `GOT<"ORACLE_EXC AttributeError '__set_name__'">`

### PropertyTests.test_property_setname_on_property_subclass (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: `GOT<"ORACLE_EXC AttributeError '__set_name__'">`
