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
