# ============================================================
# CZ 门引擎：磁通脉冲穿越 |11⟩ ↔ |02⟩ avoided crossing
# ============================================================

"""
    CZPair(EJ1, EJ2, EC, g_c; ng=0.0, nlev=3, ncut=40, D=0.0)

CZ 门工作台：**qubit1 频率固定，qubit2 是 SQUID**，E_J2(Φ) = EJ2·(cos(πΦ) + D)。

实现要点（与 `TwoQubit` 的关系，改代码前务必读懂）：

固定参考基 = 两个 transmon 在 Φ=0（idle）的本征态前 nlev 个。任意磁通下只在
**同一组固定基**里改写 Ĥ₂(Φ)——把随磁通变化的电荷基哈密顿量投影回固定基，
而不是「重新对角化再截断」（那样会白送一套基变换产生的非绝热项，数值上很难做对）。
于是

    H(Φ) = Ĥ₁⊗I + I⊗Ĥ₂(Φ) + 2π·g_c·n̂₁⊗n̂₂        [rad/ns]

Φ=0 时 H(0) 与 `TwoQubit(t1, t2, g_c).H` 完全一致（`test/test_cz.jl` 第 1 项回归）。

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

**分段常值**磁通脉冲演化（H 在每步内视为常值，矩阵指数精确；步长收敛见 test/test_cz.jl）。
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
