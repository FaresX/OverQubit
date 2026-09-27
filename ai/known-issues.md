# 未解决问题 / 已知问题

> 记录"现在还不对、但暂时没修"的东西，附**当前状态**与**下一步线索**，避免下次忘记。
> 已修的不放这里（去 `ai/session-log.md` 或 `ai/lessons.md`）。

## 1. CZ 相关内容已收尾（2026-09-27 第 5 轮关闭）

第 4 轮记录的两个 `scripts/validate_cz.jl` 问题已修，现 28/28 PASS：

- ~~`FAIL g_c = 0 时无泄漏`~~ → 阈值放到 `< 1e-9`（分段传播累计误差 ~1.7e-11，物理上本来就是 0）。
- ~~`ERROR DimensionMismatch 9 vs 6`~~ → 谱学交叉检查里多写的 `sqrt.` 已去掉（`TQ.H` 是 rad/ns，
  `/2π` 即 GHz，不能再开根号）。

`notebooks/cz_gate.jl`（⑧ 原理）与 `notebooks/cz_calibration.jl`（⑨ 校准）已并入正式演示，
演示总表 §5 第 6 行与里程碑 M3 状态已更新。第 4 轮的「CZ 教学内容化」backlog 项随之关闭。

## 2. `spike/check_frames.jl` 的 exit code 为 1（检查本身 PASS）

- 现状：脚本末尾 `allok` 在顶层 `for` 循环里赋值，触发 Julia 1.12 软作用域告警，被当成新局部变量，
  进程以 exit code 1 结束；但 `FRAME-TRACES CHECK PASS` 正常输出，判断依据是这行输出而非退出码。
- 线索：把循环里的 `allok = ...` 改成 `global allok`，或把收尾逻辑包进函数。

## 3. 全部变更尚未 commit

见 `ai/session-log.md`「当前仓库状态」。建议先决定：
- `spike/preview_*.html`、一次性调试脚本要进 `.gitignore` 还是随提交；
- `notebooks/s21_readout backup 1.jl`（用户备份）是否归档/删除；
- `cz_gate.jl` / `cz_calibration.jl` / `validate_cz.jl` 是否并入正式提交。

## 4. backlog（未开始）

Purcell 效应、测量反作用（见 `docs/architecture.md` §12 显式排除项）；
CZ 教学的可选延伸：可调耦合器路线、CR 驱动门、leakage RB——框架上仍是本页
「旋钮 + 等值线 + 误差预算」那一套。
