# 历史背景和知识地图

上一章从 cancellation 场景进入，说明 formal verification 关心的不是一条 happy path，而是模型允许的全部状态和迁移。本章把视角拉远一点：formal verification 不是一条单线技术路线，而是一组围绕“程序或系统为什么正确”的方法。我们会沿着 **程序正确性**、**时序逻辑**、**模型检查**、**符号方法**、**规格语言** 和 **定理证明** 六个节点建立知识地图。

这不是完整历史。完整历史会牵涉数理逻辑、自动定理证明、编程语言语义、硬件验证、抽象解释、类型理论和安全协议分析。这里的目标更窄：先知道哪些概念是经典节点，为什么它们在 formal verification 知识体系里占据核心位置，以及它们分别适合回答哪类工程问题。

## 程序正确性

程序正确性是关于程序是否满足其规格的精确判断。它的核心问题不是“程序看起来能跑”，而是“给定前置条件、程序语句和后置条件，能否用形式规则说明执行后的状态满足要求”。

这条线的经典起点通常会提到 Floyd 和 Hoare。Floyd 在 1967 年的 “Assigning Meanings to Programs” 中用断言和流程图边上的条件来讨论程序含义；Hoare 在 1969 年的 “An Axiomatic Basis for Computer Programming” 中提出了后来被称为 Hoare logic 的公理化程序推理方式。[^floyd-1967][^hoare-1969]

如果把它放到工程直觉里，Hoare triple 可以粗略读成：

```text
{precondition} program {postcondition}
```

它说的是：如果程序开始前满足 `precondition`，并且程序正常结束，那么结束后应满足 `postcondition`。这个形式把“测试某个输入输出”提升成了“证明一类状态变化”。读者暂时不需要掌握完整推导规则，只要先抓住一个分界：程序正确性这条线主要研究程序文本和逻辑断言之间的关系。

:::thinking 为什么不从定理证明开始？
从历史上看，程序正确性和定理证明关系很近，但作为入门路线，直接进入证明系统容易让读者先背规则、后理解问题。这里先把它定位为“用逻辑断言描述程序状态变化”，后面再区分自动检查、交互式证明和模型枚举。
:::

## 时序逻辑

时序逻辑是用于表达“状态随时间如何变化”的逻辑。它让规格不只描述当前状态是否满足某个断言，还能描述“总是如此”“最终发生”“直到某事发生前保持”等关于执行序列的性质。

Pnueli 1977 年的 “The Temporal Logic of Programs” 是 formal verification 历史中的关键论文之一，因为它把 temporal logic 引入程序验证语境，用来推理 reactive 和并发程序的行为。[^pnueli-1977] 对系统工程师来说，这一步很重要：很多系统不是算完一个结果就结束，而是持续响应事件。event loop、worker pool、分布式协议、agent runtime 都属于这种持续演化的系统。

上一章讲的 safety property 可以用一句话近似理解为“坏事永远不发生”。与之相对，liveness property 关心“好事最终会发生”。这个区分会贯穿后续章节：检查 `cancelled` 后不能 `completed` 是 safety；检查一个排队任务最终会被处理则开始接近 liveness。

## 模型检查

模型检查是自动检查有限或可有限抽象的系统模型是否满足形式规格的方法。它把系统看成状态图，把性质看成逻辑公式或状态条件，然后系统性探索所有相关行为。

模型检查在 1980 年代初形成了独立研究方向。Clarke 和 Emerson 的 branching-time temporal logic 工作，以及 Queille 和 Sifakis 在法国的独立工作，被 ACM Turing Award 介绍为 model checking 领域的奠基性工作；Clarke、Emerson、Sifakis 也因此获得 2007 年图灵奖。[^clarke-emerson-1981][^acm-model-checking]

模型检查对工程师的吸引力在于它给出的是可操作反馈。性质成立时，工具报告模型满足规格；性质不成立时，工具通常给出 counterexample execution，帮助定位错误路径。上一章的 cancellation trace 就是这种反馈的教学版：

```text
created -> running -> cancelled -> completed
```

这里的每个节点都是一个 state：任务先被创建，随后运行，接着进入取消语义，最后又被完成事件改写成 completed。箭头是 transition，表示模型允许系统从一个状态走到下一个状态。只要这条路径能从 initial state 出发走出来，`completed` 就是 reachable state。

如果规格写的是“任务一旦 cancelled，就不能再 completed”，那么这条路径就是反例。它不是说真实系统一定每次都这样运行，而是说在当前模型允许的迁移规则下，存在一条执行路径会违反 invariant。模型检查回答的问题正是：在我给定的有限模型里，是否存在一条路径违反性质？

这种反馈适合早期学习 state、transition、reachable state、invariant 和 counterexample trace，因为每个词都能落到这条线上：`created`、`running`、`cancelled`、`completed` 是 state；箭头是 transition；能走到的节点是 reachable state；“cancelled 后不能 completed” 是 invariant；整条错误路径就是 counterexample trace。

## 符号方法

符号方法是用公式、约束或压缩表示来处理大量状态的方法。它出现的压力很直接：显式枚举状态很容易遇到 state explosion。

显式模型检查会把每个 reachable state 当成具体对象处理。这个方法清楚、可解释，但状态数量会随着变量、进程、队列容量和消息交错快速增长。Burch、Clarke、McMillan、Dill、Hwang 的 “Symbolic Model Checking: 10^20 States and Beyond” 展示了用符号表示处理巨大状态空间的方向，是 symbolic model checking 的经典节点。[^symbolic-1992]

SMT 也是这一类知识地图中的重要节点。SMT 关注在某些背景理论下公式是否可满足，SMT-LIB 则提供了标准化语言和基准生态来推动 SMT 求解器研究。[^smtlib] 对入门读者来说，可以先把 SMT 理解成“把问题写成逻辑约束，让 solver 找到满足约束的赋值，或者证明不存在这样的赋值”。

这条线和模型检查的关系不是替代，而是互补。显式状态探索适合建立状态机直觉；符号方法适合解释为什么真实系统很快需要更压缩的表示、更强的求解器和更谨慎的抽象。

## 规格语言

规格语言是用来精确定义系统应当如何行为的语言。它的价值不在于让文字变得更学术，而在于让状态、操作、约束和性质可以被工具检查或被人严格审阅。

TLA 是 Leslie Lamport 提出的 Temporal Logic of Actions。它把 action 作为状态迁移关系放进 temporal logic 中，适合描述并发和 reactive systems。Lamport 的 “The Temporal Logic of Actions” 是理解 TLA/TLA+ 的经典入口。[^lamport-tla]

Alloy 则代表另一种规格语言直觉。Daniel Jackson 的 Alloy 论文把它描述为一种 lightweight object modelling notation，强调用关系和约束描述结构，并通过自动分析寻找实例或反例。[^alloy-2002] 这提醒我们：formal verification 不是只有“状态机和时序逻辑”一条路。不同规格语言把不同问题变得自然：TLA+ 更适合行为和并发，Alloy 更适合关系结构和约束。

## 定理证明

定理证明是通过逻辑推导建立命题为真的方法。和模型检查相比，它通常不依赖有限状态空间枚举，而是把正确性变成需要证明的数学命题。

Proof assistant 是支持人和机器共同构造、检查证明的工具。Lean 官方将 Lean 4 描述为 programming language 和 interactive theorem prover；Coq/Rocq、Isabelle/HOL 等系统也属于这一类工具生态。[^lean-official] 入门阶段不需要马上进入 dependent type theory，但需要知道这条线解决的问题和模型检查不同：它更适合处理无限结构、抽象数学命题、程序语义证明和机器检查证明。

这条线也解释了为什么 formal verification 不能被简化成“跑一个 checker”。有些问题适合有限模型搜索，有些问题适合约束求解，有些问题需要人引导证明。学习 FV 的关键不是站队某个工具，而是判断问题落在哪个区域。

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
