# 模型表达

这里讨论 formal verification 入门中的模型表达问题。

前面的章节已经能写出 `State`、`Event`、`Action.next` 和 `Invariant`，但这些表达还很原始。继续推进时，真正的问题不是“怎样开发更多库功能”，而是：一个初学者怎样把真实系统行为表达得更清楚、更少重复，同时仍然看得见状态、事件、迁移和性质。

计划覆盖：

```text
更好的 Action 接口
transition guard / update 拆分
bounded int / enum / bool 的模型空间
可复用 model pattern
小型 DSL 是否值得
```
