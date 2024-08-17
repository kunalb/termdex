const std = @import("std");

fn addInitModule(b: *std.Build, lib: *std.Build.Step.Compile) !void {
    const gen = b.addWriteFiles();

    const contents =
        \\const root = @import("root");
        \\
        \\export fn sqlite3_{s}_init(
        \\    db: *root.csql.sqlite3,
        \\    pz_err_msg: [*c][*c]u8,
        \\    p_api: [*c]const root.csql.sqlite3_api_routines,
        \\) callconv(.C) c_int {{
        \\    const init_result = root.csql.sqlite3_initialize();
        \\    if (init_result != root.csql.SQLITE_OK) {{
        \\        return init_result;
        \\    }}
        \\    return root.initModule(db, pz_err_msg, p_api);
        \\}}
        \\
    ;
    const format_contents = try std.fmt.allocPrint(b.allocator, contents, .{lib.name});
    defer b.allocator.free(format_contents);

    const func_source = gen.add(
        "gen_init.zig",
        format_contents,
    );
    lib.root_module.addAnonymousImport("gen_init", .{
        .root_source_file = func_source,
        .link_libc = true,
    });
}

fn setupTarget(t: *std.Build.Step.Compile) void {
    t.addSystemIncludePath(.{ .cwd_relative = "/usr/local/include" });
    t.addLibraryPath(.{ .cwd_relative = "/usr/local/lib" });
    t.linkSystemLibrary("sqlite3");
    t.linkSystemLibrary2("yaml", .{ .preferred_link_mode = std.builtin.LinkMode.dynamic });
    t.linkSystemLibrary2("cmark-gfm", .{ .preferred_link_mode = std.builtin.LinkMode.dynamic });
}

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const lib = b.addSharedLibrary(.{
        .name = "md_files",
        .root_source_file = b.path("src/md_files.zig"),
        .target = target,
        .optimize = optimize,
        .pic = true,
        .link_libc = true,
    });
    setupTarget(lib);
    b.installArtifact(lib);

    const mdlib = b.addSharedLibrary(.{
        .name = "md",
        .root_source_file = b.path("src/md_nodes.zig"),
        .target = target,
        .optimize = optimize,
        .pic = true,
        .link_libc = true,
    });
    _ = try addInitModule(b, mdlib);
    setupTarget(mdlib);
    b.installArtifact(mdlib);

    const path = try std.fs.path.join(b.allocator, &.{ b.install_path, "lib/libmd" });
    const options = b.addOptions();
    options.addOption([]const u8, "libmd_path", path);

    const mdlib_tests = b.addTest(.{
        .root_source_file = b.path("tests/md_nodes_test.zig"),
        .target = target,
        .optimize = optimize,
        .link_libc = true,
    });
    mdlib_tests.root_module.addOptions("build_paths", options);
    setupTarget(mdlib_tests);
    const run_mdlib_tests = b.addRunArtifact(mdlib_tests);
    const mdlib_tests_step = b.step("mdlib_tests", "Run mdlib tests");
    mdlib_tests_step.dependOn(&mdlib.step);
    mdlib_tests_step.dependOn(&run_mdlib_tests.step);

    const lib_unit_tests = b.addTest(.{
        .root_source_file = b.path("src/markdown_files.zig"),
        .target = target,
        .optimize = optimize,
        .link_libc = true,
    });
    setupTarget(lib_unit_tests);
    const run_lib_unit_tests = b.addRunArtifact(lib_unit_tests);
    const test_step = b.step("mdfiles_test", "Run unit tests");
    test_step.dependOn(&run_lib_unit_tests.step);
}
