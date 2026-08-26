import from ceval { exec_code }
import from pyc_first { host_compile_marshal, unmarshal }
import from objects { PyStr }

with entry {
    src = "import lzma\nprint('M:', type(lzma).__name__)\nprint('LZMAFILE:', lzma.LZMAFile)\nf = lzma.LZMAFile()\nprint('F-OK')\n";
    co = unmarshal(host_compile_marshal(src));
    out = exec_code(co, [], {"__name__": PyStr(t="str", val="__main__")});
}
