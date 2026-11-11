#!/usr/bin/env bash
#
# 校验文档里提到的 DANMAKU_* 环境变量都出现在 DanmuKuWeb-Server/.env.example。
# 扫描仓库内所有 markdown（含子模块 README），只在「文档新增变量却忘了同步模板」
# 时失败，不检查默认值是否一致。
#
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENV_EXAMPLE="$ROOT/DanmuKuWeb-Server/.env.example"

if [ ! -f "$ENV_EXAMPLE" ]; then
  echo "缺少文件：$ENV_EXAMPLE（子模块是否已初始化？）" >&2
  exit 1
fi

doc_vars="$(
  find "$ROOT" -name '*.md' \
    -not -path '*/node_modules/*' \
    -not -path '*/dist/*' \
    -not -path '*/.git/*' \
    -print0 |
    xargs -0 perl -ne 'while (/(?<![A-Z0-9_])(DANMAKU_[A-Z0-9_]+)/g) { print "$1\n" }' |
    sort -u
)"
env_vars="$(grep -oE '^DANMAKU_[A-Z0-9_]+' "$ENV_EXAMPLE" | sort -u || true)"

missing="$(comm -23 <(printf '%s\n' "$doc_vars") <(printf '%s\n' "$env_vars"))"

if [ -n "$missing" ]; then
  echo "文档提到但 .env.example 缺少的环境变量："
  echo "$missing" | sed 's/^/  - /'
  exit 1
fi

echo "文档与 .env.example 的 DANMAKU_* 变量一致"
