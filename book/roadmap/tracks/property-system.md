# 性质系统

性质系统让 Oxpecker 从简单不变量扩展到更完整的性质表达。

目标是增加更多性质类型，同时保持每个结果的边界诚实清楚。

对 agent 生成代码来说，性质就是审查契约。它说明实现变化时审查者想保护什么：取消后不能完成、资源不能释放两次、有待处理工作时 worker 不能永久停住、回调不能丢失、进入错误终态后不能再返回成功结果。

## 状态

<div class="roadmap-status-strip">
  <span>下一步</span>
  <strong>不变量检查是种子能力；下一步是死锁和时序检查。</strong>
</div>

## 目标能力

- 不变量。
- 死锁检测。
- 有界时序检查。
- 带显式假设的 liveness 和 fairness 示例。
- 适合代码审查的反例 trace。
- 能映射回工程意图的性质名和失败解释。

## 近期工作

1. 把 `deadlock` 加成独立结果。
2. 增加有界时序性质实验。
3. 在模型中显式呈现 fairness 假设。
4. 明确 liveness 相关表述都是有界语义。
5. 为常见 agent runtime 和系统示例建立 property catalog。

## 完成标准

- `violated`、`deadlock`、`incomplete` 和 `holds` 是不同结果。
- 每个非 safety 示例都说明边界和假设。
- 反例 trace 解释性质为什么失败，而不只是展示最终状态。
- 审查者不读模型源码也能看出被检查的是哪条工程承诺。
