FROM python:3.12-slim

# 设置工作目录
WORKDIR /app

# Latest releases available at https://github.com/aptible/supercronic/releases
ARG TARGETARCH
ENV SUPERCRONIC_VERSION=v0.2.39

# 安装系统依赖
# - git: Git 版本控制（用于 data 分支管理）
# - curl: 下载工具（下载 supercronic）
# - openssl: 生成密码哈希（用于密码验证）
RUN apt-get update && \
    apt-get install -y git curl openssl && \
    case ${TARGETARCH} in \
    amd64) \
    export SUPERCRONIC_URL=https://github.com/aptible/supercronic/releases/download/${SUPERCRONIC_VERSION}/supercronic-linux-amd64; \
    export SUPERCRONIC_SHA1SUM=c98bbf82c5f648aaac8708c182cc83046fe48423; \
    export SUPERCRONIC=supercronic-linux-amd64; \
    ;; \
    arm64) \
    export SUPERCRONIC_URL=https://github.com/aptible/supercronic/releases/download/${SUPERCRONIC_VERSION}/supercronic-linux-arm64; \
    export SUPERCRONIC_SHA1SUM=5ef4ccc3d43f12d0f6c3763758bc37cc4e5af76e; \
    export SUPERCRONIC=supercronic-linux-arm64; \
    ;; \
    *) \
    echo "Unsupported architecture: ${TARGETARCH}"; \
    exit 1; \
    ;; \
    esac && \
    echo "Downloading supercronic for ${TARGETARCH} from ${SUPERCRONIC_URL}" && \
    # 重试机制：最多3次，每次超时30秒
    for i in 1 2 3; do \
        echo "Download attempt $i/3"; \
        if curl -fsSL --connect-timeout 30 --max-time 60 -o "$SUPERCRONIC" "$SUPERCRONIC_URL"; then \
            echo "Download successful"; \
            break; \
        else \
            echo "Download attempt $i failed"; \
            if [ $i -eq 3 ]; then \
                echo "All download attempts failed"; \
                exit 1; \
            fi; \
            sleep 2; \
        fi \
    done && \
    echo "${SUPERCRONIC_SHA1SUM}  ${SUPERCRONIC}" | sha1sum -c - && \
    chmod +x "$SUPERCRONIC" && \
    mv "$SUPERCRONIC" "/usr/local/bin/${SUPERCRONIC}" && \
    ln -s "/usr/local/bin/${SUPERCRONIC}" /usr/local/bin/supercronic && \
    supercronic -version && \
    rm -rf /var/lib/apt/lists/*

# 安装 uv（Python 包管理器）
RUN curl -LsSf https://astral.sh/uv/install.sh | sh && \
    ln -s /root/.local/bin/uv /usr/local/bin/uv

# 创建目录结构
# - /app/config: 配置目录（挂载点，存放 .env 和日志）
# - /app/ref-main: 代码目录
# - /app/ref-data: 数据目录
RUN mkdir -p /app/config /app/ref-main /app/ref-data

WORKDIR /app

# 使用 uv 安装依赖
COPY pyproject.toml /app/pyproject.toml
COPY uv.lock /app/uv.lock
RUN uv sync --frozen

# 复制 entrypoint.sh 并强制转换为 LF 格式
# 注意：entrypoint.sh 作为 PID 1 进程运行，负责启动 supercronic
COPY docker/entrypoint.sh /entrypoint.sh.tmp
RUN sed -i 's/\r$//' /entrypoint.sh.tmp && \
    mv /entrypoint.sh.tmp /entrypoint.sh && \
    chmod +x /entrypoint.sh

# 复制 dailyarxiv.sh 到 /app 目录
COPY dailyarxiv.sh /app/dailyarxiv.sh.tmp
RUN sed -i 's/\r$//' /app/dailyarxiv.sh.tmp && \
    mv /app/dailyarxiv.sh.tmp /app/dailyarxiv.sh && \
    chmod +x /app/dailyarxiv.sh

# 设置环境变量
ENV PYTHONUNBUFFERED=1
ENV PYTHONPATH=/app/ref-main
ENV UV_VENV=/app/.venv
ENV PATH="/app/.venv/bin:$PATH"

# /app/config 目录用于挂载外部配置和日志
VOLUME ["/app/config"]

# entrypoint.sh 作为容器入口点
# 它会：加载环境变量 -> 生成 crontab -> 启动 supercronic
ENTRYPOINT ["/entrypoint.sh"]
