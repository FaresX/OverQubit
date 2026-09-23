"""生成 transmon 黄金向量：用 scqubits 计算参照值，供 Julia 实现回归验证。
用法：python scripts/generate_golden.py（需要 scqubits）
输出：data/golden_transmon.jl（纯 Julia 字面量，Julia 测试直接 include）
"""
import json
import scqubits as scq

POINTS = [
    (20.0, 0.30, 0.0),
    (20.0, 0.30, 0.25),
    (20.0, 0.30, 0.50),
    (50.0, 1.00, 0.0),
    (50.0, 1.00, 0.40),
    (10.0, 0.25, 0.10),
    (15.0, 0.45, -0.30),
    (35.0, 0.35, 0.15),
]
NCUT = 101
NLEV = 4

rows = []
for EJ, EC, ng in POINTS:
    t = scq.Transmon(EJ=EJ, EC=EC, ng=ng, ncut=NCUT)
    evals = [float(x) for x in t.eigenvals(evals_count=NLEV)]
    e01, e12, e23 = evals[1] - evals[0], evals[2] - evals[1], evals[3] - evals[2]
    rows.append((EJ, EC, ng, e01, e12, e23))

with open("data/golden_transmon.jl", "w") as f:
    f.write("# 黄金向量：由 scripts/generate_golden.py 生成\n")
    f.write(f"# 来源 scqubits v{scq.__version__}（Transmon, ncut={NCUT}）；含 E01/E12/E23 跃迁\n")
    f.write("# 用途：Julia 物理层回归验证（迁移/重构后必须仍通过）\n")
    f.write("const GOLDEN = [\n")
    for EJ, EC, ng, e01, e12, e23 in rows:
        f.write(f"    (EJ={EJ}, EC={EC}, ng={ng}, e01={e01!r}, e12={e12!r}, e23={e23!r}),\n")
    f.write("]\n")

print(json.dumps({"points": len(rows), "file": "data/golden_transmon.jl"}))
