# GREEN 验收记录（2026-11-25）

## 环境

- 分支：`feat/project-constraints`
- 套件：`bash project-constraints/tests/run.sh` → 6 个测试文件全过（templates / tools / init / check / adopt / skill-md）。
- new e2e：`.scratch/e2e-new`，15 个文件，`check: OK`，`tools/env.sh` 输出 ENV=local / ROLE=authoring / 绝对 ROOT。
- adopt e2e：`.scratch/e2e-adopt`，17 个文件（15 目标 + .cursorrules + src/app.ts），`check: OK`，`created=13 skipped=2`。
- 已有文件未改：AGENTS.md / README.md / .cursorrules 的 sha256 与接入前一致（29962d…、d5e9049…、1a2c5b3…）。

## adopt 冲突裁决（notes/adopt-report.md）

| # | 冲突点 | 现有原文 | 建议 |
| --- | --- | --- | --- |
| 1 | 推送规则 | AGENTS.md:3「直接 push main，不做评审」 | 建议 B：追加"推送前跑 check"，不删原文 |
| 2 | 验证位置 | AGENTS.md:4「测试只在本地跑」 | 建议 A：暂无远端，保留本地；接入远端时再立 D-002 |

两行都有 A/B/C/D 选项、现有原文与建议，状态为待裁决；未自动裁决。

## RED → GREEN 对照

| RED 缺失项 | GREEN 落点 |
| --- | --- |
| 没有环境判定 | ENVIRONMENTS.md + `env` + `tools/env.sh` + AGENTS §2 |
| 状态文件位置与结构不定 | 根 STATUS.md，六段固定 |
| 没有单一出处与规范/证据分层 | docs/spec/README.md + docs/evidence/README.md + AGENTS §5 |
| 没有决策编号与冲突台账 | docs/decisions/D-001.md + AGENTS §5 |
| 没有验证位置分层 | ENVIRONMENTS §7 + AGENTS §6 |
| 没有检查脚本 | `tools/check-links.sh` + `scripts/check.sh` |
| 没有证据纪律 | AGENTS §6（四件套） |
| adopt 无原文时自行写基线、改已有文件 | 默认只补缺失；报告先出；B/C/D 先问再备份 |
| adopt 冲突无编号 | 报告"冲突裁决"表 + D-001 |
| adopt 无检查 | `scripts/check.sh` |

## 冷启动

### new（cold-new2）

- 正确说出项目定位、当前阶段（项目初始化）、下一步两条；指出 §7 验证位置待填——与 STATUS 下一步第 2 条一致，说明状态文件在自洽地指路。
- 环境声明：`ENV=local · ROLE=authoring · 依据=none`（按 prompt 只读三份文件，未运行 env.sh；这个"依据=none"是如实标注）。

### adopt（cold-adopt）

- 正确说出定位、阶段、下一步、验证在本地跑、以及"直接 push main / 测试只在本地跑"两条原有规则被保留。
- 环境声明：`ENV=local，ROLE=authoring`，依据 STATUS 环境快照。

## 过程中发现并修复的缺陷

1. **STATUS 下一步与 README 冲突**：模板要求"在 README 登记文档地图"，但 README 模板已含地图；cold-new 指出后改为"填写 ENVIRONMENTS §7 验证位置与 §8 本项目事实"，并同步 SKILL.md 第 4 步与 spec。
2. **adopt 只读报告被强制要参数**：`--name/--one-liner/--stack` 原在缺 AGENTS.md 时无条件必填，导致纯报告要参数；改为仅 `--apply` 时必填（spec §6.3 同步）。
3. **测试假通过**：init/check 的否定断言原本只看退出码，脚本缺失也会通过；改为同时匹配输出里的"已存在"/"FAIL"。

## 复盘修复后复跑（2026-11-25 晚）

- 套件：test-adopt 16 / test-check 10 / test-init 10 / test-skill-md 17 / test-templates 33 / test-tools 5，全过。
- new e2e：`check: OK`；`tools/env.sh` 输出 ENV=local / ROLE=authoring / 绝对 ROOT。
- adopt e2e：17 个文件，created=13 skipped=2；AGENTS/README/.cursorrules 的 sha256 与接入前一致；`check: OK`；env=local。
- 本轮修复（对照评审）：
  1. SKILL 命令改为 `<技能目录>/scripts/...`，报告父目录自动创建。
  2. adopt 缺 env 时强制 `--env/--role` 并校验取值；已有 `.gitignore` 只追加 `/env`，且补换行。
  3. `-e` 改为 `-e 或 -L`，悬空符号链接不再能把写入引到目标外。
  4. 移除包内的 trader-plan2 映射（移到 `notes/`），测试全包扫描禁用标识。
  5. check 校验 ENV/ROLE/ROOT、600、`/env`；占位符只扫 15 个生成文件。
  6. C-xxx 落到 `docs/decisions/README.md` 的冲突表；D-001 来源改指仓库内文件。
  7. 测试临时目录移到仓库 `.scratch/`，安装包内不再残留。
