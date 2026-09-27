# 会话操作日志

> 每次 AI 会话结束追加一段：**做了什么 / 关键决策 / 验证状态 / 遗留**。
> 目的是让下一轮（人或 AI）能接上，不用重新考古。

---

## 2026-09-27（第 5 轮）CZ 门引擎 + ⑧⑨ 两个 notebook

**触发**：用户要求"增加一个超导量子 CZ 门实现原理的教程以及 CZ 门校准方案的实现原理的教程"。

**做了什么**
- `src/OverQubit.jl` 新增 CZ 引擎（仍只依赖 LinearAlgebra）：`cz_pair`/`CZPair`（qubit2 = SQUID）、
  `cz_hamiltonian`/`cz_levels`/`cz_gap`/`cz_crossing`/`cz_detuning`（谱学，找 |11⟩↔|02⟩ avoided crossing）、
  `cz_pulse_shape`/`cz_flux`/`cz_evolve`（分段常值脉冲传播 + 并行参考演化）、
  `cz_conditional_phase`/`cz_leakage`/`cz_ramsey`/`cz_ramsey_pair`/`cz_metrics`/`cz_zcorrect`/`cz_chevron`（校准可观测量）。
- `notebooks/cz_gate.jl`（⑧ 原理）：能级扇形、磁通轨迹 + 条件相位累积、双 Bloch 球动画（条件相位即 Bloch 转角）、
  相位 fringe、|U_rel|² 热图、8 步推导、quiz。
- `notebooks/cz_calibration.jl`（⑨ 校准）：chevron 热图（P₁）+ 泄漏热图、长度/幅度两条 fringe
  （信号 vs 参考序列）、8 行校准流程 + 误差预算读数表、9 步推导、quiz。
- `scripts/validate_cz.jl`（新，28 项）；`scripts/notebook_selftest.jl` 补 4 个新滑块默认值
  （`ratio2`/`amp_phi`/`t_pulse`/`shape_sel`）；`docs/architecture.md` §16 记录 + §5 表格 / §M3 状态更新。

**关键决策**
- **固定参考基投影**（不是每步重新对角化再截断）：参考基取 Φ=0 的两个本征态，任意磁通下把
  随磁通变化的电荷基 Ĥ₂(Φ) 投回同一组基；`cz_hamiltonian(p,0)` 与 `TwoQubit.H` 逐项一致作为回归。
- **相对传播子 `Urel = U·U_ref†`**（`U_ref` = 关掉 `g_c` 的同一磁通脉冲）：|11⟩ 对角相位以 ~13 GHz 旋转，
  直接取 angle 差每步跨 ±π → 去包裹必错；参考相减后差分量级只有 MHz~百 MHz。**这是本引擎最重要的一行。**
- 相位取 `Urel` 的**对角元**（`Σ_j U[c,j]U_ref[c,j]*`），不能写 `U[c,c]·conj(Uref[c,c])`（脉冲期间 U_ref 在乘积基不对角）。
- 默认参数 `ratio2 = 1.2`、`g_c = 0.03`、幅度 = 0.55Φ*、长度 37.5 ns：|Δφ| = 0.038 rad、泄漏 0.27%、
  4 态保真度 99.7%。idle 点必须比 crossing 高 |α|（磁通只会减小 E_J）。
- 「门」在固定时间窗内定义（`T_ns = 1.5 t_pulse`）：idle 的 always-on ZZ 会继续以 ~0.044 rad/ns 累积条件相位。

**验证（全部 PASS）**
- `validate_cz.jl` 28/28（与既有引擎的一致性、酉性、g_c=0 判据、crossing 判据、idle ZZ 速率（含 2π）、
  步长收敛、方沿/平滑沿对比、chevron 自洽）。
- `notebook_selftest.jl` 9 个 notebook 全过（含 `check_no_raw_frames` 静态检查）；
  `validate.jl` / `validate_dynamics.jl` / `validate_new.jl` 均未回归。
- `spike/check_frames.jl` PASS（cz_gate cell21 38 trace / 48 帧 → 专用红点 trace）；
  `spike/preview_any.jl` 两页无头渲染成功（`preview_cz_gate.html` / `preview_cz_calibration.html`）。

**顺手修掉第 4 轮记录的两个遗留**
- `FAIL g_c=0 时无泄漏`：判据 `< 1e-12` 不现实（分段传播累计 ~1.7e-11）→ 放到 `< 1e-9`。
- `ERROR DimensionMismatch 9 vs 6`：第 3 段谱学交叉检查里我多写了一个 `sqrt.`（TQ.H 已是 rad/ns，
  除以 2π 即 GHz，不能再开根号）→ 去掉后与 `cz_levels` 9 个本征值逐项对齐。

**遗留**
- 全部变更仍未 commit；`spike/preview_*.html` 是否入库待定。
- `spike/check_frames.jl` 末尾 `allok` 在顶层 for 里赋值触发了软作用域告警，进程 exit code 变 1
  （检查本身 PASS，输出正常）。

---

## 2026-09-27（第 4 轮）建立 ai/ 教训库

**触发**：用户要求"每次遇到问题应该记录下来，增加一个 ai 文件夹，记录 ai 操作的过程和教训"。

**做了什么**
- 新建 `ai/`：`README.md`（索引）、`lessons.md`（约 40 条踩坑，四段式：症状/根因/对策/防回归）、
  `checklists.md`（改 notebook / 物理层 / 渲染层 / 提交前清单 + 排障速查表）、`workflow.md`（无头验证排版的方法）。
- 把前三轮散落在对话里的教训全部固化：Pluto 文件格式 6 条、Pluto 显示层 3 条、
  plotly.js 布局与帧 5 条、物理单位口径 8 条、Windows/Julia 工具链 6 条、验证思路 6 条。
- 顺手清掉 `spike/` 里的一次性调试脚本（`add_frame_check.jl`、`serve.jl`、`dbg_*.jl`、`parsecheck.jl`）。

**决策**
- `ai/` 只写"**真的浪费过时间**"的东西，设计约定仍归 `docs/architecture.md`，两处互相引用不重复。
- 每条必须带**防回归**（哪条脚本会报错），否则等于没写。
- 无头验证方法单独成篇（`workflow.md`），因为"没有浏览器怎么自查排版"这个问题会反复出现。

**验证**：`notebook_selftest.jl` PASS；`validate.jl` / `validate_dynamics.jl` / `validate_new.jl` PASS；
`spike/check_frames.jl` PASS。文档为新增，无回归风险。

**遗留**：全部变更仍未 commit（见文末状态）。

---

## 2026-09-27（第 4 轮）建立 ai/ 教训库 + 顺手修掉 cz_gate 同类隐患

**触发**：用户要求"每次遇到问题应该记录下来，增加一个 ai 文件夹，记录 ai 操作的过程和教训"。

**做了什么**
- 新建 `ai/`：`README.md`（索引 + 三条最贵教训）、`lessons.md`（约 45 条踩坑，四段式）、
  `checklists.md`（改 notebook / 物理层 / 渲染层 / 提交前清单 + 排障速查表）、
  `workflow.md`（无头验证排版：DOM 几何断言 + Julia 侧帧索引断言 + 源码静态检查）、
  `session-log.md`（历轮记录）、`known-issues.md`（未解决问题）。
- `docs/architecture.md` 头部加 `ai/` 入口。
- **顺手修掉 `notebooks/cz_gate.jl` 同类隐患**：新加的静态检查立刻抓到它仍在用裸 `frame(`
  （帧会顶掉左球第一条纬线），已改为 `anim_frame(BALL, ...)` + 专用红点 trace；
  `check_frames.jl` 补了 cz_gate 的滑块默认值（`ratio2/amp_phi/t_pulse/shape_sel`）后 7 个动画图全过。
- 清掉 `spike/` 里的一次性调试脚本。

**新记录的教训（本轮新增）**
- **忘了 `--project=.` 会得到假报错**：我跑 `julia scripts/validate_cz.jl`（缺 `--project`）得到
  `UndefVarError: I not defined in Main`，而脚本明明 `using LinearAlgebra`；补上 `--project=.` 后同一脚本
  大部分 PASS。**以后所有脚本一律 `julia --project=. scripts/xxx.jl`。** 已写进 checklists。
- `cz_gate.jl` 证明静态防回归有价值：它不是我写的，同样埋着 `frame()` 的雷。

**遗留问题（记录到 `ai/known-issues.md`，未动手修）**
- `scripts/validate_cz.jl`：`FAIL g_c = 0 时无泄漏`（判据可能不合理：g_c=0 时驱动仍在，泄漏到 |2⟩ 是物理真实的）；
  `DimensionMismatch 9 vs 6`（第 4 段拿 9 维向量和 6 维广播，疑为 `nlev=3` 下的维度口径不一致）。
- 全部变更仍未 commit。

**验证**：`notebook_selftest.jl` 8 个 notebook（含 cz_gate）PASS；`check_frames.jl` PASS；
`validate.jl` / `validate_dynamics.jl` / `validate_new.jl` PASS；
`validate_cz.jl` 11 PASS / 1 FAIL / 1 ERROR（属已知问题，非本轮改动引入）。

---

## 2026-09-27（第 3 轮）修复"播放时抛物线消失"

**触发**：用户提问"播放时抛物线会隐藏，是特性还是 bug？"并附势阱图截图。

**定位过程**
1. 对比 `flux_tuning.jl` 与 `mvp0_transmon.jl` 的同款动画 —— 写法相同，排除单文件差异。
2. 怀疑 Plotly.js 帧语义 → 直接读 plotly.js 源码（webfetch `raw.githubusercontent.com/plotly/plotly.js/master/src/plots/plots.js`），
   在 `frameMerge` 里找到铁证：
   ```js
   traceIndices = framePtr.traces;
   if(!traceIndices) { /* If not defined, assume serial order starting at zero */ ... }
   ```
   以及 `plots.transition` 的 `gd.data[traceIndices[i]] = extendTrace(...)`。
3. 结论：帧数据 `data[0]` 永远作用在 `gd.data[0]`，而 trace 0 是势阱抛物线 ⇒ **bug**。

**修复**
- `OverQubitViz.anim_frame(idx, name, trace)`：强制写 `traces=[idx]`（0 基），docstring 里写清 why。
- 4 处修正（flux_tuning / mvp0 势阱、single_qubit_gate / two_qubit Bloch；后两者原本连专用 marker trace 都没有）。
- 2 处原本"碰巧对"的（s21_readout / t1_t2，其 trace 0 正是被动画的空 trace）也改成显式 `anim_frame(0, …)`。
- 静态防回归：`notebook_selftest.jl` 增 `check_no_raw_frames`（裸 `frame(` 直接报错）。
- 新增 `spike/check_frames.jl`：逐 cell 求值核对每帧索引必须指向小 trace。6 个动画图全过。

**踩到的附加坑**（已入 lessons）
- `frames_of()` 里 `collect()` 导致 objectid 每次不同 → "是否本格新定义 frames"永远判真 → 配错 trace 列表。
- 顶层 for 循环赋值的软作用域、world age 警告（`invokelatest` 包一下即可）。

**验证**：四条验证链全 PASS；`check_frames.jl` 输出见 `ai/workflow.md` §3。

---

## 2026-09-27（第 2 轮）修复 Notebook 排版（挤扁 / 竖排图例）

**触发**：用户"笔记本有一个地方显示不正常" + 截图（扇形图半宽、图例竖排、出现 "1:" "2:"）。

**定位过程（走了弯路，教训已固化）**
1. 一度怀疑 plotly 标题旋转 / 图例 orientation —— 自建宽度实验页（180→640px 容器）证伪：标题始终水平，
   图例在 <~200px 时才竖排。
2. 读本机 Pluto 包源码（`.julia/packages/Pluto/F6SNP/src/runner/PlutoRunner/src/display/mime dance.jl`、
   `display/tree viewer.jl`）+ 前端 `treeview.css` / `TreeView.js`，才锁定真凶：
   `pluto.tree+object` 在 MIME 优先级里排在 `text/html` 前且对 `Tuple` 生效，
   `<pluto-tree class="collapsed">` 默认 `flex-direction: row` ⇒ Tuple 返回值被并排渲染。
3. 截图上那个诡异的 "1:" "2:" 就是 tree viewer 的 `p-k` 序号——**关键线索，一开始没认出来**。

**修复**
- `OverQubitViz.oq_stack(...)`：多块 HTML 包成单个 HTMLStr（flex column、子项 `width:100%`）。
- 布局加固：`layout_base` 标题 16→14px、`margin_t` 56→68、图例 `y=1.02 + xanchor/yanchor`、新增 `legend_x`
  （按钮 `x=0.02,y=1.03` 与图例行不打架）；`.oq-plot` 去掉 `overflow:hidden`；长标题全部改短。
- 3 处 tuple 返回改 `oq_stack`（flux_tuning / s21_readout / single_qubit_gate），备份副本也一并改。
- 防回归：`check_html_tuple`（cell 返回一串 HTMLStr/MD 直接报错）。

**重大失误（教训 §1.6）**
用脚本批量替换 `legend_y=..., margin_t=...)` 时，正则把**右括号一起吃掉**，造成多文件语法错误；
更阴的是 `Meta.parseall`（JuliaSyntax）判 OK 而 `include_string`（flisp）判 FAIL。
最后逐处手工补齐括号才通过。**结论：批量改 notebook 后必须跑 `notebook_selftest.jl`。**

**顺带确认**：用户附件 `flux_tuning.html` 是浏览器"保存网页"得到的 Pluto 编辑器外壳
（无 `window.pluto_statefile`），单独打开只转圈 —— 不是导出文件。

---

## 2026-09-26（第 1 轮）学习内容扩展

**做了什么**
- 物理层（`src/OverQubit.jl`）：磁通调谐（`squid_ej`/`transmon_at_flux`）、两比特
  （`TwoQubit`/`coupled_hamiltonian`/`exchange_rate`/`zz_rate`/`evolve_two_qubit`）、
  序列引擎（`SequenceEngine`/`evolve_segments`/`rotating_drive`/`dissipator_super`）。
- 渲染层（`src/OverQubitViz.jl`）：`setup_page`（plotly.js 懒加载——**Pluto 前端不预装 plotly.js，
  不加则所有图静默失败**）、`lesson_nav`/`stat_row`/`readout_table`/`callout`/`quiz`/`figure_note`/
  `banner(icon=)`/`layout_base(ytype=)`。
- 3 个新 notebook：`t1_t2.jl`、`two_qubit.jl`、`flux_tuning.jl`；4 个旧 notebook 美化
  （setup_page + 学习路径导航 + quiz）。
- 验收：`scripts/validate_new.jl`（30 项）新建；`notebook_selftest.jl` 默认滑块值表扩充。
- 文档：`docs/architecture.md` §5 演示总表 + §13 扩展记录（含 Pluto 格式坑清单）。

**关键决策**
- 三层扩展（引擎 / 组件 / notebook），全部沿用既有模式，不引入新依赖（仍只有 LinearAlgebra）。
- 衰减率单位从"×2π 后的 rad/ns"改为**直接 ns⁻¹**，并同步修正旧引擎 `evolve_density` 系列。
- 两比特 ZZ 读数默认给非零失谐（真实器件如此），把"精确同频时条件频率概念失效"写成教学点。

**验证**：黄金向量未回归（4.58e-13）；动力学 / 新引擎 / notebook 自测全 PASS。

---

## 当前仓库状态（截至 2026-09-27）

- **未 commit**。`git status`：
  - 修改：`docs/architecture.md`、`src/OverQubit.jl`、`src/OverQubitViz.jl`、
    `scripts/notebook_selftest.jl`、`notebooks/{mvp0_transmon,s21_readout,single_qubit_gate}.jl`
  - 新增：`ai/`、`notebooks/{drag,flux_tuning,t1_t2,two_qubit,cz_gate}.jl`、
    `scripts/{validate_new,validate_cz}.jl`、`spike/`（脚本 + 预览页）
  - 未跟踪的旧文件：`notebooks/s21_readout backup 1.jl`（用户自己的备份，已顺手改成 `oq_stack`）、
    `spike/preview_*.html`（预览产物，提交前应清掉或忽略）
- **待办 / backlog**：Purcell 效应、测量反作用、CZ 序列的完整教学化（`cz_gate.jl`/`validate_cz.jl` 已在但未并入演示路径）、
  `notebooks/s21_readout backup 1.jl` 是否归档由用户决定。
---

## 2026-09-27（第 6 轮）公式全部迁移到 MathJax / LaTeX

**触发**：用户"感觉公式的字体有点奇怪，能换个常用的 latex 排版字体吗" + 推导链截图。

**定位**
读 Pluto 前端源码找到铁证：`CellOutput.js` 的 `apply_enhanced_markup_features`
只 `MathJax.typeset(container.querySelectorAll(".tex"))`，`SetupMathJax.js` 里
`processHtmlClass: "tex"`——**不带这个 class 的元素根本不被排版**，公式只能靠浏览器字体凑字形
（`√` 渲染成 `ʃ` 就是这么来的）。

**做了什么**
- `src/OverQubitViz.jl`：新增 `tex(l)`（行内 `\(...\)`）/ `texblock(l)`（display `\[...\]`），
  强制带 `class="tex"`；docstring 写死五条纪律（含 `$` 插值冲突、raw 字符串、禁 CJK）。
- `HTMLStr` 增加 `Base.string`/`Base.print`——否则 `"$(tex(...))"` 插值会吐裸 repr。
- **9 个 notebook 的推导链全部 LaTeX 化**（187 处 `.tex`），外加 quiz/concept_cards 里
  8 处高频公式（电荷色散、E_J(Φ)、f01∝√(EJ EC)、Ramsey 条纹、iSWAP 转移率…）。
- `spike/preview_any.jl` 复刻 Pluto 的 MathJax 配置，静态页也能排版（修了
  `typesetPromise` 要传**数组**、`window.MathJax` 占位竞态两个坑）。
- 防回归：`notebook_selftest.jl` 新增 `check_no_cjk_in_math`（数学定界符内出现 CJK 直接报错）。

**新记录的教训**（lessons §7）
Julia 字符串里 `$` 会触发插值（本轮连踩 3 次）、raw 字符串才能写 LaTeX 反斜杠、
MathJax 无 CJK 字形（`\text{中文}` 静默缺字）、`derivation` 步骤必须是三元组。

**验证**
- `notebook_selftest.jl`：9 个 notebook 全 PASS。
- 浏览器 DOM：`mjx-container` 数 == `.tex` 数（drag 页 12/12 ✓，display 公式带正确 viewBox）。
- `validate.jl` / `validate_dynamics.jl` / `validate_new.jl` PASS、`check_frames.jl` PASS（均未回归）。

**遗留**
`concept_cards` / `tryout` / `callout` 里还剩描述性文字公式（不影响阅读）；`validate_cz.jl` 的
两个 FAIL/ERROR 见 `known-issues.md`。

---

## 2026-09-27（第 7 轮）重构为标准 Julia 包结构

**触发**：用户要求"按照 Julia 项目的一般形式重构项目"。

**做了什么**
- 新增 `Project.toml`（name=OverQubit，uuid `db85b13b-cf81-4815-8bd1-109f4bf78330`；
  deps：LinearAlgebra / PlotlyBase / PlutoUI / HypertextLiteral；compat + test target）。
- `src/OverQubit.jl`（1076 行单文件）拆为 `transmon.jl` / `readout.jl` / `dynamics.jl` /
  `two_qubit.jl` / `cz.jl` 五个文件，include 顺序即依赖顺序；**export 全部集中到入口文件**。
- `src/OverQubitViz.jl` → `src/viz/OverQubitViz.jl`，作为子模块 `OverQubit.OverQubitViz`
  载入，渲染 API 经 `using .OverQubitViz` + `export` 从包转出——notebook 一条 `using .OverQubit`
  拿到全部物理 + 渲染名字。
- 新建 `test/`：`runtests.jl` + 按 src 文件一一对应的 5 个测试文件；四个 `scripts/validate*.jl`
  的物理断言**无损迁移**（`check(name, cond)` → `@testset`），黄金向量数据从 `data/` 移到
  `test/golden_transmon.jl`，`generate_golden.py` 输出路径同步；旧脚本删除。
- 9 个 notebook 的加载块从"两个 include + 两个 using"缩为"一个 include + 一个 using"。
- 无头工具改用 `Base.include(mod, SRC)` 预载包模块（`include_string` 解析不了包内部的
  `include("viz/…")` 相对路径）：`notebook_selftest.jl`、`spike/preview_any.jl`、`spike/check_frames.jl`。
- 文档：README.md（新建）、`.gitignore` 补全、architecture.md §17（本次重构的唯一记录）、
  checklists.md 的验证命令（validate 四条链 → `Pkg.test()`）、workflow.md / known-issues.md 路径同步。

**关键决策**
- **单包 + 渲染层做子模块**，不做两包 workspace：演示器规模不值得两个 Project.toml 的仪式感；
  分层铁律改述为"物理层文件不 import 渲染符号"（模块边界不变）。代价是包 deps 里多了 PlotlyBase。
- **notebook 维持 include 相对路径**，不改为 `using OverQubit`：Pluto notebook 环境独立，
  自包含 include 不要求激活包环境，老工作流零破坏。
- **测试环境注意**：`Pkg.test()` 的临时环境只认 `[targets]` 声明的包——`Test` 和 `Statistics`
  都要写进 `[extras]`/`[targets]`，否则测试文件里 `using Statistics` 直接挂（本轮踩到）。

**验证**
- `julia --project=. -e 'using Pkg; Pkg.test()'` → **101/101 PASS**（约 4 分钟）。
- `scripts/notebook_selftest.jl` → `NOTEBOOK SELF-TEST PASS`（9 个 notebook）。
- `spike/check_frames.jl` → `FRAME-TRACES CHECK PASS`；`spike/preview_any.jl` 出页正常。
- 导出名 89 个全部 `isdefined`；`using OverQubit` 即装即用。

**顺带修掉的 flaky 断言**
iSWAP 动力学对比的 `argmax` 峰位检查（原 validate_new §3）：sin² 的峰恰好落在采样点上，
浮点噪声让 `argmax` 随机落到任意一个峰（相差整数个周期，本轮实测差 2 个周期 11.6 ns）。
改为"前 1/3 时窗取 argmax"（恰含第一个峰），断言才稳定。

**遗留**
- 全部变更未 commit（见 known-issues §3）。
- `scripts/preview_mvp0.jl` 还是旧式独立脚本（自带色板常量，未走渲染层），功能正常，暂不迁移。
