#!/usr/bin/env bash
#
# 同时启动前后端开发服务，Ctrl-C 一并退出。
#
# 退出时会递归结束子进程树（go run 会派生出 server，npm 会派生出 vite），
# 避免留下孤儿进程占着 8080 / 5173 端口。
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

SERVER_PID=""
WEB_PID=""
STOPPING=0

# kill_tree 先递归结束后代，再结束自己
kill_tree() {
  local pid="$1" child
  for child in $(pgrep -P "$pid" 2>/dev/null || true); do
    kill_tree "$child"
  done
  kill -TERM "$pid" 2>/dev/null || true
}

cleanup() {
  [ "$STOPPING" = 1 ] && return
  STOPPING=1
  trap - INT TERM EXIT

  echo
  echo "[dev] 正在停止服务 ..."
  for pid in "$SERVER_PID" "$WEB_PID"; do
    [ -n "$pid" ] && kill_tree "$pid"
  done

  # 给子进程一点退出时间，仍未退出的强制结束
  for _ in 1 2 3 4 5 6; do
    alive=0
    for pid in "$SERVER_PID" "$WEB_PID"; do
      [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null && alive=1
    done
    [ "$alive" = 0 ] && break
    sleep 0.5
  done
  for pid in "$SERVER_PID" "$WEB_PID"; do
    [ -n "$pid" ] && kill -KILL "$pid" 2>/dev/null
  done

  echo "[dev] 已退出"
}

trap cleanup INT TERM EXIT

# 启动前检查端口：后端端口被占用时会直接启动失败，先给出明确提示
SERVER_PORT="${APP_PORT:-8080}"
if lsof -ti ":$SERVER_PORT" -sTCP:LISTEN >/dev/null 2>&1; then
  echo "[dev] 端口 $SERVER_PORT 已被占用，后端无法启动。占用进程："
  lsof -i ":$SERVER_PORT" -sTCP:LISTEN -P -n 2>/dev/null | tail -n +2 | sed 's/^/       /'
  echo "[dev] 先停掉它再重试，例如：  lsof -ti :$SERVER_PORT | xargs kill"
  trap - EXIT
  exit 1
fi

if lsof -ti :5173 -sTCP:LISTEN >/dev/null 2>&1; then
  echo "[dev] 提示：端口 5173 已被占用，Vite 会自动改用其它端口（看它输出的 Local 地址）"
fi

( cd "$ROOT/DanmuKuWeb-Server" && exec go run ./cmd/server ) &
SERVER_PID=$!

( cd "$ROOT/DanmuKuWeb-Web" && exec npm run dev ) &
WEB_PID=$!

echo "[dev] 后端 http://localhost:8080   前端 http://localhost:5173   (Ctrl-C 退出)"
echo "[dev] 后台账号密码见后端日志里的 [auth] 行"

wait
