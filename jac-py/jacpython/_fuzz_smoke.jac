# Fuzz smoke driver for the jacpython-vs-CPython differential corpus.
#
# Contract (mirrored by jac-py/tools/fuzz_run.py): reads /tmp/fuzz_cases.json
# -- a JSON array of {"name", "src"} entries where `src` is a statement-shaped
# unittest class body -- and replays each case through the Layer-1 harness:
# the setup runs in BOTH host CPython and jacpython, then every assert
# argument pair / raises-check body is evaluated against both namespaces and
# diffed. One verdict line per case, consumed by fuzz_run.py's classifier:
#     ok <name> passed: N skipped: M     no divergence (N>0 green; N==0 skip)
#     FUZZFAIL <name> passed: .. failed: .. errored: .. skipped: ..
#
# With no corpus file present it falls back to a built-in exception-attribute
# smoke sweep (chaining __context__/__cause__/__suppress_context__, args,
# add_note/__notes__), so exc-attr parity stays checkable standalone.
#
# Run: JACPYTHON_CPYTHON=python3 .venv/bin/jac run jac-py/jacpython/_fuzz_smoke.jac

import json;
import from layer0_replay_harness {
    ReplayResult,
    layer1_replay_source,
}

glob FUZZ_CASES_PATH: str = "/tmp/fuzz_cases.json";

def _fuzz_load_cases -> any {
    # None when no corpus is staged (standalone smoke mode).
    try {
        with open(FUZZ_CASES_PATH) as f {
            return json.load(f);
        }
    } except Exception {
        return None;
    }
}

def _fuzz_report(name: str, result: ReplayResult) {
    if result.failed == 0 and result.errored == 0 {
        print("ok", name, "passed:", result.passed, "skipped:", result.skipped);
    } else {
        print("FUZZFAIL", name, "passed:", result.passed,
              "failed:", result.failed, "errored:", result.errored,
              "skipped:", result.skipped);
    }
}

# Built-in fallback sweep. Same harness limits as the corpus: asserts are
# direct statements of a test_* method; args fold to interpreter-independent
# literals; __notes__ probed only AFTER add_note (jacpython pre-creates []
# where CPython is absent-until-add_note -- known deviation, owned elsewhere).
# str() of a MULTI-arg exception is avoided: it diverges only on the Layer-1
# replay path (host-marshal -> exec_code), byte-exact when run directly.
def _fuzz_builtin_cases -> list {
    cases: list = [];
    src = "class T(unittest.TestCase):\n"
    "    def test_case(self):\n"
    "        seen = []\n"
    "        try:\n"
    "            try:\n"
    "                raise ValueError('inner')\n"
    "            except ValueError:\n"
    "                raise TypeError('outer')\n"
    "        except TypeError as e:\n"
    "            seen.append(type(e).__name__)\n"
    "            seen.append(type(e.__context__).__name__)\n"
    "            seen.append(str(e.__context__))\n"
    "            seen.append(e.__suppress_context__)\n"
    "        self.assertEqual(seen, ['TypeError', 'ValueError', 'inner', False])\n";
    cases.append(("builtin-exc-chain-context", src));
    src = "class T(unittest.TestCase):\n"
    "    def test_case(self):\n"
    "        seen = []\n"
    "        try:\n"
    "            try:\n"
    "                raise ValueError('v')\n"
    "            except ValueError as v1:\n"
    "                raise KeyError('k') from v1\n"
    "        except KeyError as k:\n"
    "            seen.append(str(k.args))\n"
    "            seen.append(type(k.__cause__).__name__)\n"
    "            seen.append(str(k.__cause__))\n"
    "            seen.append(k.__suppress_context__)\n"
    "        try:\n"
    "            try:\n"
    "                raise ValueError('v2')\n"
    "            except ValueError:\n"
    "                raise KeyError('k2') from None\n"
    "        except KeyError as k2:\n"
    "            seen.append(str(k2.__cause__))\n"
    "            seen.append(k2.__suppress_context__)\n"
    "        self.assertEqual(seen, [\"('k',)\", 'ValueError', 'v', True, 'None', True])\n";
    cases.append(("builtin-exc-cause-fromnone", src));
    src = "class T(unittest.TestCase):\n"
    "    def test_case(self):\n"
    "        e1 = ValueError()\n"
    "        e2 = ValueError('a', 'b')\n"
    "        e3 = StopIteration()\n"
    "        e4 = ValueError('solo')\n"
    "        self.assertEqual(e1.args, ())\n"
    "        self.assertEqual(len(e2.args), 2)\n"
    "        self.assertEqual(e2.args[0], 'a')\n"
    "        self.assertEqual(e2.args, ('a', 'b'))\n"
    "        self.assertEqual(str(e4), 'solo')\n"
    "        self.assertEqual(e3.args, ())\n";
    cases.append(("builtin-exc-args-surface", src));
    src = "class T(unittest.TestCase):\n"
    "    def test_case(self):\n"
    "        e = ValueError('boom')\n"
    "        e.add_note('note one')\n"
    "        e.add_note('note two')\n"
    "        self.assertEqual(e.__notes__, ['note one', 'note two'])\n";
    cases.append(("builtin-exc-notes-add", src));
    return cases;
}

with entry {
    cases = _fuzz_load_cases();
    if cases is None {
        for fz in _fuzz_builtin_cases() {
            name = fz[0] as str;
            result = layer1_replay_source(fz[1] as str);
            _fuzz_report(name, result);
        }
    } else {
        for fz in cases {
            name = fz["name"] as str;
            result = layer1_replay_source(fz["src"] as str);
            _fuzz_report(name, result);
        }
    }
}
