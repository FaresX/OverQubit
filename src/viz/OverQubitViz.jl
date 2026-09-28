# OverQubitViz：渲染层共享工具（视觉主题、布局、Plotly 动画 HTML、可展开推导链）。
# 不含物理——只把数据变成好看的 Web 界面。notebook 与预览共用。
# 作为 `OverQubit.OverQubitViz` 子模块加载（src/OverQubit.jl include + using 转出口）；
# 本文件自包含（只依赖 PlotlyBase），必要时也可单独 include 使用。
module OverQubitViz

using PlotlyBase

export HTMLStr, plotly_html, spec_json, layout_base, frame, animation_menu, anim_frame
export derivation, concept_cards, tryout, PAL, PAL_FILL, INK, SUB, GRID, AXIS, FONT
export banner, section_header, stat_card
export setup_page, stat_row, readout_table, callout, figure_note, lesson_nav, quiz, divider, oq_stack, tex, texblock, deep_dive

# —— 原始 HTML 注入（Pluto 经 show(MIME"text/html") 渲染）——
struct HTMLStr
	s::String
end
Base.show(io::IO, ::MIME"text/html", h::HTMLStr) = print(io, h.s)
# 让 `"$(tex(...))"` 这类字符串插值吐出原始 HTML，而不是 HTMLStr("...") 的 repr。
# 没有这两条，插值会走默认 show → 页面上出现
# `Main.NB_xxx.OverQubitViz.HTMLStr("<span class=\"tex\">...")` 这种裸文本。
Base.string(h::HTMLStr) = h.s
Base.print(io::IO, h::HTMLStr) = print(io, h.s)

# —— 页面依赖与全局样式：plotly.js 懒加载 + 轻量视觉润色（每个 notebook 首 cell 调一次）——
const PLOTLY_CDN = "https://cdn.plot.ly/plotly-2.35.2.min.js"

"""
    setup_page()

在 notebook 第一个 cell 调用：注入 plotly.js 懒加载器与轻量全局样式。
懒加载器是必须的——Pluto 前端不预装 plotly.js，直接 `Plotly.newPlot` 会因 `Plotly` 未定义而静默失败；
样式只做圆角卡片、细边框与淡色页底，不改变 Pluto 自身控件。
"""
function setup_page()
	HTMLStr("""
	<div style="display:none"></div>
	<script>
	if (!window.__oqPlotly) {
		window.__oqPlotly = new Promise(function (resolve, reject) {
			if (window.Plotly) { return resolve(); }
			var s = document.createElement("script");
			s.src = "$PLOTLY_CDN";
			s.onload = function () { resolve(); };
			s.onerror = function () { reject(new Error("plotly.js CDN 加载失败")); };
			document.head.appendChild(s);
		});
	}
	</script>
	<style>
	body { background: #FAFBFF; }
	.oq-plot { border-radius: 12px; border: 1px solid rgba(20,24,60,0.07); background: #fff;
		box-shadow: 0 1px 10px rgba(20,24,60,0.04); margin: 4px 0 10px; }
	.oq-kbd { font: 12px ui-monospace, Menlo, Consolas, monospace; background: #F1F3FA;
		border: 1px solid rgba(20,24,60,0.12); border-radius: 5px; padding: 1px 6px; color: #4C6FFF; }
	.oq-grid { display: flex; gap: 12px; flex-wrap: wrap; margin: 8px 0; }
	</style>
	""")
end

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
	<div id="$id" class="oq-plot" style="height:$(height)px;margin:$(pad)px 0"></div>
	<script>
	window.__oqPlotly.then(function () {
		Plotly.newPlot("$id", $json, {responsive: true});
	}).catch(function (e) { console.error(e); });
	</script>
	""")
end

"""
    oq_stack(blocks...; gap::Int=12)

把多个 HTML 片段纵向堆成**一个** HTMLStr。

⚠️ 为什么必须有它：Pluto 给 cell 返回值挑 MIME 时
（`PlutoRunner/src/display/mime dance.jl` 的 allmimes），
`application/vnd.pluto.tree+object` 排在 `text/html` **前面**，而
`pluto_showable(::MIME"…tree+object", ::Tuple) = true`
（`display/tree viewer.jl`）。所以 cell 末尾直接写

    plotly_html("a", p1), plotly_html("b", p2)

返回的是 `Tuple`，会走 tree viewer：`TreeView.js` 渲染出的
`<pluto-tree class="collapsed">` 配合 treeview.css 的
`pluto-tree.collapsed pluto-tree-items { flex-direction: row; align-items: baseline }`
和 `pluto-tree p-r > p-v { display: inline-flex }`，两个图就被塞进同一行、
各占一半宽度；`p-k` 还会显示 "1:" "2:" 序号。半宽容器里 Plotly 会把图例折成
竖排、标题溢出——就是那种「排版坏掉」的样子。
用一个 HTMLStr 把两个图包起来，Pluto 就走 text/html 原样内联，每个图都拿到 100% 宽。
"""
function oq_stack(blocks...; gap::Int=12)
	items = IOBuffer()
	for b in blocks
		write(items, """<div class="oq-stack-item" style="width:100%">$(b isa HTMLStr ? b.s : string(b))</div>""")
	end
	HTMLStr("""
	<div class="oq-stack" style="display:flex;flex-direction:column;gap:$(gap)px;width:100%">$(String(take!(items)))</div>
	""")
end

# —— 动画帧：必须显式指定要更新哪条 trace ——
"""
    anim_frame(trace_index::Integer, name::String, trace)

构造一帧动画，并**强制写入** `traces=[trace_index]`（`trace_index` 是 0 基索引）。

⚠️ 为什么必须显式：Plotly.js 的 `frameMerge`（src/plots/plots.js）里

    traceIndices = framePtr.traces;
    if(!traceIndices) { /* If not defined, assume serial order starting at zero */ ... }

随后 `plots.transition` 执行
`gd.data[traceIndices[i]] = plots.extendTrace(gd.data[traceIndices[i]], data[i])`，
把帧数据合并进**指定索引**的那条 trace。所以不给 `traces` 时，`frame.data[0]`
永远作用在 `gd.data[0]` 上——若 trace 0 恰好是势阱抛物线/经纬线框这类背景曲线，
播放时它就被单个 marker 顶替、**整条曲线消失**。这是 bug，不是特性。

用法：先在 `traces` 里放一条专用的小球/标记 trace（通常放最后），再

    BALL = length(traces) - 1
    frames = [anim_frame(BALL, string(k), scatter(x=[xs[k]], y=[ys[k]]; mode="markers", ...))
              for k in 1:nfr]

`scripts/notebook_selftest.jl` 会静态检查 notebook 里不得出现裸 `frame(`。
"""
anim_frame(trace_index::Integer, name::String, trace) =
    frame(name=name, traces=[trace_index], data=[trace])

# —— 公式：交给 MathJax 排版 ——
"""
    tex(latex)        # 行内公式
    texblock(latex)   # 独占一行（display）

把公式包成 Pluto 认得的 `.tex` 元素，MathJax 会用标准 LaTeX 字形（Computer Modern 风格）
渲染，而不是让浏览器拿正文字体凑 σ/ω/√。

⚠️ **必须带 `class="tex"`**：Pluto 前端的 MathJax 只处理这个 class 的元素
（`SetupMathJax.js`: `processHtmlClass: "tex"`；`CellOutput.js`:
`MathJax.typeset(container.querySelectorAll(".tex"))`）。没有它 → 公式当普通文本，
字形随系统字体漂移，就是"公式字体很奇怪"的来源。
⚠️ **定界符用 `\\(` `\\)` 而不是 `\$`**：Julia 字符串里 `\$` 会触发插值。
⚠️ **含反斜杠的 LaTeX 一律用 `raw"..."`**：普通字符串里 `\\O`、`\\s` 是非法转义，
  Julia 直接语法报错；raw 字符串不能插值，需要数字时用 `*` 拼接（见各 notebook）。

例：`tex(raw"P_1 = \\frac{\\Omega_R^2}{\\Omega_R^2+\\delta^2}\\sin^2(\\tfrac{\\Omega t}{2})")`
"""
tex(l::AbstractString) = HTMLStr("""<span class="tex">\\($(l)\\)</span>""")

texblock(l::AbstractString) = HTMLStr("""<div class="tex" style="margin:8px 0;overflow-x:auto">\\[$(l)\\]</div>""")

# —— 统一布局模板 ——
# legend_x / legend_y：图例在纸坐标里的锚点。带动画按钮的图要传 legend_x≈0.15，
# 把图例让到按钮右侧；否则按钮（x=0, y=1.02）与图例（x=0, y≈1.02）重叠，
# 在窄容器里会被 Plotly 折成竖排堆叠、把绘图区挤成一条。
# title 字号 14：14px 下 ~26 个中文字符 ≈ 400px，仍能在 470px 宽的容器里不溢出。
function layout_base(; height::Int=520, title::String="", xtitle::String="", ytitle::String="",
		annotations=Any[], legend_y::Real=1.02, legend_x::Real=0.0, margin_t::Int=68, margin_b::Int=48,
		yrange=nothing, ytype::String="", anchor_y::Bool=false, scene::Bool=false, updatemenus=Any[])
	ax = attr(title=xtitle, gridcolor=GRID, zerolinecolor=AXIS, linecolor=AXIS,
		tickfont=attr(size=11, color=SUB), titlefont=attr(size=12, color=SUB))
	ay = attr(title=ytitle, gridcolor=GRID, zerolinecolor=AXIS, linecolor=AXIS,
		tickfont=attr(size=11, color=SUB), titlefont=attr(size=12, color=SUB))
	yrange === nothing || (ay.range = yrange)
	ytype == "" || (ay.type = ytype)
	anchor_y && (ax.scaleanchor = "y"; ax.scaleratio = 1)
	Layout(title=attr(text=title, font=attr(size=14, color=INK)), xaxis=ax, yaxis=ay,
		font=attr(family=FONT), plot_bgcolor="white", paper_bgcolor="white",
		margin=attr(l=60, r=24, t=margin_t, b=margin_b), height=height, annotations=annotations,
		updatemenus=updatemenus,
		legend=attr(orientation="h", y=legend_y, x=legend_x, xanchor="left", yanchor="bottom",
			bgcolor="rgba(0,0,0,0)", font=attr(size=11, color=SUB)))
end

"""动画播放按钮（plotly.js 原生 updatemenus）。x=0.02/y=1.02 与图例同一行，
配合 layout_base(legend_x=0.15) 使用，避免两者重叠被折成竖排。"""
animation_menu() = [attr(type="buttons", direction="left", x=0.02, y=1.03, showactive=false,
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

"""
    deep_dive(title, body; tone="detail")

可折叠的「深入一点」块：放比主线更深的细节（推导边界、工程数值、历史、
常见误解的成因），不展开也不影响理解主线。
tone="detail"（默认，紫）| "warn"（橙，放误解/陷阱）| "tip"（青，放延伸）。
"""
function deep_dive(title::String, body::String; tone::String="detail")
	(color, bg, border) = tone == "warn" ?
		("#B8812E", "#FFFBF2", "rgba(184,129,46,0.35)") :
		tone == "tip" ?
		("#14655A", "#F4FCFA", "rgba(34,195,166,0.35)") :
		("#7B61FF", "#F8F7FF", "rgba(123,97,255,0.28)")
	HTMLStr("""
	<details style="border:1px solid $(border);border-radius:10px;margin:10px 0;background:$(bg)">
	<summary style="cursor:pointer;padding:9px 14px;font-size:13.5px;color:$(color);font-weight:700">
	<span style="display:inline-block;padding:1px 8px;border-radius:9px;background:$(color);color:white;font-size:11px;margin-right:8px">深入一点</span>
	$(title)
	</summary>
	<div style="padding:2px 18px 14px;font-size:13.5px;color:#33384D;line-height:2.0">$(body)</div>
	</details>
	""")
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

"""带编号的分区标题（n 为序号字符串，title 为标题）"""
function section_header(n::String, title::String)
	HTMLStr("""
	<div style="display:flex;align-items:center;gap:10px;margin:14px 0 8px">
	<div style="width:30px;height:30px;border-radius:9px;background:linear-gradient(135deg,#4C6FFF,#7B61FF);color:white;font-weight:700;display:flex;align-items:center;justify-content:center;font-size:14px">$(n)</div>
	<div style="font-size:17px;font-weight:700;color:#1A1A2E">$(title)</div>
	<div style="flex:1;height:1px;background:linear-gradient(90deg,rgba(76,111,255,0.35),transparent)"></div>
	</div>
	""")
end

"""数据卡（label, value_html, sub_html, color）"""
function stat_card(label::String, value_html::String, sub_html::String, color::String)
	HTMLStr("""
	<div style="flex:1;min-width:150px;border:1px solid rgba(76,111,255,0.18);border-radius:12px;padding:10px 16px;background:#FBFBFF">
	<div style="font-size:11px;letter-spacing:1px;color:#7B61FF">$(label)</div>
	<div style="font-size:19px;font-weight:700;color:$(color)">$(value_html)</div>
	<div style="font-size:12px;color:#8A90AD;margin-top:2px">$(sub_html)</div>
	</div>
	""")
end

"""读数卡行：cards = [(label, value_html, sub_html, color), ...]（stat_card 的行式封装）"""
function stat_row(cards)
	io = IOBuffer()
	for (label, value, sub, color) in cards
		write(io, """
		<div style="flex:1;min-width:150px;border:1px solid rgba(76,111,255,0.18);border-radius:12px;padding:10px 16px;background:#FBFBFF">
		<div style="font-size:11px;letter-spacing:1px;color:#7B61FF">$(label)</div>
		<div style="font-size:19px;font-weight:700;color:$(color)">$(value)</div>
		<div style="font-size:12px;color:#8A90AD;margin-top:2px">$(sub)</div>
		</div>
		""")
	end
	HTMLStr("""<div class="oq-grid">$(String(take!(io)))</div>""")
end

"""两列读数表（label | value_html + note_html），用于「量 / 数值」型读数（替代手写表格）"""
function readout_table(rows; title::String="")
	io = IOBuffer()
	for (label, value, note) in rows
		write(io, """
		<tr><td style="padding:7px 0;border-top:1px solid rgba(20,24,60,0.08)">$(label)</td>
		<td style="padding:7px 0;border-top:1px solid rgba(20,24,60,0.08)"><b style="color:#1A1A2E">$(value)</b>
		<span style="color:#8A90AD;font-size:12px">$(note)</span></td></tr>
		""")
	end
	hdr = isempty(title) ? "" : """<div style="font-size:11px;letter-spacing:1px;color:#7B61FF;font-weight:600">$(title)</div>"""
	HTMLStr("""
	<div style="border:1px solid rgba(76,111,255,0.18);border-radius:12px;padding:10px 16px 14px;background:#FBFBFF">
	$hdr
	<table style="border-collapse:collapse;width:100%;font-size:15px;margin-top:2px">$(String(take!(io)))</table>
	</div>
	""")
end

"""提示框（tone = info / tip / warn）——替换裸 <p> 的关键结论行"""
function callout(text::String; tone::String="info", title::String="")
	cfg = Dict(
		"info" => ("#4C6FFF", "#F4F6FF", "#2E4A9E"),
		"tip" => ("#22C3A6", "#F0FDF8", "#14655A"),
		"warn" => ("#F5A623", "#FFF8EC", "#6B5A2E"),
	)[tone]
	(c, bg, fg) = cfg
	t = isempty(title) ? "" : """<b>$(title)　</b>"""
	HTMLStr("""
	<div style="background:$(bg);border-left:4px solid $(c);border-radius:6px;padding:10px 14px;margin:10px 0;color:$(fg);font-size:13.5px;line-height:1.9">
	$t$(text)</div>
	""")
end

"""图注（小字灰）"""
figure_note(text::String) = HTMLStr("""
<div style="font-size:12px;color:#8A90AD;margin:2px 2px 12px">$(text)</div>
""")

"""学习路径导航条：items = [(序号, 标题, 状态), ...]，状态 ∈ done / current / todo"""
function lesson_nav(items)
	io = IOBuffer()
	for (no, title, state) in items
		if state == "current"
			style = "background:linear-gradient(135deg,#4C6FFF,#7B61FF);color:#fff;border-color:transparent;font-weight:700;box-shadow:0 2px 10px rgba(76,111,255,0.28)"
			badge = "当前"
		elseif state == "done"
			style = "background:#F0FDF8;color:#14655A;border-color:rgba(34,195,166,0.35)"
			badge = no
		else
			style = "background:#fff;color:#8A90AD;border-color:rgba(20,24,60,0.12)"
			badge = no
		end
		write(io, """
		<div style="display:flex;align-items:center;gap:8px;border:1px solid;border-radius:10px;padding:6px 12px;font-size:12.5px;$(style)">
		<span style="opacity:0.75">$(badge)</span><span>$(title)</span>
		</div>
		""")
	end
	HTMLStr("""
	<div style="margin:6px 0 2px">
	<div style="font-size:11px;letter-spacing:2px;color:#7B61FF;font-weight:600">学习路径 · LEARNING PATH</div>
	<div style="display:flex;gap:8px;flex-wrap:wrap;margin-top:6px">$(String(take!(io)))</div>
	</div>
	""")
end

"""小测题组：qs = [(题干HTML, [选项HTML...], 正确项序号, 解析HTML), ...]，答案默认折叠"""
function quiz(qs)
	io = IOBuffer()
	for (i, (q, opts, ans, why)) in enumerate(qs)
		write(io, """
		<div style="border:1px solid rgba(123,97,255,0.22);border-radius:10px;padding:10px 14px;margin:8px 0;background:#FCFBFF">
		<div style="font-size:14px;font-weight:700;color:#1A1A2E">Q$(i)　$(q)</div>
		<details style="margin-top:6px"><summary style="cursor:pointer;font-size:12.5px;color:#7B61FF">展开答案与解析</summary>
		<div style="font-size:13.5px;color:#14655A;background:#F0FDF8;border-radius:8px;padding:8px 12px;margin-top:6px">
		<b>正确：$(opts[ans])</b></div>
		<div style="font-size:13px;color:#5A6182;line-height:1.85;margin-top:6px">$(why)</div>
		</details></div>
		""")
	end
	HTMLStr("""
	<div style="border:1px dashed rgba(123,97,255,0.3);border-radius:14px;padding:10px 18px 14px;background:#FCFBFF;margin-top:6px">
	<div style="font-size:16px;font-weight:700;color:#7B61FF;margin-bottom:2px">⑥ 自测</div>
	$(String(take!(io)))
	</div>
	""")
end

"""渐变横幅（eyebrow, title, subtitle; icon = bloch / well / s21 / pulse / drag / pair / clock / flux）"""
function banner(eyebrow::String, title::String, subtitle::String; icon::String="bloch")
	svg = if icon == "well"
		"""
		<svg width="88" height="88" viewBox="0 0 100 100" style="flex:none;opacity:0.92">
		<path d="M12 26 Q50 92 88 26" fill="none" stroke="#2C3E50" stroke-width="2.5"/>
		<line x1="20" y1="46" x2="80" y2="46" stroke="#4C6FFF" stroke-width="2" stroke-dasharray="5 4"/>
		<line x1="20" y1="58" x2="80" y2="58" stroke="#7B61FF" stroke-width="2" stroke-dasharray="5 4"/>
		<line x1="20" y1="68" x2="80" y2="68" stroke="#22C3A6" stroke-width="2" stroke-dasharray="5 4"/>
		<path d="M38 46 Q50 30 62 46 Q50 62 38 46" fill="rgba(76,111,255,0.18)" stroke="#4C6FFF" stroke-width="1.5"/>
		<path d="M40 58 Q50 50 60 58 Q50 66 40 58" fill="rgba(123,97,255,0.18)" stroke="#7B61FF" stroke-width="1.5"/>
		</svg>
		"""
	elseif icon == "s21"
		"""
		<svg width="88" height="88" viewBox="0 0 100 100" style="flex:none;opacity:0.92">
		<path d="M14 74 Q30 74 34 40 Q38 16 50 40 Q56 55 62 55 Q72 55 72 74" fill="none" stroke="#4C6FFF" stroke-width="2.5"/>
		<path d="M14 74 Q30 74 40 40 Q46 16 58 40 Q64 55 72 55 Q80 55 86 74" fill="none" stroke="#7B61FF" stroke-width="2" opacity="0.55"/>
		<line x1="50" y1="12" x2="50" y2="84" stroke="#F5A623" stroke-width="2" stroke-dasharray="4 4"/>
		<circle cx="50" cy="40" r="4" fill="#FF7A7A"/>
		</svg>
		"""
	elseif icon == "pulse"
		"""
		<svg width="88" height="88" viewBox="0 0 100 100" style="flex:none;opacity:0.92">
		<line x1="10" y1="62" x2="90" y2="62" stroke="rgba(20,24,60,0.2)" stroke-width="1.5"/>
		<path d="M10 62 Q26 62 32 28 Q38 62 44 62" fill="none" stroke="#4C6FFF" stroke-width="2.5"/>
		<path d="M46 62 Q50 52 54 62" fill="none" stroke="#F5A623" stroke-width="2.5"/>
		<text x="10" y="86" font-size="10" fill="#5A6182">X(π)</text>
		<text x="66" y="86" font-size="10" fill="#5A6182">Y(π/2)</text>
		</svg>
		"""
	elseif icon == "drag"
		"""
		<svg width="88" height="88" viewBox="0 0 100 100" style="flex:none;opacity:0.92">
		<path d="M12 66 Q34 66 40 34 Q46 66 58 66" fill="none" stroke="#4C6FFF" stroke-width="2.5"/>
		<path d="M12 34 Q34 34 40 66 Q46 34 58 34" fill="none" stroke="#F5A623" stroke-width="2" opacity="0.8"/>
		<circle cx="58" cy="66" r="5" fill="#4C6FFF"/><circle cx="58" cy="34" r="5" fill="#F5A623"/>
		<text x="62" y="30" font-size="9" fill="#5A6182">Q ∝ dI/dt</text>
		</svg>
		"""
	elseif icon == "pair"
		"""
		<svg width="88" height="88" viewBox="0 0 100 100" style="flex:none;opacity:0.92">
		<circle cx="34" cy="34" r="13" fill="none" stroke="#4C6FFF" stroke-width="2.5"/>
		<circle cx="66" cy="34" r="13" fill="none" stroke="#7B61FF" stroke-width="2.5"/>
		<path d="M44 44 Q50 60 56 44" fill="none" stroke="#22C3A6" stroke-width="2.5" stroke-dasharray="4 3"/>
		<text x="24" y="62" font-size="10" fill="#4C6FFF">|1⟩</text>
		<text x="66" y="62" font-size="10" fill="#7B61FF">|0⟩</text>
		<path d="M40 62 Q50 70 60 62" fill="none" stroke="#FF7A7A" stroke-width="2"/>
		</svg>
		"""
	elseif icon == "clock"
		"""
		<svg width="88" height="88" viewBox="0 0 100 100" style="flex:none;opacity:0.92">
		<circle cx="50" cy="50" r="30" fill="none" stroke="#C9D2FF" stroke-width="2.5"/>
		<path d="M50 50 L50 28" stroke="#4C6FFF" stroke-width="3"/>
		<path d="M50 50 L66 56" stroke="#7B61FF" stroke-width="3"/>
		<path d="M30 74 Q50 84 70 74" fill="none" stroke="#22C3A6" stroke-width="2.5"/>
		<text x="34" y="94" font-size="10" fill="#5A6182">T1 / T2*</text>
		</svg>
		"""
	elseif icon == "flux"
		"""
		<svg width="88" height="88" viewBox="0 0 100 100" style="flex:none;opacity:0.92">
		<circle cx="50" cy="50" r="26" fill="none" stroke="#2C3E50" stroke-width="2.5"/>
		<path d="M50 12 A38 38 0 0 1 88 50" fill="none" stroke="#4C6FFF" stroke-width="2" stroke-dasharray="5 4"/>
		<circle cx="76" cy="50" r="4" fill="#F5A623"/>
		<text x="30" y="56" font-size="11" fill="#7B61FF">Φ</text>
		<text x="60" y="92" font-size="9" fill="#5A6182">E_J(Φ)</text>
		</svg>
		"""
	else    # bloch（默认）
		"""
		<svg width="86" height="86" viewBox="0 0 100 100" style="flex:none;opacity:0.9">
		<circle cx="50" cy="50" r="34" fill="none" stroke="#C9D2FF" stroke-width="2.5"/>
		<ellipse cx="50" cy="50" rx="34" ry="12" fill="none" stroke="#D9C9FF" stroke-width="2"/>
		<ellipse cx="50" cy="50" rx="12" ry="34" fill="none" stroke="#C4F0E8" stroke-width="2"/>
		<circle cx="50" cy="16" r="5" fill="#22C3A6"/>
		<circle cx="50" cy="84" r="5" fill="#4C6FFF"/>
		<circle cx="84" cy="50" r="4" fill="#F5A623"/>
		</svg>
		"""
	end
	HTMLStr("""
	<div style="background:linear-gradient(100deg,#EEF1FF 0%,#F6F2FF 60%,#EFFBF8 100%);border-radius:14px;padding:20px 26px;margin:2px 0 10px 0;display:flex;align-items:center;gap:18px">
	<div style="flex:1">
	<div style="font-size:12px;letter-spacing:2px;color:#7B61FF;font-weight:600">$(eyebrow)</div>
	<div style="font-size:24px;font-weight:700;color:#1A1A2E;margin-top:4px">$(title)</div>
	<div style="color:#5A6182;margin-top:8px;font-size:14px">$(subtitle)</div>
	</div>
	$(svg)
	</div>
	""")
end

"""细分隔线（渐变细线，用于大区块之间）"""
divider() = HTMLStr("""
<div style="height:1px;background:linear-gradient(90deg,rgba(76,111,255,0.28),rgba(123,97,255,0.14),transparent);margin:16px 0 10px"></div>
""")

end # module
