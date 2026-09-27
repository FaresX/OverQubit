# OverQubit 架构设计文档

> 状态：已定稿（2026-09-22，与用户共同确认）。本文档是后续开发的唯一事实源；需求变更时先改本文档再改代码。
> 上游依据：`docs/research/tools-survey.md`（工具选型）、`docs/research/dev-plan.md`（薄壳方案）。
> **AI 协作记录在 `ai/` 目录**：踩坑与教训（`ai/lessons.md`）、未解决问题（`ai/known-issues.md`）、
> 无头验证方法（`ai/workflow.md`）、会话日志（`ai/session-log.md`）。改代码前先扫一眼 `ai/checklists.md`。

## 1. 产品定义

一个面向初学者的**超导量子比特原理演示器**：以真实物理计算为唯一数据源，通过交互参数 + 动画 + 可溯源公式推导，讲清楚 S21、色散读取、单比特门、DRAG、两比特门、CZ 校准等核心原理，并可持续扩展到更多原理演示。

### 1.1 核心原则

1. **前端零物理**：前端不内置任何物理模型；所有动画帧、曲线、数值均由后端真实计算（scqubits / QuTiP）产出，前端只做渲染、插值与播放控制。
2. **教学级精度 + 显式标注**：模型按教学需要截断与近似，但每次近似必须在界面明示（`approximations` 字段驱动 UI 标注条）。
3. **可扩展**：新演示 = 后端模块 + manifest + 场景组件复用，不动外壳。
4. **双模式叙事**：每个演示均支持"导览模式"（分步讲解 + 自动播放）与"自由探索模式"（自调参数）。
5. **公式可溯源**：公式链结构化存储，共享基础推导库，公式可展开逐步推导，部分步骤挂迷你演示。

## 2. 技术栈

| 层 | 选型 | 说明 |
| --- | --- | --- |
| 前端 | React + TypeScript + Vite | 界面中文；暗色主题优先 |
| 3D 渲染 | three.js（Bloch 球、电路示意） | 不引入 react-three-fiber，保持依赖最小 |
| 2D 图表 | 自绘 Canvas 组件 + SVG | 曲线、IQ 平面、热图；不用重型图表库 |
| 动画 | requestAnimationFrame 时间轴播放器 | 播放/暂停/倍速/拖拽/事件标记 |
| 公式 | KaTeX | 推导链逐步展开 |
| 后端 | Python 3.11+ / FastAPI | REST 同步 + SSE 长任务 |
| 物理引擎 | scqubits、QuTiP | BSD-3，随包保留 LICENSE 与版权声明 |
| 包管理 | 前端 npm；后端 pip/venv（`requirements.txt`） | |

## 3. 仓库结构

```
OverQubit/
├─ frontend/
│  ├─ src/shell/      # 应用外壳：演示列表、布局、路由
│  ├─ src/panels/     # manifest 驱动的参数面板、时间轴控制
│  ├─ src/scenes/     # 场景组件注册表（bloch_player / sweep_chart / iq_plot /
│  │                  #   chevron_map / population_bars / pulse_timeline /
│  │                  #   energy_diagram / circuit_diagram / wavefunction_plot）
│  ├─ src/player/     # 时间轴播放器（帧轨道、marker、倍速、拖拽）
│  ├─ src/api/        # fetch 封装、SSE 客户端
│  └─ src/formulas/   # KaTeX 渲染、推导链组件
├─ backend/
│  ├─ app/main.py         # FastAPI 入口、CORS、路由注册
│  ├─ app/registry.py     # 演示注册表（自动发现 app/demos/ 下模块）
│  ├─ app/engines/        # 共享物理引擎
│  │  ├─ resonator.py         # input-output / 阻尼驱动振子（5.1、5.2 共用）
│  │  ├─ transmon.py          # 电荷基 transmon：H0 构建、EJ(Φ)、对角化（公共）
│  │  ├─ dynamics.py          # QuTiP mesolve 封装、Bloch/布居抽取（5.3、5.5 共用）
│  │  ├─ two_qubit.py         # 双 transmon + 耦合、通量调制（5.4、5.6 共用）
│  │  └─ base_formulas.py     # 共享基础推导库数据（见 §6.4）
│  ├─ app/demos/         # 每演示一个模块：compute() + pydantic schema + manifest
│  │  └─ manifests/      # 与演示同名的 manifest（YAML/JSON）
│  └─ requirements.txt
└─ docs/                 # 本文档 + research/
```

## 4. 核心机制

### 4.1 演示注册表与 manifest 契约

后端启动时扫描 `app/demos/`，每个演示模块暴露 `compute(params) -> ComputeResult` 与 manifest。manifest 结构：

```yaml
id: single-qubit            # 唯一 id
title: 单比特门
summary: 一句话介绍
category: control           # 分类：readout / control / coupling / calibration / spectrum
scenes:                     # 前端场景组件（须在 frontend/src/scenes 注册表存在）
  - {type: bloch_player, track: bloch, title: "Bloch 球"}
  - {type: population_bars, track: pops, title: "布居"}
  - {type: pulse_timeline, track: pulse_env, title: "驱动脉冲"}
params:                     # 自动生成参数面板
  - {id: EJ, label: "E_J/h (GHz)", type: slider, range: [8, 30], default: 18, step: 0.5}
  - {id: EC, label: "E_C/h (GHz)", type: slider, range: [0.15, 0.45], default: 0.3, step: 0.01}
  - {id: omega_d, label: "驱动频率 (GHz)", type: slider, range: [4, 8], default: 5.0, step: 0.01}
  - {id: amp, label: "驱动幅度 Ω (GHz)", type: slider, range: [0, 0.3], default: 0.1, step: 0.005}
  - {id: sigma, label: "高斯宽度 σ (ns)", type: slider, range: [2, 20], default: 8, step: 0.5}
  - {id: detune, label: "失谐 δ (GHz)", type: slider, range: [-0.5, 0.5], default: 0.0, step: 0.01}
approximations:             # UI 近似标注条（逐条展示）
  - "两能级近似：动力学在 {k} 能级截断空间演化"
  - "旋转波近似（RWA）"
formulas:                   # 公式链（引用共享库或演示内定义）
  - {ref: base/transmon-hamiltonian}
  - {id: two-level, latex: "...", deps: [base/transmon-hamiltonian], op: "近似"}
  - {ref: base/rwa}
scenarios:                  # 导览模式分步脚本
  - {step: 1, narration: "...", override: {detune: 0.0}, focus_scene: bloch_player,
     show_formulas: [base/rwa], expect: "Bloch 矢量绕驱动轴匀速旋转"}
  - {step: 2, narration: "...", override: {}, focus_scene: pulse_timeline,
     show_formulas: [base/pulse-area], expect: "π 脉冲后布居反转"}
  ...
```

### 4.2 计算 API 契约

```
GET  /api/demos                          → [{id, title, summary, category}]
GET  /api/demos/{id}/manifest             → manifest（完整 JSON）
POST /api/demos/{id}/compute              → body: {参数}; resp: ComputeResult
POST /api/demos/{id}/simulate/{形如chevron} → 长任务：202 {job_id}
GET  /api/demos/{id}/jobs/{job_id}/events → SSE：{progress} … {done, result} | {error}
```

`ComputeResult` 结构（所有演示统一）：

```json
{
  "tracks": {
    "bloch":      {"t": [0, ...], "x": [...], "y": [...], "z": [...]},
    "pops":       {"t": [...], "p0": [...], "p1": [...], "p2": [...]},
    "pulse_env":  {"t": [...], "re": [...], "im": [...]}
  },
  "markers": [{"t": 12.5, "label": "π 脉冲"}],
  "static":  {"f01_ghz": 5.02, "anharmonicity_ghz": -0.21},
  "meta":    {"compute_ms": 180, "approximations": [...], "warnings": ["RWA 边缘有效"]}
}
```

约定：时间单位 ns，频率/能量单位 GHz；ħ=1（GHz 直接当角频率用时在 manifest 标注）。同步阈值：预估 <1.5s 返回 200，否则转 SSE 长任务。

### 4.3 动画管线（时间轴播放器）

- **帧轨道（track）**：compute 返回命名时间序列；播放器以 rAF 推进 playhead（支持倍速、拖拽、marker 跳转），场景组件订阅 playhead 并对 track 做索引/线性插值采样。
- **交互闭环**：参数改动 → 300ms 防抖 → `POST compute` → 替换 tracks（playhead 保持）→ 继续播放；计算期间 UI 显示"计算中"。
- **导览模式**：按 manifest.scenarios 顺序执行，每步可覆写参数（触发重算）、聚焦场景、展示对应公式、给出“预期现象”；支持上一步/下一步/自动播放。
- **真实计算边界**：帧之间的任何插值只允许线性插值（几何/视觉层面），禁止在帧间“补演”物理过程。

### 4.4 场景组件注册表（frontend/src/scenes）

| 组件 | 用途 | 渲染 |
| --- | --- | --- |
| circuit_diagram | 电路/线路示意，可点元件 | SVG/Canvas |
| bloch_player | Bloch 球 + 轨迹 | three.js |
| sweep_chart | S21、能谱、条件相位等曲线 | Canvas |
| iq_plot | IQ 平面散点 + 噪声圆 | Canvas |
| chevron_map | 二维扫描热图 | Canvas |
| population_bars | 布居堆叠条 | Canvas |
| pulse_timeline | 脉冲波形与序列 | Canvas |
| energy_diagram | 能级随时间/通量动画 | Canvas |
| wavefunction_plot | 波函数/势能 | Canvas |

新场景类型出现时才新增组件；新演示优先组合已有组件。

### 4.5 公式与推导溯源

- 公式链按 §4.1 `formulas` 引用组织；**共享基础推导库**（`base_formulas.py` + 前端渲染）节点：电路量子化（LC/约瑟夫森）、transmon 哈密顿量与电荷基截断、RWA、Rabi 与脉冲面积、Jaynes-Cummings 与色散变换、input-output 与 S21、Lindblad 主方程。
- 推导链（derivation）结构：`steps[]`，每步含 LaTeX、说明、依据公式 `from`、操作类型（定义/代入/近似/整理）、可选 `mini_demo`（挂某个场景的静态帧或微动画）。
- UI：点公式 → 就地展开推导步骤；点符号 → 定义与来源；推导步骤旁的"看演示"可跳到对应演示的导览步骤。

### 4.6 物理约定

- 电荷基对角化：`ncut` 30-50（能量/谱）；动力学：截断 k=3-6 能级（默认 3，实时监控 |2⟩ 布居并提示两能级近似有效性）。
- flux 调制：SQUID 周期式 EJ(Φ)=EJ·cos(πΦ/Φ₀)（可带不对称因子 D）。
- 退相干：默认关闭；开启时按 Lindblad 崩塌算符实现（T1（能量弛豫）、T2φ（纯退相））。

## 5. 演示规格总表

> 详细规格（教学目标/参数/分镜/计算/公式链/近似）见 §5.1-§5.10 说明或向作者索要；下表为索引。

| # | 演示 | 引擎 | 场景组件 | 公式链 | 状态 |
| --- | --- | --- | --- | --- | --- |
| 1 | S21 原理 | resonator + base | circuit_diagram, sweep_chart, pulse_timeline | 电路→量子化→JC→色散→S21→χ | M1 |
| 2 | 色散读取 | resonator | sweep_chart, iq_plot, population_bars | S21(ω,s)→稳态→SNR | M1 |
| 3 | 单比特门 | dynamics | bloch_player, population_bars, pulse_timeline | 量子化→两能级→RWA→Rabi→脉冲面积 | **M0** |
| 4 | DRAG 校准 | dynamics | pulse_timeline, population_bars, bloch_player | 3 能级振幅→泄漏→DRAG 条件 | M2 |
| 5 | 两比特门（iSWAP/ZZ） | two_qubit | energy_diagram, sweep_chart, bloch_player×2 | 耦合→交换→ZZ→CZ 概念 | **M2 已完成（Pluto）** |
| 6 | CZ 门实现原理 + 校准 | two_qubit | energy_diagram, sweep_chart, bloch_player×2, chevron_map | 交换→chevron→相位校准 | **已完成（Pluto，见 §16）** |
| 7 | transmon 谱与电荷色散（含磁通调谐） | transmon + flux | wavefunction_plot, sweep_chart, energy_diagram | SQUID E<sub>J</sub>(Φ)→扇形→色散→甜点 | **M4 已完成（Pluto）** |
| 8 | T1/T2 退相干（Ramsey/回波） | dynamics(序列) | bloch_player, sweep_chart, population_bars | Lindblad→T1/T2→T2*→自旋回波 | **M4 已完成（Pluto）** |
| 9 | Purcell 与测量反作用 | resonator + dynamics | sweep_chart, population_bars | input-out→Purcell 率→反作用 | backlog |
| 10 | iSWAP 与 ZZ 串扰 | two_qubit | population_bars, energy_diagram, sweep_chart | 耦合振子→iSWAP 振荡→ZZ | **M4 已完成（并入 #5，Pluto）** |

## 6. 里程碑

### M0（约 1 周）：端到端基础设施 + 单比特门完整演示

- [ ] backend：FastAPI 骨架、CORS、registry 自动发现、`/api/demos`、manifest、compute 路由（含 pydantic schema）
- [ ] backend：`engines/transmon.py`（电荷基 H0、对角化、f01/α）、`engines/dynamics.py`（mesolve 封装、Bloch/布居抽取）
- [ ] backend：`demos/single_qubit.py` + manifest（3 个场景组件轨道：bloch/pops/pulse_env；导览 scenarios ≥4 步；approximations 显式标注）
- [ ] frontend：Vite+React+TS 脚手架、shell 布局、演示列表（来自 API）、manifest 驱动参数面板
- [ ] frontend：时间轴播放器（播放/暂停/倍速/拖拽/marker）、bloch_player（three.js）、population_bars、pulse_timeline
- [ ] frontend：公式面板最小版（KaTeX + 静态公式链，推导展开 M4 完善）、导览模式（分步 + 覆写参数 + 聚焦场景）
- [ ] API 代理配置（vite dev proxy → FastAPI）
- **M0 验收**：浏览器改 EJ/驱动 → 重算 → Bloch 轨迹/布居随参数正确变化（Rabi 频率与 Ω、脉冲面积与布居反转等由人工抽查核对）；导览 4 步可播放；approx 标注可见；端到端首帧 <2s。

### M1：S21 + 色散读取（谐振器引擎 + sweep_chart/iq_plot；导览脚本 2 个）
### M2：DRAG（β 扫描）+ 两比特门（双比特引擎 + energy_diagram）
### M3：CZ 校准（chevron 二维扫描 + 相位校准）——**Pluto 形态已完成（§16）**；上网页版时补 SSE 异步 + 进度条（§4.2 契约不变）
### M4：公式推导库完善（共享库 + 逐步展开 + 符号定义）+ backlog 4 演示 + 打磨

## 7. 风险与对策

| 风险 | 对策 |
| --- | --- |
| scqubits 维护低活跃 | 锁定版本；只用稳定 API；fork 存档；核心引擎尽量只用 QuTiP 级原语 |
| 参数重算延迟（扫频/二维扫描） | 同步阈值 1.5s + SSE 长任务；缓存；能级数默认最小 |
| QuTiP 维度增长 | 默认 3 能级截断；界面实时显示 |2⟩ 布居作为有效性指标 |
| 物理正确性 | M0 起对每个演示做人工抽查（解析极限对照：Rabi 频率、π 脉冲、热平衡极限）；后续按用户决定引入测试 |
| 公式量庞大 | 共享基础库 + 按演示增量；不追求一次完备 |
| 许可证合规 | 随包附 scqubits/QuTiP LICENSE，界面 About 页声明 |

## 9. 演进路径：Pluto 优先 → 全面网页应用（2026-09-23 决策）

**决策**：首个形态采用 **Pluto notebook**（教学反应式优先、零 API 层、物理验证最快），同时为未来升级为全面网页应用（Bonito 优先，或 React+Julia 后端）保留迁移能力。本条与第 2-5 节的壳层设计（React/FastAPI/manifest 契约）冲突时，**以本条为准**；第 4.6 节物理约定、第 5 节演示总表、`docs/julia-assessment.md` 的 Julia 路线结论继续有效。

分层铁律（自第一天起强制执行，是迁移成本≈壳重写的保证）：

1. **物理/计算层**：所有计算代码为纯 Julia 模块（`src/` 或包结构），不依赖 Pluto。函数签名只接受普通数值/NamedTuple，禁止 PlutoUI/Slider 等类型渗入签名。
2. **演示规格层**：每个 demo 的 params schema、公式链、分镜 scenarios、approximations 为结构化数据（Dict/NamedTuple/JSON），UI 框架无关。
3. **自定义部件层**：three.js 等 JS 部件为自包含模块（容器+数据进、事件出），不依赖 Pluto 运行时 API；同一份 JS 可在 Bonito/React 复用。
4. **内容层**：讲解文本与推导内容存于 md/数据文件，不混入计算代码。
5. **验收层**：黄金向量测试（scqubits/pyEPR 一次性生成的参照值）只覆盖物理层，迁移后原样有效。

迁移成本核算：满足上述规则时，Pluto → Bonito/React = 物理层（0 改动）+ 部件 JS（基本 0 改动）+ 规格数据（0 改动）+ 壳重写（唯一成本，约占总代码量 10-20%，AI 辅助下数天~两周）。Pluto notebook 本身充当每个演示的可执行规格说明（输入滑块→计算函数→输出图→讲解文本），是 AI 转译壳层时最可靠的依据。

## 11. MVP-0 完成记录与工程约定（2026-09-23）

**已完成（MVP-0，Pluto 形态）**：

- `src/OverQubit.jl`：纯 Julia 物理层（电荷基 transmon：谱、f01/f12/α、波函数、电荷色散扫描），仅依赖 LinearAlgebra，符合第 9 节分层铁律。
- 黄金向量：`scripts/generate_golden.py` 用 scqubits v4.3.1 生成 8 个参照点（`data/golden_transmon.jl`），`scripts/validate.jl` 回归通过（最大相对误差 4.6e-13）。
- `notebooks/mvp0_transmon.jl`：MVP-0 演示（EJ/EC/ng 滑块 → 势阱能级图、|ψ|²、电荷色散、Koch 解析对照读数、原理讲解）。
- 验证链：`scripts/validate.jl`（物理回归）、`scripts/notebook_selftest.jl`（无头求值 notebook 全部非 @bind cell）、`scripts/preview_mvp0.jl`（无头渲染 → `spike/mvp0_preview.html`）。

**工程约定（踩坑记录，必须遵守）**：

1. **notebook 中含运行时变量插值的 markdown 一律用 `Markdown.parse("""...""")`，不要用 `md"""..."""`**。原因：本机 Julia 1.12.7 中 `md"""` 的 `$var` 插值在多字节（中文）长内容下会静默错乱（标识符被截断、报不存在的符号）。普通字符串插值 + `Markdown.parse` 路径已验证可靠。
2. 字符串插值只用简单变量（`$var`），预览/HTML 模板同理。
3. 运行：`julia -e 'using Pluto; Pluto.run()'` 后打开 `notebooks/*.jl`。
4. **绘图一律用 `PlotlyBase.Plot(...)`，不用 PlotlyJS/SyncPlot**——PlotlyJS 的 SyncPlot 走 WebIO 浏览器桥（曾触发 "WebIO not detected"），PlotlyBase 的 HTML 显示通道（plotly div + CDN）无需 WebIO。另注意 PlotlyBase v0.8 没有 `plot` 函数，构造器是 `Plot`。
5. **不要手改 notebook 里 Pluto 自动嵌入的 `PLUTO_PROJECT_TOML_CONTENTS`/`PLUTO_MANIFEST_TOML_CONTENTS`**；若其内容过期（如包 UUID 错位），删除这两个 cell 让 Pluto 用默认环境并在下次保存时重建。
6. **装饰性 HTML 一律用 `@htl`（HypertextLiteral，已显式安装）产出真实 DOM**；不要把 HTML 塞进 `md"""`/`Markdown.parse`——stdlib Markdown 不解析 HTML 块，会原样显示成文本。公式排版用 HTML 上下标（`E<sub>J</sub>`、`<sup>1/4</sup>`）+ unicode（α、φ、ψ、⟩、↔），**不依赖 MathJax**（`$...$` 定界符在 Julia 字符串里还要跟插值打架，弃用）。`@htl` 字符串内插值只用 `$(var)`，不得出现其他 `$`。
7. **图高写进 `Layout(height=...)`**（势阱图 620、色散图 560），不要依赖默认高度。
8. **代码单元格默认折叠**：notebook 文件尾部写 `Cell order:` footer，代码 cell 用 `# ╟─<uuid>`、展示 cell 用 `# ╠═<uuid>`（header 与 footer 的 uuid 一致；格式经 Pluto 源码核实）。
9. **单位约定**：引擎内部时间域频率一律 **rad/ns**（入口 GHz×2π）；`Ω_R = amp·|⟨0|n̂|1⟩|`（不除 2，对照 lab 系实驱动）；χ 定义为 **g²/Δ**（|0⟩/|1⟩ 的 S21 曲线位于 ωr∓χ，曲线间隔为 2χ）；载波积分需乘 `1/sinc(ωd·dt/2)` 补偿。
10. **自测每个 notebook 用全新模块**（`Module(:NB_x)` + `Base.include_string` 预载物理模块）——共用模块会因重复 include 导致 `using` 绑定歧义。
11. **DRAG/双分量驱动**：`evolve_density_iq(t, ng, ωd, It::Function, Qt::Function, T)`，H(t) = H0 + [I·cos(ωd t) − Q·sin(ωd t)]·V；I/Q 均含 sinc 步内平均补偿。DRAG 数值标定点 β*≈4 ns（amp=0.25、σ=6 时），一阶理论 1/(2|α|)≈1.5 ns 仅作量级预告——β 以数值扫描为准（与实验流程一致）。
12. **学习路径**：notebooks/ 下四个演示按 MVP-0（能级与量子化）→ 单比特门（驱动与 Rabi）→ DRAG（泄漏压制）→ 色散读取（S21 与测量）排序；每个含概念卡、滑杆交互、读数卡、可展开推导链、试试看任务。

## 13. 学习内容扩展记录（2026-09-26）

**新增三块引擎 + 三个演示 notebook + 一层共用 UI 组件**，全部沿用 §9 分层铁律（物理层纯 Julia、规格层数据化、渲染层只出 HTML）。

### 13.1 新增物理引擎（`src/OverQubit.jl`，仍只依赖 LinearAlgebra）

| 函数/类型 | 职责 | 演示 |
| --- | --- | --- |
| `squid_ej` / `transmon_at_flux` | SQUID 磁通调谐：E_J(Φ) = E_J(cos πΦ + D) | flux_tuning |
| `TwoQubit` + `coupled_hamiltonian` / `coupled_spectrum` | 双 transmon 电容耦合（g_c·n̂₁n̂₂）：能级截断有效模型 + 全电荷基精确参照 | two_qubit |
| `exchange_rate` / `zz_rate` / `bare_detuning` / `dressed_index` / `evolve_two_qubit` | iSWAP 交换率、always-on ZZ、dressed 态识别、两比特精确演化 | two_qubit |
| `SequenceEngine` + `evolve_segments` / `rotating_drive` / `dissipator_super` | 旋转坐标系 + 多能级 RWA + 分段常值 Lindblad 演化（T1/T2/Ramsey/回波） | t1_t2 |

关键约定（写进 docstring，避免与既有引擎混淆）：
- 哈密顿量是**振荡频率**，入口传 GHz、内部 ×2π 折 rad/ns；**衰减率是指数速率**，直接传 ns⁻¹（再 ×2π 会把 T1 缩小 2π 倍）。
- 1/Tφ = gammaphi、1/T2 = 1/(2T1) + 1/Tφ；两能级截断下 ZZ ≡ 0（非谐性是 ZZ 的必要条件，须 nlev≥3）。
- 驱动 `phase` = 旋转轴在 xy 平面的方位角（0°=σ_x）；段内 H 恒定 → 传播子逐步离散无截断误差，自由段可用大采样间隔（成本降 1-2 个量级）。
- dressed 态一律用**重叠最大**识别（`argmax(abs2.(row))`，勿用 `argmax(f, itr)`——后者返回元素而非索引）。

### 13.2 新增演示 notebook

| 文件 | 主题 | 组件 |
| --- | --- | --- |
| `notebooks/t1_t2.jl` | T1/T2/T2*/Ramsey/自旋回波；ensemble 准静态噪声平均 | 3 图 + Bloch 赤道面动画 + 8 步推导 + quiz |
| `notebooks/two_qubit.jl` | iSWAP 振荡、能级扇形（avoided crossing）、always-on ZZ、CZ 概念 | 4 图 + 双 Bloch 球动画 + 8 步推导 + quiz |
| `notebooks/flux_tuning.jl` | E_J(Φ)、能级扇形、电荷色散爆炸、甜点与 D 因子 | 2 图 + 势阱/经典小球动画 + 8 步推导 + quiz |

每个页面统一为：banner → lesson_nav 学习路径 → concept_cards → ③ 调参 → 读数卡（stat_row/readout_table）→ 图 → ④ 试试看 → ⑤ 推导溯源 → ⑥ 自测（quiz）→ 小结。

### 13.3 渲染层新增组件（`src/OverQubitViz.jl`）

`setup_page()`（plotly.js 懒加载 + 全局样式——**Pluto 前端不预装 plotly.js，不调用则所有图静默失败**）、
`lesson_nav`（导航条）、`stat_row` / `readout_table`（读数卡）、`callout`（info/tip/warn 提示框）、
`quiz`（折叠答案解析）、`figure_note`、`divider`、`banner(..., icon=)`（7 种主题图标）、
`layout_base(..., ytype=)`（对数轴）。

### 13.4 验收链

- `scripts/validate.jl`：scqubits 黄金向量 8 点回归，最大相对误差 4.6e-13（**未回归**）。
- `scripts/validate_dynamics.jl`：Rabi/泄漏/JC 色散/S21 五项（**未回归**）。
- `scripts/validate_new.jl`（新）：30 项，覆盖磁通调谐（含 Φ=0.5 纯电荷极限）、序列引擎（π 脉冲/Rabi/T1/Tφ/Ramsey 条纹/回波/采样无关性）、两比特（J=g_c n01²、全电荷基交叉验证、iSWAP 逐点对照解析式、ZZ≡0 判据）。
- `scripts/notebook_selftest.jl`：7 个 notebook 无头求值全通过（默认滑块值常量化注入）。

### 13.5 Pluto notebook 格式坑（本次踩到，务必遵守）

1. **cell UUID 必须是合法十六进制且末段恰好 12 位**，否则 `notebook_selftest.jl` 的 `CELL_RE` 剥不掉头部 → 报 `UndefVarError(:<uuid>)`。
2. `begin` 块内**不要写短式函数定义** `f(x) = ...`（Julia 1.12 会把参数当本地变量 → `UndefVarError(:x0)`）；用 `function ... end`。
3. 顶部 `for` 循环里出现的 `x_` / 裸赋值在软作用域下可能被当局部变量 → 包进函数。
4. `md"""` 长中文插值仍有静默错乱风险，沿用 `@htl` + `$(var)`（§11.6）。
5. `attr()` 返回 Dict，不能事后 `lay.yaxis.type = ...`；需要新轴参数时往 `layout_base` 加关键字。
6. **cell 末尾绝不要写 `html1, html2`（返回 Tuple）**——见 §14，这会让两张图只剩一半宽。

## 14. Pluto 显示层坑：cell 返回 Tuple → 图被并排挤扁（2026-09-27）

### 14.1 症状

`flux_tuning` 页里扇形图只占半宽：Plotly 把图例**折成竖排**、标题溢出被裁、绘图区被挤成一条，
旁边还挂着 "1:" "2:" 序号。

### 14.2 根因（Pluto 的 MIME 选择，不是 plotly）

`PlutoRunner/src/display/mime dance.jl` 的偏好顺序里
`application/vnd.pluto.tree+object` **排在 `text/html` 前面**，而
`display/tree viewer.jl` 里 `pluto_showable(::MIME"…tree+object", ::Tuple) = true`。
于是 cell 末尾写

```julia
plotly_html("oq_a", p1), plotly_html("oq_b", p2)   # 返回 Tuple
```

就走 tree viewer：`TreeView.js` 渲染出 `<pluto-tree class="collapsed">`，
`treeview.css` 规定 `pluto-tree.collapsed pluto-tree-items { flex-direction: row; align-items: baseline }`
且 `pluto-tree p-r > p-v { display: inline-flex }`、`p-r > p-k` 显示元素序号——
两个图被塞进**同一行、各占一半宽度**，自然坏掉。
半宽容器下 Plotly 的水平图例放不下，就折成竖排（实测宽度阈值 ≈ 200–260px）。

### 14.3 解法

`src/OverQubitViz.jl` 新增 `oq_stack(blocks...; gap=12)`：把多个 HTML 片段包进**一个** HTMLStr
（flex column、每个子项 `width:100%`）。Pluto 对单个 HTMLStr 走 `text/html` 原样内联，每张图都拿到 100% 宽。

```julia
oq_stack(plotly_html("oq_fan", pfan; height=440), plotly_html("oq_band", pband; height=410))
```

已替换 3 处：`flux_tuning.jl`（扇形图+色散图）、`s21_readout.jl`（幅度+相位）、`single_qubit_gate.jl`（包络+布居）。
同规则适用于 `md"a", md"b"`——一律包成一个。

### 14.4 防回归

`scripts/notebook_selftest.jl` 的 `check_html_tuple`：cell 求值后若返回_tuple/vector 且元素全是
HTMLStr 或 Markdown.MD，直接报错并提示改用 `oq_stack`（已用旧写法实测可触发）。

### 14.5 另：浏览器"保存网页"拿不到可用导出

Pluto 的编辑器页把前端 bundle 全部内联（≈8.8 MB），用浏览器 Ctrl+S 存下来得到的只是**外壳**
（`<pluto-editor class="loading">`，没有 `window.pluto_statefile = "data:;base64,…"`），
单独打开只会一直转圈。要拿自包含 HTML，请用 Pluto 的导出按钮（`/notebookexport` 会 bake statefile）。
本项目快速预览可用 `julia spike/preview_any.jl`（`NB=<name>` 环境变量）生成静态页。

## 15. 动画帧坑：不写 `traces=[i]` 会把背景曲线顶没（2026-09-27）

### 15.1 症状

`flux_tuning` 势阱图点"播放"后**抛物线整条消失**，只剩红球；`single_qubit_gate` 的 Bloch 球会少一条
纬线框。静态看完全正常，只有播放才暴露。

### 15.2 根因（Plotly.js 的 frameMerge）

`src/plots/plots.js` 的 `frameMerge`：

```js
traceIndices = framePtr.traces;
if(!traceIndices) {
    // If not defined, assume serial order starting at zero
    traceIndices = [];
    for (i = 0; i < framePtr.data.length; i++) traceIndices[i] = i;
}
```

随后 `plots.transition` 执行
`gd.data[traceIndices[i]] = plots.extendTrace(gd.data[traceIndices[i]], data[i])`。
所以帧数据 `data[0]` **永远作用在 `gd.data[0]`** 上。我们的小球/标记 frames 只写了一条 data，
它就去覆盖 trace 0 —— 而 trace 0 恰好是势阱抛物线 / 第一条经纬线框 → 曲线被单个 marker 顶替。

### 15.3 解法

`src/OverQubitViz.jl` 新增 `anim_frame(idx, name, trace)`，强制写 `traces=[idx]`。
用法：先放一条**专用小 trace**（通常放最后），再

    BALL = length(traces) - 1        # 0 基
    frames = [anim_frame(BALL, string(k), scatter(x=[xs[k]], y=[ys[k]]; mode="markers", ...))
              for k in 1:nfr]

已修正 4 处（flux_tuning 势阱、mvp0 势阱、single_qubit_gate Bloch、two_qubit 双 Bloch），
并把原本"碰巧对"的 2 处（s21_readout 散点云、t1_t2 IQ 投影线）也改成显式 `anim_frame(0, …)`。

### 15.4 防回归

- `scripts/notebook_selftest.jl`：静态扫描 notebook 源码，出现裸 `frame(` 直接报错。
- `scripts/check_frames.jl`：逐 cell 求值后抓 `frames` 与 `tr`/`traces`，
  核对每帧 `traces[i]` 指向的 trace 必须是小 trace（>20 点即判为背景曲线 → FAIL）。
  当前 6 个动画图全部通过（索引见上文表格）。

## 12. 显式排除（本期不做）

真机控制/校准（Qiskit Experiments 域）、任意用户自定义电路（SQcircuit 域）、量子极限放大器、多比特网络。这些在 backlog 评审时再议。

## 16. CZ 门引擎与两个新演示 notebook（2026-09-27）

**新增一块磁通脉冲两比特引擎 + 两个 notebook（⑧ 原理 / ⑨ 校准）**，全部沿用 §9 分层铁律
（物理层纯 Julia、规格层数据化、渲染层只出 HTML）与 §11 工程约定。

### 16.1 新增物理引擎（`src/OverQubit.jl`，仍只依赖 LinearAlgebra）

| 函数/类型 | 职责 | 演示 |
| --- | --- | --- |
| `cz_pair` / `CZPair` / `cz_squid_ej` | CZ 工作台：qubit1 固定 + qubit2 是 SQUID（`E_J2(Φ) = EJ2(cos πΦ + D)`） | 两者 |
| `cz_hamiltonian` / `cz_levels` / `cz_level_energy` | 固定参考基里改写 Ĥ₂(Φ) 后的哈密顿量与 dressed 谱 | 两者 |
| `cz_gap` / `cz_crossing` / `cz_detuning` | \|11⟩↔\|02⟩ avoided crossing 的最低点、隧穿耦合 2V、裸失谐振判据 | 两者 |
| `cz_pulse_shape` / `cz_flux` / `cz_evolve` | 脉冲包络（方沿/平滑沿）与分段常值传播；同段并行传播「关掉 g_c」的参考演化 | 两者 |
| `cz_conditional_phase` / `cz_leakage` / `cz_ramsey` / `cz_ramsey_pair` / `cz_metrics` / `cz_zcorrect` / `cz_chevron` | 条件相位、泄漏、Ramsey 校准序列（信号/参考）、门保真度（含虚拟 Z 校正）、二维网格 | ⑨ |

关键约定（写进 docstring，避免与既有引擎混淆）：

- **固定参考基投影**：参考基 = 两个 transmon 在 Φ=0（idle）的本征态前 `nlev` 个；任意磁通下把
  「随磁通变化的电荷基 Ĥ₂(Φ)」投影回**同一组固定基**，而不是重新对角化再截断（后者白送一套
  基变换产生的非绝热项）。`nlev=3` 是硬性要求——|2⟩ 是 CZ 的主角。
- **能量零点对齐 TwoQubit**：`cz_hamiltonian(p, 0)` 与 `TwoQubit(t1, t2, g_c).H` 逐项一致（差 < 1e-12）；
  时变部分只把「参考基态能」存成常数 `E2_ref` 每步减掉（只动对角元）。
- **相对传播子 `Urel = U·U_ref†`**（`U_ref` = 关掉 `g_c` 的**同一磁通脉冲**）：|11⟩ 的对角相位以
  ~13 GHz 旋转，直接取 `angle` 差分会一步步跨过 ±π → 去包裹完全错乱。参考相减后剩下的差分量级
  只有 MHz～百 MHz，既稳又正是实验上 spectator Ramsey 参考序列测到的东西。
- **虚拟 Z 校正 `cz_zcorrect`**：再减掉两个比特各自的单比特相位（`a = φ00−φ10`、`b = φ00−φ01`），
  之后 `P₁ = sin²(δφ/2)`、过程保真度才有意义；不校正时 `F_proc` 会被 13 GHz 残差打成一片。
- **条件 Bloch 矢量 = 条件相位本身**：`x = 2|v₀||v₁|cos φ_CZ(t)`，横向长度随泄漏收缩，
  「门不干净」在球面上直接看得见。
- **2π 单位坑**：能级组合给出的是频率（MHz），相位速率要乘 `2π`。本次踩过两次，回归里专门有一项
  「idle 条件相位速率 = −2π·(谱学 4 态组合)」。

### 16.2 新增演示 notebook

| 文件 | 主题 | 组件 |
| --- | --- | --- |
| `notebooks/cz_gate.jl` | CZ 实现原理：\|11⟩↔\|02⟩ avoided crossing、绝热/非绝热、波形边沿、条件 Bloch 旋转 | 能级扇形 + 磁通轨迹/相位累积 + 双 Bloch 球动画 + 相位 fringe + \|U_rel\|² 热图 + 8 步推导 + quiz |
| `notebooks/cz_calibration.jl` | CZ 校准方案：chevron 二维扫描、两条 fringe 精调、误差预算、参考序列 | chevron 热图（P₁）+ 泄漏热图 + 长度/幅度 fringe + 校准流程读数表 + 9 步推导 + quiz |

两页共用同一批滑块名（`ratio2`、`amp_phi`、`t_pulse`、`shape_sel`，见 `scripts/notebook_selftest.jl`
的 defaults）；chevron cell 只依赖器件参数，调脉冲滑块不会重算网格（保持交互流畅）。

### 16.3 验收链

- `scripts/validate_cz.jl`（新，28 项）：与 `TwoQubit` 的一致性（H、谱、恒定 H 布居对照
  `evolve_two_qubit`）、酉性、`g_c=0` ⟹ 条件相位恒 0、`H(Φ)` 偶对称、crossing 判据 `δ≈α₂`、
  idle ZZ 速率（含 2π）、理想 CZ 读数、条件 Bloch ≈ (−1,0,0)、步长收敛、方沿/平滑沿泄漏对比、
  chevron 网格与工作点自洽。
- 既有四项全部未回归：`validate.jl`（最大相对误差 4.58e-13）、`validate_dynamics.jl`、
  `validate_new.jl`、`notebook_selftest.jl`（9 个 notebook 全通过）。
- `spike/preview_any.jl` 无头渲染两页成功（`NB=cz_gate` / `NB=cz_calibration`）。

### 16.4 踩坑记录（本次，务必遵守）

1. **广播陷阱**：`A .-= A[1,1]` 会移矩阵所有元素，不是对角相减；要逐对角元减，或构造 `Diagonal`。
2. **结构跳变矩阵必须把 `E_J` 因子化**（存 −½，别存 −E_J/2），否则 `E_J(Φ)·Hop` 双重计数，
   表现为能级整体离谱（本次一度出现 −432 GHz 的「基态」）。
3. **相位必须取 `Urel` 的对角元**（`⟨c|U U_ref†|c⟩ = Σ_j U[c,j]U_ref[c,j]*`），
   **不能**写成 `U[c,c]·conj(Uref[c,c])`——脉冲期间 `U_ref` 在乘积基里并不对角，漏掉交叉项相位就错。
4. **`round(x, decimals=)` 不存在**，关键字是 `digits`（`decimals` 是 Python 的肌肉记忆）。
5. **不能事后改 axis dict**（`lay.xaxis.tickvals = ...` 报错）：需要新轴参数时直接构造
   `Layout(..., xaxis=attr(..., tickvals=..., ticktext=...))`（见 §13.5.5）。
6. **`push!` 只能对 trace 数组**：`PlotlyBase.heatmap(...)` 返回单个 trace，要 `push!` 进
   `PlotlyBase.GenericTrace[]` 再传给 `Plot`。
7. **range 字面量后接 `.*` 有优先级坑**：`0.4:0.1:1.0 .* phi` 解析成 `0.4:0.1:(1.0*phi)` → 空区间；
   必须写成 `(0.4:0.1:1.0) .* phi` 或 `collect(...)`。
8. **物理：idle 点必须比 crossing 高 |α|**。共振条件 `f01₁ = f01₂ + α₂`（α₂<0），而磁通只会减小
   `E_J`，所以可调比特的 idle 频率必须设得更高（本演示默认 `ratio2 = 1.2`）。
9. **「门」要在固定时间窗里定义**：脉冲结束回到 idle 后，always-on ZZ 仍以 `2π·(4 态组合)` 的速率
   继续累积条件相位（默认器件 ≈ 0.044 rad/ns → 100 ns 漂 4.4 rad）。`cz_evolve` 默认 `T_ns = 1.5 t_pulse`，
   读数一律在该窗口内取；这条要跟 ⑤ 的 ZZ 串扰串起来讲。
10. **泄漏随脉冲长度非单调**（Stückelberg 振荡），"越长越绝热"不能当通用断言；chevron 里的「暗」
    可能是泄漏造成的假暗——所以 ⑨ 同时画 P₁ 热图和泄漏热图。

---

## 16. 公式必须走 MathJax（2026-09-27）

Pluto 前端**只对 `class="tex"` 的元素**跑 MathJax（`CellOutput.js` 的
`MathJax.typeset(container.querySelectorAll(".tex"))` + `SetupMathJax.js` 的
`processHtmlClass: "tex"`）。所以公式一律用 `src/OverQubitViz.jl` 的
`tex(raw"...")`（行内 `\(...\)`）与 `texblock(raw"...")`（display `\[...\]`）。

五条纪律（详见 `ai/lessons.md` §7）：
1. 必须带 `class="tex"`；
2. 定界符用 `\(` `\)`，**不用 `$`**（与 Julia 字符串插值冲突）；
3. 含反斜杠的 LaTeX 用 `raw"..."`（`"\O"` 是 Julia 非法转义）；
4. **数学里不许出现中日韩字符**（MathJax 数学字体无 CJK 字形 → 静默缺字），中文放 math 外混排；
5. `derivation` 步骤是**三元组** `(操作, 公式, 说明)`。

9 个 notebook 的推导链已全部迁移（187 处 `.tex`）。
`notebook_selftest.jl` 的 `check_no_cjk_in_math` 负责防回归。

## 17. 标准化 Julia 包结构（2026-09-27）

仓库重构为**标准 Julia 包形式**（`Project.toml` + `src/` + `test/`），分层铁律不变。

### 17.1 新目录结构

```
OverQubit/
├── Project.toml            # name=OverQubit, uuid=db85b13b-…；deps：LinearAlgebra / PlotlyBase / PlutoUI / HypertextLiteral
├── src/
│   ├── OverQubit.jl        # 包入口：include 各文件 + 集中 export（物理 5 组 + 渲染层转出口）
│   ├── transmon.jl         # Transmon / 电荷基能谱 / charge_matrix_element / SQUID 磁通调谐
│   ├── readout.jl          # jc_chi / dispersive_params / s21 / steady_amplitude
│   ├── dynamics.jl         # driven_basis / evolve_density(_iq) / dissipator_super / SequenceEngine / evolve_segments
│   ├── two_qubit.jl        # coupled_hamiltonian / TwoQubit / exchange_rate / zz_rate / evolve_two_qubit
│   ├── cz.jl               # CZPair / cz_* 全家（磁通脉冲引擎 + 校准可观测量）
│   └── viz/OverQubitViz.jl # 渲染层（子模块 OverQubit.OverQubitViz；自包含，只依赖 PlotlyBase）
├── test/                   # runtests.jl + 按 src 文件一一对应的测试 + golden_transmon.jl（原 data/）
├── notebooks/              # 9 个 Pluto 演示（产品本体，include 相对路径加载包）
├── scripts/                # notebook_selftest.jl / preview_mvp0.jl / generate_golden.py
└── spike/                  # preview_any.jl / check_frames.jl（无头验证脚手架）
```

关键决策：

- **渲染层作为子模块**：`OverQubitViz` 从 src 根移到 `src/viz/`，由包入口 include 进来，
  `using .OverQubitViz` 后把渲染 API 一并 `export`——notebook 只需 `using .OverQubit` 一条。
  依赖代价是包 deps 增加 `PlotlyBase`（渲染层随包加载）；物理层"只依赖 LinearAlgebra"
  的铁律改述为"物理层文件不 import 渲染符号"（模块边界仍是硬边界）。
- **单包而非 workspace**：渲染层与物理层同包。两包 workspace（`packages/…`）更"纯"但会把
  notebook 的 include 路径和 Pluto 环境搞复杂，演示器规模不值得。
- **notebook 保持 include 相对路径**（不改为 `using OverQubit`）：Pluto notebook 环境独立，
  自包含的相对 include 不需要激活包环境，维持既有工作流。cell 加载代码从"两个 include +
  两个 using"缩为"一个 include + 一个 using"。
- **黄金向量数据移到 `test/`**（原 `data/golden_transmon.jl`），`generate_golden.py` 输出路径同步。

### 17.2 验证链迁移（scripts/validate*.jl → test/）

四个 validate 脚本的物理断言**全部无损迁移**为 `@testset`：

| 旧脚本 | 新测试文件 | 内容 |
| --- | --- | --- |
| `scripts/validate.jl` | `test/test_transmon.jl` | scqubits 黄金向量 8 点 + SQUID 磁通调谐 |
| `scripts/validate_dynamics.jl` | `test/test_readout.jl` + `test/test_dynamics.jl` | χ≈g²/Δ、S21；Rabi/泄漏/Bloch |
| `scripts/validate_new.jl` | `test/test_transmon.jl`（磁通）+ `test/test_dynamics.jl`（序列引擎）+ `test/test_two_qubit.jl` | 磁通调谐、π 脉冲/T1/T2/Ramsey/回波、iSWAP/ZZ |
| `scripts/validate_cz.jl` | `test/test_cz.jl` | CZ 引擎 6 组 32 项 |

运行方式：`julia --project=. -e 'using Pkg; Pkg.test()'`（101 项，约 4 分钟）；
单跑一组：`julia --project=. test/test_cz.jl`。**旧脚本已删除**，checklists 已同步。

顺带修掉一个 flaky 断言：iSWAP 动力学对比里 `argmax` 取峰位——sin² 的峰恰好是采样点，
浮点噪声会让 argmax 随机落到任意一个峰（相差整数个周期）。改为"前 1/3 时窗取 argmax"
（恰含第一个峰）。

### 17.3 无头工具的模块加载更新

`notebook_selftest.jl` / `spike/preview_any.jl` / `spike/check_frames.jl` 原先用
`include_string` 预载两个 src 文件；现在改为 `Base.include(mod, src/OverQubit.jl)`
（能正确解析包内部的 `include("viz/…")` 相对路径），`using .OverQubit, .OverQubitViz`
相应缩为 `using .OverQubit`。所有脚本一律 `julia --project=. ` 运行（老规矩）。
