const std = @import("std");

const c = @cImport({
    @cInclude("sqlite/sqlite3ext.h");
    @cInclude("string.h");
});

// Keep things simple for interop with C, potentially revisit as needed
const c_allocator = std.heap.c_allocator;

// Corresponding to the macro SQLITE_EXTENSION_INIT1
var sqlite3_api: [*c]const c.sqlite3_api_routines = undefined;

pub const VTab = extern struct {
    base: c.sqlite3_vtab = std.mem.zeroes(c.sqlite3_vtab),
    root_dir: [*:0]u8,
};

pub const Cursor = extern struct {
    base: c.sqlite3_vtab_cursor = std.mem.zeroes(c.sqlite3_vtab_cursor),
    row_id: c.sqlite3_int64 = 0,
    iter: ?*anyopaque = null, // Dir.Walker
};

pub fn vtabConnect(db: ?*c.sqlite3, aux: ?*anyopaque, argc: c_int, argv: [*c]const [*c]const u8, pp_vtab: [*c][*c]c.sqlite3_vtab, pz_err: [*c][*c]u8) callconv(.C) c_int {
    _ = aux;

    if (argc > 4) {
        pz_err.* = c.sqlite3_mprintf("Can specify at most one argument: the root directory for markdown files (received %d).", argc - 3);
        return c.SQLITE_ERROR;
    }

    var new_vtab: *VTab = undefined;
    const rc: c_int = sqlite3_api.*.declare_vtab.?(db, "CREATE TABLE x(a,b)");
    if (rc != c.SQLITE_OK) {
        return rc;
    }

    new_vtab = c_allocator.create(VTab) catch return c.SQLITE_NOMEM;
    if (argc == 4) {
        var buf: [std.fs.max_path_bytes]u8 = undefined;
        const path = std.fs.realpathZ(argv[3], &buf) catch {
            pz_err.* = c.sqlite3_mprintf("Couldn't resolve directory! `%s`", argv[3]);
            return c.SQLITE_ERROR;
        };
        new_vtab.root_dir = c_allocator.allocSentinel(u8, path.len, 0) catch return c.SQLITE_NOMEM;
        @memcpy(new_vtab.root_dir, path);
    } else {
        var buf: [std.fs.MAX_NAME_BYTES]u8 = undefined;
        const cwd = std.process.getCwd(&buf) catch {
            pz_err.* = c.sqlite3_mprintf("Could not determine current working directory!");
            return c.SQLITE_ERROR;
        };
        new_vtab.root_dir = c_allocator.allocSentinel(u8, cwd.len, 0) catch return c.SQLITE_NOMEM;
        @memcpy(new_vtab.root_dir, cwd);
    }

    pp_vtab.* = @as([*c]c.sqlite3_vtab, @ptrCast(@alignCast(new_vtab)));

    return rc;
}

pub fn vtabDisconnect(p_vtab: [*c]c.sqlite3_vtab) callconv(.C) c_int {
    const p: *VTab = @as(*VTab, @ptrCast(@alignCast(p_vtab)));
    c_allocator.free(p.root_dir[0..(std.mem.len(p.root_dir) + 1)]);
    c_allocator.destroy(p);
    return 0;
}

pub fn vtabOpen(p_vtab: [*c]c.sqlite3_vtab, pp_cursor: [*c][*c]c.sqlite3_vtab_cursor) callconv(.C) c_int {
    const vtab: *VTab = @as(*VTab, @ptrCast(@alignCast(p_vtab)));

    // TODO: vtabOpen can't return errors?
    const dir = std.fs.openDirAbsoluteZ(vtab.root_dir, .{ .iterate = true }) catch unreachable;
    const walker = dir.walk(c_allocator) catch unreachable;
    const new_cursor: *Cursor = c_allocator.create(Cursor) catch return c.SQLITE_NOMEM;

    const p_walker = c_allocator.create(@TypeOf(walker)) catch unreachable;
    p_walker.* = walker;
    new_cursor.iter = p_walker;
    pp_cursor.* = &new_cursor.*.base;
    return 0;
}

pub fn vtabClose(p_base: [*c]c.sqlite3_vtab_cursor) callconv(.C) c_int {
    const cur = @as(*Cursor, @ptrCast(@alignCast(p_base)));
    const walker = @as(*std.fs.Dir.Walker, @ptrCast(@alignCast(cur.iter.?)));

    //= while (walker.next() catch unreachable) |entry| {
    //=     switch (entry.kind) {
    //=         .file => std.debug.print("File: {s}\n", .{entry.path}),
    //=         .directory => std.debug.print("Directory: {s}\n", .{entry.path}),
    //=         .sym_link => std.debug.print("Symlink: {s}\n", .{entry.path}),
    //=         else => std.debug.print("Other: {s}\n", .{entry.path}),
    //=     }
    //= }

    c_allocator.destroy(walker);
    c_allocator.destroy(cur);
    return c.SQLITE_OK;
}

pub fn vtabNext(arg_cur: [*c]c.sqlite3_vtab_cursor) callconv(.C) c_int {
    var cur = arg_cur;
    _ = &cur;
    var pCur: [*c]Cursor = @as([*c]Cursor, @ptrCast(@alignCast(cur)));
    _ = &pCur;
    pCur.*.row_id += 1;
    return 0;
}

pub fn vtabColumn(arg_cur: [*c]c.sqlite3_vtab_cursor, arg_ctx: ?*c.sqlite3_context, arg_i: c_int) callconv(.C) c_int {
    var cur = arg_cur;
    _ = &cur;
    var ctx = arg_ctx;
    _ = &ctx;
    var i = arg_i;
    _ = &i;
    var pCur: [*c]Cursor = @as([*c]Cursor, @ptrCast(@alignCast(cur)));
    _ = &pCur;
    while (true) {
        switch (i) {
            @as(c_int, 0) => {
                sqlite3_api.*.result_int.?(ctx, @as(c_int, @bitCast(@as(c_int, @truncate(@as(c.sqlite3_int64, @bitCast(@as(c_longlong, @as(c_int, 1000)))) + pCur.*.row_id)))));
                break;
            },
            else => {
                sqlite3_api.*.result_int.?(ctx, @as(c_int, @bitCast(@as(c_int, @truncate(@as(c.sqlite3_int64, @bitCast(@as(c_longlong, @as(c_int, 2000)))) + pCur.*.row_id)))));
                break;
            },
        }
        break;
    }
    return 0;
}

pub fn vtabRowid(arg_cur: [*c]c.sqlite3_vtab_cursor, arg_pRowid: [*c]c.sqlite_int64) callconv(.C) c_int {
    var cur = arg_cur;
    _ = &cur;
    var pRowid = arg_pRowid;
    _ = &pRowid;
    var pCur: [*c]Cursor = @as([*c]Cursor, @ptrCast(@alignCast(cur)));
    _ = &pCur;
    pRowid.* = pCur.*.row_id;
    return 0;
}

pub fn vtabEof(arg_cur: [*c]c.sqlite3_vtab_cursor) callconv(.C) c_int {
    var cur = arg_cur;
    _ = &cur;
    var pCur: [*c]Cursor = @as([*c]Cursor, @ptrCast(@alignCast(cur)));
    _ = &pCur;
    return @intFromBool(pCur.*.row_id >= @as(c.sqlite3_int64, @bitCast(@as(c_longlong, @as(c_int, 10)))));
}

pub fn vtabFilter(arg_pVtabCursor: [*c]c.sqlite3_vtab_cursor, arg_idxNum: c_int, arg_idxStr: [*c]const u8, arg_argc: c_int, arg_argv: [*c]?*c.sqlite3_value) callconv(.C) c_int {
    var pVtabCursor = arg_pVtabCursor;
    _ = &pVtabCursor;
    var idxNum = arg_idxNum;
    _ = &idxNum;
    var idxStr = arg_idxStr;
    _ = &idxStr;
    var argc = arg_argc;
    _ = &argc;
    var argv = arg_argv;
    _ = &argv;
    var pCur: [*c]Cursor = @as([*c]Cursor, @ptrCast(@alignCast(pVtabCursor)));
    _ = &pCur;
    pCur.*.row_id = 1;
    return 0;
}

pub fn vtabBestIndex(arg_tab: [*c]c.sqlite3_vtab, arg_pIdxInfo: [*c]c.sqlite3_index_info) callconv(.C) c_int {
    var tab = arg_tab;
    _ = &tab;
    var pIdxInfo = arg_pIdxInfo;
    _ = &pIdxInfo;
    pIdxInfo.*.estimatedCost = @as(f64, @floatFromInt(@as(c_int, 10)));
    pIdxInfo.*.estimatedRows = 10;
    return 0;
}

const MarkdownFilesVTabModule = c.sqlite3_module{
    .iVersion = 0,
    .xCreate = vtabConnect,
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
    // .xIntegrity = 0,
};

export fn sqlite3_markdown_files_init(
    db: *c.sqlite3,
    pzErrMsg: [*c][*c]u8,
    pApi: [*c]const c.sqlite3_api_routines,
) callconv(.C) c_int {
    // Corresponding to the macro SQLITE_EXTENSION_INIT2
    sqlite3_api = pApi;
    _ = pzErrMsg;
    const rc: c_int = c.sqlite3_initialize();
    if (rc != c.SQLITE_OK) {
        return rc;
    }
    return c.sqlite3_create_module(db, "markdown_files\x00", &MarkdownFilesVTabModule, @ptrFromInt(0));
}
