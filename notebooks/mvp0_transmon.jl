### A Pluto.jl notebook ###
# v0.20.10

using Markdown

# ╔═╡ c0000000-0000-4000-8000-000000000001
begin
	using PlutoUI, PlotlyBase, Statistics, HypertextLiteral
	include(joinpath(@__DIR__, "..", "src", "OverQubit.jl"))
	include(joinpath(@__DIR__, "..", "src", "OverQubitViz.jl"))
	using .OverQubit, .OverQubitViz
end

# ╔═╡ c0000000-0000-4000-8000-000000000002
@htl("""
<div style="background:linear-gradient(100deg,#EEF1FF 0%,#F6F2FF 60%,#EFFBF8 100%);border-radius:14px;padding:20px 26px;margin:2px 0 10px 0">
<div style="font-size:12px;letter-spacing:2px;color:#7B61FF;font-weight:600">OVERQUBIT · MVP-0</div>
<div style="font-size:24px;font-weight:700;color:#1A1A2E;margin-top:4px">超导量子比特原理 · transmon 电荷基对角化</div>
<div style="color:#5A6182;margin-top:8px;font-size:14px">拖动滑块，看势阱里「住」着的量子化能级如何随 E<sub>J</sub>、E<sub>C</sub>、n<sub>g</sub> 变化</div>
</div>
<div style="font-size:15px;margin:4px 2px">
<div style="font-weight:700;font-size:17px;color:#1A1A2E">动手目标：亲眼看到三件事</div>
<ol style="color:#33384D;line-height:1.9">
<li>势阱 <i>V</i>(φ) = −E<sub>J</sub>&#8202;cos&#8202;φ 中「住」着量子化能级（不是经典小球）</li>
<li>能级非等间距 → 非谐性 α，这是「只有两个能级好用」的根源</li>
<li>改变 n<sub>g</sub> 时能级几乎不动 → transmon 对 charge noise 免疫的原因</li>
</ol>
<div style="background:#F4F6FF;border-radius:8px;padding:10px 14px;margin-top:10px;font-size:13px;color:#5A6182">
本页所有数字来自 <code>src/OverQubit.jl</code> 的电荷基对角化（<i>H</i> = 4E<sub>C</sub>(n̂ − n<sub>g</sub>)<sup>2</sup> − E<sub>J</sub>&#8202;cos&#8202;φ），
已通过 scqubits v4.3.1 黄金向量回归验证（8 个参数点，最大相对误差 ~5e-13）。
</div>
</div>
""")

# ╔═╡ c0000000-0000-4000-8000-000000000003
concept_cards([
("约瑟夫森结", "超导结给出余弦势能 −E<sub>J</sub>cos&#8202;φ：相位 φ 是库珀对的集体坐标，<i>I</i> = <i>I</i><sub>c</sub>sin&#8202;φ。E<sub>J</sub> = <i>ħI</i><sub>c</sub>/2e——势阱深度。"),
("充电能 E<sub>C</sub>", "把一个库珀对搬上岛需要付出 4E<sub>C</sub>(n−n<sub>g</sub>)² 的电能（n 是库珀对数，n<sub>g</sub> 是栅极偏置）。E<sub>C</sub> = e²/2C——势阱的「动能刻度」。"),
("相位与电荷的不确定性", "[φ̂, n̂] = i → Δφ·Δn ≥ 1/2。E<sub>J</sub>/E<sub>C</sub> 决定谁占上风：大比值 → φ 钝化（charge noise 免疫），小比值 → 经典电荷态。"),
])

# ╔═╡ c0000000-0000-4000-8000-000000000004
md"### ③ 调参（拖动滑块，全页自动重算）"

# ╔═╡ c0000000-0000-4000-8000-000000000005
@bind EJ Slider(5:0.5:50; default=20)

# ╔═╡ c0000000-0000-4000-8000-000000000006
@bind EC Slider(0.05:0.01:0.5; default=0.30)

# ╔═╡ c0000000-0000-4000-8000-000000000007
@bind ng Slider(-1:0.01:1; default=0.0)

# ╔═╡ c0000000-0000-4000-8000-000000000008
begin
	NCUT = 80
	t = Transmon(EJ, EC; ncut=NCUT)
	E = eigenenergies(t, ng)
	f01, f12 = f01_f12(t, ng)
	α = f12 - f01
	phis, psi2 = wavefunctions(t, ng, 3, 300)
	koch_f01 = EC * (sqrt(8 * EJ / EC) - 1)      # 解析极限（Koch 2007）
	phi_zpf = (2EC / EJ)^0.25
	# 经典小球（RK4，真实能量守恒方程 φ̈ = −8E_CE_J sin φ）
	function classical_ball(tmax, nfr)
		φb = zeros(nfr); nb = zeros(nfr)
		φ, n = 0.7, 0.0
		h = tmax / (10 * nfr)
		ν = 8 * EC
		for k in 1:(10 * nfr)
			a1, b1 = ν * n, -EJ * sin(φ)
			a2, b2 = ν * (n + h / 2 * b1), -EJ * sin(φ + h / 2 * a1)
			a3, b3 = ν * (n + h / 2 * b2), -EJ * sin(φ + h / 2 * a2)
			a4, b4 = ν * (n + h * b3), -EJ * sin(φ + h * a3)
			φ += h / 6 * (a1 + 2a2 + 2a3 + a4)
			n += h / 6 * (b1 + 2b2 + 2b3 + b4)
			if mod1(k, 10) == 1
				φb[div(k - 1, 10) + 1] = φ
				nb[div(k - 1, 10) + 1] = n
			end
		end
		φb, nb
	end
	omega_ho = sqrt(8 * EC * EJ)
	T_class = 2π / omega_ho
	φb, nb = classical_ball(2.2 * T_class, 48)
	# 展示用字符串（插值只用简单变量）
	EJ_EC_str = string(round(EJ / EC, digits=1))
	f01_str = string(round(f01, digits=4))
	f12_str = string(round(f12, digits=4))
	alpha_str = string(round(α, digits=4))
	koch_str = string(round(koch_f01, digits=4))
	zpf_str = string(round(phi_zpf, digits=3))
	oh_str = string(round(omega_ho, digits=3))
end

# ╔═╡ c0000000-0000-4000-8000-000000000009
@htl("""
<div style="border:1px solid rgba(76,111,255,0.18);border-radius:12px;padding:8px 16px 14px 16px;background:#FBFBFF">
<table style="border-collapse:collapse;width:100%;font-size:15px">
<tr style="color:#7B61FF;font-size:12px;letter-spacing:1px"><th align="left">量</th><th align="left">数值</th></tr>
<tr><td style="padding:7px 0;border-top:1px solid rgba(20,24,60,0.08)">E<sub>J</sub>/E<sub>C</sub>（势阱深度）</td><td style="border-top:1px solid rgba(20,24,60,0.08)"><b style="color:#4C6FFF">$(EJ_EC_str)</b>　<span style="color:#8A90AD;font-size:12px">≳50 即 transmon 区</span></td></tr>
<tr><td style="padding:7px 0;border-top:1px solid rgba(20,24,60,0.08)">f<sub>01</sub>（|0⟩ → |1⟩）</td><td style="border-top:1px solid rgba(20,24,60,0.08)"><b style="color:#1A1A2E;font-size:17px">$(f01_str) GHz</b>　<span style="color:#8A90AD;font-size:12px">Koch 极限 $(koch_str) GHz</span></td></tr>
<tr><td style="padding:7px 0;border-top:1px solid rgba(20,24,60,0.08)">f<sub>12</sub>（|1⟩ → |2⟩）</td><td style="border-top:1px solid rgba(20,24,60,0.08)">$(f12_str) GHz</td></tr>
<tr><td style="padding:7px 0;border-top:1px solid rgba(20,24,60,0.08)">α = f<sub>12</sub> − f<sub>01</sub>（非谐性）</td><td style="border-top:1px solid rgba(20,24,60,0.08)"><b style="color:#7B61FF;font-size:17px">$(alpha_str) GHz</b>　<span style="color:#8A90AD;font-size:12px">≈ −E<sub>C</sub></span></td></tr>
<tr><td style="padding:7px 0;border-top:1px solid rgba(20,24,60,0.08)">φ<sub>zpf</sub>（相位零点涨落）</td><td style="border-top:1px solid rgba(20,24,60,0.08)">$(zpf_str)　<span style="color:#8A90AD;font-size:12px">∝ (2E<sub>C</sub>/E<sub>J</sub>)<sup>1/4</sup></span></td></tr>
<tr><td style="padding:7px 0;border-top:1px solid rgba(20,24,60,0.08)">谐波近似频率 ω<sub>ho</sub></td><td style="border-top:1px solid rgba(20,24,60,0.08)">$(oh_str) GHz　<span style="color:#8A90AD;font-size:12px">经典小球的摆动频率（见下方动画）</span></td></tr>
</table>
</div>
<div style="background:#FFF8EC;border-left:4px solid #F5A623;border-radius:6px;padding:10px 14px;margin-top:10px;color:#6B5A2E;font-size:13px">
试试把 E<sub>J</sub>/E<sub>C</sub> 拖小（如 E<sub>C</sub>=0.5、E<sub>J</sub>=5）：|α| 变大、势阱变浅，cos 势的谐波近似失效——这就是 Cooper-pair box 区。
</div>
""")

# ╔═╡ c0000000-0000-4000-8000-00000000000a
begin
	# 主图 + 动画：势阱、能级、|ψ|² + 经典小球 + 量子波函数「呼吸」
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
	ann = Any[]
	for k in 1:3
		push!(ann, attr(x=π, y=Esh[k], text="E$(k-1)", showarrow=false, xanchor="left",
			font=attr(size=12, color=PAL[k])))
	end
	push!(ann, attr(x=-2.35, y=Esh[2], ax=-2.85, ay=(Esh[1] + Esh[2]) / 2, text="f01", showarrow=true,
		arrowcolor=PAL[1], arrowwidth=1.6, font=attr(size=12, color=PAL[1])))
	push!(ann, attr(x=-2.35, y=Esh[3], ax=-2.85, ay=(Esh[2] + Esh[3]) / 2, text="f12", showarrow=true,
		arrowcolor=PAL[2], arrowwidth=1.6, font=attr(size=12, color=PAL[2])))
	# 动画帧：经典小球沿势阱滑动（能量守恒轨迹，RK4 真算）
	nfr = length(φb)
	frames = PlotlyBase.PlotlyFrame[]
	for k in 1:nfr
		φk = φb[k]
		vball = -EJ * cos(φk) + EJ
		push!(frames, frame(name=string(k), data=[
			PlotlyBase.scatter(x=[φk], y=[vball]; mode="markers",
				marker=attr(size=13, color="#FF7A7A", line=attr(color="white", width=2)),
				showlegend=false, hoverinfo="skip"),
		]))
	end
	push!(traces, PlotlyBase.scatter(x=[φb[1]], y=[-EJ * cos(φb[1]) + EJ]; mode="markers",
		marker=attr(size=13, color="#FF7A7A", line=attr(color="white", width=2)), showlegend=false))
	pmain = PlotlyBase.Plot(traces,
		layout_base(height=640, title="势阱、能级与波函数密度（红球=经典粒子，对比量子化）", updatemenus=animation_menu(),
			xtitle="相位 φ (rad)", ytitle="能量（相对零点，GHz）", annotations=ann),
		frames)
	plotly_html("oq_main", pmain; height=650)
end

# ╔═╡ c0000000-0000-4000-8000-00000000000b
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
	ymin = minimum(e01s) - 0.15 * (maximum(e12s) - minimum(e12s) + 1e-9)
	ymax = maximum(e12s) + 0.15 * (maximum(e12s) - minimum(e12s) + 1e-9)
	push!(tr, PlotlyBase.scatter(x=[ng, ng], y=[ymin, ymax]; mode="lines",
		name="当前 n_g", line=attr(color=PAL[4], width=2, dash="dot")))
	pdisp = PlotlyBase.Plot(tr,
		layout_base(height=520, title="电荷色散：f01(n_g) —— transmon 几乎完全平坦（橙线=当前 n_g）",
			xtitle="偏移电荷 n_g", ytitle="相对均值 (MHz)"))
	plotly_html("oq_disp", pdisp; height=530)
end

# ╔═╡ c0000000-0000-4000-8000-00000000000c
derivation("⑤ 推导溯源：从约瑟夫森电路到能级",
[
("定义", "<i>L</i> = (C/2)(ħφ̇/2e)² + E<sub>J</sub>&#8202;cos&#8202;φ<br>即 <i>L</i> = (Cħ²/8e²)φ̇² + E<sub>J</sub>&#8202;cos&#8202;φ", "并联约瑟夫森电路：电容储能 (C/2)V² 用 V = (ħ/2e)φ̇ 换成相位速度；结给出 −E<sub>J</sub>cos&#8202;φ。"),
("代入", "Q = ∂<i>L</i>/∂φ̇ = (Cħ²/4e²)φ̇　→　<i>H</i> = Q²/(2Cħ²/4e²) − E<sub>J</sub>&#8202;cos&#8202;φ = 4E<sub>C</sub> n² − E<sub>J</sub>&#8202;cos&#8202;φ，n ≡ Q/2e", "勒让德变换换到哈密顿量；定义无量纲电荷 n（库珀对数算符的期望）。"),
("定义", "[φ̂, n̂] = i<br><i>Ĥ</i> = 4E<sub>C</sub>(n̂ − n<sub>g</sub>)² − E<sub>J</sub>&#8202;cos&#8202;φ̂", "量子化：相位与电荷成共轭对易量；栅极偏置以 n<sub>g</sub> 平移进入。E<sub>C</sub> = e²/2C。"),
("代入", "电荷基：n̂|n⟩ = n|n⟩，cos&#8202;φ̂ = ½(δ<sub>n,n+1</sub> + δ<sub>n,n−1</sub>)<br>→ H<sub>nn</sub> = 4E<sub>C</sub>(n−n<sub>g</sub>)²，H<sub>n,n±1</sub> = −E<sub>J</sub>/2", "e<sup>±iφ</sup> 只在相邻电荷态间移动一个库珀对 → 三对角矩阵（本页所有数字都来自对它的对角化）。"),
("近似", "截断 |n| ≤ n<sub>cut</sub>（本页 n<sub>cut</sub> = 80），数值对角化 → E<sub>0</sub>, E<sub>1</sub>, … 与本征矢", "低能级对 n<sub>cut</sub> 收敛极快；黄金向量验收证实 n<sub>cut</sub>=50 已达机器精度。"),
("微扰", "cos&#8202;φ ≈ 1 − φ²/2 + φ⁴/24，谐波近似 → ω<sub>ho</sub> = √(8E<sub>J</sub>E<sub>C</sub>)（即经典小球的摆动频率）；<br>φ⁴ 项做一级微扰 → 非谐性 α = E<sub>12</sub> − E<sub>01</sub> ≈ −E<sub>C</sub>", "势阱底部近似抛物线给出均匀能级间距，四次项把它「压弯」——这就是非等间距的来源。"),
("微扰", "ω<sub>01</sub> ≈ √(8E<sub>J</sub>E<sub>C</sub>) − E<sub>C</sub>　（Koch 2007 解析极限）<br>φ<sub>zpf</sub> = (2E<sub>C</sub>/E<sub>J</sub>)<sup>1/4</sup>", "本页读数卡的「Koch 对照」就是它；两者在 E<sub>J</sub>/E<sub>C</sub> ≳ 50 时吻合到 ~0.2%。"),
("整理", "n<sub>g</sub> 依赖 ∝ e<sup>−√(8E<sub>J</sub>/E<sub>C</sub>)</sup> → 指数压低", "电荷色散图的带宽随 E<sub>J</sub>/E<sub>C</sub> 指数塌缩——transmon 对 charge noise 免疫的定量理由。"),
];
lead="每一步都可点开。从经典电路出发，到本页所有数字的来源——电荷基三对角矩阵。",
result="对照读数卡：f<sub>01</sub> = $(f01_str) GHz 与 Koch 极限 $(koch_str) GHz 相差 $(string(round(100 * abs(f01 - koch_f01) / f01, digits=2)))%；α = $(alpha_str) GHz ≈ −E<sub>C</sub> = $(string(round(-EC, digits=3))) GHz。")

# ╔═╡ c0000000-0000-4000-8000-00000000000d
tryout([
("势阱变浅会发生什么", "把 E<sub>C</sub> 拖到 0.5、E<sub>J</sub> 拖到 5（E<sub>J</sub>/E<sub>C</sub> = 10）。",
 "|α| 明显增大（不再是 −E<sub>C</sub> 那么简单）、能级间距分布「歪」得厉害、读数卡的 Koch 对照偏差飙到 10% 以上——谐波近似失效，系统进入 Cooper-pair box 区。"),
("亲手验证 charge noise 免疫", "E<sub>J</sub>=20、E<sub>C</sub>=0.3 时拖 n<sub>g</sub> 从 −1 到 1。",
 "f<sub>01</sub> 几乎纹丝不动（色散图带宽 ~10⁻³ MHz 量级）；把 E<sub>J</sub> 拖到 5 再拖 n<sub>g</sub>，带宽立刻变大几个量级。"),
("看懂经典小球与量子态的差别", "点上方动画的「播放」，观察红球在势阱底来回摆动，对比虚线能级与蓝紫色 |ψ|² 分布。",
 "经典小球可以停在任意能量、在转折点速度为零；量子态只能「住」在离散能级上，且 |ψ|² 在转折点外不为零（隧穿尾巴）。红球的摆动频率正是 ω<sub>ho</sub> = $(oh_str) GHz。"),
])

# ╔═╡ c0000000-0000-4000-8000-00000000000e
@htl("""
<div style="font-size:14.5px;color:#33384D;line-height:2.0;margin-top:6px">
<p><b>为什么能级是量子化的？</b>　相位 φ 是库珀对的集体位移，被「锁」在余弦势阱里。约束运动 → 离散谱。E<sub>J</sub> 越大势阱越深越「硬」（f<sub>01</sub> ↑），E<sub>C</sub> 越大越「软」且量子涨落 φ<sub>zpf</sub> 越大。</p>
<p><b>为什么非等间距？</b>　势阱不是抛物线。四次项使间距随能级数下降（推导第 6 步），差值就是 α。|α| 是「两能级近似」合法性的唯一保证——驱动 |0⟩↔|1⟩ 时若 |2⟩ 等距就会漏到 |2⟩，DRAG 演示将正面处理这个泄漏。</p>
<p><b>为什么对 n<sub>g</sub> 不敏感？</b>　电荷本征态被隧穿 E<sub>J</sub> 抹平成「相位确定态」，n<sub>g</sub> 的影响指数压低（推导第 8 步）——量子涨落反而带来鲁棒性。</p>
<p><b>下一步去哪：</b><b>单比特门</b>演示怎么用电磁驱动在这些能级间「打转」；<b>色散读取</b>演示怎么隔着谐振子「看见」量子态。</p>
</div>
""")

# ╔═╡ Cell order:
# ╟─c0000000-0000-4000-8000-000000000001
# ╠═c0000000-0000-4000-8000-000000000002
# ╠═c0000000-0000-4000-8000-000000000003
# ╟─c0000000-0000-4000-8000-000000000004
# ╟─c0000000-0000-4000-8000-000000000005
# ╟─c0000000-0000-4000-8000-000000000006
# ╟─c0000000-0000-4000-8000-000000000007
# ╟─c0000000-0000-4000-8000-000000000008
# ╠═c0000000-0000-4000-8000-000000000009
# ╟─c0000000-0000-4000-8000-00000000000a
# ╟─c0000000-0000-4000-8000-00000000000b
# ╠═c0000000-0000-4000-8000-00000000000c
# ╠═c0000000-0000-4000-8000-00000000000d
# ╠═c0000000-0000-4000-8000-00000000000e
