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
oq_stack(
banner("OVERQUBIT · 两比特", "iSWAP 与 always-on ZZ：耦合双 transmon",
	"电容耦合让两个 transmon 交换激发（iSWAP）；非谐性又让它们互相推移频率（ZZ）——量子门既要用它，也要防它"; icon="pair"),
@htl("""
<div style="font-size:13.5px;color:#33384D;line-height:1.9;max-width:78ch;margin:2px 2px 4px">
<b>读完这页你能：</b>①指着图 A 的两条线说出<b>最小间距</b>是几 MHz，并解释为什么它等于 2J——不用任何模型，直接从谱上读出交换率；
②把 iSWAP 门时间 <b>π/(2J)</b> 心算成 ns，并用 4J²/(δ²+4J²) 说清「失谐一开、换位就不干净」是<b>上限</b>问题而不是速度问题；
③用「成对项 + 非谐性 α」讲清 ZZ 为什么<b>永远开着</b>，并把读数卡的 ZZ 折算成一个 20 ns 单比特门上的相位误差（多少度）。
</div>
"""),
)

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
	("图像 · 耦合从哪来：两个岛共享一块电容", "两个 transmon 的岛之间挂着一块小电容 C_c，它的库仑能就是耦合本身：H_int = g_c·n̂₁n̂₂，g_c ∝ e²/C_c。耦合不是「外加」的，而是版图上画下那块电容时就焊死的——想改耦合只能改版图，或换可调耦合器。类比：两个音叉不是互相喊话，而是挂在同一根横梁上，一个振动必然牵动另一个。量级上 C_c 是 fF 量级，折合 g_c/2π 约 5–20 MHz，比 5 GHz 的跃迁频率小五个数量级——这正是后面微扰论能用的前提。验证锚点：图 D 里 J 随 g_c 走直线、截距为零。"),
	("机制 · iSWAP：只换座位的那半边", "把电荷算符投影到两能级 n̂ ≈ n₀₁σ_x 后，耦合裂成两半，其中 σ⁺σ⁻ + σ⁻σ⁺ 只「换座位」：|0,1⟩ 的激发跳到另一个比特上，总激发数不变。交换以速率 J = g_c·n₀₁² 振荡，共振时 t = π/(2J) 恰好完全换位——这就是 iSWAP 门；本页默认参数下 J ≈ 70 MHz，门时间约 22 ns。类比：两个等长的秋千挂同一根横梁，一个停下、另一个荡起来，能量整份来回倒。验证锚点：图 B 里蓝线掉向 0 的同时紫线升向 1，图 C 的两个红点交换半球。"),
	("定量 · always-on ZZ：绕远路攒下的相位", "另一半 σ⁺σ⁺ + σ⁻σ⁻ 成对产生/湮灭激发，专门连接 |1,1⟩ ↔ |2,0⟩、|0,2⟩，中间只隔一个非谐性 α ≈ −0.2~−0.3 GHz。这些虚过程把 |1,1⟩ 多推了一把，于是 qubit1 的频率取决于 qubit2 在不在 |1⟩：ZZ = f(q1|q2=1) − f(q1|q2=0)，真实器件上 0.1–2 MHz。它不需要任何操作就存在：ZZ = 1 MHz 时，一个 20 ns 的单比特门就积累 2π·ZZ·t ≈ 0.13 rad ≈ 7° 的条件相位。验证锚点：图 D 橙线随 g_c 二次上升，读数卡「always-on ZZ」是它的当前值。"),
	("代价 · 门速与串扰的跷跷板", "同一个 g_c 给你两样东西：门速 J ∝ g_c（线性），串扰 ZZ ∝ g_c²（二次）——耦合加倍，门快一倍，ZZ 却变四倍。两个比特也不可能天然同频：δ ≠ 0 时最大转移率被压到 4J²/(δ²+4J²)，等再久也换不完。工程出路不是把耦合调没了事，而是调工作点：磁通甜点、ZZ 抵消点、可调耦合器，或接受 ZZ 并用补偿脉冲（虚拟 Z）修正。验证锚点：图 D 两条曲线的增速差，图 B 实线的峰值够不到 1。"),
])

# ╔═╡ f0000000-0000-4000-8000-000000000006
oq_stack(
callout("为什么关心：单比特门再完美，比特之间不「说话」就什么都算不了；可一旦让它们说话，同一份耦合又会趁你不做门时偷偷推移频率——这是超导量子计算里最经典的「用它的好、防它的坏」。本页主线跟着一个参数走：<b>结间耦合 g_c</b> 如何同时变成想要的 <b>J</b>（交换率）与不想要的 <b>ZZ</b>（条件频移）。建议读法：先看四张概念卡建立图像 → 拖 g_c / det2 做下方的实验 → 再回头看推导链（每一步都标了在哪张图或哪行读数上验证）。",
	tone="info", title="① 这一页讲什么：两个比特怎么「说话」，又怎么互相拖累"),
callout("本页用<b>能级截断有效模型</b>（每个比特取 3 个能级，n̂ 投影到本征子空间，与 ② 的 driven_basis 同一来源）；同时提供<b>全电荷基联合对角化</b>作为精确参照（读数卡的交叉验证）。默认两比特略有失谐——真实器件也总是这样。",
	tone="info", title="阅读前提"),
)

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
callout("三个读数各是什么、先动哪个：<b>J</b> 决定门多快（π/(2J) ns，先看它），<b>ZZ</b> 决定别人做门时你会被推偏多少 MHz，<b>失谐 δ</b> 决定 iSWAP 干不干净（转移率 4J²/(δ²+4J²)）。建议顺序：先把 det2 拖到 0 看一次完美 iSWAP（图 B），再拖 det2 看转移率掉下来，最后扫 g_c 看图 D 的权衡。全电荷基列出的 J 与有效模型一致 → 模型可信，放心用公式说话。",
	tone="tip", title="③ 调参前先看这里：先动 det2，再动 g_c")

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
figure_note("看图要诀（图 A）：①两条实线最靠近处的竖直间距就是 2J——沿橙色「当前 det2」虚线读它，即可不依赖模型直接标定交换率；②两条线「上下互换性格」的交叉区域中心就是共振点 δ = 0，越往两边走它们越像裸能级 |0,1⟩、|1,0⟩；③灰色虚线 |1,1⟩ 与「两条实线之和」之间的偏差，就是 ZZ 在谱上的形状（推导第 9 步）。这也是磁通脉冲做 CZ 的操作台：把工作点拖过 avoided crossing。")

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
oq_stack(
derivation("⑤ 推导溯源：从结间电容到 iSWAP 与 ZZ",
	[
	("定义", texblock(raw"H = \hat H_1 + \hat H_2 + g_c\,\hat n_1\otimes\hat n_2, \qquad g_c \propto \frac{e^2}{C_c}"), "先写下整个系统的哈密顿量：两个岛各自的势阱 + 共享电容 C_c 的库仑能。耦合项和比特的充电能出自同一套静电学，所以 g_c ∝ e²/C_c，量级只有 MHz——比 5 GHz 的跃迁频率小五个数量级，这是后面微扰论合法的大前提。类比：两个音叉挂在同一根横梁上，横梁刚度就是 g_c。交叉验证：读数卡「有效模型 / 全电荷基」就是把这个 H 直接数值对角化，两者吻合才说明投影没丢东西。"),
	("近似", texblock(raw"\hat n \;\longrightarrow\; \begin{pmatrix} 0 & n_{01} & 0 \\ n_{01} & 0 & n_{12} \\ 0 & n_{12} & 0 \end{pmatrix}"), "把电荷算符剪到前 3 个能级：电荷宇称禁戒对角元，只剩 n₀₁ 与 n₁₂ 两个刻度。n₀₁ 是「换座位」的刻度（决定 J），n₁₂ 是 |1⟩→|2⟩ 的刻度——ZZ 全靠它。为什么要 3 能级：两能级截断下 counter-rotating 项与非谐性恰好抵消，ZZ 会假性为零（试试看任务 4 亲手验证）。失效条件：驱动或耦合把人口显著踢到 |3⟩ 以上时，这个截断开始漏。"),
	("代入", texblock(raw"\hat n \to n_{01}\,\sigma_x \;\;\Rightarrow\;\; H_{\mathrm{int}} = J\,\sigma_x\sigma_x = J\big(\sigma^+\sigma^- + \sigma^-\sigma^+\big) + J\big(\sigma^+\sigma^+ + \sigma^-\sigma^-\big), \qquad J = g_c\,n_{01}^2"), "投影到两能级后耦合变成 J·σ_xσ_x，其中 J = g_c·n₀₁² 就是读数卡上的交换率。展开后两组项泾渭分明：σ⁺σ⁻ + σ⁻σ⁺ 只「换座位」（总激发数守恒），σ⁺σ⁺ + σ⁻σ⁻ 成对产生/湮灭（不守恒）——前者给 iSWAP，后者给 ZZ。类比：前者是两人互换座位，后者是凭空造出一对双胞胎再送走。注意这一步丢掉了 n₁₂，算 ZZ 时要退回上一步的 3×3 矩阵。"),
	("代入", texblock(raw"|0,1\rangle \leftrightarrow |1,0\rangle\ \ (\mathrm{swap}); \qquad |1,1\rangle \leftrightarrow |2,0\rangle,\ |0,2\rangle\ \ (\mathrm{pair},\ \Delta E \sim |\alpha|)"), "两组项连接的态对完全不同：交换项把 |0,1⟩ 与 |1,0⟩ 缠在一起（iSWAP 的舞台），成对项只连 |1,1⟩ ↔ |2,0⟩、|0,2⟩，中间隔着非谐性 α ≈ −0.2~−0.3 GHz。于是 |1,1⟩ 被虚过程推得比 |0,1⟩、|1,0⟩ 更多——条件频移的不对称由此而来。类比：绕远路攒相位，路越远（|α| 越大）攒得越少，但永不为零。这一步是 ZZ 的物理心脏：换座位人人平等，攒相位只发生在「两人都坐着」的时候。"),
	("代入", texblock(raw"H = \begin{pmatrix} f_2 & J \\ J & f_1 \end{pmatrix}\ \ (|0,1\rangle\ \mathrm{subspace}) \;\;\Rightarrow\;\; \Delta = \sqrt{\delta^2 + 4J^2}"), "聚焦 |0,1⟩/|1,0⟩ 子空间：哈密顿量塌缩成一个 2×2 矩阵，对角是两比特各自的频率（差 δ），非对角是 J。本征劈裂 Δ = √(δ²+4J²) 就是图 A 两条线间距随失谐的走向。把这个静态问题解出来投影到 |1,0⟩，就是下方的 sin² 振荡。失效条件：J ≪ |α| 时这个子空间才「干净」，否则 |2⟩ 会来搅局。"),
	("代入", texblock(raw"\Rightarrow\quad P_{10}(t) = \frac{4J^2}{\delta^2+4J^2}\,\sin^2\!\left(\frac{\Delta\, t}{2}\right)"), "投影到 |1,0⟩ 的布居就是这个 sin²。两个因子分工明确：幅度因子 4J²/(δ²+4J²) 管「换得干不干净」，频率因子 Δ/2 管「换得多快」——失谐同时打这两个。验证：图 B 的振荡频率就是 Δ/(2π)，实线（失谐）的峰值低于虚线（共振），正是幅度因子在起作用。"),
	("代入", texblock(raw"\delta = 0:\quad \Delta = 2J\ \ (\mathrm{avoided\ crossing\ width})"), "共振时劈裂塌缩成 Δ = 2J——图 A 中两条线最靠近处的最小间距。这是全页最好用的实验锚点：从谱上量最小间距、除以 2 就得到 J，不依赖任何模型。类比：两根耦合音叉的本征频率劈成一上一下，劈开的宽度就是耦合强度。"),
	("整理", texblock(raw"\delta = 0:\quad t = \frac{\pi}{2J}\ \mathrm{(full\ swap)} = \mathrm{iSWAP}; \qquad \eta_{\max} = \frac{4J^2}{\delta^2+4J^2} < 1"), "令 P₁₀ = 1 找门时间：t = π/(2J)——读数卡「共振时 π/(2J) = … ns」就是它。一旦 δ ≠ 0，最大转移率被压到 η_max = 4J²/(δ²+4J²)，等再久也换不完——「门不干净」是上限问题，不是速度问题。真实器件靠磁通把两个比特拧到同频再开门，或把 J 做大以压住失谐。验证：图 B 实线的峰值直接就是 η_max。"),
	("微扰", texblock(raw"\mathrm{counter\text{-}rotating}:\quad |1,1\rangle \leftrightarrow |2,0\rangle,|0,2\rangle \;\;(\Delta E \sim |\alpha|) \;\;\Rightarrow\;\; \delta E_{11} \sim \frac{J^2}{|\alpha|}"), "二阶微扰：|1,1⟩ 借成对项虚跃迁到 |2,0⟩、|0,2⟩，能差只有 |α|，二阶能移 ~ J²/|α|；而 |0,1⟩、|1,0⟩ 只能跟更远的态混合，推得少——两者的差就是 ZZ。<b>非谐性是 ZZ 存在的必要条件</b>：把截断从 2 能级改到 3 能级，ZZ 才不为零。验证：拖 g_c 看图 D 橙线按 g_c² 起飞（能移 ∝ J²）。"),
	("整理", texblock(raw"\mathrm{ZZ} = f\big(q_1 \,\big|\, q_2{=}1\big) - f\big(q_1 \,\big|\, q_2{=}0\big) \qquad(\mathrm{Fig.\ D})"), "把不对称写成实验可测的量：qubit1 的跃迁频率随邻居在 |0⟩ 还是 |1⟩ 差一个 ZZ，这正是读数卡的「always-on ZZ」。后果：别人做门时你的频率在动 → 单比特门失谐、读取频率拖尾、spectator 误差；而你什么都没做它也在（always-on）。折算：一个 20 ns 的单比特门上累积 2π·ZZ·t ≈ 0.13×(ZZ/MHz) rad 的条件相位。失效条件：全同比特（δ = 0）上「条件频率」的说法本身失效，见自测 Q2。"),
	("代入", texblock(raw"\mathrm{CZ:}\ \mathrm{flux\ pulse\ through\ avoided\ crossing} \;\Rightarrow\; |1,1\rangle\ \mathrm{gains}\ 2\pi"), "既然 ZZ 是可预测的相位，就把它升级成门：用磁通脉冲把工作点拖过图 A 的 avoided crossing，让 |1,1⟩ 攒下 2π 相位而 |0,1⟩、|1,0⟩ 不动——这就是 CZ。把脉冲时间当纵轴、磁通偏置当横轴扫出来，就是 chevron 图。代价：脉冲期间离甜点很远、噪声敏感，还要防泄漏到 |2⟩——CZ 校准演示就是收拾这些代价的（列为 backlog）。"),
	];
	lead="这条推导的脉络：先回答<b>耦合是什么</b>（第 1–2 步：一块共享电容 + 电荷算符投影），再回答<b>它给出什么</b>（第 3–6 步：把耦合拆成「换座位」与「攒相位」两半，解出 |01⟩↔|10⟩ 的 sin² 振荡与劈裂 Δ），然后回答<b>代价在哪</b>（第 7–9 步：门时间 π/(2J)、失谐上限与二阶微扰攒出的 ZZ），最后<b>反过来用它</b>（第 10–11 步：条件相位的定义与 CZ）。读法建议：每一步都标了在哪张图验证，先看图再展开公式；第 3、4 步的「两半拆分」是全页枢纽，值得多读两遍。",
	result="结论落回读数卡：J = $(J_s) MHz（全电荷基对照 $(J_full_s) MHz，两者吻合 ⇒ 投影模型可信）→ iSWAP 门时间 π/(2J) = $(Tis_s) ns；失谐 δ = $(delta_s) MHz ⇒ 最大转移率 $(string(round(100 * 4J^2 / (δ_dev^2 + 4J^2), digits=1)))%（图 B 实线峰值）、有效劈裂 √(δ²+4J²) = $(string(round(1000 * sqrt(δ_dev^2 + 4J^2), digits=1))) MHz（图 A 最小间距）；ZZ = $(ZZ_s) MHz ⇒ 一个 20 ns 单比特门上累积 $(string(round(2π * ZZ * 20; digits=3))) rad ≈ $(string(round(360 * ZZ * 20; digits=1)))° 的条件相位（图 D 橙线当前点）。"),
deep_dive("适用边界与工程数值：J = g_c·n₀₁² 什么时候会不准？", """
<p>这个 J 是<b>两能级投影</b>的结果，适用条件是 $(tex(raw"J \ll |\alpha|"))：本页默认 J ≈ 70 MHz 而 |α| ≈ 250 MHz，比值约 0.3，边际安全；g_c 拖到 0.2 时比值逼近 1，投影开始失真。更精确地，n̂ 的 $(tex(raw"n_{12}")) 项带来二阶修正 $(tex(raw"\delta J \sim (g_c\,n_{01}n_{12})^2/|\alpha|"))，量级只有几百 kHz——读数卡「有效模型 / 全电荷基」的差值正是它，两者对到 0.1 MHz 量级说明教学模型够用。</p>
<p>工程数值：固定频率 transmon 的 $(tex(raw"g_c/2\pi")) 约 5–20 MHz，折合 J/2π 约 10–50 MHz、iSWAP 门时间 20–50 ns，比 T1（几十 μs）短三个数量级——门必须快，但不是越快越好。另一条边界在失谐：微扰处理 ZZ 要求 dispersive 图像 $(tex(raw"|J/\delta| \ll 1"))，而图 A 的 avoided crossing 附近 $(tex(raw"|J/\delta| \sim 1"))，乘积基标签失效，只能用 dressed 态说话。想同时要「门快」和「ZZ 小」，工业界的标准答案是可调耦合器：闲时把 $(tex(raw"g_c")) 关到近零，开门时才拧开。</p>
""", tone="detail"),
deep_dive("常见误解：ZZ 是「噪声」，把耦合调小就能一劳永逸？", """
<p>先纠正第一个误解：<b>ZZ 不是噪声，是可预测的条件相位</b>。它由器件参数决定、可标定、可补偿——标准做法是把邻居的条件相位记进软件，用虚拟 Z 门免费吃掉，iSWAP 类门也常配 echo 序列消它。真正的噪声是 ZZ 的<b>涨落</b>：磁通/电荷漂移让 ZZ 抖动，那才不可预测。</p>
<p>再纠正第二个：把 $(tex(raw"g_c")) 调小确实让 ZZ 按 $(tex(raw"g_c^2")) 掉、J 只按 $(tex(raw"g_c")) 掉，看起来双赢；但门时间 $(tex(raw"\pi/(2J)")) 与 1/g_c 成正比，小到某个程度，门还没做完态就先被 T1（读数卡 T1q 滑块）收走了。快与干净的矛盾只能靠「换结构」解决——可调耦合器、ZZ 抵消工作点、补偿脉冲——不能靠一味调参。自查：如果你的答案是「把耦合关掉不就好了」，请接着回答「那你的 iSWAP 用什么做」。</p>
""", tone="warn"),
)

# ╔═╡ f0000000-0000-4000-8000-00000000001a
tryout([
	("亲手把两个比特拧到同频，完成一次 iSWAP", "<b>动机</b>：两比特门的前提是可控的频率关系；先把「换座位」做出来，再谈它值多少代价。<br><b>做法</b>：g_c 保持 0.05，把 det2 拖到 0，盯住图 B 的实线与读数卡「转移率」。",
	 "<b>看什么</b>：实线与虚线（共振对照）重合，紫线 |1,0⟩ 从 0 升到 ~1、蓝线 |0,1⟩ 同步掉到 0，读数卡转移率 ~99%，门时间 π/(2J) ≈ 22 ns。<br><b>说明什么</b>：δ = 0 时 $(tex(raw"P_{10}(t) = \sin^2(Jt)")) 完全转移，iSWAP 就是耐心等它走到第一个峰值。<br><b>如果没看到</b>：峰值远低于 1 → det2 没真正归零（转移率 = $(tex(raw"4J^2/(\delta^2+4J^2)"))）；纹丝不动 → g_c 被拖到 0 了，交换率归零。"),
	("把 ZZ 折算成你自己门上的相位误差", "<b>动机</b>：ZZ 的危害只有折算成「几度相位」才有实感，否则它只是读数卡上一个陌生数字。<br><b>做法</b>：固定 g_c = 0.05，把 det2 从 0 拖到 0.06，读「always-on ZZ」；再拖回 0 对比。",
	 "<b>看什么</b>：ZZ 随失谐明显变化（图 D 的橙点不动——它只随 g_c 动），读数卡「失谐 δ」行同步变。<br><b>说明什么</b>：条件相位 = 2π·ZZ·t<sub>gate</sub>，20 ns 门上 ≈ 0.13×(ZZ/MHz) rad ≈ 7°/MHz——ZZ = 1 MHz 就足以在深度线路上堆出百分之一量级的误差。<br><b>如果没看到</b>：ZZ 不随 det2 动 → 看错了读数卡行（图 D 的点确实不动）；ZZ 中途反号也正常——它是两个二阶能移之差，随失谐换号并不奇怪。"),
	("找到你的权衡点：把 g_c 扫一遍", "<b>动机</b>：真实器件设计就是在「门速 vs 串扰」这两条曲线上挑工作点，先亲手摸一次这条权衡。<br><b>做法</b>：把 g_c 从 0.02 拖到 0.2（其它不动），盯图 D。",
	 "<b>看什么</b>：J 沿直线涨、ZZ 沿抛物线涨，π/(2J) 反比掉。<br><b>说明什么</b>：门速 ∝ g_c、串扰 ∝ g_c²——耦合加倍，门快一倍、脏四倍；读数卡把两条曲线的取舍直接写成数字。<br><b>如果没看到</b>：两条线曲率相近 → 看清右轴是 ZZ（双 y 轴，单位相同但刻度不同）；J 完全不动 → g_c 归零，或 det2 太大把有效劈裂吃掉了。"),
	("两能级截断看不见 ZZ（给爱抬杠的你）", "<b>动机</b>：亲证「非谐性是 ZZ 的必要条件」，而不是听我说。<br><b>做法</b>：把 EC 拖到 0.45、g_c 拖到 0.2，看 ZZ 读数。",
	 "<b>看什么</b>：ZZ 不会变成 0——本页始终用 3 能级截断，|1,1⟩ ↔ |2,0⟩ 的通道一直开着。<br><b>说明什么</b>：若只保留 2 能级，counter-rotating 项与非谐性恰好抵消，ZZ ≡ 0——推导第 4、9 步说的正是这件事，这也是为什么研究 ZZ 必须算到 |2⟩。<br><b>如果没看到</b>：若 ZZ 接近 0，多半是 n₀₁ 同步变小（EC 变大 → 振子图像趋坏），对照看 J 是否也一起塌了。"),
])

# ╔═╡ f0000000-0000-4000-8000-00000000001b
quiz([
	("共振时 iSWAP 的 π 门时间是多少？",
	 ["π/J", "π/(2J)", "2π/J", "1/J"], 2,
	 "P₁₀(t) = sin²(Jt)（δ = 0），第一次取到 1 在 t = π/(2J)。<b>错误选项辨析</b>：π/J 是 sin² 的完整振荡周期——那时已经换过去又换回来了（回到 |0,1⟩，门白做成了 I）；2π/J 是两倍周期，同样回到起点；1/J 量纲对但缺 π/2 因子，照它调门会差 36%。"),
	("两个全同 transmon（δ = 0）精确耦合时，为什么「条件频率 ZZ」这个读数会异常？",
	 ["数值误差", "|0,1⟩/|1,0⟩ 已混成 dressed 态，「谁在哪个态」不再有唯一答案", "耦合被关闭了", "非谐性消失"], 2,
	 "δ = 0 时 |01⟩ 与 |10⟩ 强烈杂化成 dressed 态，「qubit1 处于 |1⟩」这种说法失去指称，条件频率的定义随之失效——本页默认给一个小失谐（真实器件也如此）。<b>错误选项辨析</b>：「数值误差」不对——本页是精确对角化，异常来自定义本身而非算错；「耦合被关闭」不对——J 仍然存在，恰是它造成杂化；「非谐性消失」不对——α 只由 EJ/EC 决定，与失谐无关。需要精确同频工作时，改用谱学定义（例如 |11⟩ 的跃迁频率）刻画 ZZ。"),
	("always-on ZZ 的物理根源是？",
	 ["电容耦合的一阶项", "counter-rotating 项 + transmon 非谐性", "T1 衰减", "读取腔色散"], 2,
	 "ZZ 出现在二阶微扰：必须靠成对（counter-rotating）项 + 非谐性（n₁₂ 通道）才能把 |1,1⟩ 与 |0,1⟩/|1,0⟩ 区分开（推导第 4、9 步）。<b>错误选项辨析</b>：「电容耦合的一阶项」是交换项，只搬布居不推频率——它给 J 不给 ZZ；「T1 衰减」是耗散通道，改变布居寿命而非频率；「读取腔色散」确实也条件移频（χ），但那是读取腔与比特的耦合效应，与比特-比特的 ZZ 是两回事。"),
])

# ╔═╡ f0000000-0000-4000-8000-00000000001c
@htl("""
<div style="font-size:14.5px;color:#33384D;line-height:2.0;margin-top:6px">
<p><b>核心机制：</b>一块结间电容 → H_int = g_c·n̂₁n̂₂ → 投影后裂成两半：交换项（σ⁺σ⁻ + h.c.）给出 iSWAP，速率 J = g_c·n₀₁²、门时间 π/(2J)；成对项（σ⁺σ⁺ + h.c.）+ 非谐性 α 给出 always-on ZZ = f(q1|q2=1) − f(q1|q2=0)。三个读数各有图像锚点：J 对上图 A 的最小间距 2J，转移率对上图 B 的峰值 4J²/(δ²+4J²)，ZZ 对上图 D 的橙线。</p>
<p><b>常见误解：</b>「ZZ 是噪声」——错，它是可预测的条件相位，可标定、可补偿（虚拟 Z / echo），只有它的<b>涨落</b>才是噪声；「把耦合调小就双赢」——错，J ∝ g_c 让门先慢死，T1 不等人；「δ = 0 时 ZZ 最好算」——错，全同比特上条件频率失去定义（自测 Q2）；「iSWAP 是把两个比特都激发」——错，它只换座位，总激发数守恒。</p>
<p><b>真实器件里什么样：</b>g_c/2π ≈ 5–20 MHz、J/2π ≈ 10–50 MHz、iSWAP/CZ 门 20–50 ns，ZZ/2π ≈ 0.1–2 MHz；两个比特永远带一点几十 MHz 的失谐，靠磁通调谐拧到需要的工作点。处理器级的通行做法是可调耦合器（闲时把 g_c 关到近零）或 ZZ 抵消工作点，剩下的条件相位用 echo 与虚拟 Z 免费吃掉。</p>
<p><b>下一步：</b><b>磁通调谐</b>看 E_J(Φ) 如何随手拧频率与耦合、如何用甜点把噪声压下去；<b>T1/T2</b> 看这些 μs 级相干时间如何给上面每个门封顶；CZ 磁通脉冲与 chevron 标定是把 |1,1⟩ 的 2π 相位真正做成门的那一步（backlog）。</p>
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
