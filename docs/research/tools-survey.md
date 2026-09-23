# 超导量子比特模拟与可视化工具调研报告

> 调研目的：为"制作一个直观展示超导量子比特模拟结果、帮助理解其原理的小软件"提供选型依据——判断是否需要自研，还是复用/组合已有工具。
> 调研日期：2026-09-22。所有事实均来自官方文档 / GitHub / PyPI 等公开来源，链接附于各节；无法核实的条目明确标注"未能验证"。

---

## 1. 需求基准（本报告所有判断的对照标准）

| 编号 | 需求维度 | 具体内容 |
| --- | --- | --- |
| R1 | 核心原理演示 | 由电路哈密顿量得到能级/跃迁；展示 flux 调谐；色散读出（χ）；简单动力学（Rabi、衰减）与脉冲序列 |
| R2 | 完整动力学 | Lindblad 主方程演化、Wigner 函数、Bloch 球等 |
| R3 | 交互性 | 可调电路参数并实时看到结果变化；界面面向学习者 |

---

## 2. 候选工具总览

| 工具 | 官方地址 | 许可证 | 最新版本 / 日期 | 维护状态 | Stars |
| --- | --- | --- | --- | --- | --- |
| scqubits | [GitHub](https://github.com/scqubits/scqubits) · [文档](https://scqubits.readthedocs.io) · [PyPI](https://pypi.org/project/scqubits/) | BSD-3-Clause | v4.3.1（2025-05-17） | 低活跃但仍在维护（main 近一年 2 次提交，2026-06 仍有推送） | 284 |
| QuTiP | [官网](https://qutip.org/) · [文档](https://qutip.readthedocs.io/en/stable/) · [GitHub](https://github.com/qutip/qutip) · [PyPI](https://pypi.org/project/qutip/) | BSD-3-Clause | 5.3.1（2026-08-04） | 活跃（2026-09 仍有 commit，版本节奏稳定） | 2077 |
| Qiskit Dynamics | [GitHub](https://github.com/qiskit-community/qiskit-dynamics) · [文档](https://qiskit-community.github.io/qiskit-dynamics/) · [PyPI](https://pypi.org/project/qiskit-dynamics/) | Apache-2.0 | 0.6.0（2025-10-07） | **已归档只读**（2025-10-31） | 未能验证 |
| Qiskit Experiments | [GitHub](https://github.com/qiskit-community/qiskit-experiments) · [文档](https://qiskit-community.github.io/qiskit-experiments/) | Apache-2.0 | 0.14.2（2026-08-25） | 活跃（2026-09-09 仍有 commit） | 未能验证 |
| SQcircuit | [主页/文档](https://sqcircuit.org) · [GitHub](https://github.com/stanfordLINQS/SQcircuit) · [PyPI](https://pypi.org/project/SQcircuit/) | BSD-3-Clause | v1.0.0（2024-08-16） | main 最后 commit 2024-08-27；dev-ew 分支 2026-08-28 有提交 | 56 |
| pyEPR | [GitHub](https://github.com/zlatko-minev/pyEPR) · [文档](https://pyepr-docs.readthedocs.io) · PyPI 包名 `pyEPR-quantum`（[PyPI](https://pypi.org/project/pyEPR-quantum/)，注意 PyPI 上的 `pyEPR` 是同名无关项目） | BSD-3-Clause | v1.0.1（2026-07-17） | 活跃（2026 年 94 commits） | 210 |
| QuSpin | [GitHub](https://github.com/QuSpin/QuSpin) · [文档](https://quspin.github.io/QuSpin/) · [PyPI](https://pypi.org/project/quspin/) | BSD-3-Clause | v1.0.1（2026-04-08） | 低-中活跃（最后 push 2026-04-10，84 open issues） | 338 |
| QuantumOptics.jl | [GitHub](https://github.com/qojulia/QuantumOptics.jl) · [文档](https://docs.qojulia.org) · [官网](https://qojulia.org) | MIT | v1.2.10（2026-09-11） | 活跃（2026-09 密集提交） | 625 |
| Qruise | [官网](https://qruise.com) · [文档](https://docs.qruise.com/latest) | 专有商业软件（申请 demo） | 文档版本 2026.08.0 | 核心代码未开源，release/commit 活跃度未能验证 | ≤1（公开周边仓库） |

> 排除说明：**QuCUN**（GitHub org `QuCun`）经查证为德国 BMBF"量子计算应用网络"联盟/社区，并非软件工具（0 个公开仓库），本报告不纳入比较。

---

## 3. 逐工具详情

### 3.1 scqubits —— 超导比特能谱专用库

- **物理能力（R1）**：内置 Transmon、TunableTransmon、Fluxonium、FluxQubit、ZeroPi、FullZeroPi、Cos2PhiQubit 及 Oscillator/KerrOscillator；`Circuit`/`SymbolicCircuit` 支持符号拉格朗日量搭建任意电路（`sym_lagrangian`、层级对角化）。`eigenvals`/`eigensys` 对角化求能级与跃迁；`get_spectrum_vs_paramvals`/`ParameterSweep`/`plot_evals_vs_paramvals` 做 flux 等参数扫描；ParameterSweep 计算 Lamb/ac-Stark/Kerr，`sweep["chi"]` 给色散位移；`matrixelement_table` 给跃迁矩阵元；各比特有 `t1`/`tphi` 类退相干估算。简单动力学与脉冲无内置求解器，官方文档明示配合 QuTiP `mesolve`/`mcsolve`（提供 `hamiltonian_for_qutip_dynamics` 与参数化含时驱动）。
- **可视化**：matplotlib 内置——能级 vs 参数图、transition spectrum、波函数/势能（1d/2d）、矩阵元热图。**无 Wigner、无 Bloch 球**（已核对源码模块与文档索引）。
- **交互性（R3）**：`scq.GUI()`（gui extra：ipywidgets + ipyvuetify）、`.widget()`、`HilbertSpaceUi`、Explorer 交互面板——调参即显，是三需求中交互性最强的候选。
- **学习成本**：User Guide + 官方 notebook + Binder；conda-forge/pip 安装；硬依赖含 qutip、sympy、scipy（偏重）。
- **结论**：R1 **满足**（"简单动力学与脉冲"部分满足，需 QuTiP）；R2 **不满足**；R3 **满足**。
- 来源：上述总览表内链接；未能验证项：GUI 实时刷新性能未实测。

### 3.2 QuTiP —— 通用量子动力学引擎

- **物理能力（R1）**：官方无 transmon/fluxonium 等内置比特类；提供任意时变哈密顿量 `QobjEvo` 与 `charge`/`tunneling`/`num` 等算子，可手工搭建电路哈密顿量并用 `eigenstates`/`eigenenergies` 对角化。flux 扫描需自行循环（有 `plot_energy_levels` 可画能级）；**色散 χ、读出/耦合参数无内置函数**（未能验证有官方实现）。
- **动力学（R2）**：`mesolve`（Lindblad 主方程）、`mcsolve`/`nm_mcsolve`（轨迹）、`brmesolve`、`ssesolve`、Floquet、`heomsolve`——Rabi、弛豫、退相干齐备。
- **可视化**：`plot_wigner`、`Bloch`（Bloch 球）、`plot_qfunc`、`plot_energy_levels` 及动画函数（Matplotlib）。**无内置 ipywidgets/GUI**。
- **学习成本**：`pip install qutip`，核心依赖 NumPy/SciPy，CPython 3.11–3.14 有 wheels；文档教程齐全，但示例偏量子光学表述，需自译为超导语境。
- **结论**：R1 **部分满足**；R2 **满足**；R3 **不满足**（需自行用 ipywidgets 封装）。

### 3.3 Qiskit Dynamics —— 脉冲级动力学（已归档）

- **物理能力（R1）**：`systems` 模块内置 `DuffingOscillator`（官方文档明确"a model of a transmon"，H=2πνN+παN(N-1)+驱动）、`IdealQubit`、`ExchangeInteraction`；`DressedBasis.from_hamiltonian` 可对角化取 dressed 能级。无 fluxonium/zero-pi 模板，**无 flux 扫描/χ 内置**。
- **动力学（R2）**：`HamiltonianModel`/`LindbladModel`（薛定谔与 Lindblad 主方程）、`Solver`/`DysonSolver`/`MagnusSolver`、RWA 与旋转帧；`DynamicsBackend` 做脉冲级仿真。**无内置 Wigner/Bloch 绘制**。
- **风险**：仓库 2025-10-31 已归档只读；且 qiskit.pulse 在 Qiskit 2.0 中移除，脉冲工作流受限。
- **结论**：R1 **部分满足**；R2 **部分满足**；R3 **不满足**。

### 3.4 Qiskit Experiments —— 真实器件表征库（定位偏离）

- 定位是真实硬件表征/校准：T1/T2Hahn/T2Ramsey/Tφ、RamseyXY、tomography、RB、QuantumVolume 等。**无电路哈密顿建模、无能谱、无 χ 工具、无主方程求解器**；可视化仅 CurvePlotter/IQPlotter。
- **结论**：R1/R2/R3 均**不满足**（对本需求价值有限，仅在未来接真机校准时有参考意义）。
- 来源：总览表内链接。

### 3.5 SQcircuit —— 任意约瑟夫森电路对角化

- **物理能力（R1）**：Capacitor/Inductor/Junction/Loop 通用元件搭任意电路；官方示例覆盖 fluxonium、flux qubit (3JJ+L)、0-π、kite、two-CPB 保护比特、inductively shunted（transmon 未出现在官方示例，但 API 支持电荷偏移）。`cr.diag(n_eig)` 对角化（导出为 QuTiP Qobj）；`Sweep.sweepFlux(..., plotF=True)` 内置 flux 扫描与能谱绘制；`coupling_op`/`matrix_elements` 给耦合算符与跃迁矩阵元；`dec_rate` 给 6 类噪声通道的 T1/Tφ。**未发现内置 χ 计算函数**（未能验证）。
- **动力学（R2）**：无内置求解器；论文明确其将耗散转换为速率与跳算符，配合 QuTiP 自行做主方程。
- **可视化**：内置能谱-vs-flux 图与波函数相位坐标图；**无 Wigner/Bloch；无交互控件**。
- **学习成本**：快速教程 + 用户指南 + 6 个复现文献的 notebook；依赖偏重（torch≥2.0、qutip≥5.0 等）。
- **结论**：R1 **部分满足**；R2 **部分满足**；R3 **不满足**。

### 3.6 pyEPR —— EPR 方法提取多模哈密顿量

- **物理能力（R1）**：EPR 方法提取多模约瑟夫森哈密顿量，用 QuTiP 数值对角化（Fock/cos 截断）得 dressed 频率、非谐 α 与 χ 矩阵（`get_chi_O1` 微扰 / `get_chi_ND` 数值）。支持 transmon 与 fluxonium（精确余弦势、自定义 V(φ)）；扫 HFSS 变量或纯数值变体做 flux 调谐，`plot_hamiltonian_results` 输出频率/Q/α/χ vs 扫描变量图；含介质损耗→T1 估算。**不含脉冲/动力学**（源码无 mesolve/mcsolve/Lindblad）。
- **可视化**：仅 matplotlib/seaborn 静态图；无 Wigner/Bloch/GUI。
- **交互性**：Jupyter/Binder 可调参重跑，但无实时控件。
- **学习成本**：7 个教程 notebook + 视频 + 无 HFSS 纯数值路径；依赖中等偏重；完整 HFSS 工作流需 Ansys 商业授权（COM 仅 Windows，v0.9.6 起 PyAEDT gRPC 跨平台）。
- **结论**：R1 **满足**（不含脉冲/动力学部分）；R2 **不满足**；R3 **部分满足**。

### 3.7 QuSpin —— 多体精确对角化与动力学

- **物理能力（R1）**：定位任意玻色/费米/自旋系统，**无超导电路内置模型**（全文检索 transmon/fluxonium/circuit 均 0 命中）；可对自建哈密顿量精确对角化；flux 扫描、χ 均无内置。
- **动力学（R2）**：Schrödinger 实时演化（evolve/Lanczos）；主方程以"密度矩阵 + matvec"方式支持（官方示例 17、27）；量子轨迹支持未能验证。
- **可视化**：**无内置绘图函数**，无 Wigner/Bloch/GUI。
- **结论**：R1 **部分满足**；R2 **部分满足**；R3 **不满足**。

### 3.8 QuantumOptics.jl —— Julia 生态通用框架

- **物理能力（R1）**：通用量子光学框架，无超导比特内置模型；内置 `ChargeBasis`/`ShiftedChargeBasis`（Cooper-pair 电荷基，适合 CPB/transmon 电荷区）与 Fock/Spin/NLevel 基；可对角化任意哈密顿量。flux 扫描无专用函数；**χ 无内置**（API 中 `ChiMatrix` 是过程层析矩阵，非色散位移）。
- **动力学（R2）**：`timeevolution.master/mcwf/stochastic/bloch_redfield/semiclassical`——Lindblad、量子轨迹、Rabi/弛豫/退相干齐备；`timecorrelations.spectrum` 可算谱。
- **可视化**：内置 Makie 函数 `blochsphereplot`/`wignerplot`/`fockdistributionplot`/`wavefunctionplot`，GL/WGLMakie 下**可交互旋转缩放**；无滑杆/GUI 生态。
- **学习成本**：需 Julia 基础（≥1.10）；依赖 SciML/DiffEq 全家桶，预编译较重；教程与示例 notebook 齐全。
- **结论**：R1 **部分满足**；R2 **满足**；R3 **部分满足**。

### 3.9 Qruise —— 商业脉冲平台（定位偏离）

- 专有商业软件，仅支持 transmon（freq/anhar/flux_range/t1/t2、dispersive_shift 作为**输入参数**），无电路哈密顿量→对角化→能谱/χ 的计算；有 Schrödinger/von Neumann/Lindblad 与最优控制；可视化返回 xarray Dataset 自行绘制；交互靠 QruiseOS Web Dashboard（面向硬件团队）。
- **结论**：R1 **部分满足**；R2 **部分满足**；R3 **部分满足**（但为部署型商业平台，非轻量教学工具）。

---

## 4. 对照矩阵

| 工具 | R1 核心原理演示 | R2 完整动力学 | R3 交互性 | 维护风险 |
| --- | --- | --- | --- | --- |
| scqubits | **满足**（动力学需 QuTiP） | 不满足 | **满足**（GUI/widgets/Explorer） | 低活跃但维护中 |
| QuTiP | 部分满足 | **满足** | 不满足 | 低（活跃） |
| Qiskit Dynamics | 部分满足 | 部分满足 | 不满足 | **高（已归档）** |
| Qiskit Experiments | 不满足 | 不满足 | 不满足 | 低（但定位偏离） |
| SQcircuit | 部分满足 | 部分满足 | 不满足 | 中（main 停更，dev 分支活跃） |
| pyEPR | **满足**（无动力学） | 不满足 | 部分满足 | 低（活跃） |
| QuSpin | 部分满足 | 部分满足 | 不满足 | 中 |
| QuantumOptics.jl | 部分满足 | **满足** | 部分满足（Makie 可交互图） | 低（活跃） |
| Qruise | 部分满足 | 部分满足 | 部分满足 | 商业闭源，不可控 |

**读法**：没有任何单一工具同时满足 R1+R2+R3；scqubits 是唯一 R1 与 R3 双满足的开源工具，但其动力学与 Wigner/Bloch 缺失，官方设计上就是交给 QuTiP。

---

## 5. 结论：是否需要再制作一个？

**物理内核不需要自研；"小软件"需要自研一个薄外壳。**

1. **能谱与原理演示（R1）**：`scqubits` 已完整覆盖（电路哈密顿量→能级/flux 调谐/χ/退相干估算），且自带 GUI/widgets 交互层——这是全网最贴近需求的现成实现，重写它没有收益。
2. **完整动力学（R2）**：`QuTiP` 是事实标准（主方程/轨迹/Wigner/Bloch 全内置，BSD-3，活跃维护），且 scqubits 官方即设计为与 QuTiP 组合（`hamiltonian_for_qutip_dynamics`）。
3. **缺口恰好在"软件形态"本身**：scqubits 的交互面向"会写 Python 的研究者"（Jupyter + ipywidgets），而目标用户是**学习者**——需要的是"打开即用、参数滑杆、结果图联动、无需配 Python 环境"的统一界面。现成工具给不了这一层；QuTiP 的 Wigner/Bloch 动态演示也需要自己拼装。
4. **因此建议**：以 `scqubits + QuTiP` 为计算引擎，自研一个面向学习者的薄交互应用（外壳），而不是从零自研物理代码，也不是直接把 Jupyter  notebook 当作交付物。若最终选择"零安装、浏览器打开"的形态，则需评估引擎在轻量部署上的代价（见待决策问题 Q1）。

> 该结论的详细落地（功能清单、技术栈比选、模块划分、里程碑）见 `docs/research/dev-plan.md`。

---

## 6. 待与用户共同决策的架构问题清单

> 以下问题不做单方面裁决，每个问题附可选方案与权衡，供后续一起探讨。

**Q1. 交付形态：桌面/本地 Web 应用，还是纯浏览器应用？**
- A. 本地 Python 应用（如 PyQt/Gradio/marimo 桌面壳）：直接复用 scqubits+QuTiP 全部能力，开发最快；代价是用户仍需 Python 环境或打包体积大。
- B. 浏览器应用（前端 + 本地/远程 Python 后端）：体验好、零安装；代价是需要后端服务或 WASM 移植（scqubits/QuTiP 暂无成熟 WASM 构建，移植工作量未验证）。
- C. 混合：教学演示页用预计算/简化模型（JS），深度模拟走本地 Python 引擎。

**Q2. 物理引擎的依赖边界：依赖 scqubits+QuTiP，还是内置简化模型？**
- A. 完整依赖（pip 安装两者）：能力最全，与社区同步；代价是安装包重、启动慢。
- B. 仅依赖 QuTiP，比特模型自己写（transmon/fluxonium 的 4-6 能级截断模型代码量有限）：可控、轻；代价是重复实现 scqubits 已有功能。
- C. 内置纯简化模型（如 Duffing 振子解析/小矩阵数值解，纯前端可跑）：零依赖、最轻；代价是只能演示有限原理。

**Q3. 交互范式的核心隐喻：参数滑杆 + 联动图表面板，还是"场景/故事线"导览？**
- A. 导览式（固定 5-8 个原理场景，每场景一页：能谱/色散/Rabi 等，步骤化讲解）：对学习者最友好，开发范围可控。
- B. 自由探索式（完整参数面板 + 任意扫描/对比）：上限高，但界面复杂度和开发量大。
- C. 两者分层：导览为默认层，"高级模式"展开自由面板。

**Q4. 技术栈方向：Python 栈还是 Julia/JS 栈？**
- A. Python（scqubits+QuTiP 生态原生）：生态最匹配，人才与资料最多。
- B. Julia（QuantumOptics.jl，MIT，Makie 交互图）：Wigner/Bloch 交互图原生、性能好；代价是生态小、超导模型需自建。
- C. 纯 JS/TS 前端 + 简化数值内核：零安装体验最好；代价是物理能力最弱（见 Q2-C）。

---

## 7. 附：调研方法与可信度说明

- 每个工具的版本、日期、许可证、能力结论均来自其官方文档/GitHub/PyPI 页面（链接见正文），检索日期 2026-09-22。
- "未能验证"条目：Qiskit Dynamics/Experiments 的 star 数（GitHub 反爬）、SQcircuit 的 χ 内置函数、QuTiP 的 χ 官方实现、QuSpin 量子轨迹、Qruise 核心代码活跃度、Q1-B 中 WASM 移植工作量。
- QuCUN 经查证非软件工具，已排除；Qiskit Experiments 与 Qruise 定位偏离本需求，保留记录但不作为主候选。
