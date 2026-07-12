"""Pipeline error-path contracts: empty FactStore and unparseable source.

Detectors and extract must degrade (empty / partial findings, no exception)
rather than assume ≥1 symbol or a clean compile.
"""

import os;
import hashlib;
import tempfile;
import from jaclang.prune.campaign { DEFAULT_RECIPES }
import from jaclang.prune.factstore { FactStore }
import from jaclang.prune.veto { VetoIndex }
import from jaclang.prune.detectors { run_detectors }
import from jaclang.prune.pipeline { compile_source_paths }
import from jaclang.prune.manifest { Manifest, ManifestEntry, FileRole }
import from jaclang.prune.extract { extract_facts }


test "run_detectors: empty store with default recipes returns no findings" {
    tmpdir = tempfile.mkdtemp(prefix="jac-empty-store-");
    db = os.path.join(tmpdir, "prune.db");
    store = FactStore(db_path=db);
    store.open();
    findings = run_detectors(store, VetoIndex(), DEFAULT_RECIPES);
    store.close();
    assert findings == [];
}


test "compile_source_paths: unparseable source records errs and does not raise" {
    tmpdir = tempfile.mkdtemp(prefix="jac-bad-syntax-");
    path = os.path.join(tmpdir, "broken.jac");
    with open(path, "w", encoding="utf-8") as f {
        f.write("def broken {\n    this is not valid jac!!!\n");
    }
    (prog, errs, warns, compiled) = compile_source_paths([path]);
    assert errs > 0 , (errs, compiled, warns);

    with open(path, "rb") as f {
        h = hashlib.sha256(f.read()).hexdigest();
    }
    man = Manifest(
        project_root=tmpdir,
        entries=[
            ManifestEntry(
                path=path, role=FileRole.SOURCE, content_hash=h, module_name="broken"
            )
        ]
    );
    facts = extract_facts(prog, man);
    store = FactStore(db_path=":memory:");
    store.open();
    store.sync(facts);
    findings = run_detectors(store, VetoIndex(), DEFAULT_RECIPES);
    store.close();
    assert isinstance(findings, list);
}
