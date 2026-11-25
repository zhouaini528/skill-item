# project-constraints 技能 实施计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 交付一个可安装的 DSH 技能 `project-constraints`，支持 new（空项目生成 15 个文件）与 adopt（已有项目只补缺失、冲突留痕）两种模式，并通过脚本检查与冷启动验收。

**Architecture:** 技能包 = SKILL.md（模式判断与两套流程）+ templates/（14 个模板）+ scripts/lib.sh（渲染/创建/追加）+ init.sh + adopt.sh（扫描、报告、只补缺失）+ check.sh + references/（理由与映射）。

**Tech Stack:** Bash 4+ / coreutils / grep / sed / Markdown；零第三方依赖；DSH 个人技能目录 `~/.dsh/skills/`。

**Spec:** `docs/superpowers/specs/2026-11-25-project-constraints-skill-design.md`

## Global Constraints

- 生成物 15 个文件；模板 14 个（`env` 由脚本生成）。
- 只允许 4 个变量：`{{PROJECT_NAME}}`、`{{ONE_LINER}}`、`{{STACK}}`、`{{DATE}}`。
- 环境文件名固定 `env`，三键 `ENV` / `ROLE` / `ROOT`，权限 600，写入 `.gitignore`。
- 不生成子目录 AGENTS.md、空 spec 文件、CI、文档站、hook。
- 文档中文，文件名 ASCII；技能名 `project-constraints`；SKILL.md 正文 ≤ 500 词（≤ 1500 字符）。
- 禁止出现 `QTV`、`trader-plan2`、`43.106.83.160`、`AutoTrader`、`.qtv-env`、任何密钥样例。
- 只依赖 bash 与 coreutils；不用 `jq`、`python`、`perl`。
- 路径可能含空格与中文：所有变量引用必须加双引号。
- **adopt 永不修改已有文件**；B/C/D 动作先 `cp` 备份为 `*.bak`。
- 冲突固定四选项 A 保留 / B 合并 / C 旁路 / D 替换，默认 A。

## Review Focus

1. adopt 在报告阶段写了文件 —— Task 7 的只读测试。
2. `adopt.sh --apply` 改动了已有文件 —— Task 7 的 sha256 对比。
3. 变量值含 `&`、`|`、`/` 时被 sed 破坏 —— Task 5 的转义测试。
4. 报告"冲突裁决"缺选项或建议 —— Task 9 的 e2e 检查。
5. 生成物互相引用断链 —— Task 6 与 Task 9 的链接检查。

---

### Task 1: 仓库初始化与 RED 基线（两场）

**Files:**
- Create: `.gitignore`
- Create: `notes/red-baseline.md`

**Interfaces:**
- Consumes: 本计划与 spec
- Produces: git 仓库；`notes/red-baseline.md` 含 `## 新项目` 与 `## 半路项目` 两段，各至少 3 条缺失项

- [ ] **Step 1: 初始化仓库**

Run: `git init -b main`

- [ ] **Step 2: 写 `.gitignore`**

三行：`.scratch/`、`*.log`、`.DS_Store`。

- [ ] **Step 3: 提交设计与计划**

~~~bash
git add -A
git commit -m "docs: project-constraints 设计与实施计划"
~~~

- [ ] **Step 4: RED 新项目**

空目录 `mkdir -p .scratch/red-new`，subagent cwd 为该目录，prompt 原文：

~~~text
这是一个新项目。请为它建立工程约束，让后续任何会话都能接手。完成后列出你创建的文件和理由。
只在这个目录内工作，不要读取上级目录。
~~~

- [ ] **Step 5: RED 半路项目**

造样本：`.scratch/red-adopt/` 下放 `AGENTS.md`（三行规则，其中一行"直接 push main"）、`README.md`、`src/hello.txt`。subagent cwd 为该目录，prompt 原文：

~~~text
这是一个已经在进行的项目，已有自己的规矩。请把统一的工程约束接进来，让新会话能接手。
有冲突请不要擅自决定，给我选项和建议。完成后说明你做了什么、发现了哪些冲突。
只在这个目录内工作，不要读取上级目录。
~~~

- [ ] **Step 6: 记录基线**

`notes/red-baseline.md`：两段，各记完整回复、创建的文件、缺失项（`- ` 起头并引原文）。

- [ ] **Step 7: 验证**

Run: `grep -c '^- ' notes/red-baseline.md`
Expected: ≥ 6

- [ ] **Step 8: 提交**

~~~bash
git add notes/red-baseline.md
git commit -m "docs(notes): 记录 new 与 adopt 的 RED 基线"
~~~

---

### Task 2: 测试脚手架与核心三件模板

**Files:**
- Create: `project-constraints/tests/run.sh`
- Create: `project-constraints/tests/test-templates.sh`
- Create: `project-constraints/templates/AGENTS.md.tmpl`
- Create: `project-constraints/templates/ENVIRONMENTS.md.tmpl`
- Create: `project-constraints/templates/STATUS.md.tmpl`

**Interfaces:**
- Consumes: 无
- Produces: 三个模板；AGENTS 的 8 个二级标题；变量 `{{PROJECT_NAME}}` / `{{ONE_LINER}}` / `{{STACK}}` / `{{DATE}}`

- [ ] **Step 1: 写测试运行器**

~~~bash
#!/usr/bin/env bash
set -uo pipefail
cd "$(dirname "$0")/.."
rc=0
for t in tests/test-*.sh; do
  printf '\n== %s\n' "$t"
  bash "$t" || rc=1
done
exit "$rc"
~~~

- [ ] **Step 2: 写模板契约测试（会失败）**

`project-constraints/tests/test-templates.sh`：

~~~bash
#!/usr/bin/env bash
set -uo pipefail
T="$(cd "$(dirname "$0")/.." && pwd)"
fail=0
ok()  { printf 'ok   %s\n' "$1"; }
bad() { printf 'FAIL %s\n' "$1"; fail=1; }
assert_file()    { [[ -f "$2" ]] && ok "$1" || bad "$1: missing $2"; }
assert_grep()    { grep -qE "$3" "$2" && ok "$1" || bad "$1: /$3/ not in $2"; }
assert_no_grep() { ! grep -qE "$3" "$2" && ok "$1" || bad "$1: /$3/ found in $2"; }

assert_file "AGENTS 模板" "$T/templates/AGENTS.md.tmpl"
assert_file "ENVIRONMENTS 模板" "$T/templates/ENVIRONMENTS.md.tmpl"
assert_file "STATUS 模板" "$T/templates/STATUS.md.tmpl"
for h in '## 1 身份与边界' '## 2 环境与声明' '## 3 开工顺序' '## 4 硬红线' \
         '## 5 文档规则' '## 6 验证与证据' '## 7 提交与收尾' '## 8 子目录规则'; do
  assert_grep "AGENTS 标题 $h" "$T/templates/AGENTS.md.tmpl" "^$h$"
done
assert_grep "环境声明格式" "$T/templates/AGENTS.md.tmpl" 'ENV=<local'
assert_grep "开工跑 env.sh" "$T/templates/AGENTS.md.tmpl" 'bash tools/env.sh'
assert_grep "STATUS 六节" "$T/templates/STATUS.md.tmpl" '^## 环境快照$'
assert_no_grep "无旧项目残留" "$T/templates/AGENTS.md.tmpl" 'QTV|trader-plan2|43\.106\.83\.160|AutoTrader|\.qtv-env'
got=$(grep -rhoE '\{\{[A-Z_]+\}\}' "$T/templates" | LC_ALL=C sort -u | tr '\n' ' ')
want='{{DATE}} {{ONE_LINER}} {{PROJECT_NAME}} {{STACK}} '
[[ "$got" == "$want" ]] && ok "变量集合" || bad "变量集合: $got"
exit "$fail"
~~~

- [ ] **Step 3: 跑测试确认失败**

Run: `bash project-constraints/tests/test-templates.sh`
Expected: FAIL，含 `missing`；退出码 1。

- [ ] **Step 4: 写 `AGENTS.md.tmpl`**

标题 `# AGENTS · {{PROJECT_NAME}}`；开头一句 `{{ONE_LINER}}`、`> 技术栈：{{STACK}}`；八节各 1–3 条：

1 身份与边界：本仓是什么；默认只改什么；业务代码变更需明确请求；归档只读；不写凭据。
2 环境与声明：判定顺序指向 ENVIRONMENTS；首行声明原文 `每条回复首行写：ENV=<local|testing|staging|prod> · ROLE=<authoring|app|ci> · ROOT=<绝对路径> · 依据=<env|none>`；`ENV=unknown` 停止询问。
3 开工顺序：AGENTS → STATUS → `bash tools/env.sh` → README → 本任务相关 spec。
4 硬红线：每环境允许/禁止指向 ENVIRONMENTS；凭据只在授权文件且只读。
5 文档规则：单一出处；spec 不引用 evidence；口径变更先立 D-xxx；冲突登记 C-xxx；文件名 ASCII、标题中文；spec 单篇上限 600 行；证据带日期与状态；旧结论不静默改写。
6 验证与证据：行为变更先写失败测试；证据四件套（命令/输出/截图或 hash）；缺失视为未完成。
7 提交与收尾：一次一件事；前缀 feat/fix/test/docs/chore 带 scope；说明含改了什么、影响、验证、遗留；状态变化更新 STATUS；口头约定必须落文件。
8 子目录规则：不设子目录 AGENTS.md；局部规则写进本节或在 docs 定义后引用。

- [ ] **Step 5: 写 `ENVIRONMENTS.md.tmpl`**

环境矩阵（local 行填好，其余"未部署"）；判定顺序（向上找 `env` → 读三键 → 非法或缺失即 unknown）；`env` 三行格式；取值映射表；红线表（四行，列 允许 / 禁止）；凭据规则（不进仓库、不进聊天、只读、路径由项目指定）。

- [ ] **Step 6: 写 `STATUS.md.tmpl`**

六节：更新时间（`{{DATE}}`）与对应 commit、当前阶段（项目初始化）、最近变更、下一步、待裁决/阻塞、环境快照。

- [ ] **Step 7: 跑测试确认通过**

Run: `bash project-constraints/tests/test-templates.sh`
Expected: 全 ok。

- [ ] **Step 8: 提交**

~~~bash
git add project-constraints/tests project-constraints/templates
git commit -m "test(templates): 核心三件模板与契约测试"
~~~

---

### Task 3: 其余模板

**Files:**
- Create: `project-constraints/templates/README.md.tmpl`
- Create: `project-constraints/templates/env.example`
- Create: `project-constraints/templates/gitignore.append`
- Create: `project-constraints/templates/docs/spec/README.md.tmpl`
- Create: `project-constraints/templates/docs/spec/00-overview.md.tmpl`
- Create: `project-constraints/templates/docs/decisions/README.md.tmpl`
- Create: `project-constraints/templates/docs/decisions/D-001.md.tmpl`
- Create: `project-constraints/templates/docs/evidence/README.md.tmpl`
- Create: `project-constraints/templates/docs/ops/README.md.tmpl`

**Interfaces:**
- Consumes: Task 2 的测试工具
- Produces: 9 个模板；D-001 五段；spec 单一出处规则

- [ ] **Step 1: 扩展 `test-templates.sh` 断言**

~~~bash
assert_file "README 模板" "$T/templates/README.md.tmpl"
assert_file "spec README" "$T/templates/docs/spec/README.md.tmpl"
assert_file "D-001" "$T/templates/docs/decisions/D-001.md.tmpl"
assert_file "env.example" "$T/templates/env.example"
assert_grep "README 先读" "$T/templates/README.md.tmpl" '^## 先读$'
assert_grep "spec 单一出处" "$T/templates/docs/spec/README.md.tmpl" '单一出处'
assert_grep "spec 上限" "$T/templates/docs/spec/README.md.tmpl" '600'
for h in '## 背景' '## 决策' '## 取舍' '## 影响' '## 来源'; do
  assert_grep "D-001 $h" "$T/templates/docs/decisions/D-001.md.tmpl" "^$h$"
done
assert_grep "证据纪律" "$T/templates/docs/evidence/README.md.tmpl" '非权威'
assert_grep "gitignore 忽略 env" "$T/templates/gitignore.append" '^/env$'
assert_grep "env.example 三键" "$T/templates/env.example" '^ENV='
~~~

- [ ] **Step 2: 跑测试确认失败**

Run: `bash project-constraints/tests/test-templates.sh`
Expected: 新增断言 FAIL。

- [ ] **Step 3: 写 README、env.example、gitignore.append**

README：先读表、三条阅读路径、文档地图、开工顺序。`env.example` 三键带注释。`gitignore.append`：`/env`、`.DS_Store`、`*.log`、`/node_modules/`、`/vendor/`。

- [ ] **Step 4: 写 docs/spec 两个模板**

`README.md`：分层规则、编号（00/10/20…）、单篇上限 600 行、单一出处地图（空表）、spec 不引用 evidence。
`00-overview.md`：目标、非目标、范围、术语四节。

- [ ] **Step 5: 写 decisions 两个模板**

`README.md`：D-xxx 一事一文件、五段、只追加、索引表。
`D-001.md`：标题"采用项目约束体系"，五段写满，来源指向 `references/conventions.md`。正文对 new 与 adopt 都成立。

- [ ] **Step 6: 写 evidence 与 ops 模板**

evidence README：证据纪律、非权威、登记表、上限 600 行。
ops README：部署/构建/验证命令的单源落点。

- [ ] **Step 7: 跑测试确认通过**

Run: `bash project-constraints/tests/test-templates.sh`
Expected: 全 ok。

- [ ] **Step 8: 提交**

~~~bash
git add project-constraints/templates project-constraints/tests/test-templates.sh
git commit -m "test(templates): 补全文档模板与断言"
~~~

---

### Task 4: tools 模板

**Files:**
- Create: `project-constraints/templates/tools/env.sh.tmpl`
- Create: `project-constraints/templates/tools/check-links.sh.tmpl`
- Create: `project-constraints/tests/test-tools.sh`

**Interfaces:**
- Consumes: Task 3 的 gitignore 约定
- Produces: `tools/env.sh`（成功打印三行并 exit 0；否则 `ENV=unknown` 并 exit 1）；`tools/check-links.sh`（打印计数，断链 exit 1）

- [ ] **Step 1: 写 `test-tools.sh`（会失败）**

~~~bash
#!/usr/bin/env bash
set -uo pipefail
T="$(cd "$(dirname "$0")/.." && pwd)"
W="$T/.scratch/tools"; rm -rf "$W"; mkdir -p "$W/p1/tools" "$W/p1/sub"
cp "$T/templates/tools/env.sh.tmpl" "$W/p1/tools/env.sh"
cp "$T/templates/tools/check-links.sh.tmpl" "$W/p1/tools/check-links.sh"
chmod +x "$W/p1/tools/"*.sh
fail=0
ok()  { printf 'ok   %s\n' "$1"; }
bad() { printf 'FAIL %s\n' "$1"; fail=1; }

out=$(cd "$W/p1/sub" && bash ../tools/env.sh); rc=$?
[[ $rc -eq 1 && "$out" == *"ENV=unknown"* ]] && ok "未知环境" || bad "未知环境: rc=$rc"

printf 'ENV=testing\nROLE=app\nROOT=/srv/p1\n' > "$W/p1/env"
out=$(cd "$W/p1/sub" && bash ../tools/env.sh); rc=$?
[[ $rc -eq 0 && "$out" == *"ENV=testing"* ]] && ok "已知环境" || bad "已知环境: rc=$rc"

printf 'ENV=foo\nROLE=app\nROOT=/srv/p1\n' > "$W/p1/env"
out=$(cd "$W/p1/sub" && bash ../tools/env.sh); rc=$?
[[ $rc -eq 1 && "$out" == *"ENV=unknown"* ]] && ok "非法环境" || bad "非法环境: rc=$rc"

printf 'x\n' > "$W/p1/a.md"; printf '[b](b.md)\n' > "$W/p1/b.md"
(cd "$W/p1" && bash tools/check-links.sh . >/dev/null); rc=$?
[[ $rc -eq 0 ]] && ok "链接正常" || bad "链接正常: rc=$rc"
printf '[c](missing.md)\n' >> "$W/p1/a.md"
(cd "$W/p1" && bash tools/check-links.sh . >/dev/null); rc=$?
[[ $rc -eq 1 ]] && ok "断链" || bad "断链: rc=$rc"
exit "$fail"
~~~

- [ ] **Step 2: 跑测试确认失败**

Run: `bash project-constraints/tests/test-tools.sh`
Expected: FAIL。

- [ ] **Step 3: 写 `env.sh.tmpl`**

从 `$PWD` 向上逐级找 `env`；解析三键；`ENV` 只接受 local/testing/staging/prod，`ROLE` 只接受 authoring/app/ci；成功打印 `ENV=…`、`ROLE=…`、`ROOT=…`、`依据=env` 并 exit 0；否则 `ENV=unknown`、`依据=none` 并 exit 1。

- [ ] **Step 4: 写 `check-links.sh.tmpl`**

遍历 `*.md`（跳过 `.git`、`node_modules`、`vendor`）；取 `](target)` 中非 http(s)/mailto/纯锚点的目标；去 `#anchor` 后解析；打印 `files=N links=M broken=K`；`K>0` 则 exit 1。

- [ ] **Step 5: 跑测试确认通过**

Run: `bash project-constraints/tests/test-tools.sh`
Expected: 全 ok。

- [ ] **Step 6: 提交**

~~~bash
git add project-constraints/templates/tools project-constraints/tests/test-tools.sh
git commit -m "feat(tools): env 判定与链接检查模板"
~~~

---

### Task 5: lib.sh 与 init.sh

**Files:**
- Create: `project-constraints/scripts/lib.sh`
- Create: `project-constraints/scripts/init.sh`
- Create: `project-constraints/tests/test-init.sh`

**Interfaces:**
- Consumes: Task 2–4 的全部模板
- Produces: `lib.sh` 的 `esc` / `render_file` / `ensure_dir` / `chmod_600` / `chmod_exec` / `append_gitignore`；`init.sh --target DIR --name S --one-liner S --stack S [--date D] [--apply]`，0 成功 / 1 预检失败 / 2 用法错误

- [ ] **Step 1: 写 `test-init.sh`（会失败）**

~~~bash
#!/usr/bin/env bash
set -uo pipefail
T="$(cd "$(dirname "$0")/.." && pwd)"
D="$T/.scratch/init"; rm -rf "$D"; mkdir -p "$D"
fail=0
ok()  { printf 'ok   %s\n' "$1"; }
bad() { printf 'FAIL %s\n' "$1"; fail=1; }
bash "$T/scripts/init.sh" --target "$D/p" --name "示例项目" --one-liner "一句话" --stack "TS"
[[ -z "$(ls -A "$D/p" 2>/dev/null)" ]] && ok "dry-run 不落盘" || bad "dry-run 写了文件"
bash "$T/scripts/init.sh" --target "$D/p" --name "示例项目" --one-liner "一句话" --stack "TS" --apply
[[ "$(find "$D/p" -type f | wc -l)" -eq 15 ]] && ok "15 个文件" || bad "文件数"
! grep -rq '{{' "$D/p" && ok "无残留" || bad "有残留"
[[ "$(stat -c %a "$D/p/env")" == "600" ]] && ok "env 600" || bad "env 权限"
grep -q '^/env$' "$D/p/.gitignore" && ok "忽略 env" || bad "未忽略 env"
bash "$T/scripts/init.sh" --target "$D/p" --name x --one-liner y --stack z --apply; [[ $? -ne 0 ]] && ok "拒绝覆盖" || bad "未拒绝"
bash "$T/scripts/init.sh" --target "$D/带 空格/项目" --name n --one-liner o --stack 'A & B | C / D' --apply
[[ -f "$D/带 空格/项目/AGENTS.md" ]] && ok "空格中文路径" || bad "空格中文路径"
grep -qF 'A & B | C / D' "$D/带 空格/项目/AGENTS.md" && ok "特殊字符原样" || bad "特殊字符被破坏"
exit "$fail"
~~~

- [ ] **Step 2: 跑测试确认失败**

Run: `bash project-constraints/tests/test-init.sh`
Expected: FAIL，`scripts/init.sh` 不存在。

- [ ] **Step 3: 实现 `lib.sh`**

`esc() { printf '%s' "$1" | sed -e 's/[\\&|]/\\&/g'; }`；`render_file <tmpl> <dest>` 用 4 个变量替换；`ensure_dir`、`chmod_600`、`chmod_exec`、`append_gitignore <target> <file>`（逐行 `grep -qxF` 后追加）。

- [ ] **Step 4: 实现 `init.sh`**

`SKILL_DIR="$(cd "$(dirname "$0")/.." && pwd)"`；source lib；解析参数；校验三个必填；target 不存在时在 `--apply` 前 `mkdir -p`；`--apply` 前检查 14 个目标路径（`.gitignore` 除外）是否已存在，任一存在则列出并 exit 1；渲染 14 个模板；生成 `env`（`ENV=local` / `ROLE=authoring` / `ROOT=<先 cd 再 pwd>`）并 `chmod 600`；`tools/*.sh` 加执行位；追加 `.gitignore`；输出清单与下一步。

- [ ] **Step 5: 跑测试确认通过**

Run: `bash project-constraints/tests/test-init.sh`
Expected: 全 ok。

- [ ] **Step 6: 提交**

~~~bash
git add project-constraints/scripts/lib.sh project-constraints/scripts/init.sh project-constraints/tests/test-init.sh
git commit -m "feat(init): 共用渲染库与 new 模式"
~~~

---

### Task 6: check.sh

**Files:**
- Create: `project-constraints/scripts/check.sh`
- Create: `project-constraints/tests/test-check.sh`

**Interfaces:**
- Consumes: Task 5 的生成结构、Task 4 的 `tools/check-links.sh`
- Produces: `check.sh DIR`；逐项输出；任一失败 exit 1

- [ ] **Step 1: 写 `test-check.sh`（会失败）**

自己生成样本 `init.sh --apply` 到 `.scratch/check/p`，不依赖其他测试残留。断言：正常 exit 0；删掉 `docs/evidence/README.md` 后 exit 1；追加 `{{NAME}}` 后 exit 1；改坏链接后 exit 1；删掉 `docs/decisions/D-001.md` 后 exit 1。

- [ ] **Step 2: 跑测试确认失败**

Run: `bash project-constraints/tests/test-check.sh`
Expected: FAIL。

- [ ] **Step 3: 实现 `check.sh`**

检查 15 个文件齐全；`grep -rE '\{\{'` 无残留；`docs/decisions/` 至少一个 `D-*.md`；`env` 存在时三键合法；调用 `$DIR/tools/check-links.sh "$DIR"`；逐项 ok/FAIL，任一失败 exit 1。

- [ ] **Step 4: 跑测试确认通过**

Run: `bash project-constraints/tests/test-check.sh`
Expected: 全 ok。

- [ ] **Step 5: 提交**

~~~bash
git add project-constraints/scripts/check.sh project-constraints/tests/test-check.sh
git commit -m "feat(check): 校验文件齐全、占位、决策与断链"
~~~

---

### Task 7: adopt.sh

**Files:**
- Create: `project-constraints/scripts/adopt.sh`
- Create: `project-constraints/tests/test-adopt.sh`

**Interfaces:**
- Consumes: Task 5 的 `lib.sh`、Task 2–4 的模板
- Produces: `adopt.sh --target DIR [--scan quick|standard|full] [--report FILE] [--apply] [--name S] [--one-liner S] [--stack S] [--env E] [--role R]`；默认 standard + 只读；0 成功 / 1 目标失败 / 2 用法错误

- [ ] **Step 1: 写 `test-adopt.sh`（会失败）**

~~~bash
#!/usr/bin/env bash
set -uo pipefail
T="$(cd "$(dirname "$0")/.." && pwd)"
W="$T/.scratch/adopt"; rm -rf "$W"; mkdir -p "$W/existing/src" "$W/scan" "$W/bad"
printf '# AGENTS\n- 规则一\n- 直接 push main\n' > "$W/existing/AGENTS.md"
h1=$(sha256sum "$W/existing/AGENTS.md" | cut -d' ' -f1)
fail=0
ok()  { printf 'ok   %s\n' "$1"; }
bad() { printf 'FAIL %s\n' "$1"; fail=1; }

bash "$T/scripts/adopt.sh" --target "$W/existing" --report "$W/r1.md" >/dev/null
[[ -f "$W/r1.md" ]] && ok "出报告" || bad "无报告"
[[ "$(find "$W/existing" -type f | wc -l)" -eq 1 ]] && ok "报告不写文件" || bad "报告阶段写了文件"
grep -q '^## 已有（跳过）$' "$W/r1.md" && ok "已有小节" || bad "缺已有小节"
grep -q 'AGENTS.md' "$W/r1.md" && ok "列出已有文件" || bad "未列出已有文件"
grep -q '^## 冲突裁决$' "$W/r1.md" && ok "冲突小节" || bad "缺冲突小节"

bash "$T/scripts/adopt.sh" --target "$W/existing" --scan standard --apply >/dev/null
[[ "$(find "$W/existing" -type f | wc -l)" -eq 15 ]] && ok "补齐 15 个" || bad "文件数"
h2=$(sha256sum "$W/existing/AGENTS.md" | cut -d' ' -f1)
[[ "$h1" == "$h2" ]] && ok "已有文件未改" || bad "已有文件被改"
grep -q '^ENV=unknown$' "$W/existing/env" && ok "env 默认 unknown" || bad "env 默认值"
mkdir -p "$W/envcase"
bash "$T/scripts/adopt.sh" --target "$W/envcase" --scan quick --apply --name X --one-liner Y --stack Z --env testing --role app >/dev/null
grep -q '^ENV=testing$' "$W/envcase/env" && ok "env 参数生效" || bad "env 参数未生效"

touch "$W/scan/.cursorrules"
bash "$T/scripts/adopt.sh" --target "$W/scan" --scan quick --report "$W/rq.md" >/dev/null
! grep -q 'cursorrules' "$W/rq.md" && ok "quick 不扫 cursorrules" || bad "quick 扫了 cursorrules"
bash "$T/scripts/adopt.sh" --target "$W/scan" --scan standard --report "$W/rs.md" >/dev/null
grep -q 'cursorrules' "$W/rs.md" && ok "standard 扫 cursorrules" || bad "standard 漏 cursorrules"

bash "$T/scripts/adopt.sh" --target "$W/bad" --scan nope >/dev/null 2>&1; [[ $? -eq 2 ]] && ok "非法 scan 退出 2" || bad "非法 scan 退出码"
bash "$T/scripts/adopt.sh" --target "$W/nope" --report "$W/r3.md" >/dev/null 2>&1; [[ $? -eq 1 ]] && ok "目标不存在退出 1" || bad "目标不存在退出码"
exit "$fail"
~~~

- [ ] **Step 2: 跑测试确认失败**

Run: `bash project-constraints/tests/test-adopt.sh`
Expected: FAIL。

- [ ] **Step 3: 实现 `adopt.sh` 的扫描与报告**

结构检测：15 个目标路径；`AGENTS.md` / `CLAUDE.md` / `README.md` / `CONTRIBUTING.md`；按级别追加 `.cursorrules` / `.cursor/rules/*` / `.github/copilot-instructions.md` / `env` / `.env.example` / `.env` / CI 工作流 / `package.json` scripts / `Makefile` / lint 配置。报告固定小节：`## 已有（跳过）`（路径、行数、建议）、`## 将创建（缺失）`、`## 结构发现`（类型、路径、说明）、`## 冲突裁决`（表头 + 一行提示"由 Agent 填写"）、`## 阻塞项`、`## 下一步`。

- [ ] **Step 4: 实现 `adopt.sh` 的 `--apply`**

只创建缺失文件：渲染、`chmod 600 env`、`chmod_exec tools`、追加 `.gitignore`；已有路径不读不写；打印 `created=N` 与 `skipped=M`。`--apply` 且 `AGENTS.md` 缺失时三个必填校验；只出报告时用默认值。`--report` 目标已存在则拒绝（exit 1）。

- [ ] **Step 5: 跑测试确认通过**

Run: `bash project-constraints/tests/test-adopt.sh`
Expected: 全 ok。

- [ ] **Step 6: 提交**

~~~bash
git add project-constraints/scripts/adopt.sh project-constraints/tests/test-adopt.sh
git commit -m "feat(adopt): 扫描、报告与只补缺失"
~~~

---

### Task 8: SKILL.md 与 references

**Files:**
- Create: `project-constraints/SKILL.md`
- Create: `project-constraints/references/conventions.md`
- Create: `project-constraints/references/example-mapping.md`
- Create: `project-constraints/tests/test-skill-md.sh`

**Interfaces:**
- Consumes: Task 1 的 `notes/red-baseline.md`；Task 5–7 的脚本契约
- Produces: 可被 DSH 加载的技能入口

- [ ] **Step 1: 写 `test-skill-md.sh`（会失败）**

~~~bash
#!/usr/bin/env bash
set -uo pipefail
T="$(cd "$(dirname "$0")/.." && pwd)"
F="$T/SKILL.md"
fail=0
ok()  { printf 'ok   %s\n' "$1"; }
bad() { printf 'FAIL %s\n' "$1"; fail=1; }
[[ "$(head -1 "$F")" == "---" ]] && ok "frontmatter 开头" || bad "frontmatter 开头"
grep -qx 'name: project-constraints' "$F" && ok "name" || bad "name"
grep -q '^description: ' "$F" && ok "description" || bad "description"
desc=$(grep '^description: ' "$F")
[[ "$desc" != *"init.sh"* && "$desc" != *"adopt.sh"* && "$desc" != *"五步"* ]] && ok "description 不写流程" || bad "description 写流程"
for h in '## 概述' '## 模式判断' '## new 五步' '## adopt 六步' '## 常见错误' '## 自检'; do
  grep -qx "$h" "$F" && ok "标题 $h" || bad "标题 $h"
done
grep -q 'scripts/init.sh' "$F" && ok "引用 init" || bad "引用 init"
grep -q 'scripts/adopt.sh' "$F" && ok "引用 adopt" || bad "引用 adopt"
grep -q 'scripts/check.sh' "$F" && ok "引用 check" || bad "引用 check"
body=$(awk 'BEGIN{n=0} /^---$/{n++; next} n>=2{print}' "$F")
[[ "$(printf '%s' "$body" | wc -m)" -le 1500 ]] && ok "正文长度" || bad "正文过长"
[[ -f "$T/references/conventions.md" ]] && ok "conventions" || bad "conventions"
[[ "$(grep -c '^|' "$T/references/conventions.md")" -ge 9 ]] && ok "误区表" || bad "误区表行数"
exit "$fail"
~~~

- [ ] **Step 2: 跑测试确认失败**

Run: `bash project-constraints/tests/test-skill-md.sh`
Expected: FAIL。

- [ ] **Step 3: 写 `SKILL.md`**

frontmatter 用 spec §3 原文。正文：概述 2 句；模式判断（检测提示 + 必须问用户）；new 五步；adopt 六步；五个必问；常见错误表（覆盖 `notes/red-baseline.md` 两段缺失项）；自检 5 条；指向 `templates/`、`scripts/`、`references/`。

- [ ] **Step 4: 写 `references/conventions.md`**

六条原则（单一出处、spec 不引用证据、决策留痕、环境先声明、状态只写现在、证据可过期）+ 常见误区表（≥ 8 行，泛化自 trader-plan2 conventions §11）+ 与旧做法差异。

- [ ] **Step 5: 写 `references/example-mapping.md`**

表格：生成文件 → trader-plan2 对应文件 → 剥掉了什么。至少覆盖 AGENTS、ENVIRONMENTS、STATUS、README、docs/spec、docs/decisions、docs/evidence、tools/env.sh。

- [ ] **Step 6: 跑测试确认通过**

Run: `bash project-constraints/tests/test-skill-md.sh`
Expected: 全 ok。

- [ ] **Step 7: 提交**

~~~bash
git add project-constraints/SKILL.md project-constraints/references project-constraints/tests/test-skill-md.sh
git commit -m "feat(skill): 双模式入口与参考文档"
~~~

---

### Task 9: 端到端（new + adopt）与冷启动

**Files:**
- Create: `notes/green-acceptance.md`

**Interfaces:**
- Consumes: Task 2–8 全部产物
- Produces: 验收记录；必要时对模板或 SKILL.md 的修正提交

- [ ] **Step 1: 跑全部测试**

Run: `bash project-constraints/tests/run.sh`
Expected: 全 ok，退出码 0。

- [ ] **Step 2: new 端到端**

~~~bash
bash project-constraints/scripts/init.sh --target .scratch/e2e-new --name "示例项目" \
  --one-liner "验证 new 模式" --stack "TypeScript / Node 22" --apply
bash project-constraints/scripts/check.sh .scratch/e2e-new
(cd .scratch/e2e-new && bash tools/env.sh)
~~~

Expected: check 0；env 打印 `ENV=local` / `ROLE=authoring` / 绝对 `ROOT`，exit 0。

- [ ] **Step 3: adopt 端到端**

造样本 `.scratch/e2e-adopt/`：`AGENTS.md`（含"直接 push main"与"测试只在本地跑"）、`README.md`、`.cursorrules`、`src/app.ts`。跑：

~~~bash
bash project-constraints/scripts/adopt.sh --target .scratch/e2e-adopt \
  --scan standard --report notes/adopt-report.md
~~~

然后由执行者按 SKILL.md 第 3 步读文件、填"冲突裁决"表：至少两行（推送规则、测试位置），每行有现有原文、选项、建议。再跑 `--apply`，最后 `check.sh`。

重跑前删掉 `notes/adopt-report.md`。Expected: 已有三个文件 sha256 不变；缺失文件补齐；报告冲突表两行且都有建议。

- [ ] **Step 4: 冷启动（new 与 adopt 各一次）**

new：subagent cwd 为 `.scratch/e2e-new`；adopt：cwd 为 `.scratch/e2e-adopt`。prompt：

~~~text
只读当前目录的 AGENTS.md、STATUS.md、README.md，不要读其他文件。
回答三点：(1) 这个项目做什么 (2) 当前阶段和下一步 (3) 验证应该在哪里跑。
最后单独一行写环境声明。
~~~

验收：三点正确；声明 `ENV` 与依据；adopt 场景要能说出"哪些规则沿用了原项目"。

- [ ] **Step 5: 对照 RED 基线**

逐条列出 `notes/red-baseline.md` 两个场景的缺失项 → 现在由 AGENTS 哪节或 SKILL 哪步覆盖。未覆盖的修模板或 SKILL.md 后重跑 Step 1–4。记录到 `notes/green-acceptance.md`。

- [ ] **Step 6: 提交**

~~~bash
git add notes/green-acceptance.md notes/adopt-report.md project-constraints
git commit -m "test(e2e): new 与 adopt 生成、检查与冷启动通过"
~~~

---

### Task 10: 安装到用户技能目录

**Files:**
- Create: `~/.dsh/skills/project-constraints/`（目录拷贝）

**Interfaces:**
- Consumes: Task 9 通过验收的技能包
- Produces: 全局可发现的技能

- [ ] **Step 1: 拷贝（需要沙箱授权）**

~~~bash
mkdir -p ~/.dsh/skills
ls ~/.dsh/skills/project-constraints 2>/dev/null
rm -rf ~/.dsh/skills/project-constraints
cp -r project-constraints ~/.dsh/skills/
~~~

`rm -rf` 只作用于已确认的安装目标；执行前先看 `ls` 输出确认是旧版本。

- [ ] **Step 2: 验证安装**

Run: `ls -R ~/.dsh/skills/project-constraints | head -30` 与 `head -5 ~/.dsh/skills/project-constraints/SKILL.md`
Expected: `name: project-constraints`，目录名一致。

- [ ] **Step 3: 告知用户**

请用户新开会话确认技能目录出现 `project-constraints`；本会话已加载的目录不会自动刷新。
