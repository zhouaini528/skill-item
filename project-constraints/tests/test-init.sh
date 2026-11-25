#!/usr/bin/env bash
set -uo pipefail
T="$(cd "$(dirname "$0")/.." && pwd)"
D="$T/.scratch/init"; rm -rf "$D"; mkdir -p "$D"
fail=0
ok()  { printf 'ok   %s\n' "$1"; }
bad() { printf 'FAIL %s\n' "$1"; fail=1; }
out=$(bash "$T/scripts/init.sh" --target "$D/p" --name "示例项目" --one-liner "一句话" --stack "TS" 2>&1); rc=$?
[[ $rc -eq 0 && "$out" == *"将创建"* ]] && ok "dry-run 预览" || bad "dry-run 退出或输出: rc=$rc"
[[ -z "$(ls -A "$D/p" 2>/dev/null)" ]] && ok "dry-run 不落盘" || bad "dry-run 写了文件"
bash "$T/scripts/init.sh" --target "$D/p" --name "示例项目" --one-liner "一句话" --stack "TS" --apply
[[ "$(find "$D/p" -type f | wc -l)" -eq 15 ]] && ok "15 个文件" || bad "文件数"
! grep -rq '{{' "$D/p" && ok "无残留" || bad "有残留"
[[ "$(stat -c %a "$D/p/env")" == "600" ]] && ok "env 600" || bad "env 权限"
grep -q '^/env$' "$D/p/.gitignore" && ok "忽略 env" || bad "未忽略 env"
out=$(bash "$T/scripts/init.sh" --target "$D/p" --name x --one-liner y --stack z --apply 2>&1); rc=$?
[[ $rc -ne 0 && "$out" == *"已存在"* ]] && ok "拒绝覆盖" || bad "未拒绝: rc=$rc"
bash "$T/scripts/init.sh" --target "$D/带 空格/项目" --name n --one-liner o --stack 'A & B | C / D' --apply
[[ -f "$D/带 空格/项目/AGENTS.md" ]] && ok "空格中文路径" || bad "空格中文路径"
grep -qF 'A & B | C / D' "$D/带 空格/项目/AGENTS.md" && ok "特殊字符原样" || bad "特殊字符被破坏"
exit "$fail"
