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
assert_grep "环境声明频率" "$T/templates/AGENTS.md.tmpl" '会话第一条'
assert_grep "扩范围例子" "$T/templates/AGENTS.md.tmpl" '改 API 契约'
assert_grep "归档条件" "$T/templates/AGENTS.md.tmpl" '若存在'
assert_grep "spec 目标区间" "$T/templates/AGENTS.md.tmpl" '300–600'
assert_grep "提交不批量重排" "$T/templates/AGENTS.md.tmpl" '不批量重排'
assert_grep "提交带锚点" "$T/templates/AGENTS.md.tmpl" '锚点'
assert_grep "TDD 例外" "$T/templates/AGENTS.md.tmpl" '纯文档或配置'
assert_grep "凭据唯一出处" "$T/templates/ENVIRONMENTS.md.tmpl" '唯一出处'
assert_grep "C 编号规则" "$T/templates/docs/decisions/README.md.tmpl" '临时号'
assert_grep "决策索引校验" "$T/templates/docs/decisions/README.md.tmpl" 'check.sh'
assert_grep "证据不设下限" "$T/templates/docs/evidence/README.md.tmpl" '不设 300'
assert_grep "出处地图示例" "$T/templates/docs/spec/README.md.tmpl" '术语、目标与范围'
assert_no_grep "AGENTS 无旧项目残留" "$T/templates/AGENTS.md.tmpl" 'QTV|trader-plan2|43\.106\.83\.160|AutoTrader|\.qtv-env'

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
assert_grep "冲突登记有落点" "$T/templates/docs/decisions/README.md.tmpl" 'C-xxx'

if grep -rqE 'QTV|trader-plan2|43\.106\.83\.160|AutoTrader|\.qtv-env' "$T" --exclude-dir=tests --exclude-dir=.scratch; then
  bad "包内旧项目标识"
else
  ok "包内无旧项目标识"
fi

got=$(grep -rhoE '\{\{[A-Z_]+\}\}' "$T/templates" | LC_ALL=C sort -u | tr '\n' ' ')
want='{{DATE}} {{ONE_LINER}} {{PROJECT_NAME}} {{STACK}} '
[[ "$got" == "$want" ]] && ok "变量集合" || bad "变量集合: $got"
exit "$fail"
