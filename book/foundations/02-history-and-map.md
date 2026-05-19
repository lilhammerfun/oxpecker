# 历史背景和知识地图

上一章从 cancellation 场景进入，说明 formal verification 关心的不是一条 happy path，而是模型允许的全部状态和迁移。这个例子背后有一个更大的问题：当系统行为不再只是一条顺序执行路径时，我们怎么判断“它真的不会出错”？

测试可以运行一些具体场景，代码审查可以发现一些局部问题，但它们都很难回答“所有可能行为是否都满足要求”。Formal verification 的历史可以先从这个压力理解：工程师不断遇到更复杂的系统行为，于是需要更精确的规格、更系统的搜索方式、更强的约束求解能力，以及在必要时由机器检查的数学证明。

所以本章不从工具清单开始，而是沿着一条问题链走：

```text
如何证明一段程序满足前后条件
-> 如何描述持续运行系统随时间变化的性质
-> 如何自动检查所有相关状态
-> 状态太多时如何压缩或求解
-> 如何把系统行为写成可检查的规格
-> 如何处理无法靠有限搜索解决的证明问题
```

这条链会经过 **程序正确性**、**时序逻辑**、**模型检查**、**符号方法**、**规格语言** 和 **定理证明** 六个节点。它不是完整历史。完整历史会牵涉数理逻辑、自动定理证明、编程语言语义、硬件验证、抽象解释、类型理论和安全协议分析。这里的目标更窄：先建立一个初始认知框架，知道这些概念为什么会出现，它们彼此怎样连接，以及它们分别适合回答哪类工程问题。

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

上一章讲的 safety property 可以用一句话近似理解为“坏事永远不发生”。与之相对，liveness property 关心“好事最终会发生”。这个区分会贯穿后续章节：检查 `cancelled` 后不能 `completed` 是 safety；检查一个排队任务最终会被处理则开始接近 liveness。

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

这段规格分成两层。`Init`、`Start`、`Cancel`、`Complete`、`BuggyComplete` 和 `Next` 描述模型：初始状态是什么，哪些事件会改变状态，哪些迁移被模型允许。`NoCompleteAfterCancel` 是要检查的性质：只要任务曾经进入过取消语义，之后状态就不应该是 `completed`。这里故意把 `BuggyComplete` 写进模型，是为了让模型检查器有机会发现“取消后仍然完成”的错误路径。后面学习 TLA+ 时会解释每个符号；现在只需要看到，形式规格不是一句更正式的自然语言，而是一份把状态、迁移和性质都写出来的可检查描述。

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

这条路径一旦存在，性质就不成立。这里的关键边界是：`completed` 不只是日志里出现过的一个结果，而是模型规则允许到达的 reachable state；整条路径也不只是一次事故复盘，而是一个 counterexample trace，说明当前模型本身允许违反规格的行为。

模型检查在 1980 年代初形成了独立研究方向。Clarke 和 Emerson 的 branching-time temporal logic 工作，以及 Queille 和 Sifakis 在法国的独立工作，被 ACM Turing Award 介绍为 model checking 领域的奠基性工作；Clarke、Emerson、Sifakis 也因此获得 2007 年图灵奖。[^clarke-emerson-1981][^acm-model-checking]

模型检查对工程师的吸引力在于它给出的是可操作反馈。性质成立时，工具报告模型满足规格；性质不成立时，工具通常给出 counterexample execution，帮助定位错误路径。刚才这条 cancellation trace 就是这种反馈的教学版：`created`、`running`、`cancelled`、`completed` 是 state；箭头是 transition；能从 initial state 走到的状态是 reachable state；“cancelled 后不能 completed” 是 invariant；整条错误路径就是 counterexample trace。

模型检查把“所有相关行为”变成了可以自动探索的对象。但这个方向很快会遇到新的限制：只要变量多一点、并发进程多一点、消息交错多一点，状态数量就会急剧增加。于是问题从“如何枚举状态”推进到“状态太多时如何表示和处理”。

## 符号方法

符号方法是用公式、约束或压缩表示来处理大量状态的方法。它出现的压力很直接：显式枚举状态很容易遇到 state explosion。

显式模型检查会把每个 reachable state 当成具体对象处理。这个方法清楚、可解释，但状态数量会随着变量、进程、队列容量和消息交错快速增长。Burch、Clarke、McMillan、Dill、Hwang 的 “Symbolic Model Checking: 10^20 States and Beyond” 展示了用符号表示处理巨大状态空间的方向，是 symbolic model checking 的经典节点。[^symbolic-1992]

SMT 也是这一类知识地图中的重要节点。SMT 关注在某些背景理论下公式是否可满足，SMT-LIB 则提供了标准化语言和基准生态来推动 SMT 求解器研究。[^smtlib] 对入门读者来说，可以先把 SMT 理解成“把问题写成逻辑约束，让 solver 找到满足约束的赋值，或者证明不存在这样的赋值”。

这条线和模型检查的关系不是替代，而是互补。显式状态探索适合建立状态机直觉；符号方法适合解释为什么真实系统很快需要更压缩的表示、更强的求解器和更谨慎的抽象。

不过，无论是显式搜索还是符号求解，都需要一个前提：系统行为和期望性质必须先被写清楚。自然语言需求经常有歧义，代码实现又混入了太多细节。为了让“要检查什么”本身变得精确，规格语言成为另一条核心线索。

## 规格语言

规格语言是用来精确定义系统应当如何行为的语言。它的价值不在于让文字变得更学术，而在于让状态、操作、约束和性质可以被工具检查或被人严格审阅。

TLA 是 Leslie Lamport 提出的 Temporal Logic of Actions。它把 action 作为状态迁移关系放进 temporal logic 中，适合描述并发和 reactive systems。Lamport 的 “The Temporal Logic of Actions” 是理解 TLA/TLA+ 的经典入口。[^lamport-tla]

Alloy 则代表另一种规格语言直觉。Daniel Jackson 的 Alloy 论文把它描述为一种 lightweight object modelling notation，强调用关系和约束描述结构，并通过自动分析寻找实例或反例。[^alloy-2002] 这提醒我们：formal verification 不是只有“状态机和时序逻辑”一条路。不同规格语言把不同问题变得自然：TLA+ 更适合行为和并发，Alloy 更适合关系结构和约束。

规格语言把问题写清楚以后，有些性质可以交给模型检查器或 solver 自动找反例。但也有一些问题不能只靠有限状态搜索解决，例如涉及无限结构、复杂程序语义或抽象数学命题的正确性。这个时候，问题会继续推进到定理证明。

## 定理证明

定理证明是通过逻辑推导建立命题为真的方法。和模型检查相比，它通常不依赖有限状态空间枚举，而是把正确性变成需要证明的数学命题。

Proof assistant 是支持人和机器共同构造、检查证明的工具。Lean 官方将 Lean 4 描述为 programming language 和 interactive theorem prover；Coq/Rocq、Isabelle/HOL 等系统也属于这一类工具生态。[^lean-official] 入门阶段不需要马上进入 dependent type theory，但需要知道这条线解决的问题和模型检查不同：它更适合处理无限结构、抽象数学命题、程序语义证明和机器检查证明。

这条线也解释了为什么 formal verification 不能被简化成“跑一个 checker”。有些问题适合有限模型搜索，有些问题适合约束求解，有些问题需要人引导证明。学习 FV 的关键不是站队某个工具，而是判断问题落在哪个区域。

现在可以把这章的路线压缩成一张知识地图。注意，表格里的节点不是彼此孤立的名词，而是同一条问题链上的不同回答。

| 节点 | 核心问题 | 典型证据 |
|---|---|---|
| 程序正确性 | 程序文本如何满足前置/后置条件 | Floyd、Hoare |
| 时序逻辑 | 如何表达随时间变化的性质 | Pnueli |
| 模型检查 | 有限模型是否满足性质 | Clarke、Emerson、Sifakis |
| 符号方法 | 如何处理巨大状态空间或约束 | Symbolic model checking、SMT-LIB |
| 规格语言 | 如何精确定义系统行为或结构 | TLA/TLA+、Alloy |
| 定理证明 | 如何构造机器可检查的证明 | Lean、Coq/Rocq、Isabelle/HOL |

Formal verification 的知识地图不是一张工具清单，而是一组问题分解方式：程序状态如何变化，系统行为如何展开，性质如何表达，状态空间如何处理，规格如何写清楚，证明如何被机器检查。

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
