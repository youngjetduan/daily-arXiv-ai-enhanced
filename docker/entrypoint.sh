#!/bin/bash
set -e

# 配置日志目录
LOG_DIR="/app/config"
LOG_FILE="$LOG_DIR/dailyarxiv.log"

echo "📝 日志文件: $LOG_FILE"

if [ -f $LOG_FILE ]; then
    rm $LOG_FILE
fi

# 记录日志的函数
log() {
    echo "[$(date -u '+%Y-%m-%d %H:%M:%S UTC')] $@" | tee -a "$LOG_FILE"
}

log "=== 容器启动 ==="
log "日志目录: $LOG_DIR"

# 加载环境变量
if [ -f "/app/config/.env" ]; then
    log "📋 从 /app/config/.env 加载环境变量..."
    if [ -r "/app/config/.env" ]; then
        # 使用更安全的方式加载环境变量
        set -a  # 自动导出所有变量
        source /app/config/.env
        set +a
        log "✅ 环境变量加载完成"
    else
        log "❌ 错误: /app/config/.env 文件不可读"
        exit 1
    fi
else
    log "⚠️  警告: /app/config/.env 不存在，将使用环境变量或默认值"
fi

# 环境变量检查
if [ -z "$OPENAI_API_KEY" ]; then
    echo "❌ 错误: OPENAI_API_KEY 未设置"
    exit 1
fi

if [ -z "$GIT_TOKEN" ]; then
    echo "❌ 错误: GIT_TOKEN 未设置"
    exit 1
fi

if [ -z "$GIT_REPO" ]; then
    echo "❌ 错误: GIT_REPO 未设置"
    exit 1
fi

if [ -z "$GIT_EMAIL" ]; then
    echo "❌ 错误: GIT_EMAIL 未设置"
    exit 1
fi

if [ -z "$GIT_NAME" ]; then
    echo "❌ 错误: GIT_NAME 未设置"
    exit 1
fi

# 记录环境变量到日志（脱敏处理）
log "🔧 环境变量配置:"
echo "GIT_REPO=${GIT_REPO}" | tee -a "$LOG_FILE"
echo "GIT_EMAIL=${GIT_EMAIL}" | tee -a "$LOG_FILE"
echo "GIT_NAME=${GIT_NAME}" | tee -a "$LOG_FILE"
echo "CRON_SCHEDULE=${CRON_SCHEDULE:-30 1 * * *}" | tee -a "$LOG_FILE"

# 生成 crontab
CRON_CMD="cd /app && bash dailyarxiv.sh >> \"$LOG_FILE\" 2>&1"
echo "${CRON_SCHEDULE:-30 1 * * *} $CRON_CMD" > /tmp/crontab

log "📅 生成的crontab内容:"
cat /tmp/crontab | tee -a "$LOG_FILE"

if ! /usr/local/bin/supercronic -test /tmp/crontab; then
    log "❌ crontab格式验证失败"
    exit 1
fi

log "⏰ 启动supercronic: ${CRON_SCHEDULE:-40 1 * * *}"
log "🎯 supercronic 将作为 PID 1 运行"
log "📊 执行日志将保存到: $LOG_FILE"
log "⚠️  注意: 所有脚本输出都会追加到日志文件中"
log "=== 容器启动完成，等待定时任务执行 ==="

exec /usr/local/bin/supercronic -passthrough-logs /tmp/crontab
