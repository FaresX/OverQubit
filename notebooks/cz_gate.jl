### A Pluto.jl notebook ###
# v1.0.3

using Markdown
using InteractiveUtils

# This Pluto notebook uses @bind for interactivity. When running this notebook outside of Pluto, the following 'mock version' of @bind gives bound variables a default value (instead of an error).
macro bind(def, element)
    #! format: off
    return quote
        local iv = try Base.loaded_modules[Base.PkgId(Base.UUID("6e696c72-6542-2067-7265-42206c756150"), "AbstractPlutoDingetjes")].Bonds.initial_value catch; b -> missing; end
        local el = $(esc(element))
        global $(esc(def)) = Core.applicable(Base.get, el) ? Base.get(el) : iv(el)
        el
    end
    #! format: on
end

# ╔═╡ c2000001-0000-4000-8000-000000000001
begin
	using PlutoUI, PlotlyBase, Statistics, HypertextLiteral
	include(joinpath(@__DIR__, "..", "src", "OverQubit.jl"))
	using .OverQubit
	setup_page()
end

# ╔═╡ c2000001-0000-4000-8000-000000000002
md"""### ① 这一页讲什么：怎么让两个比特「只在对方是 |1⟩ 时」给彼此一个相位

单比特门是「给自己转一个角度」，两比特门要的是「**看对方的情况决定自己转多少**」。
超导量子计算里这个角色几乎总是 CZ 门扮演——而它的实现方式相当 indirect：
**不给两个比特加任何微波，只是把其中一个的约瑟夫森能拧一拧，让能级图上的
|11⟩ 与 |02⟩ 撞一次车**。这一页就是这台「撞车」装置的全解剖。"""

# ╔═╡ c2000001-0000-4000-8000-000000000003
oq_stack(
banner("OVERQUBIT · 两比特门", "CZ 门实现原理：一次磁通脉冲如何造出条件相位",
	"把磁通脉冲加在可调比特上，让 |11⟩ ↔ |02⟩ avoided crossing 被穿越一次——激发的「换位」就变成了相位，两比特门成了"; icon="pair"),
HTMLStr("""<div style="margin-top:10px;font-size:13.5px;color:#33384D;line-height:1.9;max-width:78ch"><b>读完这页你能：</b>
① 说清 CZ 的条件相位<b>从哪来</b>——不是磁通给的，是能级靠近时的相互作用攒出来的；
② 徒手写出共振条件 $(tex(raw"f_{01}^{(1)} = f_{01}^{(2)} + \alpha_2"))，并解释为什么可调比特的 idle 点必须设在<b>高频侧</b>；
③ 判断一次脉冲能不能用——同时看相位残差与泄漏，并说清为什么<b>「暗 ≠ 好」</b>。</div>"""),
)

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
oq_stack(
callout("CZ 门是两比特门的主角：它只在「两个比特都是 |1⟩」时给出一个 $(tex(raw"\pi")) 的相位，其它情况一律不动。
听起来简单，做起来难——<b>因为没有任何旋钮能直接作用到 |1,1⟩ 上</b>。
这一页讲清三件事：相位要<b>从哪里来</b>（能级靠近时的量子隧穿）、<b>怎么把它做成条件的</b>（让 |1,1⟩ 专门去和 |0,2⟩ 打交道）、
<b>怎么不付出代价</b>（绝热与非绝热之间的泄漏权衡）。
建议读法：先看 A 图的能级扇形图建立「操作台」图像 → 拖脉冲幅度/长度看 B 图的相位累积 → 再回头看推导链，那里解释每一步<b>为什么</b>成立。",
	tone="info", title="① 这一页讲什么：把「条件相位」造出来"),
concept_cards([
	("CZ 要什么", "$(tex(raw"U_{\mathrm{CZ}} = \mathrm{diag}(1,1,1,-1)"))（差一个全局相位）：|00⟩、|01⟩、|10⟩ 照原样留下，只有 |1,1⟩ 拿到一个 −1。<br><br>等价说法：<b>qubit1 的 Bloch 矢量在 qubit2 处于 |1⟩ 时绕 z 轴转 $(tex(raw"\pi"))</b>——C 图的双球动画演的就是这一幕。<br><br>难点在于没有任何旋钮能直接「摸到」|1,1⟩。所有两比特门都得绕道：把 |1,1⟩ 送到另一个能级附近，借那里的相互作用攒相位，再送回来。"),
	("用什么换", "耦合项 $(tex(raw"\hat n_1\otimes\hat n_2")) 把 |1,1⟩ 与 |0,2⟩ 连起来，强度 $(tex(raw"V \approx g_c\,n_{01}n_{12}"))（本页量级几十 MHz）。<br><br>磁通把 qubit2 的能级往下拧，$(tex(raw"|f_{01}^{(1)} - f_{01}^{(2)}|")) 一路减小，到与 $(tex(raw"|\alpha_2|")) 相当时两条能级「相撞」并互相推开——这就是 <b>avoided crossing</b>。<br><br><b>CZ 的全部机制就是开着脉冲从它身上开过去</b>：靠近时混合起来，走开时混回来，只有相位记住了这段路。"),
	("为什么是 |0,2⟩", "共振条件 $(tex(raw"E_{11} = E_{02}")) 给出 $(tex(raw"f_{01}^{(1)} = f_{01}^{(2)} + \alpha_2"))，而 $(tex(raw"\alpha_2 < 0")) ⟹ qubit2 要被拖到比 qubit1 <b>高</b> $(tex(raw"|\alpha_2|")) 的位置。<br><br>又因为 $(tex(raw"\cos(\pi\Phi) \le 1"))——磁通只会减小 $(tex(raw"E_J"))、不能增大——所以 <b>idle 点必须更高</b>：真实器件里可调比特总是 idle 在高频侧，就是这个道理。<br><br>还有一点很关键：|0,2⟩ 与 |1,1⟩ 只差 $(tex(raw"|\alpha_2|"))（几百 MHz），而 |0,1⟩/|1,0⟩ 离得远远的——所以 |1,1⟩ 有<b>专属舞伴</b>，别的态不参与。"),
	("快还是慢", "脉冲<b>太慢</b>（绝热）：态跟着 dressed 能级走完整趟，{|11⟩,|02⟩} 的混合在结束时回来，只留下相位——这是理想情况。<br><br><b>太快</b>：混合来不及回，|1,1⟩ 有一部分「卡」在 |0,2⟩ 出不去，就是<b>泄漏</b>，门失效。<br><br>方沿脉冲的瞬时开关会额外制造这种非绝热激发（本页可切换「方沿/平滑沿」对比）。所以门时间是一笔权衡：<b>太慢吃退相干，太快吃泄漏</b>——最优夹在中间。"),
]),
callout("四个滑块是<b>器件</b>与<b>脉冲</b>两组旋钮：<b>EJ/EC/ratio2</b> 换器件（决定 |α₂| 与共振位置 Φ*），<b>amp_phi / t_pulse / shape_sel</b> 是脉冲本身。<br><br><b>建议动的顺序</b>：先不动器件，只拖 amp_phi 把 φ<sub>CZ</sub> 拧到 π（见 ④ 任务 1）——这样「幅度定相位」一个效应看得最清楚；再动 t_pulse 看绝热与泄漏的夹心；最后换 shape_sel 对比方沿/平滑沿。器件那三个滑块是换实验台，最后再动，且动完要重找最优幅度。",
	tone="tip", title="③ 调参前先看这里：先动哪个、为什么"),
)

# ╔═╡ c2000001-0000-4000-8000-000000000006
callout("本页沿用 ⑤ 的电容耦合模型，但 qubit2 换成 SQUID：<span class=\"oq-kbd\">cz_pair</span> 在<b>固定参考基</b>（Φ=0 的两个本征态）里改写 Ĥ₂(Φ)，Φ=0 时与 <span class=\"oq-kbd\">TwoQubit</span> 的哈密顿量逐项一致（误差 &lt; 1e-12）。能级取 3 个（|2⟩ 是主角，nlev=3 是 CZ 的硬性要求）。脉冲按<b>分段常值</b>推进，每步一个矩阵指数；时间步长收敛性由 <span class=\"oq-kbd\">test/test_cz.jl</span> 回归。",
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
let
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
let
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
let
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
let
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
﻿oq_stack(
derivation("⑧ 推导溯源：从结间电容到 CZ 的条件相位",
	[
	("定义", texblock(raw"H(\Phi) = \hat H_1\otimes I + I\otimes\hat H_2(\Phi) + 2\pi\,g_c\,\hat n_1\otimes\hat n_2, \qquad E_{J2}(\Phi) = E_{J2}\big(\cos(\pi\Phi) + D\big)"),
		"起点是两个岛的电容耦合（⑤ 讲过）：$(tex(raw"g_c\,\hat n_1\otimes\hat n_2")) 是两比特之间<b>唯一</b>的通道，它不是我们「加」上去的，而是版图上共用的那一小块电容。<br><br>这一页新增的只有一件事：<b>把 qubit2 换成 SQUID</b>，让它的 $(tex(raw"E_{J2}")) 可以被磁通拧。注意 $(tex(raw"D")) 因子让 $(tex(raw"\Phi=0.5")) 处 $(tex(raw"E_J")) 不归零——真实器件总是这样。"),
	("代入", texblock(raw"f_{01} \propto \sqrt{E_J E_C}, \qquad f_{12} = f_{01} + \alpha(\Phi)"),
		"拧 $(tex(raw"E_J")) 就是拧频率。$(tex(raw"|\Phi|")) 增大 → $(tex(raw"E_J")) 减小 → qubit2 的整条能级梯子<b>往下压</b>，$(tex(raw"f_{01}")) 与非谐性 $(tex(raw"\alpha")) 同时变化。<br><br>所以「拖过 avoided crossing」在实验上就是<b>改一个偏置电压</b>；这也是为什么可调比特的频率只能往下调（$(tex(raw"\cos(\pi\Phi) \le 1"))）。"),
	("定义", texblock(raw"U_{\mathrm{CZ}}|x\rangle = \begin{cases} |x\rangle, & x \neq |1,1\rangle \\ -|1,1\rangle, & x = |1,1\rangle \end{cases}"),
		"目标门：$(tex(raw"|00\rangle,|01\rangle,|10\rangle")) 照原样留下，只给 $(tex(raw"|1,1\rangle")) 一个 −1（差一个全局相位）。<br><br>等价表述：<b>qubit1 的相位取决于 qubit2 在哪个态</b>——「条件」二字就在这里。难点是没有任何旋钮能直接作用于 $(tex(raw"|1,1\rangle"))，只能<b>借道</b>另一个能级。"),
	("代入", texblock(raw"\langle 0,2|H|1,1\rangle \approx g_c\,n_{01}\,n_{12} \equiv V"),
		"借道的入口：投影到 3 能级后 $(tex(raw"\hat n")) 的相邻矩阵元 $(tex(raw"n_{01}, n_{12} \neq 0"))，耦合项把 $(tex(raw"|1,1\rangle")) 与 $(tex(raw"|0,2\rangle")) 连起来。<br><br>关键在 $(tex(raw"n_{12}"))——<b>它只在能级不等间距（有非谐性）时才非零</b>，这正是 CZ 必须用 nlev≥3 模型的原因。<br><br>对比：同一项也给出 $(tex(raw"|0,1\rangle\leftrightarrow|1,0\rangle")) 的交换 $(tex(raw"J = g_c n_{01}^2"))，但两者失谐完全不同，所以能各玩各的。"),
	("整理", texblock(raw"\text{共振条件: } E_{11} = E_{02} \;\Rightarrow\; f_{01}^{(1)} = f_{01}^{(2)} + \alpha_2 \quad (\alpha_2 < 0)"),
		"什么时候 $(tex(raw"|1,1\rangle")) 与 $(tex(raw"|0,2\rangle")) 真正靠近？能量相等时。把两边展开就得到这个条件：<b>qubit2 要被拖到比 qubit1 高 $(tex(raw"|\alpha_2|")) 的位置</b>。<br><br>注意 $(tex(raw"\alpha_2 < 0"))，所以这不是「把两个频率对齐」，而是<b>刻意错开一个非谐性</b>——这一条常被想反。"),
	("整理", texblock(raw"\Delta E_{\min} = 2V \qquad (\text{avoided crossing 宽度})"),
		"加上耦合后两条能级不再相交，最小间距 $(tex(raw"2V"))（图 A 中两条实线「近似但不相交」）。<br><br>$(tex(raw"\Phi^{*}")) 由 <span class=\"oq-kbd\">cz_crossing</span> 扫出；读数卡的「idle 失谐」与「峰值失谐」就是在对照共振条件（当前 $(tex(raw"\alpha_2")) = $(alpha_s) MHz）。<br><br>$(tex(raw"2V")) 同时决定两件事：穿越一次攒多少相位，以及 |0,1⟩/|1,0⟩ 的交换有多强（iSWAP 串扰）——耦合不是越大越好。"),
	("近似", texblock(raw"\text{绝热极限: } \Delta\varphi_{\mathrm{CZ}} \approx -\int\!\Big[\lambda_-(t) - E_{11}^{\mathrm{diab}}(t)\Big] dt"),
		"物理图像：耦合把 $(tex(raw"|11\rangle")) 那条能级在穿越时<b>往下压</b>了一段，走过的路程变了，相位就变了——「绕远路」攒下的相位就是条件相位。<br><br>注意被积的是 $(tex(raw"\lambda_-"))（dressed 能级）减 $(tex(raw"E_{11}^{\mathrm{diab}}"))（无耦合的裸能级）：<b>只有耦合造成的那部分</b>才计入条件相位，其余是两个比特各自的动态相位。"),
	("整理", texblock(raw"\varphi_{\mathrm{CZ}} = \varphi_{00}-\varphi_{01}-\varphi_{10}+\varphi_{11} \pmod{2\pi}, \qquad \varphi_{\mathrm{CZ}}^{\mathrm{ideal}} = \pi"),
		"四个计算态各跑一次演化（U 的 4 列），这样组合相减。<b>为什么要减三个</b>：三个单激发态带着 $(tex(raw"\sim 13")) GHz 量级的动态相位，直接读毫无意义；相减把它们整体消掉，剩下的正是耦合贡献。<br><br>实验上靠 ⑨ 的参考序列完成同样的减法（qubit2 置 $(tex(raw"|0\rangle")) 跑一遍作基线）。"),
	("微扰", texblock(raw"\text{非绝热项} \propto \frac{V}{t_{\mathrm{rise}}} \;\Rightarrow\; \text{方沿脉冲把布居甩到}\ |0,2\rangle"),
		"最后是代价：边沿太快，态跟不上 dressed 能级，一部分人口被留在 $(tex(raw"|0,2\rangle")) 出不来——这就是<b>泄漏</b>。<br><br>平滑沿把边沿摊开可压掉 1–2 个数量级（本页可切换「方沿/平滑沿」对比，当前泄漏 $(leak_s)%）。脉冲整体太短同样泄漏，⑨ 的 chevron 图里那些暗谷就是这么来的。"),
	];
	lead="这条推导只回答一个问题：<b>「给 qubit1 一个条件相位」这件事，物理上是怎么发生的？</b>
	脉络是：两岛的电容耦合（第 1 步）→ 用磁通拧 qubit2 的频率（第 2 步）→ 明确目标门长什么样（第 3 步）
	→ 找到能借道的那对能级 $(tex(raw"|1,1\rangle/|0,2\rangle"))（第 4 步）→ 算它们何时相撞、撞出多大间距（第 5–6 步）
	→ 把「靠近再走开」翻译成相位（第 7–8 步）→ 给出代价与压制办法（第 9 步）。
	建议对照 A 图的能级扇形与 B 图的相位累积曲线逐步看：B 图在 $(tex(raw"|0,2\rangle")) excursion 期间那段爬升，就是第 7 步的积分。",
	result="结论落回读数卡：$(tex(raw"\Phi^{*}")) = $(ph_s)（$(tex(raw"2V")) = $(gap_s) MHz），脉冲峰值 $(amp_phi) $(tex(raw"\Phi_0"))（= Φ* 的 $(amp_ratio_s)%），长度 $(t_pulse) ns，$(shape_sel) → φ<sub>CZ</sub> = $(phase_s) rad（残差 $(err_s) rad），泄漏 $(leak_s)%，4 态保真度 $(fstate_s)%，Ramsey P₁ = $(p1_s)。"),
deep_dive("为什么 CZ 必须用 nlev=3？两能级模型里它根本不存在", """
<p>两能级截断（每个比特只留 |0⟩、|1⟩）下，$(tex(raw"\hat n")) 只剩 $(tex(raw"n_{01}\sigma_x"))，
耦合项 $(tex(raw"\hat n_1\otimes\hat n_2")) 变成 $(tex(raw"J\\,\sigma_x\sigma_x"))——它<b>只能交换激发</b>，不产生相位。
换句话说：两能级模型里 ZZ ≡ 0，CZ 是不可能的。</p>
<p>让 CZ 存在的是 $(tex(raw"n_{12}")) 这个矩阵元：它是「能级不等间距」的指纹（非谐性 $(tex(raw"\alpha\neq 0"))），
把 $(tex(raw"|1,1\rangle")) 与 $(tex(raw"|0,2\rangle")) 连起来。所以 <b>非谐性是 CZ 的必要条件</b>，
这也是为什么 transmon（$(tex(raw"|\alpha|\sim 0.3")) GHz）比超导 LC（几乎无非谐性）更适合做比特。</p>
<p>工程数值（量级感）：$(tex(raw"g_c \sim 10-50")) MHz、$(tex(raw"|\alpha| \sim 200-300")) MHz、
$(tex(raw"2V")) 十几到几十 MHz、门时间 25–40 ns。三者互相牵制：耦合强则相位攒得快但串扰大，
门时间短则对退相干鲁棒但泄漏上升。</p>
""", tone="detail"),
deep_dive("常见误解：相位不是「磁通给的」，泄漏也不是「噪声」", """
<p><b>误解一：磁通脉冲直接产生相位。</b>磁通只改 $(tex(raw"E_J"))、只改频率；
相位是在能级靠近时由<b>相互作用</b>（$(tex(raw"V"))）累积出来的。脉冲只是把工作点拖过去再拖回来，
本身不给相位。所以「幅度大 = 相位大」只在穿越更深的意义上成立，不是线性关系。</p>
<p><b>误解二：把工作点开到共振点，相位最大。</b>相位来自整条路径上的积分，
不只来自最低点。而且开得越深，$(tex(raw"|0,2\rangle")) 的成分越多，绝热性要求越苛刻、泄漏风险越大。
本页的最优幅度 $(tex(raw"\Phi^*")) 的 $(amp_ratio_s)% 就是这个折中。</p>
<p><b>误解三：泄漏是噪声，所以平均一下就好。</b>泄漏是<b>确定性的</b>——同样的脉冲，
同样的泄漏量。它不可逆地把人口送出计算子空间，平均不会恢复。
好消息是它可预测、可通过校准把脉冲调到泄漏小的地方（⑨ 的 chevron 里那片亮区就是）。</p>
""", tone="warn"),
)

# ╔═╡ c2000001-0000-4000-8000-00000000001c
tryout([
	("亲手把 φ<sub>CZ</sub> 拧到 π", "<b>动机</b>：这是校准的第一步——找到一个可用工作点。<br><b>做法</b>：固定长度 37.5 ns，把「脉冲峰值磁通」在 0.060–0.090 之间缓慢拖，盯读数卡第一行的残差。",
	 "<b>看什么</b>：残差在 0.073 附近掉到 0.03 rad 以下，同时泄漏 &lt; 1%。<br><b>说明什么</b>：这就是一个可用的 CZ 工作点。注意最优幅度<b>不是</b>恰好 Φ*——相位主要在靠近 crossing 的<b>过程</b>中累积，不必完全开进去。<br><b>如果没看到</b>：残差一直大，先确认长度是 37.5 ns（长度变了最优幅度就变了），再看 B 图的相位曲线是不是还没到 π。"),
	("把脉冲开太短 / 太长", "<b>动机</b>：看清「绝热 vs 泄漏」这笔账怎么算。<br><b>做法</b>：保持幅度 0.073，把长度拖到 12 ns；再拖到 55 ns。",
	 "<b>看什么</b>：短——|0,2⟩ excursion 之后回不来，泄漏冲到几十 %；长——绝热性好，但 fringe 变陡（约 0.2 rad/ns），实验上更难稳住，且吃掉时钟预算。<br><b>说明什么</b>：门时间是一个<b>夹心</b>：太短吃泄漏，太长吃退相干与相位敏感度，真实器件一般取 25–40 ns。<br><b>对照</b>：把长度拖到 40 ns 附近，看泄漏与残差同时处在低位。"),
	("方沿 vs 平滑沿", "<b>动机</b>：脉冲形状本身就是一个校准对象，不是「随便画个形状」。<br><b>做法</b>：切换波形选择，对比读数卡泄漏项与 B2 图橙线的末值。",
	 "<b>看什么</b>：方沿的泄漏比平滑沿高约一个量级。<br><b>说明什么</b>：方沿的瞬时开关制造额外非绝热激发（$(tex(raw"V/t_{\mathrm{rise}}")) 太大）——「脉冲形状也是校准对象」最直接的证据。<br><b>延伸</b>：真实器件还会加 DRAG 式的边沿整形，把非绝热项按阶数压下去。"),
	("把耦合拧大", "<b>动机</b>：耦合不是越大越好，看清这笔权衡。<br><b>做法</b>：g_c 从 0.03 拖到 0.06（2V 跟着变），重新找最优幅度。",
	 "<b>看什么</b>：$(tex(raw"2V")) 变大 → 同样长度能攒更多相位、门可以更快；但 avoided crossing 离 idle 更近，idle 的 ZZ 串扰也更大。<br><b>说明什么</b>：耦合强度决定「门多快」与「串扰多大」的交换比。<br><b>延伸</b>：⑨ 的 chevron 就是在这条权衡里挑工作点——斜率告诉你对幅度/长度的敏感度。"),
])

# ╔═╡ c2000001-0000-4000-8000-00000000001d
quiz([
	("理想 CZ 门在计算基下的矩阵形式是？",
	 ["diag(1, 1, −1, 1)", "diag(1, 1, 1, −1)", "交换 |01⟩ 与 |10⟩", "给所有态加 −1"], 2,
	 "$(tex(raw"U_{\mathrm{CZ}} = \mathrm{diag}(1,1,1,-1)"))（全局相位可差 $(tex(raw"e^{i\theta}"))），只有 |1,1⟩ 拿到 −1——这就是「条件」相位。<br><br><b>辨析</b>：diag(1,1,−1,1) 是给 |1,0⟩ 加相位，不是 CZ；交换 |01⟩/|10⟩ 是 iSWAP（⑤ 的主题，靠交换项而非相位）；给所有态加 −1 只是全局相位，物理上测不出来，不构成门。"),
	("|1,1⟩ ↔ |0,2⟩ 发生共振的条件是？",
	 ["f01₁ = f01₂", "f01₁ = f01₂ + α₂（α₂ < 0）", "f12₂ = 0", "两个比特完全同频"], 2,
	 "由 $(tex(raw"E_{11} = E_{02}")) 展开：$(tex(raw"E_{11} = f_{01}^{(1)} + f_{01}^{(2)}"))，$(tex(raw"E_{02} \approx 2f_{01}^{(2)} + \alpha_2"))，相减即得 $(tex(raw"f_{01}^{(1)} = f_{01}^{(2)} + \alpha_2"))。<br><br>因为 $(tex(raw"\alpha_2 < 0"))，qubit2 要被拖到比 qubit1 <b>高</b> $(tex(raw"|\alpha_2|"))；又因为磁通只能减小 $(tex(raw"E_J"))，所以 idle 点必须设得更高。<br><br><b>辨析</b>：两比特同频是 iSWAP 的共振条件（交换），不是 CZ 的；f12₂ = 0 与本问题无关。"),
	("条件相位为什么要把 φ₀₀、φ₀₁、φ₁₀ 一起减掉？",
	 ["为了数值稳定", "减掉单比特动态相位，只留耦合贡献", "为了让门保持酉", "为了消掉 T1 衰减"], 2,
	 "对角相位以 $(tex(raw"\sim 13")) GHz 的速率转圈（<b>动态相位</b>），直接比会完全混叠；四态相减剩下的正是耦合贡献。<br><br><b>辨析</b>：这不是数值技巧而是物理减法——实验上靠参考序列（qubit2 置 |0⟩ 再跑一遍）完成同样的减法（见 ⑨）；酉性由演化本身保证，不需要额外构造；T1 衰减影响的是布居/对比度，不进相位公式。"),
	("脉冲太短时 CZ 的主要失效模式是？",
	 ["相位累积太快", "非绝热激发把布居甩到 |0,2⟩ 回不来（泄漏）", "比特被推到能级之外", "出现 iSWAP 交换"], 2,
	 "绝热条件要求脉冲足够慢：$(tex(raw"V/t_{\mathrm{rise}}")) 足够小、穿越时间远长于 $(tex(raw"1/(2V)"))。不满足就把人口留在 $(tex(raw"|0,2\rangle"))，即泄漏。<br><br><b>辨析</b>：相位累积太快不是失效（那只是相位标定问题）；「推到能级之外」说法不准确——人口是被推到子空间里的另一个态（|0,2⟩），不是出子空间；iSWAP 不会发生，因为 |0,1⟩/|1,0⟩ 全程离共振很远。"),
	("net-zero CZ 脉冲「两半反号」为什么不破坏条件相位？",
	 ["因为两半的磁通幅度相等", "条件相位是磁通 Phi 的偶函数——正负磁通同样累积；而平均磁通偏置类误差是奇函数，两半相消", "因为两半各转 pi/2", "因为参考演化会自动修正"], 2,
	 "本页验证过 $(tex(raw"H(\Phi)")) 对 Φ 偶对称：+A 与 −A 脉冲的传播子逐项相同，条件相位两半同号累加；而「脉冲期间平均磁通偏离目标」这类线性误差随 Φ 反号，两半自动抵消——偶效应留下、奇效应消掉，这是 net-zero（arXiv:2202.06616）的全部原理。<b>错误选项辨析</b>：A 幅度相等是「对称」的必要条件但不是相位不坏的原因；C 两半各是完整的（半）门，不是各转一半角度；D 参考演化是本页计算相对相位的数值技巧，不在硬件里。"),
])

# ╔═╡ c2000001-0000-4000-8000-00000000d001
let
	# 文献对标：真实 CZ 的波形工程
	oq_stack(
	section_header("⑤", "对标真实器件：从 90% 到 99.85% 的波形工程"),
	readout_table([
		("门时长", "本页 37.5 ns", "真实 20–40 ns（Google Willow 量级；受绝热边沿下限约束——本页「方沿 vs 平滑沿」演示的正是这个下限的来源）"),
		("条件相位精度", "本页 |Δφ| ≈ 0.04 rad", "标定后 |φ<sub>CZ</sub> − π| &lt; 0.01 rad：chevron/fringe 精调 + 虚拟 Z 吃掉残差（相位类误差在现代控制栈里近乎免费修复）"),
		("泄漏", "本页 ~0.3%", "真实 ~1e-3 量级：边沿整形（本页 taper）+ 幅度精修；再往下靠 net-zero 与最优控制"),
		("波形", "本页 ±A 单极性", "真实多用 <b>net-zero</b>：+A / −A 两半对称，抵消平均磁通偏置与 TV 噪声（见深潜）"),
		("谱约束", "本页 gap 图", "真实 |11⟩↔|02⟩ 避交叉 gap ~100–300 MHz：决定绝热下限与相面积速率，是布图时就算好的参数"),
	]; title="本页每个旋钮在真实标定表里都有同名条目"),
	deep_dive("net-zero 脉冲：把「偶效应留下、奇效应抵消」做成波形", """
	<p>磁通脉冲的两个麻烦：fast-flux 线有低频漂移与来自控制电子学的 TV 噪声（脉冲期间平均磁通不准），直接吃门保真度。<b>net-zero</b>（Li 等，arXiv:2202.06616）把一次 CZ 拆成对称的两半：第一半 +A、第二半 −A。<b>条件相位是 Φ 的偶函数</b>（本页验证过 H(Φ) 对称——±amp 的 U 逐项相同），两半同号累积、一分不减；<b>线性误差是 Φ 的奇函数</b>——平均磁通偏移与 TV 串扰在两半中反号，恰好相消；低频磁通噪声还被自动折返（谱上等效一次自旋回波）。代价是总时长翻倍、每半的边沿更紧。它是「用对称性免费买稳健」的教科书案例——与 ⑦ 页回波、⑨ 页参考序列同一思想谱系。</p>
	""", tone="detail"),
	deep_dive("CZ 的十五年：89% → 99.85% 都改了什么", """
	<p><b>2009</b>（DiCarlo 等，Nature）：磁通脉冲 CZ 拼出 CNOT，保真度 ~89–91%——主要损失是非绝热泄漏与磁通噪声。<b>2013–2017</b>：边沿整形、参数化波形（taper/SCALING）、失谐与幅度的联合优化，99% 关口攻破。<b>2019–2021</b>：net-zero 对称化 + 回波化两比特序列，99.5%+ 常态化。<b>2024</b>（Google Willow）：可调耦合器 + 全自动标定，CZ 错误 ~1.5×10<sup>−3</sup>（99.85%），足以支撑「低于门槛」的表面码演示。注意提升的来源分布：物理引擎（本页内容）2009 年已定；其后全是<b>波形工程、对称化与标定自动化</b>——这正是 ⑨ 页存在的理由。</p>
	""", tone="tip"),
	)
end

# ╔═╡ c2000001-0000-4000-8000-00000000001e
@htl("""
<div style="font-size:14.5px;color:#33384D;line-height:2.0;margin-top:6px">
<p><b>CZ 的 indirect 之处：</b>单比特门是「直接转它」，CZ 却是「把别人的频率拧过去撞一次车，靠绕远路攒出相位」。超导量子计算里的两比特门几乎都是这个套路（磁通脉冲、可调耦合器、CR 驱动门都逃不掉「借能级」这一步）。</p>
<p><b>两个数字决定一个门：</b><b>Φ*</b>（往哪撞，谱学定）与<b>长度</b>（攒多少，靠 fringe 定）。前者由器件版图给出，后者每次开机、每过一阵都要重新校——这就是下一页的全部内容。</p>
<p><b>下一步去哪：</b><b>⑨ CZ 门校准方案</b> 用 chevron 二维扫描把这两个工作点找出来，并拆解误差预算（相位欠/过旋转、泄漏、退相干、波形边沿）；<b>⑦ T1/T2</b> 决定这些误差的量级上限。</p>
</div>
""")

# ╔═╡ 00000000-0000-0000-0000-000000000001
PLUTO_PROJECT_TOML_CONTENTS = """
[deps]
HypertextLiteral = "ac1192a8-f4b3-4bfe-ba22-af5b92cd3ab2"
PlotlyBase = "a03496cd-edff-5a9b-9e67-9cda94a718b5"
PlutoUI = "7f904dfe-b85e-4ff6-b463-dae2292396a8"
Statistics = "10745b16-79ce-11e8-11f9-7d13ad32a3b2"

[compat]
HypertextLiteral = "~1.0.0"
PlotlyBase = "~0.8.23"
PlutoUI = "~0.7.83"
"""

# ╔═╡ 00000000-0000-0000-0000-000000000002
PLUTO_MANIFEST_TOML_CONTENTS = """
# This file is machine-generated - editing it directly is not advised

julia_version = "1.12.7"
manifest_format = "2.0"
project_hash = "01f6c87868910e8dc419001b545c640690f76598"

[[deps.AbstractPlutoDingetjes]]
git-tree-sha1 = "e71ee7b4aa06b045259a7d6101e1cb45ad140bce"
uuid = "6e696c72-6542-2067-7265-42206c756150"
version = "1.4.1"

[[deps.ArgTools]]
uuid = "0dad84c5-d112-42e6-8d28-ef12dabb789f"
version = "1.1.2"

[[deps.Artifacts]]
uuid = "56f22d72-fd6d-98f1-02f0-08ddc0907c33"
version = "1.11.0"

[[deps.Base64]]
uuid = "2a0f44e3-6c83-55bd-87e4-b1978d98bd5f"
version = "1.11.0"

[[deps.ColorSchemes]]
deps = ["ColorTypes", "ColorVectorSpace", "Colors", "FixedPointNumbers", "PrecompileTools", "Random"]
git-tree-sha1 = "b0fd3f56fa442f81e0a47815c92245acfaaa4e34"
uuid = "35d6a980-a343-548e-a6ea-1d62b119f2f4"
version = "3.31.0"

[[deps.ColorTypes]]
deps = ["FixedPointNumbers", "Random"]
git-tree-sha1 = "61761f58648aa7217445f24f841839b78c712232"
uuid = "3da002f7-5984-5a60-b8a6-cbb66c0b333f"
version = "0.12.3"
weakdeps = ["StyledStrings"]

    [deps.ColorTypes.extensions]
    StyledStringsExt = "StyledStrings"

[[deps.ColorVectorSpace]]
deps = ["ColorTypes", "FixedPointNumbers", "LinearAlgebra", "Requires", "Statistics", "TensorCore"]
git-tree-sha1 = "8b3b6f87ce8f65a2b4f857528fd8d70086cd72b1"
uuid = "c3611d14-8923-5661-9e6a-0046d554d3a4"
version = "0.11.0"

    [deps.ColorVectorSpace.extensions]
    SpecialFunctionsExt = "SpecialFunctions"

    [deps.ColorVectorSpace.weakdeps]
    SpecialFunctions = "276daf66-3868-5448-9aa4-cd146d93841b"

[[deps.Colors]]
deps = ["ColorTypes", "FixedPointNumbers", "LinearAlgebra", "Reexport"]
git-tree-sha1 = "291665b547f137df070e4dd83e432b5fee8cc4a0"
uuid = "5ae59095-9a9b-59fe-a467-6f913c188581"
version = "0.13.2"

[[deps.CompilerSupportLibraries_jll]]
deps = ["Artifacts", "Libdl"]
uuid = "e66e0078-7015-5450-92f7-15fbd957f2ae"
version = "1.3.1+2"

[[deps.Dates]]
deps = ["Printf"]
uuid = "ade2ca70-3891-5945-98fb-dc099432e06a"
version = "1.11.0"

[[deps.DelimitedFiles]]
deps = ["Mmap"]
git-tree-sha1 = "9e2f36d3c96a820c678f2f1f1782582fcf685bae"
uuid = "8bb1440f-4735-579b-a4ab-409b98df4dab"
version = "1.9.1"

[[deps.DocStringExtensions]]
git-tree-sha1 = "7442a5dfe1ebb773c29cc2962a8980f47221d76c"
uuid = "ffbed154-4ef7-542d-bbb7-c09d3a79fcae"
version = "0.9.5"

[[deps.Downloads]]
deps = ["ArgTools", "FileWatching", "LibCURL", "NetworkOptions"]
uuid = "f43a241f-c20a-4ad4-852c-f6b1247861c6"
version = "1.7.0"

[[deps.FileWatching]]
uuid = "7b1f6079-737a-58dc-b8bc-7a2ca5c1b5ee"
version = "1.11.0"

[[deps.FixedPointNumbers]]
deps = ["Random", "Statistics"]
git-tree-sha1 = "59af96b98217c6ef4ae0dfe065ac7c20831d1a84"
uuid = "53c48c17-4a7d-5ca2-90c5-79b7896eea93"
version = "0.8.6"

[[deps.Hyperscript]]
deps = ["Test"]
git-tree-sha1 = "179267cfa5e712760cd43dcae385d7ea90cc25a4"
uuid = "47d2ed2b-36de-50cf-bf87-49c2cf4b8b91"
version = "0.0.5"

[[deps.HypertextLiteral]]
deps = ["Tricks"]
git-tree-sha1 = "d1a86724f81bcd184a38fd284ce183ec067d71a0"
uuid = "ac1192a8-f4b3-4bfe-ba22-af5b92cd3ab2"
version = "1.0.0"

[[deps.IOCapture]]
deps = ["Logging", "Random"]
git-tree-sha1 = "0ee181ec08df7d7c911901ea38baf16f755114dc"
uuid = "b5f81e59-6552-4d32-b1f0-c071b021bf89"
version = "1.0.0"

[[deps.InteractiveUtils]]
deps = ["Markdown"]
uuid = "b77e0a4c-d291-57a0-90e8-8db25a27a240"
version = "1.11.0"

[[deps.JSON]]
deps = ["Dates", "Logging", "Parsers", "PrecompileTools", "StructUtils", "UUIDs", "Unicode"]
git-tree-sha1 = "633b5a34494e711f694ccbc88a6e00102f10238c"
uuid = "682c06a0-de6a-54ab-a142-c8b1cf79cde6"
version = "1.9.0"

    [deps.JSON.extensions]
    JSONArrowExt = ["ArrowTypes"]

    [deps.JSON.weakdeps]
    ArrowTypes = "31f734f8-188a-4ce0-8406-c8a06bd891cd"

[[deps.JuliaSyntaxHighlighting]]
deps = ["StyledStrings"]
uuid = "ac6e5ff7-fb65-4e79-a425-ec3bc9c03011"
version = "1.12.0"

[[deps.LaTeXStrings]]
git-tree-sha1 = "f88f3ccef05a6a72a0cf0ed417c8fd68530f4ab2"
uuid = "b964fa9f-0449-5b57-a5c2-d3ea65f4040f"
version = "1.4.1"

[[deps.LibCURL]]
deps = ["LibCURL_jll", "MozillaCACerts_jll"]
uuid = "b27032c2-a3e7-50c8-80cd-2d36dbcbfd21"
version = "0.6.4"

[[deps.LibCURL_jll]]
deps = ["Artifacts", "LibSSH2_jll", "Libdl", "OpenSSL_jll", "Zlib_jll", "nghttp2_jll"]
uuid = "deac9b47-8bc7-5906-a0fe-35ac56dc84c0"
version = "8.15.0+0"

[[deps.LibGit2]]
deps = ["LibGit2_jll", "NetworkOptions", "Printf", "SHA"]
uuid = "76f85450-5226-5b5a-8eaa-529ad045b433"
version = "1.11.0"

[[deps.LibGit2_jll]]
deps = ["Artifacts", "LibSSH2_jll", "Libdl", "OpenSSL_jll"]
uuid = "e37daf67-58a4-590a-8e99-b0245dd2ffc5"
version = "1.9.0+0"

[[deps.LibSSH2_jll]]
deps = ["Artifacts", "Libdl", "OpenSSL_jll"]
uuid = "29816b5a-b9ab-546f-933c-edad1886dfa8"
version = "1.11.3+1"

[[deps.Libdl]]
uuid = "8f399da3-3557-5675-b5ff-fb832c97cbdb"
version = "1.11.0"

[[deps.LinearAlgebra]]
deps = ["Libdl", "OpenBLAS_jll", "libblastrampoline_jll"]
uuid = "37e2e46d-f89d-539d-b4ee-838fcccc9c8e"
version = "1.12.0"

[[deps.Logging]]
uuid = "56ddb016-857b-54e1-b83d-db4d58db5568"
version = "1.11.0"

[[deps.MIMEs]]
git-tree-sha1 = "c64d943587f7187e751162b3b84445bbbd79f691"
uuid = "6c6e2e6c-3030-632d-7369-2d6c69616d65"
version = "1.1.0"

[[deps.Markdown]]
deps = ["Base64", "JuliaSyntaxHighlighting", "StyledStrings"]
uuid = "d6f4376e-aef5-505a-96c1-9c027394607a"
version = "1.11.0"

[[deps.Mmap]]
uuid = "a63ad114-7e13-5084-954f-fe012c677804"
version = "1.11.0"

[[deps.MozillaCACerts_jll]]
uuid = "14a3606d-f60d-562e-9121-12d972cd8159"
version = "2025.11.4"

[[deps.NetworkOptions]]
uuid = "ca575930-c2e3-43a9-ace4-1e988b2c1908"
version = "1.3.0"

[[deps.OpenBLAS_jll]]
deps = ["Artifacts", "CompilerSupportLibraries_jll", "Libdl"]
uuid = "4536629a-c528-5b80-bd46-f80d51c5b363"
version = "0.3.29+0"

[[deps.OpenSSL_jll]]
deps = ["Artifacts", "Libdl"]
uuid = "458c3c95-2e84-50aa-8efc-19380b2a3a95"
version = "3.5.6+0"

[[deps.OrderedCollections]]
git-tree-sha1 = "94ba93778373a53bfd5a0caaf7d809c445292ff4"
uuid = "bac558e1-5e72-5ebc-8fee-abe8a469f55d"
version = "1.8.2"

[[deps.Parameters]]
deps = ["OrderedCollections", "UnPack"]
git-tree-sha1 = "34c0e9ad262e5f7fc75b10a9952ca7692cfc5fbe"
uuid = "d96e819e-fc66-5662-9728-84c9c7592b0a"
version = "0.12.3"

[[deps.Parsers]]
deps = ["Dates", "PrecompileTools"]
git-tree-sha1 = "663e8b48b789916221e0765393b289ca6c88f24e"
uuid = "69de0a69-1ddd-5017-9359-2bf0b02dc9f0"
version = "3.0.0"

[[deps.Pkg]]
deps = ["Artifacts", "Dates", "Downloads", "FileWatching", "LibGit2", "Libdl", "Logging", "Markdown", "Printf", "Random", "SHA", "TOML", "Tar", "UUIDs", "p7zip_jll"]
uuid = "44cfe95a-1eb2-52ea-b672-e2afdf69b78f"
version = "1.12.1"
weakdeps = ["REPL"]

    [deps.Pkg.extensions]
    REPLExt = "REPL"

[[deps.PlotlyBase]]
deps = ["ColorSchemes", "Colors", "Dates", "DelimitedFiles", "DocStringExtensions", "JSON", "LaTeXStrings", "Logging", "Parameters", "Pkg", "REPL", "Requires", "Statistics", "UUIDs"]
git-tree-sha1 = "6256ab3ee24ef079b3afa310593817e069925eeb"
uuid = "a03496cd-edff-5a9b-9e67-9cda94a718b5"
version = "0.8.23"

    [deps.PlotlyBase.extensions]
    DataFramesExt = "DataFrames"
    DistributionsExt = "Distributions"
    IJuliaExt = "IJulia"
    JSON3Ext = "JSON3"

    [deps.PlotlyBase.weakdeps]
    DataFrames = "a93c6f00-e57d-5684-b7b6-d8193f3e46c0"
    Distributions = "31c24e10-a181-5473-b8eb-7969acd0382f"
    IJulia = "7073ff75-c697-5162-941a-fcdaad2a7d2a"
    JSON3 = "0f8b85d8-7281-11e9-16c2-39a750bddbf1"

[[deps.PlutoUI]]
deps = ["AbstractPlutoDingetjes", "Base64", "ColorTypes", "Dates", "Downloads", "FixedPointNumbers", "Hyperscript", "HypertextLiteral", "IOCapture", "InteractiveUtils", "Logging", "MIMEs", "Markdown", "Random", "Reexport", "URIs", "UUIDs"]
git-tree-sha1 = "e189d0623e7ce9c37389bac17e80aac3b0302e75"
uuid = "7f904dfe-b85e-4ff6-b463-dae2292396a8"
version = "0.7.83"

[[deps.PrecompileTools]]
deps = ["Preferences"]
git-tree-sha1 = "edbeefc7a4889f528644251bdb5fc9ab5348bc2c"
uuid = "aea7be01-6a6a-4083-8856-8a6e6704d82a"
version = "1.3.4"

[[deps.Preferences]]
deps = ["TOML"]
git-tree-sha1 = "5005266de4bfe50e53ff44a5cb5c540b6e47a254"
uuid = "21216c6a-2e73-6563-6e65-726566657250"
version = "1.6.0"

[[deps.Printf]]
deps = ["Unicode"]
uuid = "de0858da-6303-5e67-8744-51eddeeeb8d7"
version = "1.11.0"

[[deps.REPL]]
deps = ["InteractiveUtils", "JuliaSyntaxHighlighting", "Markdown", "Sockets", "StyledStrings", "Unicode"]
uuid = "3fa0cd96-eef1-5676-8a61-b3b8758bbffb"
version = "1.11.0"

[[deps.Random]]
deps = ["SHA"]
uuid = "9a3f8284-a2c9-5f02-9a11-845980a1fd5c"
version = "1.11.0"

[[deps.Reexport]]
git-tree-sha1 = "45e428421666073eab6f2da5c9d310d99bb12f9b"
uuid = "189a3867-3050-52da-a836-e630ba90ab69"
version = "1.2.2"

[[deps.Requires]]
deps = ["UUIDs"]
git-tree-sha1 = "62389eeff14780bfe55195b7204c0d8738436d64"
uuid = "ae029012-a4dd-5104-9daa-d747884805df"
version = "1.3.1"

[[deps.SHA]]
uuid = "ea8e919c-243c-51af-8825-aaa63cd721ce"
version = "0.7.0"

[[deps.Serialization]]
uuid = "9e88b42a-f829-5b0c-bbe9-9e923198166b"
version = "1.11.0"

[[deps.Sockets]]
uuid = "6462fe0b-24de-5631-8697-dd941f90decc"
version = "1.11.0"

[[deps.Statistics]]
deps = ["LinearAlgebra"]
git-tree-sha1 = "e2b53ce13a53367e96601081e33d34746b571bad"
uuid = "10745b16-79ce-11e8-11f9-7d13ad32a3b2"
version = "1.11.5"

    [deps.Statistics.extensions]
    SparseArraysExt = ["SparseArrays"]

    [deps.Statistics.weakdeps]
    SparseArrays = "2f01184e-e22b-5df5-ae63-d93ebab69eaf"

[[deps.StructUtils]]
deps = ["Dates", "UUIDs"]
git-tree-sha1 = "b814d5005d6a529d740ffe06f8a86396f6501138"
uuid = "ec057cc2-7a8d-4b58-b3b3-92acb9f63b42"
version = "2.9.2"

    [deps.StructUtils.extensions]
    StructUtilsLazilyInitializedFieldsExt = ["LazilyInitializedFields"]
    StructUtilsMeasurementsExt = ["Measurements"]
    StructUtilsStaticArraysCoreExt = ["StaticArraysCore"]
    StructUtilsTablesExt = ["Tables"]

    [deps.StructUtils.weakdeps]
    LazilyInitializedFields = "0e77f7df-68c5-4e49-93ce-4cd80f5598bf"
    Measurements = "eff96d63-e80a-5855-80a2-b1b0885c5ab7"
    StaticArraysCore = "1e83bf80-4336-4d27-bf5d-d5a4f845583c"
    Tables = "bd369af6-aec1-5ad0-b16a-f7cc5008161c"

[[deps.StyledStrings]]
uuid = "f489334b-da3d-4c2e-b8f0-e476e12c162b"
version = "1.11.0"

[[deps.TOML]]
deps = ["Dates"]
uuid = "fa267f1f-6049-4f14-aa54-33bafae1ed76"
version = "1.0.3"

[[deps.Tar]]
deps = ["ArgTools", "SHA"]
uuid = "a4e569a6-e804-4fa4-b0f3-eef7a1d5b13e"
version = "1.10.0"

[[deps.TensorCore]]
deps = ["LinearAlgebra"]
git-tree-sha1 = "1feb45f88d133a655e001435632f019a9a1bcdb6"
uuid = "62fd8b95-f654-4bbd-a8a5-9c27f68ccd50"
version = "0.1.1"

[[deps.Test]]
deps = ["InteractiveUtils", "Logging", "Random", "Serialization"]
uuid = "8dfed614-e22c-5e08-85e1-65c5234f0b40"
version = "1.11.0"

[[deps.Tricks]]
git-tree-sha1 = "311349fd1c93a31f783f977a71e8b062a57d4101"
uuid = "410a4b4d-49e4-4fbc-ab6d-cb71b17b3775"
version = "0.1.13"

[[deps.URIs]]
git-tree-sha1 = "908fec9df6c5de98548ead82a468c95ccf6cd263"
uuid = "5c2747f8-b7ea-4ff2-ba2e-563bfd36b1d4"
version = "1.7.0"

[[deps.UUIDs]]
deps = ["Random", "SHA"]
uuid = "cf7118a7-6976-5b1a-9a39-7adc72f591a4"
version = "1.11.0"

[[deps.UnPack]]
git-tree-sha1 = "387c1f73762231e86e0c9c5443ce3b4a0a9a0c2b"
uuid = "3a884ed6-31ef-47d7-9d2a-63182c4928ed"
version = "1.0.2"

[[deps.Unicode]]
uuid = "4ec0a83e-493e-50e2-b9ac-8f72acf5a8f5"
version = "1.11.0"

[[deps.Zlib_jll]]
deps = ["Libdl"]
uuid = "83775a58-1f1d-513f-b197-d71354ab007a"
version = "1.3.1+2"

[[deps.libblastrampoline_jll]]
deps = ["Artifacts", "Libdl"]
uuid = "8e850b90-86db-534c-a0d3-1478176c7d93"
version = "5.15.0+0"

[[deps.nghttp2_jll]]
deps = ["Artifacts", "Libdl"]
uuid = "8e850ede-7688-5339-a07c-302acd2aaf8d"
version = "1.64.0+1"

[[deps.p7zip_jll]]
deps = ["Artifacts", "CompilerSupportLibraries_jll", "Libdl"]
uuid = "3f19e933-33d8-53b3-aaab-bd5110c3b7a0"
version = "17.7.0+0"
"""

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
# ╠═c2000001-0000-4000-8000-00000000d001
# ╠═c2000001-0000-4000-8000-00000000001e
# ╟─00000000-0000-0000-0000-000000000001
# ╟─00000000-0000-0000-0000-000000000002
