const std = @import("std");
const libmd_path = @import("build_paths").libmd_path;

pub const csql = @cImport({
    @cInclude("sqlite3ext.h");
});

test "md_nodes" {
    std.debug.print("{s}", .{libmd_path});

    var db_handle: ?*csql.sqlite3 = undefined;
    if (csql.sqlite3_open(":memory:", &db_handle) != csql.SQLITE_OK) {
        return error.SQLiteOpenFailed;
    }
    defer _ = csql.sqlite3_close(db_handle);

    if (csql.sqlite3_enable_load_extension(db_handle, 1) != csql.SQLITE_OK) {
        return error.SQLiteEnableExtFailed;
    }

    var buffer: [libmd_path.len + 1]u8 = undefined;
    @memcpy(buffer[0..libmd_path.len], libmd_path);
    buffer[libmd_path.len] = 0;

    var error_message: [*c]u8 = undefined;
    if (csql.sqlite3_load_extension(db_handle, &buffer, null, &error_message) != csql.SQLITE_OK) {
        std.debug.print("Extension load failed: `{?s}`", .{error_message});
        return error.SQLiteLoadExtFailed;
    }
}
