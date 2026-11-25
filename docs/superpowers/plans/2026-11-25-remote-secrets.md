# project-constraints 远端凭据 · 实施计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 给技能加"仓外密钥文件 + 包装脚本"，生成物 15 → 18 文件；agent 只调 `tools/remote.sh`，不接触明文；本仓库也配一份。

**Architecture:** `templates/tools/secrets.sh.tmpl` 负责解析与校验；`templates/tools/remote.sh.tmpl` 是唯一入口（check / git-push / ssh / rsync）；`init.sh` / `adopt.sh` 的文件清单与映射扩到 18；`check.sh` 增加 secrets 校验；测试用假 git/ssh/sshpass 断言"值不进 argv"。

**Tech Stack:** Bash 4+ / coreutils / sed / grep；零第三方依赖；ssh 走系统 `ssh`，密码分支需要 `sshpass`（当前未安装）。

**Spec:** `docs/superpowers/specs/2026-11-25-remote-secrets-design.md`（主 spec v1.2）

## Global Constraints

- 生成物 18 个；模板 17 个（`env` 由脚本生成）。
- 密钥文件固定在 `~/.config/project-constraints/<项目>.env`，权限 600，必须在项目目录外。
- 解析不 `source`、不 `eval`；token/密码不进 argv、不进日志、不进错误信息。
- 缺外部文件时 `check.sh` 只警告；文件落在仓库内或权限不是 600 时 FAIL。
- 本仓库的 `tools/*` 与技能模板逐字节一致（`cmp` 测试；安装后无仓库 `tools` 时跳过）。
- SKILL.md 正文 ≤ 1500 字符。
- 变量仍只有 4 个：`PROJECT_NAME` / `ONE_LINER` / `STACK` / `DATE`。

## Review Focus

1. token 或密码出现在 argv、stdout、日志 —— Task 2 的假 git/ssh 测试。
2. 解析器执行文件内容（source/eval）—— Task 1 的实现与测试。
3. 仓库内出现 `secrets.env` 却通过 check —— Task 5 的用例。
4. 外部文件 644 仍被使用 —— Task 1 的权限用例。
5. 18 文件计数没同步到 init/adopt/测试 —— Task 4/8 的全量回归。

---

### Task 1: secrets 解析库

**Files:**
- Create: `project-constraints/templates/tools/secrets.sh.tmpl`
- Create: `project-constraints/tests/test-secrets.sh`

**Interfaces:**
- Produces: `secrets_project_root`（`PROJECT_ROOT` 覆盖 → `git rev-parse --show-toplevel` → `pwd`）；`secrets_path`（`PROJECT_SECRETS` 覆盖 → `XDG_CONFIG_HOME`/`HOME/.config` + `project-constraints/<slug>.env`）；`secrets_load`（校验后导出 `GIT_USER` / `GIT_TOKEN` / `SSH_HOST` / `SSH_USER` / `SSH_PASSWORD` / `SSH_KEY` / `SSH_PORT` / `RSYNC_PATH`）

- [ ] **Step 1: 写解析器测试（会失败）**

~~~bash
#!/usr/bin/env bash
set -uo pipefail
T="$(cd "$(dirname "$0")/.." && pwd)"
R="$(cd "$T/.." && pwd)"
W="$R/.scratch/secrets"; rm -rf "$W"; mkdir -p "$W/proj"
cp "$T/templates/tools/secrets.sh.tmpl" "$W/secrets.sh"
fail=0
ok()  { printf 'ok   %s\n' "$1"; }
bad() { printf 'FAIL %s\n' "$1"; fail=1; }

good="$W/good.env"
cat > "$good" <<'EOF'
# comment
[git]
user  = alice
token = "tok#123"

[ssh]
host = 10.0.0.5
user = deploy
password = 'p@ss'
port = 2222
key =
EOF
chmod 600 "$good"

run_load() {
  PROJECT_ROOT="$W/proj" PROJECT_SECRETS="$1" bash -c '
    source "'"$W"'/secrets.sh"
    secrets_load || exit 1
    printf "%s|%s|%s|%s|%s|" "$GIT_USER" "$GIT_TOKEN" "$SSH_HOST" "$SSH_USER" "$SSH_PORT"
    if [ -n "$SSH_KEY" ]; then printf "%s" "$SSH_KEY"; else printf none; fi
  '
}
out=$(run_load "$good"); rc=$?
[[ $rc -eq 0 && "$out" == "alice|tok#123|10.0.0.5|deploy|2222|none" ]] && ok "解析与引号" || bad "解析: rc=$rc out=$out"

printf 'ENV=1\n[git]\nuser = x\ntoken = y\n' > "$W/unknown.env"; chmod 600 "$W/unknown.env"
out=$(run_load "$W/unknown.env"); rc=$?
[[ $rc -eq 0 && "$out" == "x|y||||none" ]] && ok "未知节忽略" || bad "未知节: $out"

cp "$good" "$W/perm.env"; chmod 644 "$W/perm.env"
out=$(PROJECT_ROOT="$W/proj" PROJECT_SECRETS="$W/perm.env" bash -c 'source "'"$W"'/secrets.sh"; secrets_load' 2>&1); rc=$?
[[ $rc -ne 0 && "$out" == *"权限"* ]] && ok "644 拒绝" || bad "644: rc=$rc out=$out"

printf 'ENV=1\n' > "$W/proj/inside.env"; chmod 600 "$W/proj/inside.env"
out=$(PROJECT_ROOT="$W/proj" PROJECT_SECRETS="$W/proj/inside.env" bash -c 'source "'"$W"'/secrets.sh"; secrets_load' 2>&1); rc=$?
[[ $rc -ne 0 && "$out" == *"项目目录"* ]] && ok "仓库内拒绝" || bad "仓库内: rc=$rc"

out=$(PROJECT_ROOT="$W/proj" PROJECT_SECRETS="$W/nope.env" bash -c 'source "'"$W"'/secrets.sh"; secrets_load' 2>&1); rc=$?
[[ $rc -ne 0 && "$out" == *"nope.env"* ]] && ok "缺文件" || bad "缺文件: rc=$rc"
exit "$fail"
~~~

- [ ] **Step 2: 跑测试确认失败**

Run: `bash project-constraints/tests/test-secrets.sh`
Expected: FAIL，`templates/tools/secrets.sh.tmpl` 不存在。

- [ ] **Step 3: 实现 `secrets.sh.tmpl`**

要点：`PROJECT_ROOT` / `PROJECT_SECRETS` 覆盖；`secrets_load` 依次校验存在、`stat -c %a` 为 600、`stat -c %u` 等于 `id -u`、`realpath` 不在项目根下；逐行解析，`#` 注释、空行、`[节]`、第一个 `=` 切分、去空白、去引号、`tr -d '\r'`；按 `节:键` 导出；未知键忽略；错误用 `die()` 只报路径或键名。不 `source`、不 `eval`。

- [ ] **Step 4: 跑测试确认通过**

Run: `bash project-constraints/tests/test-secrets.sh`
Expected: 全 ok。

- [ ] **Step 5: 提交**

~~~bash
git add project-constraints/templates/tools/secrets.sh.tmpl project-constraints/tests/test-secrets.sh
git commit -m "feat(secrets): INI 解析与权限校验"
~~~

---

### Task 2: remote.sh

**Files:**
- Create: `project-constraints/templates/tools/remote.sh.tmpl`
- Modify: `project-constraints/tests/test-secrets.sh`

**Interfaces:**
- Consumes: Task 1 的 `secrets_load`
- Produces: `remote.sh check|git-push|ssh|rsync`；0 成功 / 1 校验或执行失败 / 2 用法

- [ ] **Step 1: 追加 remote.sh 测试（会失败）**

~~~bash
mkdir -p "$W/bin"
cat > "$W/bin/git" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$*" > "$ARGV_LOG"
if [ -n "$GIT_ASKPASS" ]; then "$GIT_ASKPASS" "Password for https://github.com" > "$TOKEN_LOG"; fi
exit 0
EOF
cat > "$W/bin/ssh" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$*" > "$SSH_LOG"
exit 0
EOF
chmod +x "$W/bin/git" "$W/bin/ssh"

out=$(PATH="$W/bin:$PATH" ARGV_LOG="$W/argv" TOKEN_LOG="$W/token" \
  PROJECT_ROOT="$W/proj" PROJECT_SECRETS="$good" \
  bash "$T/templates/tools/remote.sh.tmpl" git-push origin main 2>&1); rc=$?
[[ $rc -eq 0 ]] && ok "git-push 运行" || bad "git-push rc=$rc $out"
grep -qx 'origin main' "$W/argv" && ok "推送参数" || bad "argv: $(cat "$W/argv")"
! grep -q 'tok#123' "$W/argv" && [[ "$out" != *"tok#123"* ]] && ok "token 不进 argv/输出" || bad "token 泄露"
grep -qx 'tok#123' "$W/token" && ok "askpass 返回 token" || bad "askpass 未工作"

cp "$good" "$W/key.env"; printf 'key = /home/deploy/.ssh/id_test\n' >> "$W/key.env"; chmod 600 "$W/key.env"
out=$(PATH="$W/bin:$PATH" SSH_LOG="$W/sshlog" PROJECT_ROOT="$W/proj" PROJECT_SECRETS="$W/key.env" \
  bash "$T/templates/tools/remote.sh.tmpl" ssh "hostname" 2>&1)
grep -q '10.0.0.5' "$W/sshlog" && grep -q 'hostname' "$W/sshlog" && ok "ssh 参数" || bad "ssh: $(cat "$W/sshlog" 2>/dev/null)"

out=$(PATH="$W/bin:$PATH" PROJECT_ROOT="$W/proj" PROJECT_SECRETS="$good" \
  bash "$T/templates/tools/remote.sh.tmpl" check 2>&1); rc=$?
[[ $rc -eq 0 && "$out" == *"git=ok"* && "$out" == *"ssh=ok"* ]] && ok "check" || bad "check: rc=$rc $out"
! grep -q 'tok#123' <<< "$out" && ok "check 不打印值" || bad "check 泄露"
~~~

- [ ] **Step 2: 跑测试确认失败**

Run: `bash project-constraints/tests/test-secrets.sh`
Expected: FAIL，remote.sh 不存在。

- [ ] **Step 3: 实现 `remote.sh.tmpl`**

`source` 同目录 `secrets.sh`；`check` 打印 `file=ok`、`mode=600`、`git=ok|missing`、`ssh=ok|missing`、`rsync=ok|missing`；`git-push` 用 `mktemp` 生成 askpass（700、`trap` 删除），`GIT_ASKPASS` + `GIT_TERMINAL_PROMPT=0`，无参数时默认 `origin HEAD`；`ssh` 有 `SSH_KEY` 用 `ssh -i`，否则必须有 `sshpass`（`SSHPASS` + `sshpass -e`），没有就报两条路；`rsync` 用 ssh 参数组 `-e`，dst 缺省用 `RSYNC_PATH`。错误只报键名。

- [ ] **Step 4: 跑测试确认通过**

Run: `bash project-constraints/tests/test-secrets.sh`
Expected: 全 ok。

- [ ] **Step 5: 提交**

~~~bash
git add project-constraints/templates/tools/remote.sh.tmpl project-constraints/tests/test-secrets.sh
git commit -m "feat(remote): 凭据包装入口与假二进制测试"
~~~

---

### Task 3: secrets.example 与模板契约

**Files:**
- Create: `project-constraints/templates/secrets.example`
- Modify: `project-constraints/tests/test-templates.sh`

**Interfaces:**
- Produces: 两节案例模板；`[git]` / `[ssh]` / `[rsync]`

- [ ] **Step 1: 追加断言（会失败）**

~~~bash
assert_file "secrets 模板" "$T/templates/secrets.example"
assert_grep "git 节" "$T/templates/secrets.example" '^\[git\]$'
assert_grep "ssh 节" "$T/templates/secrets.example" '^\[ssh\]$'
assert_grep "token 键" "$T/templates/secrets.example" '^token = '
assert_grep "chmod 提示" "$T/templates/secrets.example" 'chmod 600'
~~~

- [ ] **Step 2: 跑测试确认失败**

Run: `bash project-constraints/tests/test-templates.sh`
Expected: FAIL。

- [ ] **Step 3: 写 `secrets.example`**

内容用 spec §2 的模板：路径注释、`[git]` 的 user/token、`[ssh]` 的 host/user/password/port/key 注释、`[rsync]` 可选 path 注释；值全部是占位符，不含任何真实凭据。

- [ ] **Step 4: 跑测试确认通过并提交**

Run: `bash project-constraints/tests/test-templates.sh`
Expected: 全 ok。

~~~bash
git add project-constraints/templates/secrets.example project-constraints/tests/test-templates.sh
git commit -m "feat(templates): 远端凭据模板"
~~~

---

### Task 4: init / adopt 接入 18 文件

**Files:**
- Modify: `project-constraints/scripts/init.sh`
- Modify: `project-constraints/scripts/adopt.sh`
- Modify: `project-constraints/scripts/lib.sh`
- Modify: `project-constraints/tests/test-init.sh`
- Modify: `project-constraints/tests/test-adopt.sh`

**Interfaces:**
- Consumes: Task 1–3 的模板
- Produces: 18 文件清单；`tmpl_for` 覆盖新文件；init 末尾打印仓外 secrets 命令

- [ ] **Step 1: 更新测试（会失败）**

`test-init.sh`：文件数 15 → 18；追加 `[[ -f "$D/p/secrets.example" ]]`、`[[ -x "$D/p/tools/remote.sh" ]]`；`out=$(... --apply)` 后 grep `~/.config/project-constraints`。
`test-adopt.sh`：`find ... -eq 15` → 18（fixture 只有 AGENTS.md，其余 17 个由 adopt 创建）。

- [ ] **Step 2: 跑测试确认失败**

Run: `bash project-constraints/tests/test-init.sh; bash project-constraints/tests/test-adopt.sh`
Expected: FAIL，文件数仍是 15。

- [ ] **Step 3: 实现**

`FILES` 追加 `secrets.example tools/secrets.sh tools/remote.sh`（共 18）；`lib.sh` 的 `tmpl_for` 加三条映射（`secrets.example` → `templates/secrets.example`，两个 `.sh` → 对应 `.tmpl`）；`chmod_exec` 加两个新脚本；init 的 `--apply` 预检改为 17 个目标路径（只排除 `.gitignore`；`env` 也算，防止覆盖）；init 末尾打印：

~~~bash
mkdir -p ~/.config/project-constraints
cp secrets.example ~/.config/project-constraints/<目录名>.env
chmod 600 ~/.config/project-constraints/<目录名>.env
~~~

adopt 的报告"将创建"与 `--apply` 走同一清单。

- [ ] **Step 4: 跑测试确认通过**

Run: `bash project-constraints/tests/test-init.sh; bash project-constraints/tests/test-adopt.sh`
Expected: 全 ok。

- [ ] **Step 5: 提交**

~~~bash
git add project-constraints/scripts project-constraints/tests/test-init.sh project-constraints/tests/test-adopt.sh
git commit -m "feat(init/adopt): 18 文件与凭据提示"
~~~

---

### Task 5: check.sh 凭据校验

**Files:**
- Modify: `project-constraints/scripts/check.sh`
- Modify: `project-constraints/tests/test-check.sh`

**Interfaces:**
- Produces: 18 文件校验；`secrets.example` 存在；`.gitignore` 挡 `secrets.env`；仓库内无 `secrets.env`；外部文件存在时 600（缺失只警告）

- [ ] **Step 1: 追加测试（会失败）**

~~~bash
gen "$D/n"; PROJECT_SECRETS="$D/n/ext.env" bash "$T/scripts/check.sh" "$D/n" >/dev/null 2>&1; [[ $? -eq 0 ]] && ok "缺外部文件只警告" || bad "缺外部文件被 FAIL"
printf '# x\n' > "$D/n/secrets.env"
out=$(PROJECT_SECRETS="$D/n/ext.env" bash "$T/scripts/check.sh" "$D/n" 2>&1); rc=$?
[[ $rc -ne 0 && "$out" == *"secrets.env"* ]] && ok "仓库内 secrets.env" || bad "仓库内未报"

gen "$D/o"; sed -i '/^secrets.env$/d' "$D/o/.gitignore"
out=$(bash "$T/scripts/check.sh" "$D/o" 2>&1); rc=$?
[[ $rc -ne 0 && "$out" == *"gitignore"* ]] && ok "gitignore 未挡" || bad "gitignore 未报"

gen "$D/p"; printf '# x\n' > "$D/p.ext"; chmod 644 "$D/p.ext"
out=$(PROJECT_SECRETS="$D/p.ext" bash "$T/scripts/check.sh" "$D/p" 2>&1); rc=$?
[[ $rc -ne 0 && "$out" == *"600"* ]] && ok "外部 644" || bad "外部 644 未报"
~~~

- [ ] **Step 2: 跑测试确认失败**

Run: `bash project-constraints/tests/test-check.sh`
Expected: 新增用例 FAIL。

- [ ] **Step 3: 实现**

`FILES` 18；`.gitignore` 用 `grep -qxF` 查 `secrets.env`；`$DIR/secrets.env` 存在直接 `bad`；外部路径 = `PROJECT_SECRETS` 或 `$HOME/.config/project-constraints/$(basename "$DIR").env`，存在才 `stat -c %a`，必须 600，否则 `bad`，缺失 `ok "外部 secrets 未配置（警告）"` 不置 fail。

- [ ] **Step 4: 跑测试确认通过**

Run: `bash project-constraints/tests/test-check.sh`
Expected: 全 ok。

- [ ] **Step 5: 提交**

~~~bash
git add project-constraints/scripts/check.sh project-constraints/tests/test-check.sh
git commit -m "feat(check): 凭据文件与权限校验"
~~~

---

### Task 6: AGENTS / ENVIRONMENTS / SKILL 规则

**Files:**
- Modify: `project-constraints/templates/AGENTS.md.tmpl`
- Modify: `project-constraints/templates/ENVIRONMENTS.md.tmpl`
- Modify: `project-constraints/SKILL.md`
- Modify: `project-constraints/tests/test-templates.sh`
- Modify: `project-constraints/tests/test-skill-md.sh`

- [ ] **Step 1: 追加断言（会失败）**

`test-templates.sh`：AGENTS 含 `tools/remote.sh`、`不打印`；ENVIRONMENTS 含 `~/.config`。
`test-skill-md.sh`：SKILL 含 `secrets.example` 与 `~/.config`。

- [ ] **Step 2: 跑测试确认失败**

Run: `bash project-constraints/tests/test-templates.sh; bash project-constraints/tests/test-skill-md.sh`
Expected: FAIL。

- [ ] **Step 3: 改三个文件**

AGENTS §6 增加：远端操作只走 `tools/remote.sh`；密钥文件在仓外，不读、不打印、不复制；缺文件停下问。ENVIRONMENTS §6 写路径、600、仓外、入口。SKILL：new 第 4 步与 adopt 第 6 步各加"提示创建仓外 secrets"，常见错误加"把 token/密码贴进聊天或仓库"；正文仍 ≤ 1500 字符。

- [ ] **Step 4: 跑测试确认通过**

Run: `bash project-constraints/tests/test-templates.sh; bash project-constraints/tests/test-skill-md.sh`
Expected: 全 ok（含长度断言）。

- [ ] **Step 5: 提交**

~~~bash
git add project-constraints/templates project-constraints/SKILL.md project-constraints/tests
git commit -m "docs(rules): 远端凭据规则进 AGENTS/ENVIRONMENTS/SKILL"
~~~

---

### Task 7: 本仓库配置

**Files:**
- Create: `secrets.example`（仓库根）
- Create: `tools/secrets.sh`、`tools/remote.sh`
- Modify: `.gitignore`
- Modify: `README.md`
- Modify: `project-constraints/tests/test-secrets.sh`（`cmp` 防漂移）

- [ ] **Step 1: 追加 `cmp` 测试（会失败）**

~~~bash
rt="$T/../tools"
if [ -d "$rt" ]; then
  cmp -s "$rt/secrets.sh" "$T/templates/tools/secrets.sh.tmpl" && ok "仓库 secrets.sh 同步" || bad "仓库 secrets.sh 不同步"
  cmp -s "$rt/remote.sh" "$T/templates/tools/remote.sh.tmpl" && ok "仓库 remote.sh 同步" || bad "仓库 remote.sh 不同步"
  cmp -s "$T/../secrets.example" "$T/templates/secrets.example" && ok "仓库 secrets.example 同步" || bad "secrets.example 不同步"
else
  ok "安装环境无仓库 tools，跳过 cmp"
fi
~~~

- [ ] **Step 2: 跑测试确认失败**

Run: `bash project-constraints/tests/test-secrets.sh`
Expected: FAIL，仓库 `tools` 不存在。

- [ ] **Step 3: 落盘**

复制模板到仓库根（写成 root 的文件先 `chown lwj:lwj` 再提交）；`.gitignore` 加 `secrets.env` 与 `*.secrets`；README 加"远端凭据"一节（路径、`cp/chmod`、`remote.sh` 用法、缺 sshpass 的提示）；README 里"108 条断言"改成不写死数字。

- [ ] **Step 4: 跑测试确认通过**

Run: `bash project-constraints/tests/test-secrets.sh; bash project-constraints/tests/run.sh`
Expected: 全 ok。

- [ ] **Step 5: 提交**

~~~bash
git add secrets.example tools .gitignore README.md project-constraints/tests/test-secrets.sh
git commit -m "feat(repo): 本仓库接入仓外凭据"
~~~

---

### Task 8: 端到端与全量回归

**Files:**
- Modify: `notes/green-acceptance.md`

- [ ] **Step 1: 全量测试**

Run: `bash project-constraints/tests/run.sh`
Expected: 全 ok，0 FAIL。

- [ ] **Step 2: e2e**

生成 `.scratch/e2e-secrets`（18 文件），填 §7/§8；在 `.scratch/ext.env` 写临时凭据（600）。跑 `remote.sh` 时显式给 `PROJECT_ROOT=$PWD/.scratch/e2e-secrets`、`PROJECT_SECRETS=$PWD/.scratch/ext.env`（否则会按仓库根算路径）。用假 git 在 `PATH` 里跑 `git-push`，断言 token 不进 argv；`check.sh` 在外部文件缺失时 0、在仓库内放 `secrets.env` 时 1。

- [ ] **Step 3: 记录**

`notes/green-acceptance.md` 追加本次 e2e 输出摘要与计数。

- [ ] **Step 4: 提交**

~~~bash
git add notes/green-acceptance.md
git commit -m "test(e2e): 凭据链路与 check 回归"
~~~
