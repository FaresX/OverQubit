### A Pluto.jl notebook ###
# v0.20.10

using Markdown

# ╔═╡ 1
begin
	using PlutoUI, PlotlyBase, Statistics
	include(joinpath(@__DIR__, "..", "src", "OverQubit.jl"))
	using .OverQubit

	# —— 视觉主题（与 spike/mvp0_preview.html 保持一致）——
	const PAL = ["#4C6FFF", "#7B61FF", "#22C3A6", "#F5A623"]      # E0/E1/E2/当前值
	const PAL_FILL = ["rgba(76,111,255,0.13)", "rgba(123,97,255,0.13)", "rgba(34,195,166,0.13)"]
	const INK = "#1A1A2E"; const SUB = "#5A6182"
	const GRID = "rgba(20,24,60,0.06)"; const AXIS = "rgba(20,24,60,0.22)"
	const FONT = "-apple-system,'Segoe UI','PingFang SC','Microsoft YaHei',sans-serif"
end

# ╔═╡ 2
Markdown.parse("""
<div style="background:linear-gradient(100deg,#EEF1FF 0%,#F6F2FF 60%,#EFFBF8 100%);border-radius:14px;padding:20px 26px;margin:2px 0 10px 0">
<div style="font-size:12px;letter-spacing:2px;color:#7B61FF;font-weight:600">OVERQUBIT · MVP-0</div>
<div style="font-size:24px;font-weight:700;color:#1A1A2E;margin-top:4px">超导量子比特原理 · transmon 电荷基对角化</div>
<div style="color:#5A6182;margin-top:8px;font-size:14px">拖动滑块，看势阱里「住」着的量子化能级如何随 \$E_J\$、\$E_C\$、\$n_g\$ 变化</div>
</div>

**动手目标**：亲眼看到三件事——

1. 势阱 \$V(\\varphi) = -E_J\\cos\\varphi\$ 中「住」着量子化能级（不是经典小球）
2. 能级非等间距 → 非谐性 \$\\alpha\$，这是「只有两个能级好用」的根源
3. 改变 \$n_g\$ 时能级几乎不动 → transmon 对 charge noise 免疫的原因

> 本页所有数字来自 `src/OverQubit.jl` 的电荷基对角化
> （\$H = 4E_C(\\hat n - n_g)^2 - E_J\\cos\\varphi\$），
> 该实现已通过 scqubits v4.3.1 黄金向量回归验证（8 个参数点，最大相对误差 ~5e-13）。
""")

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
<div style="border:1px solid rgba(76,111,255,0.18);border-radius:12px;padding:6px 14px 12px 14px;background:#FBFBFF">
<table style="border-collapse:collapse;width:100%;font-size:15px">
<tr style="color:#7B61FF;font-size:12px;letter-spacing:1px"><th align="left">量</th><th align="left">数值</th></tr>
<tr><td style="padding:6px 0;border-top:1px solid rgba(20,24,60,0.08)">\$E_J/E_C\$（势阱深度）</td><td style="border-top:1px solid rgba(20,24,60,0.08)"><b style="color:#4C6FFF">$EJ_EC_str</b></td></tr>
<tr><td style="padding:6px 0;border-top:1px solid rgba(20,24,60,0.08)">\$f_{01}\$（|0⟩→|1⟩ 跃迁）</td><td style="border-top:1px solid rgba(20,24,60,0.08)"><b style="color:#1A1A2E;font-size:17px">$f01_str GHz</b>　<span style="color:#8A90AD;font-size:12px">解析极限对照 $koch_str GHz</span></td></tr>
<tr><td style="padding:6px 0;border-top:1px solid rgba(20,24,60,0.08)">\$f_{12}\$（|1⟩→|2⟩ 跃迁）</td><td style="border-top:1px solid rgba(20,24,60,0.08)">$f12_str GHz</td></tr>
<tr><td style="padding:6px 0;border-top:1px solid rgba(20,24,60,0.08)">\$\\alpha = f_{12}-f_{01}\$（非谐性）</td><td style="border-top:1px solid rgba(20,24,60,0.08)"><b style="color:#7B61FF;font-size:17px">$alpha_str GHz</b>　<span style="color:#8A90AD;font-size:12px">\$\\approx -E_C\$</span></td></tr>
</table>
</div>

<div style="background:#FFF8EC;border-left:4px solid #F5A623;border-radius:6px;padding:10px 14px;margin-top:10px;color:#6B5A2E;font-size:13px">
试试把 \$E_J/E_C\$ 拖小（如 \$E_C=0.5\$、\$E_J=5\$）：\$|\\alpha|\$ 变大、势阱变浅，cos 势的谐波近似失效——这就是 Cooper-pair box 区。
</div>
""")

# ╔═╡ 9
begin
	# 电势阱 + 能级 + |ψ|² + 跃迁标注（垂直平移 E_J 使势阱底与能级同一零点）
	s = 0.30 * (E[2] - E[1]) / maximum(psi2)
	V = potential.(t, phis) .+ EJ
	Esh = E .+ EJ
	traces = PlotlyBase.GenericTrace[]
	push!(traces, PlotlyBase.scatter(x=phis, y=V; name="势阱 V(φ)", mode="lines",
		line=attr(color="#2C3E50", width=2.5), fill="tozeroy", fillcolor="rgba(44,62,80,0.05)"))
	for k in 1:3
		push!(traces, PlotlyBase.scatter(x=phis, y=fill(Esh[k], length(phis)); mode="lines",
			line=attr(dash="dash", color=PAL[k], width=1.5), name="E$(k-1)", showlegend=false))
		push!(traces, PlotlyBase.scatter(x=phis, y=psi2[k, :] * s .+ Esh[k]; fill="tozeroy",
			line=attr(color=PAL[k], width=1.4), fillcolor=PAL_FILL[k], name="|ψ$(k-1)|²", showlegend=false))
	end
	ann = Any[]   # PlotlyBase.attr 是函数不是类型，不能用 attr[] 构造空数组
	for k in 1:3   # 能级标签
		push!(ann, attr(x=π, y=Esh[k], text="E$(k-1)", showarrow=false, xanchor="left",
			font=attr(size=12, color=PAL[k])))
	end
	push!(ann, attr(x=-2.35, y=Esh[2], ax=-2.85, ay=(Esh[1] + Esh[2]) / 2, text="f01", showarrow=true,
		arrowcolor=PAL[1], arrowwidth=1.6, font=attr(size=12, color=PAL[1])))
	push!(ann, attr(x=-2.35, y=Esh[3], ax=-2.85, ay=(Esh[2] + Esh[3]) / 2, text="f12", showarrow=true,
		arrowcolor=PAL[2], arrowwidth=1.6, font=attr(size=12, color=PAL[2])))
	PlotlyBase.Plot(traces,
		Layout(title=attr(text="势阱、能级与波函数密度（n_g = $(ng)）", font=attr(size=16, color=INK)),
			xaxis=attr(title="相位 φ (rad)", gridcolor=GRID, zerolinecolor=AXIS, linecolor=AXIS,
				tickfont=attr(size=11, color=SUB)),
			yaxis=attr(title="能量（相对零点，GHz）", gridcolor=GRID, zerolinecolor=AXIS, linecolor=AXIS,
				tickfont=attr(size=11, color=SUB)),
			font=attr(family=FONT), plot_bgcolor="white", paper_bgcolor="white",
			margin=attr(l=64, r=56, t=60, b=52), height=620, annotations=ann,
			legend=attr(orientation="h", y=1.10, x=0, bgcolor="rgba(0,0,0,0)", font=attr(size=11, color=SUB))))
end

# ╔═╡ 10
begin
	ngs, Es = charge_dispersion(t, 81, 3)
	e01s = Es[:, 2] .- Es[:, 1]
	e12s = Es[:, 3] .- Es[:, 2]
	band_MHz = (maximum(e01s) - minimum(e01s)) * 1000
	band_str = string(round(band_MHz, digits=4))
	tr = PlotlyBase.GenericTrace[]
	push!(tr, PlotlyBase.scatter(x=ngs, y=(e01s .- mean(e01s)) * 1000; mode="lines",
		name="f01(n_g)", line=attr(color=PAL[1], width=2.5)))
	push!(tr, PlotlyBase.scatter(x=ngs, y=(e12s .- mean(e12s)) * 1000; mode="lines",
		name="f12(n_g)", line=attr(color=PAL[2], width=2.5)))
	# 当前 n_g 游标（随滑块动，让"平坦"可见）
	ymin = min(minimum(e01s), minimum(e12s)) - 0.15 * (maximum(e12s) - minimum(e12s) + 1e-9)
	ymax = max(maximum(e01s), maximum(e12s)) + 0.15 * (maximum(e12s) - minimum(e12s) + 1e-9)
	push!(tr, PlotlyBase.scatter(x=[ng, ng], y=[ymin, ymax]; mode="lines",
		name="当前 n_g", line=attr(color=PAL[4], width=2, dash="dot")))
	p2 = PlotlyBase.Plot(tr,
		Layout(title=attr(text="电荷色散：f01(n_g) —— transmon 几乎完全平坦", font=attr(size=16, color=INK)),
			xaxis=attr(title="偏移电荷 n_g", gridcolor=GRID, zerolinecolor=AXIS, linecolor=AXIS,
				tickfont=attr(size=11, color=SUB)),
			yaxis=attr(title="相对均值 (MHz)", gridcolor=GRID, zerolinecolor=AXIS, linecolor=AXIS,
				tickfont=attr(size=11, color=SUB)),
			font=attr(family=FONT), plot_bgcolor="white", paper_bgcolor="white",
			margin=attr(l=64, r=32, t=60, b=52), height=560,
			legend=attr(orientation="h", y=1.10, x=0, bgcolor="rgba(0,0,0,0)", font=attr(size=11, color=SUB))))
end

# ╔═╡ 11
Markdown.parse("""
---

### ② 原理要点

**为什么能级是量子化的？** 约瑟夫森结给出余弦势阱 \$V(\\varphi) = -E_J\\cos\\varphi\$；相位 \$\\varphi\$ 对应库珀对的集体位移。\$E_J\$ 越大势阱越深越「硬」（频率 ↑），\$E_C\$ 是充电能，决定量子涨落 \$\\varphi_{\\mathrm{zpf}} \\propto (2E_C/E_J)^{1/4}\$。

**为什么非等间距？** 势阱不是抛物线——cos 势的高阶项使能级间距随能级数下降。\$E_{01}\$ 与 \$E_{12}\$ 之差即非谐性 \$\\alpha \\approx -E_C\$（大 \$E_J/E_C\$ 极限）。\$|2\\rangle\$ 若与 \$|1\\rangle\$ 等距，驱动 \$|0\\rangle \\leftrightarrow |1\\rangle\$ 就会漏到 \$|2\\rangle\$——\$|\\alpha|\$ 就是「两能级系统」存在的物理基础（DRAG 演示会用到）。

**为什么对 \$n_g\$ 不敏感？** \$E_C\$ 大时电荷本征态铺开、隧穿 \$E_J\$ 抹平了 \$n_g\$ 依赖——量子涨落反而带来鲁棒性。上面色散图的带宽只有 **$band_str MHz** 量级（橙色虚线是你当前的 \$n_g\$）；作为对比，把 \$E_C\$ 拖大 \$E_J\$ 拖小重看此图（Cooper-pair box 区域）。

> 推导溯源：电路量子化 → 电荷基哈密顿量 → 对角化，见后续接入的共享推导库（M4）。
""")
