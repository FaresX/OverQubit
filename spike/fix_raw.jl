# ⚠️⚠️ 用前必读：本脚本对**任何** raw" 字面量生效，包括写在文档字符串里的示例文本！
#    文档字符串是普通字符串，里面必须写 `\\frac`（显示成 \frac）；被本脚本改成 `\frac`
#    会让 `\f` 变成非法转义 → 整个文件 parse 失败（踩过）。
#    建议：只对 notebooks/*.jl 用；对 src/ 逐行确认；改完必跑 notebook_selftest.jl。
#
# 修正 raw"..." 里误写的双反斜杠：
#   `\\theta` → `\theta`（双反斜杠 + 命令名，是我误以为 raw 也要转义造成的）
# 但保留 LaTeX 合法的 `\\` 换行/矩阵行分隔（后面跟空格、&、}、\、换行等）。
function fix(path)
    t = read(path, String)
    buf = IOBuffer()
    n = 0
    i = firstindex(t)
    while i <= lastindex(t)
        if startswith(SubString(t, i), "raw\"")
            j = i + 4
            k = j
            while k <= lastindex(t) && t[k] != '"'
                k = nextind(t, k)
            end
            inner = j < k ? t[j:prevind(t, k)] : ""
            fixed = replace(inner, r"\\\\([A-Za-z])" => s"\\\1")
            fixed != inner && (n += 1)
            print(buf, "raw\"", fixed, "\"")
            i = k <= lastindex(t) ? nextind(t, k) : lastindex(t) + 1
        else
            print(buf, t[i])
            i = nextind(t, i)
        end
    end
    write(path, String(take!(buf)))
    n
end

for f in ["notebooks/single_qubit_gate.jl"]
    println(f, " : 修正 ", fix(f), " 处 raw 字符串")
end
# fix_raw.jl：把 raw"..." 里的 `\\命令` 改成 `\命令`（误以为 raw 也要转义留下的）。
# ⚠️⚠️ 危险：它对**任何** raw" 字面量生效，包括写在文档字符串里的示例文本！
#    文档字符串是普通字符串，里面必须写 `\\frac`（显示成 \frac），
#    被这个脚本改成 `\frac` 会让 `\f` 变成非法转义 → 整个文件 parse 失败。
#    用法：只对 notebooks/*.jl 用；对 src/ 要逐行确认。修完必跑 notebook_selftest。
# 规则：只把「双反斜杠 + 命令名」改成单反斜杠；保留 LaTeX 的 `\\` 换行/矩阵行分隔
#    （后面跟空格、&、}、\、换行等）。
