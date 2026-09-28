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

# ╔═╡ c3000001-0000-4000-8000-000000000001
begin
	using PlutoUI, PlotlyBase, Statistics, HypertextLiteral
	include(joinpath(@__DIR__, "..", "src", "OverQubit.jl"))
	using .OverQubit
	setup_page()
end

# ╔═╡ c3000001-0000-4000-8000-000000000002
md"""### ① 这一页讲什么：CZ 门做出来之后，怎么把它「校」到能用

⑧ 把 CZ 的原理拆开了：一次磁通脉冲穿越 |11⟩ ↔ |02⟩ avoided crossing。真实实验里这只是
一半，另一半是**校准**：脉冲幅度、脉冲长度两条旋钮各有一个目标（幅度管「开进去多深」、
长度管「攒多少相位」），而误差全都在同一个二维图上打架——**chevron 图**。

这一页把校准流程做成可交互的：从谱学定工作磁通，到二维 chevron 粗扫，再到两条 fringe
细扫，最后拆一遍误差预算。所有读数都来自上一页同一个引擎的真实演化。"""

# ╔═╡ c3000001-0000-4000-8000-000000000003
oq_stack(
banner("OVERQUBIT · 两比特门", "CZ 门校准方案：chevron、相位 fringe 与误差预算",
	"两个旋钮（脉冲幅度 / 长度）+ 一个观测（条件相位）→ 用二维 chevron 扫描把工作点圈出来，再用 fringe 精调，最后拆误差"; icon="pair"),
HTMLStr("""<div style="margin-top:10px;font-size:13.5px;color:#33384D;line-height:1.9;max-width:78ch"><b>读完这页你能：</b>
① 看懂 chevron 热图的<b>暗脊</b>，并从它的斜率读出每个旋钮的敏感度（$(tex(raw"d\varphi/dt \approx 0.2")) rad/ns）；
② 走一遍完整校准流程：谱学定 $(tex(raw"\Phi^{*}")) → chevron 粗扫 → fringe 精调 → 复核；
③ 拆一个误差预算，指出哪一项主导、下一步该优化什么。</div>"""),
)

# ╔═╡ c3000001-0000-4000-8000-000000000004
lesson_nav([
	("①", "transmon 能级与量子化", "done"),
	("②", "单比特门与 Rabi", "done"),
	("③", "DRAG 泄漏压制", "done"),
	("④", "色散读取 S21", "done"),
	("⑤", "两比特耦合与 iSWAP", "done"),
	("⑥", "磁通调谐与能级扇形图", "done"),
	("⑦", "T1 / T2 / Ramsey", "done"),
	("⑧", "CZ 门实现原理", "done"),
	("⑨", "CZ 门校准方案", "current"),
])

# ╔═╡ c3000001-0000-4000-8000-000000000005
oq_stack(
callout("CZ 门做出来之后，怎么知道它好不好？这一页把「校准」拆成可执行的流程：
先用<b>二维扫描（chevron）</b>找到相位为 $(tex(raw"\pi")) 的等高线，再用<b>一维细扫（fringe）</b>把两个旋钮分别钉死，
最后用<b>误差预算</b>告诉你哪一项主导、还剩多少改进空间。
这套流程在真实器件里每天都在跑——它同时回答了「工作点在哪」和「这个门能用到多好」。
建议读法：先看 A 图的暗脊（工作点的轨迹）→ 拖 B/C 图的旋钮看 fringe 怎么移 → 最后读误差预算那一行，知道卡在哪。",
	tone="info", title="① 这一页讲什么：把「好门」变成可测量的数字"),
concept_cards([
	("校的是什么", "两个旋钮：<b>脉冲幅度 $(tex(raw"\Phi_{pk}"))</b>（决定能级图被拧到什么程度，即穿越多深）与<b>脉冲长度 $(tex(raw"t"))</b>（决定攒多久相位）。<br><br>目标只有一个：$(tex(raw"\varphi_{\mathrm{CZ}} = \pi"))。副产品要盯住：<b>泄漏</b>（人口留在 $(tex(raw"|0,2\rangle"))）与<b>退相干损失</b>（门太长时 T2 吃掉对比度）。<br><br>注意两个旋钮不是独立的：加大幅度可以让门变短，但也会改变绝热性要求——校准是在二维曲面上找一个点，不是各调各的。"),
	("怎么测", "教科书序列：$(tex(raw"|+\rangle_1|1\rangle_2 \to \mathrm{CZ} \to X(90^\circ)_1 \to \text{read } q_1"))。$(tex(raw"\theta=90^\circ")) 时 $(tex(raw"P_1 = \sin^2(\delta\varphi/2)"))——<b>条件相位偏离 π 多少，直接翻译成布居误差</b>。<br><br>这一步是全部测量的基础：相位本身不可测，布居可测。$(tex(raw"\delta\varphi = 0.03")) rad 对应 $(tex(raw"P_1 \approx 7\times 10^{-4}"))，几乎全暗——所以暗瓣就是 $(tex(raw"\varphi_{\mathrm{CZ}} = \pi")) 的等高线。"),
	("为什么要参考序列", "同一序列再跑一遍但 qubit2 置 $(tex(raw"|0\rangle"))：此时没有条件相位，$(tex(raw"P_1")) 是一条不动的高基线。两遍相减得到 $(tex(raw"\varphi_{00}-\varphi_{01}-\varphi_{10}+\varphi_{11}"))，把 <b>13 GHz 级动态相位</b>整体减掉。<br><br>物理上这一步是必须的：qubit1 自己的相位以 13 GHz 转圈，直接读毫无意义。实验上叫「参考相减」，数值上就是 <span class=\"oq-kbd\">cz_zcorrect</span> 的虚拟 Z 校正。"),
	("chevron 的形状", "二维扫（幅度 × 长度），$(tex(raw"P_1")) 画成热图。满足 $(tex(raw"\varphi = \pi")) 的地方是一条<b>斜斜的暗脊</b>——因为「幅度定相位的量级、长度定精细值」，两个旋钮可以互相补偿，等值线于是是斜的而不是竖直/水平。<br><br>斜率还有实用意义：它直接给出<b>每个旋钮的敏感度</b>（$(tex(raw"d\varphi/dt \approx 0.2")) rad/ns），也就是时钟要稳到多少 ns、幅度要稳到多少 $(tex(raw"\mathrm{m}\Phi_0"))。"),
]),
callout("滑块分两组：<b>器件组</b>（EJ/EC/ratio2）决定 chevron 长什么样，<b>工作点组</b>（amp_phi/t_pulse/shape_sel）决定你站在暗脊的哪一点。<br><br><b>建议动的顺序</b>：先固定器件，只动 t_pulse 沿暗脊走一趟（④ 任务 1）——看清「长度定精细值」；再动 amp_phi 看泄漏怎么涨（任务 2、3）；最后换 shape_sel 对比方沿/平滑沿。器件组最后动，动完要重新找暗脊。",
	tone="tip", title="③ 调参前先看这里：先动哪个、为什么"),
)

# ╔═╡ c3000001-0000-4000-8000-000000000006
callout("本页所有量都来自 ⑧ 的同一个引擎（<span class=\"oq-kbd\">cz_pair</span> + <span class=\"oq-kbd\">cz_evolve</span>），没有引入任何新物理。chevron 网格只依赖器件参数（E<sub>J</sub>、E<sub>C</sub>、耦合、频率比），细扫曲线额外依赖当前脉冲参数。qubit 仍取 3 能级，脉冲按分段常值推进。",
	tone="info", title="阅读前提")

# ╔═╡ c3000001-0000-4000-8000-000000000007
md"""### ③ 调参（器件参数决定 chevron；下方两个滑块决定当前工作点）"""

# ╔═╡ c3000001-0000-4000-8000-000000000008
@bind EJ Slider(5:0.5:40; default=20)

# ╔═╡ c3000001-0000-4000-8000-000000000009
@bind EC Slider(0.05:0.01:0.5; default=0.30)

# ╔═╡ c3000001-0000-4000-8000-00000000000a
@bind ratio2 Slider(1.0:0.01:1.45; default=1.20)

# ╔═╡ c3000001-0000-4000-8000-00000000000b
@bind g_c Slider(0.0:0.005:0.20; default=0.03)

# ╔═╡ c3000001-0000-4000-8000-00000000000c
@bind amp_phi Slider(0.0:0.002:0.30; default=0.073)

# ╔═╡ c3000001-0000-4000-8000-00000000000d
@bind t_pulse Slider(10:0.5:60; default=37.5)

# ╔═╡ c3000001-0000-4000-8000-00000000000e
@bind shape_sel Select(["方沿", "平滑沿"]; default="平滑沿")

# ╔═╡ c3000001-0000-4000-8000-00000000000f
@bind T1q Slider(5:2:100; default=30)

# ╔═╡ c3000001-0000-4000-8000-000000000010
begin
	# 器件 + 谱学工作点（chevron 只依赖这些 → 调脉冲滑块时不会重算网格）
	NCUT = 40
	shape_kind = shape_sel == "方沿" ? :flat : :taper
	dev = cz_pair(EJ, EJ * ratio2, EC, g_c; nlev=3, ncut=NCUT)
	phi_s, gap_s = cz_crossing(dev; span=0.45, npoints=181)
	ph_s = string(round(phi_s, digits=4)); gap_s = string(round(gap_s * 1000, digits=1))
	nothing
end

# ╔═╡ c3000001-0000-4000-8000-000000000011
begin
	# chevron 二维网格：幅度（相对 Φ*）× 长度
	amps = collect((0.40:0.15:1.25) .* phi_s)
	lens = collect(20.0:5.0:45.0)
	P1m, cphm, lkm = cz_chevron(dev, amps, lens; kind=shape_kind, dt=0.2)
	# 当前工作点落在哪一格
	iamp = argmin(abs.(amps .- amp_phi)); ilen = argmin(abs.(lens .- t_pulse))
	p1_grid = P1m[iamp, ilen]
	p1g_s = string(round(p1_grid, digits=3)); cmp_grid_s = string(round(100cphm[iamp, ilen], digits=2))
	nothing
end

# ╔═╡ c3000001-0000-4000-8000-000000000012
begin
	# 当前工作点的完整评估 + 长度/幅度细扫
	r = cz_evolve(dev, amp_phi, t_pulse; kind=shape_kind, dt=0.05)
	phase, phase_err, leak, f_proc, f_state = cz_metrics(r)
	p1, in_sub = cz_ramsey(cz_zcorrect(r), r.nlev)
	p1a, p1b, phase_pair = cz_ramsey_pair(r)
	# 两条细扫 fringe
	lens_fine = collect(range(t_pulse - 8, t_pulse + 8; length=17))
	function fringe_len(L)
		rr = cz_evolve(dev, amp_phi, L; kind=shape_kind, dt=0.1)
		(cz_conditional_phase(rr.Urel, dev.nlev), cz_ramsey(cz_zcorrect(rr), dev.nlev)[1], cz_leakage(rr.U, dev.nlev))
	end
	fL = [fringe_len(L) for L in lens_fine]
	cph_len = [fL[i][1] for i in 1:length(lens_fine)]
	p1_len = [fL[i][2] for i in 1:length(lens_fine)]
	lk_len = [fL[i][3] for i in 1:length(lens_fine)]
	# 幅度 fringe：固定长度扫峰值磁通（注意参数顺序：cz_evolve(dev, 幅度, 长度)）
	function fringe_amp(a)
		rr = cz_evolve(dev, a, t_pulse; kind=shape_kind, dt=0.1)
		(cz_conditional_phase(rr.Urel, dev.nlev), cz_ramsey(cz_zcorrect(rr), dev.nlev)[1], cz_leakage(rr.U, dev.nlev))
	end
	amps_fine = collect(range(max(amp_phi - 0.02, 0.0), amp_phi + 0.02; length=17))
	fA = [fringe_amp(a) for a in amps_fine]
	cph_amp = [fA[i][1] for i in 1:length(amps_fine)]
	p1_amp = [fA[i][2] for i in 1:length(amps_fine)]
	lk_amp = [fA[i][3] for i in 1:length(amps_fine)]
	# 退相干估计（解析）：脉冲期间的对比度损失
	T2 = 2 * T1q * 1000                        # 纯 T1 极限：1/T2 = 1/(2T1)
	contrast_loss = 1 - exp(-t_pulse / T2)
	t1_loss = 1 - exp(-t_pulse / (T1q * 1000))
	# 读数字符串
	phase_s = string(round(phase, digits=3)); err_s = string(round(phase_err, digits=3))
	err_deg_s = string(round(rad2deg(phase_err), digits=1))
	leak_s = string(round(100leak, digits=2)); fstate_s = string(round(100f_state, digits=2))
	fproc_s = string(round(100f_proc, digits=2)); p1_s = string(round(p1, digits=4))
	p1ref_s = string(round(p1b, digits=3))
	contrast_s = string(round(100contrast_loss, digits=3))
	t1l_s = string(round(100t1_loss, digits=3))
	amp_ratio_s = string(round(100 * abs(amp_phi / max(phi_s, 1e-9)), digits=0))
	# fringe 斜率（稳定性指标）
	slope_len = (cph_len[end] - cph_len[1]) / (lens_fine[end] - lens_fine[1])
	slope_len_s = string(round(slope_len, digits=3))
	nothing
end

# ╔═╡ c3000001-0000-4000-8000-000000000013
stat_row([
	("条件相位 φ<sub>CZ</sub>（mod 2π）", "$(phase_s) rad", "目标 π；残差 $(err_s) rad = $(err_deg_s)°", phase_err < 0.05 ? "#22C3A6" : "#F5A623"),
	("校准读数为 P<sub>1</sub> = sin²(δφ/2)", "$(p1_s)", "参考序列基线 $(p1ref_s)；δφ = $(err_s) rad", "#4C6FFF"),
	("泄漏（|0,2⟩ 等）", "$(leak_s)%", "chevron 对应格 $(p1g_s)", "#B8812E"),
	("门保真度（4 态 / 过程）", "$(fstate_s)% / $(fproc_s)%", "已含虚拟 Z 校正口径", "#7B61FF"),
	("相位对长度的敏感度", "$(slope_len_s) rad/ns", "→ 1 ns 抖动 ≈ $(string(round(rad2deg(abs(slope_len)), digits=1)))° 相位误差", "#1A1A2E"),
	("脉冲期间退相干损失", "$(contrast_s)%", "T1 弛豫 $(t1l_s)%（T2 = 2T1 = $(string(round(T2 / 1000, digits=0))) μs）", "#22C3A6"),
])

# ╔═╡ c3000001-0000-4000-8000-000000000014
callout("先看 <b>A 图</b>（chevron）：暗脊就是 φ<sub>CZ</sub> = π 的等高线，斜率说明两个旋钮可互相补偿；再看 <b>B/C 图</b>（两条 fringe）沿暗脊切一刀，把工作点精调到 P₁ 最低。最后看读数卡：相位残差、泄漏、退相干三项就是全部的误差预算。",
	tone="tip", title="看什么")

# ╔═╡ c3000001-0000-4000-8000-000000000015
begin
	# A1 · chevron 主图：P1 热图（暗 = 条件相位 = π）
	trA = PlotlyBase.GenericTrace[]
	push!(trA, PlotlyBase.heatmap(z=P1m, x=lens, y=amps * 1000; colorscale="Blues", showscale=true,
		colorbar=attr(title="P₁（0 = CZ 正确）", tickfont=attr(size=10, color=SUB),
			titlefont=attr(size=11, color=SUB))))
	push!(trA, PlotlyBase.scatter(x=[t_pulse], y=[amp_phi * 1000]; mode="markers",
		marker=attr(size=13, color="#FF7A7A", line=attr(color="white", width=2)),
		name="当前工作点", showlegend=false))
	pa = PlotlyBase.Plot(trA, layout_base(height=430,
		title="A1 · chevron：|+⟩₁|1⟩₂ → CZ → X(90°)₁ → 读 qubit1 的 P₁",
		xtitle="脉冲长度 (ns)", ytitle="脉冲峰值磁通 Φ<sub>pk</sub> (mΦ₀)",
		legend_y=1.02, legend_x=0.35))
	# A2 · 泄漏热图（同坐标轴）
	pe2 = PlotlyBase.heatmap(z=lkm * 100, x=lens, y=amps * 1000; colorscale="Reds", showscale=true,
		colorbar=attr(title="泄漏 (%)", tickfont=attr(size=10, color=SUB),
			titlefont=attr(size=11, color=SUB)))
	pb = PlotlyBase.Plot(pe2, layout_base(height=390,
		title="A2 · 同参数下的泄漏：暗脊附近必须同时找「P₁ 低 + 泄漏低」的交点",
		xtitle="脉冲长度 (ns)", ytitle="脉冲峰值磁通 Φ<sub>pk</sub> (mΦ₀)"))
	oq_stack(plotly_html("oq_czc_chev", pa; height=440), plotly_html("oq_czc_chevlk", pb; height=400))
end

# ╔═╡ c3000001-0000-4000-8000-000000000016
figure_note("A1 的暗脊之所以是斜的：幅度决定「开进 avoided crossing 多深」（相位的量级），长度决定「攒多久」（相位的精细值）——两者可以互相补偿，等值线自然倾斜。A2 揭示另一半真相：<b>并不是每个暗脊位置都可用</b>——大幅度 + 短长度会把布居甩到 |0,2⟩ 出不来，那种「暗」是泄漏造成的假暗。")

# ╔═╡ c3000001-0000-4000-8000-000000000017
begin
	# B · 长度 fringe：信号 vs 参考（同一序列，qubit2 置不同态）
	tr = PlotlyBase.GenericTrace[]
	push!(tr, PlotlyBase.scatter(x=lens_fine, y=p1_len; mode="lines+markers",
		name="信号：qubit2 = |1⟩", line=attr(color=PAL[1], width=2.5)))
	push!(tr, PlotlyBase.scatter(x=lens_fine, y=fill(p1b, length(lens_fine)); mode="lines",
		name="参考：qubit2 = |0⟩（高频基线）", line=attr(color="#8A90AD", width=1.5, dash="dash")))
	push!(tr, PlotlyBase.scatter(x=[t_pulse], y=[p1]; mode="markers",
		marker=attr(size=12, color="#FF7A7A", line=attr(color="white", width=2)), showlegend=false))
	lay = layout_base(height=340, title="B · 长度 fringe（固定当前幅度）：P₁ 最低点就是 φ<sub>CZ</sub> = π",
		xtitle="脉冲长度 (ns)", ytitle="P₁", yrange=[0, 1.05])
	lay.annotations = [attr(x=t_pulse, y=p1, text="当前工作点 P₁ = $(p1_s)", showarrow=true,
		font=attr(size=11, color="#C2543A"), yref="paper")]
	pp = PlotlyBase.Plot(tr, lay)
	# C · 幅度 fringe + 泄漏
	tr2 = PlotlyBase.GenericTrace[]
	push!(tr2, PlotlyBase.scatter(x=amps_fine * 1000, y=p1_amp; mode="lines+markers",
		name="信号 P₁（qubit2 = |1⟩）", line=attr(color=PAL[1], width=2.5), yaxis="y"))
	push!(tr2, PlotlyBase.scatter(x=amps_fine * 1000, y=lk_amp .* 100; mode="lines+markers",
		name="泄漏 (%)", line=attr(color="#F5A623", width=2.5), yaxis="y2"))
	lay2 = layout_base(height=340, title="C · 幅度 fringe（固定当前长度）：同时盯 P₁ 最低与泄漏最小",
		xtitle="脉冲峰值磁通 Φ<sub>pk</sub> (mΦ₀)", ytitle="P₁")
	lay2.yaxis2 = attr(title="泄漏 (%)", overlaying="y", side="right",
		gridcolor="rgba(0,0,0,0)", zerolinecolor="rgba(0,0,0,0)",
		tickfont=attr(size=11, color="#B8812E"), titlefont=attr(size=12, color="#B8812E"))
	pc = PlotlyBase.Plot(tr2, lay2)
	oq_stack(plotly_html("oq_czc_fringeL", pp; height=350), plotly_html("oq_czc_fringeA", pc; height=350))
end

# ╔═╡ c3000001-0000-4000-8000-000000000018
readout_table([
	("① 谱学定 Φ*（idle bias + 谱扫）", "Φ* = $(ph_s) Φ₀（avoided crossing 最低点，2V = $(gap_s) MHz）", "idle 点必须比 Φ* 高频——磁通只会拧小 E<sub>J</sub>"),
	("② 粗扫 chevron（幅度 × 长度）", "当前网格最小 P₁ = $(string(round(minimum(P1m), digits=4)))，对应暗脊斜率 ≈ $(slope_len_s) rad/ns", "先在 log/线性坐标里肉眼找暗脊"),
	("③ 长度 fringe 精调（固定幅度）", "当前位置 φ<sub>CZ</sub> = $(phase_s) rad，残差 $(err_s) rad（$(err_deg_s)°）", "斜率 $(slope_len_s) rad/ns → 脉冲长度要稳到 ~0.1 ns 才够"),
	("④ 幅度 fringe 复核", "幅度 = Φ* 的 $(amp_ratio_s)%；泄漏 $(leak_s)%", "同时满足「P₁ 低 + 泄漏低」才收工"),
	("⑤ 相位残差（虚拟 Z 校正后）", "残差 $(err_s) rad → 等效单比特 Z 误差 $(err_deg_s)°", "由编译器或虚拟 Z 门吸收"),
	("⑥ 泄漏", "$(leak_s)% 跑到 |0,2⟩", "会被读成「第三态」，等效布居误差；靠脉冲长度/沿形压制"),
	("⑦ 脉冲期间退相干（T1 = $(T1q) μs）", "对比度损失 $(contrast_s)%，其中 T1 弛豫 $(t1l_s)%", "纯 T1 极限下 T2 = 2T1；这是 CZ 只能做几十 ns 的原因之一"),
	("⑧ 合成门误差估计", "≈ 1 − (1 − 相位残差/π)(1 − 泄漏)(1 − 退相干) ≈ $(string(round(100 * (1 - (1 - phase_err / π) * (1 - leak) * (1 - contrast_loss)), digits=2)))%", "真实机器还要加串扰、时钟抖动、测量 SPAM 误差"),
]; title="⑨ 校准流程与误差预算（一行一步，数字全部来自当前参数）")

# ╔═╡ c3000001-0000-4000-8000-000000000019
callout("三项误差里<b>相位残差</b>通常主导：$(err_s) rad ≈ $(err_deg_s)°，折算成等效单比特相位误差；泄漏 $(leak_s)% 次之；退相干只有 $(contrast_s)%——所以「把相位拧准」比「把门做快」更值钱。但斜率 $(slope_len_s) rad/ns 说明 1 ns 的时钟抖动就已经造成 $(string(round(rad2deg(abs(slope_len)), digits=1)))° 误差，长脉冲又有退相干：这就是真实器件把 CZ 放在 25–40 ns 的原因。",
	tone="info", title="误差预算怎么读")

# ╔═╡ c3000001-0000-4000-8000-00000000001a
divider()

# ╔═╡ c3000001-0000-4000-8000-00000000001b
oq_stack(
derivation("⑨ 推导溯源：从测量序列到校准好的 CZ",
	[
	("整理", texblock(raw"\text{两个旋钮 } (\Phi_{pk},\ t) \;\to\; \varphi_{\mathrm{CZ}} = \pi \quad ; \quad \text{副产物：泄漏、退相干损失}"),
		"先明确要校什么：<b>两个旋钮、一个目标</b>。幅度决定穿越 avoided crossing 的深度，长度决定在相互作用区停留多久。<br><br>注意目标是 $(tex(raw"\varphi_{\mathrm{CZ}}=\pi"))，不是「相位最大」——相位可以绕很多圈，我们只要它落在 $(tex(raw"\pi")) 这个值上（模 $(tex(raw"2\pi"))）。"),
	("定义", texblock(raw"|+\rangle_1|1\rangle_2 \to \mathrm{CZ} \to X(\theta)_1 \to \text{read } q_1"),
		"测量序列：把 qubit1 放到赤道上，让 CZ 累积相位，再用一个 $(tex(raw"\theta")) 脉冲把相位<b>转成布居</b>，最后读 qubit1。<br><br>为什么要先放叠加态：条件相位作用在 $(tex(raw"|1,1\rangle")) 上，只有 qubit1 处于叠加时它才是可观测的相对相位。"),
	("定义", texblock(raw"\theta = \frac{\pi}{2}\ \text{脉冲的相位：}\ 0^\circ=\sigma_x,\ 90^\circ=\sigma_y"),
		"末脉冲的相位 $(tex(raw"\theta")) 决定测的是布居还是相干：<b>$(tex(raw"90^\circ"))（绕 +y）把 z 分量翻出来测布居</b>，$(tex(raw"0^\circ")) 测的是实部。<br><br>校准里固定用 $(tex(raw"90^\circ"))，因为 $(tex(raw"P_1")) 对 $(tex(raw"\delta\varphi")) 是偶函数、零点最锐。"),
	("整理", texblock(raw"\theta = 90^\circ\!:\qquad P_1 = \sin^2\!\Big(\frac{\delta\varphi}{2}\Big), \qquad \delta\varphi = (\varphi_{11}-\varphi_{01})-\pi"),
		"核心转换式：<b>相位偏差 → 布居误差</b>。$(tex(raw"\delta\varphi = 0")) 时 $(tex(raw"P_1 = 0"))（全暗），偏差越大越亮。<br><br>灵敏度很高：$(tex(raw"\delta\varphi = 0.03")) rad 就给出 $(tex(raw"P_1 \approx 7\times 10^{-4}"))，这正是暗瓣能用来定零点的原因。"),
	("定义", texblock(raw"\varphi_{\mathrm{CZ}} = \varphi_{00}-\varphi_{01}-\varphi_{10}+\varphi_{11} \pmod{2\pi}"),
		"参考序列：qubit2 置 $(tex(raw"|0\rangle")) 再跑一遍，它不感受 CZ，$(tex(raw"P_1")) 停在高基线。两遍相减就是上式。<br><br>为什么要减三个：qubit1 自己的对角相位以 $(tex(raw"\sim 2\pi\times 13")) GHz 转圈，直接读会完全混叠。"),
	("整理", texblock(raw"\varphi_{\mathrm{CZ}}^{\mathrm{ref}} = \varphi_{00}-\varphi_{01}-\varphi_{10} \equiv \varphi_{\mathrm{Z}}"),
		"实验上这一步叫「参考相减」，数值上对应 <span class=\"oq-kbd\">cz_zcorrect</span> 的<b>虚拟 Z 校正</b>：把不需要的动态相位记在一个软件数字里，而不是用微波去实现。<br><br>这也是超导量子计算里最常用的技巧之一——不花时间、不引入误差。"),
	("整理", texblock(raw"\varphi_{\mathrm{CZ}} \approx -\int\!\Delta E(t)\,dt \ \Rightarrow\ \text{等值线}\ \Phi_{pk}\cdot(\text{有效穿越深度})^{-1} \approx \mathrm{const}"),
		"chevron 的形状由积分决定：幅度决定「开进去多深」（相位的<b>量级</b>），长度决定「积分多久」（相位的<b>精细值</b>）。<br><br>两者互相补偿 → 等值线是斜的。A1 图的暗脊斜率 $(tex(raw"d\varphi/dt \approx 0.2")) rad/ns 就是 fringe 的间距尺度。"),
	("微扰", texblock(raw"\text{假暗瓣: 大幅度 + 短长度 } \Rightarrow \text{非绝热激发到}\ |0,2\rangle,\ \ P_1\ \text{变低但门不可用}"),
		"必须同时看泄漏热图（A2）。这一条是校准里最容易踩的坑：<b>暗 ≠ 好</b>。<br><br>非绝热激发把人口留在 $(tex(raw"|0,2\rangle"))，$(tex(raw"P_1")) 因为「态不见了」而变低，但这个门根本不可用——C 图把 $(tex(raw"P_1")) 与泄漏画在同一坐标里就是为了避免这个误判。"),
	("整理", texblock(raw"\text{fringe 细调：定 } t \text{ 扫 } \Phi_{pk}\ (\text{C 图}) \ ;\ \text{定 } \Phi_{pk} \text{ 扫 } t \ (\text{B 图})"),
		"固定其一扫另一个：B 图定长度（fringe 极小点），C 图定幅度（同时检验泄漏）。两者在暗脊上互相补偿。<br><br>真实流程还会<b>交叉验证</b>：交换两个旋钮的角色各走一次，若都在同一个最小值附近，说明没有死锁在局部极值。"),
	("近似", texblock(raw"\text{误差预算：}\ \varepsilon_\varphi,\ \ \varepsilon_{\mathrm{leak}},\ \ \varepsilon_{\mathrm{contrast}} = e^{-t/T_2}"),
		"本页口径三项都可在读数卡核对：相位残差、泄漏、退相干对比度损失。<br><br>通常<b>相位残差主导</b>，但如果把脉冲拖得太短，泄漏会立刻取代它成为第一项——这就是校准要在二维上做的原因。"),
	("整理", texblock(raw"\text{流程：谱学定 }\Phi^{*} \to \text{chevron 粗扫} \to \text{fringe 精调} \to \text{复核} \to \text{泄漏/RB 校验} \to \text{漂移监控}"),
		"这就是真实器件上的完整流程。前四步本页都有对应图，后两步（RB、漂移监控）是工程实践。<br><br>真实器件里相位零点会随温度、磁通偏置漂移，通常每隔几分钟到几小时重校一次。"),
	];
	lead="这条推导回答：<b>「好门」怎么变成可测量、可复现的数字？</b>
	脉络是：明确两个旋钮一个目标（第 1 步）→ 用一条把相位翻译成布居的序列（第 2–4 步）
	→ 用参考序列减掉 13 GHz 的动态相位（第 5–6 步）→ 从积分式读出 chevron 为什么是斜的（第 7 步）
	→ 警告「暗 ≠ 好」（第 8 步）→ 给出细调与误差预算（第 9–11 步）。
	读数卡与 A/B/C 三组图分别对应第 3、5、7 步。",
	result="当前工作点（幅度 = $(tex(raw"\Phi^{*}")) 的 $(amp_ratio_s)%，长度 $(t_pulse) ns，$(shape_sel)）：φ<sub>CZ</sub> = $(phase_s) rad（残差 $(err_s) rad），泄漏 $(leak_s)%，对比度损失 $(contrast_s)%——把这三项按主导程度排一排，就是你下一步该优化的方向。"),
deep_dive("校准里的「斜率」为什么比「零点」更有信息量？", """
<p>暗脊的<b>零点</b>只告诉你工作点在哪；<b>斜率</b>告诉你这个工作点有多脆弱。
A1 图的斜率 $(tex(raw"d\varphi/dt \approx 0.2")) rad/ns 意味着：脉冲长度抖 1 ns，相位就漂 0.2 rad——
已经超过误差预算了。所以真实器件要对时钟抖动提出 ns 级要求。</p>
<p>同理，幅度方向的斜率给出 $(tex(raw"d\varphi/d\Phi_{pk}"))，它决定 DAC 的分辨率要求
（通常是 $(tex(raw"\mathrm{m}\Phi_0")) 量级）。<b>这两个斜率就是「校准曲线的灵敏度」</b>，
也是为什么校准要反复做：器件漂移会让暗脊整体平移，而斜率告诉你需要多稳。</p>
<p>实用技巧：在暗脊上选一个<b>斜率较小</b>的位置（弯曲处），对漂移的敏感度会显著降低——
这是「sweet spot」思想在校准层面的对应物。</p>
""", tone="detail"),
deep_dive("常见误解：校准一次就一劳永逸？", """
<p><b>误解：找到工作点就能一直用。</b>实际上相位零点随温度、磁通偏置、相邻比特状态漂移，
真实器件每隔几分钟到几小时就要重校。<b>斜率越陡，重校越频繁</b>——这就是为什么工程上追求平缓的工作点。</p>
<p><b>误解：误差预算三项是独立的。</b>它们通过脉冲长度耦合：门越长，退相干项 $(tex(raw"e^{-t/T_2}")) 越大，
但绝热性越好、泄漏越小。所以「优化」是找一个三者之和最小的长度，不是分别压每一项。</p>
<p><b>误解：暗瓣中心就是好工作点。</b>暗只代表相位对，不代表泄漏小（见推导第 8 步的假暗瓣）。
必须同时看泄漏热图——<b>暗 + 低泄漏</b>才是真工作点。</p>
""", tone="warn"),
)

# ╔═╡ c3000001-0000-4000-8000-00000000001c
tryout([
	("沿暗脊走一趟", "固定幅度 0.073，拖「脉冲长度」从 29 到 46 ns，看 B 图 P₁ 的极小点与 A1 图里红点的位置变化。",
	 "P₁ 会扫过极小点（当前 $(p1_s)）；红点应该正好落在 A1 图的暗脊上。这就是「粗扫找暗脊、细扫定零点」的一体化演示——注意 B 图的形状是 U 形而不是 cos 形，因为 P₁ = sin²(δφ/2)。"),
	("把两个旋钮对调", "把长度固定到 45 ns（B 图右侧），然后把幅度从 0.073 一路拖到 0.055 附近。",
	 "沿暗脊移动：长度变长后需要的幅度变小（补偿关系），P₁ 能重新回到 0.02 附近——但读数卡的泄漏会同时涨到 ~8%（C 图橙线同步右移）。两个旋钮确实可以互换代价，但泄漏不答应。"),
	("制造一个「假暗瓣」", "把长度拖到 15 ns、幅度拖到 0.1325（≈Φ*），看 C 图泄漏曲线与读数卡。",
	 "P₁ ≈ 0.06 看起来很暗，但泄漏冲到 ~64%——非绝热激发把布居甩到 |0,2⟩ 出不来，P₁ 因为「态不见了」而变低。这种暗暗得没有任何用处，A2 泄漏热图同一格就是深红的。"),
	("换一种波形", "切换「方沿 / 平滑沿」，对比读数卡的泄漏。",
	 "方沿的瞬时会额外制造非绝热激发，泄漏比平滑沿高约一个量级（⑧ 的同一结论在校准口径下重现）。所以真实校准里波形本身也是一个要一起扫的参数。"),
	("退相干什么时候开始咬人", "把 T1 从 100 μs 拖到 5 μs，看读数卡最后一行。",
	 "误差预算里的第三项会从可忽略涨到百分之几——但前两项（相位、泄漏）不变。结论：<b>CZ 的长度上限由退相干定，下限由绝热条件定</b>，中间那一小段才是可用的窗口。"),
])

# ╔═╡ c3000001-0000-4000-8000-00000000001d
quiz([
	("θ=90° 的校准序列里，条件相位偏差 δφ 与测得布居 P₁ 的关系是？",
	 ["P₁ = δφ", "P₁ = sin²(δφ/2)", "P₁ = cos(δφ/2)", "P₁ = δφ²"], 2,
	 "推导第 3 步：|+⟩₁|1⟩₂ 经过 CZ 后相对相位偏了 δφ，再用绕 +y 的 90° 脉冲把它翻到 z 轴上，P₁ = sin²(δφ/2)。δφ = 0.03 rad → P₁ ≈ 7e-4。"),
	("为什么要跑一条 qubit2 置 |0⟩ 的参考序列？",
	 ["为了测 T1", "把 13 GHz 级动态相位减掉，只留条件相位", "为了测泄漏", "为了校准 X90 门"], 2,
	 "qubit1 的对角相位以 ~2π×13 GHz 转圈，直接读会完全混叠；两次相减 = φ<sub>00</sub>−φ<sub>01</sub>−φ<sub>10</sub>+φ<sub>11</sub>（= cz_zcorrect 的虚拟 Z 校正）。"),
	("chevron 图上暗脊为什么是斜的而不是竖直的？",
	 ["磁通串扰", "幅度定相位的量级、长度定精细值，两者可互相补偿", "T1 衰减", "读取误差"], 2,
	 "φ ≈ −∫ΔE(t)dt：幅度决定你能多深地切入 avoided crossing（量级），长度决定积分多久（精细值）。两者互相补偿 → 等值线倾斜。"),
	("大幅度 + 短长度出现 P₁ 很低的区域，为什么不能直接用？",
	 ["那里相位不是 π", "布居被甩到 |0,2⟩ 出不来（泄漏假暗）", "T1 太大", "iSWAP 发生"], 2,
	 "非绝热激发让态离开计算子空间，P₁ 因为「态不见了」而变低。必须同时看泄漏热图/C 图橙线——暗 + 低泄漏才是真工作点。"),
])

# ╔═╡ c3000001-0000-4000-8000-00000000001e
@htl("""
<div style="font-size:14.5px;color:#33384D;line-height:2.0;margin-top:6px">
<p><b>校准的本质是把「两个旋钮」拧到「一个等值线」上。</b>幅度和长度可以互相补偿，所以工作点是一条斜线而不是一个格点；粗扫（chevron）负责找到这条线，细扫（fringe）负责把点定在线上，泄漏与退相干负责告诉你这条线的哪一段是真的可用。</p>
<p><b>为什么这一步必须反复做：</b>斜率 $(slope_len_s) rad/ns 意味着 1 ns 的时钟抖动 ≈ $(string(round(rad2deg(abs(slope_len)), digits=1)))° 相位误差，而相位零点还会随温度与磁通偏置漂移——真实处理器把 CZ 的重新校准当成例行运维。</p>
<p><b>还没展示的：</b>可调耦合器（tunable coupler）路线、CR（cross-resonance）驱动门、iSWAP 的校准流程、泄漏基准测试（leakage RB）。这些都与本页同一套「旋钮 + 等值线 + 误差预算」框架。</p>
</div>
""")

# ╔═╡ Cell order:
# ╟─c3000001-0000-4000-8000-000000000001
# ╠═c3000001-0000-4000-8000-000000000002
# ╠═c3000001-0000-4000-8000-000000000003
# ╠═c3000001-0000-4000-8000-000000000004
# ╠═c3000001-0000-4000-8000-000000000005
# ╠═c3000001-0000-4000-8000-000000000006
# ╠═c3000001-0000-4000-8000-000000000007
# ╟─c3000001-0000-4000-8000-000000000008
# ╟─c3000001-0000-4000-8000-000000000009
# ╟─c3000001-0000-4000-8000-00000000000a
# ╟─c3000001-0000-4000-8000-00000000000b
# ╟─c3000001-0000-4000-8000-00000000000c
# ╟─c3000001-0000-4000-8000-00000000000d
# ╟─c3000001-0000-4000-8000-00000000000e
# ╟─c3000001-0000-4000-8000-00000000000f
# ╟─c3000001-0000-4000-8000-000000000010
# ╠═c3000001-0000-4000-8000-000000000011
# ╟─c3000001-0000-4000-8000-000000000012
# ╠═c3000001-0000-4000-8000-000000000013
# ╠═c3000001-0000-4000-8000-000000000014
# ╟─c3000001-0000-4000-8000-000000000015
# ╠═c3000001-0000-4000-8000-000000000016
# ╟─c3000001-0000-4000-8000-000000000017
# ╟─c3000001-0000-4000-8000-000000000018
# ╠═c3000001-0000-4000-8000-000000000019
# ╠═c3000001-0000-4000-8000-00000000001a
# ╠═c3000001-0000-4000-8000-00000000001b
# ╠═c3000001-0000-4000-8000-00000000001c
# ╠═c3000001-0000-4000-8000-00000000001d
# ╠═c3000001-0000-4000-8000-00000000001e