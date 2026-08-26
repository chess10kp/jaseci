# Triage report: `conv_codeccallbacks_pins.jac`

- source: /home/jac/repos/jac-python/reference/cpython/Lib/test/test_codeccallbacks.py
- guest leg: 0/38 marks
- pins: **18 passed** / 38 run (+5 quarantined of 43 extracted)

| pin | result | got |
|---|---|---|
| CodecCallbackTest.test_xmlcharrefreplace | PASS | |
| CodecCallbackTest.test_xmlcharnamereplace | GUEST-WRONG-OUTPUT | GOT<'ORACLE_EXC LookupError "unknown error handler name \'test.xmlcharnamereplace\'"'> |
| CodecCallbackTest.test_uninamereplace | GUEST-WRONG-OUTPUT | GOT<'ORACLE_EXC LookupError "unknown error handler name \'test.uninamereplace\'"'> |
| CodecCallbackTest.test_backslashescape | GUEST-WRONG-OUTPUT | GOT<"ORACLE_EXC LookupError 'unknown encoding: iso-8859-15'"> |
| CodecCallbackTest.test_nameescape | GUEST-WRONG-OUTPUT | GOT<'ORACLE_EXC LookupError "unknown error handler name \'namereplace\'"'> |
| CodecCallbackTest.test_decoding_callbacks | PASS | |
| CodecCallbackTest.test_charmapencode | PASS | |
| CodecCallbackTest.test_callbacks | GUEST-WRONG-OUTPUT | GOT<'ORACLE_EXC LookupError "unknown error handler name \'test.handler1\'"'> |
| CodecCallbackTest.test_longstrings | GUEST-WRONG-OUTPUT | GOT<"ORACLE_EXC LookupError 'unknown encoding: iso-8859-15'"> |
| CodecCallbackTest.test_unicodeencodeerror | GUEST-WRONG-OUTPUT | GOT<'ORACLE_EXC AssertionError \'(\\\'assertEqual\\\', "\\\'ascii\\\' codec can\\\'t encode character \\\\\\\\u00fc in position 1: ouch", "\\\'ascii\\\' codec can\\\'t encode character \\\'\\\\\\\\xfc\\\' in position 1: ouch")\''> |
| CodecCallbackTest.test_unicodedecodeerror | GUEST-WRONG-OUTPUT | GOT<'ORACLE_EXC AssertionError \'(\\\'assertEqual\\\', "(ascii, bytearray(b\\\'g\\\\\\\\xfcrk\\\'), 1, 2, ouch)", "\\\'ascii\\\' codec can\\\'t decode byte 0xfc in position 1: ouch")\''> |
| CodecCallbackTest.test_unicodetranslateerror | GUEST-WRONG-OUTPUT | GOT<"ORACLE_EXC TypeError 'UnicodeTranslateError constructor takes exactly 5 arguments'"> |
| CodecCallbackTest.test_badandgoodstrictexceptions | GUEST-WRONG-OUTPUT | GOT<"ORACLE_EXC TypeError 'UnicodeTranslateError constructor takes exactly 5 arguments'"> |
| CodecCallbackTest.test_badandgoodignoreexceptions | GUEST-WRONG-OUTPUT | GOT<"ORACLE_EXC TypeError 'UnicodeTranslateError constructor takes exactly 5 arguments'"> |
| CodecCallbackTest.test_badandgoodreplaceexceptions | GUEST-WRONG-OUTPUT | GOT<"ORACLE_EXC TypeError 'UnicodeTranslateError constructor takes exactly 5 arguments'"> |
| CodecCallbackTest.test_badandgoodxmlcharrefreplaceexceptions | PASS | |
| CodecCallbackTest.test_badandgoodbackslashreplaceexceptions | GUEST-WRONG-OUTPUT | GOT<"ORACLE_EXC TypeError 'UnicodeTranslateError constructor takes exactly 5 arguments'"> |
| CodecCallbackTest.test_badandgoodnamereplaceexceptions | PASS | |
| CodecCallbackTest.test_badandgoodsurrogateescapeexceptions | GUEST-WRONG-OUTPUT | GOT<'ORACLE_EXC AssertionError "(\'assertEqual\', (b\'\\\\x80\', 2), (b\'\\\\x80\', 2))"'> |
| CodecCallbackTest.test_badandgoodsurrogatepassexceptions | GUEST-WRONG-OUTPUT | GOT<"ORACLE_EXC LookupError 'unknown encoding: utf-16le'"> |
| CodecCallbackTest.test_badhandlerresults | GUEST-WRONG-OUTPUT | GOT<'ORACLE_EXC LookupError "unknown error handler name \'test.badhandler\'"'> |
| CodecCallbackTest.test_lookup | PASS | |
| CodecCallbackTest.test_encode_bytes_replacement | GUEST-WRONG-OUTPUT | GOT<'ORACLE_EXC LookupError "unknown error handler name \'test.replacing\'"'> |
| CodecCallbackTest.test_badregistercall | PASS | |
| CodecCallbackTest.test_badlookupcall | PASS | |
| CodecCallbackTest.test_unknownhandler | PASS | |
| CodecCallbackTest.test_xmlcharrefvalues | GUEST-WRONG-OUTPUT | GOT<'ORACLE_EXC LookupError "unknown error handler name \'test.xmlcharrefreplace\'"'> |
| CodecCallbackTest.test_decodehelper | PASS | |
| CodecCallbackTest.test_encodehelper | GUEST-WRONG-OUTPUT | GOT<'ORACLE_EXC LookupError "unknown error handler name \'test.badencodereturn1\'"'> |
| CodecCallbackTest.test_decodehelper_bug36819 | GUEST-WRONG-OUTPUT | GOT<"ORACLE_EXC LookupError 'unknown encoding: utf-16be'"> |
| CodecCallbackTest.test_translatehelper | PASS | |
| CodecCallbackTest.test_bug828737 | PASS | |
| CodecCallbackTest.test_mutating_decode_handler | PASS | |
| CodecCallbackTest.test_crashing_decode_handler | PASS | |
| CodecCallbackTest.test_fake_error_class | PASS | |
| CodecCallbackTest.test_reject_unregister_builtin_error_handler | PASS | |
| CodecCallbackTest.test_unregister_custom_error_handler | PASS | |
| CodecCallbackTest.test_unregister_custom_unknown_error_handler | PASS | |

## Quarantined at conversion

| test | reason |
|---|---|
| CodecCallbackTest.test_encode_nonascii_replacement | unresolved-name:cm |
| CodecCallbackTest.test_encode_unencodable_replacement | unresolved-name:cm |
| CodecCallbackTest.test_encode_odd_bytes_replacement | unresolved-name:cm |
| CodecCallbackTest.test_encodehelper_bug36819 | unresolved-name:cm |
| CodecCallbackTest.test_mutating_decode_handler_unicode_escape | assertWarns as-variant |

## Expected vs got

### CodecCallbackTest.test_backslashescape (GUEST-WRONG-OUTPUT)
- expected: host oracle = `ok`
- got: GOT<"ORACLE_EXC LookupError 'unknown encoding: iso-8859-15'">

### CodecCallbackTest.test_badandgoodbackslashreplaceexceptions (GUEST-WRONG-OUTPUT)
- expected: host oracle = `ok`
- got: GOT<"ORACLE_EXC TypeError 'UnicodeTranslateError constructor takes exactly 5 arguments'">

### CodecCallbackTest.test_badandgoodignoreexceptions (GUEST-WRONG-OUTPUT)
- expected: host oracle = `ok`
- got: GOT<"ORACLE_EXC TypeError 'UnicodeTranslateError constructor takes exactly 5 arguments'">

### CodecCallbackTest.test_badandgoodreplaceexceptions (GUEST-WRONG-OUTPUT)
- expected: host oracle = `ok`
- got: GOT<"ORACLE_EXC TypeError 'UnicodeTranslateError constructor takes exactly 5 arguments'">

### CodecCallbackTest.test_badandgoodstrictexceptions (GUEST-WRONG-OUTPUT)
- expected: host oracle = `ok`
- got: GOT<"ORACLE_EXC TypeError 'UnicodeTranslateError constructor takes exactly 5 arguments'">

### CodecCallbackTest.test_badandgoodsurrogateescapeexceptions (GUEST-WRONG-OUTPUT)
- expected: host oracle = `ok`
- got: GOT<'ORACLE_EXC AssertionError "(\'assertEqual\', (b\'\\\\x80\', 2), (b\'\\\\x80\', 2))"'>

### CodecCallbackTest.test_badandgoodsurrogatepassexceptions (GUEST-WRONG-OUTPUT)
- expected: host oracle = `ok`
- got: GOT<"ORACLE_EXC LookupError 'unknown encoding: utf-16le'">

### CodecCallbackTest.test_badhandlerresults (GUEST-WRONG-OUTPUT)
- expected: host oracle = `ok`
- got: GOT<'ORACLE_EXC LookupError "unknown error handler name \'test.badhandler\'"'>

### CodecCallbackTest.test_callbacks (GUEST-WRONG-OUTPUT)
- expected: host oracle = `ok`
- got: GOT<'ORACLE_EXC LookupError "unknown error handler name \'test.handler1\'"'>

### CodecCallbackTest.test_decodehelper_bug36819 (GUEST-WRONG-OUTPUT)
- expected: host oracle = `ok`
- got: GOT<"ORACLE_EXC LookupError 'unknown encoding: utf-16be'">

### CodecCallbackTest.test_encode_bytes_replacement (GUEST-WRONG-OUTPUT)
- expected: host oracle = `ok`
- got: GOT<'ORACLE_EXC LookupError "unknown error handler name \'test.replacing\'"'>

### CodecCallbackTest.test_encodehelper (GUEST-WRONG-OUTPUT)
- expected: host oracle = `ok`
- got: GOT<'ORACLE_EXC LookupError "unknown error handler name \'test.badencodereturn1\'"'>

### CodecCallbackTest.test_longstrings (GUEST-WRONG-OUTPUT)
- expected: host oracle = `ok`
- got: GOT<"ORACLE_EXC LookupError 'unknown encoding: iso-8859-15'">

### CodecCallbackTest.test_nameescape (GUEST-WRONG-OUTPUT)
- expected: host oracle = `ok`
- got: GOT<'ORACLE_EXC LookupError "unknown error handler name \'namereplace\'"'>

### CodecCallbackTest.test_unicodedecodeerror (GUEST-WRONG-OUTPUT)
- expected: host oracle = `ok`
- got: GOT<'ORACLE_EXC AssertionError \'(\\\'assertEqual\\\', "(ascii, bytearray(b\\\'g\\\\\\\\xfcrk\\\'), 1, 2, ouch)", "\\\'ascii\\\' codec can\\\'t decode byte 0xfc in position 1: ouch")\''>

### CodecCallbackTest.test_unicodeencodeerror (GUEST-WRONG-OUTPUT)
- expected: host oracle = `ok`
- got: GOT<'ORACLE_EXC AssertionError \'(\\\'assertEqual\\\', "\\\'ascii\\\' codec can\\\'t encode character \\\\\\\\u00fc in position 1: ouch", "\\\'ascii\\\' codec can\\\'t encode character \\\'\\\\\\\\xfc\\\' in position 1: ouch")\''>

### CodecCallbackTest.test_unicodetranslateerror (GUEST-WRONG-OUTPUT)
- expected: host oracle = `ok`
- got: GOT<"ORACLE_EXC TypeError 'UnicodeTranslateError constructor takes exactly 5 arguments'">

### CodecCallbackTest.test_uninamereplace (GUEST-WRONG-OUTPUT)
- expected: host oracle = `ok`
- got: GOT<'ORACLE_EXC LookupError "unknown error handler name \'test.uninamereplace\'"'>

### CodecCallbackTest.test_xmlcharnamereplace (GUEST-WRONG-OUTPUT)
- expected: host oracle = `ok`
- got: GOT<'ORACLE_EXC LookupError "unknown error handler name \'test.xmlcharnamereplace\'"'>

### CodecCallbackTest.test_xmlcharrefvalues (GUEST-WRONG-OUTPUT)
- expected: host oracle = `ok`
- got: GOT<'ORACLE_EXC LookupError "unknown error handler name \'test.xmlcharrefreplace\'"'>
