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
begin
	bnr = banner("OVERQUBIT · 磁通调谐", "能级扇形图与电荷色散：E_J(Φ) 拧动频谱",
		"一个 SQUID 环把约瑟夫森能拧成 E_J(Φ) = E_J·cos(πΦ/Φ₀)——于是比特频率、非谐性、电荷噪声灵敏度全都跟着磁流动"; icon="flux")
	@htl("""
	<div style="margin:2px 2px 0;font-size:13.5px;color:#33384D;line-height:1.9;max-width:78ch">
	<b>读完这页你能（每条都能当场自检）：</b>
	① 看着图 A 说出扇形的形状<b>为什么</b>是「cos 被平方根拧」，并报出斜率的量级——Φ=0.25 处 df<sub>01</sub>/dΦ ≈ 9 GHz/Φ<sub>0</sub>，而在 Φ=0 甜点处为 0；
	② 亲手把比特拖进「电荷噪声敏感」区，读出电荷色散带宽从 10<sup>−3</sup> MHz 涨到上百 MHz 的<b>全过程</b>，并解释这笔账为什么必须记在调谐头上；
	③ 说清 Φ=0 甜点到底甜在哪（一阶磁通噪声被抵消，<b>不是</b>「E<sub>J</sub> 最大」），以及 D&gt;0 凭什么能在半量子点再造一个甜点。
	</div>
	""")
end

# ╔═╡ 90000000-0000-4000-8000-000000000003
callout("磁通是超导量子比特的<b>万能旋钮</b>：两比特门要对齐频率、tunable coupler 要开关耦合，实验上都靠它。这一页把一个 SQUID 环装进 transmon，看 E<sub>J</sub> 怎么变成 E<sub>J</sub>(Φ)，于是频率 f<sub>01</sub>、非谐性 α、电荷色散<b>三条曲线一起</b>跟着磁流动——调谐给的自由度和要付的账单画在同一张图上。建议读法：先看四张概念卡建立图像 → 拖 Φ 滑块看扇形图上的「当前磁通」虚线扫动 → 再回头看推导链（那里解释每一步<b>为什么</b>成立）。阅读前提：本页复用 ① 的电荷基对角化引擎（<span class=\"oq-kbd\">transmon_at_flux</span> 只替换 E<sub>J</sub>），所有曲线都是真实对角化的结果；势阱动画用 RK4 解经典运动方程（φ̈ = −8E<sub>C</sub>E<sub>J</sub>sin φ），与 ① 同一套。",
	tone="info", title="① 这一页讲什么：用磁通当比特的「调谐旋钮」")

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
	("图像 · SQUID 环：用干涉拧结", "两个约瑟夫森结并联在一个超导环上，穿过环的磁通给两条路径分配相位 ±πΦ/Φ₀，两路电流相加时干涉：I = 2I<sub>c</sub>cos(πΦ/Φ₀)sin φ。整个环于是等效成「一个结」，只是约瑟夫森能被拧成 $(tex(raw"E_J(\Phi) = E_J\big(\cos(\pi\Phi/\Phi_0) + D\big)"))：Φ=0 最大，半量子磁通处被拧到最小。类比：双缝干涉的两条缝，磁通就是那块改变光程差的玻璃片。验证锚点：读数卡第一格 E<sub>J</sub>(Φ) 随 Φ 滑块实时变化——默认 Φ=0.25、D=0.1 时它是 16.14 GHz，而不是 20。"),
	("机制 · 扇形成因：cos 被平方根拧", "频率来自碗底的曲率：E<sub>J</sub>(Φ) 拧动势阱深度，$(tex(raw"f_{01} \approx E_C\big(\sqrt{8E_J(\Phi)/E_C}-1\big)")) 就跟着走。注意是「平方根」而不是「正比」：Φ 从 0 拖到 0.5，f01 只从约 7 GHz 降到 4E<sub>C</sub>，图 A 的扇子因此是往下<b>收拢</b>的曲线而不是直线。f12 降得比 f01 快，所以非谐性 α(Φ) 也在被拧：默认 −0.34 GHz，到半量子点附近 |α| 反而涨到 0.4–1 GHz（势阱变浅，能级结构退回 charge qubit）。验证锚点：图 A 的「当前磁通」虚线与读数卡 f01 逐位对得上。"),
	("定量 · 电荷色散的账单", "transmon 的命根子是 E<sub>J</sub>/E<sub>C</sub> 大 → 电荷色散 $(tex(raw"\exp\big(-\sqrt{8E_J(\Phi)/E_C}\big)")) 被指数压住：Φ=0 时带宽只有 3×10<sup>−4</sup> MHz。可磁通拧小 E<sub>J</sub> 的同时，指数里的东西一起塌掉——Φ=0.45 带宽就到 11 MHz，Φ=0.5、D=0 直接 1200 MHz，比特一夜回到 charge qubit。图 B 的对数轴画的就是这笔账：越往两边越陡。验证锚点：把 Φ 拖到 0.48，看读数卡「电荷色散带宽」涨五个量级。"),
	("代价 · 甜点在哪、甜的是什么", "Φ=0 处 cos(πΦ) 取极值，dE<sub>J</sub>/dΦ = 0——一阶磁通噪声被抵消，这就是 transmon 永远偏在零磁通附近的「甜点」。要盯准甜的到底是什么：<b>对噪声一阶不敏感</b>，而不是「频率最高」（虽然恰好也最高）。不对称因子 D&gt;0 时半量子点还残留 E<sub>J</sub> ≈ D·E<sub>J</sub>，在精确两结模型里那也是一个极小点，于是 tunable coupler 可以在半量子点附近工作而不掉进 CPB 的噪声地狱。代价则是：调谐范围越大（E<sub>J</sub> 拧得越狠），离开甜点工作时磁通噪声转成的频率噪声就越猛——默认参数下斜率 ~9 GHz/Φ<sub>0</sub>。"),
])

# ╔═╡ 90000000-0000-4000-8000-000000000006
callout("四个滑块各拧一个旋钮：<b>E<sub>J0</sub></b>（5–50 GHz，零磁通约瑟夫森能）决定扇子张多开，先动它感受整把扇子缩放；<b>E<sub>C</sub></b>（0.05–0.5 GHz，充电能）决定 f<sub>01</sub> 与非谐性的量级，也让扇形上下平移；<b>Φ</b>（−0.5…0.5，归一化磁通）是主角——拧它就是在拧频率，同时也在拧 E<sub>J</sub>/E<sub>C</sub> 和电荷色散；<b>D</b>（0–0.3，两结不对称）决定半量子点还剩多少 E<sub>J</sub> 兜底。建议顺序：先拖 Φ 看扇形图与势阱联动 → 再拖 D 看半量子点的「兜底」效果 → 最后动 E<sub>J0</sub>、E<sub>C</sub> 看整把扇子缩放。每动一个就回读数卡核一次 E<sub>J</sub>(Φ)、E<sub>J</sub>/E<sub>C</sub>、f<sub>01</sub>/f<sub>12</sub>、色散带宽这四个数。",
	tone="tip", title="③ 调参前先看这里：四个滑块各是什么、先动哪个")

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
	oq_stack(plotly_html("oq_flux_well", pwell; height=630),
		figure_note("看图要诀：① 碗深就是 E<sub>J</sub>(Φ)（纵轴已抬到碗底为 0）——拖 Φ 时看它被「拧浅」，三条虚线能级同步压低、f01 箭头变短；② |ψ|² 的峰宽是 φ<sub>zpf</sub>，碗越浅它越胖，E<sub>J</sub>/E<sub>C</sub> 拖到 ~10 时会直接摸到碗壁；③ 红球摆动频率是 ω<sub>ho</sub> = √(8E<sub>J</sub>(Φ)E<sub>C</sub>)，与量子的 f01 差约 E<sub>C</sub>——两者之差就是非谐性的来源。"))
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
	oq_stack(plotly_html("oq_flux_fan", pfan; height=440), plotly_html("oq_flux_band", pband; height=410),
		figure_note("看图要诀：① 图 A 两条实线就是「扇子」：f01(Φ) 与 f12(Φ) 都随 |Φ| 下降，虚线 f01+f12 是两光子跃迁 |0⟩→|2⟩ 的参考线，橙点线是当前 Φ（拖滑块时与读数卡 f01 对数）；② 两条实线的<b>间距</b>就是 |α(Φ)|，它随 |Φ| 增大反而<b>变宽</b>（0.34 → 1 GHz 量级）——势阱变浅，能级结构退回 charge qubit；③ 图 B 纵轴是对数：默认 Φ=0.25 处带宽 6×10<sup>−3</sup> MHz，拖到 Φ=0.48 就飙到几十上百 MHz，这条陡坡正是 exp(−√(8E<sub>J</sub>(Φ)/E<sub>C</sub>)) 的形状。"))
end

# ╔═╡ 90000000-0000-4000-8000-000000000010
callout("把 Φ 拖到 ±0.5 附近：f01 塌向 4E_C(n−n_g)² 的纯电荷极限、色散带宽从 kHz 飙到 GHz——这就是「磁通调谐」换来频率自由度的账单。D = $(D_slider) 让半量子点仍保留一些 E_J（不会真的掉到 0）。",
	tone="warn", title="动手前先看这里")

# ╔═╡ 90000000-0000-4000-8000-000000000011
divider()

# ╔═╡ 90000000-0000-4000-8000-000000000012
oq_stack(derivation("⑤ 推导溯源：从 SQUID 环到扇形图",
	[
	("定义", texblock(raw"I = I_c\big[\sin\varphi_1 + \sin\varphi_2\big], \qquad \varphi_1 = \varphi + \frac{\pi\Phi}{\Phi_0},\quad \varphi_2 = \varphi - \frac{\pi\Phi}{\Phi_0}"), "两个约瑟夫森结并联在一个超导环里，穿过环的磁通按<b>路径</b>分配相位：一个结拿到 +πΦ/Φ₀，另一个拿到 −πΦ/Φ₀。这一步只是把「磁通穿环」翻译成两个结的相位差，还没有任何近似。图像类比：双缝干涉里两条缝的光程差，磁通就是那块改变光程差的玻璃片。验证锚点：读数卡 E<sub>J</sub>(Φ) 随 Φ 变小，就是相位差在变。失效条件：忽略环的自感（环电感大时要自洽求解）。"),
	("代入", texblock(raw"I = 2I_c\cos\!\Big(\frac{\pi\Phi}{\Phi_0}\Big)\sin\varphi \;\;\Rightarrow\;\; E_J(\Phi) = E_J\cos\!\Big(\frac{\pi\Phi}{\Phi_0}\Big)"), "两路电流相加用和差化积：I = 2I<sub>c</sub>cos(πΦ/Φ₀)sin φ，磁通把临界电流调制成 cos。于是整个环等效成<b>一个结</b>，其约瑟夫森能被拧成 $(tex(raw"E_J(\Phi)=E_J\cos(\pi\Phi/\Phi_0)"))：Φ=0 最大，Φ=Φ₀/2 被拧到零。这就是「用磁通调频率」的开关本体。验证锚点：Φ 拖到 0.5 且 D=0，读数卡 E<sub>J</sub>(Φ) 显示 0。失效条件：要求两结对称且环电感可忽略。"),
	("代入", texblock(raw"E_J(\Phi) = E_J\,\big(\cos(\pi\Phi) + D\big)"), "真实工艺里两个结不可能完全一样，不对称因子 D 把模型补一刀：半量子点不再归零，而是剩 $(tex(raw"E_J\cdot D"))。D 的典型值 0.02–0.3，读数卡第一格直接显示它的效果（默认 Φ=0.25、D=0.1 → 16.14 GHz）。验证锚点：Φ 停在 0.5，把 D 从 0 拖到 0.3，E<sub>J</sub>(Φ) 从 0 升到 6 GHz。失效条件：这是简化形式，严格的两结表达式见第 9 步与下方深潜。"),
	("代入", texblock(raw"\hat H = 4E_C\,(\hat n - n_g)^2 - E_J(\Phi)\cos\hat\varphi"), "把 E<sub>J</sub>(Φ) 代回 ① 页的 transmon 哈密顿量，其余一字不改——磁通调谐不需要新引擎，只换一个参数。这就是「薄模型层」的红利：电荷基三对角对角化、波函数、色散扫描全部原样复用。验证锚点：图 A/B 的每条曲线都是这一步的<b>数值对角化</b>结果，不是画出来的示意图。失效条件：无（这一步精确）。"),
	("近似", texblock(raw"-E_J(\Phi)\cos\varphi \approx -E_J(\Phi) + \tfrac12 E_J(\Phi)\varphi^2 \;\;\Rightarrow\;\; \omega_{ho}(\Phi) = \sqrt{8E_J(\Phi)E_C}"), "碗底展开 cos 得到抛物线，曲率正比于 E<sub>J</sub>(Φ)，于是谐振频率 $(tex(raw"\omega_{ho}(\Phi)=\sqrt{8E_J(\Phi)E_C}"))——磁通把势阱拧浅，红球摆得也慢。这正是势阱动画里红球随 Φ 变慢的原因。验证锚点：默认 Φ=0.25 时 ω<sub>ho</sub> = 6.22 GHz，读数卡 f<sub>01</sub> = 5.91 GHz，差约 E<sub>C</sub>。失效条件：要求 φ<sub>zpf</sub> ≪ 1；Φ→0.5 且 D=0 时势阱消失，展开无意义。"),
	("整理", texblock(raw"f_{01}(\Phi) \approx E_C\Big(\sqrt{8E_J(\Phi)/E_C} - 1\Big) \qquad (\text{Koch 2007})"), "补上 −E<sub>C</sub> 的一阶修正就是 Koch 公式，图 A 扇形的形状完全由它决定：E<sub>J</sub> 像 cos 一样被拧，f<sub>01</sub> 只像<b>平方根</b>一样被拧，所以扇子是往下收拢的曲线而不是直线。默认参数下这条近似与数值结果差 0.28%。验证锚点：拖 Φ 时把读数卡 f<sub>01</sub> 与图 A 橙点线对数。失效条件：$(tex(raw"E_J(\Phi)/E_C \lesssim 10")) 后先垮的是非谐性（Koch 本身倒还准，见 ① 页深潜）。"),
	("整理", texblock(raw"\text{charge dispersion} \;\propto\; \exp\!\Big(-\sqrt{8E_J(\Phi)/E_C}\Big)"), "电荷色散的指数因子里装着 E<sub>J</sub>(Φ)：拧小 E<sub>J</sub>，压制指数就跟着塌。图 B 纵轴取对数、弯成陡坡，就是这条式子的形状：Φ=0 时带宽 3×10<sup>−4</sup> MHz，Φ=0.45 已到 11 MHz，Φ=0.5、D=0 直接 1200 MHz。验证锚点：读数卡「电荷色散带宽」格子 + 图 B 的橙点。失效条件：这条式子只给指数因子（前因子是多项式），量级对、细节要数值。"),
	("整理", texblock(raw"\frac{dE_J}{d\Phi} \propto -\sin(\pi\Phi) = 0 \quad @\ \Phi = 0"), "甜点的定义在这一行：斜率为零 → 磁通噪声的<b>一阶</b>效应被抵消，Φ=0 就是这样一个点。量化地看：默认参数在 Φ=0.25 处 df<sub>01</sub>/dΦ ≈ 9 GHz/Φ<sub>0</sub>，1 μΦ<sub>0</sub> 的磁通抖动就是 ~9 kHz 频率噪声；同样的噪声放到甜点上只剩二阶效应。验证锚点：把 Φ 从 0 拖离 ±0.02，读数卡 f<sub>01</sub> 立刻可测地动起来。失效条件：甜点只压一阶，二阶灵敏度 ~30 GHz/Φ<sub>0</sub>² 仍在（见深潜）。"),
	("代入", texblock(raw"D>0:\quad E_J(\Phi_0/2) = E_J\cdot D \neq 0, \qquad E_J^{\mathrm{2j}}(\Phi)=\sqrt{E_{J1}^2+E_{J2}^2+2E_{J1}E_{J2}\cos(2\pi\Phi)}"), "D&gt;0 的效果在半量子点显形：E<sub>J</sub>(Φ₀/2) = E<sub>J</sub>·D ≠ 0，势阱不消失，f<sub>01</sub> 与 α 都保住 transmon 量级。严格两结模型 $(tex(raw"E_J^{\mathrm{2j}}")) 在 Φ₀/2 取极小值 $(tex(raw"|E_{J1}-E_{J2}|"))，斜率<b>也是零</b>——这才是「半量子甜点」的完整说法；本页简化式只保留了「残留 E<sub>J</sub>」这一点。验证锚点：Φ=0.5、D=0.3 时读数卡 E<sub>J</sub>(Φ)=6 GHz、E_J/E_C=20，比 D=0 的「0」好得多，但仍低于 Φ=0 的 73。失效条件：D 很小时残留 E<sub>J</sub> 太小，半量子点依旧贴近 CPB 噪声区。"),
	];
	lead="这条推导的脉络：<b>一个环 → 一个被磁通拧动的 E<sub>J</sub> → 三条跟着走的曲线</b>。
第 1–3 步讲「拧」是怎么来的：干涉把两个结合成一个，磁通决定合成多少；
第 4 步把它塞回 ① 页的哈密顿量，于是所有计算原样复用；
第 5–7 步把拧动翻译成三张可读的图（势阱深浅、扇形、色散账单）；
第 8–9 步讲工程上怎么活用、怎么避险（甜点、不对称因子）。
建议对照图 A 看第 6 步：cos 被平方根拧，就是扇形收拢的全部原因。",
	result="<b>结论落回读数卡</b>：当前 Φ = $(phi_ext)、D = $(D_slider) → E<sub>J</sub>(Φ) = $(EJ_s) GHz、E<sub>J</sub>/E<sub>C</sub> = $(ratio_s)（第 2–3 步）；
f<sub>01</sub> = $(f01_s) GHz、f<sub>12</sub> = $(f12_s) GHz、α = $(alpha_s) GHz（第 5–6 步，图 A 的橙点线）；
电荷色散带宽 = $(band_s) MHz（第 7 步，图 B 的橙点）。
对照组要会用：同一器件 Φ=0 时带宽只有 0.0003 MHz，Φ=0.5、D=0 时 1200 MHz——中间隔着的就是 exp(−√(8E<sub>J</sub>(Φ)/E<sub>C</sub>)) 这个指数。"),
deep_dive("半量子甜点的完整说法，与磁通在实验室里的真实刻度", """
<p>先把第 9 步说完整。两个结不对称时，严格的有效约瑟夫森能是
$(tex(raw"E_J^{\mathrm{2j}}(\Phi)=\sqrt{E_{J1}^2+E_{J2}^2+2E_{J1}E_{J2}\cos(2\pi\Phi)}"))，
它在 Φ₀/2 取极小值 $(tex(raw"|E_{J1}-E_{J2}|"))，且那里斜率严格为零——<b>半量子点也是一个甜点</b>。
本页的简化式 $(tex(raw"E_J(\cos\pi\Phi+D)")) 只保留「残留 E<sub>J</sub> = E<sub>J</sub>·D」这一点，
斜率在 Φ₀/2 其实不为零，所以拖到 0.5 附近看图时要留个心眼：真实器件比图里更平。</p>
<p>甜点也只压得住<b>一阶</b>。默认参数下 Φ=0 附近的二阶灵敏度约 30 GHz/Φ<sub>0</sub>²，
1 mΦ<sub>0</sub> 的慢漂移仍给 ~15 kHz 频率漂移——对 1 μs 的 Ramsey 就是 ~0.1 rad 相位，
所以实验上要么做 echo，要么把磁通偏置伺服住。</p>
<p>实验室里的刻度：磁通由片外线圈或片上 fast-flux 线提供，1 Hz 处的磁通噪声典型 ~1 μΦ<sub>0</sub>/√Hz，
fast-flux 脉冲上升时间 1–5 ns；调谐范围通常是几 GHz（本页默认器件：Φ=0 的 6.95 GHz 到半量子点的 1.2 GHz）。
每根线圈的「Φ → 电流」换算都要单独标定，标定方法正是后面 CZ 页用到的 chevron / fringe 扫描。</p>
""", tone="detail"),
deep_dive("常见误解：调磁通只是把频率拧低？", """
<p>不是。<b>拧频率的同时至少三样东西一起变</b>：f<sub>01</sub> 当然变，但 E<sub>J</sub>/E<sub>C</sub> 也从 73 掉到 0（Φ=0.5、D=0），
电荷色散带宽从 3×10<sup>−4</sup> MHz 涨到 1200 MHz——也就是说，你把比特从「免疫电荷噪声」拧成了 charge qubit。
推导第 7 步的指数就是这笔账，图 B 只是把它画出来。</p>
<p>第二条误解：「甜点就是 E<sub>J</sub> 最大、频率最高的地方，所以好」。不对——甜的是
$(tex(raw"dE_J/d\Phi=0"))：<b>一阶磁通噪声被抵消</b>。E<sub>J</sub> 最大只是顺带的好处。
离开甜点后，磁通噪声按 df/dΦ ≈ 9 GHz/Φ<sub>0</sub> 直接变成频率噪声，1 μΦ<sub>0</sub> 就是 ~9 kHz，
idle 时相位会随机走，Ramsey 条纹直接被洗掉。</p>
<p>第三条误解：「Φ=0.5 处 E<sub>J</sub>→0，比特就报废了」。那只是两条路径<b>干涉相消</b>，不是结消失：
D&gt;0 时它退到 E<sub>J</sub>·D，正是 tunable coupler 的工作点（要可调、又要不掉进噪声地狱）。
真正的教训是：<b>调谐范围是用噪声免疫换来的</b>，调多深、工作在哪，要两头一起算。</p>
""", tone="warn"),
)

# ╔═╡ 90000000-0000-4000-8000-000000000013
tryout([
	("看势阱被磁通「拧浅」", "<b>动机</b>：调谐这件事要先在「碗」的层面看见，再去谈频率曲线。<br><b>做法</b>：其它滑块不动，把 Φ 从 0 慢慢拖到 0.45，盯住势阱图与红球动画。",
	 "<b>看什么</b>：碗深 E<sub>J</sub>(Φ) 从 22 GHz 塌到 5.1 GHz，三条虚线能级同步压低，|ψ|² 明显摊开（φ<sub>zpf</sub> 变大），红球摆动变慢——ω<sub>ho</sub> 从 7.3 GHz 降到 3.5 GHz。<br><b>说明什么</b>：图 A 里 f<sub>01</sub>(Φ) 的每一次下降，源头都是这里势阱曲率的减小（推导第 5–6 步：ω<sub>ho</sub> = √(8E<sub>J</sub>(Φ)E<sub>C</sub>)）。<br><b>如果没看到</b>：若碗几乎没动，多半拖的是 E<sub>J0</sub> 而不是 Φ；若只看到碗变浅但红球没变慢，确认动画点的是「播放」。"),
	("亲手制造「电荷噪声敏感」的比特", "<b>动机</b>：调谐的账单不能只在文章里读到，要自己付一次。<br><b>做法</b>：把 Φ 拖到 0.48、D 拖到 0，看读数卡的「电荷色散带宽」与图 B 的橙点。",
	 "<b>看什么</b>：带宽从 10<sup>−3</sup> MHz 量级涨到几十上百 MHz，图 B 的橙点爬上陡坡的高处；读数卡的 E<sub>J</sub>/E<sub>C</sub> 同时从 73 掉到 ~1。<br><b>说明什么</b>：E<sub>J</sub> 被拧小 → exp(−√(8E<sub>J</sub>/E<sub>C</sub>)) 指数暴涨，比特一夜回到 charge qubit——这就是「调磁通永远只在 Φ=0 附近小范围动」的定量理由（推导第 7 步）。<br><b>如果没看到</b>：若带宽仍很小，先确认 D 真的拖到了 0（D&gt;0 会兜底）；图 B 是对数轴，比数量级别比像素。"),
	("用 D 因子保住第二个甜点", "<b>动机</b>：tunable coupler 要「频率可调」又要「不掉进噪声地狱」，两全靠不对称因子。<br><b>做法</b>：Φ 停在 0.5，把 D 从 0 拖到 0.3，对比读数卡的 f<sub>01</sub>、α 与色散带宽。",
	 "<b>看什么</b>：E<sub>J</sub>(0.5) 从 0 升到 6 GHz，f<sub>01</sub> 从 1.2 GHz 升到 ~3.5 GHz，带宽从 1200 MHz 掉到个位数 MHz 量级，α 也回到几百 MHz。<br><b>说明什么</b>：残留 E<sub>J</sub> ≈ D·E<sub>J</sub> 保住了势阱，半量子点从「报废区」变成可用工作点（推导第 9 步）。<br><b>如果没看到</b>：Φ 必须精确停在 0.5（半量子点）；D 滑块上限只有 0.3，再大的兜底效果本页看不到。"),
	("半量子磁通处的纯电荷极限（验算题）", "<b>动机</b>：极限情形是最好的自测——先自己算，再看读数卡对不对。<br><b>做法</b>：D=0、Φ=0.5，先在纸上算 4E<sub>C</sub> = 1.2 GHz，再读读数卡的 f<sub>01</sub>、f<sub>12</sub>、α。",
	 "<b>看什么</b>：f<sub>01</sub> = 1.2 GHz = 4E<sub>C</sub>；f<sub>12</sub> = 0；α = −1.2 GHz = −4E<sub>C</sub>。<br><b>说明什么</b>：E<sub>J</sub>=0 时势阱消失，能级退回自由电荷 E<sub>n</sub> = 4E<sub>C</sub>n²；而 n = +1 与 −1 两条电荷态能量简并，数值对角化给出的第三、第四个本征值撞在一起，于是 f<sub>12</sub> 塌到 0、α = −4E<sub>C</sub>——这正是 Cooper-pair box 的退相干极限，也是 ① 页「浅势阱 = charge qubit」的极端版本。<br><b>如果没看到</b>：若 f<sub>01</sub> ≠ 1.2，多半 D 没拖到 0；Φ 也必须精确在 0.5，偏 0.02 就差出几百 MHz。"),
])

# ╔═╡ 90000000-0000-4000-8000-000000000014
quiz([
	("Φ = 0.5、D = 0 时 transmon 的 f01 与 α 是多少？",
	 ["f01 = 4E_C，α = −4E_C", "f01 = √(8E_JE_C)", "f01 = 0，α = 0", "f01 = E_J/E_C"], 1,
	 "E<sub>J</sub>=0 → 势阱消失，哈密顿量退回 4E<sub>C</sub>n²：E<sub>0</sub>=0、E<sub>±1</sub>=4E<sub>C</sub>（两条电荷态简并）→ f01 = 4E<sub>C</sub>、f12 = 0、α = −4E<sub>C</sub>。这就是 Cooper-pair box 的退相干极限。<b>错误选项辨析</b>：B 拿 Koch 公式硬套 E<sub>J</sub>=0 会算出负频率（−E<sub>C</sub>）——它前提是深势阱，极限情形失效；C 混淆了 E<sub>J</sub>=0 与 E<sub>C</sub>=0：约瑟夫森能没了，充电能还在，能级仍是 4E<sub>C</sub>n²；D 把无量纲比值当频率用，量纲就错了。"),
	("为什么 transmon 通常工作在 Φ = 0？",
	 ["那里 E_J 最大所以门最快", "dE_J/dΦ = 0，一阶磁通噪声被抵消", "那里电荷色散最大", "那里非谐性消失"], 2,
	 "甜点 = 对噪声的<b>一阶不敏感点</b>：$(tex(raw"dE_J/d\Phi = 0"))，磁通噪声不转成频率噪声。<b>错误选项辨析</b>：A 因果错位——E<sub>J</sub> 最大只是附带好处，门快慢由驱动幅度和 f01 决定，甜点的本质是「稳」不是「快」；C 恰好说反：Φ=0 处电荷色散<b>最小</b>，Φ→±0.5 才是最大（图 B）；D 不存在「非谐性消失」——α 在 Φ=0 附近基本不变，随 |Φ| 增大反而变坏。"),
	("D（不对称因子）的作用是？",
	 ["让 E_J(Φ) 变成 sin", "在半量子磁通处保留有限 E_J，造出第二个甜点", "改变 E_C", "消除非谐性"], 2,
	 "$(tex(raw"E_J(\Phi)=E_J(\cos\pi\Phi+D)"))：D&gt;0 时 Φ₀/2 处 E<sub>J</sub> = D·E<sub>J</sub> ≠ 0，tunable coupler / EE 仍能在半量子点附近工作而不掉进 CPB 噪声。<b>错误选项辨析</b>：A 形状是 cos <b>加常数</b>，不是 sin——sin 会把甜点搬到 Φ₀/2，与事实相反；C E<sub>C</sub> 由电容决定，D 是两个结的不对称度，两者互不相干；D 方向反了：D&gt;0 恰恰是<b>保住</b>势阱从而保住非谐性，「消除」非谐性会让两能级近似失效，谁也不想要。"),
])

# ╔═╡ 90000000-0000-4000-8000-000000000015
@htl("""
<div style="font-size:14.5px;color:#33384D;line-height:2.0;margin-top:6px">
<p><b>核心机制：</b>SQUID 的两条路径干涉，把约瑟夫森能拧成 E<sub>J</sub>(Φ) = E<sub>J</sub>(cos πΦ + D)。频率像<b>平方根</b>一样被拧（图 A 的扇形），电荷色散却像<b>指数</b>一样被拧爆（图 B）：同一个旋钮同时给出「频率自由度」和「噪声账单」。Φ=0 的甜点甜在 dE<sub>J</sub>/dΦ = 0——一阶磁通噪声不转成频率噪声；D&gt;0 则在半量子点留下第二个可用的极小点。</p>
<p><b>常见误解：</b>①「调磁通只是把频率拧低」——错，E<sub>J</sub>/E<sub>C</sub>、电荷色散、磁通噪声灵敏度三样一起变，调得越深账越大；②「甜点就是 E<sub>J</sub> 最大、频率最高处」——错，甜的是斜率为零，「最高」只是附带；③「Φ=0.5 处比特报废」——错，那只是两路干涉相消，D&gt;0 时它正是 tunable coupler 的工作点。</p>
<p><b>真实器件里什么样：</b>磁通可调 transmon 的 E<sub>J0</sub>/E<sub>C</sub> ≈ 50–100，f<sub>01</sub> 调谐范围通常 3–6 GHz；工作点平时钉死在 Φ=0 甜点，只在门操作的几十 ns 里用 fast-flux 线（上升沿 1–5 ns）短暂离开——CZ 就是这么做的（把两比特频率拧到 f<sub>01</sub>₁ = f<sub>01</sub>₂ + α₂ 的共振条件再拧回来）。磁通噪声 ~1 μΦ<sub>0</sub>/√Hz，甜点也只压一阶（二阶 ~30 GHz/Φ<sub>0</sub>²），所以还要 echo 或伺服兜底。</p>
<p><b>下一步去哪：</b><b>两比特耦合</b>用失谐扫出 iSWAP 与 always-on ZZ——那里你会看到「拧频率」直接变成「开关门」；<b>T1/T2</b> 看 μs 级相干时间如何限制这里的每一个磁通脉冲；<b>① 的 transmon 页</b>复习电荷色散为什么是 transmon 的命根子（本页图 B 就是它被拧爆的样子）。</p>
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
