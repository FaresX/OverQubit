module OverQubit

using LinearAlgebra

export Transmon, charge_states, charge_hamiltonian, spectrum, eigenenergies,
       f01_f12, anharmonicity, potential, wavefunctions, charge_dispersion,
       charge_matrix_element, jc_chi, dispersive_params, s21, steady_amplitude,
       driven_basis, drive_envelope, evolve_density

"""
    Transmon(EJ, EC; ncut=40)

电荷基 transmon。EJ、EC 单位为 GHz（ħ=1 约定，能级以频率 GHz 计）。
ncut 为电荷态截断 |n| ≤ ncut。
"""
struct Transmon
    EJ::Float64
    EC::Float64
    ncut::Int
end

Transmon(EJ::Real, EC::Real; ncut::Int=40) = Transmon(Float64(EJ), Float64(EC), ncut)

Base.broadcastable(t::Transmon) = Ref(t)   # 广播时视为标量（如 potential.(t, phis)）

charge_states(t::Transmon) = -t.ncut:t.ncut

"""
    charge_hamiltonian(t, ng=0.0)

H = 4E_C (n̂ - n_g)² - E_J/2 (|n⟩⟨n+1| + |n⟩⟨n-1|)
"""
function charge_hamiltonian(t::Transmon, ng::Real=0.0)
    n = charge_states(t)
    N = length(n)
    H = zeros(N, N)
    @inbounds for i in 1:N
        H[i, i] = 4t.EC * (n[i] - ng)^2
        i < N && (H[i, i+1] = H[i+1, i] = -t.EJ / 2)
    end
    Symmetric(H)
end

"""
    spectrum(t, ng=0.0)

返回 (energies, eigvecs)。energies 按升序；eigvecs 为电荷基列向量。
"""
function spectrum(t::Transmon, ng::Real=0.0)
    F = eigen(charge_hamiltonian(t, ng))
    F.values, F.vectors
end

eigenenergies(t::Transmon, ng::Real=0.0) = spectrum(t, ng)[1]

"""
    f01_f12(t, ng=0.0)

返回 (f01, f12)，单位 GHz。
"""
function f01_f12(t::Transmon, ng::Real=0.0)
    e = eigenenergies(t, ng)
    (e[2] - e[1], e[3] - e[2])
end

"""
    anharmonicity(t, ng=0.0)

α = f12 - f01，单位 GHz（transmon 为负）。
"""
anharmonicity(t::Transmon, ng::Real=0.0) = let (a, b) = f01_f12(t, ng); b - a end

"""
    potential(t, phi)

约瑟夫森势阱 V(φ) = -E_J cos(φ)，GHz。量子化零点相位 φ_zpf 可由能级/矩阵元另行计算。
"""
potential(t::Transmon, phi::Real) = -t.EJ * cos(phi)

"""
    wavefunctions(t, ng=0.0, nlevels=3, nphi=200)

在相位基 |n⟩ = e^{inφ}/√(2π) 下展开返回 (phis, |ψ_k(φ)|² 矩阵 nlevels×nphi)。
"""
function wavefunctions(t::Transmon, ng::Real=0.0, nlevels::Int=3, nphi::Int=200)
    _, vecs = spectrum(t, ng)
    phis = range(-π, π; length=nphi)
    n = charge_states(t)
    psi2 = zeros(nlevels, nphi)
    @inbounds for (j, φ) in enumerate(phis)
        for k in 1:nlevels
            re = 0.0
            im = 0.0
            for (i, nn) in enumerate(n)
                re += vecs[i, k] * cos(nn * φ)
                im += vecs[i, k] * sin(nn * φ)
            end
            psi2[k, j] = (re^2 + im^2) / 2π
        end
    end
    phis, psi2
end

"""
    charge_dispersion(t, npoints=41)

E_n(n_g) 在 n_g ∈ [-1, 1] 的扫描，返回 (ngs, energies[npoints, nlevels])。
用于展示电荷色散（transmon 中极小，fluxonium 中显著）。
"""
function charge_dispersion(t::Transmon, npoints::Int=41, nlevels::Int=3)
    ngs = range(-1, 1; length=npoints)
    E = zeros(npoints, nlevels)
    for (i, ng) in enumerate(ngs)
        e = eigenenergies(t, ng)
        E[i, :] = e[1:nlevels]
    end
    collect(ngs), E
end

# ============================================================
# 谐振器色散读取引擎（S21 / dispersive readout）
# ============================================================

"""
    charge_matrix_element(t, k, l, ng=0.0)

电荷算符 n̂ 在 transmon 本征态间的矩阵元 ⟨k|n̂|l⟩（k,l 为 0-based 能级序数）。
"""
function charge_matrix_element(t::Transmon, k::Int, l::Int, ng::Real=0.0)
    _, vecs = spectrum(t, ng)
    n = charge_states(t)
    sum(n[i] * vecs[i, k + 1] * vecs[i, l + 1] for i in eachindex(n))
end

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

# ============================================================
# 驱动动力学引擎（单比特门 / DRAG）：截断 transmon + Lindblad
# ============================================================

"""
    driven_basis(t, ng=0.0, nlev=3)

返回 (H0, V)：H0 为 nlev 能级有效哈密顿量（内部角频率约定 rad/ns，即 GHz×2π；
对角：0, 2πf01, 2π(f01+f12)），V 为电压驱动算符 n̂ 在本征子空间的投影
（驱动 H_d = Ω(t)·cos(ω_d t)·V，Ω、ω_d 亦为 rad/ns）。
"""
function driven_basis(t::Transmon, ng::Real=0.0, nlev::Int=3)
    e = eigenenergies(t, ng)
    f01, f12 = e[2] - e[1], e[3] - e[2]
    H0 = Diagonal(2π .* [0.0, f01, f01 + f12][1:nlev])
    V = [charge_matrix_element(t, k, l, ng) for k in 0:(nlev - 1), l in 0:(nlev - 1)]
    H0, Symmetric(V)
end

"""
    drive_envelope(t_ns, amp, sigma; center_ratio=0.35)

高斯驱动包络 Ω(t) = amp·exp(−((t−t0)/sigma)²)，t0 取总时长 35% 处。
amp 为角幅度（rad/ns；用户传 GHz 时由 evolve_density 内部 ×2π）。
"""
function drive_envelope(t_ns, amp::Real, sigma::Real; center_ratio::Real=0.35)
    t0 = center_ratio * (t_ns[end] - t_ns[1])
    amp .* exp.(-((t_ns .- t0) ./ sigma) .^ 2)
end

"""
    evolve_density(t, ng, omega_d, amp, sigma, T_ns; gamma1=0.0, gammaphi=0.0, dt=0.02, nlev=3)

截断 transmon（nlev 能级）+ 高斯电压驱动 + Lindblad（T1、纯退相）密度矩阵演化，
分段常值 Lindbladian 矩阵指数法。返回 (times_ns, pops[n,nlev], bloch[n,3])。

单位约定：omega_d、amp、gamma1、gammaphi 传 **GHz**（速率按 GHz·2π 折成 rad/ns）；
sigma、T_ns、dt、times 为 ns。
"""
function evolve_density(t::Transmon, ng::Real, omega_d::Real, amp::Real, sigma::Real, T_ns::Real;
        gamma1::Real=0.0, gammaphi::Real=0.0, dt::Real=0.02, nlev::Int=3)
    H0, V = driven_basis(t, ng, nlev)
    H0m = Matrix(H0); Vm = Matrix(V); I3 = Matrix{Float64}(I, nlev, nlev)
    ωd = 2π * omega_d          # rad/ns
    Ω0 = 2π * amp              # rad/ns
    γ1 = 2π * gamma1
    γφ = 2π * gammaphi
    ts = collect(0.0:dt:T_ns)
    env = drive_envelope(ts, Ω0, sigma)
    # 载波逐步平均补偿：cos 在一步内的平均 = sinc(ωd·dt/2)·cos(中点)，
    # 不补偿会系统性低估耦合 ~ sinc 因子（dt=0.02 时约 2.7%），故乘以其倒数
    x = ωd * dt / 2
    carrier = x / sin(x)
    dissip = zeros(ComplexF64, nlev^2, nlev^2)
    if gamma1 > 0
        S = zeros(nlev, nlev); S[1, 2] = 1.0            # |0⟩⟨1|
        L = sqrt(γ1) * S
        dissip .+= kron(conj.(L), L) .- 0.5 .* kron(I3, L' * L) .- 0.5 .* kron((L' * L)', I3)
    end
    if gammaphi > 0
        Z = diagm([1.0, -1.0, ones(nlev - 2)...])
        L = sqrt(γφ / 2) * Z
        dissip .+= kron(conj.(L), L) .- 0.5 .* kron(I3, L' * L) .- 0.5 .* kron((L' * L)', I3)
    end
    function lindblad_super(H)
        -1im .* (kron(I3, H) .- kron(transpose(H), I3)) .+ dissip
    end
    rho = zeros(ComplexF64, nlev, nlev); rho[1, 1] = 1.0
    nsteps = length(ts)
    pops = zeros(nsteps, nlev); bloch = zeros(nsteps, 3)
    for i in 1:nsteps
        tt = i < nsteps ? ts[i] + dt / 2 : ts[i]        # 步中点
        Om = env[i] * carrier * cos(ωd * tt)
        H = H0m .+ Om .* Vm
        rho = reshape(exp(lindblad_super(H) * dt) * vec(rho), nlev, nlev)
        pops[i, :] = real(diag(rho))
        bloch[i, 1] = 2 * real(rho[2, 1])
        bloch[i, 2] = 2 * imag(rho[2, 1])
        bloch[i, 3] = real(rho[1, 1] - rho[2, 2])
    end
    ts, pops, bloch
end

end # module
