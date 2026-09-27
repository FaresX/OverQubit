# 色散读取引擎回归：JC χ、S21 hanger 形状。
using Test
using OverQubit

@testset "色散读取（χ / S21）" begin
    t = Transmon(20.0, 0.30; ncut=60)
    E_Cr, ωr = 0.06, 8.5
    f01c, alpha, g, chi, Delta = dispersive_params(t, 0.0, E_Cr, ωr)
    @testset "χ ≈ g²/Δ（JC 对角化 vs 微扰公式）" begin
        @test chi ≈ g^2 / Delta rtol = 0.02
    end
    @testset "χ 量级与符号（|0⟩/|1⟩ 曲线关于 ωr 对称：ωr∓χ）" begin
        @test sign(chi) == -1 && abs(chi) > 1e-4 && abs(chi) < 0.2
    end
    κ, κe, ω0 = 0.01, 0.008, 7.0
    @testset "S21 峰值 = κe/(κ/2)" begin
        @test abs(abs(s21(ω0, ω0, κ, κe)) - κe / (κ / 2)) < 1e-9
    end
    @testset "S21 半功率点在 ω0 ± κ/2" begin
        @test abs(abs(s21(ω0 + κ / 2, ω0, κ, κe)) - κe / (κ / 2) / sqrt(2)) < 1e-6
    end
end
