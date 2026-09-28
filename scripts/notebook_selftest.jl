# Notebook 无头自测：对 notebooks/*.jl 逐个在全新模块中求值（除 @bind 外的全部 cell）。
# 兼容 Pluto 规范化格式（文件头含 mock @bind、cell 头为 UUID、尾部 Cell order footer 表折叠状态）。
# 注意 1：每个 notebook 用全新模块——重复 include 同一物理模块会让 using 绑定歧义。
# 注意 2：运行时创建的 Module 不隐含 Base，且 include 不是 Base 导出名；
#          因此自测预先用 Base.include(mod, SRC) 载入包模块，并剥掉 cell 里的 include 行。
const CELL_RE = r"^\s*(?:[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}|\d+)\s*\n"
const INCLUDE_RE = r"include\(joinpath\(@__DIR__, \"\.\.\", \"src\", \"[A-Za-z]+\.jl\"\)\)"
const SRC = joinpath(@__DIR__, "..", "src", "OverQubit.jl")   # 渲染层由包内部 include("viz/…") 自带

# —— 回归检查：cell 返回值不能是「一串 HTMLStr」——
# Pluto 的 mime 选择把 application/vnd.pluto.tree+object 排在 text/html 前面，
# 且 pluto_showable(...tree+object, ::Tuple) = true；于是 `html1, html2` 这种
# 返回 tuple 的 cell 会被 tree viewer 以 collapsed 的 flex-row 渲染：
# 两张图挤在同一行各占一半宽度（图例折竖排、标题溢出）、还带 "1:" "2:" 序号。
# 正确做法是 oq_stack(...) 包成单个 HTMLStr。详见 OverQubitViz.oq_stack 的文档字符串。
# 解析 HTMLStr 类型：cell 是在运行时 Module 里 include 的，
# 类型住在 mod.OverQubit.OverQubitViz.HTMLStr（using 转出口后 mod.OverQubit.HTMLStr 也解析得到）。
function _htmlstr_type(mod)
	for m in (mod, Base.invokelatest(() -> try getfield(mod, :OverQubit) catch; nothing end))
		m === nothing && continue
		T = Base.invokelatest(() -> try getfield(m, :HTMLStr) catch; nothing end)
		T isa Type && return T
		viz = Base.invokelatest(() -> try getfield(m, :OverQubitViz) catch; nothing end)
		if viz isa Module
			T = Base.invokelatest(() -> try getfield(viz, :HTMLStr) catch; nothing end)
			T isa Type && return T
		end
	end
	nothing
end

function _is_htmlstr(T, x)
	T === nothing ? nameof(typeof(x)) === :HTMLStr : x isa T
end

# Markdown.MD 同理：两个 md"..." 组成的 tuple 也会被 tree viewer 折成一行。
function _is_md(mod, x)
	nameof(typeof(x)) === :MD || return false
	m = Base.invokelatest(() -> try getfield(mod, :Markdown) catch; nothing end)
	m === nothing && return true
	return try x isa Base.invokelatest(getfield, m, :MD) catch; true end
end

# —— 回归检查：cell 返回值不能是「一串 HTMLStr」——
# Pluto 的 mime 选择（PlutoRunner 的 allmimes）把 application/vnd.pluto.tree+object 排在
# text/html 前面，且 pluto_showable(...tree+object, ::Tuple) = true；于是 cell 末尾写
#     html1, html2
# 返回的 Tuple 会被 tree viewer 渲染成 <pluto-tree class="collapsed">，
# treeview.css 里 collapsed 的 pluto-tree-items 是 flex-direction: row，
# 两张图挤在同一行各占一半宽度（Plotly 把图例折成竖排、标题溢出）、还带 "1:" "2:" 序号。
# 正确做法：oq_stack(html1, html2) 包成单个 HTMLStr。详见 OverQubitViz.oq_stack 文档字符串。
function check_html_tuple(mod, val, nb::AbstractString, cell::Int)
	val isa Union{Tuple, Vector, AbstractVector} || return nothing
	els = collect(val)
	T = _htmlstr_type(mod)
	(isempty(els) || !all(x -> _is_htmlstr(T, x) || _is_md(mod, x), els)) && return nothing
	println("  cell ", cell, " -> 返回了 ", length(els), " 个 HTML/MD 片段的 ", typeof(val).name.name,
		"（Pluto 会用 tree viewer 并排渲染、图只剩一半宽）；请改用 oq_stack(...)")
	error("排版回归：", nb, " cell ", string(cell), " 返回了 ", string(length(els)),
		" 个 HTMLStr，应使用 oq_stack(...) 包成单个 HTMLStr")
end

const DOC_MARK = "\"\"\""

# —— 静态检查：动画帧必须走 anim_frame ——
# Plotly.js 的 frameMerge 在 frame 没给 traces 时按"从 0 开始"映射，frame.data[0]
# 会被 plots.transition 合并进 gd.data[0]；若 trace 0 是背景曲线（势阱抛物线、
# Bloch 线框），播放时整条曲线被单个 marker 顶替而消失。所以帧必须带 traces=[idx]，
# 统一用 anim_frame(idx, name, trace) 构造。注释行与 docstring 行豁免。
function check_no_raw_frames(path::AbstractString)
	bad = Tuple{Int, String}[]
	for (i, line) in enumerate(eachline(path))
		s = strip(line)
		(startswith(s, "#") || occursin("#", line) || occursin(DOC_MARK, s)) && continue
		# 先剔除 anim_frame(，再看还剩不剩裸 frame(
		occursin("frame(", replace(s, "anim_frame(" => "")) || continue
		push!(bad, (i, s[1:min(72, length(s))]))
	end
	isempty(bad) && return nothing
	for (i, l) in bad
		println("  line ", i, " -> 裸 frame(：", l)
	end
	error("动画帧必须用 anim_frame(idx, name, trace)（自动带 traces=[idx]）：", basename(path),
		" 有 ", length(bad), " 处裸 frame(")
end

# —— 静态检查：数学定界符内不许出现中日韩字符 ——
# MathJax 的数学字体没有 CJK 字形，\text{中文} 会静默缺字/空白。中文一律放在 math 外面当 HTML。
# 定界符只认 \(...\)（行内）与 \[...\]（display）；美元定界符不用（与 Julia 插值冲突）。
const CJK_RE = r"[\u2e80-\u9fff\uf900-\ufaff\ufe30-\ufe4f\uff00-\uffef\u3000-\u303f]"

function check_no_cjk_in_math(path::AbstractString)
	bad = Tuple{Int, String}[]
	for (i, line) in enumerate(eachline(path))
		s = strip(line)
		(startswith(s, "#") || occursin("#", line)) && continue          # 注释行豁免
		for m in eachmatch(r"\\\((.*?)\\\)|\\\[(.*?)\\\]", line)
			body = string(something(m.captures...))
			occursin(CJK_RE, body) || continue
			push!(bad, (i, body[1:min(48, length(body))]))
		end
	end
	isempty(bad) && return nothing
	for (i, b) in bad
		println("  line ", i, " -> 数学里有中文：", b)
	end
	error("数学定界符 \\(...\\) / \\[...\\] 内不允许中日韩字符（MathJax 无 CJK 字形，会静默缺字）：",
		basename(path), " 有 ", length(bad), " 处")
end

# —— 静态检查：LaTeX 括号与环境配平 ——
# 括号不平衡会让 MathJax 渲染失败（merror），是公式最常见的一类错误。
const LATEX_RE = r"(?:tex|texblock)\(raw\"([^\"]*)\""

function check_latex_balance(path::AbstractString)
	bad = Tuple{Int, String}[]
	for (i, line) in enumerate(eachline(path))
		s = strip(line)
		(startswith(s, "#") || occursin("#", line)) && continue
		for m in eachmatch(LATEX_RE, line)
			inner = string(m.captures[1])
			d1 = count(==('{'), inner) - count(==('}'), inner)
			d2 = count(==('('), inner) - count(==(')'), inner)
			nb = length(collect(eachmatch(r"\\begin\{", inner)))
			ne = length(collect(eachmatch(r"\\end\{", inner)))
			(d1 == 0 && d2 == 0 && nb == ne) && continue
			push!(bad, (i, first(inner, 60)))
		end
	end
	isempty(bad) && return nothing
	for (i, b) in bad
		println("  line ", i, " -> LaTeX 不配平：", b)
	end
	error("tex()/texblock() 的 LaTeX 括号或 begin/end 不配平：", basename(path), " 有 ", length(bad), " 处")
end

# —— 静态检查：同一变量不许被多个 cell 顶层赋值（Pluto 多重定义错误）——
# Pluto 的响应式规则：每个全局变量必须**恰有一个**定义 cell。两个 cell 都写 `tr = …`，
# Pluto 报「tr 有多个定义」，notebook 里所有相关 cell 直接挂。
# 自测的逐 cell 求值发现不了这类错——cell 顺序求值进同一个模块，Julia 语义下
# 重赋值完全合法；这是 Pluto 语义与 Julia 语义的差异，必须静态按 Pluto 规则查 AST：
#   收集「全局作用域」的赋值目标：begin/if/toplevel 正常下钻（它们不建作用域，
#   cell 顶层 begin 里的赋值就是全局赋值）；let/for/while/function/macro/struct 体
#   不下钻（局部化）；call/macrocall 内部不下钻（关键字参数 =(kw,…) 会误报）；
#   @bind 的变量名按 Pluto 语义也算定义。
function collect_defs!(names::Vector{Symbol}, ex)
	ex isa Expr || return
	if ex.head === :(=)
		lhs = ex.args[1]
		lhs isa Symbol && push!(names, lhs)
		lhs isa Expr && lhs.head === :tuple && foreach(a -> a isa Symbol && push!(names, a), lhs.args)
		collect_defs!(names, ex.args[2])
	elseif ex.head === :const || ex.head === :global || ex.head === :local
		collect_defs!(names, ex.args[1])
	elseif ex.head === :function || ex.head === :macro
		f = ex.args[1]
		f isa Symbol ? push!(names, f) :
			f isa Expr && f.head === :call && f.args[1] isa Symbol && push!(names, f.args[1])
	elseif ex.head === :struct || ex.head === :abstract || ex.head === :primitive
		push!(names, ex.args[2] isa Symbol ? ex.args[2] : ex.args[2].args[1])
	elseif ex.head === :macrocall
		length(ex.args) >= 3 && ex.args[1] === Symbol("@bind") && ex.args[3] isa Symbol &&
			push!(names, ex.args[3])
	elseif ex.head in (:call, :let, :for, :while, :module)
		# 调用（含 kw 参数）、局部作用域体：不收集
	else
		for a in ex.args
			collect_defs!(names, a)
		end
	end
	return
end

function check_multiple_defs(path, chunks)
	where = Dict{Symbol, Vector{Int}}()
	for (i, chunk) in enumerate(chunks[2:end])
		code = replace(chunk, CELL_RE => "")
		(startswith(strip(code), "Cell order:") || startswith(strip(code), "PLUTO_")) && continue
		names = Symbol[]
		try
			collect_defs!(names, Meta.parse("begin\n" * code * "\nend"))
		catch
		end
		for n in unique(names)
			push!(get!(where, n, Int[]), i)
		end
	end
	dups = [n for (n, cs) in where if length(cs) > 1]
	isempty(dups) && return nothing
	for n in sort(string.(dups))
		println("  变量 ", n, " 被多个 cell 顶层赋值（cells: ", join(where[Symbol(n)], ", "),
			"）——Pluto 报「", n, " 有多个定义」。自包含展示 cell 用 let 包住",
			"（动画 cell 例外：需要全局 tr+frames 供 spike/check_frames.jl 配对）")
	end
	error("Pluto 多重定义：", basename(path), " 有 ", length(dups), " 个变量被多个 cell 定义")
end

function run_notebook(path)
	println("=== ", basename(path))
	check_no_raw_frames(path)
	check_no_cjk_in_math(path)
	check_latex_balance(path)
	mod = Module(Symbol("NB_", replace(basename(path), r"[^A-Za-z0-9_]" => "_")))
	Base.include(mod, SRC)   # 预载包模块（含 viz 子模块；cell 里的 include 行由 INCLUDE_RE 剥掉）
	text = read(path, String)
	chunks = split(text, "\n# ╔═╡")
	check_multiple_defs(path, chunks)   # Pluto 语义的多重定义（逐 cell 求值查不出来，见函数头注释）
	header = replace(chunks[1], r"\A### A Pluto\.jl notebook ###\n# v[\d.]+\n" => "")
	include_string(mod, header, "header")
	include_string(mod, """
	const EJ = 20.0; const EC = 0.30; const ng = 0.0
	const detune = 0.0; const amp = 0.05; const sigma = 10.0; const Tns = 60.0
	const E_Cr = 0.06; const om_r = 8.5; const kappa = 0.01; const nshots = 200; const beta = 0.0
	const cmp2 = false
	const T1us = 30.0; const Tphius = 50.0; const sigmad = 20.0; const deltak = 30.0
	const nmem = 16; const taumax = 10.0
	const g_c = 0.05; const det2 = 0.03; const T1q = 20.0; const taumax2 = 40.0
	const phi_ext = 0.0; const EJ0 = 20.0; const D_slider = 0.1
	const ratio2 = 1.20; const amp_phi = 0.073; const t_pulse = 37.5
	const shape_sel = "平滑沿"; const amp_fine = 0.073; const len_fine = 37.5
	""", "defaults")
	ok = skipped = 0
	for (i, chunk) in enumerate(chunks[2:end])
		code = replace(chunk, CELL_RE => "")
		startswith(strip(code), "Cell order:") && continue        # Pluto footer（折叠状态表）
		startswith(strip(code), "PLUTO_") && continue             # 环境快照 cell
		code = replace(code, INCLUDE_RE => "")
		code = replace(code, "@__DIR__" => repr(dirname(abspath(path))))
		if occursin("@bind", code)
			skipped += 1
			continue
		end
		try
			val = include_string(mod, code, "cell$i")
			ok += 1
			check_html_tuple(mod, val, basename(path), i)
		catch e
			println("cell $i: FAIL -> ", e)
			error("notebook 自测失败: ", path)
		end
	end
	println("结果: $ok 个 cell 求值通过, $skipped 个跳过（@bind）")
end

for f in sort(readdir(joinpath(@__DIR__, "..", "notebooks")))
	(endswith(f, ".jl") && !occursin("backup", f)) && run_notebook(joinpath(@__DIR__, "..", "notebooks", f))
end
println("NOTEBOOK SELF-TEST PASS")
