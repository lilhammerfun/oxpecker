const std = @import("std");
const spec = @import("task_cancel_spec.zig");

pub const ImplMode = enum {
    buggy,
    fixed,
};

pub const Task = struct {
    status: spec.Status,
    tool_inflight: bool,
    ever_cancelled: bool,

    pub fn init() Task {
        return fromState(spec.State.initial());
    }

    fn fromState(state: spec.State) Task {
        return .{
            .status = state.status,
            .tool_inflight = state.tool_inflight,
            .ever_cancelled = state.ever_cancelled,
        };
    }

    fn toState(self: Task) spec.State {
        return .{
            .status = self.status,
            .tool_inflight = self.tool_inflight,
            .ever_cancelled = self.ever_cancelled,
        };
    }

    pub fn apply(self: *Task, mode: ImplMode, event: spec.Event) bool {
        switch (event) {
            .start => {
                if (self.status != .created) return false;
                self.status = .running;
                self.tool_inflight = true;
                return true;
            },
            .cancel => {
                switch (self.status) {
                    .created, .running => {
                        self.status = .cancelled;
                        self.ever_cancelled = true;
                        return true;
                    },
                    .cancelled, .completed => return false,
                }
            },
            .tool_done => {
                if (!self.tool_inflight) return false;
                if (self.status == .running or (mode == .buggy and self.status == .cancelled)) {
                    self.status = .completed;
                    self.tool_inflight = false;
                    return true;
                }
                return false;
            },
        }
    }
};

pub const Mismatch = struct {
    state: spec.State,
    event: spec.Event,
    expected: ?spec.State,
    actual: ?spec.State,
};

pub fn findMismatch(allocator: std.mem.Allocator, mode: ImplMode) !?Mismatch {
    var states: std.ArrayList(spec.State) = .empty;
    defer states.deinit(allocator);

    try states.append(allocator, spec.State.initial());

    var head: usize = 0;
    while (head < states.items.len) : (head += 1) {
        const state = states.items[head];

        for (spec.EVENT_ORDER) |event| {
            const expected = spec.nextState(.fixed, state, event);
            const actual = applyImplementation(mode, state, event);
            if (!sameOptionalState(expected, actual)) {
                return .{
                    .state = state,
                    .event = event,
                    .expected = expected,
                    .actual = actual,
                };
            }

            if (expected) |next| {
                if (!hasSeenState(states.items, next)) {
                    try states.append(allocator, next);
                }
            }
        }
    }

    return null;
}

fn applyImplementation(mode: ImplMode, state: spec.State, event: spec.Event) ?spec.State {
    var task = Task.fromState(state);
    if (!task.apply(mode, event)) {
        return null;
    }
    return task.toState();
}

fn sameOptionalState(a: ?spec.State, b: ?spec.State) bool {
    if (a == null and b == null) return true;
    if (a == null or b == null) return false;
    return sameState(a.?, b.?);
}

fn sameState(a: spec.State, b: spec.State) bool {
    return spec.stateEql(a, b);
}

fn hasSeenState(states: []const spec.State, state: spec.State) bool {
    for (states) |seen| {
        if (spec.stateEql(seen, state)) return true;
    }
    return false;
}

test "buggy implementation diverges from the fixed model" {
    const mismatch = (try findMismatch(std.testing.allocator, .buggy)) orelse
        return error.ExpectedMismatch;

    try std.testing.expectEqual(spec.Status.cancelled, mismatch.state.status);
    try std.testing.expectEqual(spec.Event.tool_done, mismatch.event);
    try std.testing.expectEqual(@as(?spec.State, null), mismatch.expected);
    try std.testing.expect(mismatch.actual != null);
    try std.testing.expectEqual(spec.Status.completed, mismatch.actual.?.status);
}

test "fixed implementation matches the fixed model" {
    const mismatch = try findMismatch(std.testing.allocator, .fixed);
    try std.testing.expectEqual(@as(?Mismatch, null), mismatch);
}
