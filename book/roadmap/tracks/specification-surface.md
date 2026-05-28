# 规格表达层

规格表达层定义用户如何用 Zig 表达模型和性质。

目标是在保留状态迁移思维的同时，让规格保持可读。在 AI 辅助开发场景里，这层接口还定义了 agent 修改代码时，旁边应该维护什么样的规格。

如果写规格比手工审查实现还难，Oxpecker 就偏离了项目定位。规格表达层应该把关键审查问题显式化：有哪些状态，哪些事件可能发生，每个事件怎样改变状态，哪些性质绝不能被违反。

## 状态

<div class="roadmap-status-strip">
  <span>下一步</span>
  <strong>当前 API 可以支撑小模型；重复模式还需要命名和抽取。</strong>
</div>

## 目标能力

- guard / update 风格的 action helper。
- 有界 bool、enum 和整数 domain。
- lifecycle、queue、worker pool、retry、callback、resource ownership 等可复用 model pattern。
- 明确判断 Zig-native DSL 是否真的有价值。
- 形成一种可以要求 coding agent 编写或维护的 spec 形态。

## 近期工作

1. 把 action 逻辑拆成 guard 和 update。
2. 增加有限 domain helper。
3. 从示例中抽取通用模式。
4. 在同一模型上比较原始 Zig API 和 helper API。
5. 整理规格审查 checklist：状态字段、事件、guard、update、性质和边界。

## 完成标准

- 三个示例共享至少一种可复用模式。
- helper API 减少重复，但不隐藏状态迁移。
- 不支持的状态空间形态能清楚失败。
- 一个面向 agent 的小示例同时展示代码变更、规格变更、checker 结果和审查 artifact。
