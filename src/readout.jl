# ============================================================
# 谐振器色散读取引擎（S21 / dispersive readout）
# ============================================================

"""
    jc_chi(f01, g, omega_r; N=6)

两能级 JC 模型（谐振器截断 N 光子，RWA）对角化，用重叠匹配提取
f01(n=1) − f01(n=0)（=|0⟩ 与 |1⟩ 两条谐振频率的间隔），返回其一半：

    chi = g²/Δ   （Δ = f01 − omega_r）

即色散位移的标准定义：qubit 在 |0⟩/|1⟩ 时谐振子频率为 ωr ∓ χ。
"""
function jc_chi(f01::Real, g::Real, omega_r::Real; N::Int=6)
    D = 2 * N
    H = zeros(D, D)
    for n in 1:N
        H[n, n] = (n - 1) * omega_r            # |0, n-1⟩
        H[N + n, N + n] = f01 + (n - 1) * omega_r  # |1, n-1⟩
    end
    for n in 1:(N - 1)
        H[N + n, n + 1] = H[n + 1, N + n] = g * sqrt(n)
    end
    F = eigen(Symmetric(H))
    iq1(n) = argmax(abs.(F.vectors[N + n, :]))   # 与 |1, n-1⟩ 最像的本征态
    iq0(n) = argmax(abs.(F.vectors[n, :]))
    separation = (F.values[iq1(2)] - F.values[iq0(2)]) - (F.values[iq1(1)] - F.values[iq0(1)])
    separation / 2
end

"""
    dispersive_params(t, ng, E_Cr, omega_r)

返回 (f01, alpha, g, chi, Delta)：
- g = E_C |⟨0|n̂|1⟩| · φ_zpf,r，φ_zpf,r = (2E_Cr/ω_r)^{1/4}
- chi = JC 对角化数值结果（= g²/Δ，色散位移标准定义）
- S21 曲线位置：qubit |0⟩ → ωr − chi，|1⟩ → ωr + chi
"""
function dispersive_params(t::Transmon, ng::Real, E_Cr::Real, omega_r::Real)
    f01, f12 = f01_f12(t, ng)
    alpha = f12 - f01
    n01 = abs(charge_matrix_element(t, 0, 1, ng))
    phi_zpf_r = (2 * E_Cr / omega_r)^0.25
    g = t.EC * n01 * phi_zpf_r
    Delta = f01 - omega_r
    chi = jc_chi(f01, g, omega_r)
    (f01, alpha, g, chi, Delta)
end

"""
    s21(omega, omega_eff, kappa, kappa_e)

hanger 型单端读出谐振子传输响应 S21(ω) = κe / (i(ω−ωeff) + κ/2)（GHz 单位）。
"""
s21(omega::Real, omega_eff::Real, kappa::Real, kappa_e::Real) =
    kappa_e / (1im * (omega - omega_eff) + kappa / 2)

"""
    steady_amplitude(omega, omega_eff, kappa)

受迫谐振子稳态复振幅 A(ω) = ϵ/(i(ω−ωeff) + κ/2)（驱动强度归一化）。
"""
steady_amplitude(omega::Real, omega_eff::Real, kappa::Real) =
    1.0 / (1im * (omega - omega_eff) + kappa / 2)
