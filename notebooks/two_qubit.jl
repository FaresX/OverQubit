### A Pluto.jl notebook ###
# v0.20.10

using Markdown

# ╔═╡ f0000000-0000-4000-8000-000000000001
begin
	using PlutoUI, PlotlyBase, Statistics, HypertextLiteral
	include(joinpath(@__DIR__, "..", "src", "OverQubit.jl"))
	using .OverQubit
	setup_page()
end

# ╔═╡ f0000000-0000-4000-8000-000000000002
md"""### ① 这一页讲什么：两个比特怎么「说话」"""

# ╔═╡ f0000000-0000-4000-8000-000000000003
banner("OVERQUBIT · 两比特", "iSWAP 与 always-on ZZ：耦合双 transmon",
	"电容耦合让两个 transmon 交换激发（iSWAP）；非谐性又让它们互相推移频率（ZZ）——量子门既要用它，也要防它"; icon="pair")

# ╔═╡ f0000000-0000-4000-8000-000000000004
lesson_nav([
	("①", "transmon 能级与量子化", "done"),
	("②", "单比特门与 Rabi", "done"),
	("③", "DRAG 泄漏压制", "done"),
	("④", "色散读取 S21", "done"),
	("⑤", "两比特耦合与 iSWAP", "current"),
	("⑥", "磁通调谐与能级扇形图", "todo"),
	("⑦", "T1 / T2 / Ramsey", "done"),
])

# ╔═╡ f0000000-0000-4000-8000-000000000005
concept_cards([
	("耦合从哪来", "结间电容 C_c 的库仑能 H_int = g_c·n̂₁n̂₂（g_c ∝ e²/C_c）。投影到两能级后 n̂ → n₀₁σ_x，于是 H_int = J(σ_x₁σ_x₂) = J(σ⁺σ⁻ + σ⁻σ⁺)/2 + J(σ⁺σ⁺ + σ⁻σ⁻)/2：前一半交换激发，后一半推频率。"),
	("iSWAP 振荡", "交换项让 |01⟩ ↔ |10⟩ 以速率 J 振荡：$(tex(raw"P_{10}(t)=\frac{4J^2}{\delta^2+4J^2}\sin^2\!\big(\sqrt{\delta^2+4J^2}\,t/2\big)"))。δ=0 时 t = π/(2J) 完全换位——这就是 iSWAP 门；δ≠0 时换不干净。"),
	("always-on ZZ", "counter-rotating 项 + 非谐性让 |1,1⟩ vs |0,1⟩ 能级移动不对称 → qubit1 的频率取决于 qubit2 在哪个态：ZZ = f(q1|q2=1) − f(q1|q2=0)。它永远开着，是 spectator / 串扰误差的根源。"),
	("CZ 为什么难", "两比特门要「只在对方是 |1⟩ 时给自己加相位」。always-on ZZ 帮了忙也添了乱：真实 CZ 用磁通脉冲把两个比特拖过 avoided crossing，让 |11⟩ 累积 2π 相位——本页的能级扇形图就是它的操作台。"),
])

# ╔═╡ f0000000-0000-4000-8000-000000000006
callout("本页用<b>能级截断有效模型</b>（每个比特取 3 个能级，n̂ 投影到本征子空间，与 ② 的 driven_basis 同一来源）；同时提供<b>全电荷基联合对角化</b>作为精确参照（读数卡的交叉验证）。默认两比特略有失谐——真实器件也总是这样。",
	tone="info", title="阅读前提")

# ╔═╡ f0000000-0000-4000-8000-000000000007
md"""### ③ 调参（两个 transmon + 耦合，全部真实计算）

`det2` 是第二个比特的相对失谐（EJ₂ = EJ·(1 − det2)），`g_c` 是结间库仑耦合（GHz）。"""

# ╔═╡ f0000000-0000-4000-8000-000000000008
@bind EJ Slider(8:0.5:40; default=20)

# ╔═╡ f0000000-0000-4000-8000-000000000009
@bind EC Slider(0.15:0.01:0.45; default=0.30)

# ╔═╡ f0000000-0000-4000-8000-00000000000a
@bind g_c Slider(0.0:0.005:0.20; default=0.05)

# ╔═╡ f0000000-0000-4000-8000-00000000000b
@bind det2 Slider(-0.06:0.005:0.06; default=0.03)

# ╔═╡ f0000000-0000-4000-8000-00000000000c
@bind T1q Slider(5:5:60; default=30)

# ╔═╡ f0000000-0000-4000-8000-00000000000d
begin
	NCUT = 40
	t1 = Transmon(EJ, EC; ncut=NCUT)
	t2 = Transmon(EJ * (1 - det2), EC; ncut=NCUT)
	TQ = TwoQubit(t1, t2, g_c; nlev=3)
	J = exchange_rate(TQ)                       # iSWAP 交换率 (GHz)
	ZZ = zz_rate(TQ)                            # always-on ZZ (GHz)
	f01_1 = f01_f12(t1, 0.0)[1]
	f01_2 = f01_f12(t2, 0.0)[1]
	δ_dev = bare_detuning(TQ)                   # 当前失谐 (GHz)
	α1_ = f01_f12(t1, 0.0)[2] - f01_1
	n01 = abs(charge_matrix_element(t1, 0, 1))
	# 交叉验证：全电荷基联合对角化（ncut 相同），|01⟩/|10⟩ 劈裂 = 2J
	evfull = coupled_spectrum(t1, t2, g_c, 0.0)
	dv = [evfull.values[i + 1] - evfull.values[i] for i in 1:6]
	J_full = abs(dv[2]) / 2                     # 第一对劈裂（= f01 附近的 2J）
	# iSWAP 时间网格（3 个半周期）
	Tiswap = J > 1e-6 ? π / (2J) : 1.0
	psi0 = zeros(TQ.nlev^2); psi0[basis_index(TQ, 0, 1)] = 1.0      # |0,1⟩
	times = collect(range(0.0, 3 * Tiswap; length=420))
	_, pop, b1, b2 = evolve_two_qubit(TQ, psi0, times)
	_, popD, _, _ = evolve_two_qubit(TQ, psi0, times; gamma1=1 / (T1q * 1000))
	# 完全共振对照（EJ₂ = EJ₁）
	TQ0 = TwoQubit(t1, t1, g_c; nlev=3)
	J0 = exchange_rate(TQ0)
	times0 = collect(range(0.0, 3 * π / (2J0); length=420))
	_, pop0, _, _ = evolve_two_qubit(TQ0, psi0, times0)
	f01_s = string(round(f01_1, digits=3)); f012_s = string(round(f01_2, digits=3))
	J_s = string(round(J * 1000, digits=1)); J_full_s = string(round(J_full * 1000, digits=1))
	J0_s = string(round(J0 * 1000, digits=1))
	ZZ_s = string(round(ZZ * 1000, digits=2)); delta_s = string(round(δ_dev * 1000, digits=1))
	Tis_s = string(round(Tiswap, digits=1))
end

# ╔═╡ f0000000-0000-4000-8000-00000000000e
begin
	# 能级扇形：改变 EJ₂ 相对量，看 |0,1⟩ 与 |1,0⟩ 的 avoided crossing（宽度 = 2J）
	fracs = collect(range(-0.08, 0.08; length=97))
	E01 = zeros(length(fracs)); E10 = zeros(length(fracs)); E11 = zeros(length(fracs))
	for (i, fr) in enumerate(fracs)
		tb = Transmon(EJ * (1 - fr), EC; ncut=NCUT)
		TQb = TwoQubit(t1, tb, g_c; nlev=3)
		E01[i] = level_energy(TQb, 0, 1) - level_energy(TQb, 0, 0)
		E10[i] = level_energy(TQb, 1, 0) - level_energy(TQb, 0, 0)
		E11[i] = level_energy(TQb, 1, 1) - level_energy(TQb, 0, 0)
	end
	δs = f01_1 .- [f01_f12(Transmon(EJ * (1 - fr), EC; ncut=NCUT), 0.0)[1] for fr in fracs]
end

# ╔═╡ f0000000-0000-4000-8000-00000000000f
begin
	# ZZ 随耦合强度变化（g_c → 0 时 ZZ → 0；强耦合饱和）
	gcs = collect(range(0.0, 0.2; length=41))
	zzs = [zz_rate(TwoQubit(t1, t2, gc; nlev=3)) for gc in gcs]
	# iSWAP 转移率随耦合变化
	Js = [exchange_rate(TwoQubit(t1, t2, gc; nlev=3)) for gc in gcs]
end

# ╔═╡ f0000000-0000-4000-8000-000000000010
stat_row([
	("交换率 J（有效模型 / 全电荷基）", "$(J_s) / $(J_full_s) MHz", "共振时 π/(2J) = $(Tis_s) ns", "#4C6FFF"),
	("always-on ZZ", "$(ZZ_s) MHz", "f(q1|q2=1) − f(q1|q2=0)", "#B8812E"),
	("失谐 δ = f01₁ − f01₂", "$(delta_s) MHz", "g/δ = $(string(round(g_c / max(abs(δ_dev), 1e-9), digits=2)))", "#7B61FF"),
	("|01⟩ ↔ |10⟩ 转移率（当前）", "$(string(round(100 * maximum(pop[:, basis_index(TQ, 1, 0)]), digits=1)))%", "共振对照 $(string(round(100 * maximum(pop0[:, basis_index(TQ0, 1, 0)]), digits=1)))%", "#22C3A6"),
	("共振器件 J（det2=0）", "$(J0_s) MHz", "失谐把有效劈裂改成 √(δ²+4J²)", "#1A1A2E"),
])

# ╔═╡ f0000000-0000-4000-8000-000000000011
callout("三件事一起看：<b>J</b> 决定门多快（π/(2J) ns），<b>ZZ</b> 决定别人做门时你会被推偏多少 MHz，<b>失谐</b>决定 iSWAP 干不干净。全电荷基列出的 J 与有效模型一致 → 模型可信。",
	tone="tip", title="看什么")

# ╔═╡ f0000000-0000-4000-8000-000000000012
begin
	tr = PlotlyBase.GenericTrace[]
	push!(tr, PlotlyBase.scatter(x=δs * 1000, y=E01 * 1000; mode="lines", name="|0,1⟩ dressed 能级",
		line=attr(color=PAL[1], width=2.5)))
	push!(tr, PlotlyBase.scatter(x=δs * 1000, y=E10 * 1000; mode="lines", name="|1,0⟩ dressed 能级",
		line=attr(color=PAL[2], width=2.5)))
	push!(tr, PlotlyBase.scatter(x=δs * 1000, y=E11 * 1000; mode="lines", name="|1,1⟩", line=attr(color="#8A90AD", width=1.5, dash="dash")))
	push!(tr, PlotlyBase.scatter(x=[δ_dev * 1000, δ_dev * 1000], y=[0, 2 * f01_1 * 1000]; mode="lines",
		line=attr(color=PAL[4], width=2, dash="dot"), name="当前 det2"))
	ann = [attr(x=0, y=20000, text="avoided crossing（宽度 2J = $(string(round(2J * 1000, digits=1))) MHz）",
		showarrow=false, font=attr(size=12, color="#B8812E"), yanchor="bottom"),
		attr(x=δ_dev * 1000, y=-400, text="当前", showarrow=false, font=attr(size=11, color=PAL[4]))]
	pfan = PlotlyBase.Plot(tr, layout_base(height=470,
		title="A · 能级扇形：|01⟩/|10⟩ 的 avoided crossing",
		xtitle="失谐 δ = f01₁ − f01₂ (MHz)", ytitle="相对 |0,0⟩ 的能量 (MHz)", annotations=ann))
	plotly_html("oq_fan", pfan; height=480)
end

# ╔═╡ f0000000-0000-4000-8000-000000000013
figure_note("两条实线在最靠近處互相推开——最小间距 = 2J（可用它直接从谱上读交换率，不必依赖模型）。这也是磁通脉冲做 CZ 的操作台：把工作点拖过 avoided crossing。")

# ╔═╡ f0000000-0000-4000-8000-000000000014
begin
	tr = PlotlyBase.GenericTrace[]
	for (k, nm) in enumerate(["|0,0⟩", "|0,1⟩", "|1,0⟩", "|1,1⟩"])
		push!(tr, PlotlyBase.scatter(x=times, y=pop[:, basis_index(TQ, k ÷ 2, k % 2)]; mode="lines",
			line=attr(color=PAL[k], width=2.5), name=nm))
	end
	for k in 1:4
		push!(tr, PlotlyBase.scatter(x=times0, y=pop0[:, basis_index(TQ0, k ÷ 2, k % 2)]; mode="lines",
			line=attr(color=PAL[k], width=1.2, dash="dot"), showlegend=false, opacity=0.75))
	end
	ptime = PlotlyBase.Plot(tr, layout_base(height=440,
		title="B · iSWAP：|0,1⟩ 出发（实线=失谐，虚线=共振）",
		xtitle="时间 (ns)", ytitle="布居", yrange=[0, 1]))
	plotly_html("oq_iswap", ptime; height=450)
end

# ╔═╡ f0000000-0000-4000-8000-000000000015
begin
	# 双 Bloch 球：两个比特各自的 Bloch 轨迹（左=qubit1，右=qubit2）
	function sphere(x0)
		out = PlotlyBase.GenericTrace[]
		for lat in [-60, -30, 0, 30, 60]
			φ = deg2rad(lat); r = cos(φ); z = fill(sin(φ), length(lons))
			push!(out, PlotlyBase.scatter3d(x=x0 .+ r .* cosd.(lons), y=r .* sind.(lons), z=z; mode="lines",
				line=attr(color="rgba(20,24,60,0.10)", width=1), showlegend=false, hoverinfo="skip"))
		end
		for lon in lons
			push!(out, PlotlyBase.scatter3d(x=x0 .+ cos.(ths) .* cosd(lon), y=cos.(ths) .* sind(lon), z=sin.(ths);
				mode="lines", line=attr(color="rgba(20,24,60,0.10)", width=1), showlegend=false, hoverinfo="skip"))
		end
		out
	end
	lons = collect(0:30:330); ths = deg2rad.(collect(-75:15:75))
	tr = PlotlyBase.GenericTrace[]
	for s in sphere(-1.5); push!(tr, s); end
	for s in sphere(1.5); push!(tr, s); end
	step = max(1, div(size(times, 1), 300))
	push!(tr, PlotlyBase.scatter3d(x=-1.5 .+ b1[1:step:end, 1], y=b1[1:step:end, 2], z=b1[1:step:end, 3];
		mode="lines", line=attr(color=PAL[1], width=5), name="qubit1 轨迹"))
	push!(tr, PlotlyBase.scatter3d(x=1.5 .+ b2[1:step:end, 1], y=b2[1:step:end, 2], z=b2[1:step:end, 3];
		mode="lines", line=attr(color=PAL[2], width=5), name="qubit2 轨迹"))
	push!(tr, PlotlyBase.scatter3d(x=[-1.5, -1.5], y=[0, 0], z=[-1.35, 1.35]; mode="lines",
		line=attr(color="rgba(34,195,166,0.7)", width=3), showlegend=false, hoverinfo="skip"))
	push!(tr, PlotlyBase.scatter3d(x=[1.5, 1.5], y=[0, 0], z=[-1.35, 1.35]; mode="lines",
		line=attr(color="rgba(34,195,166,0.7)", width=3), showlegend=false, hoverinfo="skip"))
	ann = [attr(x=-1.5, y=0, z=1.5, text="|0⟩₁", showarrow=false, font=attr(size=12, color="#22C3A6")),
		attr(x=1.5, y=0, z=1.5, text="|0⟩₂", showarrow=false, font=attr(size=12, color="#22C3A6"))]
	# 双球动画标记作为最后一条专用 trace（每帧两个点：q1 蓝、q2 紫）
	push!(tr, PlotlyBase.scatter3d(x=[-1.5 + b1[1, 1], 1.5 + b2[1, 1]], y=[b1[1, 2], b2[1, 2]],
		z=[b1[1, 3], b2[1, 3]]; mode="markers",
		marker=attr(size=8, color=["#4C6FFF", "#7B61FF"], line=attr(color="white", width=2)),
		showlegend=false, hoverinfo="skip"))
	BALL = length(tr) - 1              # 0 基索引
	nfr = 48
	fidx = round.(Int, range(1, size(times, 1); length=nfr))
	frames = PlotlyBase.PlotlyFrame[]
	for i in fidx
		push!(frames, anim_frame(BALL, string(i), PlotlyBase.scatter3d(
			x=[-1.5 + b1[i, 1], 1.5 + b2[i, 1]], y=[b1[i, 2], b2[i, 2]],
			z=[b1[i, 3], b2[i, 3]]; mode="markers",
			marker=attr(size=8, color=["#4C6FFF", "#7B61FF"], line=attr(color="white", width=2)),
			showlegend=false, hoverinfo="skip")))
	end
	pbloch = PlotlyBase.Plot(tr, Layout(
		title=attr(text="C · 双 Bloch 球：激发从 qubit2 换到 qubit1（点播放）", font=attr(size=16, color=INK)),
		scene=attr(aspectmode="cube", xaxis=attr(visible=false), yaxis=attr(visible=false),
			zaxis=attr(visible=false), annotations=ann, camera=attr(eye=attr(x=0.9, y=-2.0, z=1.2))),
		font=attr(family=FONT), paper_bgcolor="white", margin=attr(l=10, r=10, t=52, b=10), height=520,
		updatemenus=animation_menu(),
		legend=attr(orientation="h", y=1.03, x=0.15, bgcolor="rgba(0,0,0,0)", font=attr(size=11, color=SUB))), frames)
	plotly_html("oq_2bloch", pbloch; height=530)
end

# ╔═╡ f0000000-0000-4000-8000-000000000016
begin
	tr = PlotlyBase.GenericTrace[]
	push!(tr, PlotlyBase.scatter(x=gcs * 1000, y=Js * 1000; mode="lines", name="交换率 J = g_c·n₀₁²",
		line=attr(color=PAL[1], width=2.5), yaxis="y"))
	push!(tr, PlotlyBase.scatter(x=gcs * 1000, y=zzs * 1000; mode="lines", name="always-on ZZ",
		line=attr(color="#F5A623", width=2.5), yaxis="y2"))
	push!(tr, PlotlyBase.scatter(x=[g_c * 1000], y=[J * 1000]; mode="markers",
		marker=attr(size=12, color="#4C6FFF", line=attr(color="white", width=2)), showlegend=false))
	lay = layout_base(height=440, title="D · 耦合越强：门越快，但 ZZ 也越大",
		xtitle="结间电容耦合 g_c (MHz)")
	lay.yaxis2 = attr(title="ZZ (MHz)", overlaying="y", side="right",
		gridcolor="rgba(0,0,0,0)", zerolinecolor="rgba(0,0,0,0)",
		tickfont=attr(size=11, color="#B8812E"), titlefont=attr(size=12, color="#B8812E"))
	pzz = PlotlyBase.Plot(tr, lay)
	plotly_html("oq_zz", pzz; height=450)
end

# ╔═╡ f0000000-0000-4000-8000-000000000017
callout("J ∝ g_c 而 ZZ ∝ g_c²（小耦合时）→ <b>门越快、串扰越大</b>。真实器件靠 flux bias 把 ZZ 调到近零（「ZZ 抵消工作点」），或干脆接受它、用补偿脉冲修正；这页的 D 图就是那条权衡曲线。",
	tone="warn", title="动手前先看这里")

# ╔═╡ f0000000-0000-4000-8000-000000000018
divider()

# ╔═╡ f0000000-0000-4000-8000-000000000019
derivation("⑤ 推导溯源：从结间电容到 iSWAP 与 ZZ",
	[
	("定义", texblock(raw"H = \hat H_1 + \hat H_2 + g_c\,\hat n_1\otimes\hat n_2, \qquad g_c \propto \frac{e^2}{C_c}"), "两个带结的岛靠结间电容耦合：耦合不是「外加」的，是两岛共享的那一小块电容；这在版图阶段就确定了。"),
	("近似", texblock(raw"\hat n \;\longrightarrow\; \begin{pmatrix} 0 & n_{01} & 0 \\ n_{01} & 0 & n_{12} \\ 0 & n_{12} & 0 \end{pmatrix}"), "各自投影到前 3 个能级（电荷宇称禁戒对角元）；与 ② 的 driven_basis 同一来源；$(tex(raw"n_{12}")) 项是非谐性的指纹，ZZ 全靠它。"),
	("代入", texblock(raw"\hat n \to n_{01}\,\sigma_x \;\;\Rightarrow\;\; H_{\mathrm{int}} = \frac{J}{2}\big(\sigma_x\sigma_x\big) = \frac{J}{2}\big(\sigma^+\sigma^- + \sigma^-\sigma^+\big) + \frac{J}{2}\big(\sigma^+\sigma^+ + \sigma^-\sigma^-\big)"), texblock(raw"J = g_c\,n_{01}^2")),
	("代入", "第一项只换位置（保总数），第二项成对产生/湮灭（不保总数）——两者的后果完全不同。", ""),
	("代入", texblock(raw"H = \begin{pmatrix} f_2 & J \\ J & f_1 \end{pmatrix}\ \ (|0,1\rangle\ \mathrm{subspace}) \;\;\Rightarrow\;\; \Delta = \sqrt{\delta^2 + 4J^2}"), texblock(raw"\Rightarrow\quad P_{10}(t) = \frac{4J^2}{\delta^2+4J^2}\,\sin^2\!\left(\frac{\Delta\, t}{2}\right)")),
	("代入", texblock(raw"\Delta = 2J \quad(\text{avoided crossing 宽度})"), "图 A 的 avoided crossing 宽度就是 $(tex(raw"2J"))；图 B 实线（失谐）与虚线（共振）的差异全在这个因子上。"),
	("整理", texblock(raw"\delta = 0:\quad t = \frac{\pi}{2J}\ \mathrm{(full\ swap)} = \mathrm{iSWAP}; \qquad \eta_{\max} = \frac{4J^2}{\delta^2+4J^2} < 1"), "「门不干净」的定量原因。真实器件靠磁通把两个比特拧到同频再开门，或接受残余误差。"),
	("微扰", texblock(raw"\mathrm{counter\text{-}rotating}:\quad |1,1\rangle \leftrightarrow |2,0\rangle,|0,2\rangle \;\;(\Delta E \sim |\alpha|)"), "而 $(tex(raw"|0,1\rangle/|1,0\rangle")) 只能跟更远的态混合 → $(tex(raw"|1,1\rangle")) 被推得更多。**非谐性是 ZZ 存在的必要条件**（本页把截断从 2 能级改到 3 能级，ZZ 才不为零）。"),
	("整理", texblock(raw"\mathrm{ZZ} = f\big(q_1 \,\big|\, q_2{=}1\big) - f\big(q_1 \,\big|\, q_2{=}0\big) \qquad(\text{图 D 橙线})"), "后果：别人做门时你的比特频率在动，单比特门失谐 → 相位误差；谐振读取的频率也在动。**always-on** = 不需要耦合操作时它也在，是所有两比特处理的头号敌人。"),
	("代入", texblock(raw"\mathrm{CZ:}\ \text{flux pulse through avoided crossing} \;\Rightarrow\; |1,1\rangle\ \mathrm{gains}\ 2\pi"), "图 A 的扇形图就是操作台：纵轴是脉冲走过去的时间，横轴是磁通偏置——chevron 图的雏形（CZ 校准列为 backlog）。"),
	];
	lead="每一步都可点开。读数卡的 J 与 ZZ 都能在这里找到对应行。",
	result="当前参数：J = $(J_s) MHz（全电荷基对照 $(J_full_s) MHz），ZZ = $(ZZ_s) MHz，失谐 δ = $(delta_s) MHz → iSWAP 最大转移率 = $(string(round(100 * 4J^2 / (δ_dev^2 + 4J^2), digits=1)))%，门时间 π/(2J) = $(Tis_s) ns。")

# ╔═╡ f0000000-0000-4000-8000-00000000001a
tryout([
	("亲手把两个比特调到同频", "把 det2 拖到 0（或贴近 0），看图 B 虚线与实线重合、读数卡转移率升到 ~99%。",
	 "δ=0 时 iSWAP 完全转移；但只要 det2 ≠ 0，最大转移率 = $(tex(raw"\frac{4J^2}{\delta^2+4J^2}")) 立刻掉下来——这就是「磁通调谐」存在的理由（下一个演示的主题）。"),
	("看 ZZ 把单比特门推偏", "固定 g_c，把 det2 拖大，观察 ZZ 读数卡。",
	 "ZZ 随失谐变化；把它折算成时间：一个 20 ns 的单比特门上，ZZ = 1 MHz 就意味着 0.02·2π rad ≈ 7° 的相位误差——足够毁掉一个深度线路。"),
	("找到你的权衡点", "拖 g_c 从 0.02 到 0.2，看图 D：J 线性上升，ZZ 二次上升。",
	 "门时间 ∝ 1/J 变快，但串扰 ∝ J² 涨得更快。真实器件的 g_c 通常取「门够快、ZZ 还能被补偿」的折衷。"),
	("两能级截断看不见 ZZ", "（给爱抬杠的你）把 EC 拖到 0.45、g_c 拖到 0.2，看 ZZ 读数——它不会变成 0，因为本页用 3 能级截断。",
	 "如果只用 2 能级，counter-rotating 与非谐性恰好抵消，ZZ ≡ 0——图 D 的橙线会变成一个常数 0。这就是推导第 6 步的含义。"),
])

# ╔═╡ f0000000-0000-4000-8000-00000000001b
quiz([
	("共振时 iSWAP 的 π 门时间是多少？",
	 ["π/J", "π/(2J)", "2π/J", "1/J"], 2,
	 "P₁₀(t) = sin²(Jt)（δ=0）→ 第一次完全转移在 t = π/(2J)。所以 J 越大门越快，但 ZZ ∝ J² 也越大。"),
	("两个全同 transmon（δ=0）精确耦合时，为什么「条件频率 ZZ」这个读数会异常？",
	 ["数值误差", "|0,1⟩/|1,0⟩ 已混成 dressed 态，「谁在哪个态」不再有唯一答案", "耦合被关闭了", "非谐性消失"], 2,
	 "δ=0 时 |01⟩ 与 |10⟩ 强烈杂化，乘积基标签失效——本页默认给一个小失谐（真实器件也如此）。需要精确同频时，应改用谱学定义（例如 |11⟩ 的跃迁频率）。"),
	("always-on ZZ 的物理根源是？",
	 ["电容耦合的一阶项", "counter-rotating 项 + transmon 非谐性", "T1 衰减", "读取腔色散"], 2,
	 "纯交换项（一阶）只搬布居不推频率；ZZ 出现在二阶，且必须靠非谐性（n₁₂ 项）才能与 |0,1⟩/|1,0⟩ 区分开。"),
])

# ╔═╡ f0000000-0000-4000-8000-00000000001c
@htl("""
<div style="font-size:14.5px;color:#33384D;line-height:2.0;margin-top:6px">
<p><b>两比特的 duality：</b>iSWAP 是<b>想要的</b>耦合（交换激发），ZZ 是<b>不想要的</b>耦合（互相推频率）。同一个 g_c·n̂₁n̂₂ 同时给出两者——这是超导量子计算里最经典的「用它的好、防它的坏」。</p>
<p><b>还没展示的：</b>CZ 磁通脉冲与 chevron 标定（backlog）、CR 驱动门、iSWAP 的校准流程。</p>
<p><b>下一步去哪：</b><b>磁通调谐</b>看 E_J(Φ) 如何随手调频率/耦合、如何用甜点把噪声压下去；<b>T1/T2</b> 看这些 μs 级相干时间如何限制上面的每一个门。</p>
</div>
""")

# ╔═╡ Cell order:
# ╟─f0000000-0000-4000-8000-000000000001
# ╠═f0000000-0000-4000-8000-000000000002
# ╠═f0000000-0000-4000-8000-000000000003
# ╠═f0000000-0000-4000-8000-000000000004
# ╠═f0000000-0000-4000-8000-000000000005
# ╠═f0000000-0000-4000-8000-000000000006
# ╟─f0000000-0000-4000-8000-000000000007
# ╟─f0000000-0000-4000-8000-000000000008
# ╟─f0000000-0000-4000-8000-000000000009
# ╟─f0000000-0000-4000-8000-00000000000a
# ╟─f0000000-0000-4000-8000-00000000000b
# ╟─f0000000-0000-4000-8000-00000000000c
# ╠═f0000000-0000-4000-8000-00000000000d
# ╟─f0000000-0000-4000-8000-00000000000e
# ╟─f0000000-0000-4000-8000-00000000000f
# ╠═f0000000-0000-4000-8000-000000000010
# ╠═f0000000-0000-4000-8000-000000000011
# ╟─f0000000-0000-4000-8000-000000000012
# ╠═f0000000-0000-4000-8000-000000000013
# ╟─f0000000-0000-4000-8000-000000000014
# ╟─f0000000-0000-4000-8000-000000000015
# ╟─f0000000-0000-4000-8000-000000000016
# ╠═f0000000-0000-4000-8000-000000000017
# ╠═f0000000-0000-4000-8000-000000000018
# ╠═f0000000-0000-4000-8000-000000000019
# ╠═f0000000-0000-4000-8000-00000000001a
# ╠═f0000000-0000-4000-8000-00000000001b
# ╠═f0000000-0000-4000-8000-00000000001c
