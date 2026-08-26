# Triage report: `conv_zipimport_pins.jac`

- source: /home/jac/repos/jac-python/reference/cpython/Lib/test/test_zipimport.py
- guest leg: 0/12 marks
- pins: **5 passed** / 12 run (+37 quarantined of 49 extracted)

| pin | result | got |
|---|---|---|
| CompressedZipImportTestCase.testPackageExplicitDirectories | GUEST-WRONG-OUTPUT | RUN<"ImportError: cannot import name 'nlargest' from '<unknown>'"> |
| CompressedZipImportTestCase.testPackageImplicitDirectories | GUEST-WRONG-OUTPUT | RUN<"ImportError: cannot import name 'nlargest' from '<unknown>'"> |
| CompressedZipImportTestCase.testNamespacePackageExplicitDirectories | GUEST-WRONG-OUTPUT | RUN<"ImportError: cannot import name 'nlargest' from '<unknown>'"> |
| CompressedZipImportTestCase.testNamespacePackageImplicitDirectories | GUEST-WRONG-OUTPUT | RUN<"ImportError: cannot import name 'nlargest' from '<unknown>'"> |
| CompressedZipImportTestCase.testGetDataExplicitDirectories | GUEST-WRONG-OUTPUT | RUN<"ImportError: cannot import name 'nlargest' from '<unknown>'"> |
| CompressedZipImportTestCase.testGetDataImplicitDirectories | GUEST-WRONG-OUTPUT | RUN<"ImportError: cannot import name 'nlargest' from '<unknown>'"> |
| BadFileZipImportTestCase.testNoFile | PASS | |
| BadFileZipImportTestCase.testEmptyFilename | PASS | |
| BadFileZipImportTestCase.testBadArgs | PASS | |
| BadFileZipImportTestCase.testFilenameTooLong | PASS | |
| BadFileZipImportTestCase.testEmptyFile | GUEST-WRONG-OUTPUT | GOT<"ORACLE_EXC AttributeError 'create_empty_file'"> |
| BadFileZipImportTestCase.testNotZipFile | PASS | |

## Quarantined at conversion

| test | reason |
|---|---|
| UncompressedZipImportTestCase.testUnencodable | decorator:unittest.skipIf |
| UncompressedZipImportTestCase.testZip64 | decorator:support.requires_resource |
| UncompressedZipImportTestCase.testZip64CruftAndComment | decorator:support.requires_resource |
| BadFileZipImportTestCase.testFileUnreadable | decorator:unittest.skipIf |
| CompressedZipImportTestCase.testAFakeZlib | self.skipTest |
| CompressedZipImportTestCase.testPy | host-raised:NameError: name 'self' is not defined |
| CompressedZipImportTestCase.testPyc | host-raised:NameError: name 'self' is not defined |
| CompressedZipImportTestCase.testBoth | host-raised:NameError: name 'self' is not defined |
| CompressedZipImportTestCase.testUncheckedHashBasedPyc | host-raised:NameError: name 'self' is not defined |
| CompressedZipImportTestCase.test_checked_hash_based_change_pyc | host-raised:NameError: name 'self' is not defined |
| CompressedZipImportTestCase.testEmptyPy | host-raised:NameError: name 'self' is not defined |
| CompressedZipImportTestCase.testBadMagic | host-raised:NameError: name 'self' is not defined |
| CompressedZipImportTestCase.testBadMagic2 | host-raised:NameError: name 'self' is not defined |
| CompressedZipImportTestCase.testBadMTime | host-raised:NameError: name 'self' is not defined |
| CompressedZipImportTestCase.test2038MTime | host-raised:NameError: name 'self' is not defined |
| CompressedZipImportTestCase.testPackage | host-raised:NameError: name 'self' is not defined |
| CompressedZipImportTestCase.testSubPackage | host-raised:NameError: name 'self' is not defined |
| CompressedZipImportTestCase.testSubNamespacePackage | host-raised:NameError: name 'self' is not defined |
| CompressedZipImportTestCase.testMixedNamespacePackage | host-raised:NameError: name 'self' is not defined |
| CompressedZipImportTestCase.testNamespacePackage | host-raised:NameError: name 'self' is not defined |
| CompressedZipImportTestCase.testZipImporterMethods | host-raised:NameError: name 'self' is not defined |
| CompressedZipImportTestCase.testInvalidateCaches | host-raised:NameError: name 'self' is not defined |
| CompressedZipImportTestCase.testInvalidateCachesWithMultipleZipimports | host-raised:NameError: name 'self' is not defined |
| CompressedZipImportTestCase.testZipImporterMethodsInSubDirectory | host-raised:NameError: name 'self' is not defined |
| CompressedZipImportTestCase.testImporterAttr | host-raised:NameError: name 'self' is not defined |
| CompressedZipImportTestCase.testDefaultOptimizationLevel | host-raised:NameError: name 'self' is not defined |
| CompressedZipImportTestCase.testImport_WithStuff | host-raised:NameError: name 'self' is not defined |
| CompressedZipImportTestCase.testGetSource | host-raised:AttributeError: '_SelfNS' object has no attribute 'assertModuleSource' |
| CompressedZipImportTestCase.testGetCompiledSource | host-raised:AttributeError: '_SelfNS' object has no attribute 'assertModuleSource' |
| CompressedZipImportTestCase.testDoctestFile | host-raised:AttributeError: '_SelfNS' object has no attribute 'doDoctestFile' |
| CompressedZipImportTestCase.testDoctestSuite | host-raised:AttributeError: '_SelfNS' object has no attribute 'doDoctestSuite' |
| CompressedZipImportTestCase.testTraceback | host-raised:AttributeError: '_SelfNS' object has no attribute 'doTraceback' |
| CompressedZipImportTestCase.testBytesPath | host-raised:NameError: name 'self' is not defined |
| CompressedZipImportTestCase.testComment | host-raised:NameError: name 'self' is not defined |
| CompressedZipImportTestCase.testBeginningCruftAndComment | host-raised:NameError: name 'self' is not defined |
| CompressedZipImportTestCase.testLargestPossibleComment | host-raised:NameError: name 'self' is not defined |
| CompressedZipImportTestCase.testZip64LargeFile | host-raised:OSError: [Errno 28] No space left on device |

## Expected vs got

### BadFileZipImportTestCase.testEmptyFile (GUEST-WRONG-OUTPUT)
- expected: host oracle = `ok`
- got: GOT<"ORACLE_EXC AttributeError 'create_empty_file'">

### CompressedZipImportTestCase.testGetDataExplicitDirectories (GUEST-WRONG-OUTPUT)
- expected: host oracle = `ok`
- got: RUN<"ImportError: cannot import name 'nlargest' from '<unknown>'">

### CompressedZipImportTestCase.testGetDataImplicitDirectories (GUEST-WRONG-OUTPUT)
- expected: host oracle = `ok`
- got: RUN<"ImportError: cannot import name 'nlargest' from '<unknown>'">

### CompressedZipImportTestCase.testNamespacePackageExplicitDirectories (GUEST-WRONG-OUTPUT)
- expected: host oracle = `ok`
- got: RUN<"ImportError: cannot import name 'nlargest' from '<unknown>'">

### CompressedZipImportTestCase.testNamespacePackageImplicitDirectories (GUEST-WRONG-OUTPUT)
- expected: host oracle = `ok`
- got: RUN<"ImportError: cannot import name 'nlargest' from '<unknown>'">

### CompressedZipImportTestCase.testPackageExplicitDirectories (GUEST-WRONG-OUTPUT)
- expected: host oracle = `ok`
- got: RUN<"ImportError: cannot import name 'nlargest' from '<unknown>'">

### CompressedZipImportTestCase.testPackageImplicitDirectories (GUEST-WRONG-OUTPUT)
- expected: host oracle = `ok`
- got: RUN<"ImportError: cannot import name 'nlargest' from '<unknown>'">
