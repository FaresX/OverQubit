# 操作清单

> 动手前 5 分钟过一遍。每条末尾是"为什么"的索引（`ai/lessons.md` / `docs/architecture.md`）。

## A. 改动 notebook（`notebooks/*.jl`）

- [ ] cell 头 UUID 末段 **12 位十六进制**（lessons 1.1）
- [ ] `begin` 块内用 `function ... end`，不要短式定义（lessons 1.2）
- [ ] 正文用 `@htl` + `$(简单变量)`，不用 `md"""` 插值（lessons 1.4）
- [ ] **一个 cell 只返回一个 HTMLStr**；多个图/多段文字用 `oq_stack(...)`（lessons 2.1）
- [ ] 动画帧一律 `anim_frame(idx, name, trace)`，并有专用小 trace（lessons 3.4）
- [ ] 带动画的图给 `layout_base(..., legend_x=0.15, updatemenus=animation_menu())`（lessons 3.2）
- [ ] 图标题 ≤ 26 个中文字符；图例名短（lessons 3.3 / 3.1）
- [ ] 新滑块同步 `scripts/notebook_selftest.jl` 的默认值表
- [ ] 公式一律 `tex()` / `texblock()`（带 class="tex"、定界符用 `\(` `\)`、**数学里不出现中文**）——见 lessons §7
- [ ] `derivation` 步骤是**三元组** `(操作, 公式, 说明)`（少一个 → BoundsError）
- [ ] **自包含展示 cell 用 `let` 包住**（`begin` 不建作用域，变量名跨 cell 重复 → Pluto「有多个定义」）；动画 cell 例外，独占全局 `tr`+`frames`（lessons §8）
- [ ] 跑 `julia --project=. scripts/notebook_selftest.jl` → 必须 `NOTEBOOK SELF-TEST PASS`

## B. 改动物理层（`src/transmon.jl` 等，入口 `src/OverQubit.jl`）

- [ ] 物理层文件只依赖 LinearAlgebra、不 import 渲染符号；渲染一律放 `src/viz/OverQubitViz.jl`（architecture §9/§17 分层铁律）
- [ ] 单位口径：频率 GHz 入口 ×2π；衰减率 ns⁻¹ 不 ×2π（lessons 4）
- [ ] 新函数写 docstring + 在入口 `src/OverQubit.jl` 加 `export`；约定写进注释防误用
- [ ] 跑测试套件（**都要带 `--project=.`**，见 lessons 5.1b；validate 脚本已迁入 test/，见 architecture §17.2）：
  ```powershell
  julia --project=. -e 'using Pkg; Pkg.test()'    # 全部 101 项物理回归（约 4 分钟）
  julia --project=. test/test_cz.jl               # 或单跑一组（test_transmon/readout/dynamics/two_qubit/cz）
  julia --project=. scripts/notebook_selftest.jl  # 全部 notebook 逐 cell 求值 + 排版回归
  ```

## C. 改渲染层（`src/viz/OverQubitViz.jl`）

- [ ] 组件返回**单个 HTMLStr**；多块用 `oq_stack`
- [ ] 所有样式内联（不依赖 Pluto 全局 CSS）
- [ ] 新布局参数加到 `layout_base` 关键字里，别在 notebook 里补丁 `attr()`
- [ ] 新组件写 docstring，尤其"为什么必须这样"（给后来的人/后来的 AI 看）
- [ ] 如果新组件是"为了绕某个坑"，在 `ai/lessons.md` 补条目

## D. 提交前（全部改动）

- [ ] `Pkg.test()` 与 `scripts/notebook_selftest.jl` 全 PASS（`--project=.`，见 lessons 5.1b）
- [ ] `julia --project=. spike/check_frames.jl` → `FRAME-TRACES CHECK PASS`（动过动画时）
- [ ] `$env:NB = "<name>"`; `julia --project=. spike/preview_any.jl` 出静态页，肉眼过一遍
- [ ] `git status` 确认没有把 `spike/*.html`、临时脚本带进提交
- [ ] 有新的"坑"→ 更新 `ai/lessons.md`；有结构性改动 → 更新 `docs/architecture.md`

## E. 排障速查

| 现象 | 先查 |
| --- | --- |
| 图只剩半宽 / 图例竖排 / 标题溢出 / "1:" "2:" | lessons 2.1（cell 返回了 Tuple） |
| 播放时曲线消失 | lessons 3.4（帧没写 `traces`） |
| cell 求值 `UndefVarError(:<uuid>)` | lessons 1.1 |
| `ParseError` 但 `Meta.parseall` 说 OK | lessons 1.6（用 `include_string` 的脚本复验） |
| 图完全不显示 | `setup_page()` 没调用（Pluto 前端不预装 plotly.js） |
| 数对不上（差 2π / 差一半） | lessons 4 单位口径 |
| 条件相位漂移 / 看着随机 | lessons 4.1（13 GHz 动态相位取 angle 差必混叠，要用 Urel） |
| P₁ / 过程保真度莫名很低 | lessons 4.2（缺虚拟 Z 校正，`cz_zcorrect`） |
| 拉长总时长后门的读数变了 | lessons 4.3（idle ZZ 继续攒相位，窗口要固定） |
| `julia -e` 命令诡异报错 | lessons 5.1（改写脚本文件） |
