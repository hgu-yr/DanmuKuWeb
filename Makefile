.PHONY: run server web build test tidy clean

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

test:
	cd DanmuKuWeb-Server && go test ./...

tidy:
	cd DanmuKuWeb-Server && go mod tidy
	cd DanmuKuWeb-Web && npm install

clean:
	cd DanmuKuWeb-Server && make clean
	rm -rf DanmuKuWeb-Web/dist
