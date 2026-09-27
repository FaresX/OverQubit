# 无头验证 Notebook 排版的方法

> 场景：**不能在浏览器里看 Pluto**（浏览器工具够不到本地 file:// 或 127.0.0.1），
> 或者要写进 CI 的断言。目标：不靠截图也能发现"图被挤扁 / 图例竖排 / 曲线被顶替"。

## 1. 生成静态预览页（把 notebook 的输出拼成一个 HTML）

```powershell
julia spike/preview_any.jl              # 默认 flux_tuning
$env:NB = "two_qubit"; julia spike/preview_any.jl   # 指定 notebook
```

产物 `spike/preview_<name>.html`：每个 cell 的 HTML 输出依次排在 `.cell` 容器里，
plotly 走 CDN + 懒加载器（`window.__oqPlotly`）。⚠️ 它**跳过 @bind cell**，
所以滑块不出现——但所有图、卡片、推导、quiz 都在。

## 2. 断言一：布局是否健康（DOM 几何）

用浏览器工具打开后 `evaluate` 这段（或将来移植到 CI 的 headless Chrome）：

```js
(function(){
  var out = [];
  document.querySelectorAll('.js-plotly-plot').forEach(function(el){
    var dw = el.offsetWidth, worst = {w:0,s:null};
    var ts = el.getElementsByTagName('text');
    for (var i=0;i<ts.length;i++){
      var b = ts[i].getBoundingClientRect();
      if (b.width > worst.w) worst = {w: Math.round(b.width), s: ts[i].textContent.slice(0,20)};
    }
    var lg = el.querySelector('g.legend');
    var stacked = false;
    if (lg){ var ys = []; var its = lg.querySelectorAll('g.traces');
      for (var k=0;k<its.length;k++){ var t=its[k].querySelector('text'); if(t) ys.push(Math.round(t.getBoundingClientRect().y)); }
      stacked = ys.length>1 && !ys.every(function(y){return y===ys[0];}); }   // y 不同 ⇒ 竖排
    out.push({id: el.id, divW: dw, widest: worst, overflow: worst.w > dw,
              legendStacked: stacked, legendItems: lg ? lg.querySelectorAll('g.traces').length : 0});
  });
  return JSON.stringify(out);
})()
```

健康标准：
- 每个 plot 的 `divW` ≈ 所在列宽（**不能是半宽**；半宽基本等于踩了 lessons 2.1）
- `overflow == false`（标题没超出容器）
- `legendStacked == false`（横向图例没被折竖排）

> 本会话实测参照值：flux_tuning 三张图 divW 均 923px（≈满宽）、扇形图图例 323×29 单行、
> 标题 202–268px 不溢出。半宽容器下同一张图图例会竖排。

## 3. 断言二：动画帧索引是否指向专用 trace（Julia 侧，无需浏览器）

```powershell
julia spike/check_frames.jl       # → FRAME-TRACES CHECK PASS
```

原理：逐 cell 求值 notebook，抓模块里的 `frames` 与 `tr`/`traces`，
核对每帧 `traces[i]` 指向的 trace **必须是小 trace**（>20 点即判为背景曲线 → FAIL）。
注意两个实现细节（都踩过）：
- 抓 `frames` 时**不要 `collect`**，否则每次 objectid 都变，"是否本格新定义"永远判真；
- 只在"本格新定义了 frames"时配对 trace 列表，否则后面的格子把 `tr` 换成别的图会配错。

## 4. 断言三：cell 返回值不是"一串 HTML"

`notebook_selftest.jl` 的 `check_html_tuple` 已内置：cell 返回 Tuple/Vector 且元素全是
HTMLStr/Markdown.MD → 报错并提示改用 `oq_stack`。

## 5. 断言四：不许出现裸 `frame(`

`notebook_selftest.jl` 的 `check_no_raw_frames`：扫描 notebook 源码
（先剔除 `anim_frame(`，注释行与 docstring 行豁免），出现裸 `frame(` 直接报错。

## 6. 生成页本身的正确性核对

`spike/preview_any.jl` 是自研的，它本身也会错，所以顺手核对：
- [ ] 每个 plot div 都拿到了 `newPlot` 调用（搜 `js-plotly-plot` 数量 = `plotly_html` 调用次数）
- [ ] 帧 JSON 里有 `"traces":[n]`（搜 `"frames":[{"name":"1","traces":`）
- [ ] 中文没有变问号（文件按 UTF-8 写、`<meta charset="utf-8">` 在）

## 7. 什么时候还是得靠人眼

- 配色对比度、留白节奏、文案是否拗口 —— 这些没有断言，靠 `preview_any.jl` 出页 + 人看。
- 交互（hover、缩放、拖滑块后的联动）—— Pluto 里手动点。
