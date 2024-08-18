const std = @import("std");
const libmd_path = @import("build_paths").libmd_path;

pub const csql = @cImport({
    @cInclude("sqlite3ext.h");
});

fn c(label: []const u8, return_code: c_int) !void {
    if (return_code != csql.SQLITE_OK) {
        std.debug.print("> {s} failed with return code: [{}]\n", .{ label, return_code });
        return error.SQLiteCommandFailed;
    }
}

fn printResult(unused: ?*anyopaque, argc: c_int, rows: [*c][*c]u8, cols: [*c][*c]u8) callconv(.C) c_int {
    _ = unused;
    std.debug.print("{s}:{s} [{}]\n", .{ cols[0], rows[0], argc });
    return 0;
}

test "md_nodes" {
    var db: ?*csql.sqlite3 = undefined;

    try c("Open", csql.sqlite3_open(":memory:", &db));
    defer c("Close", csql.sqlite3_close(db)) catch {};
    errdefer std.debug.print("> DB Error: {s}\n", .{csql.sqlite3_errmsg(db)});

    try c("Enable extension", csql.sqlite3_enable_load_extension(db, 1));

    var error_message: [*c]u8 = undefined;

    var buffer: [libmd_path.len + 1:0]u8 = undefined;
    buffer[libmd_path.len] = 0;
    @memcpy(buffer[0..libmd_path.len], libmd_path);

    try c("Load extension", csql.sqlite3_load_extension(db, &buffer, null, &error_message));

    const stmt: [:0]const u8 = "SELECT * FROM md_nodes";
    try c("Exec", csql.sqlite3_exec(db, stmt.ptr, printResult, null, null));
}
