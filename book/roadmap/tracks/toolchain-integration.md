# 工具链集成

工具链集成让 Oxpecker 进入日常工程流程。

目标是在本地开发、CI、代码审查和 agent 生成代码工作流中，让检查结果可以复现。

这里会回到 Oxpecker 的核心定位。我们想要的工作流不是“agent 写代码，人类手工读完所有路径”。我们想要的是：agent 写出或修改状态逻辑，Oxpecker 运行相关规格，代码审查收到关于性质、边界、trace 和不支持区域的具体报告。

## 状态

<div class="roadmap-status-strip">
  <span>下一步</span>
  <strong>CLI 和报告形态应在 checker 结果类型稳定后推进。</strong>
</div>

## 目标能力

- 带非零退出码的 CLI。
- JSON 和 Markdown 报告。
- CI-friendly 输出。
- 可复现检查元数据。
- 代码审查和 coding agent 集成模式。
- 支持的 Zig 版本策略。
- 面向 agent 生成变更的稳定审查 artifact。

## 近期工作

1. 定义 CLI 命令形态。
2. 为模型检查结果增加 JSON 报告。
3. 增加适合代码审查的 Markdown trace 输出。
4. 记录模型版本、性质名、已探索状态、限制和 trace。
5. 定义 coding agent 应该如何把 Oxpecker 结果附到变更里。

## 完成标准

- 检查失败会让 CI 失败。
- 报告稳定到足以被自动化消费。
- 审查者能根据报告在本地复现 trace。
- agent 编写的状态逻辑变更可以根据检查结果被接受、拒绝或标记为不确定。
