# 单比特驱动动力学回归：载波引擎（Rabi/泄漏）+ 旋转坐标系序列引擎（π 脉冲/T1/T2/Ramsey/回波）。
using Test
using OverQubit
using Statistics

# 布居上升沿 0.5 穿越（用于从数值曲线读 Rabi 周期）
function crossing(ts, y; maxc=6)
    out = Float64[]
    for i in 2:size(y, 1)
        if y[i - 1] < 0.5 <= y[i]
            f = (0.5 - y[i - 1]) / (y[i] - y[i - 1])
            push!(out, ts[i - 1] + f * (ts[i] - ts[i - 1]))
            length(out) >= maxc && break
        end
    end
    out
end

# log-线性拟合斜率（T1 / T2 的指数衰减读数）
slope_fit(τ, y) = sum((τ .- mean(τ)) .* (log.(y) .- mean(log.(y)))) / sum((τ .- mean(τ)) .^ 2)

@testset "载波驱动引擎（evolve_density）" begin
    t = Transmon(20.0, 0.30; ncut=60)
    n01 = abs(charge_matrix_element(t, 0, 1))
    f01 = f01_f12(t)[1]
    amp = 0.05
    ts, pops, bloch = evolve_density(t, 0.0, f01, amp, 300.0, 100.0)
    @testset "Rabi 频率 = amp·n01" begin
        cr = crossing(ts, pops[:, 2])
        ΩR_num = length(cr) >= 2 ? 1 / ((cr[end] - cr[1]) / (length(cr) - 1)) : NaN
        @test ΩR_num ≈ amp * n01 rtol = 0.02
    end
    @testset "共振驱动布居反转" begin
        @test maximum(pops[:, 2]) > 0.95
    end
    @testset "Bloch 矢量保持在单位球上" begin
        @test maximum(abs.(sqrt.(sum(bloch .^ 2; dims=2)) .- 1)) < 0.02
    end
    @testset "弱驱动 |2⟩ 泄漏 < 2%（两能级近似）" begin
        @test maximum(pops[:, 3]) < 0.02
    end
    @testset "强驱动泄漏显著增长（DRAG 动机）" begin
        _, pops_strong, _ = evolve_density(t, 0.0, f01, 0.10, 300.0, 100.0)
        @test maximum(pops_strong[:, 3]) > 3 * maximum(pops[:, 3])
    end
    @testset "两套引擎 Rabi 口径一致（高斯 σ→∞ 近似常值驱动）" begin
        tsC, pC, _ = evolve_density(t, 0.0, f01, 0.10, 200.0, 60.0; dt=0.02)
        crC = crossing(tsC, pC[:, 2]; maxc=3)
        ΩC = 1 / ((crC[end] - crC[1]) / (length(crC) - 1))
        @test ΩC ≈ 0.10 * n01 rtol = 0.05
    end
end

@testset "旋转坐标系序列引擎（evolve_segments）" begin
    t = Transmon(20.0, 0.30; ncut=60)
    n01 = abs(charge_matrix_element(t, 0, 1))
    drvamp = 0.10
    T90 = 1 / (4 * drvamp * n01)
    Tpi = 2 * T90
    @testset "π 脉冲后 p1 ≈ 1" begin
        _, pp, _ = evolve_segments(t, 0.0, [(T=Tpi, amp=drvamp, phase=0.0)]; dt=0.01)
        @test abs(pp[end, 2] - 1) < 5e-3
    end
    @testset "Rabi 频率 = drvamp·n01" begin
        tsR, pR, _ = evolve_segments(t, 0.0, [(T=40.0, amp=drvamp, phase=0.0)]; dt=0.05)
        cr = crossing(tsR, pR[:, 2])
        Ωnum = 1 / ((cr[end] - cr[1]) / (length(cr) - 1))
        @test Ωnum ≈ drvamp * n01 rtol = 0.02
    end
    @testset "驱动相位 → 旋转轴（0°→x，90°→y）" begin
        _, _, b0 = evolve_segments(t, 0.0, [(T=T90, amp=drvamp, phase=0.0)]; dt=0.02)
        _, _, b90 = evolve_segments(t, 0.0, [(T=T90, amp=drvamp, phase=90.0)]; dt=0.02)
        @test abs(b0[end, 2] - 1) < 5e-3
        @test abs(b90[end, 1] - 1) < 5e-3
    end
    @testset "T1：设定 30 μs" begin
        γ1 = 1 / 30000.0
        ts1, p1_, _ = evolve_segments(t, 0.0,
            [(T=Tpi, amp=drvamp, phase=0.0), (T=6 * 30000.0, amp=0.0, dt=50.0)]; gamma1=γ1, dt=0.02)
        m = ts1 .> Tpi + 10
        τ1 = ts1[m] .- ts1[m][1]
        T1m = -1 / slope_fit(τ1, p1_[m, 2])
        @test T1m ≈ 30000.0 rtol = 0.02
    end
    @testset "纯退相：T2 = Tφ = 50 μs（1/T2 = 1/(2T1) + 1/Tφ 的 T1→∞ 极限）" begin
        γφ = 1 / 50000.0
        ts2_, _, b2_ = evolve_segments(t, 0.0,
            [(T=T90, amp=drvamp, phase=0.0), (T=8 * 25000.0, amp=0.0, dt=10.0)]; gammaphi=γφ, dt=0.02)
        coh = sqrt.(b2_[:, 1] .^ 2 .+ b2_[:, 2] .^ 2) ./ 2
        m2 = ts2_ .> T90 + 100
        T2m = -1 / slope_fit(ts2_[m2] .- ts2_[m2][1], coh[m2])
        @test T2m ≈ 1 / γφ rtol = 0.02
    end
    δ = 3e-5
    @testset "Ramsey 条纹（零时刻零点 / ½ 周期峰 / 整周期零点）" begin
        _, _, b0 = evolve_segments(t, 0.0, [(T=T90, amp=drvamp, phase=0.0)]; detune=δ, dt=0.02)
        _, _, bH = evolve_segments(t, 0.0,
            [(T=T90, amp=drvamp, phase=0.0), (T=1 / (2δ), amp=0.0, dt=1 / (2δ))]; detune=δ, dt=0.02)
        _, _, bF = evolve_segments(t, 0.0,
            [(T=T90, amp=drvamp, phase=0.0), (T=1 / δ, amp=0.0, dt=1 / δ)]; detune=δ, dt=0.02)
        @test abs((1 - b0[end, 2]) / 2) < 0.01
        @test abs((1 - bH[end, 2]) / 2 - 1) < 0.01
        @test abs((1 - bF[end, 2]) / 2) < 0.01
    end
    @testset "自旋回波抵消静态失谐" begin
        _, pE_, _ = evolve_segments(t, 0.0,
            [(T=T90, amp=drvamp, phase=0.0), (T=2000.0, amp=0.0, dt=100.0),
             (T=Tpi, amp=drvamp, phase=0.0), (T=2000.0, amp=0.0, dt=100.0),
             (T=T90, amp=drvamp, phase=180.0)]; detune=δ, dt=0.02)
        _, pNm, _ = evolve_segments(t, 0.0,
            [(T=T90, amp=drvamp, phase=0.0), (T=2000.0, amp=0.0, dt=100.0),
             (T=T90, amp=drvamp, phase=180.0)]; detune=δ, dt=0.02)
        @test pE_[end, 2] > 0.95
        @test pNm[end, 2] < 0.2
    end
    @testset "段内大采样间隔仍精确（传播子无截断误差）" begin
        _, pFine, _ = evolve_segments(t, 0.0, [(T=T90, amp=drvamp, phase=0.0), (T=500.0, amp=0.0, dt=0.02)],
            detune=δ, dt=0.02)
        _, pCoarse, _ = evolve_segments(t, 0.0, [(T=T90, amp=drvamp, phase=0.0), (T=500.0, amp=0.0, dt=500.0)],
            detune=δ, dt=0.02)
        @test abs(pFine[end, 2] - pCoarse[end, 2]) < 1e-9
    end
end
