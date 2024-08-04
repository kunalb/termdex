const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const lib = b.addSharedLibrary(.{
        .name = "markdown_files",
        .root_source_file = b.path("src/markdown_files.zig"),
        .target = target,
        .optimize = optimize,
        .pic = true,
        .link_libc = true,
    });
    lib.addSystemIncludePath(.{ .cwd_relative = "/usr/local/include" });
    lib.addLibraryPath(.{ .cwd_relative = "/usr/local/lib" });
    lib.linkSystemLibrary("sqlite3");
    lib.linkSystemLibrary2("yaml", .{ .preferred_link_mode = std.builtin.LinkMode.dynamic });
    lib.linkSystemLibrary2("cmark-gfm", .{ .preferred_link_mode = std.builtin.LinkMode.dynamic });
    b.installArtifact(lib);

    const lib_unit_tests = b.addTest(.{
        .root_source_file = b.path("src/markdown_files.zig"),
        .target = target,
        .optimize = optimize,
        .link_libc = true,
    });
    lib_unit_tests.addSystemIncludePath(.{ .cwd_relative = "/usr/local/include" });
    lib_unit_tests.addLibraryPath(.{ .cwd_relative = "/usr/local/lib" });
    lib_unit_tests.linkSystemLibrary("sqlite3");
    lib_unit_tests.linkSystemLibrary("yaml");
    lib_unit_tests.linkSystemLibrary("cmark-gfm");
    const run_lib_unit_tests = b.addRunArtifact(lib_unit_tests);

    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_lib_unit_tests.step);
}
