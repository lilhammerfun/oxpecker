# 序言

这本 booklet 面向已经熟悉工程系统、但刚开始系统学习 formal verification 的读者。它不是某个项目的说明书，也不是某个工具的手册；它的目标是解释 formal verification 试图解决什么问题、核心概念如何互相连接，以及工程师怎样从真实系统行为进入模型、性质和检查。

普通测试很擅长验证人已经想到的路径，但系统错误经常藏在没有手动挑出来的路径里。一个 task 被 cancel 后又 completed，一个 payment callback 和 timeout 同时到达，一个 worker pool 在 queue 非空时停住，这些错误并不是因为某一行代码看起来复杂，而是因为系统允许多个事件以不同顺序发生。

本书会从这类工程问题开始，逐步引入 state、transition、reachable state、invariant、counterexample trace、deadlock、liveness、fairness 和 state explosion。TLA+、Alloy、SMT、Kani、Lean 等工具会作为参照出现，但它们不是一开始要掌握的目标。更重要的是先建立一个判断框架：什么问题适合建模，模型里应该保留哪些状态，性质应该怎样表达，工具输出的反例意味着什么。

## 阅读方式

每一章都会先提出一个具体问题，再引入解决这个问题所需的概念。抽象概念必须配一个小模型、trace、图示、代码片段或工具输出。早期章节不追求覆盖所有理论，而是追求一个判断：读完之后，读者是否能把一个系统行为说成 state、transition 和 property。

## 实践方式

Formal verification 不能只靠阅读建立直觉。读者可以用 TLA+ 写小规格，用 Alloy 表达关系约束，用 SMT solver 解小约束，也可以自己写一个 explicit-state model checker 来观察状态空间。具体工具可以变化，但练习目标保持一致：把真实系统问题压缩成有限模型，检查模型允许的所有行为，再用反例回到系统设计。

| 线索 | 作用 |
|---|---|
| 小模型 | 把真实系统行为压缩到可理解范围 |
| 性质 | 明确什么行为必须成立，什么行为绝不能发生 |
| 工具输出 | 用 reachable state、trace 或 counterexample 反馈模型问题 |

接下来我们先回答一个入口问题：为什么系统工程师需要 formal verification，而不是只写更多测试。
