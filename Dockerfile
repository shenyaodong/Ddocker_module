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

# 安装必要工具（添加 sed 用于替换占位符）
RUN apk --no-cache add ca-certificates tzdata sed

# 创建 exporter 工作目录
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

# ============================================
# 修改文件权限，使其可写（用于运行时注入 AK/SK）
# ============================================
RUN chmod +x /exporter/openGauss-exporter && \
    chmod 666 /exporter/clouds.yml && \
    chmod 666 /exporter/logs.yml && \
    chmod 666 /exporter/endpoints.yml && \
    chmod 666 /exporter/metric.yml && \
    chmod 666 /exporter/*.json 2>/dev/null || true

# ============================================
# 创建启动脚本（用于替换占位符）
# ============================================
RUN cat > /exporter/start.sh << 'EOF'
#!/bin/sh
# 替换 clouds.yml 中的占位符
if [ -n "$AUTH_URL" ]; then
    sed -i "s|AUTH_URL_PLACEHOLDER|$AUTH_URL|g" /exporter/clouds.yml
fi
if [ -n "$PROJECT_NAME" ]; then
    sed -i "s|PROJECT_NAME_PLACEHOLDER|$PROJECT_NAME|g" /exporter/clouds.yml
fi
if [ -n "$REGION" ]; then
    sed -i "s|REGION_PLACEHOLDER|$REGION|g" /exporter/clouds.yml
fi
if [ -n "$HUAWEI_CLOUD_AK" ]; then
    sed -i "s|access_key: \"\"|access_key: \"$HUAWEI_CLOUD_AK\"|" /exporter/clouds.yml
fi
if [ -n "$HUAWEI_CLOUD_SK" ]; then
    sed -i "s|secret_key: \"\"|secret_key: \"$HUAWEI_CLOUD_SK\"|" /exporter/clouds.yml
fi
# 启动 exporter
exec /exporter/openGauss-exporter "$@"
EOF

RUN chmod 755 /exporter/start.sh

# 暴露端口
EXPOSE 8080

# 使用启动脚本作为入口点
ENTRYPOINT ["/exporter/start.sh"]
