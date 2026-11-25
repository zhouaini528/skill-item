#!/usr/bin/env bash
set -uo pipefail
T="$(cd "$(dirname "$0")/.." && pwd)"
R="$(cd "$T/.." && pwd)"
D="$R/.scratch/check"; rm -rf "$D"; mkdir -p "$D"
fail=0
ok()  { printf 'ok   %s\n' "$1"; }
bad() { printf 'FAIL %s\n' "$1"; fail=1; }
gen() { rm -rf "$1"; bash "$T/scripts/init.sh" --target "$1" --name x --one-liner y --stack z --apply >/dev/null; }

gen "$D/a"
out=$(bash "$T/scripts/check.sh" "$D/a" 2>&1); rc=$?
[[ $rc -eq 0 ]] && ok "正常项目" || bad "正常项目: $out"

gen "$D/b"; rm "$D/b/docs/evidence/README.md"
out=$(bash "$T/scripts/check.sh" "$D/b" 2>&1); rc=$?
[[ $rc -ne 0 && "$out" == *"FAIL"* ]] && ok "缺文件" || bad "缺文件未报: rc=$rc"

gen "$D/c"; printf '{{NAME}}\n' >> "$D/c/AGENTS.md"
out=$(bash "$T/scripts/check.sh" "$D/c" 2>&1); rc=$?
[[ $rc -ne 0 && "$out" == *"FAIL"* ]] && ok "占位符" || bad "占位符未报: rc=$rc"

gen "$D/d"; printf '[x](missing.md)\n' >> "$D/d/README.md"
out=$(bash "$T/scripts/check.sh" "$D/d" 2>&1); rc=$?
[[ $rc -ne 0 && "$out" == *"FAIL"* ]] && ok "断链" || bad "断链未报: rc=$rc"

gen "$D/e"; rm "$D/e/docs/decisions/D-001.md"
out=$(bash "$T/scripts/check.sh" "$D/e" 2>&1); rc=$?
[[ $rc -ne 0 && "$out" == *"FAIL"* ]] && ok "缺决策" || bad "缺决策未报: rc=$rc"

gen "$D/f"; sed -i 's/^ROLE=.*/ROLE=hacker/' "$D/f/env"
out=$(bash "$T/scripts/check.sh" "$D/f" 2>&1); rc=$?
[[ $rc -ne 0 && "$out" == *"ROLE 非法"* ]] && ok "非法 ROLE" || bad "非法 ROLE 未报"

gen "$D/g"; sed -i 's|^ROOT=.*|ROOT=|' "$D/g/env"
out=$(bash "$T/scripts/check.sh" "$D/g" 2>&1); rc=$?
[[ $rc -ne 0 && "$out" == *"ROOT"* ]] && ok "空 ROOT" || bad "空 ROOT 未报"

gen "$D/h"; chmod 644 "$D/h/env"
out=$(bash "$T/scripts/check.sh" "$D/h" 2>&1); rc=$?
[[ $rc -ne 0 && "$out" == *"权限"* ]] && ok "env 权限" || bad "env 权限未报"

gen "$D/i"; grep -v '^/env$' "$D/i/.gitignore" > "$D/i/.gitignore.tmp"; mv "$D/i/.gitignore.tmp" "$D/i/.gitignore"
out=$(bash "$T/scripts/check.sh" "$D/i" 2>&1); rc=$?
[[ $rc -ne 0 && "$out" == *".gitignore"* ]] && ok "缺 /env" || bad "缺 /env 未报"

gen "$D/j"; mkdir -p "$D/j/src"; printf '{{TOKEN}}\n' > "$D/j/src/t.txt"
out=$(bash "$T/scripts/check.sh" "$D/j" 2>&1); rc=$?
[[ $rc -eq 0 ]] && ok "用户文件里的占位符不算" || bad "误报用户文件: $out"

exit "$fail"
