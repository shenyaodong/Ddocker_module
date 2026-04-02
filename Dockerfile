# Dockerfile - openGauss-exporter for ARM64
FROM python:3.8-slim AS builder

WORKDIR /build

RUN apt-get update && apt-get install -y --no-install-recommends \
    git \
    gcc \
    g++ \
    make \
    libpq-dev \
    && rm -rf /var/lib/apt/lists/*

ARG DBMIND_BRANCH=master
ARG EXPORTER_VERSION=latest

RUN git clone --depth 1 -b ${DBMIND_BRANCH} https://gitee.com/opengauss/openGauss-DBMind.git openGauss-DBMind

RUN if [ ! -d "openGauss-DBMind/dbmind/components/opengauss_exporter" ]; then \
        echo "ERROR: opengauss_exporter component not found!" && exit 1; \
    fi

RUN cat > requirements.txt << 'EOF'
psycopg2-binary>=2.9.0
prometheus-client>=0.14.0
click>=8.0.0
EOF

RUN pip install --user --no-cache-dir -r requirements.txt

FROM python:3.8-slim

RUN groupadd -r dbmind && useradd -r -g dbmind dbmind

RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    curl \
    libpq5 \
    && rm -rf /var/lib/apt/lists/*

COPY --from=builder /build/openGauss-DBMind /opt/openGauss-DBMind
COPY --from=builder /root/.local /home/dbmind/.local

ENV PATH="/home/dbmind/.local/bin:${PATH}" \
    PYTHONUNBUFFERED=1 \
    PYTHONPATH="/opt/openGauss-DBMind:${PYTHONPATH}"

WORKDIR /opt/openGauss-DBMind

RUN cat > /entrypoint.sh << 'EOF'
#!/bin/bash
set -e

DEFAULT_LISTEN_ADDR="0.0.0.0"
DEFAULT_LISTEN_PORT="9187"

if [ -z "$DATASOURCE" ]; then
    echo "ERROR: DATASOURCE environment variable not set"
    echo "Example: -e DATASOURCE='postgresql://user:pass@host:port/db'"
    exit 1
fi

exec gs_dbmind component opengauss_exporter \
    --url "$DATASOURCE" \
    --web.listen-address "${LISTEN_ADDR:-$DEFAULT_LISTEN_ADDR}" \
    --web.listen-port "${LISTEN_PORT:-$DEFAULT_LISTEN_PORT}" \
    --disable-https \
    --log.level "${LOG_LEVEL:-info}"
EOF

RUN chmod +x /entrypoint.sh

USER dbmind

EXPOSE 9187

ENTRYPOINT ["/entrypoint.sh"]
