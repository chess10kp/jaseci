# Triage report: `conv_pprint_pins.jac`

- source: /home/jac/repos/jac-python/reference/cpython/Lib/test/test_pprint.py
- guest leg: 0/43 marks
- pins: **7 passed** / 43 run (+2 quarantined of 45 extracted)

| pin | result | got |
|---|---|---|
| QueryTestCase.test_lazy_import | GUEST-WRONG-OUTPUT | RUN<"ModuleNotFoundError: No module named 'test.support.import_helper'"> |
| QueryTestCase.test_init | PASS | |
| QueryTestCase.test_basic | PASS | |
| QueryTestCase.test_stdout_is_None | PASS | |
| QueryTestCase.test_knotted | GUEST-WRONG-OUTPUT | GOT<'ORACLE_EXC AssertionError "(\'assertTrue\', False)"'> |
| QueryTestCase.test_unreadable | GUEST-WRONG-OUTPUT | GOT<'ORACLE_EXC TypeError "bridge-table: type \'module\' has policy BridgePolicy.FAIL but no to_host conversion arm"'> |
| QueryTestCase.test_container_repr_override_called | GUEST-WRONG-OUTPUT | `GOT<"ORACLE_EXC TypeError 'EnumCheck.__init_subclass__() takes no keyword arguments'">` |
| QueryTestCase.test_basic_line_wrap | GUEST-WRONG-OUTPUT | `GOT<"ORACLE_EXC TypeError 'EnumCheck.__init_subclass__() takes no keyword arguments'">` |
| QueryTestCase.test_nested_indentations | GUEST-WRONG-OUTPUT | `GOT<"ORACLE_EXC TypeError 'EnumCheck.__init_subclass__() takes no keyword arguments'">` |
| QueryTestCase.test_integer | GUEST-WRONG-OUTPUT | GOT<'ORACLE_EXC TypeError "unsupported operand type(s) for +: \'Temperature\' and \'float\'"'> |
| QueryTestCase.test_sorted_dict | PASS | |
| QueryTestCase.test_sort_dict | PASS | |
| QueryTestCase.test_ordered_dict | GUEST-WRONG-OUTPUT | `GOT<"ORACLE_EXC TypeError 'EnumCheck.__init_subclass__() takes no keyword arguments'">` |
| QueryTestCase.test_mapping_proxy | GUEST-WRONG-OUTPUT | `GOT<"ORACLE_EXC TypeError 'EnumCheck.__init_subclass__() takes no keyword arguments'">` |
| QueryTestCase.test_empty_simple_namespace | PASS | |
| QueryTestCase.test_small_simple_namespace | GUEST-WRONG-OUTPUT | GOT<'ORACLE_EXC AssertionError "(\'assertEqual\', \'namespace(b=2, a=1)\', \'namespace(a=1, b=2)\')"'> |
| QueryTestCase.test_simple_namespace | GUEST-WRONG-OUTPUT | `GOT<"ORACLE_EXC TypeError 'EnumCheck.__init_subclass__() takes no keyword arguments'">` |
| QueryTestCase.test_simple_namespace_subclass | GUEST-WRONG-OUTPUT | `GOT<'ORACLE_EXC AssertionError "(\'assertEqual\', \'<__main__.AdvancedNamespace object at 0x7fdb92d123d0>\', \'AdvancedNamespace(the=0,\\\\n                  quick=1,\\\\n                  brown=2,\\\\n                  fox=3,\\\\n                  jumped=4,\\\\n                  over=5,\\\\n                  a=6,\\\\n                  lazy=7,\\\\n                  dog=8)\')"'>` |
| QueryTestCase.test_empty_dataclass | GUEST-WRONG-OUTPUT | `RUN<'TypeError: EnumCheck.__init_subclass__() takes no keyword arguments'>` |
| QueryTestCase.test_small_dataclass | GUEST-WRONG-OUTPUT | `RUN<'TypeError: EnumCheck.__init_subclass__() takes no keyword arguments'>` |
| QueryTestCase.test_larger_dataclass | GUEST-WRONG-OUTPUT | `RUN<'TypeError: EnumCheck.__init_subclass__() takes no keyword arguments'>` |
| QueryTestCase.test_dataclass_with_repr | GUEST-WRONG-OUTPUT | `RUN<'TypeError: EnumCheck.__init_subclass__() takes no keyword arguments'>` |
| QueryTestCase.test_dataclass_no_repr | GUEST-WRONG-OUTPUT | `RUN<'TypeError: EnumCheck.__init_subclass__() takes no keyword arguments'>` |
| QueryTestCase.test_recursive_dataclass | GUEST-WRONG-OUTPUT | `RUN<'TypeError: EnumCheck.__init_subclass__() takes no keyword arguments'>` |
| QueryTestCase.test_cyclic_dataclass | GUEST-WRONG-OUTPUT | `RUN<'TypeError: EnumCheck.__init_subclass__() takes no keyword arguments'>` |
| QueryTestCase.test_subclassing | GUEST-WRONG-OUTPUT | `GOT<"ORACLE_EXC TypeError 'EnumCheck.__init_subclass__() takes no keyword arguments'">` |
| QueryTestCase.test_set_reprs | GUEST-WRONG-OUTPUT | `GOT<"ORACLE_EXC TypeError 'EnumCheck.__init_subclass__() takes no keyword arguments'">` |
| QueryTestCase.test_set_of_sets_reprs | GUEST-WRONG-OUTPUT | `GOT<"ORACLE_EXC TypeError 'EnumCheck.__init_subclass__() takes no keyword arguments'">` |
| QueryTestCase.test_depth | PASS | |
| QueryTestCase.test_sort_unorderable_values | GUEST-WRONG-OUTPUT | RUN<"AttributeError: 'super' object has no attribute 'seed'"> |
| QueryTestCase.test_sort_orderable_and_unorderable_values | GUEST-WRONG-OUTPUT | `GOT<"ORACLE_EXC TypeError 'EnumCheck.__init_subclass__() takes no keyword arguments'">` |
| QueryTestCase.test_str_wrap | GUEST-WRONG-OUTPUT | `GOT<"ORACLE_EXC TypeError 'EnumCheck.__init_subclass__() takes no keyword arguments'">` |
| QueryTestCase.test_compact | GUEST-WRONG-OUTPUT | `GOT<"ORACLE_EXC TypeError 'EnumCheck.__init_subclass__() takes no keyword arguments'">` |
| QueryTestCase.test_compact_width | GUEST-WRONG-OUTPUT | `GOT<"ORACLE_EXC TypeError 'EnumCheck.__init_subclass__() takes no keyword arguments'">` |
| QueryTestCase.test_bytes_wrap | GUEST-WRONG-OUTPUT | `GOT<"ORACLE_EXC TypeError 'EnumCheck.__init_subclass__() takes no keyword arguments'">` |
| QueryTestCase.test_bytearray_wrap | GUEST-WRONG-OUTPUT | `GOT<"ORACLE_EXC TypeError 'EnumCheck.__init_subclass__() takes no keyword arguments'">` |
| QueryTestCase.test_default_dict | GUEST-WRONG-OUTPUT | `GOT<"ORACLE_EXC TypeError 'EnumCheck.__init_subclass__() takes no keyword arguments'">` |
| QueryTestCase.test_counter | GUEST-WRONG-OUTPUT | `GOT<"ORACLE_EXC TypeError 'EnumCheck.__init_subclass__() takes no keyword arguments'">` |
| QueryTestCase.test_chainmap | GUEST-WRONG-OUTPUT | `GOT<"ORACLE_EXC TypeError 'EnumCheck.__init_subclass__() takes no keyword arguments'">` |
| QueryTestCase.test_deque | GUEST-WRONG-OUTPUT | `GOT<"ORACLE_EXC TypeError 'EnumCheck.__init_subclass__() takes no keyword arguments'">` |
| QueryTestCase.test_user_dict | GUEST-WRONG-OUTPUT | `GOT<"ORACLE_EXC TypeError 'EnumCheck.__init_subclass__() takes no keyword arguments'">` |
| QueryTestCase.test_user_list | GUEST-WRONG-OUTPUT | `GOT<"ORACLE_EXC TypeError 'EnumCheck.__init_subclass__() takes no keyword arguments'">` |
| QueryTestCase.test_user_string | GUEST-WRONG-OUTPUT | `GOT<"ORACLE_EXC TypeError 'EnumCheck.__init_subclass__() takes no keyword arguments'">` |

## Quarantined at conversion

| test | reason |
|---|---|
| QueryTestCase.test_same_as_repr | host-raised:AttributeError: '_SelfNS' object has no attribute 'assertTrue' |
| QueryTestCase.test_width | host-raised:NameError: name 'set2' is not defined |

## Expected vs got

### QueryTestCase.test_basic_line_wrap (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: `GOT<"ORACLE_EXC TypeError 'EnumCheck.__init_subclass__() takes no keyword arguments'">`

### QueryTestCase.test_bytearray_wrap (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: `GOT<"ORACLE_EXC TypeError 'EnumCheck.__init_subclass__() takes no keyword arguments'">`

### QueryTestCase.test_bytes_wrap (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: `GOT<"ORACLE_EXC TypeError 'EnumCheck.__init_subclass__() takes no keyword arguments'">`

### QueryTestCase.test_chainmap (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: `GOT<"ORACLE_EXC TypeError 'EnumCheck.__init_subclass__() takes no keyword arguments'">`

### QueryTestCase.test_compact (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: `GOT<"ORACLE_EXC TypeError 'EnumCheck.__init_subclass__() takes no keyword arguments'">`

### QueryTestCase.test_compact_width (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: `GOT<"ORACLE_EXC TypeError 'EnumCheck.__init_subclass__() takes no keyword arguments'">`

### QueryTestCase.test_container_repr_override_called (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: `GOT<"ORACLE_EXC TypeError 'EnumCheck.__init_subclass__() takes no keyword arguments'">`

### QueryTestCase.test_counter (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: `GOT<"ORACLE_EXC TypeError 'EnumCheck.__init_subclass__() takes no keyword arguments'">`

### QueryTestCase.test_cyclic_dataclass (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: `RUN<'TypeError: EnumCheck.__init_subclass__() takes no keyword arguments'>`

### QueryTestCase.test_dataclass_no_repr (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: `RUN<'TypeError: EnumCheck.__init_subclass__() takes no keyword arguments'>`

### QueryTestCase.test_dataclass_with_repr (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: `RUN<'TypeError: EnumCheck.__init_subclass__() takes no keyword arguments'>`

### QueryTestCase.test_default_dict (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: `GOT<"ORACLE_EXC TypeError 'EnumCheck.__init_subclass__() takes no keyword arguments'">`

### QueryTestCase.test_deque (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: `GOT<"ORACLE_EXC TypeError 'EnumCheck.__init_subclass__() takes no keyword arguments'">`

### QueryTestCase.test_empty_dataclass (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: `RUN<'TypeError: EnumCheck.__init_subclass__() takes no keyword arguments'>`

### QueryTestCase.test_integer (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<'ORACLE_EXC TypeError "unsupported operand type(s) for +: \'Temperature\' and \'float\'"'>

### QueryTestCase.test_knotted (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<'ORACLE_EXC AssertionError "(\'assertTrue\', False)"'>

### QueryTestCase.test_larger_dataclass (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: `RUN<'TypeError: EnumCheck.__init_subclass__() takes no keyword arguments'>`

### QueryTestCase.test_lazy_import (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"ModuleNotFoundError: No module named 'test.support.import_helper'">

### QueryTestCase.test_mapping_proxy (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: `GOT<"ORACLE_EXC TypeError 'EnumCheck.__init_subclass__() takes no keyword arguments'">`

### QueryTestCase.test_nested_indentations (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: `GOT<"ORACLE_EXC TypeError 'EnumCheck.__init_subclass__() takes no keyword arguments'">`

### QueryTestCase.test_ordered_dict (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: `GOT<"ORACLE_EXC TypeError 'EnumCheck.__init_subclass__() takes no keyword arguments'">`

### QueryTestCase.test_recursive_dataclass (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: `RUN<'TypeError: EnumCheck.__init_subclass__() takes no keyword arguments'>`

### QueryTestCase.test_set_of_sets_reprs (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: `GOT<"ORACLE_EXC TypeError 'EnumCheck.__init_subclass__() takes no keyword arguments'">`

### QueryTestCase.test_set_reprs (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: `GOT<"ORACLE_EXC TypeError 'EnumCheck.__init_subclass__() takes no keyword arguments'">`

### QueryTestCase.test_simple_namespace (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: `GOT<"ORACLE_EXC TypeError 'EnumCheck.__init_subclass__() takes no keyword arguments'">`

### QueryTestCase.test_simple_namespace_subclass (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: `GOT<'ORACLE_EXC AssertionError "(\'assertEqual\', \'<__main__.AdvancedNamespace object at 0x7fdb92d123d0>\', \'AdvancedNamespace(the=0,\\\\n                  quick=1,\\\\n                  brown=2,\\\\n                  fox=3,\\\\n                  jumped=4,\\\\n                  over=5,\\\\n                  a=6,\\\\n                  lazy=7,\\\\n                  dog=8)\')"'>`

### QueryTestCase.test_small_dataclass (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: `RUN<'TypeError: EnumCheck.__init_subclass__() takes no keyword arguments'>`

### QueryTestCase.test_small_simple_namespace (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<'ORACLE_EXC AssertionError "(\'assertEqual\', \'namespace(b=2, a=1)\', \'namespace(a=1, b=2)\')"'>

### QueryTestCase.test_sort_orderable_and_unorderable_values (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: `GOT<"ORACLE_EXC TypeError 'EnumCheck.__init_subclass__() takes no keyword arguments'">`

### QueryTestCase.test_sort_unorderable_values (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"AttributeError: 'super' object has no attribute 'seed'">

### QueryTestCase.test_str_wrap (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: `GOT<"ORACLE_EXC TypeError 'EnumCheck.__init_subclass__() takes no keyword arguments'">`

### QueryTestCase.test_subclassing (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: `GOT<"ORACLE_EXC TypeError 'EnumCheck.__init_subclass__() takes no keyword arguments'">`

### QueryTestCase.test_unreadable (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<'ORACLE_EXC TypeError "bridge-table: type \'module\' has policy BridgePolicy.FAIL but no to_host conversion arm"'>

### QueryTestCase.test_user_dict (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: `GOT<"ORACLE_EXC TypeError 'EnumCheck.__init_subclass__() takes no keyword arguments'">`

### QueryTestCase.test_user_list (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: `GOT<"ORACLE_EXC TypeError 'EnumCheck.__init_subclass__() takes no keyword arguments'">`

### QueryTestCase.test_user_string (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: `GOT<"ORACLE_EXC TypeError 'EnumCheck.__init_subclass__() takes no keyword arguments'">`
