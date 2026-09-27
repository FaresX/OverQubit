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
</div>
""")

# ╔═╡ b0000000-0000-4000-8000-000000000003
concept_cards([
("hanger 读出腔", "一段 λ/4 微波谐振子（频率 ω<sub>r</sub>，线宽 κ）挂在传输线上：信号在 ω<sub>r</sub> 处谐振增强或抵消，S21 出现凹陷/谐振峰。κ 大=读得快但准头差，反之亦然。"),
("色散读取（QND）", "qubit 与腔远离共振（失谐 Δ ≫ g）时，qubit 不与腔交换能量，只把腔频「推」一下：|0⟩ → ω<sub>r</sub>−χ，|1⟩ → ω<sub>r</sub>+χ。读腔 = 间接读 qubit，不翻转它。"),
("为什么要积分", "单次测量是 IQ 平面上的一个高斯散点。n 次平均后噪声圆半径 ∝ 1/√n——SNR ∝ √(κT)。下方动画让你亲眼看散点云收敛。"),
])

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
	oq_stack(plotly_html("oq_s21a", p1; height=490), plotly_html("oq_s21b", p2; height=410))
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
	plotly_html("oq_iq", piq; height=490)
end

# ╔═╡ b0000000-0000-4000-8000-00000000000f
derivation("⑤ 推导溯源：从传输线到「看见」量子态",
[
("定义", texblock(raw"\text{经典 RLC：} \text{传输振幅} \propto \frac{1}{i(\omega-\omega_r)+\kappa/2} \;\;\Rightarrow\;\; S_{21}(\omega) = \frac{\kappa_e}{i(\omega-\omega_{\mathrm{eff}})+\kappa/2}"), "hanger 谐振子的洛伦兹响应：$(tex(raw"\kappa")) 是总衰减率，$(tex(raw"\kappa_e")) 是耦合到传输线的部分。"),
("定义", texblock(raw"H_r = \omega_r\Big(a^\dagger a + \frac{1}{2}\Big), \qquad V \propto \varphi_{\mathrm{zpf},r}\,(a+a^\dagger)"), texblock(raw"\Rightarrow\quad \varphi_{\mathrm{zpf},r} = \Big(\frac{2E_{Cr}}{\omega_r}\Big)^{1/4}")),
("定义", texblock(raw"\varphi_{\mathrm{zpf},r} = \Big(\frac{2E_{Cr}}{\omega_r}\Big)^{1/4}"), "LC 电路 → 光子数阶梯。$(tex(raw"\varphi_{\mathrm{zpf},r}")) 是相位零点涨落（与 transmon 的 $(tex(raw"\varphi_{\mathrm{zpf}}")) 同源）。"),
("定义", texblock(raw"\dot a = -\Big(i\omega_r + \frac{\kappa}{2}\Big)a - \sqrt{\kappa_e}\,a_{\mathrm{in}}"), texblock(raw"\Rightarrow\quad S_{21}(\omega) = \frac{\kappa_e}{i(\omega-\omega_r)+\kappa/2}\quad(\text{与第 1 步同式})")),
("定义", texblock(raw"A(\omega) = \frac{\epsilon}{i\Delta+\kappa/2}"), "腔场由入射微波受迫驱动；稳态振幅就是 IQ 平面上的点。"),
("代入", texblock(raw"g = E_C\,\big|\langle 0|\hat n|1\rangle\big|\,\varphi_{\mathrm{zpf},r}"), "$(tex(raw"g")) 的微观来源——电荷矩阵元 × 腔零点涨落。读数卡显示它的数值（~百 MHz 量级）。"),
("定义", texblock(raw"H = \omega_r\,a^\dagger a + \frac{\omega_{01}}{2}\sigma_z + g\,(a\sigma_+ + a^\dagger\sigma_-)"), "Jaynes–Cummings：qubit 与腔交换一个光子的全耦合模型（含 $(tex(raw"|2\rangle")) 修正后 $(tex(raw"\chi")) 多一个 $(tex(raw"\alpha/(\Delta+\alpha)")) 因子）。"),
("近似", texblock(raw"g \ll |\Delta|,\ \ \text{Schrieffer–Wolff:}\qquad H_{\mathrm{disp}} = \big(\omega_r + \chi\,\sigma_z\big)a^\dagger a + \cdots"), texblock(raw"\chi = \frac{g^2}{\Delta}, \qquad \Delta = \omega_{01}-\omega_r")),
("近似", texblock(raw"|0\rangle \to \omega_r - \chi, \qquad |1\rangle \to \omega_r + \chi"), "qubit 不交换能量（QND），只改腔频。数值上由 JC 对角化精确复现。"),
("代入", texblock(raw"\text{读取：} S_{21}(\omega,|0\rangle)\ \text{与}\ S_{21}(\omega,|1\rangle)\ \text{峰位差} = 2\chi"), "把 qubit 态转成微波频率差——这就是「看见」的全部机制。橙色虚线是你选定的驱动频率。"),
("整理", texblock(raw"\mathrm{SNR} = \frac{2\chi}{\sigma}\,\sqrt{\kappa T} \qquad (n \propto \kappa T)"), "积分时间 $(tex(raw"T")) 内的 shot 数 $(tex(raw"n\propto\kappa T"))。IQ 动画的散点云收敛就是这个 $(tex(raw"\sqrt n")) 的可视化。"),
];
lead="每一步都可点开。对照读数卡：g、Δ、χ 都是电荷基 transmon + JC 对角化的真值。",
result="χ = $(chi_s) MHz，曲线间隔 $(sep_s) MHz；g/Δ = $(ratio_s)——$(ratio < 0.1 ? "色散近似成立，两曲线关于 ω_r 对称" : "g/Δ 偏大，色散近似开始失效（把 ω_r 拖远试试）")。")

# ╔═╡ b0000000-0000-4000-8000-000000000010
tryout([
("眼见色散近似失效", "把 ω<sub>r</sub> 从 8.5 往下拖到 6.8（贴近 f01）。",
 "g/Δ 卡片逼近 1，χ 数值急剧变大、两条曲线不再对称——这时读出腔已不是「旁观者」，QND 读取的假设崩塌（推导第 6 步失效）。"),
("带宽 κ 的快准权衡", "拖 κ 从 0.002 到 0.02，观察 S21 峰。",
 "κ 小：峰窄而高（准头好）但 ring-up 慢（读得慢）；κ 大：峰宽而矮。真实器件 κ/2π ~ 1-10 MHz，就是两者的折衷。"),
("亲自看 SNR ∝ √n", "拖「shot 数」从 50 到 500，点 IQ 动画的播放。",
 "散点云从「糊成一片」到「两个可分的团」——分离度（信号间距/噪声圆）随 √n 增长。这就是量子计算里「读出保真度 99%+」背后的全部统计学。"),
])

# ╔═╡ b0000000-0000-4000-8000-000000001002
quiz([
	("色散读取中 qubit 处于 |1⟩ 时，读出腔的频率如何变化？",
	 ["不变", "ω_r + χ", "ω_r − χ", "κ 变大"], 2,
	 "色散哈密顿量 (ω_r + χσ_z)a†a：|0⟩ → ω_r − χ，|1⟩ → ω_r + χ，两条 S21 曲线相差 2χ。χ = g²/Δ。"),
	("为什么说色散读取是「QND」的？",
	 ["测量很快", "qubit 与腔失谐很大，不交换能量，只被推移频率", "腔里没有光子", "用了量子极限放大器"], 2,
	 "g ≪ |Δ| 时耦合极弱，qubit 既不吸收也不放出光子，只把腔频推移 ±χ——读完不翻转状态（非破解性测量）。"),
	("读出保真度主要靠什么提升？",
	 ["增大 κ", "积分时间/平均次数（SNR ∝ √(κT)）", "减小 χ", "增大 g"], 2,
	 "IQ 平面两个高斯团的分离度固定后，噪声圆半径 ∝ 1/√n，n = κT 为积分内平均光子数——这就是 99%+ 保真度背后的统计学。"),
])

# ╔═╡ b0000000-0000-4000-8000-000000000012
@htl("""
<div style="font-size:14.5px;color:#33384D;line-height:2.0;margin-top:6px">
<p><b>为什么读得远。</b>腔的光子数 ~10⁴ 才能推动放大器，qubit 的 |0⟩/|1⟩ 只推腔频 ±χ（~MHz）。色散读取把「弱信号」转成「频率差」，这是它取代直接测量的核心原因。</p>
<p><b>还没展示的。</b>强驱动下的光子数分裂（dressed 态间隔 2χ√n̄）、测量反作用与波函数塌缩、Purcell 效应——都列为后续演示（backlog）。</p>
<p><b>下一步：</b>回到 <b>MVP-0</b> 看非谐性 α 如何决定这一切；去 <b>单比特门</b> 看怎么把 |0⟩ 推到 |1⟩ 再读出来。</p>
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
# ╠═b0000000-0000-4000-8000-000000000012
# ╟─00000000-0000-0000-0000-000000000001
# ╟─00000000-0000-0000-0000-000000000002
