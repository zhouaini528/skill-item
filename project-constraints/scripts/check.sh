#!/usr/bin/env bash
set -uo pipefail

DIR=.
if [ $# -gt 0 ]; then DIR=$1; fi
fail=0
ok() { printf 'ok   %s\n' "$1"; }
bad() { printf 'FAIL %s\n' "$1"; fail=1; }

FILES="AGENTS.md ENVIRONMENTS.md STATUS.md README.md env env.example .gitignore docs/spec/README.md docs/spec/00-overview.md docs/decisions/README.md docs/decisions/D-001.md docs/evidence/README.md docs/ops/README.md tools/env.sh tools/check-links.sh"

missing=0
for f in $FILES; do
  if [ ! -f "$DIR/$f" ]; then bad "缺文件 $f"; missing=$((missing+1)); fi
done
if [ "$missing" -eq 0 ]; then ok "文件齐全（15）"; fi

placeholder=0
for f in $FILES; do
  if [ -f "$DIR/$f" ] && grep -qE '\{\{' "$DIR/$f"; then
    bad "占位符残留 $f"
    placeholder=$((placeholder+1))
  fi
done
if [ "$placeholder" -eq 0 ]; then ok "无占位符残留"; fi

if ls "$DIR"/docs/decisions/D-*.md >/dev/null 2>&1; then
  ok "有决策记录"
else
  bad "缺 docs/decisions/D-*.md"
fi

if [ -f "$DIR/env" ]; then
  kv() {
    sed -n "s/^[[:space:]]*\(export[[:space:]]\+\)\?$1[[:space:]]*=[[:space:]]*//p" "$DIR/env" \
      | head -n1 | sed -e 's/[[:space:]]*$//' -e 's/^"//' -e 's/"$//'
  }
  e=$(kv ENV); r=$(kv ROLE); rt=$(kv ROOT)
  case "$e" in local|testing|staging|prod) ok "ENV=$e" ;; *) bad "ENV 非法（$e）" ;; esac
  case "$r" in authoring|app|ci) ok "ROLE=$r" ;; *) bad "ROLE 非法（$r）" ;; esac
  case "$rt" in /*) ok "ROOT 是绝对路径" ;; *) bad "ROOT 不是绝对路径（$rt）" ;; esac
  mode=$(stat -c %a "$DIR/env" 2>/dev/null || printf '?')
  if [ "$mode" = "600" ]; then ok "env 权限 600"; else bad "env 权限（$mode）"; fi
  if grep -qx '/env' "$DIR/.gitignore" 2>/dev/null; then ok ".gitignore 忽略 /env"; else bad ".gitignore 缺 /env"; fi
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
