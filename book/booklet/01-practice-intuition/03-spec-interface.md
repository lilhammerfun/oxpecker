# 规格接口

上一章的检查器已经能完成一个最小闭环：写状态、写状态转移、写安全性质，然后搜索所有可达状态。问题是，上一章的代码仍然太专用：检查器、任务取消模型和输出 demo 混在一起，很难看出哪些是库能力，哪些只是一个例子。

本章把这三层拆开：

```text
src/oxpecker.zig                  # Oxpecker 库接口和检查器
examples/agent_task_spec.zig      # 规格：状态、不变量、状态等价
examples/agent_task_candidate.zig # 候选业务逻辑：被检查对象
examples/agent_task_check.zig     # 把候选业务逻辑接到 Oxpecker 检查器
book/booklet/01-practice-intuition/code/... # 章节里的历史教学代码
```

这里的重点不是再写一个任务取消模型，而是看清楚：如果我们要用 Zig 开发一个 FV 库，库应该提供什么接口；真实一点的示例又应该怎样把“要求”和“被检查对象”分开。

## 参考结构

Oxpecker 不要求读者先学习某个新规格语言，而是把 formal verification 里常见的规格结构落到 Zig 代码里。TLA+ 会作为参考系出现，但不是本章的前置工具。

| 规格语义 | TLA+ 写法 | Oxpecker 写法 | 含义 |
|---|---|---|---|
| 状态变量 | `VARIABLES` | `State` | 模型保留哪些状态信息 |
| 初始状态 | `Init` | `Spec.init` | 模型从哪里开始 |
| 动作 | `StartToolCall` / `Cancel` / `ToolResult` | `Action` | 一步状态转移 |
| 下一步关系 | `Next == StartToolCall \/ Cancel \/ ToolResult` | `Spec.next` | 每一步允许选择哪些动作 |
| 不变量 | `INVARIANT NoCompleteAfterCancel` | `Invariant` / `Spec.invariants` | 每个可达状态都必须满足的性质 |
| 状态等价 | TLC 内部处理状态判重 | `Spec.state_eql` | 判断两个状态是否是同一个状态 |

所以本章的 `init`、`next`、`Invariant` 不是随意发明的新术语，而是把成熟 FV 工具里常见的“初始状态、下一步关系、必须保持的性质”落成 Zig 接口。当前实现只覆盖有限状态、显式搜索和安全性质。

## 库接口

库入口在：

```text
src/oxpecker.zig
```

一个可检查规格写成 `Spec`：

```zig
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
```

这里要停一下解释 Zig 的 `comptime`。`Spec` 不是接收一个状态值，而是接收两个类型：

```zig
comptime State: type
comptime Event: type
```

这表示：调用方在写 `oxpecker.Spec(MyState, MyEvent)` 时，`MyState` 和 `MyEvent` 会作为编译期参数传给库。库还没有运行检查器，就已经知道“用户准备用什么类型表示状态，用什么类型表示事件”。

既然类型在编译期已经可见，库就可以提前检查它们是否适合这个接口：

```zig
comptime {
    validateState(State);
    validateEvent(Event);
}
```

`validateState` 和 `validateEvent` 就是这层类型边界。当前代码直接用 `@typeInfo` 检查类型：

```zig
fn validateState(comptime State: type) void {
    switch (@typeInfo(State)) {
        .@"struct", .@"union", .@"enum", .int, .bool => {},
        else => @compileError("Oxpecker State must be a copyable model state type, but found " ++ @typeName(State)),
    }
}

fn validateEvent(comptime Event: type) void {
    switch (@typeInfo(Event)) {
        .@"enum" => {},
        else => @compileError("Oxpecker Event must be an enum type, but found " ++ @typeName(Event)),
    }
}
```

`@typeInfo(State)` 会在编译期拿到 `State` 的类型信息。现在 Oxpecker 允许 `State` 是 `struct`、`union`、`enum`、整数或布尔值，因为这些类型可以作为模型状态值保存下来，再交给 `state_eql` 判断是否相等。

这里有一个很重要的边界：当前 `validateState` 只检查顶层类型，并不会递归检查 `struct` 或 `union` 的每个字段。换句话说，库要求调用方把 `State` 设计成非 owning、可复制、可比较的模型状态值。检查器会把 `State` 复制到内部队列和反例轨迹里，`CheckResult.deinit` 只释放检查器分配的 trace 数组，不会深度释放 `State` 里的字段。

所以，教学阶段最推荐的 `State` 是由 `enum`、`bool`、小整数和这些字段组成的简单 `struct`。如果把指针、slice 或拥有外部资源的对象放进 `State`，Zig 类型系统不一定会在这里阻止你，但模型边界会变得不清楚，反例轨迹也不再只是一个独立的状态快照。

`Event` 目前只允许 enum。原因是检查器需要把每一步动作标记成一个明确事件，并在反例轨迹里输出。enum 的取值集合天然是有限的，也适合表达 `start_tool_call`、`cancel`、`tool_result` 这种动作标签。

如果类型不符合要求，`@compileError` 会让 Zig 编译直接失败，并给出我们写的错误信息。这样调用方传错类型时，错误会在规格接口入口暴露，而不是等到检查器内部某个函数指针或数组类型报出很难读的编译错误。

`Spec` 的四个字段分别对应：

```text
init        初始状态
next        下一步关系，也就是所有允许动作
invariants  不变量列表
state_eql   状态等价判断
```

这里的 `state_eql` 是 Oxpecker 自己需要的实现入口。显式状态搜索必须判断“这个状态以前有没有见过”。不能只依赖一个数字 key，因为不同状态一旦碰撞，检查器就可能把两个状态误认为同一个状态，进而漏掉反例。

## 动作

动作是一步状态转移：

```zig
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
```

`name` 用于反例轨迹，`event` 是这个动作对应的事件标签，`next` 是真正的状态转移函数。`next` 返回 `?State`：返回 `null` 表示这个动作在当前状态下不能发生，返回 `State` 表示发生后进入的新状态。

## 不变量

不变量是每个可达状态都必须满足的性质：

```zig
pub fn Invariant(comptime State: type) type {
    comptime validateState(State);

    return struct {
        name: []const u8,
        holds: *const fn (state: State) bool,
    };
}
```

这对应 TLA+ 的 `INVARIANT`。`name` 用于错误报告，`holds` 判断某个状态是否满足这条性质。

`holds` 不是状态转移函数。它不产生下一状态，也不决定某个事件能不能发生。检查器每探索到一个状态，就把这个状态交给所有 `holds` 函数，问的是：

```text
这个状态本身是不是合法？
```

例如 agent task 里的取消性质是：

```zig
pub fn noCompleteAfterCancel(state: State) bool {
    return !(state.ever_cancelled and state.status == .completed);
}
```

它只看当前状态里的两个字段。如果 `ever_cancelled=true` 且 `status=completed`，这个状态就违反性质。它不关心这个状态是从 `start_tool_call -> cancel -> tool_result` 走来的，还是从别的路径走来的；路径会由检查器的反例轨迹负责还原。

另一个常见例子是状态取值范围。假设任务状态用整数表示，`0`、`1`、`2` 是合法状态，其他值都不合法：

```zig
pub fn statusInRange(state: State) bool {
    return state.status <= 2;
}
```

这个 `holds` 检查的是“当前状态是否还在模型允许的取值范围内”。它不表达业务流程，只表达状态边界。

再比如一个队列长度上限可以写成：

```zig
pub fn queueWithinLimit(state: State) bool {
    return state.queue_len <= state.queue_limit;
}
```

它表达的是“队列不能超过上限”。注意这里仍然只判断一个状态：如果某个可达状态满足 `queue_len > queue_limit`，性质就失败。至于系统怎样走到这个状态，是 `check` 在发现失败后通过 trace 告诉我们的。

## 检查器

检查器的入口是：

```zig
pub fn check(
    comptime State: type,
    comptime Event: type,
    allocator: std.mem.Allocator,
    spec: Spec(State, Event),
) !CheckResult(State, Event)
```

它不关心业务名，只处理一个 `Spec`：从 `init` 出发，枚举 `next` 里的动作，每到一个状态就检查 `invariants`，用 `state_eql` 去重。

更准确地说，检查器做的是显式状态搜索：它不是只检查一条路径，而是把模型允许走到的状态逐步收集起来，再逐个检查和展开。

这个过程可以压缩成一句话：

```text
检查当前状态
-> 用所有动作生成后继状态
-> 把没见过的后继状态放回 nodes
-> 继续检查 nodes 里的下一个状态
```

所以 `nodes` 不是一个普通结果列表。它同时是“已经发现的状态集合”和“等待继续展开的队列”：

```zig
var nodes: std.ArrayList(NodeT) = .empty;
```

`nodes` 里每一项不是只有状态，还保存它是怎么来的：

```zig
state        当前状态
parent       这个状态从哪个旧状态走来
event        走到这里用的是哪个事件
action_name  走到这里用的是哪个动作
```

第一步，检查器把初始状态放进 `nodes`：

```zig
try nodes.append(allocator, .{
    .state = spec.init,
    .parent = null,
    .event = null,
    .action_name = null,
});
```

初始状态没有父节点，也不是由某个事件走来的，所以 `parent`、`event`、`action_name` 都是 `null`。

然后检查器用 `head` 逐个处理 `nodes` 里的状态：

```zig
var head: usize = 0;
while (head < nodes.items.len) : (head += 1) {
    const node = nodes.items[head];
    ...
}
```

这里有一个关键点：`nodes.items.len` 不是固定的。循环开始时，`nodes` 里可能只有初始状态；但是处理某个状态时，检查器可能发现新的后继状态，并把它们 append 到 `nodes` 后面。于是 `nodes` 会一边被遍历，一边增长。

可以把它想成这样：

```text
nodes = [初始状态]
head  = 0

处理 nodes[0]
  发现新状态 S1、S2
  nodes = [初始状态, S1, S2]

head 变成 1
处理 nodes[1]，也就是 S1
  继续发现更多新状态

head 变成 2
处理 nodes[2]，也就是 S2
...
```

这就是“探索所有可达状态”的本质。一个状态只要能从初始状态通过若干动作走到，就会在某一步被追加进 `nodes`；只要它被追加进 `nodes`，后面的循环就会轮到它，检查它是否违反不变量，并继续展开它的后继状态。

处理每个 `node` 时，检查器先检查当前状态是否违反不变量：

```zig
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
```

这里为什么先检查、再展开动作？因为不变量判断的是“当前状态本身是否合法”。如果当前状态已经是坏状态，就已经找到反例了，没有必要继续从坏状态往后走。此时检查器直接用 `buildTrace` 把从初始状态到这个坏状态的路径还原出来。

如果当前状态没有违反不变量，检查器才尝试所有动作，生成下一批可能状态：

```zig
for (spec.next) |action| {
    const next = action.next(node.state) orelse continue;
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
```

`action.next(node.state)` 回答的是：这个动作能不能从当前状态发生？如果返回 `null`，说明这个动作在当前状态下不合法，检查器跳过它。如果返回一个新状态，检查器就拿到了一个后继状态。

这里先保证语义正确：只有 `state_eql` 判断为相等的两个状态，才会被视为同一个状态。后续如果需要性能优化，可以再引入 hash，但 hash 只能作为加速索引，不能替代等价判断。

如果这个后继状态以前没见过，检查器会把它加入 `nodes`：

```zig
try nodes.append(allocator, .{
    .state = next,
    .parent = head,
    .event = action.event,
    .action_name = action.name,
});
```

这一步不是马上检查 `next`。它只是把 `next` 放进队列。等 `head` 走到这个新节点时，循环会用同样的流程检查它的不变量，再展开它的动作。于是检查和展开形成一个重复过程：

```text
当前状态合法吗？
合法 -> 生成后继状态 -> 加入 nodes
不合法 -> 停止，返回反例 trace
```

这里的 `parent = head` 很关键。它不是为了继续搜索，而是为了失败时还原反例。比如检查器最后发现某个状态违反了 `NoCompleteAfterCancel`，这个坏状态本身只告诉我们“任务曾经取消过，但当前却完成了”。但读者真正需要知道的是：系统是怎么走到这里的？`parent`、`event`、`action_name` 把每个状态和上一步连接起来，`buildTrace` 就能从坏状态一路倒回初始状态。

失败时返回 `Violation`：

```zig
pub fn Violation(comptime State: type, comptime Event: type) type {
    return struct {
        invariant_name: []const u8,
        states_explored: usize,
        trace: []TraceStep(State, Event),
    };
}
```

它告诉我们三件事：哪条不变量失败、搜索了多少状态、反例轨迹是什么。

## 示例结构

现在看一个更接近真实工作流的示例。它拆成三个文件：

```text
examples/agent_task_spec.zig       # 规格：状态、不变量、状态等价
examples/agent_task_candidate.zig  # 候选业务逻辑：被检查对象
examples/agent_task_check.zig      # 把候选业务逻辑接到 Oxpecker 检查器
```

这样拆分后，关系更清楚：

```text
规格       说明系统应该满足什么
候选实现   说明我们准备检查的设计方案是什么
检查器     系统性探索候选实现，看它是否违反规格
```

这比在同一个文件里手动切换“修复前 / 修复后”参数更接近真实使用方式。真实工作里，我们通常不是为了演示而构造一个开关；更常见的是：有一个候选设计或一段候选实现，看起来合理，但我们想知道它是否真的满足规格。

## 示例规格

`examples/agent_task_spec.zig` 只表达要求。这里先不要急着看源码，而要先问：如果我们要为一个真实业务切面写规格，应该依次决定什么？

一个最小规格通常需要五件事：

```text
1. 业务切面：我们要检查真实系统里的哪一小块行为？
2. 状态：为了判断这个目标，模型必须记住哪些信息？
3. 初始状态：系统从哪里开始？
4. 事件集合：系统可能被哪些外部动作推进？
5. 性质和等价：怎样判断状态是否合法，怎样判断两个状态相同？
```

注意这里还没有写 `Action`。`Action` 是“一步怎么走”的规则；在这个章节里，我们故意让动作来自候选业务逻辑，再通过适配层接到检查器。也就是说，`agent_task_spec.zig` 先写“要求”，`agent_task_candidate.zig` 写“候选实现怎么走”，`agent_task_check.zig` 再把两者组装成完整的 `Spec`。

第一步不是直接写不变量，而是先定业务切面。这里我们选的是 agent 运行时里很小但真实的一块行为：任务发出工具调用后，用户可能取消任务；工具结果可能稍后才回来。

选业务切面回答的是“我们把真实系统的哪一部分拿出来建模”。这一步还不是 checker 能执行的性质，它只是把 review 问题收窄到一个足够小、足够真实的范围。这个切面里最值得检查的要求是：

```text
一个任务一旦进入过取消语义，后续就不能再变成 completed。
```

第二步是定状态。状态不是把真实系统所有字段搬进模型，而是只保留判断这个要求所必需的信息：

```zig
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
```

`status` 是任务当前状态，`tool_inflight` 表示是否还有工具调用结果没回来，`ever_cancelled` 记录这个任务是否曾经取消过。最后一个字段是为了表达历史事实：如果任务已经从 `cancelled` 被错误改成 `completed`，只看当前 `status` 就看不出它曾经取消过。

第三步是定初始状态。这个状态回答的是：检查器从哪个点开始展开所有可能路径？

```zig
pub fn initial() State {
    return .{
        .status = .created,
        .tool_inflight = false,
        .ever_cancelled = false,
    };
}
```

这不是随便填默认值。它表达了模型边界：任务刚创建时还没有开始运行，没有发出的工具调用，也没有发生过取消。

第四步是定事件集合。事件不是状态转移本身，只是“有哪些外部动作可能发生”的名字：

```zig
pub const Event = enum {
    start_tool_call,
    cancel,
    tool_result,
};
```

`start_tool_call` 表示任务开始并发出工具调用，`cancel` 表示用户取消任务，`tool_result` 表示稍后返回的工具结果。这里定义事件，是为了让检查器能枚举路径，并在反例里告诉读者是哪一步把系统推向坏状态。

第五步才是定性质，也就是把第一步里的检查要求写成 TLA+ 里的 `INVARIANT`。在 Oxpecker 里，不变量写成一个普通函数：

```zig
pub fn noCompleteAfterCancel(state: State) bool {
    return !(state.ever_cancelled and state.status == .completed);
}
```

这句话可以读成：不存在一个状态同时满足“任务曾经取消过”和“任务当前已经完成”。也就是说，第一步得到的是一句工程要求，第五步把这句要求变成 checker 可以对每个可达状态反复调用的布尔函数。

最后还要提供状态等价判断：

```zig
pub fn stateEql(a: State, b: State) bool {
    return a.status == b.status and
        a.tool_inflight == b.tool_inflight and
        a.ever_cancelled == b.ever_cancelled;
}
```

显式状态搜索必须知道“这个状态以前有没有见过”。对这个例子来说，两个状态只有在 `status`、`tool_inflight` 和 `ever_cancelled` 都相同时，才算同一个状态。

所以，写这个规格文件时，我们真正完成的是：

```text
业务切面       工具调用、取消、工具结果晚到
检查要求       取消后不能完成
状态           status / tool_inflight / ever_cancelled
初始状态       created，没有进行中的工具调用，也没有取消过
事件集合       start_tool_call / cancel / tool_result
不变量         noCompleteAfterCancel
状态等价       stateEql
```

到这里为止，我们还没有写任何“业务代码怎么运行”的规则，也没有写 `Action.next`。这是刻意的边界：规格先把“什么状态不允许出现”讲清楚；候选实现和适配层再负责提供“系统可能怎样一步步走到某个状态”。

## 候选实现

`examples/agent_task_candidate.zig` 是被检查对象。它写的是一段更像业务实现的候选逻辑：

```zig
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
};
```

这段代码不是 `fn (State) ?State` 这种规格动作函数，而是一个会修改自身字段的业务对象。`startToolCall` 表示任务开始执行，并发出一个还没返回的工具调用。

取消逻辑也像业务代码：

```zig
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
```

真正的问题出现在工具结果回调：

```zig
pub fn handleToolResult(self: *Task) bool {
    if (!self.tool_inflight) return false;
    if (self.status != .running and self.status != .cancelled) return false;
    self.status = .completed;
    self.tool_inflight = false;
    return true;
}
```

这段代码接受任何还在路上的工具结果。它检查了 `tool_inflight`，也检查了当前状态是不是 `running` 或 `cancelled`，看起来不是完全没有防守。但它允许 `cancelled` 状态继续接收工具结果，并把任务改成 `completed`。这就是 agent runtime 里常见的晚到 callback 问题。

## 组装检查

`examples/agent_task_check.zig` 的作用，是把前三件东西接成一次真正的检查：

```text
Oxpecker 库     提供 check、Spec、Action、Invariant
规格文件        提供 State、Event、不变量、状态等价
候选业务逻辑    提供真实的状态修改方法
检查入口        把业务方法适配成 Action.next，然后调用 oxpecker.check
```

这个文件最重要的地方不是“又写了一个模型”，而是它没有重新实现业务规则。真正会改变任务状态的规则来自 `candidate.Task`，也就是候选业务逻辑。检查入口只是把这段业务逻辑翻译成 Oxpecker 检查器认识的接口。

先看导入关系：

```zig
const oxpecker = @import("oxpecker");
const candidate = @import("agent_task_candidate.zig");
const task_spec = @import("agent_task_spec.zig");

pub const State = task_spec.State;
pub const Event = task_spec.Event;
pub const Action = oxpecker.Action(State, Event);
pub const Invariant = oxpecker.Invariant(State);
pub const Spec = oxpecker.Spec(State, Event);
pub const CheckResult = oxpecker.CheckResult(State, Event);
```

这几行已经把边界分清楚了：`oxpecker` 是库，`task_spec` 是规格，`candidate` 是被检查的业务逻辑。`State` 和 `Event` 不从候选实现里来，而从规格里来；候选实现只负责回答“如果发生某个事件，业务对象会怎样修改自己”。

这里需要一层适配层。原因是业务代码通常不会天然长成 `fn (State) ?State` 的规格接口；它可能是一个 struct 加几个会修改内部字段的方法。适配层做的事情是：把模型状态转换成业务对象，调用业务方法，再把业务对象转换回模型状态。

```zig
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

fn toolResult(state: State) ?State {
    var task = fromState(state);
    if (!task.handleToolResult()) return null;
    return toState(task);
}
```

这里的 `toolResult` 就是一条适配后的状态转移。它不是手写一套“工具结果应该怎样处理”的规格规则，而是直接调用真实候选实现里的 `task.handleToolResult()`。如果业务方法返回 `false`，说明这个事件在当前状态下不允许发生，适配层返回 `null`；如果业务方法返回 `true`，说明事件发生了，适配层把修改后的业务对象重新转回 `State`。

另外两个动作也是同样的结构：

```text
startToolCall  -> Task.startToolCall()
cancel         -> Task.cancel()
toolResult     -> Task.handleToolResult()
```

到这里，候选业务逻辑已经变成了三条 Oxpecker 能枚举的状态转移。检查器之后探索的不是我们另写的一套抽象规则，而是这些业务方法在所有可达状态下的效果。

然后再把适配后的动作交给 Oxpecker：

```zig
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
```

这个 `Spec` 是组装点。每个字段的来源都不一样：

```text
init                 来自规格：检查从哪个状态开始
state_eql            来自规格：怎样判断两个状态相同
invariants           来自规格：哪些性质必须一直成立
next                 来自适配层：有哪些事件可以推进系统
适配层调用的方法      来自候选业务逻辑：每一步真正怎样修改状态
```

最后，检查入口把这个 `Spec` 交给 Oxpecker 库：

```zig
pub fn check(allocator: std.mem.Allocator) !CheckResult {
    return oxpecker.check(State, Event, allocator, spec());
}
```

这句话才是“用 Oxpecker 库 + 规格检查真实候选逻辑”的入口。`oxpecker.check` 会从 `spec().init` 开始，枚举 `spec().next` 里的动作；每个动作都会调用候选业务逻辑；每产生一个新状态，就用 `spec().invariants` 检查它是否合法，并用 `spec().state_eql` 判断是否已经见过。

检查器会找到反例：

```text
start_tool_call -> cancel -> tool_result
```

执行这三步后，状态变成：

```text
status = completed
tool_inflight = false
ever_cancelled = true
```

于是 `NoCompleteAfterCancel` 失败。这个结果的含义不是“我们成功演示了一个手写错误开关”，而是：

```text
候选业务逻辑允许一条可达路径，
这条路径会走到规格禁止的状态。
```

这才是更接近真实 FV 的使用方式。规格不等于候选实现；规格是要求，候选业务逻辑是被检查对象，检查器负责找两者是否冲突。

运行：

```sh
zig build test
```

这个命令会同时测试 `src/oxpecker.zig` 和 `examples/agent_task_check.zig`。这就是示例放在根目录的价值：它不是只服务文档的代码片段，而是持续验证检查器的真实用例。

## 本章小结

本章完成了三个边界拆分：

```text
库接口：src/oxpecker.zig
规格：examples/agent_task_spec.zig
候选业务逻辑：examples/agent_task_candidate.zig
检查入口：examples/agent_task_check.zig
章节说明：book/booklet/01-practice-intuition/03-spec-interface.md
```

库只负责表达规格和检查规格；`examples/` 负责保存可运行的规格、候选业务逻辑和检查入口；booklet 负责解释为什么这样组织。后续继续开发 Oxpecker 时，新能力应该优先进入 `src/`，新的教学/回归用例可以进入 `examples/`，章节再选择合适的示例来讲解。

## 本章测试

<QuickTest
  :questions="[
    {
      id: 'layers',
      type: 'single',
      prompt: '本章为什么把 agent task 示例拆成规格、候选实现和检查入口三个文件？',
      options: [
        {
          id: 'a',
          text: '因为规格、被检查对象和检查入口是三件不同的事。',
          correct: true,
          explanation: '这样能更接近真实 FV 工作流：规格表达要求，候选实现表达业务逻辑，检查入口负责调用检查器。',
        },
        {
          id: 'b',
          text: '因为 Zig 不允许一个文件里有多个函数。',
          explanation: 'Zig 当然允许；这里拆文件是为了表达职责边界。',
        },
        {
          id: 'c',
          text: '因为检查器只能检查文件名叫 check 的代码。',
          explanation: '检查器不关心文件名；这是项目结构和教学结构选择。',
        },
      ],
    },
    {
      id: 'invariant',
      type: 'single',
      prompt: 'NoCompleteAfterCancel 这条不变量表达了什么？',
      options: [
        {
          id: 'a',
          text: '任务取消之后不能再变成 completed。',
          correct: true,
          explanation: '它禁止 ever_cancelled=true 且 status=completed 的可达状态。',
        },
        {
          id: 'b',
          text: '工具调用最终一定会返回。',
          explanation: '这是活性问题，不是本章的不变量。',
        },
        {
          id: 'c',
          text: '取消操作一定会成功。',
          explanation: '这不是本章检查的性质；本章只检查取消后的完成状态是否可达。',
        },
      ],
    },
  ]"
/>
