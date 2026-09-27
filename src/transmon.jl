# ============================================================
# 电荷基 transmon：能级、波函数、磁通调谐（SQUID）
# ============================================================

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

"""
    charge_matrix_element(t, k, l, ng=0.0)

电荷算符 n̂ 在 transmon 本征态间的矩阵元 ⟨k|n̂|l⟩（k,l 为 0-based 能级序数）。
"""
function charge_matrix_element(t::Transmon, k::Int, l::Int, ng::Real=0.0)
    _, vecs = spectrum(t, ng)
    n = charge_states(t)
    sum(n[i] * vecs[i, k + 1] * vecs[i, l + 1] for i in eachindex(n))
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
