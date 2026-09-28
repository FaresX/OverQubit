# 指定 notebook 名生成预览页（preview_any.jl 的命令行包装，免去设环境变量）。
# 用法：julia --project=. spike/preview_named.jl mvp0_transmon
ENV["NB"] = isempty(ARGS) ? "mvp0_transmon" : ARGS[1]
include(joinpath(@__DIR__, "preview_any.jl"))
