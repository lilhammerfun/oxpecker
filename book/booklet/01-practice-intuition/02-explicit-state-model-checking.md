# 显式状态模型检查

上一章把 formal verification 的入口压缩成一个问题：如果 coding agent 改了任务取消逻辑，我们怎样判断“取消后不能完成”这条要求真的没有被破坏？

本章目标是用 Zig 建立一个最小的显式状态模型检查闭环。这个检查器不取代成熟工具，只负责展示模型检查的基本结构：把系统抽象成状态，把事件写成迁移，把正确性要求写成性质，然后系统性搜索所有可达状态。如果性质失败，检查器给出一条反例轨迹。

这一章对应的完整代码在：

```text
book/booklet/01-practice-intuition/code/task_cancel_checker.zig
```

运行示例：

```sh
zig build run
```

运行测试：

```sh
zig build test
```

## 任务取消模型

真实的 agent task runtime 可能包含队列、worker、数据库记录、工具调用、取消请求、超时、重试和回调。第一步不是把这些细节全塞进模型，而是问：对于“取消后不能完成”这个性质，最少需要保留哪些信息？

这里我们只保留三个字段：

```zig
pub const State = struct {
    status: Status,
    tool_inflight: bool,
    ever_cancelled: bool,
};
```

`status` 表示任务当前处于 `created`、`running`、`cancelled` 或 `completed`。`tool_inflight` 表示工具调用是否已经发出但结果还没有回来。`ever_cancelled` 记录历史事实：这个任务是否曾经进入过取消语义。

最后这个字段很重要。如果只看当前 `status`，那么 `cancelled` 和 `completed` 是两个不同枚举值，写出 `status == cancelled => status != completed` 没有意义。真正的性质是：一旦任务曾经取消，后续就不能被结果回调改成完成。所以模型必须把“曾经取消过”这个历史事实也放进状态。

## 事件与状态转移

这个模型只保留三个事件：

```zig
pub const Event = enum {
    start,
    cancel,
    tool_done,
};
```

`start` 让任务从 `created` 进入 `running`，并发出工具调用。`cancel` 让 `created` 或 `running` 的任务进入 `cancelled`，同时把 `ever_cancelled` 设为 `true`。`tool_done` 表示工具结果返回。

关键问题就在 `tool_done`。如果实现允许它在 `cancelled` 状态下继续把任务改成 `completed`，那么模型就有机会走出坏路径。

代码里用一个开关保留这个有问题的规则：

```zig
pub const Model = struct {
    allow_done_after_cancel: bool,
};
```

当 `allow_done_after_cancel = true` 时，我们是在检查 buggy 模型；当它为 `false` 时，我们是在检查修正后的模型。同一个检查器跑两遍，读者可以清楚看到：模型规则变了，状态空间和验证结果也会变。

## 安全性质

这一章只检查一个安全性质：

```zig
fn invariant(state: State) bool {
    return !(state.ever_cancelled and state.status == .completed);
}
```

这句话可以直接读成：不存在一个状态，同时满足“曾经取消过”和“当前已经完成”。它不讨论任务最终是否会结束，也不讨论性能或公平性，只禁止一类坏状态出现。

这就是安全性质最适合入门的原因。它把“坏事不要发生”变成了一个可以对每个可达状态逐个检查的判断。

## 可达状态搜索

检查器的主体在 `verify` 函数里。它维护两个集合：

```zig
var nodes: std.ArrayList(Node) = .empty;
var visited = std.AutoHashMap(u8, usize).init(allocator);
```

`nodes` 保存已经发现的状态节点。每个节点还记住父节点和走到这里的事件，这样一旦发现错误，就能倒推出完整反例轨迹。`visited` 用来避免重复探索同一个状态。

核心循环可以分成四步看。

第一步，`head` 指向当前要处理的节点：

```zig
var head: usize = 0;
while (head < nodes.items.len) : (head += 1) {
    const node = nodes.items[head];
    ...
}
```

这里的 `nodes` 不只是一个普通数组，它同时扮演了“已发现状态列表”和“待探索队列”。`head` 之前的节点已经处理过，`head` 以及后面的节点还在等待处理。每处理完一个节点，`head += 1`，检查器就会继续处理下一个已经发现但尚未展开的状态。

第二步，先检查当前状态是否违反安全性质：

```zig
if (!invariant(node.state)) {
    const trace = try buildTrace(allocator, nodes.items, head);
    return .{ .violated = .{
        .states_explored = head + 1,
        .trace = trace,
    } };
}
```

这一步体现了安全性质的检查方式：每到达一个状态，就立刻问“这个状态是不是坏状态”。如果 `ever_cancelled=true` 且 `status=completed`，检查器不需要继续搜索，因为已经找到足以推翻性质的反例。

第三步，如果当前状态没有违反性质，就尝试所有可能的状态转移：

```zig
for (EVENT_ORDER) |event| {
    const next = transition(model, node.state, event) orelse continue;
    ...
}
```

`transition` 就是状态转移规则。它可以读成：

```text
当前状态 + 事件 -> 下一状态
```

不是每个事件在每个状态下都能发生。例如 `start` 只能从 `created` 发生；`cancel` 只能从 `created` 或 `running` 发生；修正后的 `tool_done` 只能从仍然接受工具结果的 `running` 状态发生。如果某个组合没有合法状态转移，`transition` 返回 `null`，检查器就跳过它。

第四步，如果下一状态还没有见过，就把它加入待探索列表，并记录它从哪里来：

```zig
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
```

这一步同时做两件事。`visited` 保证同一个状态只展开一次；否则状态图里一旦有环，检查器就可能反复探索同一个状态。`parent = head` 和 `event = event` 则记录了新状态从哪里来。检查器发现坏状态时，当前节点只知道“我坏了”，但读者真正需要的是“系统怎样一步步走到这里”。父节点和事件把每个状态串回初始状态，`buildTrace` 就能倒推出完整路径。

把这四步合起来，核心循环完整长这样：

```zig
var head: usize = 0;
while (head < nodes.items.len) : (head += 1) {
    const node = nodes.items[head];

    if (!invariant(node.state)) {
        const trace = try buildTrace(allocator, nodes.items, head);
        return .{ .violated = .{
            .states_explored = head + 1,
            .trace = trace,
        } };
    }

    for (EVENT_ORDER) |event| {
        const next = transition(model, node.state, event) orelse continue;
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
```

这就是显式状态模型检查的最小闭环：从初始状态开始，检查当前状态是否违反性质；如果没有违反，就尝试所有事件，生成后继状态；没见过的新状态加入队列，继续探索；如果遇到坏状态，就沿着父节点还原反例轨迹。

注意这里没有随机性，也不是挑几条测试路径。只要状态空间有限，检查器就会按模型规则把所有可达状态系统性走完。

## 反例轨迹

运行 `zig build run`，第一段输出来自 buggy 模型：

```text
buggy cancellation model
invariant violated after exploring 6 states
counterexample trace:
0. initial: status=created, tool_inflight=false, ever_cancelled=false
1. start: status=running, tool_inflight=true, ever_cancelled=false
2. cancel: status=cancelled, tool_inflight=true, ever_cancelled=true
3. tool_done: status=completed, tool_inflight=false, ever_cancelled=true
```

这比“测试失败”多给了一个东西：错误怎样发生。反例轨迹说明模型允许这样的事件顺序：

```text
start -> cancel -> tool_done
```

到最后一步时，`ever_cancelled=true`，但 `status=completed`，所以安全性质失败。这个结果逼我们回到迁移规则本身：`tool_done` 不应该在取消后的状态里继续写入完成状态。

这里要特别注意：`buggy model` 和 `fixed model` 不是两个无关例子，而是同一个系统在“修复前”和“修复后”的两组规则。demo 里真正切换的是这个参数：

```zig
.allow_done_after_cancel = true   // 修复前：允许 cancelled 后继续 completed
.allow_done_after_cancel = false  // 修复后：禁止 cancelled 后继续 completed
```

也就是说，反例不是这一章的终点，而是修复的依据。我们先让检查器验证修复前规则，得到反例；再调整状态转移规则，让检查器验证修复后规则是否排除了同类反例。

第二段输出来自 fixed 模型：

```text
fixed cancellation model
invariant holds after exploring 5 states
```

这句话容易被误读，所以要停下来讲清楚。`invariant holds` 不是在说“真实系统已经完全正确”，也不是在说“这个任务系统没有任何 bug”。它只回答了一个更窄的问题：

```text
在我们写下来的这个模型里，
从初始状态出发，
按照这几个状态转移规则走，
是否可能到达 ever_cancelled=true 且 status=completed 的状态？
```

检查器回答：没有。

这个结论有三个边界。

第一，结论只覆盖模型里写出来的状态字段。这里我们只建模了 `status`、`tool_inflight` 和 `ever_cancelled`。如果真实系统的 bug 来自数据库事务、锁、队列重试、进程崩溃或跨机器消息乱序，而模型里没有这些状态，检查器当然看不见。

第二，结论只覆盖模型里写出来的事件。这里我们只写了 `start`、`cancel` 和 `tool_done`。如果真实系统还有 `timeout`、`retry`、`restore_from_db`、`worker_restart`，但模型里没有这些事件，那么“检查通过”不代表这些事件组合也安全。

第三，结论只覆盖我们写出来的性质。这里检查的性质是“取消后不能完成”。它没有检查“任务最终一定会结束”，也没有检查“工具结果不会丢失”，更没有检查“内存释放一定正确”。如果想回答那些问题，需要再写新的性质，甚至可能需要扩展模型。

所以这段输出真正表达的是：

```text
在当前这个小模型的边界内，
针对“取消后不能完成”这一条安全性质，
修正后的状态转移规则没有可达反例。
```

这已经很有价值，因为它比单条测试路径强：它不是只检查 `start -> cancel -> tool_done` 这一条路径，而是检查这个小模型允许的所有可达路径。但它也有明确边界：模型写得不对、事件漏了、性质没覆盖到，检查通过也不会神奇地证明真实系统完全正确。

## 实现一致性

到这里为止，检查器检查的是模型本身。一个自然问题是：如果真实业务代码没有遵守这套状态转移规则，怎么办？

对应的完整代码在：

```text
book/booklet/01-practice-intuition/code/task_implementation.zig
```

这份代码写了一个很小的 `Task` 业务实现：

```zig
pub const Task = struct {
    status: spec.Status,
    tool_inflight: bool,
    ever_cancelled: bool,

    pub fn apply(self: *Task, mode: ImplMode, event: spec.Event) bool {
        ...
    }
};
```

`Task.apply` 接受一个事件并修改任务状态。检查目标不是“实现有没有所有可能的 bug”，而是一个更具体的问题：

```text
对模型中每一个可达状态，
对每一个可能事件，
业务实现给出的下一状态
是否和模型规格给出的下一状态一致？
```

代码里这两个结果分别叫 `expected` 和 `actual`：

```zig
const expected = spec.nextState(model, state, event);
const actual = applyImplementation(mode, state, event);
if (!sameOptionalState(expected, actual)) {
    return .{
        .state = state,
        .event = event,
        .expected = expected,
        .actual = actual,
    };
}
```

`expected` 来自模型规格，`actual` 来自业务实现。二者不同，就说明实现偏离了模型。

buggy 实现仍然允许 `cancelled + tool_done -> completed`。一致性检查会发现：

```text
在 cancelled 状态下收到 tool_done：
模型期望：没有合法转移
buggy 实现实际：转到 completed
```

fixed 实现把 `tool_done` 限制在 `running` 状态，因此不会再出现这个 mismatch。运行 `zig build test` 时，这两个实现一致性测试会和模型检查测试一起执行。

这个实践环节补上了一个关键边界：模型不是只给自己看的。它也可以成为实现的参照物，用来检查业务代码是否偏离规格。

## 本章小结

本章代码放在 `book/booklet/01-practice-intuition/code/` 下，因为它首先是书里的教学材料，而不是独立工具的最终形态。项目根目录的 `build.zig` 直接指向这些章节代码，让 `zig build run` 和 `zig build test` 可以从项目根目录运行。

本章的核心成果不是“写了一个模型检查器”，而是把 formal verification 的几个基础动作串成了可运行流程：

```text
抽象状态
-> 定义迁移
-> 写出安全性质
-> 搜索可达状态
-> 得到反例轨迹
-> 修改迁移规则
-> 再次检查
-> 对比实现与规格
```

这一步说明，formal verification 不是把普通测试换个名字。测试通常运行人挑出来的路径；模型检查则让模型规则自己展开所有相关路径。

本章边界也很明确：它仍然只覆盖我们写进模型的状态、事件和性质。下一章不会更换工具主线，而是继续把这里已经出现的状态、迁移、性质和反例反馈，整理成更清楚的 Zig 规格接口。

## 本章测试

<QuickTest
  :questions="[
    {
      id: 'history-state',
      type: 'single',
      prompt: '为什么模型里需要 ever_cancelled，而不是只看当前 status？',
      options: [
        {
          id: 'a',
          text: '因为“曾经取消过”是历史事实，只看当前 status 会丢掉这个信息。',
          correct: true,
          explanation: '取消后不能完成说的是一段历史之后的禁止状态，所以模型必须保留 ever_cancelled。',
        },
        {
          id: 'b',
          text: '因为 Zig 的 enum 不能表示 cancelled。',
          explanation: 'Zig enum 可以表示 cancelled。问题不是语言能力，而是模型是否保留了验证性质需要的信息。',
        },
        {
          id: 'c',
          text: '因为 tool_inflight 只能和 ever_cancelled 一起使用。',
          explanation: '这两个字段没有这种语言层面的绑定关系；它们分别表达不同状态信息。',
        },
      ],
    },
    {
      id: 'counterexample',
      type: 'single',
      prompt: 'buggy 模型中的反例轨迹说明了什么？',
      options: [
        {
          id: 'a',
          text: '模型允许 start -> cancel -> tool_done 这条路径到达坏状态。',
          correct: true,
          explanation: '这条路径最终到达 ever_cancelled=true 且 status=completed 的状态，所以违反安全性质。',
        },
        {
          id: 'b',
          text: '真实生产系统已经发生过这个事故。',
          explanation: '模型检查发现的是模型允许这条路径，不等于生产系统日志已经出现过这条路径。',
        },
        {
          id: 'c',
          text: '所有测试都没有价值。',
          explanation: '测试仍然有价值；模型检查补充的是对模型可达状态的系统性探索。',
        },
      ],
    },
    {
      id: 'implementation-consistency',
      type: 'single',
      prompt: '实现一致性检查里的 expected 和 actual 分别代表什么？',
      options: [
        {
          id: 'a',
          text: 'expected 来自模型规格，actual 来自 Task.apply 的实际状态转移。',
          correct: true,
          explanation: '一致性检查比较的是模型规定的下一状态和业务实现实际给出的下一状态。',
        },
        {
          id: 'b',
          text: 'expected 是修复前模型，actual 是修复后模型。',
          explanation: '修复前/后由不同规则或模式区分；expected/actual 区分的是规格和实现。',
        },
        {
          id: 'c',
          text: 'expected 来自用户界面，actual 来自数据库。',
          explanation: '这一章没有检查 UI 或数据库；它只比较状态转移。',
        },
      ],
    },
  ]"
/>
