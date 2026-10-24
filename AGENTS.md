# 项目约定

## 提交与推送

**每完成一个功能点后自动提交并推送，不需要再询问。**

一键脚本（推荐）：

```bash
./scripts/push-to-github.sh
```

它会依次：检查两个子模块没有未提交改动 → 推送子仓库 → 提交并推送根仓库（含 submodule 指针）。

手动等价流程（顺序不能颠倒，先子后根）：

```bash
# 1) 两个子项目各自提交推送
cd DanmuKuWeb-Server && git add -A && git commit -m "..." && git push
cd ../DanmuKuWeb-Web && git add -A && git commit -m "..." && git push

# 2) 根仓库记录新的子模块指针
cd .. && git add -A && git commit -m "chore: bump submodules" && git push
```

### 提交前必须通过

```bash
# 后端
cd DanmuKuWeb-Server && go build ./... && go vet ./... && go test ./...

# 前端
cd DanmuKuWeb-Web && npx vue-tsc --noEmit && npm run build
```

### 其它

- 提交信息用英文（conventional commits），与既有历史保持一致
- 一个功能点一个提交，信息里说清「做了什么、为什么」

## 不要提交的内容

- 密钥、`.env`（`.env.example` 模板可以）
- `data/` 目录：里面有 11MB 的离线 IP 库 `ip2region.xdb` 和 SQLite 数据库
- `dist/`、`node_modules/`

## 本地开发

```bash
make run      # 前后端一起起（Ctrl-C 一起退）
make server   # 只起后端 :8080
make web      # 只起前端 :5173
```

- 弹幕墙：http://localhost:5173/
- 管理后台：http://localhost:5173/manage/yr/ —— 主站不提供入口，只能直接访问（路径见 `DanmuKuWeb-Web/src/config/paths.ts`）
