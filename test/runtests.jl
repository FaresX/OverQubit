# OverQubit 物理层回归测试（Pkg.test() 入口）。
# 单独跑某一组：julia --project=. test/test_cz.jl
using Test
using OverQubit

@testset "OverQubit" begin
    include("test_transmon.jl")
    include("test_readout.jl")
    include("test_dynamics.jl")
    include("test_two_qubit.jl")
    include("test_cz.jl")
end
