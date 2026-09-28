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

# ╔═╡ b0000000-0000-4000-8000-000000000001
begin
	using PlutoUI, PlotlyBase, Statistics, Random, HypertextLiteral
	include(joinpath(@__DIR__, "..", "src", "OverQubit.jl"))
	using .OverQubit
	setup_page()
end

# ╔═╡ b0000000-0000-4000-8000-000000001001
lesson_nav([
	("①", "transmon 能级与量子化", "done"),
	("②", "单比特门与 Rabi", "done"),
	("③", "DRAG 泄漏压制", "done"),
	("④", "色散读取 S21", "current"),
	("⑤", "两比特耦合与 iSWAP", "todo"),
	("⑥", "磁通调谐与能级扇形图", "todo"),
	("⑦", "T1 / T2 / Ramsey", "todo"),
])

# ╔═╡ b0000000-0000-4000-8000-000000000002
@htl("""
<div style="background:linear-gradient(100deg,#EEF1FF 0%,#F6F2FF 60%,#EFFBF8 100%);border-radius:14px;padding:20px 26px;margin:2px 0 10px 0">
<div style="font-size:12px;letter-spacing:2px;color:#7B61FF;font-weight:600">OVERQUBIT · 读取</div>
<div style="font-size:24px;font-weight:700;color:#1A1A2E;margin-top:4px">色散读取：S21 如何「看见」qubit</div>
<div style="color:#5A6182;margin-top:8px;font-size:14px">读得远 ≠ 看得清：qubit 通过色散位移 χ 移动读出谐振子的频率，S21 曲线的位置差就是「信号」</div>
<div style="margin-top:12px;font-size:13.5px;color:#33384D;line-height:1.9;max-width:78ch">
<b>读完这页你能：</b>①说清「看见」的机制——qubit 状态怎么把读出腔的谐振频率挪动 ±χ，并在 S21 图上指认<b>哪一段</b>是信号；
②用三个数判断色散读取成不成立：g/Δ（合法性）、2χ/κ（可分辨性）、光子数 vs n<sub>crit</sub>（功率上限）；
③解释读出保真度为什么最终是<b>统计问题</b>：写出 SNR ∝ √(κT)，并说出「99% 读出」的代价与前提各是什么。
</div>
</div>
""")

# ╔═╡ b0000000-0000-4000-8000-000000000003
oq_stack(
callout("量子门做完只是半场戏：还要把结果<b>读</b>出来。这一页只回答一个问题——「一个只有两个能级的量子系统，怎么被一台经典微波仪器看见？」主线三步：腔把频率变成幅度与相位（S21）→ qubit 用 χ 把腔频挪动 ±χ → 重复测量把噪声平均掉，两个可分的散点团就是判决结果。
建议读法：先看四张概念卡与两张 S21 图，建立「同一个腔的两条曲线」这个图像 → 拖滑块体会 χ、κ、shot 数的三角权衡 → 最后读推导链（那里解释 χ 为什么等于 g²/Δ，以及它什么时候不成立）。",
	tone="info", title="① 这一页讲什么：把量子态翻译成一条微波曲线"),
concept_cards([
("图像：腔是麦克风，qubit 是挪音高的音叉", "一段 λ/4 谐振子挂在传输线上，微波扫过它的固有频率 ω<sub>r</sub> 时被吸收或反射，S<sub>21</sub> 就出现一个凹陷（hanger）或谐振峰——峰的半宽由 κ 决定，默认 κ = 0.01 GHz，即 10 MHz。<br><br>qubit 离腔很远（Δ = f<sub>01</sub>−ω<sub>r</sub> ≈ −1.9 GHz），像一只不咬合的音叉：它不吞掉腔里的光子，只是把自己的「重量」压上去，把腔的音高挪一下。挪多少？|0⟩ 挪 −χ、|1⟩ 挪 +χ，于是你看到<b>两条</b>几乎一样的曲线，间隔 2|χ| ≈ 15.5 MHz（默认参数）。<br><br>验证锚点：上方第一张图里蓝（|0⟩）紫（|1⟩）两条曲线的峰位差，就是这一页要读出的全部信号。"),
("机制：χ = g²/Δ，二阶效应才给位移", "qubit 与腔的耦合 g ≈ 121 MHz（电荷矩阵元 × 腔零点涨落，见推导第 5 步），一阶效应本该是交换光子——但失谐 |Δ| ≈ 1.9 GHz 是 g 的 15 倍，交换被能量失配禁戒。<br><br>剩下的是二阶过程：腔里的光子「借」给 qubit 又立刻还回来，代价是腔频被推移 $(tex(raw"\chi = g^2/\Delta \approx -7.7")) MHz。类比：两台没咬合的齿轮中间连根弹簧，转不动对方，只会让对方的节奏偏一点。<br><br>验证锚点：读数卡的 χ 与 g/Δ 就是这个图像的两个刻度；χ 的符号决定哪条曲线在左（默认 χ<0 时 |1⟩ 反而在低频侧），但间隔永远是 2|χ|。"),
("定量：读出最终是统计学", "单次测量只得到 IQ 平面上的一个散点；同一次实验重复 n 发，才是一个可用的判断。散点围绕各自的「真值」形成高斯云，平均之后云心的抖动按 1/√n 收缩，于是 $(tex(raw"\mathrm{SNR} = \tfrac{2\chi}{\sigma}\sqrt{\kappa T}"))。<br><br>信号由曲线间隔 2χ 给定，噪声由单发噪声 σ 与积分时间 T 决定。所谓「读出保真度 99%」的全部数学就在这里——不是信号变强了，而是噪声被平均掉了。<br><br>验证锚点：IQ 动画里的两个噪声圆（半径 = σ，不随 n 变）与虚线「信号间距」；把 shot 数从 50 拖到 500，看云收敛而圆不变。"),
("代价：读出不是免费的", "腔里得有光子才有信号，但光子数 n̄ 一旦接近临界值 $(tex(raw"n_{\mathrm{crit}} = (\Delta/2g)^2 \approx 60"))，色散图像就崩塌：腔频不再停在 ω<sub>r</sub>±χ，而是随 n̄ 连续移动（AC-Stark），qubit 频率也被推走，读完的态不再是读之前的态。<br><br>κ 也有代价：κ 大读得快（ring-up ≈ 2/κ ≈ 200 ns）但线宽大、两条曲线容易糊在一起；κ 小分得清，每次测量却要等更久。再加 Purcell 衰减——腔会把 qubit 的能量漏走，κ 大 T1 就短。<br><br>所以真实读出链路是 χ、κ、T 三者的折衷，每个数字都被人反复调过。"),
]),
callout("六个滑块里，<b>ω<sub>r</sub></b> 决定腔与 qubit 的失谐 Δ，是这一页的主旋钮：它一动，g/Δ 与 χ 同时变，先拖它。<b>κ</b> 决定线宽与读出速度，是「快准权衡」的旋钮，第二个拖。<b>E<sub>Cr</sub></b> 改腔的零点涨落、从而改 g；<b>E<sub>J</sub></b> / <b>E<sub>C</sub></b> 改 qubit 的 f<sub>01</sub> 与非谐性——这两个用来复现「不同器件」。<b>shot 数</b> 只影响统计云收敛，完全不影响曲线本身。
建议顺序：ω<sub>r</sub> → κ → shot 数，其余保持默认。",
	tone="tip", title="③ 调参前先看这里：六个滑块各在改什么"),
)

# ╔═╡ b0000000-0000-4000-8000-000000000004
md"### ③ 调参（transmon + 读出谐振子，全部真实计算）"

# ╔═╡ b0000000-0000-4000-8000-000000000005
@bind EJ Slider(5:0.5:50; default=20)

# ╔═╡ b0000000-0000-4000-8000-000000000006
@bind EC Slider(0.05:0.01:0.5; default=0.30)

# ╔═╡ b0000000-0000-4000-8000-000000000007
@bind E_Cr Slider(0.01:0.005:0.15; default=0.06)

# ╔═╡ b0000000-0000-4000-8000-000000000008
@bind om_r Slider(6.0:0.05:10.0; default=8.5)

# ╔═╡ b0000000-0000-4000-8000-000000000009
@bind kappa Slider(0.002:0.001:0.02; default=0.01)

# ╔═╡ b0000000-0000-4000-8000-00000000000a
@bind nshots Slider(50:50:500; default=200)

# ╔═╡ b0000000-0000-4000-8000-00000000000b
begin
	t = Transmon(EJ, EC; ncut=60)
	f01, alpha, g, chi, Delta = dispersive_params(t, 0.0, E_Cr, om_r)
	ratio = abs(g / Delta)
	kappa_e = 0.6 * kappa
	wr0 = om_r - chi
	wr1 = om_r + chi
	ws = range(om_r - 0.15, om_r + 0.15; length=400)
	s0 = [s21(w, wr0, kappa, kappa_e) for w in ws]
	s1 = [s21(w, wr1, kappa, kappa_e) for w in ws]
	A0 = steady_amplitude(om_r, wr0, kappa)
	A1 = steady_amplitude(om_r, wr1, kappa)
	scale = 60.0
	p0, q0 = real(A0) * scale, imag(A0) * scale
	p1_, q1_ = real(A1) * scale, imag(A1) * scale
	noise = scale / sqrt(kappa * 5.0) * 0.004
	# 测量蒙特卡洛（真实随机抽样：每次 shot 是高斯散点）
	rng = Random.MersenneTwister(42)
	shots0 = [(p0 + noise * Random.randn(rng), q0 + noise * Random.randn(rng)) for _ in 1:nshots]
	shots1 = [(p1_ + noise * Random.randn(rng), q1_ + noise * Random.randn(rng)) for _ in 1:nshots]
	f01_s = string(round(f01, digits=3)); alpha_s = string(round(alpha, digits=3))
	g_s = string(round(g * 1000, digits=1))
	chi_s = string(round(chi * 1000, digits=2))
	sep_s = string(round(2abs(chi) * 1000, digits=2))
	ratio_s = string(round(ratio, digits=3))
end

# ╔═╡ b0000000-0000-4000-8000-00000000000c
@htl("""
<div style="display:flex;gap:12px;flex-wrap:wrap;margin:8px 0">
<div style="flex:1;min-width:140px;border:1px solid rgba(76,111,255,0.18);border-radius:12px;padding:10px 16px;background:#FBFBFF">
<div style="font-size:11px;letter-spacing:1px;color:#7B61FF">色散位移 χ</div>
<div style="font-size:19px;font-weight:700;color:#4C6FFF">$(chi_s) <span style="font-size:12px;color:#8A90AD">MHz</span></div></div>
<div style="flex:1;min-width:140px;border:1px solid rgba(76,111,255,0.18);border-radius:12px;padding:10px 16px;background:#FBFBFF">
<div style="font-size:11px;letter-spacing:1px;color:#7B61FF">|0⟩/|1⟩ 曲线间隔 2χ</div>
<div style="font-size:19px;font-weight:700;color:#7B61FF">$(sep_s) <span style="font-size:12px;color:#8A90AD">MHz</span></div></div>
<div style="flex:1;min-width:140px;border:1px solid rgba(76,111,255,0.18);border-radius:12px;padding:10px 16px;background:#FBFBFF">
<div style="font-size:11px;letter-spacing:1px;color:#7B61FF">耦合 g / 失谐 Δ</div>
<div style="font-size:19px;font-weight:700;color:#1A1A2E">$(g_s) <span style="font-size:12px;color:#8A90AD">MHz / g/Δ = $(ratio_s)</span></div></div>
<div style="flex:1;min-width:140px;border:1px solid rgba(34,195,166,0.25);border-radius:12px;padding:10px 16px;background:#F3FCFA">
<div style="font-size:11px;letter-spacing:1px;color:#199A87">色散近似有效性</div>
<div style="font-size:15px;font-weight:700;color:#199A87">g/Δ &lt; 0.1 时成立 ✓</div></div>
</div>
""")

# ╔═╡ b0000000-0000-4000-8000-00000000000d
let
	ann = Any[
		attr(x=om_r, y=1.02, text="ω_r", showarrow=false, font=attr(size=11, color=PAL[4])),
		attr(x=wr1, y=0.06, text="|1⟩", showarrow=false, font=attr(size=11, color=PAL[2])),
		attr(x=wr0, y=0.06, text="|0⟩", showarrow=false, font=attr(size=11, color=PAL[1])),
	]
	tr = PlotlyBase.GenericTrace[]
	push!(tr, PlotlyBase.scatter(x=ws, y=abs.(s0); mode="lines", name="|0⟩", line=attr(color=PAL[1], width=2.5)))
	push!(tr, PlotlyBase.scatter(x=ws, y=abs.(s1); mode="lines", name="|1⟩", line=attr(color=PAL[2], width=2.5)))
	push!(tr, PlotlyBase.scatter(x=[om_r, om_r], y=[0, 1.05]; mode="lines",
		line=attr(color=PAL[4], width=2, dash="dot"), name="驱动频率 ω_r"))
	p1 = PlotlyBase.Plot(tr,
		layout_base(height=480, title="S21 幅度：qubit 状态把谐振峰整体移动 ±χ",
			xtitle="微波频率 (GHz)", ytitle="|S21|", annotations=ann))
	tr2 = PlotlyBase.GenericTrace[]
	push!(tr2, PlotlyBase.scatter(x=ws, y=angle.(s0) .* 180 / π; mode="lines", name="|0⟩ 相位", line=attr(color=PAL[1], width=2)))
	push!(tr2, PlotlyBase.scatter(x=ws, y=angle.(s1) .* 180 / π; mode="lines", name="|1⟩ 相位", line=attr(color=PAL[2], width=2)))
	p2 = PlotlyBase.Plot(tr2,
		layout_base(height=400, title="S21 相位：同样携带状态信息",
			xtitle="微波频率 (GHz)", ytitle="arg S21 (°)"))
	oq_stack(plotly_html("oq_s21a", p1; height=490),
		figure_note("看图要诀：①蓝（|0⟩）紫（|1⟩）是<b>同一个腔</b>的两条洛伦兹曲线，峰位相隔 2|χ|（读数卡第 2 格），单条峰的半宽就是 κ。②橙色点线是驱动频率 ω<sub>r</sub>，固定不动时两条曲线在它上面的高度差，就是每次测量拿到的「信号」。③把 ω<sub>r</sub> 往 f<sub>01</sub> ≈ 6.6 GHz 拖，两条曲线会突然大幅分开又变形——那是色散近似失效的现场，不是好信号。"),
		plotly_html("oq_s21b", p2; height=410),
		figure_note("看图要诀：①相位在共振附近最陡，斜率就是「小频差 → 大相位差」的放大倍数。②两条相位曲线同样相隔 2|χ|，说明相位通道携带的信息与幅度一样多。③真实读出常在相位（或 IQ 联合）上做判决，因为陡峭斜率对小 χ 更敏感。"))
end

# ╔═╡ b0000000-0000-4000-8000-00000000000e
begin
	# IQ 测量蒙特卡洛动画：散点云逐帧积累（每帧 8 发 shot，真实随机抽样）
	nfr = min(25, max(5, div(nshots, 8)))
	per = max(1, div(nshots, nfr))
	frames = PlotlyBase.PlotlyFrame[]
	for k in 1:nfr
		i2 = min(k * per, nshots)
		xs = vcat([s[1] for s in shots0[1:i2]], [s[1] for s in shots1[1:i2]])
		ys = vcat([s[2] for s in shots0[1:i2]], [s[2] for s in shots1[1:i2]])
		clr = vcat(fill("#4C6FFF", i2), fill("#7B61FF", i2))
		push!(frames, anim_frame(0, string(k), PlotlyBase.scattergl(x=xs, y=ys; mode="markers",
			showlegend=false, hoverinfo="skip", marker=attr(size=4, color=clr, opacity=0.55))))
	end
	tr = PlotlyBase.GenericTrace[]
	push!(tr, PlotlyBase.scattergl(x=Float64[], y=Float64[]; mode="markers", showlegend=false))
	#  ↑ trace 0 就是被动画更新的散点云（初始为空）
	circle_th = range(0, 2π; length=80)
	push!(tr, PlotlyBase.scatter(x=p0 .+ noise .* cos.(circle_th), y=q0 .+ noise .* sin.(circle_th);
		mode="lines", line=attr(color=PAL[1], width=2), name="|0⟩ 噪声圆"))
	push!(tr, PlotlyBase.scatter(x=p1_ .+ noise .* cos.(circle_th), y=q1_ .+ noise .* sin.(circle_th);
		mode="lines", line=attr(color=PAL[2], width=2), name="|1⟩ 噪声圆"))
	push!(tr, PlotlyBase.scatter(x=[p0, p1_], y=[q0, q1_]; mode="lines",
		line=attr(color="rgba(20,24,60,0.25)", width=1.5, dash="dash"), name="信号间距"))
	piq = PlotlyBase.Plot(tr,
		layout_base(height=480, title="IQ 平面测量蒙特卡洛（点播放看散点云积累）",
			xtitle="同相分量 I", ytitle="正交分量 Q", anchor_y=true,
			updatemenus=animation_menu()),
		frames)
	oq_stack(plotly_html("oq_iq", piq; height=490),
		figure_note("看图要诀：①每个点是一发 shot，两团分别是 qubit 处于 |0⟩ 与 |1⟩ 的测量结果，两个噪声圆的圆心距就是信号。②圆的半径是单发噪声 σ，<b>不随</b> shot 数变化；随 n 缩小的是「云心的不确定度」∝ 1/√n。③点播放看散点逐帧积累：两团从重叠到分开，就是判决从「猜」到「确定」的过程。"))
end

# ╔═╡ b0000000-0000-4000-8000-00000000000f
oq_stack(
derivation("⑤ 推导溯源：从传输线到「看见」量子态",
[
	("定义", texblock(raw"S_{21}(\omega) = \frac{\kappa_e}{i(\omega-\omega_{\mathrm{eff}})+\kappa/2}"), "在做什么：把 hanger 谐振子等效成一个有损耗的一阶谐振模，写出它对入射微波的传输响应。为什么成立：任何线性谐振子（RLC 电路、音叉、微波腔）的受迫响应都是同一条洛伦兹线型，分母里的 κ/2 是损耗，分子 κ<sub>e</sub> 是「耦合到传输线的那部分损耗」。图像类比：推秋千——以固有频率 ω<sub>eff</sub> 驱动响应最大，偏开一点就按 |ω−ω<sub>eff</sub>| 衰减。在哪验证：第一张 S21 图里峰的位置 = ω<sub>eff</sub>、峰的半宽 = κ；失效条件：出现寄生模或 κ 随频率明显变化时，单模洛伦兹不再够用。"),
	("定义", texblock(raw"H_r = \omega_r\Big(a^\dagger a + \frac{1}{2}\Big), \qquad V \propto \varphi_{\mathrm{zpf},r}\,(a+a^\dagger)"), "在做什么：把 LC 电路量子化——腔变成光子数阶梯，电压算符正比于产生与湮灭算符之和。为什么成立：LC 谐振子与量子谐振子数学同构，唯一的新物理量是零点涨落 φ<sub>zpf,r</sub>：一个光子都没有时相位也不严格为零。图像类比：绝对零度下仍在轻微发抖的弹簧。在哪验证：拖 E<sub>Cr</sub> 滑块，读数卡的 g 会跟着变（g 正比于 φ<sub>zpf,r</sub>）。失效条件：E<sub>Cr</sub> 不再远小于 ω<sub>r</sub> 的高阻环境下，单模截断与这个近似都要重做。"),
	("定义", texblock(raw"\varphi_{\mathrm{zpf},r} = \Big(\frac{2E_{Cr}}{\omega_r}\Big)^{1/4}"), "在做什么：把零点涨落换算成可测量的电路参数 E<sub>Cr</sub> 与 ω<sub>r</sub>。为什么成立：谐振子基态里相位算符的方差由零点能定标，量纲分析给出四分之一次方。给出数字：默认 E<sub>Cr</sub> = 0.06、ω<sub>r</sub> = 8.5 GHz 时 φ<sub>zpf,r</sub> ≈ 0.345；把 E<sub>Cr</sub> 从 0.01 拖到 0.15，它从 0.22 涨到 0.43。在哪验证：读数卡第 3 格 g = E<sub>C</sub>·n<sub>01</sub>·φ<sub>zpf,r</sub> ≈ 121 MHz 就是这三个数相乘。失效条件：这一步只是参数换算，但 E<sub>Cr</sub> 必须与实际加工出来的电容一致，否则 g 全错。"),
	("定义", texblock(raw"A(\omega) = \frac{\epsilon}{i(\omega-\omega_r)+\kappa/2}"), "在做什么：求受迫谐振子的稳态复振幅，它就是 IQ 平面上的一个点（实部 = I、虚部 = Q）。为什么成立：这是一阶线性微分方程的稳态解，入射波强度 ε 决定幅度，失谐决定相位。图像类比：电流表指针匀速停在某个角度，频率一变角度跟着变。在哪验证：IQ 散点图里两个团心就是 |0⟩ 与 |1⟩ 各自的 A(ω)。失效条件：驱动太强时光子数超 n<sub>crit</sub>，响应不再与 ε 成正比，这个解就失效。"),
	("代入", texblock(raw"g = E_C\,\big|\langle 0|\hat n|1\rangle\big|\,\varphi_{\mathrm{zpf},r}"), "在做什么：算 qubit 与腔的耦合强度 g——电荷矩阵元 n<sub>01</sub> 乘以腔零点涨落再乘以 E<sub>C</sub>。为什么成立：耦合来自岛上库珀对与腔电压的相互作用，n̂ 在两个能级间的矩阵元就是「推力的刻度」（与单比特门那页同源）。给出数字：默认参数 n<sub>01</sub> ≈ 1.17、φ<sub>zpf,r</sub> ≈ 0.345，得 g ≈ 121 MHz，是百 MHz 量级——这正是色散读取可行的前提。在哪验证：读数卡第 3 格；失效条件：公式把 qubit 当两能级，E<sub>J</sub>/E<sub>C</sub> 太小（CPB 区）时 n<sub>01</sub> 与整个图像都要改。"),
	("定义", texblock(raw"H = \omega_r\,a^\dagger a + \frac{\omega_{01}}{2}\sigma_z + g\,(a\sigma_+ + a^\dagger\sigma_-)"), "在做什么：把 qubit 和腔写进同一个 Jaynes–Cummings 哈密顿量——这是本页的全模型。为什么成立：耦合项描述「腔丢一个光子、qubit 升一级」的交换，矩阵元随光子数按 √n 增强。图像类比：两个秋千之间连根弹簧，能量在两者间来回倒。在哪验证：本页显示的 χ 正是对这个哈密顿量（截断 6 个光子）数值对角化得到的。失效条件：这里已做了一次 RWA（丢掉 aσ<sub>−</sub> 之类的快变项），要求 g、κ ≪ ω<sub>r</sub>，本页 0.12 GHz ≪ 8.5 GHz，成立。"),
	("近似", texblock(raw"g \ll |\Delta|:\qquad H_{\mathrm{disp}} = \big(\omega_r + \chi\,\sigma_z\big)a^\dagger a + \cdots, \qquad \chi = \frac{g^2}{\Delta}"), "在做什么：做 Schrieffer–Wolff 变换，把「交换光子」的一阶耦合转成二阶的频移项——这就是色散展开的核心。为什么成立：失谐 |Δ| = 1.89 GHz 是 g = 0.121 GHz 的 15 倍（读数卡 g/Δ = 0.064），能量失配把交换压到 (g/Δ)² 量级。图像类比：没咬合的齿轮互相压出一点节奏偏移，却转不动对方。在哪验证：看 g/Δ 卡片——它小于 0.1 时两条曲线才关于 ω<sub>r</sub> 对称。失效条件：g/Δ ≳ 0.1 后微扰不收敛，把 ω<sub>r</sub> 拖近 f<sub>01</sub> 就能看到 χ 的微扰值与数值对角化分道扬镳。"),
	("近似", texblock(raw"|0\rangle \to \omega_r - \chi, \qquad |1\rangle \to \omega_r + \chi"), "在做什么：把色散哈密顿量翻译成人话——qubit 处在哪个态，腔频就挪到哪里。为什么成立：σ<sub>z</sub> 的本征值 ±1 直接进 a†a 前面的系数；又因为没有能量交换，读完之后 qubit 态不变，这就是 QND（非破坏测量）。给出数字：默认 χ = −7.7 MHz，两条曲线相隔 2|χ| = 15.5 MHz，比线宽 κ = 10 MHz 略宽——刚好能分开。在哪验证：第一张图两条曲线的峰位差。失效条件：χ 的符号随 Δ 变号（默认 χ<0 时 |1⟩ 曲线反而在低频侧），但间隔永远是 2|χ|；另外真实 transmon 的 χ 还要乘一个 |2⟩ 修正因子（见下方深入）。"),
	("代入", texblock(raw"S_{21}(\omega,|0\rangle)\ \ \mathrm{vs.}\ \ S_{21}(\omega,|1\rangle) \qquad \Rightarrow\qquad \text{peak separation} = 2\chi"), "在做什么：把「qubit 处于哪个态」翻译成「两条 S21 曲线在哪」——扫频能直接看到，固定频率则变成幅度/相位的差别。为什么成立：微波仪器最擅长分辨频率与相位，而 2χ ≈ 15 MHz 完全在它的量程里。图像类比：与其去听音叉本身（太弱），不如听它挪动的那口钟。在哪验证：橙色点线（驱动频率 ω<sub>r</sub>）处两条曲线的高度差，就是单发测量的信号。失效条件：2χ ≲ κ 时两条曲线糊在一起，只能靠相位斜率与更长积分勉强分辨。"),
	("整理", texblock(raw"\mathrm{SNR} = \frac{2\chi}{\sigma}\,\sqrt{\kappa T}, \qquad n \propto \kappa T"), "在做什么：把有限积分时间写进判决公式——分子是信号间距 2χ，分母里的 σ/√n 是平均 n 发之后的噪声。为什么成立：n 发独立高斯 shot 平均后噪声圆半径按 1/√n 收缩，而 n 由腔的带宽 κ 与积分时间 T 共同决定（κ 越大每秒收集的样本越多）。图像类比：多听几秒，就听清了。在哪验证：IQ 动画里把 shot 数从 50 拖到 500，看两团从重叠到分开。失效条件：n 不能无限加——光子数超 n<sub>crit</sub> ≈ 60 时，测量本身会把 qubit 推走（见下方深入）。"),
];
lead="这条推导分三段：<b>先建腔</b>（第 1–4 步：把 hanger 谐振子写成有损耗的谐振模，得到 S21 的洛伦兹线型与 IQ 稳态点）→ <b>再接上 qubit</b>（第 5–8 步：耦合 g 来自电荷矩阵元，色散展开把它变成腔频的 ±χ 位移）→ <b>最后翻译成可测量</b>（第 9–10 步：两条曲线的峰位差 2χ，以及有限积分时间带来的统计误差）。
读法：每一步都标了「在哪验证」——对照上方两张 S21 图与读数卡的 g、Δ、χ 三个数；它们由 transmon 电荷基对角化算出，<b>不是拟合参数</b>。",
result="结论落回读数卡：χ = $(chi_s) MHz ⇒ 两条 S21 曲线相隔 $(sep_s) MHz——这就是上方第一张图上量得到的「信号」；g/Δ = $(ratio_s)，$(ratio < 0.1 ? "色散近似成立，两曲线关于 ω<sub>r</sub> 对称" : "g/Δ 偏大，色散近似开始失效（把 ω<sub>r</sub> 拖远试试）")。再对照线宽 κ = $(kappa) GHz：2χ 与 κ 同量级时两峰只是勉强分开，SNR 公式里剩下的自由度只有积分时间 T（shot 数滑块）。"),
deep_dive("色散读取的三个数字：g/Δ、2χ/κ、n̄/n_crit", """
<p>色散读取成不成立，由三个无量纲比值决定，默认参数下分别是：
<b>g/Δ ≈ 0.064</b>（微扰是否收敛）、<b>2|χ|/κ ≈ 1.5</b>（两条曲线是否可分）、<b>n̄/n<sub>crit</sub></b>（功率是否越界），
其中 $(tex(raw"n_{\mathrm{crit}} = (\Delta/2g)^2 \approx 60")) 个光子。第一条要小（本页读数卡在 g/Δ < 0.1 时画 ✓），
第二条要大（15.5 MHz 对 10 MHz 只是勉强），第三条限制测量功率。</p>
<p>工程上还有几组数量级：腔的 ring-up 时间 ~2/κ ≈ 200 ns，所以一次读出至少几百 ns；
真实器件 κ/2π ≈ 1–5 MHz、χ/2π ≈ 0.5–2 MHz（比本页演示小一档，因为真实失谐更大）；
读出线上必须放量子极限放大器（约 +20 dB、噪声温度 ~2 K），否则单发噪声 σ 会把 2χ 淹没。</p>
<p>公式的边界：$(tex(raw"\chi = g^2/\Delta")) 是<b>两能级</b>结果，本页的 χ 由两能级 JC 数值对角化给出
（默认参数下与 $(tex(raw"g^2/\Delta")) 只差约 1%）。真实 transmon 还有 |2⟩ 的贡献，
色散位移变为 $(tex(raw"\chi = \frac{g^2}{\Delta}\cdot\frac{\alpha}{\Delta+\alpha}"))，默认参数下多乘一个 ≈ 0.15 的因子（χ 只剩 ~1.2 MHz）。
自检记法：α → 0（谐性极限）时这个式子给 χ → 0——线性系统里「条件频率」根本不存在，这正是它比 $(tex(raw"g^2/\Delta")) 更可信的原因。</p>
""", tone="detail"),
deep_dive("常见误解：功率越大看得越清？S21 是 qubit 的谱？", """
<p><b>误解一：读出功率越大，看得越清楚。</b>错。信号间距 2χ 是<b>频率差</b>，加功率并不会把它拉大，
拉大的只是腔内光子数 n̄。一旦 n̄ 接近 $(tex(raw"n_{\mathrm{crit}} \approx 60"))，色散图像崩塌：
腔频随 n̄ 连续移动（AC-Stark 频移），qubit 频率也被推离标定位置，读完的态不再是读之前的态——
这既毁掉 QND，也毁掉保真度。正确做法是：功率取在 n<sub>crit</sub> 以下，用积分时间换信噪比。</p>
<p><b>误解二：S21 是 qubit 的吸收谱。</b>错。S21 的峰是<b>腔</b>的响应，qubit 从头到尾没有直接出现在这条曲线上，
它只是把腔频挪了 ±χ。看第一张图时请读成「同一个腔的两条曲线」，而不是「qubit 的两条谱线」。</p>
<p><b>误解三：两条曲线分开了就一定能读。</b>错，判据是 2χ 与 κ 的<b>比值</b>。
默认 2|χ| ≈ 15.5 MHz、κ = 10 MHz 只是勉强；把 κ 拖到 0.02，两条曲线糊成一团，
此时再长的积分也救不回来——信号与线宽的比值已经小于 1，这是结构性问题，不是统计问题。</p>
""", tone="warn"),
)

# ╔═╡ b0000000-0000-4000-8000-000000000010
tryout([
("眼见色散近似失效", "<b>动机</b>：色散读取的全部合法性押在 g/Δ ≪ 1 上；只有亲眼看过它崩塌，才知道这个条件到底卡住什么。<br><b>做法</b>：把 ω<sub>r</sub> 从 8.5 一路拖到 6.8（贴近 f<sub>01</sub> ≈ 6.6 GHz），其余滑块不动。",
 "<b>看什么</b>：g/Δ 卡片从 0.06 涨到 0.5 以上，χ 的数值急剧变大（MHz 位数跳一级），两条 S21 曲线不再关于 ω<sub>r</sub> 对称，峰位与形状都变形。<br><b>说明什么</b>：交换光子不再被能量失配禁戒，腔与 qubit 开始真的交换能量，QND 假设崩塌（推导第 7–8 步失效）；同时 χ = g²/Δ 的微扰值与数值对角化分道扬镳。<br><b>如果没看到</b>：先确认 E<sub>J</sub>/E<sub>C</sub> 仍是 20/0.30（此时 f<sub>01</sub> ≈ 6.6 GHz）；若把 ω<sub>r</sub> 拖得比 f<sub>01</sub> 还低，Δ 变号、χ 跟着变号，两条曲线左右互换——这本身也是一个值得看一眼的现象。"),
("κ 的快准权衡与「可分辨」判据", "<b>动机</b>：真实读出要在「读得快」与「分得清」之间折衷，判据不是单看 κ，而是 2χ/κ 这个比值。<br><b>做法</b>：回到默认参数（ω<sub>r</sub> = 8.5），把 κ 从 0.002 拖到 0.02。",
 "<b>看什么</b>：κ 小：峰窄而高、两条曲线分得很开；κ 大：峰宽而矮，当 κ 接近 2|χ| ≈ 15.5 MHz（即 κ ≈ 0.015）时两条曲线开始糊在一起。<br><b>说明什么</b>：κ 既是带宽（读出速率 ∝ κ）又是模糊度（可分辨性要求 2χ ≳ κ），一个旋钮两个后果，这就是快准权衡的来源。真实器件 κ/2π ≈ 1–5 MHz、2χ/2π ≈ 0.5–2 MHz，两者同量级，靠相位斜率与数字积分分开。<br><b>如果没看到</b>：两条曲线始终分得很开，说明当前 χ 还远大于 κ；继续拖大 κ，或拖小 E<sub>Cr</sub>（它减小 g，从而按 g² 减小 χ），把 2χ/κ 压到 1 附近再看。"),
("亲自看 SNR ∝ √n", "<b>动机</b>：「99% 读出保真度」的魔法其实是统计学——噪声没有变小，只是被平均掉了。<br><b>做法</b>：κ 回到 0.01，把 shot 数从 50 拖到 500，点 IQ 动画的播放按钮。",
 "<b>看什么</b>：散点云从「两团重叠」到「两团清晰分开」；两个噪声圆的半径不变，缩小的是团心的抖动范围。<br><b>说明什么</b>：单发噪声 σ 由放大器与线宽决定，平均 n 发后噪声圆半径 ∝ 1/√n，于是 SNR = (2χ/σ)·√(κT)——保真度是被平均出来的，不是被放大出来的。<br><b>如果没看到</b>：shot 拖到 500 仍分不开，先看 κ 是不是已被拖大（两峰已糊）或 χ 太小——统计学救不了「信号/线宽」的结构性问题，得先回上一个任务把 2χ/κ 调好。"),
])

# ╔═╡ b0000000-0000-4000-8000-000000001002
quiz([
	("色散读取中 qubit 处于 |1⟩ 时，读出腔的频率如何变化？",
	 ["不变", "ω_r + χ", "ω_r − χ", "κ 变大"], 2,
	 "正确：ω_r + χ。色散哈密顿量把 qubit 的态塞进腔频的系数里：|0⟩ → ω_r − χ、|1⟩ → ω_r + χ，两条 S21 曲线相差 2χ，且 χ = g²/Δ。<br><b>错误选项辨析</b>：「不变」错——那等于 g = 0、qubit 与腔完全没耦合，可读出恰恰靠 g²/Δ 这个小位移；「ω_r − χ」错——那是 |0⟩ 的位置（注意 χ 变号时两条曲线左右互换，但 |0⟩ 永远取 −χ）；「κ 变大」错——κ 是腔的损耗率、由外部耦合决定，qubit 只挪中心频率，不动线宽。"),
	("为什么说色散读取是「QND」的？",
	 ["测量很快", "qubit 与腔失谐很大，不交换能量，只被推移频率", "腔里没有光子", "用了量子极限放大器"], 2,
	 "正确：g ≪ |Δ| 时一阶交换被能量失配禁戒，qubit 既不吸收也不放出光子，只把腔频推移 ±χ——读完之后态不变（非破坏测量）。<br><b>错误选项辨析</b>：「测量很快」错——快慢与是否翻转态无关，甚至更快的脉冲带宽更宽、更容易引起跃迁；「腔里没有光子」错——读出必须有 n̄ 个光子才有信号，QND 限制的是 n̄ ≪ n_crit，而不是 n̄ = 0；「量子极限放大器」错——它只降低电子学噪声，不改变测量与 qubit 的相互作用方式。"),
	("读出保真度主要靠什么提升？",
	 ["增大 κ", "积分时间/平均次数（SNR ∝ √(κT)）", "减小 χ", "增大 g"], 2,
	 "正确：积分时间/平均次数。两个高斯团的间距固定后，噪声圆半径 ∝ 1/√n，n = κT 是积分内的样本数——99%+ 保真度背后的全部统计学。<br><b>错误选项辨析</b>：「增大 κ」错——κ 变大虽然多收集样本，却同时加宽带宽噪声、并让 2χ/κ 变小（两峰变糊），单靠它通常更差；「减小 χ」错——χ 是信号的一半，减小它等于把两条曲线拉近；「增大 g」看似合理（χ = g²/Δ 会变大），但 g 变大也让 g/Δ 变大、色散近似变差，还通过 Purcell 缩短 T1——真正的杠杆是 2χ/κ 的设计与积分时间。"),
	("真实读出链路为什么几乎都给读出腔加 Purcell 滤波器？",
	 ["提高谐振腔的品质因数 Q，让曲线更尖锐", "让腔在测量频点照样快漏，但对比特频率呈高阻，压低 kappa(g/Delta)^2 的衰减通道", "把 chi 增大，两条谐振曲线分得更开", "防止光子数超过临界值 n_crit"], 2,
	 "Purcell 滤波器解决的是「读得快 vs 死得快」的矛盾：测量要 κ 大，但比特顺着同一通道衰减 $(tex(raw"\Gamma_P=\kappa(g/\Delta)^2"))。滤波器让腔的<b>外部阻抗</b>在工作频点低（κ 大、读得快）、在比特频点高（Γ<sub>P</sub> 被压 10–100×）。<b>错误选项辨析</b>：A 恰好说反——要读得快恰恰要 κ 大（Q 小）；C χ 由 g、Δ 决定，滤波器不改变色散移位；D n_crit 靠「少放光子」控制，与滤波器无关（那是概念卡「代价」的另一条账）。"),
])

# ╔═╡ b0000000-0000-4000-8000-00000000d001
let
	# 文献对标：色散读取链路的真实参数（Blais 2021 RMP 为主要来源）
	kappa_MHz = string(round(kappa * 1000, digits=1))
	oq_stack(
	section_header("⑦", "对标真实读出链路：χ、κ、Purcell 与量子效率"),
	readout_table([
		("谐振腔 ω<sub>r</sub>", string(round(om_r, digits=1), " GHz"), "真实 6–8 GHz：λ/4 共面波导或 3D 腔；与比特失谐 Δ/2π = 1–3 GHz 保证色散判据 g/Δ ≪ 1"),
		("线宽 κ/2π", string(kappa_MHz, " MHz"), "真实 0.1–10 MHz；工程经验法则 <b>κ ≈ 2χ</b> 时两条谐振曲线的判别度最优（Blais 2021 RMP §VI）"),
		("耦合 g/2π", "本页读数卡", "真实 50–250 MHz；g 大信号强，但 g/Δ 变大色散近似先垮——又是拔河"),
		("色散移位 χ/2π", "本页读数卡", "真实 0.5–3 MHz（可到 ~10 MHz：可调耦合器/参数增强）；本页默认参数的 χ 偏大，是教学故意调浓的"),
		("读出时长", "（本页 κ 对应 ring-up ≈ 2/κ）", "真实 100 ns–1 μs：测量率 Γ<sub>meas</sub> ≈ 0.1–10 MHz，与 κ、光子数 n̄ 同刻度"),
		("单发判别", "IQ 平面 + 重复平均", "真实 99%+ 读出保真度 = κ≈2χ 的设计 + 量子极限放大器 + 匹配滤波/数字积分"),
	]; title="本页六个滑块扫的正是真实读出链路的六个设计旋钮"),
	deep_dive("Purcell 衰减：腔读得越快，比特死得越快", """
	<p>色散读取的隐藏账单：比特通过同一个 g 与腔耦合，腔又以 κ 往测量线漏光子，于是比特多了一条衰减通道——$(tex(raw"\Gamma_{\mathrm{Purcell}} = \kappa\,(g/\Delta)^2"))。代入真实数字感受量级：κ/2π = 2 MHz、g/2π = 100 MHz、Δ/2π = 1.5 GHz → Γ<sub>P</sub>/2π ≈ 9 kHz，对应 T<sub>1,P</sub> ≈ 18 μs——比材料极限（>100 μs）差好几倍。<b>要读得快就得 κ 大，κ 大 Purcell 就狠</b>，这就是为什么几乎每台处理器都在读出腔后面加 <b>Purcell 滤波器</b>（Reed 2010；Sete–Martinis–Korotkov PRA 2015 的带通理论）：让腔在工作频点照样快漏（测量快），但对比特频率呈现高阻（衰减被压 10–100×），κ/2π 可以放到 10–20 MHz 而不牺牲 T<sub>1</sub>。</p>
	""", tone="detail"),
	deep_dive("量子效率：散粒噪声是 readout 的物理底", """
	<p>概念卡说「保真度靠平均」，平均的成本由<b>量子效率 η</b> 结账：η =（你实际拿到的 SNR）/（理论上从腔里漏出的光子所允许的最大 SNR），真实链路（HEMT + 约瑟夫森参数放大器 + 损耗）典型 η = 0.3–0.6。η < 1 意味着达到同样保真度需要更多光子、更长积分——这也是为什么读出放大器是量子硬件里和比特同样金贵的部件。另有一条容易忽略的账：腔里光子数的涨落（shot noise）会通过 χ 给比特一个随机的 AC-Stark 相移——测量本身在把 T<sub>2</sub> 往下压，读出强度又一次不是免费的。</p>
	""", tone="tip"),
	)
end

# ╔═╡ b0000000-0000-4000-8000-000000000012
@htl("""
<div style="font-size:14.5px;color:#33384D;line-height:2.0;margin-top:6px">
<p><b>核心机制。</b>色散读取把「量子态」翻译成「腔频」：qubit 与腔不交换能量，只通过二阶过程把腔频挪动 ±χ = ±g²/Δ；S21 两条曲线的峰位差 2χ 就是全部信号，在 IQ 平面上表现为两个可分的散点团。三个无量纲数决定成败：g/Δ ≈ 0.06（合法性）、2χ/κ ≈ 1.5（可分辨性）、n̄/n<sub>crit</sub>（功率上限，n<sub>crit</sub> ≈ 60 个光子）。</p>
<p><b>常见误解。</b>「S21 是 qubit 的谱」——不，它是腔的响应，qubit 只负责搬峰位；「功率越大看得越清」——超过 n<sub>crit</sub> 后色散崩塌、AC-Stark 频移把态推走；「两条曲线分开就一定能读」——若 2χ ≲ κ，再长的积分也救不回来；「χ 永远是正的」——χ 的符号跟着 Δ 走，只有间隔 2|χ| 是不变量。</p>
<p><b>真实器件里什么样。</b>χ/2π 只有 0.5–2 MHz、κ/2π 约 1–5 MHz，读出线末端是约 +20 dB 的量子极限放大器，判决靠数字积分与匹配滤波；一次读出几百 ns 到 1 µs，读出腔还要加 Purcell 滤波器保住 T1。99%+ 的读出保真度 = 2χ/κ 的设计 + 几十到几百次重复 + 逐日标定的判决阈值。</p>
<p><b>下一步。</b>回 <b>MVP-0</b> 看非谐性 α 如何进入 χ（真实 transmon 的 χ 要乘 α/(Δ+α)）；去 <b>单比特门</b> 看怎么把 |0⟩ 精确推到 |1⟩；<b>DRAG</b> 那页解释为什么门必须在读出之前就压住 |2⟩ 泄漏——否则你读到的态早已不是你造出的态。</p>
</div>
""")

# ╔═╡ 00000000-0000-0000-0000-000000000001
PLUTO_PROJECT_TOML_CONTENTS = """
[deps]
HypertextLiteral = "ac1192a8-f4b3-4bfe-ba22-af5b92cd3ab2"
PlotlyBase = "a03496cd-edff-5a9b-9e67-9cda94a718b5"
PlutoUI = "7f904dfe-b85e-4ff6-b463-dae2292396a8"
Random = "9a3f8284-a2c9-5f02-9a11-845980a1fd5c"
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
project_hash = "d128672547a86e1b64d01ce88fadc7ea6722822d"

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
# ╟─b0000000-0000-4000-8000-000000000001
# ╠═b0000000-0000-4000-8000-000000001001
# ╠═b0000000-0000-4000-8000-000000000002
# ╠═b0000000-0000-4000-8000-000000000003
# ╟─b0000000-0000-4000-8000-000000000004
# ╟─b0000000-0000-4000-8000-000000000005
# ╟─b0000000-0000-4000-8000-000000000006
# ╟─b0000000-0000-4000-8000-000000000007
# ╟─b0000000-0000-4000-8000-000000000008
# ╟─b0000000-0000-4000-8000-000000000009
# ╟─b0000000-0000-4000-8000-00000000000a
# ╟─b0000000-0000-4000-8000-00000000000b
# ╠═b0000000-0000-4000-8000-00000000000c
# ╟─b0000000-0000-4000-8000-00000000000d
# ╟─b0000000-0000-4000-8000-00000000000e
# ╠═b0000000-0000-4000-8000-00000000000f
# ╠═b0000000-0000-4000-8000-000000000010
# ╠═b0000000-0000-4000-8000-000000001002
# ╠═b0000000-0000-4000-8000-00000000d001
# ╠═b0000000-0000-4000-8000-000000000012
# ╟─00000000-0000-0000-0000-000000000001
# ╟─00000000-0000-0000-0000-000000000002
