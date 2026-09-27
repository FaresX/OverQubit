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

# ╔═╡ 90000000-0000-4000-8000-000000000001
begin
	using PlutoUI, PlotlyBase, Statistics, HypertextLiteral
	include(joinpath(@__DIR__, "..", "src", "OverQubit.jl"))
	using .OverQubit
	setup_page()
end

# ╔═╡ 90000000-0000-4000-8000-000000000002
md"""### ① 这一页讲什么：用磁通当比特的「调谐旋钮」"""

# ╔═╡ 90000000-0000-4000-8000-000000000003
banner("OVERQUBIT · 磁通调谐", "能级扇形图与电荷色散：E_J(Φ) 拧动频谱",
	"一个 SQUID 环把约瑟夫森能拧成 E_J(Φ) = E_J·cos(πΦ/Φ₀)——于是比特频率、非谐性、电荷噪声灵敏度全都跟着磁流动"; icon="flux")

# ╔═╡ 90000000-0000-4000-8000-000000000004
lesson_nav([
	("①", "transmon 能级与量子化", "done"),
	("②", "单比特门与 Rabi", "done"),
	("③", "DRAG 泄漏压制", "done"),
	("④", "色散读取 S21", "done"),
	("⑤", "两比特耦合与 iSWAP", "done"),
	("⑥", "磁通调谐与能级扇形图", "current"),
	("⑦", "T1 / T2 / Ramsey", "done"),
])

# ╔═╡ 90000000-0000-4000-8000-000000000005
concept_cards([
	("SQUID 环", "两个结并联成环：穿过环的磁通让两条路的相位差干涉，等效约瑟夫森能变成 $(tex(raw"E_J(\Phi) = E_J\big(\cos(\pi\Phi/\Phi_0) + D\big)"))。Φ=0 最大、半量子磁通处最小——这就是「用磁通调频率」的开关。"),
	("扇形成因", "E_J(Φ) 改变势阱深度：$(tex(raw"f_{01}\propto\sqrt{E_J E_C}")) → f01(Φ) 画出来是一把展开的扇子；f12 与 f01 的间距同时改变（非谐性 α(Φ) 也随磁通变化）。"),
	("电荷色散爆炸", "transmon 的核心卖点是「E_J/E_C 大 → 对 n_g 不敏感」。可一旦磁通把 E_J 拧小，比值塌掉、电荷色散从 kHz 涨到 GHz——每次调磁通都要重新付这笔税。"),
	("甜点", "Φ=0 处 cos(πΦ) 取极值，一阶磁通噪声被抵消（dE_J/dΦ = 0）→ transmon 的「meander」偏置点；不对称因子 D>0 还能在半量子点也造一个甜点（EE / tunable coupler 的原理）。"),
])

# ╔═╡ 90000000-0000-4000-8000-000000000006
callout("本页复用 ① 的电荷基对角化引擎（<span class=\"oq-kbd\">transmon_at_flux</span> 只替换 E_J），所有曲线都是真实对角化的结果；势阱动画用 RK4 解经典运动方程（φ̈ = −8E_CE_J sinφ），与 ① 同一套。",
	tone="info", title="阅读前提")

# ╔═╡ 90000000-0000-4000-8000-000000000007
md"""### ③ 调参（SQUID transmon：零磁通约瑟夫森能 + 充电能 + 磁通）"""

# ╔═╡ 90000000-0000-4000-8000-000000000008
@bind EJ0 Slider(5:0.5:50; default=20)

# ╔═╡ 90000000-0000-4000-8000-000000000009
@bind EC Slider(0.05:0.01:0.5; default=0.30)

# ╔═╡ 90000000-0000-4000-8000-00000000000a
@bind phi_ext Slider(-0.5:0.005:0.5; default=0.25)

# ╔═╡ 90000000-0000-4000-8000-00000000000b
@bind D_slider Slider(0.0:0.01:0.3; default=0.1)

# ╔═╡ 90000000-0000-4000-8000-00000000000c
begin
	NCUT = 80
	tf = transmon_at_flux(EJ0, EC, phi_ext; D=D_slider, ncut=NCUT)
	EJ_now = tf.EJ
	E = eigenenergies(tf, 0.0)
	f01, f12 = f01_f12(tf, 0.0)
	α_ = f12 - f01
	phis, psi2 = wavefunctions(tf, 0.0, 3, 300)
	ngs, Es = charge_dispersion(tf, 81, 3)
	e01s = Es[:, 2] .- Es[:, 1]; e12s = Es[:, 3] .- Es[:, 2]
	band_MHz = (maximum(e01s) - minimum(e01s)) * 1000
	# 磁通扫描（扇形图 + 电荷色散随磁通爆炸）
	phis_sweep = collect(range(-0.5, 0.5; length=101))
	F01 = zeros(length(phis_sweep)); F12 = zeros(length(phis_sweep)); BND = zeros(length(phis_sweep))
	for (i, φ) in enumerate(phis_sweep)
		ts = transmon_at_flux(EJ0, EC, φ; D=D_slider, ncut=40)
		f1, f2 = f01_f12(ts, 0.0)
		F01[i] = f1; F12[i] = f2
		_, Es_s = charge_dispersion(ts, 21, 2)
		BND[i] = (maximum(Es_s[:, 2] .- Es_s[:, 1]) - minimum(Es_s[:, 2] .- Es_s[:, 1])) * 1000
	end
	EJ_s = string(round(EJ_now, digits=3)); f01_s = string(round(f01, digits=4))
	f12_s = string(round(f12, digits=4)); alpha_s = string(round(α_, digits=4))
	band_s = string(round(band_MHz, digits=4))
	ratio = EJ_now / EC
	ratio_s = string(round(ratio, digits=1))
end

# ╔═╡ 90000000-0000-4000-8000-00000000000d
stat_row([
	("E_J(Φ)（有效约瑟夫森能）", "$(EJ_s) GHz", "E_J·(cos πΦ + D)，Φ=$(phi_ext), D=$(D_slider)", "#4C6FFF"),
	("E_J/E_C", "$(ratio_s)", "≳50 才是 transmon 区；掉到 ~10 就是 CPB 区", "#7B61FF"),
	("f01 / f12", "$(f01_s) / $(f12_s) GHz", "α = $(alpha_s) GHz", "#1A1A2E"),
	("电荷色散带宽", "$(band_s) MHz", "f01 在 n_g ∈ [−1,1] 的全摆幅", "#B8812E"),
])

# ╔═╡ 90000000-0000-4000-8000-00000000000e
begin
	# 势阱 + 能级 + |ψ|² + 经典小球动画（磁通改变势阱深度）
	s = 0.30 * (E[2] - E[1]) / maximum(psi2)
	V = potential.(tf, phis) .+ EJ_now
	Esh = E .+ EJ_now
	traces = PlotlyBase.GenericTrace[]
	push!(traces, PlotlyBase.scatter(x=phis, y=V; name="势阱 V(φ)", mode="lines",
		line=attr(color="#2C3E50", width=2.5), fill="tozeroy", fillcolor="rgba(44,62,80,0.05)"))
	for k in 1:3
		push!(traces, PlotlyBase.scatter(x=phis, y=fill(Esh[k], length(phis)); mode="lines",
			line=attr(dash="dash", color=PAL[k], width=1.5), name="E$(k-1)", showlegend=false))
		push!(traces, PlotlyBase.scatter(x=phis, y=psi2[k, :] * s .+ Esh[k]; fill="tozeroy",
			line=attr(color=PAL[k], width=1.4), fillcolor=PAL_FILL[k], name="|ψ$(k-1)|²", showlegend=false))
	end
	# 经典小球（RK4，真实能量守恒方程 φ̈ = −8E_CE_J sinφ）——包成函数避开 for 软作用域歧义
	function classical_traj(nfr, EJv, ECv)
		ph = 0.7; nn = 0.0; φb = zeros(nfr); block = 0
		ωho = sqrt(8 * ECv * EJv); Tcl = 2π / ωho
		h = 2.2 * Tcl / (10 * nfr); ν = 8 * ECv
		for k in 1:(10 * nfr)
			a1 = ν * nn;                b1 = -EJv * sin(ph)
			a2 = ν * (nn + h / 2 * b1);  b2 = -EJv * sin(ph + h / 2 * a1)
			a3 = ν * (nn + h / 2 * b2);  b3 = -EJv * sin(ph + h / 2 * a2)
			a4 = ν * (nn + h * b3);      b4 = -EJv * sin(ph + h * a3)
			ph = ph + h / 6 * (a1 + 2a2 + 2a3 + a4)
			nn = nn + h / 6 * (b1 + 2b2 + 2b3 + b4)
			if mod1(k, 10) == 1
				block += 1
				φb[block] = ph
			end
		end
		φb
	end
	nfr = 48
	φb = classical_traj(nfr, EJ_now, EC)
	ωho = sqrt(8 * EC * EJ_now)
	# 小球必须是 traces 里的**最后一条**（专用 trace，播放时只更新它）
	push!(traces, PlotlyBase.scatter(x=[φb[1]], y=[-EJ_now * cos(φb[1]) + EJ_now]; mode="markers",
		marker=attr(size=13, color="#FF7A7A", line=attr(color="white", width=2)),
		showlegend=false, hoverinfo="skip"))
	BALL = length(traces) - 1          # 0 基索引
	frames = PlotlyBase.PlotlyFrame[]
	for k in 1:nfr
		φk = φb[k]
		push!(frames, anim_frame(BALL, string(k), PlotlyBase.scatter(x=[φk], y=[-EJ_now * cos(φk) + EJ_now];
			mode="markers", marker=attr(size=13, color="#FF7A7A", line=attr(color="white", width=2)),
			showlegend=false, hoverinfo="skip")))
	end
	ann = Any[]
	for k in 1:3
		push!(ann, attr(x=π, y=Esh[k], text="E$(k-1)", showarrow=false, xanchor="left",
			font=attr(size=12, color=PAL[k])))
	end
	push!(ann, attr(x=-2.35, y=Esh[2], ax=-2.85, ay=(Esh[1] + Esh[2]) / 2, text="f01", showarrow=true,
		arrowcolor=PAL[1], arrowwidth=1.6, font=attr(size=12, color=PAL[1])))
	pwell = PlotlyBase.Plot(traces,
		layout_base(height=620, title="势阱、能级与波函数（红球＝经典小球）",
			xtitle="相位 φ (rad)", ytitle="能量（相对零点，GHz）", annotations=ann,
			legend_x=0.15, updatemenus=animation_menu()),
		frames)
	plotly_html("oq_flux_well", pwell; height=630)
end

# ╔═╡ 90000000-0000-4000-8000-00000000000f
begin
	# 扇形图：f01(Φ)、f12(Φ) 与电荷色散带宽（对数轴）
	tr = PlotlyBase.GenericTrace[]
	push!(tr, PlotlyBase.scatter(x=phis_sweep, y=F01; mode="lines", name="f01(Φ)",
		line=attr(color=PAL[1], width=2.5)))
	push!(tr, PlotlyBase.scatter(x=phis_sweep, y=F12; mode="lines", name="f12(Φ)",
		line=attr(color=PAL[2], width=2.5)))
	push!(tr, PlotlyBase.scatter(x=phis_sweep, y=F01 .+ F12; mode="lines", name="f01+f12",
		line=attr(color="#8A90AD", width=1.5, dash="dash")))
	push!(tr, PlotlyBase.scatter(x=[phi_ext, phi_ext], y=[0, maximum(F01 .+ F12) * 1.05]; mode="lines",
		line=attr(color=PAL[4], width=2, dash="dot"), name="当前磁通"))
	pfan = PlotlyBase.Plot(tr, layout_base(height=430,
		title="A · 能级扇形图：f01(Φ) 与 f12(Φ)",
		xtitle="归一化磁通 Φ (Φ₀)", ytitle="频率 (GHz)"))
	tr2 = PlotlyBase.GenericTrace[]
	push!(tr2, PlotlyBase.scatter(x=phis_sweep, y=max.(BND, 1e-3); mode="lines", name="色散带宽",
		line=attr(color="#B8812E", width=2.5)))
	push!(tr2, PlotlyBase.scatter(x=[phi_ext], y=[max(band_MHz, 1e-3)]; mode="markers",
		marker=attr(size=12, color="#F5A623", line=attr(color="white", width=2)), name="当前磁通"))
	lay_band = layout_base(height=400, ytype="log",
		title="B · 电荷色散随 E_J 塌缩而爆炸（纵轴对数）",
		xtitle="归一化磁通 Φ", ytitle="f01 在 n_g∈[−1,1] 的摆幅 (MHz)")
	pband = PlotlyBase.Plot(tr2, lay_band)
	oq_stack(plotly_html("oq_flux_fan", pfan; height=440), plotly_html("oq_flux_band", pband; height=410))
end

# ╔═╡ 90000000-0000-4000-8000-000000000010
callout("把 Φ 拖到 ±0.5 附近：f01 塌向 4E_C(n−n_g)² 的纯电荷极限、色散带宽从 kHz 飙到 GHz——这就是「磁通调谐」换来频率自由度的账单。D = $(D_slider) 让半量子点仍保留一些 E_J（不会真的掉到 0）。",
	tone="warn", title="动手前先看这里")

# ╔═╡ 90000000-0000-4000-8000-000000000011
divider()

# ╔═╡ 90000000-0000-4000-8000-000000000012
derivation("⑤ 推导溯源：从 SQUID 环到扇形图",
	[
	("定义", texblock(raw"\text{SQUID：两结并联在环里，环磁通在两结上产生相位差}\ \pm\frac{\pi\Phi}{\Phi_0}"), texblock(raw"I = I_c\big[\sin\varphi_1 + \sin\varphi_2\big], \qquad \varphi_1 = \varphi + \frac{\pi\Phi}{\Phi_0},\quad \varphi_2 = \varphi - \frac{\pi\Phi}{\Phi_0}")),
	("代入", texblock(raw"I = 2I_c\cos\!\Big(\frac{\pi\Phi}{\Phi_0}\Big)\sin\varphi \;\;\Rightarrow\;\; I_c(\Phi) = 2I_c\cos\!\Big(\frac{\pi\Phi}{\Phi_0}\Big)"), texblock(raw"\Rightarrow\quad E_J(\Phi) = E_J\cos\!\Big(\frac{\pi\Phi}{\Phi_0}\Big)")),
	("代入", texblock(raw"E_J(\Phi) = E_J\,\big(\cos(\pi\Phi) + D\big)"), "把整个环看成一个「结」，只是 $(tex(raw"E_J")) 变成了磁通的函数；$(tex(raw"D\neq 0")) 描述两个结不对称，$(tex(raw"\Phi_0/2")) 处不再归零。"),
	("代入", texblock(raw"\hat H = 4E_C\,(\hat n - n_g)^2 - E_J(\Phi)\cos\hat\varphi"), "其余一字不改 → 直接对角化就是本页所有数字。这就是「薄模型层」的好处：磁通调谐不需要新引擎，只换一个参数。"),
	("近似", texblock(raw"-E_J(\Phi)\cos\varphi \approx -E_J(\Phi) + \tfrac12 E_J(\Phi)\varphi^2 \;\;\Rightarrow\;\; \omega_{ho}(\Phi) = \sqrt{8E_J(\Phi)E_C}"), texblock(raw"\Rightarrow\quad f_{01} \approx E_C\Big(\sqrt{8E_J(\Phi)/E_C} - 1\Big)\quad(\text{Koch 极限})")),
	("近似", texblock(raw"f_{01}(\Phi) \approx E_C\Big(\sqrt{8E_J(\Phi)/E_C} - 1\Big)"), "图 A 的扇形形状完全由这个式子决定：$(tex(raw"E_J(\Phi)")) 像 cos 曲线拧，$(tex(raw"f_{01}")) 就像平方根一样被拧。"),
	("整理", texblock(raw"\text{charge dispersion}\big(E_n(n_g)\big) \;\propto\; \exp\!\Big(-\sqrt{8E_J(\Phi)/E_C}\Big)"), "图 B 的纵轴取对数，弯成指数就是这条式子的形状：$(tex(raw"\Phi \to \pm 0.5")) 时 $(tex(raw"E_J(\Phi) \to 0"))，摆幅指数爆炸。"),
	("整理", texblock(raw"\frac{dE_J}{d\Phi} \propto -\sin(\pi\Phi) = 0 \quad @\ \Phi = 0"), "一阶磁通噪声被抵消；这是 transmon 永远偏在 $(tex(raw"\Phi=0")) 的原因。「甜点」是把器件放在对噪声一阶不敏感处。"),
	("代入", texblock(raw"\text{若 } D>0:\quad E_J(\Phi_0/2) = E_J\cdot D \neq 0 \ \text{且}\ \frac{dE_J}{d\Phi}=0 \ \Rightarrow\ \text{半量子甜点}"), "tunable coupler 就靠这个半量子甜点工作：既要频率可调，又不能掉进 CPB 的噪声地狱。"),
	];
	lead="每一步都可点开。读数卡的四个数字都能在这里找到对应行。",
	result="当前 Φ = $(phi_ext)、D = $(D_slider)：E_J(Φ) = $(EJ_s) GHz → E_J/E_C = $(ratio_s)，f01 = $(f01_s) GHz，电荷色散带宽 = $(band_s) MHz（对照 Φ=0 的同参数器件可差 2-3 个量级）。")

# ╔═╡ 90000000-0000-4000-8000-000000000013
tryout([
	("看势阱被磁通「拧浅」", "Φ 从 0 拖到 0.45，看上方势阱图。",
	 "势阱深度 E_J(Φ) 塌下去、能级间距压缩、|ψ|² 摊开（φ_zpf 变大）——红球的摆动频率 ω_ho = √(8E_JE_C) 也同步变慢。"),
	("亲手制造「电荷噪声敏感」的比特", "把 Φ 拖到 0.48、D 拖到 0，看电荷色散带宽卡与图 B。",
	 "带宽从 10⁻³ MHz 量级涨到几十 MHz——比特对栅极电荷噪声一去不返地敏感。这就是为什么调磁通永远只在 Φ=0 附近小范围动。"),
	("用 D 因子保住第二个甜点", "把 D 从 0 拖到 0.3，Φ 停在 0.5，对比 f01 与 α。",
	 "D>0 时 E_J(0.5) = E_J·D ≠ 0：f01 不再塌到 4E_C，非谐性也保持 transmon 量级——tunable coupler 的工作区。"),
	("半量子磁通处的纯电荷极限", "D=0、Φ=0.5 时读 f01 与 α，对答案 4E_C。",
	 "Φ=0.5 且 D=0 时 E_J=0，势阱消失，能级退回自由电荷：E_n = 4E_C(n−0)² → f01 = 4E_C、α = −4E_C。读数卡应与之吻合。"),
])

# ╔═╡ 90000000-0000-4000-8000-000000000014
quiz([
	("Φ = 0.5、D = 0 时 transmon 的 f01 与 α 是多少？",
	 ["f01 = 4E_C，α = −4E_C", "f01 = √(8E_JE_C)", "f01 = 0，α = 0", "f01 = E_J/E_C"], 1,
	 "E_J=0 → 势阱消失，哈密顿量退回 4E_C n²，E₀=0、E±1=4E_C → f01=4E_C、f12=0、α=−4E_C。这是 Cooper-pair box 的退相干极限。"),
	("为什么 transmon 通常工作在 Φ = 0？",
	 ["那里 E_J 最大所以门最快", "dE_J/dΦ = 0，一阶磁通噪声被抵消", "那里电荷色散最大", "那里非谐性消失"], 2,
	 "甜点 = 对噪声的一阶不敏感点。E_J 最大只是附带好处；门速度由 f01 决定，而 α 在 Φ=0 附近基本不变。"),
	("D（不对称因子）的作用是？",
	 ["让 E_J(Φ) 变成 sin", "在半量子磁通处保留有限 E_J，造出第二个甜点", "改变 E_C", "消除非谐性"], 2,
	 "$(tex(raw"E_J(\Phi)=E_J(\cos\pi\Phi+D)"))：D>0 时 Φ₀/2 处 E_J = D·E_J ≠ 0，于是 tunable coupler / EE 仍能在半量子点附近工作而不掉进 CPB 噪声。"),
])

# ╔═╡ 90000000-0000-4000-8000-000000000015
@htl("""
<div style="font-size:14.5px;color:#33384D;line-height:2.0;margin-top:6px">
<p><b>磁通是三件套的公共旋钮：</b>调频率（两比特对齐）、调耦合（tunable coupler）、以及——不小心的话——引入噪声。扇形成本页把这三件事画在同一张图上。</p>
<p><b>下一步去哪：</b><b>两比特耦合</b>用失谐扫出 iSWAP 与 always-on ZZ；<b>T1/T2</b> 看这些 μs 级相干时间如何限制上面的每一个门；<b>① 的 transmon 页</b>复习电荷色散为什么是 transmon 的命根子。</p>
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
git-tree-sha1 = "67e11ee83a43eb71ddc950302c53bf33f0690dfe"
uuid = "3da002f7-5984-5a60-b8a6-cbb66c0b333f"
version = "0.12.1"
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
deps = ["ColorTypes", "FixedPointNumbers", "Reexport"]
git-tree-sha1 = "37ea44092930b1811e666c3bc38065d7d87fcc74"
uuid = "5ae59095-9a9b-59fe-a467-6f913c188581"
version = "0.13.1"

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
deps = ["Dates", "Mmap", "Parsers", "Unicode"]
git-tree-sha1 = "31e996f0a15c7b280ba9f76636b3ff9e2ae58c9a"
uuid = "682c06a0-de6a-54ab-a142-c8b1cf79cde6"
version = "0.21.4"

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
deps = ["Dates", "PrecompileTools", "UUIDs"]
git-tree-sha1 = "ba0dc8a8a67cacac4842631f960c046e4e563675"
uuid = "69de0a69-1ddd-5017-9359-2bf0b02dc9f0"
version = "2.8.8"

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
# ╟─90000000-0000-4000-8000-000000000001
# ╠═90000000-0000-4000-8000-000000000002
# ╠═90000000-0000-4000-8000-000000000003
# ╠═90000000-0000-4000-8000-000000000004
# ╠═90000000-0000-4000-8000-000000000005
# ╠═90000000-0000-4000-8000-000000000006
# ╟─90000000-0000-4000-8000-000000000007
# ╟─90000000-0000-4000-8000-000000000008
# ╟─90000000-0000-4000-8000-000000000009
# ╟─90000000-0000-4000-8000-00000000000a
# ╟─90000000-0000-4000-8000-00000000000b
# ╠═90000000-0000-4000-8000-00000000000c
# ╠═90000000-0000-4000-8000-00000000000d
# ╠═90000000-0000-4000-8000-00000000000e
# ╟─90000000-0000-4000-8000-00000000000f
# ╠═90000000-0000-4000-8000-000000000010
# ╠═90000000-0000-4000-8000-000000000011
# ╠═90000000-0000-4000-8000-000000000012
# ╠═90000000-0000-4000-8000-000000000013
# ╠═90000000-0000-4000-8000-000000000014
# ╠═90000000-0000-4000-8000-000000000015
# ╟─00000000-0000-0000-0000-000000000001
# ╟─00000000-0000-0000-0000-000000000002
