# 弹幕库 · DanmuKuWeb

一个**上班摸鱼发弹幕**的网站。打开页面就能发弹幕、看别人的弹幕实时滚过屏幕。

> 当前版本只做一件事：**发弹幕**（前后端分离，实时广播）。

## 组成

| 目录 | 仓库 | 说明 |
| --- | --- | --- |
| [`DanmuKuWeb-Server`](./DanmuKuWeb-Server) | `hgu-yr/DanmuKuWeb-Server` | 后端：Go + Gin + WebSocket，提供弹幕接口、实时广播与过滤引擎（submodule） |
| [`DanmuKuWeb-Web`](./DanmuKuWeb-Web) | `hgu-yr/DanmuKuWeb-Web` | 前端：Vue 3 + Vite + TypeScript，弹幕墙 + 独立的管理后台入口（submodule） |

两个子项目通过 **git submodule** 引用，根仓库只放 Makefile、脚本与文档（见文末「仓库结构」）。

## 架构

```
┌────────────────────┐        HTTP  POST /api/v1/danmaku        ┌──────────────────────┐
│   DanmuKuWeb-Web   │ ───────────────────────────────────────▶ │  DanmuKuWeb-Server   │
│  (Vue3 + Vite)     │ ◀─────────────────────────────────────── │   (Go + Gin)         │
│                    │        WebSocket  /ws  (实时弹幕)          │                      │
└────────────────────┘                                          └──────────────────────┘
        ▲                                                                  │
        └──────────────── 广播给所有在线客户端 ◀────────────────────────────┘
```

- 发送弹幕：前端 `POST /api/v1/danmaku` → 后端写内存并写穿 SQLite → 通过 WebSocket 广播给所有在线客户端
- 进入页面：前端 `GET /api/v1/danmaku` 拉取最近历史弹幕做回放，然后连接 `/ws` 接收实时弹幕
- 重启恢复：启动时从 `danmaku` 表加载未过期弹幕，重启后仍能回放（详见下方「弹幕持久化」的已知限制）

### 弹幕持久化

- SQLite 默认 `data/danmuku.db`（`DB_PATH`）；Docker 部署需挂载 `danmuku-data` 卷
- 写穿失败只记日志，内存热数据仍可广播，不阻塞发弹幕
- 普通弹幕 TTL `DANMAKU_TTL`（默认 2h），私密回复 `DANMAKU_REPLY_TTL`（默认 7d）
- 已知限制：点赞者去重集合不落库，重启后同一用户可再次点赞；点赞数会保留
- 以上变量都在 `.env.example` / `docker-compose.yml` 中配置，详见「Docker 部署」章节

## 本地启动

在**仓库根目录**（本文件所在目录）提供了统一的 Makefile：

```bash
make run      # 前后端一起启动，Ctrl-C 一并退出
```

也可以分开启动、或用其他命令：

```bash
make server   # 仅后端（默认 :8080）
make web      # 仅前端（默认 :5173）
make test     # 后端测试
make build    # 生产构建：后端 -> DanmuKuWeb-Server/bin，前端 -> DanmuKuWeb-Web/dist
```

想手动分两个终端跑：

```bash
# 1) 后端（默认 :8080）
cd DanmuKuWeb-Server
go mod tidy
go run ./cmd/server

# 2) 前端（默认 :5173）
cd ../DanmuKuWeb-Web
npm install
npm run dev
```

打开 http://localhost:5173 即可发弹幕（Vite 已把 `/api` 与 `/ws` 代理到后端）。

> 后端只读环境变量，**不会自动加载 `.env` 文件**。想用配置文件的话：
> ```bash
> cp DanmuKuWeb-Server/.env.example DanmuKuWeb-Server/.env
> set -a && source DanmuKuWeb-Server/.env && set +a
> make server
> ```

## Docker 部署

```bash
cp .env.example .env
# 必改：ADMIN_PASSWORD、ALLOWED_ORIGINS（生产填真实域名）
docker compose up -d --build
```

- `web` 容器监听 `WEB_PORT`（默认 80），托管前端并把 `/api`、`/ws` 反代到 `server`
- `server` 不对外暴露 8080，SQLite 数据放在 `danmuku-data` 命名卷
- 更新：`git pull && git submodule update --init --recursive && docker compose up -d --build`
- 自动备份：server 默认每天用 SQLite `VACUUM INTO` 生成一致性快照到 `data/backups/`，
  保留最近 7 份；可用 `BACKUP_DIR` / `BACKUP_INTERVAL` / `BACKUP_KEEP` 调整。
- Docker 恢复：先 `docker compose stop server`，快照在 `danmuku-data` 数据卷的
  `/app/data/backups/` 内，按下面方式在卷内操作，避免恢复到宿主机错误路径：
  ```bash
  docker run --rm -v danmuku_danmuku-data:/data alpine ls -lt /data/backups | head
  docker run --rm -v danmuku_danmuku-data:/data alpine sh -c 'set -e
    if [ -f /data/danmuku.db ]; then cp /data/danmuku.db /data/danmuku.db.before-restore.$(date +%s); fi
    rm -f /data/danmuku.db-wal /data/danmuku.db-shm
    cp /data/backups/<快照>.db /data/danmuku.db'
  docker compose start server
  ```
- 非 Docker 部署：`./scripts/restore-sqlite.sh <快照>.db <target.db>`，
  脚本会校验 SQLite 文件头并保留当前库副本
- 手动备份数据卷：
  ```bash
  docker run --rm -v danmuku_danmuku-data:/data -v "$PWD":/backup alpine \
    tar czf /backup/danmuku-data.tar.gz -C /data .
  ```
- 需要地区统计时，把 `ip2region.xdb` 放到 `./data/`，并取消 compose 里的只读挂载注释
- 生产建议在 web 前再加一层 HTTPS 反向代理（Caddy / Traefik / Nginx），并确保
  `ALLOWED_ORIGINS` 与实际域名一致

## 观测

- `GET /health`：liveness，只证明进程能应答
- `GET /readyz`：readiness，额外 ping SQLite，失败返回 503
- `GET /metrics`：Prometheus 指标（HTTP 延迟、WS 连接/丢弃、弹幕事件、LLM 延迟/跳过）
- 日志：JSON（slog），包含 `request_id`、`route`、`status`、`latency_ms`
- `server` 端口不对公网发布，`/metrics` 只在容器网络内可访问

## CI 与代码质检

`.github/workflows/ci.yml` 包含：

1. **代码质检**：Go `build` / `vet` / `test`、`staticcheck`、`govulncheck`；
   前端 `npm ci`、`eslint`、`vitest`、`vue-tsc`、`vite build`、`npm audit`
2. **Docker 构建**：构建 server / web 镜像，并校验 `docker compose config`
3. **PR 评论**：质检和 Docker 结果自动汇总到 PR 评论（同一条评论更新，不刷屏）
4. **镜像发布**：`main` 分支通过后推送 `ghcr.io/<owner>/danmuku-server` 与
   `ghcr.io/<owner>/danmuku-web`

职责划分：

- **GitHub Actions** 是权威质量门禁：staticcheck / govulncheck / Docker / 镜像发布
- **Gitee Go** 负责镜像构建反馈 + AI 审查与 Issue 跟踪；后端/前端构建通过后才执行审查
- AI 审查可用 Gitee 通用变量 `AI_REVIEW_ENABLED=0` 关闭
- 只修改 `scripts/ai-review.sh` 时不会再触发「审查器审自己」的 CI 审查

前置条件：

- 仓库 secret `SUBMODULE_SSH_KEY`：一把能读取两个子仓库的 SSH 私钥
- 仓库 Settings → Actions → Workflow permissions 允许写 packages

本地复现质检：

```bash
./scripts/ci-quality.sh
cat quality-report.md
```

部署服务器可以直接拉 CI 镜像：

```bash
export SERVER_IMAGE=ghcr.io/hgu-yr/danmuku-server:latest
export WEB_IMAGE=ghcr.io/hgu-yr/danmuku-web:latest
docker compose pull
docker compose up -d --no-build
```

> 仍需要在 `.env` 中设置强密码与真实域名；`docker compose` 会读取它。

## 后台管理

访问 http://localhost:5173/manage/yr/ 进入后台（过滤规则与命中趋势（7/14/30 天图表） + 词频统计 + 地区统计 + 引擎复盘），未登录会先跳到登录页。

前端分为**两个独立入口**，各自打包、互不加载对方的代码：

| 入口 | 地址 | 说明 |
| --- | --- | --- |
| 主站 | `/` | 弹幕墙（面向观众） |
| 管理后台 | `/manage/yr/` | 后台，内部用 hash 路由（如 `/manage/yr/#/review`）；**主站不提供入口**，需直接访问该地址（建议存书签） |

> 后台路径默认用带层级的自定义地址（`/manage/yr/`）而不是 `/admin`，避免被扫描器按常见字典命中。
> 更换只需改 `DanmuKuWeb-Web/src/config/paths.ts` 一处，详见该目录 README。

后台不再使用静态令牌，而是「用户名 + 密码」登录：

- 服务端签发短期**访问令牌（JWT）** + 可撤销、可轮换的**刷新令牌**，改密码后旧令牌立即失效
- 密码以 bcrypt 哈希存储，JWT 密钥默认自动生成并保存在数据库，**不出现在源码或环境变量里**
- 单一管理员账号：首次启动创建，可在后台「修改密码」自助更换（不再提供用户管理界面）

过滤引擎具备**自我进化**能力（后台「引擎复盘」页）：

- 规则词表只写中文主体词，引擎自动派生拼音全拼与首字母缩写（「加微信」→ `jwx` / `wx` / `weixin`）
- 引擎放行的内容会进入样本池，分析器自动挖掘漏网写法与形近缩写，产出候选后一键采纳即生效
- 所有变更都有日志可回溯，`wx:123123` 这类写法无需人工逐条添加

默认词表分十四类（政治敏感、色情低俗、赌博博彩、毒品、诈骗、违禁品交易、涉未成年人、
暴力血腥与自残、隐私信息、联系方式与站外导流、引战与歧视、谣言与不实信息、
广告引流、辱骂攻击），合计约 1570 个词；
手机号、身份证、银行卡、网址、邮箱、QQ/微信等无固定词形的内容由内置正则识别。
词表只增不减，升级内置词库不会覆盖后台改过的规则：

```bash
cd DanmuKuWeb-Server
DB_PATH=data/danmuku.db go run ./cmd/seedrules   # 合并内置默认词表
```

政治类只收「法律明确禁止的行为与主张」的类别表述，不放具体人名与事件（易过时、误伤代价高）。
需要更全覆盖时，把权威词库导进去即可，引擎的拼音派生与复盘学习对导入的词同样生效：

```bash
# 纯词表：每行一个词，也支持逗号/顿号分隔，# 开头是注释
DB_PATH=data/danmuku.db go run ./cmd/importwords -rule politics -file politics.txt

# JSON：与后台规则接口同构，可一次导入多条规则
DB_PATH=data/danmuku.db go run ./cmd/importwords -file ruleset.json
```

导入是幂等的，只补缺失的词，不会删除或覆盖已有词；导完重启服务生效。

首次启动时若数据库里还没有账号，会自动创建初始管理员：

- 设置了 `ADMIN_PASSWORD` → 使用它作为初始密码
- 未设置 → 随机生成密码并打印在后端**启动日志**里（登录后请立即修改）

## 仓库结构

这是一个 **umbrella 仓库**：根仓库只放 Makefile、脚本和文档，两个子项目以
[git submodule](https://git-scm.com/book/zh/v2/Git-%E5%B7%A5%E5%85%B7-%E5%AD%90%E6%A8%A1%E5%9D%97)
的形式引用。

```
DanmuKuWeb/               # 根仓库
├── DanmuKuWeb-Server/    # submodule -> hgu-yr/DanmuKuWeb-Server
├── DanmuKuWeb-Web/       # submodule -> hgu-yr/DanmuKuWeb-Web
├── Makefile              # 根目录统一入口：make run / server / web / test / build
├── README.md
└── scripts/
    ├── dev.sh            # make run 的实际实现（前后端一起起、Ctrl-C 一起退）
    └── push-to-github.sh # 一键推送子模块 + 根仓库
```

### 日常提交

先在子项目里提交推送，再回到根仓库记录新的子模块指针：

```bash
cd DanmuKuWeb-Server && git add -A && git commit -m "..." && git push
cd ../DanmuKuWeb-Web && git add -A && git commit -m "..." && git push

# 根仓库记录指针变化
cd .. && git add DanmuKuWeb-Server DanmuKuWeb-Web
git commit -m "chore: update submodule pointers" && git push
```

也可以直接跑：

```bash
./scripts/push-to-github.sh
```

（它会先检查子模块是否有未提交改动，然后依次推送子模块、提交并推送根仓库。）

### 全新克隆

```bash
git clone --recurse-submodules git@github.com:hgu-yr/DanmuKuWeb.git

# 已经克隆过、忘了带参数：
git submodule update --init --recursive
```

### 首次推送根仓库

在 GitHub 上新建**空的** `DanmuKuWeb` 仓库（不要勾选初始化 README），然后：

```bash
git remote add origin git@github.com:hgu-yr/DanmuKuWeb.git
git push -u origin main
```

## 后续规划

- [x] 弹幕持久化（SQLite 写穿 + 启动回放）
- [ ] 弹幕广播多实例化（Redis Pub/Sub / NATS）；当前 WebSocket 广播仅在单实例内生效
- [ ] 房间 / 频道、弹幕防遮挡轨道
- [x] 敏感词过滤（可配置规则 + 管理接口）
- [x] 后台登录（JWT + 刷新令牌）与可配置的隐蔽后台路径
- [x] 过滤引擎自进化（拼音变体 + 复盘候选 + 在线学习）
- [x] 词频统计与地区（省份）统计
- [x] 弹幕点赞（匿名作者识别 + 实时「👍 +1」提示）
- [x] 观众侧本地过滤（屏蔽词 / 剧透关键词，只存浏览器）
- [x] 发送频率限制（IP 固定窗口 + 用户令牌桶）
- [x] 弹幕表情（分组面板 + 纯表情发送）
- [x] 弹幕回复（仅双方可见；会话聚合、未读红点、拉黑、举报、2 分钟撤回、7 天保留、触屏操作条）
- [x] 举报治理（访客提交 + 后台列表与处理状态）
- [x] 匿名身份签名（clientId + 服务端 token，防止冒充读取私密回复）
- [x] 回复指标（按天统计发送数 / 面板打开数）
- [x] 安全加固（安全头/CSP、WS Origin、请求体限制、登录双维度限流、日志脱敏、SQLite 0600）
- [x] 后台数据查看（表选择、分页、关键字段筛选，敏感表/列脱敏）
- [x] 主站与管理后台拆分为独立入口（`/` 与 `/manage/yr/`）
- [ ] 发送弹幕与点赞的频率限制
- [ ] 部署（Docker + Nginx 反代 `/api`、`/ws`）
