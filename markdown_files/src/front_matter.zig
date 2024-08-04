const std = @import("std");

const c = @cImport({
    @cInclude("yaml.h");
});

const FrontMatterState = enum {
    Start,
    SequenceStart,
    SequenceInside,
    MappingStart,
    MappingKey,
    MappingVal,
};

const FrontMatterError = error{
    YAMLParserInitFailed,
    YAMLParserError,
};

pub fn parseFrontMatter(
    abs_path: []const u8,
    field: []const u8,
    allocator: std.mem.Allocator,
) !?[]u8 {
    const file = try std.fs.cwd().openFile(abs_path, .{});
    defer file.close();

    var buf_reader = std.io.bufferedReader(file.reader());
    var in_stream = buf_reader.reader();
    var buf: [4096]u8 = undefined;
    var raw_yaml = std.ArrayList(u8).init(allocator);
    defer raw_yaml.deinit();

    var first = true;
    while (try in_stream.readUntilDelimiterOrEof(&buf, '\n')) |line| {
        if (first and !(line.len >= 3 and std.mem.eql(u8, line[0..3], "---"))) {
            break;
        } else if (!first and line.len >= 3 and std.mem.eql(u8, line[0..3], "---")) {
            break;
        } else if (!first) {
            try raw_yaml.appendSlice(line);
            try raw_yaml.append('\n');
        }

        first = false;
    }

    const raw_yaml_contiguous = try raw_yaml.toOwnedSliceSentinel(0);
    defer allocator.free(raw_yaml_contiguous);

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

    var result_pieces = std.ArrayList(u8).init(allocator);
    defer result_pieces.deinit();

    var state_stack = std.ArrayList(FrontMatterState).init(allocator);
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
