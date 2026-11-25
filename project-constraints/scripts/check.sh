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

status_ok=1
for h in "## 最近变更" "## 下一步" "## 待裁决 / 阻塞" "## 环境快照"; do
  if ! grep -qxF "$h" "$DIR/STATUS.md" 2>/dev/null; then bad "STATUS 缺 $h"; status_ok=0; fi
done
if [ "$status_ok" -eq 1 ]; then ok "STATUS 结构完整"; fi

section_has_value() {
  local file=$1 heading=$2 line on=0 val total=0 filled=0
  while IFS= read -r line; do
    if [ "$line" = "$heading" ]; then on=1; continue; fi
    case "$line" in "## "*) on=0 ;; esac
    if [ "$on" -eq 1 ]; then
      case "$line" in
        "- "*)
          total=$((total+1))
          val=${line#*：}
          if [ "$val" != "$line" ]; then
            val=${val#"${val%%[![:space:]]*}"}
            if [ -n "$val" ]; then filled=$((filled+1)); fi
          fi
          ;;
      esac
    fi
  done < "$file"
  [ "$total" -gt 0 ] && [ "$filled" -eq "$total" ]
}

if section_has_value "$DIR/ENVIRONMENTS.md" "## 7 验证位置"; then ok "§7 验证位置已填"; else bad "§7 验证位置未填"; fi
if section_has_value "$DIR/ENVIRONMENTS.md" "## 8 本项目事实"; then ok "§8 本项目事实已填"; else bad "§8 本项目事实未填"; fi

index_ok=1
for f in "$DIR"/docs/decisions/D-*.md; do
  [ -f "$f" ] || continue
  b=$(basename "$f" .md)
  if ! grep -qF "$b" "$DIR/docs/decisions/README.md" 2>/dev/null; then bad "决策索引缺 $b"; index_ok=0; fi
done
if [ "$index_ok" -eq 1 ]; then ok "决策索引齐全"; fi

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