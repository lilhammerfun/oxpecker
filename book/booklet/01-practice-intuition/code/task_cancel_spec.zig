const std = @import("std");
const oxpecker = @import("oxpecker");

pub const Status = enum(u2) {
    created,
    running,
    cancelled,
    completed,
};

pub const Event = enum {
    start,
    cancel,
    tool_done,
};

pub const EVENT_ORDER = [_]Event{ .start, .cancel, .tool_done };

pub const State = struct {
    status: Status,
    tool_inflight: bool,
    // This records history that cannot be recovered from the current status.
    ever_cancelled: bool,

    pub fn initial() State {
        return .{
            .status = .created,
            .tool_inflight = false,
            .ever_cancelled = false,
        };
    }
};

pub const ModelMode = enum {
    buggy,
    fixed,
};

pub const Action = oxpecker.Action(State, Event);
pub const Invariant = oxpecker.Invariant(State);
pub const Spec = oxpecker.Spec(State, Event);
pub const CheckResult = oxpecker.CheckResult(State, Event);
pub const TraceStep = oxpecker.TraceStep(State, Event);

/// Build the task cancellation spec in either its buggy or fixed rule set.
pub fn spec(comptime mode: ModelMode) Spec {
    return .{
        .init = State.initial(),
        .next = &.{
            .{ .name = "Start", .event = .start, .next = start },
            .{ .name = "Cancel", .event = .cancel, .next = cancel },
            .{ .name = "ToolDone", .event = .tool_done, .next = if (mode == .buggy) toolDoneBuggy else toolDoneFixed },
        },
        .invariants = &.{
            .{ .name = "NoCompleteAfterCancel", .holds = noCompleteAfterCancel },
        },
        .state_eql = stateEql,
    };
}

pub fn check(allocator: std.mem.Allocator, comptime mode: ModelMode) !CheckResult {
    return oxpecker.check(State, Event, allocator, spec(mode));
}

/// Ask the spec what one event does from one state.
pub fn nextState(comptime mode: ModelMode, state: State, event: Event) ?State {
    for (spec(mode).next) |action| {
        if (action.event == event) {
            return action.next(state);
        }
    }
    return null;
}

fn start(state: State) ?State {
    if (state.status != .created) return null;
    return .{
        .status = .running,
        .tool_inflight = true,
        .ever_cancelled = state.ever_cancelled,
    };
}

fn cancel(state: State) ?State {
    switch (state.status) {
        .created, .running => return .{
            .status = .cancelled,
            .tool_inflight = state.tool_inflight,
            .ever_cancelled = true,
        },
        .cancelled, .completed => return null,
    }
}

fn toolDoneBuggy(state: State) ?State {
    if (!state.tool_inflight) return null;
    if (state.status != .running and state.status != .cancelled) return null;
    return .{
        .status = .completed,
        .tool_inflight = false,
        .ever_cancelled = state.ever_cancelled,
    };
}

fn toolDoneFixed(state: State) ?State {
    if (!state.tool_inflight) return null;
    if (state.status != .running) return null;
    return .{
        .status = .completed,
        .tool_inflight = false,
        .ever_cancelled = state.ever_cancelled,
    };
}

pub fn noCompleteAfterCancel(state: State) bool {
    // Once cancellation has happened, completed is a bad reachable state.
    return !(state.ever_cancelled and state.status == .completed);
}

/// State equality is exact; this prevents key/hash collisions from hiding states.
pub fn stateEql(a: State, b: State) bool {
    return a.status == b.status and
        a.tool_inflight == b.tool_inflight and
        a.ever_cancelled == b.ever_cancelled;
}

test "buggy model finds cancel then done counterexample" {
    const result = try check(std.testing.allocator, .buggy);
    defer result.deinit(std.testing.allocator);

    const violation = switch (result) {
        .violated => |violation| violation,
        .holds => return error.ExpectedViolation,
    };

    try std.testing.expectEqualStrings("NoCompleteAfterCancel", violation.invariant_name);
    try std.testing.expectEqual(@as(usize, 4), violation.trace.len);
    try std.testing.expectEqual(Status.created, violation.trace[0].state.status);
    try std.testing.expectEqual(Event.start, violation.trace[1].event.?);
    try std.testing.expectEqual(Status.running, violation.trace[1].state.status);
    try std.testing.expectEqual(Event.cancel, violation.trace[2].event.?);
    try std.testing.expectEqual(Status.cancelled, violation.trace[2].state.status);
    try std.testing.expectEqual(Event.tool_done, violation.trace[3].event.?);
    try std.testing.expectEqual(Status.completed, violation.trace[3].state.status);
    try std.testing.expect(violation.trace[3].state.ever_cancelled);
}

test "fixed model satisfies cancellation invariant" {
    const result = try check(std.testing.allocator, .fixed);
    defer result.deinit(std.testing.allocator);

    switch (result) {
        .holds => |holds| try std.testing.expect(holds.states_explored > 0),
        .violated => return error.UnexpectedViolation,
    }
}
