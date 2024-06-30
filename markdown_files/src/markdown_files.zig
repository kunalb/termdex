const std = @import("std");

const c = @cImport({
    @cInclude("sqlite/sqlite3ext.h");
    @cInclude("markdown_files.c");
});

// Corresponding to the macro SQLITE_EXTENSION_INIT1
var sqlite3_api: [*c]const c.sqlite3_api_routines = undefined;

const MarkdownFilesVTabModule = c.sqlite3_module{
    .iVersion = 0,
    .xCreate = @ptrFromInt(0),
    .xConnect = c.markdown_filesConnect,
    .xBestIndex = c.markdown_filesBestIndex,
    .xDisconnect = c.markdown_filesDisconnect,
    .xDestroy = @ptrFromInt(0),
    .xOpen = c.markdown_filesOpen,
    .xClose = c.markdown_filesClose,
    .xFilter = c.markdown_filesFilter,
    .xNext = c.markdown_filesNext,
    .xEof = c.markdown_filesEof,
    .xColumn = c.markdown_filesColumn,
    .xRowid = c.markdown_filesRowid,
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
    c.sqlite3_api = pApi;

    // return c.sqlite3_markdown_files_init_c(db, pzErrMsg, pApi);
    _ = pzErrMsg;
    _ = c.sqlite3_malloc(0);
    const name = "markdown_files";
    return c.sqlite3_create_module(db, name.ptr, &MarkdownFilesVTabModule, @ptrFromInt(0));
}
