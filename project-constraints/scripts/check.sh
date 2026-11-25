#!/usr/bin/env bash
set -uo pipefail

DIR=${1:-.}
fail=0
ok() { printf 'ok   %s\n' "$1"; }
bad() { printf 'FAIL %s\n' "$1"; fail=1; }

FILES="AGENTS.md ENVIRONMENTS.md STATUS.md README.md env env.example .gitignore docs/spec/README.md docs/spec/00-overview.md docs/decisions/README.md docs/decisions/D-001.md docs/evidence/README.md docs/ops/README.md tools/env.sh tools/check-links.sh"

missing=0
for f in $FILES; do
  if [ ! -f "$DIR/$f" ]; then bad "缺文件 $f"; missing=$((missing+1)); fi
done
if [ "$missing" -eq 0 ]; then ok "文件齐全（15）"; fi

if grep -rqE '\{\{' "$DIR" --exclude-dir=.git --exclude-dir=node_modules --exclude-dir=vendor 2>/dev/null; then
  bad "存在 {{ }} 残留"
  grep -rlE '\{\{' "$DIR" --exclude-dir=.git --exclude-dir=node_modules --exclude-dir=vendor 2>/dev/null | head -5 | sed 's/^/     /'
else
  ok "无占位符残留"
fi

if ls "$DIR"/docs/decisions/D-*.md >/dev/null 2>&1; then
  ok "有决策记录"
else
  bad "缺 docs/decisions/D-*.md"
fi

if [ -f "$DIR/env" ]; then
  e=$(sed -n 's/^ENV=//p' "$DIR/env" | head -1)
  case "$e" in
    local|testing|staging|prod) ok "env 合法（$e）" ;;
    *) bad "env 非法（$e）" ;;
  esac
fi

if [ -f "$DIR/tools/check-links.sh" ]; then
  out=$(bash "$DIR/tools/check-links.sh" "$DIR" 2>&1); rc=$?
  if [ "$rc" -eq 0 ]; then
    ok "链接检查通过"
  else
    bad "存在断链"
    printf '%s\n' "$out" | sed 's/^/     /'
  fi
fi

printf '\n'
if [ "$fail" -eq 0 ]; then
  printf 'check: OK\n'
  exit 0
fi
printf 'check: FAIL\n'
exit 1
