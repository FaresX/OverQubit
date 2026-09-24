# OverQubitViz：渲染层共享工具（视觉主题、布局、Plotly 动画 HTML、可展开推导链）。
# 不含物理——只把数据变成好看的 Web 界面。notebook 与预览共用。
module OverQubitViz

using PlotlyBase

export HTMLStr, plotly_html, spec_json, layout_base, frame, animation_menu
export derivation, concept_cards, tryout, PAL, PAL_FILL, INK, SUB, GRID, AXIS, FONT

# —— 原始 HTML 注入（Pluto 经 show(MIME"text/html") 渲染）——
struct HTMLStr
	s::String
end
Base.show(io::IO, ::MIME"text/html", h::HTMLStr) = print(io, h.s)

# —— 视觉主题 ——
const PAL = ["#4C6FFF", "#7B61FF", "#22C3A6", "#F5A623"]     # 序列主色（蓝/紫/青/橙）
const PAL_FILL = ["rgba(76,111,255,0.13)", "rgba(123,97,255,0.13)", "rgba(34,195,166,0.13)"]
const INK = "#1A1A2E"; const SUB = "#5A6182"
const GRID = "rgba(20,24,60,0.06)"; const AXIS = "rgba(20,24,60,0.22)"
const FONT = "-apple-system,'Segoe UI','PingFang SC','Microsoft YaHei',sans-serif"

spec_json(p) = (fn = tempname() * ".json"; savejson(p, fn); s = read(fn, String); rm(fn; force = true); s)

"""
    plotly_html(id, p; height=520, pad=2)

把 PlotlyBase.Plot 渲染成带 frames 的自绘 HTML（savejson 全量序列化 → Plotly.newPlot）。
动画按钮由 layout 的 updatemenus 提供（见 animation_menu()），数据仍是真实计算的帧。
"""
function plotly_html(id::String, p; height::Int=520, pad::Int=2)
	json = spec_json(p)
	HTMLStr("""
	<div id="$id" style="height:$(height)px;margin:$(pad)px 0"></div>
	<script>Plotly.newPlot("$id", $json, {responsive:true});</script>
	""")
end

# —— 统一布局模板 ——
function layout_base(; height::Int=520, title::String="", xtitle::String="", ytitle::String="",
		annotations=Any[], legend_y::Real=1.09, margin_t::Int=56, margin_b::Int=48,
		yrange=nothing, anchor_y::Bool=false, scene::Bool=false, updatemenus=Any[])
	ax = attr(title=xtitle, gridcolor=GRID, zerolinecolor=AXIS, linecolor=AXIS,
		tickfont=attr(size=11, color=SUB), titlefont=attr(size=12, color=SUB))
	ay = attr(title=ytitle, gridcolor=GRID, zerolinecolor=AXIS, linecolor=AXIS,
		tickfont=attr(size=11, color=SUB), titlefont=attr(size=12, color=SUB))
	yrange === nothing || (ay.range = yrange)
	anchor_y && (ax.scaleanchor = "y"; ax.scaleratio = 1)
	Layout(title=attr(text=title, font=attr(size=16, color=INK)), xaxis=ax, yaxis=ay,
		font=attr(family=FONT), plot_bgcolor="white", paper_bgcolor="white",
		margin=attr(l=60, r=24, t=margin_t, b=margin_b), height=height, annotations=annotations,
		updatemenus=updatemenus,
		legend=attr(orientation="h", y=legend_y, x=0, bgcolor="rgba(0,0,0,0)", font=attr(size=11, color=SUB)))
end

"""动画播放按钮（plotly.js 原生 updatemenus）"""
animation_menu() = [attr(type="buttons", direction="left", x=0.0, y=1.14, showactive=false,
	buttons=[attr(label="播放", method="animate",
		args=[nothing, attr(frame=attr(duration=80, redraw=true), transition=attr(duration=0),
			mode="immediate", fromcurrent=true)]),
		attr(label="暂停", method="animate",
			args=[[nothing], attr(frame=attr(duration=0, redraw=false), transition=attr(duration=0),
				mode="immediate")])])]

# —— 可展开推导链（每步 <details>，浏览器原生交互）——
"""
    derivation(title, steps; lead="", result="")

steps = [(操作, 公式HTML, 说明), ...]。渲染为逐步可展开的推导链。
result 为结论行 HTML（调用方自行插入已格式化的数值字符串）。
"""
function derivation(title::String, steps; lead::String="", result::String="")
	rows = IOBuffer()
	for (i, (op, formula, note)) in enumerate(steps)
		color = op == "定义" ? "#7B61FF" : op == "近似" ? "#B8812E" : op == "微扰" ? "#C2543A" : "#4C6FFF"
		write(rows, """
		<details style="border:1px solid rgba(20,24,60,0.10);border-radius:10px;margin:6px 0;background:white">
		<summary style="cursor:pointer;padding:9px 14px;font-size:13.5px;color:#33384D;list-style:none">
		<span style="display:inline-block;min-width:26px;color:$color;font-weight:700">$(i)</span>
		<span style="display:inline-block;padding:1px 8px;border-radius:9px;background:$color;color:white;font-size:11px;margin:0 8px">$op</span>
		$(note)
		</summary>
		<div style="padding:4px 18px 14px 46px;font-size:15px;color:#1A1A2E;line-height:2.1">$formula</div>
		</details>
		""")
	end
	leaddiv = isempty(lead) ? "" :
		"""<div style="font-size:13.5px;color:#5A6182;margin:2px 2px 8px">$lead</div>"""
	resultdiv = isempty(result) ? "" :
		"""<div style="background:#F0FDF8;border-left:4px solid #22C3A6;border-radius:6px;padding:9px 14px;margin-top:8px;font-size:13.5px;color:#14655A">$result</div>"""
	HTMLStr("""
	<div style="border:1px solid rgba(76,111,255,0.16);border-radius:14px;padding:14px 18px 16px;background:linear-gradient(180deg,#FAFBFF,#FFFFFF)">
	<div style="font-size:16px;font-weight:700;color:#1A1A2E;margin-bottom:6px">$(title)</div>
	$leaddiv
	$(String(take!(rows)))
	$resultdiv
	</div>
	""")
end

"""概念卡行（cards = [(标题, HTML内容), ...]）"""
function concept_cards(cards)
	io = IOBuffer()
	for (t, c) in cards
		write(io, """
		<div style="flex:1;min-width:190px;border:1px solid rgba(76,111,255,0.14);border-radius:12px;padding:10px 14px;background:#FBFBFF">
		<div style="font-size:11px;letter-spacing:1px;color:#7B61FF;font-weight:600">$(t)</div>
		<div style="font-size:13.5px;color:#33384D;line-height:1.85;margin-top:4px">$(c)</div></div>
		""")
	end
	HTMLStr("""<div style="display:flex;gap:12px;flex-wrap:wrap;margin:8px 0">$(String(take!(io)))</div>""")
end

"""试试看任务（title, 做法, 预期现象）——预期现象默认折叠"""
function tryout(tasks)
	io = IOBuffer()
	for (i, (t, how, expect)) in enumerate(tasks)
		write(io, """
		<div style="border-left:3px solid #7B61FF;padding:6px 0 6px 14px;margin:10px 0">
		<div style="font-weight:700;color:#1A1A2E;font-size:14.5px">任务 $i · $t</div>
		<div style="font-size:13.5px;color:#33384D;line-height:1.85;margin-top:3px">$how</div>
		<details style="margin-top:5px"><summary style="cursor:pointer;font-size:12.5px;color:#7B61FF">展开预期现象</summary>
		<div style="font-size:13px;color:#5A6182;padding:6px 2px;line-height:1.8">$expect</div></details>
		</div>
		""")
	end
	HTMLStr("""
	<div style="border:1px dashed rgba(123,97,255,0.35);border-radius:14px;padding:10px 18px 14px;background:#FCFBFF">
	<div style="font-size:16px;font-weight:700;color:#7B61FF;margin-bottom:4px">④ 试试看</div>
	$(String(take!(io)))
	</div>
	""")
end

end # module
