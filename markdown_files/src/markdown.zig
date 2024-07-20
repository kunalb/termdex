const std = @import("std");
const c = @cImport({
    @cInclude("/usr/include/cmark-gfm.h");
});

// Uses malloc, no other choices
pub fn toHTML(abs_path: []const u8, allocator: std.mem.Allocator) !?[]u8 {
    const file = try std.fs.cwd().openFile(abs_path, .{});
    defer file.close();
    const contents = try file.readToEndAlloc(allocator, 10000000);
    const c_ptr = c.cmark_markdown_to_html(contents.ptr, contents.len, 0);
    std.debug.print("Failed to parse {s}\n\n", .{c_ptr});
    return std.mem.span(c_ptr);
}
