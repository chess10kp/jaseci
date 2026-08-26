import from ceval { exec_code }
import from pyc_first { host_compile_marshal, unmarshal }
import from objects { PyStr }

with entry {
    src = "from io import BytesIO, UnsupportedOperation, DEFAULT_BUFFER_SIZE\nprint('W1:', BytesIO is not None)\nprint('W2:', UnsupportedOperation.__name__)\nprint('W3:', DEFAULT_BUFFER_SIZE > 0)\ntry:\n    f = BytesIO()\nexcept UnsupportedOperation:\n    pass\nprint('DONE')\n";
    co = unmarshal(host_compile_marshal(src));
    out = exec_code(co, [], {"__name__": PyStr(t="str", val="__main__")});
}
