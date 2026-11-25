#!/usr/bin/env bash
set -uo pipefail
T="$(cd "$(dirname "$0")/.." && pwd)"
W="$T/.scratch/tools"; rm -rf "$W"; mkdir -p "$W/p1/tools" "$W/p1/sub"
cp "$T/templates/tools/env.sh.tmpl" "$W/p1/tools/env.sh"
cp "$T/templates/tools/check-links.sh.tmpl" "$W/p1/tools/check-links.sh"
chmod +x "$W/p1/tools/"*.sh
fail=0
ok()  { printf 'ok   %s\n' "$1"; }
bad() { printf 'FAIL %s\n' "$1"; fail=1; }

out=$(cd "$W/p1/sub" && bash ../tools/env.sh); rc=$?
[[ $rc -eq 1 && "$out" == *"ENV=unknown"* ]] && ok "未知环境" || bad "未知环境: rc=$rc"

printf 'ENV=testing\nROLE=app\nROOT=/srv/p1\n' > "$W/p1/env"
out=$(cd "$W/p1/sub" && bash ../tools/env.sh); rc=$?
[[ $rc -eq 0 && "$out" == *"ENV=testing"* ]] && ok "已知环境" || bad "已知环境: rc=$rc"

printf 'ENV=foo\nROLE=app\nROOT=/srv/p1\n' > "$W/p1/env"
out=$(cd "$W/p1/sub" && bash ../tools/env.sh); rc=$?
[[ $rc -eq 1 && "$out" == *"ENV=unknown"* ]] && ok "非法环境" || bad "非法环境: rc=$rc"

printf 'x\n' > "$W/p1/a.md"; printf '[b](b.md)\n' > "$W/p1/b.md"
(cd "$W/p1" && bash tools/check-links.sh . >/dev/null); rc=$?
[[ $rc -eq 0 ]] && ok "链接正常" || bad "链接正常: rc=$rc"
printf '[c](missing.md)\n' >> "$W/p1/a.md"
(cd "$W/p1" && bash tools/check-links.sh . >/dev/null); rc=$?
[[ $rc -eq 1 ]] && ok "断链" || bad "断链: rc=$rc"
exit "$fail"
