### A Pluto.jl notebook ###
# v0.20.10

using Markdown

# ╔═╡ e0000000-0000-4000-8000-000000000001
begin
	using PlutoUI, PlotlyBase, Statistics, Random, HypertextLiteral
	include(joinpath(@__DIR__, "..", "src", "OverQubit.jl"))
	include(joinpath(@__DIR__, "..", "src", "OverQubitViz.jl"))
	using .OverQubit, .OverQubitViz
	setup_page()
end

# ╔═╡ e0000000-0000-4000-8000-000000000002
md"""### ① 这一页讲什么：比特为什么会「忘记」自己的状态"""

# ╔═╡ e0000000-0000-4000-8000-000000000003
banner("OVERQUBIT · 退相干", "T1 / T2 / Ramsey / 自旋回波：量子态的遗忘曲线",
	"同一台 transmon，状态能「活」多久？π/2 脉冲之后画出 Bloch 横向分量就是 Ramsey 条纹；在中间插一个 π 脉冲折回去，就是自旋回波"; icon="clock")

# ╔═╡ e0000000-0000-4000-8000-000000000004
lesson_nav([
	("①", "transmon 能级与量子化", "done"),
	("②", "单比特门与 Rabi", "done"),
	("③", "DRAG 泄漏压制", "done"),
	("④", "色散读取 S21", "done"),
	("⑤", "两比特耦合与 iSWAP", "done"),
	("⑥", "T1 / T2 / Ramsey", "current"),
	("⑦", "磁通调谐与能级扇形图", "todo"),
])

# ╔═╡ e0000000-0000-4000-8000-000000000005
concept_cards([
	("T1（能量弛豫）", "|1⟩ 会把一个能量量子还给电路：介质损耗、准粒子隧穿、Purcell 泄漏都会让它衰减回 |0⟩，真实器件 T1 ~ 10-500 μs。Lindblad 崩溃算符 L = √γ₁·|0⟩⟨1|，γ₁ = 1/T1。"),
	("T2（相干时间）", "不只布居会丢，**相位**也会丢。弛豫必然贡献一半速率（1/2T1），其余来自纯退相 Tφ：1/T2 = 1/(2T1) + 1/Tφ，因此 T2 ≤ 2T1。"),
	("Ramsey 干涉", "π/2 脉冲把态放到赤道，自由演化 τ，再补一个 π/2 读出来。失谐 δ 把相位转成布居条纹 $(tex(raw"P_1=\tfrac12\big[1+V\cos(2\pi\delta\tau)\big]"))——这就是「用 Ramsey 测频率」的全部原理。"),
	("自旋回波", "τ/2 处插一个绕 y 的 π 脉冲，静态失谐被「折返」抵消，只有 τ 期间**变化**的噪声幸存。回波测出的 T2 总比 Ramsey 的 T2* 长（Hahn 1950）。"),
])

# ╔═╡ e0000000-0000-4000-8000-000000000006
callout("本页是<b>两能级故事</b>：EJ/E_C 只决定 f01 与 |⟨0|n̂|1⟩⟩| 的数值（见 ①），动力学在旋转坐标系 + 多能级 RWA 下精确演化（引擎 <span class=\"oq-kbd\">evolve_segments</span>，与 ② 的载波引擎同一套 Rabi 口径）。",
	tone="info", title="阅读前提")

# ╔═╡ e0000000-0000-4000-8000-000000000007
md"""### ③ 调参（器件 + 噪声，全部真实计算）

静态噪声用 **kHz** 量级（这才是真实器件的 T2* 尺度）：σ_δ 是每次实验里准静态的失谐分布宽度。"""

# ╔═╡ e0000000-0000-4000-8000-000000000008
@bind EJ Slider(5:0.5:50; default=20)

# ╔═╡ e0000000-0000-4000-8000-000000000009
@bind EC Slider(0.05:0.01:0.5; default=0.30)

# ╔═╡ e0000000-0000-4000-8000-00000000000a
@bind T1us Slider(5:1:60; default=30)

# ╔═╡ e0000000-0000-4000-8000-00000000000b
@bind Tphius Slider(5:1:80; default=50)

# ╔═╡ e0000000-0000-4000-8000-00000000000c
@bind sigmad Slider(0:2:100; default=20)

# ╔═╡ e0000000-0000-4000-8000-00000000000d
@bind deltak Slider(0:2:100; default=30)

# ╔═╡ e0000000-0000-4000-8000-00000000000e
@bind nmem Slider(8:8:128; default=64)

# ╔═╡ e0000000-0000-4000-8000-00000000000f
@bind taumax Slider(2.0:1.0:30.0; default=15.0)

# ╔═╡ e0000000-0000-4000-8000-000000000010
begin
	t = Transmon(EJ, EC; ncut=60)
	f01, f12 = f01_f12(t, 0.0)
	α_ = f12 - f01
	n01 = abs(charge_matrix_element(t, 0, 1))
	# 速率约定：gamma1 = 1/T1、gammaphi = 1/Tφ（ns⁻¹ 即 GHz）
	γ1 = 1 / (T1us * 1000)
	γφ = 1 / (Tphius * 1000)
	decay = γ1 / 2 + γφ                       # 相干总衰减率 (ns⁻¹)
	# 脉冲面积：θ = 2π·drvamp·n01·T → π/2 需 T = 1/(4·drvamp·n01)
	drvamp = 0.10
	T90 = 1 / (4 * drvamp * n01)
	Tpi = 2 * T90
	σ_kHz = sigmad; δ_kHz = deltak
	rng = Random.MersenneTwister(20260926)
	# 每次 shot 的准静态失谐（GHz）；第一条固定为名义值便于看单条条纹
	δs = δ_kHz / 1e6 .+ (σ_kHz / 1e6) .* Random.randn(rng, nmem)
	δs[1] = δ_kHz / 1e6
	tolT2 = min(2 * T1us * 1000, Tphius * 1000)   # T2 理论上限
	f01_s = string(round(f01, digits=3)); alpha_s = string(round(α_, digits=3))
	T90_s = string(round(T90, digits=2)); Tpi_s = string(round(Tpi, digits=2))
end

# ╔═╡ e0000000-0000-4000-8000-000000000011
begin
	# —— A) T1：π 脉冲后自由演化，p1 指数衰减（两能级近似，采样 50 ns） ——
	engT1 = SequenceEngine(t, 0.0, 0.0; gamma1=γ1, gammaphi=0.0, nlev=2)
	tsT1, pT1, _ = evolve_segments(engT1,
		[(T=Tpi, amp=drvamp, phase=0.0), (T=6 * T1us * 1000, amp=0.0, dt=50.0)])
	maskT1 = tsT1 .> Tpi + 10
	τT1 = tsT1[maskT1] .- tsT1[maskT1][1]
	yT1 = pT1[maskT1, 2]
	slope1 = sum((τT1 .- mean(τT1)) .* (log.(yT1) .- mean(log.(yT1)))) / sum((τT1 .- mean(τT1)) .^ 2)
	T1_meas = -1 / (slope1 * 1000)
	T1_s = string(round(T1_meas, digits=1))
end

# ╔═╡ e0000000-0000-4000-8000-000000000012
begin
	# —— B) Ramsey/回波公共网格：π/2 – τ（– π(y) – τ）– 末态；每个 shot 一个准静态 δ_k ——
	taus = collect(range(0.0, taumax * 1000; length=61))          # ns（每个 echo 延迟的半间距）
	nT = length(taus)
	stripes = zeros(nmem, nT)      # 经典 Ramsey 布居条纹 = ½(1 − by)
	bloch_x = zeros(nmem, nT)      # Bloch 横向分量（= 2Re ρ01）
	bloch_y = zeros(nmem, nT)      # = 2Im ρ01
	echoes = zeros(nmem, nT)       # 自旋回波条纹
	for (k, δk) in enumerate(δs)
		eng = SequenceEngine(t, 0.0, δk; gamma1=γ1, gammaphi=γφ, nlev=2)
		segR(τ) = [(T=T90, amp=drvamp, phase=0.0), (T=τ, amp=0.0, dt=τ)]
		segE(τ) = [(T=T90, amp=drvamp, phase=0.0), (T=τ, amp=0.0, dt=τ), (T=Tpi, amp=drvamp, phase=0.0),
			(T=τ, amp=0.0, dt=τ), (T=T90, amp=drvamp, phase=180.0)]
		for (j, τ) in enumerate(taus)
			_, _, b = evolve_segments(eng, segR(τ))
			bloch_x[k, j] = b[end, 1]; bloch_y[k, j] = b[end, 2]
			stripes[k, j] = (1 - b[end, 2]) / 2
			_, _, b2 = evolve_segments(eng, segE(τ))
			echoes[k, j] = (1 - b2[end, 3]) / 2      # 末脉冲（反相）把相干翻成布居 → p₁，静态失谐抵消后回到 1
		end
	end
	bx_m = vec(mean(bloch_x; dims=1)); by_m = vec(mean(bloch_y; dims=1))
	coh_mag = sqrt.(bx_m .^ 2 .+ by_m .^ 2) ./ 2      # |⟨ρ01⟩|
	stripe_mean = vec(mean(stripes; dims=1))
	echo_mean = vec(mean(echoes; dims=1))
	# T2*：相干包络相对 1/e 的首个穿越点（包络初值 = ½·e^(−τ/T2)）
	im = findfirst(coh_mag .<= coh_mag[1] * exp(-1))
	T2star_meas = im === nothing ? taus[end] : taus[im]
	T2star_meas_s = string(round(T2star_meas / 1000, digits=2))
	# 理论包络 exp(-(2πσ_δ τ)²/2)（含 T2 衰减时整体乘以 e^(-τ/T2)）
	env = exp.(-(2π * σ_kHz / 1e6 .* taus) .^ 2 ./ 2) .* exp.(-taus / tolT2)
end

# ╔═╡ e0000000-0000-4000-8000-000000000013
begin
	# —— C) 真实 T2：无静态噪声、无失谐，看 Bloch 横向长度的衰减 ——
	engT2 = SequenceEngine(t, 0.0, 0.0; gamma1=γ1, gammaphi=γφ, nlev=2)
	tsT2, pT2, bT2 = evolve_segments(engT2,
		[(T=T90, amp=drvamp, phase=0.0), (T=8 * tolT2, amp=0.0, dt=10.0)])
	coh = sqrt.(bT2[:, 1] .^ 2 .+ bT2[:, 2] .^ 2) ./ 2
	m2 = tsT2 .> T90 + max(10.0, 0.02 * 8 * tolT2)
	τc = tsT2[m2] .- tsT2[m2][1]
	yc = coh[m2]
	slope2 = sum((τc .- mean(τc)) .* (log.(yc) .- mean(log.(yc)))) / sum((τc .- mean(τc)) .^ 2)
	T2_meas = -1 / slope2
	T2_meas_s = string(round(T2_meas / 1000, digits=2))
	T2_theory_s = string(round(1 / decay / 1000, digits=2))
end

# ╔═╡ e0000000-0000-4000-8000-000000000014
stat_row([
	("T1（设定 / 实测）", "$(T1us) / $(T1_s) μs", "γ₁ = 1/T1 → p₁ ∝ e^(−t/T1)", "#4C6FFF"),
	("Tφ（设定）", "$(Tphius) μs", "1/Tφ = γφ（纯退相）", "#7B61FF"),
	("T2（理论 / 实测）", "$(T2_theory_s) / $(T2_meas_s) μs", "1/T2 = 1/(2T1) + 1/Tφ ≤ 2T1", "#22C3A6"),
	("T2*（Ramsey, 实测）", "$(T2star_meas_s) μs", "σ_δ = $(σ_kHz) kHz → 理论 ≈ $(string(round(1 / (sqrt(2) * π * σ_kHz / 1e6) / 1000, digits=2))) μs（n=$(nmem) 次 shot 估计）", "#B8812E"),
	("f01 / α（本页不参与动力学）", "$(f01_s) / $(alpha_s) GHz", "π/2 = $(T90_s) ns，π = $(Tpi_s) ns", "#1A1A2E"),
])

# ╔═╡ e0000000-0000-4000-8000-000000000015
callout("三组数一起读：<b>T2*</b> ≪ <b>T2</b> ≲ 2T1。T2* 短说明有准静态噪声（电荷/磁通漂移、相邻比特的 ZZ 漂移）——这在真实器件里最常见，而它可以被自旋回波救回来。",
	tone="tip", title="看什么")

# ╔═╡ e0000000-0000-4000-8000-000000000016
begin
	tr = PlotlyBase.GenericTrace[]
	push!(tr, PlotlyBase.scatter(x=τT1 / 1000, y=yT1; mode="lines", name="p₁ 实测",
		line=attr(color=PAL[1], width=2.5)))
	push!(tr, PlotlyBase.scatter(x=τT1 / 1000, y=yT1[1] * exp.(-τT1 / (T1us * 1000)); mode="lines",
		name="理想 e^(−t/T1)", line=attr(color="#8A90AD", width=1.5, dash="dash")))
	push!(tr, PlotlyBase.scatter(x=τT1 / 1000, y=1 .- yT1; mode="lines", name="p₀",
		line=attr(color=PAL[3], width=1.8), opacity=0.75))
	pt1 = PlotlyBase.Plot(tr, layout_base(height=400, title="A · T1：π 脉冲把比特翻上去，它自己会掉下来",
		xtitle="π 脉冲后时间 (μs)", ytitle="布居", yrange=[0, 1]))
	plotly_html("oq_t1", pt1; height=410)
end

# ╔═╡ e0000000-0000-4000-8000-000000000017
begin
	# B) Ramsey：单条条纹 + ensemble 平均 + 相干包络 vs 理论
	tr = PlotlyBase.GenericTrace[]
	for k in 2:nmem
		push!(tr, PlotlyBase.scatter(x=taus / 1000, y=stripes[k, :]; mode="lines",
			line=attr(color="rgba(76,111,255,0.16)", width=1), showlegend=(k == 2),
			name="各次 shot（准静态 δ_k）"))
	end
	push!(tr, PlotlyBase.scatter(x=taus / 1000, y=stripes[1, :]; mode="lines",
		line=attr(color=PAL[1], width=2), name="名义失谐 δ = $(δ_kHz) kHz（单条）"))
	push!(tr, PlotlyBase.scatter(x=taus / 1000, y=stripe_mean; mode="lines",
		line=attr(color="#7B61FF", width=3), name="条纹平均（被噪声抹平）"))
	push!(tr, PlotlyBase.scatter(x=taus / 1000, y=0.5 .+ coh_mag .* sign.(by_m .+ 1e-30); mode="lines",
		line=attr(color="#22C3A6", width=2, dash="dot"), name="相干幅度 |⟨ρ₀₁⟩|（= T2* 包络）"))
	push!(tr, PlotlyBase.scatter(x=taus / 1000, y=0.5 .+ 0.5 .* env; mode="lines",
		line=attr(color="#B8812E", width=1.5, dash="dash"), name="理论包络 ½e^(−(2πσ_δτ)²/2)·e^(−τ/T2)"))
	pram = PlotlyBase.Plot(tr, layout_base(height=450,
		title="B · Ramsey 条纹与 T2* 包络（准静态噪声）",
		xtitle="π/2 之后的自由演化时间 τ (μs)", ytitle="P₁", yrange=[0, 1]))
	plotly_html("oq_ramsey", pram; height=460)
end

# ╔═╡ e0000000-0000-4000-8000-000000000018
begin
	# C) 自旋回波对比：横轴是**回波总时长 2τ**（π/2 与 π/2 之间隔两段 τ）
	tr = PlotlyBase.GenericTrace[]
	push!(tr, PlotlyBase.scatter(x=taus / 1000, y=stripe_mean; mode="lines", name="Ramsey（无回波，T2*）",
		line=attr(color=PAL[1], width=3)))
	push!(tr, PlotlyBase.scatter(x=taus / 1000, y=0.5 .+ 0.5 .* env; mode="lines",
		line=attr(color=PAL[1], width=1.2, dash="dash"), showlegend=false))
	push!(tr, PlotlyBase.scatter(x=2 .* taus / 1000, y=echo_mean; mode="lines", name="自旋回波（≈ T2）",
		line=attr(color="#F5A623", width=3)))
	push!(tr, PlotlyBase.scatter(x=2 .* taus / 1000, y=0.5 .+ 0.5 * exp.(-2 .* taus / tolT2); mode="lines",
		name="½(1 + e^(−2τ/T2)) 理论", line=attr(color="#B8812E", width=1.5, dash="dash")))
	pech = PlotlyBase.Plot(tr, layout_base(height=450,
		title="C · 自旋回波：静态噪声被折返，剩下真正的 T2",
		xtitle="回波总时长 2τ (μs)（Ramsey 曲线用 τ，回波曲线用 2τ）", ytitle="P₁", yrange=[0, 1]))
	plotly_html("oq_echo", pech; height=460)
end

# ╔═╡ e0000000-0000-4000-8000-000000000019
figure_note("回波序列末脉冲取同相位（读 x 分量），因此静态失谐被抵消后 P₁ 回到 1；把 σ_δ 拖到 0，橙线会塌到与 Ramse 一样的振荡曲线——因为「静态」已无物可折。")

# ╔═╡ e0000000-0000-4000-8000-00000000001a
begin
	# D) IQ 平面动画：名义失谐那条 shot 的 Bloch 矢量在赤道面上旋转 + 收缩
	nfr = 40
	fidx = round.(Int, range(1, nT; length=nfr))
	circle_th = range(0, 2π; length=90)
	frames = PlotlyBase.PlotlyFrame[]
	for i in fidx
		push!(frames, anim_frame(0, string(i), PlotlyBase.scatter(x=[stripes[1, i] .- 0.5, bx_m[i] / 2],
			y=[0, by_m[i] / 2]; mode="lines", line=attr(color="rgba(123,97,255,0.5)", width=2),
			showlegend=false, hoverinfo="skip")))
	end
	tr = PlotlyBase.GenericTrace[]
	push!(tr, PlotlyBase.scatter(x=Float64[], y=Float64[]; mode="lines", showlegend=false))
	#  ↑ trace 0 就是被动画更新的那条矢量投影线（初始为空）
	push!(tr, PlotlyBase.scatter(x=cos.(circle_th), y=sin.(circle_th); mode="lines",
		line=attr(color="rgba(20,24,60,0.12)", width=1), showlegend=false, name="Bloch 赤道"))
	push!(tr, PlotlyBase.scatter(x=bx_m ./ 2, y=by_m ./ 2; mode="lines",
		line=attr(color=PAL[1], width=2, dash="dot"), name="ensemble 平均 ⟨ρ₀₁⟩"))
	push!(tr, PlotlyBase.scatter(x=[bx_m[1] / 2], y=[by_m[1] / 2]; mode="markers",
		marker=attr(size=9, color="#FF7A7A", line=attr(color="white", width=2)), showlegend=false))
	piq = PlotlyBase.Plot(tr, layout_base(height=420, anchor_y=true,
		title="D · Bloch 赤道面（IQ 平面）：单条矢量匀速转，平均矢量越转越短",
		xtitle="x = 2Re ρ₀₁", ytitle="y = 2Im ρ₀₁", legend_x=0.15, updatemenus=animation_menu()),
		frames)
	plotly_html("oq_iq_t1t2", piq; height=430)
end

# ╔═╡ e0000000-0000-4000-8000-00000000001b
divider()

# ╔═╡ e0000000-0000-4000-8000-00000000001c
derivation("⑤ 推导溯源：从 Lindblad 主方程到 T2*",
	[
	("定义", texblock(raw"\dot\rho = -i[H_0,\rho] + \mathcal{D}[L_1]\rho + \mathcal{D}[L_\phi]\rho"), texblock(raw"L_1 = \sqrt{\gamma_1}\,|0\rangle\langle 1|, \qquad L_\phi = \sqrt{\frac{\gamma_\phi}{2}}\,\mathrm{diag}(1,-1)")),
	("定义", "本页所有曲线都由这个方程在旋转坐标系中精确演化得到。", "两能级子系统 + 马尔可夫环境；崩溃算符的个数就是噪声通道数。"),
	("代入", texblock(raw"\mathcal{D}[L_1]\ \text{只作用在}\ |1\rangle\langle 1| \text{ 上} \Rightarrow \frac{d\rho_{11}}{dt} = -\gamma_1\,\rho_{11}"), texblock(raw"\Rightarrow\quad p_1(t) = p_1(0)\,e^{-\gamma_1 t} \;\;\Rightarrow\;\; T_1 = \frac{1}{\gamma_1}")),
	("代入", texblock(raw"p_0 + p_1 = 1 \quad\text{（能量弛豫只动布居、不碰相干）}"), "图 A 里蓝/绿线始终互补。"),
	("定义", texblock(raw"Z = |0\rangle\langle 0| - |1\rangle\langle 1|, \qquad Z\rho Z\ \text{在}\ \rho_{01}\ \text{上给}\ -\rho_{01}"), texblock(raw"\Rightarrow\quad \mathcal{D}[L_\phi]\rho_{01} = -\gamma_\phi\,\rho_{01} \;\;\Rightarrow\;\; \frac{1}{T_\phi} = \gamma_\phi")),
	("定义", texblock(raw"\mathrm{pure\ dephasing:}\quad \rho_{01} \to e^{-\gamma_\phi t}\rho_{01}, \qquad \rho_{00},\ \rho_{11}\ \mathrm{unchanged}"), "频率抖动（1/f 噪声、电荷/磁通噪声）不改能级占据，只抹相位——这就是纯退相。"),
	("整理", texblock(raw"\frac{d\rho_{01}}{dt} = -\Big(\frac{\gamma_1}{2} + 2\gamma_\phi\Big)\rho_{01} \;\;\Rightarrow\;\; \frac{1}{T_2} = \frac{1}{2T_1} + \frac{1}{T_\phi}"), "T2 的两个来源：弛豫（必然贡献一半速率）+ 纯退相。注意自旋回波消不掉第一项。"),
	("代入", texblock(raw"\text{Ramsey: } \tfrac{\pi}{2} - \tau - \tfrac{\pi}{2} \;\;\Rightarrow\;\; \rho_{01}(\tau) \propto e^{-i2\pi\delta\tau}"), texblock(raw"\Rightarrow\quad P_1(\tau) = \frac{1}{2}\big[1 + V\cos(2\pi\delta\tau + \varphi)\big], \quad V \le 1")),
	("代入", texblock(raw"\text{Ramsey: }\ \rho_{01}\ \text{绕 } z \text{ 轴以}\ \delta\ \text{匀速转}"), "旋转坐标系里看：态矢量在赤道平面以 $(tex(raw"\delta")) 匀速转。图 D 就是这个旋转 + 衰减。"),
	("整理", texblock(raw"\delta \sim \mathcal{N}(0,\sigma_\delta):\qquad \big\langle e^{-i2\pi\delta\tau}\big\rangle = e^{-(2\pi\sigma_\delta\tau)^2/2}"), texblock(raw"\Rightarrow\quad T_2^{*}\ \text{包络} = e^{-(2\pi\sigma_\delta\tau)^2/2}, \qquad \frac{1}{e}\ \text{时间}\approx \frac{1}{\sqrt{2}\,\pi\sigma_\delta}")),
	("整理", texblock(raw"T_2^{*}\ \mathrm{envelope} = e^{-(2\pi\sigma_\delta\tau)^2/2}"), "T2* 与 T2 的全部差别就在这一项：静态噪声能被回波折返，动态噪声不能。"),
	("代入", texblock(raw"\text{spin echo: }\ \tfrac{\pi}{2} - \tau - \pi - \tau - \tfrac{\pi}{2}"), "Hahn 1950：只对**时间上不变**的噪声有效（静态失谐、准静态梯度）；对 τ 期间翻转的噪声（T1 型）无效。"),
	("整理", texblock(raw"T_2^{*} \le T_2 \le 2T_1"), "实验顺序：测 T1 → 测 T2*（Ramsey）→ 测 T2（回波）；差值就是噪声谱信息。"),
	("整理", texblock(raw"\Delta\varphi_{\mathrm{static}} = 2\pi\delta\tau - 2\pi\delta\tau = 0"), "这也是噪声谱学的起点：改变回波脉冲间距即可扫出噪声功率谱——今天所有「量子噪声谱学」的祖先。"),
	];
	lead="每一步都可点开。读数卡里的四个数字都能在这里找到对应的那一行。",
	result="当前参数：T1 = $(T1us) μs、Tφ = $(Tphius) μs → 理论 T2 = 1/(1/(2T1) + 1/Tφ) = $(T2_theory_s) μs（上限 2T1 = $(2T1us) μs），实测 $(T2_meas_s) μs；准静态 σ_δ = $(σ_kHz) kHz → 理论 T2* ≈ $(string(round(1 / (sqrt(2) * π * σ_kHz / 1e6) / 1000, digits=2))) μs，实测 $(T2star_meas_s) μs。")

# ╔═╡ e0000000-0000-4000-8000-00000000001d
tryout([
	("亲手复现 1/T2 = 1/(2T1) + 1/Tφ", "固定 T1 = 30 μs、σ_δ = 0，把 Tφ 从 80 拖到 10，看 T2 读数卡与图 C 橙线。",
	 "T2 从 ~34 μs（1/60 + 1/80）一路掉到 ~20 μs（1/60 + 1/10）——读数卡的理论值与实测值始终吻合，且永远 ≤ 2T1 = 60 μs。"),
	("亲眼看见 T2* ≪ T2", "σ_δ 拖到 100 kHz，对比图 B 与图 C。",
	 "Ramsey 条纹在 ~1 μs 内就被抹平（T2*），而回波曲线还在 10 μs 尺度上完好——准静态噪声被折返的证据；把 σ_δ 拖回 0，两者重合。"),
	("让条纹慢下来", "σ_δ = 0、名义失谐拖到 20 kHz、τmax 拖到 30 μs。",
	 "条纹周期变成 50 μs，图 D 里的红点在赤道面上匀速转一圈正好一个周期——这就是「用 Ramsey 测频率」：数条纹周期就能定 δ。"),
	("回波为什么救不了 T1", "把 T1 拖到 5 μs（很差），再对比 Ramsey 与回波。",
	 "两条曲线都变快——回波只折返静态失谐，折返不了 |1⟩ 的真实衰减。T2 ≤ 2T1 在图上直接可见：5 μs 的 T1 把 T2 卡在 10 μs 以内。"),
])

# ╔═╡ e0000000-0000-4000-8000-00000000001e
quiz([
	("一台比特 T1 = 40 μs、Tφ = 30 μs，T2 上限是多少？",
	 ["30 μs", "20 μs", "60 μs", "40 μs"], 2,
	 "1/T2 = 1/(2·40) + 1/30 = 0.0125 + 0.0333 = 0.0458 /μs → T2 ≈ 21.8 μs。T2 ≤ 2T1 = 80 μs 也满足，本例中被纯退相主导。"),
	("Ramsey 条纹的周期由什么决定？",
	 ["T2*", "驱动幅度 drvamp", "失谐 δ", "T1"], 3,
	 "周期 = 1/δ（P₁ ∝ cos²(πδτ)）。δ → 0 时条纹消失成水平线；δ 越大条纹越密。T2* 只决定条纹能持续多久。"),
	("为什么自旋回波的时间通常比 Ramsey 长？",
	 ["回波用了更强的驱动", "回波抵消了准静态噪声", "回波能让 T1 变长", "回波没有测量噪声"], 2,
	 "τ/2 处的 π 脉冲把静态失谐的累积相位折返（推导第 7 步），只剩 τ 期间真正变化的噪声——这正是 Hahn 回波成为主流相干测量的原因。"),
])

# ╔═╡ e0000000-0000-4000-8000-00000000001f
@htl("""
<div style="font-size:14.5px;color:#33384D;line-height:2.0;margin-top:6px">
<p><b>一张图记住全部：</b>T1 是布居的衰减（图 A），T2* 是 Ramsey 条纹的寿命（图 B），T2 是回波的寿命（图 C），图 D 把「相位在赤道面上转圈」画了出来。1/T2 = 1/(2T1) + 1/Tφ 就是器件工艺的体检报告。</p>
<p><b>数字的意义：</b>今天的超导 transmon T1 普遍 50-500 μs、T2 20-300 μs；一台处理器能算多深，取决于这些 μs 里能塞进多少个 20 ns 量级的门。</p>
<p><b>下一步去哪：</b><b>两比特耦合</b>看两个比特如何用 iSWAP 交换状态、以及 always-on ZZ 如何反过来制造退相干；<b>磁通调谐</b>看 E_J(Φ) 如何把能级拧成扇形图、如何用甜点压噪声。</p>
</div>
""")

# ╔═╡ Cell order:
# ╟─e0000000-0000-4000-8000-000000000001
# ╠═e0000000-0000-4000-8000-000000000002
# ╠═e0000000-0000-4000-8000-000000000003
# ╠═e0000000-0000-4000-8000-000000000004
# ╠═e0000000-0000-4000-8000-000000000005
# ╠═e0000000-0000-4000-8000-000000000006
# ╟─e0000000-0000-4000-8000-000000000007
# ╟─e0000000-0000-4000-8000-000000000008
# ╟─e0000000-0000-4000-8000-000000000009
# ╟─e0000000-0000-4000-8000-00000000000a
# ╟─e0000000-0000-4000-8000-00000000000b
# ╟─e0000000-0000-4000-8000-00000000000c
# ╟─e0000000-0000-4000-8000-00000000000d
# ╟─e0000000-0000-4000-8000-00000000000e
# ╟─e0000000-0000-4000-8000-00000000000f
# ╠═e0000000-0000-4000-8000-000000000010
# ╟─e0000000-0000-4000-8000-000000000011
# ╟─e0000000-0000-4000-8000-000000000012
# ╟─e0000000-0000-4000-8000-000000000013
# ╠═e0000000-0000-4000-8000-000000000014
# ╠═e0000000-0000-4000-8000-000000000015
# ╟─e0000000-0000-4000-8000-000000000016
# ╟─e0000000-0000-4000-8000-000000000017
# ╟─e0000000-0000-4000-8000-000000000018
# ╠═e0000000-0000-4000-8000-000000000019
# ╟─e0000000-0000-4000-8000-00000000001a
# ╠═e0000000-0000-4000-8000-00000000001b
# ╠═e0000000-0000-4000-8000-00000000001c
# ╠═e0000000-0000-4000-8000-00000000001d
# ╠═e0000000-0000-4000-8000-00000000001e
# ╠═e0000000-0000-4000-8000-00000000001f
