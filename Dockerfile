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

RUN chmod +x /exporter/cloudeye-exporter && chmod 666 /exporter/clouds.yml

COPY --chmod=755 <<'START_SCRIPT' /exporter/start.sh
#!/bin/sh
[ -n "$AUTH_URL" ] && sed -i "s|AUTH_URL_PLACEHOLDER|$AUTH_URL|g" /exporter/clouds.yml
[ -n "$PROJECT_NAME" ] && sed -i "s|PROJECT_NAME_PLACEHOLDER|$PROJECT_NAME|g" /exporter/clouds.yml
[ -n "$REGION" ] && sed -i "s|REGION_PLACEHOLDER|$REGION|g" /exporter/clouds.yml
[ -n "$HUAWEI_CLOUD_AK" ] && sed -i 's|access_key: ""|access_key: "'"$HUAWEI_CLOUD_AK"'"|' /exporter/clouds.yml
[ -n "$HUAWEI_CLOUD_SK" ] && sed -i 's|secret_key: ""|secret_key: "'"$HUAWEI_CLOUD_SK"'"|' /exporter/clouds.yml
exec /exporter/cloudeye-exporter "$@"
START_SCRIPT

RUN chmod 755 /exporter/start.sh

EXPOSE 8080
ENTRYPOINT ["/exporter/start.sh"]
