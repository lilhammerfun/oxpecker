# 路线图

Oxpecker 是一个 **Zig 优先的形式化验证库和工具链**，但工具本身不是最终问题。

Oxpecker 的问题背景是 AI 辅助开发：代码生成速度在上升，但代码审查、验证和回归确认没有同步提速。按照短板原则，整体工程效率会被“如何确认代码真的对”卡住。

Oxpecker 要探索的是：形式化验证能否把 agent 生成的代码约束成更容易检查的形态。最终目标是让系统工程师可以用 Zig 表达规格、模型和候选实现，用同一套工具执行状态搜索、反例分析、性质检查、符号求解和工程集成。路线图记录的是这个工具本体怎样服务 AI 辅助开发中的验证瓶颈。

换句话说，Oxpecker 的核心假设不是“做一个新的形式化验证工具就能替代代码审查”，而是：如果 agent 修改的是状态逻辑、并发交错、取消语义、重试语义、资源生命周期或协议状态机，那么代码审查不应该只靠读 diff 和补测试。我们应该让 agent 同时给出规格、模型、性质和可复现检查结果，让审查者从“人工追所有路径”转向“检查模型边界、性质是否正确、反例或通过结果是否可信”。

<div class="roadmap-hero">
  <div>
    <p class="roadmap-kicker">$ oxpecker route</p>
    <h2>让 agent 生成的代码更容易被验证</h2>
    <p>
      Oxpecker 先把 agent 修改过的状态逻辑抽象成小模型，再用检查器给出可复现的反例和性质结果。
      工具路线会逐步扩展到规格表达、状态空间工程、时序性质、符号方法和受限 Zig 程序验证。
    </p>
  </div>
  <ul>
    <li><span>问题</span>AI 写代码更快，代码审查跟不上</li>
    <li><span>方法</span>规格、模型、反例和可复现检查</li>
    <li><span>目标</span>让生成代码进入可验证工作流</li>
  </ul>
</div>

## 路线原则

<div class="roadmap-grid">
  <section>
    <h3>工具优先</h3>
    <p>路线图围绕 Oxpecker 库、CLI、检查器核心、求解后端和工程集成展开，服务 agent 生成代码的验证问题。</p>
  </section>
  <section>
    <h3>并行轨道</h3>
    <p>像以太坊路线图一样，Oxpecker 的长期路线不是单线程阶段表，而是多个互相支撑的技术轨道。</p>
  </section>
  <section>
    <h3>诚实边界</h3>
    <p>有界检查、抽象模型、solver-backed 结果和 proof checking 必须分别说明证明了什么、假设了什么、没有覆盖什么。</p>
  </section>
  <section>
    <h3>Zig 优先</h3>
    <p>规格、模型、候选实现、测试和工程入口优先使用 Zig。外部 solver 和成熟工具可以接入，但不替代 Zig 主线。</p>
  </section>
  <section>
    <h3>审查优先</h3>
    <p>每个能力都要回答它怎样帮助代码审查：能否给出更小的检查面、更清楚的性质、更可复现的失败路径。</p>
  </section>
</div>

## 技术轨道

<div class="roadmap-track">
  <div class="roadmap-track__label">轨道 01</div>
  <div>
    <h3>检查器核心</h3>
    <p>把当前显式状态检查器打磨成稳定、可组合、可嵌入的核心库。</p>
    <ul>
      <li>稳定 `Spec`、`Action`、`Invariant`、`CheckResult` 和 `TraceStep`。</li>
      <li>支持多个初始状态、多个性质、搜索限制和明确的 `incomplete` 结果。</li>
      <li>保持精确相等性是状态等价的语义来源；hash 只能作为优化。</li>
      <li>提供 BFS、DFS 和有界搜索的清晰结果语义。</li>
    </ul>
  </div>
  <strong>现在</strong>
</div>

<div class="roadmap-track">
  <div class="roadmap-track__label">轨道 02</div>
  <div>
    <h3>规格表达层</h3>
    <p>让用户能用普通 Zig 写出清楚的模型、动作、状态空间和性质，而不是被迫学习另一门规格语言。</p>
    <ul>
      <li>拆分 action 的 guard / update，使迁移规则更接近形式规格。</li>
      <li>提供有界 bool、enum、int domain helper。</li>
      <li>沉淀 lifecycle、queue、worker pool、callback ordering 等可复用 model pattern。</li>
      <li>评估 Zig-native DSL 是否能减少重复，而不是隐藏状态机思维。</li>
    </ul>
  </div>
  <strong>下一步</strong>
</div>

<div class="roadmap-track">
  <div class="roadmap-track__label">轨道 03</div>
  <div>
    <h3>状态空间工程</h3>
    <p>让 Oxpecker 能处理真实工程小模型，而不是只能运行玩具状态机。</p>
    <ul>
      <li>实现高效 visited-state storage，并用 equality 确认 hash 命中。</li>
      <li>支持 state canonicalization、状态图输出、trace 压缩和搜索统计。</li>
      <li>诊断 state explosion 的来源，例如队列长度、worker 数量、事件交错和整数范围。</li>
      <li>探索 symmetry reduction、partial-order reduction 和 checkpoint。</li>
    </ul>
  </div>
  <strong>下一步</strong>
</div>

<div class="roadmap-track">
  <div class="roadmap-track__label">轨道 04</div>
  <div>
    <h3>性质系统</h3>
    <p>从 invariant 扩展到更完整的性质系统，但不把有限检查伪装成无限证明。</p>
    <ul>
      <li>区分 safety violation、deadlock、search limit、holds 和 incomplete。</li>
      <li>实现 deadlock detection 和 bounded temporal checks。</li>
      <li>为 liveness、fairness 和 temporal property 建立可解释的 bounded 语义。</li>
      <li>输出能回到工程代码审查的 counterexample trace。</li>
    </ul>
  </div>
  <strong>下一步</strong>
</div>

<div class="roadmap-track">
  <div class="roadmap-track__label">轨道 05</div>
  <div>
    <h3>符号方法</h3>
    <p>在显式枚举遇到状态爆炸时，引入符号表示、约束求解和外部 solver。</p>
    <ul>
      <li>把 bool、bounded int、enum 和 bit-vector 条件导出为约束。</li>
      <li>实验 path condition、symbolic transition 和 solver model 到 trace 的反向解释。</li>
      <li>接入现有 SMT / SAT solver，而不是过早自研生产级 solver。</li>
      <li>明确 solver-backed 结果的信任边界。</li>
    </ul>
  </div>
  <strong>研究</strong>
</div>

<div class="roadmap-track">
  <div class="roadmap-track__label">轨道 06</div>
  <div>
    <h3>受限 Zig 验证</h3>
    <p>从“用 Zig 写模型”走向“检查一小段受限 Zig 代码”，但只在语义边界清楚时推进。</p>
    <ul>
      <li>先限定纯函数、小整数、无 allocator、无 FFI、无并发的 Zig 子集。</li>
      <li>探索从 Zig AST / IR 提取表达式、控制流和路径条件。</li>
      <li>unsupported construct 必须明确失败，不能被静默跳过。</li>
      <li>等 Zig 1.0 和 compiler interface 更稳定后，重新评估更深的程序验证路线。</li>
    </ul>
  </div>
  <strong>研究</strong>
</div>

<div class="roadmap-track">
  <div class="roadmap-track__label">轨道 07</div>
  <div>
    <h3>证明边界</h3>
    <p>当有限搜索和自动求解不够时，Oxpecker 需要解释并实验 proof obligation，而不是假装所有问题都能枚举。</p>
    <ul>
      <li>实验 tiny proof checker，只检查小证明，不承诺 production theorem prover。</li>
      <li>把 induction、lemma、invariant strengthening 和 machine-checkable proof 放进工具边界讨论。</li>
      <li>探索 solver proof logging 或 proof artifact 的长期可能性。</li>
    </ul>
  </div>
  <strong>稍后</strong>
</div>

<div class="roadmap-track">
  <div class="roadmap-track__label">轨道 08</div>
  <div>
    <h3>工具链集成</h3>
    <p>把 Oxpecker 接入 coding agent、CI 和代码审查，使 agent 修改状态逻辑后自动产生可检查证据。</p>
    <ul>
      <li>提供 CLI、JSON / Markdown report、非零退出码和稳定 machine-readable output。</li>
      <li>支持 CI、代码审查、coding agent 变更检查和回归模型集合。</li>
      <li>记录每次检查的模型版本、性质名、状态数、搜索限制和 trace。</li>
      <li>建立 API stability、supported Zig version 和 reproducibility policy。</li>
    </ul>
  </div>
  <strong>下一步</strong>
</div>

## 里程碑

<div class="roadmap-milestones">
  <section>
    <span>01</span>
    <h3>种子检查器</h3>
    <p>最小显式状态检查器可运行，能输出 invariant failure 和 counterexample trace。</p>
  </section>
  <section>
    <span>02</span>
    <h3>核心库</h3>
    <p>稳定公共 API、多个性质、搜索限制、清晰结果类型和示例集合。</p>
  </section>
  <section>
    <span>03</span>
    <h3>工程规模</h3>
    <p>状态空间去重、统计、诊断、图输出和适合 CI 的报告进入主线。</p>
  </section>
  <section>
    <span>04</span>
    <h3>超越显式搜索</h3>
    <p>引入 bounded temporal check、symbolic method、SMT 后端实验和受限 Zig 验证原型。</p>
  </section>
</div>

## 完成信号

Oxpecker 的路线阶段不能靠“功能看起来存在”标记完成。每个阶段至少需要满足：

- 有可运行的 Zig example 覆盖目标能力。
- 有失败样例证明 checker 能发现问题。
- 有通过样例证明 fixed design / fixed implementation 能通过检查。
- 结果类型能区分 violated、deadlock、incomplete 和 holds。
- `zig build test` 能覆盖核心行为。
- CLI / report 输出足够支持 CI 和代码审查复现。

## 重新评估触发条件

出现下列情况时，必须重新修订路线图：

- Zig 到达 1.0 或新的 compiler / IR 稳定性里程碑。
- 当前 API 无法表达三个以上真实工程模型。
- 状态空间工程成为主要瓶颈。
- 外部 SMT / SAT solver 集成进入主线。
- Oxpecker 开始验证受限 Zig 源码，而不只是执行用户写出的模型。
- 工具出现原作者之外的真实使用者。
- 任何路线描述开始把有界结果误写成无界证明。
