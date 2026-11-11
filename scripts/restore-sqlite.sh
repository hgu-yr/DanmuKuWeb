#!/usr/bin/env bash
#
# 从 SQLite 快照恢复数据库。
#
# 用法：
#   ./scripts/restore-sqlite.sh <backup.db> [target.db]
#
# 注意：
#   1. 先停止 server（Docker: docker compose stop server），避免恢复过程中仍有写入；
#   2. 脚本会先把当前数据库另存为 *.before-restore.<时间戳>；
#   3. 恢复后重启 server（Docker: docker compose start server）。
set -euo pipefail

BACKUP="${1:?用法: $0 <backup.db> [target.db]}"
TARGET="${2:-data/danmuku.db}"

if [[ ! -f "$BACKUP" ]]; then
  echo "备份不存在: $BACKUP" >&2
  exit 1
fi

mkdir -p "$(dirname "$TARGET")"

if [[ -f "$TARGET" ]]; then
  SAFE="$TARGET.before-restore.$(date +%Y%m%d-%H%M%S)"
  cp "$TARGET" "$SAFE"
  echo "已保留当前数据库: $SAFE"
fi

# WAL / SHM 是当前数据库的运行时文件，恢复前必须移除
rm -f "${TARGET}-wal" "${TARGET}-shm"
cp "$BACKUP" "$TARGET"
chmod 600 "$TARGET"

echo "恢复完成: $BACKUP -> $TARGET"
echo "请重启 server；Docker 部署可执行: docker compose start server"
