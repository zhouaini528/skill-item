---
name: project-constraints
description: 当用户要为新建项目建立工程约束（AGENTS、环境判定、决策台账、STATUS），或把既有项目的规矩接入半路项目、需要处理与现有规定的冲突时使用。
---

# project-constraints

## 概述

给项目落一套可交接的运行约束：根 AGENTS/ENVIRONMENTS/STATUS/README，加 docs 的 spec/decisions/evidence/ops 四层；新建与半路接入共用同一套模板。

## 模式判断

看根目录：有 AGENTS.md 或 CLAUDE.md、git 有历史、有源码 → 倾向 adopt；空目录 → 倾向 new。检测只做提示，必须问用户一句再继续。

## new 五步

1. 预检：已有任一目标文件就停；目录非空先列出并确认。
2. 一次问完：项目名、一句话目标、技术栈、环境、验证在哪跑。
3. 预览：`bash <技能目录>/scripts/init.sh --target . --name … --one-liner … --stack …`
4. 写入：加 `--apply`；补写 AGENTS §1/§4、docs/spec/00-overview.md、ENVIRONMENTS §7/§8 与矩阵。
5. 验收：`bash <技能目录>/scripts/check.sh .` 全过，贴清单与输出。

## adopt 六步

1. 问扫描级别：quick / standard（推荐）/ full。
2. `mkdir -p notes`，出报告：`bash <技能目录>/scripts/adopt.sh --target . --scan standard --report notes/adopt-report.md`；报告已存在先删或换名。
3. 填"冲突裁决"表（六类：环境声明、验证位置、提交/推送、文档事实来源、凭据、既有 AGENTS 重复/互斥）。
4. 逐条问 A 保留 / B 合并 / C 旁路 / D 替换；问是否在现有 AGENTS 末尾追加引用段。
5. `--apply`：没有 AGENTS.md 补 `--name/--one-liner/--stack`；env 缺失必须补 `--env/--role`；只补缺失，`.gitignore` 仅追加 `/env`。
6. 补写 README 一句话与栈、ENVIRONMENTS §7/§8；写 D-001 或下一个编号；`check.sh`。

## 常见错误

- 半路项目直接改已有 AGENTS：覆盖别人的规矩。默认只补缺失。
- 冲突自己裁决：用户不知情。给选项与建议。
- env 判不出来还继续：在错误环境执行。停下问 `--env/--role`。
- 生成后不补写：地图与概述空着。补三处。
- 跳过 check 就报完成：占位符、断链漏过。跑 check 并贴输出。

## 自检

- 15 文件齐全，无 `{{ }}` 残留。
- `env` 权限 600、`/env` 已忽略、三键合法。
- 冲突表每行有选项与建议。
- adopt 前后已有文件字节未变（`.gitignore` 追加 `/env` 除外）。
- `bash <技能目录>/scripts/check.sh <目标>` 退出码 0。

## 参考

- `references/conventions.md`
