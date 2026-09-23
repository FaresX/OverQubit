# Notebook 无头自测：按顺序求值 notebooks/*.jl 中除 @bind 外的全部 cell。
# 兼容 Pluto 规范化格式（文件头含 mock @bind，cell 头为 UUID），并剥离子代生成的
# PLUTO_*_TOML 环境快照 cell。模拟 Pluto 求值，确保 notebook 打开即可运行。
module NBTest

include(joinpath(@__DIR__, "..", "src", "OverQubit.jl"))

end

const CELL_RE = r"^\s*(?:[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}|\d+)\s*\n"

function run_notebook(path)
	text = read(path, String)
	chunks = split(text, "\n# ╔═╡")
	# 第一段：Pluto 文件头（using Markdown + mock @bind 宏），照常求值
	header = chunks[1]
	header = replace(header, r"\A### A Pluto\.jl notebook ###\n# v[\d.]+\n" => "")
	include_string(NBTest, header, "header")

	# 预置滑块默认值（@bind cell 跳过）
	include_string(NBTest, "const EJ = 20.0; const EC = 0.30; const ng = 0.0", "defaults")

	ok = skipped = 0
	for (i, chunk) in enumerate(chunks[2:end])
		code = replace(chunk, CELL_RE => "")
		code = replace(code, "@__DIR__" => repr(joinpath(@__DIR__, "..", "notebooks")))  # include_string 中 @__DIR__ 不可用
		startswith(strip(code), "PLUTO_") && continue        # 环境快照 cell，跳过
		if occursin("@bind", code)
			skipped += 1
			println("cell $i: 跳过（含 @bind，需 Pluto 运行时）")
			continue
		end
		try
			include_string(NBTest, code, "cell$i")
			ok += 1
			println("cell $i: OK")
		catch e
			println("cell $i: FAIL -> ", e)
			error("notebook 自测失败")
		end
	end
	println("结果: $ok 个 cell 求值通过, $skipped 个跳过（@bind）")
end

run_notebook(joinpath(@__DIR__, "..", "notebooks", "mvp0_transmon.jl"))
println("NOTEBOOK SELF-TEST PASS")
