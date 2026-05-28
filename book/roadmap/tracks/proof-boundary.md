# 证明边界

证明边界解释搜索和 solver 自动化会停在哪里。

目标是在不过早把 Oxpecker 变成生产级 theorem prover 的前提下，实验 proof obligation。

对 AI 辅助开发来说，证明边界很重要，因为绿色 checker 结果很容易制造错误信心。有些性质需要归纳、强化不变量或机器可检查的证明 artifact；有界搜索可以暴露失败，但不能支撑每一个一般性结论。

## 状态

<div class="roadmap-status-strip">
  <span>稍后</span>
  <strong>当真实例子中的模型检查边界变清楚之后，这条轨道才有价值。</strong>
</div>

## 目标能力

- 小型 proof checker 实验。
- induction 和 invariant strengthening 示例。
- 机器可检查 proof artifact 实验。
- solver proof logging 调研。
- 区分有界证据和 proof obligation 的审查表述。

## 近期工作

1. 找出一个有界检查无法一般性证明的性质。
2. 表达对应 proof obligation。
3. 构建或集成一个小型 checker 来检查 proof artifact。
4. 将结果与模型检查输出对比。
5. 展示审查者应该如何理解“在边界内检查通过”和“在假设下证明成立”。

## 完成标准

- proof 实验与生产 checker claim 隔离。
- 被检查的证明有很小的 trusted kernel。
- 路线图说明 Oxpecker 证明边界之外还剩下什么。
- 审查报告只有在真正检查了 proof artifact 时才使用证明语言。
