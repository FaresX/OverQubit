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

# ╔═╡ c0000000-0000-4000-8000-000000000001
begin
	using PlutoUI, PlotlyBase, Statistics, HypertextLiteral
	include(joinpath(@__DIR__, "..", "src", "OverQubit.jl"))
	using .OverQubit
	setup_page()
end

# ╔═╡ c0000000-0000-4000-8000-000000000002
@htl("""
<div style="background:linear-gradient(100deg,#EEF1FF 0%,#F6F2FF 60%,#EFFBF8 100%);border-radius:14px;padding:20px 26px;margin:2px 0 10px 0">
<div style="font-size:12px;letter-spacing:2px;color:#7B61FF;font-weight:600">OVERQUBIT · MVP-0</div>
<div style="font-size:24px;font-weight:700;color:#1A1A2E;margin-top:4px">超导量子比特原理 · transmon 电荷基对角化</div>
<div style="color:#5A6182;margin-top:8px;font-size:14px">拖动滑块，看势阱里「住」着的量子化能级如何随 E<sub>J</sub>、E<sub>C</sub>、n<sub>g</sub> 变化</div>
</div>
<div style="font-size:15px;margin:4px 2px">
<div style="font-weight:700;font-size:17px;color:#1A1A2E">读完这页你能（每条都能当场自检）：</div>
<ol style="color:#33384D;line-height:1.9">
<li>指着主图说出<b>三条证据</b>，证明「能级是量子化的」：① 能量只落在离散虚线上（红球却能停在任意高度）；② |ψ|² 只在特定形状上有峰，势阱壁外还有<b>隧穿尾巴</b>；③ 自下而上间距越来越窄——并指出第三条就是非谐性 α</li>
<li>拖 E<sub>J</sub>、E<sub>C</sub> 两个滑块，用 Koch 公式<b>先估后读</b>：先算 f<sub>01</sub> ≈ √(8E<sub>J</sub>E<sub>C</sub>) − E<sub>C</sub>，再和读数卡对到小数点后两位，并解释为什么 α 总落在 −E<sub>C</sub> 附近</li>
<li>用一句话说清 transmon <b>为什么不怕 charge noise</b>，并给出当场可验的锚点：把 n<sub>g</sub> 从 −1 拖到 1，电荷色散带宽仍只有 10<sup>−3</sup> MHz 量级；把 E<sub>J</sub>/E<sub>C</sub> 拖到 10，它立刻涨到上百 MHz</li>
</ol>
<div style="background:#F4F6FF;border-radius:8px;padding:10px 14px;margin-top:10px;font-size:13px;color:#5A6182">
本页所有数字来自 <code>src/OverQubit.jl</code> 的电荷基对角化（<i>H</i> = 4E<sub>C</sub>(n̂ − n<sub>g</sub>)<sup>2</sup> − E<sub>J</sub>&#8202;cos&#8202;φ），
已通过 scqubits v4.3.1 黄金向量回归验证（8 个参数点，最大相对误差 ~5e-13）。
</div>
</div>
""")

# ╔═╡ c0000000-0000-4000-8000-00000000c001
oq_stack(
callout("超导量子比特不是「缩小版的经典电路」，而是一整个<b>被势阱锁住的量子系统</b>。这一页只讲一件事：一个约瑟夫森结 + 一块电容，为什么会生出离散能级、非等间距、以及对电荷噪声的免疫力——三件事共用同一个引擎（电荷基三对角矩阵的数值对角化），本页每个数字都从它出来，也都能被你用滑块复现。建议读法：先看四张概念卡建立图像 → 拖滑块做实验 → 再回头看推导链（那里解释每一步<b>为什么</b>成立）；读数卡上的每个数字，在推导链里都有对应的一行。",
	tone="info", title="① 这一页讲什么：把超导电路看成势阱里的量子"),
lesson_nav([
	("①", "transmon 能级与量子化", "current"),
	("②", "单比特门与 Rabi", "todo"),
	("③", "DRAG 泄漏压制", "todo"),
	("④", "色散读取 S21", "todo"),
	("⑤", "两比特耦合与 iSWAP", "todo"),
	("⑥", "磁通调谐与能级扇形图", "todo"),
	("⑦", "T1 / T2 / Ramsey", "todo"),
]))

# ╔═╡ c0000000-0000-4000-8000-000000000003
concept_cards([
("图像 · 势阱里「住」着量子", "约瑟夫森结给出余弦势 <i>V</i>(φ) = −E<sub>J</sub>cos&#8202;φ——一口深 2E<sub>J</sub> 的「碗」（碗底 φ=0、碗沿 φ=±π），默认 E<sub>J</sub>=20 GHz 时碗深约 40 GHz。被这口碗锁住的相位只能取离散能量：主图里三条虚线 E0/E1/E2 就是前三个能级，彩色 |ψ|² 面积画在各自能级上。经典红球可以停在碗里任意高度、在碗壁处速度为零；量子态不能，而且 |ψ|² 在碗壁之外仍有<b>隧穿尾巴</b>。验证锚点：拖大 E<sub>J</sub>，碗变深、三条线一起被压密。"),
("机制 · 两个能量尺度拔河", "一切由 E<sub>J</sub> 与 E<sub>C</sub> 的拔河决定：E<sub>J</sub> 想把相位钉死在碗底（势阱深度，E<sub>J</sub> = <i>ħI</i><sub>c</sub>/2e），E<sub>C</sub> 想把电荷数钉死（搬一对库珀对上岛要付 4E<sub>C</sub>(n−n<sub>g</sub>)²，E<sub>C</sub> = e²/2C）。量子力学不让两者同时确定（[φ̂, n̂] = i → Δφ·Δn ≥ 1/2），于是相位有零点涨落 φ<sub>zpf</sub> ≈ (2E<sub>C</sub>/E<sub>J</sub>)<sup>1/4</sup> ≈ 0.4 rad。类比：碗越深、球越「重」，井里的量子抖动就越轻。验证锚点：读数卡的 φ<sub>zpf</sub> 随 E<sub>J</sub> 变大而变小。"),
("定量 · 三条公式管住所有数字", "频率：f<sub>01</sub> ≈ √(8E<sub>J</sub>E<sub>C</sub>) − E<sub>C</sub>（Koch 2007）；非谐性：α ≈ −E<sub>C</sub>；电荷噪声免疫：charge dispersion ∝ exp(−√(8E<sub>J</sub>/E<sub>C</sub>))。默认 E<sub>J</sub>=20、E<sub>C</sub>=0.3 GHz 给出 f<sub>01</sub> ≈ 6.61 GHz、α ≈ −0.34 GHz，与读数卡逐位对得上。三条都是近似，真值来自电荷基三对角矩阵的数值对角化（n<sub>cut</sub>=80，与 scqubits 黄金向量最大相对误差 ~5e-13）。验证锚点：读数卡的「Koch 对照」偏差 0.22%，就是近似质量的仪表。"),
("代价 · 免疫不是免费的", "transmon 用非谐性换电荷噪声免疫：α ≈ −E<sub>C</sub> ≈ −0.2~−0.3 GHz，只有 f<sub>01</sub>（4–6 GHz）的 4–5%。这意味着驱动 |0⟩↔|1⟩ 时，|1⟩↔|2⟩ 只差 0.3 GHz——驱动一强就会顺手把人口踢上去，泄漏按 amp² 增长（下一页 DRAG 专治它）。E<sub>J</sub>/E<sub>C</sub> 也<b>不是越大越好</b>：色散按 exp(−√(8E<sub>J</sub>/E<sub>C</sub>)) 收益递减，而相对非谐性 |α|/f<sub>01</sub> 越压越小，门越难做快。工程甜点是 E<sub>J</sub>/E<sub>C</sub> ≈ 50–100、f<sub>01</sub> = 4–6 GHz、T<sub>1</sub> = 50–100 μs。"),
])

# ╔═╡ c0000000-0000-4000-8000-000000000004
callout("三个滑块各拧哈密顿量里的一个旋钮：<b>E<sub>J</sub></b>（5–50 GHz，势阱深度）先动——它决定 f<sub>01</sub> 的量级，拖一下看读数卡 f<sub>01</sub> 与 Koch 对照一起走；<b>E<sub>C</sub></b>（0.05–0.5 GHz，动能刻度）次之——它<b>同时</b>控制非谐性 α 与相位涨落 φ<sub>zpf</sub>，拖大会让碗变「软」、能级歪得更厉害；<b>n<sub>g</sub></b>（−1…1，栅极偏置）最后动——它是本页的<b>对照组</b>：transmon 区里它几乎什么都不改，这正是要亲眼确认的事。建议顺序 E<sub>J</sub> → E<sub>C</sub> → n<sub>g</sub>，每动一个就回读数卡核一次数；拖动任一滑块，全页（图、读数卡、推导链结论行）自动重算。",
	tone="tip", title="③ 调参前先看这里：三个滑块各是什么、先动哪个")

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
	# 小球作为最后一条专用 trace 先入栈，动画帧只更新它
	push!(traces, PlotlyBase.scatter(x=[φb[1]], y=[-EJ * cos(φb[1]) + EJ]; mode="markers",
		marker=attr(size=13, color="#FF7A7A", line=attr(color="white", width=2)),
		showlegend=false, hoverinfo="skip"))
	BALL = length(traces) - 1          # 0 基索引
	# 动画帧：经典小球沿势阱滑动（能量守恒轨迹，RK4 真算）
	nfr = length(φb)
	frames = PlotlyBase.PlotlyFrame[]
	for k in 1:nfr
		φk = φb[k]
		push!(frames, anim_frame(BALL, string(k), PlotlyBase.scatter(x=[φk], y=[-EJ * cos(φk) + EJ];
			mode="markers", marker=attr(size=13, color="#FF7A7A", line=attr(color="white", width=2)),
			showlegend=false, hoverinfo="skip")))
	end
	pmain = PlotlyBase.Plot(traces,
		layout_base(height=640, title="势阱、能级与波函数密度（红球＝经典粒子）", updatemenus=animation_menu(),
			xtitle="相位 φ (rad)", ytitle="能量（相对零点，GHz）", annotations=ann, legend_x=0.15),
		frames)
	oq_stack(plotly_html("oq_main", pmain; height=650),
		figure_note("看图要诀：① 三条水平虚线是本征能量 E0/E1/E2——间距自下而上<b>变窄</b>，肉眼分不出就把左侧 f01 与 f12 两个箭头比一比；② 彩色 |ψ|² 面积画在各自能级上，峰宽就是 φ<sub>zpf</sub>，把 E<sub>C</sub> 拖大会看到它们变胖、甚至顶到碗壁；③ 红球是经典粒子，盯住它在碗壁处「减速—停住—折返」，再看 |ψ|² 在同一位置仍有尾巴——那就是隧穿。"))
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
		layout_base(height=520, title="电荷色散：f01(n_g) 几乎完全平坦",
			xtitle="偏移电荷 n_g", ytitle="相对均值 (MHz)"))
	oq_stack(plotly_html("oq_disp", pdisp; height=530),
		figure_note("看图要诀：① 纵轴是 f<sub>01</sub>(n<sub>g</sub>) 相对均值的偏移，单位 MHz——默认参数下整条曲线的摆幅不到 0.001 MHz，也就是说 <b>n<sub>g</sub> 从 −1 拖到 1，比特频率纹丝不动</b>；② 橙色点线是当前 n<sub>g</sub>，拖 n<sub>g</sub> 时它扫过全图，曲线却不跟着动——这就是「指数压低」的视觉版；③ 把 E<sub>J</sub> 拖到 5 再看（E<sub>C</sub>=0.3）：曲线立刻涨到 12 MHz 量级；再把 E<sub>C</sub> 拖到 0.5 就是上百 MHz，纵轴刻度会自己换量级。"))
end

# ╔═╡ c0000000-0000-4000-8000-00000000000c
oq_stack(derivation("⑤ 推导溯源：从约瑟夫森电路到能级",
[
	("定义", texblock(raw"\mathcal{L} = \frac{C}{2}\Big(\frac{\hbar\dot\varphi}{2e}\Big)^2 + E_J\cos\varphi \qquad\Rightarrow\qquad \mathcal{L} = \frac{C\hbar^2}{8e^2}\dot\varphi^2 + E_J\cos\varphi"), "从一个真实的电路出发：约瑟夫森结并联一块电容 C，电容储能是 (C/2)V²，而结两端电压与相位速度直接相连 V = (ħ/2e)φ̇；结自己给出势能 −E_Jcos&#8202;φ。这一步只做变量替换，把电路的电磁量全部翻译成相位 φ 这<b>一个</b>自由度。图像类比：φ 是碗里小球的位置，C 是它的质量，E_J 决定碗形——主图横轴就是 φ，画出来的曲线正是它。失效条件：结电容与杂散电容被合并成一个 C，且忽略环的有限电感。"),
	("代入", texblock(raw"Q = \frac{\partial \mathcal{L}}{\partial \dot\varphi} = \frac{C\hbar^2}{4e^2}\dot\varphi \;\;\Rightarrow\;\; H = \frac{Q^2}{2C\hbar^2/4e^2} - E_J\cos\varphi = 4E_C\,n^2 - E_J\cos\varphi, \quad n \equiv \frac{Q}{2e}"), "对 φ̇ 做勒让德变换换到哈密顿量，动能项变成 Q² 除以一个有效电容。定义无量纲电荷 n = Q/2e（多搬一对库珀对，n 加 1），动能项整齐地写成 $(tex(raw"4E_C n^2"))，其中 $(tex(raw"E_C = e^2/2C"))——到此得到本页一切数字的出发点 H = 4E_C n² − E_Jcos&#8202;φ。验证锚点：E_C 滑块拧的就是这个系数，拖大它会同时看到 f01 上升、α 变大。失效条件：E_C 必须用<b>总</b>电容算，漏掉杂散电容会系统性低估 E_C、高估 f01。"),
	("定义", texblock(raw"[\hat\varphi, \hat n] = i, \qquad \hat H = 4E_C\,(\hat n - n_g)^2 - E_J\cos\hat\varphi"), "把 φ 与 n 当成一对共轭算符：$(tex(raw"[\hat\varphi,\hat n]=i"))，正如位置与动量。栅极偏置把电荷零点平移 $(tex(raw"n_g"))，它不必是整数，于是哈密顿量写成 $(tex(raw"4E_C(\hat n-n_g)^2 - E_J\cos\hat\varphi"))。这一步是全页唯一的量子化假设，后面就都是算术。验证锚点：n_g 滑块扫的就是这个平移量，而读数卡的 f01 几乎不动。失效条件：n_g 被当作准静态偏置；随时间快速涨落的 n_g 是噪声，要另算（见 ⑦ 的退相干）。"),
	("代入", texblock(raw"\hat n|n\rangle = n|n\rangle, \qquad \langle n|\cos\hat\varphi|n\pm1\rangle = \tfrac12"), "在电荷基 |n⟩ 里 n̂ 是对角的，而 $(tex(raw"\cos\hat\varphi = (e^{i\hat\varphi}+e^{-i\hat\varphi})/2")) 每作用一次就把 n 改变 ±1——它只连接<b>相邻</b>电荷态。于是哈密顿量不是稠密矩阵，而是一条三对角的窄带。类比：一排相邻的台阶，每一级只和左右邻居握手。验证锚点：本页所有数字都来自对这条窄带矩阵的对角化。失效条件：无（这一步精确），代价只是得不到闭式解、必须数值计算。"),
	("代入", texblock(raw"H_{nn} = 4E_C(n-n_g)^2, \qquad H_{n,n\pm1} = -\frac{E_J}{2}"), "把两个算符的矩阵元摆出来：对角线是充电能的抛物线 $(tex(raw"4E_C(n-n_g)^2"))，次对角线是常数 $(tex(raw"-E_J/2"))（隧穿强度）。抛物线 + 常数隧穿 = 三对角矩阵，它正是连续版 Mathieu 方程的离散形式。验证锚点：读数卡每个数字都是它对角化后本征值的差分。失效条件：无；这也是「换磁通只需换 E_J 一个数」的原因（见 ⑥ 页）。"),
	("近似", texblock(raw"|n| \le n_{cut} = 80 \;\Rightarrow\; \mathrm{eig}(H) \to E_0, E_1, E_2, \dots"), "矩阵本是无穷维，实际只取 $(tex(raw"|n|\le 80")) 的窗口做数值对角化。低能级收敛极快：$(tex(raw"E_J/E_C \gtrsim 50")) 时 n_cut = 50 已到机器精度（黄金向量验收：8 个参数点、对 scqubits 最大相对误差 ~5e-13）。验证锚点：把 NCUT 改小再改回，读数卡前几位不该变。失效条件：势阱越浅（E_J/E_C 越小）电荷数涨落越宽，需要的 n_cut 越大。"),
	("微扰", texblock(raw"\cos\varphi \approx 1 - \frac{\varphi^2}{2} + \frac{\varphi^4}{24} \;\;\Rightarrow\;\; \omega_{ho} = \sqrt{8E_J E_C}"), "碗底附近把 cos 展开：二次项就是抛物线，给出<b>等间距</b>能级 $(tex(raw"\omega_{ho}=\sqrt{8E_JE_C}"))；四次项描述碗壁向外张开，把上层间距往下压——非等间距就是这么来的。读数卡的「谐波近似频率」就是 ω_ho，默认参数 6.93 GHz，比真实 f01 = 6.61 GHz 高出约 E_C。验证锚点：动画红球的摆动频率正是 ω_ho，它明显快过量子的 f01。失效条件：$(tex(raw"\varphi\ll 1")) 才成立；E_J/E_C = 10 时 φ_zpf ≈ 0.67 rad，波函数已摸到碗壁，这条展开开始失真。"),
	("微扰", string(texblock(raw"\alpha = E_{12} - E_{01} \approx -E_C"), texblock(raw"\varphi_{zpf} = \Big(\frac{2E_C}{E_J}\Big)^{1/4}")), "四次项的一级微扰直接给出非谐性 α ≈ −E_C：能级越往上间距越窄，读数卡的 α = f12 − f01 默认为 −0.34 GHz（≈ −1.1E_C，微扰只到主导项，差 ~10%）。α 是「两能级近似合法」的唯一保证：|1⟩ 与 |2⟩ 之间只差它，驱动 |0⟩↔|1⟩ 才不至于顺手打到 |2⟩。φ_zpf 则给出相位涨落的宽度，也就是主图 |ψ|² 的胖瘦（默认 0.42 rad）。验证锚点：把 E_C 加倍，α 约加倍，而 f01 只按 √E_C 增长。"),
	("整理", texblock(raw"\omega_{01} \approx \sqrt{8E_J E_C} - E_C \qquad (\text{Koch 2007})"), "把微扰结果整理成实验上最好用的形式：f01 ≈ √(8E_JE_C) − E_C。它与数值对角化在默认参数下只差 0.22%，读数卡的「Koch 对照」实时显示这个偏差；想把比特频率做高，按它加 E_J 或 E_C 即可。验证锚点：拖 E_J 时读数卡的 f01 与 Koch 值始终并肩移动。失效条件：这个公式其实相当皮实（E_J/E_C = 10 时偏差仍不到 1%），真正先垮的是上一步的 α ≈ −E_C。"),
	("整理", texblock(raw"\text{charge dispersion} \;\propto\; \exp\!\Big(-\sqrt{8E_J/E_C}\Big)"), "最后一行回答「为什么不怕 charge noise」：f01 对 n_g 的依赖被 $(tex(raw"\exp(-\sqrt{8E_J/E_C})")) 压住，默认参数下指数因子已小到 1e-10 量级、带宽只有 8e-4 MHz。物理图像：隧穿 E_J 把电荷本征态抹平成「相位确定态」，n_g 的平移再也推不动能级。验证锚点：电荷色散图——n_g 从 −1 拖到 1，f01 几乎纹丝不动；把 E_J 拖到 5 就涨到 12 MHz。失效条件：E_J 被拧小（⑥ 磁通调谐页的主题）时指数因子暴涨，免疫一夜失效。"),
	];
lead="这条推导的脉络：<b>一个电路 → 一个自由度 → 一对共轭算符 → 一条窄带矩阵 → 三条好用的公式</b>。
第 1–3 步是「翻译」：把约瑟夫森电路写成相位 $(tex(raw"\varphi")) 的哈密顿量并量子化，几乎不丢东西；
第 4–6 步是「算」：把算符摊成三对角矩阵再数值对角化——本页所有数字的真正来源；
第 7–10 步是「读」：用微扰把结果整理成三条能记住的公式（频率、非谐性、电荷色散）。
建议对照主图看第 7–8 步：抛物线给 $(tex(raw"\omega_{ho}"))，四次项给 $(tex(raw"\alpha"))，两者的差正是「红球摆动」与「量子能级」的差别。",
result="<b>结论落回读数卡</b>：f<sub>01</sub> = $(f01_str) GHz 与 Koch 极限 $(koch_str) GHz 只差 $(string(round(100 * abs(f01 - koch_f01) / f01, digits=2)))% ⇒ 第 9 步的整理可用；
α = $(alpha_str) GHz ≈ −E<sub>C</sub> = $(string(round(-EC, digits=3))) GHz ⇒ 第 8 步的四次项微扰定量成立；
φ<sub>zpf</sub> = $(zpf_str) rad 解释主图 |ψ|² 的宽度；电荷色散图平到 10<sup>−3</sup> MHz 量级 ⇒ 第 10 步的指数压制真在起作用。
反例也要会读：把 E<sub>J</sub> 拖到 5、E<sub>C</sub> 拖到 0.5，Koch 对照<b>仍然</b>准，但 α 会跑到 −2.5E<sub>C</sub>、色散带上百 MHz——先垮的是微扰，不是公式。"),
deep_dive("三条近似各自的「保质期」：谁先失效？", """
<p>三条近似的保质期不一样长，值得分开记。</p>
<p>① <b>Koch 公式</b> $(tex(raw"f_{01}\approx\sqrt{8E_JE_C}-E_C")) 最皮实：默认 $(tex(raw"E_J/E_C = 66.7")) 时偏差 0.22%，把滑块拖到最小比值 10 也只有约 0.6%。它只吃「碗底抛物线 + 一阶修正」，对碗壁形状不敏感。</p>
<p>② <b>$(tex(raw"\alpha\approx -E_C"))</b> 保质期短得多：E_J/E_C = 66.7 时数值结果是 $(tex(raw"-1.12E_C"))，到 E_J/E_C = 10 就变成 $(tex(raw"-2.5E_C"))——读数卡的 α 行当场可验。所以它只能当量级估计，做门设计必须用数值的 α。</p>
<p>③ <b>电荷色散</b> $(tex(raw"\exp(-\sqrt{8E_J/E_C})")) 是三者里最陡的：指数从 e<sup>−23</sup>（E_J/E_C=66.7）涨到 e<sup>−8.9</sup>（E_J/E_C=10），带宽从 8×10<sup>−4</sup> MHz 直接到 125 MHz。<b>它才是 transmon 区的真正判据</b>，而不是 Koch 公式的偏差。</p>
<p>工程侧的参照系：真实器件 E<sub>J</sub>/h ≈ 10–25 GHz、E<sub>C</sub>/h ≈ 0.2–0.3 GHz、f<sub>01</sub> = 4–6 GHz、α ≈ −200…−350 MHz、T<sub>1</sub> = 50–100 μs；本页默认值 20 / 0.3 正落在这个区间的高频端。数值侧的两条边界：n<sub>cut</sub>=80 对 E_J/E_C ≳ 20 绰绰有余；而 E_J/E_C = 10 时 |ψ|² 的隧穿尾巴已经摸到 φ ≈ ±π 的碗沿，「四次项微扰」的图像本身开始失真——这时该直接信数值对角化，而不是信任何一条公式。</p>
""", tone="detail"),
deep_dive("常见误解：E_J/E_C 越大越好？——收益递减，代价递增", """
<p>最常见的误读是把「电荷色散被指数压低」当成「E_J/E_C 越大越好」。指数确实在掉，但收益<b>递减</b>：比值从 50 到 100，指数从 e<sup>−20</sup> 到 e<sup>−28</sup>，而默认参数的带宽已是 8×10<sup>−4</sup> MHz（约 0.8 kHz）——远低于任何实际可测的噪声底，再压没有意义。</p>
<p>代价却<b>递增</b>：α ≈ −E_C 基本不动，f01 ∝ √E_J 却在涨，于是相对非谐性 $(tex(raw"|\alpha|/f_{01}")) 越来越小——驱动 |0⟩↔|1⟩ 时误伤 |1⟩↔|2⟩ 的概率变大，门只能做得更慢更小心。同时色散读出的判别率 $(tex(raw"\chi")) 变小，读出变慢。也就是说：压电荷噪声换来的是<b>更难做的门和更慢的读出</b>。</p>
<p>顺手纠正第二条小误解：$(tex(raw"\alpha = -E_C")) 不是恒等式，默认参数下数值结果是 $(tex(raw"-1.12E_C"))（拖滑块对照读数卡的 α 与 −E<sub>C</sub> 两列就明白）。正确的心智模型是「E_C 决定 α 的<b>量级</b>」。工程甜点 E_J/E_C ≈ 50–100 就是在这两头之间取的平衡，本页默认 20 / 0.3 = 66.7 正落在中间。</p>
""", tone="warn"),
)

# ╔═╡ c0000000-0000-4000-8000-00000000000d
tryout([
("势阱变浅：把器件拖进 Cooper-pair box 区", "<b>动机</b>：transmon 不是天生的，它是「把 E<sub>J</sub>/E<sub>C</sub> 调大」调出来的；亲手把系统拖出 transmon 区，才知道那三条近似各自什么时候作废。<br><b>做法</b>：把 E<sub>C</sub> 拖到 0.5、E<sub>J</sub> 拖到 5（E<sub>J</sub>/E<sub>C</sub> = 10），其余不动。",
 "<b>看什么</b>：① 读数卡 α 从 −0.34 GHz 跳到 −1.27 GHz（≈ −2.5E<sub>C</sub>，不再是 −E<sub>C</sub>）；② 电荷色散带宽从 8×10<sup>−4</sup> MHz 涨到 125 MHz；③ 主图里 |ψ|² 明显变胖、摸到碗壁，红球与虚线能级的「错位」变大。<br><b>说明什么</b>：先垮的是<b>四次项微扰</b>（α ≈ −E<sub>C</sub>）和电荷噪声免疫，而不是 Koch 公式——它的对照偏差只从 0.22% 涨到 0.57%，比想象中皮实得多。<br><b>如果没看到</b>：确认 E<sub>J</sub> 与 E<sub>C</sub> 都拖到位（比值要在读数卡上看到 10）；若 α 仍 ≈ −E<sub>C</sub>，多半是只拖了 E<sub>J</sub> 没拖 E<sub>C</sub>。"),
("亲手验证 charge noise 免疫", "<b>动机</b>：「transmon 免疫电荷噪声」不该是一句口号，它应该是一个你<b>看得见读数不动</b>的实验。<br><b>做法</b>：E<sub>J</sub>=20、E<sub>C</sub>=0.3 固定，把 n<sub>g</sub> 从 −1 慢慢拖到 1，眼睛盯住电荷色散图与读数卡的 f<sub>01</sub>。",
 "<b>看什么</b>：橙色点线扫过整张图，f<sub>01</sub> 曲线却纹丝不动，带宽只有 ~8×10<sup>−4</sup> MHz（0.8 kHz）；然后把 E<sub>J</sub> 拖到 5 再拖一次 n<sub>g</sub>，曲线立刻「呼吸」起来，带宽涨到 12 MHz。<br><b>说明什么</b>：$(tex(raw"\exp(-\sqrt{8E_J/E_C})")) 这个指数因子就是免疫的全部来源；E<sub>J</sub>/E<sub>C</sub> 越大，n<sub>g</sub> 越推不动能级。<br><b>如果没看到</b>：先看纵轴单位是不是 MHz（不是 GHz）——默认参数下摆幅小到容易误以为图坏了；把 E<sub>J</sub>/E<sub>C</sub> 拖小是让效应「现形」的最快办法。"),
("看懂经典小球与量子态的差别", "<b>动机</b>：「量子化」到底量子在哪？把经典与量子画在同一口碗里，差别就不再抽象。<br><b>做法</b>：点主图动画的「播放」，看红球来回摆动，同时对照三条虚线能级与彩色 |ψ|² 面积。",
 "<b>看什么</b>：红球在碗壁处减速、停住、折返（经典转折点），而 |ψ|² 在同一位置<b>不为零</b>、还拖出隧穿尾巴；红球摆动的频率是 ω<sub>ho</sub> = $(oh_str) GHz，比量子的 f<sub>01</sub> = $(f01_str) GHz 快出约 E<sub>C</sub>。<br><b>说明什么</b>：经典粒子可以停在任意能量，量子态只能住在离散能级上；两者频率之差正是四次项（非谐性）的宏观体现——推导第 7–8 步就是这两句话的公式。<br><b>如果没看到</b>：动画只动红球不改背景是正常的（帧只更新小球）；若红球不动，先确认点的是「播放」而不是图例；若 |ψ|² 看不出尾巴，把 E<sub>C</sub> 拖大让它胖起来。"),
])

# ╔═╡ c0000000-0000-4000-8000-00000000c002
quiz([
	("transmon 相对 charge qubit 的核心优势来源是？",
	 ["E_J/E_C → 0", "E_J/E_C 大 → 电荷色散被指数压低", "E_C = 0", "n_g = 0"], 2,
	 "$(tex(raw"\text{charge dispersion} \propto \exp\!\big(-\sqrt{8E_J/E_C}\big)"))——E_J/E_C 大时 n_g 的依赖被指数压掉，这就是 transmon 对 charge noise 免疫的定量理由。<b>错误选项辨析</b>：A 恰好说反——E_J/E_C → 0 是 charge qubit（CPB）极限，色散不降反爆表（把 E_J 拖到 5 就能看到带宽 12 MHz）；C 把 E_C 归零不是出路：α ≈ −E_C 会一起消失，两能级近似直接失效；D 把 n<sub>g</sub> 调到 0 只是挑了一个偏置点，而「免疫」的意思是 n<sub>g</sub> <b>随便动</b>都没关系——一个点和一条平线是两回事。"),
	("非谐性 α = f12 − f01 的物理来源是？",
	 ["量子涨落", "势阱不是抛物线（四次项）", "电荷噪声", "栅极偏置 n_g"], 2,
	 "cos φ 的四次项让能级间距随能级数下降，微扰给出 α ≈ −E_C（默认参数数值值 −1.1E_C）。没有它，|0⟩↔|1⟩ 与 |1⟩↔|2⟩ 等距，两能级近似失效、驱动会无限泄漏。<b>错误选项辨析</b>：A 量子涨落负责的是 φ<sub>zpf</sub>（|ψ|² 的宽度），不决定间距是否等距；C 电荷噪声是<b>外来的</b>扰动，而 α 是器件本征属性，把噪声关掉它照样是 −E_C；D n<sub>g</sub> 只平移电荷零点，拖 n<sub>g</sub> 时 α 几乎不动——这正可以在读数卡上验证。"),
	("为什么改变 n_g 时 transmon 的能级几乎不动？",
	 ["n_g 不进哈密顿量", "依赖被指数因子压低", "因为用了电荷基", "因为 α 很小"], 2,
	 "4E_C(n̂−n_g)² 的 n_g 依赖在深势阱里被 $(tex(raw"\exp(-\sqrt{8E_J/E_C})")) 压掉；浅势阱（CPB 区）同一条式子立刻给出 MHz 量级的摆幅。<b>错误选项辨析</b>：A 错在「不进」——n_g 明明白白写在哈密顿量里，只是作用被指数压制，这正是推导第 10 步的内容；C 电荷基只是<b>计算</b>用的基底，换成相位基结论一个字不变；D 因果倒置：α 小是四次项的结果，与 n_g 不敏感之间没有因果关系。"),
	("把本页参数表与真实器件对照，下列哪组最接近行业典型值？",
	 ["E<sub>J</sub>/E<sub>C</sub> ≈ 5、E<sub>C</sub> ≈ 1 GHz", "E<sub>J</sub>/E<sub>C</sub> ≈ 50、E<sub>C</sub> ≈ 0.25 GHz、f<sub>01</sub> ≈ 5 GHz", "E<sub>J</sub>/E<sub>C</sub> ≈ 500、E<sub>C</sub> ≈ 0.05 GHz", "E<sub>J</sub>/E<sub>C</sub> ≈ 1、f<sub>01</sub> ≈ 15 GHz"], 2,
	 "行业典型：E<sub>J</sub>/E<sub>C</sub> = 30–80、E<sub>C</sub>/h = 0.20–0.30 GHz、f<sub>01</sub> = 4–7 GHz、α ≈ −0.2…−0.35 GHz（Koch 2007 设计窗口，即 ⑦ 表）。<b>错误选项辨析</b>：A 是 Cooper-pair box 区——电荷色散 MHz 级，正是 transmon 要逃离的参数；C 比值过大，|α|/f<sub>01</sub> 被压到 1% 量级，单比特门慢到没法用（概念卡「代价」的极限版）；D 是电荷比特时代的老参数（高 f01 + E_J/E_C≈1），现代器件用 4–7 GHz 给读取和门留空间。"),
])

# ╔═╡ c0000000-0000-4000-8000-00000000d001
let
	# 文献对标：本页模型 vs 真实器件设计窗口（调研 2026-09，来源见 deep_dive）
	oq_stack(
	section_header("⑦", "对标真实器件：这套参数不是玩具"),
	readout_table([
		("E<sub>J</sub>/E<sub>C</sub>", string(round(EJ / EC, digits=1)), "真实器件 30–80：Koch 2007 给出的设计窗口；Schreier 2008 实测比值 ×2.5 → 电荷色散 ↓ 两个数量级"),
		("E<sub>C</sub>/h", string(round(EC, digits=2), " GHz"), "0.20–0.30 GHz——几乎全行业一致，因为它直接钉死 α ≈ −E<sub>C</sub> ≈ −0.2…−0.35 GHz"),
		("f<sub>01</sub>", string(round(f01, digits=2), " GHz", ), "真实器件 4–7 GHz：高于冰箱热噪声（10–20 mK ↔ k<sub>B</sub>T/h ≈ 0.2–0.4 GHz），又留出色散读取（谐振腔 6–8 GHz）需要的失谐"),
		("电荷色散带宽", "≈ 10<sup>−3</sup> MHz", "真实器件工作点上同样压到 kHz 以下——你拖 n<sub>g</sub> 全程读数不动，就是它的视觉版"),
		("T<sub>1</sub>（本页未建模）", "—", "2007 初代 ≈ 1 μs → 3D transmon（2011）≈ 100 μs → 钽电极（2021）> 300 μs——见下方深潜"),
	]; title="本页默认参数正落在行业设计窗口内（右侧三列都是文献典型值）"),
	deep_dive("T<sub>1</sub> 十八年提升史：每一步都在砍一个损失渠道", """
	<p><b>1999–2002 · 前身</b>：Nakamura 等（1999）首次在约瑟夫森结上看到相干振荡；Vion 等的 quantronium（2002）用甜点偏置压电荷噪声——但它们都是 E<sub>J</sub>/E<sub>C</sub> ~ 1 的「电荷比特」，对 n<sub>g</sub> 敏感，相干时间 ~1 μs 量级。把本页 E<sub>J</sub> 拖到 5、E<sub>C</sub> 拖到 0.5，你就站在那个年代。</p>
	<p><b>2007 · transmon 诞生</b>：Koch、DiCarlo、Gambetta 等（PRB 76, 042519）指出把 E<sub>J</sub>/E<sub>C</sub> 推到 ~50，电荷色散按 $(tex(raw"\exp(-\sqrt{8E_J/E_C})")) 指数塌掉、非谐性只按幂律变差——这笔交易正是推导第 10 步。Schreier 等（2008）实验确认：比值 ×2.5，色散 ↓ 100 倍。</p>
	<p><b>2011 · 3D transmon</b>：Paik 等把比特搬进三维微波腔，砍掉芯片表面的介电损耗参与度，T<sub>1</sub> ≈ 100 μs。<b>2021 · 钽</b>：Place、Wang 等（Princeton）把电容换成钽，界面损耗再砍一刀，T<sub>1</sub> > 300 μs；2024 年干法刻蚀 vs 湿法刻蚀仍给出 ~2× 的系统差。结论：这十八年 T<sub>1</sub> 的主战场在<b>材料与工艺</b>，电路设计（本页的内容）2007 年就已定型。</p>
	""", tone="detail"),
	deep_dive("为什么全行业把 f01 钉在 4–7 GHz？", """
	<p>这是三个约束夹出来的窗口：<b>下限</b>来自热噪声——稀释冰箱 10–20 mK 对应 k<sub>B</sub>T/h ≈ 0.2–0.4 GHz，f<sub>01</sub> 必须远高于它（5 GHz 时激发态热布居 ~e<sup>−240</sup>，可以彻底忽略）；<b>上限</b>来自读取——读取谐振腔通常放在 6–8 GHz，色散读取需要 |Δ| = 1–3 GHz 的失谐（④ 页的 g/Δ ≪ 1），比特频率得压在腔的下面；<b>中间</b>还要躲开两能级系统（TLS）密集区和邻近比特的频率碰撞（⑧⑨ 页）。本页默认 6.61 GHz 在窗口偏上沿——真实设计更常用 4–6 GHz。</p>
	""", tone="tip"),
	)
end

# ╔═╡ c0000000-0000-4000-8000-00000000000e
@htl("""
<div style="font-size:14.5px;color:#33384D;line-height:2.0;margin-top:6px">
<p><b>核心机制：</b>一个结 + 一块电容 = 一口深 2E<sub>J</sub> 的余弦碗 + 一个动能刻度 E<sub>C</sub>。被碗锁住的相位只能取离散能量（量子化的来源）；碗壁的四次项让间距自上而下变窄，差值就是非谐性 α ≈ −E<sub>C</sub>（推导第 7–8 步）；隧穿把电荷本征态抹平成「相位确定态」，于是 n<sub>g</sub> 的作用被 exp(−√(8E<sub>J</sub>/E<sub>C</sub>)) 指数压掉（推导第 10 步）。一句话：<b>用 α 换 charge noise 免疫</b>，这就是 transmon 的全部交易。</p>
<p><b>常见误解：</b>①「E<sub>J</sub>/E<sub>C</sub> 越大越好」——不对，色散收益递减而门的代价递增（见上面的深潜）；②「α = −E<sub>C</sub>」是恒等式——不对，默认参数下它其实是 −1.1E<sub>C</sub>，E<sub>J</sub>/E<sub>C</sub>=10 时是 −2.5E<sub>C</sub>；③「Koch 公式只在深势阱才准」——反了，它比 α ≈ −E<sub>C</sub> 皮实得多，E<sub>J</sub>/E<sub>C</sub>=10 时偏差仍不到 1%。</p>
<p><b>真实器件里什么样：</b>f<sub>01</sub> 被刻意放在 4–6 GHz（避开 50 GHz 以上的热激发，又不至于低到被磁通噪声淹没），E<sub>C</sub>/h ≈ 0.2–0.3 GHz 给出 α ≈ −200…−350 MHz，T<sub>1</sub> 做到 50–100 μs，单比特门压缩到 20–40 ns。芯片上它是一小块约 300×700 μm 的约瑟夫森结 + 电容叉指，读数时还要挂一根 λ/4 谐振子——下一页和 ④ 会分别讲这两件事。</p>
<p><b>下一步去哪：</b><b>单比特门</b>演示怎么用电磁驱动在这些能级间「打转」（重点看 Rabi 与脉冲面积）；<b>DRAG</b> 处理这里埋下的伏笔——|2⟩ 泄漏；<b>色散读取</b>演示怎么隔着谐振子「看见」量子态；<b>⑥ 磁通调谐</b>展示把 E<sub>J</sub> 拧成 E<sub>J</sub>(Φ) 之后，这页的免疫会怎样被「拧没」。</p>
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
# ╟─c0000000-0000-4000-8000-000000000001
# ╠═c0000000-0000-4000-8000-000000000002
# ╠═c0000000-0000-4000-8000-00000000c001
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
# ╠═c0000000-0000-4000-8000-00000000c002
# ╠═c0000000-0000-4000-8000-00000000d001
# ╠═c0000000-0000-4000-8000-00000000000e
# ╟─00000000-0000-0000-0000-000000000001
# ╟─00000000-0000-0000-0000-000000000002
