# project-constraints 技能 · 设计

| 项 | 值 |
| 状态 | 待评审 |
| 版本 | v1.1（2026-11-25 加入 adopt 模式） |
| 日期 | 2026-11-25 |
| 范围 | 新建 DSH 个人技能 `project-constraints`：为新项目生成约束，或把同一套约束接入已有项目 |
| 依据 | trader-plan2 的 AGENTS / ENVIRONMENTS / STATUS / docs 分层实践（脱敏泛化） |

## 0 摘要

两种模式共用一套模板：

- **new**：空项目，一次生成 15 个文件。
- **adopt**：已有项目，先扫描出报告；默认只补缺失、不动已有文件；冲突给选项与建议，由用户裁决。

## 1 目标与非目标

目标：

1. new 产出 15 个文件，结构与 trader-plan2 同构，不含其品牌、主机、凭据、业务术语。
2. adopt 只增不改：已有文件字节不变，缺失文件补齐，冲突有记录。
3. 生成即满足：规则只写一处、环境先声明、决策留痕、状态可交接。
4. 可验证：脚本检查 + 冷启动测试，不靠"看起来完成"。

非目标：

- 不自动裁决冲突，不删除用户原文。
- 不做项目业务设计。
- 不生成子目录 AGENTS.md、CI 配置、文档站点、hook、空 spec 文件。
- 不自动 `git init`、不自动提交、不写任何凭据。
- 不迁移或重写已有文档。

## 2 生成物（两种模式共用）

~~~text
<项目>/
├── AGENTS.md              # 常驻约束，DSH 自动注入
├── ENVIRONMENTS.md        # 环境矩阵、判定顺序、每环境允许/禁止
├── STATUS.md              # 只写现在
├── README.md              # 先读表、阅读路径、文档地图
├── env                    # ENV= / ROLE= / ROOT=，权限 600，gitignored
├── env.example
├── .gitignore             # 幂等追加 /env、.DS_Store、*.log、/node_modules、/vendor
├── docs/
│   ├── spec/
│   │   ├── README.md      # 分层规则、编号、单一出处地图（空表）
│   │   └── 00-overview.md # 目标/范围/非目标/术语（Agent 补写）
│   ├── decisions/
│   │   ├── README.md      # D-xxx 规则与索引
│   │   └── D-001.md       # 真实决策"采用项目约束体系"，兼作格式示例
│   ├── evidence/
│   │   └── README.md      # 证据纪律与登记表
│   └── ops/
│       └── README.md      # 部署、构建、验证手册的落点
└── tools/
    ├── env.sh             # 读 env，打印三行；unknown 则 exit 1
    └── check-links.sh     # 相对链接检查，零依赖
~~~

共 15 个文件。adopt 下已存在的路径跳过，未创建的路径按模板补。

### 2.1 AGENTS.md 八节

| 节 | 内容 |
| --- | --- |
| 1 身份与边界 | 这个仓是什么（`{{ONE_LINER}}`）；默认只改什么，扩范围（改契约/改他人模块/加依赖/改目录）先问；归档若存在则只读；凭据指向 ENVIRONMENTS §6 |
| 2 环境与声明 | 判定顺序指向 ENVIRONMENTS；会话第一条回复写 `ENV=… · ROLE=… · ROOT=… · 依据=…`，环境变化时更新；unknown 停止询问 |
| 3 开工顺序 | AGENTS → STATUS → `bash tools/env.sh` → README → 本任务相关 spec；只读需要的 spec |
| 4 硬红线 | 每环境允许/禁止指向 ENVIRONMENTS §5；凭据只引用 §6，不复制 |
| 5 文档规则 | 单一出处；spec 不引用 evidence；口径变更先立 D-xxx；冲突 C-xxx；文件名 ASCII、标题中文；spec 单篇目标 300–600、上限 600，细节见 spec README；证据带日期与状态；旧结论不静默改写 |
| 6 验证与证据 | 行为变更先写失败测试，纯文档/配置说明替代检查；证据至少命令+输出，必要时截图或 hash；缺失视为未完成 |
| 7 提交与收尾 | 一次一件事，不批量重排/改缩进/重命名；前缀带 scope；说明含改了什么、影响、验证、遗留，文档带文件与锚点；状态变化更新 STATUS；有远端副本时约定提交权威/镜像/禁 force 并做收尾检查；口头约定落文件 |
| 8 子目录规则 | 不设子目录 AGENTS.md；局部规则写进本节或在 docs 定义后引用 |

### 2.2 环境文件

`env` 三行，权限 600，进 `.gitignore`：

~~~text
ENV=local
ROLE=authoring
ROOT=/abs/path/to/project
~~~

取值：`ENV` ∈ local / testing / staging / prod；`ROLE` ∈ authoring / app / ci。`tools/env.sh` 从 cwd 向上找 `env`，找不到或值非法时输出 `ENV=unknown` 并以 1 退出。

adopt 下 `env` 缺失时：给了 `--env` / `--role` 就用，没给写 `ENV=unknown`、`ROLE=authoring`，并在报告"阻塞项"里列出。

## 3 技能包结构

~~~text
project-constraints/
├── SKILL.md
├── templates/             # 14 个模板；env 由脚本直接生成
│   ├── AGENTS.md.tmpl  ENVIRONMENTS.md.tmpl  STATUS.md.tmpl  README.md.tmpl
│   ├── env.example  gitignore.append
│   ├── docs/spec/README.md.tmpl  docs/spec/00-overview.md.tmpl
│   ├── docs/decisions/README.md.tmpl  docs/decisions/D-001.md.tmpl
│   ├── docs/evidence/README.md.tmpl  docs/ops/README.md.tmpl
│   └── tools/env.sh.tmpl  tools/check-links.sh.tmpl
├── scripts/
│   ├── lib.sh             # 渲染、创建、追加、权限、报告，供两个模式共用
│   ├── init.sh            # new
│   ├── adopt.sh           # adopt：扫描 + 报告 + 只补缺失
│   └── check.sh
├── references/
│   └── conventions.md
└── tests/
    ├── run.sh
    ├── test-templates.sh  test-tools.sh  test-init.sh
    ├── test-check.sh      test-adopt.sh  test-skill-md.sh
~~~

SKILL.md 约束：

- frontmatter 只有 `name: project-constraints` 与 `description`，description 只写触发条件：
  `当用户要为新建项目建立工程约束（AGENTS、环境判定、决策台账、STATUS），或把既有项目的规矩接入半路项目、需要处理与现有规定的冲突时使用。`
- 正文 < 500 词（≤ 1500 字符），含：概述、模式判断、new 五步、adopt 六步、五个问题、常见错误、自检、references 链接。
- 不复制模板正文，重内容放 `references/`。

## 4 模板变量

| 变量 | 来源 | 示例 |
| --- | --- | --- |
| `{{PROJECT_NAME}}` | new：第 2 步；adopt：`--name` 或目录名 | 订单服务 |
| `{{ONE_LINER}}` | new：第 2 步；adopt：`--one-liner` | 把下单、对账、告警收在一处的内部服务 |
| `{{STACK}}` | new：第 2 步；adopt：`--stack` | TypeScript / Node 22 / Postgres |
| `{{DATE}}` | 生成日期 | 2026-11-25 |

只有这 4 个变量由脚本替换；模板中不得出现其他 `{{…}}`。其余项目专属内容由 Agent 补写。

## 5 触发与流程

### 5.1 模式判断

检测只做提示，不自动决定：根目录有 `AGENTS.md` / `CLAUDE.md`、git 有历史、有源码目录 → 倾向 adopt；空目录或只有模板文件 → 倾向 new。最终问用户一句。

### 5.2 new（五步）

预检：已有任一目标文件（含悬空符号链接）→ 停止并列出；目录非空但无目标文件 → 列出并确认；不自动 `git init`。

1. 问 5 个问题（一次问完）：项目名、一句话目标、技术栈、环境（仅 local / +远程机 / +staging / +prod）、验证在哪跑。
2. dry-run：`bash scripts/init.sh --target . --name … --one-liner … --stack … --env … --role …`（默认 local/authoring），列出将创建的文件。
3. `--apply`：写文件、`chmod 600 env`、`chmod +x tools/*.sh`、幂等追加 `.gitignore`、目标路径已存在则整批拒绝。
4. 补写：AGENTS §1 与 §4；`docs/spec/00-overview.md`；按答案填 ENVIRONMENTS 矩阵与 §7/§8。
5. 自检：`bash scripts/check.sh .` 全过；`bash tools/env.sh` 行为正确；贴文件清单与检查输出。

### 5.3 adopt（六步）

1. 问扫描级别（三档，推荐 standard）。
2. `mkdir -p notes` 后 `bash scripts/adopt.sh --target . --scan standard --report notes/adopt-report.md`：只出报告，不写生成物。
3. Agent 读扫描到的文件，把"冲突裁决"表填满：冲突点 / 现有原文（文件:行）/ 模板要求 / 选项 / 建议。
4. 逐条问用户：A/B/C/D 选哪个；是否写决策记录；是否在现有 AGENTS.md 末尾追加引用段；确认 ENV/ROLE。
5. `--apply` 只创建缺失文件；`env` 缺失时必须给 `--env`/`--role`；B/C/D 由 Agent 按选择手工执行（先 `cp` 备份为 `*.bak`）。`.gitignore` 是唯一允许改的已有文件：只追加 `/env`。
6. 写或补决策记录（D-001 或下一个编号）；`check.sh`；报告创建数、跳过数、已裁决冲突数、阻塞项。

### 5.4 扫描三档

| 档 | 内容 |
| --- | --- |
| quick | `AGENTS.md`、`CLAUDE.md`、`README.md`、`CONTRIBUTING.md`、`docs/` 目标路径 |
| **standard（推荐）** | quick + `.cursorrules` / `.cursor/rules/*` / `.github/copilot-instructions.md` + `env` / `.env.example` / `.env`（只读键名）+ CI 工作流 + `package.json` scripts / `Makefile` 目标 |
| full | standard + `.editorconfig`、lint/format 配置、锁文件（只登记，不判冲突） |

推荐 standard：冲突多来自"另一套 AI 规则文件"和"验证在哪跑"；lint 配置多为机械约束，扫了只增噪声。

### 5.5 冲突处置

六类：环境声明方式、验证位置、提交/推送规则、文档事实来源、凭据处理、已有 AGENTS 与八节的重复或互斥。

每行给四个选项：

- **A 保留现有**（默认）：不动原文，只在报告里记录；
- **B 合并**：在现有文件末尾追加一段"新增约束"引用（5–10 行），先备份 `*.bak`；
- **C 旁路**：生成 `<file>.new.md`，由用户手工合并；
- **D 替换**：备份后以模板替换，仅在用户明确选择时执行。

建议规则：默认 A；若现有做法触碰安全或证据红线（凭据入仓、只靠口头约定、无决策记录且规范与代码脱节），建议 B 或 D 并写明理由。状态记 `待裁决` / `已裁决（日期）`。

### 5.6 护栏

- adopt 默认只报告；`--apply` 永不修改已有文件。
- 任何 B/C/D 动作先 `cp` 备份，再执行，再跑 `check.sh`。
- 单个文件失败即停，列出已创建与未创建。
- 不删除、不移动用户文件。

## 6 脚本契约

### 6.1 lib.sh

提供 `esc`（转义 sed 元字符）、`render_file`（4 变量替换）、`ensure_dir`、`chmod_600`、`chmod_exec`、`append_gitignore`（逐行 grep 后追加）、`echo_item`。两个模式都 source 它。

### 6.2 init.sh

- 用法 `bash scripts/init.sh --target DIR --name S --one-liner S --stack S [--date YYYY-MM-DD] [--env E] [--role R] [--apply]`；默认 dry-run；`--env`/`--role` 默认 local/authoring，非法值 exit 2。
- 退出码：0 成功；1 预检失败（`AGENTS.md` 已存在、目标不可写、参数缺失）；2 用法错误。
- target 不存在时在 `--apply` 前 `mkdir -p`。
- `--apply` 前检查 14 个目标路径（`.gitignore` 除外）是否已存在，任一存在则列出并 exit 1，不写任何文件。
- 生成 `env`（`ENV=local` / `ROLE=authoring` / `ROOT=<绝对路径>`，先 `cd` 再 `pwd`），权限 600。

### 6.3 adopt.sh

- 用法 `bash scripts/adopt.sh --target DIR [--scan quick|standard|full] [--report FILE] [--apply] [--name S] [--one-liner S] [--stack S] [--env E] [--role R]`。
- 默认 `--scan standard`、只读；`--report` 写新文件，父目录不存在则创建，文件已存在则拒绝。
- 退出码：0 报告生成或应用成功；1 目标不存在/不可写；2 用法错误（含非法 scan 值）。
- 报告固定小节：`## 已有（跳过）`、`## 将创建（缺失）`、`## 结构发现`、`## 冲突裁决`、`## 阻塞项`、`## 下一步`。
- `--apply`：只创建缺失文件，打印 `created=` / `skipped=` 计数；已有文件不读不写。
- `--apply` 且 `AGENTS.md` 缺失时 `--name` / `--one-liner` / `--stack` 必填；只出报告时用默认值（目录名 / 待补写）。
- `--apply` 且 `env` 缺失时 `--env` / `--role` 必填且取值合法；已有 `.gitignore` 只追加 `/env`（换行安全，不跟随符号链接），其余已有文件不读不写。

### 6.4 check.sh

- 用法 `bash scripts/check.sh DIR`。
- 检查：15 个文件齐全；15 个生成文件中无 `{{…}}` 残留（不扫用户文件）；STATUS 四节齐全；ENVIRONMENTS §7/§8 每条 bullet 都有值；`docs/decisions/` 至少一个 `D-*.md` 且都在索引表；`env` 三键合法、权限 600、`.gitignore` 含 `/env`；调用 `$DIR/tools/check-links.sh "$DIR"`。
- 逐项 ok/FAIL 与计数，任一失败 exit 1。

## 7 验证

| 编号 | 检查 | 通过标准 |
| --- | --- | --- |
| V1 | RED 基线（两场） | 无技能的 fresh subagent 分别做"新项目"与"半路项目"，各记录 ≥3 个缺失项 |
| V2 | GREEN new | `init.sh --apply` 成功；`check.sh` 0 错；15 个文件 |
| V3 | new 冷启动 | 新 subagent 只读 AGENTS + STATUS + README，正确声明环境并回答一个范围问题 |
| V4 | 幂等 | 第二次 `init.sh` 退出码非 0 |
| V5 | 占位符 | 人为留 `{{NAME}}`，`check.sh` 报错 exit 1 |
| V6 | 环境判定 | 无 `env` 时 `tools/env.sh` 输出 unknown + exit 1；有 `env` 时三行 + exit 0 |
| V7 | adopt 只读 | 已有 `AGENTS.md` 的样本上跑报告，文件 hash 不变、无新文件 |
| V8 | adopt 补缺 | `--apply` 后已有文件 hash 不变，缺失文件补齐，`created` 计数正确 |
| V9 | 冲突表 | 报告"冲突裁决"每行都有选项与建议，既有 AGENTS 至少一行 |
| V10 | adopt 冷启动 | 新 subagent 读"已有 AGENTS + 新 STATUS + 新 README"，正确声明环境并说清下一步 |
| V11 | 安装 | `~/.dsh/skills/project-constraints/` 结构与 frontmatter 正确，新会话可见 |

测试在会话工作区内的临时项目进行，通过项目级 `.dsh/skills/` 挂载，不先动全局安装。

## 8 安装与维护

- 开发在 `/home/lwj/deepseek-harness/new-skill/`，通过后复制到 `~/.dsh/skills/project-constraints/`（沙箱外，需授权）。
- 技能包不设版本号，用 git 历史；更新模板或脚本后在临时项目重跑 V2–V10 再安装。
- 项目级 `.dsh/skills/` 高于用户级，同名会遮蔽；更新后需新会话生效。

## 9 明确不做

- 子目录 AGENTS.md、空 spec 占位、CI 配置、文档站、hook。
- 自动 git init、自动提交、自动推送。
- 写凭据、复制 trader-plan2 的主机/IP/业务术语。
- 自动删除或重写已有文档与规则。
