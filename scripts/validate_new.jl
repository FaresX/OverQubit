# 新增引擎物理验收：磁通调谐、两比特耦合、旋转坐标系序列（T1/T2/Ramsey/回波）。
# 用法：julia --project=. scripts/validate_new.jl
include(joinpath(@__DIR__, "..", "src", "OverQubit.jl"))
using .OverQubit
using Statistics

ok = Ref(true)
check(name, cond) = (println(cond ? "PASS  " : "FAIL  ", name); ok[] &= cond)

function slope_fit(τ, y)
    sum((τ .- mean(τ)) .* (log.(y) .- mean(log.(y)))) / sum((τ .- mean(τ)) .^ 2)
end

function main()
    t = Transmon(20.0, 0.30; ncut=60)
    f01, f12 = f01_f12(t, 0.0)
    α = f12 - f01
    n01 = abs(charge_matrix_element(t, 0, 1))

    println("— 1) 磁通调谐（SQUID E_J(Φ)）—")
    check("E_J(0) = E_J0（D=0）", abs(squid_ej(20.0, 0.0) - 20.0) < 1e-12)
    check("E_J(0.5) = 0（D=0，半量子磁通处塌掉）", abs(squid_ej(20.0, 0.5)) < 1e-12)
    check("E_J(0.5) = D·E_J0（不对称因子保留）", abs(squid_ej(20.0, 0.5; D=0.1) - 2.0) < 1e-12)
    t0 = transmon_at_flux(20.0, 0.30, 0.0; ncut=60)
    check("Φ=0 与基准 transmon 能级一致", abs(f01_f12(t0, 0.0)[1] - f01) < 1e-12)
    th = transmon_at_flux(20.0, 0.30, 0.5; D=0.0, ncut=60)
    e = eigenenergies(th, 0.0)
    check("D=0、Φ=0.5 回到纯电荷极限：f01 = 4E_C = $(round(e[2] - e[1], digits=8))",
        abs((e[2] - e[1]) - 4 * 0.30) < 1e-8)
    check("D=0、Φ=0.5 的非谐性 = −4E_C（Δ₂=0）", abs(((e[3] - e[2]) - (e[2] - e[1])) + 4 * 0.30) < 1e-8)
    # 甜点单调性：|Φ| 越小 E_J 越大 → f01 越大
    fs = [f01_f12(transmon_at_flux(20.0, 0.30, φ; ncut=40), 0.0)[1] for φ in [0.0, 0.1, 0.2, 0.35, 0.45]]
    check("f01(|Φ|) 单调下降：$(round.(fs, digits=4))", issorted(-fs))
    # 电荷色散随 E_J 塌缩而增大
    bw = let
        b = Float64[]
        for φ in [0.0, 0.25, 0.4, 0.45]
            tb = transmon_at_flux(20.0, 0.30, φ; ncut=40)
            _, Es = charge_dispersion(tb, 41, 2)
            push!(b, (maximum(Es[:, 2] .- Es[:, 1]) - minimum(Es[:, 2] .- Es[:, 1])))
        end
        b
    end
    check("电荷色散随磁通指数增长：$(round.(bw .* 1000, digits=4)) MHz", issorted(bw) && bw[4] > 100bw[1])

    println("— 2) 旋转坐标系序列引擎（Rabi / π 脉冲 / T1 / 退相 / Ramsey / 回波）—")
    drvamp = 0.10
    T90 = 1 / (4 * drvamp * n01)
    Tpi = 2 * T90
    # (a) π 脉冲
    _, pp, _ = evolve_segments(t, 0.0, [(T=Tpi, amp=drvamp, phase=0.0)]; dt=0.01)
    check("π 脉冲后 p1 = $(round(pp[end, 2], digits=5))", abs(pp[end, 2] - 1) < 5e-3)
    # (b) Rabi 频率 = drvamp·n01
    tsR, pR, _ = evolve_segments(t, 0.0, [(T=40.0, amp=drvamp, phase=0.0)]; dt=0.05)
    cr = Float64[]
    for i in 2:size(pR, 1)
        if pR[i - 1, 2] < 0.5 <= pR[i, 2]
            push!(cr, tsR[i - 1] + (0.5 - pR[i - 1, 2]) / (pR[i, 2] - pR[i - 1, 2]) * (tsR[i] - tsR[i - 1]))
            length(cr) >= 5 && break
        end
    end
    Ωnum = 1 / ((cr[end] - cr[1]) / (length(cr) - 1))
    check("Rabi 频率 数值 $(round(Ωnum, digits=5)) vs drvamp·n01 = $(round(drvamp * n01, digits=5)) GHz",
        abs(Ωnum - drvamp * n01) / (drvamp * n01) < 0.02)
    # (c) 与载波引擎 evolve_density 交叉验证（同样的 0.10 GHz 常值驱动）
    #     载波引擎是高斯包络，这里取 σ 远大于 T 的极限（近似常值）并只比前两个 Rabi 峰的位置
    tsC, pC, _ = evolve_density(t, 0.0, f01, 0.10, 200.0, 60.0; dt=0.02)
    crC = Float64[]
    for i in 2:size(pC, 1)
        if pC[i - 1, 2] < 0.5 <= pC[i, 2]
            push!(crC, tsC[i - 1] + (0.5 - pC[i - 1, 2]) / (pC[i, 2] - pC[i - 1, 2]) * (tsC[i] - tsC[i - 1]))
            length(crC) >= 3 && break
        end
    end
    ΩC = 1 / ((crC[end] - crC[1]) / (length(crC) - 1))
    check("两套引擎 Rabi 口径一致：载波 $(round(ΩC, digits=5)) vs 序列 $(round(drvamp * n01, digits=5)) GHz（相对差 $(round(abs(ΩC - drvamp * n01) / (drvamp * n01) * 100, digits=1))%）",
        abs(ΩC - drvamp * n01) / (drvamp * n01) < 0.05)
    # (d) 驱动相位 → 旋转轴
    _, _, b0 = evolve_segments(t, 0.0, [(T=T90, amp=drvamp, phase=0.0)]; dt=0.02)
    _, _, b90 = evolve_segments(t, 0.0, [(T=T90, amp=drvamp, phase=90.0)]; dt=0.02)
    check("phase=0 → 绕 x 转（到 +ŷ），phase=90° → 绕 y 转（到 +x̂）",
        abs(b0[end, 2] - 1) < 5e-3 && abs(b90[end, 1] - 1) < 5e-3)
    # (e) T1
    γ1 = 1 / 30000.0
    ts1, p1_, _ = evolve_segments(t, 0.0,
        [(T=Tpi, amp=drvamp, phase=0.0), (T=6 * 30000.0, amp=0.0, dt=50.0)]; gamma1=γ1, dt=0.02)
    m = ts1 .> Tpi + 10
    τ1 = ts1[m] .- ts1[m][1]
    T1m = -1 / slope_fit(τ1, p1_[m, 2])
    check("T1 设定 30 μs → 实测 $(round(T1m / 1000, digits=2)) μs", abs(T1m - 30000.0) / 30000.0 < 0.02)
    # (f) 纯退相 → 1/T2 = 1/(2T1) + 1/Tφ
    γφ = 1 / 50000.0
    ts2_, _, b2_ = evolve_segments(t, 0.0,
        [(T=T90, amp=drvamp, phase=0.0), (T=8 * 25000.0, amp=0.0, dt=10.0)]; gammaphi=γφ, dt=0.02)
    coh = sqrt.(b2_[:, 1] .^ 2 .+ b2_[:, 2] .^ 2) ./ 2
    m2 = ts2_ .> T90 + 100
    T2m = -1 / slope_fit(ts2_[m2] .- ts2_[m2][1], coh[m2])
    T2th = 1 / (γφ)
    check("纯退相 Tφ 设定 50 μs → 实测相干时间 $(round(T2m / 1000, digits=2)) μs", abs(T2m - T2th) / T2th < 0.02)
    # (g) Ramsey 条纹：p1 = (1 − y)/2 = ½[1 + cos(2πδτ)]；零点是 T=0，峰在 ½ 周期
    δ = 3e-5
    _, _, b0 = evolve_segments(t, 0.0, [(T=T90, amp=drvamp, phase=0.0)]; detune=δ, dt=0.02)
    _, _, bH = evolve_segments(t, 0.0,
        [(T=T90, amp=drvamp, phase=0.0), (T=1 / (2δ), amp=0.0, dt=1 / (2δ))]; detune=δ, dt=0.02)
    _, _, bF = evolve_segments(t, 0.0,
        [(T=T90, amp=drvamp, phase=0.0), (T=1 / δ, amp=0.0, dt=1 / δ)]; detune=δ, dt=0.02)
    p0 = (1 - b0[end, 2]) / 2
    pH = (1 - bH[end, 2]) / 2
    pF = (1 - bF[end, 2]) / 2
    check("Ramsey 零时刻在零点：p1 = $(round(p0, digits=5))", abs(p0) < 0.01)
    check("Ramsey ½ 周期（T=1/(2δ)）回到峰：p1 = $(round(pH, digits=5))", abs(pH - 1) < 0.01)
    check("Ramsey 整周期回到零点：p1 = $(round(pF, digits=5))", abs(pF) < 0.01)
    # (h) 自旋回波抵消静态失谐
    _, pE_, _ = evolve_segments(t, 0.0,
        [(T=T90, amp=drvamp, phase=0.0), (T=2000.0, amp=0.0, dt=100.0),
         (T=Tpi, amp=drvamp, phase=0.0), (T=2000.0, amp=0.0, dt=100.0),
         (T=T90, amp=drvamp, phase=180.0)]; detune=δ, dt=0.02)
    _, pNm, _ = evolve_segments(t, 0.0,
        [(T=T90, amp=drvamp, phase=0.0), (T=2000.0, amp=0.0, dt=100.0),
         (T=T90, amp=drvamp, phase=180.0)]; detune=δ, dt=0.02)
    check("自旋回波把静态失谐折返：回波 p1=$(round(pE_[end, 2], digits=4)) vs Rabi=$(round(pNm[end, 2], digits=4))",
        pE_[end, 2] > 0.95 && pNm[end, 2] < 0.2)
    # (i) 段内采样间隔不影响结果（传播子精确）
    _, pFine, _ = evolve_segments(t, 0.0, [(T=T90, amp=drvamp, phase=0.0), (T=500.0, amp=0.0, dt=0.02)],
        detune=δ, dt=0.02)
    _, pCoarse, _ = evolve_segments(t, 0.0, [(T=T90, amp=drvamp, phase=0.0), (T=500.0, amp=0.0, dt=500.0)],
        detune=δ, dt=0.02)
    check("自由段大采样间隔仍精确（差 $(round(abs(pFine[end, 2] - pCoarse[end, 2]), digits=2))）",
        abs(pFine[end, 2] - pCoarse[end, 2]) < 1e-9)

    println("— 3) 两比特耦合（iSWAP / ZZ / 全电荷基交叉验证）—")
    t2 = Transmon(20.0 * (1 - 0.03), 0.30; ncut=40)
    TQ = TwoQubit(t, t2, 0.05; nlev=3)
    J = exchange_rate(TQ)
    ZZ = zz_rate(TQ)
    check("J ≈ g_c·n01²：$(round(J * 1000, digits=2)) vs $(round(0.05 * n01^2 * 1000, digits=2)) MHz（差 $(round(abs(J - 0.05 * n01^2) / (0.05 * n01^2) * 100, digits=1))%）",
        abs(J - 0.05 * n01^2) / (0.05 * n01^2) < 0.05)
    check("|0,1⟩/|1,0⟩ 子空间劈裂 Δ = √(δ²+(2J)²)：全电荷基 vs 有效模型",
        let ev = coupled_spectrum(t, t2, 0.05, 0.0)
            δb = bare_detuning(TQ)
            # 全电荷基（1681 维）最低 8 个能级差里，找与交换劈裂 2J 相符的那个
            dv = [ev.values[i + 1] - ev.values[i] for i in 1:8]
            Δeff = sqrt(δb^2 + 4J^2)
            # |0,1⟩/|1,0⟩ 的劈裂应在子空间内：允许 5% 偏差
            any(abs.(dv .- Δeff) ./ Δeff .< 0.05)
        end)
    check("iSWAP 动力学与解析公式逐点一致（P10 = [4J²/(δ²+4J²)]·sin²(πΩt)）",
        let TQ2 = TwoQubit(t, t2, 0.05; nlev=2)
            J2 = exchange_rate(TQ2); δb = bare_detuning(TQ2)
            psi0 = zeros(TQ2.nlev^2); psi0[basis_index(TQ2, 0, 1)] = 1.0
            Ω = sqrt(δb^2 + 4J2^2)                 # GHz（子空间本征劈裂）
            times = collect(range(0.0, 3 / Ω; length=301))   # 覆盖 3 个振荡周期
            _, pop, _, _ = evolve_two_qubit(TQ2, psi0, times)
            pred = (4J2^2 / Ω^2) .* sin.(π .* Ω .* times) .^ 2
            num = pop[:, basis_index(TQ2, 1, 0)]
            err = maximum(abs.(num .- pred))
            err < 0.01 && abs(times[argmax(num)] - times[argmax(pred)]) < times[end] / 100
        end)
    check("nlev=3（含 |2⟩）：首峰位置与 nlev=2 解析式一致（高能级只降峰高）",
        let psi0 = zeros(TQ.nlev^2); psi0[basis_index(TQ, 0, 1)] = 1.0
            δb = bare_detuning(TQ)
            Ω = sqrt(δb^2 + 4J^2)
            times = collect(range(0.0, 1.2 / Ω; length=241))    # 覆盖第一个峰
            _, pop, _, _ = evolve_two_qubit(TQ, psi0, times)
            num = pop[:, basis_index(TQ, 1, 0)]
            # 第一个峰：num 首次超过最终峰值的一半
            iFirst = findfirst(num .> 0.5 * maximum(num))
            tPeak = times[argmax(num[1:div(end, 2)])]           # 前半段内的峰
            abs(tPeak - 1 / (2Ω)) < 1 / (20Ω) && maximum(num) < 4J^2 / Ω^2 + 0.03 && iFirst !== nothing
        end)
    check("两能级截断下 ZZ ≡ 0（非谐性是 ZZ 的必要条件）",
        abs(zz_rate(TwoQubit(t, t2, 0.05; nlev=2))) < 1e-12)
    check("三能级截断下 ZZ ≠ 0：$(round(ZZ * 1000, digits=2)) MHz", abs(ZZ) > 1e-5)
    check("ZZ ∝ g_c²（小耦合段）：ZZ(0.05)/ZZ(0.025) ≈ 4",
        let z2 = zz_rate(TwoQubit(t, t2, 0.025; nlev=3))
            abs(ZZ / z2) > 3.5 && abs(ZZ / z2) < 4.5
        end)
    check("全电荷基中 |0,0⟩ = 0、ncut=20 与 ncut=40 谱一致（收敛）",
        let e20 = coupled_spectrum(Transmon(20.0, 0.30; ncut=20), t2, 0.05, 0.0).values
            e40 = coupled_spectrum(t, t2, 0.05, 0.0).values
            maximum(abs.(e20[1:5] .- e40[1:5])) < 1e-6
        end)
    check("布居守恒 + Bloch 提取正确（|01⟩ 初态：q1 在 |0⟩，q2 在 |1⟩）",
        let psi0 = zeros(TQ.nlev^2); psi0[basis_index(TQ, 0, 1)] = 1.0
            _, pop, b1q, b2q = evolve_two_qubit(TQ, psi0, [0.0, 5.0])
            abs(pop[1, basis_index(TQ, 0, 1)] - 1) < 1e-12 && abs(b1q[1, 3] - 1) < 1e-12 &&
                abs(b2q[1, 3] + 1) < 1e-12 && abs(sum(pop[2, :]) - 1) < 1e-9
        end)

    ok[] || exit(1)
    println("\nNEW-ENGINE VALIDATION PASS")
end

main()
