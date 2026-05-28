# Booklet

Booklet 是 Oxpecker 的学习部分，面向想从工程问题进入 formal verification 的读者。

它的目标不是替代库文档，而是建立判断框架：怎样把真实系统行为压缩成状态、事件、迁移和性质；怎样理解反例；怎样知道一个模型检查结论的边界。

Oxpecker 的 Zig 库会作为本书的教学工具出现，但它不是 booklet 的独立课程阶段。库 API、工程路线和生产化能力放在 Docs 与 Roadmap 中维护；booklet 只在解释 FV 概念需要可运行工具时使用这套库。

## 课程结构

```text
FV 实践直觉
模型表达
时序性质
定理证明
工程集成
```

## 阅读入口

- [初识 Formal Verification](./01-practice-intuition/01-introduction.md)
- [显式状态模型检查](./01-practice-intuition/02-explicit-state-model-checking.md)
- [规格接口](./01-practice-intuition/03-spec-interface.md)
- [规格与实现](./01-practice-intuition/04-spec-and-implementation.md)
