# 远端凭据集中管理 · 设计

| 项 | 值 |
| --- | --- |
| 状态 | 待评审 |
| 版本 | v1.1（2026-11-25 移除密码路线，改为 SSH 密钥 + 初始化时可选生成公钥） |
| 范围 | project-constraints 技能新增"仓外密钥文件 + 包装脚本"，并应用到本仓库 |
| 关联 | [project-constraints-skill-design.md](2026-11-25-project-constraints-skill-design.md) v1.2 |

## 0 摘要

远端操作（git push、ssh、rsync）的凭据只放在仓库外一个文件里，由用户填写；仓库里只有模板和包装脚本。**SSH 只允许密钥，不支持密码。** 初始化时询问用户是否生成/使用公钥，需要就把公钥打印出来供其加到服务器。agent 只调用包装脚本，不读、不打印私钥。

## 1 目标与非目标

目标：

1. 一个仓外文件同时放 git 与 ssh 两类凭据，用户按模板填写。
2. 每个生成的项目带 `secrets.example` 与包装脚本；agent 不接触明文。
3. 初始化时可选生成 SSH 密钥，并输出公钥（只输出公钥）。
4. 仓库内不出现真实值；误放能被 `check.sh` 发现。
5. 本仓库也按同一约定配一份。

非目标：

- **不支持 SSH 密码登录**，不引入 `sshpass`，文件里不存密码。
- 不做密钥轮换、加密存储；靠文件权限（600）与仓外位置。
- 不接管既有 ssh config 或 git credential helper。
- 不存云厂商密钥。

## 2 文件与路径

路径：`~/.config/project-constraints/<项目>.env`，`<项目>` 取项目根目录名（含空格时替换为 `-`）。可用环境变量 `PROJECT_SECRETS` 覆盖。

项目根：优先 `git rev-parse --show-toplevel`，没有 git 时用当前目录；`PROJECT_ROOT` 可覆盖（测试与特殊布局用）。

格式（`secrets.example` 原样）：

~~~ini
# 复制到 ~/.config/project-constraints/<项目>.env，然后 chmod 600
# 仓库里不要出现真实值；下面全部替换成你自己的。

[git]
user  = your-github-user
token = ghp_xxxxxxxxxxxxxxxx

[ssh]
host = 203.0.113.10
user = deploy
port = 22
key  = ~/.ssh/id_ed25519

[rsync]
# 可选；不填就用 [ssh] 的 host/user/port
# path = /var/www/myapp/
~~~

解析规则：

- 只认 `[节]` 与 `键 = 值`；`#` 开头（去空白后）是注释；空行忽略；不支持行内注释。
- 键值按第一个 `=` 切分；两侧空白去掉；值两端的单/双引号去掉；CRLF 兼容。
- 节名、键名不区分大小写；未知节/键忽略；重复键后者覆盖。
- 空值视为未设置。
- `key` 的值以 `~` 开头时展开为 `$HOME`；文件不存在时 `remote.sh` 报错并提示 `key-init`。
- 不再有 `password` 键；出现 `password` 直接忽略并警告"密码路线已移除"。

## 3 生成物变化（15 → 18）

新增：

| 文件 | 作用 |
| --- | --- |
| `secrets.example` | 上面那份模板，两节案例，提交进仓库 |
| `tools/secrets.sh` | INI 解析库；只读、不执行、不打印值 |
| `tools/remote.sh` | 唯一入口：`check` / `key-init` / `git-push` / `ssh` / `rsync` |

同步修改：

- `.gitignore` 增加 `secrets.env` 与 `*.secrets`。
- `AGENTS.md` §6：远端操作只走 `tools/remote.sh`；私钥不读、不打印、不复制；缺文件就停。
- `ENVIRONMENTS.md` §6：路径、600、仓外、入口。
- `check.sh`：`secrets.example` 存在；`.gitignore` 挡 `secrets.env`；仓库内无 `secrets.env`；外部文件存在时 600（只 `stat`）。
- `SKILL.md`：new/adopt 末尾加"是否生成/使用 SSH 公钥"的问题与 `key-init`；提示 `cp/chmod`；常见错误加"把 token 或私钥贴进聊天/仓库"。

## 4 脚本契约

### 4.1 secrets.sh

source 进 `remote.sh`，不单独执行。提供：

- `secrets_project_root`、`secrets_path`。
- `secrets_load`：校验并解析，导出 `GIT_USER` / `GIT_TOKEN` / `SSH_HOST` / `SSH_USER` / `SSH_KEY` / `SSH_PORT` / `RSYNC_PATH`。
- 校验顺序：文件存在 → 属主是当前用户 → 权限 600 → 路径不在项目目录内 → 解析。
- 失败只报"哪个文件/哪个键"，不报值；退出码 1。

### 4.2 remote.sh

- `check`：校验文件、权限、两节必需键；输出 `file=ok`、`mode=600`、`git=ok|missing`、`ssh=ok|missing`、`rsync=ok|missing`，不输出值。
- `key-init [--path PATH]`：默认 `~/.ssh/id_ed25519`；私钥存在则读公钥（`.pub` 缺失时用 `ssh-keygen -y` 派生），不存在则 `ssh-keygen -t ed25519 -N ""` 生成；目录不存在时创建并 700；私钥 600、公钥 644；**只打印公钥**；拒绝覆盖；输出里给服务器端的 `authorized_keys` 追加命令。
- `git-push [参数...]`：默认 `origin HEAD`；token 经 `GIT_ASKPASS` 环境变量传递；`GIT_TERMINAL_PROMPT=0`；askpass 临时文件 700、`trap` 删除。
- `ssh "<命令>"`：必须 `SSH_KEY` 且文件存在；`ssh -i key -p port user@host cmd`。
- `rsync <src> [dst]`：用 ssh 的 host/user/port/key 组 `-e`；dst 缺省用 `RSYNC_PATH`。
- 退出码：0 成功；1 文件/校验/执行失败；2 用法错误。

## 5 安全护栏

- 解析不 `source`、不 `eval`；值不进命令行参数。
- 文件必须 600、属主为当前用户；路径在项目目录内则拒绝。
- 私钥永不打印、永不写入仓库、永不进 argv；公钥可以打印。
- 脚本 `set +x`；错误信息不含值；git 不弹交互密码。
- 密钥生成只在初始化时、由用户明确选择后执行；不覆盖已有密钥。
- `check.sh` 只 `stat` 外部文件，不读内容；仓库内出现 `secrets.env` 直接 FAIL。
- agent 规则：只调 `tools/remote.sh`；不 `cat` / `read` 密钥文件。

## 6 流程

- new / adopt 生成完，问用户：**是否要生成/使用 SSH 公钥？**
  - 是：跑 `bash tools/remote.sh key-init`，把公钥打印给用户，并给服务器命令（追加到 `~/.ssh/authorized_keys` 或 `ssh-copy-id` 由用户自己执行）。
  - 否：只打印密钥路径应写在哪（`[ssh] key = ~/.ssh/id_ed25519`）。
- 再打印：

~~~bash
mkdir -p ~/.config/project-constraints
cp secrets.example ~/.config/project-constraints/<项目>.env
chmod 600 ~/.config/project-constraints/<项目>.env
~~~

不自动创建仓外文件。

- `remote.sh check` 可随时自检；缺文件时 `check.sh` 只警告，不 FAIL。
- 本仓库：根目录放 `secrets.example`、`tools/secrets.sh`、`tools/remote.sh`；`.gitignore` 加两条；README 加"远端凭据"一节；仓库 `tools` 与模板逐字节一致（`cmp` 测试，安装后无仓库 `tools` 时跳过）。

## 7 验证

| 编号 | 检查 | 通过标准 |
| --- | --- | --- |
| V1 | 解析器 | 分节、注释、引号、CRLF、缺键、重复键、空值、`~` 展开都按规则 |
| V2 | 权限与位置 | 644、非本人、路径在项目内，三种都拒绝且不泄露值 |
| V3 | 凭据传递 | 假 git 记录 argv 与环境：token 只在环境/askpass，不在 argv；假 ssh 收到 `-i` |
| V4 | key-init | 临时路径生成 ed25519；只打印公钥与指纹；私钥 600；二次运行拒绝覆盖 |
| V5 | check | 缺 `secrets.example`、`.gitignore` 没挡、仓库内有 `secrets.env`、外部文件 644，四种都 FAIL |
| V6 | e2e | 生成项目 + 外部临时 secrets（600，带 key）+ 假 git 推送成功；删文件后报"缺文件" |
| V7 | 本仓库 | `tools/*` 与模板 `cmp` 一致；`key-init` 在临时路径可用 |
| V8 | 无泄露 | 所有脚本输出里 grep 不到测试用的 token；也 grep 不到 `PRIVATE KEY` |

## 8 明确不做

- SSH 密码、`sshpass`、密码字段。
- 密码管理器、加密文件、自动把公钥安装到服务器。
- 改全局 credential helper 或 `~/.ssh/config`。

## 9 取舍

- 只允许密钥：去掉 `sshpass` 依赖与密码落盘风险；代价是服务器必须先有公钥。
- 初始化时可选生成公钥：不用记命令；代价是多一次询问，且生成是无口令密钥（自动化需要）。
- 选仓外文件而不是仓库内 gitignored：避免误提交；代价是每台机器单独填。
- 选 INI 而不是 `KEY=VALUE` + `source`：拒绝代码执行；代价是多一个解析器要测。
