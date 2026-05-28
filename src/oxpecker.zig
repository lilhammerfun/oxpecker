const std = @import("std");

/// One named transition the checker can try from a reachable state.
pub fn Action(comptime State: type, comptime Event: type) type {
    comptime {
        validateState(State);
        validateEvent(Event);
    }

    return struct {
        name: []const u8,
        event: Event,
        next: *const fn (state: State) ?State,
    };
}

/// A named property that must hold for every reachable state.
pub fn Invariant(comptime State: type) type {
    comptime validateState(State);

    return struct {
        name: []const u8,
        holds: *const fn (state: State) bool,
    };
}

/// A finite-state specification that the checker can explore.
pub fn Spec(comptime State: type, comptime Event: type) type {
    comptime {
        validateState(State);
        validateEvent(Event);
    }

    return struct {
        init: State,
        next: []const Action(State, Event),
        invariants: []const Invariant(State),
        state_eql: *const fn (a: State, b: State) bool,
    };
}

/// Result of checking all reachable states from `Spec.init`.
pub fn CheckResult(comptime State: type, comptime Event: type) type {
    comptime {
        validateState(State);
        validateEvent(Event);
    }

    return union(enum) {
        holds: Holds,
        violated: Violation(State, Event),

        pub fn deinit(self: @This(), allocator: std.mem.Allocator) void {
            switch (self) {
                .holds => {},
                .violated => |violation| allocator.free(violation.trace),
            }
        }
    };
}

pub const Holds = struct {
    states_explored: usize,
};

/// Details for the first invariant violation found by the checker.
pub fn Violation(comptime State: type, comptime Event: type) type {
    comptime {
        validateState(State);
        validateEvent(Event);
    }

    return struct {
        invariant_name: []const u8,
        states_explored: usize,
        trace: []TraceStep(State, Event),
    };
}

/// One step in the counterexample trace from the initial state.
pub fn TraceStep(comptime State: type, comptime Event: type) type {
    comptime {
        validateState(State);
        validateEvent(Event);
    }

    return struct {
        event: ?Event,
        action_name: ?[]const u8,
        state: State,
    };
}

fn Node(comptime State: type, comptime Event: type) type {
    comptime {
        validateState(State);
        validateEvent(Event);
    }

    return struct {
        state: State,
        parent: ?usize,
        event: ?Event,
        action_name: ?[]const u8,
    };
}

/// Explore every reachable state until all invariants hold or one fails.
pub fn check(
    comptime State: type,
    comptime Event: type,
    allocator: std.mem.Allocator,
    spec: Spec(State, Event),
) !CheckResult(State, Event) {
    const NodeT = Node(State, Event);

    var nodes: std.ArrayList(NodeT) = .empty;
    defer nodes.deinit(allocator);

    try nodes.append(allocator, .{
        .state = spec.init,
        .parent = null,
        .event = null,
        .action_name = null,
    });

    var head: usize = 0;
    while (head < nodes.items.len) : (head += 1) {
        const node = nodes.items[head];

        for (spec.invariants) |invariant| {
            if (!invariant.holds(node.state)) {
                const trace = try buildTrace(State, Event, allocator, nodes.items, head);
                return .{ .violated = .{
                    .invariant_name = invariant.name,
                    .states_explored = nodes.items.len,
                    .trace = trace,
                } };
            }
        }

        for (spec.next) |action| {
            const next = action.next(node.state) orelse continue;
            // Correctness comes before speed here: exact equality avoids
            // silently merging two different states that share a hash/key.
            if (hasSeenState(State, Event, nodes.items, next, spec.state_eql)) {
                continue;
            }

            try nodes.append(allocator, .{
                .state = next,
                .parent = head,
                .event = action.event,
                .action_name = action.name,
            });
        }
    }

    return .{ .holds = .{
        .states_explored = nodes.items.len,
    } };
}

fn hasSeenState(
    comptime State: type,
    comptime Event: type,
    nodes: []const Node(State, Event),
    state: State,
    eql: *const fn (a: State, b: State) bool,
) bool {
    for (nodes) |node| {
        if (eql(node.state, state)) return true;
    }
    return false;
}

fn buildTrace(
    comptime State: type,
    comptime Event: type,
    allocator: std.mem.Allocator,
    nodes: []const Node(State, Event),
    failed_index: usize,
) ![]TraceStep(State, Event) {
    const TraceStepT = TraceStep(State, Event);
    var reversed: std.ArrayList(TraceStepT) = .empty;
    defer reversed.deinit(allocator);

    var cursor: ?usize = failed_index;
    while (cursor) |index| {
        const node = nodes[index];
        try reversed.append(allocator, .{
            .event = node.event,
            .action_name = node.action_name,
            .state = node.state,
        });
        cursor = node.parent;
    }

    const trace = try allocator.alloc(TraceStepT, reversed.items.len);
    for (reversed.items, 0..) |step, index| {
        trace[reversed.items.len - index - 1] = step;
    }
    return trace;
}

fn validateState(comptime State: type) void {
    switch (@typeInfo(State)) {
        .@"struct", .@"union", .@"enum", .int, .bool => {},
        else => @compileError("Oxpecker State must be a finite value type, but found " ++ @typeName(State)),
    }
}

fn validateEvent(comptime Event: type) void {
    switch (@typeInfo(Event)) {
        .@"enum" => {},
        else => @compileError("Oxpecker Event must be an enum type, but found " ++ @typeName(Event)),
    }
}
