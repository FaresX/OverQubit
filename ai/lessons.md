# 踩坑与教训

> 每条四段：**症状 / 根因 / 对策 / 防回归**。按"下次遇到什么现象"检索。
> 交叉引用：`docs/architecture.md` §11（工程约定）、§13（扩展记录）、§14（tuple 排版）、§15（动画帧）。

---

## 1. Pluto notebook 文件格式层

### 1.1 `UndefVarError(:<uuid>)` —— cell 头部剥不掉
- **症状**：`notebook_selftest.jl` 报 `UndefVarError: 90000000...`（一长串十六进制）。
- **根因**：Pluto cell 头是 `# ╔═⡅ <uuid>`，其 UUID 末段必须**恰好 12 位十六进制**，否则
  `CELL_RE = r"^\s*(?:[0-9a-f-]{36}|\d+)\s*\n"` 剥不掉头部，uuid 被当成标识符求值。
- **对策**：新建/手改 cell 头时，末段写满 12 位（如 `...-8000-00000000000f`）。
- **防回归**：`notebook_selftest.jl` 会立刻炸。

### 1.2 `begin` 块里写 `f(x) = ...` 会 `UndefVarError(:x0)`
- **症状**：Julia 1.12 报参数未定义。
- **根因**：短式函数定义在 `begin` 块内被当赋值语句处理。
- **对策**：块内一律 `function f(x) ... end`。本项目 `flux_tuning.jl` 的 `classical_traj` 就是这么写的。

### 1.3 顶部 `for` 软作用域吃变量
- **症状**：循环里的 `x_` / 裸赋值循环外取不到。
- **对策**：把循环包进函数；`for` 里要写全局就加 `global`。

### 1.4 `md"""` 长中文插值静默错乱
- **根因**：Markdown 解析 + `$` 插值 + 中文标点混在一起容易出歧义。
- **对策**：正文一律 `@htl("""...""")` + `$(var)`，只用简单变量（别在插值里写表达式）。
  见 `notebooks/flux_tuning.jl` 的写法。

### 1.5 `attr()` 返回的是 Dict，不能事后改
- **症状**：`lay.yaxis.type = "log"` 无效或报错。
- **对策**：所有轴参数都走 `layout_base` 的关键字（已有 `ytype=`、`yrange=`、`legend_x=`…），
  需要新参数时改 `layout_base`，不要在 notebook 里补丁。

### 1.6 用脚本批量改 notebook 会改出括号残骸
- **症状**：`ParseError("Expected ')' or ','")`、`Expected 'end'`。
- **根因**：正则/字符串替换把 `layout_base(...)` 的参数连同右括号一起吃掉了。
  更阴的是：**`Meta.parseall`（JuliaSyntax）可能判 OK，而 `include_string`（flisp）判 FAIL**，
  所以"能 parse"不等于能在 Pluto 里跑。
- **对策**：批量改完必须跑 `notebook_selftest.jl`（它用 `include_string`）。
- **防回归**：见 `checklists.md` 的"改动 notebook 后"。

---

## 2. Pluto 显示层（最高频，最贵）

### 2.1 cell 末尾写 `html1, html2` → 两张图并排挤扁、图例竖排、标题溢出、出现 "1:" "2:"
- **症状**：图形只剩半宽；plotly 图例被折成竖排堆在左上；长标题被裁；输出左边挂 `1:` `2:` 序号。
  第一张图（单独返回的）却完全正常。
- **根因**（Pluto 源码，非 plotly）：
  1. `PlutoRunner/src/display/mime dance.jl` 的 `allmimes` 把
     `application/vnd.pluto.tree+object` 排在 `text/html` **前面**；
  2. `display/tree viewer.jl` 里 `pluto_showable(::MIME"…tree+object", ::Tuple) = true`；
  3. `TreeView.js` 渲染出 `<pluto-tree class="collapsed">`，而 `treeview.css` 规定
     `pluto-tree.collapsed pluto-tree-items { flex-direction: row; align-items: baseline }`、
     `pluto-tree p-r > p-v { display: inline-flex }`、`p-r > p-k` 显示序号。
  ⇒ Tuple 让 Pluto 走 tree viewer，两个图被塞进**同一行、各占半宽**。
- **对策**：`OverQubitViz.oq_stack(html1, html2; gap=12)` —— 把多个 HTML 片段包成**一个** HTMLStr
  （flex column、子项 `width:100%`）。Pluto 对单个 HTMLStr 走 `text/html` 原样内联，每张图拿满宽。
  同规则适用于 `md"a", md"b"`。
- **防回归**：`notebook_selftest.jl` 的 `check_html_tuple` —— cell 返回值是 Tuple/Vector 且元素全是
  HTMLStr 或 Markdown.MD → 直接报错。**实测可触发**（改回旧写法会 FAIL）。

### 2.2 浏览器"保存网页"得不到可用导出
- **症状**：存下来的 `.html` 8.8MB，打开只有一个转圈 progress。
- **根因**：那是 Pluto 编辑器外壳（前端 bundle 全内联），`<body>` 里只有
  `<pluto-editor class="loading fullscreen">`，且**没有** `window.pluto_statefile = "data:;base64,…"`
  （真导出 `/notebookexport → generate_html()` 会 bake statefile）。
- **对策**：用 Pluto 的导出按钮；本地快速预览用 `julia spike/preview_any.jl`（`NB=<name>`）。

### 2.3 Pluto 的 `pluto-output` 会继承 Alegreya Sans 字体
- **对策**：所有自定义 HTML 组件都用内联 `style`（本项目 `OverQubitViz` 已经这么做），
  别依赖全局字体；图内字体由 Plotly layout 的 `font.family` 显式指定。

---

## 3. plotly.js 布局与前端的恩怨

### 3.1 横向图例在窄容器里会折成竖排（阈值 ≈ 200–260px）
- **症状**：图例项上下堆成一列、绘图区被挤成一条、"文字竖着排"。
- **实测**：4 项图例（"f01(Φ)/f12(Φ)/f01+f12/当前磁通"，≈367px）在 468px 容器里是单行，
  在 180px 容器里逐项堆叠（相邻项 y 坐标相差 ~19px 而非相同）。
- **对策**：**保证图拿满宽**（这是 2.1 的连带收益）；图例名尽量短（去长后缀、去全角括号）；
  图例别放 `legend_y > 1.1`（推到绘图区外更脆弱）。

### 3.2 动画按钮与图例都默认在 `x=0, y≈1.1`，会重叠
- **对策**：`layout_base` 现在是 按钮 `x=0.02, y=1.03` + 图例 `x=legend_x, y=1.02, xanchor="left"`；
  **带动画的图必须传 `legend_x≈0.15`**，两者同行不打架。

### 3.3 长标题会溢出容器并被 `overflow:hidden` 裁掉
- **实测**：16px 下 38 字符标题宽 508px > 468px 容器。
- **对策**：`layout_base` 标题字号已从 16 → 14（≈26 个中文字符 ~400px）；
  `.oq-plot` 去掉 `overflow:hidden`；标题仍要短（"A · 能级扇形图：f01(Φ) 与 f12(Φ)" 这种长度）。

### 3.4 animation 帧不写 `traces=[i]` → 播放时背景曲线整条消失 ★
- **症状**：静态正常；点播放后抛物线/经纬线框不见了，只剩标记点。
- **根因**（plotly.js `src/plots/plots.js` `frameMerge`）：
  ```js
  traceIndices = framePtr.traces;
  if(!traceIndices) { /* If not defined, assume serial order starting at zero */ ... }
  ```
  随后 `plots.transition`：`gd.data[traceIndices[i]] = extendTrace(gd.data[traceIndices[i]], data[i])`
  ⇒ 单条帧数据**永远覆盖 `gd.data[0]`**，而 trace 0 常是背景曲线。
- **对策**：`OverQubitViz.anim_frame(idx, name, trace)`（强制写 `traces=[idx]`，idx 为 0 基），
  配一条**专用小 trace**（放最后）：
  ```julia
  push!(traces, scatter(x=[x0], y=[y0]; mode="markers", showlegend=false))   # 先占位
  BALL = length(traces) - 1
  frames = [anim_frame(BALL, string(k), scatter(x=[xs[k]], y=[ys[k]]; mode="markers", ...))
            for k in 1:nfr]
  ```
- **防回归**：两道。① `notebook_selftest.jl` 静态扫源码，裸 `frame(` 直接报错；
  ② `spike/check_frames.jl` 逐 cell 求值核对每帧索引指向的必须是小 trace（>20 点判为背景曲线）。

### 3.5 `plotly_html` 的 div 只有高度、宽度靠父容器
- **对策**：不要给它写固定 `width`；父容器是什么宽度图就是什么宽。塞进 flex/grid 时要小心
  （flex 子项默认 `flex: 0 1 auto`，宽度可能塌成内容宽）——所以用 `oq_stack` 时子项写 `width:100%`。

---

## 4. 物理与单位（写引擎时先确认，别事后返工）

| 约定 | 说明 |
| --- | --- |
| 哈密顿量频率 | 入口传 **GHz**，内部 `×2π` 折 rad/ns |
| 衰减率 | 直接传 **ns⁻¹**（指数速率，**不再 ×2π**，否则 T1 小 2π 倍） |
| 1/Tφ、1/T2 | `1/Tφ = gammaphi`；`1/T2 = 1/(2T1) + 1/Tφ` |
| ZZ 判据 | 两能级截断下 **ZZ ≡ 0**（非谐性是必要条件，须 `nlev ≥ 3`） |
| dressed 态识别 | 一律 `argmax(abs2.(row))` —— **别用 `argmax(f, itr)`**（返回元素而非索引） |
| 驱动 phase | 旋转轴在 xy 平面的方位角，0° = σ_x |
| J 与 g | `J = g_c · n01²`；小耦合下 `ZZ ∝ g_c²` |
| 色散 χ | `χ = g²/Δ`，|0⟩→ωr−χ、|1⟩→ωr+χ |
| CZ 条件相位 | `φ_CZ = φ₀₀ − φ₀₁ − φ₁₀ + φ₁₁`（mod 2π），理想 = π |
| CZ 共振条件 | `f01₁ = f01₂ + α₂`（α₂<0）→ 可调比特的 idle 点必须比 crossing **高**（磁通只会减小 E_J） |
| 频率 vs 相位速率 | `rad/ns = 2π × GHz`；任何"数值 vs 谱学"速率对照都要带这个 2π（第 5 轮连踩两次） |
| 时变两比特 H 的实现口径 | **固定参考基投影**（Φ=0 本征态 + 电荷基 Ĥ₂(Φ) 投回），不要每步重新对角化再截断 |

### 4.1 13 GHz 动态相位会让 `angle` 差分彻底失效（第 5 轮，本次最贵）

- **症状**：`φ_jk = angle(U[c,c])` 逐步去包裹，结果单态相对相位 100 ns 漂 100 rad、四态组合毫无规律；
  脉冲相位看起来完全随机。
- **根因**：|11⟩ 的对角相位以 `2π×13.6 GHz` 旋转，`dt = 0.05 ns` 一步就是 **4.3 rad > π**，
  我的去包裹假设 `|Δφ| < π` 直接破；而且即使不混叠，看到的也只是动态相位而非门相位。
- **对策**：同时传播**参考演化** `U_ref`（同一磁通轨迹、关掉耦合 `g_c`），取**相对传播子**
  `Urel = U·U_ref†` 的对角元：`⟨c|U U_ref†|c⟩ = Σ_j U[c,j]·conj(U_ref[c,j])`。
  差分量级只剩 MHz~百 MHz，每步变化 ≪ π，去包裹稳定；这正是实验上「spectator 参考序列」做的事。
- ⚠️ **别写成** `U[c,c]·conj(Uref[c,c])`：脉冲期间 `U_ref` 在乘积基里并不对角，漏掉 `Σ_j` 交叉项相位就错。
- **防回归**：`scripts/validate_cz.jl` 的 `idle 条件相位速率 = −2π·(谱学 4 态组合)` 与
  `去包裹相位与末态 Urel 自洽（mod 2π）` 两项直接卡这条；跑偏就 FAIL。

### 4.2 用 `Urel` 之后还要「虚拟 Z 校正」，否则 P₁ / F_proc 全是噪声

- **症状**：`cz_ramsey(U, nlev)` 得到的 P₁ ≈ 0.28（与条件相位毫无关系）；`F_proc = 0.16` 而 `F_state = 0.997`。
- **根因**：绝对传播子带着 13 GHz 级动态相位；过程保真度 `|tr(U_CZ† U_c)|²/16` 对四个单比特相位极其敏感
  （四个单位相量相加，稍微不同步就只剩 2 左右）。
- **对策**：`cz_zcorrect(r)` 在 `Urel` 上再减掉两个比特各自的单比特相位
  （`a = φ₀₀−φ₁₀`、`b = φ₀₀−φ₀₁` ⇒ `D = diag(1, e^{ib}, e^{ia}, e^{i(a+b)})`），
  之后 `P₁ = sin²(δφ/2)`、过程保真度 ≈ 态保真度。这一校正就是实验室的虚拟 Z / frame 更新。
- **防回归**：`validate_cz.jl` 的「理想 CZ 的读数：phase=π、0 泄漏、保真度 1、Ramsey P₁=0」。

### 4.3 CZ 的「门」必须在固定时间窗里定义

- **症状**：同样一次脉冲，把总时长拉长 100 ns，条件相位整体漂掉 4.4 rad，看起来「门不稳定」。
- **根因**：脉冲结束回到 idle 后，always-on ZZ 仍在按 `2π×(4 态能级组合)`（默认器件 ≈ 0.044 rad/ns）
  继续累积条件相位——这是 ⑤ 讲的 ZZ 串扰，不是 bug。
- **对策**：`cz_evolve` 默认 `T_ns = 1.5·t_pulse`，所有读数一律在该窗口内取；跨窗口比较要显式给 `T_ns`。
- **防回归**：`validate_cz.jl` 的 idle 速率项把这条固化成可算的数。

### 4.4 泄漏随脉冲长度**非单调**，别写「越长越绝热」

- **症状**：`amp = Φ*` 时泄漏 vs 长度是 50.8% → 1.3% → 63.9% → 78.6% → 1.7% 的振荡，看着像引擎坏了。
- **根因**：穿越 avoided crossing 的绝热/非绝热两条路径干涉（Stückelberg 相位），末态布居必然振荡。
- **对策**：描述趋势改用**单调的量**（如 |0,2⟩ excursion 的最深值随幅度单调增）；chevron 的「暗」
  可能是泄漏造成的假暗，必须 P₁ 与泄漏两张图一起看。
- **防回归**：`validate_cz.jl` 第 5 段用的是「excursion 随幅度单调」，没用「泄漏随长度单调」。

---

## 5. 工具链（Windows + Julia + 本仓库特有）

### 5.1 PowerShell 会吃掉 `julia -e '...'` 里的引号
- **症状**：`ParseError ... ip127.0.0.1 invalid numeric constant`、`-replace` 正则里的引号消失。
- **对策**：**别写 `julia -e` 长命令**，写 `spike/xxx.jl` 再 `julia spike/xxx.jl`；
  字符串里有双引号时优先用 Julia 脚本而非 PowerShell 单行。

### 5.1b 忘了 `--project=.` 会得到**假报错**
- **症状**：`julia scripts/xxx.jl` 报 `UndefVarError: I not defined in Main`，
  而脚本明明第 5 行就 `using LinearAlgebra`；按注释加 `--project=.` 后同一脚本大部分 PASS。
- **根因**：不带 `--project` 时用默认环境（GlobalEnv/共享 depot），包里符号解析与预期不一致；
  本项目所有脚本头部都注明 `julia --project=. scripts/xxx.jl`。
- **对策**：**一律带 `--project=.`**。见到诡异 `UndefVarError` 先确认命令带没带它。
- **同类**：`julia scripts/validate_cz.jl`（假 `I` 报错）vs `julia --project=. scripts/validate_cz.jl`（真 FAIL 才暴露）。

### 5.2 edit 工具对 tab 缩进敏感
- **症状**：`Could not find oldString`，肉眼看着一模一样。
- **对策**：`oldString` 必须精确匹配 tab 数量（本仓库 Julia 源码用 tab）。
  改不动就改用 Julia/PowerShell 脚本做替换（替换完立刻跑测试）。

### 5.3 世界年龄警告噪音
- **症状**：`WARNING: Detected access to binding ... in a world prior to its definition world`。
- **对策**：在 `Base.invokelatest(() -> ...)` 里访问运行时模块的字段
  （`notebook_selftest.jl` 的 `_htmlstr_type` 就这么处理）。

### 5.4 Julia 顶层 for 循环里赋值要 `global`
- **症状**：`syntax: global fixed: fixed is a local variable` / 软作用域警告。
- **对策**：脚本类代码包进 `function main() ... end` 再 `main()`。

### 5.5 浏览器工具用不了本地文件时怎么办
- file:// 不能被 `browser.tabs.open` 接受（只能用 `browser.preview`）；
  起本地 HTTP 服务也没用——**浏览器跑在另一台机器上，够不到你的 127.0.0.1**（502）。
- **对策**：走 `workflow.md` 的**无头验证**路线（Julia 侧生成 HTML + DOM 断言 + 静态检查）。

### 5.6 `notebook_selftest` 的模块隔离
- 每个 notebook 用**全新 Module**；预载物理/渲染模块代替 cell 里的 `include`（重复 include 会让 `using` 绑定歧义）。
- @bind cell 跳过，滑块默认值用常量注入（新增滑块要同步更新默认值表）。

---

## 6. 值得复用的验证思路

1. **黄金向量回归**：`validate.jl` 对 scqubits 的 8 个点，最大相对误差 4.6e-13 —— 每次动物理层必跑。
2. **解析式逐点对照**：新引擎不只测"数量级"，要和闭式解逐点比（iSWAP 的 `P₁₀=[4J²/(δ²+4J²)]sin²(πΩt)` 就是这么验的）。
3. **极限回归**：Φ=0.5、D=0 → 纯电荷极限 `f01→4E_C(n−n_g)²`；nlev=2 → ZZ≡0。
4. **收敛性交叉验证**：ncut=20 vs 40 谱一致、全电荷基 vs 能级截断模型的 J 一致。
5. **无头渲染自查**：`spike/preview_any.jl` 出静态页，再按 `workflow.md` 断言 DOM。
6. **"静默坏掉"的代码最危险**：plotly.js 未加载、图例竖排、曲线被顶替——都是静默的。
   凡是"看起来还在动"的都要做**结构性断言**（trace 数、帧索引、元素 bbox），不能只看截图。
7. **换一条独立代码路径算同一个量**：CZ 的条件相位既可以从 `Urel` 的四个对角元算
   （`cz_conditional_phase`），也可以从 Ramsey 两序列的 `angle(v1)−angle(v0)` 相减算
   （`cz_ramsey_pair`）——两者对不上就一定有一个错。第 5 轮就是靠这条抓出「取错对角元」的。
---

## 7. 公式必须走 MathJax，不能当普通 HTML 文本（第 6 轮）

### 7.1 症状
推导链 / 卡片里的公式（`ω01`、`√(8E_JE_C)`、`σ_x`）字体和正文不一致、字形随系统字体漂移，`√` 甚至渲染成 `ʃ`；整体"看不出是公式"。

### 7.2 根因
公式被写成**普通 HTML 文本**（Unicode 希腊字母 + `<sub>`）。Pluto 的
`apply_enhanced_markup_features`（`CellOutput.js`）只对 `.tex` 元素调 MathJax：

```js
window.MathJax.typeset(container.querySelectorAll(".tex"));
```

`SetupMathJax.js` 里 `processHtmlClass: "tex"`；Pluto 自己加载 MathJax 3.2.2（tex-svg-full）。

### 7.3 解法：`OverQubitViz.tex()` / `texblock()`

```julia
tex(l)       # 行内 <span class="tex">\(...\)</span>
texblock(l)  # 独占一行 <div class="tex">\[...\]</div>
```

**五条必须遵守的**（本轮全踩过）：

1. **必须带 `class="tex"`**，否则 Pluto 根本不排版。
2. **定界符用 `\(` `\)` 而不是 `$`** —— Julia 字符串里 `$` 会触发插值，直接 syntax error（本轮连踩 3 次：docstring 里、`two_qubit.jl` 的 `$C_c$`、preview 脚本里）。
3. **含反斜杠的 LaTeX 用 `raw"..."`** —— `"\O"`、`"\s"` 是 Julia 非法转义。
4. **数学里不许出现中日韩字符** —— MathJax 数学字体无 CJK 字形，`\text{中文}` **静默缺字**；中文放 math 外面，用 `$(tex(...))` 混排。
5. **`HTMLStr` 要能在字符串插值里用** —— 需定义 `Base.string` / `Base.print`，否则 `"$(tex(...))"` 会吐出 `Main.NB_xxx.OverQubitViz.HTMLStr("<span class=\"tex\">...")` 这种裸 repr。

预览页（`spike/preview_any.jl`）要复刻 Pluto 的 MathJax 配置，且
`MathJax.typesetPromise([document.body])` —— **参数是元素数组**，
传单个元素会 `TypeError: Object is not iterable`（Pluto 传的是 NodeList，所以它自己没事）。

### 7.4 `derivation` 步骤必须是**三元组**
`(操作, 公式, 说明)`；写成两元组 → `BoundsError`。本轮批量迁移时反复踩：没有公式的步骤也要凑三元组（公式位放公式、说明位放注释，或把散文挪进公式位）。
注意 `concept_cards` 的条目是**两元组** `(标题, 正文)`，别和推导链搞混——grep `^\t\(".*", ".*"\),$` 会把两者一起抓出来，要自己分辨。

### 7.5 防回归
- `notebook_selftest.jl` → `check_no_cjk_in_math`：`\(...\)` / `\[...\]` 内出现 CJK 直接报错。
- 预览页生成后统计 `class="tex"` 数量；浏览器侧断言 `mjx-container` 数 == `.tex` 数。
- **迁移规模**：9 个 notebook 的推导链全部 LaTeX 化（187 处 `.tex`）+ quiz/cards 8 处。`concept_cards` / `tryout` / `callout` 里还剩描述性文字公式，属"不影响阅读"的遗留。
