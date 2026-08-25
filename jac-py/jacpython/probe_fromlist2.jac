import from ceval { exec_code }
import from pyc_first { host_compile_marshal, unmarshal }
import from objects { PyStr }

with entry {
    src = "from lzma import LZMAFile\nfrom io import UnsupportedOperation\nf = LZMAFile()\ntry:\n    f.read(1)\n    print('NO-RAISE')\nexcept UnsupportedOperation as e:\n    print('CAUGHT:', type(e).__name__, '|', e)\nexcept Exception as e:\n    print('WRONG-EXC:', type(e).__name__, '|', e)\n";
    co = unmarshal(host_compile_marshal(src));
    out = exec_code(co, [], {"__name__": PyStr(t="str", val="__main__")});
}
