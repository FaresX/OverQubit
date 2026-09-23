# Julia 路线可行性评估（v2，重新加权版）

> 状态：评估记录，v2（2026-09-22 修订）。v1 结论"维持 Python"基于**商业产品**的权重假设。经用户澄清本项目为**个人学习项目 / 内部少数人学习**、**全部 web 展示**、**不使用 WGLMakie**，并参考用户提供的《03_Julia核心可行性调研》及新增核实事实后重写。
> 本文只做事实调研与权衡，最终取舍待用户确认后记入架构决策。

## TL;DR

**在修正后的权重下，Julia 路线从"不推荐"变为"可行且多数维度占优"。** 决定性变化有三：(1) 部署/运维/人才/生态这些 v1 中 Julia 的主要失分项，在个人项目里几乎全部失效；(2) "展示能力差距"经核实**不存在**——Pluto 与 Stipple 均有官方文档化的 WebGL/JS 嵌入路径、原生 LaTeX、甚至官方 three.js 教程；(3) Julia 生态出现了两个 v1 未计入的重要事实：**QuantumToolbox.jl（QuTiP API 兼容的 Julia 实现，已发 Quantum 期刊论文）**和 **JuliaQuantumControl 的官方双 transmon 例子**。

剩下真正的取舍只有两个：**是否愿意自研 200-500 行超导比特模型层（失去 scqubits 交叉验证，可用"黄金向量"缓解）**，以及**用户对 Julia 的熟悉度/意愿**。

## 0. 本次修订因素

- 用户澄清：个人学习项目（非商业）；可能扩大到内部少数人员学习；全部走 web 页面展示；WGLMakie 不会使用。
- 参考文档：`docs/03_Julia核心可行性调研.md`（用户提供，倾向 Julia+Pluto）。
- 新增核实：Pluto 自定义 JS/WebGL 嵌入、PlutoSliderServer 现状、Stipple 定制化深度与 StippleLatex、QuantumToolbox.jl、JuliaQuantumControl。

## 1. 物理能力：不仅达标，比 v1 评估时更强

- **QuantumOptics.jl** v1.2.10（MIT，625★，活跃）：含时 Lindblad `master_dynamic`、`mcwf`、`bloch_redfield`、`ChargeBasis`（电荷基，transmon 专用）、稀疏/惰性算子——本项目 M0-M3 动力学链路全覆盖。
- **QuantumToolbox.jl（v1 未计入，重要）**：qutip 官方组织的 **QuTiP API 兼容 Julia 实现**（`mesolve`/`Qobj` 同款 API），v0.49.0（2026-09-19），172★；DifferentialEquations 求解器、CUDA GPU、稀疏、自动微分；论文 *Quantum* 9, 1866 (2025)，基准自称四库最快（mesolve/mcsolve/smesolve 对 QuTiP/dynamiqs/QuantumOptics；具体倍速数字未能验证）。含义：**为 QuTiP API 写的动力学代码可近 1:1 移植，且有 GPU 升级路径**。
- **JuliaQuantumControl**：QuantumControl.jl v0.11.5（活跃），**官方双 transmon 纠缠门示例**（`perfect_entanglers.jl`，N=6 能级，源自 Goerz PRA 91, 062307）；Krotov.jl 即 Python qucontrol/krotov 的官方 Julia 移植。对 5.4/5.6（两比特门/CZ）及未来 DRAG/脉冲优化演示是现成起点。
- **缺口不变**：Julia 无 scqubits 对等物。但按用户参考调研的拆分，需自建的是"模型定义与参数化层"（transmon 电荷基对角化 ~低难度、扫参 ~低、χ ~中、T1/T2 公式库 ~中-高），**不动求解器红线**；预估 200-500 行。对个人学习项目，自建这层**兼具正确性风险与学习价值**两面。
- 缓解（v1 未提）：**黄金向量法**——用现有 Python 环境一次性生成 scqubits/pyEPR 的参照值（典型 EJ/EC 的能谱、α、χ），作为测试向量存入 Julia 仓库，随时回归验证。既保留交叉验证，又不引入双运行时。

## 2. 展示能力专章（回答"web 展示会不会有差距"）

**结论：能力上没有差距，差距只在工程生产力，且不用 WGLMakie 后差距进一步缩小。**

已核实的官方路径：

| 架构组件 | Julia 路线实现（已验证） |
| --- | --- |
| 滑块调参联动 | Pluto `@bind` + 反应式 cell 自动重跑（Pluto 的核心设计）；或 Stipple reactive model（JSON 双向同步） |
| 标准 2D 曲线（S21、能谱、布居） | Pluto/Stipple 下 PlotlyJS（锯齿/悬停/缩放免费），对比 React 路线需手搓 canvas 图表——**这条 Julia 反而更省** |
| Bloch 球（three.js WebGL） | Pluto 有**官方 three.js 教程**（WebGL + `@bind Slider` 联动 + `invalidation` 清理 + canvas 复用，fonsp/featured）；Stipple 有官方 CesiumJS 3D 嵌入范式（同法接 three.js） |
| 时间轴播放器 | PlutoUI 有 `Scrubbable` 原生 scrub 控件；播放/倍速可经官方 JS→Julia 事件通道（`dispatchEvent("input")` + `@bind`）自建，模式已文档化 |
| 公式渲染 | Pluto md 原生 LaTeX（MathJax 内置）；StippleLatex（Vue-KaTeX，README 的 nestlist demo 即"公式逐步拼接"） |
| 公式逐步推导 | Stipple：StippleLatex 参数绑定 model 字段 → nestlist 逐步展开已验证可行；Pluto：md/JS 拼接需自建，无现成结构 |
| 复杂自定义组件 | Pluto：`@htl` 任意 HTML+`<script>`，Julia→JS 用 `published_to_js`，JS→Julia 用 CustomEvent；Stipple：`add_script`/`@deps`/自定义 Vue 组件（`register_global_component`、Julia 生成 SFC） |
| 多人访问（内部学习场景） | **PlutoSliderServer v1.9.0（活跃，无状态、每访客隔离、git 监视部署）；MIT《computationalthinking.mit.edu》即其驱动**——与"内部少数人学习"场景完全同构 |

诚实的差距（均为生产力/风险，非能力）：

- **无 HMR**：Pluto 用 reactivity 缓解（改 Julia 代码即时重跑，其强项）；Bonito/Stipple 无此待遇。
- **无 TSX 级类型安全与 React 生态先例**：时间轴播放器、逐步推导面板这类"没人做过"的组合，Julia 侧可参考的示例更少（官方嵌入口子已验证，但整屋装修要自己来）。
- **调试跨两语言**：Julia + 手写 JS，无 React DevTools。
- **静态导出失去交互**：Pluto 导出 HTML 中 `@bind` 失效（官方明示），所有演示必须跑在 Julia 服务上——对本场景可接受。
- **PlutoSliderServer 安全模型**："not designed to be secure，访客可执行代码"（官方 README）→ 内部/容器化部署可行，**不可暴露公网**。

## 3. 部署与分发（按个人项目重新加权）

| 项 | Julia | Python |
| --- | --- | --- |
| 个人本地用 | 装 Julia + `Pkg.instantiate`（首次预编译 TTFP 分钟级，之后快） | pip/conda 安装（常见环境坑） |
| 内部少数人 | PlutoSliderServer 一台服务器全搞定（MIT 课程先例）或各人本地跑 notebook | 需部署 FastAPI 后端 + 前端构建产物两层 |
| 独立 exe | PackageCompiler 可行但重（v1 已述） | PyInstaller 相对轻 |
| 长期维护 | 包版本锁定（Julia 兼容性较敏感） | 更宽松 |

## 4. 对比矩阵（重新加权版）

| 维度 | Julia 路线 | Python 路线（现状架构） | 权重（本项目） |
| --- | --- | --- | --- |
| 本项目所需物理能力 | ✅ QuantumOptics/QuantumToolbox | ✅ scqubits/QuTiP | 高 |
| 超导专用模型库 | ❌ 自建 200-500 行 | ✅ scqubits | 高（Julia 侧） |
| 正确性交叉验证 | ⚠️ 黄金向量缓解 | ✅ 现成 | 高（Julia 侧） |
| 标准教学 UI 生产力（滑块/公式/文字/联动） | ✅✅ Pluto 原生强项 | ⚠️ 全部要造（参数面板/manifest/API） | 高 |
| Bespoke  widgets（播放器/Bloch/推导面板） | ⚠️ 官方嵌入口子已验证，自装 | ✅ 生态先例多 | 高 |
| 学习价值（个人项目核心） | ✅✅ 单语言+自建模型层+SciML | ⚠️ 主要学 React+API | 高 |
| 计算性能 | ✅（本项目无感知差异） | ✅ 够 | 低 |
| 部署运维 | ⚠️ TTFP/版本锁定 | ✅ 轻 | 中（已降权） |
| 团队/协作/开源 | ❌ 小 | ✅ 大 | 低（个人项目） |
| 已有沉没设计 | 需重写架构文档的壳层部分 | ✅ architecture.md 已定稿 | 中 |

## 5. 若走 Julia：路线草图（采纳参考调研的 MVP 路径）

```
Pluto 壳（@bind 滑块 · 多图联动 · md 讲解 · Stipplable 时间轴 · 官方 three.js Bloch）
   │ 直接函数调用（无 API 层）
models/（自研薄层 200-500 行）
   transmon 电荷基对角化（能级/α/势阱/φzpf）· EJ(Φ) · flux 扫描 · χ
   （黄金向量：scqubits/pyEPR 一次性生成的参照值）
dynamics/（复用）QuantumOptics 或 QuantumToolbox（QuTiP API 兼容）
viz/ PlotlyJS（标准曲线）+ three.js/自嵌 JS（Bloch/播放器/chevron）
```

- MVP-0：transmon 对角化 + 势阱/能级图（纯 Julia），黄金向量验收（EJ/EC=50 → α≈−215 MHz 量级）。
- MVP-1：Pluto 滑块联动势阱+能级+Rabi（单比特门，对应现 M0）。
- MVP-2：S21/色散、DRAG、两比特门（可借 JuliaQuantumControl 思路）；分享用 PlutoSliderServer。
- 若想要"更像应用"（路由/仪表盘/Docker 模板）而非 notebook：Stipple 是 Julia 路线内的备选壳，代价是引入 Genie server 与更多机制。

## 6. 结论与建议

**修正 v1 的结论：在"个人学习 + 全 web + 教学优先 + 内部小范围"的前提下，Julia+Pluto 值得选，多数维度占优。** 真正的决策因子只剩三个，都只取决于你：

1. **Julia 熟悉度/学习意愿**：若愿意借这个项目深入 Julia（SciML + 量子生态），这是最大加分项；若完全不熟且不想学，迭代速度会拖慢（参考调研列为中-高风险）。
2. **对自建模型层的态度**：愿意亲手写 transmon 对角化（学习价值）并能接受"黄金向量"式验证 → Julia；希望零物理轮子、开箱对照 scqubits → Python。
3. **形态偏好**：Pluto notebook 式"反应式多图联动"是你心中的教学形态 → Julia+Pluto；坚持"应用外壳 + 时间轴播放器 + manifest 驱动"的架构 → 维持 Python+React（architecture.md 已定稿，M0 可直接开工）。

**维持项**：两条路线都不推翻"薄壳 + 复用求解器"总架构；都不在 MVP 做 PythonCall 混搭；Jupyter/Python 科研生态互通（发表/协作）仍是 Python 的独有加分。

## 参考来源（2026-09-22 核实）

- Pluto.jl 文档与 featured 教程（threejs、javascript、reactivity、plutosliderserver、export-html）：plutojl.org；PlutoSliderServer.jl v1.9.0（MIT 课程先例）
- Stipple.jl / StippleLatex.jl / GenieFrameworkDocs（adding-JS-libraries、custom-components）：github.com/GenieFramework
- QuantumOptics.jl v1.2.10：github.com/qojulia/QuantumOptics.jl
- QuantumToolbox.jl v0.49.0 + *Quantum* 9, 1866 (2025)：github.com/qutip/QuantumToolbox.jl
- JuliaQuantumControl（QuantumControl.jl v0.11.5、perfect_entanglers.jl 官方 transmon 示例）：github.com/JuliaQuantumControl
- v1 评估来源（Genie/Oxygen/HTTP.jl、PackageCompiler、Bonito/Makie、PythonCall）见本文档 v1 版或 git 历史
