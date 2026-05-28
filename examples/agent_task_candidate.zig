const task_spec = @import("agent_task_spec.zig");

pub const Status = task_spec.Status;

pub const Task = struct {
    status: Status = .created,
    tool_inflight: bool = false,
    ever_cancelled: bool = false,

    pub fn startToolCall(self: *Task) bool {
        if (self.status != .created) return false;
        self.status = .running;
        self.tool_inflight = true;
        return true;
    }

    pub fn cancel(self: *Task) bool {
        switch (self.status) {
            .created, .running => {
                self.status = .cancelled;
                self.ever_cancelled = true;
                return true;
            },
            .cancelled, .completed => return false,
        }
    }

    /// Candidate business logic under review.
    ///
    /// The tool callback accepts any in-flight result, even when the task has
    /// already been cancelled. This is the kind of late-callback race an agent
    /// runtime can hit in production.
    pub fn handleToolResult(self: *Task) bool {
        if (!self.tool_inflight) return false;
        if (self.status != .running and self.status != .cancelled) return false;
        self.status = .completed;
        self.tool_inflight = false;
        return true;
    }
};
