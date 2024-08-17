const std = @import("std");
pub const csql = @cImport({
    @cInclude("sqlite3ext.h");
});
const lib_name = @import("build_options").lib_name;

const VTabError = error{
    InitFailed,
    CreateFailed,
};

const Module = struct {};

const MODULE_REGISTRY = std.ArrayList(Module);

const VirtualTable = struct {
    name: []u8,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) !VirtualTable {
        _ = allocator;
    }

    pub fn deinit(self: *VirtualTable) void {
        _ = self;
    }

    pub fn create(self: *VirtualTable, args: [][]u8) void {
        _ = self;
        _ = args;
    }

    pub fn connect(self: *VirtualTable, args: [][]u8) void {
        _ = self;
        _ = args;
    }

    pub fn bestIndex() void {}
};

pub fn createModule(comptime T: type, db: anytype) !void {
    checkProtocol(VirtualTable, T);

    var vtab = try T.init(std.heap.c_allocator);
    const result = csql.sqlite3_create_module(db, vtab.name.ptr, &vtabModule, &vtab);
    if (result != csql.SQLITE_OK) {
        std.debug.print("sqlite3_create_module failed with error code {}", .{result});
        return VTabError.CreateFailed;
    }
}

pub fn vtabCreate(db: ?*csql.sqlite3, aux: ?*anyopaque, argc: c_int, argv: [*c]const [*c]const u8, pp_vtab: [*c][*c]csql.sqlite3_vtab, pz_err: [*c][*c]u8) callconv(.C) c_int {
    _ = db;
    _ = aux;
    _ = argc;
    _ = argv;
    _ = pp_vtab;
    _ = pz_err;

    return 0;
}

pub fn vtabConnect(db: ?*csql.sqlite3, aux: ?*anyopaque, argc: c_int, argv: [*c]const [*c]const u8, pp_vtab: [*c][*c]csql.sqlite3_vtab, pz_err: [*c][*c]u8) callconv(.C) c_int {
    _ = db;
    _ = aux;
    _ = argc;
    _ = argv;
    _ = pp_vtab;
    _ = pz_err;

    return 0;
}

pub fn vtabBestIndex(arg_tab: [*c]csql.sqlite3_vtab, arg_pIdxInfo: [*c]csql.sqlite3_index_info) callconv(.C) c_int {
    _ = arg_tab;
    _ = arg_pIdxInfo;
    return 0;
}

pub fn vtabDisconnect(p_vtab: [*c]csql.sqlite3_vtab) callconv(.C) c_int {
    _ = p_vtab;
    return 0;
}

pub fn vtabOpen(p_vtab: [*c]csql.sqlite3_vtab, pp_cursor: [*c][*c]csql.sqlite3_vtab_cursor) callconv(.C) c_int {
    _ = p_vtab;
    _ = pp_cursor;
    return csql.SQLITE_OK;
}

pub fn vtabClose(p_base: [*c]csql.sqlite3_vtab_cursor) callconv(.C) c_int {
    _ = p_base;
    return csql.SQLITE_OK;
}

pub fn vtabNext(p_cur_base: [*c]csql.sqlite3_vtab_cursor) callconv(.C) c_int {
    _ = p_cur_base;
    return 0;
}

pub fn vtabColumn(p_cur: [*c]csql.sqlite3_vtab_cursor, p_ctx: ?*csql.sqlite3_context, i: c_int) callconv(.C) c_int {
    _ = p_cur;
    _ = p_ctx;
    _ = i;
    return csql.SQLITE_OK;
}

pub fn vtabRowid(arg_cur: [*c]csql.sqlite3_vtab_cursor, arg_pRowid: [*c]csql.sqlite_int64) callconv(.C) c_int {
    _ = arg_cur;
    _ = arg_pRowid;
    return 0;
}

pub fn vtabEof(p_base: [*c]csql.sqlite3_vtab_cursor) callconv(.C) c_int {
    _ = p_base;
    return 0;
}

pub fn vtabFilter(p_vtab_cursor: [*c]csql.sqlite3_vtab_cursor, idx_num: c_int, idx_str: [*c]const u8, argc: c_int, argv: [*c]?*csql.sqlite3_value) callconv(.C) c_int {
    _ = p_vtab_cursor;
    _ = idx_num;
    _ = idx_str;
    _ = argc;
    _ = argv;
    return 0;
}

const vtabModule = csql.sqlite3_module{
    .iVersion = 0,
    .xCreate = vtabCreate,
    .xConnect = vtabConnect,
    .xBestIndex = vtabBestIndex,
    .xDisconnect = vtabDisconnect,
    .xDestroy = vtabDisconnect,
    .xOpen = vtabOpen,
    .xClose = vtabClose,
    .xFilter = vtabFilter,
    .xNext = vtabNext,
    .xEof = vtabEof,
    .xColumn = vtabColumn,
    .xRowid = vtabRowid,
    .xUpdate = @ptrFromInt(0),
    .xBegin = @ptrFromInt(0),
    .xSync = @ptrFromInt(0),
    .xCommit = @ptrFromInt(0),
    .xRollback = @ptrFromInt(0),
    .xFindFunction = @ptrFromInt(0),
    .xRename = @ptrFromInt(0),
    .xSavepoint = @ptrFromInt(0),
    .xRelease = @ptrFromInt(0),
    .xRollbackTo = @ptrFromInt(0),
    .xShadowName = @ptrFromInt(0),
};

fn checkProtocol(comptime B: type, comptime T: type) void {
    comptime {
        for (@typeInfo(B).Struct.fields) |expected_field| {
            var solved = false;
            for (@typeInfo(T).Struct.fields) |actual_field| {
                if (std.mem.eql(u8, expected_field.name, actual_field.name)) {
                    const expected_type = @TypeOf(expected_field);
                    const actual_type = @TypeOf(actual_field);
                    std.debug.assert(expected_type == actual_type);
                    solved = true;
                    break;
                }
            }

            if (!solved) {
                @compileLog("Could not resolve {}", .{expected_field});
            }
        }
    }
}
