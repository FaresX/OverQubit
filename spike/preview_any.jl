# 无头预览：把指定 notebook 的所有展示 cell 渲染成单页 HTML（调试布局用）。
# 用法：julia --project=. spike/preview_any.jl（可配 $env:NB = "<notebook名>"）
include(joinpath(@__DIR__, "..", "src", "OverQubit.jl"))
using .OverQubit

const NB = get(ENV, "NB", "flux_tuning")
const OUT = joinpath(@__DIR__, "..", "spike", "preview_$(NB).html")

const CELL_RE = r"^\s*(?:[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}|\d+)\s*\n"
const INCLUDE_RE = r"include\(joinpath\(@__DIR__, \"\.\.\", \"src\", \"[A-Za-z]+\.jl\"\)\)"

# 各 notebook 的 @bind 默认值（与 notebook 里 Slider(default=...) 一致）
const DEFAULTS = """
const EJ = 20.0; const EC = 0.30; const ng = 0.0
const detune = 0.0; const amp = 0.05; const sigma = 10.0; const Tns = 60.0
const E_Cr = 0.06; const om_r = 8.5; const kappa = 0.01; const nshots = 200; const beta = 0.0
const cmp2 = false
const T1us = 30.0; const Tphius = 50.0; const sigmad = 20.0; const deltak = 30.0
const nmem = 16; const taumax = 10.0
const g_c = 0.05; const det2 = 0.03; const T1q = 30.0
const phi_ext = 0.25; const EJ0 = 20.0; const D_slider = 0.1
"""

mod = Module(Symbol("PREV_", NB))
Base.include(mod, joinpath(@__DIR__, "..", "src", "OverQubit.jl"))
Base.eval(mod, Meta.parse("using .OverQubit, PlutoUI, PlotlyBase, Statistics, Random, HypertextLiteral, Markdown"))

path = joinpath(@__DIR__, "..", "notebooks", "$(NB).jl")
text = read(path, String)
chunks = split(text, "\n# ╔═╡")
Base.include_string(mod, replace(chunks[1], r"\A### A Pluto\.jl notebook ###\n# v[\d.]+\n" => ""), "header")
Base.eval(mod, Meta.parse("const EJ = 20.0; const EC = 0.30; const ng = 0.0"))
Base.eval(mod, Meta.parse("const detune = 0.0; const amp = 0.05; const sigma = 10.0; const Tns = 60.0"))
Base.eval(mod, Meta.parse("const E_Cr = 0.06; const om_r = 8.5; const kappa = 0.01; const nshots = 200; const beta = 0.0"))
Base.eval(mod, Meta.parse("const cmp2 = false"))
Base.eval(mod, Meta.parse("const T1us = 30.0; const Tphius = 50.0; const sigmad = 20.0; const deltak = 30.0"))
Base.eval(mod, Meta.parse("const nmem = 16; const taumax = 10.0"))
Base.eval(mod, Meta.parse("const g_c = 0.05; const det2 = 0.03; const T1q = 30.0"))
Base.eval(mod, Meta.parse("const phi_ext = 0.25; const EJ0 = 20.0; const D_slider = 0.1"))
Base.eval(mod, Meta.parse("const ratio2 = 1.20; const amp_phi = 0.073; const t_pulse = 37.5"))
Base.eval(mod, Meta.parse("const shape_sel = \"平滑沿\""))

blocks = String[]
for (i, chunk) in enumerate(chunks[2:end])
    code = replace(chunk, CELL_RE => "")
    (startswith(strip(code), "Cell order:") || startswith(strip(code), "PLUTO_")) && continue
    code = replace(code, INCLUDE_RE => "")
    code = replace(code, "@__DIR__" => repr(dirname(abspath(path))))
    occursin("@bind", code) && continue
    val = try
        Base.include_string(mod, code, "cell$i")
    catch e
        println("cell $i 求值失败：", e)
        continue
    end
    buf = IOBuffer()
    shown = false
    for v in (val isa Tuple ? collect(val) : [val])
        v === nothing && continue
        try
            show(IOContext(buf, :limit => false), MIME"text/html"(), v)
            shown = true
        catch
        end
    end
    shown && push!(blocks, String(take!(buf)))
end

open(OUT, "w") do io
    write(io, """
    <!DOCTYPE html><html><head><meta charset="utf-8"><title>preview $(NB)</title>
    <script src="https://cdn.plot.ly/plotly-2.35.2.min.js"></script>
    <script>
    // 复刻 Pluto 的 MathJax 配置（SetupMathJax.js），否则预览页里公式不会被排版
    window.MathJax = {
        options: { ignoreHtmlClass: "no-MαθJax", processHtmlClass: "tex" },
        tex: { inlineMath: [["\$", "\$"], ["\\\\(", "\\\\)"]] },
        svg: { fontCache: "global" },
        startup: { typeset: false }
    };
    </script>
    <script id="MathJax-script" async src="https://cdn.jsdelivr.net/npm/mathjax@3.2.2/es5/tex-svg-full.js"></script>
    <style>
    body{margin:0;background:#FAFBFF;font-family:-apple-system,'Segoe UI','PingFang SC','Microsoft YaHei',sans-serif;color:#1A1A2E}
    .wrap{max-width:1100px;margin:0 auto;padding:24px 20px 60px}
    .cell{background:#fff;border:1px solid rgba(20,24,60,0.06);border-radius:10px;padding:6px 10px;margin:6px 0}
    mjx-container{overflow-x:auto; overflow-y:hidden}
    </style></head><body><div class="wrap">
    <div style="font-size:11px;letter-spacing:2px;color:#7B61FF;font-weight:600">PREVIEW · $(NB)</div>
    """)
    for (i, b) in enumerate(blocks)
        write(io, "<div class=\"cell\" id=\"c$i\">$b</div>\n")
    end
    write(io, """
    <script>
    // Pluto 是「每次输出后 typeset 该容器里的 .tex」；静态页这里等 MathJax 真正就绪后跑一次。
    // ⚠️ 不能只监听 script 的 load 事件：本页先写了 window.MathJax 配置对象（没有 typesetPromise），
    //    若 script 先于这段执行完，load 事件就永远等不到；用轮询最稳。
    (function(){
      var tries = 0;
      (function go(){
        if (window.MathJax && typeof MathJax.typesetPromise === 'function') {
          // ⚠️ 参数是元素**数组**：Pluto 传的是 NodeList（可迭代），传单个元素会
          //    TypeError: Object is not iterable
          MathJax.typesetPromise([document.body]);
        } else if (++tries < 150) {
          setTimeout(go, 100);
        }
      })();
    })();
    </script>
    </div></body></html>""")
end
println("written: spike/preview_$(NB).html  (blocks=", length(blocks), ")")
