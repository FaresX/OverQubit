module OverQubit

using LinearAlgebra

export Transmon, charge_states, charge_hamiltonian, spectrum, eigenenergies,
       f01_f12, anharmonicity, potential, wavefunctions, charge_dispersion,
       charge_matrix_element, jc_chi, dispersive_params, s21, steady_amplitude,
       driven_basis, drive_envelope, evolve_density, evolve_density_iq,
       squid_ej, transmon_at_flux,
       coupled_hamiltonian, coupled_spectrum, TwoQubit, basis_index, dressed_index,
       level_energy, energies_ghz, bare_detuning, exchange_rate, conditional_f01,
       conditional_f01_2, zz_rate, evolve_two_qubit,
       dissipator_super, rotating_drive, evolve_segments, SequenceEngine

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
    e, vecs = spectrum(t, ng)                  # 只对角化一次（V 的矩阵元复用同一组本征矢）
    f01, f12 = e[2] - e[1], e[3] - e[2]
    H0 = Diagonal(2π .* [0.0, f01, f01 + f12][1:nlev])
    n = charge_states(t)
    V = [sum(n[i] * vecs[i, k + 1] * vecs[i, l + 1] for i in eachindex(n)) for k in 0:(nlev - 1), l in 0:(nlev - 1)]
    H0, Symmetric(V)
end

"""
    evolve_density_iq(t, ng, omega_d, It, Qt, T_ns; gamma1=0.0, gammaphi=0.0, dt=0.02, nlev=3)

任意 I/Q 双分量驱动：H(t) = H0 + [I(t)·cos(ωd t) − Q(t)·sin(ωd t)]·V。
It、Qt 为 **Function**(t) -> 值（GHz），在每步中点求值；内部 ×2π 折成 rad/ns。
返回 (times, pops[n,nlev], bloch[n,3])。
"""
function evolve_density_iq(t::Transmon, ng::Real, omega_d::Real,
		It::Function, Qt::Function, T_ns::Real;
		gamma1::Real=0.0, gammaphi::Real=0.0, dt::Real=0.02, nlev::Int=3)
	H0, V = driven_basis(t, ng, nlev)
	H0m = Matrix(H0); Vm = Matrix(V); I3 = Matrix{Float64}(I, nlev, nlev)
	ωd = 2π * omega_d
	γ1 = gamma1        # 衰减率：ns⁻¹（=1/T1），不乘 2π
	γφ = gammaphi
	ts = collect(0.0:dt:T_ns)
	dissip = zeros(ComplexF64, nlev^2, nlev^2)
	if gamma1 > 0
		S = zeros(nlev, nlev); S[1, 2] = 1.0
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
	# 载波逐步平均补偿（同 evolve_density）：cos/sin 的步内平均各带 sinc 因子
	x = ωd * dt / 2
	carrier = x / sin(x)
	rho = zeros(ComplexF64, nlev, nlev); rho[1, 1] = 1.0
	nsteps = length(ts)
	pops = zeros(nsteps, nlev); bloch = zeros(nsteps, 3)
	for i in 1:nsteps
		tt = i < nsteps ? ts[i] + dt / 2 : ts[i]
		Om = carrier * 2π * (It(tt) * cos(ωd * tt) - Qt(tt) * sin(ωd * tt))
		H = H0m .+ Om .* Vm
		rho = reshape(exp(lindblad_super(H) * dt) * vec(rho), nlev, nlev)
		pops[i, :] = real(diag(rho))
		bloch[i, 1] = 2 * real(rho[2, 1]); bloch[i, 2] = 2 * imag(rho[2, 1])
		bloch[i, 3] = real(rho[1, 1] - rho[2, 2])
	end
	ts, pops, bloch
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

单位约定：omega_d、amp、sigma、T_ns、dt 口径同 evolve_density（频率 GHz → rad/ns ×2π；
**衰减率 gamma1、gammaphi 例外，直接传 ns⁻¹ 速率**：gamma1 = 1/T1，gammaphi 给出 1/Tφ = 2·gammaphi）。
"""
function evolve_density(t::Transmon, ng::Real, omega_d::Real, amp::Real, sigma::Real, T_ns::Real;
        gamma1::Real=0.0, gammaphi::Real=0.0, dt::Real=0.02, nlev::Int=3)
    H0, V = driven_basis(t, ng, nlev)
    H0m = Matrix(H0); Vm = Matrix(V); I3 = Matrix{Float64}(I, nlev, nlev)
    ωd = 2π * omega_d          # rad/ns
    Ω0 = 2π * amp              # rad/ns
    γ1 = gamma1                # 衰减率：ns⁻¹（=1/T1），不乘 2π
    γφ = gammaphi
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

# ============================================================
# 磁通调谐 transmon（SQUID）：EJ(Φ) = EJ·(cos(πΦ/Φ₀) + D)
# ============================================================

"""
    squid_ej(EJ0, phi; D=0.0)

SQUID 的有效约瑟夫森能 E_J(Φ) = E_J·(cos(πΦ/Φ₀) + D)（Φ₀ 归一化为 1，phi 为归一化磁通）。
D 为不对称因子（0 ≤ D ≤ 1）：D=0 时磁通半量子点处 E_J→0；D>0 保留有限 E_J，可完全避开简并点。
"""
squid_ej(EJ0::Real, phi::Real; D::Real=0.0) = EJ0 * (cos(π * phi) + D)

"""
    transmon_at_flux(EJ0, EC, phi; D=0.0, ncut=60)

按归一化磁通 phi 构造等效 Transmon：把 E_J 换成 E_J(phi)，其余与普通 transmon 完全一致。
用于「磁通调谐」演示：能级、f01(Φ)、电荷色散随磁通的塌缩/爆炸。
"""
transmon_at_flux(EJ0::Real, EC::Real, phi::Real; D::Real=0.0, ncut::Int=60) =
    Transmon(squid_ej(EJ0, phi; D=D), EC; ncut=ncut)

# ============================================================
# 两比特耦合引擎（电容耦合 g_c·n̂₁n̂₂ + 能级截断有效模型）
# ============================================================

"""
    coupled_hamiltonian(t1, t2, g_c, ng=0.0)

两 transmon 电容耦合的**全电荷基**哈密顿量（稠密对称矩阵，用于精确参照）：

    H = H₁⊗I + I⊗H₂ + g_c·n̂₁⊗n̂₂

耦合项 g_c·n̂₁⊗n̂₂ 来自结间电容 C_c 的库仑能（g_c ∝ e²/C_c，GHz）。
指标顺序 (i,j) → i·N₂+j（kron 约定），与 TwoQubit 的乘积基一致。
"""
function coupled_hamiltonian(t1::Transmon, t2::Transmon, g_c::Real, ng::Real=0.0)
    n1 = charge_states(t1)
    n2 = charge_states(t2)
    N1, N2 = length(n1), length(n2)
    H = zeros(N1 * N2, N1 * N2)
    @inbounds for i in 1:N1, j in 1:N2
        k = (i - 1) * N2 + j
        H[k, k] = 4t1.EC * (n1[i] - ng)^2 + 4t2.EC * (n2[j] - ng)^2 + g_c * n1[i] * n2[j]
        i < N1 && (H[k, k + N2] = H[k + N2, k] = -t1.EJ / 2)
        j < N2 && (H[k, k + 1] = H[k + 1, k] = -t2.EJ / 2)
    end
    Symmetric(H)
end

"""全电荷基耦合谱（E, U），返回能量单位 GHz、列向量为本征态。"""
coupled_spectrum(t1::Transmon, t2::Transmon, g_c::Real, ng::Real=0.0) =
    eigen(coupled_hamiltonian(t1, t2, g_c, ng))

"""
    TwoQubit(t1, t2, g_c; ng=0.0, nlev=2)

两比特**截断有效模型**：每个比特取前 nlev 个能级，电荷算符 n̂ 投影到各自本征子空间
（与 driven_basis 同一来源），H 存为内部角频率约定（rad/ns）：

    H = Σ_k Ĥ₀^(k) ⊗ I + g_c·2π·n̂₁⊗n̂₂

交互界面用 `energies_ghz` / `exchange_rate` / `zz_rate` / `evolve_two_qubit`。
"""
struct TwoQubit
    t1::Transmon
    t2::Transmon
    g_c::Float64
    ng::Float64
    nlev::Int
    H::Matrix{Float64}
    E::Vector{Float64}
    U::Matrix{Float64}
end

function TwoQubit(t1::Transmon, t2::Transmon, g_c::Real; ng::Real=0.0, nlev::Int=2)
    H01, V1 = driven_basis(t1, ng, nlev)
    H02, V2 = driven_basis(t2, ng, nlev)
    Im = Matrix{Float64}(I, nlev, nlev)
    H = kron(Matrix(H01), Im) + kron(Im, Matrix(H02)) + 2π * Float64(g_c) * kron(Matrix(V1), Matrix(V2))
    F = eigen(Symmetric(H))
    TwoQubit(t1, t2, Float64(g_c), Float64(ng), nlev, H, F.values, F.vectors)
end

"""乘积基索引：能级序数 k1,k2（0-based）→ 1-based 列索引。"""
basis_index(TQ::TwoQubit, k1::Int, k2::Int) = k1 * TQ.nlev + k2 + 1

"""
    dressed_index(TQ, k1, k2)

与乘积基态 |k1,k2⟩ 最像的那个本征态序号（按重叠平方取最大）——耦合后乘积基不再是本征态，
所有"能级"读数都必须先做这种标记（同 jc_chi 的做法）。精确简并时取任一，能量相同。
"""
dressed_index(TQ::TwoQubit, k1::Int, k2::Int) = argmax(abs2.(view(TQ.U, basis_index(TQ, k1, k2), :)))

"""耦合谱中 |k1,k2⟩ 对应 dressed 态的能量（GHz）。"""
level_energy(TQ::TwoQubit, k1::Int, k2::Int) = TQ.E[dressed_index(TQ, k1, k2)] / 2π

"""耦合谱全部能级（GHz，按升序）。"""
energies_ghz(TQ::TwoQubit) = TQ.E ./ 2π

"""裸失谐 δ = f01(q1) − f01(q2)（GHz）。"""
bare_detuning(TQ::TwoQubit) = f01_f12(TQ.t1, TQ.ng)[1] - f01_f12(TQ.t2, TQ.ng)[1]

"""
    exchange_rate(TQ)

iSWAP 交换率 J（GHz）。|0,1⟩/|1,0⟩ 子空间的 dressed 能级劈裂 Δ 满足 Δ² = δ² + (2J)²
（δ 为裸失谐），故 J = √(Δ²−δ²)/2——共振时 Δ=2J，|01⟩↔|10⟩ 布居以 J 振荡，
π iSWAP 门时间 t = π/(2J)。实现上取与两个乘积态总重叠最大的两个本征态，避免简并歧义。
"""
function exchange_rate(TQ::TwoQubit)
    v = abs2.(view(TQ.U, basis_index(TQ, 0, 1), :)) .+ abs2.(view(TQ.U, basis_index(TQ, 1, 0), :))
    idx = sortperm(v; rev = true)[1:2]
    Δ = abs(TQ.E[idx[1]] - TQ.E[idx[2]]) / 2π
    δ = bare_detuning(TQ)
    sqrt(max(Δ^2 - δ^2, 0.0)) / 2
end

"""qubit1 的 |0⟩→|1⟩ 频率在 qubit2 处于能级 k2 时的值（GHz，dressed 谱读出）。"""
conditional_f01(TQ::TwoQubit, k2::Int) = level_energy(TQ, 1, k2) - level_energy(TQ, 0, k2)

"""qubit2 的 |0⟩→|1⟩ 频率在 qubit1 处于能级 k1 时的值（GHz）。"""
conditional_f01_2(TQ::TwoQubit, k1::Int) = level_energy(TQ, k1, 1) - level_energy(TQ, k1, 0)

"""
    zz_rate(TQ)

always-on ZZ（GHz）：把 qubit2 从 |0⟩ 换到 |1⟩ 时 qubit1 频率的移动量
（对称器件下与 qubit2 侧相同，取两侧平均）。非零即 spectator / 串扰误差的来源。
注意：两能级截断（nlev=2）下 counter-rotating 项与非谐性恰好抵消，ZZ=0；
真实的 ZZ 来自 |1,1⟩ ↔ |2,0⟩/|0,2⟩ 等含非谐性的通道，必须 nlev≥3 才看得见。
"""
function zz_rate(TQ::TwoQubit)
    z1 = conditional_f01(TQ, 1) - conditional_f01(TQ, 0)
    z2 = conditional_f01_2(TQ, 1) - conditional_f01_2(TQ, 0)
    (z1 + z2) / 2
end

"""
    evolve_two_qubit(TQ, psi0, times; gamma1=0.0, gammaphi=0.0)

精确演化（H 含时无关 → 本征分解；gamma>0 时用 Lindblad 分段常值传播子）。
返回 (times, pops[nt, nlev²], bloch1[nt,3], bloch2[nt,3])。
psi0 为乘积基列向量（1-based，索引同 basis_index）。
"""
function evolve_two_qubit(TQ::TwoQubit, psi0::Vector{Float64}, times;
        gamma1::Real=0.0, gammaphi::Real=0.0)
    N = TQ.nlev^2
    n = TQ.nlev
    pops = zeros(length(times), N)
    b1 = zeros(length(times), 3)
    b2 = zeros(length(times), 3)
    if gamma1 == 0 && gammaphi == 0
        c = TQ.U' * psi0
        for (i, tt) in enumerate(times)
            psi = TQ.U * (exp.(-1im .* TQ.E .* tt) .* c)
            store_two_qubit!(pops, b1, b2, i, ComplexF64.(psi * psi'), n)
        end
    else
        rho = ComplexF64.(psi0 * psi0')
        IN = Matrix{Float64}(I, N, N)
        Hc = ComplexF64.(TQ.H)
        diss = dissipator_super(N, gamma1, gammaphi)
        L = -1im .* (kron(IN, Hc) .- kron(transpose(Hc), IN)) .+ diss
        for (i, tt) in enumerate(times)
            rho = reshape(exp(L * tt) * vec(rho), N, N)
            store_two_qubit!(pops, b1, b2, i, rho, n)
        end
    end
    (times, pops, b1, b2)
end

# 从乘积基密度矩阵抽取布居与两个比特各自的 Bloch 分量（偏迹，只用 |0⟩/|1⟩ 两能级）
# 索引约定（basis_index）：|k1,k2⟩ → k1*n + k2 + 1，即 qubit1 是慢索引、qubit2 是快索引。
function store_two_qubit!(pops, b1, b2, i, ρ::Matrix{ComplexF64}, n::Int)
    pops[i, :] .= real.(diag(ρ))
    # qubit1：ρ1[k1a,k1b] = Σ_{k2} ρ[k1a·n+k2+1, k1b·n+k2+1]
    ρ00 = sum(ρ[k + 1, k + 1] for k in 0:(n - 1))
    ρ11 = sum(ρ[n + k + 1, n + k + 1] for k in 0:(n - 1))
    ρ01 = sum(ρ[k + 1, n + k + 1] for k in 0:(n - 1))
    b1[i, 1] = 2 * real(ρ01); b1[i, 2] = 2 * imag(ρ01); b1[i, 3] = real(ρ00 - ρ11)
    # qubit2：ρ2[k2a,k2b] = Σ_{k1} ρ[k1·n+k2a+1, k1·n+k2b+1]
    σ00 = sum(ρ[k * n + 1, k * n + 1] for k in 0:(n - 1))
    σ11 = sum(ρ[k * n + 2, k * n + 2] for k in 0:(n - 1))
    σ01 = sum(ρ[k * n + 1, k * n + 2] for k in 0:(n - 1))
    b2[i, 1] = 2 * real(σ01); b2[i, 2] = 2 * imag(σ01); b2[i, 3] = real(σ00 - σ11)
    nothing
end

# ============================================================
# 旋转坐标系序列引擎（T1 / T2 / Ramsey / 自旋回波）
# ============================================================

"""共享 Lindblad 耗散超算符（列主序 vec 约定）：jumps 为已含 √速率（rad/ns）的崩溃算符列表。"""
function dissipator_super(nlev::Int, jumps::Vector{Matrix{ComplexF64}})
    Im = Matrix{Float64}(I, nlev, nlev)
    D = zeros(ComplexF64, nlev^2, nlev^2)
    for L in jumps
        D .+= kron(conj.(L), L) .- 0.5 .* kron(Im, L' * L) .- 0.5 .* kron((L' * L)', Im)
    end
    D
end

"""
    dissipator_super(nlev, gamma1, gammaphi)

按单位约定构造耗散超算符（**速率直接传 ns⁻¹ 数值，即 GHz 单位的纯速率**）：
- gamma1 = 1/T1：能量弛豫，崩溃算符 √gamma1·|0⟩⟨1|
- gammaphi = 1/Tφ：纯退相，崩溃算符 √(gammaphi/2)·diag(1,−1,1,…)

注意与哈密顿量的区别：哈密顿量是**振荡频率**，需 ×2π 折成 rad/ns 才能进薛定谔方程；
衰减率是**指数衰减速率**，dρ/dt = −rate·ρ 中直接以 ns⁻¹ 使用（再 ×2π 会把 T1 整整缩小 2π 倍）。
|0⟩↔|1⟩ 相干的总衰减率 = gamma1/2 + gammaphi（即 1/T2 = 1/(2T1) + 1/Tφ，见 t1_t2 演示推导第 4 步）。
"""
function dissipator_super(nlev::Int, gamma1::Real, gammaphi::Real)
    jumps = Matrix{ComplexF64}[]
    if gamma1 > 0
        S = zeros(ComplexF64, nlev, nlev); S[1, 2] = 1.0
        push!(jumps, sqrt(gamma1) * S)
    end
    if gammaphi > 0
        Z = diagm(ComplexF64.([1.0, -1.0, ones(max(nlev - 2, 0))...]))
        push!(jumps, sqrt(gammaphi / 2) * Z)
    end
    dissipator_super(nlev, jumps)
end

"""
    rotating_drive(V, amp, phase_deg)

多能级 RWA 的旋转坐标驱动矩阵：`phase` 是旋转轴在 xy 平面内的方位角（0°=σ_x，90°=σ_y）。
载波 I·cos(ωt) − Q·sin(ωt) 分解后只有共转项存活，V 的相邻矩阵元 c_k 各贡献
(c_k/2)·[(I+iQ)|k+1⟩⟨k| + h.c.]，其中 I = amp·cosφ、Q = −amp·sinφ
（推导：e^{iω_p N t} 变换后，静态项恰为 (c/2)[(I+iQ)|k+1⟩⟨k| + (I−iQ)|k⟩⟨k+1|]）。
"""
function rotating_drive(V::AbstractMatrix, amp::Real, phase_deg::Real)
    n = size(V, 1)
    I = amp * cos(deg2rad(phase_deg))
    Q = -amp * sin(deg2rad(phase_deg))
    D = zeros(ComplexF64, n, n)
    @inbounds for k in 1:(n - 1)
        c = V[k, k + 1]
        D[k + 1, k] = (c / 2) * (I + im * Q)
        D[k, k + 1] = (c / 2) * (I - im * Q)
    end
    D
end

"""
    SequenceEngine(t, ng, detune; gamma1=0.0, gammaphi=0.0, nlev=3)

预计算的旋转坐标引擎：H₀（含 detune 的帧内对角）、驱动算符 V、耗散超算符。
配合 `evolve_segments(eng, segs)` 使用时，网格扫描（Ramsey 条纹、自旋回波、ensemble 平均）
不必重复对角化 transmon——这是 t1_t2 演示能实时交互的关键。
"""
struct SequenceEngine
    H0::Diagonal{Float64, Vector{Float64}}
    Vc::Matrix{ComplexF64}
    dissip::Matrix{ComplexF64}
    nlev::Int
end

function SequenceEngine(t::Transmon, ng::Real, detune::Real;
        gamma1::Real=0.0, gammaphi::Real=0.0, nlev::Int=3)
    e = eigenenergies(t, ng)
    f01, f12 = e[2] - e[1], e[3] - e[2]
    H0 = Diagonal(2π .* [0.0, detune, f12 + detune][1:nlev])
    V = Matrix([charge_matrix_element(t, k, l, ng) for k in 0:(nlev - 1), l in 0:(nlev - 1)])
    SequenceEngine(H0, ComplexF64.(V), dissipator_super(nlev, gamma1, gammaphi), nlev)
end

"""
    evolve_segments(t, ng, segs; detune=…, gamma1=…, gammaphi=…, dt=0.02, nlev=3)
    evolve_segments(eng::SequenceEngine, segs; dt=0.02)

**旋转坐标系 + 多能级 RWA + 分段常值** 密度矩阵演化——Ramsey / T1 / 自旋回波引擎。
`detune` 为比特频率相对帧频率的偏移 δ = f01 − ω_p（GHz）；帧内对角 = 2π·[0, δ, f12+δ]，
故 detune=0 时驱动共振。与 evolve_density 口径一致（Rabi 频率 = amp·|⟨0|n̂|1⟩|）。

`segs` 为分段向量，每段是 NamedTuple：
- `(T=<ns>, amp=<GHz>, phase=<deg>)`：常值驱动段（amp=0 即自由演化 / 测量延迟）
- 可选 `dt=<ns>`：该段的**输出采样间隔**（默认取关键字 `dt`）。段内传播子 exp(L·dt) 的
  逐步离散无截断误差（H 恒定），自由演化段可放心用大间隔，成本降 1-2 个量级。

返回 (times_ns, pops[nt,nlev], bloch[nt,3])。
"""
function evolve_segments(eng::SequenceEngine, segs; dt::Real=0.02)
    nlev = eng.nlev
    IN = Matrix{Float64}(I, nlev, nlev)
    H0c = ComplexF64.(Matrix(eng.H0))
    lindblad(H) = -1im .* (kron(IN, H) .- kron(transpose(H), IN)) .+ eng.dissip
    nsteps = [s.T <= 0 ? 1 : max(1, round(Int, s.T / get(s, :dt, dt))) for s in segs]
    nt = sum(nsteps)
    ts = zeros(nt); pops = zeros(nt, nlev); bloch = zeros(nt, 3)
    rho = zeros(ComplexF64, nlev, nlev); rho[1, 1] = 1.0
    t0 = 0.0; i = 0
    for (s, ns) in zip(segs, nsteps)
        H = H0c .+ 2π .* rotating_drive(eng.Vc, get(s, :amp, 0.0), get(s, :phase, 0.0))
        P = exp(lindblad(H) * (s.T / ns))
        for _ in 1:ns
            i += 1; t0 += s.T / ns
            rho = reshape(P * vec(rho), nlev, nlev)
            @inbounds begin
                ts[i] = t0
                pops[i, :] .= real.(diag(rho))
                bloch[i, 1] = 2 * real(rho[2, 1])
                bloch[i, 2] = 2 * imag(rho[2, 1])
                bloch[i, 3] = real(rho[1, 1] - rho[2, 2])
            end
        end
    end
    ts, pops, bloch
end

"""便捷包装：按 (t, ng, detune, gamma…) 现建引擎后演化。网格循环请改用 SequenceEngine 复用。"""
function evolve_segments(t::Transmon, ng::Real, segs;
        detune::Real=0.0, gamma1::Real=0.0, gammaphi::Real=0.0, dt::Real=0.02, nlev::Int=3)
    evolve_segments(SequenceEngine(t, ng, detune; gamma1=gamma1, gammaphi=gammaphi, nlev=nlev), segs; dt=dt)
end

# ============================================================
# CZ 门引擎：磁通脉冲穿越 |11⟩ ↔ |02⟩ avoided crossing
# ============================================================

export CZPair, cz_pair, cz_squid_ej, cz_hamiltonian, cz_levels, cz_level_energy,
       cz_gap, cz_crossing, cz_detuning, cz_pulse_shape, cz_flux, cz_evolve,
       cz_conditional_phase, cz_leakage, cz_ramsey, cz_ramsey_pair, cz_metrics, cz_chevron,
       cz_zcorrect

"""
    CZPair(EJ1, EJ2, EC, g_c; ng=0.0, nlev=3, ncut=40, D=0.0)

CZ 门工作台：**qubit1 频率固定，qubit2 是 SQUID**，E_J2(Φ) = EJ2·(cos(πΦ) + D)。

实现要点（与 `TwoQubit` 的关系，改代码前务必读懂）：

固定参考基 = 两个 transmon 在 Φ=0（idle）的本征态前 nlev 个。任意磁通下只在
**同一组固定基**里改写 Ĥ₂(Φ)——把随磁通变化的电荷基哈密顿量投影回固定基，
而不是「重新对角化再截断」（那样会白送一套基变换产生的非绝热项，数值上很难做对）。
于是

    H(Φ) = Ĥ₁⊗I + I⊗Ĥ₂(Φ) + 2π·g_c·n̂₁⊗n̂₂        [rad/ns]

Φ=0 时 H(0) 与 `TwoQubit(t1, t2, g_c).H` 完全一致（`scripts/validate_cz.jl` 第 1 项回归）。

交互界面：`cz_levels` / `cz_gap` / `cz_crossing`（谱学，找操作点）、
`cz_evolve`（磁通脉冲动力学）、`cz_conditional_phase` / `cz_metrics` / `cz_ramsey` / `cz_chevron`
（校准可观测量与二维网格）。
"""
struct CZPair
    t1::Transmon
    EJ2::Float64
    EC::Float64
    g_c::Float64
    ng::Float64
    nlev::Int
    D::Float64
    ncut::Int
    H1::Matrix{Float64}       # Ĥ₁ 投影到本征子空间（GHz，已把 |0⟩ 归零）
    V1::Matrix{Float64}       # n̂₁ 投影（GHz）
    E2_ref::Float64           # qubit2 参考基（Φ=0）基态能量，Ĥ₂(Φ) 统一减去它以归零
    V2::Matrix{Float64}       # n̂₂ 投影（GHz，与 Φ 无关）
    W2::Matrix{Float64}       # qubit2 电荷基 → 参考本征基（截断 nlev 列）
    Ech2::Vector{Float64}     # qubit2 电荷基对角能 4E_C(n−n_g)²（GHz，与 Φ 无关）
    Hop2::Matrix{Float64}     # qubit2 结构跳变矩阵（−½·(|n⟩⟨n+1|+h.c.)，E_J 已因子化）
    nstate::Int
end

function cz_pair(EJ1::Real, EJ2::Real, EC::Real, g_c::Real;
        ng::Real=0.0, nlev::Int=3, ncut::Int=40, D::Real=0.0)
    t1 = Transmon(EJ1, EC; ncut=ncut)
    t2 = Transmon(EJ2, EC; ncut=ncut)
    H1c = Matrix(charge_hamiltonian(t1, ng))
    H2c = Matrix(charge_hamiltonian(t2, ng))
    n = collect(charge_states(t1))
    Nm = diagm(n .* 1.0)
    W1 = eigen(Symmetric(H1c)).vectors[:, 1:nlev]
    W2 = eigen(Symmetric(H2c)).vectors[:, 1:nlev]
    H1p = W1' * H1c * W1
    H2p = W2' * H2c * W2
    # 能量零点对齐 TwoQubit：|0,0⟩ 取 0。H1 不再显含时间，直接存移好的矩阵；
    # H2(Φ) 每步重建，因此把「参考基的基态能量」存成常数 E2_ref，
    # 由 cz_hamiltonian 统一减去（只动对角，非对角元本来就是 0）。
    H1 = copy(H1p)
    @inbounds for k in 1:nlev
        H1[k, k] -= H1p[1, 1]
    end
    # 结构跳变矩阵（E_J 已因子化）：Ĥ₂(Φ) = diag(4E_C(n−n_g)²) + E_J2(Φ)·Hop
    Nb = length(n)
    Hop = zeros(Nb, Nb)
    @inbounds for i in 1:(Nb - 1)
        Hop[i, i + 1] = Hop[i + 1, i] = -0.5
    end
    CZPair(t1, Float64(EJ2), Float64(EC), Float64(g_c), Float64(ng), nlev, Float64(D), ncut,
        H1, W1' * Nm * W1, H2p[1, 1], W2' * Nm * W2, W2, diag(H2c), Hop, nlev^2)
end

"""乘积基索引（能级序数 k1,k2（0-based）→ 1-based 列索引）；qubit1 是慢索引。"""
_prod_index(nlev::Int, k1::Int, k2::Int) = k1 * nlev + k2 + 1

"CZPair 的乘积基索引（同 `basis_index`）。"
basis_index(p::CZPair, k1::Int, k2::Int) = _prod_index(p.nlev, k1, k2)

"""qubit2 的有效约瑟夫森能 E_J2(Φ) = EJ2·(cos(πΦ) + D)（Φ₀ 归一化为 1）。"""
cz_squid_ej(p::CZPair, phi::Real) = p.EJ2 * (cos(π * phi) + p.D)

"""
    cz_hamiltonian(p, phi)

磁通 Φ 下的两比特哈密顿量（rad/ns，nlev² 维，含 2π 折换）。Φ=0 时等于 `TwoQubit` 的 H。
"""
function cz_hamiltonian(p::CZPair, phi::Real)
    H2c = diagm(p.Ech2) .+ cz_squid_ej(p, phi) .* p.Hop2
    Im = Matrix{Float64}(I, p.nlev, p.nlev)
    H2p = p.W2' * H2c * p.W2 .- p.E2_ref .* Im
    H = kron(p.H1, Im) .+ kron(Im, H2p) .+ p.g_c .* kron(p.V1, p.V2)
    Symmetric(H .* (2π))
end

"""
    cz_levels(p, phi)

Φ 下的 dressed 谱：返回 (energies_ghz, eigvecs)。能级随磁通的移动只能由本征分解得到
（|11⟩ ↔ |02⟩ 会避开交叉），这是 CZ 操作台的纵轴。能量零点同样是 |0,0⟩（同 `level_energy` 口径）。
"""
cz_levels(p::CZPair, phi::Real) = let F = eigen(Matrix(cz_hamiltonian(p, phi)))
    F.values ./ 2π, F.vectors
end

"""与乘积基态 |k1,k2⟩ 最像的那条 dressed 能级的能量（GHz）。"""
function cz_level_energy(p::CZPair, phi::Real, k1::Int, k2::Int)
    E, U = cz_levels(p, phi)
    E[argmax(abs2.(view(U, basis_index(p, k1, k2), :)))]
end

"""
    cz_gap(p, phi; a=(1,1), b=(0,2))

两条 dressed 能级的间距（GHz）。默认 a=|11⟩、b=|02⟩——**CZ 的相互作用通道**：
磁通把 qubit2 的 |1⟩→|2⟩ 频率拖到与 qubit1 的 |0⟩→|1⟩ 共振，gap 即隧穿耦合 V，
它同时决定「相面积累积多快」和「脉冲必须多慢才绝热」。
"""
function cz_gap(p::CZPair, phi::Real; a::Tuple{Int,Int}=(1, 1), b::Tuple{Int,Int}=(0, 2))
    E, U = cz_levels(p, phi)
    ia = argmax(abs2.(view(U, basis_index(p, a[1], a[2]), :)))
    ib = argmax(abs2.(view(U, basis_index(p, b[1], b[2]), :)))
    abs(E[ia] - E[ib])
end

"""
    cz_crossing(p; span=0.5, npoints=201, a=(1,1), b=(0,2))

扫 Φ ∈ [−span, span] 找 |11⟩ ↔ |02⟩ avoided crossing 的最低点，返回 (phi_star, gap_star)。
phi_star 就是 CZ 脉冲要「开到」的目标磁通；gap_star 是该校准点上的隧穿耦合。
"""
function cz_crossing(p::CZPair; span::Real=0.35, npoints::Int=141,
        a::Tuple{Int,Int}=(1, 1), b::Tuple{Int,Int}=(0, 2))
    phis = collect(range(0.0, span; length=npoints))    # H(Φ) 对 Φ 偶对称，只扫正半轴
    gaps = [cz_gap(p, φ; a=a, b=b) for φ in phis]
    i = argmin(gaps)
    (phis[i], gaps[i])
end

"""
    cz_detuning(p, phi)

**裸**失谐 δ = f01(q1) − f01(q2(Φ))（GHz，不含耦合）。
CZ crossing 的物理条件：qubit1 的 |0⟩→|1⟩ 撞上 qubit2 的 |1⟩→|2⟩，即 δ = α₂ = f12−f01 < 0。
用它与 `cz_crossing`（含耦合的解）对照，可看出耦合把 crossing 搬动了多少。
"""
function cz_detuning(p::CZPair, phi::Real)
    t2 = Transmon(cz_squid_ej(p, phi), p.EC; ncut=p.ncut)
    f01_f12(p.t1, p.ng)[1] - f01_f12(t2, p.ng)[1]
end

"""
    cz_pulse_shape(u; kind=:flat, edge=0.2)

门时间内归一化到峰值 1 的磁通脉冲包络 W(u)，u = t/t_pulse ∈ [0,1]：
- `:flat`：方沿（edge 比例内为 0，其余 1）——理想化，边沿跳变
- `:taper`：raised-cosine 平滑沿 0.5(1−cos(πx)) 的升降沿——真实波形更接近它

包络必须**起止于 0**（脉冲结束回到 idle 磁通），否则门做完工作点没回去。
"""
function cz_pulse_shape(u::Real; kind::Symbol=:flat, edge::Real=0.2)
    (u <= 0 || u >= 1) && return 0.0
    r = clamp(u / edge, 0.0, 1.0)
    f = clamp((1 - u) / edge, 0.0, 1.0)
    kind === :flat ? (u >= edge && u <= 1 - edge ? 1.0 : 0.0) : 0.5 * (1 - cos(π * r)) * 0.5 * (1 - cos(π * f))
end

"""
    cz_flux(t; amp, t_pulse, phi_bias=0.0, kind=:taper, edge=0.2, t0=0.0)

磁通轨迹 Φ(t) = phi_bias + amp·W((t−t0)/t_pulse)。amp 是**峰值磁通摆幅**（Φ₀ 归一化）。
"""
cz_flux(t::Real; amp::Real, t_pulse::Real, phi_bias::Real=0.0, kind::Symbol=:taper,
        edge::Real=0.2, t0::Real=0.0) =
    phi_bias + amp * cz_pulse_shape((t - t0) / t_pulse; kind=kind, edge=edge)

"""
    CZResult …（`cz_evolve` 的返回值）

- `times` / `phis`：时间与磁通轨迹（步中点采样）
- `pops11`：|11⟩ 初态在各乘积基上的布居（看 |02⟩ excursion）
- `phases`：四个计算基态相对**无耦合参考演化**的去包裹相位（rad）
- `cphase`：条件相位 φ_00 − φ_01 − φ_10 + φ_11（rad，去包裹）
- `leak11`：|11⟩ 初态漏出计算子空间的布居
- `cond_bloch`：qubit1 在「q2=|1⟩」子空间里的条件 Bloch 矢量——CZ 的**可观测效果**
- `U`：末态总传播子（nlev² 维）
- `Urel`：末态相对传播子 U·U_ref†（U_ref = 关掉 g_c 的同一磁通脉冲）

**为什么要 Urel**：|11⟩ 的对角相位以 f11 ≈ 13 GHz 的速率转圈，直接取 angle 的差分会
每隔几步就跨过 ±π（dt=0.05 ns 时一步就是 4.3 rad）→ 去包裹会完全错乱。
而参考演化把「单比特自相位」整体减掉，剩下的差分量级只有 MHz～百 MHz，
每步变化 << π，既稳又正是实验上「spectator Ramsey 参考序列」测到的东西。
"""
struct CZResult
    times::Vector{Float64}
    phis::Vector{Float64}
    pops11::Matrix{Float64}
    phases::Matrix{Float64}
    cphase::Vector{Float64}
    leak11::Vector{Float64}
    cond_bloch::Matrix{Float64}
    U::Matrix{ComplexF64}
    Urel::Matrix{ComplexF64}
    nlev::Int
end

"""
    cz_evolve(p, amp, t_pulse; T_ns=0.0, phi_bias=0.0, kind=:taper, edge=0.2, dt=0.05)

**分段常值**磁通脉冲演化（H 在每步内视为常值，矩阵指数精确；步长收敛见 validate_cz.jl）。
`T_ns` 为总时长（0 表示 1.5×t_pulse，前后留出 idle 段看相位累积）。
四个计算基初态同时传播（U 的 4 列即它们的末态），因此一次演化就能读出
条件相位、泄漏、条件 Bloch 矢量与 Ramsey 信号；同时段内并行传播「关掉 g_c」的
参考演化，用于给出无混叠的相对相位（见 `CZResult.Urel`）。
"""
function cz_evolve(p::CZPair, amp::Real, t_pulse::Real;
        T_ns::Real=0.0, phi_bias::Real=0.0, kind::Symbol=:taper, edge::Real=0.2, dt::Real=0.05)
    T_tot = T_ns > 0 ? Float64(T_ns) : 1.5 * Float64(t_pulse)
    t0 = (T_tot - t_pulse) / 2
    times = collect(0.0:dt:T_tot)
    nt = length(times); ns = p.nstate
    U = Matrix{ComplexF64}(I, ns, ns)
    Uref = Matrix{ComplexF64}(I, ns, ns)
    pops11 = zeros(nt, ns); phases = zeros(nt, 4)
    cphase = zeros(nt); leak11 = zeros(nt); cond_bloch = zeros(nt, 3); phis = zeros(nt)
    comp = [_prod_index(p.nlev, k1, k2) for k1 in 0:1, k2 in 0:1]
    (i00, i01, i10, i11) = (comp[1,1], comp[1,2], comp[2,1], comp[2,2])
    prev = zeros(4)
    Coupl = (2π * p.g_c) .* kron(p.V1, p.V2)      # 与 Φ 无关，提出来
    @inbounds for i in 1:nt
        tt = i < nt ? times[i] + dt / 2 : times[i]
        phi = cz_flux(tt; amp=amp, t_pulse=t_pulse, phi_bias=phi_bias, kind=kind, edge=edge, t0=t0)
        phis[i] = phi
        if i > 1
            H = ComplexF64.(Matrix(cz_hamiltonian(p, phi)))
            # 参考演化：同一磁通轨迹、关掉 g_c（= 实验里 qubit2 置 |0⟩ 的参考序列）
            Href = H .- Coupl
            step = exp((-1im) .* H .* dt)
            U = step * U
            Uref = exp((-1im) .* Href .* dt) * Uref
        end
        pops11[i, :] .= abs2.(view(U, :, i11))
        leak11[i] = 1 - sum(abs2(U[c, i11]) for c in comp)
        Urel = U * Uref'
        # 相对相位 = 相对传播子 Urel 的对角元（⟨c|U U_ref†|c⟩，实际态与参考态的重叠）：
        # 注意不能写成 U[c,c]·conj(Uref[c,c])——脉冲期间 U_ref 在乘积基里并不对角，
        # 那样会漏掉 Σ_j U[c,j]U_ref[c,j]* 的交叉项，相位会算错。
        now = [angle(Urel[c, c]) for c in comp]
        for k in 1:4                       # 去包裹：让相位可连续越过 ±π
            d = now[k] - prev[k]
            prev[k] += d - 2π * round(d / 2π)
        end
        phases[i, :] .= prev
        cphase[i] = prev[1] - prev[2] - prev[3] + prev[4]
        v0 = (Urel[i01, i01] + Urel[i01, i11]) / sqrt(2.0)   # q2=|1⟩ 子空间的条件态
        v1 = (Urel[i11, i01] + Urel[i11, i11]) / sqrt(2.0)
        # 条件 Bloch 矢量：转过的角度就是条件相位本身（四态相减已把单比特自相位/动态相位
        # 连同 spectator 修正一起减掉），横向长度随泄漏收缩——「门不干净」直接看得见
        rr = 2 * sqrt(abs2(v0) * abs2(v1))
        cond_bloch[i, 1] = rr * cos(cphase[i])
        cond_bloch[i, 2] = rr * sin(cphase[i])
        cond_bloch[i, 3] = abs2(v0) - abs2(v1)
    end
    CZResult(times, phis, pops11, phases, cphase, leak11, cond_bloch, U, U * Uref', p.nlev)
end

"""把角度归一化到 (−π, π]。"""
_wrappi(x::Real) = x - 2π * round(x / (2π))

"""
    cz_conditional_phase(U, nlev)

从总传播子读 CZ 条件相位（rad，wrap 到 (−π, π]）：
    φ_CZ = φ_00 − φ_01 − φ_10 + φ_11，  φ_jk = arg⟨jk|U|jk⟩
这正是实验上「spectator Ramsey 参考序列」测到的量：qubit2 取 |1⟩ 与 |0⟩ 两次相减，
单比特自相位（动态相位）被整体减掉。**理想 CZ = π。**

⚠️ 传进来的 U 应当是**相对传播子**（如 `cz_evolve` 返回的 `Urel`，或已做过参考相减的 U）。
直接传绝对传播子会因 13 GHz 级动态相位的混叠而得到垃圾值（见 `CZResult.Urel` 的说明）。
"""
cz_conditional_phase(U::AbstractMatrix, nlev::Int) = _wrappi(let
    c = [_prod_index(nlev, k1, k2) for k1 in 0:1, k2 in 0:1]
    angle(U[c[1,1], c[1,1]]) - angle(U[c[1,2], c[1,2]]) -
        angle(U[c[2,1], c[2,1]]) + angle(U[c[2,2], c[2,2]])
end)

"""四个计算基初态各自漏出计算子空间的最大布居。"""
function cz_leakage(U::AbstractMatrix, nlev::Int)
    c = [_prod_index(nlev, k1, k2) for k1 in 0:1, k2 in 0:1]
    maximum(1 - sum(abs2(U[i, j]) for i in vec(c)) for j in vec(c))
end

"""
    cz_ramsey(U, nlev; theta_deg=90.0)

教科书级 CZ 相位校准序列读数：|+⟩₁|1⟩₂ → CZ → X(θ)₁ → 读 qubit1 的 P(|1⟩)。
θ=90° 时 P1 = sin²(δφ/2)（δφ 为条件相位相对 π 的偏差）——**所以这条序列直接把相位误差
翻译成布居误差**。`in_sub` 是留在 q2=|1⟩ 子空间的布居；漏出去的部分在真实实验里读成别的态，
这里故意不归一化，泄漏会把 P1 往 0.5 拉（实验上的「对比度下降」）。
"""
function cz_ramsey(U::AbstractMatrix, nlev::Int; theta_deg::Real=90.0)
    i01 = _prod_index(nlev, 0, 1); i11 = _prod_index(nlev, 1, 1)
    v0 = (U[i01, i01] + U[i01, i11]) / sqrt(2.0)
    v1 = (U[i11, i01] + U[i11, i11]) / sqrt(2.0)
    θ = deg2rad(theta_deg)
    (abs((sin(θ) - im * cos(θ)) * v0 + v1)^2 / 2, abs2(v0) + abs2(v1))
end

"""
    cz_ramsey_pair(U, nlev; theta_deg=90.0)

把校准序列跑两遍：qubit2 分别置 |1⟩（信号）与 |0⟩（参考）。
返回 (P1_q2_1, P1_q2_0, phase_cond)。phase_cond = 两序列 qubit1 相位之差
= φ_00 − φ_01 − φ_10 + φ_11（mod 2π）——**参考序列存在的理由就是把动态相位减掉**。
"""
function cz_ramsey_pair(U::AbstractMatrix, nlev::Int; theta_deg::Real=90.0)
    function one(i0, i1)                     # q2 固定在某个态，qubit1 走 |+⟩
        v0 = (U[i0, i0] + U[i0, i1]) / sqrt(2.0)
        v1 = (U[i1, i0] + U[i1, i1]) / sqrt(2.0)
        θ = deg2rad(theta_deg)
        (abs((sin(θ) - im * cos(θ)) * v0 + v1)^2 / 2, angle(v1) - angle(v0))
    end
    p1, d1 = one(_prod_index(nlev, 0, 1), _prod_index(nlev, 1, 1))   # q2 = |1⟩（信号）
    p0, d0 = one(_prod_index(nlev, 0, 0), _prod_index(nlev, 1, 0))   # q2 = |0⟩（参考）
    (p1, p0, _wrappi(d1 - d0))
end

"""
    cz_zcorrect(r::CZResult)

实验口径的「虚拟 Z 校正」：在相对传播子 `Urel` 上再减掉两个比特各自的单比特相位，
返回 9×9 校正后传播子。为什么要它：实验室里 qubit 的相位由 AWG 的 frame 定义，
13 GHz 级动态相位本来就会被 frame 更新/虚拟 Z 吸收；不校正的话 Ramsey 读数会抖成一片
随机数（P1 与条件相位毫无关系）。校正后 `cz_ramsey` 与 `cz_metrics` 的口径一致：
P1 = sin²(δφ/2)，δφ = 0 处就是暗瓣。
"""
function cz_zcorrect(r::CZResult)
    c = vec([_prod_index(r.nlev, k1, k2) for k1 in 0:1, k2 in 0:1])
    U = copy(r.Urel)
    U[c, c] = r.Urel[c, c] * _cz_diag_correction(r.Urel[c, c], 4)
    U
end

"""校准序列的实验口径读数（对 `cz_evolve` 结果）：先用 `cz_zcorrect` 减掉单比特相位，
再跑信号 / 参考两条序列。返回 (P1_signal, P1_reference, phase_cond)。
`P1_signal` = sin²(δφ/2)（δφ 为条件相位相对 π 的偏差）→ 0 即 CZ；参考序列恒为 ≈0.5。"""
cz_ramsey_pair(r::CZResult; theta_deg::Real=90.0) = cz_ramsey_pair(cz_zcorrect(r), r.nlev; theta_deg=theta_deg)

"""
    cz_metrics(U, nlev)

门质量读数：返回 (phase_rad, phase_err_rad, leakage, f_proc, f_state)。
- phase_rad：条件相位（mod 2π，归一化到 (−π, π]）
- phase_err_rad：|phase − π|，相位欠/过旋转量
- leakage：四个计算基初态漏出计算子空间的最大布居（|0,2⟩ 等非计算态）
- f_proc：与理想 CZ 的过程保真度 |tr(U_CZ† U_c·D)|²/16（**已做局域 Z 校正**）
- f_state：四个计算基初态的平均态保真度

**为什么要 D 校正**：理想 CZ 前后允许每个比特各差一个单比特相位（实验上由虚拟 Z 门或
编译器的 frame 修正吸收）。不校正时，13 GHz 级动态相位残差会把 |tr| 打成一片，
F_proc 看起来差得离谱；校正后剩下的就是真正属于「两比特门」的误差。
传进来的 U 应当是**相对传播子**（`cz_evolve` 返回的 `Urel`，或已做过参考相减的 U）；
直接对 `CZResult` 调用 `cz_metrics(r)` 会自动分派正确口径。
"""
function _cz_diag_correction(Uc::AbstractMatrix, d::Int)
    # a = θ00 − θ10（qubit1 单比特相位），b = θ00 − θ01（qubit2）；D = diag(1, e^{ib}, e^{ia}, e^{i(a+b)})
    a = angle(Uc[1, 1] * conj(Uc[3, 3]))
    b = angle(Uc[1, 1] * conj(Uc[2, 2]))
    Diagonal(ComplexF64[1.0, exp(im * b), exp(im * a), exp(im * (a + b))])
end

function _cz_scores(Uc::AbstractMatrix, d::Int)
    Ui = Matrix{ComplexF64}(I, d, d); Ui[d, d] = -1.0
    Ucorr = Uc * _cz_diag_correction(Uc, d)
    (real(abs(tr(Ui' * Ucorr))^2 / d^2),
     real(sum(abs(dot(Ui[:, j], Ucorr[:, j]))^2 for j in 1:d) / d))
end

function cz_metrics(U::AbstractMatrix, nlev::Int)
    d = 4
    c = vec([_prod_index(nlev, k1, k2) for k1 in 0:1, k2 in 0:1])
    Uc = U[c, c]
    f_proc, f_state = _cz_scores(Uc, d)
    ph = _wrappi(cz_conditional_phase(U, nlev))
    (ph, abs(_wrappi(ph - π)), cz_leakage(U, nlev), f_proc, f_state)
end

"""门质量读数（对 `cz_evolve` 结果）：相位/保真度取 `Urel`（已减掉单比特动态相位，
即实验室里做虚拟 Z 校正后的口径），泄漏取 `U`（真实布居）。"""
function cz_metrics(r::CZResult)
    d = 4
    c = vec([_prod_index(r.nlev, k1, k2) for k1 in 0:1, k2 in 0:1])
    f_proc, f_state = _cz_scores(r.Urel[c, c], d)
    ph = _wrappi(cz_conditional_phase(r.Urel, r.nlev))
    (ph, abs(_wrappi(ph - π)), cz_leakage(r.U, r.nlev), f_proc, f_state)
end

"""
    cz_chevron(p, amps, lengths; kind=:taper, edge=0.2, phi_bias=0.0, dt=0.05, theta_deg=90.0)

二维校准网格（amplitude × length），逐点真实跑磁通脉冲。
返回 (P1[na, nl], cphase[na, nl], leak[na, nl])——P1 的亮瓣就是实验 chevron 图的模样，
第一瓣中心即 CZ 工作点。**这是校准 notebook 的主图**，成本 ≈ na·nl 次演化。
"""
function cz_chevron(p::CZPair, amps, lengths; kind::Symbol=:taper, edge::Real=0.2,
        phi_bias::Real=0.0, dt::Real=0.05, theta_deg::Real=90.0)
    P1 = zeros(length(amps), length(lengths))
    cph = zeros(length(amps), length(lengths))
    lk = zeros(length(amps), length(lengths))
    for (i, a) in enumerate(amps), (j, L) in enumerate(lengths)
        r = cz_evolve(p, a, L; phi_bias=phi_bias, kind=kind, edge=edge, dt=dt)
        P1[i, j] = cz_ramsey(cz_zcorrect(r), p.nlev; theta_deg=theta_deg)[1]   # 实验口径（虚拟 Z 已校正）
        cph[i, j] = cz_conditional_phase(r.Urel, p.nlev)               # 相位走相对传播子
        lk[i, j] = cz_leakage(r.U, p.nlev)                             # 泄漏是真实布居
    end
    (P1, cph, lk)
end

end # module
