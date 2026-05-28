const std = @import("std");
const task_cancel = @import("task_cancel_checker.zig");

pub fn main() !void {
    var stdout_buffer: [4096]u8 = undefined;
    var stdout_writer = std.fs.File.Writer.init(std.fs.File.stdout(), &stdout_buffer);
    defer stdout_writer.interface.flush() catch {};
    const stdout = &stdout_writer.interface;

    var debug_allocator: std.heap.DebugAllocator(.{}) = .init;
    defer _ = debug_allocator.deinit();
    const allocator = debug_allocator.allocator();

    try stdout.writeAll("buggy cancellation model\n");
    const buggy = try task_cancel.check(allocator, .{
        .allow_done_after_cancel = true,
    });
    defer buggy.deinit(allocator);
    try printResult(stdout, buggy);

    try stdout.writeAll("\nfixed cancellation model\n");
    const fixed = try task_cancel.check(allocator, .{
        .allow_done_after_cancel = false,
    });
    defer fixed.deinit(allocator);
    try printResult(stdout, fixed);
}

fn printResult(writer: *std.Io.Writer, result: task_cancel.CheckResult) !void {
    switch (result) {
        .holds => |holds| {
            try writer.print("invariant holds after exploring {d} states\n", .{
                holds.states_explored,
            });
        },
        .violated => |violation| {
            try writer.print("invariant violated after exploring {d} states\n", .{
                violation.states_explored,
            });
            try writer.writeAll("counterexample trace:\n");
            for (violation.trace, 0..) |step, index| {
                try writer.print("{d}. ", .{index});
                if (step.event) |event| {
                    try writer.print("{s}: ", .{@tagName(event)});
                } else {
                    try writer.writeAll("initial: ");
                }
                try printState(writer, step.state);
                try writer.writeByte('\n');
            }
        },
    }
}

fn printState(writer: *std.Io.Writer, state: task_cancel.State) !void {
    try writer.print(
        "status={s}, tool_inflight={}, ever_cancelled={}",
        .{
            @tagName(state.status),
            state.tool_inflight,
            state.ever_cancelled,
        },
    );
}
