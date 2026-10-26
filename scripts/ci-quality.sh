#!/usr/bin/env bash
#
# 本地/CI 共用的代码质检脚本。
# 生成 markdown 报告（默认 quality-report.md），阻断项失败时以非零退出。
#
# 用法：
#   ./scripts/ci-quality.sh
#   REPORT=/tmp/report.md ./scripts/ci-quality.sh
#
set -u

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REPORT="${REPORT:-$ROOT/quality-report.md}"
FAIL=0

: > "$REPORT"
{
  echo "# 代码质检报告"
  echo ""
  echo "- 提交：\`${GITHUB_SHA:-$(git -C "$ROOT" rev-parse --short HEAD 2>/dev/null || echo unknown)}\`"
  echo "- 时间：$(date -u '+%Y-%m-%d %H:%M:%S UTC')"
  echo ""
} >> "$REPORT"

run_check() {
  local name="$1" mode="$2"
  shift 2

  local log
  log="$(mktemp)"
  if "$@" >"$log" 2>&1; then
    printf -- "- ✅ **%s**\n" "$name" >> "$REPORT"
  else
    printf -- "- ❌ **%s**\n" "$name" >> "$REPORT"
    {
      echo ""
      echo "<details><summary>查看输出</summary>"
      echo ""
      echo '```'
      tail -n 60 "$log"
      echo '```'
      echo ""
      echo "</details>"
      echo ""
    } >> "$REPORT"
    if [ "$mode" = "block" ]; then
      FAIL=1
    fi
  fi
  rm -f "$log"
}

echo "## 后端" >> "$REPORT"
run_check "go build" block bash -c "cd '$ROOT/DanmuKuWeb-Server' && go build ./..."
run_check "go vet" block bash -c "cd '$ROOT/DanmuKuWeb-Server' && go vet ./..."
run_check "go test" block bash -c "cd '$ROOT/DanmuKuWeb-Server' && go test ./..."

if command -v staticcheck >/dev/null 2>&1; then
  run_check "staticcheck" warn bash -c "cd '$ROOT/DanmuKuWeb-Server' && staticcheck ./..."
else
  echo "- ⏭️ **staticcheck**（未安装，跳过）" >> "$REPORT"
fi

if command -v govulncheck >/dev/null 2>&1; then
  run_check "govulncheck" warn bash -c "cd '$ROOT/DanmuKuWeb-Server' && govulncheck ./..."
else
  echo "- ⏭️ **govulncheck**（未安装，跳过）" >> "$REPORT"
fi

echo "" >> "$REPORT"
echo "## 前端" >> "$REPORT"
run_check "npm ci" block bash -c "cd '$ROOT/DanmuKuWeb-Web' && npm ci --no-audit --no-fund"
run_check "vue-tsc" block bash -c "cd '$ROOT/DanmuKuWeb-Web' && npm run type-check"
run_check "vite build" block bash -c "cd '$ROOT/DanmuKuWeb-Web' && npm run build"
run_check "npm audit (prod)" warn bash -c "cd '$ROOT/DanmuKuWeb-Web' && npm audit --omit=dev"

echo "" >> "$REPORT"
if [ "$FAIL" -eq 0 ]; then
  echo "**结论：通过**" >> "$REPORT"
else
  echo "**结论：存在阻断项，请修复后重试。**" >> "$REPORT"
fi

if [ -n "${GITHUB_STEP_SUMMARY:-}" ]; then
  cat "$REPORT" >> "$GITHUB_STEP_SUMMARY"
fi

if [ "$FAIL" -ne 0 ]; then
  echo "质量检查未通过，详见 $REPORT" >&2
fi
exit "$FAIL"
