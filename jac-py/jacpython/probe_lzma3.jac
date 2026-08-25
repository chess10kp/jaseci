import from ceval { exec_code }
import from pyc_first { host_compile_marshal, unmarshal }
import from objects { PyStr }

with entry {
    src = "import lzma\ntry:\n    f = lzma.LZMAFile(filename=None)\n    print('KWARG-OK')\nexcept BaseException as e:\n    print('KWARG-FAIL:', type(e).__name__, e)\nimport gzip\ntry:\n    g = gzip.GzipFile()\n    print('GZIP-OK')\nexcept BaseException as e:\n    print('GZIP-FAIL:', type(e).__name__, e)\n";
    co = unmarshal(host_compile_marshal(src));
    out = exec_code(co, [], {"__name__": PyStr(t="str", val="__main__")});
}
