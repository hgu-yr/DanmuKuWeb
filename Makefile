.PHONY: run server web build test tidy clean env env-check

# 启动后端（默认 :8080）
server:
	cd DanmuKuWeb-Server && go run ./cmd/server

# 启动前端（默认 :5173）
web:
	cd DanmuKuWeb-Web && npm run dev

# 前后端一起启动，Ctrl-C 一并退出
run:
	@bash scripts/dev.sh

# 生产构建：后端 -> bin/，前端 -> dist/
build:
	cd DanmuKuWeb-Server && make build
	cd DanmuKuWeb-Web && npm run build

test: env-check
	cd DanmuKuWeb-Server && go test ./...

tidy:
	cd DanmuKuWeb-Server && go mod tidy
	cd DanmuKuWeb-Web && npm install

# 从 internal/config/spec.go 重新生成后端 .env.example
env:
	cd DanmuKuWeb-Server && go run ./cmd/genenv

# 校验 .env.example 是否与 spec.go 一致（CI 也会跑）
env-check:
	cd DanmuKuWeb-Server && go run ./cmd/genenv -check

clean:
	cd DanmuKuWeb-Server && make clean
	rm -rf DanmuKuWeb-Web/dist
