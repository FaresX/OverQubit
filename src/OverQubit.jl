module OverQubit

using LinearAlgebra

export Transmon, charge_states, charge_hamiltonian, spectrum, eigenenergies,
       f01_f12, anharmonicity, potential, wavefunctions, charge_dispersion

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

end # module
