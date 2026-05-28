const std = @import("std");
const oxpecker = @import("oxpecker");
const candidate = @import("agent_task_candidate.zig");
const task_spec = @import("agent_task_spec.zig");

pub const State = task_spec.State;
pub const Event = task_spec.Event;
pub const Action = oxpecker.Action(State, Event);
pub const Invariant = oxpecker.Invariant(State);
pub const Spec = oxpecker.Spec(State, Event);
pub const CheckResult = oxpecker.CheckResult(State, Event);

fn fromState(state: State) candidate.Task {
    return .{
        .status = state.status,
        .tool_inflight = state.tool_inflight,
        .ever_cancelled = state.ever_cancelled,
    };
}

fn toState(task: candidate.Task) State {
    return .{
        .status = task.status,
        .tool_inflight = task.tool_inflight,
        .ever_cancelled = task.ever_cancelled,
    };
}

fn startToolCall(state: State) ?State {
    var task = fromState(state);
    if (!task.startToolCall()) return null;
    return toState(task);
}

fn cancel(state: State) ?State {
    var task = fromState(state);
    if (!task.cancel()) return null;
    return toState(task);
}

fn toolResult(state: State) ?State {
    var task = fromState(state);
    if (!task.handleToolResult()) return null;
    return toState(task);
}

pub fn spec() Spec {
    return .{
        .init = State.initial(),
        .next = &.{
            .{ .name = "StartToolCall", .event = .start_tool_call, .next = startToolCall },
            .{ .name = "Cancel", .event = .cancel, .next = cancel },
            .{ .name = "ToolResult", .event = .tool_result, .next = toolResult },
        },
        .invariants = &.{
            .{ .name = "NoCompleteAfterCancel", .holds = task_spec.noCompleteAfterCancel },
        },
        .state_eql = task_spec.stateEql,
    };
}

pub fn check(allocator: std.mem.Allocator) !CheckResult {
    return oxpecker.check(State, Event, allocator, spec());
}

test "late tool result can complete a cancelled task" {
    const result = try check(std.testing.allocator);
    defer result.deinit(std.testing.allocator);

    const violation = switch (result) {
        .violated => |violation| violation,
        .holds => return error.ExpectedViolation,
    };

    try std.testing.expectEqualStrings("NoCompleteAfterCancel", violation.invariant_name);
    try std.testing.expectEqual(@as(usize, 4), violation.trace.len);
    try std.testing.expectEqual(Event.start_tool_call, violation.trace[1].event.?);
    try std.testing.expectEqual(Event.cancel, violation.trace[2].event.?);
    try std.testing.expectEqual(Event.tool_result, violation.trace[3].event.?);
    try std.testing.expectEqual(task_spec.Status.completed, violation.trace[3].state.status);
    try std.testing.expect(violation.trace[3].state.ever_cancelled);
}
