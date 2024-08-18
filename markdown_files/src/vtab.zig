const std = @import("std");
pub const csql = @cImport({
    @cInclude("sqlite3ext.h");
});
const lib_name = @import("build_options").lib_name;

const VTabError = error{
    InitFailed,
    CreateFailed,
};

/// Interface to build a virtual table in SQLite
const VirtualTable = struct {
    name: []u8,
    allocator: std.mem.Allocator,
    api: [*c]const csql.sqlite3_api_routines,

    /// Set to true to skip generating a create function
    eponymous_only: bool = false,

    pub fn init(allocator: std.mem.Allocator) !*VirtualTable {
        _ = allocator;
    }

    pub fn deinit(self: *VirtualTable) void {
        _ = self;
    }

    pub fn connect(self: *VirtualTable, args: [][]u8) void {
        _ = self;
        _ = args;
    }

    pub fn disconnect(self: *VirtualTable, args: [][]u8) void {
        _ = self;
        _ = args;
    }

    pub fn bestIndex() void {}
};

fn declsMap(comptime T: type) std.StaticStringMap(void) {
    comptime {
        const decls = @typeInfo(T).Struct.decls;
        var kvs: [decls.len]struct { []const u8 } = undefined;
        for (decls, 0..) |decl, i| {
            kvs[i] = .{decl.name};
        }
        return std.StaticStringMap(void).initComptime(kvs);
    }
}

fn createFn(comptime T: type) @TypeOf(vtabCreate) {
    comptime {
        // TODO actually check the default value of this field
        if (@hasField(T, "eponymous_only")) {
            return null;
        } else if (declsMap(T).has("create")) {
            return altCreate(T);
        } else {
            return altConnect(T);
        }
    }
}

fn destroyFn(comptime T: type) @TypeOf(vtabDestroy) {
    comptime {
        if (declsMap(T).has("destroy")) {
            return vtabDestroy;
        } else {
            return vtabDisconnect;
        }
    }
}

/// Create a SQLite3 Module at Comptime
/// Introspects on the contents of the vtab struct
/// and generates functions to run the virtual table
/// using generics.
fn buildModule(comptime T: type) csql.sqlite3_module {
    checkProtocol(VirtualTable, T);

    return csql.sqlite3_module{
        .iVersion = 0,
        .xCreate = altConnect(T),
        .xConnect = altConnect(T),
        .xBestIndex = vtabBestIndex,
        .xDisconnect = vtabDisconnect,
        .xDestroy = destroyFn(T),
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
}

/// Register a module with SQLite for the given VTab implementation
pub fn createModule(comptime T: type, db: anytype, p_api: [*c]const csql.sqlite3_api_routines) !void {
    const vtabModule = try std.heap.c_allocator.create(csql.sqlite3_module);
    vtabModule.* = buildModule(T);

    const vtab = try T.init(std.heap.c_allocator, p_api);

    // TODO deallocate vtab with callback using v2
    const result = csql.sqlite3_create_module(db, vtab.name.ptr, vtabModule, vtab);
    if (result != csql.SQLITE_OK) {
        std.debug.print("sqlite3_create_module failed with error code {}", .{result});
        return VTabError.CreateFailed;
    }
    std.debug.print("> sqlite3_create_module `{s}` succeeded!\n", .{vtab.name});
}

pub fn altCreate(comptime T: type) Create {
    // std.debug.print("called altCreate for {s}", .{@typeName(T)});
    return struct {
        pub fn vtabCreate(db: ?*csql.sqlite3, aux: ?*anyopaque, argc: c_int, argv: [*c]const [*c]const u8, pp_vtab: [*c][*c]csql.sqlite3_vtab, pz_err: [*c][*c]u8) callconv(.C) c_int {
            const vtab: *T = @ptrCast(@alignCast(aux));
            std.debug.print("Called alt create's generated function! {s}", .{vtab.name});

            _ = db;
            _ = argc;
            _ = argv;
            _ = pp_vtab;
            _ = pz_err;
            return 0;
        }
    }.vtabCreate;
}

const Create: type = fn (?*csql.struct_sqlite3, ?*anyopaque, c_int, [*c]const [*c]const u8, [*c][*c]csql.struct_sqlite3_vtab, [*c][*c]u8) callconv(.C) c_int;

pub fn vtabCreate(db: ?*csql.sqlite3, aux: ?*anyopaque, argc: c_int, argv: [*c]const [*c]const u8, pp_vtab: [*c][*c]csql.sqlite3_vtab, pz_err: [*c][*c]u8) callconv(.C) c_int {
    _ = aux;
    _ = db;
    _ = argc;
    _ = argv;
    _ = pp_vtab;
    _ = pz_err;

    return 0;
}

pub fn altConnect(comptime T: type) @TypeOf(vtabConnect) {
    @compileLog(@TypeOf(vtabCreate));
    // std.debug.print("called altCreate for {s}", .{@typeName(T)});
    return struct {
        pub fn vtabConnect(db: ?*csql.sqlite3, aux: ?*anyopaque, argc: c_int, argv: [*c]const [*c]const u8, pp_vtab: [*c][*c]csql.sqlite3_vtab, pz_err: [*c][*c]u8) callconv(.C) c_int {
            const vtab: *T = @ptrCast(@alignCast(aux));
            vtab.connect();
            std.debug.print("Called alt connects generated function! {s}\n", .{vtab.name});

            _ = db;
            _ = argc;
            _ = argv;
            _ = pp_vtab;
            _ = pz_err;
            return 0;
        }
    }.vtabConnect;
}

pub fn vtabConnect(db: ?*csql.sqlite3, aux: ?*anyopaque, argc: c_int, argv: [*c]const [*c]const u8, pp_vtab: [*c][*c]csql.sqlite3_vtab, pz_err: [*c][*c]u8) callconv(.C) c_int {
    std.debug.print(">> Called connect function!\n", .{});

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

pub fn vtabDestroy(p_vtab: [*c]csql.sqlite3_vtab) callconv(.C) c_int {
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

fn checkProtocol(comptime B: type, comptime T: type) void {
    comptime {
        for (@typeInfo(B).Struct.decls) |expected_decl| {
            var solved = false;
            for (@typeInfo(T).Struct.decls) |actual_decl| {
                if (std.mem.eql(u8, expected_decl.name, actual_decl.name)) {
                    const expected_type = @TypeOf(expected_decl);
                    const actual_type = @TypeOf(actual_decl);
                    std.debug.assert(expected_type == actual_type);
                    solved = true;
                    break;
                }
            }

            if (!solved) {
                @compileLog("Could not resolve: ", expected_decl.name);
                @compileError("Incomplete interface");
            }
        }

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
                @compileLog("Could not resolve: ", expected_field.name);
                @compileError("Incomplete interface");
            }
        }
    }
}
