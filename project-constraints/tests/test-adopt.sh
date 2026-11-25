#!/usr/bin/env bash
set -uo pipefail
T="$(cd "$(dirname "$0")/.." && pwd)"
W="$T/.scratch/adopt"; rm -rf "$W"; mkdir -p "$W/existing/src" "$W/scan" "$W/bad"
printf '# AGENTS\n- 规则一\n- 直接 push main\n' > "$W/existing/AGENTS.md"
h1=$(sha256sum "$W/existing/AGENTS.md" | cut -d' ' -f1)
fail=0
ok()  { printf 'ok   %s\n' "$1"; }
bad() { printf 'FAIL %s\n' "$1"; fail=1; }

bash "$T/scripts/adopt.sh" --target "$W/existing" --report "$W/r1.md" >/dev/null 2>&1
[[ -f "$W/r1.md" ]] && ok "出报告" || bad "无报告"
[[ "$(find "$W/existing" -type f | wc -l)" -eq 1 ]] && ok "报告不写文件" || bad "报告阶段写了文件"
grep -q '^## 已有（跳过）$' "$W/r1.md" && ok "已有小节" || bad "缺已有小节"
grep -q 'AGENTS.md' "$W/r1.md" && ok "列出已有文件" || bad "未列出已有文件"
grep -q '^## 冲突裁决$' "$W/r1.md" && ok "冲突小节" || bad "缺冲突小节"

bash "$T/scripts/adopt.sh" --target "$W/existing" --scan standard --apply >/dev/null 2>&1
[[ "$(find "$W/existing" -type f | wc -l)" -eq 15 ]] && ok "补齐 15 个" || bad "文件数"
h2=$(sha256sum "$W/existing/AGENTS.md" | cut -d' ' -f1)
[[ "$h1" == "$h2" ]] && ok "已有文件未改" || bad "已有文件被改"
grep -q '^ENV=unknown$' "$W/existing/env" && ok "env 默认 unknown" || bad "env 默认值"

mkdir -p "$W/envcase"
bash "$T/scripts/adopt.sh" --target "$W/envcase" --scan quick --apply --name X --one-liner Y --stack Z --env testing --role app >/dev/null 2>&1
grep -q '^ENV=testing$' "$W/envcase/env" && ok "env 参数生效" || bad "env 参数未生效"

touch "$W/scan/.cursorrules"
bash "$T/scripts/adopt.sh" --target "$W/scan" --scan quick --report "$W/rq.md" >/dev/null 2>&1
! grep -q 'cursorrules' "$W/rq.md" && ok "quick 不扫 cursorrules" || bad "quick 扫了 cursorrules"
bash "$T/scripts/adopt.sh" --target "$W/scan" --scan standard --report "$W/rs.md" >/dev/null 2>&1
grep -q 'cursorrules' "$W/rs.md" && ok "standard 扫 cursorrules" || bad "standard 漏 cursorrules"

bash "$T/scripts/adopt.sh" --target "$W/bad" --scan nope >/dev/null 2>&1; [[ $? -eq 2 ]] && ok "非法 scan 退出 2" || bad "非法 scan 退出码"
bash "$T/scripts/adopt.sh" --target "$W/nope" --report "$W/r3.md" >/dev/null 2>&1; [[ $? -eq 1 ]] && ok "目标不存在退出 1" || bad "目标不存在退出码"
exit "$fail"
