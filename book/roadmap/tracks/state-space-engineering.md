# 状态空间工程

状态空间工程让 Oxpecker 能处理比玩具例子更真实的小模型。

目标是在保持 checker 语义清楚的前提下，理解并控制可达状态数量的增长。

这对 AI 辅助开发很重要，因为 agent 的局部修改看起来可能很小，却会引入大量新的事件交错。审查者需要知道 Oxpecker 是否探索了相关状态空间，是因为边界停止，还是因为模型增长过大而失去信心。

## 状态

<div class="roadmap-status-strip">
  <span>下一步</span>
  <strong>状态去重在概念上可用；扩展策略仍然开放。</strong>
</div>

## 目标能力

- 高效 visited-state 存储。
- hash 命中后的相等性确认。
- state canonicalization hook。
- 搜索统计和状态增长诊断。
- 状态图输出。
- trace 压缩。
- symmetry reduction 和 partial-order reduction 实验。
- 诊断生成代码变更为什么增加了可达状态数量。

## 近期工作

1. 用 hash-backed 结构替代线性 seen-state 扫描。
2. 保持 equality 是最终语义检查。
3. 报告已探索状态数、frontier 大小、重复状态数和停止原因。
4. 生成一个可用于代码审查的小状态图。
5. 比较生成代码或规格变更前后的状态增长。

## 完成标准

- 较大的有界示例比基线线性扫描更快。
- 诊断信息能指出哪些模型维度增加了状态数量。
- 状态图输出可以附到 CI 或代码审查报告。
- 审查报告能说明结果是可信、有界，还是因为状态增长超过限制而不完整。
