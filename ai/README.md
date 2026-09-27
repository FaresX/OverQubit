# ai/ — AI 协作过程与教训库

这个文件夹记录 AI 在这个仓库里的**操作过程、踩坑、决策与验证方法**。
`docs/architecture.md` 讲"系统是怎么设计的"，这里讲"**下次别再踩**"。

## 索引

| 文件 | 内容 | 什么时候读 |
| --- | --- | --- |
| [`lessons.md`](lessons.md) | 踩坑与教训（症状 → 根因 → 对策 → 防回归） | **遇到任何怪毛病先查这里** |
| [`checklists.md`](checklists.md) | 操作前/改动前/提交前检查清单 + 验证命令 | 动手前 5 分钟过一遍 |
| [`session-log.md`](session-log.md) | 历次会话的操作记录、决策与结果 | 交接、回溯"为什么这么写" |
| [`known-issues.md`](known-issues.md) | 未解决问题（现状 + 下一步线索） | **接手前先看这里** |
| `workflow.md` | 无头验证 Notebook 的方法（没有浏览器时怎么自查排版） | 改了任何 `@htl` / plotly 布局 |

## 四条最贵的教训（详版在 lessons.md）

1. **Pluto 里 cell 末尾写 `html1, html2` 会静默把两张图并排挤扁**——Pluto 的 MIME 选择把
   `pluto.tree+object` 排在 `text/html` 前面且对 `Tuple` 生效，tree viewer 默认 collapsed 是 flex-row。
   必须用 `oq_stack(...)` 包成单个 HTMLStr。见 [lessons §2](lessons.md)。
2. **plotly.js 帧不写 `traces=[i]` 会把背景曲线顶没**——`frameMerge` 缺省"从 0 开始"映射，
   单条 data 永远覆盖 `gd.data[0]`。必须用 `anim_frame(idx, name, trace)`。见 [lessons §3](lessons.md)。
3. **plotly.js 的横向图例在容器 < ~260px 时会折成竖排**，把绘图区挤成一条——半宽容器是重灾区。
   图必须拿满宽，标题要短（14px 下 ≤26 个中文字符）。见 [lessons §3.5](lessons.md)。
4. **公式必须走 MathJax**（`tex()` / `texblock()`，带 `class="tex"`、数学里不出现中文）——
   写成普通 HTML 文本 Pluto 根本不排版，公式字体就会很奇怪。见 [lessons §7](lessons.md)。

## 写新条目的约定

`lessons.md` 每条固定四段：**症状 / 根因（引源码或实测）/ 对策（可直接抄的代码）/ 防回归（哪条脚本会报错）**。
只写"真的浪费过时间"的东西；能从 `docs/architecture.md` 查到的设计约定不重复。
