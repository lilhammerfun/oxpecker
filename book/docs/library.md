# 库接口

Oxpecker 当前库入口是：

```text
src/oxpecker.zig
```

当前核心类型：

```text
Action
Invariant
Spec
CheckResult
TraceStep
```

## 最小检查流程

```text
定义 State
定义 Event
定义初始状态
定义 Action.next
定义 Invariant.holds
定义 state_eql
调用 oxpecker.check
```

## 当前限制

- 只覆盖有限状态模型。
- 当前 checker 是显式状态搜索。
- 当前状态去重以 `state_eql` 为语义来源。
- 当前库不验证任意 Zig 源码。
- 当前库不提供完整 temporal logic、SMT solving 或 theorem proving。

