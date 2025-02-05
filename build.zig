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

    const zyra_module = b.addModule("zyra", .{
        .root_source_file = zyra_root_file_path,
        .target = target,
        .optimize = optimize,
    });

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

    setup_examples(zyra_module, options);
    setup_tests(options);
}

pub fn setup_examples(module: *const std.Build.Module, options: Options) void {
    const b = options.build;
    const target = options.target;
    const optimize = options.optimize;

    const example_step = b.step("examples", "Build examples");

    const simple_example_exec = b.addExecutable(.{
        .name = "simple_example",
        .root_source_file = b.path("examples/simple_example.zig"),
        .target = target,
        .optimize = optimize,
    });
    const install_simple_example = b.addInstallArtifact(simple_example_exec, .{});
    simple_example_exec.root_module.addImport("zyra", @constCast(module));

    example_step.dependOn(&simple_example_exec.step);
    example_step.dependOn(&install_simple_example.step);

    b.default_step.dependOn(example_step);
}

// Tests
pub fn setup_tests(options: Options) void {
    const b = options.build;
    const target = options.target;
    const optimize = options.optimize;

    const root_file_path = b.path("src/zyra.zig");

    const zyra_test_step = b.step("test", "Run all tests recursively");
    const zyra_tests = b.addTest(.{
        .root_source_file = root_file_path,
        .target = target,
        .optimize = optimize,
    });

    const zyra_run_tests = b.addRunArtifact(zyra_tests);
    zyra_test_step.dependOn(&zyra_run_tests.step);
}
