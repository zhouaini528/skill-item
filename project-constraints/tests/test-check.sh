#!/usr/bin/env bash
set -uo pipefail
T="$(cd "$(dirname "$0")/.." && pwd)"
D="$T/.scratch/check"; rm -rf "$D"; mkdir -p "$D"
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

exit "$fail"
