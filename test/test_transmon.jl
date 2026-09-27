# transmon 能谱回归：scqubits 黄金向量 + SQUID 磁通调谐。
# 黄金向量由 scripts/generate_golden.py 生成（scqubits Transmon, ncut=101）。
using Test
using OverQubit

include(joinpath(@__DIR__, "golden_transmon.jl"))

@testset "transmon 能谱" begin
    @testset "黄金向量 EJ=$(g.EJ) EC=$(g.EC) ng=$(g.ng)" for g in GOLDEN
        t = Transmon(g.EJ, g.EC; ncut = 50)
        e = eigenenergies(t, g.ng)
        @test e[2] - e[1] ≈ g.e01 rtol = 1e-6
        @test e[3] - e[2] ≈ g.e12 rtol = 1e-6
        @test e[4] - e[3] ≈ g.e23 rtol = 1e-6
    end
end

@testset "磁通调谐（SQUID E_J(Φ)）" begin
    @testset "E_J(Φ) 形状" begin
        @test squid_ej(20.0, 0.0) ≈ 20.0 atol = 1e-12          # Φ=0 = E_J0
        @test abs(squid_ej(20.0, 0.5)) < 1e-12                 # D=0 半量子处塌掉
        @test squid_ej(20.0, 0.5; D=0.1) ≈ 2.0 atol = 1e-12    # D 保留有限 E_J
    end
    t = Transmon(20.0, 0.30; ncut=60)
    f01 = f01_f12(t)[1]
    @testset "Φ=0 与基准 transmon 一致" begin
        @test f01_f12(transmon_at_flux(20.0, 0.30, 0.0; ncut=60))[1] ≈ f01 atol = 1e-12
    end
    e = eigenenergies(transmon_at_flux(20.0, 0.30, 0.5; ncut=60))
    @testset "D=0、Φ=0.5 回到纯电荷极限" begin
        @test (e[2] - e[1]) ≈ 4 * 0.30 atol = 1e-8             # f01 = 4E_C
        @test ((e[3] - e[2]) - (e[2] - e[1])) ≈ -4 * 0.30 atol = 1e-8   # 非谐性 = −4E_C（Δ₂=0）
    end
    @testset "f01(|Φ|) 单调下降（甜点单调性）" begin
        fs = [f01_f12(transmon_at_flux(20.0, 0.30, φ; ncut=40))[1] for φ in [0.0, 0.1, 0.2, 0.35, 0.45]]
        @test issorted(-fs)
    end
    @testset "电荷色散随磁通指数增长" begin
        bw = Float64[]
        for φ in [0.0, 0.25, 0.4, 0.45]
            tb = transmon_at_flux(20.0, 0.30, φ; ncut=40)
            _, Es = charge_dispersion(tb, 41, 2)
            push!(bw, maximum(Es[:, 2] .- Es[:, 1]) - minimum(Es[:, 2] .- Es[:, 1]))
        end
        @test issorted(bw) && bw[4] > 100bw[1]
    end
end
