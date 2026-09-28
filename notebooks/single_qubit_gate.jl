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

# ╔═╡ a0000000-0000-4000-8000-000000000001
begin
	using PlutoUI, PlotlyBase, Statistics, HypertextLiteral
	include(joinpath(@__DIR__, "..", "src", "OverQubit.jl"))
	using .OverQubit
	setup_page()
end

# ╔═╡ a0000000-0000-4000-8000-000000001001
lesson_nav([
	("①", "transmon 能级与量子化", "done"),
	("②", "单比特门与 Rabi", "current"),
	("③", "DRAG 泄漏压制", "todo"),
	("④", "色散读取 S21", "todo"),
	("⑤", "两比特耦合与 iSWAP", "todo"),
	("⑥", "磁通调谐与能级扇形图", "todo"),
	("⑦", "T1 / T2 / Ramsey", "todo"),
])

# ╔═╡ a0000000-0000-4000-8000-000000000002
@htl("""
<div style="background:linear-gradient(100deg,#EEF1FF 0%,#F6F2FF 60%,#EFFBF8 100%);border-radius:14px;padding:20px 26px;margin:2px 0 10px 0">
<div style="font-size:12px;letter-spacing:2px;color:#7B61FF;font-weight:600">OVERQUBIT · 单比特门</div>
<div style="font-size:24px;font-weight:700;color:#1A1A2E;margin-top:4px">驱动、Rabi 振荡与脉冲面积</div>
<div style="color:#5A6182;margin-top:8px;font-size:14px">给 transmon 加一束微波驱动，看 Bloch 球上的状态如何被「推」着转——门，就是控制这个旋转</div>
<div style="margin-top:12px;font-size:13.5px;color:#33384D;line-height:1.9;max-width:78ch">
<b>读完这页你能：</b>①说清微波驱动是<b>怎么</b>变成作用在 qubit 上的力的（不是「施加一个电场」这么简单）；
②徒手把一个 X 门调出来，并解释为什么是 <b>π</b> 而不是别的数；
③说出「门不能无限快」的<b>定量</b>原因（泄漏 ∝ amp²），而不是「有噪声」这种含糊答案。
</div>
</div>
""")

# ╔═╡ a0000000-0000-4000-8000-000000000003
oq_stack(
callout("量子门不是魔法，它就是<b>受控的转动</b>：一个被我们精确控制方向与角度的旋转。
这一页从「驱动怎么作用上去」讲到「转多少角度」再到「为什么转快了会失控」，
三件事串成一条线——每一步都能在下方的图和读数卡上找到对应的证据。
建议的读法：先看四张概念卡建立图像 → 拖滑块做实验 → 再回头看推导链（那里解释每一步<b>为什么</b>成立）。",
	tone="info", title="① 这一页讲什么：把「门」拆成一次受控旋转"),
concept_cards([
("驱动怎么耦合 qubit", "栅极上加一束微波 V<sub>d</sub>cos(ω<sub>d</sub>t)，通过电容耦合到岛上的库珀对，哈密顿量里就多出一项 H<sub>d</sub> = 2eV<sub>d</sub>cos(ω<sub>d</sub>t)·n̂。<br><br>真正决定「推力」的不是电压本身，而是电荷算符 n̂ 在两个能级之间的<b>跃迁矩阵元</b> ⟨0|n̂|1⟩ ≈ n<sub>01</sub>——它就是旋钮的刻度。transmon 的 n<sub>01</sub> ≈ 1–2，这正是我们能用普通幅度做门的原因；若是 CPB（E<sub>J</sub>/E<sub>C</sub> ≲ 1），n<sub>01</sub> 会小得多，同样电压几乎推不动。"),
("旋转坐标系与 RWA", "换个视角：站在跟着 ω<sub>d</sub> 一起转动的参考系里，qubit 的态几乎不动，而驱动场被拆成两半——一半是<b>不动的横向有效场</b>，一半是以 2ω<sub>d</sub> 高速绕圈的碎屑。<br><br>后者在几个周期内平均归零（这就是 RWA 的全部内容）。于是「随时间驱动」的复杂问题退化成「绕一根固定轴匀速转」的静态问题——Bloch 球上那个旋转就是这么来的。"),
("脉冲面积定理", "共振时，态矢量转过的角度只取决于包络的<b>面积</b>：$(tex(raw"\theta = n_{01}\!\int\!\Omega(t)\,dt"))，与包络是高斯、方波还是三角形无关。<br><br>θ=π 是 X 门（|0⟩↔|1⟩），θ=π/2 是 50/50 分束（做出叠加态），θ=2π 绕回原点但带一个相位。实验上「调门」调的就是这个面积——本页读数卡里的 θ 正是你拖 amp 时在改的东西。"),
("快与准的权衡", "想门快就调大 amp，但 transmon 不是完美的两能级：|1⟩ 与 |2⟩ 只差一个非谐性 α（约 −0.3 GHz），强驱动会顺手把人口踢上去，泄漏按 $(tex(raw"p_2\propto amp^2")) 增长。<br><br>所以 π 门被卡在几十 ns 量级——再快就要付泄漏的代价。DRAG 用一条正交微分曲线把泄漏压回去，是下一页的主题。"),
]))

# ╔═╡ a0000000-0000-4000-8000-000000000004
oq_stack(
section_header("③", "调参（驱动频率默认锁定 f01，失谐为 0）"),
callout("三个滑块对应三个旋钮：<b>amp</b> 是驱动幅度（GHz，决定转速与脉冲面积）、<b>σ</b> 是高斯包络宽度（ns，决定门时长）、<b>detune</b> 是驱动频率相对 f<sub>01</sub> 的偏移（GHz，看失谐怎么毁掉门）。<br><br><b>建议动的顺序</b>：先把 detune 归零、σ 固定 10 ns，只拖 amp 做出一个 π 门——这样「面积」这一个效应不会和别的混在一起；调好后再动 detune，观察幅度因子掉下来；最后勾上「对比模式」看泄漏。EJ/EC 两个滑块是换器件（改 f<sub>01</sub> 与非谐性），不是门参数，最后再动。",
	tone="tip", title="调参前先看这里：先动哪个、为什么"),
)

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
	# 动画帧参数（帧本身在下方画 Bloch 球的 cell 里构造——那里才知道小球 trace 的索引）
	nfr = 60
	fidx = round.(Int, range(1, size(bloch, 1); length=nfr))
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
	BALL = length(tr) - 1              # 红点动画标记是最后一条 trace（0 基索引）
	# 动画帧：Bloch 状态点沿轨迹推进——只更新 BALL 那条 trace
	frames = PlotlyBase.PlotlyFrame[]
	for (k, i) in enumerate(fidx)
		push!(frames, anim_frame(BALL, string(k), PlotlyBase.scatter3d(x=[bloch[i, 1]], y=[bloch[i, 2]],
			z=[bloch[i, 3]]; mode="markers", marker=attr(size=9, color="#FF7A7A",
			line=attr(color="white", width=2)), showlegend=false, hoverinfo="skip")))
	end
	pbloch = PlotlyBase.Plot(tr,
		Layout(title=attr(text="Bloch 球上的状态轨迹（点播放看红点推进）", font=attr(size=16, color=INK)),
			scene=attr(aspectmode="cube", xaxis=attr(visible=false), yaxis=attr(visible=false),
				zaxis=attr(visible=false), annotations=ann,
				camera=attr(eye=attr(x=1.5, y=1.5, z=1.1))),
			font=attr(family=FONT), paper_bgcolor="white",
			margin=attr(l=10, r=10, t=52, b=10), height=620, updatemenus=animation_menu(),
			legend=attr(orientation="h", y=1.06, x=0, bgcolor="rgba(0,0,0,0)", font=attr(size=11, color=SUB))),
		frames)
	oq_stack(plotly_html("oq_bloch", pbloch; height=630),
		figure_note("看图要诀：① 红点是当前态、紫点是终点——θ=π 时它贴到南半球（|1⟩）；② 轨迹绕的是「有效场」轴，失谐时这根轴会向 z 歪斜（反转因此不完全）；③ 点播放对照推导第 5 步：红点在球面上的摆动就是 $(tex(raw"\sin^2")) 振荡的投影。"))
end

# ╔═╡ a0000000-0000-4000-8000-00000000000f
begin
	env = drive_envelope(ts, amp, sigma)
	penv = PlotlyBase.Plot([PlotlyBase.scatter(x=ts, y=env; mode="lines", fill="tozeroy",
		line=attr(color="#7B61FF", width=2), fillcolor="rgba(123,97,255,0.15)", name="驱动包络 Ω(t)")],
		layout_base(height=280, title="驱动脉冲包络（高斯）", xtitle="时间 (ns)", ytitle="Ω (GHz)"))
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
			yrange=[0, 1]))
	oq_stack(plotly_html("oq_penv", penv; height=290), plotly_html("oq_pops", ppop; height=310),
		figure_note("看图要诀：① 上图是包络——面积 $(tex(raw"\theta = n_{01}\cdot amp\cdot\sigma\sqrt{\pi}")) 才是门的度量，形状只影响泄漏；② 下图蓝/绿互补（$(tex(raw"p_0+p_1=1"))，能量守恒），青色 |2⟩ 是代价项；③ 勾「对比模式」看虚线：幅度翻倍时 |2⟩ 涨约 4 倍——平方律的直接证据。"))
end

# ╔═╡ a0000000-0000-4000-8000-000000000010
oq_stack(
derivation("⑤ 推导溯源：从驱动电路到 Rabi 公式",
[
	("近似", "两能级投影：$(tex(raw"|0\rangle,\ |1\rangle")) 子空间，$(tex(raw"\hat n \;\to\; n_{01}\,\sigma_x"))（对角项 ~0，奇偶性禁戒）", "先把算符限制在 {|0⟩,|1⟩} 里。这一步要求非谐性 $(tex(raw"\alpha")) 足够大——否则 |1⟩ 紧贴 |2⟩，驱动一上来就「漏」过去（末步量化了这件事）。电荷算符在这个子空间里只有非对角元（宇称守恒禁戒对角项），于是 n̂ ≈ n<sub>01</sub>σ<sub>x</sub>：驱动变成一根推着 Bloch 矢量转的<b>横向力</b>。读数卡里的 n<sub>01</sub> 就是这根力的刻度。"),
	("代入", texblock(raw"H = \frac{\omega_{01}}{2}\,\sigma_z \;+\; \Omega(t)\cos(\omega_d t)\,n_{01}\sigma_x, \qquad \Omega(t) = amp\cdot\exp\!\left(-\frac{(t-t_0)^2}{\sigma^2}\right)"), "把上一步塞回哈密顿量：第一项是 qubit 自身的能量，第二项是驱动。注意 $(tex(raw"\Omega(t)")) 是高斯包络，它决定<b>转速随时间怎么变</b>——这就是「脉冲形状」；滑块里的 σ 就是包络宽度，t<sub>0</sub> 是包络中心。实验室里这对应任意波形发生器输出的那一段包络。"),
	("代入", texblock(raw"U = \exp\!\left(i\,\omega_d t\,\frac{\sigma_z}{2}\right): \qquad \sigma_x \to \sigma_x\cos(\omega_d t) - \sigma_y\sin(\omega_d t)"), "乘一个绕 z 轴转 $(tex(raw"\omega_d t")) 的酉变换，把「随时间转」从基矢里拿走。代价是 $(tex(raw"\sigma_x")) 被拆成两项：一项<b>不随时间变</b>（我们想要的有效场），一项以 $(tex(raw"2\omega_d")) 高速旋转（待会儿平均掉的碎屑）。"),
	("近似", texblock(raw"\mathrm{RWA:}\quad \overline{2\omega_d\,\mathrm{term}} = 0 \;\;\Rightarrow\;\; H_{\mathrm{eff}} = \frac{\delta}{2}\sigma_z + \frac{\Omega_R}{2}\sigma_x, \qquad \Omega_R = amp\cdot n_{01}, \quad \delta = \omega_d - \omega_{01}"), "丢掉 $(tex(raw"2\omega_d")) 那项。合法条件是 $(tex(raw"\omega_d \gg \Omega_R"))：在有效场把 Bloch 矢量推过 90° 之前，碎屑已转了几千圈，净效应为零。结果是一个<b>静态</b>哈密顿量——问题从「受迫」变成「绕固定轴匀速转」。读数卡「实测/理论」对照的就是这一步：吻合即 RWA 成立。"),
	("代入", texblock(raw"P_1(t) = \frac{\Omega_R^2}{\Omega_R^2+\delta^2}\;\sin^2\!\left(\sqrt{\Omega_R^2+\delta^2}\cdot\frac{t}{2}\right)"), "解静态哈密顿量的转动，投影到 |1⟩ 就是这个 $(tex(raw"\sin^2"))。两个因子要分开看：<b>幅度因子</b> $(tex(raw"\Omega_R^2/(\Omega_R^2+\delta^2)"))——失谐让反转不完全；<b>频率因子</b> $(tex(raw"\sqrt{\Omega_R^2+\delta^2}"))——失谐让振荡变快。$(tex(raw"\delta=0")) 时两者分别退化为 1 与 $(tex(raw"\Omega_R"))。"),
	("整理", texblock(raw"\theta = n_{01}\!\int\!\Omega(t)\,dt = n_{01}\cdot amp\cdot\sigma\sqrt{\pi} \qquad\Rightarrow\qquad \theta=\pi:\ X\ \mathrm{gate}\ (|0\rangle\leftrightarrow|1\rangle)"), "对高斯包络积分得到面积，这就是<b>脉冲面积定理</b>的定量版。实验上「调门」就是找这个面积：把 amp×σ 调到 $(tex(raw"\theta=\pi"))。注意形状<b>不进</b>这个公式——高斯和方波只要面积相同就转过同样角度（真实器件里这一点不完全成立，因为泄漏依赖形状，见下）。"),
	("微扰", texblock(raw"p_2 \approx \left(\frac{amp\cdot V_{12}}{\Delta_2}\right)^2, \qquad \Delta_2 = f_{12}-\omega_d \approx \alpha"), "最后看三能级的代价：|1⟩→|2⟩ 的耦合是 $(tex(raw"V_{12}"))，失谐只有 $(tex(raw"\Delta_2 \approx \alpha \approx -0.3")) GHz，强驱动下的非共振激发给出上式。分母这么小，就是「$(tex(raw"\pi")) 门不能无限快」的定量原因。"),
	];
lead="这条推导只做一件事：<b>把「微波打上去」翻译成「Bloch 矢量转过一个角度」</b>。
关键的转折在第 3–4 步——换个参考系，再把高频碎屑平均掉，问题就从「随时间受迫」退化成「绕固定轴匀速转」。
第 5 步解这个静态问题，第 6 步把它落成实验上可调的量（脉冲面积），第 7 步给出代价（泄漏）。
建议对照上方的 Bloch 轨迹与 p₁(t) 曲线逐步看：第 5 步的 $(tex(raw"\sin^2")) 就是红点在球面上摆动的投影。",
result="结论回到读数卡：实测 Rabi $(rabi_s) GHz 与理论 amp·n01 = $(rabi_th_s) GHz 吻合 ⇒ RWA 与两能级投影都成立；
当前 $(tex(raw"\theta")) = $(area_s)（拖 amp 或 σ 改面积；拖 detune 看幅度因子掉下来）；泄漏 $(leak_s)% 是三能级的代价，
正是下一页 DRAG 要压掉的量。"),
deep_dive("RWA 到底丢掉了什么？丢掉的项什么时候会咬人？", """
<p>RWA 丢掉的 $(tex(raw"2\omega_d")) 项<b>不是小到没有</b>，而是「振荡得足够快，对布居的净贡献为零」。
它的真实效果是一个很小的 <b>Bloch–Siegert 频移</b>：$(tex(raw"f_{01}")) 会被推高约 $(tex(raw"\Omega_R^2/(4\omega_d)"))。
对本页典型参数（$(tex(raw"\Omega_R \approx 10")) MHz、$(tex(raw"\omega_d \approx 6")) GHz）这个频移约 kHz 量级，
比门误差小得多，所以教学里常忽略；但在超快门（$(tex(raw"\Omega_R")) 与 $(tex(raw"|\alpha|")) 相比）或高精度标定时必须补上。</p>
<p>还有两个隐藏条件：① 包络 $(tex(raw"\Omega(t)")) 的变化要慢于 $(tex(raw"1/\omega_d"))，
本页 $(tex(raw"\sigma \ge 5")) ns 而 $(tex(raw"1/\omega_d \approx 0.17")) ns，安全；
② $(tex(raw"\omega_d \gg \Omega_R"))。第二个条件常被误解成「amp 可以随便加大」——
实际上 amp 大到 $(tex(raw"\Omega_R")) 与 $(tex(raw"\omega_d")) 同量级时，丢掉的项就会有可观测后果。</p>
""", tone="detail"),
deep_dive("常见误解：θ=2π 为什么不等于「什么都没做」？", """
<p>$(tex(raw"\theta = 2\pi")) 时 Bloch 矢量绕回起点，布居看起来和初态一样，
但态矢量拿到了一个 <b>−1 的相位</b>（$(tex(raw"\pi")) 的几何相位）。
对 |0⟩ 单独来说这不重要；可一旦 |0⟩ 和 |1⟩ 处在叠加态，这个<b>相对相位</b>就可观测了。</p>
<p>所以「2π 脉冲」在量子控制里是一个<b>有用的门</b>（相位门），不是白绕一圈。
真实器件的标定里经常故意用 2π 脉冲来测相位——这也是「虚拟 Z 门」思想的起点：
把相位当作软件里的一个数字去记录，而不是用微波去实现。</p>
""", tone="warn"),
)

# ╔═╡ a0000000-0000-4000-8000-000000000011
tryout([
("亲手做出一个 X 门", "<b>动机</b>：门的定义就是「把 |0⟩ 精确翻到 |1⟩」，先把这件事做出来再谈别的。<br><b>做法</b>：失谐=0、σ=10 ns 固定，只拖 amp，直到读数卡的 θ ≈ 3.14（约 amp≈0.085）。",
 "<b>看什么</b>：p₁ 曲线在脉冲结束时到达 ~1，Bloch 轨迹的红点终止在 |1⟩ 附近（南半球）。<br><b>说明什么</b>：$(tex(raw"\theta = n_{01}\cdot amp\cdot\sigma\sqrt{\pi} = \pi"))，面积定理成立。<br><b>如果没看到</b>：先确认 detune 归零，再看 amp 是不是拖过头了——θ>π 时 p₁ 会回落（2π 时完全回到 |0⟩）。"),
("失谐为什么毁掉门", "<b>动机</b>：真实器件的 f<sub>01</sub> 会漂移，驱动频率不可能永远锁在共振，所以「失谐容忍度」是门质量的一部分。<br><b>做法</b>：先把 θ 调到 π，再把 detune 拖到 0.1 GHz（其它不动）。",
 "<b>看什么</b>：p₁ 的峰值跌到 0.9 以下，同时振荡变快。<br><b>说明什么</b>：峰值由<b>幅度因子</b> $(tex(raw"\Omega_R^2/(\Omega_R^2+\delta^2)")) 决定，频率由<b>广义 Rabi 频率</b> $(tex(raw"\sqrt{\Omega_R^2+\delta^2}")) 决定——两个效应同时出现才是失谐的指纹（单纯噪声通常只改幅度）。<br><b>注意</b>：读数卡的「实测/理论」会开始对不上，因为那里的理论式是共振情形。"),
("亲手制造泄漏（DRAG 的动机）", "<b>动机</b>：把「π 门不能无限快」从口号变成看得见的曲线。<br><b>做法</b>：勾上「对比模式」（双倍幅度），amp=0.10，盯住青色 |2⟩ 曲线。",
 "<b>看什么</b>：双倍幅度的虚线 |2⟩ 明显更高。<br><b>说明什么</b>：$(tex(raw"p_2 \propto amp^2"))——驱动经非共振耦合 V<sub>12</sub> 把人口踢到 |2⟩，而失谐只有 $(tex(raw"\Delta_2 \approx |\alpha| \approx 0.3")) GHz。<br><b>对照</b>：把 amp 减半，看 |2⟩ 峰值降到约 1/4（平方律）。这一条曲线就是下一页 DRAG 的出发点。"),
])

# ╔═╡ a0000000-0000-4000-8000-000000011002
quiz([
	("共振驱动下要把 |0⟩ 翻成 |1⟩（X 门），脉冲面积 θ 应取多少？",
	 ["π/2", "π", "2π", "π/4"], 2,
	 "θ = n01·∫Ω(t)dt；θ = π 时 P₁ = sin²(θ/2) = 1。θ = π/2 得叠加态，θ = 2π 回到 |0⟩（带相位）。"),
	("失谐 δ ≠ 0 时，Rabi 振荡的最大布居是多少？",
	 ["还是 1", "Ω_R²/(Ω_R²+δ²)", "0.5", "取决于 σ"], 2,
	 "P₁,max = Ω_R²/(Ω_R²+δ²) < 1，且振荡频率变快（广义 Ω_R = √(Ω_R²+δ²)）这就是「门变脏」的参数化图像。"),
	("为什么 π 门不能无限快？",
	 ["T1 衰减", "|2⟩ 泄漏 ∝ (amp·V12/Δ₂)²", "DRAG 需要时间", "Bloch 球转速上限"], 2,
	 "Δ₂ ≈ |α| 只有 ~0.3 GHz，驱动一强，|1⟩→|2⟩ 的非共振激发就按 amp² 涨上来——这正是 DRAG 要压掉的东西。"),
])

# ╔═╡ a0000000-0000-4000-8000-000000000012
@htl("""
<div style="font-size:14.5px;color:#33384D;line-height:2.0;margin-top:6px">
<p><b>门 = 受控的旋转。</b>Bloch 球上 |0⟩→|1⟩ 是绕 x 轴转 π；相位门（虚拟 Z）则绕 z 轴。所有单比特门都是这两类旋转的组合——脉冲的幅度、时长、相位（I/Q 两路）就是全部旋钮。</p>
<p><b>快与准的权衡。</b>π 门越快（amp 越大）对 T1 越鲁棒，但 |2⟩ 泄漏 ∝ amp²（推导末步）。真实器件的门时间被这个权衡卡在几十 ns 量级。</p>
<p><b>下一步：</b><b>DRAG</b> 演示怎么用一条正交微分曲线压掉泄漏；<b>色散读取</b>演示门做完之后怎么读出结果。</p>
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
# ╟─a0000000-0000-4000-8000-000000000001
# ╠═a0000000-0000-4000-8000-000000001001
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
# ╠═a0000000-0000-4000-8000-000000011002
# ╠═a0000000-0000-4000-8000-000000000012
# ╟─00000000-0000-0000-0000-000000000001
# ╟─00000000-0000-0000-0000-000000000002
