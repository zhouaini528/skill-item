# project-constraints

把项目开工要用的工程约束——运行规则、环境判定、决策台账、状态文件——做成一个可复用技能，给新项目或半路项目一次性铺好。

零依赖：只用 bash 与 coreutils。

## 它解决什么

新会话接手项目时常见三类问题：不知道在哪个环境、规则散落在 README 与会话里、结论没有留痕。技能把这三点落成可检查的文件：

- 根 `AGENTS.md`：执行约束（开工顺序、红线、提交粒度）
- `ENVIRONMENTS.md` + `env` + `tools/env.sh`：环境判定，判不出来就停
- `STATUS.md`：只写现在
- `docs/spec` / `decisions` / `evidence` / `ops`：规范、决策、证据、运维分层
- `tools/check-links.sh` + `scripts/check.sh`：把"完成"变成可验证

## 两种模式

| 模式 | 适用 | 行为 |
| --- | --- | --- |
| new | 空项目 | 一次生成 15 个文件 |
| adopt | 已有项目 | 先扫描出报告，默认只补缺失、不动已有文件；冲突给 A/B/C/D 选项与建议，由用户裁决 |

## 生成什么

~~~text
AGENTS.md  ENVIRONMENTS.md  STATUS.md  README.md  env  env.example  .gitignore
docs/spec/  docs/decisions/  docs/evidence/  docs/ops/
tools/env.sh  tools/check-links.sh
~~~

每个文件的职责、规则边界与验收标准见设计文档，不在这里重复。

## 安装

DSH 以 root 运行，`DSH_HOME=/root/.dsh`，所以**全局安装需要 sudo**；只想给单个项目用，走项目级即可。

### 全局（所有项目可用）

~~~bash
sudo mkdir -p /root/.dsh/skills
sudo cp -r /home/lwj/deepseek-harness/new-skill/project-constraints /root/.dsh/skills/
sudo chown -R root:root /root/.dsh/skills/project-constraints
~~~

### 项目级（不需要 sudo）

~~~bash
mkdir -p /path/to/project/.dsh/skills
cp -r /home/lwj/deepseek-harness/new-skill/project-constraints /path/to/project/.dsh/skills/
~~~

`.dsh/skills` 放在项目根——有 `.git` 的那一层；没有 git 时就是会话工作目录。同名时项目级覆盖全局。

### 验证

新开一个 DSH 会话（技能目录在会话启动时加载，当前会话不会自动出现），然后说：

- 新项目：**给这个项目立约束**
- 已有项目：**把这个项目的约束接进来**

也可以直接让 agent 读 `project-constraints/SKILL.md`。

## 怎么用

- **新项目**：技能问 5 个问题（项目名、一句话目标、技术栈、环境、验证在哪跑）→ dry-run → `--apply` → 补写 AGENTS 边界/概述/ENVIRONMENTS §7/§8 → `check.sh`。
- **半路项目**：先问扫描级别（quick / standard / full，推荐 standard）→ 出报告 → 填"冲突裁决"表 → 逐条选 A/B/C/D → `--apply`（缺 env 时给 `--env/--role`；没有 AGENTS.md 时补 `--name/--one-liner/--stack`）→ 补写 → `check.sh`。

## 包结构

~~~text
project-constraints/
├── SKILL.md            # 技能入口：模式判断 + 两套流程 + 自检
├── templates/          # 14 个模板（env 由脚本生成）
├── scripts/            # lib.sh / init.sh / adopt.sh / check.sh
├── references/         # conventions.md（原则与误区）
└── tests/              # 6 个测试文件，当前 108 条断言
~~~

## 开发与测试

~~~bash
cd /home/lwj/deepseek-harness/new-skill
bash project-constraints/tests/run.sh
~~~

测试在仓库 `.scratch/` 建临时项目，不写安装包；不要在安装目录跑测试。

## 更新与卸载

~~~bash
# 更新
sudo rm -rf /root/.dsh/skills/project-constraints
sudo cp -r /home/lwj/deepseek-harness/new-skill/project-constraints /root/.dsh/skills/
# 卸载
sudo rm -rf /root/.dsh/skills/project-constraints
~~~

项目级直接删对应目录。更新后新开会话生效。

## 参考

- 设计：[spec](docs/superpowers/specs/2026-11-25-project-constraints-skill-design.md)
- 计划：[plan](docs/superpowers/plans/2026-11-25-project-constraints-skill.md)
- 规则审核：[rules-audit](notes/rules-audit.md)
- 技能入口：[SKILL.md](project-constraints/SKILL.md)
