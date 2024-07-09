const std = @import("std");

const c = @cImport({
    @cInclude("string.h");
    @cInclude("/usr/include/sqlite3ext.h");
    @cInclude("/usr/include/yaml.h");
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
    p_state.walker = walker;
    p_state.stat = null;
    while (true) {
        p_state.entry = p_state.walker.next() catch return c.SQLITE_ERROR;
        if (p_state.entry == null or p_state.entry.?.kind == std.fs.Dir.Entry.Kind.file) {
            break;
        }
    }

    std.debug.assert(p_state.*.stat == null);
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

    state.stat = null;
    while (true) {
        state.entry = state.walker.next() catch return c.SQLITE_ERROR;
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
            const error_msg = std.fmt.allocPrint(c_allocator, "Could not stat {s}: {}", .{ absPath, err }) catch {
                return c.SQLITE_NOMEM;
            };
            defer c_allocator.free(error_msg);
            sqlite3_api.*.result_error.?(ctx, error_msg.ptr, @intCast(error_msg.len));
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

pub fn vtabFilter(p_vtab_cursor: [*c]c.sqlite3_vtab_cursor, idx_num: c_int, idx_str: [*c]const u8, argc: c_int, argv: [*c]?*c.sqlite3_value) callconv(.C) c_int {
    _ = idx_num;
    _ = idx_str;
    _ = argc;
    _ = argv;
    const cur: [*c]Cursor = @as([*c]Cursor, @ptrCast(@alignCast(p_vtab_cursor)));
    cur.*.row_id = 1;
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

fn mdfFrontMatterFunc(ctx: ?*c.sqlite3_context, argc: c_int, pp_value: [*c]?*c.sqlite3_value) callconv(.C) void {
    std.debug.assert(argc == 2);
    const abs_path: [*:0]const u8 = @ptrCast(@alignCast(c.sqlite3_value_text(pp_value[0])));
    const field: [*:0]const u8 = @ptrCast(@alignCast(c.sqlite3_value_text(pp_value[1])));

    const val = frontMatter(std.mem.span(abs_path), std.mem.span(field)) catch |err| {
        const err_msg = std.fmt.allocPrint(c_allocator, "{?}", .{err}) catch {
            sqlite3_api.*.result_error.?(ctx, "Ran out of memory while trying to report error!", -1);
            return;
        };

        defer c_allocator.free(err_msg);
        sqlite3_api.*.result_error.?(ctx, err_msg.ptr, @intCast(err_msg.len));
        return;
    };

    if (val == null) {
        sqlite3_api.*.result_null.?(ctx);
    } else {
        sqlite3_api.*.result_text.?(ctx, val.?.ptr, @intCast(val.?.len), null);
    }
}

const FrontMatterError = error{
    YAMLParserInitFailed,
    YAMLParserError,
};

fn frontMatter(
    abs_path: []const u8,
    field: []const u8,
) !?[]u8 {
    const file = try std.fs.cwd().openFile(abs_path, .{});
    defer file.close();

    var buf_reader = std.io.bufferedReader(file.reader());
    var in_stream = buf_reader.reader();
    var buf: [4096]u8 = undefined;
    var raw_yaml = std.ArrayList(u8).init(c_allocator);
    defer raw_yaml.deinit();

    var first = true;
    while (try in_stream.readUntilDelimiterOrEof(&buf, '\n')) |line| {
        if (first and !std.mem.eql(u8, line[0..3], "---")) {
            break;
        } else if (!first and std.mem.eql(u8, line[0..3], "---")) {
            break;
        } else if (!first) {
            try raw_yaml.appendSlice(line);
            try raw_yaml.append('\n');
        }

        first = false;
    }

    const raw_yaml_contiguous = try raw_yaml.toOwnedSliceSentinel(0);
    defer c_allocator.free(raw_yaml_contiguous);

    var event: c.yaml_event_t = undefined;
    var parser: c.yaml_parser_t = undefined;
    if (c.yaml_parser_initialize(&parser) != 1) {
        return FrontMatterError.YAMLParserInitFailed;
    }
    defer c.yaml_parser_delete(&parser);
    c.yaml_parser_set_input_string(&parser, raw_yaml_contiguous.ptr, raw_yaml_contiguous.len);

    var return_next_token = false;
    while (true) {
        if (c.yaml_parser_parse(&parser, &event) != 1) {
            std.debug.print("Failed to parse {s}\n\n", .{abs_path});
            return FrontMatterError.YAMLParserError;
        }
        defer c.yaml_event_delete(&event);

        switch (event.type) {
            c.YAML_STREAM_END_EVENT => break,
            c.YAML_SCALAR_EVENT => {
                const key = event.data.scalar.value;
                if (std.mem.eql(u8, std.mem.span(key), field)) {
                    return_next_token = true;
                    break;
                }
            },
            else => {},
        }
    }

    if (!return_next_token) {
        return null;
    }

    var result_pieces = std.ArrayList(u8).init(c_allocator);
    defer result_pieces.deinit();

    var state_stack = std.ArrayList(FrontMatterState).init(c_allocator);
    defer state_stack.deinit();

    try state_stack.append(FrontMatterState.Start);

    while (state_stack.items.len > 0) {
        if (c.yaml_parser_parse(&parser, &event) != 1) {
            std.debug.print("Failed to parse {s}\n\n", .{abs_path});
            return FrontMatterError.YAMLParserError;
        }
        defer c.yaml_event_delete(&event);

        const popped = state_stack.pop();

        if (event.type == c.YAML_SEQUENCE_START_EVENT) {
            try state_stack.append(FrontMatterState.SequenceStart);
            try result_pieces.appendSlice("[ ");
        } else if (event.type == c.YAML_SEQUENCE_END_EVENT) {
            try result_pieces.appendSlice(" ]");
        } else if (event.type == c.YAML_MAPPING_START_EVENT) {
            try state_stack.append(FrontMatterState.MappingStart);
            try result_pieces.appendSlice("{ ");
        } else if (event.type == c.YAML_MAPPING_END_EVENT) {
            try result_pieces.appendSlice(" }");
        } else if (event.type == c.YAML_SCALAR_EVENT) {
            const val = std.mem.span(event.data.scalar.value);

            switch (popped) {
                FrontMatterState.Start => {
                    try result_pieces.appendSlice(val);
                },
                FrontMatterState.SequenceStart => {
                    try state_stack.append(FrontMatterState.SequenceInside);
                    try result_pieces.appendSlice(val);
                },
                FrontMatterState.SequenceInside => {
                    try state_stack.append(FrontMatterState.SequenceInside);
                    try result_pieces.appendSlice(", ");
                    try result_pieces.appendSlice(val);
                },
                FrontMatterState.MappingStart => {
                    try result_pieces.appendSlice(val);
                    try state_stack.append(FrontMatterState.MappingVal);
                },
                FrontMatterState.MappingKey => {
                    try result_pieces.appendSlice(", ");
                    try result_pieces.appendSlice(val);
                    try state_stack.append(FrontMatterState.MappingVal);
                },
                FrontMatterState.MappingVal => {
                    try result_pieces.appendSlice(": ");
                    try result_pieces.appendSlice(val);
                    try state_stack.append(FrontMatterState.MappingKey);
                },
            }
        } else if (event.type == c.YAML_STREAM_END_EVENT) {
            break;
        }
    }

    const result = try result_pieces.toOwnedSlice();
    return result;
}

const FrontMatterState = enum {
    Start,
    SequenceStart,
    SequenceInside,
    MappingStart,
    MappingKey,
    MappingVal,
};

export fn sqlite3_markdownfiles_init(
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
        c.SQLITE_UTF8,
        null,
        mdfContentsFunc,
        null,
        null,
        null,
    );
    if (rc != c.SQLITE_OK) {
        return rc;
    }

    return c.sqlite3_create_function_v2(db, "mdf_front_matter", 2, c.SQLITE_UTF8, null, mdfFrontMatterFunc, null, null, null);
}
