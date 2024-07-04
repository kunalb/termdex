const std = @import("std");

const c = @cImport({
    @cInclude("sqlite/sqlite3ext.h");
    @cInclude("string.h");
});

// Keep things simple for interop with C, potentially revisit as needed
const c_allocator = std.heap.c_allocator;

// Corresponding to the macro SQLITE_EXTENSION_INIT1
var sqlite3_api: [*c]const c.sqlite3_api_routines = undefined;

pub const CursorState: type = struct {
    walker: std.fs.Dir.Walker,
    entry: ?std.fs.Dir.Walker.Entry = null,
    stat: ?std.fs.File.Stat = null,
};

pub const VTab = extern struct {
    base: c.sqlite3_vtab = std.mem.zeroes(c.sqlite3_vtab),
    root_dir: [*:0]u8,
};

pub const Cursor = extern struct {
    base: c.sqlite3_vtab_cursor = std.mem.zeroes(c.sqlite3_vtab_cursor),
    row_id: c.sqlite3_int64 = 0,
    state: ?*anyopaque = null, // CursorState
};

pub fn vtabConnect(db: ?*c.sqlite3, aux: ?*anyopaque, argc: c_int, argv: [*c]const [*c]const u8, pp_vtab: [*c][*c]c.sqlite3_vtab, pz_err: [*c][*c]u8) callconv(.C) c_int {
    _ = aux;

    if (argc > 4) {
        pz_err.* = c.sqlite3_mprintf("Can specify at most one argument: the root directory for markdown files (received %d).", argc - 3);
        return c.SQLITE_ERROR;
    }

    var new_vtab: *VTab = undefined;
    const rc: c_int = sqlite3_api.*.declare_vtab.?(db, "CREATE TABLE x(path,basename,size_bytes,ctime_s,mtime_s,atime_s)");
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

    const dir = std.fs.openDirAbsoluteZ(vtab.root_dir, .{ .iterate = true }) catch return c.SQLITE_ERROR;
    const walker = dir.walk(c_allocator) catch return c.SQLITE_ERROR;
    const new_cursor: *Cursor = c_allocator.create(Cursor) catch return c.SQLITE_NOMEM;

    var p_state: *CursorState = c_allocator.create(CursorState) catch return c.SQLITE_NOMEM;
    p_state.*.walker = walker;
    p_state.*.entry = p_state.walker.next() catch return c.SQLITE_ERROR;
    new_cursor.state = p_state;
    pp_cursor.* = &new_cursor.*.base;
    return c.SQLITE_OK;
}

pub fn vtabClose(p_base: [*c]c.sqlite3_vtab_cursor) callconv(.C) c_int {
    const cur = @as(*Cursor, @ptrCast(@alignCast(p_base)));
    const state = @as(*CursorState, @ptrCast(@alignCast(cur.state.?)));
    c_allocator.destroy(state);
    c_allocator.destroy(cur);
    return c.SQLITE_OK;
}

pub fn vtabNext(p_cur_base: [*c]c.sqlite3_vtab_cursor) callconv(.C) c_int {
    const cursor: [*c]Cursor = @as([*c]Cursor, @ptrCast(@alignCast(p_cur_base)));
    cursor.*.row_id += 1;
    var state = @as(*CursorState, @ptrCast(@alignCast(cursor.*.state)));

    while (true) {
        state.entry = state.walker.next() catch return c.SQLITE_ERROR;
        state.stat = null;

        if (state.entry == null or state.entry.?.kind == std.fs.Dir.Entry.Kind.file) {
            break;
        }
    }
    return 0;
}

pub fn vtabColumn(p_cur: [*c]c.sqlite3_vtab_cursor, p_ctx: ?*c.sqlite3_context, i: c_int) callconv(.C) c_int {
    const ctx = p_ctx.?;
    const cur = @as(*Cursor, @ptrCast(@alignCast(p_cur)));
    const state = @as(*CursorState, @ptrCast(@alignCast(cur.state.?)));
    const row_id = cur.*.row_id;

    const tab: *VTab = @ptrCast(@alignCast(cur.base.pVtab));
    const entry = state.entry.?;
    const dir = entry.dir;
    const absPath = std.fs.path.join(c_allocator, &[_][]const u8{ tab.root_dir[0..std.mem.len(tab.root_dir)], entry.path }) catch unreachable;
    defer c_allocator.free(absPath);

    // Stat columns
    if (i >= 2 and state.stat == null) {
        state.stat = dir.statFile(absPath) catch |err| {
            std.debug.print("Could not stat {s}: {}", .{ state.entry.?.path, err });
            return c.SQLITE_ERROR;
        };
    }

    switch (i) {
        0 => {
            // Memory leak for generated path
            const path = c_allocator.dupe(u8, absPath) catch unreachable;
            sqlite3_api.*.result_text.?(ctx, path.ptr, @intCast(path.len), null);
        },
        1 => {
            const basename = state.entry.?.basename;
            // Ditto
            sqlite3_api.*.result_text.?(ctx, basename.ptr, @intCast(basename.len), null);
        },
        2 => {
            sqlite3_api.*.result_int64.?(ctx, @intCast(state.stat.?.size));
        },
        3 => {
            sqlite3_api.*.result_int64.?(ctx, @intCast(@divFloor(state.stat.?.ctime, std.time.ns_per_s)));
        },
        4 => {
            sqlite3_api.*.result_int64.?(ctx, @intCast(@divFloor(state.stat.?.mtime, std.time.ns_per_s)));
        },
        5 => {
            sqlite3_api.*.result_int64.?(ctx, @intCast(@divFloor(state.stat.?.atime, std.time.ns_per_s)));
        },
        else => sqlite3_api.*.result_int64.?(ctx, row_id),
    }
    return c.SQLITE_OK;
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

pub fn vtabEof(p_base: [*c]c.sqlite3_vtab_cursor) callconv(.C) c_int {
    const cur = @as(*Cursor, @ptrCast(@alignCast(p_base)));
    const state = @as(*CursorState, @ptrCast(@alignCast(cur.state.?)));
    return @intFromBool(state.entry == null);
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

fn mdfContentsFunc(
    ctx: ?*c.sqlite3_context,
    argc: c_int,
    pp_value: [*c]?*c.sqlite3_value,
) callconv(.C) void {
    std.debug.assert(argc == 1);
    const absPath: [*:0]const u8 = @ptrCast(@alignCast(c.sqlite3_value_text(pp_value[0])));

    const contents = std.fs.cwd().readFileAlloc(c_allocator, absPath[0..std.mem.len(absPath)], std.math.maxInt(usize)) catch |err| {
        const msg = std.fmt.allocPrint(c_allocator, "Could not read contents of {s}: {}", .{ absPath, err }) catch {
            sqlite3_api.*.result_error.?(ctx, "Ran out of memory while trying to report read error!\\x00", -1);
            return;
        };
        sqlite3_api.*.result_error.?(ctx, msg.ptr, @intCast(msg.len));
        return;
    };
    sqlite3_api.*.result_text.?(ctx, contents.ptr, @intCast(contents.len), null);
}

fn mdfContentsDestroy(ptr: ?*anyopaque) callconv(.C) void {
    _ = ptr;
}

export fn sqlite3_markdown_files_init(
    db: *c.sqlite3,
    pzErrMsg: [*c][*c]u8,
    pApi: [*c]const c.sqlite3_api_routines,
) callconv(.C) c_int {
    // Corresponding to the macro SQLITE_EXTENSION_INIT2
    sqlite3_api = pApi;
    _ = pzErrMsg;
    var rc: c_int = c.sqlite3_initialize();
    if (rc != c.SQLITE_OK) {
        return rc;
    }
    rc = c.sqlite3_create_module(db, "markdown_files\x00", &MarkdownFilesVTabModule, @ptrFromInt(0));
    if (rc != c.SQLITE_OK) {
        return rc;
    }

    rc = c.sqlite3_create_function_v2(
        db,
        "mdf_contents",
        1,
        c.SQLITE_UTF8 | c.SQLITE_DETERMINISTIC,
        null,
        mdfContentsFunc,
        null,
        null,
        mdfContentsDestroy,
    );

    return rc;
}
