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

# ╔═╡ c0000000-0000-4000-8000-00000000c001
lesson_nav([
	("①", "transmon 能级与量子化", "current"),
	("②", "单比特门与 Rabi", "todo"),
	("③", "DRAG 泄漏压制", "todo"),
	("④", "色散读取 S21", "todo"),
	("⑤", "两比特耦合与 iSWAP", "todo"),
	("⑥", "磁通调谐与能级扇形图", "todo"),
	("⑦", "T1 / T2 / Ramsey", "todo"),
])

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
		layout_base(height=520, title="电荷色散：f01(n_g) 几乎完全平坦",
			xtitle="偏移电荷 n_g", ytitle="相对均值 (MHz)"))
	plotly_html("oq_disp", pdisp; height=530)
end

# ╔═╡ c0000000-0000-4000-8000-00000000000c
derivation("⑤ 推导溯源：从约瑟夫森电路到能级",
[
	("定义", texblock(raw"\mathcal{L} = \frac{C}{2}\Big(\frac{\hbar\dot\varphi}{2e}\Big)^2 + E_J\cos\varphi \qquad\Rightarrow\qquad \mathcal{L} = \frac{C\hbar^2}{8e^2}\dot\varphi^2 + E_J\cos\varphi"), "并联约瑟夫森电路：电容储能 $(tex(raw"(C/2)V^2")) 用 $(tex(raw"V = (\hbar/2e)\dot\varphi")) 换成相位速度；结给出 $(tex(raw"-E_J\cos\varphi"))。"),
	("代入", texblock(raw"Q = \frac{\partial \mathcal{L}}{\partial \dot\varphi} = \frac{C\hbar^2}{4e^2}\dot\varphi \;\;\Rightarrow\;\; H = \frac{Q^2}{2C\hbar^2/4e^2} - E_J\cos\varphi = 4E_C\,n^2 - E_J\cos\varphi, \quad n \equiv \frac{Q}{2e}"), "勒让德变换换到哈密顿量；定义无量纲电荷 $(tex(raw"n"))（库珀对数算符的期望）。"),
	("定义", texblock(raw"[\hat\varphi, \hat n] = i, \qquad \hat H = 4E_C\,(\hat n - n_g)^2 - E_J\cos\hat\varphi"), "量子化：相位与电荷成共轭对易量；栅极偏置以 $(tex(raw"n_g")) 平移进入。$(tex(raw"E_C = e^2/2C"))。"),
	("代入", texblock(raw"\hat n|n\rangle = n|n\rangle, \qquad \cos\hat\varphi = \tfrac12\big(\delta_{n,n+1} + \delta_{n,n-1}\big)"), texblock(raw"\Rightarrow\quad H_{nn} = 4E_C(n-n_g)^2, \qquad H_{n,n\pm1} = -\frac{E_J}{2}")),
	("代入", "$(tex(raw"e^{\pm i\varphi}")) 只在相邻电荷态间移动一个库珀对 → 三对角矩阵（本页所有数字都来自对它的对角化）。", ""),
	("近似", texblock(raw"\text{截断 } |n| \le n_{cut} = 80 \ \Rightarrow\ \text{数值对角化} \rightarrow E_0, E_1, \dots\ \text{与本征矢}"), "低能级对 $(tex(raw"n_{cut}")) 收敛极快；黄金向量验收证实 $(tex(raw"n_{cut}=50")) 已达机器精度。"),
	("微扰", texblock(raw"\cos\varphi \approx 1 - \frac{\varphi^2}{2} + \frac{\varphi^4}{24} \;\;\Rightarrow\;\; \omega_{ho} = \sqrt{8E_J E_C}"), "势阱底部近似抛物线给出均匀能级间距，四次项把它「压弯」——这就是非等间距的来源。"),
	("微扰", texblock(raw"\alpha = E_{12} - E_{01} \approx -E_C \quad(\varphi^4\ \text{项的一级微扰})"), texblock(raw"\varphi_{zpf} = \Big(\frac{2E_C}{E_J}\Big)^{1/4}")),
	("整理", texblock(raw"\omega_{01} \approx \sqrt{8E_J E_C} - E_C \qquad (\text{Koch 2007 解析极限})"), "本页读数卡的「Koch 对照」就是它；两者在 $(tex(raw"E_J/E_C \gtrsim 50")) 时吻合到 ~0.2%。"),
	("整理", texblock(raw"\text{charge dispersion} \;\propto\; \exp\!\Big(-\sqrt{8E_J/E_C}\Big)"), "电荷色散图的带宽随 $(tex(raw"E_J/E_C")) 指数塌缩——transmon 对 charge noise 免疫的定量理由。"),
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

# ╔═╡ c0000000-0000-4000-8000-00000000c002
quiz([
	("transmon 相对 charge qubit 的核心优势来源是？",
	 ["E_J/E_C → 0", "E_J/E_C 大 → 电荷色散被指数压低", "E_C = 0", "n_g = 0"], 2,
	 "电荷色散 $(tex(raw"\propto \exp\!\big(-\sqrt{8E_J/E_C}\big)"))；E_J/E_C 大时 n_g 的依赖被指数压掉——这就是 transmon 对 charge noise 免疫的定量理由。"),
	("非谐性 α = f12 − f01 的物理来源是？",
	 ["量子涨落", "势阱不是抛物线（四次项）", "电荷噪声", "栅极偏置 n_g"], 2,
	 "cos φ 的四次项让能级间距随能级数下降：α ≈ −E_C。没有它 |0⟩↔|1⟩ 与 |1⟩↔|2⟩ 就等距，两能级近似失效、DRAG 页面要处理的泄漏会更严重。"),
	("为什么改变 n_g 时 transmon 的能级几乎不动？",
	 ["n_g 不进哈密顿量", "依赖被指数因子压低", "因为用了电荷基", "因为 α 很小"], 2,
	 "4E_C(n̂−n_g)² 的 n_g 依赖在深势阱里被 $(tex(raw"\exp(-\sqrt{8E_J/E_C})")) 压掉；浅势阱（CPB 区）时同一条式子给出 MHz 量级的摆幅。"),
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
# ╠═c0000000-0000-4000-8000-00000000000e
# ╟─00000000-0000-0000-0000-000000000001
# ╟─00000000-0000-0000-0000-000000000002
