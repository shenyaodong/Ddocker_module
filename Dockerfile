# 第一阶段：构建阶段
FROM --platform=linux/arm64 golang:1.19-alpine AS builder

ENV GO111MODULE=on \
    GOPROXY=https://goproxy.cn,direct \
    CGO_ENABLED=0 \
    GOOS=linux \
    GOARCH=arm64

WORKDIR /build

# 复制源代码并编译
COPY cloudeye-exporter-source/ .
RUN go mod download
RUN go build -ldflags="-s -w" -o cloudeye-exporter .

# 第二阶段：运行阶段
FROM --platform=linux/arm64 alpine:latest

# 安装必要工具
RUN apk --no-cache add ca-certificates tzdata sed

# 创建 exporter 工作目录
RUN mkdir -p /exporter
WORKDIR /exporter

# 从构建阶段复制二进制文件
COPY --from=builder /build/cloudeye-exporter /exporter/

# 复制所有配置文件
COPY config-files/ /exporter/

# 给二进制文件执行权限，配置文件改为可写
RUN chmod +x /exporter/cloudeye-exporter && \
    chmod 666 /exporter/clouds.yml && \
    chmod 666 /exporter/logs.yml && \
    chmod 666 /exporter/endpoints.yml && \
    chmod 666 /exporter/metric.yml

# 创建启动脚本
RUN echo '#!/bin/sh' > /exporter/start.sh && \
    echo '' >> /exporter/start.sh && \
    echo '# 替换占位符' >> /exporter/start.sh && \
    echo 'if [ -n "$AUTH_URL" ]; then' >> /exporter/start.sh && \
    echo '    sed -i "s|AUTH_URL_PLACEHOLDER|$AUTH_URL|g" /exporter/clouds.yml' >> /exporter/start.sh && \
    echo 'fi' >> /exporter/start.sh && \
    echo 'if [ -n "$PROJECT_NAME" ]; then' >> /exporter/start.sh && \
    echo '    sed -i "s|PROJECT_NAME_PLACEHOLDER|$PROJECT_NAME|g" /exporter/clouds.yml' >> /exporter/start.sh && \
    echo 'fi' >> /exporter/start.sh && \
    echo 'if [ -n "$REGION" ]; then' >> /exporter/start.sh && \
    echo '    sed -i "s|REGION_PLACEHOLDER|$REGION|g" /exporter/clouds.yml' >> /exporter/start.sh && \
    echo 'fi' >> /exporter/start.sh && \
    echo 'if [ -n "$HUAWEI_CLOUD_AK" ]; then' >> /exporter/start.sh && \
    echo '    sed -i "s|access_key: \"\"|access_key: \"$HUAWEI_CLOUD_AK\"|" /exporter/clouds.yml' >> /exporter/start.sh && \
    echo 'fi' >> /exporter/start.sh && \
    echo 'if [ -n "$HUAWEI_CLOUD_SK" ]; then' >> /exporter/start.sh && \
    echo '    sed -i "s|secret_key: \"\"|secret_key: \"$HUAWEI_CLOUD_SK\"|" /exporter/clouds.yml' >> /exporter/start.sh && \
    echo 'fi' >> /exporter/start.sh && \
    echo '' >> /exporter/start.sh && \
    echo '# 启动 exporter' >> /exporter/start.sh && \
    echo 'exec /exporter/cloudeye-exporter "$@"' >> /exporter/start.sh

RUN chmod 755 /exporter/start.sh

# 暴露端口
EXPOSE 8080

# 使用启动脚本作为入口点
ENTRYPOINT ["/exporter/start.sh"]
