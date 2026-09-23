### A Pluto.jl notebook ###
# v0.20.10

using Markdown

# ╔═╡ 1
begin
	using PlutoUI, PlotlyBase, Statistics
	include(joinpath(@__DIR__, "..", "src", "OverQubit.jl"))
	using .OverQubit
end

# ╔═╡ 2
md"""
# OverQubit · 超导量子比特原理 · MVP-0：transmon 电荷基对角化

**动手目标**：改变 transmon 的两个核心参数（\$E_J\$、\$E_C\$）和偏移电荷 \$n_g\$，亲眼看到：

1. 势阱 \$V(\\varphi) = -E_J\\cos\\varphi\$ 中「住」着量子化能级（不是经典小球）
2. 能级非等间距 → 非谐性 \$\\alpha\$，这是「只有两个能级好用」的根源
3. 改变 \$n_g\$ 时能级几乎不动 → transmon 对 charge noise 免疫的原因

> 本页所有数字来自 `src/OverQubit.jl` 的电荷基对角化
> （\$H = 4E_C(\\hat n - n_g)^2 - E_J\\cos\\varphi\$），
> 该实现已通过 scqubits v4.3.1 黄金向量回归验证（8 个参数点，最大相对误差 ~5e-13）。
"""

# ╔═╡ 3
md"### ① 调参（拖动滑块，全页自动重算）"

# ╔═╡ 4
@bind EJ Slider(5:0.5:50; default=20)

# ╔═╡ 5
@bind EC Slider(0.05:0.01:0.5; default=0.30)

# ╔═╡ 6
@bind ng Slider(-1:0.01:1; default=0.0)

# ╔═╡ 7
begin
	NCUT = 80
	t = Transmon(EJ, EC; ncut=NCUT)
	E = eigenenergies(t, ng)
	f01, f12 = f01_f12(t, ng)
	α = f12 - f01
	phis, psi2 = wavefunctions(t, ng, 3, 300)
	# 解析极限对照（Koch et al. 2007, 大 E_J/E_C 极限）
	koch_f01 = EC * (sqrt(8 * EJ / EC) - 1)
	# 展示用字符串（插值只用简单变量，规避字符串插值解析陷阱）
	EJ_EC_str = string(round(EJ / EC, digits=1))
	f01_str = string(round(f01, digits=4))
	f12_str = string(round(f12, digits=4))
	alpha_str = string(round(α, digits=4))
	koch_str = string(round(koch_f01, digits=4))
end

# ╔═╡ 8
Markdown.parse("""
**当前读数**

| 量 | 数值 |
|---|---|
| \$E_J/E_C\$ | $EJ_EC_str |
| \$f_{01}\$ | **$f01_str GHz**（解析极限对照 $koch_str GHz） |
| \$f_{12}\$ | $f12_str GHz |
| \$\\alpha = f_{12}-f_{01}\$ | **$alpha_str GHz**（\$\\approx -E_C\$，transmon 的「非谐性」） |

> 提示：把 \$E_J/E_C\$ 拖小（如 \$E_C=0.5\$、\$E_J=5\$），\$|\\alpha|\$ 绝对值变大、势阱变浅，cos 势的谐波近似失效。
""")

# ╔═╡ 9
begin
	# 电势阱 + 能级 + |ψ|²（垂直平移 E_J 使势阱底与能级同一零点）
	s = 0.30 * (E[2] - E[1]) / maximum(psi2)
	V = potential.(t, phis) .+ EJ
	Esh = E .+ EJ
	traces = PlotlyBase.GenericTrace[]
	push!(traces, PlotlyBase.scatter(x=phis, y=V; name="V(φ) = −E_J cos φ", line=attr(color="black", width=2)))
	for k in 1:3
		push!(traces, PlotlyBase.scatter(x=phis, y=fill(Esh[k], length(phis)); mode="lines",
			line=attr(dash="dash", color="gray"), name="E$(k-1)", showlegend=false))
		push!(traces, PlotlyBase.scatter(x=phis, y=psi2[k, :] * s .+ Esh[k]; fill="tozeroy",
			line=attr(color="rgba(80,80,220,0.45)"), name="|ψ$(k-1)|²"))
	end
	PlotlyBase.Plot(traces,
		Layout(title="势阱、能级与波函数密度（n_g = $(ng)）", xaxis_title="相位 φ (rad)",
			yaxis_title="能量（相对零点，GHz）", height=620, legend=attr(orientation="h")))
end

# ╔═╡ 10
begin
	ngs, Es = charge_dispersion(t, 81, 3)
	e01s = Es[:, 2] .- Es[:, 1]
	e12s = Es[:, 3] .- Es[:, 2]
	band_MHz = (maximum(e01s) - minimum(e01s)) * 1000
	band_str = string(round(band_MHz, digits=4))
	p2 = PlotlyBase.Plot([
		PlotlyBase.scatter(x=ngs, y=(e01s .- mean(e01s)) * 1000; mode="lines", name="f01(n_g)"),
		PlotlyBase.scatter(x=ngs, y=(e12s .- mean(e12s)) * 1000; mode="lines", name="f12(n_g)"),
	],
		Layout(title="电荷色散：f01(n_g)（transmon 几乎完全平坦）", xaxis_title="偏移电荷 n_g",
			yaxis_title="相对均值 (MHz)", height=560, legend=attr(orientation="h")))
end

# ╔═╡ 11
Markdown.parse("""
### ② 原理要点

**为什么能级是量子化的？** 约瑟夫森结给出余弦势阱 \$V(\\varphi) = -E_J\\cos\\varphi\$；相位 \$\\varphi\$ 对应库珀对的集体位移。\$E_J\$ 越大势阱越深越「硬」（频率 ↑），\$E_C\$ 是充电能，决定量子涨落 \$\\varphi_{\\mathrm{zpf}} \\propto (2E_C/E_J)^{1/4}\$。

**为什么非等间距？** 势阱不是抛物线——cos 势的高阶项使能级间距随能级数下降。\$E_{01}\$ 与 \$E_{12}\$ 之差即非谐性 \$\\alpha \\approx -E_C\$（大 \$E_J/E_C\$ 极限）。\$|2\\rangle\$ 若与 \$|1\\rangle\$ 等距，驱动 \$|0\\rangle \\leftrightarrow |1\\rangle\$ 就会漏到 \$|2\\rangle\$——\$|\\alpha|\$ 就是「两能级系统」存在的物理基础（DRAG 演示会用到）。

**为什么对 \$n_g\$ 不敏感？** \$E_C\$ 大时电荷本征态铺开、隧穿 \$E_J\$ 抹平了 \$n_g\$ 依赖——量子涨落反而带来鲁棒性。下面色散图的带宽只有 **$band_str MHz** 量级；作为对比，把 \$E_C\$ 拖大 \$E_J\$ 拖小重看此图（Cooper-pair box 区域）。

> 推导溯源：电路量子化 → 电荷基哈密顿量 → 对角化，见后续接入的共享推导库（M4）。
""")
