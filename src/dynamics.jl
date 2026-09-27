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
# Lindblad 耗散超算符与旋转坐标系序列引擎（T1 / T2 / Ramsey / 自旋回波）
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
