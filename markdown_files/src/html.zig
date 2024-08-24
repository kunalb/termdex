const std = @import("std");
const c = @cImport({
    @cInclude("cmark-gfm.h");
    @cInclude("string.h");
});

// TODO Make this frontmatter aware

pub fn toHTML(abs_path: []const u8, allocator: std.mem.Allocator) !?[]u8 {
    const file = try std.fs.cwd().openFile(abs_path, .{});
    defer file.close();
    const contents = try file.readToEndAlloc(allocator, 10000000);
    const c_ptr = c.cmark_markdown_to_html(contents.ptr, contents.len, 0);
    return std.mem.span(c_ptr);
}

test "Test html conversion" {
    const test_file = "./resources/test_post.md";
    const converted = try toHTML(test_file, std.heap.c_allocator);
    const expected = "<h1>Heading</h1>\n<p>A paragraph of content with <a href=\"https://github.com/kunalb/termdex\">links</a>.</p>\n";
    try std.testing.expectEqualStrings(expected, converted.?);
}
