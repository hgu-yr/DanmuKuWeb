#!/usr/bin/env bash
#
# 校验 README 里提到的 DANMAKU_* 环境变量都出现在 DanmuKuWeb-Server/.env.example。
# 只在文档新增变量却忘了同步模板时失败，不检查默认值是否一致。
#
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
README="$ROOT/README.md"
ENV_EXAMPLE="$ROOT/DanmuKuWeb-Server/.env.example"

doc_vars="$(grep -oE 'DANMAKU_[A-Z_]+' "$README" | sort -u || true)"
env_vars="$(grep -oE '^DANMAKU_[A-Z_]+' "$ENV_EXAMPLE" | sort -u || true)"

missing="$(comm -23 <(printf '%s\n' "$doc_vars") <(printf '%s\n' "$env_vars"))"

if [ -n "$missing" ]; then
  echo "README 提到但 .env.example 缺少的环境变量："
  echo "$missing" | sed 's/^/  - /'
  exit 1
fi

echo "README 与 .env.example 的 DANMAKU_* 变量一致"
