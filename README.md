# OverQubit

面向初学者的**超导量子比特原理演示器**：以真实物理计算为唯一数据源，通过 Pluto 交互 notebook
讲清楚 S21 色散读取、单比特门、DRAG、T1/T2、两比特耦合、CZ 门校准等核心原理。
每个演示都带可溯源的公式推导、参数动画与自测 quiz。

## 项目结构（标准 Julia 包）

```
OverQubit/
├── Project.toml            # 包定义（deps / compat / test target）
├── src/
│   ├── OverQubit.jl        # 包入口：include 各模块 + 集中 export
│   ├── transmon.jl         # 电荷基 transmon 能谱 + SQUID 磁通调谐
│   ├── readout.jl          # 谐振器色散读取（JC χ / S21）
│   ├── dynamics.jl         # 驱动动力学（载波/旋转坐标系 + Lindblad）
│   ├── two_qubit.jl        # 两比特电容耦合（有效模型 + 全电荷基参照）
│   ├── cz.jl               # CZ 门引擎（磁通脉冲 + 校准可观测量）
│   └── viz/OverQubitViz.jl # 渲染层子模块（Plotly HTML 组件，不含物理）
├── test/                   # Pkg.test() 测试套件（含 scqubits 黄金向量）
├── notebooks/              # 9 个 Pluto 演示 notebook（产品本体）
├── scripts/                # 无头验证工具（notebook 自测、黄金向量生成）
├── spike/                  # 开发脚手架（预览、动画帧检查）
├── docs/                   # 设计文档（architecture.md 是唯一事实源）
└── ai/                     # AI 协作记录（踩坑/清单/会话日志）
```

分层铁律：**物理层只依赖 LinearAlgebra**；渲染层 `OverQubitViz` 不含物理，只把数据变成 HTML。
物理与渲染的 API 经 `OverQubit` 统一导出（渲染层是包的子模块，转出口见 `src/OverQubit.jl`）。

## 环境与安装

需要 Julia ≥ 1.10（在 [juliaup](https://github.com/JuliaLang/juliaup) 或官网安装）。

```powershell
cd OverQubit
julia --project=. -e 'using Pkg; Pkg.instantiate()'   # 首次：按 Manifest 安装依赖
```

依赖：`LinearAlgebra`（物理层）、`PlotlyBase` + `PlutoUI` + `HypertextLiteral`（notebook 与渲染层）。

## 快速开始

```powershell
julia --project=. -e 'using Pkg; Pkg.add("Pluto"); using Pluto; Pluto.run()'
```

在浏览器里打开 `notebooks/` 下任意 notebook，例如 `mvp0_transmon.jl`（能谱与波函数）、
`s21_readout.jl`（色散读取）、`cz_calibration.jl`（CZ 校准）。notebook 通过相对路径
`include("../src/OverQubit.jl")` 加载包模块，自包含、无需注册包。

## 测试

物理层回归测试（scqubits 黄金向量、Rabi/T1/T2/Ramsey 解析对照、iSWAP/ZZ、CZ 全链路）：

```powershell
julia --project=. -e 'using Pkg; Pkg.test()'        # 全部 101 项，约 4 分钟
julia --project=. test/test_transmon.jl             # 或单跑某一组
```

无头验证工具（改 notebook 排版时用）：

```powershell
julia --project=. scripts/notebook_selftest.jl      # 全部 notebook 逐 cell 求值 + 排版回归
julia --project=. spike/check_frames.jl             # 动画帧 traces 索引校验
$env:NB = "flux_tuning"; julia --project=. spike/preview_any.jl   # 静态预览页
```

## 文档

- [`docs/architecture.md`](docs/architecture.md) — 架构设计（唯一事实源）
- [`docs/01_调研报告_超导量子比特模拟可视化.md`](docs/01_调研报告_超导量子比特模拟可视化.md) 等前期调研
- [`ai/README.md`](ai/README.md) — AI 协作记录库索引（改代码前先扫 `ai/checklists.md`）

## 运行黄金向量再生成（可选）

`test/golden_transmon.jl` 由 scqubits 生成，一般不需重跑；确需时：

```powershell
python scripts/generate_golden.py    # 需要 python 环境 + scqubits
```
