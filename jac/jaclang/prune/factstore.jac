import os;
import sqlite3;
import from typing { cast }

import from jaclang.prune.extract {
    FactSet,
    ModuleFact,
    SymbolFact,
    ReferenceFact,
    ImportFact,
    FieldAccessFact,
    BranchFact,
    EXTRACTOR_VERSION,
    dep_fact_id
}
import from jaclang.prune.bodies { BodyFact }
import from jaclang.prune.literals { LiteralFact }
import from jaclang.prune.docstrings { DocstringFact }


glob FACT_SCHEMA_VERSION = "7",
     _DATA_TABLES = [
         "modules",
         "module_deps",
         "symbols",
         "refs",
         "imports",
         "field_accesses",
         "branches",
         "bodies",
         "literals",
         "docstrings"
     ],
     SCHEMA = """
CREATE TABLE IF NOT EXISTS meta (
    key   TEXT PRIMARY KEY,
    value TEXT
);
CREATE TABLE IF NOT EXISTS modules (
    path         TEXT PRIMARY KEY,
    module_name  TEXT,
    content_hash TEXT,
    role         TEXT,
    fact_hash    TEXT,
    status       TEXT,
    error_count  INTEGER
);
CREATE TABLE IF NOT EXISTS module_deps (
    id        TEXT,
    from_path TEXT,
    to_path   TEXT
);
CREATE TABLE IF NOT EXISTS symbols (
    id             TEXT PRIMARY KEY,
    module_path    TEXT,
    name           TEXT,
    kind           TEXT,
    access         TEXT,
    imported       INTEGER,
    parent_id      TEXT,
    decl_pos_start INTEGER,
    decl_pos_end   INTEGER,
    decl_line      INTEGER,
    scope_chain    TEXT
);
CREATE TABLE IF NOT EXISTS refs (
    id          TEXT,
    used_id     TEXT,
    using_id    TEXT,
    module_path TEXT,
    pos_start   INTEGER,
    pos_end     INTEGER,
    line        INTEGER,
    kind        TEXT
);
CREATE TABLE IF NOT EXISTS imports (
    module_path    TEXT,
    item_name      TEXT,
    alias          TEXT,
    resolved_id    TEXT,
    resolved_path  TEXT,
    pos_start      INTEGER,
    pos_end        INTEGER,
    line           INTEGER,
    is_from        INTEGER,
    stmt_pos_start INTEGER,
    stmt_pos_end   INTEGER,
    n_items        INTEGER
);
CREATE TABLE IF NOT EXISTS field_accesses (
    field_id    TEXT,
    module_path TEXT,
    pos_start   INTEGER,
    pos_end     INTEGER,
    line        INTEGER,
    kind        TEXT
);
CREATE TABLE IF NOT EXISTS branches (
    module_path   TEXT,
    cond_value    TEXT,
    is_elif       INTEGER,
    has_else      INTEGER,
    if_pos_start  INTEGER,
    if_pos_end    INTEGER,
    cond_pos_start INTEGER,
    cond_pos_end  INTEGER,
    line          INTEGER
);
CREATE TABLE IF NOT EXISTS bodies (
    symbol_id       TEXT,
    name            TEXT,
    module_path     TEXT,
    owner_id        TEXT,
    owner_name      TEXT,
    body_file       TEXT,
    body_pos_start  INTEGER,
    body_pos_end    INTEGER,
    stmt_pos_start  INTEGER,
    stmt_pos_end    INTEGER,
    exact_hash      TEXT,
    structural_hash TEXT,
    arity           INTEGER,
    is_async        INTEGER,
    is_gen          INTEGER,
    stmt_count      INTEGER,
    line_count      INTEGER,
    size_band       INTEGER,
    completeness    TEXT,
    vector          TEXT,
    stmt_seq        TEXT,
    struct_tokens   TEXT
);
CREATE TABLE IF NOT EXISTS literals (
    module_path  TEXT,
    value_hash   TEXT,
    value_repr   TEXT,
    literal_kind TEXT,
    size         INTEGER,
    owner_id     TEXT,
    owner_name   TEXT,
    pos_start    INTEGER,
    pos_end      INTEGER,
    line         INTEGER
);
CREATE TABLE IF NOT EXISTS docstrings (
    symbol_id   TEXT,
    name        TEXT,
    module_path TEXT,
    kind        TEXT,
    text_hash   TEXT,
    text        TEXT,
    length      INTEGER,
    pos_start   INTEGER,
    pos_end     INTEGER,
    line        INTEGER
);
CREATE INDEX IF NOT EXISTS idx_refs_used      ON refs(used_id, kind);
CREATE INDEX IF NOT EXISTS idx_refs_using     ON refs(using_id, kind);
CREATE INDEX IF NOT EXISTS idx_refs_mod       ON refs(module_path);
CREATE INDEX IF NOT EXISTS idx_refs_id        ON refs(id);
CREATE INDEX IF NOT EXISTS idx_sym_mod        ON symbols(module_path, kind, imported);
CREATE INDEX IF NOT EXISTS idx_sym_name       ON symbols(name, kind);
CREATE INDEX IF NOT EXISTS idx_fld_field      ON field_accesses(field_id);
CREATE INDEX IF NOT EXISTS idx_imp_mod        ON imports(module_path);
CREATE INDEX IF NOT EXISTS idx_dep_from       ON module_deps(from_path);
CREATE INDEX IF NOT EXISTS idx_dep_to         ON module_deps(to_path);
CREATE INDEX IF NOT EXISTS idx_dep_id         ON module_deps(id);
CREATE INDEX IF NOT EXISTS idx_body_exact     ON bodies(exact_hash);
CREATE INDEX IF NOT EXISTS idx_body_struct    ON bodies(structural_hash);
CREATE INDEX IF NOT EXISTS idx_body_sym       ON bodies(symbol_id);
CREATE INDEX IF NOT EXISTS idx_body_mod       ON bodies(module_path);
CREATE INDEX IF NOT EXISTS idx_body_bucket    ON bodies(arity, is_async, size_band);
CREATE INDEX IF NOT EXISTS idx_lit_hash       ON literals(value_hash);
CREATE INDEX IF NOT EXISTS idx_lit_mod        ON literals(module_path);
CREATE INDEX IF NOT EXISTS idx_doc_hash       ON docstrings(text_hash);
CREATE INDEX IF NOT EXISTS idx_doc_mod        ON docstrings(module_path);
""";


def _scope(col: str) -> str {
    return f" AND {col} IN (SELECT path FROM active_scope)";
}


obj FactStore {
    has db_path: str,
        conn: any = None;

    def open {
        self.conn = sqlite3.connect(self.db_path);

        self.conn.isolation_level = None;
        self.conn.execute("PRAGMA busy_timeout=5000");
        try {
            self.conn.execute("PRAGMA journal_mode=WAL");
        } except Exception {
            pass;
        }
        self.conn.executescript(SCHEMA);
        self._migrate();
        self._ensure_scope();
    }

    def close {
        if self.conn is not None {
            self.conn.close();
            self.conn = None;
        }
    }

    def _migrate {
        want = f"{FACT_SCHEMA_VERSION}/{EXTRACTOR_VERSION}";
        cur = self.conn.execute("SELECT value FROM meta WHERE key = 'version'");
        row = cur.fetchone();
        have = cast(str, row[0]) if row else "";
        if have != want {
            for tbl in _DATA_TABLES {
                self.conn.execute(f"DROP TABLE IF EXISTS {tbl}");
            }
            self.conn.executescript(SCHEMA);
            self.conn.execute(
                "INSERT OR REPLACE INTO meta(key, value) VALUES ('version', ?)",
                (want, )
            );
        }
    }

    def _ensure_scope {
        self.conn.execute(
            "CREATE TEMP TABLE IF NOT EXISTS active_scope (path TEXT PRIMARY KEY)"
        );
    }

    def set_scope(paths: list[str]) {
        self._ensure_scope();
        self.conn.execute("DELETE FROM active_scope");
        self.conn.executemany(
            "INSERT OR IGNORE INTO active_scope(path) VALUES (?)",
            [(p, ) for p in paths]
        );
    }

    def stored_fact_hash(path: str) -> (str | None) {
        cur = self.conn.execute(
            "SELECT fact_hash FROM modules WHERE path = ?", (path, )
        );
        row = cur.fetchone();
        return cast(str, row[0]) if row else None;
    }

    def _clear_module(path: str) {
        for tbl in [
            "symbols",
            "refs",
            "imports",
            "field_accesses",
            "branches",
            "bodies",
            "literals",
            "docstrings"
        ] {
            self.conn.execute(f"DELETE FROM {tbl} WHERE module_path = ?", (path, ));
        }
        self.conn.execute("DELETE FROM module_deps WHERE from_path = ?", (path, ));
        self.conn.execute("DELETE FROM modules WHERE path = ?", (path, ));
    }

    def write_module(
        mod: ModuleFact,
        symbols: list[SymbolFact],
        refs: list[ReferenceFact],
        imports: list[ImportFact],
        fields: list[FieldAccessFact],
        branches: list[BranchFact] = [],
        bodies: list[BodyFact] = [],
        literals: list[LiteralFact] = [],
        docstrings: list[DocstringFact] = []
    ) {
        self._clear_module(mod.path);
        self.conn.execute(
            "INSERT INTO modules(path, module_name, content_hash, role, "
            "fact_hash, status, error_count) VALUES (?, ?, ?, ?, ?, ?, ?)",
            (
                mod.path,
                mod.module_name,
                mod.content_hash,
                mod.role,
                mod.fact_hash,
                mod.status,
                mod.error_count
            )
        );
        self.conn.executemany(
            "INSERT INTO module_deps(id, from_path, to_path) VALUES (?, ?, ?)",
            [(dep_fact_id(mod.path, dep), mod.path, dep) for dep in mod.deps]
        );
        self.conn.executemany(
            "INSERT INTO symbols(id, module_path, name, kind, access, imported, "
            "parent_id, decl_pos_start, decl_pos_end, decl_line, scope_chain) "
            "VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)",
            [
                (
                    s.id,
                    s.module_path,
                    s.name,
                    s.kind,
                    s.access,
                    1 if s.imported else 0,
                    s.parent_id,
                    s.decl_pos_start,
                    s.decl_pos_end,
                    s.decl_line,
                    s.scope_chain
                ) for s in symbols
            ]
        );
        self.conn.executemany(
            "INSERT INTO refs(id, used_id, using_id, module_path, pos_start, "
            "pos_end, line, kind) VALUES (?, ?, ?, ?, ?, ?, ?, ?)",
            [
                (
                    r.id,
                    r.used_id,
                    r.using_id,
                    r.module_path,
                    r.pos_start,
                    r.pos_end,
                    r.line,
                    r.kind
                ) for r in refs
            ]
        );
        self.conn.executemany(
            "INSERT INTO imports(module_path, item_name, alias, resolved_id, "
            "resolved_path, pos_start, pos_end, line, is_from, "
            "stmt_pos_start, stmt_pos_end, n_items) "
            "VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)",
            [
                (
                    im.module_path,
                    im.item_name,
                    im.alias,
                    im.resolved_id,
                    im.resolved_path,
                    im.pos_start,
                    im.pos_end,
                    im.line,
                    1 if im.is_from else 0,
                    im.stmt_pos_start,
                    im.stmt_pos_end,
                    im.n_items
                ) for im in imports
            ]
        );
        self.conn.executemany(
            "INSERT INTO field_accesses(field_id, module_path, pos_start, pos_end, line, kind) "
            "VALUES (?, ?, ?, ?, ?, ?)",
            [
                (
                    fa.field_id,
                    fa.module_path,
                    fa.pos_start,
                    fa.pos_end,
                    fa.line,
                    fa.kind
                ) for fa in fields
            ]
        );
        self.conn.executemany(
            "INSERT INTO branches(module_path, cond_value, is_elif, has_else, "
            "if_pos_start, if_pos_end, cond_pos_start, cond_pos_end, line) "
            "VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)",
            [
                (
                    br.module_path,
                    br.cond_value,
                    1 if br.is_elif else 0,
                    1 if br.has_else else 0,
                    br.if_pos_start,
                    br.if_pos_end,
                    br.cond_pos_start,
                    br.cond_pos_end,
                    br.line
                ) for br in branches
            ]
        );
        self.conn.executemany(
            "INSERT INTO bodies(symbol_id, name, module_path, owner_id, "
            "owner_name, body_file, body_pos_start, body_pos_end, "
            "stmt_pos_start, stmt_pos_end, exact_hash, "
            "structural_hash, arity, is_async, is_gen, stmt_count, line_count, "
            "size_band, completeness, vector, stmt_seq, struct_tokens) "
            "VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)",
            [
                (
                    bd.symbol_id,
                    bd.name,
                    bd.module_path,
                    bd.owner_id,
                    bd.owner_name,
                    bd.body_file,
                    bd.body_pos_start,
                    bd.body_pos_end,
                    bd.stmt_pos_start,
                    bd.stmt_pos_end,
                    bd.exact_hash,
                    bd.structural_hash,
                    bd.arity,
                    1 if bd.is_async else 0,
                    1 if bd.is_gen else 0,
                    bd.stmt_count,
                    bd.line_count,
                    bd.size_band,
                    bd.completeness,
                    bd.vector,
                    bd.stmt_seq,
                    bd.struct_tokens
                ) for bd in bodies
            ]
        );
        self.conn.executemany(
            "INSERT INTO literals(module_path, value_hash, value_repr, "
            "literal_kind, size, owner_id, owner_name, pos_start, pos_end, line) "
            "VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)",
            [
                (
                    lit.module_path,
                    lit.value_hash,
                    lit.value_repr,
                    lit.literal_kind,
                    lit.size,
                    lit.owner_id,
                    lit.owner_name,
                    lit.pos_start,
                    lit.pos_end,
                    lit.line
                ) for lit in literals
            ]
        );
        self.conn.executemany(
            "INSERT INTO docstrings(symbol_id, name, module_path, kind, "
            "text_hash, text, length, pos_start, pos_end, line) "
            "VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)",
            [
                (
                    dc.symbol_id,
                    dc.name,
                    dc.module_path,
                    dc.kind,
                    dc.text_hash,
                    dc.text,
                    dc.length,
                    dc.pos_start,
                    dc.pos_end,
                    dc.line
                ) for dc in docstrings
            ]
        );
    }

    def sync(facts: FactSet) -> tuple[list[str], list[str]] {
        grouped = facts.by_module();
        refreshed: list[str] = [];
        skipped: list[str] = [];
        self.conn.execute("BEGIN IMMEDIATE");
        try {
            for mod in facts.modules {
                if self.stored_fact_hash(mod.path) == mod.fact_hash and mod.fact_hash {
                    skipped.append(mod.path);
                    continue;
                }
                bundle = grouped.get(mod.path);
                if bundle is None {
                    self.write_module(mod, [], [], [], [], [], [], [], []);
                } else {
                    self.write_module(
                        mod,
                        cast(list[SymbolFact], bundle[0]),
                        cast(list[ReferenceFact], bundle[1]),
                        cast(list[ImportFact], bundle[2]),
                        cast(list[FieldAccessFact], bundle[3]),
                        cast(list[BranchFact], bundle[4]),
                        cast(list[BodyFact], bundle[5]),
                        cast(list[LiteralFact], bundle[6]),
                        cast(list[DocstringFact], bundle[7])
                    );
                }
                refreshed.append(mod.path);
            }
            self.conn.execute("COMMIT");
        } except Exception {
            self.conn.execute("ROLLBACK");
            raise;
        }

        self.set_scope([m.path for m in facts.modules]);
        return (refreshed, skipped);
    }

    def use_count(symbol_id: str) -> int {
        cur = self.conn.execute(
            "SELECT COUNT(*) FROM refs WHERE used_id = ?" + _scope("module_path"),
            (symbol_id, )
        );
        return int(cur.fetchone()[0]);
    }

    def external_use_count(symbol_id: str) -> int {
        cur = self.conn.execute(
            "SELECT s.module_path, s.decl_pos_start, s.decl_pos_end "
            "FROM symbols s WHERE s.id = ?",
            (symbol_id, )
        );
        row = cur.fetchone();
        if not row {
            return self.use_count(symbol_id);
        }
        cur2 = self.conn.execute(
            "SELECT COUNT(*) FROM refs WHERE used_id = ? AND NOT "
            "(module_path = ? AND pos_start >= ? AND pos_end <= ?)" + _scope(
                "module_path"
            ),
            (symbol_id, row[0], row[1], row[2])
        );
        return int(cur2.fetchone()[0]);
    }

    def cross_module_use_count(symbol_id: str) -> int {
        cur = self.conn.execute(
            "SELECT s.module_path FROM symbols s WHERE s.id = ?", (symbol_id, )
        );
        row = cur.fetchone();
        if not row {
            return 0;
        }
        cur2 = self.conn.execute(
            "SELECT COUNT(*) FROM refs WHERE used_id = ? AND module_path != ?" + _scope(
                "module_path"
            ),
            (symbol_id, row[0])
        );
        return int(cur2.fetchone()[0]);
    }

    def is_reexported(symbol_id: str) -> bool {
        cur = self.conn.execute(
            "SELECT i.module_path FROM imports i WHERE i.resolved_id = ?" + _scope(
                "i.module_path"
            ),
            (symbol_id, )
        );
        for row in cur.fetchall() {
            if str(row[0]).endswith("__init__.jac") {
                return True;
            }
        }
        return False;
    }

    def field_rw_counts(field_id: str) -> tuple[int, int] {
        cur = self.conn.execute(
            "SELECT kind, COUNT(*) FROM field_accesses WHERE field_id = ?" + _scope(
                "module_path"
            ) + " GROUP BY kind",
            (field_id, )
        );
        reads = 0;
        writes = 0;
        for (kind, n) in cur.fetchall() {
            if kind == "write" or kind == "del" {
                writes += int(n);
            } else {
                reads += int(n);
            }
        }
        return (reads, writes);
    }

    def unused_import_items -> list[dict] {
        cur = self.conn.execute(
            "SELECT i.module_path, i.item_name, i.alias, i.resolved_id, "
            "i.pos_start, i.pos_end, i.line, i.stmt_pos_start, i.stmt_pos_end, "
            "i.n_items, i.is_from, i.resolved_path "
            "FROM imports i WHERE i.resolved_id != ''" + _scope("i.module_path") + " AND (SELECT COUNT(*) FROM refs r WHERE r.used_id = i.resolved_id" + _scope(
                "r.module_path"
            ) + ") = 0 " "ORDER BY i.module_path, i.pos_start"
        );
        out: list[dict] = [];
        for row in cur.fetchall() {
            out.append(
                {
                    "module_path": row[0],
                    "item_name": row[1],
                    "alias": row[2],
                    "resolved_id": row[3],
                    "pos_start": row[4],
                    "pos_end": row[5],
                    "line": row[6],
                    "stmt_pos_start": row[7],
                    "stmt_pos_end": row[8],
                    "n_items": row[9],
                    "is_from": bool(row[10]),
                    "resolved_path": row[11]
                }
            );
        }
        return out;
    }

    def module_leaf_names -> set {
        out: set = set();
        for row in self.conn.execute(
            "SELECT module_name, path FROM modules"
        ).fetchall() {
            mod_name = str(row[0] or "");
            if mod_name {
                out.add(mod_name.rsplit(".", 1)[-1]);
            }
            base = os.path.basename(str(row[1] or ""));
            if base.endswith(".jac") {
                out.add(base[:-4]);
            }
        }
        return out;
    }

    def symbols_for_detection -> list[dict] {
        cur = self.conn.execute(
            "SELECT id, module_path, name, kind, access, imported, parent_id, "
            "decl_pos_start, decl_pos_end, decl_line, scope_chain "
            "FROM symbols WHERE imported = 0" + _scope("module_path") + " ORDER BY module_path, decl_pos_start, id"
        );
        out: list[dict] = [];
        for row in cur.fetchall() {
            out.append(
                {
                    "id": row[0],
                    "module_path": row[1],
                    "name": row[2],
                    "kind": row[3],
                    "access": row[4],
                    "imported": bool(row[5]),
                    "parent_id": row[6],
                    "decl_pos_start": row[7],
                    "decl_pos_end": row[8],
                    "decl_line": row[9],
                    "scope_chain": row[10]
                }
            );
        }
        return out;
    }

    def literal_branches -> list[dict] {
        cur = self.conn.execute(
            "SELECT module_path, cond_value, is_elif, has_else, if_pos_start, "
            "if_pos_end, cond_pos_start, cond_pos_end, line FROM branches "
            "WHERE 1 = 1" + _scope("module_path") + " ORDER BY module_path, if_pos_start"
        );
        out: list[dict] = [];
        for row in cur.fetchall() {
            out.append(
                {
                    "module_path": row[0],
                    "cond_value": row[1],
                    "is_elif": bool(row[2]),
                    "has_else": bool(row[3]),
                    "if_pos_start": row[4],
                    "if_pos_end": row[5],
                    "cond_pos_start": row[6],
                    "cond_pos_end": row[7],
                    "line": row[8]
                }
            );
        }
        return out;
    }

    def module_name(path: str) -> str {
        cur = self.conn.execute(
            "SELECT module_name FROM modules WHERE path = ?", (path, )
        );
        row = cur.fetchone();
        return cast(str, row[0]) if row and row[0] else "";
    }

    def module_status(path: str) -> dict {
        cur = self.conn.execute(
            "SELECT status, error_count FROM modules WHERE path = ?", (path, )
        );
        row = cur.fetchone();
        if not row {
            return {"status": "unknown", "error_count": 0};
        }
        return {"status": str(row[0]), "error_count": int(row[1])};
    }

    def symbol_row(symbol_id: str) -> (dict | None) {
        cur = self.conn.execute(
            "SELECT id, module_path, name, kind, access, imported, parent_id, "
            "decl_pos_start, decl_pos_end, decl_line, scope_chain "
            "FROM symbols WHERE id = ?",
            (symbol_id, )
        );
        row = cur.fetchone();
        if not row {
            return None;
        }
        return {
            "id": row[0],
            "module_path": row[1],
            "name": row[2],
            "kind": row[3],
            "access": row[4],
            "imported": bool(row[5]),
            "parent_id": row[6],
            "decl_pos_start": row[7],
            "decl_pos_end": row[8],
            "decl_line": row[9],
            "scope_chain": row[10]
        };
    }

    def symbol_exists(symbol_id: str) -> bool {
        cur = self.conn.execute(
            "SELECT 1 FROM symbols WHERE id = ? LIMIT 1", (symbol_id, )
        );
        return cur.fetchone() is not None;
    }

    def ref_exists(ref_id: str) -> bool {
        cur = self.conn.execute("SELECT 1 FROM refs WHERE id = ? LIMIT 1", (ref_id, ));
        return cur.fetchone() is not None;
    }

    def dep_exists(dep_id: str) -> bool {
        cur = self.conn.execute(
            "SELECT 1 FROM module_deps WHERE id = ? LIMIT 1", (dep_id, )
        );
        return cur.fetchone() is not None;
    }

    def module_exists(module_path: str) -> bool {
        cur = self.conn.execute(
            "SELECT 1 FROM modules WHERE path = ? LIMIT 1", (module_path, )
        );
        return cur.fetchone() is not None;
    }

    def callers_of(symbol_id: str) -> list[str] {
        cur = self.conn.execute(
            "SELECT DISTINCT using_id FROM refs "
            "WHERE used_id = ? AND kind = 'call' AND using_id != ''" + _scope(
                "module_path"
            ) + " ORDER BY using_id",
            (symbol_id, )
        );
        return [str(row[0]) for row in cur.fetchall()];
    }

    def callees_of(symbol_id: str) -> list[str] {
        cur = self.conn.execute(
            "SELECT DISTINCT used_id FROM refs "
            "WHERE using_id = ? AND kind = 'call' AND used_id != ''" + _scope(
                "module_path"
            ) + " ORDER BY used_id",
            (symbol_id, )
        );
        return [str(row[0]) for row in cur.fetchall()];
    }

    def callers_of_many(symbol_ids: list[str]) -> dict[str, list[str]] {
        out: dict[str, list[str]] = {sid: [] for sid in symbol_ids};
        if not symbol_ids {
            return out;
        }
        seen: set = set();
        placeholders = ",".join(["?"] * len(symbol_ids));
        cur = self.conn.execute(
            f"SELECT DISTINCT used_id, using_id FROM refs "
            f"WHERE kind = 'call' AND using_id != '' AND used_id IN ({placeholders})" + _scope(
                "module_path"
            ) + " ORDER BY used_id, using_id",
            tuple(symbol_ids)
        );
        for (used, using) in cur.fetchall() {
            key = (str(used), str(using));
            if key in seen {
                continue;
            }
            seen.add(key);
            out[str(used)].append(str(using));
        }
        return out;
    }

    def callees_of_many(symbol_ids: list[str]) -> dict[str, list[str]] {
        out: dict[str, list[str]] = {sid: [] for sid in symbol_ids};
        if not symbol_ids {
            return out;
        }
        seen: set = set();
        placeholders = ",".join(["?"] * len(symbol_ids));
        cur = self.conn.execute(
            f"SELECT DISTINCT using_id, used_id FROM refs "
            f"WHERE kind = 'call' AND used_id != '' AND using_id IN ({placeholders})" + _scope(
                "module_path"
            ) + " ORDER BY using_id, used_id",
            tuple(symbol_ids)
        );
        for (using, used) in cur.fetchall() {
            key = (str(using), str(used));
            if key in seen {
                continue;
            }
            seen.add(key);
            out[str(using)].append(str(used));
        }
        return out;
    }

    def call_edges -> list[tuple[str, str]] {
        cur = self.conn.execute(
            "SELECT DISTINCT using_id, used_id FROM refs "
            "WHERE kind = 'call' AND using_id != '' AND used_id != ''" + _scope(
                "module_path"
            ) + " ORDER BY using_id, used_id"
        );
        return [(str(row[0]), str(row[1])) for row in cur.fetchall()];
    }

    def symbols_in_module(path: str) -> list[dict] {
        cur = self.conn.execute(
            "SELECT id, name, kind, access, decl_line FROM symbols "
            "WHERE module_path = ? AND imported = 0 ORDER BY decl_line, id",
            (path, )
        );
        return [
            {
                "id": row[0],
                "name": row[1],
                "kind": row[2],
                "access": row[3],
                "decl_line": row[4]
            } for row in cur.fetchall()
        ];
    }

    def deps_of(path: str) -> list[str] {
        cur = self.conn.execute(
            "SELECT to_path FROM module_deps WHERE from_path = ? ORDER BY to_path",
            (path, )
        );
        return [str(row[0]) for row in cur.fetchall()];
    }

    def module_dep_edges -> list[tuple[str, str]] {
        cur = self.conn.execute(
            "SELECT from_path, to_path FROM module_deps " "WHERE 1 = 1" + _scope(
                "from_path"
            ) + " ORDER BY from_path, to_path"
        );
        return [(str(row[0]), str(row[1])) for row in cur.fetchall()];
    }

    def symbol_ref_edges -> list[dict] {
        cur = self.conn.execute(
            "SELECT DISTINCT r.using_id, su.module_path, r.used_id, sd.module_path "
            "FROM refs r "
            "JOIN symbols su ON su.id = r.using_id AND su.imported = 0 "
            "JOIN symbols sd ON sd.id = r.used_id AND sd.imported = 0 "
            "WHERE r.using_id != '' AND r.used_id != '' AND r.using_id != r.used_id" + _scope(
                "r.module_path"
            ) + " ORDER BY su.module_path, r.using_id, r.used_id"
        );
        return [
            {
                "using_id": str(row[0]),
                "using_mod": str(row[1]),
                "used_id": str(row[2]),
                "used_mod": str(row[3])
            } for row in cur.fetchall()
        ];
    }

    def callable_symbols -> list[dict] {
        cur = self.conn.execute(
            "SELECT id, module_path, name, kind, access, scope_chain "
            "FROM symbols WHERE imported = 0 AND kind IN ('ability', 'method')" + _scope(
                "module_path"
            ) + " ORDER BY module_path, decl_pos_start, id"
        );
        return [
            {
                "id": row[0],
                "module_path": row[1],
                "name": row[2],
                "kind": row[3],
                "access": row[4],
                "scope_chain": row[5]
            } for row in cur.fetchall()
        ];
    }

    def private_callable_bodies -> list[dict] {
        cur = self.conn.execute(
            "SELECT s.id, s.module_path, s.name, s.kind, s.access, "
            "s.scope_chain, s.decl_pos_start, s.decl_pos_end, s.decl_line, "
            "b.stmt_count, b.line_count "
            "FROM symbols s JOIN bodies b ON s.id = b.symbol_id "
            "WHERE s.imported = 0 AND s.kind IN ('ability', 'method') "
            "AND s.access IN ('private', 'protected') "
            "AND b.completeness = 'complete'" + _scope("s.module_path") + " ORDER BY s.module_path, s.decl_pos_start, s.id"
        );
        out: list[dict] = [];
        for row in cur.fetchall() {
            out.append(
                {
                    "id": row[0],
                    "module_path": row[1],
                    "name": row[2],
                    "kind": row[3],
                    "access": row[4],
                    "scope_chain": row[5],
                    "decl_pos_start": row[6],
                    "decl_pos_end": row[7],
                    "decl_line": row[8],
                    "stmt_count": row[9],
                    "line_count": row[10]
                }
            );
        }
        return out;
    }

    def candidate_bodies -> list[dict] {
        cur = self.conn.execute(
            "SELECT symbol_id, name, module_path, owner_id, owner_name, "
            "body_file, body_pos_start, body_pos_end, stmt_pos_start, "
            "stmt_pos_end, exact_hash, "
            "structural_hash, arity, is_async, is_gen, stmt_count, line_count, "
            "size_band, completeness, vector, struct_tokens FROM bodies "
            "WHERE completeness = 'complete'" + _scope("module_path") + " ORDER BY structural_hash, exact_hash, module_path, "
            "body_pos_start, symbol_id"
        );
        out: list[dict] = [];
        for row in cur.fetchall() {
            out.append(
                {
                    "symbol_id": row[0],
                    "name": row[1],
                    "module_path": row[2],
                    "owner_id": row[3],
                    "owner_name": row[4],
                    "body_file": row[5],
                    "body_pos_start": row[6],
                    "body_pos_end": row[7],
                    "stmt_pos_start": row[8],
                    "stmt_pos_end": row[9],
                    "exact_hash": row[10],
                    "structural_hash": row[11],
                    "arity": row[12],
                    "is_async": bool(row[13]),
                    "is_gen": bool(row[14]),
                    "stmt_count": row[15],
                    "line_count": row[16],
                    "size_band": row[17],
                    "completeness": row[18],
                    "vector": row[19],
                    "struct_tokens": row[20]
                }
            );
        }
        return out;
    }

    def body_exists(symbol_id: str) -> bool {
        cur = self.conn.execute(
            "SELECT 1 FROM bodies WHERE symbol_id = ? LIMIT 1", (symbol_id, )
        );
        return cur.fetchone() is not None;
    }

    def body_stmt_count(symbol_id: str) -> int {
        cur = self.conn.execute(
            "SELECT stmt_count FROM bodies WHERE symbol_id = ? LIMIT 1", (symbol_id, )
        );
        row = cur.fetchone();
        return int(row[0]) if row and row[0] is not None else 0;
    }

    def ref_row(ref_id: str) -> (dict | None) {
        cur = self.conn.execute(
            "SELECT id, used_id, using_id, module_path, pos_start, pos_end, "
            "line, kind FROM refs WHERE id = ? LIMIT 1",
            (ref_id, )
        );
        row = cur.fetchone();
        if not row {
            return None;
        }
        return {
            "id": row[0],
            "used_id": row[1],
            "using_id": row[2],
            "module_path": row[3],
            "pos_start": row[4],
            "pos_end": row[5],
            "line": row[6],
            "kind": row[7]
        };
    }

    def stmt_sequences -> list[dict] {
        cur = self.conn.execute(
            "SELECT symbol_id, name, owner_id, owner_name, module_path, "
            "body_file, stmt_seq FROM bodies "
            "WHERE completeness = 'complete' AND stmt_seq != ''" + _scope(
                "module_path"
            ) + " ORDER BY module_path, symbol_id"
        );
        out: list[dict] = [];
        for row in cur.fetchall() {
            out.append(
                {
                    "symbol_id": row[0],
                    "name": row[1],
                    "owner_id": row[2],
                    "owner_name": row[3],
                    "module_path": row[4],
                    "body_file": row[5],
                    "stmt_seq": row[6]
                }
            );
        }
        return out;
    }

    def duplicated_literals(min_size: int, min_sites: int = 2) -> list[dict] {
        cur = self.conn.execute(
            "SELECT value_hash, literal_kind, size, module_path, owner_id, "
            "owner_name, pos_start, pos_end, line FROM literals "
            "WHERE size >= ?" + _scope("module_path") + " ORDER BY value_hash, module_path, pos_start",
            (min_size, )
        );
        groups: dict[str, dict] = {};
        order: list[str] = [];
        for row in cur.fetchall() {
            vh = str(row[0]);
            if vh not in groups {
                groups[vh] = {
                    "value_hash": vh,
                    "literal_kind": str(row[1]),
                    "size": int(row[2]),
                    "sites": []
                };
                order.append(vh);
            }
            cast(list, groups[vh]["sites"]).append(
                {
                    "module_path": str(row[3]),
                    "owner_id": str(row[4]),
                    "owner_name": str(row[5]),
                    "pos_start": int(row[6]),
                    "pos_end": int(row[7]),
                    "line": int(row[8])
                }
            );
        }
        out: list[dict] = [];
        for vh in order {
            g = groups[vh];
            if len(cast(list, g["sites"])) >= min_sites {
                out.append(g);
            }
        }
        return out;
    }

    def duplicate_docstrings(min_length: int = 0) -> list[dict] {
        cur = self.conn.execute(
            "SELECT text_hash, symbol_id, name, module_path, kind, length, "
            "pos_start, pos_end, line FROM docstrings "
            "WHERE length >= ?" + _scope("module_path") + " ORDER BY text_hash, symbol_id, module_path, pos_start",
            (min_length, )
        );
        groups: dict[str, dict] = {};
        order: list[str] = [];
        for row in cur.fetchall() {
            th = str(row[0]);
            sid = str(row[1]);
            if th not in groups {
                groups[th] = {
                    "text_hash": th,
                    "length": int(row[5]),
                    "kinds": set(),
                    "seen": set(),
                    "sites": []
                };
                order.append(th);
            }
            g = groups[th];
            cast(set, g["kinds"]).add(str(row[4]));
            if sid in cast(set, g["seen"]) {
                continue;
            }
            cast(set, g["seen"]).add(sid);
            cast(list, g["sites"]).append(
                {
                    "symbol_id": sid,
                    "name": str(row[2]),
                    "module_path": str(row[3]),
                    "kind": str(row[4]),
                    "pos_start": int(row[6]),
                    "pos_end": int(row[7]),
                    "line": int(row[8])
                }
            );
        }
        out: list[dict] = [];
        for th in order {
            g = groups[th];
            if len(cast(list, g["sites"])) >= 2 {
                out.append(
                    {
                        "text_hash": g["text_hash"],
                        "length": g["length"],
                        "kinds": sorted(cast(set, g["kinds"])),
                        "sites": g["sites"]
                    }
                );
            }
        }
        return out;
    }

    def counts -> dict[str, int] {
        out: dict[str, int] = {};
        for tbl in [
            "modules",
            "symbols",
            "refs",
            "imports",
            "field_accesses",
            "branches",
            "module_deps",
            "bodies",
            "literals",
            "docstrings"
        ] {
            cur = self.conn.execute(f"SELECT COUNT(*) FROM {tbl}");
            out[tbl] = int(cur.fetchone()[0]);
        }
        return out;
    }
}
