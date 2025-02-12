const std = @import("std");

const Options = struct {
    build: *std.Build,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
};

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const zyra_root_file_path = b.path("src/zyra.zig");

    const zyra_lib = b.addStaticLibrary(.{
        .name = "zyra",
        .root_source_file = zyra_root_file_path,
        .target = target,
        .optimize = optimize,
    });

    b.installArtifact(zyra_lib);

    const options: Options = .{
        .build = b,
        .target = target,
        .optimize = optimize,
    };

    setup_tests(options);
}

// Tests
pub fn setup_tests(options: Options) void {
    const b = options.build;
    const target = options.target;
    const optimize = options.optimize;

    const root_file_path = b.path("src/test.zig");

    const zyra_test_step = b.step("test", "Run all tests recursively");
    const zyra_tests = b.addTest(.{
        .root_source_file = root_file_path,
        .target = target,
        .optimize = optimize,
    });

    const zyra_run_tests = b.addRunArtifact(zyra_tests);
    zyra_test_step.dependOn(&zyra_run_tests.step);
}
