# 符号方法

符号方法是显式枚举之外的路线。

目标是用约束表示大量状态，并在不隐藏信任边界的前提下进行 solver-backed 实验。

这条轨道存在的原因是代码审查不能永远依赖穷举枚举。当 agent 生成的变更引入更宽的整数范围、更多标志位或大量等价交错时，Oxpecker 需要在不神化 solver 的前提下保持可检查性。

## 状态

<div class="roadmap-status-strip">
  <span>研究</span>
  <strong>还不是生产后端；当显式搜索限制变得明显后才有价值。</strong>
</div>

## 目标能力

- 为 bool、enum、有界整数和 bit-vector domain 导出约束。
- path condition 实验。
- SMT / SAT solver 集成实验。
- 从 solver model 反向重建 trace。
- 信任边界报告。
- 报告要区分显式搜索证据和 solver-backed 证据。

## 近期工作

1. 定义一个很小的 constraint IR。
2. 把一个有界模型导出为约束。
3. 调用外部 solver。
4. 把 solver model 转回具体 trace。
5. 在报告中解释结果的哪部分来自 Oxpecker，哪部分来自 solver。

## 完成标准

- 一个 solver-backed 示例能找到具体反例。
- 报告说明信任了哪个 solver。
- 不支持的表达式明确失败。
- 返回的 model 能被翻译成可审查的事件 trace 或状态赋值。
