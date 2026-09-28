# 只跑指定 notebook 的自测（scripts/notebook_selftest.jl 的过滤版）。
# 用法：julia --project=. spike/selftest_two.jl            # 跑本轮负责的两个
#       julia --project=. spike/selftest_two.jl mvp0_transmon   # 只跑一个（参数是过滤正则）
# 背景：notebook_selftest.jl 跑全部 notebook，会在别人的（cz_* 等）失败处中断，
#       到不了 mvp0_transmon / flux_tuning，所以先用这个过滤版验收自己的两个。
const FILTER = isempty(ARGS) ? "flux_tuning|mvp0_transmon" : ARGS[1]
src = read(joinpath(@__DIR__, "..", "scripts", "notebook_selftest.jl"), String)
src = replace(src, "@__DIR__, \"..\"" => "SCRIPTDIR, \"..\"")
src = replace(src, "(endswith(f, \".jl\") && !occursin(\"backup\", f)) && run_notebook(" =>
	"(endswith(f, \".jl\") && occursin(r\"" * FILTER * "\", f)) && run_notebook(")
src = "const SCRIPTDIR = " * repr(joinpath(@__DIR__, "..", "scripts")) * "\n" * src
include_string(Main, src, joinpath(@__DIR__, "..", "scripts", "notebook_selftest.jl"))
