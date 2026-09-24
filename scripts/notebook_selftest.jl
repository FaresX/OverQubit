# Notebook 无头自测：对 notebooks/*.jl 逐个在全新模块中求值（除 @bind 外的全部 cell）。
# 兼容 Pluto 规范化格式（文件头含 mock @bind、cell 头为 UUID、尾部 Cell order footer 表折叠状态）。
# 注意 1：每个 notebook 用全新模块——重复 include 同一物理模块会让 using 绑定歧义。
# 注意 2：运行时创建的 Module 不隐含 Base，且 include 不是 Base 导出名；
#          因此自测预先 include_string 物理模块，并剥掉 cell 里的 include 行。
const CELL_RE = r"^\s*(?:[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}|\d+)\s*\n"
const INCLUDE_RE = r"include\(joinpath\(@__DIR__, \"\.\.\", \"src\", \"[A-Za-z]+\.jl\"\)\)"
const SRCS = [joinpath(@__DIR__, "..", "src", "OverQubit.jl"), joinpath(@__DIR__, "..", "src", "OverQubitViz.jl")]

function run_notebook(path)
	println("=== ", basename(path))
	mod = Module(Symbol("NB_", replace(basename(path), r"[^A-Za-z0-9_]" => "_")))
	for src in SRCS   # 预载物理/渲染模块（cell 1 的 include 由自测代劳）
		Base.include_string(mod, read(src, String), basename(src))
	end
	text = read(path, String)
	chunks = split(text, "\n# ╔═╡")
	header = replace(chunks[1], r"\A### A Pluto\.jl notebook ###\n# v[\d.]+\n" => "")
	include_string(mod, header, "header")
	include_string(mod, """
	const EJ = 20.0; const EC = 0.30; const ng = 0.0
	const detune = 0.0; const amp = 0.05; const sigma = 10.0; const Tns = 60.0
	const E_Cr = 0.06; const om_r = 8.5; const kappa = 0.01; const nshots = 200
	const cmp2 = false
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
			include_string(mod, code, "cell$i")
			ok += 1
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
