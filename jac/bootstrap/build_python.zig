//! Build the release Python before any Jac tooling can run. Sources are
//! checksum-pinned; the completed distribution is cached independently of Jac.
const std = @import("std");
const builtin = @import("builtin");
const seed = @import("seed.zig");
const Io = std.Io;
const inputs = [_][]const u8{
    "bootstrap/build_python.zig",    "bootstrap/seed.zig",
    "bootstrap/python/sources.json", "bootstrap/python/cpython-sources.txt",
    "bootstrap/python/build.sh",     "bootstrap/python/smoke.py",
    "bootstrap/python/finalize.py",
};
const Source = struct { url: []const u8, sha256: []const u8, version: ?[]const u8 = null };

pub fn supported(platform: []const u8) bool {
    for ([_][]const u8{ "linux-x86_64", "linux-aarch64", "macos-x86_64", "macos-aarch64" }) |p| {
        if (std.mem.eql(u8, p, platform)) return true;
    }
    return false;
}

fn hostPlatform() []const u8 {
    return switch (builtin.os.tag) {
        .linux => switch (builtin.cpu.arch) {
            .x86_64 => "linux-x86_64",
            .aarch64 => "linux-aarch64",
            else => "unsupported",
        },
        .macos => switch (builtin.cpu.arch) {
            .x86_64 => "macos-x86_64",
            .aarch64 => "macos-aarch64",
            else => "unsupported",
        },
        else => "unsupported",
    };
}

pub fn main(init: std.process.Init) !void {
    const io = init.io;
    const a = init.arena.allocator();
    const args = try init.minimal.args.toSlice(a);
    if (args.len != 5) seed.die("usage: build_python <os-arch> <destination> <jac-root> <zig>", .{});
    const platform = args[1];
    if (!supported(platform)) seed.die("build-python: unsupported platform {s}", .{platform});
    if (!std.mem.eql(u8, platform, hostPlatform()))
        seed.die("build-python: build {s} on its matching release runner (host is {s})", .{ platform, hostPlatform() });
    const dest = args[2];
    const root = args[3];
    const smoke = try std.fs.path.join(a, &.{ root, "bootstrap/python/smoke.py" });
    var hash = std.crypto.hash.sha2.Sha256.init(.{});
    hash.update(platform);
    hash.update(builtin.zig_version_string);
    if (builtin.os.tag == .macos) {
        const sdk = try std.process.run(a, io, .{ .argv = &.{ "xcrun", "--sdk", "macosx", "--show-sdk-version" } });
        if (sdk.term != .exited or sdk.term.exited != 0) return error.MissingMacOSSDK;
        hash.update(std.mem.trim(u8, sdk.stdout, " \r\n"));
    }
    for (inputs) |path| {
        const full = try std.fs.path.join(a, &.{ root, path });
        const content = try Io.Dir.cwd().readFileAlloc(io, full, a, .unlimited);
        hash.update(path);
        hash.update(content);
    }
    var digest: [32]u8 = undefined;
    hash.final(&digest);
    const key = std.fmt.bytesToHex(digest, .lower);
    const stamp_path = try std.fs.path.join(a, &.{ dest, "build-key" });
    const old = Io.Dir.cwd().readFileAlloc(io, stamp_path, a, .limited(128)) catch "";
    const python = try std.fs.path.join(a, &.{ dest, "python/install/bin/python3.14" });
    if (std.mem.eql(u8, old, &key) and seed.fileExists(io, python)) {
        try runSmoke(io, python, smoke);
        seed.log("build-python: cached {s} ({s})", .{ platform, key[0..16] });
        return;
    }
    const work = try std.fmt.allocPrint(a, "{s}.work", .{dest});
    // A failed build never produces the completion stamp or replaces a good tree.
    try Io.Dir.cwd().deleteTree(io, work);
    try Io.Dir.cwd().createDirPath(io, work);
    const manifest_path = try std.fs.path.join(a, &.{ root, "bootstrap/python/sources.json" });
    const manifest = try Io.Dir.cwd().readFileAlloc(io, manifest_path, a, .unlimited);
    const sources = try std.json.parseFromSliceLeaky(std.json.ArrayHashMap(Source), a, manifest, .{});
    for (sources.map.keys(), sources.map.values()) |name, source| {
        seed.log("build-python: fetch {s}", .{name});
        const gz = try seed.httpGetAlloc(io, init.gpa, source.url);
        defer init.gpa.free(gz);
        const actual = seed.sha256Hex(gz);
        if (!std.mem.eql(u8, &actual, source.sha256))
            seed.die("build-python: checksum mismatch for {s}", .{name});
        const source_dir = try std.fs.path.join(a, &.{ work, "src", name });
        try Io.Dir.cwd().createDirPath(io, source_dir);
        var dir = try Io.Dir.cwd().openDir(io, source_dir, .{ .iterate = true });
        defer dir.close(io);
        const window = try init.gpa.alloc(u8, std.compress.flate.max_window_len);
        defer init.gpa.free(window);
        var reader = Io.Reader.fixed(gz);
        var decompressor: std.compress.flate.Decompress = .init(&reader, .gzip, window);
        try std.tar.extract(io, dir, &decompressor.reader, .{
            .mode_mode = .executable_bit_only,
            .strip_components = 1,
        });
        if (std.mem.eql(u8, name, "cpython")) {
            const list_path = try std.fs.path.join(a, &.{ root, "bootstrap/python/cpython-sources.txt" });
            const list = try Io.Dir.cwd().readFileAlloc(io, list_path, a, .limited(128 * 1024));
            try retainSources(io, a, dir, list);
        }
    }
    const recipe = try std.fs.path.join(a, &.{ root, "bootstrap/python" });
    const script = try std.fs.path.join(a, &.{ recipe, "build.sh" });
    var child = try std.process.spawn(io, .{ .argv = &.{ "sh", script, platform, work, args[4], recipe } });
    const term = try child.wait(io);
    if (term != .exited or term.exited != 0) seed.die("build-python: build failed; logs at {s}/logs", .{work});
    // Cache only the runtime and link archives, not intermediate objects or sources.
    try Io.Dir.cwd().deleteTree(io, try std.fs.path.join(a, &.{ work, "src" }));
    try Io.Dir.cwd().deleteTree(io, try std.fs.path.join(a, &.{ work, "deps" }));
    try Io.Dir.cwd().deleteTree(io, try std.fs.path.join(a, &.{ work, "bin" }));
    try Io.Dir.cwd().deleteTree(io, dest);
    try Io.Dir.cwd().rename(work, Io.Dir.cwd(), dest, io);
    // Verify relocation before allowing a cache hit on the next invocation.
    try runSmoke(io, python, smoke);
    try Io.Dir.cwd().writeFile(io, .{ .sub_path = stamp_path, .data = &key });
}

fn runSmoke(io: Io, python: []const u8, smoke: []const u8) !void {
    var check = try std.process.spawn(io, .{ .argv = &.{ python, "-I", smoke } });
    const result = try check.wait(io);
    if (result != .exited or result.exited != 0) {
        return error.RelocationFailed;
    }
}

fn safePath(path: []const u8) bool {
    if (path.len == 0 or std.fs.path.isAbsolute(path)) return false;
    if (std.mem.indexOfAny(u8, path, "\\:*?[]\t\r\n") != null) return false;
    var parts = std.mem.splitScalar(u8, path, '/');
    while (parts.next()) |part| {
        if (part.len == 0 or std.mem.eql(u8, part, "..") or std.mem.eql(u8, part, ".")) return false;
    }
    return true;
}

fn covered(path: []const u8, entries: []const []const u8) bool {
    for (entries) |entry| {
        if (std.mem.eql(u8, path, std.mem.trimEnd(u8, entry, "/"))) return true;
        if (std.mem.endsWith(u8, entry, "/") and std.mem.startsWith(u8, path, entry)) return true;
    }
    return false;
}

fn needed(path: []const u8, directory: bool, entries: []const []const u8) bool {
    if (covered(path, entries)) return true;
    if (directory) for (entries) |entry| {
        if (entry.len > path.len and entry[path.len] == '/' and std.mem.startsWith(u8, entry, path)) return true;
    };
    return false;
}

// Validate every entry before changing the extracted tree. Directory entries
// end in '/', files are exact paths, and overlapping entries are rejected so
// removing a line cannot be silently defeated by a broader directory entry.
fn retainSources(io: Io, a: std.mem.Allocator, dir: Io.Dir, manifest: []const u8) !void {
    var entries: std.ArrayList([]const u8) = .empty;
    defer entries.deinit(a);
    var lines = std.mem.splitScalar(u8, manifest, '\n');
    while (lines.next()) |raw| {
        const entry = std.mem.trim(u8, raw, " \t\r");
        if (entry.len == 0 or entry[0] == '#') continue;
        const directory = std.mem.endsWith(u8, entry, "/");
        const path = if (directory) entry[0 .. entry.len - 1] else entry;
        if (!safePath(path)) return error.UnsafeSourcePath;
        if (covered(path, entries.items)) return error.OverlappingSourceEntries;
        for (entries.items) |previous| {
            if (covered(std.mem.trimEnd(u8, previous, "/"), &.{entry})) return error.OverlappingSourceEntries;
        }
        const stat = dir.statFile(io, path, .{ .follow_symlinks = false }) catch |err| {
            seed.log("build-python: source entry {s}: {s}", .{ entry, @errorName(err) });
            return err;
        };
        const expected_kind: Io.File.Kind = if (directory) .directory else .file;
        if (stat.kind != expected_kind) return error.SourceEntryKindMismatch;
        try entries.append(a, entry);
    }
    if (entries.items.len == 0) return error.EmptySourceManifest;

    var walker = try dir.walkSelectively(a);
    defer walker.deinit();
    while (try walker.next(io)) |entry| {
        if (!needed(entry.path, entry.kind == .directory, entries.items)) {
            try entry.dir.deleteTree(io, entry.basename);
        } else if (entry.kind == .directory and !covered(entry.path, entries.items)) {
            try walker.enter(io, entry);
        }
    }
    seed.log("build-python: retained {d} CPython source entries", .{entries.items.len});
}

test "only release targets are accepted" {
    try std.testing.expect(supported("linux-x86_64"));
    try std.testing.expect(supported("macos-aarch64"));
    try std.testing.expect(!supported("windows-x86_64"));
}

test "source paths stay inside the extracted tree" {
    try std.testing.expect(safePath("Tools/msi"));
    try std.testing.expect(!safePath("../LICENSE"));
    try std.testing.expect(!safePath("/tmp"));
    try std.testing.expect(!safePath("."));
    try std.testing.expect(!safePath("Modules//main.c"));
    try std.testing.expect(!safePath("Modules/*.c"));
    try std.testing.expect(!safePath("..\\outside"));
}

test "source allowlist preserves exact files and subtrees and removes an entry on the next build" {
    const io = std.testing.io;
    const a = std.testing.allocator;
    var tmp = std.testing.tmpDir(.{ .iterate = true });
    defer tmp.cleanup();
    for ([_][]const u8{ "Objects", "Lib/re", "Lib/regex", "Lib/test" }) |path| try tmp.dir.createDirPath(io, path);
    for ([_][]const u8{ "Objects/listobject.c", "Objects/dictobject.c", "Objects/listobject.c.bak", "Lib/re/__init__.py", "Lib/regex/probe.py", "Lib/test/test_list.py", "LICENSE" }) |path| {
        try tmp.dir.writeFile(io, .{ .sub_path = path, .data = "source\n" });
    }
    try retainSources(io, a, tmp.dir, "# CPython inputs\n\nObjects/listobject.c\nObjects/dictobject.c\nLib/re/\r\nLICENSE\n");
    _ = try tmp.dir.statFile(io, "Objects/listobject.c", .{});
    _ = try tmp.dir.statFile(io, "Lib/re/__init__.py", .{});
    try std.testing.expectError(error.FileNotFound, tmp.dir.statFile(io, "Objects/listobject.c.bak", .{}));
    try std.testing.expectError(error.FileNotFound, tmp.dir.statFile(io, "Lib/regex", .{}));
    try std.testing.expectError(error.FileNotFound, tmp.dir.statFile(io, "Lib/test", .{}));
    try retainSources(io, a, tmp.dir, "Objects/dictobject.c\nLib/re/\nLICENSE\n");
    try std.testing.expectError(error.FileNotFound, tmp.dir.statFile(io, "Objects/listobject.c", .{}));
}

test "invalid source manifests fail before pruning" {
    const io = std.testing.io;
    const a = std.testing.allocator;
    var tmp = std.testing.tmpDir(.{ .iterate = true });
    defer tmp.cleanup();
    try tmp.dir.createDirPath(io, "Include");
    try tmp.dir.writeFile(io, .{ .sub_path = "Include/Python.h", .data = "header\n" });
    try std.testing.expectError(error.EmptySourceManifest, retainSources(io, a, tmp.dir, "# empty\n"));
    try std.testing.expectError(error.UnsafeSourcePath, retainSources(io, a, tmp.dir, "../outside\n"));
    try std.testing.expectError(error.FileNotFound, retainSources(io, a, tmp.dir, "missing.c\n"));
    try std.testing.expectError(error.SourceEntryKindMismatch, retainSources(io, a, tmp.dir, "Include\n"));
    try std.testing.expectError(error.OverlappingSourceEntries, retainSources(io, a, tmp.dir, "Include/\nInclude/Python.h\n"));
    try std.testing.expectError(error.OverlappingSourceEntries, retainSources(io, a, tmp.dir, "Include/Python.h\nInclude/\n"));
    _ = try tmp.dir.statFile(io, "Include/Python.h", .{});
}
