# Generated canary -- DO NOT EDIT BY HAND.
import from layer_p2_libtest { p2_libtest_run_snippet }

def _mark(name: str, source: str) -> None {
    (ok, detail) = p2_libtest_run_snippet(source);
    if ok {
        if detail == "ok" {
            print("MARK PASS " + name);
        } else {
            print("MARK FAIL " + name + " GOT<" + repr(detail) + ">");
        }
    } else {
        print("MARK FAIL " + name + " RUN<" + repr(detail) + ">");
    }
}

with entry {
    _mark("HarnessCanary.test_pprint_import", "import pprint\nprint('ok')");
    _mark("HarnessCanary.test_ordereddict_repr_surface", "import collections\nassert collections.OrderedDict.__repr__ is not None\nprint('ok')");
    _mark("HarnessCanary.test_guest_class_dunder_fallback", "class C:\n    pass\nassert C.__repr__ is not None\nprint('ok')");
    _mark("HarnessCanary.test_functools_cache_present", "import functools\nassert hasattr(functools, 'cache')\nprint('ok')");
    _mark("HarnessCanary.test_typing_import", "import typing\nprint('ok')");
    _mark("HarnessCanary.test_function_descriptor_protocol", "def f(): pass\nassert hasattr(f, '__get__')\nprint('ok')");
    _mark("HarnessCanary.test_intflag_inheritance", "import enum\nclass X(enum.IntFlag):\n    A=1\nassert X.A.value==1\nprint('ok')");
    _mark("HarnessCanary.test_super_seed_bridge", "import random\nclass R(random.Random):\n    def __init__(self, x):\n        super().seed(x)\nr=R(42)\nprint('ok')");
    print("MARK ALLDONE");
}
