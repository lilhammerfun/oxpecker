const std = @import("std");

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
    // The safety property depends on history, not only the current status.
    ever_cancelled: bool,

    pub fn initial() State {
        return .{
            .status = .created,
            .tool_inflight = false,
            .ever_cancelled = false,
        };
    }

    pub fn key(self: State) u8 {
        return @as(u8, @intFromEnum(self.status)) |
            (@as(u8, @intFromBool(self.tool_inflight)) << 2) |
            (@as(u8, @intFromBool(self.ever_cancelled)) << 3);
    }
};

pub const Model = struct {
    allow_done_after_cancel: bool,
};

const Node = struct {
    state: State,
    parent: ?usize,
    event: ?Event,
};

pub const TraceStep = struct {
    event: ?Event,
    state: State,
};

pub const Holds = struct {
    states_explored: usize,
};

pub const Violation = struct {
    states_explored: usize,
    trace: []TraceStep,
};

pub const CheckResult = union(enum) {
    holds: Holds,
    violated: Violation,

    pub fn deinit(self: CheckResult, allocator: std.mem.Allocator) void {
        switch (self) {
            .holds => {},
            .violated => |violation| allocator.free(violation.trace),
        }
    }
};

pub fn check(allocator: std.mem.Allocator, model: Model) !CheckResult {
    var nodes: std.ArrayList(Node) = .empty;
    defer nodes.deinit(allocator);

    var visited = std.AutoHashMap(u8, usize).init(allocator);
    defer visited.deinit();

    try nodes.append(allocator, .{
        .state = State.initial(),
        .parent = null,
        .event = null,
    });
    try visited.put(State.initial().key(), 0);

    var head: usize = 0;
    while (head < nodes.items.len) : (head += 1) {
        const node = nodes.items[head];

        if (!invariant(node.state)) {
            const trace = try buildTrace(allocator, nodes.items, head);
            return .{ .violated = .{
                .states_explored = nodes.items.len,
                .trace = trace,
            } };
        }

        for (EVENT_ORDER) |event| {
            const next = nextState(model, node.state, event) orelse continue;
            const next_key = next.key();
            if (visited.contains(next_key)) {
                continue;
            }

            const next_index = nodes.items.len;
            try visited.put(next_key, next_index);
            try nodes.append(allocator, .{
                .state = next,
                .parent = head,
                .event = event,
            });
        }
    }

    return .{ .holds = .{ .states_explored = nodes.items.len } };
}

pub fn nextState(model: Model, state: State, event: Event) ?State {
    switch (event) {
        .start => {
            if (state.status != .created) return null;
            return .{
                .status = .running,
                .tool_inflight = true,
                .ever_cancelled = state.ever_cancelled,
            };
        },
        .cancel => {
            switch (state.status) {
                .created, .running => return .{
                    .status = .cancelled,
                    .tool_inflight = state.tool_inflight,
                    .ever_cancelled = true,
                },
                .cancelled, .completed => return null,
            }
        },
        .tool_done => {
            if (!state.tool_inflight) return null;
            if (state.status != .running and
                !(model.allow_done_after_cancel and state.status == .cancelled))
            {
                return null;
            }
            return .{
                .status = .completed,
                .tool_inflight = false,
                .ever_cancelled = state.ever_cancelled,
            };
        },
    }
}

fn invariant(state: State) bool {
    return !(state.ever_cancelled and state.status == .completed);
}

fn buildTrace(
    allocator: std.mem.Allocator,
    nodes: []const Node,
    failed_index: usize,
) ![]TraceStep {
    var reversed: std.ArrayList(TraceStep) = .empty;
    defer reversed.deinit(allocator);

    var cursor: ?usize = failed_index;
    while (cursor) |index| {
        const node = nodes[index];
        try reversed.append(allocator, .{
            .event = node.event,
            .state = node.state,
        });
        cursor = node.parent;
    }

    const trace = try allocator.alloc(TraceStep, reversed.items.len);
    for (reversed.items, 0..) |step, index| {
        trace[reversed.items.len - index - 1] = step;
    }
    return trace;
}

test "buggy model finds cancel then done counterexample" {
    const result = try check(std.testing.allocator, .{
        .allow_done_after_cancel = true,
    });
    defer result.deinit(std.testing.allocator);

    const violation = switch (result) {
        .violated => |violation| violation,
        .holds => return error.ExpectedViolation,
    };

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
    const result = try check(std.testing.allocator, .{
        .allow_done_after_cancel = false,
    });
    defer result.deinit(std.testing.allocator);

    switch (result) {
        .holds => |holds| try std.testing.expect(holds.states_explored > 0),
        .violated => return error.UnexpectedViolation,
    }
}
