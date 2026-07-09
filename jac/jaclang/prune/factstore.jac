import sqlite3;

import from jaclang.prune.extract {
    FactSet,
    ModuleFact,
    SymbolFact,
    ReferenceFact,
    ImportFact,
    FieldAccessFact
}


glob SCHEMA = """
CREATE TABLE IF NOT EXISTS modules (
    path         TEXT PRIMARY KEY,
    module_name  TEXT,
    content_hash TEXT,
    role         TEXT
);
CREATE TABLE IF NOT EXISTS module_deps (
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
    used_id     TEXT,
    using_id    TEXT,
    module_path TEXT,
    pos_start   INTEGER,
    pos_end     INTEGER,
    line        INTEGER,
    kind        TEXT
);
CREATE TABLE IF NOT EXISTS imports (
    module_path   TEXT,
    item_name     TEXT,
    alias         TEXT,
    resolved_id   TEXT,
    resolved_path TEXT,
    pos_start     INTEGER,
    pos_end       INTEGER,
    line          INTEGER,
    is_from       INTEGER
);
CREATE TABLE IF NOT EXISTS field_accesses (
    field_id    TEXT,
    module_path TEXT,
    pos_start   INTEGER,
    pos_end     INTEGER,
    line        INTEGER,
    kind        TEXT
);
CREATE INDEX IF NOT EXISTS idx_refs_used   ON refs(used_id);
CREATE INDEX IF NOT EXISTS idx_refs_mod    ON refs(module_path);
CREATE INDEX IF NOT EXISTS idx_sym_mod     ON symbols(module_path);
CREATE INDEX IF NOT EXISTS idx_fld_field   ON field_accesses(field_id);
""";


obj FactStore {
    has db_path: str,
        conn: any = None;

    def open {
        self.conn = sqlite3.connect(self.db_path);
        self.conn.executescript(SCHEMA);
        self.conn.commit();
    }

    def close {
        if self.conn is not None {
            self.conn.commit();
            self.conn.close();
            self.conn = None;
        }
    }

    def stored_hash(path: str) -> (str | None) {
        cur = self.conn.execute(
            "SELECT content_hash FROM modules WHERE path = ?", (path, )
        );
        row = cur.fetchone();
        return row[0] if row else None;
    }

    def _clear_module(path: str) {
        for tbl in ["symbols", "refs", "imports", "field_accesses"] {
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
        fields: list[FieldAccessFact]
    ) {
        self._clear_module(mod.path);
        self.conn.execute(
            "INSERT INTO modules(path, module_name, content_hash, role) VALUES (?, ?, ?, ?)",
            (mod.path, mod.module_name, mod.content_hash, mod.role)
        );
        self.conn.executemany(
            "INSERT INTO module_deps(from_path, to_path) VALUES (?, ?)",
            [(mod.path, dep) for dep in mod.deps]
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
            "INSERT INTO refs(used_id, using_id, module_path, pos_start, pos_end, line, kind) "
            "VALUES (?, ?, ?, ?, ?, ?, ?)",
            [
                (
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
            "resolved_path, pos_start, pos_end, line, is_from) "
            "VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)",
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
                    1 if im.is_from else 0
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
    }

    def sync(facts: FactSet) -> tuple[list[str], list[str]] {
        grouped = facts.by_module();
        refreshed: list[str] = [];
        skipped: list[str] = [];
        for mod in facts.modules {
            if self.stored_hash(mod.path) == mod.content_hash {
                skipped.append(mod.path);
                continue;
            }
            bundle = grouped.get(mod.path);
            self.write_module(
                mod,
                bundle[0] if bundle else [],
                bundle[1] if bundle else [],
                bundle[2] if bundle else [],
                bundle[3] if bundle else []
            );
            refreshed.append(mod.path);
        }
        self.conn.commit();
        return (refreshed, skipped);
    }

    def use_count(symbol_id: str) -> int {
        cur = self.conn.execute(
            "SELECT COUNT(*) FROM refs WHERE used_id = ?", (symbol_id, )
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
            "(module_path = ? AND pos_start >= ? AND pos_end <= ?)",
            (symbol_id, row[0], row[1], row[2])
        );
        return int(cur2.fetchone()[0]);
    }

    def field_rw_counts(field_id: str) -> tuple[int, int] {
        cur = self.conn.execute(
            "SELECT kind, COUNT(*) FROM field_accesses WHERE field_id = ? GROUP BY kind",
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
            "i.pos_start, i.pos_end, i.line "
            "FROM imports i WHERE i.resolved_id != '' AND "
            "(SELECT COUNT(*) FROM refs r WHERE r.used_id = i.resolved_id) = 0"
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
                    "line": row[6]
                }
            );
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
            "module_deps"
        ] {
            cur = self.conn.execute(f"SELECT COUNT(*) FROM {tbl}");
            out[tbl] = int(cur.fetchone()[0]);
        }
        return out;
    }
}
