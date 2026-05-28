const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const oxpecker_module = b.addModule("oxpecker", .{
        .root_source_file = b.path("src/oxpecker.zig"),
        .target = target,
        .optimize = optimize,
    });

    const exe = b.addExecutable(.{
        .name = "oxpecker",
        .root_module = b.createModule(.{
            .root_source_file = b.path("book/booklet/01-practice-intuition/code/task_cancel_demo.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    b.installArtifact(exe);

    const run_cmd = b.addRunArtifact(exe);
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run the task cancellation model checker demo");
    run_step.dependOn(&run_cmd.step);

    const test_step = b.step("test", "Run Zig unit tests");
    test_step.dependOn(&addTestRun(b, target, optimize, "src/oxpecker.zig").step);
    test_step.dependOn(&addTestRun(b, target, optimize, "book/booklet/01-practice-intuition/code/task_cancel_checker.zig").step);
    test_step.dependOn(&addOxpeckerTestRun(b, target, optimize, "book/booklet/01-practice-intuition/code/task_cancel_spec.zig", oxpecker_module).step);
    test_step.dependOn(&addOxpeckerTestRun(b, target, optimize, "examples/agent_task_check.zig", oxpecker_module).step);
    test_step.dependOn(&addOxpeckerTestRun(b, target, optimize, "book/booklet/01-practice-intuition/code/task_implementation.zig", oxpecker_module).step);
}

fn addTestRun(
    b: *std.Build,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
    root_source_file: []const u8,
) *std.Build.Step.Run {
    const tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path(root_source_file),
            .target = target,
            .optimize = optimize,
        }),
    });
    return b.addRunArtifact(tests);
}

fn addOxpeckerTestRun(
    b: *std.Build,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
    root_source_file: []const u8,
    oxpecker_module: *std.Build.Module,
) *std.Build.Step.Run {
    const test_module = b.createModule(.{
        .root_source_file = b.path(root_source_file),
        .target = target,
        .optimize = optimize,
    });
    test_module.addImport("oxpecker", oxpecker_module);

    const tests = b.addTest(.{
        .root_module = test_module,
    });
    return b.addRunArtifact(tests);
}
