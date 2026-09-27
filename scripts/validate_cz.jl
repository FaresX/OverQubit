# CZ 门引擎验收：磁通脉冲穿越 |11⟩ ↔ |02⟩ avoided crossing 的动力学 + 校准可观测量。
# 用法：julia --project=. scripts/validate_cz.jl
include(joinpath(@__DIR__, "..", "src", "OverQubit.jl"))
using .OverQubit
using LinearAlgebra

ok = Ref(true)
check(name, cond) = (println(cond ? "PASS  " : "FAIL  ", name); ok[] &= cond)

function main()
    EJ1, EJ2, EC, gc = 20.0, 24.0, 0.30, 0.03
    dev = cz_pair(EJ1, EJ2, EC, gc; nlev=3, ncut=40)
    t1 = Transmon(EJ1, EC; ncut=40)
    t2 = Transmon(EJ2, EC; ncut=40)
    TQ = TwoQubit(t1, t2, gc; nlev=3)
    I9 = Matrix(1.0 * I, 9, 9)
    cidx = [basis_index(dev, k1, k2) for k1 in 0:1, k2 in 0:1]

    println("— 1) 与既有引擎的一致性 —")
    check("Φ=0 的哈密顿量与 TwoQubit.H 逐项一致（差 $(round(maximum(abs.(Matrix(cz_hamiltonian(dev, 0.0)) .- TQ.H)), sigdigits=3))）",
        maximum(abs.(Matrix(cz_hamiltonian(dev, 0.0)) .- TQ.H)) < 1e-9)
    # 恒定 H：分三个时刻与已验证的 evolve_two_qubit 逐点对照布居（4 个计算基初态）
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
    check("恒定 H 下末态布居与 evolve_two_qubit 一致（最大差 $(round(worst, sigdigits=3))）", worst < 1e-9)
    # idle ZZ：条件相位在 idle 段应以 2π·(4 态能级组合) 的速度线性增长
    r0 = cz_evolve(dev, 0.0, 1.0; T_ns=200.0, dt=0.05)
    E, U = cz_levels(dev, 0.0)
    idx = [argmax(abs2.(view(U, ci, :))) for ci in cidx]
    comb = E[idx[1]] - E[idx[2]] - E[idx[3]] + E[idx[4]]      # GHz
    m = (r0.times .> 100) .& (r0.times .< 190)
    slope = (r0.cphase[m][end] - r0.cphase[m][1]) / (r0.times[m][end] - r0.times[m][1])
    check("idle 条件相位速率 = −2π·(谱学 4 态组合)：数值 $(round(slope, digits=5)) vs $(round(-2π * comb, digits=5)) rad/ns",
        abs(slope + 2π * comb) < 2e-3)
    check("去包裹相位与末态 Urel 自洽（mod 2π）",
        abs(_wrappi_rad(r0.cphase[end] - cz_conditional_phase(r0.Urel, 3))) < 1e-6)

    println("— 2) 酉性与参考演化 —")
    r = cz_evolve(dev, 0.073, 37.5; kind=:taper, dt=0.05)
    check("U 酉（误差 $(round(maximum(abs.(r.U' * r.U .- I9)), sigdigits=3))）", maximum(abs.(r.U' * r.U .- I9)) < 1e-10)
    check("Urel = U·U_ref† 也酉", maximum(abs.(r.Urel' * r.Urel .- I9)) < 1e-10)
    dev0 = cz_pair(EJ1, EJ2, EC, 0.0; nlev=3, ncut=40)        # 关掉耦合
    rn = cz_evolve(dev0, 0.12, 30.0; kind=:taper, dt=0.05)
    check("g_c = 0 时条件相位恒为 0（耦合是条件相位的唯一来源）",
        abs(cz_conditional_phase(rn.Urel, dev0.nlev)) < 1e-9 && maximum(abs.(rn.cphase)) < 1e-9)
    check("g_c = 0 时无泄漏（两比特各自演化）：泄漏 $(round(cz_leakage(rn.U, dev0.nlev), sigdigits=3))",
        cz_leakage(rn.U, dev0.nlev) < 1e-9)
    rp = cz_evolve(dev, 0.10, 30.0; kind=:taper, dt=0.05)     # H(Φ) 偶函数
    rm = cz_evolve(dev, -0.10, 30.0; kind=:taper, dt=0.05)
    check("H(Φ) 对 Φ 偶对称 → ±amp 的脉冲完全相同",
        maximum(abs.(rp.U .- rm.U)) < 1e-12 && maximum(abs.(rp.phis .+ rm.phis)) < 1e-12)

    println("— 3) 谱学：avoided crossing —")
    phi_s, gap_s = cz_crossing(dev; span=0.45, npoints=181)
    t2s = Transmon(cz_squid_ej(dev, phi_s), EC; ncut=40)
    alpha2 = f01_f12(t2, 0.0)[2] - f01_f12(t2, 0.0)[1]
    det_s = cz_detuning(dev, phi_s)
    check("Φ* 处 gap 远小于 idle 处（$(round(gap_s * 1000, digits=1)) vs $(round(cz_gap(dev, 0.0) * 1000, digits=1)) MHz）",
        gap_s < 0.5 * cz_gap(dev, 0.0))
    check("crossing 判据 δ(Φ*) ≈ α₂：$(round(det_s * 1000, digits=1)) vs $(round(alpha2 * 1000, digits=1)) MHz（差 $(round(abs(det_s - alpha2) * 1000, digits=1))）",
        abs(det_s - alpha2) / abs(alpha2) < 0.15)
    check("f01₂ 随 Φ 单调下降（磁通只会拧小 E_J）",
        let fs = [f01_f12(Transmon(cz_squid_ej(dev, φ), EC; ncut=40), 0.0)[1] for φ in [0.0, 0.05, 0.1, 0.15, 0.2]]
            issorted(-fs)
        end)
    check("Φ=0 的谱与 TwoQubit 同（9 个本征值）",
        maximum(abs.(sort(eigvals(Symmetric(Float64.(TQ.H))) ./ 2π) .- cz_levels(dev, 0.0)[1])) < 1e-9)

    println("— 4) 门质量读数 —")
    phase, phase_err, leak, f_proc, f_state = cz_metrics(r)
    p1, in_sub = cz_ramsey(cz_zcorrect(r), r.nlev)          # 实验口径（虚拟 Z 已校正）
    p1a, p1b, ph_pair = cz_ramsey_pair(r)
    check("默认工作点就是 CZ：|φ_CZ − π| = $(round(phase_err, digits=4)) rad", phase_err < 0.08)
    check("门干净：泄漏 $(round(100leak, digits=2))%、4 态保真度 $(round(100f_state, digits=2))%、过程保真度 $(round(100f_proc, digits=2))%",
        leak < 0.02 && f_state > 0.99 && f_proc > 0.99)
    check("Urel 条件相位 = Ramsey 两序列（信号 q2=|1⟩ / 参考 q2=|0⟩）相减之差（差 $(round(abs(phase - ph_pair), sigdigits=2))）",
        abs(phase - ph_pair) < 1e-9)
    check("理想 CZ 的读数：phase=π、0 泄漏、保真度 1、Ramsey P₁=0",
        let Ui = Matrix(1.0 * I, 9, 9); Ui[5, 5] = -1.0
            ph, e, l, fp, fs = cz_metrics(ComplexF64.(Ui), 3)
            abs(e) < 1e-12 && l < 1e-12 && fp > 1 - 1e-12 && fs > 1 - 1e-12 && abs(ph - π) < 1e-12 &&
                cz_ramsey(ComplexF64.(Ui), 3)[1] < 1e-12
        end)
    check("条件 Bloch 矢量终点 ≈ (−1, 0, 0)：qubit1 确实转了 π（实测 $(round.(r.cond_bloch[end, :], digits=4))）",
        maximum(abs.(r.cond_bloch[end, :] .- [-1.0, 0.0, 0.0])) < 0.05)
    check("|1,1⟩ 末态几乎完全回到 |1,1⟩（$(round(100 * r.pops11[end, cidx[4]], digits=2))%）",
        r.pops11[end, cidx[4]] > 0.99)

    println("— 5) 数值收敛与波形物理 —")
    rA = cz_evolve(dev, 0.073, 37.5; kind=:taper, dt=0.02)
    rB = cz_evolve(dev, 0.073, 37.5; kind=:taper, dt=0.005)
    check("步长收敛：dt 0.02 vs 0.005 → Δφ = $(round(abs(cz_conditional_phase(rA.Urel, 3) - cz_conditional_phase(rB.Urel, 3)), digits=5)) rad",
        abs(cz_conditional_phase(rA.Urel, 3) - cz_conditional_phase(rB.Urel, 3)) < 5e-3)
    rF = cz_evolve(dev, 0.073, 37.5; kind=:flat, dt=0.05)
    lkf = cz_leakage(rF.U, 3)
    check("方沿泄漏远大于平滑沿（$(round(100lkf, digits=1))% vs $(round(100leak, digits=2))%）——边沿非绝热激发",
        lkf > 8 * leak)
    check("更长/更深脉冲把 |0,2⟩ excursion 推得更大（绝热深度的直接体现）",
        let probe(fa) = maximum(cz_evolve(dev, fa * phi_s, 20.0; kind=:taper, dt=0.05).pops11[:, basis_index(dev, 0, 2)])
            e1 = probe(0.3); e2 = probe(0.6); e3 = probe(1.0)
            e1 < e2 && e2 < e3 && e3 > 0.3
        end)
    check("脉冲包络起止为 0、峰值 1",
        cz_pulse_shape(0.0; kind=:taper) == 0.0 && cz_pulse_shape(1.0; kind=:taper) == 0.0 &&
            abs(cz_pulse_shape(0.5; kind=:taper) - 1.0) < 1e-12 &&
            cz_pulse_shape(0.5; kind=:flat) == 1.0 && cz_pulse_shape(0.1; kind=:flat) == 0.0)

    println("— 6) chevron 网格（校准 notebook 主图）—")
    P1m, cphm, lkm = cz_chevron(dev, collect((0.45:0.15:1.2) .* phi_s), collect(22.0:6.0:46.0); dt=0.2)
    check("网格尺寸与取值域（$(size(P1m))，P1 ∈ [$(round(minimum(P1m), digits=3)), $(round(maximum(P1m), digits=3))]）",
        size(P1m) == (6, 5) && all(0 .<= P1m .<= 1) && all(0 .<= lkm .<= 1) && all(abs.(cphm) .<= π + 1e-9))
    check("chevron 里存在工作点（最小 P1 = $(round(minimum(P1m), digits=4))）", minimum(P1m) < 0.1)
    check("chevron 的暗瓣与默认工作点一致（默认 P1 = $(round(p1, digits=4)) → 落在暗瓣里）", p1 < 0.1)

    ok[] || exit(1)
    println("\nCZ-ENGINE VALIDATION PASS")
end

"""把角度归一化到 (−π, π]（自测用）。"""
_wrappi_rad(x::Real) = x - 2π * round(x / (2π))

main()
