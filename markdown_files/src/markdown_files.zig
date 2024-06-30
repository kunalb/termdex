const std = @import("std");

const c = @cImport({
    @cInclude("sqlite/sqlite3ext.h");
    @cInclude("string.h");
});

// Corresponding to the macro SQLITE_EXTENSION_INIT1
var sqlite3_api: [*c]const c.sqlite3_api_routines = undefined;

pub const struct_markdown_files_vtab = extern struct {
    base: c.sqlite3_vtab = @import("std").mem.zeroes(c.sqlite3_vtab),
};
pub const markdown_files_vtab = struct_markdown_files_vtab;
pub const struct_markdown_files_cursor = extern struct {
    base: c.sqlite3_vtab_cursor = @import("std").mem.zeroes(c.sqlite3_vtab_cursor),
    iRowid: c.sqlite3_int64 = @import("std").mem.zeroes(c.sqlite3_int64),
};
pub const markdown_files_cursor = struct_markdown_files_cursor;
pub fn markdown_filesConnect(arg_db: ?*c.sqlite3, arg_pAux: ?*anyopaque, arg_argc: c_int, arg_argv: [*c]const [*c]const u8, arg_ppVtab: [*c][*c]c.sqlite3_vtab, arg_pzErr: [*c][*c]u8) callconv(.C) c_int {
    var db = arg_db;
    _ = &db;
    var pAux = arg_pAux;
    _ = &pAux;
    var argc = arg_argc;
    _ = &argc;
    var argv = arg_argv;
    _ = &argv;
    var ppVtab = arg_ppVtab;
    _ = &ppVtab;
    var pzErr = arg_pzErr;
    _ = &pzErr;
    var pNew: [*c]markdown_files_vtab = undefined;
    _ = &pNew;
    var rc: c_int = undefined;
    _ = &rc;
    rc = sqlite3_api.*.declare_vtab.?(db, "CREATE TABLE x(a,b)\x00");
    if (rc == @as(c_int, 0)) {
        pNew = @as([*c]markdown_files_vtab, @ptrCast(@alignCast(sqlite3_api.*.malloc.?(@as(c_int, @bitCast(@as(c_uint, @truncate(@sizeOf(markdown_files_vtab)))))))));
        ppVtab.* = @as([*c]c.sqlite3_vtab, @ptrCast(@alignCast(pNew)));
        if (pNew == null) return 7;
        _ = c.memset(@as(?*anyopaque, @ptrCast(pNew)), @as(c_int, 0), @sizeOf(markdown_files_vtab));
    }
    return rc;
}
pub fn markdown_filesDisconnect(arg_pVtab: [*c]c.sqlite3_vtab) callconv(.C) c_int {
    var pVtab = arg_pVtab;
    _ = &pVtab;
    var p: [*c]markdown_files_vtab = @as([*c]markdown_files_vtab, @ptrCast(@alignCast(pVtab)));
    _ = &p;
    sqlite3_api.*.free.?(@as(?*anyopaque, @ptrCast(p)));
    return 0;
}
pub fn markdown_filesOpen(arg_p: [*c]c.sqlite3_vtab, arg_ppCursor: [*c][*c]c.sqlite3_vtab_cursor) callconv(.C) c_int {
    var p = arg_p;
    _ = &p;
    var ppCursor = arg_ppCursor;
    _ = &ppCursor;
    var pCur: [*c]markdown_files_cursor = undefined;
    _ = &pCur;
    pCur = @as([*c]markdown_files_cursor, @ptrCast(@alignCast(sqlite3_api.*.malloc.?(@as(c_int, @bitCast(@as(c_uint, @truncate(@sizeOf(markdown_files_cursor)))))))));
    if (pCur == null) return 7;
    _ = c.memset(@as(?*anyopaque, @ptrCast(pCur)), @as(c_int, 0), @sizeOf(markdown_files_cursor));
    ppCursor.* = &pCur.*.base;
    return 0;
}
pub fn markdown_filesClose(arg_cur: [*c]c.sqlite3_vtab_cursor) callconv(.C) c_int {
    var cur = arg_cur;
    _ = &cur;
    var pCur: [*c]markdown_files_cursor = @as([*c]markdown_files_cursor, @ptrCast(@alignCast(cur)));
    _ = &pCur;
    sqlite3_api.*.free.?(@as(?*anyopaque, @ptrCast(pCur)));
    return 0;
}
pub fn markdown_filesNext(arg_cur: [*c]c.sqlite3_vtab_cursor) callconv(.C) c_int {
    var cur = arg_cur;
    _ = &cur;
    var pCur: [*c]markdown_files_cursor = @as([*c]markdown_files_cursor, @ptrCast(@alignCast(cur)));
    _ = &pCur;
    pCur.*.iRowid += 1;
    return 0;
}
pub fn markdown_filesColumn(arg_cur: [*c]c.sqlite3_vtab_cursor, arg_ctx: ?*c.sqlite3_context, arg_i: c_int) callconv(.C) c_int {
    var cur = arg_cur;
    _ = &cur;
    var ctx = arg_ctx;
    _ = &ctx;
    var i = arg_i;
    _ = &i;
    var pCur: [*c]markdown_files_cursor = @as([*c]markdown_files_cursor, @ptrCast(@alignCast(cur)));
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
pub fn markdown_filesRowid(arg_cur: [*c]c.sqlite3_vtab_cursor, arg_pRowid: [*c]c.sqlite_int64) callconv(.C) c_int {
    var cur = arg_cur;
    _ = &cur;
    var pRowid = arg_pRowid;
    _ = &pRowid;
    var pCur: [*c]markdown_files_cursor = @as([*c]markdown_files_cursor, @ptrCast(@alignCast(cur)));
    _ = &pCur;
    pRowid.* = pCur.*.iRowid;
    return 0;
}
pub fn markdown_filesEof(arg_cur: [*c]c.sqlite3_vtab_cursor) callconv(.C) c_int {
    var cur = arg_cur;
    _ = &cur;
    var pCur: [*c]markdown_files_cursor = @as([*c]markdown_files_cursor, @ptrCast(@alignCast(cur)));
    _ = &pCur;
    return @intFromBool(pCur.*.iRowid >= @as(c.sqlite3_int64, @bitCast(@as(c_longlong, @as(c_int, 10)))));
}
pub fn markdown_filesFilter(arg_pVtabCursor: [*c]c.sqlite3_vtab_cursor, arg_idxNum: c_int, arg_idxStr: [*c]const u8, arg_argc: c_int, arg_argv: [*c]?*c.sqlite3_value) callconv(.C) c_int {
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
    var pCur: [*c]markdown_files_cursor = @as([*c]markdown_files_cursor, @ptrCast(@alignCast(pVtabCursor)));
    _ = &pCur;
    pCur.*.iRowid = 1;
    return 0;
}
pub fn markdown_filesBestIndex(arg_tab: [*c]c.sqlite3_vtab, arg_pIdxInfo: [*c]c.sqlite3_index_info) callconv(.C) c_int {
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
    .xConnect = markdown_filesConnect,
    .xBestIndex = markdown_filesBestIndex,
    .xDisconnect = markdown_filesDisconnect,
    .xDestroy = @ptrFromInt(0),
    .xOpen = markdown_filesOpen,
    .xClose = markdown_filesClose,
    .xFilter = markdown_filesFilter,
    .xNext = markdown_filesNext,
    .xEof = markdown_filesEof,
    .xColumn = markdown_filesColumn,
    .xRowid = markdown_filesRowid,
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
    // c.sqlite3_api = pApi;

    // return c.sqlite3_markdown_files_init_c(db, pzErrMsg, pApi);
    _ = pzErrMsg;
    _ = c.sqlite3_malloc(0);
    const name = "markdown_files";
    return c.sqlite3_create_module(db, name.ptr, &MarkdownFilesVTabModule, @ptrFromInt(0));
}
