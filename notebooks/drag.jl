### A Pluto.jl notebook ###
# v0.20.10

using Markdown

# ╔═╡d0000000-0000-4000-8000-000000000001
begin
	using PlutoUI, PlotlyBase, Statistics, HypertextLiteral
	include(joinpath(@__DIR__, "..", "src", "OverQubit.jl"))
	include(joinpath(@__DIR__, "..", "src", "OverQubitViz.jl"))
	using .OverQubit, .OverQubitViz
	setup_page()
end

# ╔═╡d0000000-0000-4000-8000-000000000002
@htl("""
<div style="background:linear-gradient(100deg,#EEF1FF 0%,#F6F2FF 60%,#EFFBF8 100%);border-radius:14px;padding:20px 26px;margin:2px 0 10px 0">
<div style="font-size:12px;letter-spacing:2px;color:#7B61FF;font-weight:600">OVERQUBIT · DRAG 校准</div>
<div style="font-size:24px;font-weight:700;color:#1A1A2E;margin-top:4px">DRAG：用一条正交微分曲线压住泄漏</div>
<div style="color:#5A6182;margin-top:8px;font-size:14px">驱动 |0⟩↔|1⟩ 时，|2⟩ 只差 |α| 就共振了。DRAG 的答案：给脉冲加一条「导数正交分量」，让泄漏路径自己抵消</div>
</div>
""")

# ╔═╡d0000000-0000-4000-8000-000000000003
concept_cards([
("为什么泄漏躲不掉", "驱动频率 f<sub>01</sub> 离 |1⟩→|2⟩ 跃迁只有 |α|（~0.3 GHz）。门要快（amp 大），泄漏就 ∝ (amp·V<sub>12</sub>/Δ<sub>2</sub>)² 涨上来。"),
("DRAG 的想法", "在脉冲的**正交分量**（相位差 90°）加一条 ∝ dI/dt 的微分曲线：它产生的泄漏恰好与主脉冲的泄漏反相，一阶抵消。"),
("β 是要标定的", "一阶理论给出 |β| ≈ 1/(2|Δ₂|) 量级，但高阶修正让实验上 β 永远靠数值扫描标定——本页的 β 扫描就是真实器件的标定流程。"),
])

# ╔═╡d0000000-0000-4000-8000-000000000002
lesson_nav([
	("①", "transmon 能级与量子化", "done"),
	("②", "单比特门与 Rabi", "done"),
	("③", "DRAG 泄漏压制", "current"),
	("④", "色散读取 S21", "todo"),
	("⑤", "两比特耦合与 iSWAP", "todo"),
	("⑥", "磁通调谐与能级扇形图", "todo"),
	("⑦", "T1 / T2 / Ramsey", "todo"),
])

# ╔═╡d0000000-0000-4000-8000-000000000004
md"""### ③ 调参（单次门：幅度 / 宽度 / DRAG 系数）"""

# ╔═╡d0000000-0000-4000-8000-000000000005
@bind amp Slider(0.05:0.01:0.35; default=0.25)

# ╔═╡d0000000-0000-4000-8000-000000000006
@bind sigma Slider(3:0.5:15; default=6)

# ╔═╡d0000000-0000-4000-8000-000000000007
@bind beta Slider(-5:0.25:5; default=0.0)

# ╔═╡d0000000-0000-4000-8000-000000000008
begin
	t = Transmon(20.0, 0.30; ncut=60)
	f01, f12 = f01_f12(t, 0.0)
	α_ = f12 - f01
	n01 = abs(charge_matrix_element(t, 0, 1))
	n12 = abs(charge_matrix_element(t, 1, 2))
	T = 30.0; t0 = 0.35 * T
	It(tt) = amp * exp(-((tt - t0) / sigma)^2)
	dIt(tt) = It(tt) * (-2 * (tt - t0) / sigma^2)
	Qt(tt) = -beta * dIt(tt)
	ts, pops, _ = evolve_density_iq(t, 0.0, f01, It, Qt, T; dt=0.02)
	# β 扫描（固定 amp/σ/T，真实循环计算）
	betas = collect(-5:0.25:5)
	leaks = Float64[]
	for b in betas
		Qb(tt) = -b * dIt(tt)
		_, p3, _ = evolve_density_iq(t, 0.0, f01, It, Qb, T; dt=0.04)
		push!(leaks, maximum(p3[:, 3]))
	end
	bmin = betas[argmin(leaks)]
	# 无 DRAG 基线
	_, pops0, _ = evolve_density_iq(t, 0.0, f01, It, tt -> 0.0*tt, T; dt=0.02)
	leak0 = maximum(pops0[:, 3]); leak1 = maximum(pops[:, 3])
	amp_s = string(round(amp, digits=3)); sigma_s = string(round(sigma, digits=1))
	beta_s = string(round(beta, digits=2)); leak0_s = string(round(100leak0, digits=1))
	leak1_s = string(round(100leak1, digits=1)); bmin_s = string(round(bmin, digits=2))
end

# ╔═╡d0000000-0000-4000-8000-000000000009
@htl("""
<div style="display:flex;gap:12px;flex-wrap:wrap;margin:8px 0">
<div style="flex:1;min-width:150px;border:1px solid rgba(76,111,255,0.18);border-radius:12px;padding:10px 16px;background:#FBFBFF">
<div style="font-size:11px;letter-spacing:1px;color:#7B61FF">无 DRAG 泄漏（β=0）</div>
<div style="font-size:19px;font-weight:700;color:#B8812E">$(leak0_s)%</div></div>
<div style="flex:1;min-width:150px;border:1px solid rgba(34,195,166,0.25);border-radius:12px;padding:10px 16px;background:#F3FCFA">
<div style="font-size:11px;letter-spacing:1px;color:#199A87">当前 β=$(beta_s) 的泄漏</div>
<div style="font-size:19px;font-weight:700;color:#199A87">$(leak1_s)%</div></div>
<div style="flex:1;min-width:150px;border:1px solid rgba(76,111,255,0.18);border-radius:12px;padding:10px 16px;background:#FBFBFF">
<div style="font-size:11px;letter-spacing:1px;color:#7B61FF">β 扫描最小点（数值标定）</div>
<div style="font-size:19px;font-weight:700;color:#4C6FFF">β* ≈ $(bmin_s) ns</div></div>
<div style="flex:1;min-width:150px;border:1px solid rgba(76,111,255,0.18);border-radius:12px;padding:10px 16px;background:#FBFBFF">
<div style="font-size:11px;letter-spacing:1px;color:#7B61FF">一阶理论预告</div>
<div style="font-size:19px;font-weight:700;color:#1A1A2E">|β| ≈ 1/(2|Δ₂|) <span style="font-size:12px;color:#8A90AD">≈ 1.5 ns</span></div></div>
</div>
<div style="font-size:12.5px;color:#8A90AD;margin-top:4px">高阶修正使实际 β* 偏离一阶理论——这正是实验上 β 要靠数值扫描标定的原因（本页的扫描就是真实标定流程）。</div>
""")

# ╔═╡d0000000-0000-4000-8000-00000000000a
begin
	tt = range(0, T; length=400)
	It_c(tt) = amp * exp(-((tt - t0) / sigma)^2)
	Qt_c(tt) = -beta * It_c(tt) * (-2 * (tt - t0) / sigma^2)
	trI = PlotlyBase.GenericTrace[]
	push!(trI, PlotlyBase.scatter(x=collect(tt), y=It_c.(tt); mode="lines", name="I（同相）",
		line=attr(color=PAL[1], width=2.5)))
	push!(trI, PlotlyBase.scatter(x=collect(tt), y=Qt_c.(tt) .* 10; mode="lines", name="Q（正交，×10 显示）",
		line=attr(color="#F5A623", width=2.5)))
	piq = PlotlyBase.Plot(trI,
		layout_base(height=340, title="I/Q 驱动波形（Q ∝ −β·dI/dt）",
			xtitle="时间 (ns)", ytitle="幅度 (GHz)"))
	plotly_html("oq_drag_iq", piq; height=350)
end

# ╔═╡d0000000-0000-4000-8000-00000000000b
begin
	tr = PlotlyBase.GenericTrace[]
	push!(tr, PlotlyBase.scatter(x=betas, y=leaks .* 100; mode="lines+markers",
		line=attr(color=PAL[2], width=2.5), marker=attr(size=6), name="泄漏 max|2⟩"))
	push!(tr, PlotlyBase.scatter(x=[bmin], y=[leaks[argmin(leaks)] * 100]; mode="markers",
		marker=attr(size=12, color="#F5A623", line=attr(color="white", width=2)), name="最小点"))
	push!(tr, PlotlyBase.scatter(x=[0], y=[leak0 * 100]; mode="markers",
		marker=attr(size=10, color="#B8812E", symbol="x"), name="β=0（无 DRAG）"))
	pbeta = PlotlyBase.Plot(tr,
		layout_base(height=460, title="β 扫描：泄漏最小值 = DRAG 标定点（amp=$(amp) GHz, σ=$(sigma) ns）",
			xtitle="DRAG 系数 β (ns)", ytitle="max |2⟩ 布居 (%)", annotations=Any[
				attr(x=bmin, y=leaks[argmin(leaks)] * 100 + 1.2, text="标定点 β*≈$(bmin_s)",
					showarrow=false, font=attr(size=12, color="#B8812E"))]))
	plotly_html("oq_drag_beta", pbeta; height=470)
end

# ╔═╡d0000000-0000-4000-8000-00000000000c
begin
	tr = PlotlyBase.GenericTrace[]
	for (k, nm) in enumerate(["|0⟩", "|1⟩", "|2⟩"])
		push!(tr, PlotlyBase.scatter(x=ts, y=pops[:, k]; mode="lines",
			line=attr(color=PAL[k], width=2.5), name=nm))
	end
	ppop = PlotlyBase.Plot(tr,
		layout_base(height=340, title="当前 β 下的布居（β=0 时青色 |2⟩ 会显著隆起）",
			xtitle="时间 (ns)", ytitle="布居", yrange=[0, 1]))
	plotly_html("oq_drag_pops", ppop; height=350)
end

# ╔═╡d0000000-0000-4000-8000-00000000000d
derivation("⑥ 推导溯源：DRAG 的一阶抵消",
[
("近似", texblock(raw"\text{RWA: } \omega_d = \omega_{01} \ \Rightarrow\ H_{\mathrm{eff}} = H_{0\leftrightarrow 1} + H_{1\leftrightarrow 2}\ \text{（失谐 } \Delta_2 = \alpha\text{）}"), "3 能级截断：两能级门 + 一个「只差 $(tex(raw"\alpha"))」的泄漏通道——单比特门页面的泄漏问题。"),
("定义", texblock(raw"\Omega(t)\,e^{-i\omega_d t}, \qquad \Omega(t) = I(t) + i\,Q(t)"), "$(tex(raw"I"))：高斯主脉冲；$(tex(raw"Q"))：待定的正交分量。IQ 两路就是实验上任意波形发生器的两个通道。"),
("微扰", texblock(raw"\dot a_2 \approx -i\,\frac{V_{12}}{2}\,\Omega(t)\,e^{-i\Delta_2 t}"), "把 $(tex(raw"\Omega")) 换成 $(tex(raw"I+iQ"))，泄漏由 I 与 Q 各贡献一份。Q 的贡献带 $(tex(raw"i")) 因子（相位差 90°）——这给了「反相抵消」的入口。"),
("整理", texblock(raw"Q(t) = -\beta\,\frac{dI}{dt} \ \Rightarrow\ \dot a_2 \propto \frac{V_{12}}{2}\,e^{-i\Delta_2 t}\Big[I(t) + i\beta\,\dot I(t)\Big]"), "正交分量以 90° 相位差进入，恰好能抵消 I 引起的泄漏增长（类似阻尼的相位关系）。对 β 求极小即可。"),
("近似", texblock(raw"\beta \approx \frac{1}{2|\Delta_2|} = \frac{1}{2|\alpha|}"), "高阶修正与脉冲形状让实际 $(tex(raw"\beta^{*}")) 偏大 → 数值扫描标定（本页 β 扫描就是标准流程：粗扫找最小 → 精调）。"),
];
lead="从单比特门页面的「|2⟩ 泄漏」问题出发，到本页 β 扫描的标定点。",
result="当前参数下：无 DRAG 泄漏 $(leak0_s)% → 标定点 β*=$(bmin_s) ns 附近最小。把 amp 拖大、σ 拖小（门更快），最小值会右移且变浅——泄漏压制的代价。")

# ╔═╡d0000000-0000-4000-8000-00000000000e
tryout([
("复现标定流程", "amp=0.25、σ=6 固定，看 β 扫描图的最小点；把 σ 拖到 4（门更快）再看。",
 "门更快 → 无 DRAG 泄漏更高、最小值右移变浅——「快与准」的权衡直接写在图上。"),
("验证泄漏 ∝ amp²", "β=0 固定，amp 从 0.05 拖到 0.35，记录无 DRAG 泄漏卡。",
 "泄漏大致按 amp² 增长（微扰公式 p₂ ≈ (amp·V₁₂/Δ₂)²）——这就是为什么 DRAG 在高保真门时代必不可少。"),
("找到你的最优 β", "把 amp、σ 调到你想做的门参数，读 β 扫描最小点的 β*，把 β 滑杆设为 β*。",
 "布居图里青色 |2⟩ 隆起被压平，|0⟩/|1⟩ 振荡更干净——这就是「校准过的 DRAG 门」。"),
])

# ╔═╡d0000000-0000-4000-8000-00000000000f
@htl("""
<div style="font-size:14.5px;color:#33384D;line-height:2.0;margin-top:6px">
<p><b>DRAG 之后呢？</b>一阶 DRAG 压住主要泄漏，更高保真度还有二阶 DRAG（加 ∝ İ̈ 的分量）、导数去除（derivative removal）等变体——思路一脉相承：用已知的物理结构设计控制波形。</p>
<p><b>下一步：</b><b>两比特门</b>（耦合 transmon 与条件相位，backlog）做完后，单比特门 + DRAG + 两比特门 + 色散读取就凑齐了一台量子处理器的全部基本操作。</p>
</div>
""")

# ╔═╡Cell order:
# ╠═d0000000-0000-4000-8000-000000000001
# ╠═d0000000-0000-4000-8000-000000000002
# ╠═d0000000-0000-4000-8000-000000000003
# ╠═d0000000-0000-4000-8000-000000000002
# ╠═d0000000-0000-4000-8000-000000000004
# ╠═d0000000-0000-4000-8000-000000000005
# ╠═d0000000-0000-4000-8000-000000000006
# ╠═d0000000-0000-4000-8000-000000000007
# ╠═d0000000-0000-4000-8000-000000000008
# ╠═d0000000-0000-4000-8000-000000000009
# ╠═d0000000-0000-4000-8000-00000000000a
# ╠═d0000000-0000-4000-8000-00000000000b
# ╠═d0000000-0000-4000-8000-00000000000c
# ╠═d0000000-0000-4000-8000-00000000000d
# ╠═d0000000-0000-4000-8000-00000000000e
# ╠═d0000000-0000-4000-8000-00000000000f
# ╠═d0000000-0000-4000-8000-000000000002
# ╠═d0000000-0000-4000-8000-000000000003
# ╟─d0000000-0000-4000-8000-000000000004
# ╟─d0000000-0000-4000-8000-000000000005
# ╟─d0000000-0000-4000-8000-000000000006
# ╟─d0000000-0000-4000-8000-000000000007
# ╟─d0000000-0000-4000-8000-000000000008
# ╠═d0000000-0000-4000-8000-000000000009
# ╟─d0000000-0000-4000-8000-00000000000a
# ╟─d0000000-0000-4000-8000-00000000000b
# ╟─d0000000-0000-4000-8000-00000000000c
# ╠═d0000000-0000-4000-8000-00000000000d
# ╠═d0000000-0000-4000-8000-00000000000e
# ╠═d0000000-0000-4000-8000-00000000000f