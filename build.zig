const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const raylib_zig = b.dependency("raylib_zig", .{
        .shared = true,
        .target = target,
        .optimize = optimize,
    });

    const raylib = raylib_zig.module("raylib");
    const raygui = raylib_zig.module("raygui");
    const raylib_artifact = raylib_zig.artifact("raylib");

    raylib_artifact.root_module.addCMacro("SUPPORT_FILEFORMAT_JPG", "");

    const exe_mod = b.createModule(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "raylib", .module = raylib },
            .{ .name = "raygui", .module = raygui },
        },
    });

    exe_mod.linkLibrary(raylib_artifact);
    b.installArtifact(raylib_artifact);

    const exe = b.addExecutable(.{
        .name = "tonnetz",
        .root_module = exe_mod,
    });

    b.installArtifact(exe);

    const run_step = b.step("run", "Run the muzic executable");
    const run_cmd = b.addRunArtifact(exe);
    run_step.dependOn(&run_cmd.step);

    if (b.args) |args| run_cmd.addArgs(args);

    const test_step = b.step("test", "Run the muzic tests");
    const exe_test = b.addTest(.{
        .root_module = exe_mod,
    });
    const test_run = b.addRunArtifact(exe_test);
    test_step.dependOn(&test_run.step);
}
