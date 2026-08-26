import from ceval { exec_code }
import from pyc_first { host_compile_marshal, unmarshal }
import from objects { PyStr }

with entry {
    src = "import lzma\nf = lzma.LZMAFile(None)\nprint('EXPLICIT-NONE: OK')\nimport io\nb = io.BytesIO()\nprint('BYTESIO-OK')\ng = io.StringIO()\nprint('STRINGIO-OK')\n";
    co = unmarshal(host_compile_marshal(src));
    out = exec_code(co, [], {"__name__": PyStr(t="str", val="__main__")});
}
