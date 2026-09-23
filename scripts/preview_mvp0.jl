# MVP-0 无头预览：复刻 notebook 的计算与绘图路径，输出 HTML。
# 用途：不打开浏览器也验证 notebook 的代码真实可跑；视觉主题与 notebook 保持一致。
include(joinpath(@__DIR__, "..", "src", "OverQubit.jl"))
using .OverQubit
using PlotlyBase
using Statistics

const PAL = ["#4C6FFF", "#7B61FF", "#22C3A6", "#F5A623"]
const PAL_FILL = ["rgba(76,111,255,0.13)", "rgba(123,97,255,0.13)", "rgba(34,195,166,0.13)"]
const INK = "#1A1A2E"
const SUB = "#5A6182"
const GRID = "rgba(20,24,60,0.06)"
const AXIS = "rgba(20,24,60,0.22)"
const FONT = "-apple-system,'Segoe UI','PingFang SC','Microsoft YaHei',sans-serif"

function spec_json(p)
	fn = tempname() * ".json"
	PlotlyBase.savejson(p, fn)
	s = read(fn, String)
	rm(fn; force=true)
	s
end

function build_section(EJ, EC, ng)
	NCUT = 80
	t = Transmon(EJ, EC; ncut=NCUT)
	E = eigenenergies(t, ng)
	f01, f12 = f01_f12(t, ng)
	α = f12 - f01
	phis, psi2 = wavefunctions(t, ng, 3, 300)
	koch_f01 = EC * (sqrt(8 * EJ / EC) - 1)

	s = 0.30 * (E[2] - E[1]) / maximum(psi2)
	V = potential.(t, phis) .+ EJ
	Esh = E .+ EJ
	traces = PlotlyBase.GenericTrace[]
	push!(traces, PlotlyBase.scatter(x=phis, y=V; name="势阱 V(phi)", mode="lines",
		line=attr(color="#2C3E50", width=2.5), fill="tozeroy", fillcolor="rgba(44,62,80,0.05)"))
	for k in 1:3
		push!(traces, PlotlyBase.scatter(x=phis, y=fill(Esh[k], length(phis)); mode="lines",
			line=attr(dash="dash", color=PAL[k], width=1.5), name="E$(k-1)", showlegend=false))
		push!(traces, PlotlyBase.scatter(x=phis, y=psi2[k, :] * s .+ Esh[k]; fill="tozeroy",
			line=attr(color=PAL[k], width=1.4), fillcolor=PAL_FILL[k], name="|psi$(k-1)|^2", showlegend=false))
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
	p1 = PlotlyBase.Plot(traces,
		Layout(title=attr(text="势阱、能级与波函数密度（ng = $ng）", font=attr(size=16, color=INK)),
			xaxis=attr(title="相位 phi (rad)", gridcolor=GRID, zerolinecolor=AXIS, linecolor=AXIS,
				tickfont=attr(size=11, color=SUB)),
			yaxis=attr(title="能量（相对零点，GHz）", gridcolor=GRID, zerolinecolor=AXIS, linecolor=AXIS,
				tickfont=attr(size=11, color=SUB)),
			font=attr(family=FONT), plot_bgcolor="white", paper_bgcolor="white",
			margin=attr(l=64, r=56, t=60, b=52), height=620, annotations=ann,
			legend=attr(orientation="h", y=1.10, x=0, bgcolor="rgba(0,0,0,0)", font=attr(size=11, color=SUB))))

	ngs, Es = charge_dispersion(t, 81, 3)
	e01s = Es[:, 2] .- Es[:, 1]
	e12s = Es[:, 3] .- Es[:, 2]
	band_MHz = (maximum(e01s) - minimum(e01s)) * 1000
	span = maximum(e12s) - minimum(e12s) + 1e-9
	tr = PlotlyBase.GenericTrace[]
	push!(tr, PlotlyBase.scatter(x=ngs, y=(e01s .- mean(e01s)) * 1000; mode="lines",
		name="f01(n_g)", line=attr(color=PAL[1], width=2.5)))
	push!(tr, PlotlyBase.scatter(x=ngs, y=(e12s .- mean(e12s)) * 1000; mode="lines",
		name="f12(n_g)", line=attr(color=PAL[2], width=2.5)))
	push!(tr, PlotlyBase.scatter(x=[ng, ng], y=[minimum(e01s) - 0.15span, maximum(e12s) + 0.15span]; mode="lines",
		name="当前 n_g", line=attr(color=PAL[4], width=2, dash="dot")))
	p2 = PlotlyBase.Plot(tr,
		Layout(title=attr(text="电荷色散：f01(n_g) —— transmon 几乎完全平坦", font=attr(size=16, color=INK)),
			xaxis=attr(title="偏移电荷 n_g", gridcolor=GRID, zerolinecolor=AXIS, linecolor=AXIS,
				tickfont=attr(size=11, color=SUB)),
			yaxis=attr(title="相对均值 (MHz)", gridcolor=GRID, zerolinecolor=AXIS, linecolor=AXIS,
				tickfont=attr(size=11, color=SUB)),
			font=attr(family=FONT), plot_bgcolor="white", paper_bgcolor="white",
			margin=attr(l=64, r=32, t=60, b=52), height=560,
			legend=attr(orientation="h", y=1.10, x=0, bgcolor="rgba(0,0,0,0)", font=attr(size=11, color=SUB))))

	a = round(f01, digits=4); b = round(koch_f01, digits=4); c = round(f12, digits=4)
	d = round(α, digits=4); e = round(band_MHz, digits=4)
	h2 = "f01 = $a GHz（Koch 对照 $b） | f12 = $c GHz | alpha = $d GHz | 电荷色散带宽 = $e MHz"
	return (; h2, s1 = spec_json(p1), s2 = spec_json(p2))
end

function section_html(sec, id)
	"""
	<h2>$(sec.h2)</h2>
	<div id="p1_$(id)" class="plotly-graph"></div>
	<script>Plotly.newPlot("p1_$(id)", $(sec.s1), {responsive: true})</script>
	<div id="p2_$(id)" class="plotly-graph"></div>
	<script>Plotly.newPlot("p2_$(id)", $(sec.s2), {responsive: true})</script>
	"""
end

sec_default = build_section(20.0, 0.30, 0.0)
sec_extreme = build_section(5.0, 0.50, 0.0)

open(joinpath(@__DIR__, "..", "spike", "mvp0_preview.html"), "w") do io
	write(io, """
	<html><head><meta charset="utf-8"><title>OverQubit · MVP-0 preview</title>
	<script src="https://cdn.plot.ly/plotly-2.35.2.min.js"></script>
	<style>
	body{margin:0;background:#F4F5FA;font-family:-apple-system,'Segoe UI','PingFang SC','Microsoft YaHei',sans-serif;color:#1A1A2E}
	.wrap{max-width:980px;margin:0 auto;padding:28px 20px 60px}
	.card{background:white;border:1px solid rgba(76,111,255,0.14);border-radius:14px;padding:18px 22px;margin-top:18px;box-shadow:0 2px 14px rgba(20,24,60,0.05)}
	h1{font-size:22px;margin:0}
	h2{font-size:15px;color:#5A6182;font-weight:600;margin:6px 4px 0}
	.tag{font-size:11px;letter-spacing:2px;color:#7B61FF;font-weight:600}
	.plotly-graph{width:100%;height:620px}
	</style></head><body><div class="wrap">
	<div class="tag">OVERQUBIT · MVP-0</div>
	<h1>超导量子比特原理 · transmon 电荷基对角化</h1>
	<div class="card"><h2>默认参数 EJ=20, EC=0.3（transmon 区）</h2>
	$(section_html(sec_default, "a"))</div>
	<div class="card"><h2>极端参数 EJ=5, EC=0.5（Cooper-pair box 区，注意色散带宽变化）</h2>
	$(section_html(sec_extreme, "b"))</div>
	</div></body></html>
	""")
end
println("written: spike/mvp0_preview.html")
