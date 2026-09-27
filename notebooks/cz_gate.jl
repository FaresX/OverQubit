### A Pluto.jl notebook ###
# v0.20.10

using Markdown

# ╔═╡ c2000001-0000-4000-8000-000000000001
begin
	using PlutoUI, PlotlyBase, Statistics, HypertextLiteral
	include(joinpath(@__DIR__, "..", "src", "OverQubit.jl"))
	include(joinpath(@__DIR__, "..", "src", "OverQubitViz.jl"))
	using .OverQubit, .OverQubitViz
	setup_page()
end

# ╔═╡ c2000001-0000-4000-8000-000000000002
md"""### ① 这一页讲什么：怎么让两个比特「只在对方是 |1⟩ 时」给彼此一个相位

单比特门是「给自己转一个角度」，两比特门要的是「**看对方的情况决定自己转多少**」。
超导量子计算里这个角色几乎总是 CZ 门扮演——而它的实现方式相当 indirect：
**不给两个比特加任何微波，只是把其中一个的约瑟夫森能拧一拧，让能级图上的
|11⟩ 与 |02⟩ 撞一次车**。这一页就是这台「撞车」装置的全解剖。"""

# ╔═╡ c2000001-0000-4000-8000-000000000003
banner("OVERQUBIT · 两比特门", "CZ 门实现原理：一次磁通脉冲如何造出条件相位",
	"把磁通脉冲加在可调比特上，让 |11⟩ ↔ |02⟩ avoided crossing 被穿越一次——激发的「换位」就变成了相位，两比特门成了"; icon="pair")

# ╔═╡ c2000001-0000-4000-8000-000000000004
lesson_nav([
	("①", "transmon 能级与量子化", "done"),
	("②", "单比特门与 Rabi", "done"),
	("③", "DRAG 泄漏压制", "done"),
	("④", "色散读取 S21", "done"),
	("⑤", "两比特耦合与 iSWAP", "done"),
	("⑥", "磁通调谐与能级扇形图", "done"),
	("⑦", "T1 / T2 / Ramsey", "done"),
	("⑧", "CZ 门实现原理", "current"),
	("⑨", "CZ 门校准方案", "todo"),
])

# ╔═╡ c2000001-0000-4000-8000-000000000005
concept_cards([
	("CZ 要什么", "<i>U</i><sub>CZ</sub> = diag(1, 1, 1, −1)（差一个全局相位）：只有 |1,1⟩ 拿到 −1。等价说法：<b>qubit1 的 Bloch 矢量在 qubit2 处于 |1⟩ 时绕 z 轴转 π</b>——C 图的双球动画就是这一幕。"),
	("用什么换", "耦合 n̂₁⊗n̂₂ 把 |1,1⟩ 与 |0,2⟩ 连起来（强度 ≈ g_c·n<sub>01</sub>·n<sub>12</sub>）。磁通把 qubit2 的能级往下拧，|<i>f</i><sub>01</sub>₁ − <i>f</i><sub>01</sub>₂| 一路减小到与 |α| 相当时两条能级相撞、互相推开——这就是 avoided crossing。CZ 的全部机制就是<b>开着脉冲从它身上开过去</b>。"),
	("为什么是 |0,2⟩", "共振条件 <i>E</i><sub>11</sub> = <i>E</i><sub>02</sub> 给出 <i>f</i><sub>01</sub>₁ = <i>f</i><sub>01</sub>2 + α₂，而 α₂ &lt; 0 ⟹ <b>qubit2 要被拖到比 qubit1 高 |α₂| 的位置</b>；又因为 cos πΦ ≤ 1（磁通只会减小 E<sub>J</sub>），所以 <b>idle 点必须更高</b>——真实器件里可调比特总是 idle 在高频侧，就是这个道理。"),
	("快还是慢", "脉冲太慢（绝热）→ 态跟着 dressed 能级走完整趟，{|11⟩、|02⟩} 的混合在结束时回来；太快 → 混合来不及回，|11⟩ 有一部分「卡」在 |02⟩ 出不去，就是<b>泄漏</b>。方沿脉冲的瞬时会额外制造这种非绝热激发（本页可切换对比）。"),
])

# ╔═╡ c2000001-0000-4000-8000-000000000006
callout("本页沿用 ⑤ 的电容耦合模型，但 qubit2 换成 SQUID：<span class=\"oq-kbd\">cz_pair</span> 在<b>固定参考基</b>（Φ=0 的两个本征态）里改写 Ĥ₂(Φ)，Φ=0 时与 <span class=\"oq-kbd\">TwoQubit</span> 的哈密顿量逐项一致（误差 &lt; 1e-12）。能级取 3 个（|2⟩ 是主角，nlev=3 是 CZ 的硬性要求）。脉冲按<b>分段常值</b>推进，每步一个矩阵指数；时间步长收敛性由 <span class=\"oq-kbd\">scripts/validate_cz.jl</span> 回归。",
	tone="info", title="阅读前提")

# ╔═╡ c2000001-0000-4000-8000-000000000007
md"""### ③ 调参（qubit1 固定 + 可调 qubit2 + 结间电容耦合 + 磁通脉冲）"""

# ╔═╡ c2000001-0000-4000-8000-000000000008
@bind EJ Slider(5:0.5:40; default=20)

# ╔═╡ c2000001-0000-4000-8000-000000000009
@bind EC Slider(0.05:0.01:0.5; default=0.30)

# ╔═╡ c2000001-0000-4000-8000-00000000000a
@bind g_c Slider(0.0:0.005:0.20; default=0.03)

# ╔═╡ c2000001-0000-4000-8000-00000000000b
@bind ratio2 Slider(1.0:0.01:1.45; default=1.20)

# ╔═╡ c2000001-0000-4000-8000-00000000000c
@bind amp_phi Slider(0.0:0.002:0.30; default=0.073)

# ╔═╡ c2000001-0000-4000-8000-00000000000d
@bind t_pulse Slider(10:0.5:60; default=37.5)

# ╔═╡ c2000001-0000-4000-8000-00000000000e
@bind shape_sel Select(["方沿", "平滑沿"]; default="平滑沿")

# ╔═╡ c2000001-0000-4000-8000-00000000000f
begin
	NCUT = 40
	shape_kind = shape_sel == "方沿" ? :flat : :taper
	# 器件：qubit1 频率固定，qubit2 idle 在更高频（ratio2 × EJ）
	dev = cz_pair(EJ, EJ * ratio2, EC, g_c; nlev=3, ncut=NCUT)
	# 谱学：|11⟩ ↔ |02⟩ avoided crossing 的磁通 Φ* 与最小间距 2V
	phi_s, gap_s = cz_crossing(dev; span=0.45, npoints=181)
	# 演化：当前脉冲参数下的全部门质量读数
	r = cz_evolve(dev, amp_phi, t_pulse; kind=shape_kind, dt=0.05)
	phase, phase_err, leak, f_proc, f_state = cz_metrics(r)
	p1, in_sub = cz_ramsey(cz_zcorrect(r), r.nlev)       # 实验口径（虚拟 Z 已校正）
	p1_q2_1, p1_q2_0, phase_pair = cz_ramsey_pair(r)     # 信号 / 参考两条序列 + 条件相位
	max_p02 = maximum(r.pops11[:, basis_index(dev, 0, 2)])
	# 频率读数（idle / 脉冲峰值）
	t2idle = Transmon(cz_squid_ej(dev, 0.0), EC; ncut=NCUT)
	f01_1, f12_1 = f01_f12(dev.t1, 0.0)
	f01_2, f12_2 = f01_f12(t2idle, 0.0)
	f01_2_pk = f01_f12(Transmon(cz_squid_ej(dev, amp_phi), EC; ncut=NCUT), 0.0)[1]
	alpha2 = f12_2 - f01_2
	det_idle = f01_1 - f01_2
	det_peak = f01_1 - f01_2_pk
	# 读数卡字符串
	ph_s = string(round(phi_s, digits=4)); gap_s = string(round(gap_s * 1000, digits=1))
	det_idle_s = string(round(det_idle * 1000, digits=0)); det_peak_s = string(round(det_peak * 1000, digits=0))
	phase_s = string(round(phase, digits=3)); err_s = string(round(phase_err, digits=3))
	leak_s = string(round(100leak, digits=2)); fstate_s = string(round(100f_state, digits=2))
	p1_s = string(round(p1, digits=3)); p1pair_s = string(round(p1_q2_1, digits=3))
	p1ref_s = string(round(p1_q2_0, digits=3))
	maxp02_s = string(round(100max_p02, digits=1))
	amp_ratio_s = string(round(100 * abs(amp_phi / max(phi_s, 1e-9)), digits=0))
	alpha_s = string(round(1000alpha2, digits=0))
	nothing
end

# ╔═╡ c2000001-0000-4000-8000-000000000010
stat_row([
	("条件相位 φ<sub>CZ</sub>（mod 2π）", "$(phase_s) rad", "目标 π = 3.1416；残差 $(err_s) rad", phase_err < 0.1 ? "#22C3A6" : "#F5A623"),
	("门保真度（4 计算态平均）", "$(fstate_s)%", "过程保真度 $(string(round(100f_proc, digits=1)))%", "#4C6FFF"),
	("泄漏（跑到 |0,2⟩ 等）", "$(leak_s)%", "脉冲中途最多 $(maxp02_s)% 到过 |0,2⟩", "#B8812E"),
	("|11⟩↔|02⟩ avoided crossing", "Φ* = $(ph_s)", "最小间距 2V = $(gap_s) MHz", "#7B61FF"),
	("当前脉冲峰值磁通", "$(amp_phi) Φ₀", "= Φ* 的 $(amp_ratio_s)%；峰值失谐 $(det_peak_s) MHz", "#1A1A2E"),
	("Ramsey 读数 P<sub>1</sub>", "$(p1_s)", "信号 $(p1pair_s) / 参考序列 $(p1ref_s)（⑨）", "#22C3A6"),
])

# ╔═╡ c2000001-0000-4000-8000-000000000011
callout("三件事一起看：<b>A 图</b>是操作台——|11⟩ 与 |02⟩ 只在一处靠近，脉冲的任务就是把工作点拖过去再拖回来；<b>B 图</b>是过程——条件相位在 |0,2⟩ excursion 期间累积，末值 ≃ π 就是门；<b>C 图</b>是效果——qubit2 全程没被微波驱动，qubit1 的 Bloch 矢量却绕 z 转了 π。",
	tone="tip", title="看什么")

# ╔═╡ c2000001-0000-4000-8000-000000000012
begin
	# A · 能级扇形：|11⟩ 与 |02⟩ 的 avoided crossing（沿着磁通扫过去）
	phis_s = collect(range(0.0, 0.30; length=121))
	E11 = zeros(length(phis_s)); E02 = zeros(length(phis_s))
	E01 = zeros(length(phis_s)); E10 = zeros(length(phis_s))
	for (i, φ) in enumerate(phis_s)
		E11[i] = cz_level_energy(dev, φ, 1, 1)
		E02[i] = cz_level_energy(dev, φ, 0, 2)
		E01[i] = cz_level_energy(dev, φ, 0, 1)
		E10[i] = cz_level_energy(dev, φ, 1, 0)
	end
	ytop = 1.1 * maximum([E11; E02; E01; E10]) * 1000
	icross = argmin(E11 .- E02)
	tr = PlotlyBase.GenericTrace[]
	push!(tr, PlotlyBase.scatter(x=phis_s, y=E01 * 1000; mode="lines", name="|0,1⟩ / |1,0⟩（远离）",
		line=attr(color="#8A90AD", width=1.5, dash="dash")))
	push!(tr, PlotlyBase.scatter(x=phis_s, y=E10 * 1000; mode="lines",
		line=attr(color="#8A90AD", width=1.5, dash="dash"), showlegend=false))
	push!(tr, PlotlyBase.scatter(x=phis_s, y=E11 * 1000; mode="lines", name="|1,1⟩ dressed 能级",
		line=attr(color=PAL[1], width=3)))
	push!(tr, PlotlyBase.scatter(x=phis_s, y=E02 * 1000; mode="lines", name="|0,2⟩ dressed 能级",
		line=attr(color=PAL[4], width=3)))
	push!(tr, PlotlyBase.scatter(x=[phi_s, phi_s], y=[0, ytop]; mode="lines",
		line=attr(color="#FF7A7A", width=2, dash="dot"), name="Φ*（最低点）"))
	push!(tr, PlotlyBase.scatter(x=[amp_phi, amp_phi], y=[0, ytop]; mode="lines",
		line=attr(color=PAL[2], width=2, dash="dash"), name="当前脉冲峰值"))
	push!(tr, PlotlyBase.scatter(x=[phi_s], y=[(E11[icross] + E02[icross]) / 2 * 1000];
		mode="markers", marker=attr(size=11, color="#FF7A7A", line=attr(color="white", width=2)), showlegend=false))
	ann = [attr(x=phi_s, y=0.97 * ytop, text="avoided crossing：最小间距 2V = $(gap_s) MHz",
		showarrow=false, font=attr(size=12, color="#C2543A"), yanchor="top"),
		attr(x=amp_phi, y=0.03 * ytop, text="当前", showarrow=false, font=attr(size=11, color=PAL[2]))]
	pfan = PlotlyBase.Plot(tr, layout_base(height=470,
		title="A · 操作台：磁通把 |11⟩ 与 |02⟩ 拖到互相推开",
		xtitle="归一化磁通 Φ / Φ₀（加在可调 qubit2 上）", ytitle="相对 |0,0⟩ 的能量 (MHz)", annotations=ann))
	plotly_html("oq_cz_fan", pfan; height=480)
end

# ╔═╡ c2000001-0000-4000-8000-000000000013
figure_note("两条实线<b>近似但不相交</b>——最靠近处差 2V（隧穿耦合）。|0,1⟩/|1,0⟩ 离得远远的（|δ| ≫ J），iSWAP 全程不会发生，脉冲期间的激发交换被彻底压制。")

# ╔═╡ c2000001-0000-4000-8000-000000000014
begin
	# B1 · 磁通轨迹 Φ(t)
	tr = PlotlyBase.GenericTrace[]
	push!(tr, PlotlyBase.scatter(x=r.times, y=r.phis; mode="lines", name="Φ(t)",
		line=attr(color=PAL[2], width=2.5)))
	push!(tr, PlotlyBase.scatter(x=r.times, y=fill(phi_s, length(r.times)); mode="lines", name="Φ*",
		line=attr(color="#FF7A7A", width=1.5, dash="dot")))
	ppulse = PlotlyBase.Plot(tr, layout_base(height=250,
		title="B1 · 磁通脉冲（起止都回到 idle 的 Φ = 0）", xtitle="时间 (ns)", ytitle="Φ / Φ₀"))
	# B2 · 条件相位累积 + |0,2⟩ excursion
	tr2 = PlotlyBase.GenericTrace[]
	push!(tr2, PlotlyBase.scatter(x=r.times, y=r.cphase; mode="lines", name="条件相位 φ<sub>CZ</sub>(t)",
		line=attr(color=PAL[1], width=3), yaxis="y"))
	push!(tr2, PlotlyBase.scatter(x=r.times, y=r.pops11[:, basis_index(dev, 0, 2)]; mode="lines",
		name="|0,2⟩ 布居（|1,1⟩ 出发）", line=attr(color=PAL[4], width=2.5), yaxis="y2"))
	push!(tr2, PlotlyBase.scatter(x=r.times, y=fill(π, length(r.times)); mode="lines", name="π（CZ 目标）",
		line=attr(color="#22C3A6", width=1.5, dash="dot")))
	lay = layout_base(height=300, title="B2 · 相位在 excitation 期间累积；末值 ≃ π 即 CZ 门",
		xtitle="时间 (ns)", ytitle="条件相位 (rad)")
	lay.yaxis2 = attr(title="|0,2⟩ 布居", overlaying="y", side="right",
		gridcolor="rgba(0,0,0,0)", zerolinecolor="rgba(0,0,0,0)",
		tickfont=attr(size=11, color="#B8812E"), titlefont=attr(size=12, color="#B8812E"))
	pph = PlotlyBase.Plot(tr2, lay)
	oq_stack(plotly_html("oq_cz_pulse", ppulse; height=260), plotly_html("oq_cz_phase", pph; height=310))
end

# ╔═╡ c2000001-0000-4000-8000-000000000015
begin
	# C · 双 Bloch 球：qubit2 全程无微波，qubit1 的条件 Bloch 矢量绕 z 转 π
	function sphere(x0)
		out = PlotlyBase.GenericTrace[]
		for lat in [-60, -30, 0, 30, 60]
			φ = deg2rad(lat); rr = cos(φ); z = fill(sin(φ), length(lons))
			push!(out, PlotlyBase.scatter3d(x=x0 .+ rr .* cosd.(lons), y=rr .* sind.(lons), z=z; mode="lines",
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
	for s in sphere(-1.6); push!(tr, s); end
	for s in sphere(1.6); push!(tr, s); end
	push!(tr, PlotlyBase.scatter3d(x=[1.6], y=[0.0], z=[-1.0]; mode="markers", marker=attr(size=9,
		color=PAL[2], line=attr(color="white", width=2)), name="qubit2 = |1⟩（不动）"))
	step = max(1, div(size(r.times, 1), 300))
	push!(tr, PlotlyBase.scatter3d(x=-1.6 .+ r.cond_bloch[1:step:end, 1], y=r.cond_bloch[1:step:end, 2],
		z=r.cond_bloch[1:step:end, 3]; mode="lines", line=attr(color=PAL[1], width=5), name="qubit1 条件 Bloch 轨迹"))
	push!(tr, PlotlyBase.scatter3d(x=[-1.6 + r.cond_bloch[1, 1]], y=[r.cond_bloch[1, 2]], z=[r.cond_bloch[1, 3]];
		mode="markers", marker=attr(size=7, color="#22C3A6"), name="起始 |+⟩"))
	ann = [attr(x=-1.6, y=0, z=1.42, text="|0⟩₁", showarrow=false, font=attr(size=12, color="#22C3A6")),
		attr(x=1.6, y=0, z=1.42, text="|0⟩₂", showarrow=false, font=attr(size=12, color="#22C3A6")),
		attr(x=-1.6, y=0, z=-1.42, text="|1⟩₁", showarrow=false, font=attr(size=12, color="#22C3A6"))]
	nfr = 48
	fidx = round.(Int, range(1, size(r.times, 1); length=nfr))
	# 条件 Bloch 动画红点作为最后一条专用 trace（只更新它，否则会顶掉第一条纬线）
	push!(tr, PlotlyBase.scatter3d(x=[-1.6 + r.cond_bloch[1, 1]], y=[r.cond_bloch[1, 2]],
		z=[r.cond_bloch[1, 3]]; mode="markers",
		marker=attr(size=9, color="#FF7A7A", line=attr(color="white", width=2)),
		showlegend=false, hoverinfo="skip"))
	BALL = length(tr) - 1              # 0 基索引
	frames = PlotlyBase.PlotlyFrame[]
	for i in fidx
		push!(frames, anim_frame(BALL, string(i), PlotlyBase.scatter3d(
			x=[-1.6 + r.cond_bloch[i, 1]], y=[r.cond_bloch[i, 2]], z=[r.cond_bloch[i, 3]];
			mode="markers", marker=attr(size=9, color="#FF7A7A", line=attr(color="white", width=2)),
			showlegend=false, hoverinfo="skip")))
	end
	pbloch = PlotlyBase.Plot(tr, Layout(
		title=attr(text="C · 条件 Bloch 球：qubit2 在 |1⟩ 时 qubit1 绕 z 转 π（点播放）", font=attr(size=16, color=INK)),
		scene=attr(aspectmode="cube", xaxis=attr(visible=false), yaxis=attr(visible=false),
			zaxis=attr(visible=false), annotations=ann, camera=attr(eye=attr(x=0.9, y=-2.0, z=1.2))),
		font=attr(family=FONT), paper_bgcolor="white", margin=attr(l=10, r=10, t=52, b=10), height=520,
		updatemenus=animation_menu(),
		legend=attr(orientation="h", y=1.03, x=0.15, bgcolor="rgba(0,0,0,0)", font=attr(size=11, color=SUB))), frames)
	plotly_html("oq_cz_bloch", pbloch; height=530)
end

# ╔═╡ c2000001-0000-4000-8000-000000000016
begin
	# D · 相位 fringe：固定幅度扫长度——两个旋钮必须一起调的原因
	function cphase_at(dev, amp, L; kind, dt)
		rr = cz_evolve(dev, amp, L; kind=kind, dt=dt)
		cz_conditional_phase(rr.Urel, dev.nlev)
	end
	lens = collect(18.0:2.0:44.0)
	fracs = [0.6, 0.85, 1.05]
	trs = [begin
		cph = [cphase_at(dev, fa * phi_s, L; kind=shape_kind, dt=0.15) for L in lens]
		PlotlyBase.scatter(x=lens, y=cph; mode="lines+markers",
			name="幅度 = $(string(round(fa, digits=2)))·Φ*", line=attr(color=PAL[k], width=2.5))
	end for (k, fa) in enumerate(fracs)]
	tr = PlotlyBase.GenericTrace[]
	for t in trs; push!(tr, t); end
	push!(tr, PlotlyBase.scatter(x=lens, y=fill(π, length(lens)); mode="lines", name="π（CZ 目标）",
		line=attr(color="#22C3A6", width=1.5, dash="dot")))
	lay = layout_base(height=400, title="D · 相位 fringe：φ<sub>CZ</sub> 随脉冲长度扫过 π",
		xtitle="脉冲长度 (ns)", ytitle="条件相位 φ<sub>CZ</sub> (rad)")
	pfr = PlotlyBase.Plot(tr, lay)
	plotly_html("oq_cz_fringe", pfr; height=410)
end

# ╔═╡ c2000001-0000-4000-8000-000000000017
figure_note("三条曲线在 π 处的斜率都很陡（dφ/dL ≈ 0.2 rad/ns）——所以要<b>两个旋钮一起调</b>：幅度决定「开进去多深」（相位的量级），长度决定「积累多久」（相位的精细值）。⑨ 讲的就是这件事的实验流程。")

# ╔═╡ c2000001-0000-4000-8000-000000000018
begin
	# E · 末态相对传播子的模方热图：计算子空间内应近似对角
	labs = ["00", "01", "02", "10", "11", "12", "20", "21", "22"]
	Z = abs2.(r.Urel)
	pe = PlotlyBase.heatmap(z=Z, x=1:9, y=1:9; colorscale="Blues", showscale=true,
		colorbar=attr(title="|⟨f|U|i⟩|²", tickfont=attr(size=10, color=SUB), titlefont=attr(size=11, color=SUB)),
		text=[string(round(Z[i, j], digits=3)) for i in 1:9, j in 1:9],
		texttemplate="%{text}", textfont=attr(size=9, color="#33384D"), xgap=1, ygap=1)
	axx = attr(title="末态 ⟨f|", gridcolor=GRID, zerolinecolor=AXIS, linecolor=AXIS,
		tickfont=attr(size=11, color=SUB), titlefont=attr(size=12, color=SUB), tickvals=1:9, ticktext=labs)
	axy = attr(title="初态 |i⟩", gridcolor=GRID, zerolinecolor=AXIS, linecolor=AXIS,
		tickfont=attr(size=11, color=SUB), titlefont=attr(size=12, color=SUB), tickvals=1:9, ticktext=labs)
	lay = Layout(title=attr(text="E · 末态相对传播子 |U_rel|²：计算态应打在计算态上（行列序为 |k1,k2⟩）",
		font=attr(size=14, color=INK)), xaxis=axx, yaxis=axy, font=attr(family=FONT),
		plot_bgcolor="white", paper_bgcolor="white", margin=attr(l=56, r=24, t=68, b=48), height=430,
		legend=attr(orientation="h", y=1.02, x=0.0, bgcolor="rgba(0,0,0,0)", font=attr(size=11, color=SUB)))
	pe2 = PlotlyBase.Plot(pe, lay)
	plotly_html("oq_cz_U", pe2; height=440)
end

# ╔═╡ c2000001-0000-4000-8000-000000000019
callout("对角线上四个格子的幅值平方都 ≈ 1、|0,2⟩ 那一行只有中心一点亮——脉冲把 |1,1⟩ 送去 |0,2⟩ 兜了一圈又<b>原封不动</b>送回来，只在相位上留下差别。出不来就是泄漏（B2 图橙线的末值）。",
	tone="info", title="怎么读 E 图")

# ╔═╡ c2000001-0000-4000-8000-00000000001a
divider()

# ╔═╡ c2000001-0000-4000-8000-00000000001b
derivation("⑧ 推导溯源：从结间电容到 CZ 的条件相位",
	[
	("定义", texblock(raw"H(\Phi) = \hat H_1\otimes I + I\otimes\hat H_2(\Phi) + 2\pi\,g_c\,\hat n_1\otimes\hat n_2"), texblock(raw"E_{J2}(\Phi) = E_{J2}\,\big(\cos(\pi\Phi) + D\big)")),
	("定义", texblock(raw"H = \hat H_1\otimes I + I\otimes\hat H_2(\Phi) \quad(\text{耦合项见下一步})"), "两比特哈密顿量（qubit2 是 SQUID）。耦合不是外加的（⑤ 已讲）；这一页新增的只有磁通拧 $(tex(raw"E_{J2}"))。参照 ⑥ 的 `squid_ej`。"),
	("代入", texblock(raw"f_{01} \propto \sqrt{E_J E_C}, \qquad f_{12} = f_{01} + \alpha(\Phi)"), "$(tex(raw"|\Phi|")) 越大 → $(tex(raw"E_J")) 越小 → qubit2 的整条能级梯子往下压。所以「拖过 avoided crossing」本质是**拧 $(tex(raw"E_J"))**，这也是频率只能往下调的原因（$(tex(raw"\cos\pi\Phi \le 1"))）。"),
	("定义", texblock(raw"U_{\mathrm{CZ}}\,|x\rangle = \begin{cases} |x\rangle, & x \neq |1,1\rangle \\ -|1,1\rangle, & x = |1,1\rangle \end{cases}"), "目标门把 $(tex(raw"|00\rangle,|01\rangle,|10\rangle")) 照原样留下，只把 $(tex(raw"|11\rangle")) 变成负的（差一个全局相位）。等价表述：qubit1 的相位依赖 qubit2 处在哪个态——「条件」二字的意思。"),
	("代入", texblock(raw"\langle 0,2|H|1,1\rangle \approx g_c\,n_{01}\,n_{12} \equiv V"), "投影到 3 能级后 $(tex(raw"\hat n")) 的相邻矩阵元 $(tex(raw"n_{01},n_{12}\neq 0"))，耦合项把 $(tex(raw"|1,1\rangle")) 与 $(tex(raw"|0,2\rangle")) 连起来。"),
	("整理", texblock(raw"\text{共振条件: }\ E_{11} = E_{02} \Rightarrow f_{01}^{(1)} = f_{01}^{(2)} + \alpha_2 \quad (\alpha_2 < 0)"), texblock(raw"\Rightarrow\quad \text{加耦合后最小间距} = 2V")),
	("整理", texblock(raw"\Delta E_{\min} = 2V \quad(\text{avoided crossing 宽度})"), "图 A 的 avoided crossing。$(tex(raw"\Phi^{*}")) 由 `cz_crossing` 扫出；读数卡里「idle 失谐」与「峰值失谐」就是在对照这个条件（当前 $(tex(raw"\alpha_2")) = $(alpha_s) MHz）。"),
	("近似", texblock(raw"\text{绝热极限: }\ \Delta\varphi_{\mathrm{CZ}} \approx -\int\!\Big[\lambda_-(t) - E_{11}^{\mathrm{diabatic}}(t)\Big]\,dt"), "物理图像：耦合把 $(tex(raw"|11\rangle")) 那条能级在穿越时往下压了一段，走过的路程变了，相位就变了——「绕远路」攒下的相位就是条件相位。"),
	("整理", texblock(raw"\varphi_{\mathrm{CZ}} = \varphi_{00} - \varphi_{01} - \varphi_{10} + \varphi_{11} \pmod{2\pi}, \qquad \varphi_{\mathrm{CZ}}^{\mathrm{ideal}} = \pi"), "四个计算态各跑一次演化（U 的 4 列）。为什么减三个：三个单激发态的**动态相位**（~13 GHz 量级）不是我们要的，相减后剩下的正是耦合贡献。实验上靠 ⑨ 的参考序列完成这个减法。"),
	("微扰", texblock(raw"\text{非绝热项} \propto \frac{V}{t_{\mathrm{rise}}} \ \Rightarrow\ \text{方沿脉冲把布居甩到}\ |0,2\rangle \ (\text{泄漏})"), "平滑沿把边沿摊开可把它压掉 1-2 个数量级。切换「方沿 / 平滑沿」即可对比（当前泄漏 $(leak_s)%）。脉冲整体太短同样泄漏——⑨ 的 chevron 图里那些暗谷就是这么来的。"),
	];
	lead="每一步都可点开。读数卡的 φ<sub>CZ</sub>、泄漏、保真度与这里的步骤一一对应。",
	result="当前参数：Φ* = $(ph_s)（2V = $(gap_s) MHz），脉冲峰值 $(amp_phi) Φ₀ = Φ* 的 $(amp_ratio_s)%，长度 $(t_pulse) ns，$(shape_sel) → φ<sub>CZ</sub> = $(phase_s) rad（残差 $(err_s) rad），泄漏 $(leak_s)%，4 态保真度 $(fstate_s)%，Ramsey P₁ = $(p1_s)。")

# ╔═╡ c2000001-0000-4000-8000-00000000001c
tryout([
	("亲手把 φ<sub>CZ</sub> 拧到 π", "固定长度 37.5 ns，把「脉冲峰值磁通」在 0.060–0.090 之间缓慢拖，盯读数卡第一行的残差。",
	 "残差会在 0.073 附近掉到 0.03 rad 以下、同时泄漏 &lt; 1%——这就是一个可用的 CZ 工作点。注意最优幅度<b>不是</b>恰好 Φ*：相位主要在靠近 crossing 的过程中累积，不必完全开进去。"),
	("把脉冲开太短 / 太长", "保持幅度 0.073，把长度拖到 12 ns；再拖到 55 ns。",
	 "短：|0,2⟩ excursion 之后回不来，泄漏冲到几十 %；长：绝热性好，但 fringe 很陡（约 0.2 rad/ns）、实验上更难稳住，且占时钟预算。真实器件一般取 25–40 ns。"),
	("方沿 vs 平滑沿", "切换波形选择，对比读数卡泄漏项与 B2 图橙线的末值。",
	 "方沿的瞬时会制造额外的非绝热激发，泄漏比平滑沿高约一个量级——「脉冲形状也是校准对象」最直接的证据。"),
	("把耦合拧大", "g_c 从 0.03 拖到 0.06（2V 跟着变），重新找最优幅度。",
	 "隧穿耦合加大 → 同样长度能积累更多相位、门可以更快；但 avoided crossing 离 idle 更近，idle 的 ZZ 串扰也更大。⑨ 的 chevron 就是在这条权衡里挑工作点。"),
])

# ╔═╡ c2000001-0000-4000-8000-00000000001d
quiz([
	("理想 CZ 门在计算基下的矩阵形式是？",
	 ["diag(1, 1, −1, 1)", "diag(1, 1, 1, −1)", "交换 |01⟩ 与 |10⟩", "给所有态加 −1"], 2,
	 "U<sub>CZ</sub> = diag(1,1,1,−1)（全局相位可差 e<sup>iθ</sup>）。只有 |1,1⟩ 拿到 −1——「条件」相位。交换 |01⟩/|10⟩ 那是 iSWAP（⑤ 的主题）。"),
	("|1,1⟩ ↔ |0,2⟩ 发生共振的条件是？",
	 ["f01₁ = f01₂", "f01₁ = f01₂ + α₂（α₂ < 0）", "f12₂ = 0", "两个比特完全同频"], 2,
	 "E<sub>11</sub> = f01₁ + f01₂，E<sub>02</sub> ≈ 2f01₂ + α₂ → 共振时 f01₁ = f01₂ + α₂。因为 α₂ &lt; 0，qubit2 要被拖到比 qubit1 高 |α₂|；又因为磁通只能减小 E_J，所以 idle 点必须设得更高。"),
	("条件相位为什么要把 φ₀₀、φ₀₁、φ₁₀ 一起减掉？",
	 ["为了数值稳定", "减掉单比特动态相位，只留耦合贡献", "为了让门保持酉", "为了消掉 T1 衰减"], 2,
	 "对角相位以 ~13 GHz 的速率转圈（动态相位），直接比会完全混叠；四态相减剩下的正是实验参考序列（qubit2 置 |0⟩ 再跑一遍）测到的量。见 ⑨。"),
	("脉冲太短时 CZ 的主要失效模式是？",
	 ["相位累积太快", "非绝热激发把布居甩到 |0,2⟩ 回不来（泄漏）", "比特被推到能级之外", "出现 iSWAP 交换"], 2,
	 "绝热条件要求脉冲足够慢：V/t<sub>rise</sub> 小、穿越时间远长于 1/(2V)。不满足就泄漏。iSWAP 不会发生，因为 |0,1⟩/|1,0⟩ 全程离共振很远。"),
])

# ╔═╡ c2000001-0000-4000-8000-00000000001e
@htl("""
<div style="font-size:14.5px;color:#33384D;line-height:2.0;margin-top:6px">
<p><b>CZ 的 indirect 之处：</b>单比特门是「直接转它」，CZ 却是「把别人的频率拧过去撞一次车，靠绕远路攒出相位」。超导量子计算里的两比特门几乎都是这个套路（磁通脉冲、可调耦合器、CR 驱动门都逃不掉「借能级」这一步）。</p>
<p><b>两个数字决定一个门：</b><b>Φ*</b>（往哪撞，谱学定）与<b>长度</b>（攒多少，靠 fringe 定）。前者由器件版图给出，后者每次开机、每过一阵都要重新校——这就是下一页的全部内容。</p>
<p><b>下一步去哪：</b><b>⑨ CZ 门校准方案</b> 用 chevron 二维扫描把这两个工作点找出来，并拆解误差预算（相位欠/过旋转、泄漏、退相干、波形边沿）；<b>⑦ T1/T2</b> 决定这些误差的量级上限。</p>
</div>
""")

# ╔═╡ Cell order:
# ╟─c2000001-0000-4000-8000-000000000001
# ╠═c2000001-0000-4000-8000-000000000002
# ╠═c2000001-0000-4000-8000-000000000003
# ╠═c2000001-0000-4000-8000-000000000004
# ╠═c2000001-0000-4000-8000-000000000005
# ╠═c2000001-0000-4000-8000-000000000006
# ╠═c2000001-0000-4000-8000-000000000007
# ╟─c2000001-0000-4000-8000-000000000008
# ╟─c2000001-0000-4000-8000-000000000009
# ╟─c2000001-0000-4000-8000-00000000000a
# ╟─c2000001-0000-4000-8000-00000000000b
# ╟─c2000001-0000-4000-8000-00000000000c
# ╟─c2000001-0000-4000-8000-00000000000d
# ╟─c2000001-0000-4000-8000-00000000000e
# ╟─c2000001-0000-4000-8000-00000000000f
# ╠═c2000001-0000-4000-8000-000000000010
# ╠═c2000001-0000-4000-8000-000000000011
# ╟─c2000001-0000-4000-8000-000000000012
# ╠═c2000001-0000-4000-8000-000000000013
# ╟─c2000001-0000-4000-8000-000000000014
# ╟─c2000001-0000-4000-8000-000000000015
# ╟─c2000001-0000-4000-8000-000000000016
# ╠═c2000001-0000-4000-8000-000000000017
# ╟─c2000001-0000-4000-8000-000000000018
# ╠═c2000001-0000-4000-8000-000000000019
# ╠═c2000001-0000-4000-8000-00000000001a
# ╠═c2000001-0000-4000-8000-00000000001b
# ╠═c2000001-0000-4000-8000-00000000001c
# ╠═c2000001-0000-4000-8000-00000000001d
# ╠═c2000001-0000-4000-8000-00000000001e
