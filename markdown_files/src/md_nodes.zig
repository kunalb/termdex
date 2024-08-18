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
    name: [:0]const u8 = "md_nodes",
    eponymous_only: bool = false,

    allocator: std.mem.Allocator,
    api: [*c]const csql.sqlite3_api_routines,

    pub fn init(allocator: std.mem.Allocator, api: [*c]const csql.sqlite3_api_routines) !*NodesTable {
        const ptr = try allocator.create(@This());
        ptr.* = NodesTable{ .allocator = allocator, .api = api };
        return ptr;
    }

    pub fn deinit(self: *NodesTable) void {
        _ = self;
    }

    pub fn create(self: *NodesTable, args: [][]u8) void {
        _ = self;
        _ = args;
    }

    pub fn connect(self: *NodesTable) void {
        std.debug.print("Called NodesTable.connect", .{});
        _ = self;
    }

    pub fn disconnect(self: *NodesTable, args: [][]u8) void {
        _ = self;
        _ = args;
    }

    pub fn bestIndex(self: *NodesTable, args: [][]u8) void {
        _ = self;
        _ = args;
    }
};

pub fn initModule(
    db: *csql.sqlite3,
    pz_err_msg: [*c][*c]u8,
    p_api: [*c]const csql.sqlite3_api_routines,
) callconv(.C) c_int {
    _ = pz_err_msg;
    vtab.createModule(NodesTable, db, p_api) catch |err| {
        std.debug.print("{?}", .{err});
        return -1;
    };

    return 0;
}

// TODO: Move this out
test "Test html conversion" {
    const test_file = "./resources/test_post.md";
    const converted = try toHTML(test_file, std.heap.c_allocator);
    const expected = "<h1>Heading</h1>\n<p>A paragraph of content with <a href=\"https://github.com/kunalb/termdex\">links</a>.</p>\n";
    try std.testing.expectEqualStrings(expected, converted.?);
}
