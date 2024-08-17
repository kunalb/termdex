const std = @import("std");
const c = @cImport({
    @cInclude("cmark-gfm.h");
    @cInclude("string.h");
});

pub usingnamespace @import("gen_init");

const vtab = @import("vtab.zig");
pub const csql = vtab.csql;

pub fn toHTML(abs_path: []const u8, allocator: std.mem.Allocator) !?[]u8 {
    const file = try std.fs.cwd().openFile(abs_path, .{});
    defer file.close();
    const contents = try file.readToEndAlloc(allocator, 10000000);
    const c_ptr = c.cmark_markdown_to_html(contents.ptr, contents.len, 0);
    return std.mem.span(c_ptr);
}

const NodesTable = struct {
    name: []const u8 = "md_nodes",
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) !NodesTable {
        return NodesTable{ .allocator = allocator };
    }

    pub fn deinit(self: *NodesTable) void {
        _ = self;
    }

    pub fn create(self: *NodesTable, args: [][]u8) void {
        _ = self;
        _ = args;
    }

    pub fn connect(self: *NodesTable, args: [][]u8) void {
        _ = self;
        _ = args;
    }
};

pub fn initModule(
    db: *csql.sqlite3,
    pz_err_msg: [*c][*c]u8,
    p_api: [*c]const csql.sqlite3_api_routines,
) callconv(.C) c_int {
    std.debug.print("initModule triggered!", .{});

    _ = p_api;
    _ = pz_err_msg;
    vtab.createModule(NodesTable, db) catch |err| {
        std.debug.print("{?}", .{err});
        return -1;
    };

    return 0;
}

test "Test html conversion" {
    const test_file = "./resources/test_post.md";
    const converted = try toHTML(test_file, std.heap.c_allocator);
    const expected = "<h1>Heading</h1>\n<p>A paragraph of content with <a href=\"https://github.com/kunalb/termdex\">links</a>.</p>\n";
    try std.testing.expectEqualStrings(expected, converted.?);
}

test "Test SQLite extension loading and querying" {
    // Set up temporary directory for SQLite database
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();

    // Create a path for the SQLite database
    var path_buf: [std.fs.MAX_PATH_BYTES]u8 = undefined;
    const db_path = try tmp.dir.realpath("test.db", &path_buf);

    // Open SQLite database
    var db: ?*csql.sqlite3 = undefined;
    const rc = csql.sqlite3_open(db_path.ptr, &db);
    defer _ = csql.sqlite3_close(db);
    try std.testing.expect(rc == csql.SQLITE_OK);

    // Load the extension
    var err_msg: [*c]u8 = undefined;
    const ext_path = "libmd.so";
    const load_rc = csql.sqlite3_load_extension(db, ext_path, null, &err_msg);
    if (load_rc != csql.SQLITE_OK) {
        std.debug.print("Failed to load extension: {s}\n", .{err_msg});
        csql.sqlite3_free(err_msg);
    }
    try std.testing.expect(load_rc == csql.SQLITE_OK);

    // Create a virtual table
    const create_table_sql = "CREATE VIRTUAL TABLE md_nodes USING md_nodes()";
    const create_rc = csql.sqlite3_exec(db, create_table_sql, null, null, &err_msg);
    if (create_rc != csql.SQLITE_OK) {
        std.debug.print("Failed to create virtual table: {s}\n", .{err_msg});
        csql.sqlite3_free(err_msg);
    }
    try std.testing.expect(create_rc == csql.SQLITE_OK);

    // Query the virtual table
    const query_sql = "SELECT * FROM md_nodes LIMIT 1";
    var stmt: ?*csql.sqlite3_stmt = undefined;
    const prepare_rc = csql.sqlite3_prepare_v2(db, query_sql, -1, &stmt, null);
    try std.testing.expect(prepare_rc == csql.SQLITE_OK);
    defer _ = csql.sqlite3_finalize(stmt);

    // Execute the query
    const step_rc = csql.sqlite3_step(stmt);
    try std.testing.expect(step_rc == csql.SQLITE_ROW or step_rc == csql.SQLITE_DONE);

    // If we got a row, we could add more specific checks here
    if (step_rc == csql.SQLITE_ROW) {
        // Example: Check that we have at least one column
        const column_count = csql.sqlite3_column_count(stmt);
        try std.testing.expect(column_count > 0);
    }
}
