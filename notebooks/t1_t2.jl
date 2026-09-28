### A Pluto.jl notebook ###
# v0.20.10

using Markdown

# ╔═╡ e0000000-0000-4000-8000-000000000001
begin
	using PlutoUI, PlotlyBase, Statistics, Random, HypertextLiteral
	include(joinpath(@__DIR__, "..", "src", "OverQubit.jl"))
	using .OverQubit
	setup_page()
end

# ╔═╡ e0000000-0000-4000-8000-000000000002
md"""### ① 这一页讲什么：比特为什么会「忘记」自己的状态"""

# ╔═╡ e0000000-0000-4000-8000-000000000003
oq_stack(
banner("OVERQUBIT · 退相干", "T1 / T2 / Ramsey / 自旋回波：量子态的遗忘曲线",
	"同一台 transmon，状态能「活」多久？π/2 脉冲之后画出 Bloch 横向分量就是 Ramsey 条纹；在中间插一个 π 脉冲折回去，就是自旋回波"; icon="clock"),
@htl("""
<div style="font-size:13.5px;color:#33384D;line-height:1.9;max-width:78ch;margin:2px 2px 4px">
<b>读完这页你能：</b>①说清 T1、Tφ、T2、T2* 四个时间<b>各管什么、谁限制谁</b>，并用心算式 1/T2 = 1/(2T1) + 1/Tφ 把给定器件的 T2 估出来（含 2T1 硬上限）；
②看 Ramsey 条纹<b>数周期</b>反推失谐 δ，并解释为什么多次实验平均后条纹会「糊」掉——给出准静态噪声的定量指纹（高斯包络）；
③解释自旋回波的 π 脉冲「折返」了什么（静态失谐）、折返不了什么（T1 与快噪声），并判断 T2* ≪ T2 的器件该先治什么。
</div>
"""),
)

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
	("图像 · 两个时钟：布居的与相位的", "Bloch 球上退相干有两张面孔：T1 把球整体拉向 |0⟩（能量漏走），Tφ 让赤道上的箭头越转越散（相位漏走）。图 A 的 p₁ 指数衰减是第一张面孔，图 D 里矢量越转越短是第二张。真实 transmon 的 T1 约 10–500 μs，而单比特门只要 20–40 ns——门比 T1 短三个数量级，这正是超导比特能连做上千次操作的原因。验证锚点：图 A 蓝线与灰色虚线 e^(−t/T1) 重合，读数卡「T1 设定 / 实测」并排对照。"),
	("机制 · Lindblad：一条噪声通道一个崩溃算符", "系统加环境被压缩成密度矩阵的主方程 ρ̇ = −i[H₀,ρ] + D[L₁]ρ + D[L_φ]ρ。L₁ = √γ₁|0⟩⟨1| 是能量交换通道（介质损耗、准粒子隧穿、Purcell 泄漏），L_φ 是纯相位通道（1/f 电荷/磁通噪声）。两条通道对相干的贡献相加：1/T2 = 1/(2T1) + 1/Tφ，所以 T2 ≤ 2T1——弛豫是永远还不掉的地板。类比：T1 是水位下降，Tφ 是水面涟漪，波纹的寿命必然短于水位。验证锚点：读数卡「T2 理论 / 实测」两列始终吻合。"),
	("定量 · Ramsey：把频率差变成条纹", "π/2 – τ – π/2 三段序列把相位读成布居：P₁ = ½[1 + V cos(2πδτ + φ)]，条纹周期 = 1/δ。每次实验的准静态失谐还会漂（高斯分布，宽度 σ_δ 为 kHz 量级），平均后 ⟨e^(−i2πδτ)⟩ = e^(−(2πσ_δτ)²/2)——条纹被抹平，包络的 1/e 时间就是 T2* ≈ 1/(√2 π σ_δ)。σ_δ = 20 kHz 时 T2* ≈ 11 μs，往往比 T2 短好几倍。验证锚点：图 B 青色点线与橙色虚线（理论包络）重合，图 D 平均矢量越转越短。"),
	("代价 · 自旋回波：折得回静态，折不回动态", "τ 中点插一个 π 脉冲把累积相位折返：静态失谐前半段攒 +2πδτ、后半段 −2πδτ，恰好抵消；只有在 τ 期间真正变化的噪声幸存。所以回波测出的 T2 总比 Ramsey 的 T2* 长（Hahn 1950），但封顶在 2T1。代价：序列翻倍到 2τ，π 脉冲自身不完美也留痕，对快噪声（白噪声、T1 型涨落）完全无效。验证锚点：图 C 橙线比蓝线撑得久；把 σ_δ 拖到 0，两者塌到一起。"),
])

# ╔═╡ e0000000-0000-4000-8000-000000000006
oq_stack(
callout("为什么关心：量子计算的算力预算就是「相干时间 ÷ 门时间」——T1/T2 不是参数表里的装饰，而是每条线路的硬预算。本页主线：一个 π/2 脉冲把态放到赤道，然后让三种「遗忘」各自显形——弛豫（图 A）、准静态失谐（图 B）、可折返与不可折返的分界（图 C），图 D 把全过程画在 IQ 平面上。建议读法：先看四张概念卡分清四个时间 → 拖 T1 / Tφ / σ_δ 做四个实验 → 再回头看推导链（每一步都标了在哪张图或哪行读数上验证）。",
	tone="info", title="① 这一页讲什么：量子态的三种「遗忘」与它们的解药"),
callout("本页是<b>两能级故事</b>：EJ/E_C 只决定 f01 与 |⟨0|n̂|1⟩⟩| 的数值（见 ①），动力学在旋转坐标系 + 多能级 RWA 下精确演化（引擎 <span class=\"oq-kbd\">evolve_segments</span>，与 ② 的载波引擎同一套 Rabi 口径）。",
	tone="info", title="阅读前提"),
)

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
callout("三组数一起读：<b>T2*</b> ≪ <b>T2</b> ≲ 2T1。T2* 短说明有准静态噪声（电荷/磁通漂移、相邻比特的 ZZ 漂移）——这在真实器件里最常见，而它可以被自旋回波救回来。建议顺序：先动 <b>Tφ</b> 看 T2 沿 1/(2T1) + 1/Tφ 的公式走（图 C），再动 <b>σ_δ</b> 看 T2* 单独塌下去而 T2 不动（图 B vs 图 C），最后拖 <b>T1</b> 看 2T1 天花板压下来。",
	tone="tip", title="③ 调参前先看这里：先动 Tφ，再动 σ_δ")

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
figure_note("看图要诀（图 B/C）：①蓝线（Ramsey）看两件事——条纹的疏密是 1/δ，条纹「糊掉」的快慢是 T2*；②青色点线是相干幅度 |⟨ρ₀₁⟩|，它与橙色虚线（理论高斯包络）重合即说明准静态图像成立；③橙线（回波）画在 2τ 轴上——同一横坐标处它的实际时长是蓝线的两倍，比较「谁活得久」时要按实际时长对齐。回波序列末脉冲取同相位（读 x 分量），静态失谐被抵消后 P₁ 回到 1；把 σ_δ 拖到 0，橙线会塌到与 Ramsey 一样的振荡曲线——因为「静态」已无物可折。")

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
oq_stack(
derivation("⑤ 推导溯源：从 Lindblad 主方程到 T2*",
	[
	("定义", texblock(raw"\dot\rho = -i[H_0,\rho] + \mathcal{D}[L_1]\rho + \mathcal{D}[L_\phi]\rho"), "主方程把「系统 + 环境」压缩成对密度矩阵 ρ 的方程：第一项是相干演化，后两项各代表一条噪声通道。崩溃算符的个数就是噪声通道数，本页只开两条——一条管能量，一条管相位。本页所有曲线都由这个方程在旋转坐标系中精确演化（引擎 evolve_segments，与 ② 同一套 RWA 口径），不是手画的示意图。类比：L₁ 像漏水，L_φ 像水面涟漪。失效条件：马尔可夫 + 弱耦合；1/f 噪声严格说有记忆，用准静态系综近似处理（第 9 步）。"),
	("定义", texblock(raw"L_1 = \sqrt{\gamma_1}\,|0\rangle\langle 1|, \qquad L_\phi = \sqrt{\frac{\gamma_\phi}{2}}\,\mathrm{diag}(1,-1)"), "两个崩溃算符各带一个速率：γ₁ = 1/T1、γφ = 1/Tφ——读数卡的 T1us、Tphius 两个滑块就是它们。L₁ 只连接 |1⟩→|0⟩，是个单向的「下楼梯」算符；L_φ 与 Z 成正比，只翻转相干项的符号、不动布居。注意约定：L_φ 前的 √(γφ/2) 保证 ρ₀₁ 的衰减率恰好是 γφ——不同教材的因子 2 约定不同，对照公式前先核对这一步。"),
	("代入", texblock(raw"\frac{d\rho_{11}}{dt} = -\gamma_1\,\rho_{11} \;\;\Rightarrow\;\; p_1(t) = p_1(0)\,e^{-\gamma_1 t}, \qquad T_1 = \frac{1}{\gamma_1}"), "把 L₁ 代入：激发态布居按指数漏光，时间常数 T₁ = 1/γ₁——这就是图 A 的蓝线，1/e 处即 T1。物理上这是能量量子（5 GHz ≈ 20 μeV）还给环境：介质损耗、准粒子隧穿、Purcell 泄漏三条路。验证：读数卡「T1 设定 / 实测」应当相等，实测是对 log p₁ 做线性拟合，图 A 蓝线与灰色虚线重合即拟合可信。失效条件：若环境有热激发（|0⟩→|1⟩ 上爬），指数会带上非零稳态尾巴。"),
	("整理", texblock(raw"p_0(t) + p_1(t) = 1 \qquad(\mathrm{relaxation\ moves\ populations\ only})"), "弛豫只搬布居、不碰相干的形状：p₀ 与 p₁ 永远互补（图 A 绿线是蓝线的镜像，任意时刻竖着相加为 1）。这一步看着平凡，却限定了 T1 的角色——它给 T2 贡献固定的一半速率，剩下的预算才归纯退相。自旋回波也正因如此救不了 T1（试试看任务 4）。"),
	("定义", texblock(raw"Z = |0\rangle\langle 0| - |1\rangle\langle 1|, \qquad (Z\rho Z)_{01} = -\rho_{01} \;\;\Rightarrow\;\; \mathcal{D}[L_\phi]\rho_{01} = -\gamma_\phi\,\rho_{01}"), "L_φ ∝ Z，而 ZρZ 把 ρ₀₁ 变号：于是退相通道对相干项给出 −γφ ρ₀₁，布居纹丝不动。物理图像是频率抖动——能级没动（布居不变），但每次实验的相位积累速率不同，平均下来相干变短。类比：一排钟走得一样准，唯独每只快慢随机，几小时后指针就散了。验证：σ_δ = 0 时图 D 的单条矢量只转不缩，相干缩短全部来自这一项与 T1。"),
	("整理", texblock(raw"\frac{d\rho_{01}}{dt} = -\Big(\frac{\gamma_1}{2} + \gamma_\phi\Big)\rho_{01} \;\;\Rightarrow\;\; \frac{1}{T_2} = \frac{1}{2T_1} + \frac{1}{T_\phi}, \qquad T_2 \le 2T_1"), "把两条通道的贡献相加：相干衰减率 = γ₁/2 + γφ，即 1/T2 = 1/(2T1) + 1/Tφ。注意弛豫贡献的是 1/(2T1) 而不是 1/T1——布居掉一半时相干才掉一半，这个 1/2 是考试与论文里最常见的错。推论：Tφ → ∞ 时 T2 取到硬上限 2T1。验证：拖 Tφ 滑块，读数卡「T2 理论」按公式走、「T2 实测」同步跟随。"),
	("代入", texblock(raw"\mathrm{Ramsey:}\ \ \tfrac{\pi}{2} - \tau - \tfrac{\pi}{2} \;\;\Rightarrow\;\; \rho_{01}(\tau) \propto e^{-i2\pi\delta\tau}"), "Ramsey 序列：第一个 π/2 把 |0⟩ 放到赤道，自由演化 τ 期间 ρ₀₁ 以失谐 δ 匀速转过 2πδτ，第二个 π/2 把角度翻成布居。于是相位变成了可读的布居信号——这就是「用 Ramsey 测频率」的全部原理。验证：图 B 单条蓝线数一数周期，与 1/δ 对得上；图 D 的红点匀速转圈就是这个旋转。"),
	("代入", texblock(raw"P_1(\tau) = \frac{1}{2}\big[1 + V\cos(2\pi\delta\tau + \varphi)\big], \qquad V \le 1"), "投影到 |1⟩ 就是这条余弦条纹：周期 1/δ，对比度 V ≤ 1。V 为什么不到 1：有限温度的热布居、π/2 脉冲的不完美、读出误差都会把条纹「压扁」——真实 Ramsey 数据先看 V 再看周期。验证：图 B 蓝线的峰峰值就是 V；δ → 0 时条纹退化成水平线，所以实验上故意加一点已知失谐。"),
	("整理", texblock(raw"\delta \sim \mathcal{N}(0,\sigma_\delta):\qquad \big\langle e^{-i2\pi\delta\tau}\big\rangle = e^{-(2\pi\sigma_\delta\tau)^2/2}"), "真实实验里每次 shot 的准静态失谐都略有不同（漂移、1/f 噪声、邻居的 ZZ 漂移），用高斯分布宽度 σ_δ（kHz 量级）描述。对相位因子做系综平均得到高斯包络：不同 δ 的条纹周期不同，平均后互相拍平。1/e 时间即 T2* ≈ 1/(√2 π σ_δ)——σ_δ = 20 kHz 时 T2* ≈ 11 μs。验证：图 B 青色点线（相干幅度）与橙色虚线（理论包络）重合，读数卡「T2*」实测/理论并排对照。失效条件：高斯包络假设噪声准静态（相关时间 ≫ τ）；快噪声会把包络变成指数型。"),
	("整理", texblock(raw"T_2^{*}\ \mathrm{envelope} = e^{-(2\pi\sigma_\delta\tau)^2/2}\cdot e^{-\tau/T_2}, \qquad \tau_{1/e}^{*} \approx \frac{1}{\sqrt{2}\,\pi\sigma_\delta}"), "完整的 Ramsey 包络 = 高斯（准静态噪声）× 指数（本征 T2）；σ_δ = 0 时退回纯指数，T2* = T2。T2* 与 T2 的全部差别就在高斯那一项：静态噪声能被回波折返，本征衰减不能。这就是器件表上为什么同时列 T2* 与 T2——前者是「不做任何保护」时的表现，后者是「排除静态漂移后」的底子。"),
	("代入", texblock(raw"\mathrm{spin\ echo:}\ \ \tfrac{\pi}{2} - \tau - \pi - \tau - \tfrac{\pi}{2}, \qquad \Delta\varphi_{\mathrm{static}} = 2\pi\delta\tau - 2\pi\delta\tau = 0"), "Hahn 1950：τ 中点的 π 脉冲把 Bloch 矢量翻个面，静态失谐前半段攒的相位后半段原路抵消，净相位为零。只对时间上不变的噪声有效：准静态漂移被折返，τ 期间翻转的噪声（T1 型、白噪声）幸存。验证：图 C 橙线比蓝线撑得久；把 σ_δ 拖到 0，两者塌到一起——已无静态噪声可折。失效条件：π 脉冲本身不理想（有限时长、误差、期间照常 T1 衰减），序列越长这笔开销越大。"),
	("整理", texblock(raw"T_2^{*} \le T_2 \le 2T_1"), "三个时间的层级关系：T2*（含静态漂移）≤ T2（回波 / 本征）≤ 2T1（弛豫硬上限）。实验顺序由此而来：先测 T1，再测 T2*（Ramsey），再测 T2（回波）；三者的差值就是噪声谱信息。改变回波脉冲间距扫出噪声功率谱，就是今天「量子噪声谱学」的祖先（CPMG 等动态解耦是它的升级版）。验证：读数卡四行数字的大小顺序应满足这条链。"),
	];
	lead="这条推导的脉络：先立规矩（第 1–2 步：主方程与两条噪声通道），再分别看两条通道各自的独立后果（第 3–5 步：L₁ 只动布居、L_φ 只动相干），合起来得到 T2 的预算公式（第 6 步：1/T2 = 1/(2T1) + 1/Tφ）。然后把相干放进 Ramsey 序列里测出来（第 7–8 步），把真实器件的准静态漂移加进来得到 T2*（第 9–10 步），最后用自旋回波把静态部分折掉、露出真正的 T2（第 11–12 步）。建议对照图 A–D 逐步看：每一步都写了在哪张图或哪行读数上验证；第 6 步的 1/2 因子与第 9 步的高斯平均是全页两个枢纽。",
	result="结论落回读数卡：T1 = $(T1us) μs、Tφ = $(Tphius) μs ⇒ 理论 T2 = 1/(1/(2T1) + 1/Tφ) = $(T2_theory_s) μs（硬上限 2T1 = $(2T1us) μs），实测 $(T2_meas_s) μs（图 C 橙线）；准静态 σ_δ = $(σ_kHz) kHz ⇒ 理论 T2* ≈ $(string(round(1 / (sqrt(2) * π * σ_kHz / 1e6) / 1000, digits=2))) μs，实测 $(T2star_meas_s) μs（图 B 青色点线的 1/e 点）。四条曲线各司其职：图 A 管 T1、图 B 管 T2*、图 C 管 T2，图 D 把「匀速转圈 + 逐渐缩短」画在 IQ 平面上——平均矢量的长度就是 |⟨ρ₀₁⟩|。"),
deep_dive("适用边界与工程数值：高斯包络、1/f 噪声与 2T1 天花板", """
<p>本页的 T2* 包络 $(tex(raw"e^{-(2\pi\sigma_\delta\tau)^2/2}")) 假设噪声是<b>准静态</b>的：单次实验里 δ 不变、实验之间随机抽样。这只在噪声相关时间 ≫ 序列时长（几十 μs）时成立，正是 1/f 电荷/磁通噪声的低频段。若噪声在 τ 期间就翻转（相关时间与 τ 同量级），高斯平均失效，包络更接近指数、回波的折返效率也下降——此时要用 CPMG / UDD 等多脉冲序列，有效相干随脉冲数 n 延长（常见标度 $(tex(raw"T_2 \propto n^\gamma"))，γ 约 0.5–1）。</p>
<p>工程数值：超导 transmon 的 T1 普遍 10–500 μs（典型 50–200 μs），T2 ≤ 2T1；准静态失谐宽度 σ_δ 约 1–100 kHz，对应 T2* 约 1–20 μs；单比特门 20–40 ns，所以「算得深」= 在 T2 里塞进尽可能多的门（几百到上千个）。测量协议固定：T1 用 π 脉冲后衰减、T2* 用 Ramsey、T2 用 Hahn 回波；三者交叉核对，不满足 $(tex(raw"T_2^{*} \le T_2 \le 2T_1")) 的数据说明标定有问题（常见原因：σ_δ 没归零、拟合窗口含脉冲段、读出对比度 V 被误当相干幅度）。</p>
""", tone="detail"),
deep_dive("常见误解：T2* 短就是器件烂？回波能把 T2 救到任意长？", """
<p>误解一：「T2* 只有几 μs，这器件没救了」。T2* 短最常见的原因是<b>准静态失谐漂移</b>（磁通线噪声、电荷漂移、邻居比特的 ZZ 漂移），它是可折返的——自旋回波、动态解耦、用 Ramsey 当误差信号做频率锁定，都能把有效相干拉回接近 T2。评价器件先看 T2 与 2T1；T2* 只是「不做任何保护」时的下限。</p>
<p>误解二：「回波加得越多，T2 就能无限延长」。回波只能折返<b>时间上不变</b>的相位；$(tex(raw"1/T_2 = 1/(2T_1) + 1/T_\phi")) 里由 T1 决定的那一半速率谁也折不掉，所以 $(tex(raw"T_2 \le 2T_1")) 是硬天花板。快噪声（白噪声、准粒子爆发）同样穿透回波。还有一笔常被忽略的开销：π 脉冲自己不理想——有限时长、有误差、期间比特照常衰减，序列越长这笔账越大。判断你是否陷入此误解：如果你把 2T1 当成「回波的预期值」，请回到推导第 6 步重看那个 1/2。</p>
""", tone="warn"),
)

# ╔═╡ e0000000-0000-4000-8000-00000000001d
tryout([
	("亲手复现 1/T2 = 1/(2T1) + 1/Tφ", "<b>动机</b>：把公式变成手感，看清「弛豫地板」与「纯退相预算」谁在限制你。<br><b>做法</b>：固定 T1 = 30 μs、σ_δ = 0，把 Tφ 从 80 拖到 10，盯读数卡「T2 理论 / 实测」与图 C 橙线。",
	 "<b>看什么</b>：T2 从 ~34 μs（1/60 + 1/80）一路掉到 ~9 μs（1/60 + 1/10），理论与实测始终吻合，且永远 ≤ 2T1 = 60 μs。<br><b>说明什么</b>：1/(2T1) 是还不掉的地板——Tφ 拖到 80 μs 以上时 T2 几乎不再改善；Tφ 很小时纯退相反超为主导。<br><b>如果没看到</b>：T2 不随 Tφ 动 → 确认 σ_δ 拖到了 0（高斯混响会把差异盖住）；理论/实测分家 → 看拟合窗口是否踩到 π/2 脉冲段。"),
	("亲眼看见 T2* ≪ T2", "<b>动机</b>：准静态噪声是真实器件 T2* 短的头号原因，而且它可救——先看清它的指纹。<br><b>做法</b>：σ_δ 拖到 100 kHz，对比图 B 与图 C。",
	 "<b>看什么</b>：图 B 的条纹在 ~2 μs 内被抹平（T2* ≈ 1/(√2 π σ_δ) ≈ 2.2 μs），图 C 橙线却还在 10 μs 尺度上完好。<br><b>说明什么</b>：静态失谐被回波折返的直接证据；把 σ_δ 拖回 0，两条曲线的包络重合——说明剩下的差别全是静态噪声贡献的。<br><b>如果没看到</b>：图 C 也塌得很快 → Tφ 太小或 T1 太差，先把 Tphius 放大再看。"),
	("用 Ramsey 当频率计", "<b>动机</b>：Ramsey 的第一用途不是测 T2*，而是测频率——亲手数一次条纹。<br><b>做法</b>：σ_δ = 0、名义失谐拖到 20 kHz、τmax 拖到 30 μs。",
	 "<b>看什么</b>：条纹周期 = 50 μs（= 1/δ），图 D 的红点在赤道面匀速转圈、平均矢量只缩短不打转。<br><b>说明什么</b>：数条纹周期就能定 δ；真实器件用它把比特锁回工作点，也顺手量出邻居 ZZ 漂移带来的频率抖动。<br><b>如果没看到</b>：只有半个条纹 → τmax 不够（至少要覆盖 2 个周期）；条纹完全平掉 → δ 被拖成 0，或者 σ_δ 忘了归零。"),
	("回波为什么救不了 T1", "<b>动机</b>：分清「折返相位」与「挽回能量」——这是所有动态解耦技术的边界。<br><b>做法</b>：把 T1 拖到 5 μs（很差的器件），对比 Ramsey 与回波曲线。",
	 "<b>看什么</b>：两条曲线一起变快，回波的领先优势缩小；读数卡 T2 被压到 ≤ 2T1 = 10 μs。<br><b>说明什么</b>：π 脉冲只折返静态失谐，折不回 |1⟩ 的真实衰减——T1 是谁也绕不开的地板（推导第 6 步的 1/(2T1)）。<br><b>如果没看到</b>：回波反而明显更慢 → 核对横轴：回波曲线画在 2τ 轴上，同一 x 处它的实际时长是蓝线的两倍。"),
])

# ╔═╡ e0000000-0000-4000-8000-00000000001e
quiz([
	("一台比特 T1 = 40 μs、Tφ = 30 μs，T2 最接近多少？",
	 ["30 μs", "≈22 μs", "60 μs", "40 μs"], 2,
	 "1/T2 = 1/(2·40) + 1/30 = 0.0125 + 0.0333 = 0.0458 /μs → T2 ≈ 21.8 μs，本例被纯退相主导。<b>错误选项辨析</b>：「30 μs」是 Tφ 本身，忘了弛豫还要叠加 1/(2T1)；「60 μs」是 2T1 硬上限，那是天花板不是实际值（只有 Tφ → ∞ 才取到）；「40 μs」是 T1，混淆了布居寿命与相干寿命。"),
	("Ramsey 条纹的周期由什么决定？",
	 ["T2*", "驱动幅度 drvamp", "失谐 δ", "T1"], 3,
	 "P₁ ∝ cos(2πδτ)，周期 = 1/δ。<b>错误选项辨析</b>：T2* 只决定条纹能活多久（包络衰减），不改周期——条纹会「糊」但不会变密；drvamp 只决定 π/2 脉冲的时长（T90 = 1/(4·drvamp·n01)），不进条纹公式；T1 只是给条纹整体加衰减。δ → 0 时条纹退化成水平线，所以测频时要故意加一个已知失谐。"),
	("为什么自旋回波测出的 T2 通常比 Ramsey 的 T2* 长？",
	 ["回波用了更强的驱动", "回波抵消了准静态失谐", "回波能让 T1 变长", "回波没有测量噪声"], 2,
	 "τ 中点的 π 脉冲把静态失谐的累积相位折返（推导第 11 步的 Δφ = 2πδτ − 2πδτ = 0），只剩 τ 期间真正变化的噪声幸存。<b>错误选项辨析</b>：π 与 π/2 脉冲用同一幅度 drvamp，只是时长翻倍，不是「更强」；回波不改 T1，2T1 的硬上限照样生效；读出噪声与弛豫都还在，回波只针对<b>静态相位</b>。这正是 Hahn 回波成为主流相干测量的原因。"),
])

# ╔═╡ e0000000-0000-4000-8000-00000000001f
@htl("""
<div style="font-size:14.5px;color:#33384D;line-height:2.0;margin-top:6px">
<p><b>核心机制：</b>弛豫通道 L₁ 只动布居（T1），纯退相通道 L_φ 只动相干（Tφ），两者对相干的贡献相加：1/T2 = 1/(2T1) + 1/Tφ，且 T2 ≤ 2T1。Ramsey 把失谐转成条纹（周期 1/δ），准静态噪声把条纹抹平成高斯包络 T2* ≈ 1/(√2 π σ_δ)；自旋回波用一个 π 脉冲把静态相位折返，露出真正的 T2。四个时间对应四张图：图 A 管 T1、图 B 管 T2*、图 C 管 T2、图 D 画出「转圈 + 缩短」的全过程。</p>
<p><b>常见误解：</b>「T2* 短就是器件烂」——错，多半是准静态漂移（可回波/动态解耦/频率锁定救回），先看 T2 与 2T1；「回波能把 T2 救到任意长」——错，1/(2T1) 谁也折不掉，2T1 是硬天花板；「1/(2T1) 写成 1/T1」——最常见的因子 2 错误；「π 脉冲是免费的」——它有限时长、有误差、期间照常衰减，序列越长开销越大。</p>
<p><b>真实器件里什么样：</b>超导 transmon 的 T1 普遍 50–500 μs、T2 20–300 μs、T2* 常见 1–20 μs（σ_δ 约 1–100 kHz），单比特门 20–40 ns——一台处理器能算多深，取决于这些 μs 里能塞进多少个门。实验室的标准流程是 T1 → Ramsey(T2*) → Hahn(T2) 三连测，日常用 Ramsey 锁频率、用回波和 CPMG 对抗 1/f 噪声。</p>
<p><b>下一步：</b><b>两比特耦合</b>看 iSWAP 如何交换状态、always-on ZZ 如何反过来制造频率漂移（正是 T2* 的一个来源）；<b>磁通调谐</b>看 E_J(Φ) 如何把能级拧成扇形图、如何用甜点把 σ_δ 压下去；DRAG 与色散读取则分别管「门做快」和「读出不毁相干」。</p>
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
