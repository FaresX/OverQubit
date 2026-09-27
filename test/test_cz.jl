# CZ 门引擎回归：与 TwoQubit 一致性、酉性、avoided crossing 谱学、门质量、收敛、chevron 网格。
using Test
using OverQubit
using LinearAlgebra

# 把角度归一化到 (−π, π]（测试用）
_wrappi_rad(x::Real) = x - 2π * round(x / (2π))

@testset "CZ 门引擎" begin
    EJ1, EJ2, EC, gc = 20.0, 24.0, 0.30, 0.03
    dev = cz_pair(EJ1, EJ2, EC, gc; nlev=3, ncut=40)
    t1 = Transmon(EJ1, EC; ncut=40)
    t2 = Transmon(EJ2, EC; ncut=40)
    TQ = TwoQubit(t1, t2, gc; nlev=3)
    I9 = Matrix(1.0 * I, 9, 9)
    cidx = [basis_index(dev, k1, k2) for k1 in 0:1, k2 in 0:1]
    phi_s, gap_s = cz_crossing(dev; span=0.45, npoints=181)   # avoided crossing 工作点（后面多组测试用到）

    @testset "与既有引擎的一致性" begin
        @testset "Φ=0 的哈密顿量与 TwoQubit.H 逐项一致" begin
            @test maximum(abs.(Matrix(cz_hamiltonian(dev, 0.0)) .- TQ.H)) < 1e-9
        end
        # 恒定 H：分三个时刻与已验证的 evolve_two_qubit 逐点对照布居（4 个计算基初态）
        @testset "恒定 H 下末态布居与 evolve_two_qubit 一致" begin
            worst = 0.0
            for T in [20.0, 60.0, 120.0]
                rr = cz_evolve(dev, 0.0, 20.0; T_ns=T, dt=0.05)
                times = collect(0.0:0.05:T)
                for c in cidx
                    psi0 = zeros(9); psi0[c] = 1.0
                    _, pop, _, _ = evolve_two_qubit(TQ, psi0, times)
                    worst = max(worst, maximum(abs.(pop[end, :] .- abs2.(rr.U[:, c]))))
                end
            end
            @test worst < 1e-9
        end
        # idle ZZ：条件相位在 idle 段应以 2π·(4 态能级组合) 的速度线性增长
        @testset "idle 条件相位速率 = −2π·(谱学 4 态组合)" begin
            r0 = cz_evolve(dev, 0.0, 1.0; T_ns=200.0, dt=0.05)
            E, U = cz_levels(dev, 0.0)
            idx = [argmax(abs2.(view(U, ci, :))) for ci in cidx]
            comb = E[idx[1]] - E[idx[2]] - E[idx[3]] + E[idx[4]]      # GHz
            m = (r0.times .> 100) .& (r0.times .< 190)
            slope = (r0.cphase[m][end] - r0.cphase[m][1]) / (r0.times[m][end] - r0.times[m][1])
            @test abs(slope + 2π * comb) < 2e-3
        end
        @testset "去包裹相位与末态 Urel 自洽（mod 2π）" begin
            r0 = cz_evolve(dev, 0.0, 1.0; T_ns=200.0, dt=0.05)
            @test abs(_wrappi_rad(r0.cphase[end] - cz_conditional_phase(r0.Urel, 3))) < 1e-6
        end
    end

    @testset "酉性与参考演化" begin
        r = cz_evolve(dev, 0.073, 37.5; kind=:taper, dt=0.05)
        @testset "U 酉" begin
            @test maximum(abs.(r.U' * r.U .- I9)) < 1e-10
        end
        @testset "Urel = U·U_ref† 也酉" begin
            @test maximum(abs.(r.Urel' * r.Urel .- I9)) < 1e-10
        end
        dev0 = cz_pair(EJ1, EJ2, EC, 0.0; nlev=3, ncut=40)        # 关掉耦合
        rn = cz_evolve(dev0, 0.12, 30.0; kind=:taper, dt=0.05)
        @testset "g_c = 0 时条件相位恒为 0（耦合是条件相位的唯一来源）" begin
            @test abs(cz_conditional_phase(rn.Urel, dev0.nlev)) < 1e-9
            @test maximum(abs.(rn.cphase)) < 1e-9
        end
        @testset "g_c = 0 时无泄漏（两比特各自演化）" begin
            @test cz_leakage(rn.U, dev0.nlev) < 1e-9
        end
        rp = cz_evolve(dev, 0.10, 30.0; kind=:taper, dt=0.05)     # H(Φ) 偶函数
        rm = cz_evolve(dev, -0.10, 30.0; kind=:taper, dt=0.05)
        @testset "H(Φ) 对 Φ 偶对称 → ±amp 的脉冲完全相同" begin
            @test maximum(abs.(rp.U .- rm.U)) < 1e-12
            @test maximum(abs.(rp.phis .+ rm.phis)) < 1e-12
        end
    end

    @testset "谱学：avoided crossing" begin
        alpha2 = f01_f12(t2)[2] - f01_f12(t2)[1]
        det_s = cz_detuning(dev, phi_s)
        @testset "Φ* 处 gap 远小于 idle 处" begin
            @test gap_s < 0.5 * cz_gap(dev, 0.0)
        end
        @testset "crossing 判据 δ(Φ*) ≈ α₂" begin
            @test det_s ≈ alpha2 rtol = 0.15
        end
        @testset "f01₂ 随 Φ 单调下降（磁通只会拧小 E_J）" begin
            fs = [f01_f12(Transmon(cz_squid_ej(dev, φ), EC; ncut=40))[1] for φ in [0.0, 0.05, 0.1, 0.15, 0.2]]
            @test issorted(-fs)
        end
        @testset "Φ=0 的谱与 TwoQubit 同（9 个本征值）" begin
            @test maximum(abs.(sort(eigvals(Symmetric(Float64.(TQ.H))) ./ 2π) .- cz_levels(dev, 0.0)[1])) < 1e-9
        end
    end

    r = cz_evolve(dev, 0.073, 37.5; kind=:taper, dt=0.05)
    phase, phase_err, leak, f_proc, f_state = cz_metrics(r)
    p1, in_sub = cz_ramsey(cz_zcorrect(r), r.nlev)          # 实验口径（虚拟 Z 已校正）
    p1a, p1b, ph_pair = cz_ramsey_pair(r)

    @testset "门质量读数" begin
        @testset "默认工作点就是 CZ：|φ_CZ − π| < 0.08" begin
            @test phase_err < 0.08
        end
        @testset "门干净：泄漏 < 2%、4 态/过程保真度 > 99%" begin
            @test leak < 0.02 && f_state > 0.99 && f_proc > 0.99
        end
        @testset "Urel 条件相位 = Ramsey 两序列相减之差" begin
            @test abs(phase - ph_pair) < 1e-9
        end
        @testset "理想 CZ 的读数：phase=π、0 泄漏、保真度 1、Ramsey P₁=0" begin
            Ui = Matrix(1.0 * I, 9, 9); Ui[5, 5] = -1.0
            ph, e, l, fp, fs = cz_metrics(ComplexF64.(Ui), 3)
            @test abs(e) < 1e-12 && l < 1e-12 && fp > 1 - 1e-12 && fs > 1 - 1e-12 && abs(ph - π) < 1e-12
            @test cz_ramsey(ComplexF64.(Ui), 3)[1] < 1e-12
        end
        @testset "条件 Bloch 矢量终点 ≈ (−1, 0, 0)：qubit1 确实转了 π" begin
            @test maximum(abs.(r.cond_bloch[end, :] .- [-1.0, 0.0, 0.0])) < 0.05
        end
        @testset "|1,1⟩ 末态几乎完全回到 |1,1⟩" begin
            @test r.pops11[end, cidx[4]] > 0.99
        end
    end

    @testset "数值收敛与波形物理" begin
        rA = cz_evolve(dev, 0.073, 37.5; kind=:taper, dt=0.02)
        rB = cz_evolve(dev, 0.073, 37.5; kind=:taper, dt=0.005)
        @testset "步长收敛：dt 0.02 vs 0.005 → Δφ < 5e-3 rad" begin
            @test abs(cz_conditional_phase(rA.Urel, 3) - cz_conditional_phase(rB.Urel, 3)) < 5e-3
        end
        rF = cz_evolve(dev, 0.073, 37.5; kind=:flat, dt=0.05)
        lkf = cz_leakage(rF.U, 3)
        @testset "方沿泄漏远大于平滑沿（边沿非绝热激发）" begin
            @test lkf > 8 * leak
        end
        @testset "更长/更深脉冲把 |0,2⟩ excursion 推得更大（绝热深度）" begin
            probe(fa) = maximum(cz_evolve(dev, fa * phi_s, 20.0; kind=:taper, dt=0.05).pops11[:, basis_index(dev, 0, 2)])
            e1 = probe(0.3); e2 = probe(0.6); e3 = probe(1.0)
            @test e1 < e2 && e2 < e3 && e3 > 0.3
        end
        @testset "脉冲包络起止为 0、峰值 1" begin
            @test cz_pulse_shape(0.0; kind=:taper) == 0.0 && cz_pulse_shape(1.0; kind=:taper) == 0.0
            @test cz_pulse_shape(0.5; kind=:taper) ≈ 1.0 atol = 1e-12
            @test cz_pulse_shape(0.5; kind=:flat) == 1.0 && cz_pulse_shape(0.1; kind=:flat) == 0.0
        end
    end

    @testset "chevron 网格（校准 notebook 主图）" begin
        P1m, cphm, lkm = cz_chevron(dev, collect((0.45:0.15:1.2) .* phi_s), collect(22.0:6.0:46.0); dt=0.2)
        @testset "网格尺寸与取值域" begin
            @test size(P1m) == (6, 5)
            @test all(0 .<= P1m .<= 1) && all(0 .<= lkm .<= 1) && all(abs.(cphm) .<= π + 1e-9)
        end
        @testset "chevron 里存在工作点（最小 P1 < 0.1）" begin
            @test minimum(P1m) < 0.1
        end
        @testset "chevron 的暗瓣与默认工作点一致" begin
            @test p1 < 0.1
        end
    end
end
