---
name: project-constraints
description: 当用户要为新建项目建立工程约束（AGENTS、环境判定、决策台账、STATUS），或把既有项目的规矩接入半路项目、需要处理与现有规定的冲突时使用。
---

# project-constraints

## 概述

给项目落一套可交接的运行约束：根 AGENTS/ENVIRONMENTS/STATUS/README，加 docs 的 spec/decisions/evidence/ops 四层。新建与半路接入共用同一套模板。

## 模式判断

看根目录：有 AGENTS.md 或 CLAUDE.md、git 有历史、有源码 → 倾向 adopt；空目录 → 倾向 new。检测只做提示，必须问用户一句再继续。

## new 五步

1. 预检：已有 AGENTS.md 就停；目录非空先列出并确认。
2. 一次问完：项目名、一句话目标、技术栈、环境、验证在哪跑。
3. 预览：`bash scripts/init.sh --target . --name … --one-liner … --stack …`
4. 写入：加 `--apply`；补写 README 文档地图、AGENTS §1/§4、docs/spec/00-overview.md。
5. 验收：`bash scripts/check.sh .` 全过，贴文件清单与输出。

## adopt 六步

1. 问扫描级别：quick / standard（推荐）/ full。
2. 出报告：`bash scripts/adopt.sh --target . --scan standard --report notes/adopt-report.md`
3. 读扫描到的文件，填"冲突裁决"表：冲突点、现有原文、模板要求、选项、建议。
4. 逐条问用户选 A 保留 / B 合并 / C 旁路 / D 替换；确认是否写决策记录。
5. `--apply` 只补缺失；B/C/D 由你按选择手工做，先备份为 `.bak`。
6. 写 D-001 或下一个编号；`bash scripts/check.sh`；报告 created/skipped、已裁决冲突、阻塞项。

## 常见错误

| 错误 | 后果 | 正确做法 |
| --- | --- | --- |
| 半路项目直接改已有 AGENTS/README | 覆盖别人的规矩 | 默认只补缺失；B/C/D 先问再备份 |
| 冲突自己裁决 | 用户不知情 | 每行给选项与建议 |
| 环境判不出还继续 | 在错误环境执行 | ENV=unknown 立即停问 |
| 生成后不补写三处 | 地图与概述空着 | README/AGENTS/overview 必补 |
| 跳过 check 就报完成 | 占位符、断链漏过 | 跑 check.sh 并贴输出 |

## 自检

- 15 个文件齐全，无 `{{ }}` 残留。
- 环境声明能在首行写出。
- 冲突表每行有选项与建议。
- adopt 前后已有文件字节未变。
- `bash scripts/check.sh <目标>` 退出码 0。

## 参考

- `references/conventions.md`：原则与误区。
- `references/example-mapping.md`：与 trader-plan2 的对应关系。
