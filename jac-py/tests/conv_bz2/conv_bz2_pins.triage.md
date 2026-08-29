# Triage report: `conv_bz2_pins.jac`

- source: /opt/jacpy/repo/reference/cpython/Lib/test/test_bz2.py
- guest leg: TIMEOUT at 60s cap
- pins: **0 passed** / 0 run (+102 quarantined of 102 extracted)

| pin | result | got |
|---|---|---|

## Quarantined at conversion

| test | reason |
|---|---|
| BZ2FileTest.testThreading | decorator:threading_helper.requires_working_threading |
| BZ2CompressorTest.testCompress4G | decorator:support.skip_if_pgo_task |
| BZ2DecompressorTest.testDecompress4G | decorator:support.skip_if_pgo_task |
| BZ2DecompressorTest.test_refleaks_in___init__ | decorator:support.refcount_test |
| BZ2FileTest.testBadArgs | uses-self.filename |
| BZ2FileTest.testRead | uses-self.filename |
| BZ2FileTest.testReadBadFile | uses-self.filename |
| BZ2FileTest.testReadMultiStream | uses-self.filename |
| BZ2FileTest.testReadMonkeyMultiStream | uses-self.filename |
| BZ2FileTest.testReadTrailingJunk | uses-self.filename |
| BZ2FileTest.testReadMultiStreamTrailingJunk | uses-self.filename |
| BZ2FileTest.testRead0 | uses-self.filename |
| BZ2FileTest.testReadChunk10 | uses-self.filename |
| BZ2FileTest.testReadChunk10MultiStream | uses-self.filename |
| BZ2FileTest.testRead100 | uses-self.filename |
| BZ2FileTest.testPeek | self.assertStartsWith |
| BZ2FileTest.testReadInto | uses-self.filename |
| BZ2FileTest.testReadLine | uses-self.filename |
| BZ2FileTest.testReadLineMultiStream | uses-self.filename |
| BZ2FileTest.testReadLines | uses-self.filename |
| BZ2FileTest.testReadLinesMultiStream | uses-self.filename |
| BZ2FileTest.testIterator | uses-self.filename |
| BZ2FileTest.testIteratorMultiStream | uses-self.filename |
| BZ2FileTest.testClosedIteratorDeadlock | uses-self.filename |
| BZ2FileTest.testWrite | uses-self.filename |
| BZ2FileTest.testWriteChunks10 | uses-self.filename |
| BZ2FileTest.testWriteNonDefaultCompressLevel | uses-self.filename |
| BZ2FileTest.testWriteLines | uses-self.filename |
| BZ2FileTest.testWriteMethodsOnReadOnlyFile | uses-self.filename |
| BZ2FileTest.testAppend | uses-self.filename |
| BZ2FileTest.testSeekForward | uses-self.filename |
| BZ2FileTest.testSeekForwardAcrossStreams | uses-self.filename |
| BZ2FileTest.testSeekBackwards | uses-self.filename |
| BZ2FileTest.testSeekBackwardsAcrossStreams | uses-self.filename |
| BZ2FileTest.testSeekBackwardsFromEnd | uses-self.filename |
| BZ2FileTest.testSeekBackwardsFromEndAcrossStreams | uses-self.filename |
| BZ2FileTest.testSeekPostEnd | uses-self.filename |
| BZ2FileTest.testSeekPostEndMultiStream | uses-self.filename |
| BZ2FileTest.testSeekPostEndTwice | uses-self.filename |
| BZ2FileTest.testSeekPostEndTwiceMultiStream | uses-self.filename |
| BZ2FileTest.testSeekPreStart | uses-self.filename |
| BZ2FileTest.testSeekPreStartMultiStream | uses-self.filename |
| BZ2FileTest.testFileno | uses-self.filename |
| BZ2FileTest.testSeekable | uses-self.filename |
| BZ2FileTest.testReadable | uses-self.filename |
| BZ2FileTest.testWritable | uses-self.filename |
| BZ2FileTest.testOpenDel | uses-self.filename |
| BZ2FileTest.testOpenNonexistent | uses-self.filename |
| BZ2FileTest.testReadlinesNoNewline | uses-self.filename |
| BZ2FileTest.testContextProtocol | uses-self.filename |
| BZ2FileTest.testMixedIterationAndReads | uses-self.filename |
| BZ2FileTest.testMultiStreamOrdering | uses-self.filename |
| BZ2FileTest.testOpenFilename | uses-self.filename |
| BZ2FileTest.testOpenFileWithName | uses-self.filename |
| BZ2FileTest.testOpenFileWithoutName | uses-self.filename |
| BZ2FileTest.testOpenFileWithIntName | uses-self.filename |
| BZ2FileTest.testOpenBytesFilename | uses-self.filename |
| BZ2FileTest.testOpenPathLikeFilename | uses-self.filename |
| BZ2FileTest.testDecompressLimited | uses-self.filename |
| BZ2FileTest.testReadBytesIO | uses-self.filename |
| BZ2FileTest.testPeekBytesIO | self.assertStartsWith |
| BZ2FileTest.testWriteBytesIO | uses-self.filename |
| BZ2FileTest.testSeekForwardBytesIO | uses-self.filename |
| BZ2FileTest.testSeekBackwardsBytesIO | uses-self.filename |
| BZ2FileTest.test_read_truncated | uses-self.filename |
| BZ2FileTest.test_issue44439 | uses-self.filename |
| BZ2CompressorTest.testCompress | uses-self.filename |
| BZ2CompressorTest.testCompressEmptyString | uses-self.filename |
| BZ2CompressorTest.testCompressChunks10 | uses-self.filename |
| BZ2CompressorTest.testPickle | uses-self.filename |
| BZ2DecompressorTest.test_Constructor | uses-self.filename |
| BZ2DecompressorTest.testDecompress | uses-self.filename |
| BZ2DecompressorTest.testDecompressChunks10 | uses-self.filename |
| BZ2DecompressorTest.testDecompressUnusedData | uses-self.filename |
| BZ2DecompressorTest.testEOFError | uses-self.filename |
| BZ2DecompressorTest.testPickle | uses-self.filename |
| BZ2DecompressorTest.testDecompressorChunksMaxsize | uses-self.filename |
| BZ2DecompressorTest.test_decompressor_inputbuf_1 | uses-self.filename |
| BZ2DecompressorTest.test_decompressor_inputbuf_2 | uses-self.filename |
| BZ2DecompressorTest.test_decompressor_inputbuf_3 | uses-self.filename |
| BZ2DecompressorTest.test_failure | uses-self.filename |
| BZ2DecompressorTest.test_decompress_after_data_error | uses-self.filename |
| BZ2DecompressorTest.test_uninitialized_BZ2Decompressor_crash | uses-self.filename |
| CompressDecompressTest.testCompress | uses-self.filename |
| CompressDecompressTest.testCompressEmptyString | uses-self.filename |
| CompressDecompressTest.testDecompress | uses-self.filename |
| CompressDecompressTest.testDecompressEmpty | uses-self.filename |
| CompressDecompressTest.testDecompressToEmptyString | uses-self.filename |
| CompressDecompressTest.testDecompressIncomplete | uses-self.filename |
| CompressDecompressTest.testDecompressBadData | uses-self.filename |
| CompressDecompressTest.testDecompressMultiStream | uses-self.filename |
| CompressDecompressTest.testDecompressTrailingJunk | uses-self.filename |
| CompressDecompressTest.testDecompressMultiStreamTrailingJunk | uses-self.filename |
| OpenTest.test_binary_modes | uses-self.filename |
| OpenTest.test_implicit_binary_modes | uses-self.filename |
| OpenTest.test_text_modes | uses-self.filename |
| OpenTest.test_x_mode | uses-self.filename |
| OpenTest.test_fileobj | uses-self.filename |
| OpenTest.test_bad_params | uses-self.open |
| OpenTest.test_encoding | uses-self.filename |
| OpenTest.test_encoding_error_handler | uses-self.filename |
| OpenTest.test_newline | uses-self.filename |
