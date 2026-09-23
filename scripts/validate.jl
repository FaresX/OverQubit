# Julia 物理层回归验证：对照 scqubits 黄金向量。
# 用法：julia --project=. scripts/validate.jl
# 通过条件：所有点的 e01/e12/e23 相对误差 < 1e-6。
include(joinpath(@__DIR__, "..", "src", "OverQubit.jl"))
using .OverQubit

include(joinpath(@__DIR__, "..", "data", "golden_transmon.jl"))

function main(; rtol = 1e-6, ncut = 50)
    worst = 0.0
    worst_at = ""
    for (i, g) in enumerate(GOLDEN)
        t = Transmon(g.EJ, g.EC; ncut = ncut)
        e = eigenenergies(t, g.ng)
        mine = (e[2] - e[1], e[3] - e[2], e[4] - e[3])
        refs = (g.e01, g.e12, g.e23)
        for (name, m, r) in zip(("e01", "e12", "e23"), mine, refs)
            err = abs(m - r) / abs(r)
            if err > worst
                worst = err
                worst_at = "point $i ($name): EJ=$(g.EJ) EC=$(g.EC) ng=$(g.ng)"
            end
        end
    end
    println("验证点数: ", length(GOLDEN), "  Julia ncut=", ncut)
    println("最大相对误差: ", worst, "  (", worst_at, ")")
    worst < rtol && (println("PASS"); return true)
    println("FAIL")
    return false
end

main() || exit(1)
