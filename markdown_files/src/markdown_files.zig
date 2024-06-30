const std = @import("std");

const c = @cImport({
    @cInclude("sqlite/sqlite3ext.h");
    @cInclude("string.h");
});

// Corresponding to the macro SQLITE_EXTENSION_INIT1
var sqlite3_api: [*c]const c.sqlite3_api_routines = undefined;

pub const VTab = extern struct {
    base: c.sqlite3_vtab = @import("std").mem.zeroes(c.sqlite3_vtab),
};
pub const Cursor = extern struct {
    base: c.sqlite3_vtab_cursor = @import("std").mem.zeroes(c.sqlite3_vtab_cursor),
    iRowid: c.sqlite3_int64 = @import("std").mem.zeroes(c.sqlite3_int64),
};

pub fn vTabConnect(db: ?*c.sqlite3, aux: ?*anyopaque, argc: c_int, argv: [*c]const [*c]const u8, vtab: [*c][*c]c.sqlite3_vtab, err: [*c][*c]u8) callconv(.C) c_int {
    _ = aux;
    _ = argc;
    _ = argv;
    _ = err;

    var new_vtab: [*c]VTab = undefined;
    _ = &new_vtab;
    const rc: c_int = sqlite3_api.*.declare_vtab.?(db, "CREATE TABLE x(a,b)");
    if (rc == @as(c_int, 0)) {
        new_vtab = @as([*c]VTab, @ptrCast(@alignCast(sqlite3_api.*.malloc.?(@as(c_int, @bitCast(@as(c_uint, @truncate(@sizeOf(VTab)))))))));
        vtab.* = @as([*c]c.sqlite3_vtab, @ptrCast(@alignCast(new_vtab)));
        if (new_vtab == null) return 7;
        _ = c.memset(@as(?*anyopaque, @ptrCast(new_vtab)), @as(c_int, 0), @sizeOf(VTab));
    }
    return rc;
}

pub fn vTabDisconnect(arg_pVtab: [*c]c.sqlite3_vtab) callconv(.C) c_int {
    var pVtab = arg_pVtab;
    _ = &pVtab;
    var p: [*c]VTab = @as([*c]VTab, @ptrCast(@alignCast(pVtab)));
    _ = &p;
    sqlite3_api.*.free.?(@as(?*anyopaque, @ptrCast(p)));
    return 0;
}
pub fn vTabOpen(arg_p: [*c]c.sqlite3_vtab, arg_ppCursor: [*c][*c]c.sqlite3_vtab_cursor) callconv(.C) c_int {
    var p = arg_p;
    _ = &p;
    var ppCursor = arg_ppCursor;
    _ = &ppCursor;
    var pCur: [*c]Cursor = undefined;
    _ = &pCur;
    pCur = @as([*c]Cursor, @ptrCast(@alignCast(sqlite3_api.*.malloc.?(@as(c_int, @bitCast(@as(c_uint, @truncate(@sizeOf(Cursor)))))))));
    if (pCur == null) return 7;
    _ = c.memset(@as(?*anyopaque, @ptrCast(pCur)), @as(c_int, 0), @sizeOf(Cursor));
    ppCursor.* = &pCur.*.base;
    return 0;
}
pub fn vTabClose(arg_cur: [*c]c.sqlite3_vtab_cursor) callconv(.C) c_int {
    var cur = arg_cur;
    _ = &cur;
    var pCur: [*c]Cursor = @as([*c]Cursor, @ptrCast(@alignCast(cur)));
    _ = &pCur;
    sqlite3_api.*.free.?(@as(?*anyopaque, @ptrCast(pCur)));
    return 0;
}
pub fn vTabNext(arg_cur: [*c]c.sqlite3_vtab_cursor) callconv(.C) c_int {
    var cur = arg_cur;
    _ = &cur;
    var pCur: [*c]Cursor = @as([*c]Cursor, @ptrCast(@alignCast(cur)));
    _ = &pCur;
    pCur.*.iRowid += 1;
    return 0;
}
pub fn vTabColumn(arg_cur: [*c]c.sqlite3_vtab_cursor, arg_ctx: ?*c.sqlite3_context, arg_i: c_int) callconv(.C) c_int {
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
                sqlite3_api.*.result_int.?(ctx, @as(c_int, @bitCast(@as(c_int, @truncate(@as(c.sqlite3_int64, @bitCast(@as(c_longlong, @as(c_int, 1000)))) + pCur.*.iRowid)))));
                break;
            },
            else => {
                sqlite3_api.*.result_int.?(ctx, @as(c_int, @bitCast(@as(c_int, @truncate(@as(c.sqlite3_int64, @bitCast(@as(c_longlong, @as(c_int, 2000)))) + pCur.*.iRowid)))));
                break;
            },
        }
        break;
    }
    return 0;
}
pub fn vTabRowid(arg_cur: [*c]c.sqlite3_vtab_cursor, arg_pRowid: [*c]c.sqlite_int64) callconv(.C) c_int {
    var cur = arg_cur;
    _ = &cur;
    var pRowid = arg_pRowid;
    _ = &pRowid;
    var pCur: [*c]Cursor = @as([*c]Cursor, @ptrCast(@alignCast(cur)));
    _ = &pCur;
    pRowid.* = pCur.*.iRowid;
    return 0;
}
pub fn vTabEof(arg_cur: [*c]c.sqlite3_vtab_cursor) callconv(.C) c_int {
    var cur = arg_cur;
    _ = &cur;
    var pCur: [*c]Cursor = @as([*c]Cursor, @ptrCast(@alignCast(cur)));
    _ = &pCur;
    return @intFromBool(pCur.*.iRowid >= @as(c.sqlite3_int64, @bitCast(@as(c_longlong, @as(c_int, 10)))));
}
pub fn vTabFilter(arg_pVtabCursor: [*c]c.sqlite3_vtab_cursor, arg_idxNum: c_int, arg_idxStr: [*c]const u8, arg_argc: c_int, arg_argv: [*c]?*c.sqlite3_value) callconv(.C) c_int {
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
    pCur.*.iRowid = 1;
    return 0;
}
pub fn vTabBestIndex(arg_tab: [*c]c.sqlite3_vtab, arg_pIdxInfo: [*c]c.sqlite3_index_info) callconv(.C) c_int {
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
    .xCreate = @ptrFromInt(0),
    .xConnect = vTabConnect,
    .xBestIndex = vTabBestIndex,
    .xDisconnect = vTabDisconnect,
    .xDestroy = @ptrFromInt(0),
    .xOpen = vTabOpen,
    .xClose = vTabClose,
    .xFilter = vTabFilter,
    .xNext = vTabNext,
    .xEof = vTabEof,
    .xColumn = vTabColumn,
    .xRowid = vTabRowid,
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
    return c.sqlite3_create_module(db, "markdown_files", &MarkdownFilesVTabModule, @ptrFromInt(0));
}
