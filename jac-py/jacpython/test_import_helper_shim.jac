# test.support.import_helper guest shim pins (gap fp-v1:8e23f48882c8).
#
# Regression guard for the census gap that hit ~69 converted Lib/test suites
# with "ImportError: cannot import name 'import_helper' from '<unknown>'":
# the test.support shim had no import_helper submodule, and PyModule shims did
# not expose __name__, so IMPORT_FROM degraded to the <unknown> message. Each
# pin mirrors the exact import forms the converted corpus uses.
import from layer_p2_libtest { p2_libtest_run_snippet }


test "from test.support import import_helper resolves the shim" {
    (ok, detail) = p2_libtest_run_snippet(
        "from test.support import import_helper\n"
        "print(import_helper.__name__)\n"
    );
    assert ok , "RUN<" + detail + ">";
    assert detail == "test.support.import_helper" , "GOT<" + detail + ">";
}


test "direct submodule import serves import_fresh_module" {
    (ok, detail) = p2_libtest_run_snippet(
        "from test.support.import_helper import import_fresh_module\n"
        "coll = import_fresh_module('collections')\n"
        "d = coll.OrderedDict([('a', 1), ('b', 2)])\n"
        "print(d['b'], list(coll.OrderedDict(a=1)))\n"
    );
    assert ok , "RUN<" + detail + ">";
    assert detail == "2 [('a', 1)]" , "GOT<" + detail + ">";
}


test "import_fresh_module with fresh/blocked kwargs returns working module" {
    # Corpus shape (test_ordered_dict family): fresh=['_collections'] /
    # blocked=['_collections'] must not fail -- the guest has one native
    # collections implementation, so both reduce to a cache-forgotten import.
    (ok, detail) = p2_libtest_run_snippet(
        "from test.support import import_helper\n"
        "c_coll = import_helper.import_fresh_module('collections', fresh=['_collections'])\n"
        "py_coll = import_helper.import_fresh_module('collections', blocked=['_collections'])\n"
        "od = c_coll.OrderedDict(b=2, a=1)\n"
        "od.move_to_end('b', last=False)\n"
        "print(list(od), py_coll is not None)\n"
    );
    assert ok , "RUN<" + detail + ">";
    assert detail == "['b', 'a'] True" , "GOT<" + detail + ">";
}


test "forget drops the module so re-import rebuilds it" {
    (ok, detail) = p2_libtest_run_snippet(
        "from test.support.import_helper import forget\n"
        "import json\n"
        "first = id(json.dumps)\n"
        "forget('json')\n"
        "import json\n"
        "print(json.dumps({'k': 1}))\n"
    );
    assert ok , "RUN<" + detail + ">";
    assert detail == "{\"k\": 1}" , "GOT<" + detail + ">";
}


test "ensure_lazy_imports passes when submodules stay unimported" {
    (ok, detail) = p2_libtest_run_snippet(
        "from test.support.import_helper import ensure_lazy_imports\n"
        "ensure_lazy_imports('json', ['base64', 'binascii'])\n"
        "print('ok')\n"
    );
    assert ok , "RUN<" + detail + ">";
    assert detail == "ok" , "GOT<" + detail + ">";
}


test "shim modules report __name__ in IMPORT_FROM errors (no <unknown>)" {
    (ok, detail) = p2_libtest_run_snippet(
        "try:\n"
        "    from test.support import nonexistent_helper_name\n"
        "except ImportError as e:\n"
        "    print(str(e))\n"
    );
    assert ok , "RUN<" + detail + ">";
    assert detail == "cannot import name 'nonexistent_helper_name' from 'test.support'" , (
        "GOT<" + detail + ">"
    );
}
