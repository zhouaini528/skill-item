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
