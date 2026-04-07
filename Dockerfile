# 第一阶段：构建阶段
FROM --platform=linux/arm64 golang:1.19-alpine AS builder

ARG DBMIND_BRANCH=master

ENV GO111MODULE=on \
    GOPROXY=https://goproxy.cn,direct \
    CGO_ENABLED=0 \
    GOOS=linux \
    GOARCH=arm64

WORKDIR /build

# 克隆 openGauss-DBMind 源码
RUN git clone --branch ${DBMIND_BRANCH} --depth 1 https://gitee.com/opengauss/openGauss-DBMind.git .

# 编译 openGauss-exporter
WORKDIR /build/tools/exporter
RUN go mod download
RUN go build -ldflags="-s -w" -o openGauss-exporter .

# 第二阶段：运行阶段
FROM --platform=linux/arm64 alpine:latest

RUN apk --no-cache add ca-certificates tzdata

# 创建 exporter 工作目录（改为 /exporter）
RUN mkdir -p /exporter
WORKDIR /exporter

# 从构建阶段复制二进制文件
COPY --from=builder /build/tools/exporter/openGauss-exporter /exporter/

# ============================================
# 复制配置文件到 /exporter 目录
# ============================================
COPY config-files/clouds.yml /exporter/
COPY config-files/logs.yml /exporter/
COPY config-files/metric.yml /exporter/
COPY config-files/endpoints.yml /exporter/
# 如果有 i18n.json 也复制
COPY config-files/i18n.json /exporter/ 2>/dev/null || true

# 给二进制文件执行权限
RUN chmod +x /exporter/openGauss-exporter

# 暴露端口
EXPOSE 8080

# 启动程序（工作目录是 /exporter，配置文件就在当前目录）
ENTRYPOINT ["/exporter/openGauss-exporter"]
