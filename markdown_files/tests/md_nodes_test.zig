const std = @import("std");
const libmd_path = @import("build_paths").libmd_path;

pub const csql = @cImport({
    @cInclude("sqlite3ext.h");
});

test "md_nodes" {
    std.debug.print("{s}", .{libmd_path});
    // _ = csql.sqlite3_open(":memory:", null);
}
