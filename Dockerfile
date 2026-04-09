FROM --platform=linux/arm64 golang:1.19-alpine AS builder

ENV GO111MODULE=on \
    GOPROXY=https://goproxy.cn,direct \
    CGO_ENABLED=0 \
    GOOS=linux \
    GOARCH=arm64

WORKDIR /build

COPY cloudeye-exporter-source/ .
RUN go mod download
RUN go build -ldflags="-s -w" -o cloudeye-exporter

FROM --platform=linux/arm64 alpine:latest

RUN apk --no-cache add ca-certificates tzdata sed

RUN mkdir -p /exporter
WORKDIR /exporter

COPY --from=builder /build/cloudeye-exporter /exporter/
COPY config-files/ /exporter/

# 给二进制文件执行权限，所有配置文件改为可写
RUN chmod +x /exporter/cloudeye-exporter && \
    chmod 666 /exporter/clouds.yml && \
    chmod 666 /exporter/logs.yml && \
    chmod 666 /exporter/endpoints.yml && \
    chmod 666 /exporter/metric.yml && \
    chmod 666 /exporter/*.json 2>/dev/null || true

# 创建启动脚本
RUN echo '#!/bin/sh' > /exporter/start.sh
RUN echo 'if [ -n "$AUTH_URL" ]; then' >> /exporter/start.sh
RUN echo '    sed -i "s|AUTH_URL_PLACEHOLDER|$AUTH_URL|g" /exporter/clouds.yml' >> /exporter/start.sh
RUN echo 'fi' >> /exporter/start.sh
RUN echo 'if [ -n "$PROJECT_NAME" ]; then' >> /exporter/start.sh
RUN echo '    sed -i "s|PROJECT_NAME_PLACEHOLDER|$PROJECT_NAME|g" /exporter/clouds.yml' >> /exporter/start.sh
RUN echo 'fi' >> /exporter/start.sh
RUN echo 'if [ -n "$REGION" ]; then' >> /exporter/start.sh
RUN echo '    sed -i "s|REGION_PLACEHOLDER|$REGION|g" /exporter/clouds.yml' >> /exporter/start.sh
RUN echo 'fi' >> /exporter/start.sh
RUN echo 'if [ -n "$HUAWEI_CLOUD_AK" ]; then' >> /exporter/start.sh
RUN echo '    sed -i "s|access_key: \"\"|access_key: \"$HUAWEI_CLOUD_AK\"|" /exporter/clouds.yml' >> /exporter/start.sh
RUN echo 'fi' >> /exporter/start.sh
RUN echo 'if [ -n "$HUAWEI_CLOUD_SK" ]; then' >> /exporter/start.sh
RUN echo '    sed -i "s|secret_key: \"\"|secret_key: \"$HUAWEI_CLOUD_SK\"|" /exporter/clouds.yml' >> /exporter/start.sh
RUN echo 'fi' >> /exporter/start.sh
RUN echo 'exec /exporter/cloudeye-exporter "$@"' >> /exporter/start.sh

RUN chmod 755 /exporter/start.sh

EXPOSE 8080
ENTRYPOINT ["/exporter/start.sh"]
