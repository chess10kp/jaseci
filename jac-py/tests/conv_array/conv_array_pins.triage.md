# Triage report: `conv_array_pins.jac`

- source: /home/jac/repos/jac-python/reference/cpython/Lib/test/test_array.py
- guest leg: 0/511 marks
- pins: **90 passed** / 511 run (+276 quarantined of 787 extracted)

| pin | result | got |
|---|---|---|
| MiscTest.test_array_is_sequence | PASS | |
| MiscTest.test_bad_constructor | PASS | |
| MiscTest.test_empty | GUEST-WRONG-OUTPUT | GOT<"ORACLE_EXC TypeError 'object does not support item assignment'"> |
| ArrayReconstructorTest.test_error | PASS | |
| ArrayReconstructorTest.test_numbers | PASS | |
| ByteTest.test_constructor | PASS | |
| ShortTest.test_constructor | PASS | |
| IntTest.test_constructor | PASS | |
| LongTest.test_constructor | PASS | |
| LongLongTest.test_constructor | PASS | |
| UnsignedByteTest.test_constructor | PASS | |
| UnsignedShortTest.test_constructor | PASS | |
| UnsignedIntTest.test_constructor | PASS | |
| UnsignedLongTest.test_constructor | PASS | |
| UnsignedLongLongTest.test_constructor | PASS | |
| FloatTest.test_constructor | PASS | |
| DoubleTest.test_constructor | PASS | |
| ByteTest.test_len | PASS | |
| ShortTest.test_len | PASS | |
| IntTest.test_len | PASS | |
| LongTest.test_len | PASS | |
| LongLongTest.test_len | PASS | |
| UnsignedByteTest.test_len | PASS | |
| UnsignedShortTest.test_len | PASS | |
| UnsignedIntTest.test_len | PASS | |
| UnsignedLongTest.test_len | PASS | |
| UnsignedLongLongTest.test_len | PASS | |
| FloatTest.test_len | PASS | |
| DoubleTest.test_len | PASS | |
| ByteTest.test_buffer_info | PASS | |
| ShortTest.test_buffer_info | PASS | |
| IntTest.test_buffer_info | PASS | |
| LongTest.test_buffer_info | PASS | |
| LongLongTest.test_buffer_info | PASS | |
| UnsignedByteTest.test_buffer_info | PASS | |
| UnsignedShortTest.test_buffer_info | PASS | |
| UnsignedIntTest.test_buffer_info | PASS | |
| UnsignedLongTest.test_buffer_info | PASS | |
| UnsignedLongLongTest.test_buffer_info | PASS | |
| FloatTest.test_buffer_info | PASS | |
| DoubleTest.test_buffer_info | PASS | |
| ByteTest.test_byteswap | PASS | |
| ShortTest.test_byteswap | PASS | |
| IntTest.test_byteswap | PASS | |
| LongTest.test_byteswap | PASS | |
| LongLongTest.test_byteswap | PASS | |
| UnsignedByteTest.test_byteswap | PASS | |
| UnsignedShortTest.test_byteswap | PASS | |
| UnsignedIntTest.test_byteswap | PASS | |
| UnsignedLongTest.test_byteswap | PASS | |
| UnsignedLongLongTest.test_byteswap | PASS | |
| FloatTest.test_byteswap | PASS | |
| DoubleTest.test_byteswap | PASS | |
| ByteTest.test_copy | PASS | |
| ShortTest.test_copy | PASS | |
| IntTest.test_copy | PASS | |
| LongTest.test_copy | PASS | |
| LongLongTest.test_copy | PASS | |
| UnsignedByteTest.test_copy | PASS | |
| UnsignedShortTest.test_copy | PASS | |
| UnsignedIntTest.test_copy | PASS | |
| UnsignedLongTest.test_copy | PASS | |
| UnsignedLongLongTest.test_copy | PASS | |
| FloatTest.test_copy | PASS | |
| DoubleTest.test_copy | PASS | |
| ByteTest.test_deepcopy | PASS | |
| ShortTest.test_deepcopy | PASS | |
| IntTest.test_deepcopy | PASS | |
| LongTest.test_deepcopy | PASS | |
| LongLongTest.test_deepcopy | PASS | |
| UnsignedByteTest.test_deepcopy | PASS | |
| UnsignedShortTest.test_deepcopy | PASS | |
| UnsignedIntTest.test_deepcopy | PASS | |
| UnsignedLongTest.test_deepcopy | PASS | |
| UnsignedLongLongTest.test_deepcopy | PASS | |
| FloatTest.test_deepcopy | PASS | |
| DoubleTest.test_deepcopy | PASS | |
| ByteTest.test_reduce_ex | PASS | |
| ShortTest.test_reduce_ex | PASS | |
| IntTest.test_reduce_ex | PASS | |
| LongTest.test_reduce_ex | PASS | |
| LongLongTest.test_reduce_ex | PASS | |
| UnsignedByteTest.test_reduce_ex | PASS | |
| UnsignedShortTest.test_reduce_ex | PASS | |
| UnsignedIntTest.test_reduce_ex | PASS | |
| UnsignedLongTest.test_reduce_ex | PASS | |
| UnsignedLongLongTest.test_reduce_ex | PASS | |
| FloatTest.test_reduce_ex | PASS | |
| DoubleTest.test_reduce_ex | PASS | |
| ByteTest.test_pickle | VM-CRASH | no MARK captured |
| ShortTest.test_pickle | VM-CRASH | no MARK captured |
| IntTest.test_pickle | VM-CRASH | `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 \|     host_cls = _jac_standin_class(u.cls)  1051 \|     inst = host_cls.__new__(host_cls)  1052 \|     # Strong back-reference: while the host holds the stand-in, the` |
| LongTest.test_pickle | VM-CRASH | `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 \|     host_cls = _jac_standin_class(u.cls)  1051 \|     inst = host_cls.__new__(host_cls)  1052 \|     # Strong back-reference: while the host holds the stand-in, the` |
| LongLongTest.test_pickle | VM-CRASH | `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 \|     host_cls = _jac_standin_class(u.cls)  1051 \|     inst = host_cls.__new__(host_cls)  1052 \|     # Strong back-reference: while the host holds the stand-in, the` |
| UnsignedByteTest.test_pickle | VM-CRASH | `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 \|     host_cls = _jac_standin_class(u.cls)  1051 \|     inst = host_cls.__new__(host_cls)  1052 \|     # Strong back-reference: while the host holds the stand-in, the` |
| UnsignedShortTest.test_pickle | VM-CRASH | `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 \|     host_cls = _jac_standin_class(u.cls)  1051 \|     inst = host_cls.__new__(host_cls)  1052 \|     # Strong back-reference: while the host holds the stand-in, the` |
| UnsignedIntTest.test_pickle | VM-CRASH | `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 \|     host_cls = _jac_standin_class(u.cls)  1051 \|     inst = host_cls.__new__(host_cls)  1052 \|     # Strong back-reference: while the host holds the stand-in, the` |
| UnsignedLongTest.test_pickle | VM-CRASH | `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 \|     host_cls = _jac_standin_class(u.cls)  1051 \|     inst = host_cls.__new__(host_cls)  1052 \|     # Strong back-reference: while the host holds the stand-in, the` |
| UnsignedLongLongTest.test_pickle | VM-CRASH | `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 \|     host_cls = _jac_standin_class(u.cls)  1051 \|     inst = host_cls.__new__(host_cls)  1052 \|     # Strong back-reference: while the host holds the stand-in, the` |
| FloatTest.test_pickle | VM-CRASH | `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 \|     host_cls = _jac_standin_class(u.cls)  1051 \|     inst = host_cls.__new__(host_cls)  1052 \|     # Strong back-reference: while the host holds the stand-in, the` |
| DoubleTest.test_pickle | VM-CRASH | `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 \|     host_cls = _jac_standin_class(u.cls)  1051 \|     inst = host_cls.__new__(host_cls)  1052 \|     # Strong back-reference: while the host holds the stand-in, the` |
| ByteTest.test_pickle_for_empty_array | VM-CRASH | `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 \|     host_cls = _jac_standin_class(u.cls)  1051 \|     inst = host_cls.__new__(host_cls)  1052 \|     # Strong back-reference: while the host holds the stand-in, the` |
| ShortTest.test_pickle_for_empty_array | VM-CRASH | `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 \|     host_cls = _jac_standin_class(u.cls)  1051 \|     inst = host_cls.__new__(host_cls)  1052 \|     # Strong back-reference: while the host holds the stand-in, the` |
| IntTest.test_pickle_for_empty_array | VM-CRASH | `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 \|     host_cls = _jac_standin_class(u.cls)  1051 \|     inst = host_cls.__new__(host_cls)  1052 \|     # Strong back-reference: while the host holds the stand-in, the` |
| LongTest.test_pickle_for_empty_array | VM-CRASH | `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 \|     host_cls = _jac_standin_class(u.cls)  1051 \|     inst = host_cls.__new__(host_cls)  1052 \|     # Strong back-reference: while the host holds the stand-in, the` |
| LongLongTest.test_pickle_for_empty_array | VM-CRASH | `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 \|     host_cls = _jac_standin_class(u.cls)  1051 \|     inst = host_cls.__new__(host_cls)  1052 \|     # Strong back-reference: while the host holds the stand-in, the` |
| UnsignedByteTest.test_pickle_for_empty_array | VM-CRASH | `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 \|     host_cls = _jac_standin_class(u.cls)  1051 \|     inst = host_cls.__new__(host_cls)  1052 \|     # Strong back-reference: while the host holds the stand-in, the` |
| UnsignedShortTest.test_pickle_for_empty_array | VM-CRASH | `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 \|     host_cls = _jac_standin_class(u.cls)  1051 \|     inst = host_cls.__new__(host_cls)  1052 \|     # Strong back-reference: while the host holds the stand-in, the` |
| UnsignedIntTest.test_pickle_for_empty_array | VM-CRASH | `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 \|     host_cls = _jac_standin_class(u.cls)  1051 \|     inst = host_cls.__new__(host_cls)  1052 \|     # Strong back-reference: while the host holds the stand-in, the` |
| UnsignedLongTest.test_pickle_for_empty_array | VM-CRASH | `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 \|     host_cls = _jac_standin_class(u.cls)  1051 \|     inst = host_cls.__new__(host_cls)  1052 \|     # Strong back-reference: while the host holds the stand-in, the` |
| UnsignedLongLongTest.test_pickle_for_empty_array | VM-CRASH | `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 \|     host_cls = _jac_standin_class(u.cls)  1051 \|     inst = host_cls.__new__(host_cls)  1052 \|     # Strong back-reference: while the host holds the stand-in, the` |
| FloatTest.test_pickle_for_empty_array | VM-CRASH | `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 \|     host_cls = _jac_standin_class(u.cls)  1051 \|     inst = host_cls.__new__(host_cls)  1052 \|     # Strong back-reference: while the host holds the stand-in, the` |
| DoubleTest.test_pickle_for_empty_array | VM-CRASH | `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 \|     host_cls = _jac_standin_class(u.cls)  1051 \|     inst = host_cls.__new__(host_cls)  1052 \|     # Strong back-reference: while the host holds the stand-in, the` |
| ByteTest.test_iterator_pickle | VM-CRASH | `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 \|     host_cls = _jac_standin_class(u.cls)  1051 \|     inst = host_cls.__new__(host_cls)  1052 \|     # Strong back-reference: while the host holds the stand-in, the` |
| ShortTest.test_iterator_pickle | VM-CRASH | `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 \|     host_cls = _jac_standin_class(u.cls)  1051 \|     inst = host_cls.__new__(host_cls)  1052 \|     # Strong back-reference: while the host holds the stand-in, the` |
| IntTest.test_iterator_pickle | VM-CRASH | `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 \|     host_cls = _jac_standin_class(u.cls)  1051 \|     inst = host_cls.__new__(host_cls)  1052 \|     # Strong back-reference: while the host holds the stand-in, the` |
| LongTest.test_iterator_pickle | VM-CRASH | `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 \|     host_cls = _jac_standin_class(u.cls)  1051 \|     inst = host_cls.__new__(host_cls)  1052 \|     # Strong back-reference: while the host holds the stand-in, the` |
| LongLongTest.test_iterator_pickle | VM-CRASH | `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 \|     host_cls = _jac_standin_class(u.cls)  1051 \|     inst = host_cls.__new__(host_cls)  1052 \|     # Strong back-reference: while the host holds the stand-in, the` |
| UnsignedByteTest.test_iterator_pickle | VM-CRASH | `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 \|     host_cls = _jac_standin_class(u.cls)  1051 \|     inst = host_cls.__new__(host_cls)  1052 \|     # Strong back-reference: while the host holds the stand-in, the` |
| UnsignedShortTest.test_iterator_pickle | VM-CRASH | `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 \|     host_cls = _jac_standin_class(u.cls)  1051 \|     inst = host_cls.__new__(host_cls)  1052 \|     # Strong back-reference: while the host holds the stand-in, the` |
| UnsignedIntTest.test_iterator_pickle | VM-CRASH | `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 \|     host_cls = _jac_standin_class(u.cls)  1051 \|     inst = host_cls.__new__(host_cls)  1052 \|     # Strong back-reference: while the host holds the stand-in, the` |
| UnsignedLongTest.test_iterator_pickle | VM-CRASH | `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 \|     host_cls = _jac_standin_class(u.cls)  1051 \|     inst = host_cls.__new__(host_cls)  1052 \|     # Strong back-reference: while the host holds the stand-in, the` |
| UnsignedLongLongTest.test_iterator_pickle | VM-CRASH | `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 \|     host_cls = _jac_standin_class(u.cls)  1051 \|     inst = host_cls.__new__(host_cls)  1052 \|     # Strong back-reference: while the host holds the stand-in, the` |
| FloatTest.test_iterator_pickle | VM-CRASH | `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 \|     host_cls = _jac_standin_class(u.cls)  1051 \|     inst = host_cls.__new__(host_cls)  1052 \|     # Strong back-reference: while the host holds the stand-in, the` |
| DoubleTest.test_iterator_pickle | VM-CRASH | `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 \|     host_cls = _jac_standin_class(u.cls)  1051 \|     inst = host_cls.__new__(host_cls)  1052 \|     # Strong back-reference: while the host holds the stand-in, the` |
| ByteTest.test_exhausted_iterator | VM-CRASH | `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 \|     host_cls = _jac_standin_class(u.cls)  1051 \|     inst = host_cls.__new__(host_cls)  1052 \|     # Strong back-reference: while the host holds the stand-in, the` |
| ShortTest.test_exhausted_iterator | VM-CRASH | `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 \|     host_cls = _jac_standin_class(u.cls)  1051 \|     inst = host_cls.__new__(host_cls)  1052 \|     # Strong back-reference: while the host holds the stand-in, the` |
| IntTest.test_exhausted_iterator | VM-CRASH | `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 \|     host_cls = _jac_standin_class(u.cls)  1051 \|     inst = host_cls.__new__(host_cls)  1052 \|     # Strong back-reference: while the host holds the stand-in, the` |
| LongTest.test_exhausted_iterator | VM-CRASH | `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 \|     host_cls = _jac_standin_class(u.cls)  1051 \|     inst = host_cls.__new__(host_cls)  1052 \|     # Strong back-reference: while the host holds the stand-in, the` |
| LongLongTest.test_exhausted_iterator | VM-CRASH | `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 \|     host_cls = _jac_standin_class(u.cls)  1051 \|     inst = host_cls.__new__(host_cls)  1052 \|     # Strong back-reference: while the host holds the stand-in, the` |
| UnsignedByteTest.test_exhausted_iterator | VM-CRASH | `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 \|     host_cls = _jac_standin_class(u.cls)  1051 \|     inst = host_cls.__new__(host_cls)  1052 \|     # Strong back-reference: while the host holds the stand-in, the` |
| UnsignedShortTest.test_exhausted_iterator | VM-CRASH | `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 \|     host_cls = _jac_standin_class(u.cls)  1051 \|     inst = host_cls.__new__(host_cls)  1052 \|     # Strong back-reference: while the host holds the stand-in, the` |
| UnsignedIntTest.test_exhausted_iterator | VM-CRASH | `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 \|     host_cls = _jac_standin_class(u.cls)  1051 \|     inst = host_cls.__new__(host_cls)  1052 \|     # Strong back-reference: while the host holds the stand-in, the` |
| UnsignedLongTest.test_exhausted_iterator | VM-CRASH | `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 \|     host_cls = _jac_standin_class(u.cls)  1051 \|     inst = host_cls.__new__(host_cls)  1052 \|     # Strong back-reference: while the host holds the stand-in, the` |
| UnsignedLongLongTest.test_exhausted_iterator | VM-CRASH | `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 \|     host_cls = _jac_standin_class(u.cls)  1051 \|     inst = host_cls.__new__(host_cls)  1052 \|     # Strong back-reference: while the host holds the stand-in, the` |
| FloatTest.test_exhausted_iterator | VM-CRASH | `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 \|     host_cls = _jac_standin_class(u.cls)  1051 \|     inst = host_cls.__new__(host_cls)  1052 \|     # Strong back-reference: while the host holds the stand-in, the` |
| DoubleTest.test_exhausted_iterator | VM-CRASH | `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 \|     host_cls = _jac_standin_class(u.cls)  1051 \|     inst = host_cls.__new__(host_cls)  1052 \|     # Strong back-reference: while the host holds the stand-in, the` |
| ByteTest.test_reverse_iterator | VM-CRASH | `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 \|     host_cls = _jac_standin_class(u.cls)  1051 \|     inst = host_cls.__new__(host_cls)  1052 \|     # Strong back-reference: while the host holds the stand-in, the` |
| ShortTest.test_reverse_iterator | VM-CRASH | `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 \|     host_cls = _jac_standin_class(u.cls)  1051 \|     inst = host_cls.__new__(host_cls)  1052 \|     # Strong back-reference: while the host holds the stand-in, the` |
| IntTest.test_reverse_iterator | VM-CRASH | `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 \|     host_cls = _jac_standin_class(u.cls)  1051 \|     inst = host_cls.__new__(host_cls)  1052 \|     # Strong back-reference: while the host holds the stand-in, the` |
| LongTest.test_reverse_iterator | VM-CRASH | `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 \|     host_cls = _jac_standin_class(u.cls)  1051 \|     inst = host_cls.__new__(host_cls)  1052 \|     # Strong back-reference: while the host holds the stand-in, the` |
| LongLongTest.test_reverse_iterator | VM-CRASH | `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 \|     host_cls = _jac_standin_class(u.cls)  1051 \|     inst = host_cls.__new__(host_cls)  1052 \|     # Strong back-reference: while the host holds the stand-in, the` |
| UnsignedByteTest.test_reverse_iterator | VM-CRASH | `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 \|     host_cls = _jac_standin_class(u.cls)  1051 \|     inst = host_cls.__new__(host_cls)  1052 \|     # Strong back-reference: while the host holds the stand-in, the` |
| UnsignedShortTest.test_reverse_iterator | VM-CRASH | `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 \|     host_cls = _jac_standin_class(u.cls)  1051 \|     inst = host_cls.__new__(host_cls)  1052 \|     # Strong back-reference: while the host holds the stand-in, the` |
| UnsignedIntTest.test_reverse_iterator | VM-CRASH | `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 \|     host_cls = _jac_standin_class(u.cls)  1051 \|     inst = host_cls.__new__(host_cls)  1052 \|     # Strong back-reference: while the host holds the stand-in, the` |
| UnsignedLongTest.test_reverse_iterator | VM-CRASH | `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 \|     host_cls = _jac_standin_class(u.cls)  1051 \|     inst = host_cls.__new__(host_cls)  1052 \|     # Strong back-reference: while the host holds the stand-in, the` |
| UnsignedLongLongTest.test_reverse_iterator | VM-CRASH | `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 \|     host_cls = _jac_standin_class(u.cls)  1051 \|     inst = host_cls.__new__(host_cls)  1052 \|     # Strong back-reference: while the host holds the stand-in, the` |
| FloatTest.test_reverse_iterator | VM-CRASH | `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 \|     host_cls = _jac_standin_class(u.cls)  1051 \|     inst = host_cls.__new__(host_cls)  1052 \|     # Strong back-reference: while the host holds the stand-in, the` |
| DoubleTest.test_reverse_iterator | VM-CRASH | `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 \|     host_cls = _jac_standin_class(u.cls)  1051 \|     inst = host_cls.__new__(host_cls)  1052 \|     # Strong back-reference: while the host holds the stand-in, the` |
| ByteTest.test_reverse_iterator_picking | VM-CRASH | `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 \|     host_cls = _jac_standin_class(u.cls)  1051 \|     inst = host_cls.__new__(host_cls)  1052 \|     # Strong back-reference: while the host holds the stand-in, the` |
| ShortTest.test_reverse_iterator_picking | VM-CRASH | `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 \|     host_cls = _jac_standin_class(u.cls)  1051 \|     inst = host_cls.__new__(host_cls)  1052 \|     # Strong back-reference: while the host holds the stand-in, the` |
| IntTest.test_reverse_iterator_picking | VM-CRASH | `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 \|     host_cls = _jac_standin_class(u.cls)  1051 \|     inst = host_cls.__new__(host_cls)  1052 \|     # Strong back-reference: while the host holds the stand-in, the` |
| LongTest.test_reverse_iterator_picking | VM-CRASH | `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 \|     host_cls = _jac_standin_class(u.cls)  1051 \|     inst = host_cls.__new__(host_cls)  1052 \|     # Strong back-reference: while the host holds the stand-in, the` |
| LongLongTest.test_reverse_iterator_picking | VM-CRASH | `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 \|     host_cls = _jac_standin_class(u.cls)  1051 \|     inst = host_cls.__new__(host_cls)  1052 \|     # Strong back-reference: while the host holds the stand-in, the` |
| UnsignedByteTest.test_reverse_iterator_picking | VM-CRASH | `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 \|     host_cls = _jac_standin_class(u.cls)  1051 \|     inst = host_cls.__new__(host_cls)  1052 \|     # Strong back-reference: while the host holds the stand-in, the` |
| UnsignedShortTest.test_reverse_iterator_picking | VM-CRASH | `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 \|     host_cls = _jac_standin_class(u.cls)  1051 \|     inst = host_cls.__new__(host_cls)  1052 \|     # Strong back-reference: while the host holds the stand-in, the` |
| UnsignedIntTest.test_reverse_iterator_picking | VM-CRASH | `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 \|     host_cls = _jac_standin_class(u.cls)  1051 \|     inst = host_cls.__new__(host_cls)  1052 \|     # Strong back-reference: while the host holds the stand-in, the` |
| UnsignedLongTest.test_reverse_iterator_picking | VM-CRASH | `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 \|     host_cls = _jac_standin_class(u.cls)  1051 \|     inst = host_cls.__new__(host_cls)  1052 \|     # Strong back-reference: while the host holds the stand-in, the` |
| UnsignedLongLongTest.test_reverse_iterator_picking | VM-CRASH | `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 \|     host_cls = _jac_standin_class(u.cls)  1051 \|     inst = host_cls.__new__(host_cls)  1052 \|     # Strong back-reference: while the host holds the stand-in, the` |
| FloatTest.test_reverse_iterator_picking | VM-CRASH | `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 \|     host_cls = _jac_standin_class(u.cls)  1051 \|     inst = host_cls.__new__(host_cls)  1052 \|     # Strong back-reference: while the host holds the stand-in, the` |
| DoubleTest.test_reverse_iterator_picking | VM-CRASH | `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 \|     host_cls = _jac_standin_class(u.cls)  1051 \|     inst = host_cls.__new__(host_cls)  1052 \|     # Strong back-reference: while the host holds the stand-in, the` |
| ByteTest.test_exhausted_reverse_iterator | VM-CRASH | `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 \|     host_cls = _jac_standin_class(u.cls)  1051 \|     inst = host_cls.__new__(host_cls)  1052 \|     # Strong back-reference: while the host holds the stand-in, the` |
| ShortTest.test_exhausted_reverse_iterator | VM-CRASH | `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 \|     host_cls = _jac_standin_class(u.cls)  1051 \|     inst = host_cls.__new__(host_cls)  1052 \|     # Strong back-reference: while the host holds the stand-in, the` |
| IntTest.test_exhausted_reverse_iterator | VM-CRASH | `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 \|     host_cls = _jac_standin_class(u.cls)  1051 \|     inst = host_cls.__new__(host_cls)  1052 \|     # Strong back-reference: while the host holds the stand-in, the` |
| LongTest.test_exhausted_reverse_iterator | VM-CRASH | `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 \|     host_cls = _jac_standin_class(u.cls)  1051 \|     inst = host_cls.__new__(host_cls)  1052 \|     # Strong back-reference: while the host holds the stand-in, the` |
| LongLongTest.test_exhausted_reverse_iterator | VM-CRASH | `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 \|     host_cls = _jac_standin_class(u.cls)  1051 \|     inst = host_cls.__new__(host_cls)  1052 \|     # Strong back-reference: while the host holds the stand-in, the` |
| UnsignedByteTest.test_exhausted_reverse_iterator | VM-CRASH | `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 \|     host_cls = _jac_standin_class(u.cls)  1051 \|     inst = host_cls.__new__(host_cls)  1052 \|     # Strong back-reference: while the host holds the stand-in, the` |
| UnsignedShortTest.test_exhausted_reverse_iterator | VM-CRASH | `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 \|     host_cls = _jac_standin_class(u.cls)  1051 \|     inst = host_cls.__new__(host_cls)  1052 \|     # Strong back-reference: while the host holds the stand-in, the` |
| UnsignedIntTest.test_exhausted_reverse_iterator | VM-CRASH | `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 \|     host_cls = _jac_standin_class(u.cls)  1051 \|     inst = host_cls.__new__(host_cls)  1052 \|     # Strong back-reference: while the host holds the stand-in, the` |
| UnsignedLongTest.test_exhausted_reverse_iterator | VM-CRASH | `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 \|     host_cls = _jac_standin_class(u.cls)  1051 \|     inst = host_cls.__new__(host_cls)  1052 \|     # Strong back-reference: while the host holds the stand-in, the` |
| UnsignedLongLongTest.test_exhausted_reverse_iterator | VM-CRASH | `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 \|     host_cls = _jac_standin_class(u.cls)  1051 \|     inst = host_cls.__new__(host_cls)  1052 \|     # Strong back-reference: while the host holds the stand-in, the` |
| FloatTest.test_exhausted_reverse_iterator | VM-CRASH | `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 \|     host_cls = _jac_standin_class(u.cls)  1051 \|     inst = host_cls.__new__(host_cls)  1052 \|     # Strong back-reference: while the host holds the stand-in, the` |
| DoubleTest.test_exhausted_reverse_iterator | VM-CRASH | `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 \|     host_cls = _jac_standin_class(u.cls)  1051 \|     inst = host_cls.__new__(host_cls)  1052 \|     # Strong back-reference: while the host holds the stand-in, the` |
| ByteTest.test_insert | VM-CRASH | `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 \|     host_cls = _jac_standin_class(u.cls)  1051 \|     inst = host_cls.__new__(host_cls)  1052 \|     # Strong back-reference: while the host holds the stand-in, the` |
| ShortTest.test_insert | VM-CRASH | `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 \|     host_cls = _jac_standin_class(u.cls)  1051 \|     inst = host_cls.__new__(host_cls)  1052 \|     # Strong back-reference: while the host holds the stand-in, the` |
| IntTest.test_insert | VM-CRASH | `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 \|     host_cls = _jac_standin_class(u.cls)  1051 \|     inst = host_cls.__new__(host_cls)  1052 \|     # Strong back-reference: while the host holds the stand-in, the` |
| LongTest.test_insert | VM-CRASH | `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 \|     host_cls = _jac_standin_class(u.cls)  1051 \|     inst = host_cls.__new__(host_cls)  1052 \|     # Strong back-reference: while the host holds the stand-in, the` |
| LongLongTest.test_insert | VM-CRASH | `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 \|     host_cls = _jac_standin_class(u.cls)  1051 \|     inst = host_cls.__new__(host_cls)  1052 \|     # Strong back-reference: while the host holds the stand-in, the` |
| UnsignedByteTest.test_insert | VM-CRASH | `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 \|     host_cls = _jac_standin_class(u.cls)  1051 \|     inst = host_cls.__new__(host_cls)  1052 \|     # Strong back-reference: while the host holds the stand-in, the` |
| UnsignedShortTest.test_insert | VM-CRASH | `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 \|     host_cls = _jac_standin_class(u.cls)  1051 \|     inst = host_cls.__new__(host_cls)  1052 \|     # Strong back-reference: while the host holds the stand-in, the` |
| UnsignedIntTest.test_insert | VM-CRASH | `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 \|     host_cls = _jac_standin_class(u.cls)  1051 \|     inst = host_cls.__new__(host_cls)  1052 \|     # Strong back-reference: while the host holds the stand-in, the` |
| UnsignedLongTest.test_insert | VM-CRASH | `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 \|     host_cls = _jac_standin_class(u.cls)  1051 \|     inst = host_cls.__new__(host_cls)  1052 \|     # Strong back-reference: while the host holds the stand-in, the` |
| UnsignedLongLongTest.test_insert | VM-CRASH | `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 \|     host_cls = _jac_standin_class(u.cls)  1051 \|     inst = host_cls.__new__(host_cls)  1052 \|     # Strong back-reference: while the host holds the stand-in, the` |
| FloatTest.test_insert | VM-CRASH | `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 \|     host_cls = _jac_standin_class(u.cls)  1051 \|     inst = host_cls.__new__(host_cls)  1052 \|     # Strong back-reference: while the host holds the stand-in, the` |
| DoubleTest.test_insert | VM-CRASH | `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 \|     host_cls = _jac_standin_class(u.cls)  1051 \|     inst = host_cls.__new__(host_cls)  1052 \|     # Strong back-reference: while the host holds the stand-in, the` |
| ByteTest.test_tofromlist | VM-CRASH | `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 \|     host_cls = _jac_standin_class(u.cls)  1051 \|     inst = host_cls.__new__(host_cls)  1052 \|     # Strong back-reference: while the host holds the stand-in, the` |
| ShortTest.test_tofromlist | VM-CRASH | `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 \|     host_cls = _jac_standin_class(u.cls)  1051 \|     inst = host_cls.__new__(host_cls)  1052 \|     # Strong back-reference: while the host holds the stand-in, the` |
| IntTest.test_tofromlist | VM-CRASH | `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 \|     host_cls = _jac_standin_class(u.cls)  1051 \|     inst = host_cls.__new__(host_cls)  1052 \|     # Strong back-reference: while the host holds the stand-in, the` |
| LongTest.test_tofromlist | VM-CRASH | `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 \|     host_cls = _jac_standin_class(u.cls)  1051 \|     inst = host_cls.__new__(host_cls)  1052 \|     # Strong back-reference: while the host holds the stand-in, the` |
| LongLongTest.test_tofromlist | VM-CRASH | `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 \|     host_cls = _jac_standin_class(u.cls)  1051 \|     inst = host_cls.__new__(host_cls)  1052 \|     # Strong back-reference: while the host holds the stand-in, the` |
| UnsignedByteTest.test_tofromlist | VM-CRASH | `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 \|     host_cls = _jac_standin_class(u.cls)  1051 \|     inst = host_cls.__new__(host_cls)  1052 \|     # Strong back-reference: while the host holds the stand-in, the` |
| UnsignedShortTest.test_tofromlist | VM-CRASH | `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 \|     host_cls = _jac_standin_class(u.cls)  1051 \|     inst = host_cls.__new__(host_cls)  1052 \|     # Strong back-reference: while the host holds the stand-in, the` |
| UnsignedIntTest.test_tofromlist | VM-CRASH | `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 \|     host_cls = _jac_standin_class(u.cls)  1051 \|     inst = host_cls.__new__(host_cls)  1052 \|     # Strong back-reference: while the host holds the stand-in, the` |
| UnsignedLongTest.test_tofromlist | VM-CRASH | `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 \|     host_cls = _jac_standin_class(u.cls)  1051 \|     inst = host_cls.__new__(host_cls)  1052 \|     # Strong back-reference: while the host holds the stand-in, the` |
| UnsignedLongLongTest.test_tofromlist | VM-CRASH | `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 \|     host_cls = _jac_standin_class(u.cls)  1051 \|     inst = host_cls.__new__(host_cls)  1052 \|     # Strong back-reference: while the host holds the stand-in, the` |
| FloatTest.test_tofromlist | VM-CRASH | `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 \|     host_cls = _jac_standin_class(u.cls)  1051 \|     inst = host_cls.__new__(host_cls)  1052 \|     # Strong back-reference: while the host holds the stand-in, the` |
| DoubleTest.test_tofromlist | VM-CRASH | `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 \|     host_cls = _jac_standin_class(u.cls)  1051 \|     inst = host_cls.__new__(host_cls)  1052 \|     # Strong back-reference: while the host holds the stand-in, the` |
| ByteTest.test_tofrombytes | VM-CRASH | `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 \|     host_cls = _jac_standin_class(u.cls)  1051 \|     inst = host_cls.__new__(host_cls)  1052 \|     # Strong back-reference: while the host holds the stand-in, the` |
| ShortTest.test_tofrombytes | VM-CRASH | `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 \|     host_cls = _jac_standin_class(u.cls)  1051 \|     inst = host_cls.__new__(host_cls)  1052 \|     # Strong back-reference: while the host holds the stand-in, the` |
| IntTest.test_tofrombytes | VM-CRASH | `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 \|     host_cls = _jac_standin_class(u.cls)  1051 \|     inst = host_cls.__new__(host_cls)  1052 \|     # Strong back-reference: while the host holds the stand-in, the` |
| LongTest.test_tofrombytes | VM-CRASH | `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 \|     host_cls = _jac_standin_class(u.cls)  1051 \|     inst = host_cls.__new__(host_cls)  1052 \|     # Strong back-reference: while the host holds the stand-in, the` |
| LongLongTest.test_tofrombytes | VM-CRASH | `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 \|     host_cls = _jac_standin_class(u.cls)  1051 \|     inst = host_cls.__new__(host_cls)  1052 \|     # Strong back-reference: while the host holds the stand-in, the` |
| UnsignedByteTest.test_tofrombytes | VM-CRASH | `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 \|     host_cls = _jac_standin_class(u.cls)  1051 \|     inst = host_cls.__new__(host_cls)  1052 \|     # Strong back-reference: while the host holds the stand-in, the` |
| UnsignedShortTest.test_tofrombytes | VM-CRASH | `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 \|     host_cls = _jac_standin_class(u.cls)  1051 \|     inst = host_cls.__new__(host_cls)  1052 \|     # Strong back-reference: while the host holds the stand-in, the` |
| UnsignedIntTest.test_tofrombytes | VM-CRASH | `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 \|     host_cls = _jac_standin_class(u.cls)  1051 \|     inst = host_cls.__new__(host_cls)  1052 \|     # Strong back-reference: while the host holds the stand-in, the` |
| UnsignedLongTest.test_tofrombytes | VM-CRASH | `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 \|     host_cls = _jac_standin_class(u.cls)  1051 \|     inst = host_cls.__new__(host_cls)  1052 \|     # Strong back-reference: while the host holds the stand-in, the` |
| UnsignedLongLongTest.test_tofrombytes | VM-CRASH | `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 \|     host_cls = _jac_standin_class(u.cls)  1051 \|     inst = host_cls.__new__(host_cls)  1052 \|     # Strong back-reference: while the host holds the stand-in, the` |
| FloatTest.test_tofrombytes | VM-CRASH | `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 \|     host_cls = _jac_standin_class(u.cls)  1051 \|     inst = host_cls.__new__(host_cls)  1052 \|     # Strong back-reference: while the host holds the stand-in, the` |
| DoubleTest.test_tofrombytes | VM-CRASH | `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 \|     host_cls = _jac_standin_class(u.cls)  1051 \|     inst = host_cls.__new__(host_cls)  1052 \|     # Strong back-reference: while the host holds the stand-in, the` |
| ByteTest.test_fromarray | VM-CRASH | `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 \|     host_cls = _jac_standin_class(u.cls)  1051 \|     inst = host_cls.__new__(host_cls)  1052 \|     # Strong back-reference: while the host holds the stand-in, the` |
| ShortTest.test_fromarray | VM-CRASH | `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 \|     host_cls = _jac_standin_class(u.cls)  1051 \|     inst = host_cls.__new__(host_cls)  1052 \|     # Strong back-reference: while the host holds the stand-in, the` |
| IntTest.test_fromarray | VM-CRASH | `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 \|     host_cls = _jac_standin_class(u.cls)  1051 \|     inst = host_cls.__new__(host_cls)  1052 \|     # Strong back-reference: while the host holds the stand-in, the` |
| LongTest.test_fromarray | VM-CRASH | `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 \|     host_cls = _jac_standin_class(u.cls)  1051 \|     inst = host_cls.__new__(host_cls)  1052 \|     # Strong back-reference: while the host holds the stand-in, the` |
| LongLongTest.test_fromarray | VM-CRASH | `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 \|     host_cls = _jac_standin_class(u.cls)  1051 \|     inst = host_cls.__new__(host_cls)  1052 \|     # Strong back-reference: while the host holds the stand-in, the` |
| UnsignedByteTest.test_fromarray | VM-CRASH | `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 \|     host_cls = _jac_standin_class(u.cls)  1051 \|     inst = host_cls.__new__(host_cls)  1052 \|     # Strong back-reference: while the host holds the stand-in, the` |
| UnsignedShortTest.test_fromarray | VM-CRASH | `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 \|     host_cls = _jac_standin_class(u.cls)  1051 \|     inst = host_cls.__new__(host_cls)  1052 \|     # Strong back-reference: while the host holds the stand-in, the` |
| UnsignedIntTest.test_fromarray | VM-CRASH | `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 \|     host_cls = _jac_standin_class(u.cls)  1051 \|     inst = host_cls.__new__(host_cls)  1052 \|     # Strong back-reference: while the host holds the stand-in, the` |
| UnsignedLongTest.test_fromarray | VM-CRASH | `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 \|     host_cls = _jac_standin_class(u.cls)  1051 \|     inst = host_cls.__new__(host_cls)  1052 \|     # Strong back-reference: while the host holds the stand-in, the` |
| UnsignedLongLongTest.test_fromarray | VM-CRASH | `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 \|     host_cls = _jac_standin_class(u.cls)  1051 \|     inst = host_cls.__new__(host_cls)  1052 \|     # Strong back-reference: while the host holds the stand-in, the` |
| FloatTest.test_fromarray | VM-CRASH | `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 \|     host_cls = _jac_standin_class(u.cls)  1051 \|     inst = host_cls.__new__(host_cls)  1052 \|     # Strong back-reference: while the host holds the stand-in, the` |
| DoubleTest.test_fromarray | VM-CRASH | `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 \|     host_cls = _jac_standin_class(u.cls)  1051 \|     inst = host_cls.__new__(host_cls)  1052 \|     # Strong back-reference: while the host holds the stand-in, the` |
| ByteTest.test_repr | VM-CRASH | `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 \|     host_cls = _jac_standin_class(u.cls)  1051 \|     inst = host_cls.__new__(host_cls)  1052 \|     # Strong back-reference: while the host holds the stand-in, the` |
| ShortTest.test_repr | VM-CRASH | `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 \|     host_cls = _jac_standin_class(u.cls)  1051 \|     inst = host_cls.__new__(host_cls)  1052 \|     # Strong back-reference: while the host holds the stand-in, the` |
| IntTest.test_repr | VM-CRASH | `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 \|     host_cls = _jac_standin_class(u.cls)  1051 \|     inst = host_cls.__new__(host_cls)  1052 \|     # Strong back-reference: while the host holds the stand-in, the` |
| LongTest.test_repr | VM-CRASH | `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 \|     host_cls = _jac_standin_class(u.cls)  1051 \|     inst = host_cls.__new__(host_cls)  1052 \|     # Strong back-reference: while the host holds the stand-in, the` |
| LongLongTest.test_repr | VM-CRASH | `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 \|     host_cls = _jac_standin_class(u.cls)  1051 \|     inst = host_cls.__new__(host_cls)  1052 \|     # Strong back-reference: while the host holds the stand-in, the` |
| UnsignedByteTest.test_repr | VM-CRASH | `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 \|     host_cls = _jac_standin_class(u.cls)  1051 \|     inst = host_cls.__new__(host_cls)  1052 \|     # Strong back-reference: while the host holds the stand-in, the` |
| UnsignedShortTest.test_repr | VM-CRASH | `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 \|     host_cls = _jac_standin_class(u.cls)  1051 \|     inst = host_cls.__new__(host_cls)  1052 \|     # Strong back-reference: while the host holds the stand-in, the` |
| UnsignedIntTest.test_repr | VM-CRASH | `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 \|     host_cls = _jac_standin_class(u.cls)  1051 \|     inst = host_cls.__new__(host_cls)  1052 \|     # Strong back-reference: while the host holds the stand-in, the` |
| UnsignedLongTest.test_repr | VM-CRASH | `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 \|     host_cls = _jac_standin_class(u.cls)  1051 \|     inst = host_cls.__new__(host_cls)  1052 \|     # Strong back-reference: while the host holds the stand-in, the` |
| UnsignedLongLongTest.test_repr | VM-CRASH | `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 \|     host_cls = _jac_standin_class(u.cls)  1051 \|     inst = host_cls.__new__(host_cls)  1052 \|     # Strong back-reference: while the host holds the stand-in, the` |
| FloatTest.test_repr | VM-CRASH | `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 \|     host_cls = _jac_standin_class(u.cls)  1051 \|     inst = host_cls.__new__(host_cls)  1052 \|     # Strong back-reference: while the host holds the stand-in, the` |
| DoubleTest.test_repr | VM-CRASH | `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 \|     host_cls = _jac_standin_class(u.cls)  1051 \|     inst = host_cls.__new__(host_cls)  1052 \|     # Strong back-reference: while the host holds the stand-in, the` |
| ByteTest.test_str | VM-CRASH | `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 \|     host_cls = _jac_standin_class(u.cls)  1051 \|     inst = host_cls.__new__(host_cls)  1052 \|     # Strong back-reference: while the host holds the stand-in, the` |
| ShortTest.test_str | VM-CRASH | `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 \|     host_cls = _jac_standin_class(u.cls)  1051 \|     inst = host_cls.__new__(host_cls)  1052 \|     # Strong back-reference: while the host holds the stand-in, the` |
| IntTest.test_str | VM-CRASH | `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 \|     host_cls = _jac_standin_class(u.cls)  1051 \|     inst = host_cls.__new__(host_cls)  1052 \|     # Strong back-reference: while the host holds the stand-in, the` |
| LongTest.test_str | VM-CRASH | `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 \|     host_cls = _jac_standin_class(u.cls)  1051 \|     inst = host_cls.__new__(host_cls)  1052 \|     # Strong back-reference: while the host holds the stand-in, the` |
| LongLongTest.test_str | VM-CRASH | `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 \|     host_cls = _jac_standin_class(u.cls)  1051 \|     inst = host_cls.__new__(host_cls)  1052 \|     # Strong back-reference: while the host holds the stand-in, the` |
| UnsignedByteTest.test_str | VM-CRASH | `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 \|     host_cls = _jac_standin_class(u.cls)  1051 \|     inst = host_cls.__new__(host_cls)  1052 \|     # Strong back-reference: while the host holds the stand-in, the` |
| UnsignedShortTest.test_str | VM-CRASH | `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 \|     host_cls = _jac_standin_class(u.cls)  1051 \|     inst = host_cls.__new__(host_cls)  1052 \|     # Strong back-reference: while the host holds the stand-in, the` |
| UnsignedIntTest.test_str | VM-CRASH | `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 \|     host_cls = _jac_standin_class(u.cls)  1051 \|     inst = host_cls.__new__(host_cls)  1052 \|     # Strong back-reference: while the host holds the stand-in, the` |
| UnsignedLongTest.test_str | VM-CRASH | `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 \|     host_cls = _jac_standin_class(u.cls)  1051 \|     inst = host_cls.__new__(host_cls)  1052 \|     # Strong back-reference: while the host holds the stand-in, the` |
| UnsignedLongLongTest.test_str | VM-CRASH | `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 \|     host_cls = _jac_standin_class(u.cls)  1051 \|     inst = host_cls.__new__(host_cls)  1052 \|     # Strong back-reference: while the host holds the stand-in, the` |
| FloatTest.test_str | VM-CRASH | `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 \|     host_cls = _jac_standin_class(u.cls)  1051 \|     inst = host_cls.__new__(host_cls)  1052 \|     # Strong back-reference: while the host holds the stand-in, the` |
| DoubleTest.test_str | VM-CRASH | `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 \|     host_cls = _jac_standin_class(u.cls)  1051 \|     inst = host_cls.__new__(host_cls)  1052 \|     # Strong back-reference: while the host holds the stand-in, the` |
| ByteTest.test_cmp | VM-CRASH | `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 \|     host_cls = _jac_standin_class(u.cls)  1051 \|     inst = host_cls.__new__(host_cls)  1052 \|     # Strong back-reference: while the host holds the stand-in, the` |
| ShortTest.test_cmp | VM-CRASH | `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 \|     host_cls = _jac_standin_class(u.cls)  1051 \|     inst = host_cls.__new__(host_cls)  1052 \|     # Strong back-reference: while the host holds the stand-in, the` |
| IntTest.test_cmp | VM-CRASH | `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 \|     host_cls = _jac_standin_class(u.cls)  1051 \|     inst = host_cls.__new__(host_cls)  1052 \|     # Strong back-reference: while the host holds the stand-in, the` |
| LongTest.test_cmp | VM-CRASH | `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 \|     host_cls = _jac_standin_class(u.cls)  1051 \|     inst = host_cls.__new__(host_cls)  1052 \|     # Strong back-reference: while the host holds the stand-in, the` |
| LongLongTest.test_cmp | VM-CRASH | `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 \|     host_cls = _jac_standin_class(u.cls)  1051 \|     inst = host_cls.__new__(host_cls)  1052 \|     # Strong back-reference: while the host holds the stand-in, the` |
| UnsignedByteTest.test_cmp | VM-CRASH | `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 \|     host_cls = _jac_standin_class(u.cls)  1051 \|     inst = host_cls.__new__(host_cls)  1052 \|     # Strong back-reference: while the host holds the stand-in, the` |
| UnsignedShortTest.test_cmp | VM-CRASH | `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 \|     host_cls = _jac_standin_class(u.cls)  1051 \|     inst = host_cls.__new__(host_cls)  1052 \|     # Strong back-reference: while the host holds the stand-in, the` |
| UnsignedIntTest.test_cmp | VM-CRASH | `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 \|     host_cls = _jac_standin_class(u.cls)  1051 \|     inst = host_cls.__new__(host_cls)  1052 \|     # Strong back-reference: while the host holds the stand-in, the` |
| UnsignedLongTest.test_cmp | VM-CRASH | `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 \|     host_cls = _jac_standin_class(u.cls)  1051 \|     inst = host_cls.__new__(host_cls)  1052 \|     # Strong back-reference: while the host holds the stand-in, the` |
| UnsignedLongLongTest.test_cmp | VM-CRASH | `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 \|     host_cls = _jac_standin_class(u.cls)  1051 \|     inst = host_cls.__new__(host_cls)  1052 \|     # Strong back-reference: while the host holds the stand-in, the` |
| FloatTest.test_cmp | VM-CRASH | `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 \|     host_cls = _jac_standin_class(u.cls)  1051 \|     inst = host_cls.__new__(host_cls)  1052 \|     # Strong back-reference: while the host holds the stand-in, the` |
| DoubleTest.test_cmp | VM-CRASH | `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 \|     host_cls = _jac_standin_class(u.cls)  1051 \|     inst = host_cls.__new__(host_cls)  1052 \|     # Strong back-reference: while the host holds the stand-in, the` |
| ByteTest.test_mul | VM-CRASH | `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 \|     host_cls = _jac_standin_class(u.cls)  1051 \|     inst = host_cls.__new__(host_cls)  1052 \|     # Strong back-reference: while the host holds the stand-in, the` |
| ShortTest.test_mul | VM-CRASH | `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 \|     host_cls = _jac_standin_class(u.cls)  1051 \|     inst = host_cls.__new__(host_cls)  1052 \|     # Strong back-reference: while the host holds the stand-in, the` |
| IntTest.test_mul | VM-CRASH | `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 \|     host_cls = _jac_standin_class(u.cls)  1051 \|     inst = host_cls.__new__(host_cls)  1052 \|     # Strong back-reference: while the host holds the stand-in, the` |
| LongTest.test_mul | VM-CRASH | `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 \|     host_cls = _jac_standin_class(u.cls)  1051 \|     inst = host_cls.__new__(host_cls)  1052 \|     # Strong back-reference: while the host holds the stand-in, the` |
| LongLongTest.test_mul | VM-CRASH | `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 \|     host_cls = _jac_standin_class(u.cls)  1051 \|     inst = host_cls.__new__(host_cls)  1052 \|     # Strong back-reference: while the host holds the stand-in, the` |
| UnsignedByteTest.test_mul | VM-CRASH | `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 \|     host_cls = _jac_standin_class(u.cls)  1051 \|     inst = host_cls.__new__(host_cls)  1052 \|     # Strong back-reference: while the host holds the stand-in, the` |
| UnsignedShortTest.test_mul | VM-CRASH | `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 \|     host_cls = _jac_standin_class(u.cls)  1051 \|     inst = host_cls.__new__(host_cls)  1052 \|     # Strong back-reference: while the host holds the stand-in, the` |
| UnsignedIntTest.test_mul | VM-CRASH | `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 \|     host_cls = _jac_standin_class(u.cls)  1051 \|     inst = host_cls.__new__(host_cls)  1052 \|     # Strong back-reference: while the host holds the stand-in, the` |
| UnsignedLongTest.test_mul | VM-CRASH | `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 \|     host_cls = _jac_standin_class(u.cls)  1051 \|     inst = host_cls.__new__(host_cls)  1052 \|     # Strong back-reference: while the host holds the stand-in, the` |
| UnsignedLongLongTest.test_mul | VM-CRASH | `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 \|     host_cls = _jac_standin_class(u.cls)  1051 \|     inst = host_cls.__new__(host_cls)  1052 \|     # Strong back-reference: while the host holds the stand-in, the` |
| FloatTest.test_mul | VM-CRASH | `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 \|     host_cls = _jac_standin_class(u.cls)  1051 \|     inst = host_cls.__new__(host_cls)  1052 \|     # Strong back-reference: while the host holds the stand-in, the` |
| DoubleTest.test_mul | VM-CRASH | `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 \|     host_cls = _jac_standin_class(u.cls)  1051 \|     inst = host_cls.__new__(host_cls)  1052 \|     # Strong back-reference: while the host holds the stand-in, the` |
| ByteTest.test_imul | VM-CRASH | `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 \|     host_cls = _jac_standin_class(u.cls)  1051 \|     inst = host_cls.__new__(host_cls)  1052 \|     # Strong back-reference: while the host holds the stand-in, the` |
| ShortTest.test_imul | VM-CRASH | `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 \|     host_cls = _jac_standin_class(u.cls)  1051 \|     inst = host_cls.__new__(host_cls)  1052 \|     # Strong back-reference: while the host holds the stand-in, the` |
| IntTest.test_imul | VM-CRASH | `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 \|     host_cls = _jac_standin_class(u.cls)  1051 \|     inst = host_cls.__new__(host_cls)  1052 \|     # Strong back-reference: while the host holds the stand-in, the` |
| LongTest.test_imul | VM-CRASH | `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 \|     host_cls = _jac_standin_class(u.cls)  1051 \|     inst = host_cls.__new__(host_cls)  1052 \|     # Strong back-reference: while the host holds the stand-in, the` |
| LongLongTest.test_imul | VM-CRASH | `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 \|     host_cls = _jac_standin_class(u.cls)  1051 \|     inst = host_cls.__new__(host_cls)  1052 \|     # Strong back-reference: while the host holds the stand-in, the` |
| UnsignedByteTest.test_imul | VM-CRASH | `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 \|     host_cls = _jac_standin_class(u.cls)  1051 \|     inst = host_cls.__new__(host_cls)  1052 \|     # Strong back-reference: while the host holds the stand-in, the` |
| UnsignedShortTest.test_imul | VM-CRASH | `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 \|     host_cls = _jac_standin_class(u.cls)  1051 \|     inst = host_cls.__new__(host_cls)  1052 \|     # Strong back-reference: while the host holds the stand-in, the` |
| UnsignedIntTest.test_imul | VM-CRASH | `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 \|     host_cls = _jac_standin_class(u.cls)  1051 \|     inst = host_cls.__new__(host_cls)  1052 \|     # Strong back-reference: while the host holds the stand-in, the` |
| UnsignedLongTest.test_imul | VM-CRASH | `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 \|     host_cls = _jac_standin_class(u.cls)  1051 \|     inst = host_cls.__new__(host_cls)  1052 \|     # Strong back-reference: while the host holds the stand-in, the` |
| UnsignedLongLongTest.test_imul | VM-CRASH | `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 \|     host_cls = _jac_standin_class(u.cls)  1051 \|     inst = host_cls.__new__(host_cls)  1052 \|     # Strong back-reference: while the host holds the stand-in, the` |
| FloatTest.test_imul | VM-CRASH | `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 \|     host_cls = _jac_standin_class(u.cls)  1051 \|     inst = host_cls.__new__(host_cls)  1052 \|     # Strong back-reference: while the host holds the stand-in, the` |
| DoubleTest.test_imul | VM-CRASH | `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 \|     host_cls = _jac_standin_class(u.cls)  1051 \|     inst = host_cls.__new__(host_cls)  1052 \|     # Strong back-reference: while the host holds the stand-in, the` |
| ByteTest.test_delitem | VM-CRASH | `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 \|     host_cls = _jac_standin_class(u.cls)  1051 \|     inst = host_cls.__new__(host_cls)  1052 \|     # Strong back-reference: while the host holds the stand-in, the` |
| ShortTest.test_delitem | VM-CRASH | `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 \|     host_cls = _jac_standin_class(u.cls)  1051 \|     inst = host_cls.__new__(host_cls)  1052 \|     # Strong back-reference: while the host holds the stand-in, the` |
| IntTest.test_delitem | VM-CRASH | `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 \|     host_cls = _jac_standin_class(u.cls)  1051 \|     inst = host_cls.__new__(host_cls)  1052 \|     # Strong back-reference: while the host holds the stand-in, the` |
| LongTest.test_delitem | VM-CRASH | `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 \|     host_cls = _jac_standin_class(u.cls)  1051 \|     inst = host_cls.__new__(host_cls)  1052 \|     # Strong back-reference: while the host holds the stand-in, the` |
| LongLongTest.test_delitem | VM-CRASH | `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 \|     host_cls = _jac_standin_class(u.cls)  1051 \|     inst = host_cls.__new__(host_cls)  1052 \|     # Strong back-reference: while the host holds the stand-in, the` |
| UnsignedByteTest.test_delitem | VM-CRASH | `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 \|     host_cls = _jac_standin_class(u.cls)  1051 \|     inst = host_cls.__new__(host_cls)  1052 \|     # Strong back-reference: while the host holds the stand-in, the` |
| UnsignedShortTest.test_delitem | VM-CRASH | `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 \|     host_cls = _jac_standin_class(u.cls)  1051 \|     inst = host_cls.__new__(host_cls)  1052 \|     # Strong back-reference: while the host holds the stand-in, the` |
| UnsignedIntTest.test_delitem | VM-CRASH | `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 \|     host_cls = _jac_standin_class(u.cls)  1051 \|     inst = host_cls.__new__(host_cls)  1052 \|     # Strong back-reference: while the host holds the stand-in, the` |
| UnsignedLongTest.test_delitem | VM-CRASH | `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 \|     host_cls = _jac_standin_class(u.cls)  1051 \|     inst = host_cls.__new__(host_cls)  1052 \|     # Strong back-reference: while the host holds the stand-in, the` |
| UnsignedLongLongTest.test_delitem | VM-CRASH | `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 \|     host_cls = _jac_standin_class(u.cls)  1051 \|     inst = host_cls.__new__(host_cls)  1052 \|     # Strong back-reference: while the host holds the stand-in, the` |
| FloatTest.test_delitem | VM-CRASH | `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 \|     host_cls = _jac_standin_class(u.cls)  1051 \|     inst = host_cls.__new__(host_cls)  1052 \|     # Strong back-reference: while the host holds the stand-in, the` |
| DoubleTest.test_delitem | VM-CRASH | `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 \|     host_cls = _jac_standin_class(u.cls)  1051 \|     inst = host_cls.__new__(host_cls)  1052 \|     # Strong back-reference: while the host holds the stand-in, the` |
| ByteTest.test_getslice | VM-CRASH | `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 \|     host_cls = _jac_standin_class(u.cls)  1051 \|     inst = host_cls.__new__(host_cls)  1052 \|     # Strong back-reference: while the host holds the stand-in, the` |
| ShortTest.test_getslice | VM-CRASH | `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 \|     host_cls = _jac_standin_class(u.cls)  1051 \|     inst = host_cls.__new__(host_cls)  1052 \|     # Strong back-reference: while the host holds the stand-in, the` |
| IntTest.test_getslice | VM-CRASH | `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 \|     host_cls = _jac_standin_class(u.cls)  1051 \|     inst = host_cls.__new__(host_cls)  1052 \|     # Strong back-reference: while the host holds the stand-in, the` |
| LongTest.test_getslice | VM-CRASH | `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 \|     host_cls = _jac_standin_class(u.cls)  1051 \|     inst = host_cls.__new__(host_cls)  1052 \|     # Strong back-reference: while the host holds the stand-in, the` |
| LongLongTest.test_getslice | VM-CRASH | `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 \|     host_cls = _jac_standin_class(u.cls)  1051 \|     inst = host_cls.__new__(host_cls)  1052 \|     # Strong back-reference: while the host holds the stand-in, the` |
| UnsignedByteTest.test_getslice | VM-CRASH | `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 \|     host_cls = _jac_standin_class(u.cls)  1051 \|     inst = host_cls.__new__(host_cls)  1052 \|     # Strong back-reference: while the host holds the stand-in, the` |
| UnsignedShortTest.test_getslice | VM-CRASH | `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 \|     host_cls = _jac_standin_class(u.cls)  1051 \|     inst = host_cls.__new__(host_cls)  1052 \|     # Strong back-reference: while the host holds the stand-in, the` |
| UnsignedIntTest.test_getslice | VM-CRASH | `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 \|     host_cls = _jac_standin_class(u.cls)  1051 \|     inst = host_cls.__new__(host_cls)  1052 \|     # Strong back-reference: while the host holds the stand-in, the` |
| UnsignedLongTest.test_getslice | VM-CRASH | `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 \|     host_cls = _jac_standin_class(u.cls)  1051 \|     inst = host_cls.__new__(host_cls)  1052 \|     # Strong back-reference: while the host holds the stand-in, the` |
| UnsignedLongLongTest.test_getslice | VM-CRASH | `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 \|     host_cls = _jac_standin_class(u.cls)  1051 \|     inst = host_cls.__new__(host_cls)  1052 \|     # Strong back-reference: while the host holds the stand-in, the` |
| FloatTest.test_getslice | VM-CRASH | `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 \|     host_cls = _jac_standin_class(u.cls)  1051 \|     inst = host_cls.__new__(host_cls)  1052 \|     # Strong back-reference: while the host holds the stand-in, the` |
| DoubleTest.test_getslice | VM-CRASH | `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 \|     host_cls = _jac_standin_class(u.cls)  1051 \|     inst = host_cls.__new__(host_cls)  1052 \|     # Strong back-reference: while the host holds the stand-in, the` |
| ByteTest.test_extended_getslice | VM-CRASH | `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 \|     host_cls = _jac_standin_class(u.cls)  1051 \|     inst = host_cls.__new__(host_cls)  1052 \|     # Strong back-reference: while the host holds the stand-in, the` |
| ShortTest.test_extended_getslice | VM-CRASH | `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 \|     host_cls = _jac_standin_class(u.cls)  1051 \|     inst = host_cls.__new__(host_cls)  1052 \|     # Strong back-reference: while the host holds the stand-in, the` |
| IntTest.test_extended_getslice | VM-CRASH | `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 \|     host_cls = _jac_standin_class(u.cls)  1051 \|     inst = host_cls.__new__(host_cls)  1052 \|     # Strong back-reference: while the host holds the stand-in, the` |
| LongTest.test_extended_getslice | VM-CRASH | `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 \|     host_cls = _jac_standin_class(u.cls)  1051 \|     inst = host_cls.__new__(host_cls)  1052 \|     # Strong back-reference: while the host holds the stand-in, the` |
| LongLongTest.test_extended_getslice | VM-CRASH | `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 \|     host_cls = _jac_standin_class(u.cls)  1051 \|     inst = host_cls.__new__(host_cls)  1052 \|     # Strong back-reference: while the host holds the stand-in, the` |
| UnsignedByteTest.test_extended_getslice | VM-CRASH | `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 \|     host_cls = _jac_standin_class(u.cls)  1051 \|     inst = host_cls.__new__(host_cls)  1052 \|     # Strong back-reference: while the host holds the stand-in, the` |
| UnsignedShortTest.test_extended_getslice | VM-CRASH | `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 \|     host_cls = _jac_standin_class(u.cls)  1051 \|     inst = host_cls.__new__(host_cls)  1052 \|     # Strong back-reference: while the host holds the stand-in, the` |
| UnsignedIntTest.test_extended_getslice | VM-CRASH | `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 \|     host_cls = _jac_standin_class(u.cls)  1051 \|     inst = host_cls.__new__(host_cls)  1052 \|     # Strong back-reference: while the host holds the stand-in, the` |
| UnsignedLongTest.test_extended_getslice | VM-CRASH | `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 \|     host_cls = _jac_standin_class(u.cls)  1051 \|     inst = host_cls.__new__(host_cls)  1052 \|     # Strong back-reference: while the host holds the stand-in, the` |
| UnsignedLongLongTest.test_extended_getslice | VM-CRASH | `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 \|     host_cls = _jac_standin_class(u.cls)  1051 \|     inst = host_cls.__new__(host_cls)  1052 \|     # Strong back-reference: while the host holds the stand-in, the` |
| FloatTest.test_extended_getslice | VM-CRASH | `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 \|     host_cls = _jac_standin_class(u.cls)  1051 \|     inst = host_cls.__new__(host_cls)  1052 \|     # Strong back-reference: while the host holds the stand-in, the` |
| DoubleTest.test_extended_getslice | VM-CRASH | `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 \|     host_cls = _jac_standin_class(u.cls)  1051 \|     inst = host_cls.__new__(host_cls)  1052 \|     # Strong back-reference: while the host holds the stand-in, the` |
| ByteTest.test_extended_set_del_slice | VM-CRASH | `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 \|     host_cls = _jac_standin_class(u.cls)  1051 \|     inst = host_cls.__new__(host_cls)  1052 \|     # Strong back-reference: while the host holds the stand-in, the` |
| ShortTest.test_extended_set_del_slice | VM-CRASH | `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 \|     host_cls = _jac_standin_class(u.cls)  1051 \|     inst = host_cls.__new__(host_cls)  1052 \|     # Strong back-reference: while the host holds the stand-in, the` |
| IntTest.test_extended_set_del_slice | VM-CRASH | `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 \|     host_cls = _jac_standin_class(u.cls)  1051 \|     inst = host_cls.__new__(host_cls)  1052 \|     # Strong back-reference: while the host holds the stand-in, the` |
| LongTest.test_extended_set_del_slice | VM-CRASH | `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 \|     host_cls = _jac_standin_class(u.cls)  1051 \|     inst = host_cls.__new__(host_cls)  1052 \|     # Strong back-reference: while the host holds the stand-in, the` |
| LongLongTest.test_extended_set_del_slice | VM-CRASH | `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 \|     host_cls = _jac_standin_class(u.cls)  1051 \|     inst = host_cls.__new__(host_cls)  1052 \|     # Strong back-reference: while the host holds the stand-in, the` |
| UnsignedByteTest.test_extended_set_del_slice | VM-CRASH | `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 \|     host_cls = _jac_standin_class(u.cls)  1051 \|     inst = host_cls.__new__(host_cls)  1052 \|     # Strong back-reference: while the host holds the stand-in, the` |
| UnsignedShortTest.test_extended_set_del_slice | VM-CRASH | `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 \|     host_cls = _jac_standin_class(u.cls)  1051 \|     inst = host_cls.__new__(host_cls)  1052 \|     # Strong back-reference: while the host holds the stand-in, the` |
| UnsignedIntTest.test_extended_set_del_slice | VM-CRASH | `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 \|     host_cls = _jac_standin_class(u.cls)  1051 \|     inst = host_cls.__new__(host_cls)  1052 \|     # Strong back-reference: while the host holds the stand-in, the` |
| UnsignedLongTest.test_extended_set_del_slice | VM-CRASH | `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 \|     host_cls = _jac_standin_class(u.cls)  1051 \|     inst = host_cls.__new__(host_cls)  1052 \|     # Strong back-reference: while the host holds the stand-in, the` |
| UnsignedLongLongTest.test_extended_set_del_slice | VM-CRASH | `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 \|     host_cls = _jac_standin_class(u.cls)  1051 \|     inst = host_cls.__new__(host_cls)  1052 \|     # Strong back-reference: while the host holds the stand-in, the` |
| FloatTest.test_extended_set_del_slice | VM-CRASH | `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 \|     host_cls = _jac_standin_class(u.cls)  1051 \|     inst = host_cls.__new__(host_cls)  1052 \|     # Strong back-reference: while the host holds the stand-in, the` |
| DoubleTest.test_extended_set_del_slice | VM-CRASH | `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 \|     host_cls = _jac_standin_class(u.cls)  1051 \|     inst = host_cls.__new__(host_cls)  1052 \|     # Strong back-reference: while the host holds the stand-in, the` |
| ByteTest.test_index | VM-CRASH | `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 \|     host_cls = _jac_standin_class(u.cls)  1051 \|     inst = host_cls.__new__(host_cls)  1052 \|     # Strong back-reference: while the host holds the stand-in, the` |
| ShortTest.test_index | VM-CRASH | `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 \|     host_cls = _jac_standin_class(u.cls)  1051 \|     inst = host_cls.__new__(host_cls)  1052 \|     # Strong back-reference: while the host holds the stand-in, the` |
| IntTest.test_index | VM-CRASH | `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 \|     host_cls = _jac_standin_class(u.cls)  1051 \|     inst = host_cls.__new__(host_cls)  1052 \|     # Strong back-reference: while the host holds the stand-in, the` |
| LongTest.test_index | VM-CRASH | `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 \|     host_cls = _jac_standin_class(u.cls)  1051 \|     inst = host_cls.__new__(host_cls)  1052 \|     # Strong back-reference: while the host holds the stand-in, the` |
| LongLongTest.test_index | VM-CRASH | `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 \|     host_cls = _jac_standin_class(u.cls)  1051 \|     inst = host_cls.__new__(host_cls)  1052 \|     # Strong back-reference: while the host holds the stand-in, the` |
| UnsignedByteTest.test_index | VM-CRASH | `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 \|     host_cls = _jac_standin_class(u.cls)  1051 \|     inst = host_cls.__new__(host_cls)  1052 \|     # Strong back-reference: while the host holds the stand-in, the` |
| UnsignedShortTest.test_index | VM-CRASH | `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 \|     host_cls = _jac_standin_class(u.cls)  1051 \|     inst = host_cls.__new__(host_cls)  1052 \|     # Strong back-reference: while the host holds the stand-in, the` |
| UnsignedIntTest.test_index | VM-CRASH | `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 \|     host_cls = _jac_standin_class(u.cls)  1051 \|     inst = host_cls.__new__(host_cls)  1052 \|     # Strong back-reference: while the host holds the stand-in, the` |
| UnsignedLongTest.test_index | VM-CRASH | `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 \|     host_cls = _jac_standin_class(u.cls)  1051 \|     inst = host_cls.__new__(host_cls)  1052 \|     # Strong back-reference: while the host holds the stand-in, the` |
| UnsignedLongLongTest.test_index | VM-CRASH | `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 \|     host_cls = _jac_standin_class(u.cls)  1051 \|     inst = host_cls.__new__(host_cls)  1052 \|     # Strong back-reference: while the host holds the stand-in, the` |
| FloatTest.test_index | VM-CRASH | `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 \|     host_cls = _jac_standin_class(u.cls)  1051 \|     inst = host_cls.__new__(host_cls)  1052 \|     # Strong back-reference: while the host holds the stand-in, the` |
| DoubleTest.test_index | VM-CRASH | `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 \|     host_cls = _jac_standin_class(u.cls)  1051 \|     inst = host_cls.__new__(host_cls)  1052 \|     # Strong back-reference: while the host holds the stand-in, the` |
| ByteTest.test_count | VM-CRASH | `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 \|     host_cls = _jac_standin_class(u.cls)  1051 \|     inst = host_cls.__new__(host_cls)  1052 \|     # Strong back-reference: while the host holds the stand-in, the` |
| ShortTest.test_count | VM-CRASH | `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 \|     host_cls = _jac_standin_class(u.cls)  1051 \|     inst = host_cls.__new__(host_cls)  1052 \|     # Strong back-reference: while the host holds the stand-in, the` |
| IntTest.test_count | VM-CRASH | `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 \|     host_cls = _jac_standin_class(u.cls)  1051 \|     inst = host_cls.__new__(host_cls)  1052 \|     # Strong back-reference: while the host holds the stand-in, the` |
| LongTest.test_count | VM-CRASH | `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 \|     host_cls = _jac_standin_class(u.cls)  1051 \|     inst = host_cls.__new__(host_cls)  1052 \|     # Strong back-reference: while the host holds the stand-in, the` |
| LongLongTest.test_count | VM-CRASH | `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 \|     host_cls = _jac_standin_class(u.cls)  1051 \|     inst = host_cls.__new__(host_cls)  1052 \|     # Strong back-reference: while the host holds the stand-in, the` |
| UnsignedByteTest.test_count | VM-CRASH | `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 \|     host_cls = _jac_standin_class(u.cls)  1051 \|     inst = host_cls.__new__(host_cls)  1052 \|     # Strong back-reference: while the host holds the stand-in, the` |
| UnsignedShortTest.test_count | VM-CRASH | `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 \|     host_cls = _jac_standin_class(u.cls)  1051 \|     inst = host_cls.__new__(host_cls)  1052 \|     # Strong back-reference: while the host holds the stand-in, the` |
| UnsignedIntTest.test_count | VM-CRASH | `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 \|     host_cls = _jac_standin_class(u.cls)  1051 \|     inst = host_cls.__new__(host_cls)  1052 \|     # Strong back-reference: while the host holds the stand-in, the` |
| UnsignedLongTest.test_count | VM-CRASH | `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 \|     host_cls = _jac_standin_class(u.cls)  1051 \|     inst = host_cls.__new__(host_cls)  1052 \|     # Strong back-reference: while the host holds the stand-in, the` |
| UnsignedLongLongTest.test_count | VM-CRASH | `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 \|     host_cls = _jac_standin_class(u.cls)  1051 \|     inst = host_cls.__new__(host_cls)  1052 \|     # Strong back-reference: while the host holds the stand-in, the` |
| FloatTest.test_count | VM-CRASH | `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 \|     host_cls = _jac_standin_class(u.cls)  1051 \|     inst = host_cls.__new__(host_cls)  1052 \|     # Strong back-reference: while the host holds the stand-in, the` |
| DoubleTest.test_count | VM-CRASH | `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 \|     host_cls = _jac_standin_class(u.cls)  1051 \|     inst = host_cls.__new__(host_cls)  1052 \|     # Strong back-reference: while the host holds the stand-in, the` |
| ByteTest.test_remove | VM-CRASH | `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 \|     host_cls = _jac_standin_class(u.cls)  1051 \|     inst = host_cls.__new__(host_cls)  1052 \|     # Strong back-reference: while the host holds the stand-in, the` |
| ShortTest.test_remove | VM-CRASH | `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 \|     host_cls = _jac_standin_class(u.cls)  1051 \|     inst = host_cls.__new__(host_cls)  1052 \|     # Strong back-reference: while the host holds the stand-in, the` |
| IntTest.test_remove | VM-CRASH | `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 \|     host_cls = _jac_standin_class(u.cls)  1051 \|     inst = host_cls.__new__(host_cls)  1052 \|     # Strong back-reference: while the host holds the stand-in, the` |
| LongTest.test_remove | VM-CRASH | `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 \|     host_cls = _jac_standin_class(u.cls)  1051 \|     inst = host_cls.__new__(host_cls)  1052 \|     # Strong back-reference: while the host holds the stand-in, the` |
| LongLongTest.test_remove | VM-CRASH | `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 \|     host_cls = _jac_standin_class(u.cls)  1051 \|     inst = host_cls.__new__(host_cls)  1052 \|     # Strong back-reference: while the host holds the stand-in, the` |
| UnsignedByteTest.test_remove | VM-CRASH | `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 \|     host_cls = _jac_standin_class(u.cls)  1051 \|     inst = host_cls.__new__(host_cls)  1052 \|     # Strong back-reference: while the host holds the stand-in, the` |
| UnsignedShortTest.test_remove | VM-CRASH | `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 \|     host_cls = _jac_standin_class(u.cls)  1051 \|     inst = host_cls.__new__(host_cls)  1052 \|     # Strong back-reference: while the host holds the stand-in, the` |
| UnsignedIntTest.test_remove | VM-CRASH | `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 \|     host_cls = _jac_standin_class(u.cls)  1051 \|     inst = host_cls.__new__(host_cls)  1052 \|     # Strong back-reference: while the host holds the stand-in, the` |
| UnsignedLongTest.test_remove | VM-CRASH | `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 \|     host_cls = _jac_standin_class(u.cls)  1051 \|     inst = host_cls.__new__(host_cls)  1052 \|     # Strong back-reference: while the host holds the stand-in, the` |
| UnsignedLongLongTest.test_remove | VM-CRASH | `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 \|     host_cls = _jac_standin_class(u.cls)  1051 \|     inst = host_cls.__new__(host_cls)  1052 \|     # Strong back-reference: while the host holds the stand-in, the` |
| FloatTest.test_remove | VM-CRASH | `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 \|     host_cls = _jac_standin_class(u.cls)  1051 \|     inst = host_cls.__new__(host_cls)  1052 \|     # Strong back-reference: while the host holds the stand-in, the` |
| DoubleTest.test_remove | VM-CRASH | `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 \|     host_cls = _jac_standin_class(u.cls)  1051 \|     inst = host_cls.__new__(host_cls)  1052 \|     # Strong back-reference: while the host holds the stand-in, the` |
| ByteTest.test_reverse | VM-CRASH | `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 \|     host_cls = _jac_standin_class(u.cls)  1051 \|     inst = host_cls.__new__(host_cls)  1052 \|     # Strong back-reference: while the host holds the stand-in, the` |
| ShortTest.test_reverse | VM-CRASH | `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 \|     host_cls = _jac_standin_class(u.cls)  1051 \|     inst = host_cls.__new__(host_cls)  1052 \|     # Strong back-reference: while the host holds the stand-in, the` |
| IntTest.test_reverse | VM-CRASH | `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 \|     host_cls = _jac_standin_class(u.cls)  1051 \|     inst = host_cls.__new__(host_cls)  1052 \|     # Strong back-reference: while the host holds the stand-in, the` |
| LongTest.test_reverse | VM-CRASH | `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 \|     host_cls = _jac_standin_class(u.cls)  1051 \|     inst = host_cls.__new__(host_cls)  1052 \|     # Strong back-reference: while the host holds the stand-in, the` |
| LongLongTest.test_reverse | VM-CRASH | `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 \|     host_cls = _jac_standin_class(u.cls)  1051 \|     inst = host_cls.__new__(host_cls)  1052 \|     # Strong back-reference: while the host holds the stand-in, the` |
| UnsignedByteTest.test_reverse | VM-CRASH | `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 \|     host_cls = _jac_standin_class(u.cls)  1051 \|     inst = host_cls.__new__(host_cls)  1052 \|     # Strong back-reference: while the host holds the stand-in, the` |
| UnsignedShortTest.test_reverse | VM-CRASH | `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 \|     host_cls = _jac_standin_class(u.cls)  1051 \|     inst = host_cls.__new__(host_cls)  1052 \|     # Strong back-reference: while the host holds the stand-in, the` |
| UnsignedIntTest.test_reverse | VM-CRASH | `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 \|     host_cls = _jac_standin_class(u.cls)  1051 \|     inst = host_cls.__new__(host_cls)  1052 \|     # Strong back-reference: while the host holds the stand-in, the` |
| UnsignedLongTest.test_reverse | VM-CRASH | `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 \|     host_cls = _jac_standin_class(u.cls)  1051 \|     inst = host_cls.__new__(host_cls)  1052 \|     # Strong back-reference: while the host holds the stand-in, the` |
| UnsignedLongLongTest.test_reverse | VM-CRASH | `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 \|     host_cls = _jac_standin_class(u.cls)  1051 \|     inst = host_cls.__new__(host_cls)  1052 \|     # Strong back-reference: while the host holds the stand-in, the` |
| FloatTest.test_reverse | VM-CRASH | `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 \|     host_cls = _jac_standin_class(u.cls)  1051 \|     inst = host_cls.__new__(host_cls)  1052 \|     # Strong back-reference: while the host holds the stand-in, the` |
| DoubleTest.test_reverse | VM-CRASH | `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 \|     host_cls = _jac_standin_class(u.cls)  1051 \|     inst = host_cls.__new__(host_cls)  1052 \|     # Strong back-reference: while the host holds the stand-in, the` |
| ByteTest.test_constructor_with_iterable_argument | VM-CRASH | `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 \|     host_cls = _jac_standin_class(u.cls)  1051 \|     inst = host_cls.__new__(host_cls)  1052 \|     # Strong back-reference: while the host holds the stand-in, the` |
| ShortTest.test_constructor_with_iterable_argument | VM-CRASH | `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 \|     host_cls = _jac_standin_class(u.cls)  1051 \|     inst = host_cls.__new__(host_cls)  1052 \|     # Strong back-reference: while the host holds the stand-in, the` |
| IntTest.test_constructor_with_iterable_argument | VM-CRASH | `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 \|     host_cls = _jac_standin_class(u.cls)  1051 \|     inst = host_cls.__new__(host_cls)  1052 \|     # Strong back-reference: while the host holds the stand-in, the` |
| LongTest.test_constructor_with_iterable_argument | VM-CRASH | `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 \|     host_cls = _jac_standin_class(u.cls)  1051 \|     inst = host_cls.__new__(host_cls)  1052 \|     # Strong back-reference: while the host holds the stand-in, the` |
| LongLongTest.test_constructor_with_iterable_argument | VM-CRASH | `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 \|     host_cls = _jac_standin_class(u.cls)  1051 \|     inst = host_cls.__new__(host_cls)  1052 \|     # Strong back-reference: while the host holds the stand-in, the` |
| UnsignedByteTest.test_constructor_with_iterable_argument | VM-CRASH | `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 \|     host_cls = _jac_standin_class(u.cls)  1051 \|     inst = host_cls.__new__(host_cls)  1052 \|     # Strong back-reference: while the host holds the stand-in, the` |
| UnsignedShortTest.test_constructor_with_iterable_argument | VM-CRASH | `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 \|     host_cls = _jac_standin_class(u.cls)  1051 \|     inst = host_cls.__new__(host_cls)  1052 \|     # Strong back-reference: while the host holds the stand-in, the` |
| UnsignedIntTest.test_constructor_with_iterable_argument | VM-CRASH | `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 \|     host_cls = _jac_standin_class(u.cls)  1051 \|     inst = host_cls.__new__(host_cls)  1052 \|     # Strong back-reference: while the host holds the stand-in, the` |
| UnsignedLongTest.test_constructor_with_iterable_argument | VM-CRASH | `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 \|     host_cls = _jac_standin_class(u.cls)  1051 \|     inst = host_cls.__new__(host_cls)  1052 \|     # Strong back-reference: while the host holds the stand-in, the` |
| UnsignedLongLongTest.test_constructor_with_iterable_argument | VM-CRASH | `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 \|     host_cls = _jac_standin_class(u.cls)  1051 \|     inst = host_cls.__new__(host_cls)  1052 \|     # Strong back-reference: while the host holds the stand-in, the` |
| FloatTest.test_constructor_with_iterable_argument | VM-CRASH | `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 \|     host_cls = _jac_standin_class(u.cls)  1051 \|     inst = host_cls.__new__(host_cls)  1052 \|     # Strong back-reference: while the host holds the stand-in, the` |
| DoubleTest.test_constructor_with_iterable_argument | VM-CRASH | `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 \|     host_cls = _jac_standin_class(u.cls)  1051 \|     inst = host_cls.__new__(host_cls)  1052 \|     # Strong back-reference: while the host holds the stand-in, the` |
| ByteTest.test_buffer | VM-CRASH | `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 \|     host_cls = _jac_standin_class(u.cls)  1051 \|     inst = host_cls.__new__(host_cls)  1052 \|     # Strong back-reference: while the host holds the stand-in, the` |
| ShortTest.test_buffer | VM-CRASH | `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 \|     host_cls = _jac_standin_class(u.cls)  1051 \|     inst = host_cls.__new__(host_cls)  1052 \|     # Strong back-reference: while the host holds the stand-in, the` |
| IntTest.test_buffer | VM-CRASH | `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 \|     host_cls = _jac_standin_class(u.cls)  1051 \|     inst = host_cls.__new__(host_cls)  1052 \|     # Strong back-reference: while the host holds the stand-in, the` |
| LongTest.test_buffer | VM-CRASH | `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 \|     host_cls = _jac_standin_class(u.cls)  1051 \|     inst = host_cls.__new__(host_cls)  1052 \|     # Strong back-reference: while the host holds the stand-in, the` |
| LongLongTest.test_buffer | VM-CRASH | `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 \|     host_cls = _jac_standin_class(u.cls)  1051 \|     inst = host_cls.__new__(host_cls)  1052 \|     # Strong back-reference: while the host holds the stand-in, the` |
| UnsignedByteTest.test_buffer | VM-CRASH | `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 \|     host_cls = _jac_standin_class(u.cls)  1051 \|     inst = host_cls.__new__(host_cls)  1052 \|     # Strong back-reference: while the host holds the stand-in, the` |
| UnsignedShortTest.test_buffer | VM-CRASH | `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 \|     host_cls = _jac_standin_class(u.cls)  1051 \|     inst = host_cls.__new__(host_cls)  1052 \|     # Strong back-reference: while the host holds the stand-in, the` |
| UnsignedIntTest.test_buffer | VM-CRASH | `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 \|     host_cls = _jac_standin_class(u.cls)  1051 \|     inst = host_cls.__new__(host_cls)  1052 \|     # Strong back-reference: while the host holds the stand-in, the` |
| UnsignedLongTest.test_buffer | VM-CRASH | `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 \|     host_cls = _jac_standin_class(u.cls)  1051 \|     inst = host_cls.__new__(host_cls)  1052 \|     # Strong back-reference: while the host holds the stand-in, the` |
| UnsignedLongLongTest.test_buffer | VM-CRASH | `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 \|     host_cls = _jac_standin_class(u.cls)  1051 \|     inst = host_cls.__new__(host_cls)  1052 \|     # Strong back-reference: while the host holds the stand-in, the` |
| FloatTest.test_buffer | VM-CRASH | `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 \|     host_cls = _jac_standin_class(u.cls)  1051 \|     inst = host_cls.__new__(host_cls)  1052 \|     # Strong back-reference: while the host holds the stand-in, the` |
| DoubleTest.test_buffer | VM-CRASH | `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 \|     host_cls = _jac_standin_class(u.cls)  1051 \|     inst = host_cls.__new__(host_cls)  1052 \|     # Strong back-reference: while the host holds the stand-in, the` |
| UCS4Test.test_subclass_with_kwargs | VM-CRASH | `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 \|     host_cls = _jac_standin_class(u.cls)  1051 \|     inst = host_cls.__new__(host_cls)  1052 \|     # Strong back-reference: while the host holds the stand-in, the` |
| ByteTest.test_subclass_with_kwargs | VM-CRASH | `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 \|     host_cls = _jac_standin_class(u.cls)  1051 \|     inst = host_cls.__new__(host_cls)  1052 \|     # Strong back-reference: while the host holds the stand-in, the` |
| ShortTest.test_subclass_with_kwargs | VM-CRASH | `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 \|     host_cls = _jac_standin_class(u.cls)  1051 \|     inst = host_cls.__new__(host_cls)  1052 \|     # Strong back-reference: while the host holds the stand-in, the` |
| IntTest.test_subclass_with_kwargs | VM-CRASH | `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 \|     host_cls = _jac_standin_class(u.cls)  1051 \|     inst = host_cls.__new__(host_cls)  1052 \|     # Strong back-reference: while the host holds the stand-in, the` |
| LongTest.test_subclass_with_kwargs | VM-CRASH | `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 \|     host_cls = _jac_standin_class(u.cls)  1051 \|     inst = host_cls.__new__(host_cls)  1052 \|     # Strong back-reference: while the host holds the stand-in, the` |
| LongLongTest.test_subclass_with_kwargs | VM-CRASH | `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 \|     host_cls = _jac_standin_class(u.cls)  1051 \|     inst = host_cls.__new__(host_cls)  1052 \|     # Strong back-reference: while the host holds the stand-in, the` |
| UnsignedByteTest.test_subclass_with_kwargs | VM-CRASH | `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 \|     host_cls = _jac_standin_class(u.cls)  1051 \|     inst = host_cls.__new__(host_cls)  1052 \|     # Strong back-reference: while the host holds the stand-in, the` |
| UnsignedShortTest.test_subclass_with_kwargs | VM-CRASH | `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 \|     host_cls = _jac_standin_class(u.cls)  1051 \|     inst = host_cls.__new__(host_cls)  1052 \|     # Strong back-reference: while the host holds the stand-in, the` |
| UnsignedIntTest.test_subclass_with_kwargs | VM-CRASH | `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 \|     host_cls = _jac_standin_class(u.cls)  1051 \|     inst = host_cls.__new__(host_cls)  1052 \|     # Strong back-reference: while the host holds the stand-in, the` |
| UnsignedLongTest.test_subclass_with_kwargs | VM-CRASH | `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 \|     host_cls = _jac_standin_class(u.cls)  1051 \|     inst = host_cls.__new__(host_cls)  1052 \|     # Strong back-reference: while the host holds the stand-in, the` |
| UnsignedLongLongTest.test_subclass_with_kwargs | VM-CRASH | `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 \|     host_cls = _jac_standin_class(u.cls)  1051 \|     inst = host_cls.__new__(host_cls)  1052 \|     # Strong back-reference: while the host holds the stand-in, the` |
| FloatTest.test_subclass_with_kwargs | VM-CRASH | `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 \|     host_cls = _jac_standin_class(u.cls)  1051 \|     inst = host_cls.__new__(host_cls)  1052 \|     # Strong back-reference: while the host holds the stand-in, the` |
| DoubleTest.test_subclass_with_kwargs | VM-CRASH | `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 \|     host_cls = _jac_standin_class(u.cls)  1051 \|     inst = host_cls.__new__(host_cls)  1052 \|     # Strong back-reference: while the host holds the stand-in, the` |
| UCS4Test.test_create_from_bytes | VM-CRASH | `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 \|     host_cls = _jac_standin_class(u.cls)  1051 \|     inst = host_cls.__new__(host_cls)  1052 \|     # Strong back-reference: while the host holds the stand-in, the` |
| ByteTest.test_create_from_bytes | VM-CRASH | `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 \|     host_cls = _jac_standin_class(u.cls)  1051 \|     inst = host_cls.__new__(host_cls)  1052 \|     # Strong back-reference: while the host holds the stand-in, the` |
| ShortTest.test_create_from_bytes | VM-CRASH | `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 \|     host_cls = _jac_standin_class(u.cls)  1051 \|     inst = host_cls.__new__(host_cls)  1052 \|     # Strong back-reference: while the host holds the stand-in, the` |
| IntTest.test_create_from_bytes | VM-CRASH | `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 \|     host_cls = _jac_standin_class(u.cls)  1051 \|     inst = host_cls.__new__(host_cls)  1052 \|     # Strong back-reference: while the host holds the stand-in, the` |
| LongTest.test_create_from_bytes | VM-CRASH | `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 \|     host_cls = _jac_standin_class(u.cls)  1051 \|     inst = host_cls.__new__(host_cls)  1052 \|     # Strong back-reference: while the host holds the stand-in, the` |
| LongLongTest.test_create_from_bytes | VM-CRASH | `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 \|     host_cls = _jac_standin_class(u.cls)  1051 \|     inst = host_cls.__new__(host_cls)  1052 \|     # Strong back-reference: while the host holds the stand-in, the` |
| UnsignedByteTest.test_create_from_bytes | VM-CRASH | `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 \|     host_cls = _jac_standin_class(u.cls)  1051 \|     inst = host_cls.__new__(host_cls)  1052 \|     # Strong back-reference: while the host holds the stand-in, the` |
| UnsignedShortTest.test_create_from_bytes | VM-CRASH | `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 \|     host_cls = _jac_standin_class(u.cls)  1051 \|     inst = host_cls.__new__(host_cls)  1052 \|     # Strong back-reference: while the host holds the stand-in, the` |
| UnsignedIntTest.test_create_from_bytes | VM-CRASH | `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 \|     host_cls = _jac_standin_class(u.cls)  1051 \|     inst = host_cls.__new__(host_cls)  1052 \|     # Strong back-reference: while the host holds the stand-in, the` |
| UnsignedLongTest.test_create_from_bytes | VM-CRASH | `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 \|     host_cls = _jac_standin_class(u.cls)  1051 \|     inst = host_cls.__new__(host_cls)  1052 \|     # Strong back-reference: while the host holds the stand-in, the` |
| UnsignedLongLongTest.test_create_from_bytes | VM-CRASH | `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 \|     host_cls = _jac_standin_class(u.cls)  1051 \|     inst = host_cls.__new__(host_cls)  1052 \|     # Strong back-reference: while the host holds the stand-in, the` |
| FloatTest.test_create_from_bytes | VM-CRASH | `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 \|     host_cls = _jac_standin_class(u.cls)  1051 \|     inst = host_cls.__new__(host_cls)  1052 \|     # Strong back-reference: while the host holds the stand-in, the` |
| DoubleTest.test_create_from_bytes | VM-CRASH | `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 \|     host_cls = _jac_standin_class(u.cls)  1051 \|     inst = host_cls.__new__(host_cls)  1052 \|     # Strong back-reference: while the host holds the stand-in, the` |
| UCS4Test.test_empty_string_mem_leak_gh140474 | VM-CRASH | `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 \|     host_cls = _jac_standin_class(u.cls)  1051 \|     inst = host_cls.__new__(host_cls)  1052 \|     # Strong back-reference: while the host holds the stand-in, the` |
| ByteTest.test_extslice | VM-CRASH | `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 \|     host_cls = _jac_standin_class(u.cls)  1051 \|     inst = host_cls.__new__(host_cls)  1052 \|     # Strong back-reference: while the host holds the stand-in, the` |
| ShortTest.test_extslice | VM-CRASH | `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 \|     host_cls = _jac_standin_class(u.cls)  1051 \|     inst = host_cls.__new__(host_cls)  1052 \|     # Strong back-reference: while the host holds the stand-in, the` |
| IntTest.test_extslice | VM-CRASH | `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 \|     host_cls = _jac_standin_class(u.cls)  1051 \|     inst = host_cls.__new__(host_cls)  1052 \|     # Strong back-reference: while the host holds the stand-in, the` |
| LongTest.test_extslice | VM-CRASH | `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 \|     host_cls = _jac_standin_class(u.cls)  1051 \|     inst = host_cls.__new__(host_cls)  1052 \|     # Strong back-reference: while the host holds the stand-in, the` |
| LongLongTest.test_extslice | VM-CRASH | `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 \|     host_cls = _jac_standin_class(u.cls)  1051 \|     inst = host_cls.__new__(host_cls)  1052 \|     # Strong back-reference: while the host holds the stand-in, the` |
| UnsignedByteTest.test_extslice | VM-CRASH | `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 \|     host_cls = _jac_standin_class(u.cls)  1051 \|     inst = host_cls.__new__(host_cls)  1052 \|     # Strong back-reference: while the host holds the stand-in, the` |
| UnsignedShortTest.test_extslice | VM-CRASH | `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 \|     host_cls = _jac_standin_class(u.cls)  1051 \|     inst = host_cls.__new__(host_cls)  1052 \|     # Strong back-reference: while the host holds the stand-in, the` |
| UnsignedIntTest.test_extslice | VM-CRASH | `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 \|     host_cls = _jac_standin_class(u.cls)  1051 \|     inst = host_cls.__new__(host_cls)  1052 \|     # Strong back-reference: while the host holds the stand-in, the` |
| UnsignedLongTest.test_extslice | VM-CRASH | `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 \|     host_cls = _jac_standin_class(u.cls)  1051 \|     inst = host_cls.__new__(host_cls)  1052 \|     # Strong back-reference: while the host holds the stand-in, the` |
| UnsignedLongLongTest.test_extslice | VM-CRASH | `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 \|     host_cls = _jac_standin_class(u.cls)  1051 \|     inst = host_cls.__new__(host_cls)  1052 \|     # Strong back-reference: while the host holds the stand-in, the` |
| FloatTest.test_extslice | VM-CRASH | `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 \|     host_cls = _jac_standin_class(u.cls)  1051 \|     inst = host_cls.__new__(host_cls)  1052 \|     # Strong back-reference: while the host holds the stand-in, the` |
| DoubleTest.test_extslice | VM-CRASH | `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 \|     host_cls = _jac_standin_class(u.cls)  1051 \|     inst = host_cls.__new__(host_cls)  1052 \|     # Strong back-reference: while the host holds the stand-in, the` |
| ByteTest.test_delslice | VM-CRASH | `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 \|     host_cls = _jac_standin_class(u.cls)  1051 \|     inst = host_cls.__new__(host_cls)  1052 \|     # Strong back-reference: while the host holds the stand-in, the` |
| ShortTest.test_delslice | VM-CRASH | `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 \|     host_cls = _jac_standin_class(u.cls)  1051 \|     inst = host_cls.__new__(host_cls)  1052 \|     # Strong back-reference: while the host holds the stand-in, the` |
| IntTest.test_delslice | VM-CRASH | `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 \|     host_cls = _jac_standin_class(u.cls)  1051 \|     inst = host_cls.__new__(host_cls)  1052 \|     # Strong back-reference: while the host holds the stand-in, the` |
| LongTest.test_delslice | VM-CRASH | `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 \|     host_cls = _jac_standin_class(u.cls)  1051 \|     inst = host_cls.__new__(host_cls)  1052 \|     # Strong back-reference: while the host holds the stand-in, the` |
| LongLongTest.test_delslice | VM-CRASH | `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 \|     host_cls = _jac_standin_class(u.cls)  1051 \|     inst = host_cls.__new__(host_cls)  1052 \|     # Strong back-reference: while the host holds the stand-in, the` |
| UnsignedByteTest.test_delslice | VM-CRASH | `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 \|     host_cls = _jac_standin_class(u.cls)  1051 \|     inst = host_cls.__new__(host_cls)  1052 \|     # Strong back-reference: while the host holds the stand-in, the` |
| UnsignedShortTest.test_delslice | VM-CRASH | `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 \|     host_cls = _jac_standin_class(u.cls)  1051 \|     inst = host_cls.__new__(host_cls)  1052 \|     # Strong back-reference: while the host holds the stand-in, the` |
| UnsignedIntTest.test_delslice | VM-CRASH | `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 \|     host_cls = _jac_standin_class(u.cls)  1051 \|     inst = host_cls.__new__(host_cls)  1052 \|     # Strong back-reference: while the host holds the stand-in, the` |
| UnsignedLongTest.test_delslice | VM-CRASH | `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 \|     host_cls = _jac_standin_class(u.cls)  1051 \|     inst = host_cls.__new__(host_cls)  1052 \|     # Strong back-reference: while the host holds the stand-in, the` |
| UnsignedLongLongTest.test_delslice | VM-CRASH | `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 \|     host_cls = _jac_standin_class(u.cls)  1051 \|     inst = host_cls.__new__(host_cls)  1052 \|     # Strong back-reference: while the host holds the stand-in, the` |
| FloatTest.test_delslice | VM-CRASH | `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 \|     host_cls = _jac_standin_class(u.cls)  1051 \|     inst = host_cls.__new__(host_cls)  1052 \|     # Strong back-reference: while the host holds the stand-in, the` |
| DoubleTest.test_delslice | VM-CRASH | `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 \|     host_cls = _jac_standin_class(u.cls)  1051 \|     inst = host_cls.__new__(host_cls)  1052 \|     # Strong back-reference: while the host holds the stand-in, the` |
| ByteTest.test_assignment | VM-CRASH | `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 \|     host_cls = _jac_standin_class(u.cls)  1051 \|     inst = host_cls.__new__(host_cls)  1052 \|     # Strong back-reference: while the host holds the stand-in, the` |
| ShortTest.test_assignment | VM-CRASH | `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 \|     host_cls = _jac_standin_class(u.cls)  1051 \|     inst = host_cls.__new__(host_cls)  1052 \|     # Strong back-reference: while the host holds the stand-in, the` |
| IntTest.test_assignment | VM-CRASH | `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 \|     host_cls = _jac_standin_class(u.cls)  1051 \|     inst = host_cls.__new__(host_cls)  1052 \|     # Strong back-reference: while the host holds the stand-in, the` |
| LongTest.test_assignment | VM-CRASH | `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 \|     host_cls = _jac_standin_class(u.cls)  1051 \|     inst = host_cls.__new__(host_cls)  1052 \|     # Strong back-reference: while the host holds the stand-in, the` |
| LongLongTest.test_assignment | VM-CRASH | `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 \|     host_cls = _jac_standin_class(u.cls)  1051 \|     inst = host_cls.__new__(host_cls)  1052 \|     # Strong back-reference: while the host holds the stand-in, the` |
| UnsignedByteTest.test_assignment | VM-CRASH | `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 \|     host_cls = _jac_standin_class(u.cls)  1051 \|     inst = host_cls.__new__(host_cls)  1052 \|     # Strong back-reference: while the host holds the stand-in, the` |
| UnsignedShortTest.test_assignment | VM-CRASH | `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 \|     host_cls = _jac_standin_class(u.cls)  1051 \|     inst = host_cls.__new__(host_cls)  1052 \|     # Strong back-reference: while the host holds the stand-in, the` |
| UnsignedIntTest.test_assignment | VM-CRASH | `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 \|     host_cls = _jac_standin_class(u.cls)  1051 \|     inst = host_cls.__new__(host_cls)  1052 \|     # Strong back-reference: while the host holds the stand-in, the` |
| UnsignedLongTest.test_assignment | VM-CRASH | `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 \|     host_cls = _jac_standin_class(u.cls)  1051 \|     inst = host_cls.__new__(host_cls)  1052 \|     # Strong back-reference: while the host holds the stand-in, the` |
| UnsignedLongLongTest.test_assignment | VM-CRASH | `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 \|     host_cls = _jac_standin_class(u.cls)  1051 \|     inst = host_cls.__new__(host_cls)  1052 \|     # Strong back-reference: while the host holds the stand-in, the` |
| FloatTest.test_assignment | VM-CRASH | `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 \|     host_cls = _jac_standin_class(u.cls)  1051 \|     inst = host_cls.__new__(host_cls)  1052 \|     # Strong back-reference: while the host holds the stand-in, the` |
| DoubleTest.test_assignment | VM-CRASH | `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 \|     host_cls = _jac_standin_class(u.cls)  1051 \|     inst = host_cls.__new__(host_cls)  1052 \|     # Strong back-reference: while the host holds the stand-in, the` |
| ByteTest.test_iterationcontains | VM-CRASH | `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 \|     host_cls = _jac_standin_class(u.cls)  1051 \|     inst = host_cls.__new__(host_cls)  1052 \|     # Strong back-reference: while the host holds the stand-in, the` |
| ShortTest.test_iterationcontains | VM-CRASH | `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 \|     host_cls = _jac_standin_class(u.cls)  1051 \|     inst = host_cls.__new__(host_cls)  1052 \|     # Strong back-reference: while the host holds the stand-in, the` |
| IntTest.test_iterationcontains | VM-CRASH | `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 \|     host_cls = _jac_standin_class(u.cls)  1051 \|     inst = host_cls.__new__(host_cls)  1052 \|     # Strong back-reference: while the host holds the stand-in, the` |
| LongTest.test_iterationcontains | VM-CRASH | `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 \|     host_cls = _jac_standin_class(u.cls)  1051 \|     inst = host_cls.__new__(host_cls)  1052 \|     # Strong back-reference: while the host holds the stand-in, the` |
| LongLongTest.test_iterationcontains | VM-CRASH | `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 \|     host_cls = _jac_standin_class(u.cls)  1051 \|     inst = host_cls.__new__(host_cls)  1052 \|     # Strong back-reference: while the host holds the stand-in, the` |
| UnsignedByteTest.test_iterationcontains | VM-CRASH | `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 \|     host_cls = _jac_standin_class(u.cls)  1051 \|     inst = host_cls.__new__(host_cls)  1052 \|     # Strong back-reference: while the host holds the stand-in, the` |
| UnsignedShortTest.test_iterationcontains | VM-CRASH | `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 \|     host_cls = _jac_standin_class(u.cls)  1051 \|     inst = host_cls.__new__(host_cls)  1052 \|     # Strong back-reference: while the host holds the stand-in, the` |
| UnsignedIntTest.test_iterationcontains | VM-CRASH | `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 \|     host_cls = _jac_standin_class(u.cls)  1051 \|     inst = host_cls.__new__(host_cls)  1052 \|     # Strong back-reference: while the host holds the stand-in, the` |
| UnsignedLongTest.test_iterationcontains | VM-CRASH | `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 \|     host_cls = _jac_standin_class(u.cls)  1051 \|     inst = host_cls.__new__(host_cls)  1052 \|     # Strong back-reference: while the host holds the stand-in, the` |
| UnsignedLongLongTest.test_iterationcontains | VM-CRASH | `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 \|     host_cls = _jac_standin_class(u.cls)  1051 \|     inst = host_cls.__new__(host_cls)  1052 \|     # Strong back-reference: while the host holds the stand-in, the` |
| FloatTest.test_iterationcontains | VM-CRASH | `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 \|     host_cls = _jac_standin_class(u.cls)  1051 \|     inst = host_cls.__new__(host_cls)  1052 \|     # Strong back-reference: while the host holds the stand-in, the` |
| DoubleTest.test_iterationcontains | VM-CRASH | `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 \|     host_cls = _jac_standin_class(u.cls)  1051 \|     inst = host_cls.__new__(host_cls)  1052 \|     # Strong back-reference: while the host holds the stand-in, the` |
| ByteTest.test_subclassing | VM-CRASH | `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 \|     host_cls = _jac_standin_class(u.cls)  1051 \|     inst = host_cls.__new__(host_cls)  1052 \|     # Strong back-reference: while the host holds the stand-in, the` |
| ByteTest.test_frombytearray | VM-CRASH | `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 \|     host_cls = _jac_standin_class(u.cls)  1051 \|     inst = host_cls.__new__(host_cls)  1052 \|     # Strong back-reference: while the host holds the stand-in, the` |
| ShortTest.test_frombytearray | VM-CRASH | `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 \|     host_cls = _jac_standin_class(u.cls)  1051 \|     inst = host_cls.__new__(host_cls)  1052 \|     # Strong back-reference: while the host holds the stand-in, the` |
| IntTest.test_frombytearray | VM-CRASH | `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 \|     host_cls = _jac_standin_class(u.cls)  1051 \|     inst = host_cls.__new__(host_cls)  1052 \|     # Strong back-reference: while the host holds the stand-in, the` |
| LongTest.test_frombytearray | VM-CRASH | `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 \|     host_cls = _jac_standin_class(u.cls)  1051 \|     inst = host_cls.__new__(host_cls)  1052 \|     # Strong back-reference: while the host holds the stand-in, the` |
| LongLongTest.test_frombytearray | VM-CRASH | `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 \|     host_cls = _jac_standin_class(u.cls)  1051 \|     inst = host_cls.__new__(host_cls)  1052 \|     # Strong back-reference: while the host holds the stand-in, the` |
| UnsignedByteTest.test_frombytearray | VM-CRASH | `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 \|     host_cls = _jac_standin_class(u.cls)  1051 \|     inst = host_cls.__new__(host_cls)  1052 \|     # Strong back-reference: while the host holds the stand-in, the` |
| UnsignedShortTest.test_frombytearray | VM-CRASH | `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 \|     host_cls = _jac_standin_class(u.cls)  1051 \|     inst = host_cls.__new__(host_cls)  1052 \|     # Strong back-reference: while the host holds the stand-in, the` |
| UnsignedIntTest.test_frombytearray | VM-CRASH | `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 \|     host_cls = _jac_standin_class(u.cls)  1051 \|     inst = host_cls.__new__(host_cls)  1052 \|     # Strong back-reference: while the host holds the stand-in, the` |
| UnsignedLongTest.test_frombytearray | VM-CRASH | `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 \|     host_cls = _jac_standin_class(u.cls)  1051 \|     inst = host_cls.__new__(host_cls)  1052 \|     # Strong back-reference: while the host holds the stand-in, the` |
| UnsignedLongLongTest.test_frombytearray | VM-CRASH | `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 \|     host_cls = _jac_standin_class(u.cls)  1051 \|     inst = host_cls.__new__(host_cls)  1052 \|     # Strong back-reference: while the host holds the stand-in, the` |
| FloatTest.test_frombytearray | VM-CRASH | `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 \|     host_cls = _jac_standin_class(u.cls)  1051 \|     inst = host_cls.__new__(host_cls)  1052 \|     # Strong back-reference: while the host holds the stand-in, the` |
| DoubleTest.test_frombytearray | VM-CRASH | `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 \|     host_cls = _jac_standin_class(u.cls)  1051 \|     inst = host_cls.__new__(host_cls)  1052 \|     # Strong back-reference: while the host holds the stand-in, the` |
| ByteTest.test_type_error | VM-CRASH | `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 \|     host_cls = _jac_standin_class(u.cls)  1051 \|     inst = host_cls.__new__(host_cls)  1052 \|     # Strong back-reference: while the host holds the stand-in, the` |
| ShortTest.test_type_error | VM-CRASH | `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 \|     host_cls = _jac_standin_class(u.cls)  1051 \|     inst = host_cls.__new__(host_cls)  1052 \|     # Strong back-reference: while the host holds the stand-in, the` |
| IntTest.test_type_error | VM-CRASH | `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 \|     host_cls = _jac_standin_class(u.cls)  1051 \|     inst = host_cls.__new__(host_cls)  1052 \|     # Strong back-reference: while the host holds the stand-in, the` |
| LongTest.test_type_error | VM-CRASH | `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 \|     host_cls = _jac_standin_class(u.cls)  1051 \|     inst = host_cls.__new__(host_cls)  1052 \|     # Strong back-reference: while the host holds the stand-in, the` |
| LongLongTest.test_type_error | VM-CRASH | `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 \|     host_cls = _jac_standin_class(u.cls)  1051 \|     inst = host_cls.__new__(host_cls)  1052 \|     # Strong back-reference: while the host holds the stand-in, the` |
| UnsignedByteTest.test_type_error | VM-CRASH | `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 \|     host_cls = _jac_standin_class(u.cls)  1051 \|     inst = host_cls.__new__(host_cls)  1052 \|     # Strong back-reference: while the host holds the stand-in, the` |
| UnsignedShortTest.test_type_error | VM-CRASH | `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 \|     host_cls = _jac_standin_class(u.cls)  1051 \|     inst = host_cls.__new__(host_cls)  1052 \|     # Strong back-reference: while the host holds the stand-in, the` |
| UnsignedIntTest.test_type_error | VM-CRASH | `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 \|     host_cls = _jac_standin_class(u.cls)  1051 \|     inst = host_cls.__new__(host_cls)  1052 \|     # Strong back-reference: while the host holds the stand-in, the` |
| UnsignedLongTest.test_type_error | VM-CRASH | `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 \|     host_cls = _jac_standin_class(u.cls)  1051 \|     inst = host_cls.__new__(host_cls)  1052 \|     # Strong back-reference: while the host holds the stand-in, the` |
| UnsignedLongLongTest.test_type_error | VM-CRASH | `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 \|     host_cls = _jac_standin_class(u.cls)  1051 \|     inst = host_cls.__new__(host_cls)  1052 \|     # Strong back-reference: while the host holds the stand-in, the` |
| UnsignedByteTest.test_bytes_extend | VM-CRASH | `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 \|     host_cls = _jac_standin_class(u.cls)  1051 \|     inst = host_cls.__new__(host_cls)  1052 \|     # Strong back-reference: while the host holds the stand-in, the` |
| UnsignedShortTest.test_bytes_extend | VM-CRASH | `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 \|     host_cls = _jac_standin_class(u.cls)  1051 \|     inst = host_cls.__new__(host_cls)  1052 \|     # Strong back-reference: while the host holds the stand-in, the` |
| UnsignedIntTest.test_bytes_extend | VM-CRASH | `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 \|     host_cls = _jac_standin_class(u.cls)  1051 \|     inst = host_cls.__new__(host_cls)  1052 \|     # Strong back-reference: while the host holds the stand-in, the` |
| UnsignedLongTest.test_bytes_extend | VM-CRASH | `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 \|     host_cls = _jac_standin_class(u.cls)  1051 \|     inst = host_cls.__new__(host_cls)  1052 \|     # Strong back-reference: while the host holds the stand-in, the` |
| UnsignedLongLongTest.test_bytes_extend | VM-CRASH | `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 \|     host_cls = _jac_standin_class(u.cls)  1051 \|     inst = host_cls.__new__(host_cls)  1052 \|     # Strong back-reference: while the host holds the stand-in, the` |
| FloatTest.test_nan | VM-CRASH | `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 \|     host_cls = _jac_standin_class(u.cls)  1051 \|     inst = host_cls.__new__(host_cls)  1052 \|     # Strong back-reference: while the host holds the stand-in, the` |
| DoubleTest.test_nan | VM-CRASH | `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 \|     host_cls = _jac_standin_class(u.cls)  1051 \|     inst = host_cls.__new__(host_cls)  1052 \|     # Strong back-reference: while the host holds the stand-in, the` |
| FloatTest.test_byteswap | PASS | |
| DoubleTest.test_byteswap | PASS | |
| DoubleTest.test_alloc_overflow | VM-CRASH | `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 \|     host_cls = _jac_standin_class(u.cls)  1051 \|     inst = host_cls.__new__(host_cls)  1052 \|     # Strong back-reference: while the host holds the stand-in, the` |
| LargeArrayTest.test_gh_128961 | VM-CRASH | `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 \|     host_cls = _jac_standin_class(u.cls)  1051 \|     inst = host_cls.__new__(host_cls)  1052 \|     # Strong back-reference: while the host holds the stand-in, the` |
| LargeArrayTest.test_setitem_use_after_shrink_with_int_data | VM-CRASH | `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 \|     host_cls = _jac_standin_class(u.cls)  1051 \|     inst = host_cls.__new__(host_cls)  1052 \|     # Strong back-reference: while the host holds the stand-in, the` |

## Quarantined at conversion

| test | reason |
|---|---|
| MiscTest.test_disallow_instantiation | decorator:support.cpython_only |
| MiscTest.test_immutable | decorator:support.cpython_only |
| BaseTest.test_bug_782369 | decorator:unittest.skipUnless |
| BaseTest.test_sizeof_with_buffer | decorator:support.cpython_only |
| BaseTest.test_sizeof_without_buffer | decorator:support.cpython_only |
| BaseTest.test_obsolete_write_lock | decorator:support.cpython_only |
| LargeArrayTest.test_example_data | decorator:support.bigmemtest |
| LargeArrayTest.test_access | decorator:support.bigmemtest |
| LargeArrayTest.test_slice | decorator:support.bigmemtest |
| LargeArrayTest.test_count | decorator:support.bigmemtest |
| LargeArrayTest.test_append | decorator:support.bigmemtest |
| LargeArrayTest.test_extend | decorator:support.bigmemtest |
| LargeArrayTest.test_frombytes | decorator:support.bigmemtest |
| LargeArrayTest.test_fromlist | decorator:support.bigmemtest |
| LargeArrayTest.test_index | decorator:support.bigmemtest |
| LargeArrayTest.test_insert | decorator:support.bigmemtest |
| LargeArrayTest.test_pop | decorator:support.bigmemtest |
| LargeArrayTest.test_remove | decorator:support.bigmemtest |
| LargeArrayTest.test_reverse | decorator:support.bigmemtest |
| LargeArrayTest.test_tolist | decorator:support.bigmemtest |
| UCS4Test.test_constructor | unresolved-name:sizeof_wchar |
| UCS4Test.test_len | unresolved-name:sizeof_wchar |
| UCS4Test.test_buffer_info | unresolved-name:sizeof_wchar |
| UCS4Test.test_byteswap | unresolved-name:sizeof_wchar |
| UCS4Test.test_copy | unresolved-name:sizeof_wchar |
| UCS4Test.test_deepcopy | unresolved-name:sizeof_wchar |
| UCS4Test.test_reduce_ex | unresolved-name:sizeof_wchar |
| UCS4Test.test_pickle | unresolved-name:sizeof_wchar |
| UCS4Test.test_pickle_for_empty_array | unresolved-name:sizeof_wchar |
| UCS4Test.test_iterator_pickle | unresolved-name:sizeof_wchar |
| UCS4Test.test_exhausted_iterator | unresolved-name:sizeof_wchar |
| UCS4Test.test_reverse_iterator | unresolved-name:sizeof_wchar |
| UCS4Test.test_reverse_iterator_picking | unresolved-name:sizeof_wchar |
| UCS4Test.test_exhausted_reverse_iterator | unresolved-name:sizeof_wchar |
| UCS4Test.test_insert | unresolved-name:sizeof_wchar |
| UCS4Test.test_tofromfile | unresolved-name:sizeof_wchar |
| UCS4Test.test_fromfile_ioerror | unresolved-name:sizeof_wchar |
| UCS4Test.test_filewrite | unresolved-name:sizeof_wchar |
| UCS4Test.test_tofromlist | unresolved-name:sizeof_wchar |
| UCS4Test.test_tofrombytes | unresolved-name:sizeof_wchar |
| UCS4Test.test_fromarray | unresolved-name:sizeof_wchar |
| UCS4Test.test_repr | unresolved-name:sizeof_wchar |
| UCS4Test.test_str | unresolved-name:sizeof_wchar |
| UCS4Test.test_cmp | unresolved-name:sizeof_wchar |
| UCS4Test.test_add | unresolved-name:sizeof_wchar |
| ByteTest.test_add | unresolved-name:badtypecode |
| ShortTest.test_add | unresolved-name:badtypecode |
| IntTest.test_add | unresolved-name:badtypecode |
| LongTest.test_add | unresolved-name:badtypecode |
| LongLongTest.test_add | unresolved-name:badtypecode |
| UnsignedByteTest.test_add | unresolved-name:badtypecode |
| UnsignedShortTest.test_add | unresolved-name:badtypecode |
| UnsignedIntTest.test_add | unresolved-name:badtypecode |
| UnsignedLongTest.test_add | unresolved-name:badtypecode |
| UnsignedLongLongTest.test_add | unresolved-name:badtypecode |
| FloatTest.test_add | unresolved-name:badtypecode |
| DoubleTest.test_add | unresolved-name:badtypecode |
| UCS4Test.test_iadd | unresolved-name:sizeof_wchar |
| ByteTest.test_iadd | unresolved-name:badtypecode |
| ShortTest.test_iadd | unresolved-name:badtypecode |
| IntTest.test_iadd | unresolved-name:badtypecode |
| LongTest.test_iadd | unresolved-name:badtypecode |
| LongLongTest.test_iadd | unresolved-name:badtypecode |
| UnsignedByteTest.test_iadd | unresolved-name:badtypecode |
| UnsignedShortTest.test_iadd | unresolved-name:badtypecode |
| UnsignedIntTest.test_iadd | unresolved-name:badtypecode |
| UnsignedLongTest.test_iadd | unresolved-name:badtypecode |
| UnsignedLongLongTest.test_iadd | unresolved-name:badtypecode |
| FloatTest.test_iadd | unresolved-name:badtypecode |
| DoubleTest.test_iadd | unresolved-name:badtypecode |
| UCS4Test.test_mul | unresolved-name:sizeof_wchar |
| UCS4Test.test_imul | unresolved-name:sizeof_wchar |
| UCS4Test.test_getitem | unresolved-name:sizeof_wchar |
| ByteTest.test_getitem | unresolved-name:assertEntryEqual |
| ShortTest.test_getitem | unresolved-name:assertEntryEqual |
| IntTest.test_getitem | unresolved-name:assertEntryEqual |
| LongTest.test_getitem | unresolved-name:assertEntryEqual |
| LongLongTest.test_getitem | unresolved-name:assertEntryEqual |
| UnsignedByteTest.test_getitem | unresolved-name:assertEntryEqual |
| UnsignedShortTest.test_getitem | unresolved-name:assertEntryEqual |
| UnsignedIntTest.test_getitem | unresolved-name:assertEntryEqual |
| UnsignedLongTest.test_getitem | unresolved-name:assertEntryEqual |
| UnsignedLongLongTest.test_getitem | unresolved-name:assertEntryEqual |
| FloatTest.test_getitem | unresolved-name:assertEntryEqual |
| DoubleTest.test_getitem | unresolved-name:assertEntryEqual |
| UCS4Test.test_setitem | unresolved-name:sizeof_wchar |
| ByteTest.test_setitem | unresolved-name:assertEntryEqual |
| ShortTest.test_setitem | unresolved-name:assertEntryEqual |
| IntTest.test_setitem | unresolved-name:assertEntryEqual |
| LongTest.test_setitem | unresolved-name:assertEntryEqual |
| LongLongTest.test_setitem | unresolved-name:assertEntryEqual |
| UnsignedByteTest.test_setitem | unresolved-name:assertEntryEqual |
| UnsignedShortTest.test_setitem | unresolved-name:assertEntryEqual |
| UnsignedIntTest.test_setitem | unresolved-name:assertEntryEqual |
| UnsignedLongTest.test_setitem | unresolved-name:assertEntryEqual |
| UnsignedLongLongTest.test_setitem | unresolved-name:assertEntryEqual |
| FloatTest.test_setitem | unresolved-name:assertEntryEqual |
| DoubleTest.test_setitem | unresolved-name:assertEntryEqual |
| UCS4Test.test_delitem | unresolved-name:sizeof_wchar |
| UCS4Test.test_getslice | unresolved-name:sizeof_wchar |
| UCS4Test.test_extended_getslice | unresolved-name:sizeof_wchar |
| UCS4Test.test_setslice | unresolved-name:sizeof_wchar |
| ByteTest.test_setslice | unresolved-name:badtypecode |
| ShortTest.test_setslice | unresolved-name:badtypecode |
| IntTest.test_setslice | unresolved-name:badtypecode |
| LongTest.test_setslice | unresolved-name:badtypecode |
| LongLongTest.test_setslice | unresolved-name:badtypecode |
| UnsignedByteTest.test_setslice | unresolved-name:badtypecode |
| UnsignedShortTest.test_setslice | unresolved-name:badtypecode |
| UnsignedIntTest.test_setslice | unresolved-name:badtypecode |
| UnsignedLongTest.test_setslice | unresolved-name:badtypecode |
| UnsignedLongLongTest.test_setslice | unresolved-name:badtypecode |
| FloatTest.test_setslice | unresolved-name:badtypecode |
| DoubleTest.test_setslice | unresolved-name:badtypecode |
| UCS4Test.test_extended_set_del_slice | unresolved-name:sizeof_wchar |
| UCS4Test.test_index | unresolved-name:sizeof_wchar |
| UCS4Test.test_count | unresolved-name:sizeof_wchar |
| UCS4Test.test_remove | unresolved-name:sizeof_wchar |
| UCS4Test.test_pop | unresolved-name:sizeof_wchar |
| ByteTest.test_pop | unresolved-name:assertEntryEqual |
| ShortTest.test_pop | unresolved-name:assertEntryEqual |
| IntTest.test_pop | unresolved-name:assertEntryEqual |
| LongTest.test_pop | unresolved-name:assertEntryEqual |
| LongLongTest.test_pop | unresolved-name:assertEntryEqual |
| UnsignedByteTest.test_pop | unresolved-name:assertEntryEqual |
| UnsignedShortTest.test_pop | unresolved-name:assertEntryEqual |
| UnsignedIntTest.test_pop | unresolved-name:assertEntryEqual |
| UnsignedLongTest.test_pop | unresolved-name:assertEntryEqual |
| UnsignedLongLongTest.test_pop | unresolved-name:assertEntryEqual |
| FloatTest.test_pop | unresolved-name:assertEntryEqual |
| DoubleTest.test_pop | unresolved-name:assertEntryEqual |
| UCS4Test.test_clear | unresolved-name:sizeof_wchar |
| UCS4Test.test_reverse | unresolved-name:sizeof_wchar |
| UCS4Test.test_extend | unresolved-name:sizeof_wchar |
| ByteTest.test_extend | unresolved-name:badtypecode |
| ShortTest.test_extend | unresolved-name:badtypecode |
| IntTest.test_extend | unresolved-name:badtypecode |
| LongTest.test_extend | unresolved-name:badtypecode |
| LongLongTest.test_extend | unresolved-name:badtypecode |
| UnsignedByteTest.test_extend | unresolved-name:badtypecode |
| UnsignedShortTest.test_extend | unresolved-name:badtypecode |
| UnsignedIntTest.test_extend | unresolved-name:badtypecode |
| UnsignedLongTest.test_extend | unresolved-name:badtypecode |
| UnsignedLongLongTest.test_extend | unresolved-name:badtypecode |
| FloatTest.test_extend | unresolved-name:badtypecode |
| DoubleTest.test_extend | unresolved-name:badtypecode |
| UCS4Test.test_constructor_with_iterable_argument | unresolved-name:sizeof_wchar |
| UCS4Test.test_coveritertraverse | self.skipTest |
| ByteTest.test_coveritertraverse | self.skipTest |
| ShortTest.test_coveritertraverse | self.skipTest |
| IntTest.test_coveritertraverse | self.skipTest |
| LongTest.test_coveritertraverse | self.skipTest |
| LongLongTest.test_coveritertraverse | self.skipTest |
| UnsignedByteTest.test_coveritertraverse | self.skipTest |
| UnsignedShortTest.test_coveritertraverse | self.skipTest |
| UnsignedIntTest.test_coveritertraverse | self.skipTest |
| UnsignedLongTest.test_coveritertraverse | self.skipTest |
| UnsignedLongLongTest.test_coveritertraverse | self.skipTest |
| FloatTest.test_coveritertraverse | self.skipTest |
| DoubleTest.test_coveritertraverse | self.skipTest |
| UCS4Test.test_buffer | unresolved-name:sizeof_wchar |
| UCS4Test.test_weakref | unresolved-name:sizeof_wchar |
| UCS4Test.test_initialize_with_unicode | unresolved-name:cm |
| ByteTest.test_initialize_with_unicode | unresolved-name:cm |
| ShortTest.test_initialize_with_unicode | unresolved-name:cm |
| IntTest.test_initialize_with_unicode | unresolved-name:cm |
| LongTest.test_initialize_with_unicode | unresolved-name:cm |
| LongLongTest.test_initialize_with_unicode | unresolved-name:cm |
| UnsignedByteTest.test_initialize_with_unicode | unresolved-name:cm |
| UnsignedShortTest.test_initialize_with_unicode | unresolved-name:cm |
| UnsignedIntTest.test_initialize_with_unicode | unresolved-name:cm |
| UnsignedLongTest.test_initialize_with_unicode | unresolved-name:cm |
| UnsignedLongLongTest.test_initialize_with_unicode | unresolved-name:cm |
| FloatTest.test_initialize_with_unicode | unresolved-name:cm |
| DoubleTest.test_initialize_with_unicode | unresolved-name:cm |
| UCS4Test.test_free_after_iterating | unresolved-name:sizeof_wchar |
| UCS4Test.test_setitem | unresolved-name:sizeof_wchar |
| UCS4Test.test_unicode | unresolved-name:sizeof_wchar |
| UCS4Test.test_issue17223 | self.skipTest |
| UCS4Test.test_typecode_u_deprecation | uses-self.assertWarns |
| ShortTest.test_subclassing | unresolved-name:assertEntryEqual |
| IntTest.test_subclassing | unresolved-name:assertEntryEqual |
| LongTest.test_subclassing | unresolved-name:assertEntryEqual |
| LongLongTest.test_subclassing | unresolved-name:assertEntryEqual |
| UnsignedByteTest.test_subclassing | unresolved-name:assertEntryEqual |
| UnsignedShortTest.test_subclassing | unresolved-name:assertEntryEqual |
| UnsignedIntTest.test_subclassing | unresolved-name:assertEntryEqual |
| UnsignedLongTest.test_subclassing | unresolved-name:assertEntryEqual |
| UnsignedLongLongTest.test_subclassing | unresolved-name:assertEntryEqual |
| FloatTest.test_subclassing | unresolved-name:assertEntryEqual |
| DoubleTest.test_subclassing | unresolved-name:assertEntryEqual |
| ShortTest.test_overflow | unresolved-name:check_overflow |
| IntTest.test_overflow | unresolved-name:check_overflow |
| LongTest.test_overflow | unresolved-name:check_overflow |
| LongLongTest.test_overflow | unresolved-name:check_overflow |
| UnsignedShortTest.test_overflow | unresolved-name:check_overflow |
| UnsignedIntTest.test_overflow | unresolved-name:check_overflow |
| UnsignedLongTest.test_overflow | unresolved-name:check_overflow |
| UnsignedLongLongTest.test_overflow | unresolved-name:check_overflow |
| LargeArrayTest.test_setitem_use_after_clear_with_int_data | unresolved-name:dtype |
| LargeArrayTest.test_setitem_use_after_clear_with_float_data | unresolved-name:dtype |
| ArrayReconstructorTest.test_unicode | host-raised:TypeError: cannot use a str to initialize an array with typecode 'w' |
| ByteTest.test_tofromfile | harness-error:ModuleNotFoundError: No module named 'test' |
| ShortTest.test_tofromfile | harness-error:ModuleNotFoundError: No module named 'test' |
| IntTest.test_tofromfile | harness-error:ModuleNotFoundError: No module named 'test' |
| LongTest.test_tofromfile | harness-error:ModuleNotFoundError: No module named 'test' |
| LongLongTest.test_tofromfile | harness-error:ModuleNotFoundError: No module named 'test' |
| UnsignedByteTest.test_tofromfile | harness-error:ModuleNotFoundError: No module named 'test' |
| UnsignedShortTest.test_tofromfile | harness-error:ModuleNotFoundError: No module named 'test' |
| UnsignedIntTest.test_tofromfile | harness-error:ModuleNotFoundError: No module named 'test' |
| UnsignedLongTest.test_tofromfile | harness-error:ModuleNotFoundError: No module named 'test' |
| UnsignedLongLongTest.test_tofromfile | harness-error:ModuleNotFoundError: No module named 'test' |
| FloatTest.test_tofromfile | harness-error:ModuleNotFoundError: No module named 'test' |
| DoubleTest.test_tofromfile | harness-error:ModuleNotFoundError: No module named 'test' |
| ByteTest.test_fromfile_ioerror | harness-error:ModuleNotFoundError: No module named 'test' |
| ShortTest.test_fromfile_ioerror | harness-error:ModuleNotFoundError: No module named 'test' |
| IntTest.test_fromfile_ioerror | harness-error:ModuleNotFoundError: No module named 'test' |
| LongTest.test_fromfile_ioerror | harness-error:ModuleNotFoundError: No module named 'test' |
| LongLongTest.test_fromfile_ioerror | harness-error:ModuleNotFoundError: No module named 'test' |
| UnsignedByteTest.test_fromfile_ioerror | harness-error:ModuleNotFoundError: No module named 'test' |
| UnsignedShortTest.test_fromfile_ioerror | harness-error:ModuleNotFoundError: No module named 'test' |
| UnsignedIntTest.test_fromfile_ioerror | harness-error:ModuleNotFoundError: No module named 'test' |
| UnsignedLongTest.test_fromfile_ioerror | harness-error:ModuleNotFoundError: No module named 'test' |
| UnsignedLongLongTest.test_fromfile_ioerror | harness-error:ModuleNotFoundError: No module named 'test' |
| FloatTest.test_fromfile_ioerror | harness-error:ModuleNotFoundError: No module named 'test' |
| DoubleTest.test_fromfile_ioerror | harness-error:ModuleNotFoundError: No module named 'test' |
| ByteTest.test_filewrite | harness-error:ModuleNotFoundError: No module named 'test' |
| ShortTest.test_filewrite | harness-error:ModuleNotFoundError: No module named 'test' |
| IntTest.test_filewrite | harness-error:ModuleNotFoundError: No module named 'test' |
| LongTest.test_filewrite | harness-error:ModuleNotFoundError: No module named 'test' |
| LongLongTest.test_filewrite | harness-error:ModuleNotFoundError: No module named 'test' |
| UnsignedByteTest.test_filewrite | harness-error:ModuleNotFoundError: No module named 'test' |
| UnsignedShortTest.test_filewrite | harness-error:ModuleNotFoundError: No module named 'test' |
| UnsignedIntTest.test_filewrite | harness-error:ModuleNotFoundError: No module named 'test' |
| UnsignedLongTest.test_filewrite | harness-error:ModuleNotFoundError: No module named 'test' |
| UnsignedLongLongTest.test_filewrite | harness-error:ModuleNotFoundError: No module named 'test' |
| FloatTest.test_filewrite | harness-error:ModuleNotFoundError: No module named 'test' |
| DoubleTest.test_filewrite | harness-error:ModuleNotFoundError: No module named 'test' |
| ByteTest.test_clear | host-raised:AttributeError: 'array.array' object has no attribute 'clear' |
| ShortTest.test_clear | host-raised:AttributeError: 'array.array' object has no attribute 'clear' |
| IntTest.test_clear | host-raised:AttributeError: 'array.array' object has no attribute 'clear' |
| LongTest.test_clear | host-raised:AttributeError: 'array.array' object has no attribute 'clear' |
| LongLongTest.test_clear | host-raised:AttributeError: 'array.array' object has no attribute 'clear' |
| UnsignedByteTest.test_clear | host-raised:AttributeError: 'array.array' object has no attribute 'clear' |
| UnsignedShortTest.test_clear | host-raised:AttributeError: 'array.array' object has no attribute 'clear' |
| UnsignedIntTest.test_clear | host-raised:AttributeError: 'array.array' object has no attribute 'clear' |
| UnsignedLongTest.test_clear | host-raised:AttributeError: 'array.array' object has no attribute 'clear' |
| UnsignedLongLongTest.test_clear | host-raised:AttributeError: 'array.array' object has no attribute 'clear' |
| FloatTest.test_clear | host-raised:AttributeError: 'array.array' object has no attribute 'clear' |
| DoubleTest.test_clear | host-raised:AttributeError: 'array.array' object has no attribute 'clear' |
| ByteTest.test_weakref | harness-error:ModuleNotFoundError: No module named 'test' |
| ShortTest.test_weakref | harness-error:ModuleNotFoundError: No module named 'test' |
| IntTest.test_weakref | harness-error:ModuleNotFoundError: No module named 'test' |
| LongTest.test_weakref | harness-error:ModuleNotFoundError: No module named 'test' |
| LongLongTest.test_weakref | harness-error:ModuleNotFoundError: No module named 'test' |
| UnsignedByteTest.test_weakref | harness-error:ModuleNotFoundError: No module named 'test' |
| UnsignedShortTest.test_weakref | harness-error:ModuleNotFoundError: No module named 'test' |
| UnsignedIntTest.test_weakref | harness-error:ModuleNotFoundError: No module named 'test' |
| UnsignedLongTest.test_weakref | harness-error:ModuleNotFoundError: No module named 'test' |
| UnsignedLongLongTest.test_weakref | harness-error:ModuleNotFoundError: No module named 'test' |
| FloatTest.test_weakref | harness-error:ModuleNotFoundError: No module named 'test' |
| DoubleTest.test_weakref | harness-error:ModuleNotFoundError: No module named 'test' |
| ByteTest.test_free_after_iterating | harness-error:ModuleNotFoundError: No module named 'test' |
| ShortTest.test_free_after_iterating | harness-error:ModuleNotFoundError: No module named 'test' |
| IntTest.test_free_after_iterating | harness-error:ModuleNotFoundError: No module named 'test' |
| LongTest.test_free_after_iterating | harness-error:ModuleNotFoundError: No module named 'test' |
| LongLongTest.test_free_after_iterating | harness-error:ModuleNotFoundError: No module named 'test' |
| UnsignedByteTest.test_free_after_iterating | harness-error:ModuleNotFoundError: No module named 'test' |
| UnsignedShortTest.test_free_after_iterating | harness-error:ModuleNotFoundError: No module named 'test' |
| UnsignedIntTest.test_free_after_iterating | harness-error:ModuleNotFoundError: No module named 'test' |
| UnsignedLongTest.test_free_after_iterating | harness-error:ModuleNotFoundError: No module named 'test' |
| UnsignedLongLongTest.test_free_after_iterating | harness-error:ModuleNotFoundError: No module named 'test' |
| FloatTest.test_free_after_iterating | harness-error:ModuleNotFoundError: No module named 'test' |
| DoubleTest.test_free_after_iterating | harness-error:ModuleNotFoundError: No module named 'test' |
| ByteTest.test_overflow | host-raised:NameError: name 'self' is not defined |
| UnsignedByteTest.test_overflow | host-raised:NameError: name 'self' is not defined |

## Expected vs got

### ByteTest.test_assignment (VM-CRASH)

- expected: host oracle = `ok`
- got: `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 |     host_cls = _jac_standin_class(u.cls)  1051 |     inst = host_cls.__new__(host_cls)  1052 |     # Strong back-reference: while the host holds the stand-in, the`

### ByteTest.test_buffer (VM-CRASH)

- expected: host oracle = `ok`
- got: `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 |     host_cls = _jac_standin_class(u.cls)  1051 |     inst = host_cls.__new__(host_cls)  1052 |     # Strong back-reference: while the host holds the stand-in, the`

### ByteTest.test_cmp (VM-CRASH)

- expected: host oracle = `ok`
- got: `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 |     host_cls = _jac_standin_class(u.cls)  1051 |     inst = host_cls.__new__(host_cls)  1052 |     # Strong back-reference: while the host holds the stand-in, the`

### ByteTest.test_constructor_with_iterable_argument (VM-CRASH)

- expected: host oracle = `ok`
- got: `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 |     host_cls = _jac_standin_class(u.cls)  1051 |     inst = host_cls.__new__(host_cls)  1052 |     # Strong back-reference: while the host holds the stand-in, the`

### ByteTest.test_count (VM-CRASH)

- expected: host oracle = `ok`
- got: `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 |     host_cls = _jac_standin_class(u.cls)  1051 |     inst = host_cls.__new__(host_cls)  1052 |     # Strong back-reference: while the host holds the stand-in, the`

### ByteTest.test_create_from_bytes (VM-CRASH)

- expected: host oracle = `ok`
- got: `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 |     host_cls = _jac_standin_class(u.cls)  1051 |     inst = host_cls.__new__(host_cls)  1052 |     # Strong back-reference: while the host holds the stand-in, the`

### ByteTest.test_delitem (VM-CRASH)

- expected: host oracle = `ok`
- got: `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 |     host_cls = _jac_standin_class(u.cls)  1051 |     inst = host_cls.__new__(host_cls)  1052 |     # Strong back-reference: while the host holds the stand-in, the`

### ByteTest.test_delslice (VM-CRASH)

- expected: host oracle = `ok`
- got: `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 |     host_cls = _jac_standin_class(u.cls)  1051 |     inst = host_cls.__new__(host_cls)  1052 |     # Strong back-reference: while the host holds the stand-in, the`

### ByteTest.test_exhausted_iterator (VM-CRASH)

- expected: host oracle = `ok`
- got: `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 |     host_cls = _jac_standin_class(u.cls)  1051 |     inst = host_cls.__new__(host_cls)  1052 |     # Strong back-reference: while the host holds the stand-in, the`

### ByteTest.test_exhausted_reverse_iterator (VM-CRASH)

- expected: host oracle = `ok`
- got: `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 |     host_cls = _jac_standin_class(u.cls)  1051 |     inst = host_cls.__new__(host_cls)  1052 |     # Strong back-reference: while the host holds the stand-in, the`

### ByteTest.test_extended_getslice (VM-CRASH)

- expected: host oracle = `ok`
- got: `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 |     host_cls = _jac_standin_class(u.cls)  1051 |     inst = host_cls.__new__(host_cls)  1052 |     # Strong back-reference: while the host holds the stand-in, the`

### ByteTest.test_extended_set_del_slice (VM-CRASH)

- expected: host oracle = `ok`
- got: `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 |     host_cls = _jac_standin_class(u.cls)  1051 |     inst = host_cls.__new__(host_cls)  1052 |     # Strong back-reference: while the host holds the stand-in, the`

### ByteTest.test_extslice (VM-CRASH)

- expected: host oracle = `ok`
- got: `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 |     host_cls = _jac_standin_class(u.cls)  1051 |     inst = host_cls.__new__(host_cls)  1052 |     # Strong back-reference: while the host holds the stand-in, the`

### ByteTest.test_fromarray (VM-CRASH)

- expected: host oracle = `ok`
- got: `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 |     host_cls = _jac_standin_class(u.cls)  1051 |     inst = host_cls.__new__(host_cls)  1052 |     # Strong back-reference: while the host holds the stand-in, the`

### ByteTest.test_frombytearray (VM-CRASH)

- expected: host oracle = `ok`
- got: `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 |     host_cls = _jac_standin_class(u.cls)  1051 |     inst = host_cls.__new__(host_cls)  1052 |     # Strong back-reference: while the host holds the stand-in, the`

### ByteTest.test_getslice (VM-CRASH)

- expected: host oracle = `ok`
- got: `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 |     host_cls = _jac_standin_class(u.cls)  1051 |     inst = host_cls.__new__(host_cls)  1052 |     # Strong back-reference: while the host holds the stand-in, the`

### ByteTest.test_imul (VM-CRASH)

- expected: host oracle = `ok`
- got: `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 |     host_cls = _jac_standin_class(u.cls)  1051 |     inst = host_cls.__new__(host_cls)  1052 |     # Strong back-reference: while the host holds the stand-in, the`

### ByteTest.test_index (VM-CRASH)

- expected: host oracle = `ok`
- got: `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 |     host_cls = _jac_standin_class(u.cls)  1051 |     inst = host_cls.__new__(host_cls)  1052 |     # Strong back-reference: while the host holds the stand-in, the`

### ByteTest.test_insert (VM-CRASH)

- expected: host oracle = `ok`
- got: `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 |     host_cls = _jac_standin_class(u.cls)  1051 |     inst = host_cls.__new__(host_cls)  1052 |     # Strong back-reference: while the host holds the stand-in, the`

### ByteTest.test_iterationcontains (VM-CRASH)

- expected: host oracle = `ok`
- got: `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 |     host_cls = _jac_standin_class(u.cls)  1051 |     inst = host_cls.__new__(host_cls)  1052 |     # Strong back-reference: while the host holds the stand-in, the`

### ByteTest.test_iterator_pickle (VM-CRASH)

- expected: host oracle = `ok`
- got: `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 |     host_cls = _jac_standin_class(u.cls)  1051 |     inst = host_cls.__new__(host_cls)  1052 |     # Strong back-reference: while the host holds the stand-in, the`

### ByteTest.test_mul (VM-CRASH)

- expected: host oracle = `ok`
- got: `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 |     host_cls = _jac_standin_class(u.cls)  1051 |     inst = host_cls.__new__(host_cls)  1052 |     # Strong back-reference: while the host holds the stand-in, the`

### ByteTest.test_pickle (VM-CRASH)

- expected: host oracle = `ok`
- got: no MARK captured

### ByteTest.test_pickle_for_empty_array (VM-CRASH)

- expected: host oracle = `ok`
- got: `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 |     host_cls = _jac_standin_class(u.cls)  1051 |     inst = host_cls.__new__(host_cls)  1052 |     # Strong back-reference: while the host holds the stand-in, the`

### ByteTest.test_remove (VM-CRASH)

- expected: host oracle = `ok`
- got: `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 |     host_cls = _jac_standin_class(u.cls)  1051 |     inst = host_cls.__new__(host_cls)  1052 |     # Strong back-reference: while the host holds the stand-in, the`

### ByteTest.test_repr (VM-CRASH)

- expected: host oracle = `ok`
- got: `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 |     host_cls = _jac_standin_class(u.cls)  1051 |     inst = host_cls.__new__(host_cls)  1052 |     # Strong back-reference: while the host holds the stand-in, the`

### ByteTest.test_reverse (VM-CRASH)

- expected: host oracle = `ok`
- got: `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 |     host_cls = _jac_standin_class(u.cls)  1051 |     inst = host_cls.__new__(host_cls)  1052 |     # Strong back-reference: while the host holds the stand-in, the`

### ByteTest.test_reverse_iterator (VM-CRASH)

- expected: host oracle = `ok`
- got: `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 |     host_cls = _jac_standin_class(u.cls)  1051 |     inst = host_cls.__new__(host_cls)  1052 |     # Strong back-reference: while the host holds the stand-in, the`

### ByteTest.test_reverse_iterator_picking (VM-CRASH)

- expected: host oracle = `ok`
- got: `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 |     host_cls = _jac_standin_class(u.cls)  1051 |     inst = host_cls.__new__(host_cls)  1052 |     # Strong back-reference: while the host holds the stand-in, the`

### ByteTest.test_str (VM-CRASH)

- expected: host oracle = `ok`
- got: `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 |     host_cls = _jac_standin_class(u.cls)  1051 |     inst = host_cls.__new__(host_cls)  1052 |     # Strong back-reference: while the host holds the stand-in, the`

### ByteTest.test_subclass_with_kwargs (VM-CRASH)

- expected: host oracle = `ok`
- got: `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 |     host_cls = _jac_standin_class(u.cls)  1051 |     inst = host_cls.__new__(host_cls)  1052 |     # Strong back-reference: while the host holds the stand-in, the`

### ByteTest.test_subclassing (VM-CRASH)

- expected: host oracle = `ok`
- got: `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 |     host_cls = _jac_standin_class(u.cls)  1051 |     inst = host_cls.__new__(host_cls)  1052 |     # Strong back-reference: while the host holds the stand-in, the`

### ByteTest.test_tofrombytes (VM-CRASH)

- expected: host oracle = `ok`
- got: `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 |     host_cls = _jac_standin_class(u.cls)  1051 |     inst = host_cls.__new__(host_cls)  1052 |     # Strong back-reference: while the host holds the stand-in, the`

### ByteTest.test_tofromlist (VM-CRASH)

- expected: host oracle = `ok`
- got: `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 |     host_cls = _jac_standin_class(u.cls)  1051 |     inst = host_cls.__new__(host_cls)  1052 |     # Strong back-reference: while the host holds the stand-in, the`

### ByteTest.test_type_error (VM-CRASH)

- expected: host oracle = `ok`
- got: `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 |     host_cls = _jac_standin_class(u.cls)  1051 |     inst = host_cls.__new__(host_cls)  1052 |     # Strong back-reference: while the host holds the stand-in, the`

### DoubleTest.test_alloc_overflow (VM-CRASH)

- expected: host oracle = `ok`
- got: `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 |     host_cls = _jac_standin_class(u.cls)  1051 |     inst = host_cls.__new__(host_cls)  1052 |     # Strong back-reference: while the host holds the stand-in, the`

### DoubleTest.test_assignment (VM-CRASH)

- expected: host oracle = `ok`
- got: `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 |     host_cls = _jac_standin_class(u.cls)  1051 |     inst = host_cls.__new__(host_cls)  1052 |     # Strong back-reference: while the host holds the stand-in, the`

### DoubleTest.test_buffer (VM-CRASH)

- expected: host oracle = `ok`
- got: `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 |     host_cls = _jac_standin_class(u.cls)  1051 |     inst = host_cls.__new__(host_cls)  1052 |     # Strong back-reference: while the host holds the stand-in, the`

### DoubleTest.test_cmp (VM-CRASH)

- expected: host oracle = `ok`
- got: `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 |     host_cls = _jac_standin_class(u.cls)  1051 |     inst = host_cls.__new__(host_cls)  1052 |     # Strong back-reference: while the host holds the stand-in, the`

### DoubleTest.test_constructor_with_iterable_argument (VM-CRASH)

- expected: host oracle = `ok`
- got: `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 |     host_cls = _jac_standin_class(u.cls)  1051 |     inst = host_cls.__new__(host_cls)  1052 |     # Strong back-reference: while the host holds the stand-in, the`

### DoubleTest.test_count (VM-CRASH)

- expected: host oracle = `ok`
- got: `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 |     host_cls = _jac_standin_class(u.cls)  1051 |     inst = host_cls.__new__(host_cls)  1052 |     # Strong back-reference: while the host holds the stand-in, the`

### DoubleTest.test_create_from_bytes (VM-CRASH)

- expected: host oracle = `ok`
- got: `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 |     host_cls = _jac_standin_class(u.cls)  1051 |     inst = host_cls.__new__(host_cls)  1052 |     # Strong back-reference: while the host holds the stand-in, the`

### DoubleTest.test_delitem (VM-CRASH)

- expected: host oracle = `ok`
- got: `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 |     host_cls = _jac_standin_class(u.cls)  1051 |     inst = host_cls.__new__(host_cls)  1052 |     # Strong back-reference: while the host holds the stand-in, the`

### DoubleTest.test_delslice (VM-CRASH)

- expected: host oracle = `ok`
- got: `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 |     host_cls = _jac_standin_class(u.cls)  1051 |     inst = host_cls.__new__(host_cls)  1052 |     # Strong back-reference: while the host holds the stand-in, the`

### DoubleTest.test_exhausted_iterator (VM-CRASH)

- expected: host oracle = `ok`
- got: `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 |     host_cls = _jac_standin_class(u.cls)  1051 |     inst = host_cls.__new__(host_cls)  1052 |     # Strong back-reference: while the host holds the stand-in, the`

### DoubleTest.test_exhausted_reverse_iterator (VM-CRASH)

- expected: host oracle = `ok`
- got: `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 |     host_cls = _jac_standin_class(u.cls)  1051 |     inst = host_cls.__new__(host_cls)  1052 |     # Strong back-reference: while the host holds the stand-in, the`

### DoubleTest.test_extended_getslice (VM-CRASH)

- expected: host oracle = `ok`
- got: `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 |     host_cls = _jac_standin_class(u.cls)  1051 |     inst = host_cls.__new__(host_cls)  1052 |     # Strong back-reference: while the host holds the stand-in, the`

### DoubleTest.test_extended_set_del_slice (VM-CRASH)

- expected: host oracle = `ok`
- got: `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 |     host_cls = _jac_standin_class(u.cls)  1051 |     inst = host_cls.__new__(host_cls)  1052 |     # Strong back-reference: while the host holds the stand-in, the`

### DoubleTest.test_extslice (VM-CRASH)

- expected: host oracle = `ok`
- got: `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 |     host_cls = _jac_standin_class(u.cls)  1051 |     inst = host_cls.__new__(host_cls)  1052 |     # Strong back-reference: while the host holds the stand-in, the`

### DoubleTest.test_fromarray (VM-CRASH)

- expected: host oracle = `ok`
- got: `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 |     host_cls = _jac_standin_class(u.cls)  1051 |     inst = host_cls.__new__(host_cls)  1052 |     # Strong back-reference: while the host holds the stand-in, the`

### DoubleTest.test_frombytearray (VM-CRASH)

- expected: host oracle = `ok`
- got: `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 |     host_cls = _jac_standin_class(u.cls)  1051 |     inst = host_cls.__new__(host_cls)  1052 |     # Strong back-reference: while the host holds the stand-in, the`

### DoubleTest.test_getslice (VM-CRASH)

- expected: host oracle = `ok`
- got: `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 |     host_cls = _jac_standin_class(u.cls)  1051 |     inst = host_cls.__new__(host_cls)  1052 |     # Strong back-reference: while the host holds the stand-in, the`

### DoubleTest.test_imul (VM-CRASH)

- expected: host oracle = `ok`
- got: `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 |     host_cls = _jac_standin_class(u.cls)  1051 |     inst = host_cls.__new__(host_cls)  1052 |     # Strong back-reference: while the host holds the stand-in, the`

### DoubleTest.test_index (VM-CRASH)

- expected: host oracle = `ok`
- got: `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 |     host_cls = _jac_standin_class(u.cls)  1051 |     inst = host_cls.__new__(host_cls)  1052 |     # Strong back-reference: while the host holds the stand-in, the`

### DoubleTest.test_insert (VM-CRASH)

- expected: host oracle = `ok`
- got: `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 |     host_cls = _jac_standin_class(u.cls)  1051 |     inst = host_cls.__new__(host_cls)  1052 |     # Strong back-reference: while the host holds the stand-in, the`

### DoubleTest.test_iterationcontains (VM-CRASH)

- expected: host oracle = `ok`
- got: `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 |     host_cls = _jac_standin_class(u.cls)  1051 |     inst = host_cls.__new__(host_cls)  1052 |     # Strong back-reference: while the host holds the stand-in, the`

### DoubleTest.test_iterator_pickle (VM-CRASH)

- expected: host oracle = `ok`
- got: `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 |     host_cls = _jac_standin_class(u.cls)  1051 |     inst = host_cls.__new__(host_cls)  1052 |     # Strong back-reference: while the host holds the stand-in, the`

### DoubleTest.test_mul (VM-CRASH)

- expected: host oracle = `ok`
- got: `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 |     host_cls = _jac_standin_class(u.cls)  1051 |     inst = host_cls.__new__(host_cls)  1052 |     # Strong back-reference: while the host holds the stand-in, the`

### DoubleTest.test_nan (VM-CRASH)

- expected: host oracle = `ok`
- got: `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 |     host_cls = _jac_standin_class(u.cls)  1051 |     inst = host_cls.__new__(host_cls)  1052 |     # Strong back-reference: while the host holds the stand-in, the`

### DoubleTest.test_pickle (VM-CRASH)

- expected: host oracle = `ok`
- got: `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 |     host_cls = _jac_standin_class(u.cls)  1051 |     inst = host_cls.__new__(host_cls)  1052 |     # Strong back-reference: while the host holds the stand-in, the`

### DoubleTest.test_pickle_for_empty_array (VM-CRASH)

- expected: host oracle = `ok`
- got: `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 |     host_cls = _jac_standin_class(u.cls)  1051 |     inst = host_cls.__new__(host_cls)  1052 |     # Strong back-reference: while the host holds the stand-in, the`

### DoubleTest.test_remove (VM-CRASH)

- expected: host oracle = `ok`
- got: `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 |     host_cls = _jac_standin_class(u.cls)  1051 |     inst = host_cls.__new__(host_cls)  1052 |     # Strong back-reference: while the host holds the stand-in, the`

### DoubleTest.test_repr (VM-CRASH)

- expected: host oracle = `ok`
- got: `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 |     host_cls = _jac_standin_class(u.cls)  1051 |     inst = host_cls.__new__(host_cls)  1052 |     # Strong back-reference: while the host holds the stand-in, the`

### DoubleTest.test_reverse (VM-CRASH)

- expected: host oracle = `ok`
- got: `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 |     host_cls = _jac_standin_class(u.cls)  1051 |     inst = host_cls.__new__(host_cls)  1052 |     # Strong back-reference: while the host holds the stand-in, the`

### DoubleTest.test_reverse_iterator (VM-CRASH)

- expected: host oracle = `ok`
- got: `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 |     host_cls = _jac_standin_class(u.cls)  1051 |     inst = host_cls.__new__(host_cls)  1052 |     # Strong back-reference: while the host holds the stand-in, the`

### DoubleTest.test_reverse_iterator_picking (VM-CRASH)

- expected: host oracle = `ok`
- got: `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 |     host_cls = _jac_standin_class(u.cls)  1051 |     inst = host_cls.__new__(host_cls)  1052 |     # Strong back-reference: while the host holds the stand-in, the`

### DoubleTest.test_str (VM-CRASH)

- expected: host oracle = `ok`
- got: `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 |     host_cls = _jac_standin_class(u.cls)  1051 |     inst = host_cls.__new__(host_cls)  1052 |     # Strong back-reference: while the host holds the stand-in, the`

### DoubleTest.test_subclass_with_kwargs (VM-CRASH)

- expected: host oracle = `ok`
- got: `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 |     host_cls = _jac_standin_class(u.cls)  1051 |     inst = host_cls.__new__(host_cls)  1052 |     # Strong back-reference: while the host holds the stand-in, the`

### DoubleTest.test_tofrombytes (VM-CRASH)

- expected: host oracle = `ok`
- got: `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 |     host_cls = _jac_standin_class(u.cls)  1051 |     inst = host_cls.__new__(host_cls)  1052 |     # Strong back-reference: while the host holds the stand-in, the`

### DoubleTest.test_tofromlist (VM-CRASH)

- expected: host oracle = `ok`
- got: `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 |     host_cls = _jac_standin_class(u.cls)  1051 |     inst = host_cls.__new__(host_cls)  1052 |     # Strong back-reference: while the host holds the stand-in, the`

### FloatTest.test_assignment (VM-CRASH)

- expected: host oracle = `ok`
- got: `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 |     host_cls = _jac_standin_class(u.cls)  1051 |     inst = host_cls.__new__(host_cls)  1052 |     # Strong back-reference: while the host holds the stand-in, the`

### FloatTest.test_buffer (VM-CRASH)

- expected: host oracle = `ok`
- got: `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 |     host_cls = _jac_standin_class(u.cls)  1051 |     inst = host_cls.__new__(host_cls)  1052 |     # Strong back-reference: while the host holds the stand-in, the`

### FloatTest.test_cmp (VM-CRASH)

- expected: host oracle = `ok`
- got: `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 |     host_cls = _jac_standin_class(u.cls)  1051 |     inst = host_cls.__new__(host_cls)  1052 |     # Strong back-reference: while the host holds the stand-in, the`

### FloatTest.test_constructor_with_iterable_argument (VM-CRASH)

- expected: host oracle = `ok`
- got: `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 |     host_cls = _jac_standin_class(u.cls)  1051 |     inst = host_cls.__new__(host_cls)  1052 |     # Strong back-reference: while the host holds the stand-in, the`

### FloatTest.test_count (VM-CRASH)

- expected: host oracle = `ok`
- got: `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 |     host_cls = _jac_standin_class(u.cls)  1051 |     inst = host_cls.__new__(host_cls)  1052 |     # Strong back-reference: while the host holds the stand-in, the`

### FloatTest.test_create_from_bytes (VM-CRASH)

- expected: host oracle = `ok`
- got: `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 |     host_cls = _jac_standin_class(u.cls)  1051 |     inst = host_cls.__new__(host_cls)  1052 |     # Strong back-reference: while the host holds the stand-in, the`

### FloatTest.test_delitem (VM-CRASH)

- expected: host oracle = `ok`
- got: `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 |     host_cls = _jac_standin_class(u.cls)  1051 |     inst = host_cls.__new__(host_cls)  1052 |     # Strong back-reference: while the host holds the stand-in, the`

### FloatTest.test_delslice (VM-CRASH)

- expected: host oracle = `ok`
- got: `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 |     host_cls = _jac_standin_class(u.cls)  1051 |     inst = host_cls.__new__(host_cls)  1052 |     # Strong back-reference: while the host holds the stand-in, the`

### FloatTest.test_exhausted_iterator (VM-CRASH)

- expected: host oracle = `ok`
- got: `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 |     host_cls = _jac_standin_class(u.cls)  1051 |     inst = host_cls.__new__(host_cls)  1052 |     # Strong back-reference: while the host holds the stand-in, the`

### FloatTest.test_exhausted_reverse_iterator (VM-CRASH)

- expected: host oracle = `ok`
- got: `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 |     host_cls = _jac_standin_class(u.cls)  1051 |     inst = host_cls.__new__(host_cls)  1052 |     # Strong back-reference: while the host holds the stand-in, the`

### FloatTest.test_extended_getslice (VM-CRASH)

- expected: host oracle = `ok`
- got: `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 |     host_cls = _jac_standin_class(u.cls)  1051 |     inst = host_cls.__new__(host_cls)  1052 |     # Strong back-reference: while the host holds the stand-in, the`

### FloatTest.test_extended_set_del_slice (VM-CRASH)

- expected: host oracle = `ok`
- got: `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 |     host_cls = _jac_standin_class(u.cls)  1051 |     inst = host_cls.__new__(host_cls)  1052 |     # Strong back-reference: while the host holds the stand-in, the`

### FloatTest.test_extslice (VM-CRASH)

- expected: host oracle = `ok`
- got: `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 |     host_cls = _jac_standin_class(u.cls)  1051 |     inst = host_cls.__new__(host_cls)  1052 |     # Strong back-reference: while the host holds the stand-in, the`

### FloatTest.test_fromarray (VM-CRASH)

- expected: host oracle = `ok`
- got: `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 |     host_cls = _jac_standin_class(u.cls)  1051 |     inst = host_cls.__new__(host_cls)  1052 |     # Strong back-reference: while the host holds the stand-in, the`

### FloatTest.test_frombytearray (VM-CRASH)

- expected: host oracle = `ok`
- got: `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 |     host_cls = _jac_standin_class(u.cls)  1051 |     inst = host_cls.__new__(host_cls)  1052 |     # Strong back-reference: while the host holds the stand-in, the`

### FloatTest.test_getslice (VM-CRASH)

- expected: host oracle = `ok`
- got: `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 |     host_cls = _jac_standin_class(u.cls)  1051 |     inst = host_cls.__new__(host_cls)  1052 |     # Strong back-reference: while the host holds the stand-in, the`

### FloatTest.test_imul (VM-CRASH)

- expected: host oracle = `ok`
- got: `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 |     host_cls = _jac_standin_class(u.cls)  1051 |     inst = host_cls.__new__(host_cls)  1052 |     # Strong back-reference: while the host holds the stand-in, the`

### FloatTest.test_index (VM-CRASH)

- expected: host oracle = `ok`
- got: `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 |     host_cls = _jac_standin_class(u.cls)  1051 |     inst = host_cls.__new__(host_cls)  1052 |     # Strong back-reference: while the host holds the stand-in, the`

### FloatTest.test_insert (VM-CRASH)

- expected: host oracle = `ok`
- got: `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 |     host_cls = _jac_standin_class(u.cls)  1051 |     inst = host_cls.__new__(host_cls)  1052 |     # Strong back-reference: while the host holds the stand-in, the`

### FloatTest.test_iterationcontains (VM-CRASH)

- expected: host oracle = `ok`
- got: `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 |     host_cls = _jac_standin_class(u.cls)  1051 |     inst = host_cls.__new__(host_cls)  1052 |     # Strong back-reference: while the host holds the stand-in, the`

### FloatTest.test_iterator_pickle (VM-CRASH)

- expected: host oracle = `ok`
- got: `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 |     host_cls = _jac_standin_class(u.cls)  1051 |     inst = host_cls.__new__(host_cls)  1052 |     # Strong back-reference: while the host holds the stand-in, the`

### FloatTest.test_mul (VM-CRASH)

- expected: host oracle = `ok`
- got: `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 |     host_cls = _jac_standin_class(u.cls)  1051 |     inst = host_cls.__new__(host_cls)  1052 |     # Strong back-reference: while the host holds the stand-in, the`

### FloatTest.test_nan (VM-CRASH)

- expected: host oracle = `ok`
- got: `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 |     host_cls = _jac_standin_class(u.cls)  1051 |     inst = host_cls.__new__(host_cls)  1052 |     # Strong back-reference: while the host holds the stand-in, the`

### FloatTest.test_pickle (VM-CRASH)

- expected: host oracle = `ok`
- got: `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 |     host_cls = _jac_standin_class(u.cls)  1051 |     inst = host_cls.__new__(host_cls)  1052 |     # Strong back-reference: while the host holds the stand-in, the`

### FloatTest.test_pickle_for_empty_array (VM-CRASH)

- expected: host oracle = `ok`
- got: `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 |     host_cls = _jac_standin_class(u.cls)  1051 |     inst = host_cls.__new__(host_cls)  1052 |     # Strong back-reference: while the host holds the stand-in, the`

### FloatTest.test_remove (VM-CRASH)

- expected: host oracle = `ok`
- got: `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 |     host_cls = _jac_standin_class(u.cls)  1051 |     inst = host_cls.__new__(host_cls)  1052 |     # Strong back-reference: while the host holds the stand-in, the`

### FloatTest.test_repr (VM-CRASH)

- expected: host oracle = `ok`
- got: `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 |     host_cls = _jac_standin_class(u.cls)  1051 |     inst = host_cls.__new__(host_cls)  1052 |     # Strong back-reference: while the host holds the stand-in, the`

### FloatTest.test_reverse (VM-CRASH)

- expected: host oracle = `ok`
- got: `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 |     host_cls = _jac_standin_class(u.cls)  1051 |     inst = host_cls.__new__(host_cls)  1052 |     # Strong back-reference: while the host holds the stand-in, the`

### FloatTest.test_reverse_iterator (VM-CRASH)

- expected: host oracle = `ok`
- got: `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 |     host_cls = _jac_standin_class(u.cls)  1051 |     inst = host_cls.__new__(host_cls)  1052 |     # Strong back-reference: while the host holds the stand-in, the`

### FloatTest.test_reverse_iterator_picking (VM-CRASH)

- expected: host oracle = `ok`
- got: `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 |     host_cls = _jac_standin_class(u.cls)  1051 |     inst = host_cls.__new__(host_cls)  1052 |     # Strong back-reference: while the host holds the stand-in, the`

### FloatTest.test_str (VM-CRASH)

- expected: host oracle = `ok`
- got: `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 |     host_cls = _jac_standin_class(u.cls)  1051 |     inst = host_cls.__new__(host_cls)  1052 |     # Strong back-reference: while the host holds the stand-in, the`

### FloatTest.test_subclass_with_kwargs (VM-CRASH)

- expected: host oracle = `ok`
- got: `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 |     host_cls = _jac_standin_class(u.cls)  1051 |     inst = host_cls.__new__(host_cls)  1052 |     # Strong back-reference: while the host holds the stand-in, the`

### FloatTest.test_tofrombytes (VM-CRASH)

- expected: host oracle = `ok`
- got: `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 |     host_cls = _jac_standin_class(u.cls)  1051 |     inst = host_cls.__new__(host_cls)  1052 |     # Strong back-reference: while the host holds the stand-in, the`

### FloatTest.test_tofromlist (VM-CRASH)

- expected: host oracle = `ok`
- got: `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 |     host_cls = _jac_standin_class(u.cls)  1051 |     inst = host_cls.__new__(host_cls)  1052 |     # Strong back-reference: while the host holds the stand-in, the`

### IntTest.test_assignment (VM-CRASH)

- expected: host oracle = `ok`
- got: `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 |     host_cls = _jac_standin_class(u.cls)  1051 |     inst = host_cls.__new__(host_cls)  1052 |     # Strong back-reference: while the host holds the stand-in, the`

### IntTest.test_buffer (VM-CRASH)

- expected: host oracle = `ok`
- got: `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 |     host_cls = _jac_standin_class(u.cls)  1051 |     inst = host_cls.__new__(host_cls)  1052 |     # Strong back-reference: while the host holds the stand-in, the`

### IntTest.test_cmp (VM-CRASH)

- expected: host oracle = `ok`
- got: `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 |     host_cls = _jac_standin_class(u.cls)  1051 |     inst = host_cls.__new__(host_cls)  1052 |     # Strong back-reference: while the host holds the stand-in, the`

### IntTest.test_constructor_with_iterable_argument (VM-CRASH)

- expected: host oracle = `ok`
- got: `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 |     host_cls = _jac_standin_class(u.cls)  1051 |     inst = host_cls.__new__(host_cls)  1052 |     # Strong back-reference: while the host holds the stand-in, the`

### IntTest.test_count (VM-CRASH)

- expected: host oracle = `ok`
- got: `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 |     host_cls = _jac_standin_class(u.cls)  1051 |     inst = host_cls.__new__(host_cls)  1052 |     # Strong back-reference: while the host holds the stand-in, the`

### IntTest.test_create_from_bytes (VM-CRASH)

- expected: host oracle = `ok`
- got: `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 |     host_cls = _jac_standin_class(u.cls)  1051 |     inst = host_cls.__new__(host_cls)  1052 |     # Strong back-reference: while the host holds the stand-in, the`

### IntTest.test_delitem (VM-CRASH)

- expected: host oracle = `ok`
- got: `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 |     host_cls = _jac_standin_class(u.cls)  1051 |     inst = host_cls.__new__(host_cls)  1052 |     # Strong back-reference: while the host holds the stand-in, the`

### IntTest.test_delslice (VM-CRASH)

- expected: host oracle = `ok`
- got: `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 |     host_cls = _jac_standin_class(u.cls)  1051 |     inst = host_cls.__new__(host_cls)  1052 |     # Strong back-reference: while the host holds the stand-in, the`

### IntTest.test_exhausted_iterator (VM-CRASH)

- expected: host oracle = `ok`
- got: `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 |     host_cls = _jac_standin_class(u.cls)  1051 |     inst = host_cls.__new__(host_cls)  1052 |     # Strong back-reference: while the host holds the stand-in, the`

### IntTest.test_exhausted_reverse_iterator (VM-CRASH)

- expected: host oracle = `ok`
- got: `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 |     host_cls = _jac_standin_class(u.cls)  1051 |     inst = host_cls.__new__(host_cls)  1052 |     # Strong back-reference: while the host holds the stand-in, the`

### IntTest.test_extended_getslice (VM-CRASH)

- expected: host oracle = `ok`
- got: `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 |     host_cls = _jac_standin_class(u.cls)  1051 |     inst = host_cls.__new__(host_cls)  1052 |     # Strong back-reference: while the host holds the stand-in, the`

### IntTest.test_extended_set_del_slice (VM-CRASH)

- expected: host oracle = `ok`
- got: `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 |     host_cls = _jac_standin_class(u.cls)  1051 |     inst = host_cls.__new__(host_cls)  1052 |     # Strong back-reference: while the host holds the stand-in, the`

### IntTest.test_extslice (VM-CRASH)

- expected: host oracle = `ok`
- got: `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 |     host_cls = _jac_standin_class(u.cls)  1051 |     inst = host_cls.__new__(host_cls)  1052 |     # Strong back-reference: while the host holds the stand-in, the`

### IntTest.test_fromarray (VM-CRASH)

- expected: host oracle = `ok`
- got: `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 |     host_cls = _jac_standin_class(u.cls)  1051 |     inst = host_cls.__new__(host_cls)  1052 |     # Strong back-reference: while the host holds the stand-in, the`

### IntTest.test_frombytearray (VM-CRASH)

- expected: host oracle = `ok`
- got: `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 |     host_cls = _jac_standin_class(u.cls)  1051 |     inst = host_cls.__new__(host_cls)  1052 |     # Strong back-reference: while the host holds the stand-in, the`

### IntTest.test_getslice (VM-CRASH)

- expected: host oracle = `ok`
- got: `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 |     host_cls = _jac_standin_class(u.cls)  1051 |     inst = host_cls.__new__(host_cls)  1052 |     # Strong back-reference: while the host holds the stand-in, the`

### IntTest.test_imul (VM-CRASH)

- expected: host oracle = `ok`
- got: `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 |     host_cls = _jac_standin_class(u.cls)  1051 |     inst = host_cls.__new__(host_cls)  1052 |     # Strong back-reference: while the host holds the stand-in, the`

### IntTest.test_index (VM-CRASH)

- expected: host oracle = `ok`
- got: `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 |     host_cls = _jac_standin_class(u.cls)  1051 |     inst = host_cls.__new__(host_cls)  1052 |     # Strong back-reference: while the host holds the stand-in, the`

### IntTest.test_insert (VM-CRASH)

- expected: host oracle = `ok`
- got: `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 |     host_cls = _jac_standin_class(u.cls)  1051 |     inst = host_cls.__new__(host_cls)  1052 |     # Strong back-reference: while the host holds the stand-in, the`

### IntTest.test_iterationcontains (VM-CRASH)

- expected: host oracle = `ok`
- got: `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 |     host_cls = _jac_standin_class(u.cls)  1051 |     inst = host_cls.__new__(host_cls)  1052 |     # Strong back-reference: while the host holds the stand-in, the`

### IntTest.test_iterator_pickle (VM-CRASH)

- expected: host oracle = `ok`
- got: `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 |     host_cls = _jac_standin_class(u.cls)  1051 |     inst = host_cls.__new__(host_cls)  1052 |     # Strong back-reference: while the host holds the stand-in, the`

### IntTest.test_mul (VM-CRASH)

- expected: host oracle = `ok`
- got: `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 |     host_cls = _jac_standin_class(u.cls)  1051 |     inst = host_cls.__new__(host_cls)  1052 |     # Strong back-reference: while the host holds the stand-in, the`

### IntTest.test_pickle (VM-CRASH)

- expected: host oracle = `ok`
- got: `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 |     host_cls = _jac_standin_class(u.cls)  1051 |     inst = host_cls.__new__(host_cls)  1052 |     # Strong back-reference: while the host holds the stand-in, the`

### IntTest.test_pickle_for_empty_array (VM-CRASH)

- expected: host oracle = `ok`
- got: `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 |     host_cls = _jac_standin_class(u.cls)  1051 |     inst = host_cls.__new__(host_cls)  1052 |     # Strong back-reference: while the host holds the stand-in, the`

### IntTest.test_remove (VM-CRASH)

- expected: host oracle = `ok`
- got: `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 |     host_cls = _jac_standin_class(u.cls)  1051 |     inst = host_cls.__new__(host_cls)  1052 |     # Strong back-reference: while the host holds the stand-in, the`

### IntTest.test_repr (VM-CRASH)

- expected: host oracle = `ok`
- got: `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 |     host_cls = _jac_standin_class(u.cls)  1051 |     inst = host_cls.__new__(host_cls)  1052 |     # Strong back-reference: while the host holds the stand-in, the`

### IntTest.test_reverse (VM-CRASH)

- expected: host oracle = `ok`
- got: `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 |     host_cls = _jac_standin_class(u.cls)  1051 |     inst = host_cls.__new__(host_cls)  1052 |     # Strong back-reference: while the host holds the stand-in, the`

### IntTest.test_reverse_iterator (VM-CRASH)

- expected: host oracle = `ok`
- got: `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 |     host_cls = _jac_standin_class(u.cls)  1051 |     inst = host_cls.__new__(host_cls)  1052 |     # Strong back-reference: while the host holds the stand-in, the`

### IntTest.test_reverse_iterator_picking (VM-CRASH)

- expected: host oracle = `ok`
- got: `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 |     host_cls = _jac_standin_class(u.cls)  1051 |     inst = host_cls.__new__(host_cls)  1052 |     # Strong back-reference: while the host holds the stand-in, the`

### IntTest.test_str (VM-CRASH)

- expected: host oracle = `ok`
- got: `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 |     host_cls = _jac_standin_class(u.cls)  1051 |     inst = host_cls.__new__(host_cls)  1052 |     # Strong back-reference: while the host holds the stand-in, the`

### IntTest.test_subclass_with_kwargs (VM-CRASH)

- expected: host oracle = `ok`
- got: `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 |     host_cls = _jac_standin_class(u.cls)  1051 |     inst = host_cls.__new__(host_cls)  1052 |     # Strong back-reference: while the host holds the stand-in, the`

### IntTest.test_tofrombytes (VM-CRASH)

- expected: host oracle = `ok`
- got: `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 |     host_cls = _jac_standin_class(u.cls)  1051 |     inst = host_cls.__new__(host_cls)  1052 |     # Strong back-reference: while the host holds the stand-in, the`

### IntTest.test_tofromlist (VM-CRASH)

- expected: host oracle = `ok`
- got: `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 |     host_cls = _jac_standin_class(u.cls)  1051 |     inst = host_cls.__new__(host_cls)  1052 |     # Strong back-reference: while the host holds the stand-in, the`

### IntTest.test_type_error (VM-CRASH)

- expected: host oracle = `ok`
- got: `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 |     host_cls = _jac_standin_class(u.cls)  1051 |     inst = host_cls.__new__(host_cls)  1052 |     # Strong back-reference: while the host holds the stand-in, the`

### LargeArrayTest.test_gh_128961 (VM-CRASH)

- expected: host oracle = `ok`
- got: `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 |     host_cls = _jac_standin_class(u.cls)  1051 |     inst = host_cls.__new__(host_cls)  1052 |     # Strong back-reference: while the host holds the stand-in, the`

### LargeArrayTest.test_setitem_use_after_shrink_with_int_data (VM-CRASH)

- expected: host oracle = `ok`
- got: `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 |     host_cls = _jac_standin_class(u.cls)  1051 |     inst = host_cls.__new__(host_cls)  1052 |     # Strong back-reference: while the host holds the stand-in, the`

### LongLongTest.test_assignment (VM-CRASH)

- expected: host oracle = `ok`
- got: `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 |     host_cls = _jac_standin_class(u.cls)  1051 |     inst = host_cls.__new__(host_cls)  1052 |     # Strong back-reference: while the host holds the stand-in, the`

### LongLongTest.test_buffer (VM-CRASH)

- expected: host oracle = `ok`
- got: `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 |     host_cls = _jac_standin_class(u.cls)  1051 |     inst = host_cls.__new__(host_cls)  1052 |     # Strong back-reference: while the host holds the stand-in, the`

### LongLongTest.test_cmp (VM-CRASH)

- expected: host oracle = `ok`
- got: `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 |     host_cls = _jac_standin_class(u.cls)  1051 |     inst = host_cls.__new__(host_cls)  1052 |     # Strong back-reference: while the host holds the stand-in, the`

### LongLongTest.test_constructor_with_iterable_argument (VM-CRASH)

- expected: host oracle = `ok`
- got: `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 |     host_cls = _jac_standin_class(u.cls)  1051 |     inst = host_cls.__new__(host_cls)  1052 |     # Strong back-reference: while the host holds the stand-in, the`

### LongLongTest.test_count (VM-CRASH)

- expected: host oracle = `ok`
- got: `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 |     host_cls = _jac_standin_class(u.cls)  1051 |     inst = host_cls.__new__(host_cls)  1052 |     # Strong back-reference: while the host holds the stand-in, the`

### LongLongTest.test_create_from_bytes (VM-CRASH)

- expected: host oracle = `ok`
- got: `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 |     host_cls = _jac_standin_class(u.cls)  1051 |     inst = host_cls.__new__(host_cls)  1052 |     # Strong back-reference: while the host holds the stand-in, the`

### LongLongTest.test_delitem (VM-CRASH)

- expected: host oracle = `ok`
- got: `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 |     host_cls = _jac_standin_class(u.cls)  1051 |     inst = host_cls.__new__(host_cls)  1052 |     # Strong back-reference: while the host holds the stand-in, the`

### LongLongTest.test_delslice (VM-CRASH)

- expected: host oracle = `ok`
- got: `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 |     host_cls = _jac_standin_class(u.cls)  1051 |     inst = host_cls.__new__(host_cls)  1052 |     # Strong back-reference: while the host holds the stand-in, the`

### LongLongTest.test_exhausted_iterator (VM-CRASH)

- expected: host oracle = `ok`
- got: `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 |     host_cls = _jac_standin_class(u.cls)  1051 |     inst = host_cls.__new__(host_cls)  1052 |     # Strong back-reference: while the host holds the stand-in, the`

### LongLongTest.test_exhausted_reverse_iterator (VM-CRASH)

- expected: host oracle = `ok`
- got: `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 |     host_cls = _jac_standin_class(u.cls)  1051 |     inst = host_cls.__new__(host_cls)  1052 |     # Strong back-reference: while the host holds the stand-in, the`

### LongLongTest.test_extended_getslice (VM-CRASH)

- expected: host oracle = `ok`
- got: `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 |     host_cls = _jac_standin_class(u.cls)  1051 |     inst = host_cls.__new__(host_cls)  1052 |     # Strong back-reference: while the host holds the stand-in, the`

### LongLongTest.test_extended_set_del_slice (VM-CRASH)

- expected: host oracle = `ok`
- got: `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 |     host_cls = _jac_standin_class(u.cls)  1051 |     inst = host_cls.__new__(host_cls)  1052 |     # Strong back-reference: while the host holds the stand-in, the`

### LongLongTest.test_extslice (VM-CRASH)

- expected: host oracle = `ok`
- got: `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 |     host_cls = _jac_standin_class(u.cls)  1051 |     inst = host_cls.__new__(host_cls)  1052 |     # Strong back-reference: while the host holds the stand-in, the`

### LongLongTest.test_fromarray (VM-CRASH)

- expected: host oracle = `ok`
- got: `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 |     host_cls = _jac_standin_class(u.cls)  1051 |     inst = host_cls.__new__(host_cls)  1052 |     # Strong back-reference: while the host holds the stand-in, the`

### LongLongTest.test_frombytearray (VM-CRASH)

- expected: host oracle = `ok`
- got: `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 |     host_cls = _jac_standin_class(u.cls)  1051 |     inst = host_cls.__new__(host_cls)  1052 |     # Strong back-reference: while the host holds the stand-in, the`

### LongLongTest.test_getslice (VM-CRASH)

- expected: host oracle = `ok`
- got: `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 |     host_cls = _jac_standin_class(u.cls)  1051 |     inst = host_cls.__new__(host_cls)  1052 |     # Strong back-reference: while the host holds the stand-in, the`

### LongLongTest.test_imul (VM-CRASH)

- expected: host oracle = `ok`
- got: `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 |     host_cls = _jac_standin_class(u.cls)  1051 |     inst = host_cls.__new__(host_cls)  1052 |     # Strong back-reference: while the host holds the stand-in, the`

### LongLongTest.test_index (VM-CRASH)

- expected: host oracle = `ok`
- got: `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 |     host_cls = _jac_standin_class(u.cls)  1051 |     inst = host_cls.__new__(host_cls)  1052 |     # Strong back-reference: while the host holds the stand-in, the`

### LongLongTest.test_insert (VM-CRASH)

- expected: host oracle = `ok`
- got: `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 |     host_cls = _jac_standin_class(u.cls)  1051 |     inst = host_cls.__new__(host_cls)  1052 |     # Strong back-reference: while the host holds the stand-in, the`

### LongLongTest.test_iterationcontains (VM-CRASH)

- expected: host oracle = `ok`
- got: `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 |     host_cls = _jac_standin_class(u.cls)  1051 |     inst = host_cls.__new__(host_cls)  1052 |     # Strong back-reference: while the host holds the stand-in, the`

### LongLongTest.test_iterator_pickle (VM-CRASH)

- expected: host oracle = `ok`
- got: `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 |     host_cls = _jac_standin_class(u.cls)  1051 |     inst = host_cls.__new__(host_cls)  1052 |     # Strong back-reference: while the host holds the stand-in, the`

### LongLongTest.test_mul (VM-CRASH)

- expected: host oracle = `ok`
- got: `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 |     host_cls = _jac_standin_class(u.cls)  1051 |     inst = host_cls.__new__(host_cls)  1052 |     # Strong back-reference: while the host holds the stand-in, the`

### LongLongTest.test_pickle (VM-CRASH)

- expected: host oracle = `ok`
- got: `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 |     host_cls = _jac_standin_class(u.cls)  1051 |     inst = host_cls.__new__(host_cls)  1052 |     # Strong back-reference: while the host holds the stand-in, the`

### LongLongTest.test_pickle_for_empty_array (VM-CRASH)

- expected: host oracle = `ok`
- got: `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 |     host_cls = _jac_standin_class(u.cls)  1051 |     inst = host_cls.__new__(host_cls)  1052 |     # Strong back-reference: while the host holds the stand-in, the`

### LongLongTest.test_remove (VM-CRASH)

- expected: host oracle = `ok`
- got: `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 |     host_cls = _jac_standin_class(u.cls)  1051 |     inst = host_cls.__new__(host_cls)  1052 |     # Strong back-reference: while the host holds the stand-in, the`

### LongLongTest.test_repr (VM-CRASH)

- expected: host oracle = `ok`
- got: `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 |     host_cls = _jac_standin_class(u.cls)  1051 |     inst = host_cls.__new__(host_cls)  1052 |     # Strong back-reference: while the host holds the stand-in, the`

### LongLongTest.test_reverse (VM-CRASH)

- expected: host oracle = `ok`
- got: `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 |     host_cls = _jac_standin_class(u.cls)  1051 |     inst = host_cls.__new__(host_cls)  1052 |     # Strong back-reference: while the host holds the stand-in, the`

### LongLongTest.test_reverse_iterator (VM-CRASH)

- expected: host oracle = `ok`
- got: `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 |     host_cls = _jac_standin_class(u.cls)  1051 |     inst = host_cls.__new__(host_cls)  1052 |     # Strong back-reference: while the host holds the stand-in, the`

### LongLongTest.test_reverse_iterator_picking (VM-CRASH)

- expected: host oracle = `ok`
- got: `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 |     host_cls = _jac_standin_class(u.cls)  1051 |     inst = host_cls.__new__(host_cls)  1052 |     # Strong back-reference: while the host holds the stand-in, the`

### LongLongTest.test_str (VM-CRASH)

- expected: host oracle = `ok`
- got: `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 |     host_cls = _jac_standin_class(u.cls)  1051 |     inst = host_cls.__new__(host_cls)  1052 |     # Strong back-reference: while the host holds the stand-in, the`

### LongLongTest.test_subclass_with_kwargs (VM-CRASH)

- expected: host oracle = `ok`
- got: `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 |     host_cls = _jac_standin_class(u.cls)  1051 |     inst = host_cls.__new__(host_cls)  1052 |     # Strong back-reference: while the host holds the stand-in, the`

### LongLongTest.test_tofrombytes (VM-CRASH)

- expected: host oracle = `ok`
- got: `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 |     host_cls = _jac_standin_class(u.cls)  1051 |     inst = host_cls.__new__(host_cls)  1052 |     # Strong back-reference: while the host holds the stand-in, the`

### LongLongTest.test_tofromlist (VM-CRASH)

- expected: host oracle = `ok`
- got: `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 |     host_cls = _jac_standin_class(u.cls)  1051 |     inst = host_cls.__new__(host_cls)  1052 |     # Strong back-reference: while the host holds the stand-in, the`

### LongLongTest.test_type_error (VM-CRASH)

- expected: host oracle = `ok`
- got: `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 |     host_cls = _jac_standin_class(u.cls)  1051 |     inst = host_cls.__new__(host_cls)  1052 |     # Strong back-reference: while the host holds the stand-in, the`

### LongTest.test_assignment (VM-CRASH)

- expected: host oracle = `ok`
- got: `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 |     host_cls = _jac_standin_class(u.cls)  1051 |     inst = host_cls.__new__(host_cls)  1052 |     # Strong back-reference: while the host holds the stand-in, the`

### LongTest.test_buffer (VM-CRASH)

- expected: host oracle = `ok`
- got: `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 |     host_cls = _jac_standin_class(u.cls)  1051 |     inst = host_cls.__new__(host_cls)  1052 |     # Strong back-reference: while the host holds the stand-in, the`

### LongTest.test_cmp (VM-CRASH)

- expected: host oracle = `ok`
- got: `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 |     host_cls = _jac_standin_class(u.cls)  1051 |     inst = host_cls.__new__(host_cls)  1052 |     # Strong back-reference: while the host holds the stand-in, the`

### LongTest.test_constructor_with_iterable_argument (VM-CRASH)

- expected: host oracle = `ok`
- got: `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 |     host_cls = _jac_standin_class(u.cls)  1051 |     inst = host_cls.__new__(host_cls)  1052 |     # Strong back-reference: while the host holds the stand-in, the`

### LongTest.test_count (VM-CRASH)

- expected: host oracle = `ok`
- got: `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 |     host_cls = _jac_standin_class(u.cls)  1051 |     inst = host_cls.__new__(host_cls)  1052 |     # Strong back-reference: while the host holds the stand-in, the`

### LongTest.test_create_from_bytes (VM-CRASH)

- expected: host oracle = `ok`
- got: `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 |     host_cls = _jac_standin_class(u.cls)  1051 |     inst = host_cls.__new__(host_cls)  1052 |     # Strong back-reference: while the host holds the stand-in, the`

### LongTest.test_delitem (VM-CRASH)

- expected: host oracle = `ok`
- got: `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 |     host_cls = _jac_standin_class(u.cls)  1051 |     inst = host_cls.__new__(host_cls)  1052 |     # Strong back-reference: while the host holds the stand-in, the`

### LongTest.test_delslice (VM-CRASH)

- expected: host oracle = `ok`
- got: `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 |     host_cls = _jac_standin_class(u.cls)  1051 |     inst = host_cls.__new__(host_cls)  1052 |     # Strong back-reference: while the host holds the stand-in, the`

### LongTest.test_exhausted_iterator (VM-CRASH)

- expected: host oracle = `ok`
- got: `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 |     host_cls = _jac_standin_class(u.cls)  1051 |     inst = host_cls.__new__(host_cls)  1052 |     # Strong back-reference: while the host holds the stand-in, the`

### LongTest.test_exhausted_reverse_iterator (VM-CRASH)

- expected: host oracle = `ok`
- got: `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 |     host_cls = _jac_standin_class(u.cls)  1051 |     inst = host_cls.__new__(host_cls)  1052 |     # Strong back-reference: while the host holds the stand-in, the`

### LongTest.test_extended_getslice (VM-CRASH)

- expected: host oracle = `ok`
- got: `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 |     host_cls = _jac_standin_class(u.cls)  1051 |     inst = host_cls.__new__(host_cls)  1052 |     # Strong back-reference: while the host holds the stand-in, the`

### LongTest.test_extended_set_del_slice (VM-CRASH)

- expected: host oracle = `ok`
- got: `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 |     host_cls = _jac_standin_class(u.cls)  1051 |     inst = host_cls.__new__(host_cls)  1052 |     # Strong back-reference: while the host holds the stand-in, the`

### LongTest.test_extslice (VM-CRASH)

- expected: host oracle = `ok`
- got: `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 |     host_cls = _jac_standin_class(u.cls)  1051 |     inst = host_cls.__new__(host_cls)  1052 |     # Strong back-reference: while the host holds the stand-in, the`

### LongTest.test_fromarray (VM-CRASH)

- expected: host oracle = `ok`
- got: `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 |     host_cls = _jac_standin_class(u.cls)  1051 |     inst = host_cls.__new__(host_cls)  1052 |     # Strong back-reference: while the host holds the stand-in, the`

### LongTest.test_frombytearray (VM-CRASH)

- expected: host oracle = `ok`
- got: `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 |     host_cls = _jac_standin_class(u.cls)  1051 |     inst = host_cls.__new__(host_cls)  1052 |     # Strong back-reference: while the host holds the stand-in, the`

### LongTest.test_getslice (VM-CRASH)

- expected: host oracle = `ok`
- got: `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 |     host_cls = _jac_standin_class(u.cls)  1051 |     inst = host_cls.__new__(host_cls)  1052 |     # Strong back-reference: while the host holds the stand-in, the`

### LongTest.test_imul (VM-CRASH)

- expected: host oracle = `ok`
- got: `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 |     host_cls = _jac_standin_class(u.cls)  1051 |     inst = host_cls.__new__(host_cls)  1052 |     # Strong back-reference: while the host holds the stand-in, the`

### LongTest.test_index (VM-CRASH)

- expected: host oracle = `ok`
- got: `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 |     host_cls = _jac_standin_class(u.cls)  1051 |     inst = host_cls.__new__(host_cls)  1052 |     # Strong back-reference: while the host holds the stand-in, the`

### LongTest.test_insert (VM-CRASH)

- expected: host oracle = `ok`
- got: `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 |     host_cls = _jac_standin_class(u.cls)  1051 |     inst = host_cls.__new__(host_cls)  1052 |     # Strong back-reference: while the host holds the stand-in, the`

### LongTest.test_iterationcontains (VM-CRASH)

- expected: host oracle = `ok`
- got: `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 |     host_cls = _jac_standin_class(u.cls)  1051 |     inst = host_cls.__new__(host_cls)  1052 |     # Strong back-reference: while the host holds the stand-in, the`

### LongTest.test_iterator_pickle (VM-CRASH)

- expected: host oracle = `ok`
- got: `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 |     host_cls = _jac_standin_class(u.cls)  1051 |     inst = host_cls.__new__(host_cls)  1052 |     # Strong back-reference: while the host holds the stand-in, the`

### LongTest.test_mul (VM-CRASH)

- expected: host oracle = `ok`
- got: `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 |     host_cls = _jac_standin_class(u.cls)  1051 |     inst = host_cls.__new__(host_cls)  1052 |     # Strong back-reference: while the host holds the stand-in, the`

### LongTest.test_pickle (VM-CRASH)

- expected: host oracle = `ok`
- got: `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 |     host_cls = _jac_standin_class(u.cls)  1051 |     inst = host_cls.__new__(host_cls)  1052 |     # Strong back-reference: while the host holds the stand-in, the`

### LongTest.test_pickle_for_empty_array (VM-CRASH)

- expected: host oracle = `ok`
- got: `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 |     host_cls = _jac_standin_class(u.cls)  1051 |     inst = host_cls.__new__(host_cls)  1052 |     # Strong back-reference: while the host holds the stand-in, the`

### LongTest.test_remove (VM-CRASH)

- expected: host oracle = `ok`
- got: `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 |     host_cls = _jac_standin_class(u.cls)  1051 |     inst = host_cls.__new__(host_cls)  1052 |     # Strong back-reference: while the host holds the stand-in, the`

### LongTest.test_repr (VM-CRASH)

- expected: host oracle = `ok`
- got: `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 |     host_cls = _jac_standin_class(u.cls)  1051 |     inst = host_cls.__new__(host_cls)  1052 |     # Strong back-reference: while the host holds the stand-in, the`

### LongTest.test_reverse (VM-CRASH)

- expected: host oracle = `ok`
- got: `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 |     host_cls = _jac_standin_class(u.cls)  1051 |     inst = host_cls.__new__(host_cls)  1052 |     # Strong back-reference: while the host holds the stand-in, the`

### LongTest.test_reverse_iterator (VM-CRASH)

- expected: host oracle = `ok`
- got: `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 |     host_cls = _jac_standin_class(u.cls)  1051 |     inst = host_cls.__new__(host_cls)  1052 |     # Strong back-reference: while the host holds the stand-in, the`

### LongTest.test_reverse_iterator_picking (VM-CRASH)

- expected: host oracle = `ok`
- got: `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 |     host_cls = _jac_standin_class(u.cls)  1051 |     inst = host_cls.__new__(host_cls)  1052 |     # Strong back-reference: while the host holds the stand-in, the`

### LongTest.test_str (VM-CRASH)

- expected: host oracle = `ok`
- got: `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 |     host_cls = _jac_standin_class(u.cls)  1051 |     inst = host_cls.__new__(host_cls)  1052 |     # Strong back-reference: while the host holds the stand-in, the`

### LongTest.test_subclass_with_kwargs (VM-CRASH)

- expected: host oracle = `ok`
- got: `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 |     host_cls = _jac_standin_class(u.cls)  1051 |     inst = host_cls.__new__(host_cls)  1052 |     # Strong back-reference: while the host holds the stand-in, the`

### LongTest.test_tofrombytes (VM-CRASH)

- expected: host oracle = `ok`
- got: `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 |     host_cls = _jac_standin_class(u.cls)  1051 |     inst = host_cls.__new__(host_cls)  1052 |     # Strong back-reference: while the host holds the stand-in, the`

### LongTest.test_tofromlist (VM-CRASH)

- expected: host oracle = `ok`
- got: `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 |     host_cls = _jac_standin_class(u.cls)  1051 |     inst = host_cls.__new__(host_cls)  1052 |     # Strong back-reference: while the host holds the stand-in, the`

### LongTest.test_type_error (VM-CRASH)

- expected: host oracle = `ok`
- got: `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 |     host_cls = _jac_standin_class(u.cls)  1051 |     inst = host_cls.__new__(host_cls)  1052 |     # Strong back-reference: while the host holds the stand-in, the`

### MiscTest.test_empty (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<"ORACLE_EXC TypeError 'object does not support item assignment'">

### ShortTest.test_assignment (VM-CRASH)

- expected: host oracle = `ok`
- got: `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 |     host_cls = _jac_standin_class(u.cls)  1051 |     inst = host_cls.__new__(host_cls)  1052 |     # Strong back-reference: while the host holds the stand-in, the`

### ShortTest.test_buffer (VM-CRASH)

- expected: host oracle = `ok`
- got: `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 |     host_cls = _jac_standin_class(u.cls)  1051 |     inst = host_cls.__new__(host_cls)  1052 |     # Strong back-reference: while the host holds the stand-in, the`

### ShortTest.test_cmp (VM-CRASH)

- expected: host oracle = `ok`
- got: `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 |     host_cls = _jac_standin_class(u.cls)  1051 |     inst = host_cls.__new__(host_cls)  1052 |     # Strong back-reference: while the host holds the stand-in, the`

### ShortTest.test_constructor_with_iterable_argument (VM-CRASH)

- expected: host oracle = `ok`
- got: `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 |     host_cls = _jac_standin_class(u.cls)  1051 |     inst = host_cls.__new__(host_cls)  1052 |     # Strong back-reference: while the host holds the stand-in, the`

### ShortTest.test_count (VM-CRASH)

- expected: host oracle = `ok`
- got: `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 |     host_cls = _jac_standin_class(u.cls)  1051 |     inst = host_cls.__new__(host_cls)  1052 |     # Strong back-reference: while the host holds the stand-in, the`

### ShortTest.test_create_from_bytes (VM-CRASH)

- expected: host oracle = `ok`
- got: `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 |     host_cls = _jac_standin_class(u.cls)  1051 |     inst = host_cls.__new__(host_cls)  1052 |     # Strong back-reference: while the host holds the stand-in, the`

### ShortTest.test_delitem (VM-CRASH)

- expected: host oracle = `ok`
- got: `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 |     host_cls = _jac_standin_class(u.cls)  1051 |     inst = host_cls.__new__(host_cls)  1052 |     # Strong back-reference: while the host holds the stand-in, the`

### ShortTest.test_delslice (VM-CRASH)

- expected: host oracle = `ok`
- got: `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 |     host_cls = _jac_standin_class(u.cls)  1051 |     inst = host_cls.__new__(host_cls)  1052 |     # Strong back-reference: while the host holds the stand-in, the`

### ShortTest.test_exhausted_iterator (VM-CRASH)

- expected: host oracle = `ok`
- got: `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 |     host_cls = _jac_standin_class(u.cls)  1051 |     inst = host_cls.__new__(host_cls)  1052 |     # Strong back-reference: while the host holds the stand-in, the`

### ShortTest.test_exhausted_reverse_iterator (VM-CRASH)

- expected: host oracle = `ok`
- got: `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 |     host_cls = _jac_standin_class(u.cls)  1051 |     inst = host_cls.__new__(host_cls)  1052 |     # Strong back-reference: while the host holds the stand-in, the`

### ShortTest.test_extended_getslice (VM-CRASH)

- expected: host oracle = `ok`
- got: `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 |     host_cls = _jac_standin_class(u.cls)  1051 |     inst = host_cls.__new__(host_cls)  1052 |     # Strong back-reference: while the host holds the stand-in, the`

### ShortTest.test_extended_set_del_slice (VM-CRASH)

- expected: host oracle = `ok`
- got: `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 |     host_cls = _jac_standin_class(u.cls)  1051 |     inst = host_cls.__new__(host_cls)  1052 |     # Strong back-reference: while the host holds the stand-in, the`

### ShortTest.test_extslice (VM-CRASH)

- expected: host oracle = `ok`
- got: `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 |     host_cls = _jac_standin_class(u.cls)  1051 |     inst = host_cls.__new__(host_cls)  1052 |     # Strong back-reference: while the host holds the stand-in, the`

### ShortTest.test_fromarray (VM-CRASH)

- expected: host oracle = `ok`
- got: `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 |     host_cls = _jac_standin_class(u.cls)  1051 |     inst = host_cls.__new__(host_cls)  1052 |     # Strong back-reference: while the host holds the stand-in, the`

### ShortTest.test_frombytearray (VM-CRASH)

- expected: host oracle = `ok`
- got: `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 |     host_cls = _jac_standin_class(u.cls)  1051 |     inst = host_cls.__new__(host_cls)  1052 |     # Strong back-reference: while the host holds the stand-in, the`

### ShortTest.test_getslice (VM-CRASH)

- expected: host oracle = `ok`
- got: `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 |     host_cls = _jac_standin_class(u.cls)  1051 |     inst = host_cls.__new__(host_cls)  1052 |     # Strong back-reference: while the host holds the stand-in, the`

### ShortTest.test_imul (VM-CRASH)

- expected: host oracle = `ok`
- got: `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 |     host_cls = _jac_standin_class(u.cls)  1051 |     inst = host_cls.__new__(host_cls)  1052 |     # Strong back-reference: while the host holds the stand-in, the`

### ShortTest.test_index (VM-CRASH)

- expected: host oracle = `ok`
- got: `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 |     host_cls = _jac_standin_class(u.cls)  1051 |     inst = host_cls.__new__(host_cls)  1052 |     # Strong back-reference: while the host holds the stand-in, the`

### ShortTest.test_insert (VM-CRASH)

- expected: host oracle = `ok`
- got: `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 |     host_cls = _jac_standin_class(u.cls)  1051 |     inst = host_cls.__new__(host_cls)  1052 |     # Strong back-reference: while the host holds the stand-in, the`

### ShortTest.test_iterationcontains (VM-CRASH)

- expected: host oracle = `ok`
- got: `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 |     host_cls = _jac_standin_class(u.cls)  1051 |     inst = host_cls.__new__(host_cls)  1052 |     # Strong back-reference: while the host holds the stand-in, the`

### ShortTest.test_iterator_pickle (VM-CRASH)

- expected: host oracle = `ok`
- got: `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 |     host_cls = _jac_standin_class(u.cls)  1051 |     inst = host_cls.__new__(host_cls)  1052 |     # Strong back-reference: while the host holds the stand-in, the`

### ShortTest.test_mul (VM-CRASH)

- expected: host oracle = `ok`
- got: `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 |     host_cls = _jac_standin_class(u.cls)  1051 |     inst = host_cls.__new__(host_cls)  1052 |     # Strong back-reference: while the host holds the stand-in, the`

### ShortTest.test_pickle (VM-CRASH)

- expected: host oracle = `ok`
- got: no MARK captured

### ShortTest.test_pickle_for_empty_array (VM-CRASH)

- expected: host oracle = `ok`
- got: `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 |     host_cls = _jac_standin_class(u.cls)  1051 |     inst = host_cls.__new__(host_cls)  1052 |     # Strong back-reference: while the host holds the stand-in, the`

### ShortTest.test_remove (VM-CRASH)

- expected: host oracle = `ok`
- got: `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 |     host_cls = _jac_standin_class(u.cls)  1051 |     inst = host_cls.__new__(host_cls)  1052 |     # Strong back-reference: while the host holds the stand-in, the`

### ShortTest.test_repr (VM-CRASH)

- expected: host oracle = `ok`
- got: `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 |     host_cls = _jac_standin_class(u.cls)  1051 |     inst = host_cls.__new__(host_cls)  1052 |     # Strong back-reference: while the host holds the stand-in, the`

### ShortTest.test_reverse (VM-CRASH)

- expected: host oracle = `ok`
- got: `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 |     host_cls = _jac_standin_class(u.cls)  1051 |     inst = host_cls.__new__(host_cls)  1052 |     # Strong back-reference: while the host holds the stand-in, the`

### ShortTest.test_reverse_iterator (VM-CRASH)

- expected: host oracle = `ok`
- got: `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 |     host_cls = _jac_standin_class(u.cls)  1051 |     inst = host_cls.__new__(host_cls)  1052 |     # Strong back-reference: while the host holds the stand-in, the`

### ShortTest.test_reverse_iterator_picking (VM-CRASH)

- expected: host oracle = `ok`
- got: `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 |     host_cls = _jac_standin_class(u.cls)  1051 |     inst = host_cls.__new__(host_cls)  1052 |     # Strong back-reference: while the host holds the stand-in, the`

### ShortTest.test_str (VM-CRASH)

- expected: host oracle = `ok`
- got: `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 |     host_cls = _jac_standin_class(u.cls)  1051 |     inst = host_cls.__new__(host_cls)  1052 |     # Strong back-reference: while the host holds the stand-in, the`

### ShortTest.test_subclass_with_kwargs (VM-CRASH)

- expected: host oracle = `ok`
- got: `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 |     host_cls = _jac_standin_class(u.cls)  1051 |     inst = host_cls.__new__(host_cls)  1052 |     # Strong back-reference: while the host holds the stand-in, the`

### ShortTest.test_tofrombytes (VM-CRASH)

- expected: host oracle = `ok`
- got: `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 |     host_cls = _jac_standin_class(u.cls)  1051 |     inst = host_cls.__new__(host_cls)  1052 |     # Strong back-reference: while the host holds the stand-in, the`

### ShortTest.test_tofromlist (VM-CRASH)

- expected: host oracle = `ok`
- got: `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 |     host_cls = _jac_standin_class(u.cls)  1051 |     inst = host_cls.__new__(host_cls)  1052 |     # Strong back-reference: while the host holds the stand-in, the`

### ShortTest.test_type_error (VM-CRASH)

- expected: host oracle = `ok`
- got: `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 |     host_cls = _jac_standin_class(u.cls)  1051 |     inst = host_cls.__new__(host_cls)  1052 |     # Strong back-reference: while the host holds the stand-in, the`

### UCS4Test.test_create_from_bytes (VM-CRASH)

- expected: host oracle = `ok`
- got: `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 |     host_cls = _jac_standin_class(u.cls)  1051 |     inst = host_cls.__new__(host_cls)  1052 |     # Strong back-reference: while the host holds the stand-in, the`

### UCS4Test.test_empty_string_mem_leak_gh140474 (VM-CRASH)

- expected: host oracle = `ok`
- got: `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 |     host_cls = _jac_standin_class(u.cls)  1051 |     inst = host_cls.__new__(host_cls)  1052 |     # Strong back-reference: while the host holds the stand-in, the`

### UCS4Test.test_subclass_with_kwargs (VM-CRASH)

- expected: host oracle = `ok`
- got: `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 |     host_cls = _jac_standin_class(u.cls)  1051 |     inst = host_cls.__new__(host_cls)  1052 |     # Strong back-reference: while the host holds the stand-in, the`

### UnsignedByteTest.test_assignment (VM-CRASH)

- expected: host oracle = `ok`
- got: `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 |     host_cls = _jac_standin_class(u.cls)  1051 |     inst = host_cls.__new__(host_cls)  1052 |     # Strong back-reference: while the host holds the stand-in, the`

### UnsignedByteTest.test_buffer (VM-CRASH)

- expected: host oracle = `ok`
- got: `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 |     host_cls = _jac_standin_class(u.cls)  1051 |     inst = host_cls.__new__(host_cls)  1052 |     # Strong back-reference: while the host holds the stand-in, the`

### UnsignedByteTest.test_bytes_extend (VM-CRASH)

- expected: host oracle = `ok`
- got: `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 |     host_cls = _jac_standin_class(u.cls)  1051 |     inst = host_cls.__new__(host_cls)  1052 |     # Strong back-reference: while the host holds the stand-in, the`

### UnsignedByteTest.test_cmp (VM-CRASH)

- expected: host oracle = `ok`
- got: `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 |     host_cls = _jac_standin_class(u.cls)  1051 |     inst = host_cls.__new__(host_cls)  1052 |     # Strong back-reference: while the host holds the stand-in, the`

### UnsignedByteTest.test_constructor_with_iterable_argument (VM-CRASH)

- expected: host oracle = `ok`
- got: `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 |     host_cls = _jac_standin_class(u.cls)  1051 |     inst = host_cls.__new__(host_cls)  1052 |     # Strong back-reference: while the host holds the stand-in, the`

### UnsignedByteTest.test_count (VM-CRASH)

- expected: host oracle = `ok`
- got: `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 |     host_cls = _jac_standin_class(u.cls)  1051 |     inst = host_cls.__new__(host_cls)  1052 |     # Strong back-reference: while the host holds the stand-in, the`

### UnsignedByteTest.test_create_from_bytes (VM-CRASH)

- expected: host oracle = `ok`
- got: `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 |     host_cls = _jac_standin_class(u.cls)  1051 |     inst = host_cls.__new__(host_cls)  1052 |     # Strong back-reference: while the host holds the stand-in, the`

### UnsignedByteTest.test_delitem (VM-CRASH)

- expected: host oracle = `ok`
- got: `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 |     host_cls = _jac_standin_class(u.cls)  1051 |     inst = host_cls.__new__(host_cls)  1052 |     # Strong back-reference: while the host holds the stand-in, the`

### UnsignedByteTest.test_delslice (VM-CRASH)

- expected: host oracle = `ok`
- got: `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 |     host_cls = _jac_standin_class(u.cls)  1051 |     inst = host_cls.__new__(host_cls)  1052 |     # Strong back-reference: while the host holds the stand-in, the`

### UnsignedByteTest.test_exhausted_iterator (VM-CRASH)

- expected: host oracle = `ok`
- got: `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 |     host_cls = _jac_standin_class(u.cls)  1051 |     inst = host_cls.__new__(host_cls)  1052 |     # Strong back-reference: while the host holds the stand-in, the`

### UnsignedByteTest.test_exhausted_reverse_iterator (VM-CRASH)

- expected: host oracle = `ok`
- got: `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 |     host_cls = _jac_standin_class(u.cls)  1051 |     inst = host_cls.__new__(host_cls)  1052 |     # Strong back-reference: while the host holds the stand-in, the`

### UnsignedByteTest.test_extended_getslice (VM-CRASH)

- expected: host oracle = `ok`
- got: `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 |     host_cls = _jac_standin_class(u.cls)  1051 |     inst = host_cls.__new__(host_cls)  1052 |     # Strong back-reference: while the host holds the stand-in, the`

### UnsignedByteTest.test_extended_set_del_slice (VM-CRASH)

- expected: host oracle = `ok`
- got: `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 |     host_cls = _jac_standin_class(u.cls)  1051 |     inst = host_cls.__new__(host_cls)  1052 |     # Strong back-reference: while the host holds the stand-in, the`

### UnsignedByteTest.test_extslice (VM-CRASH)

- expected: host oracle = `ok`
- got: `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 |     host_cls = _jac_standin_class(u.cls)  1051 |     inst = host_cls.__new__(host_cls)  1052 |     # Strong back-reference: while the host holds the stand-in, the`

### UnsignedByteTest.test_fromarray (VM-CRASH)

- expected: host oracle = `ok`
- got: `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 |     host_cls = _jac_standin_class(u.cls)  1051 |     inst = host_cls.__new__(host_cls)  1052 |     # Strong back-reference: while the host holds the stand-in, the`

### UnsignedByteTest.test_frombytearray (VM-CRASH)

- expected: host oracle = `ok`
- got: `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 |     host_cls = _jac_standin_class(u.cls)  1051 |     inst = host_cls.__new__(host_cls)  1052 |     # Strong back-reference: while the host holds the stand-in, the`

### UnsignedByteTest.test_getslice (VM-CRASH)

- expected: host oracle = `ok`
- got: `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 |     host_cls = _jac_standin_class(u.cls)  1051 |     inst = host_cls.__new__(host_cls)  1052 |     # Strong back-reference: while the host holds the stand-in, the`

### UnsignedByteTest.test_imul (VM-CRASH)

- expected: host oracle = `ok`
- got: `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 |     host_cls = _jac_standin_class(u.cls)  1051 |     inst = host_cls.__new__(host_cls)  1052 |     # Strong back-reference: while the host holds the stand-in, the`

### UnsignedByteTest.test_index (VM-CRASH)

- expected: host oracle = `ok`
- got: `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 |     host_cls = _jac_standin_class(u.cls)  1051 |     inst = host_cls.__new__(host_cls)  1052 |     # Strong back-reference: while the host holds the stand-in, the`

### UnsignedByteTest.test_insert (VM-CRASH)

- expected: host oracle = `ok`
- got: `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 |     host_cls = _jac_standin_class(u.cls)  1051 |     inst = host_cls.__new__(host_cls)  1052 |     # Strong back-reference: while the host holds the stand-in, the`

### UnsignedByteTest.test_iterationcontains (VM-CRASH)

- expected: host oracle = `ok`
- got: `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 |     host_cls = _jac_standin_class(u.cls)  1051 |     inst = host_cls.__new__(host_cls)  1052 |     # Strong back-reference: while the host holds the stand-in, the`

### UnsignedByteTest.test_iterator_pickle (VM-CRASH)

- expected: host oracle = `ok`
- got: `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 |     host_cls = _jac_standin_class(u.cls)  1051 |     inst = host_cls.__new__(host_cls)  1052 |     # Strong back-reference: while the host holds the stand-in, the`

### UnsignedByteTest.test_mul (VM-CRASH)

- expected: host oracle = `ok`
- got: `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 |     host_cls = _jac_standin_class(u.cls)  1051 |     inst = host_cls.__new__(host_cls)  1052 |     # Strong back-reference: while the host holds the stand-in, the`

### UnsignedByteTest.test_pickle (VM-CRASH)

- expected: host oracle = `ok`
- got: `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 |     host_cls = _jac_standin_class(u.cls)  1051 |     inst = host_cls.__new__(host_cls)  1052 |     # Strong back-reference: while the host holds the stand-in, the`

### UnsignedByteTest.test_pickle_for_empty_array (VM-CRASH)

- expected: host oracle = `ok`
- got: `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 |     host_cls = _jac_standin_class(u.cls)  1051 |     inst = host_cls.__new__(host_cls)  1052 |     # Strong back-reference: while the host holds the stand-in, the`

### UnsignedByteTest.test_remove (VM-CRASH)

- expected: host oracle = `ok`
- got: `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 |     host_cls = _jac_standin_class(u.cls)  1051 |     inst = host_cls.__new__(host_cls)  1052 |     # Strong back-reference: while the host holds the stand-in, the`

### UnsignedByteTest.test_repr (VM-CRASH)

- expected: host oracle = `ok`
- got: `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 |     host_cls = _jac_standin_class(u.cls)  1051 |     inst = host_cls.__new__(host_cls)  1052 |     # Strong back-reference: while the host holds the stand-in, the`

### UnsignedByteTest.test_reverse (VM-CRASH)

- expected: host oracle = `ok`
- got: `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 |     host_cls = _jac_standin_class(u.cls)  1051 |     inst = host_cls.__new__(host_cls)  1052 |     # Strong back-reference: while the host holds the stand-in, the`

### UnsignedByteTest.test_reverse_iterator (VM-CRASH)

- expected: host oracle = `ok`
- got: `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 |     host_cls = _jac_standin_class(u.cls)  1051 |     inst = host_cls.__new__(host_cls)  1052 |     # Strong back-reference: while the host holds the stand-in, the`

### UnsignedByteTest.test_reverse_iterator_picking (VM-CRASH)

- expected: host oracle = `ok`
- got: `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 |     host_cls = _jac_standin_class(u.cls)  1051 |     inst = host_cls.__new__(host_cls)  1052 |     # Strong back-reference: while the host holds the stand-in, the`

### UnsignedByteTest.test_str (VM-CRASH)

- expected: host oracle = `ok`
- got: `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 |     host_cls = _jac_standin_class(u.cls)  1051 |     inst = host_cls.__new__(host_cls)  1052 |     # Strong back-reference: while the host holds the stand-in, the`

### UnsignedByteTest.test_subclass_with_kwargs (VM-CRASH)

- expected: host oracle = `ok`
- got: `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 |     host_cls = _jac_standin_class(u.cls)  1051 |     inst = host_cls.__new__(host_cls)  1052 |     # Strong back-reference: while the host holds the stand-in, the`

### UnsignedByteTest.test_tofrombytes (VM-CRASH)

- expected: host oracle = `ok`
- got: `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 |     host_cls = _jac_standin_class(u.cls)  1051 |     inst = host_cls.__new__(host_cls)  1052 |     # Strong back-reference: while the host holds the stand-in, the`

### UnsignedByteTest.test_tofromlist (VM-CRASH)

- expected: host oracle = `ok`
- got: `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 |     host_cls = _jac_standin_class(u.cls)  1051 |     inst = host_cls.__new__(host_cls)  1052 |     # Strong back-reference: while the host holds the stand-in, the`

### UnsignedByteTest.test_type_error (VM-CRASH)

- expected: host oracle = `ok`
- got: `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 |     host_cls = _jac_standin_class(u.cls)  1051 |     inst = host_cls.__new__(host_cls)  1052 |     # Strong back-reference: while the host holds the stand-in, the`

### UnsignedIntTest.test_assignment (VM-CRASH)

- expected: host oracle = `ok`
- got: `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 |     host_cls = _jac_standin_class(u.cls)  1051 |     inst = host_cls.__new__(host_cls)  1052 |     # Strong back-reference: while the host holds the stand-in, the`

### UnsignedIntTest.test_buffer (VM-CRASH)

- expected: host oracle = `ok`
- got: `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 |     host_cls = _jac_standin_class(u.cls)  1051 |     inst = host_cls.__new__(host_cls)  1052 |     # Strong back-reference: while the host holds the stand-in, the`

### UnsignedIntTest.test_bytes_extend (VM-CRASH)

- expected: host oracle = `ok`
- got: `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 |     host_cls = _jac_standin_class(u.cls)  1051 |     inst = host_cls.__new__(host_cls)  1052 |     # Strong back-reference: while the host holds the stand-in, the`

### UnsignedIntTest.test_cmp (VM-CRASH)

- expected: host oracle = `ok`
- got: `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 |     host_cls = _jac_standin_class(u.cls)  1051 |     inst = host_cls.__new__(host_cls)  1052 |     # Strong back-reference: while the host holds the stand-in, the`

### UnsignedIntTest.test_constructor_with_iterable_argument (VM-CRASH)

- expected: host oracle = `ok`
- got: `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 |     host_cls = _jac_standin_class(u.cls)  1051 |     inst = host_cls.__new__(host_cls)  1052 |     # Strong back-reference: while the host holds the stand-in, the`

### UnsignedIntTest.test_count (VM-CRASH)

- expected: host oracle = `ok`
- got: `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 |     host_cls = _jac_standin_class(u.cls)  1051 |     inst = host_cls.__new__(host_cls)  1052 |     # Strong back-reference: while the host holds the stand-in, the`

### UnsignedIntTest.test_create_from_bytes (VM-CRASH)

- expected: host oracle = `ok`
- got: `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 |     host_cls = _jac_standin_class(u.cls)  1051 |     inst = host_cls.__new__(host_cls)  1052 |     # Strong back-reference: while the host holds the stand-in, the`

### UnsignedIntTest.test_delitem (VM-CRASH)

- expected: host oracle = `ok`
- got: `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 |     host_cls = _jac_standin_class(u.cls)  1051 |     inst = host_cls.__new__(host_cls)  1052 |     # Strong back-reference: while the host holds the stand-in, the`

### UnsignedIntTest.test_delslice (VM-CRASH)

- expected: host oracle = `ok`
- got: `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 |     host_cls = _jac_standin_class(u.cls)  1051 |     inst = host_cls.__new__(host_cls)  1052 |     # Strong back-reference: while the host holds the stand-in, the`

### UnsignedIntTest.test_exhausted_iterator (VM-CRASH)

- expected: host oracle = `ok`
- got: `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 |     host_cls = _jac_standin_class(u.cls)  1051 |     inst = host_cls.__new__(host_cls)  1052 |     # Strong back-reference: while the host holds the stand-in, the`

### UnsignedIntTest.test_exhausted_reverse_iterator (VM-CRASH)

- expected: host oracle = `ok`
- got: `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 |     host_cls = _jac_standin_class(u.cls)  1051 |     inst = host_cls.__new__(host_cls)  1052 |     # Strong back-reference: while the host holds the stand-in, the`

### UnsignedIntTest.test_extended_getslice (VM-CRASH)

- expected: host oracle = `ok`
- got: `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 |     host_cls = _jac_standin_class(u.cls)  1051 |     inst = host_cls.__new__(host_cls)  1052 |     # Strong back-reference: while the host holds the stand-in, the`

### UnsignedIntTest.test_extended_set_del_slice (VM-CRASH)

- expected: host oracle = `ok`
- got: `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 |     host_cls = _jac_standin_class(u.cls)  1051 |     inst = host_cls.__new__(host_cls)  1052 |     # Strong back-reference: while the host holds the stand-in, the`

### UnsignedIntTest.test_extslice (VM-CRASH)

- expected: host oracle = `ok`
- got: `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 |     host_cls = _jac_standin_class(u.cls)  1051 |     inst = host_cls.__new__(host_cls)  1052 |     # Strong back-reference: while the host holds the stand-in, the`

### UnsignedIntTest.test_fromarray (VM-CRASH)

- expected: host oracle = `ok`
- got: `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 |     host_cls = _jac_standin_class(u.cls)  1051 |     inst = host_cls.__new__(host_cls)  1052 |     # Strong back-reference: while the host holds the stand-in, the`

### UnsignedIntTest.test_frombytearray (VM-CRASH)

- expected: host oracle = `ok`
- got: `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 |     host_cls = _jac_standin_class(u.cls)  1051 |     inst = host_cls.__new__(host_cls)  1052 |     # Strong back-reference: while the host holds the stand-in, the`

### UnsignedIntTest.test_getslice (VM-CRASH)

- expected: host oracle = `ok`
- got: `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 |     host_cls = _jac_standin_class(u.cls)  1051 |     inst = host_cls.__new__(host_cls)  1052 |     # Strong back-reference: while the host holds the stand-in, the`

### UnsignedIntTest.test_imul (VM-CRASH)

- expected: host oracle = `ok`
- got: `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 |     host_cls = _jac_standin_class(u.cls)  1051 |     inst = host_cls.__new__(host_cls)  1052 |     # Strong back-reference: while the host holds the stand-in, the`

### UnsignedIntTest.test_index (VM-CRASH)

- expected: host oracle = `ok`
- got: `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 |     host_cls = _jac_standin_class(u.cls)  1051 |     inst = host_cls.__new__(host_cls)  1052 |     # Strong back-reference: while the host holds the stand-in, the`

### UnsignedIntTest.test_insert (VM-CRASH)

- expected: host oracle = `ok`
- got: `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 |     host_cls = _jac_standin_class(u.cls)  1051 |     inst = host_cls.__new__(host_cls)  1052 |     # Strong back-reference: while the host holds the stand-in, the`

### UnsignedIntTest.test_iterationcontains (VM-CRASH)

- expected: host oracle = `ok`
- got: `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 |     host_cls = _jac_standin_class(u.cls)  1051 |     inst = host_cls.__new__(host_cls)  1052 |     # Strong back-reference: while the host holds the stand-in, the`

### UnsignedIntTest.test_iterator_pickle (VM-CRASH)

- expected: host oracle = `ok`
- got: `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 |     host_cls = _jac_standin_class(u.cls)  1051 |     inst = host_cls.__new__(host_cls)  1052 |     # Strong back-reference: while the host holds the stand-in, the`

### UnsignedIntTest.test_mul (VM-CRASH)

- expected: host oracle = `ok`
- got: `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 |     host_cls = _jac_standin_class(u.cls)  1051 |     inst = host_cls.__new__(host_cls)  1052 |     # Strong back-reference: while the host holds the stand-in, the`

### UnsignedIntTest.test_pickle (VM-CRASH)

- expected: host oracle = `ok`
- got: `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 |     host_cls = _jac_standin_class(u.cls)  1051 |     inst = host_cls.__new__(host_cls)  1052 |     # Strong back-reference: while the host holds the stand-in, the`

### UnsignedIntTest.test_pickle_for_empty_array (VM-CRASH)

- expected: host oracle = `ok`
- got: `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 |     host_cls = _jac_standin_class(u.cls)  1051 |     inst = host_cls.__new__(host_cls)  1052 |     # Strong back-reference: while the host holds the stand-in, the`

### UnsignedIntTest.test_remove (VM-CRASH)

- expected: host oracle = `ok`
- got: `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 |     host_cls = _jac_standin_class(u.cls)  1051 |     inst = host_cls.__new__(host_cls)  1052 |     # Strong back-reference: while the host holds the stand-in, the`

### UnsignedIntTest.test_repr (VM-CRASH)

- expected: host oracle = `ok`
- got: `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 |     host_cls = _jac_standin_class(u.cls)  1051 |     inst = host_cls.__new__(host_cls)  1052 |     # Strong back-reference: while the host holds the stand-in, the`

### UnsignedIntTest.test_reverse (VM-CRASH)

- expected: host oracle = `ok`
- got: `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 |     host_cls = _jac_standin_class(u.cls)  1051 |     inst = host_cls.__new__(host_cls)  1052 |     # Strong back-reference: while the host holds the stand-in, the`

### UnsignedIntTest.test_reverse_iterator (VM-CRASH)

- expected: host oracle = `ok`
- got: `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 |     host_cls = _jac_standin_class(u.cls)  1051 |     inst = host_cls.__new__(host_cls)  1052 |     # Strong back-reference: while the host holds the stand-in, the`

### UnsignedIntTest.test_reverse_iterator_picking (VM-CRASH)

- expected: host oracle = `ok`
- got: `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 |     host_cls = _jac_standin_class(u.cls)  1051 |     inst = host_cls.__new__(host_cls)  1052 |     # Strong back-reference: while the host holds the stand-in, the`

### UnsignedIntTest.test_str (VM-CRASH)

- expected: host oracle = `ok`
- got: `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 |     host_cls = _jac_standin_class(u.cls)  1051 |     inst = host_cls.__new__(host_cls)  1052 |     # Strong back-reference: while the host holds the stand-in, the`

### UnsignedIntTest.test_subclass_with_kwargs (VM-CRASH)

- expected: host oracle = `ok`
- got: `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 |     host_cls = _jac_standin_class(u.cls)  1051 |     inst = host_cls.__new__(host_cls)  1052 |     # Strong back-reference: while the host holds the stand-in, the`

### UnsignedIntTest.test_tofrombytes (VM-CRASH)

- expected: host oracle = `ok`
- got: `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 |     host_cls = _jac_standin_class(u.cls)  1051 |     inst = host_cls.__new__(host_cls)  1052 |     # Strong back-reference: while the host holds the stand-in, the`

### UnsignedIntTest.test_tofromlist (VM-CRASH)

- expected: host oracle = `ok`
- got: `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 |     host_cls = _jac_standin_class(u.cls)  1051 |     inst = host_cls.__new__(host_cls)  1052 |     # Strong back-reference: while the host holds the stand-in, the`

### UnsignedIntTest.test_type_error (VM-CRASH)

- expected: host oracle = `ok`
- got: `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 |     host_cls = _jac_standin_class(u.cls)  1051 |     inst = host_cls.__new__(host_cls)  1052 |     # Strong back-reference: while the host holds the stand-in, the`

### UnsignedLongLongTest.test_assignment (VM-CRASH)

- expected: host oracle = `ok`
- got: `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 |     host_cls = _jac_standin_class(u.cls)  1051 |     inst = host_cls.__new__(host_cls)  1052 |     # Strong back-reference: while the host holds the stand-in, the`

### UnsignedLongLongTest.test_buffer (VM-CRASH)

- expected: host oracle = `ok`
- got: `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 |     host_cls = _jac_standin_class(u.cls)  1051 |     inst = host_cls.__new__(host_cls)  1052 |     # Strong back-reference: while the host holds the stand-in, the`

### UnsignedLongLongTest.test_bytes_extend (VM-CRASH)

- expected: host oracle = `ok`
- got: `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 |     host_cls = _jac_standin_class(u.cls)  1051 |     inst = host_cls.__new__(host_cls)  1052 |     # Strong back-reference: while the host holds the stand-in, the`

### UnsignedLongLongTest.test_cmp (VM-CRASH)

- expected: host oracle = `ok`
- got: `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 |     host_cls = _jac_standin_class(u.cls)  1051 |     inst = host_cls.__new__(host_cls)  1052 |     # Strong back-reference: while the host holds the stand-in, the`

### UnsignedLongLongTest.test_constructor_with_iterable_argument (VM-CRASH)

- expected: host oracle = `ok`
- got: `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 |     host_cls = _jac_standin_class(u.cls)  1051 |     inst = host_cls.__new__(host_cls)  1052 |     # Strong back-reference: while the host holds the stand-in, the`

### UnsignedLongLongTest.test_count (VM-CRASH)

- expected: host oracle = `ok`
- got: `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 |     host_cls = _jac_standin_class(u.cls)  1051 |     inst = host_cls.__new__(host_cls)  1052 |     # Strong back-reference: while the host holds the stand-in, the`

### UnsignedLongLongTest.test_create_from_bytes (VM-CRASH)

- expected: host oracle = `ok`
- got: `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 |     host_cls = _jac_standin_class(u.cls)  1051 |     inst = host_cls.__new__(host_cls)  1052 |     # Strong back-reference: while the host holds the stand-in, the`

### UnsignedLongLongTest.test_delitem (VM-CRASH)

- expected: host oracle = `ok`
- got: `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 |     host_cls = _jac_standin_class(u.cls)  1051 |     inst = host_cls.__new__(host_cls)  1052 |     # Strong back-reference: while the host holds the stand-in, the`

### UnsignedLongLongTest.test_delslice (VM-CRASH)

- expected: host oracle = `ok`
- got: `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 |     host_cls = _jac_standin_class(u.cls)  1051 |     inst = host_cls.__new__(host_cls)  1052 |     # Strong back-reference: while the host holds the stand-in, the`

### UnsignedLongLongTest.test_exhausted_iterator (VM-CRASH)

- expected: host oracle = `ok`
- got: `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 |     host_cls = _jac_standin_class(u.cls)  1051 |     inst = host_cls.__new__(host_cls)  1052 |     # Strong back-reference: while the host holds the stand-in, the`

### UnsignedLongLongTest.test_exhausted_reverse_iterator (VM-CRASH)

- expected: host oracle = `ok`
- got: `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 |     host_cls = _jac_standin_class(u.cls)  1051 |     inst = host_cls.__new__(host_cls)  1052 |     # Strong back-reference: while the host holds the stand-in, the`

### UnsignedLongLongTest.test_extended_getslice (VM-CRASH)

- expected: host oracle = `ok`
- got: `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 |     host_cls = _jac_standin_class(u.cls)  1051 |     inst = host_cls.__new__(host_cls)  1052 |     # Strong back-reference: while the host holds the stand-in, the`

### UnsignedLongLongTest.test_extended_set_del_slice (VM-CRASH)

- expected: host oracle = `ok`
- got: `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 |     host_cls = _jac_standin_class(u.cls)  1051 |     inst = host_cls.__new__(host_cls)  1052 |     # Strong back-reference: while the host holds the stand-in, the`

### UnsignedLongLongTest.test_extslice (VM-CRASH)

- expected: host oracle = `ok`
- got: `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 |     host_cls = _jac_standin_class(u.cls)  1051 |     inst = host_cls.__new__(host_cls)  1052 |     # Strong back-reference: while the host holds the stand-in, the`

### UnsignedLongLongTest.test_fromarray (VM-CRASH)

- expected: host oracle = `ok`
- got: `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 |     host_cls = _jac_standin_class(u.cls)  1051 |     inst = host_cls.__new__(host_cls)  1052 |     # Strong back-reference: while the host holds the stand-in, the`

### UnsignedLongLongTest.test_frombytearray (VM-CRASH)

- expected: host oracle = `ok`
- got: `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 |     host_cls = _jac_standin_class(u.cls)  1051 |     inst = host_cls.__new__(host_cls)  1052 |     # Strong back-reference: while the host holds the stand-in, the`

### UnsignedLongLongTest.test_getslice (VM-CRASH)

- expected: host oracle = `ok`
- got: `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 |     host_cls = _jac_standin_class(u.cls)  1051 |     inst = host_cls.__new__(host_cls)  1052 |     # Strong back-reference: while the host holds the stand-in, the`

### UnsignedLongLongTest.test_imul (VM-CRASH)

- expected: host oracle = `ok`
- got: `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 |     host_cls = _jac_standin_class(u.cls)  1051 |     inst = host_cls.__new__(host_cls)  1052 |     # Strong back-reference: while the host holds the stand-in, the`

### UnsignedLongLongTest.test_index (VM-CRASH)

- expected: host oracle = `ok`
- got: `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 |     host_cls = _jac_standin_class(u.cls)  1051 |     inst = host_cls.__new__(host_cls)  1052 |     # Strong back-reference: while the host holds the stand-in, the`

### UnsignedLongLongTest.test_insert (VM-CRASH)

- expected: host oracle = `ok`
- got: `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 |     host_cls = _jac_standin_class(u.cls)  1051 |     inst = host_cls.__new__(host_cls)  1052 |     # Strong back-reference: while the host holds the stand-in, the`

### UnsignedLongLongTest.test_iterationcontains (VM-CRASH)

- expected: host oracle = `ok`
- got: `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 |     host_cls = _jac_standin_class(u.cls)  1051 |     inst = host_cls.__new__(host_cls)  1052 |     # Strong back-reference: while the host holds the stand-in, the`

### UnsignedLongLongTest.test_iterator_pickle (VM-CRASH)

- expected: host oracle = `ok`
- got: `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 |     host_cls = _jac_standin_class(u.cls)  1051 |     inst = host_cls.__new__(host_cls)  1052 |     # Strong back-reference: while the host holds the stand-in, the`

### UnsignedLongLongTest.test_mul (VM-CRASH)

- expected: host oracle = `ok`
- got: `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 |     host_cls = _jac_standin_class(u.cls)  1051 |     inst = host_cls.__new__(host_cls)  1052 |     # Strong back-reference: while the host holds the stand-in, the`

### UnsignedLongLongTest.test_pickle (VM-CRASH)

- expected: host oracle = `ok`
- got: `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 |     host_cls = _jac_standin_class(u.cls)  1051 |     inst = host_cls.__new__(host_cls)  1052 |     # Strong back-reference: while the host holds the stand-in, the`

### UnsignedLongLongTest.test_pickle_for_empty_array (VM-CRASH)

- expected: host oracle = `ok`
- got: `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 |     host_cls = _jac_standin_class(u.cls)  1051 |     inst = host_cls.__new__(host_cls)  1052 |     # Strong back-reference: while the host holds the stand-in, the`

### UnsignedLongLongTest.test_remove (VM-CRASH)

- expected: host oracle = `ok`
- got: `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 |     host_cls = _jac_standin_class(u.cls)  1051 |     inst = host_cls.__new__(host_cls)  1052 |     # Strong back-reference: while the host holds the stand-in, the`

### UnsignedLongLongTest.test_repr (VM-CRASH)

- expected: host oracle = `ok`
- got: `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 |     host_cls = _jac_standin_class(u.cls)  1051 |     inst = host_cls.__new__(host_cls)  1052 |     # Strong back-reference: while the host holds the stand-in, the`

### UnsignedLongLongTest.test_reverse (VM-CRASH)

- expected: host oracle = `ok`
- got: `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 |     host_cls = _jac_standin_class(u.cls)  1051 |     inst = host_cls.__new__(host_cls)  1052 |     # Strong back-reference: while the host holds the stand-in, the`

### UnsignedLongLongTest.test_reverse_iterator (VM-CRASH)

- expected: host oracle = `ok`
- got: `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 |     host_cls = _jac_standin_class(u.cls)  1051 |     inst = host_cls.__new__(host_cls)  1052 |     # Strong back-reference: while the host holds the stand-in, the`

### UnsignedLongLongTest.test_reverse_iterator_picking (VM-CRASH)

- expected: host oracle = `ok`
- got: `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 |     host_cls = _jac_standin_class(u.cls)  1051 |     inst = host_cls.__new__(host_cls)  1052 |     # Strong back-reference: while the host holds the stand-in, the`

### UnsignedLongLongTest.test_str (VM-CRASH)

- expected: host oracle = `ok`
- got: `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 |     host_cls = _jac_standin_class(u.cls)  1051 |     inst = host_cls.__new__(host_cls)  1052 |     # Strong back-reference: while the host holds the stand-in, the`

### UnsignedLongLongTest.test_subclass_with_kwargs (VM-CRASH)

- expected: host oracle = `ok`
- got: `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 |     host_cls = _jac_standin_class(u.cls)  1051 |     inst = host_cls.__new__(host_cls)  1052 |     # Strong back-reference: while the host holds the stand-in, the`

### UnsignedLongLongTest.test_tofrombytes (VM-CRASH)

- expected: host oracle = `ok`
- got: `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 |     host_cls = _jac_standin_class(u.cls)  1051 |     inst = host_cls.__new__(host_cls)  1052 |     # Strong back-reference: while the host holds the stand-in, the`

### UnsignedLongLongTest.test_tofromlist (VM-CRASH)

- expected: host oracle = `ok`
- got: `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 |     host_cls = _jac_standin_class(u.cls)  1051 |     inst = host_cls.__new__(host_cls)  1052 |     # Strong back-reference: while the host holds the stand-in, the`

### UnsignedLongLongTest.test_type_error (VM-CRASH)

- expected: host oracle = `ok`
- got: `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 |     host_cls = _jac_standin_class(u.cls)  1051 |     inst = host_cls.__new__(host_cls)  1052 |     # Strong back-reference: while the host holds the stand-in, the`

### UnsignedLongTest.test_assignment (VM-CRASH)

- expected: host oracle = `ok`
- got: `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 |     host_cls = _jac_standin_class(u.cls)  1051 |     inst = host_cls.__new__(host_cls)  1052 |     # Strong back-reference: while the host holds the stand-in, the`

### UnsignedLongTest.test_buffer (VM-CRASH)

- expected: host oracle = `ok`
- got: `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 |     host_cls = _jac_standin_class(u.cls)  1051 |     inst = host_cls.__new__(host_cls)  1052 |     # Strong back-reference: while the host holds the stand-in, the`

### UnsignedLongTest.test_bytes_extend (VM-CRASH)

- expected: host oracle = `ok`
- got: `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 |     host_cls = _jac_standin_class(u.cls)  1051 |     inst = host_cls.__new__(host_cls)  1052 |     # Strong back-reference: while the host holds the stand-in, the`

### UnsignedLongTest.test_cmp (VM-CRASH)

- expected: host oracle = `ok`
- got: `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 |     host_cls = _jac_standin_class(u.cls)  1051 |     inst = host_cls.__new__(host_cls)  1052 |     # Strong back-reference: while the host holds the stand-in, the`

### UnsignedLongTest.test_constructor_with_iterable_argument (VM-CRASH)

- expected: host oracle = `ok`
- got: `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 |     host_cls = _jac_standin_class(u.cls)  1051 |     inst = host_cls.__new__(host_cls)  1052 |     # Strong back-reference: while the host holds the stand-in, the`

### UnsignedLongTest.test_count (VM-CRASH)

- expected: host oracle = `ok`
- got: `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 |     host_cls = _jac_standin_class(u.cls)  1051 |     inst = host_cls.__new__(host_cls)  1052 |     # Strong back-reference: while the host holds the stand-in, the`

### UnsignedLongTest.test_create_from_bytes (VM-CRASH)

- expected: host oracle = `ok`
- got: `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 |     host_cls = _jac_standin_class(u.cls)  1051 |     inst = host_cls.__new__(host_cls)  1052 |     # Strong back-reference: while the host holds the stand-in, the`

### UnsignedLongTest.test_delitem (VM-CRASH)

- expected: host oracle = `ok`
- got: `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 |     host_cls = _jac_standin_class(u.cls)  1051 |     inst = host_cls.__new__(host_cls)  1052 |     # Strong back-reference: while the host holds the stand-in, the`

### UnsignedLongTest.test_delslice (VM-CRASH)

- expected: host oracle = `ok`
- got: `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 |     host_cls = _jac_standin_class(u.cls)  1051 |     inst = host_cls.__new__(host_cls)  1052 |     # Strong back-reference: while the host holds the stand-in, the`

### UnsignedLongTest.test_exhausted_iterator (VM-CRASH)

- expected: host oracle = `ok`
- got: `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 |     host_cls = _jac_standin_class(u.cls)  1051 |     inst = host_cls.__new__(host_cls)  1052 |     # Strong back-reference: while the host holds the stand-in, the`

### UnsignedLongTest.test_exhausted_reverse_iterator (VM-CRASH)

- expected: host oracle = `ok`
- got: `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 |     host_cls = _jac_standin_class(u.cls)  1051 |     inst = host_cls.__new__(host_cls)  1052 |     # Strong back-reference: while the host holds the stand-in, the`

### UnsignedLongTest.test_extended_getslice (VM-CRASH)

- expected: host oracle = `ok`
- got: `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 |     host_cls = _jac_standin_class(u.cls)  1051 |     inst = host_cls.__new__(host_cls)  1052 |     # Strong back-reference: while the host holds the stand-in, the`

### UnsignedLongTest.test_extended_set_del_slice (VM-CRASH)

- expected: host oracle = `ok`
- got: `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 |     host_cls = _jac_standin_class(u.cls)  1051 |     inst = host_cls.__new__(host_cls)  1052 |     # Strong back-reference: while the host holds the stand-in, the`

### UnsignedLongTest.test_extslice (VM-CRASH)

- expected: host oracle = `ok`
- got: `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 |     host_cls = _jac_standin_class(u.cls)  1051 |     inst = host_cls.__new__(host_cls)  1052 |     # Strong back-reference: while the host holds the stand-in, the`

### UnsignedLongTest.test_fromarray (VM-CRASH)

- expected: host oracle = `ok`
- got: `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 |     host_cls = _jac_standin_class(u.cls)  1051 |     inst = host_cls.__new__(host_cls)  1052 |     # Strong back-reference: while the host holds the stand-in, the`

### UnsignedLongTest.test_frombytearray (VM-CRASH)

- expected: host oracle = `ok`
- got: `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 |     host_cls = _jac_standin_class(u.cls)  1051 |     inst = host_cls.__new__(host_cls)  1052 |     # Strong back-reference: while the host holds the stand-in, the`

### UnsignedLongTest.test_getslice (VM-CRASH)

- expected: host oracle = `ok`
- got: `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 |     host_cls = _jac_standin_class(u.cls)  1051 |     inst = host_cls.__new__(host_cls)  1052 |     # Strong back-reference: while the host holds the stand-in, the`

### UnsignedLongTest.test_imul (VM-CRASH)

- expected: host oracle = `ok`
- got: `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 |     host_cls = _jac_standin_class(u.cls)  1051 |     inst = host_cls.__new__(host_cls)  1052 |     # Strong back-reference: while the host holds the stand-in, the`

### UnsignedLongTest.test_index (VM-CRASH)

- expected: host oracle = `ok`
- got: `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 |     host_cls = _jac_standin_class(u.cls)  1051 |     inst = host_cls.__new__(host_cls)  1052 |     # Strong back-reference: while the host holds the stand-in, the`

### UnsignedLongTest.test_insert (VM-CRASH)

- expected: host oracle = `ok`
- got: `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 |     host_cls = _jac_standin_class(u.cls)  1051 |     inst = host_cls.__new__(host_cls)  1052 |     # Strong back-reference: while the host holds the stand-in, the`

### UnsignedLongTest.test_iterationcontains (VM-CRASH)

- expected: host oracle = `ok`
- got: `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 |     host_cls = _jac_standin_class(u.cls)  1051 |     inst = host_cls.__new__(host_cls)  1052 |     # Strong back-reference: while the host holds the stand-in, the`

### UnsignedLongTest.test_iterator_pickle (VM-CRASH)

- expected: host oracle = `ok`
- got: `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 |     host_cls = _jac_standin_class(u.cls)  1051 |     inst = host_cls.__new__(host_cls)  1052 |     # Strong back-reference: while the host holds the stand-in, the`

### UnsignedLongTest.test_mul (VM-CRASH)

- expected: host oracle = `ok`
- got: `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 |     host_cls = _jac_standin_class(u.cls)  1051 |     inst = host_cls.__new__(host_cls)  1052 |     # Strong back-reference: while the host holds the stand-in, the`

### UnsignedLongTest.test_pickle (VM-CRASH)

- expected: host oracle = `ok`
- got: `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 |     host_cls = _jac_standin_class(u.cls)  1051 |     inst = host_cls.__new__(host_cls)  1052 |     # Strong back-reference: while the host holds the stand-in, the`

### UnsignedLongTest.test_pickle_for_empty_array (VM-CRASH)

- expected: host oracle = `ok`
- got: `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 |     host_cls = _jac_standin_class(u.cls)  1051 |     inst = host_cls.__new__(host_cls)  1052 |     # Strong back-reference: while the host holds the stand-in, the`

### UnsignedLongTest.test_remove (VM-CRASH)

- expected: host oracle = `ok`
- got: `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 |     host_cls = _jac_standin_class(u.cls)  1051 |     inst = host_cls.__new__(host_cls)  1052 |     # Strong back-reference: while the host holds the stand-in, the`

### UnsignedLongTest.test_repr (VM-CRASH)

- expected: host oracle = `ok`
- got: `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 |     host_cls = _jac_standin_class(u.cls)  1051 |     inst = host_cls.__new__(host_cls)  1052 |     # Strong back-reference: while the host holds the stand-in, the`

### UnsignedLongTest.test_reverse (VM-CRASH)

- expected: host oracle = `ok`
- got: `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 |     host_cls = _jac_standin_class(u.cls)  1051 |     inst = host_cls.__new__(host_cls)  1052 |     # Strong back-reference: while the host holds the stand-in, the`

### UnsignedLongTest.test_reverse_iterator (VM-CRASH)

- expected: host oracle = `ok`
- got: `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 |     host_cls = _jac_standin_class(u.cls)  1051 |     inst = host_cls.__new__(host_cls)  1052 |     # Strong back-reference: while the host holds the stand-in, the`

### UnsignedLongTest.test_reverse_iterator_picking (VM-CRASH)

- expected: host oracle = `ok`
- got: `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 |     host_cls = _jac_standin_class(u.cls)  1051 |     inst = host_cls.__new__(host_cls)  1052 |     # Strong back-reference: while the host holds the stand-in, the`

### UnsignedLongTest.test_str (VM-CRASH)

- expected: host oracle = `ok`
- got: `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 |     host_cls = _jac_standin_class(u.cls)  1051 |     inst = host_cls.__new__(host_cls)  1052 |     # Strong back-reference: while the host holds the stand-in, the`

### UnsignedLongTest.test_subclass_with_kwargs (VM-CRASH)

- expected: host oracle = `ok`
- got: `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 |     host_cls = _jac_standin_class(u.cls)  1051 |     inst = host_cls.__new__(host_cls)  1052 |     # Strong back-reference: while the host holds the stand-in, the`

### UnsignedLongTest.test_tofrombytes (VM-CRASH)

- expected: host oracle = `ok`
- got: `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 |     host_cls = _jac_standin_class(u.cls)  1051 |     inst = host_cls.__new__(host_cls)  1052 |     # Strong back-reference: while the host holds the stand-in, the`

### UnsignedLongTest.test_tofromlist (VM-CRASH)

- expected: host oracle = `ok`
- got: `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 |     host_cls = _jac_standin_class(u.cls)  1051 |     inst = host_cls.__new__(host_cls)  1052 |     # Strong back-reference: while the host holds the stand-in, the`

### UnsignedLongTest.test_type_error (VM-CRASH)

- expected: host oracle = `ok`
- got: `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 |     host_cls = _jac_standin_class(u.cls)  1051 |     inst = host_cls.__new__(host_cls)  1052 |     # Strong back-reference: while the host holds the stand-in, the`

### UnsignedShortTest.test_assignment (VM-CRASH)

- expected: host oracle = `ok`
- got: `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 |     host_cls = _jac_standin_class(u.cls)  1051 |     inst = host_cls.__new__(host_cls)  1052 |     # Strong back-reference: while the host holds the stand-in, the`

### UnsignedShortTest.test_buffer (VM-CRASH)

- expected: host oracle = `ok`
- got: `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 |     host_cls = _jac_standin_class(u.cls)  1051 |     inst = host_cls.__new__(host_cls)  1052 |     # Strong back-reference: while the host holds the stand-in, the`

### UnsignedShortTest.test_bytes_extend (VM-CRASH)

- expected: host oracle = `ok`
- got: `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 |     host_cls = _jac_standin_class(u.cls)  1051 |     inst = host_cls.__new__(host_cls)  1052 |     # Strong back-reference: while the host holds the stand-in, the`

### UnsignedShortTest.test_cmp (VM-CRASH)

- expected: host oracle = `ok`
- got: `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 |     host_cls = _jac_standin_class(u.cls)  1051 |     inst = host_cls.__new__(host_cls)  1052 |     # Strong back-reference: while the host holds the stand-in, the`

### UnsignedShortTest.test_constructor_with_iterable_argument (VM-CRASH)

- expected: host oracle = `ok`
- got: `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 |     host_cls = _jac_standin_class(u.cls)  1051 |     inst = host_cls.__new__(host_cls)  1052 |     # Strong back-reference: while the host holds the stand-in, the`

### UnsignedShortTest.test_count (VM-CRASH)

- expected: host oracle = `ok`
- got: `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 |     host_cls = _jac_standin_class(u.cls)  1051 |     inst = host_cls.__new__(host_cls)  1052 |     # Strong back-reference: while the host holds the stand-in, the`

### UnsignedShortTest.test_create_from_bytes (VM-CRASH)

- expected: host oracle = `ok`
- got: `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 |     host_cls = _jac_standin_class(u.cls)  1051 |     inst = host_cls.__new__(host_cls)  1052 |     # Strong back-reference: while the host holds the stand-in, the`

### UnsignedShortTest.test_delitem (VM-CRASH)

- expected: host oracle = `ok`
- got: `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 |     host_cls = _jac_standin_class(u.cls)  1051 |     inst = host_cls.__new__(host_cls)  1052 |     # Strong back-reference: while the host holds the stand-in, the`

### UnsignedShortTest.test_delslice (VM-CRASH)

- expected: host oracle = `ok`
- got: `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 |     host_cls = _jac_standin_class(u.cls)  1051 |     inst = host_cls.__new__(host_cls)  1052 |     # Strong back-reference: while the host holds the stand-in, the`

### UnsignedShortTest.test_exhausted_iterator (VM-CRASH)

- expected: host oracle = `ok`
- got: `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 |     host_cls = _jac_standin_class(u.cls)  1051 |     inst = host_cls.__new__(host_cls)  1052 |     # Strong back-reference: while the host holds the stand-in, the`

### UnsignedShortTest.test_exhausted_reverse_iterator (VM-CRASH)

- expected: host oracle = `ok`
- got: `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 |     host_cls = _jac_standin_class(u.cls)  1051 |     inst = host_cls.__new__(host_cls)  1052 |     # Strong back-reference: while the host holds the stand-in, the`

### UnsignedShortTest.test_extended_getslice (VM-CRASH)

- expected: host oracle = `ok`
- got: `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 |     host_cls = _jac_standin_class(u.cls)  1051 |     inst = host_cls.__new__(host_cls)  1052 |     # Strong back-reference: while the host holds the stand-in, the`

### UnsignedShortTest.test_extended_set_del_slice (VM-CRASH)

- expected: host oracle = `ok`
- got: `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 |     host_cls = _jac_standin_class(u.cls)  1051 |     inst = host_cls.__new__(host_cls)  1052 |     # Strong back-reference: while the host holds the stand-in, the`

### UnsignedShortTest.test_extslice (VM-CRASH)

- expected: host oracle = `ok`
- got: `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 |     host_cls = _jac_standin_class(u.cls)  1051 |     inst = host_cls.__new__(host_cls)  1052 |     # Strong back-reference: while the host holds the stand-in, the`

### UnsignedShortTest.test_fromarray (VM-CRASH)

- expected: host oracle = `ok`
- got: `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 |     host_cls = _jac_standin_class(u.cls)  1051 |     inst = host_cls.__new__(host_cls)  1052 |     # Strong back-reference: while the host holds the stand-in, the`

### UnsignedShortTest.test_frombytearray (VM-CRASH)

- expected: host oracle = `ok`
- got: `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 |     host_cls = _jac_standin_class(u.cls)  1051 |     inst = host_cls.__new__(host_cls)  1052 |     # Strong back-reference: while the host holds the stand-in, the`

### UnsignedShortTest.test_getslice (VM-CRASH)

- expected: host oracle = `ok`
- got: `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 |     host_cls = _jac_standin_class(u.cls)  1051 |     inst = host_cls.__new__(host_cls)  1052 |     # Strong back-reference: while the host holds the stand-in, the`

### UnsignedShortTest.test_imul (VM-CRASH)

- expected: host oracle = `ok`
- got: `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 |     host_cls = _jac_standin_class(u.cls)  1051 |     inst = host_cls.__new__(host_cls)  1052 |     # Strong back-reference: while the host holds the stand-in, the`

### UnsignedShortTest.test_index (VM-CRASH)

- expected: host oracle = `ok`
- got: `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 |     host_cls = _jac_standin_class(u.cls)  1051 |     inst = host_cls.__new__(host_cls)  1052 |     # Strong back-reference: while the host holds the stand-in, the`

### UnsignedShortTest.test_insert (VM-CRASH)

- expected: host oracle = `ok`
- got: `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 |     host_cls = _jac_standin_class(u.cls)  1051 |     inst = host_cls.__new__(host_cls)  1052 |     # Strong back-reference: while the host holds the stand-in, the`

### UnsignedShortTest.test_iterationcontains (VM-CRASH)

- expected: host oracle = `ok`
- got: `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 |     host_cls = _jac_standin_class(u.cls)  1051 |     inst = host_cls.__new__(host_cls)  1052 |     # Strong back-reference: while the host holds the stand-in, the`

### UnsignedShortTest.test_iterator_pickle (VM-CRASH)

- expected: host oracle = `ok`
- got: `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 |     host_cls = _jac_standin_class(u.cls)  1051 |     inst = host_cls.__new__(host_cls)  1052 |     # Strong back-reference: while the host holds the stand-in, the`

### UnsignedShortTest.test_mul (VM-CRASH)

- expected: host oracle = `ok`
- got: `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 |     host_cls = _jac_standin_class(u.cls)  1051 |     inst = host_cls.__new__(host_cls)  1052 |     # Strong back-reference: while the host holds the stand-in, the`

### UnsignedShortTest.test_pickle (VM-CRASH)

- expected: host oracle = `ok`
- got: `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 |     host_cls = _jac_standin_class(u.cls)  1051 |     inst = host_cls.__new__(host_cls)  1052 |     # Strong back-reference: while the host holds the stand-in, the`

### UnsignedShortTest.test_pickle_for_empty_array (VM-CRASH)

- expected: host oracle = `ok`
- got: `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 |     host_cls = _jac_standin_class(u.cls)  1051 |     inst = host_cls.__new__(host_cls)  1052 |     # Strong back-reference: while the host holds the stand-in, the`

### UnsignedShortTest.test_remove (VM-CRASH)

- expected: host oracle = `ok`
- got: `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 |     host_cls = _jac_standin_class(u.cls)  1051 |     inst = host_cls.__new__(host_cls)  1052 |     # Strong back-reference: while the host holds the stand-in, the`

### UnsignedShortTest.test_repr (VM-CRASH)

- expected: host oracle = `ok`
- got: `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 |     host_cls = _jac_standin_class(u.cls)  1051 |     inst = host_cls.__new__(host_cls)  1052 |     # Strong back-reference: while the host holds the stand-in, the`

### UnsignedShortTest.test_reverse (VM-CRASH)

- expected: host oracle = `ok`
- got: `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 |     host_cls = _jac_standin_class(u.cls)  1051 |     inst = host_cls.__new__(host_cls)  1052 |     # Strong back-reference: while the host holds the stand-in, the`

### UnsignedShortTest.test_reverse_iterator (VM-CRASH)

- expected: host oracle = `ok`
- got: `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 |     host_cls = _jac_standin_class(u.cls)  1051 |     inst = host_cls.__new__(host_cls)  1052 |     # Strong back-reference: while the host holds the stand-in, the`

### UnsignedShortTest.test_reverse_iterator_picking (VM-CRASH)

- expected: host oracle = `ok`
- got: `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 |     host_cls = _jac_standin_class(u.cls)  1051 |     inst = host_cls.__new__(host_cls)  1052 |     # Strong back-reference: while the host holds the stand-in, the`

### UnsignedShortTest.test_str (VM-CRASH)

- expected: host oracle = `ok`
- got: `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 |     host_cls = _jac_standin_class(u.cls)  1051 |     inst = host_cls.__new__(host_cls)  1052 |     # Strong back-reference: while the host holds the stand-in, the`

### UnsignedShortTest.test_subclass_with_kwargs (VM-CRASH)

- expected: host oracle = `ok`
- got: `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 |     host_cls = _jac_standin_class(u.cls)  1051 |     inst = host_cls.__new__(host_cls)  1052 |     # Strong back-reference: while the host holds the stand-in, the`

### UnsignedShortTest.test_tofrombytes (VM-CRASH)

- expected: host oracle = `ok`
- got: `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 |     host_cls = _jac_standin_class(u.cls)  1051 |     inst = host_cls.__new__(host_cls)  1052 |     # Strong back-reference: while the host holds the stand-in, the`

### UnsignedShortTest.test_tofromlist (VM-CRASH)

- expected: host oracle = `ok`
- got: `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 |     host_cls = _jac_standin_class(u.cls)  1051 |     inst = host_cls.__new__(host_cls)  1052 |     # Strong back-reference: while the host holds the stand-in, the`

### UnsignedShortTest.test_type_error (VM-CRASH)

- expected: host oracle = `ok`
- got: `jac dev mode - using compiler source at /var/tmp/worker4-portarray-wt/jac  Error: array() takes at least 1 argument (0 given)  1050 |     host_cls = _jac_standin_class(u.cls)  1051 |     inst = host_cls.__new__(host_cls)  1052 |     # Strong back-reference: while the host holds the stand-in, the`
