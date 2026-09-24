### A Pluto.jl notebook ###
# v0.20.10

using Markdown

# ╔═╡ a0000000-0000-4000-8000-000000000001
begin
	using PlutoUI, PlotlyBase, Statistics, HypertextLiteral
	include(joinpath(@__DIR__, "..", "src", "OverQubit.jl"))
	include(joinpath(@__DIR__, "..", "src", "OverQubitViz.jl"))
	using .OverQubit, .OverQubitViz
end

# ╔═╡ a0000000-0000-4000-8000-000000000002
@htl("""
<div style="background:linear-gradient(100deg,#EEF1FF 0%,#F6F2FF 60%,#EFFBF8 100%);border-radius:14px;padding:20px 26px;margin:2px 0 10px 0">
<div style="font-size:12px;letter-spacing:2px;color:#7B61FF;font-weight:600">OVERQUBIT · 单比特门</div>
<div style="font-size:24px;font-weight:700;color:#1A1A2E;margin-top:4px">驱动、Rabi 振荡与脉冲面积</div>
<div style="color:#5A6182;margin-top:8px;font-size:14px">给 transmon 加一束微波驱动，看 Bloch 球上的状态如何被「推」着转——门，就是控制这个旋转</div>
</div>
""")

# ╔═╡ a0000000-0000-4000-8000-000000000003
concept_cards([
("驱动怎么耦合 qubit", "电压驱动 V<sub>d</sub>cos(ω<sub>d</sub>t) 施加在栅极上 → H<sub>d</sub> = 2eV<sub>d</sub>cos(ω<sub>d</sub>t)·n̂。n̂ 的跃迁矩阵元 ⟨0|n̂|1⟩ ≈ 1-2 才是「旋钮的刻度」。"),
("旋转坐标系", "站在以 ω<sub>d</sub> 转动的参考系里看量子态：不动的部分是「有效场」，快速转圈的部分会被平均掉——这就是 RWA 的几何图像。"),
("脉冲面积定理", "共振驱动下态矢绕有效场转过的角度 = θ = n01·∫Ω(t)dt。θ=π 就是 X 门。实验上「调门」调的就是这个面积。"),
])

# ╔═╡ a0000000-0000-4000-8000-000000000004
md"### ③ 调参（驱动频率默认锁定 f01，失谐为 0）"

# ╔═╡ a0000000-0000-4000-8000-000000000005
@bind EJ Slider(5:0.5:50; default=20)

# ╔═╡ a0000000-0000-4000-8000-000000000006
@bind EC Slider(0.05:0.01:0.5; default=0.30)

# ╔═╡ a0000000-0000-4000-8000-000000000007
@bind detune Slider(-0.5:0.01:0.5; default=0.0)

# ╔═╡ a0000000-0000-4000-8000-000000000008
@bind amp Slider(0.0:0.005:0.15; default=0.05)

# ╔═╡ a0000000-0000-4000-8000-000000000009
@bind sigma Slider(2:0.5:25; default=10)

# ╔═╡ a0000000-0000-4000-8000-00000000000a
@bind Tns Slider(20:5:100; default=60)

# ╔═╡ a0000000-0000-4000-8000-00000000000b
@bind cmp2 CheckBox(default=false)

# ╔═╡ a0000000-0000-4000-8000-00000000000c
begin
	t = Transmon(EJ, EC; ncut=60)
	f01, f12 = f01_f12(t, 0.0)
	α_ = f12 - f01
	n01 = abs(charge_matrix_element(t, 0, 1))
	n12 = abs(charge_matrix_element(t, 1, 2))
	ωd = f01 + detune
	ts, pops, bloch = evolve_density(t, 0.0, ωd, amp, sigma, Tns)
	# 对比曲线：双倍幅度
	_, pops2, bloch2 = cmp2 ? evolve_density(t, 0.0, ωd, 2amp, sigma, Tns) : (ts, nothing, nothing)
	# Rabi 频率（实测 vs 理论）与脉冲面积
	cross = Float64[]
	for i in 2:size(pops, 1)
		if pops[i - 1, 2] < 0.5 <= pops[i, 2]
			f = (0.5 - pops[i - 1, 2]) / (pops[i, 2] - pops[i - 1, 2])
			push!(cross, ts[i - 1] + f * (ts[i] - ts[i - 1]))
			length(cross) >= 5 && break
		end
	end
	rabi = length(cross) >= 2 ? 1 / ((cross[end] - cross[1]) / (length(cross) - 1)) : NaN
	rabi_th = amp * n01
	area = n01 * amp * sigma * sqrt(π)
	leak = maximum(pops[:, 3])
	f01_s = string(round(f01, digits=3)); alpha_s = string(round(α_, digits=3))
	rabi_s = isnan(rabi) ? "—" : string(round(rabi, digits=3))
	rabi_th_s = string(round(rabi_th, digits=3))
	area_s = string(round(area, digits=3)); leak_s = string(round(100leak, digits=2))
	# 动画帧：Bloch 状态点沿轨迹推进（索引 0 为动画标记）
	nfr = 60
	fidx = round.(Int, range(1, size(bloch, 1); length=nfr))
	frames = PlotlyBase.PlotlyFrame[]
	for (k, i) in enumerate(fidx)
		push!(frames, frame(name=string(k), data=[
			PlotlyBase.scatter3d(x=[bloch[i, 1]], y=[bloch[i, 2]], z=[bloch[i, 3]]; mode="markers",
				marker=attr(size=9, color="#FF7A7A", line=attr(color="white", width=2)),
				showlegend=false, hoverinfo="skip"),
		]))
	end
end

# ╔═╡ a0000000-0000-4000-8000-00000000000d
@htl("""
<div style="display:flex;gap:12px;flex-wrap:wrap;margin:8px 0">
<div style="flex:1;min-width:150px;border:1px solid rgba(76,111,255,0.18);border-radius:12px;padding:10px 16px;background:#FBFBFF">
<div style="font-size:11px;letter-spacing:1px;color:#7B61FF">f01 / α</div>
<div style="font-size:19px;font-weight:700;color:#1A1A2E">$(f01_s) <span style="font-size:12px;color:#8A90AD">GHz / $(alpha_s) GHz</span></div></div>
<div style="flex:1;min-width:150px;border:1px solid rgba(76,111,255,0.18);border-radius:12px;padding:10px 16px;background:#FBFBFF">
<div style="font-size:11px;letter-spacing:1px;color:#7B61FF">RABI 频率（实测 / 理论）</div>
<div style="font-size:19px;font-weight:700;color:#4C6FFF">$(rabi_s) / $(rabi_th_s) <span style="font-size:12px;color:#8A90AD">GHz</span></div></div>
<div style="flex:1;min-width:150px;border:1px solid rgba(76,111,255,0.18);border-radius:12px;padding:10px 16px;background:#FBFBFF">
<div style="font-size:11px;letter-spacing:1px;color:#7B61FF">脉冲面积 θ = n01·∫Ω dt</div>
<div style="font-size:19px;font-weight:700;color:#7B61FF">$(area_s) <span style="font-size:12px;color:#8A90AD">rad（π≈3.14 即门）</span></div></div>
<div style="flex:1;min-width:150px;border:1px solid rgba(245,166,35,0.25);border-radius:12px;padding:10px 16px;background:#FFFBF3">
<div style="font-size:11px;letter-spacing:1px;color:#B8812E">|2⟩ 泄漏（Δ₂ ≈ α）</div>
<div style="font-size:19px;font-weight:700;color:#B8812E">$(leak_s)%</div></div>
</div>
<label style="font-size:13px;color:#5A6182;cursor:pointer">□ 对比模式：叠加双倍幅度（虚线轨迹 / 淡色布居）——把 $(cmp2 ? "勾" : "框")上试试</label>
""")

# ╔═╡ a0000000-0000-4000-8000-00000000000e
begin
	# Bloch 球：线框 + 轴 + 全轨迹 + 对比轨迹 + 动画标记
	lons = collect(0:30:330); ths = deg2rad.(collect(-75:15:75))
	tr = PlotlyBase.GenericTrace[]
	for lat in [-60, -30, 0, 30, 60]
		φ = deg2rad(lat); r = cos(φ); z = fill(sin(φ), length(lons))
		push!(tr, PlotlyBase.scatter3d(x=r .* cosd.(lons), y=r .* sind.(lons), z=z; mode="lines",
			line=attr(color="rgba(20,24,60,0.10)", width=1), showlegend=false, hoverinfo="skip"))
	end
	for lon in lons
		push!(tr, PlotlyBase.scatter3d(x=cos.(ths) .* cosd(lon), y=cos.(ths) .* sind(lon), z=sin.(ths);
			mode="lines", line=attr(color="rgba(20,24,60,0.10)", width=1), showlegend=false, hoverinfo="skip"))
	end
	push!(tr, PlotlyBase.scatter3d(x=[-1.15, 1.15], y=[0, 0], z=[0, 0]; mode="lines",
		line=attr(color="rgba(255,107,107,0.55)", width=2), showlegend=false, hoverinfo="skip"))
	push!(tr, PlotlyBase.scatter3d(x=[0, 0], y=[-1.15, 1.15], z=[0, 0]; mode="lines",
		line=attr(color="rgba(76,111,255,0.55)", width=2), showlegend=false, hoverinfo="skip"))
	push!(tr, PlotlyBase.scatter3d(x=[0, 0], y=[0, 0], z=[-1.25, 1.25]; mode="lines",
		line=attr(color="rgba(34,195,166,0.7)", width=3), showlegend=false, hoverinfo="skip"))
	ann = [
		attr(x=0, y=0, z=1.32, text="|0⟩", showarrow=false, font=attr(size=14, color="#22C3A6")),
		attr(x=0, y=0, z=-1.42, text="|1⟩", showarrow=false, font=attr(size=14, color="#22C3A6")),
		attr(x=1.24, y=0, z=0, text="+x", showarrow=false, font=attr(size=11, color="#FF6B6B")),
		attr(x=0, y=1.24, z=0, text="+y", showarrow=false, font=attr(size=11, color="#4C6FFF")),
	]
	step = max(1, div(size(bloch, 1), 400))
	if cmp2
		push!(tr, PlotlyBase.scatter3d(x=bloch2[1:step:end, 1], y=bloch2[1:step:end, 2], z=bloch2[1:step:end, 3];
			mode="lines", line=attr(color="rgba(123,97,255,0.35)", width=4), name="2×幅度轨迹"))
	end
	push!(tr, PlotlyBase.scatter3d(x=bloch[1:step:end, 1], y=bloch[1:step:end, 2], z=bloch[1:step:end, 3];
		mode="lines", line=attr(color="#4C6FFF", width=5), name="状态轨迹"))
	push!(tr, PlotlyBase.scatter3d(x=[bloch[1, 1]], y=[bloch[1, 2]], z=[bloch[1, 3]];
		mode="markers", marker=attr(size=7, color="#22C3A6"), name="起始 |0⟩"))
	push!(tr, PlotlyBase.scatter3d(x=[bloch[end, 1]], y=[bloch[end, 2]], z=[bloch[end, 3]];
		mode="markers", marker=attr(size=7, color="#7B61FF"), name="终止态"))
	push!(tr, PlotlyBase.scatter3d(x=[bloch[1, 1]], y=[bloch[1, 2]], z=[bloch[1, 3]]; mode="markers",
		marker=attr(size=9, color="#FF7A7A", line=attr(color="white", width=2)), showlegend=false))
	pbloch = PlotlyBase.Plot(tr,
		Layout(title=attr(text="Bloch 球上的状态轨迹（点播放看红点推进）", font=attr(size=16, color=INK)),
			scene=attr(aspectmode="cube", xaxis=attr(visible=false), yaxis=attr(visible=false),
				zaxis=attr(visible=false), annotations=ann,
				camera=attr(eye=attr(x=1.5, y=1.5, z=1.1))),
			font=attr(family=FONT), paper_bgcolor="white",
			margin=attr(l=10, r=10, t=52, b=10), height=620, updatemenus=animation_menu(),
			legend=attr(orientation="h", y=1.06, x=0, bgcolor="rgba(0,0,0,0)", font=attr(size=11, color=SUB))),
		frames)
	plotly_html("oq_bloch", pbloch; height=630)
end

# ╔═╡ a0000000-0000-4000-8000-00000000000f
begin
	env = drive_envelope(ts, amp, sigma)
	penv = PlotlyBase.Plot([PlotlyBase.scatter(x=ts, y=env; mode="lines", fill="tozeroy",
		line=attr(color="#7B61FF", width=2), fillcolor="rgba(123,97,255,0.15)", name="驱动包络 Ω(t)")],
		layout_base(height=280, title="驱动脉冲包络（高斯）", xtitle="时间 (ns)", ytitle="Ω (GHz)",
			legend_y=1.2, margin_t=44, margin_b=44))
	tr2 = PlotlyBase.GenericTrace[]
	if cmp2
		for k in 1:3
			push!(tr2, PlotlyBase.scatter(x=ts, y=pops2[:, k]; mode="lines",
				line=attr(color=PAL[k], width=1.5, dash="dot"), showlegend=false))
		end
	end
	for (k, nm) in enumerate(["|0⟩", "|1⟩", "|2⟩"])
		push!(tr2, PlotlyBase.scatter(x=ts, y=pops[:, k]; mode="lines",
			line=attr(color=PAL[k], width=2.5), name=nm))
	end
	ppop = PlotlyBase.Plot(tr2,
		layout_base(height=300, title="能级布居（虚线=双倍幅度对比）", xtitle="时间 (ns)", ytitle="布居",
			yrange=[0, 1], legend_y=1.2, margin_t=44, margin_b=44))
	plotly_html("oq_penv", penv; height=290), plotly_html("oq_pops", ppop; height=310)
end

# ╔═╡ a0000000-0000-4000-8000-000000000010
derivation("⑤ 推导溯源：从驱动电路到 Rabi 公式",
[
("近似", "两能级投影：|0⟩、|1⟩ 子空间，n̂ → n01·σ<sub>x</sub>（对角项 ~0，奇偶性禁戒）", "前提 |α| 足够大；泄漏大小由推导末步的微扰估计给出，读数卡实时验证。"),
("代入", "H = (ω01/2)σ<sub>z</sub> + Ω(t)cos(ω<sub>d</sub>t)·n01·σ<sub>x</sub>，Ω(t) = amp·exp(−((t−t0)/σ)²)", "栅极电压驱动 2eV<sub>d</sub>cos(ω<sub>d</sub>t)·n̂ 投影到两能级。"),
("代入", "旋转坐标系 U = exp(iω<sub>d</sub>t σ<sub>z</sub>/2)：σ<sub>x</sub> → σ<sub>x</sub>cos(ω<sub>d</sub>t) − σ<sub>y</sub>sin(ω<sub>d</sub>t)", "把快转动转进基矢，只剩「有效场」慢变部分 + 快速绕圈部分。"),
("近似", "RWA：2ω<sub>d</sub> 项平均为零<br>→ H<sub>eff</sub> = (δ/2)σ<sub>z</sub> + (Ω<sub>R</sub>/2)σ<sub>x</sub>，Ω<sub>R</sub> = amp·n01，δ = ω<sub>d</sub> − ω<sub>01</sub>", "适用条件 ω<sub>d</sub> ≫ Ω<sub>R</sub>；读数卡的「实测/理论」对照就是这一步的验证。"),
("代入", "Bloch 方程 / SU(2) 指数：<br>P<sub>1</sub>(t) = (Ω<sub>R</sub>²/(Ω<sub>R</sub>²+δ²))·sin²(√(Ω<sub>R</sub>²+δ²)·t/2)", "δ=0 退化为纯 Rabi 振荡 sin²(Ω<sub>R</sub>t/2)；δ≠0 则反转不完全且频率变快。"),
("整理", "脉冲面积 θ = n01·∫Ω(t)dt = n01·amp·σ√π<br>θ = π → X 门（|0⟩↔|1⟩）；θ = π/2 → 叠加态；θ = 2π → 回 |0⟩ 带相位", "调参任务里调的就是 θ。实验上用 Rabi 频率×脉宽定标。"),
("微扰", "泄漏：|1⟩→|2⟩ 由同一驱动经 V12 非共振激发，p<sub>2</sub> ≈ (amp·V12/Δ₂)²，Δ₂ = f12 − ω<sub>d</sub> ≈ α", "这解释了为什么强驱动必然泄漏（Δ₂ 只有 ~|α|）——正是 DRAG 脉冲要压掉的项。"),
];
lead="每一步都可点开。点击播放 Bloch 动画时对照第 5 步：红点轨迹就是 sin² 振荡在球面上的投影。",
result="对照读数卡：实测 Rabi $(rabi_s) GHz vs 理论 amp·n01 = $(rabi_th_s) GHz；当前 θ = $(area_s)，泄漏 $(leak_s)%。")

# ╔═╡ a0000000-0000-4000-8000-000000000011
tryout([
("亲手做出一个 X 门", "失谐=0，σ=10 ns 固定，拖 amp 到读数卡 θ≈3.14（约 amp≈0.085）。",
 "p1 曲线在脉冲结束时到达 ~1，Bloch 轨迹终止于 |1⟩ 附近（紫点贴南半球）。θ 再大，p1 回落——2π 脉冲。"),
("失谐为什么毁掉门", "θ 调到 π 后，拖「失谐」到 0.1 GHz。",
 "p1 最大值跌到 ~0.9 以下（公式里的 Ω<sub>R</sub>²/(Ω<sub>R</sub>²+δ²) 因子），且振荡变快（√(Ω<sub>R</sub>²+δ²)）——实测/理论卡的频率也开始对不上（那是共振公式）。"),
("亲手制造泄漏（DRAG 的动机）", "勾上「对比模式」（双倍幅度），amp=0.10，看 |2⟩ 曲线（青色）。",
 "双倍幅度的虚线 |2⟩ 明显更高——p<sub>2</sub> ∝ amp²。这就是为什么 π 门不能无限快：加速就要付出泄漏，DRAG 用正交微分分量把泄漏压回去（下一个演示的主题）。"),
])

# ╔═╡ a0000000-0000-4000-8000-000000000012
@htl("""
<div style="font-size:14.5px;color:#33384D;line-height:2.0;margin-top:6px">
<p><b>门 = 受控的旋转。</b>Bloch 球上 |0⟩→|1⟩ 是绕 x 轴转 π；相位门（虚拟 Z）则绕 z 轴。所有单比特门都是这两类旋转的组合——脉冲的幅度、时长、相位（I/Q 两路）就是全部旋钮。</p>
<p><b>快与准的权衡。</b>π 门越快（amp 越大）对 T1 越鲁棒，但 |2⟩ 泄漏 ∝ amp²（推导末步）。真实器件的门时间被这个权衡卡在几十 ns 量级。</p>
<p><b>下一步：</b><b>DRAG</b> 演示怎么用一条正交微分曲线压掉泄漏；<b>色散读取</b>演示门做完之后怎么读出结果。</p>
</div>
""")

# ╔═╡ Cell order:
# ╟─a0000000-0000-4000-8000-000000000001
# ╠═a0000000-0000-4000-8000-000000000002
# ╠═a0000000-0000-4000-8000-000000000003
# ╟─a0000000-0000-4000-8000-000000000004
# ╟─a0000000-0000-4000-8000-000000000005
# ╟─a0000000-0000-4000-8000-000000000006
# ╟─a0000000-0000-4000-8000-000000000007
# ╟─a0000000-0000-4000-8000-000000000008
# ╟─a0000000-0000-4000-8000-000000000009
# ╟─a0000000-0000-4000-8000-00000000000a
# ╟─a0000000-0000-4000-8000-00000000000b
# ╟─a0000000-0000-4000-8000-00000000000c
# ╠═a0000000-0000-4000-8000-00000000000d
# ╟─a0000000-0000-4000-8000-00000000000e
# ╟─a0000000-0000-4000-8000-00000000000f
# ╠═a0000000-0000-4000-8000-000000000010
# ╠═a0000000-0000-4000-8000-000000000011
# ╠═a0000000-0000-4000-8000-000000000012
