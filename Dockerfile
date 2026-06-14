# syntax=docker/dockerfile:1
FROM node:22-bookworm-slim

LABEL org.opencontainers.image.title="playhub"
LABEL org.opencontainers.image.description="TVBox Web frontend/backend runtime image, arm64 compatible"

ENV APP_PORT=18080 \
    APP_CACHE_DIR=/opt/playhub/data/cache \
    APP_LOG_FILE=/opt/playhub/logs/playhub.log \
    DEX2JAR_COMMAND=__AUTO__ \
    NODE_COMMAND=node \
    PYTHON_COMMAND=python3 \
    JAVA_OPTS="-Xms64m -Xmx384m -XX:+UseG1GC -XX:MaxGCPauseMillis=200 -XX:+HeapDumpOnOutOfMemoryError -XX:HeapDumpPath=/opt/playhub/logs/" \
    APP_SPIDER_OPERATION_MAX_CONCURRENCY=2 \
    APP_SCRIPT_MAX_CONCURRENCY=2

# 移除错误sed换源，原生官方源直接安装
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        bash \
        ca-certificates \
        curl \
        openjdk-17-jre-headless \
        procps \
        python3 \
        python3-pip \
        python3-venv \
        unzip \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /opt/playhub

COPY target/playhub-*.jar app/playhub.jar
COPY scripts/ scripts/
COPY docker/application.yml config/application.yml

# 容器内在线拉取dex-tools纯Java包，无架构绑定
RUN mkdir -p tools && cd tools \
    && curl -fsSL https://github.com/pxb1988/dex2jar/releases/download/v2.4/dex-tools-v2.4.zip -o dex-tools.zip \
    && unzip -q dex-tools.zip \
    && rm -f dex-tools.zip \
    && chmod +x dex-tools-v2.4/*.sh \
    && rm -rf dex-tools-v2.4/*.exe dex-tools-v2.4/*.bat dex-tools-v2.4/*.dll \
    && mkdir -p data/cache logs run .cache/android-cache .cache/android-external .cache/android-files \
    && find scripts -type d -name __pycache__ -prune -exec rm -rf {} + \
    && find scripts -type f -name "*.pyc" -delete \
    && groupadd -r playhub \
    && useradd -r -g playhub -d /opt/playhub playhub \
    && chown -R playhub:playhub /opt/playhub

USER playhub

EXPOSE 18080

HEALTHCHECK --interval=30s --timeout=5s --start-period=40s --retries=3 \
    CMD curl -fsS "http://127.0.0.1:${APP_PORT}/api/health" >/dev/null || exit 1

ENTRYPOINT ["sh", "-c", "exec java ${JAVA_OPTS} -jar app/playhub.jar --spring.config.additional-location=file:config/application.yml \"$@\"", "--"]
