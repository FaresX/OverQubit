# OverQubit 架构设计文档

> 状态：已定稿（2026-09-22，与用户共同确认）。本文档是后续开发的唯一事实源；需求变更时先改本文档再改代码。
> 上游依据：`docs/research/tools-survey.md`（工具选型）、`docs/research/dev-plan.md`（薄壳方案）。

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
| 5 | 两比特门 | two_qubit | circuit_diagram, energy_diagram, bloch_player | 双比特 H→dressed 谱→条件相位 | M2 |
| 6 | CZ 校准 | two_qubit | pulse_timeline, chevron_map(SSE), sweep_chart | 交换→chevron→相位校准 | M3 |
| 7 | transmon 谱与电荷色散 | transmon | sweep_chart, energy_diagram | transmon H→电荷色散 | M4 |
| 8 | T1/T2 退相干 | dynamics | bloch_player, sweep_chart, population_bars | Lindblad→T1/T2→自旋回波 | M4 |
| 9 | Purcell 与测量反作用 | resonator + dynamics | sweep_chart, population_bars | input-out→Purcell 率→反作用 | M4 |
| 10 | iSWAP 与 ZZ 串扰 | two_qubit | population_bars, energy_diagram, sweep_chart | 耦合振子→iSWAP 振荡→ZZ | M4 |

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
### M3：CZ 校准（SSE 异步 chevron 长任务 + 进度条）
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

## 12. 显式排除（本期不做）

真机控制/校准（Qiskit Experiments 域）、任意用户自定义电路（SQcircuit 域）、量子极限放大器、多比特网络。这些在 backlog 评审时再议。
