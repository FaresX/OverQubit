# 新引擎物理验收：Rabi（=amp·n01）、弱驱动两能级性、泄漏随幅度增长、JC 色散、S21。
include(joinpath(@__DIR__, "..", "src", "OverQubit.jl"))
using .OverQubit

function crossing(ts, y)
    out = Float64[]
    for i in 2:size(y, 1)
        if y[i - 1] < 0.5 <= y[i]
            f = (0.5 - y[i - 1]) / (y[i] - y[i - 1])
            push!(out, ts[i - 1] + f * (ts[i] - ts[i - 1]))
            length(out) >= 6 && break
        end
    end
    out
end

function main()
    ok = Ref(true)
    check(name, cond) = (println(cond ? "PASS  " : "FAIL  ", name); ok[] &= cond)

    t = Transmon(20.0, 0.30; ncut=60)
    n01 = abs(charge_matrix_element(t, 0, 1))
    f01, f12 = f01_f12(t, 0.0)

    amp = 0.05
    ts, pops, bloch = evolve_density(t, 0.0, f01, amp, 300.0, 100.0)
    cr = crossing(ts, pops[:, 2])
    ΩR_num = length(cr) >= 2 ? 1 / ((cr[end] - cr[1]) / (length(cr) - 1)) : NaN
    ΩR_theory = amp * n01
    check("Rabi 频率 数值 $(round(ΩR_num, digits=4)) vs amp·n01=$(round(ΩR_theory, digits=4)) GHz",
        abs(ΩR_num - ΩR_theory) / ΩR_theory < 0.02)
    check("共振驱动布居反转 p1_max > 0.95", maximum(pops[:, 2]) > 0.95)
    check("Bloch 矢量保持在单位球上", maximum(abs.(sqrt.(sum(bloch .^ 2; dims=2)) .- 1)) < 0.02)

    _, pops_strong, _ = evolve_density(t, 0.0, f01, 0.10, 300.0, 100.0)
    check("弱驱动 |2⟩ 泄漏 < 2%（两能级近似，max=$(round(maximum(pops[:, 3]); digits=4))）",
        maximum(pops[:, 3]) < 0.02)
    check("强驱动泄漏显著增长（DRAG 动机）：$(round(maximum(pops[:, 3]), digits=3)) → $(round(maximum(pops_strong[:, 3]), digits=3))",
        maximum(pops_strong[:, 3]) > 3 * maximum(pops[:, 3]))

    E_Cr, ωr = 0.06, 8.5
    f01c, alpha, g, chi, Delta = dispersive_params(t, 0.0, E_Cr, ωr)
    check("χ ≈ g²/Δ: $(round(chi, digits=5)) vs $(round(g^2/Delta, digits=5)) GHz",
        abs(chi - g^2 / Delta) / abs(g^2 / Delta) < 0.02)
    check("χ 量级 $(round(chi*1000, digits=2)) MHz，|0⟩/|1⟩ 曲线关于 ωr 对称（ωr∓χ）",
        sign(chi) == -1 && abs(chi) > 1e-4 && abs(chi) < 0.2)

    κ, κe, ω0 = 0.01, 0.008, 7.0
    check("S21 峰值 = κe/(κ/2)", abs(abs(s21(ω0, ω0, κ, κe)) - κe / (κ / 2)) < 1e-9)
    check("S21 半功率点在 ω0 ± κ/2",
        abs(abs(s21(ω0 + κ / 2, ω0, κ, κe)) - κe / (κ / 2) / sqrt(2)) < 1e-6)

    ok[] || exit(1)
    println("DYNAMICS/RESONATOR VALIDATION PASS")
end

main()
