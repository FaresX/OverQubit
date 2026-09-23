# 开发规划：超导量子比特原理演示小软件（薄壳方案）

> 本规划依据《超导量子比特模拟与可视化工具调研报告》（`docs/research/tools-survey.md`）的结论制定：**物理内核不自研**（scqubits 覆盖 R1 与 R3，QuTiP 覆盖 R2，BSD-3 许可可商用/再分发），**自研面向学习者的交互外壳**。
> 规划日期：2026-09-22。架构层面的最终取舍留给用户决策（见第 6 节），本文给推荐默认路径与备选方案。

---

## 1. 一句话定位

一个"打开就能玩"的超导量子比特原理演示器：选一种比特（transmon / fluxonium / 0-π…）→ 拖滑杆改参数（Ej、Ec、外部 flux、驱动幅度/频率）→ 实时看到能谱、波函数、χ、Rabi/衰减曲线、Wigner/Bloch 动画，每个画面配一两句原理讲解。

目标用户：量子方向学生/初学者/科普展示。非目标：替代 scqubits 做科研级参数扫描、替代 Qiskit 做真机控制（该方向可行但明确不做）。

---

## 2. 复用方式（引擎集成路径）

```bash
pip install scqubits qutip    # 均为 BSD-3-Clause
```

```python
import scqubits as scq
tmon = scq.TunableTransmon(EJ=20.0, EC=0.3, d=0.0, ng=0.0, ncut=30)
evals = tmon.eigenvals(evals_count=5)          # 哈密顿量 → 能级/跃迁
sweep = scq.ParameterSweep(...)                # flux 扫描；sweep["chi"] → 色散位移
H = tmon.hamiltonian_for_qutip_dynamics(...)   # 交给 QuTiP
```

- **R1（原理演示）**：全部来自 scqubits（能谱、flux 扫描、χ、退相干估算、波函数）。
- **R2（动力学）**：`qutip.mesolve` 做主方程演化，`qutip.plot_wigner` / `qutip.Bloch` 出图。
- **R3（交互）**：scqubits 自带 GUI/widgets 仅作参考实现（面向研究者），产品交互层自研。

---

## 3. 功能清单与优先级

### P0 —— 最小可用产品（证明"值得存在"）

| # | 功能 | 对应需求 | 引擎来源 |
| --- | --- | --- | --- |
| 1 | 比特选择与参数面板（transmon、fluxonium；Ej/Ec/电容/flux） | R1 | scqubits |
| 2 | 能级 vs flux 能谱图（跃迁标注、可缩放能级数） | R1 | scqubits |
| 3 | 波函数与势能图（随 flux 联动） | R1 | scqubits 内置绘图改写 |
| 4 | 色散 χ vs flux 曲线 | R1 | scqubits ParameterSweep |
| 5 | 简单动力学：Rabi 与 T1 衰减时间演化曲线 | R1/R2 | QuTiP mesolve |

### P1 —— 教学价值放大

| # | 功能 | 对应需求 |
| --- | --- | --- |
| 6 | Wigner 函数动画（演化过程逐帧） | R2 |
| 7 | Bloch 球动画（配合 Rabi/衰减） | R2 |
| 8 | 导览模式：5-8 个原理场景（如"为什么 transmon 对 charge noise 不敏感""fluxonium 的重正化"），每场景 = 预设参数 + 联动图 + 讲解文本 | R1/R3 |
| 9 | 结果导出（图片 PNG、参数快照 JSON、曲线数据 CSV） | R3 |

### P2 —— 增强（明确可砍）

| # | 功能 |
| --- |
| 10 | 更多比特类型（ZeroPi、FluxQubit、Cos2Phi 等 scqubits 已支持，接入成本低） |
| 11 | 高阶演示：非谐驱动的能级混合、避免交叉演示 |
| 12 | 打包为单文件可执行程序（PyInstaller onedir）或 Docker 镜像分发 |

明确不做：真机控制/校准（Qiskit Experiments 领域）、任意用户自定义电路求解（SQcircuit 领域）、多比特耦合网络、科研级参数扫描导出工具链。

---

## 4. 技术栈比选（三个方向的取舍）

> 共同基础：引擎 = scqubits + QuTiP（不变）；差异只在外壳形态。

| 维度 | 方向 A：本地 Python 应用（推荐） | 方向 B：浏览器应用 | 方向 C：纯前端简化模型 |
| --- | --- | --- | --- |
| 形态 | marimo（响应式 notebook，像 App）或 Gradio/Streamlit；或 PyQt 桌面壳 | Web 前端（Svelte/React + Plotly/Three.js）+ 本地 Python 后端（FastAPI） | 纯 JS/TS，数值内核自写（Duffing/截断小矩阵） |
| 能力 | **完整 R1+R2+R3**，直接调用全部引擎 | 完整能力（经后端），但多一层架构 | 仅简化原理（Duffing、4 能级、公式化 χ），无精确 fluxonium 势 |
| 安装/分发 | 需 Python 环境；可 PyInstaller 打包（体积大，含 scipy/sympy） | 前端零安装；后端仍需 Python（除非 WASM） | **零安装、最轻**，任何人浏览器打开即用 |
| 开发速度 | **最快**（周级出原型） | 中（前后端拆分、异步/缓存设计） | 中（物理内核重写，且能力打折） |
| 实时性 | 滑杆→重算，取决于缓存设计 | 同左，多网络/序列化开销 | **最好**（小矩阵毫秒级） |
| 风险 | 体积与启动速度；非程序员用户安装门槛 | WASM 移植 scqubits/QuTiP **工作量未能验证**，是最大不确定项 | 物理正确性风险：简化模型何时失效需严格标注 |

**推荐默认路径**：先按方向 A 做出 P0+P1（周级迭代、风险最低），同时保留方向 B 作为二期"零安装版"的演进方向；方向 C 只作为 P2 的网页演示彩蛋，不作为主干。

**备选引擎说明**：若倾向 Julia 栈（QuantumOptics.jl，MIT，Makie 交互图原生支持 Bloch 球/Wigner 旋转），可作为方向 A 的变体，代价是超导比特模型需自建、生态较小。

---

## 5. 模块划分与里程碑

### 模块划分（方向 A 假设）

```
app/
├─ scenes/        # 教学场景定义：参数预设 + 讲解文本 + 画面编排（P1-8 核心）
├─ panels/        # 参数面板（滑杆、下拉、复位）
├─ engine/        # 引擎适配层：统一 simulate() 接口，屏蔽 scqubits/QuTiP 细节
│   ├─ spectrum.py    # 能级/flux 扫描/χ（scqubits）
│   ├─ wavefunction.py# 波函数/势能
│   └─ dynamics.py    # mesolve 时间演化 + Wigner/Bloch 帧生成
├─ viz/           # 绘图层：统一图表风格、图例/标注规范、导出
├─ cache/         # 重算缓存（参数分档、预计算 P0 曲线）
└─ app.py         # 入口与布局（marimo notebook 或 Gradio Blocks）
```

### 里程碑（按方向 A，每周 5 个工作日估算）

| 里程碑 | 内容 | 出口判据 |
| --- | --- | --- |
| M1（第 1-2 周） | P0-1/2/4：参数面板 + 能谱 vs flux + χ 曲线最小闭环 | 改 flux/Ej 滑杆，能谱图 <2s 内刷新；画面标注能级与跃迁 |
| M2（第 2-3 周） | P0-3/5：波函数联动 + Rabi/T1 动力学曲线 | 驱动参数改变后 Rabi 曲线形状变化符合预期；T1 输入与曲线衰减一致 |
| M3（第 4 周） | P1-6/7/8：Wigner/Bloch 动画 + 导览模式第一版（3 个场景） | 三个场景可从头播放到尾，讲解与画面同步 |
| M4（第 5 周） | P1-9 导出 + 打磨 + 验收 | 通过第 6 节定义的验收清单 |

---

## 6. 风险清单

| # | 风险 | 影响 | 缓解 |
| --- | --- | --- | --- |
| 1 | scqubits 维护低活跃（main 近一年仅 2 次提交，见调研报告 3.1） | 长期 bug 无人修 | 锁定版本号；本地 fork 存档；只在 P1 使用其稳定 API |
| 2 | flux 全扫描重算延迟（数百参数点 × 对角化） | 交互卡顿 | 能级数默认 5 以内；参数分档缓存；异步预计算；M1 出口判据强制 <2s |
| 3 | QuTiP 主方程维度随截断能级指数增长 | Rabi 演示慢 | 默认 4-6 能级截断并在界面标注"截断近似" |
| 4 | 打包体积（scipy/sympy/qutip） | 分发门槛 | PyInstaller onedir；或提供 `environment.yml` + 启动脚本；Web 化放二期 |
| 5 | 许可证合规 | 法务 | scqubits/QuTiP 均 BSD-3，允许闭源再分发，随包保留 LICENSE 与版权声明 |
| 6 | 教学准确性 | 误导学习者 | 每个场景的物理结论与教科书/原始论文对照评审；界面对简化/截断处显式标注 |
| 7 | 未验证项：WASM/Browser 移植工作量；scqubits GUI 实时刷新性能 | 二期范围估价不准 | 二期启动前先做 1 周技术 spike 再排期 |
| 8 | SQcircuit 不引入（其 torch≥2.0 依赖显著增重） | — | 仅 P2 若需任意电路再评估 |

---

## 7. 待与用户共同决策的架构问题清单（规划侧）

> 以下问题不做单方面裁决；调研报告另有 Q1-Q4 四个形态问题（交付形态/依赖边界/交互范式/技术栈），本清单聚焦立项与执行层面。

**Q5. 应用框架选型：marimo、Gradio/Streamlit，还是 PyQt 桌面壳？**
- A. marimo：响应式 notebook，最接近"像 App 的 notebook"，Python 用户易改易分享
- B. Gradio/Streamlit：UI 脚手架最快，社区 demo 多；布局自由度较低
- C. PyQt/PySide：最像传统桌面软件、可打包分发体验好；开发量最大

**Q6. 分发方式：**
- A. `pip/conda` 环境 + 启动脚本（开发者友好）
- B. PyInstaller onedir 打包（普通用户友好，体积数百 MB）
- C. Docker 镜像（跨平台一致，普通用户门槛高）
- D. 先不做分发，仅本地运行（P0/P1 阶段）

**Q7. 验收标准：如何证明"帮助理解原理"？**
- A. 场景清单制：第 6 节导览场景全部可播放，且每场景附 2-3 个"学习者应能回答的问题"
- B. 小范围用户测试：找 3-5 名目标用户试用并收集反馈后迭代
- C. A+B（推荐）：清单保底 + 用户试用打磨

**Q8. 范围边界：是否预留"未来接真机/校准数据"的接口？**
- A. 不预留，保持纯粹教学工具（推荐，范围最可控）
- B. 数据层预留导入 CSV（Qiskit Experiments 输出的 T1/T2/χ 实测值）做"理论 vs 实测"对比演示
- C. 二期直接集成 Qiskit Experiments 工作流

---

## 8. 与调研报告的衔接

- 本规划的所有能力判断、维护状态、许可证事实以 `docs/research/tools-survey.md` 为准；两文档的待决策问题（Q1-Q8）合起来就是"架构与形态"探讨的完整议程。
- 建议下一步：我们先过一遍 Q1-Q8，确定形态与框架后，将本规划中对应分支固化为正式开发计划，再启动 M1。
