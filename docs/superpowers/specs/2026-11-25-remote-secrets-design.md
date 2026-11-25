# 远端凭据集中管理 · 设计

| 项 | 值 |
| --- | --- |
| 状态 | 待评审 |
| 版本 | v1.0（2026-11-25） |
| 范围 | project-constraints 技能新增"仓外密钥文件 + 包装脚本"，并应用到本仓库 |
| 关联 | [project-constraints-skill-design.md](2026-11-25-project-constraints-skill-design.md) v1.2 |

## 0 摘要

远端操作（git push、ssh、rsync）的账号密码只放在仓库外一个文件里，由用户填写；仓库里只有模板和包装脚本。agent 只调用包装脚本，不读、不打印密钥；仓库内出现真实凭据会被 check 拦下。

## 1 目标与非目标

目标：

1. 一个仓外文件同时放 git 与 ssh 两类凭据，用户按模板填写。
2. 每个生成的项目带 `secrets.example` 与两个包装脚本；agent 不接触明文。
3. 仓库内不出现真实值；误放能被 `check.sh` 发现。
4. 本仓库也按同一约定配一份，可直接用来推送。

非目标：

- 不做密钥轮换、加密存储；靠文件权限（600）与仓外位置。
- 不接管既有的 ssh config 或 git credential helper；包装脚本只是可选入口。
- 不存云厂商（AWS/阿里云等）密钥；只覆盖 git 与 ssh/rsync。

## 2 文件与路径

路径：`~/.config/project-constraints/<项目>.env`，`<项目>` 取项目根目录名（含空格时替换为 `-`）。可用环境变量 `PROJECT_SECRETS` 覆盖。

项目根：优先 `git rev-parse --show-toplevel`，没有 git 时用当前目录。

格式（`secrets.example` 原样）：

~~~ini
# 复制到 ~/.config/project-constraints/<项目>.env，然后 chmod 600
# 仓库里不要出现真实值；下面全部替换成你自己的。

[git]
user  = your-github-user
token = ghp_xxxxxxxxxxxxxxxx

[ssh]
host     = 203.0.113.10
user     = deploy
password = your-server-password
port     = 22
# key = ~/.ssh/id_ed25519   # 用密钥时填这行，password 留空

[rsync]
# 可选；不填就用 [ssh] 的 host/user/port
# path = /var/www/myapp/
~~~

解析规则：

- 只认 `[节]` 与 `键 = 值`；`#` 开头（去空白后）是注释；空行忽略；不支持行内注释。
- 键值按第一个 `=` 切分；两侧空白去掉；值两端的单/双引号去掉；CRLF 自动兼容。
- 节名、键名不区分大小写；未知节/键忽略；重复键后者覆盖。
- 空值视为未设置。

## 3 生成物变化（15 → 18）

新增：

| 文件 | 作用 |
| --- | --- |
| `secrets.example` | 上面那份模板，两节案例，提交进仓库 |
| `tools/secrets.sh` | INI 解析库；只读、不执行、不打印值 |
| `tools/remote.sh` | 唯一入口：`check` / `git-push` / `ssh` / `rsync` |

同步修改：

- `.gitignore` 增加 `secrets.env` 与 `*.secrets`（在仓库里出现真实文件也要挡住）。
- `AGENTS.md` §6 增加：远端操作只走 `tools/remote.sh`；不读、不打印、不复制密钥文件；缺文件就停并询问。
- `ENVIRONMENTS.md` §6 写清路径、600、仓外，并指向 `tools/remote.sh`。
- `check.sh` 增加：`secrets.example` 存在；`.gitignore` 挡住 `secrets.env`；仓库内无 `secrets.env`；外部文件存在时权限 600（只 `stat`，不读内容）。
- `SKILL.md` 的 new/adopt 末尾加"提示用户创建外部 secrets"，并给 `mkdir/cp/chmod` 命令；常见错误加"把 token 或密码贴进聊天/仓库"。

## 4 脚本契约

### 4.1 secrets.sh

source 进 `remote.sh`，不单独执行。提供：

- `secrets_path`：打印解析后的绝对路径。
- `secrets_load`：校验并解析，导出 `GIT_USER` / `GIT_TOKEN` / `SSH_HOST` / `SSH_USER` / `SSH_PASSWORD` / `SSH_KEY` / `SSH_PORT` / `RSYNC_PATH`。
- 校验顺序：文件存在 → 属主是当前用户 → 权限 600 → 路径不在项目目录内 → 解析。
- 失败只报"哪个文件/哪个键"，不报值；退出码 1。

### 4.2 remote.sh

- `bash tools/remote.sh check`：校验文件、权限、两节必需键；输出 `file=ok`、`mode=600`、`git=ok|missing`、`ssh=ok|missing`、`rsync=ok|missing`，不输出值；退出码 0/1。
- `bash tools/remote.sh git-push [git push 参数...]`：默认 `origin HEAD`；token 经 `GIT_ASKPASS` 环境变量传给 git，`GIT_TERMINAL_PROMPT=0`；askpass 临时文件 700，`trap` 删除。
- `bash tools/remote.sh ssh "<命令>"`：有 `SSH_KEY` 用 `ssh -i`；否则用 `SSHPASS` + `sshpass -e`；`sshpass` 未安装时报错并给出两条路（安装或改用 key）。
- `bash tools/remote.sh rsync <src> [dst]`：用 ssh 的 host/user/port/key 组 `-e`，目标写成 `user@host:path`；省略 dst 时用 `RSYNC_PATH`，仍缺则 exit 2。
- 退出码：0 成功；1 文件/校验/执行失败；2 用法错误。

## 5 安全护栏

- 解析不 `source`、不 `eval`；值不进命令行参数。
- 文件必须 600、属主为当前用户；解析出的路径在项目目录内则拒绝。
- 脚本 `set +x`；错误信息不含值；git 不弹交互密码。
- ssh 密码只经 `SSHPASS`（环境变量）；git token 只经 askpass 的环境变量。
- `check.sh` 只 `stat` 外部文件，不读内容；仓库内出现 `secrets.env` 直接 FAIL。
- agent 规则：只调 `tools/remote.sh`；不 `cat` / `read` 密钥文件；缺文件停下问用户。

## 6 流程

- new / adopt 生成完，最后一步打印：

~~~bash
mkdir -p ~/.config/project-constraints
cp secrets.example ~/.config/project-constraints/<项目>.env
chmod 600 ~/.config/project-constraints/<项目>.env
~~~

不自动创建仓外文件；由用户填。

- `remote.sh check` 可随时自检；缺文件时 new/adopt 的 check 只警告，不 FAIL（远端操作前必须补）。
- 本仓库：根目录放 `secrets.example`、`tools/secrets.sh`、`tools/remote.sh`；`.gitignore` 加两条；README 加"远端凭据"一节；源码仓库的两个 `tools` 脚本与技能模板逐字节一致（加 `cmp` 测试，安装后无仓库 `tools` 时跳过）。

## 7 验证

| 编号 | 检查 | 通过标准 |
| --- | --- | --- |
| V1 | 解析器 | 分节、注释、引号、CRLF、缺键、重复键、空值都按上面规则 |
| V2 | 权限与位置 | 644、非本人、路径在项目内，三种都拒绝且不泄露值 |
| V3 | 凭据传递 | 假 git 记录 argv 与环境：token 只在环境/askpass，不在 argv；假 ssh/sshpass 参数正确 |
| V4 | 缺 sshpass | 报错并给出安装或 key 两条路，不降级为交互密码 |
| V5 | check | 缺 `secrets.example`、`.gitignore` 没挡、仓库内有 `secrets.env`、外部文件 644，四种都 FAIL |
| V6 | e2e | 生成项目 + 外部临时 secrets（600）+ 假 git 推送成功；删文件后报"缺文件" |
| V7 | 本仓库 | `tools/*` 与模板 `cmp` 一致；`remote.sh check` 在临时文件上输出 ok |
| V8 | 无泄露 | 所有脚本输出里 grep 不到测试用的 token/密码 |

## 8 明确不做

- 不做密码管理器、不加密文件、不生成密钥对。
- 不自动填任何值，不把用户输入写进仓库。
- 不改 git 的全局 credential helper 或 `~/.ssh/config`。

## 9 取舍

- 选仓外文件而不是仓库内 gitignored：避免误提交与打包泄漏；代价是每台机器要单独填。
- 选 INI 而不是 `KEY=VALUE` + `source`：拒绝代码执行；代价是多一个解析器要测。
- 密码与 key 都支持：优先 key；密码需要 `sshpass`，装不了就改用 key。
