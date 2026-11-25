# adopt 报告 · e2e-adopt

- 生成时间：2026-11-25
- 扫描级别：standard
- 目标：/home/lwj/deepseek-harness/new-skill/.scratch/e2e-adopt
- git：否

## 已有（跳过）

| 路径 | 行数 | 建议 |
| --- | --- | --- |
| AGENTS.md | 4 | 保留；与模板八节逐条比对，冲突写进裁决表 |
| README.md | 3 | 保留；确认职责是否与模板重叠 |

## 将创建（缺失）

| 路径 |
| --- |
| ENVIRONMENTS.md |
| STATUS.md |
| env |
| env.example |
| .gitignore |
| docs/spec/README.md |
| docs/spec/00-overview.md |
| docs/decisions/README.md |
| docs/decisions/D-001.md |
| docs/evidence/README.md |
| docs/ops/README.md |
| tools/env.sh |
| tools/check-links.sh |

## 结构发现

| 类型 | 路径 | 说明 |
| --- | --- | --- |
| AI 规则 | .cursorrules | 另一套 AI 约束，逐条比对 |

## 冲突裁决

由 Agent 读取上方文件后逐行填写；每行必须有现有原文、选项与建议。

| # | 冲突点 | 现有原文 | 模板要求 | 选项 | 建议 | 状态 |
| --- | --- | --- | --- | --- | --- | --- |
| 1 | 推送规则 | AGENTS.md:3「直接 push main，不做评审」 | AGENTS §7：一次一件事、验证后提交，推送按节奏 | A 保留 / B 合并 / C 旁路 / D 替换 | 建议 B：在现有 AGENTS 追加"推送前跑 check"，不删原文 | 待裁决 |
| 2 | 验证位置 | AGENTS.md:4「测试只在本地跑」 | AGENTS §6：按环境分层，重验证在远端；当前无远端 | A 保留 / B 合并 / C 旁路 / D 替换 | 建议 A：暂无远端，保留本地；接入远端时再立 D-002 | 待裁决 |

## 阻塞项

- env 未建立：暂用 ENV=unknown，需补写 ROLE/ROOT
- 没有 STATUS：新会话无法判断当前阶段

## 下一步

1. 逐条裁决冲突，选 A 保留 / B 合并 / C 旁路 / D 替换。
2. 选 B 时先备份，再在现有文件末尾追加引用段。
3. 补写 README 的一句话与技术栈（若显示"待补写"）。
4. 运行 bash scripts/check.sh <目标>。
