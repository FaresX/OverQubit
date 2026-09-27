# 两比特耦合引擎回归：iSWAP 交换率、ZZ、全电荷基交叉验证。
using Test
using OverQubit

@testset "两比特耦合（TwoQubit）" begin
    t = Transmon(20.0, 0.30; ncut=60)
    n01 = abs(charge_matrix_element(t, 0, 1))
    t2 = Transmon(20.0 * (1 - 0.03), 0.30; ncut=40)
    TQ = TwoQubit(t, t2, 0.05; nlev=3)
    J = exchange_rate(TQ)
    ZZ = zz_rate(TQ)
    @testset "J ≈ g_c·n01²" begin
        @test J ≈ 0.05 * n01^2 rtol = 0.05
    end
    @testset "|0,1⟩/|1,0⟩ 劈裂 = √(δ²+(2J)²)：全电荷基 vs 有效模型" begin
        ev = coupled_spectrum(t, t2, 0.05, 0.0)
        δb = bare_detuning(TQ)
        # 全电荷基（1681 维）最低 8 个能级差里，找与交换劈裂 2J 相符的那个
        dv = [ev.values[i + 1] - ev.values[i] for i in 1:8]
        Δeff = sqrt(δb^2 + 4J^2)
        # |0,1⟩/|1,0⟩ 的劈裂应在子空间内：允许 5% 偏差
        @test any(abs.(dv .- Δeff) ./ Δeff .< 0.05)
    end
    @testset "iSWAP 动力学与解析公式逐点一致（P10 = [4J²/(δ²+4J²)]·sin²(πΩt)）" begin
        TQ2 = TwoQubit(t, t2, 0.05; nlev=2)
        J2 = exchange_rate(TQ2); δb = bare_detuning(TQ2)
        psi0 = zeros(TQ2.nlev^2); psi0[basis_index(TQ2, 0, 1)] = 1.0
        Ω = sqrt(δb^2 + 4J2^2)                 # GHz（子空间本征劈裂）
        times = collect(range(0.0, 3 / Ω; length=301))   # 覆盖 3 个振荡周期
        _, pop, _, _ = evolve_two_qubit(TQ2, psi0, times)
        pred = (4J2^2 / Ω^2) .* sin.(π .* Ω .* times) .^ 2
        num = pop[:, basis_index(TQ2, 1, 0)]
        @test maximum(abs.(num .- pred)) < 0.01
        # 峰位对比不能用全局 argmax（多周期采样下 sin² 峰恰好是采样点，浮点噪声让
        # argmax 随机落到任意一个峰上）；取前 1/3 时窗（恰含第一个峰）的 argmax。
        tPeak = times[argmax(num[1:div(end, 3)])]
        @test tPeak ≈ 1 / (2Ω) atol = times[end] / 100
    end
    @testset "nlev=3（含 |2⟩）：首峰位置与 nlev=2 解析式一致（高能级只降峰高）" begin
        psi0 = zeros(TQ.nlev^2); psi0[basis_index(TQ, 0, 1)] = 1.0
        δb = bare_detuning(TQ)
        Ω = sqrt(δb^2 + 4J^2)
        times = collect(range(0.0, 1.2 / Ω; length=241))    # 覆盖第一个峰
        _, pop, _, _ = evolve_two_qubit(TQ, psi0, times)
        num = pop[:, basis_index(TQ, 1, 0)]
        tPeak = times[argmax(num[1:div(end, 2)])]           # 前半段内的峰
        @test tPeak ≈ 1 / (2Ω) atol = 1 / (20Ω)
        @test maximum(num) < 4J^2 / Ω^2 + 0.03
        @test findfirst(num .> 0.5 * maximum(num)) !== nothing
    end
    @testset "两能级截断下 ZZ ≡ 0（非谐性是 ZZ 的必要条件）" begin
        @test abs(zz_rate(TwoQubit(t, t2, 0.05; nlev=2))) < 1e-12
    end
    @testset "三能级截断下 ZZ ≠ 0" begin
        @test abs(ZZ) > 1e-5
    end
    @testset "ZZ ∝ g_c²（小耦合段）：ZZ(0.05)/ZZ(0.025) ≈ 4" begin
        z2 = zz_rate(TwoQubit(t, t2, 0.025; nlev=3))
        @test 3.5 < ZZ / z2 < 4.5
    end
    @testset "全电荷基中 |0,0⟩ = 0、ncut=20 与 ncut=40 谱一致（收敛）" begin
        e20 = coupled_spectrum(Transmon(20.0, 0.30; ncut=20), t2, 0.05, 0.0).values
        e40 = coupled_spectrum(t, t2, 0.05, 0.0).values
        @test maximum(abs.(e20[1:5] .- e40[1:5])) < 1e-6
    end
    @testset "布居守恒 + Bloch 提取正确（|01⟩ 初态）" begin
        psi0 = zeros(TQ.nlev^2); psi0[basis_index(TQ, 0, 1)] = 1.0
        _, pop, b1q, b2q = evolve_two_qubit(TQ, psi0, [0.0, 5.0])
        @test pop[1, basis_index(TQ, 0, 1)] ≈ 1 atol = 1e-12
        @test b1q[1, 3] ≈ 1 atol = 1e-12
        @test b2q[1, 3] ≈ -1 atol = 1e-12
        @test sum(pop[2, :]) ≈ 1 atol = 1e-9
    end
end
