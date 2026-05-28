# 初识 Formal Verification

过去我们常问的是：人写的代码怎么验证。现在这个问题正在变得更尖锐：如果一个 coding agent 可以在很短时间里改写大量代码，我们怎么判断它真的改对了？

这不是一个假想问题。2026 年 5 月，The Register 报道 Bun 的 Rust 重写合入主仓库：一次超过百万行代码的变更，依赖既有测试套件来判断兼容性和回归风险。[^bun-rust-2026] 这类事件会让一个老问题重新浮到台前：测试通过、编译通过、review 也看过，是否就足以说明一个大规模 agent 生成或改写的系统行为仍然正确？

研究界也已经在围绕这个问题推进。Clover 把大模型生成代码的问题改写成“代码、自然语言说明和形式化标注是否一致”的闭环检查；AlphaVerus 尝试让模型生成带规格和证明的 Rust/Verus 程序；IDS 则直接把 agent、实现和证明合成放进同一个循环，用分布式键值存储这类需要全覆盖保证的系统做实验。[^clover-2024][^alphaverus-2025][^ids-2026] 这些工作还远没有把“AI 写代码”变成自动可信，但它们说明 formal verification 正在被认真地放进 AI 辅助开发的验证链路里。

所以这一章不从术语表开始，而是从一个更小、更可检查的 coding agent 场景进入：agent 修改了任务运行器的取消逻辑。它跑过了测试，也修掉了明显报错；但我们还想知道，当前规则是否仍然允许“任务已经取消，却又被后到的结果改成完成”。为了回答这个问题，我们需要依次理解 **期望流程**、**状态空间**、**安全性质**、**模型检查** 和 **反例轨迹** 之间的关系。

## 从期望流程到状态空间

期望流程是人按照业务意图写下的一条或几条执行路径。它通常描述系统应该怎样走完一个任务，例如：

```text
task start -> tool call -> tool result -> completed
```

期望流程对工程讨论很有用，因为它让需求变得可读。但它有一个限制：它经常默认事件按照某个正常顺序发生。真实系统不会只执行正常顺序。用户可以取消任务，网络可以重试，超时可以和回调并发到达，worker 可以在不同时间看到队列和进行中的任务标志。

以 agent task 为例，一个自然的期望流程是：

```text
created -> running -> completed
```

如果加入取消，很多设计文档会补一条：

```text
running -> cancelled
```

这两条路径看起来已经覆盖了需求，但它们没有回答一个关键问题：如果 cancel 和 tool result 几乎同时到达，系统是否可能先进入 `cancelled`，又被后到的 tool result 推进到 `completed`？

这就是“按流程想问题”和“按状态迁移想问题”的分界。前者关心我们期待系统怎样走；后者关心系统规则实际上允许它怎样走。

状态空间是一个模型从初始状态出发，按照允许的状态迁移能到达的所有状态集合。它关心的不是一条期望路径，而是系统规则允许的全部路径。

把 task 模型写得小一点，我们可以先只看三个字段：

```text
status: created | running | completed | cancelled
tool_inflight: true | false
ever_cancelled: true | false
```

如果 `start`、`tool_done`、`cancel` 都是可能发生的状态迁移，那么模型需要回答的不是“正常路径是什么”，而是“这些事件任意交错后，哪些状态可以到达”。

:::thinking 为什么先讲状态空间？
如果读者只看期望流程，就会把验证理解成“检查这条路径对不对”。Formal verification 的第一步不是检查一条路径，而是定义哪些状态存在、哪些迁移允许发生、从初始状态能走到哪里。没有状态空间，后面的不变量、反例轨迹和状态爆炸都没有对象。
:::

## 从安全性质到反例轨迹

安全性质是一种描述“坏事永远不应该发生”的性质。它不要求系统最终一定完成某件事，只要求所有可到达状态都避开某类错误状态。

对 cancellation 场景，一个有工程意义的安全性质可以写成：

```text
ever_cancelled == true => status != completed
```

它表达的是：只要任务曾经进入取消语义，后续就不能再被完成事件改写成 `completed`。普通单元测试可以手写一条“先取消、后返回结果”的路径来检查它；模型检查则会枚举模型允许的所有路径，只要有一条路径违反它，就返回反例。

模型检查是自动探索模型状态空间，并检查指定性质是否在所有可到达状态上成立的方法。对入门学习来说，最适合作为第一步的是显式状态模型检查：检查器直接枚举具体状态，而不是先进入符号求解或定理证明。

一个最小的显式状态检查器结构很朴素：

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

这段伪代码已经包含显式状态模型检查的最小闭环：初始状态、状态迁移、已访问集合、不变量检查和状态探索。它不需要一开始有专门语言，也不需要一开始支持完整 TLA+。它需要先把“系统允许发生什么”和“永远不该发生什么”分开。

反例轨迹是一条从初始状态走到错误状态的状态迁移序列。它的价值不是告诉你“有 bug”，而是告诉你系统如何一步步走到 bug。

对 cancellation 模型，一个反例轨迹可能长这样：

```text
0. initial: status=created, tool_inflight=false, ever_cancelled=false
1. start:   status=running, tool_inflight=true,  ever_cancelled=false
2. cancel:  status=cancelled, tool_inflight=true, ever_cancelled=true
3. done:    status=completed, tool_inflight=false, ever_cancelled=true

Invariant failed:
ever_cancelled == true => status != completed
```

这条轨迹比“测试失败”更有解释力。它暴露的不是某个函数返回值不对，而是状态迁移设计允许 `done` 在取消后继续改写终态。修复也应该回到状态迁移规则：`done` 只有在当前状态仍然接受 tool result 时才能进入 `completed`。

Formal verification 的第一步不是选择工具，而是把“这个流程应该怎样走”改写成“这个系统允许哪些状态和迁移，以及哪些状态绝不能到达”。

这一章对应的第一个可运行练习已经放在 Zig 项目里。运行：

```sh
zig build run
```

会先检查一个有问题的 cancellation 模型，得到一条反例轨迹：

```text
created -> running -> cancelled -> completed
```

然后再检查修正后的模型，确认同一个安全性质成立。这个练习的目的不是实现一个成熟工具，而是让读者第一次完整经历：写状态、写迁移、写性质、搜索可达状态、看到反例、修正规则、再次检查通过。

## 历史背景和知识地图

上面的 cancellation 场景说明 formal verification 关心的不是一条 happy path，而是模型允许的全部状态和迁移。这个例子背后有一个更大的问题：测试可以运行一些具体场景，代码审查可以发现一些局部问题，但它们都很难回答“所有可能行为是否都满足要求”。

Formal verification 的历史可以先从这个压力理解：工程师不断遇到更复杂的系统行为，于是需要更精确的规格、更系统的搜索方式、更强的约束求解能力，以及在必要时由机器检查的数学证明。

所以这一章后半部分不从工具清单开始，而是沿着一条问题链走：

```text
如何证明一段程序满足前后条件
-> 如何描述持续运行系统随时间变化的性质
-> 如何自动检查所有相关状态
-> 状态太多时如何继续自动检查
-> 如何把系统行为写成可检查的规格
-> 如何处理无法靠有限搜索解决的证明问题
```

这条链会经过 **程序正确性**、**时序逻辑**、**模型检查**、**符号方法**、**规格语言** 和 **定理证明** 六个观察点。这里先提醒一个容易误解的地方：它们不是六个平级分类，也不是六个互相替代的工具。它们之间有一条问题推动关系：程序正确性把测试样例推进到逻辑断言；但前置/后置条件不足以描述持续运行系统，于是需要时序逻辑；有了时序性质以后，需要自动检查相关行为，于是进入模型检查；模型检查遇到状态爆炸以后，检查目标没有消失，但状态表示和搜索方式要变成符号化；这些检查都要求系统行为和性质先被精确定义，于是规格语言成为表达层；当问题超出有限搜索和自动求解时，定理证明提供机器可检查的证明路径。

从层次上看，这六个观察点也混合了三类东西。

第一层是问题类型或研究方向。**程序正确性**关心程序是否满足前置条件和后置条件；**时序逻辑**关心如何描述系统随时间展开的性质；**定理证明**关心如何构造机器可检查的证明。

第二层是自动化检查方法。**模型检查**通过枚举或探索模型状态空间来寻找反例或确认性质成立；**符号方法**用公式、约束或压缩表示来处理大量状态和变量组合。

第三层是表达系统行为的媒介。**规格语言**负责把系统行为、结构和性质写清楚，例如 TLA+ 更适合描述行为和并发，Alloy 更适合描述关系结构和约束。

所以后面的六节不是在列 formal verification 的完整目录，而是在回答同一个主问题：当测试和代码审查不足以说明“所有相关行为都正确”时，我们还能怎样获得更强的正确性证据？完整历史会牵涉数理逻辑、自动定理证明、编程语言语义、硬件验证、抽象解释、类型理论和安全协议分析。这里的目标更窄：先建立一个初始认知框架，知道这些概念为什么会出现，它们彼此怎样连接，以及它们分别适合回答哪类工程问题。

## 程序正确性

最先出现的问题很朴素：一段程序运行前有某些条件，运行后应该满足某些结果。测试只能挑一些输入跑一遍，但程序员真正想知道的是：只要开始条件成立，这段程序结束后是否一定满足要求？

程序正确性就是围绕这个问题建立的精确判断。它的核心不是“程序看起来能跑”，而是“给定前置条件、程序语句和后置条件，能否用形式规则说明执行后的状态满足要求”。

这条线的经典起点通常会提到 Floyd 和 Hoare。Floyd 在 1967 年的 “Assigning Meanings to Programs” 中用断言和流程图边上的条件来讨论程序含义；Hoare 在 1969 年的 “An Axiomatic Basis for Computer Programming” 中提出了后来被称为 Hoare logic 的公理化程序推理方式。[^floyd-1967][^hoare-1969]

如果把它放到工程直觉里，Hoare triple 可以粗略读成：

```text
{precondition} program {postcondition}
```

它说的是：如果程序开始前满足 `precondition`，并且程序正常结束，那么结束后应满足 `postcondition`。这个形式把“测试某个输入输出”提升成了“证明一类状态变化”。读者暂时不需要掌握完整推导规则，只要先抓住一个分界：程序正确性这条线主要研究程序文本和逻辑断言之间的关系。

但很多工程系统不是运行一段代码、算出一个结果、然后结束。服务器会持续响应请求，worker 会反复取任务，协议会在多个节点之间交换消息。对这类系统来说，只描述“开始前”和“结束后”还不够，因为真正重要的错误常常发生在运行过程中的某个时刻。这就把问题推向了时序逻辑。

:::thinking 为什么不从定理证明开始？
从历史上看，程序正确性和定理证明关系很近，但作为入门路线，直接进入证明系统容易让读者先背规则、后理解问题。这里先把它定位为“用逻辑断言描述程序状态变化”，后面再区分自动检查、交互式证明和模型枚举。
:::

## 时序逻辑

时序逻辑要解决的是“运行过程中一直发生什么”的问题。它让规格不只描述当前状态是否满足某个断言，还能描述“总是如此”“最终发生”“直到某事发生前保持”等关于执行序列的性质。

Pnueli 1977 年的 “The Temporal Logic of Programs” 是 formal verification 历史中的关键论文之一，因为它把 temporal logic 引入程序验证语境，用来推理 reactive 和并发程序的行为。[^pnueli-1977] 对系统工程师来说，这一步很重要：很多系统不是算完一个结果就结束，而是持续响应事件。event loop、worker pool、分布式协议、agent runtime 都属于这种持续演化的系统。

前面讲的安全性质可以用一句话近似理解为“坏事永远不发生”。与之相对，活性性质关心“好事最终会发生”。这个区分会贯穿后续章节：检查 `cancelled` 后不能 `completed` 是安全性质；检查一个排队任务最终会被处理则开始接近活性性质。

有了这类性质以后，下一步问题自然出现：如果性质已经写清楚了，能不能让工具自动检查系统的所有相关行为？模型检查就是对这个问题的回答。

## 模型检查

模型检查是自动检查有限或可有限抽象的系统模型是否满足形式规格的方法。它把系统看成状态图，把性质看成逻辑公式或状态条件，然后系统性探索所有相关行为。

这里说的“自动检查”，通常由一个模型检查器完成。它不是泛指任意程序，也不是线上系统本身，而是一类专门读取“模型”和“性质”的检查程序。模型告诉它：系统有哪些状态、哪些事件会触发状态变化、哪些迁移是允许的。性质告诉它：哪些状态或路径是我们要求必须满足的。模型检查器拿到这两类输入后，从初始状态开始搜索模型允许的路径，最后给出两类结果：性质成立，或者找到一条违反性质的路径。

“形式规格”和“性质”在这里不是两个完全分开的东西。形式规格是更大的表达：它把系统应当满足的要求写成精确、可检查的形式。性质是其中一条具体要求，例如“任务一旦 `cancelled`，就不能再 `completed`”。一个规格里可以有多条性质：取消后不能完成、任务不能从 `created` 直接跳到 `completed`、进入 `running` 后最终要么完成要么取消。入门阶段先抓住这个关系就够了：规格是一组可检查要求的表达，性质是其中某一条要被检查的要求。

还是用任务取消来观察这个定义。产品需求里写“用户取消任务后，任务不应该再显示为完成”，这还不是模型检查。它只是一个期望，里面没有说任务有哪些状态、哪些事件会改变状态、哪些事件可能并发到达，也没有形成模型检查器可以读取并搜索的模型。

如果线上日志里出现了一条记录：任务先收到 cancel 请求，随后又被 complete 回调改成 completed，这也还不是模型检查。日志能证明真实系统里发生过一次坏路径，但它只给出已经发生的一次执行。模型检查关心的是：即使这条日志还没有在线上出现，只要当前规则允许它发生，模型检查器就应该把这条路径找出来。

再进一步，如果我们写一个测试，先启动任务，再调用 cancel，再模拟 complete 回调，最后断言状态不能是 completed，这仍然主要是测试。它检查的是我们手动安排的一条路径。这个测试当然有价值，但它没有回答另一个问题：除了这条路径以外，是否还有别的事件顺序也会把任务带到错误状态？

进入模型检查时，我们要把任务系统压缩成一个小模型。例如，任务状态只保留 `created`、`running`、`cancelled`、`completed`；事件只保留 `start`、`cancel`、`complete`；规则写成“在哪个状态下，哪个事件可以把任务带到哪个状态”。这一步不是把真实系统完整交给模型检查器，而是为模型检查器准备一个有限的状态空间。真实系统里的线程 ID、日志格式、数据库字段、网络延迟先不放进来，因为这些细节会扩大状态空间，却不一定影响“取消后还能不能完成”这个问题。

如果用 TLA+ 写成一个很小的规格，它可以长这样。现在不需要掌握语法，只要先看出它把哪些东西写清楚了。代码里的 `\*` 是注释；`/\` 表示“并且”，`\/` 表示“或者”，这些斜杠组合是 TLA+ 的真实语法，不是转义字符：

```text
---- MODULE TaskCancel ----
EXTENDS TLC

VARIABLES status, wasCancelled
\* status 记录当前任务状态
\* wasCancelled 记录任务是否曾经进入过取消语义

Init ==
  /\ status = "created"       \* 初始时任务刚创建
  /\ wasCancelled = FALSE     \* 初始时任务还没有被取消过

Start ==
  /\ status = "created"       \* 只有 created 状态可以开始运行
  /\ status' = "running"      \* 下一步状态变成 running
  /\ wasCancelled' = wasCancelled
                              \* start 不改变“是否取消过”

Cancel ==
  /\ status \in {"created", "running"}
                              \* created 或 running 都允许取消
  /\ status' = "cancelled"    \* 下一步状态变成 cancelled
  /\ wasCancelled' = TRUE     \* 记录“已经取消过”

Complete ==
  /\ status = "running"       \* 正常完成只能从 running 发生
  /\ status' = "completed"    \* 下一步状态变成 completed
  /\ wasCancelled' = wasCancelled
                              \* complete 不改变“是否取消过”

BuggyComplete ==
  /\ status = "cancelled"     \* 故意允许一个有问题的迁移
  /\ status' = "completed"    \* cancelled 之后又变成 completed
  /\ wasCancelled' = wasCancelled

Next ==
  Start \/ Cancel \/ Complete \/ BuggyComplete
\* 每一步都可以选择上述四种迁移之一

Spec ==
  Init /\ [][Next]_<<status, wasCancelled>>
\* 从 Init 开始，并且之后每一步都遵守 Next

NoCompleteAfterCancel ==
  [](wasCancelled => status # "completed")
\* 始终要求：一旦取消过，状态就不能是 completed
====
```

这段规格分成两层。`Init`、`Start`、`Cancel`、`Complete`、`BuggyComplete` 和 `Next` 描述模型：初始状态是什么，哪些事件会改变状态，哪些迁移被模型允许。`NoCompleteAfterCancel` 是要检查的性质：只要任务曾经进入过取消语义，之后状态就不应该是 `completed`。这里故意把 `BuggyComplete` 写进模型，是为了让模型检查器有机会发现“取消后仍然完成”的错误路径。现在不需要掌握 TLA+ 语法，只需要看到：形式规格不是一句更正式的自然语言，而是一份把状态、迁移和性质都写出来的可检查描述。

这时，“任务一旦 `cancelled`，就不能再 `completed`”才从产品期望变成形式规格里的一条性质。模型检查器要做的不是相信某个测试场景，也不是复述某条线上日志，而是从模型的初始状态出发，覆盖模型允许的相关状态和路径。入门阶段可以先把它理解成：检查器不断问“从当前状态还能走到哪里？”

比如从 `created` 出发，如果模型允许 `start` 和 `cancel`，检查器会继续看这些分支：

```text
created -> running
created -> cancelled
```

到了 `running`，如果模型允许 `complete` 和 `cancel`，它又会继续展开：

```text
created -> running -> completed
created -> running -> cancelled
```

前一条路径没有违反“cancelled 后不能 completed”，因为任务没有进入过 `cancelled`。后一条路径也暂时没有违反，因为它停在 `cancelled`。真正的问题出现在：如果模型还允许 `cancelled` 接收 `complete` 事件，那么检查器可以继续走出：

```text
created -> running -> cancelled -> completed
```

这条路径一旦存在，性质就不成立。这里的关键边界是：`completed` 不只是日志里出现过的一个结果，而是模型规则允许到达的可达状态；整条路径也不只是一次事故复盘，而是一个反例轨迹，说明当前模型本身允许违反规格的行为。

模型检查在 1980 年代初形成了独立研究方向。Clarke 和 Emerson 的 branching-time temporal logic 工作，以及 Queille 和 Sifakis 在法国的独立工作，被 ACM Turing Award 介绍为 model checking 领域的奠基性工作；Clarke、Emerson、Sifakis 也因此获得 2007 年图灵奖。[^clarke-emerson-1981][^acm-model-checking]

模型检查对工程师的吸引力在于它给出的是可操作反馈。性质成立时，工具报告模型满足规格；性质不成立时，工具通常给出一条反例执行，帮助定位错误路径。刚才这条 cancellation 轨迹就是这种反馈的教学版：`created`、`running`、`cancelled`、`completed` 是状态；箭头是状态迁移；能从初始状态走到的状态是可达状态；“cancelled 后不能 completed” 是不变量；整条错误路径就是反例轨迹。

模型检查把“所有相关行为”变成了可以自动探索的对象。但这个方向很快会遇到新的限制：只要变量多一点、并发进程多一点、消息交错多一点，状态数量就会急剧增加。于是问题从“如何枚举状态”推进到“状态太多时如何表示和处理”。

## 符号方法

符号方法是用公式、约束或压缩表示来处理大量状态的方法。它出现的压力很直接：显式枚举状态很容易遇到 state explosion。

仍然看任务状态。如果只有一个任务，它可能处在四种状态之一：

```text
created
running
cancelled
completed
```

显式状态探索可以把这四个状态一个个列出来。但如果系统里同时有 3 个任务，每个任务都有 4 种状态，组合状态就变成了：

```text
4 * 4 * 4 = 64
```

如果有 10 个任务，就是：

```text
4^10 = 1,048,576
```

这还没有把队列、重试次数、网络消息和 worker 调度算进去。状态数量不是按代码行数增长，而是随着变量组合快速膨胀。

符号方法的直觉是：不要总是把每个组合状态逐个列出来，而是用一个公式描述一整类状态。比如每个任务只保留两个布尔信息：`cancelled_i` 表示第 `i` 个任务是否曾经取消过，`completed_i` 表示它现在是否完成。对于 3 个任务，显式枚举要列出很多组合：

```text
task1.cancelled task1.completed task2.cancelled task2.completed task3.cancelled task3.completed
false           false           false           false           false           false
true            false           false           false           false           false
false           true            false           false           false           false
...
```

但我们真正关心的坏状态不是这些表格里的某一行，而是“至少有一个任务取消后又完成”。这可以直接写成公式：

```text
(cancelled_1 and completed_1)
or (cancelled_2 and completed_2)
or (cancelled_3 and completed_3)
```

如果任务数量变成 10 个，显式状态组合会变成百万级，但坏状态仍然可以按同一个模式写出来：

```text
exists i:
  cancelled_i and completed_i
```

这就是符号表示带来的变化。它不是列出所有状态，而是用公式描述一整组状态。状态集合、坏状态集合、迁移关系都可以被写成公式或压缩结构；检查器后续处理的是这些表示，而不是一个个具体状态。

这也回答了“状态爆炸以后怎么继续模型检查”的问题：符号方法不是让显式模型检查原样继续，而是改变模型检查的形态。**符号模型检查**仍然保留“自动寻找反例或确认性质成立”的目标，但它推进的是符号状态集合。例如从初始状态公式出发，检查器计算“一步以后可能到达的状态集合”“两步以后可能到达的状态集合”，每一步都用公式或压缩结构表示一批状态。Burch、Clarke、McMillan、Dill、Hwang 的 “Symbolic Model Checking: 10^20 States and Beyond” 展示了用符号表示处理巨大状态空间的方向，是 symbolic model checking 的经典节点。[^symbolic-1992]

另一条相关方向是 **约束求解 / 可满足性检查**。这时问题会被改写成“是否存在一个赋值或一条路径，让坏状态公式成立”。如果 solver 找到满足条件的赋值，它就给出一个反例；如果 solver 能说明不存在这样的赋值，就说明在当前约束范围内找不到坏状态。比如上面的坏状态公式如果可满足，就意味着至少存在一个任务同时满足 `cancelled_i` 和 `completed_i`；如果不可满足，就说明当前模型和约束排除了这种状态。

SMT 是这一类知识地图中的重要节点。SMT 关注在某些背景理论下公式是否可满足，SMT-LIB 则提供了标准化语言和基准生态来推动 SMT 求解器研究。[^smtlib] 对入门读者来说，可以先把 SMT 理解成“把问题写成逻辑约束，让 solver 找到满足约束的赋值，或者证明不存在这样的赋值”。

这条线和模型检查的关系不是替代，而是改变表示方式以后继续自动检查。显式状态探索适合建立状态机直觉；符号方法解释为什么真实系统很快需要更压缩的状态表示、更强的求解器和更谨慎的抽象。

不过，无论是显式搜索还是符号求解，都需要一个前提：系统行为和期望性质必须先被写清楚。自然语言需求经常有歧义，代码实现又混入了太多细节。为了让“要检查什么”本身变得精确，规格语言成为另一条核心线索。

## 规格语言

规格语言是用来精确定义系统应当如何行为的语言。它的价值不在于让文字变得更学术，而在于让状态、操作、约束和性质可以被工具检查或被人严格审阅。

TLA 是 Leslie Lamport 提出的 Temporal Logic of Actions。它把 action 作为状态迁移关系放进 temporal logic 中，适合描述并发和 reactive systems。Lamport 的 “The Temporal Logic of Actions” 是理解 TLA/TLA+ 的经典入口。[^lamport-tla]

Alloy 则代表另一种规格语言直觉。Daniel Jackson 的 Alloy 论文把它描述为一种 lightweight object modelling notation，强调用关系和约束描述结构，并通过自动分析寻找实例或反例。[^alloy-2002] 这提醒我们：formal verification 不是只有“状态机和时序逻辑”一条路。不同规格语言把不同问题变得自然：TLA+ 更适合行为和并发，Alloy 更适合关系结构和约束。

规格语言把问题写清楚以后，有些性质可以交给模型检查器或 solver 自动找反例。但也有一些问题不能只靠有限状态搜索解决，例如涉及无限结构、复杂程序语义或抽象数学命题的正确性。这个时候，问题会继续推进到定理证明。

## 定理证明

定理证明是通过逻辑推导建立命题为真的方法。和模型检查相比，它通常不依赖有限状态空间枚举，而是把正确性变成需要证明的数学命题。

Proof assistant 是支持人和机器共同构造、检查证明的工具。Lean 官方将 Lean 4 描述为 programming language 和 interactive theorem prover；Coq/Rocq、Isabelle/HOL 等系统也属于这一类工具生态。[^lean-official] 入门阶段不需要马上进入 dependent type theory，但需要知道这条线解决的问题和模型检查不同：它更适合处理无限结构、抽象数学命题、程序语义证明和机器检查证明。

这一节不会完整解释证明是怎样被生成的。真正进入 proof assistant 时，还要学习命题如何表示、定义如何展开、归纳假设从哪里来、tactic 如何推进证明、以及机器最后检查的证明对象是什么。这里先只建立一个更小的直觉：当我们想证明“某个规则对所有输入都成立”时，工具不会满足于几个样例，而会要求每一步推理都能被展开和检查。

把这个问题放回今天的工程环境里，可以从 coding agent 看得更具体。现在很多代码不是完全由人手写，而是由 agent 根据 issue、上下文和测试反馈生成 patch。我们通常用两种方式判断 patch 是否正确：一是运行测试，看已知用例是否通过；二是人工 code review，看实现是否符合设计意图、是否有明显边界错误。这两种方式都重要，但它们仍然主要回答“我们想到的检查有没有通过”和“reviewer 有没有发现问题”。

Formal verification 提供的是第三类证据，但它不是替代测试和 review 的通用流程。它要求我们先把“写得对”拆成更精确的问题：这个 patch 应该保持什么性质？哪些状态是允许的？哪些迁移是合法的？如果性质失败，工具能不能给出反例；如果性质成立，证明能不能被机器检查？

一个更接近定理证明的 coding agent 场景，不是小状态机，而是程序变换。可以先从 Python 里常见的算术表达式想起：`x + 0` 的结果和 `x` 一样，`1 * y` 的结果和 `y` 一样，`(2 + 3) * y` 可以先算成 `5 * y`。如果项目里有一段代码专门处理这类表达式，coding agent 可能会被要求加一组“自动简化”规则：在不改变计算结果的前提下，把表达式改写得更简单。

:::expand 背景：表达式解释器、表达式树和 pass
表达式解释器可以先理解成一个“会计算表达式的小程序”。给它一个表达式，例如 `x + 0`，再给它一张变量表，例如 `x = 10`，它就能算出结果 `10`。这里可以把核心函数叫作 `eval`：`eval(expr, env)` 表示“在变量环境 `env` 下计算表达式 `expr` 的值”。

表达式树是表达式在程序里的结构化表示。`1 * (b + 0)` 不是一整段字符串，而可以被表示成一棵树：最外层是乘法，左边是常量 `1`，右边是加法；这个加法的左边是变量 `b`，右边是常量 `0`。用树表示以后，程序才能递归地处理子表达式。

Pass 是编译器和解释器里常见的说法，意思是“对程序表示做一轮处理”。优化 pass 就是在真正计算或生成代码之前，先走一遍表达式树，把能简化的地方改写掉。它不是直接算出最终结果，而是把 `1 * (b + 0)` 这样的表达式改写成更简单但语义相同的表达式。
:::

agent 可能会生成类似这样的规则：

```text
x + 0        -> x
0 + x        -> x
x * 1        -> x
1 * x        -> x
(2 + 3) * y  -> 5 * y
```

测试可以挑一些表达式运行，例如 `a + 0`、`1 * (b + 0)`、`(2 + 3) * y`。reviewer 也可以看出这些规则“直觉上”合理。但这个 patch 真正要保持的性质不是“这几个例子输出一样”，而是：

```text
对任意表达式 expr 和任意变量环境 env，
eval(optimize(expr), env) = eval(expr, env)
```

这时问题就不像前面的 task lifecycle 那样自然落在有限模型检查上。表达式可以任意深，变量环境可以有任意取值，优化函数还会递归处理子表达式。我们当然可以继续增加测试：更深的表达式、更多变量、更多常量组合。但测试仍然只能覆盖被挑出来的有限样本。review 也很难靠肉眼保证所有递归分支都保持语义。

Proof assistant 要检查的就是这类命题。可以先看一条最简单的规则：

```text
x + 0 -> x
```

证明时不能只说“显然一样”。机器会要求我们把左右两边都展开成 `eval` 的含义。左边优化前是：

```text
eval(x + 0, env)
= eval(x, env) + eval(0, env)
= env[x] + 0
```

右边优化后是：

```text
eval(x, env)
= env[x]
```

接下来证明要说明：对任何数字 `n`，`n + 0 = n`。一旦这个算术事实成立，`env[x] + 0 = env[x]` 就成立，所以 `x + 0 -> x` 保持语义。

复杂表达式也是同一个思路，只是证明会递归地拆开表达式结构。比如 `1 * (b + 0)` 先看最外层乘法，再进入右边的 `(b + 0)`。证明右边子表达式优化后语义不变以后，再回到外层说明 `1 * value = value`。所以 proof assistant 做的不是运行几个样例，而是强迫每一种表达式形状、每一条改写规则都交代清楚：改写前后为什么对任意环境都算出同一个值。

如果 coding agent 写错了一条规则，例如把：

```text
x * 0 -> x
```

证明就会卡住。展开左右两边以后，左边是：

```text
eval(x * 0, env)
= env[x] * 0
= 0
```

右边是：

```text
eval(x, env)
= env[x]
```

要让这条规则成立，就必须证明“对任意 `env[x]`，`0 = env[x]`”。这显然不可能；只要 `env[x] = 5`，左右两边就分别是 `0` 和 `5`。这里的失败不是“某个测试没覆盖到”，而是机器检查的证明无法成立；它指出这条程序变换本身不保持语义。

这段推演把前面几个节点串在一起了。coding agent 生成的是程序文本；“优化前后语义相同”是性质；表达式、环境和 `eval` 构成规格；如果只检查有限样本，那还是测试；如果要证明任意表达式和任意环境都成立，就需要把结论写成机器可检查的证明。测试、review 和 FV 因此不是互相替代的关系：测试观察具体执行，review 检查设计和代码意图，FV 则把关键正确性要求变成模型、反例或证明。

这条线也解释了为什么 formal verification 不能被简化成“跑一个 checker”。有些问题适合有限模型搜索，有些问题适合约束求解，有些问题需要人引导证明。学习 FV 的关键不是站队某个工具，而是判断问题落在哪个区域。

现在可以把这章的路线压缩成一张知识地图。注意，表格里的行不是平级分类，而是这条问题链上承担不同角色的观察点。

| 观察点 | 所在层次 | 在问题链里的角色 | 典型证据 |
|---|---|---|---|
| 程序正确性 | 问题类型 / 研究方向 | 把“程序是否正确”变成前置条件、程序语句和后置条件之间的逻辑关系 | Floyd、Hoare |
| 时序逻辑 | 问题类型 / 研究方向 | 表达运行过程中关于“总是”“最终”“直到”的性质 | Pnueli |
| 模型检查 | 自动化检查方法 | 在有限或可有限抽象的模型里系统性寻找反例或确认性质成立 | Clarke、Emerson、Sifakis |
| 符号方法 | 自动化检查方法 | 把逐个枚举状态改成用公式表示状态集合，并通过符号模型检查或可满足性检查继续寻找反例 | Symbolic model checking、SMT-LIB |
| 规格语言 | 表达系统行为的媒介 | 把系统行为、结构和性质写成工具或人可以严格检查的形式 | TLA/TLA+、Alloy |
| 定理证明 | 问题类型 / 研究方向 | 对有限搜索难以覆盖的命题构造机器可检查的证明 | Lean、Coq/Rocq、Isabelle/HOL |

Formal verification 的知识地图不是一张工具清单，而是一组问题分解方式：程序状态如何变化，系统行为如何展开，性质如何表达，状态空间如何处理，规格如何写清楚，证明如何被机器检查。

## 本章测试

<QuickTest
  :questions="[
    {
      id: 'workflow-state-space',
      type: 'single',
      prompt: '这一章为什么要先区分“按流程想问题”和“按状态迁移想问题”？',
      options: [
        {
          id: 'a',
          text: '因为期望流程只描述我们希望系统怎么走，而状态迁移模型要描述系统规则实际允许的状态和迁移。',
          correct: true,
          explanation: '这是本章的入口：形式化验证关心的不只是 happy path，而是系统规则允许到达的状态空间。',
        },
        {
          id: 'b',
          text: '因为期望流程只能用于业务系统，状态迁移模型只能用于数学证明。',
          explanation: '这把概念按领域错误切开了。二者都可以用于工程系统，只是抽象层次不同。',
        },
        {
          id: 'c',
          text: '因为期望流程是代码实现，状态迁移模型是测试用例。',
          explanation: '期望流程不是代码实现，状态迁移模型也不是测试用例；它们分别描述期望路径和允许行为。',
        },
      ],
    },
    {
      id: 'model-checking-trace',
      type: 'single',
      prompt: '反例轨迹在模型检查中最准确的作用是什么？',
      options: [
        {
          id: 'a',
          text: '展示模型怎样从 initial state 走到违反性质的状态。',
          correct: true,
          explanation: '反例轨迹把抽象的性质失败还原成具体状态迁移序列。',
        },
        {
          id: 'b',
          text: '证明除了这条路径以外，其他路径都正确。',
          explanation: '反例轨迹只说明性质失败，不是完整正确性证明。',
        },
        {
          id: 'c',
          text: '统计测试覆盖了哪些代码行。',
          explanation: '这是测试覆盖率，不是模型检查里的反例轨迹。',
        },
      ],
    },
    {
      id: 'concept-map',
      type: 'multiple',
      prompt: '关于本章的知识地图，下列哪些说法正确？',
      options: [
        {
          id: 'a',
          text: '程序正确性、时序逻辑和定理证明更接近问题类型或研究方向。',
          correct: true,
          explanation: '它们回答的是怎样表述和证明不同形态的正确性问题。',
        },
        {
          id: 'b',
          text: '模型检查和符号方法更接近自动化检查方法。',
          correct: true,
          explanation: '模型检查强调系统性探索；符号方法强调用公式或约束表示大量状态。',
        },
        {
          id: 'c',
          text: '规格语言负责把系统行为、结构和性质写成可检查表达。',
          correct: true,
          explanation: 'TLA+、Alloy 这类语言都属于表达系统行为或结构的媒介。',
        },
        {
          id: 'd',
          text: '这六个概念是六个互相替代的工具。',
          explanation: '这是本章要避免的误解。它们处在不同层次，并由问题链连接起来。',
        },
      ],
    },
  ]"
/>

[^floyd-1967]: Robert W. Floyd, “Assigning Meanings to Programs,” *Mathematical Aspects of Computer Science*, 1967. Reprint: https://www.lem12.uksw.edu.pl/images/1/15/AssigningMeanings1967.pdf
[^hoare-1969]: C. A. R. Hoare, “An Axiomatic Basis for Computer Programming,” *Communications of the ACM*, 1969. ACM page: https://cacm.acm.org/research/an-axiomatic-basis-for-computer-programming-2/
[^pnueli-1977]: Amir Pnueli, “The Temporal Logic of Programs,” 1977. PDF copy: https://users.cs.utah.edu/~tch/notes/PSSAT/IR/SAT/pnueli_temporal_1977.pdf
[^clarke-emerson-1981]: E. M. Clarke and E. A. Emerson, “Design and Synthesis of Synchronization Skeletons Using Branching-Time Temporal Logic,” 1981. Bibliographic entry: https://www.bibsonomy.org/bibtex/7b74027639fb3fa06162f1f34f5c832e
[^acm-model-checking]: ACM, “ACM Turing Award Honors Founders of Automatic Verification Technology,” 2008: https://www.acm.org/media-center/2008/february/acm-turing-award-honors-founders-of-automatic-verification-technology
[^symbolic-1992]: J. R. Burch, E. M. Clarke, K. L. McMillan, D. L. Dill, and L. J. Hwang, “Symbolic Model Checking: 10^20 States and Beyond,” *Information and Computation*, 1992. Bibliographic entry: https://mcmil.net/pubs/bibtexbrowser.php?bib=mybib.bib&key=DBLP%3Ajournals-iandc-BurchCMDH92
[^smtlib]: SMT-LIB, “The Satisfiability Modulo Theories Library”: https://smt-lib.org/index.shtml
[^lamport-tla]: Leslie Lamport, “The Temporal Logic of Actions,” *ACM Transactions on Programming Languages and Systems*, 1994. Microsoft Research page: https://www.microsoft.com/en-us/research/publication/the-temporal-logic-of-actions/
[^alloy-2002]: Daniel Jackson, “Alloy: A Lightweight Object Modelling Notation,” *ACM Transactions on Software Engineering and Methodology*, 2002. PDF: https://groups.csail.mit.edu/sdg/pubs/2002/alloy-journal.pdf
[^lean-official]: Lean 4 official website: https://lean4.dev/
[^bun-rust-2026]: Tim Anderson, “Anthropic’s Bun Rust rewrite merged at speed of AI,” *The Register*, 2026-05-14: https://www.theregister.com/devops/2026/05/14/anthropics_bun_rust_rewrite_merged_at_speed_of_ai/
[^clover-2024]: Chuyue Sun, Ying Sheng, Oded Padon, and Clark Barrett, “Clover: Closed-Loop Verifiable Code Generation,” SAIV 2024: https://theory.stanford.edu/~barrett/pubs/SSP%2B24-abstract.html
[^alphaverus-2025]: Pranjal Aggarwal, Bryan Parno, and Sean Welleck, “AlphaVerus: Bootstrapping Formally Verified Code Generation through Self-Improving Translation and Treefinement,” ICML 2025: https://www.andrew.cmu.edu/user/bparno/papers/alpha-verus.pdf
[^ids-2026]: “Inductive Deductive Synthesis: Enabling AI to Generate Formally Verified Systems,” arXiv:2605.23109, 2026: https://arxiv.org/abs/2605.23109
