const std = @import("std");
const c = @cImport({
    @cInclude("cmark-gfm.h");
    @cInclude("string.h");
});
const log = std.log.scoped(.md_nodes);

pub usingnamespace @import("gen_init");

const vtab = @import("vtab.zig");
pub const csql = vtab.csql;

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

    pub fn deinit(self: *NodesTable) !void {
        try self.allocator.free(self);
    }

    pub fn create(self: *NodesTable, args: [][]u8) void {
        _ = self;
        _ = args;
    }

    pub fn connect(self: *NodesTable, args: []const [:0]const u8) void {
        log.debug("> Called NodesTable.connect {}", .{args.len});
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

pub fn initModule(args: vtab.CreateModuleArgs) !void {
    return vtab.createModule(NodesTable, args);
}
