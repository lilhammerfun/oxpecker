pub const Status = enum {
    created,
    running,
    cancelled,
    completed,
};

pub const Event = enum {
    start_tool_call,
    cancel,
    tool_result,
};

pub const State = struct {
    status: Status,
    tool_inflight: bool,
    ever_cancelled: bool,

    pub fn initial() State {
        return .{
            .status = .created,
            .tool_inflight = false,
            .ever_cancelled = false,
        };
    }
};

/// Required property: a cancelled task must not later become completed.
pub fn noCompleteAfterCancel(state: State) bool {
    return !(state.ever_cancelled and state.status == .completed);
}

pub fn stateEql(a: State, b: State) bool {
    return a.status == b.status and
        a.tool_inflight == b.tool_inflight and
        a.ever_cancelled == b.ever_cancelled;
}
