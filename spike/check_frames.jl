# 校验动画帧的 traces=[i] 指向的确实是「专用小 trace」，而不是背景曲线。
# 依据：Plotly.js 的 frameMerge + plots.transition：
#   gd.data[frame.traces[i]] = extendTrace(gd.data[frame.traces[i]], frame.data[i])
# 索引错了就会把背景曲线（势阱抛物线 / 经纬线框）顶替成单个 marker —— 播放时曲线消失。
# 结构沿用 spike/preview_any.jl（已验证的逐 cell 求值骨架）。

const CELL_RE0 = r"^\s*(?:[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}|\d+)\s*\n"
const INCLUDE_RE0 = r"include\(joinpath\(@__DIR__, \"\.\.\", \"src\", \"[A-Za-z]+\.jl\"\)\)"

function gf(m, s)
    Base.invokelatest(() -> try getfield(m, s) catch; nothing end)
end

function trace_points(tr)
    Base.invokelatest() do
        try
            x = tr.fields[:x]
            x === nothing ? 0 : length(collect(x))
        catch
            0
        end
    end
end

function trace_name(tr)
    Base.invokelatest() do
        try
            n = tr.fields[:name]
            n === nothing ? "(无名)" : string(n)
        catch
            "?"
        end
    end
end

frames_of(m) = Base.invokelatest() do
    frs = try getfield(m, :frames) catch; nothing end
    frs === nothing && return nothing
    isempty(frs) ? nothing : frs          # 返回原对象（勿 collect，否则 objectid 每次都变）
end

traces_of(m) = Base.invokelatest() do
    for s in (:tr, :traces)
        v = try getfield(m, s) catch; nothing end
        v === nothing && continue
        c = try collect(v) catch; nothing end
        (c !== nothing && !isempty(c)) && return c
    end
    nothing
end

fr_traces(fr) = Base.invokelatest() do
    try collect(fr.fields[:traces]) catch; nothing end
end

function snapshots(path)
    nb = splitext(basename(path))[1]
    mod = Module(Symbol("CHK_", replace(nb, r"[^A-Za-z0-9_]" => "_")))
    Base.include(mod, joinpath(@__DIR__, "..", "src", "OverQubit.jl"))
    Base.eval(mod, Meta.parse("using .OverQubit, PlutoUI, PlotlyBase, Statistics, Random, HypertextLiteral, Markdown"))
    text = read(path, String)
    chunks = split(text, "\n# ╔═╡")
    Base.include_string(mod, replace(chunks[1], r"\A### A Pluto\.jl notebook ###\n# v[\d.]+\n" => ""), "header")
    for d in ["const EJ = 20.0; const EC = 0.30; const ng = 0.0",
              "const detune = 0.0; const amp = 0.05; const sigma = 10.0; const Tns = 60.0",
              "const E_Cr = 0.06; const om_r = 8.5; const kappa = 0.01; const nshots = 200; const beta = 0.0",
              "const cmp2 = false",
              "const T1us = 30.0; const Tphius = 50.0; const sigmad = 20.0; const deltak = 30.0",
              "const nmem = 16; const taumax = 10.0",
              "const g_c = 0.05; const det2 = 0.03; const T1q = 20.0; const taumax2 = 40.0",
              "const phi_ext = 0.0; const EJ0 = 20.0; const D_slider = 0.1",
              # cz_gate.jl 的滑块默认值
              "const ratio2 = 1.20; const amp_phi = 0.073; const t_pulse = 37.5; const shape_sel = \"平滑沿\""]
        Base.eval(mod, Meta.parse(d))
    end
    out = []
    prev_fid = nothing
    for (i, chunk) in enumerate(chunks[2:end])
        code = replace(chunk, CELL_RE0 => "")
        (startswith(strip(code), "Cell order:") || startswith(strip(code), "PLUTO_")) && continue
        code = replace(code, INCLUDE_RE0 => "")
        code = replace(code, "@__DIR__" => repr(dirname(abspath(path))))
        occursin("@bind", code) && continue
        try
            Base.include_string(mod, code, "cell_$(nb)_$i")
        catch e
            println("  ($nb cell $i 求值失败，快照到此为止：", sprint(showerror, e)[1:min(70, end)], ")")
            break
        end
        frs = frames_of(mod)
        tl = traces_of(mod)
        fid = frs === nothing ? nothing : objectid(frs)
        tid = tl === nothing ? nothing : objectid(tl)
        # 只在「本格新定义了 frames」时配对：否则后一格可能把 tr/traces 换成别的图的，
        # 而 frames 还留在上一格（会配错）。
        if frs !== nothing && !isempty(frs) && fid != prev_fid
            println("   [快照] $nb cell $i: traces=", tl === nothing ? "none" : string(length(tl)),
                    " frames=", length(frs),
                    " idx=", join(sort(unique([let t = fr_traces(f); t === nothing || isempty(t) ? -1 : Int(t[1]) end for f in frs])), ","))
            (tl !== nothing) && push!(out, (cell = i, traces = tl, frames = frs))
        end
        (frs !== nothing) && (prev_fid = fid)
    end
    out
end

println("== 动画帧 traces 索引校验 ==")
allok = true
for f in sort(readdir(joinpath(@__DIR__, "..", "notebooks")))
    endswith(f, ".jl") || continue
    occursin("backup", f) && continue
    name = f[1:end-3]
    sns = snapshots(joinpath(@__DIR__, "..", "notebooks", f))
    if isempty(sns)
        println(rpad(name, 20), " 无动画帧（跳过）")
        continue
    end
    bad = String[]
    for (cell, tl, frs) in sns
        ntr = length(tl)
        idxs = Int[]
        for fr in frs
            tix = fr_traces(fr)
            if tix === nothing || isempty(tix)
                push!(bad, "cell $cell 有一帧没带 traces")
                continue
            end
            ix = Int(tix[1]) + 1                     # 0 基 → 1 基
            push!(idxs, ix)
            (ix < 1 || ix > ntr) && (push!(bad, "cell $cell 帧 traces 索引越界"); continue)
            npts = trace_points(tl[ix])
            npts > 20 && push!(bad, "cell $cell 帧 traces=[$(ix - 1)] 指向 $(npts) 点的长曲线「$(trace_name(tl[ix]))」——背景曲线会被顶替")
        end
        u = sort(unique(idxs))
        descr = join([string("trace$(uix - 1)=", trace_name(tl[uix]), "(", trace_points(tl[uix]), "点)") for uix in u], ", ")
        println(rpad(name, 20), " cell $cell: ", ntr, " 条 trace / ", length(frs), " 帧 → ", descr)
    end
    if !isempty(bad)
        allok = false
        foreach(b -> println("      ✗ ", b), bad)
    end
end
println(allok ? "FRAME-TRACES CHECK PASS" : "FRAME-TRACES CHECK FAIL")
