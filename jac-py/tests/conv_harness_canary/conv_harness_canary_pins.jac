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
    _mark("HarnessCanary.test_intflag_inheritance", "import enum\nclass X(enum.IntFlag, boundary=enum.KEEP):\n    A = 1\n    B = 2\nassert (X.A | X.B) == 3\nprint('ok')");
    _mark("HarnessCanary.test_enum_flag_intenum_members", "import enum\nclass Y(enum.Flag):\n    R = 1\n    G = 2\nclass Z(enum.IntEnum):\n    ONE = 1\n    TWO = 2\nassert (Z.ONE + Z.TWO) == 3\nassert int(Z.ONE) == 1\nassert not (Y.R & Y.G)\nassert (Y.R | Y.G)\nprint('ok')");
    _mark("HarnessCanary.test_enum_module_attr", "import enum\nclass W(enum.IntFlag):\n    A = 1\nassert enum.IntFlag.__module__ == 'enum'\nassert enum.Enum.__module__ == 'enum'\nassert W.__module__ == '__main__', W.__module__\nprint('ok')");
    _mark("HarnessCanary.test_init_subclass_kwarg_forwarding", "seen = []\nclass Base:\n    def __init_subclass__(cls, **kw):\n        seen.append(kw)\nclass A(Base, meta_kw=7):\n    pass\nassert seen == [{'meta_kw': 7}], seen\nprint('ok')");
    print("MARK ALLDONE");
}
