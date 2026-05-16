# 为什么需要形式化验证

上一节把本书的学习方式定为从真实系统问题进入模型、性质和工具反馈。本章解释第一件事：为什么系统工程师需要 formal verification。我们会从一个 cancellation 场景进入，建立 **workflow**、**state space**、**safety property**、**model checking** 和 **counterexample trace** 之间的关系。

## Workflow

Workflow 是人按照业务意图写下的一条或几条期望执行路径。它通常描述系统应该怎样走完一个任务，例如 “task start -> tool call -> tool result -> completed”，或者 “payment created -> paid -> order fulfilled”。

Workflow 对工程讨论很有用，因为它让需求变得可读。但 workflow 有一个限制：它经常默认事件按照某个正常顺序发生。真实系统不会只执行正常顺序。用户可以取消任务，网络可以重试，timeout 可以和 callback 并发到达，worker 可以在不同时间看到 queue 和 inflight 标志。

以 agent task 为例，一个自然 workflow 是：

```text
created -> running -> completed
```

如果加入取消，很多设计文档会补一条：

```text
running -> cancelled
```

这两条路径看起来已经覆盖了需求，但它们没有回答一个关键问题：如果 cancel 和 tool result 几乎同时到达，系统是否可能先进入 cancelled，又被后到的 tool result 推进到 completed？

## State Space

State space 是一个模型从初始状态出发，按照允许的 transition 能到达的所有状态集合。它关心的不是一条期望路径，而是系统规则允许的全部路径。

把 task 模型写得小一点，我们可以先只看三个字段：

```text
status: created | running | completed | cancelled
tool_inflight: true | false
cancel_requested: true | false
```

如果 `start`、`tool_done`、`cancel` 都是可能发生的 transition，那么模型需要回答的不是 “happy path 是什么”，而是 “这些 transition 任意交错后，哪些 state reachable”。这就是 workflow thinking 和 transition-system thinking 的分界。

:::thinking 为什么先讲 state space？
如果读者只看 workflow，就会把验证理解成 “检查这条路径对不对”。Formal verification 的第一步不是检查一条路径，而是定义哪些状态存在、哪些迁移允许发生、从初始状态能走到哪里。没有 state space，后面的 invariant、trace 和 state explosion 都没有对象。
:::

## Safety Property

Safety property 是一种描述 “坏事永远不应该发生” 的性质。它不要求系统最终一定完成某件事，只要求所有 reachable state 都避开某类错误状态。

对 cancellation 场景，一个 safety property 可以写成：

```text
status == cancelled => status != completed
```

这个写法本身有点多余，因为 `status` 是单值 enum；更有工程意义的版本通常会把历史事实纳入状态：

```text
ever_cancelled == true => status != completed
```

它表达的是：只要任务曾经进入取消语义，后续就不能再被完成事件改写成 completed。普通单元测试可以手写一条 cancel-before-result 的路径来检查它；model checking 则会枚举模型允许的所有路径，只要有一条路径违反它，就返回反例。

## Model Checking

Model checking 是自动探索模型状态空间，并检查指定性质是否在所有 reachable state 上成立的方法。对入门学习来说，最适合作为第一步的是 explicit-state model checking：checker 直接枚举具体状态，而不是先进入符号求解或定理证明。

一个最小 explicit-state checker 的结构很朴素：

```text
queue = [initial_state]
visited = {}

while queue is not empty:
    state = pop(queue)
    if state in visited:
        continue
    add state to visited
    check invariant(state)
    for next in transitions(state):
        push(queue, next)
```

这段伪代码已经包含 explicit-state model checking 的最小闭环：initial state、transition、visited set、invariant checking 和 state exploration。它不需要一开始有 DSL，也不需要一开始支持完整 TLA+。它需要先把 “系统允许发生什么” 和 “永远不该发生什么” 分开。

:::expand TLA+ 的历史位置
TLA+ 是 Leslie Lamport 设计的 specification language，核心思想来自 Temporal Logic of Actions。它适合描述并发和分布式系统的行为，并通过 TLC 这类工具检查有限模型。本书不会一开始要求读者掌握完整 TLA+，但会借用它对 state、action、invariant 和 temporal property 的建模直觉。
:::

## Counterexample Trace

Counterexample trace 是一条从 initial state 走到错误状态的 transition 序列。它的价值不是告诉你 “有 bug”，而是告诉你系统如何一步步走到 bug。

对 cancellation 模型，一个反例 trace 可能长这样：

```text
0. initial: status=created, tool_inflight=false, ever_cancelled=false
1. start:   status=running, tool_inflight=true,  ever_cancelled=false
2. cancel:  status=cancelled, tool_inflight=true, ever_cancelled=true
3. done:    status=completed, tool_inflight=false, ever_cancelled=true

Invariant failed:
ever_cancelled == true => status != completed
```

这条 trace 比 “测试失败” 更有解释力。它暴露的不是某个函数返回值不对，而是 transition 设计允许 `done` 在取消后继续改写终态。修复也应该回到 transition 规则：`done` 只有在当前状态仍然接受 tool result 时才能进入 completed。

## Formal Verification

Formal verification 是用精确定义的模型、性质和推理或检查过程，证明或反驳系统是否满足某些正确性要求的技术集合。它不是单一工具，也不是某一种语言；TLA+、Alloy、SMT、Kani、Lean 和 explicit-state checker 都覆盖其中不同区域。

对系统工程师来说，formal verification 的入口不一定是证明数学定理，而可以是把系统工程问题变成可检查模型。我们先学习 safety property 和 explicit-state model checking，是因为它们最接近工程师已经熟悉的状态机、队列、重试、取消和并发事件。

| 概念 | 本章含义 |
|---|---|
| Workflow | 人期待系统执行的路径 |
| State space | 模型规则允许到达的全部状态 |
| Safety property | 坏事永远不应该发生 |
| Model checking | 自动探索状态空间并检查性质 |
| Counterexample trace | 从初始状态到错误状态的可复现路径 |
| Formal verification | 用精确定义的模型和性质检查系统正确性 |

Formal verification 的第一步不是选择工具，而是把 “这个流程应该怎样走” 改写成 “这个系统允许哪些状态和迁移，以及哪些状态绝不能 reachable”。

## Test

<QuickTest
  :questions="[
    {
      id: 'state-space',
      type: 'single',
      prompt: '在本章语境中，state space 最准确的含义是什么？',
      options: [
        {
          id: 'a',
          text: '模型中状态变量所有可能取值组合构成的空间，其中 reachable state 是从 initial state 按 transition 实际可达的部分。',
          correct: true,
          explanation: '这个选项同时区分了 state space 和 reachable state：前者是模型状态空间，后者是从初始状态沿迁移能到达的子集。',
        },
        {
          id: 'b',
          text: '系统从开始到结束的一条具体执行路径。',
          explanation: '这混淆了 state space 和 execution trace。Trace 是路径；state space 是状态集合或状态图。',
        },
        {
          id: 'c',
          text: '开发者希望系统遵守的一条正常业务流程。',
          explanation: '这混淆了 state space 和 workflow。Workflow 常描述期望路径，state space 描述模型允许的状态范围。',
        },
        {
          id: 'd',
          text: '所有测试用例实际执行过的输入和输出集合。',
          explanation: '这混淆了 state space 和测试覆盖结果。测试观察到的是被选中的执行，state space 是模型层面的可能状态。',
        },
      ],
    },
    {
      id: 'safety-property',
      type: 'single',
      prompt: '下面哪一个最准确地区分了 safety property 和 liveness property？',
      options: [
        {
          id: 'a',
          text: 'Safety 关心坏状态不可达；liveness 关心某个期望状态或事件最终会发生。',
          correct: true,
          explanation: '这是本章需要建立的基础区分：safety 是坏事不发生，liveness 是好事最终发生。',
        },
        {
          id: 'b',
          text: 'Safety 只关心性能上限；liveness 只关心内存安全。',
          explanation: '这是把性质类型和工程指标混在一起。Safety/liveness 是关于行为性质的分类，不是性能/内存领域划分。',
        },
        {
          id: 'c',
          text: 'Safety 必须通过测试验证；liveness 必须通过人工代码审查验证。',
          explanation: '这是把性质和验证手段混淆。Safety/liveness 描述性质类型，不规定只能用哪种验证手段。',
        },
        {
          id: 'd',
          text: 'Safety 是系统最终状态；liveness 是系统初始状态。',
          explanation: '这是把时序性质误解成状态位置。二者都可以谈执行过程，只是关注的问题不同。',
        },
      ],
    },
    {
      id: 'model-checking',
      type: 'multiple',
      prompt: '关于 model checking，下列哪些说法正确？',
      options: [
        {
          id: 'a',
          text: '它检查的是模型是否满足性质，而不是自动等同于真实实现完全正确。',
          correct: true,
          explanation: 'Model checking 的对象是模型。模型和真实实现之间仍然需要建模假设和工程映射。',
        },
        {
          id: 'b',
          text: '它通常系统性探索模型允许的状态或路径，而不是只运行人工挑选的一条路径。',
          correct: true,
          explanation: '这是 model checking 和普通路径测试的重要区别。',
        },
        {
          id: 'c',
          text: '当性质失败时，它常给出 counterexample trace 来展示失败如何发生。',
          correct: true,
          explanation: 'Counterexample trace 是 model checking 的重要反馈形式，可以把性质失败具体化。',
        },
        {
          id: 'd',
          text: '它的主要含义是对生产代码运行大量随机输入。',
          explanation: '这是把 model checking 误解成随机测试。Model checking 的核心是对模型状态空间进行系统性检查。',
        },
      ],
    },
    {
      id: 'counterexample-trace',
      type: 'single',
      prompt: 'counterexample trace 在 model checking 中最准确的作用是什么？',
      options: [
        {
          id: 'a',
          text: '它是一条从 initial state 到违反性质状态的路径，用来解释性质为什么失败。',
          correct: true,
          explanation: 'Counterexample trace 把抽象的性质失败还原成具体的状态迁移序列。',
        },
        {
          id: 'b',
          text: '它证明除了这条路径以外，其他所有路径都正确。',
          explanation: '反例 trace 出现在性质失败时，它不是正确性证明。',
        },
        {
          id: 'c',
          text: '它是测试覆盖率报告，用来统计哪些函数被执行过。',
          explanation: '这混淆了 counterexample trace 和测试覆盖率。Trace 解释的是模型中的错误路径。',
        },
        {
          id: 'd',
          text: '它是模型的完整状态空间，列出了所有 reachable state。',
          explanation: '这混淆了 trace 和 state space。Trace 是一条路径；state space 是状态集合或状态图。',
        },
      ],
    },
  ]"
/>
