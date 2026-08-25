# Triage report: `conv_zipimport_pins.jac`

- source: /home/jac/repos/jac-python/reference/cpython/Lib/test/test_zipimport.py
- guest leg: 0/6 marks
- pins: **5 passed** / 6 run (+43 quarantined of 49 extracted)

| pin | result | got |
|---|---|---|
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
| CompressedZipImportTestCase.testAFakeZlib | helper:doTest(helper:makeZip(self.addCleanup)) |
| CompressedZipImportTestCase.testPy | helper:doTest(helper:makeZip(self.addCleanup)) |
| CompressedZipImportTestCase.testPyc | helper:doTest(helper:makeZip(self.addCleanup)) |
| CompressedZipImportTestCase.testBoth | helper:doTest(helper:makeZip(self.addCleanup)) |
| CompressedZipImportTestCase.testUncheckedHashBasedPyc | helper:doTest(helper:makeZip(self.addCleanup)) |
| CompressedZipImportTestCase.test_checked_hash_based_change_pyc | helper:doTest(helper:makeZip(self.addCleanup)) |
| CompressedZipImportTestCase.testEmptyPy | helper:doTest(helper:makeZip(self.addCleanup)) |
| CompressedZipImportTestCase.testBadMagic | helper:doTest(helper:makeZip(self.addCleanup)) |
| CompressedZipImportTestCase.testBadMagic2 | helper:doTest(helper:makeZip(self.addCleanup)) |
| CompressedZipImportTestCase.testBadMTime | helper:doTest(helper:makeZip(self.addCleanup)) |
| CompressedZipImportTestCase.test2038MTime | helper:doTest(helper:makeZip(self.addCleanup)) |
| CompressedZipImportTestCase.testPackage | helper:doTest(helper:makeZip(self.addCleanup)) |
| CompressedZipImportTestCase.testSubPackage | helper:doTest(helper:makeZip(self.addCleanup)) |
| CompressedZipImportTestCase.testSubNamespacePackage | helper:doTest(helper:makeZip(self.addCleanup)) |
| CompressedZipImportTestCase.testPackageExplicitDirectories | self.addCleanup |
| CompressedZipImportTestCase.testPackageImplicitDirectories | self.addCleanup |
| CompressedZipImportTestCase.testNamespacePackageExplicitDirectories | self.addCleanup |
| CompressedZipImportTestCase.testNamespacePackageImplicitDirectories | self.addCleanup |
| CompressedZipImportTestCase.testMixedNamespacePackage | helper:makeZip(self.addCleanup) |
| CompressedZipImportTestCase.testNamespacePackage | helper:makeZip(self.addCleanup) |
| CompressedZipImportTestCase.testZipImporterMethods | helper:makeZip(self.addCleanup) |
| CompressedZipImportTestCase.testInvalidateCaches | helper:makeZip(self.addCleanup) |
| CompressedZipImportTestCase.testInvalidateCachesWithMultipleZipimports | helper:makeZip(self.addCleanup) |
| CompressedZipImportTestCase.testZipImporterMethodsInSubDirectory | helper:makeZip(self.addCleanup) |
| CompressedZipImportTestCase.testGetDataExplicitDirectories | self.addCleanup |
| CompressedZipImportTestCase.testGetDataImplicitDirectories | self.addCleanup |
| CompressedZipImportTestCase.testImporterAttr | helper:doTest(helper:makeZip(self.addCleanup)) |
| CompressedZipImportTestCase.testDefaultOptimizationLevel | helper:makeZip(self.addCleanup) |
| CompressedZipImportTestCase.testImport_WithStuff | helper:doTest(helper:makeZip(self.addCleanup)) |
| CompressedZipImportTestCase.testGetSource | helper:doTest(helper:makeZip(self.addCleanup)) |
| CompressedZipImportTestCase.testGetCompiledSource | helper:doTest(helper:makeZip(self.addCleanup)) |
| CompressedZipImportTestCase.testDoctestFile | helper:runDoctest(helper:doTest(helper:makeZip(self.addCleanup))) |
| CompressedZipImportTestCase.testDoctestSuite | helper:runDoctest(helper:doTest(helper:makeZip(self.addCleanup))) |
| CompressedZipImportTestCase.testTraceback | helper:doTest(helper:makeZip(self.addCleanup)) |
| CompressedZipImportTestCase.testBytesPath | helper:makeZip(self.addCleanup) |
| CompressedZipImportTestCase.testComment | helper:doTest(helper:makeZip(self.addCleanup)) |
| CompressedZipImportTestCase.testBeginningCruftAndComment | helper:doTest(helper:makeZip(self.addCleanup)) |
| CompressedZipImportTestCase.testLargestPossibleComment | helper:doTest(helper:makeZip(self.addCleanup)) |
| CompressedZipImportTestCase.testZip64LargeFile | self.addCleanup |

## Expected vs got

### BadFileZipImportTestCase.testEmptyFile (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<"ORACLE_EXC AttributeError 'create_empty_file'">
