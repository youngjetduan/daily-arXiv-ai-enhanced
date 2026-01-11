#!/bin/bash

# Docker 环境下的执行脚本
# 此脚本会在 Docker 容器中运行，并自动将 data 分支的更改推送到远程仓库
# 目录结构: /app/ref-main (代码) 和 /app/ref-data (数据，可挂载外部存储)

set -e

echo "=== Docker 环境下执行 arXiv 论文爬取任务 ==="

# 加载环境变量
if [ -f "/app/config/.env" ]; then
    echo "📋 从 /app/config/.env 加载环境变量..."
    if [ -r "/app/config/.env" ]; then
        # 使用更安全的方式加载环境变量
        set -a  # 自动导出所有变量
        source /app/config/.env
        set +a
        echo "✅ 环境变量加载完成"
    else
        echo "❌ 错误: /app/config/.env 文件不可读"
        exit 1
    fi
else
    echo "⚠️  警告: /app/config/.env 不存在，将使用环境变量或默认值"
fi

# 设置默认值
export OPENAI_BASE_URL="${OPENAI_BASE_URL:-https://api.openai.com/v1}"
export PASSWORD="${ACCESS_PASSWORD:-}"
export MODEL_NAME="${MODEL_NAME:-deepseek-chat}"
export CATEGORIES="${CATEGORIES:-}"
export MAX_WORKERS="${MAX_WORKERS:-1}"
export LANGUAGE="${LANGUAGE:-Chinese}"
export DEFAULT_KEYWORDS="${DEFAULT_KEYWORDS:-}"
export DEFAULT_AUTHORS="${DEFAULT_AUTHORS:-}"
export WECHAT_WEBHOOK_URL="${WECHAT_WEBHOOK_URL:-}"

echo "🔧 环境变量配置:"
echo "   OPENAI_BASE_URL: $OPENAI_BASE_URL"
echo "   MODEL_NAME: $MODEL_NAME"
echo "   CATEGORIES: $CATEGORIES"
echo "   MAX_WORKERS: $MAX_WORKERS"
echo "   LANGUAGE: $LANGUAGE"
echo "   DEFAULT_KEYWORDS: $DEFAULT_KEYWORDS"
echo "   DEFAULT_AUTHORS: $DEFAULT_AUTHORS"

# 获取当前日期
today=$(date -u "+%Y-%m-%d")

# 配置 Git
git config --global user.email "$GIT_EMAIL"
git config --global user.name "$GIT_NAME"

# 设置认证 URL（使用 token）
REPO_URL="https://github.com/${GIT_REPO}.git"
AUTH_REPO_URL="https://x-access-token:${GIT_TOKEN}@github.com/${GIT_REPO}.git"

# 工作目录
REF_MAIN="/app/ref-main"
REF_DATA="/app/ref-data"

echo ""
echo "=== 检查 ref-main 目录 ==="

# 检查 /app/ref-main 是否为 Git 仓库
if [ -d "$REF_MAIN/.git" ]; then
    echo "ref-main 已是 Git 仓库 / ref-main has already been a Git repository"
    echo "尝试拉取远程 main 分支最新内容... / Trying to pull latest main branch from remote..."

    cd "$REF_MAIN"

    # 尝试拉取远程更新
    if git fetch origin main 2>/dev/null && git pull origin main --no-edit 2>/dev/null; then
        echo "✅ 成功拉取并合并远程 main 分支内容 / Successfully pulled and merged remote main branch"
    else
        echo "⚠️  拉取远程 main 分支失败，清空本地内容并重新克隆 / Failed to pull remote main branch, clearing local content and re-cloning..."
        # 返回上级目录以便清空
        cd /app
        # 清空 ref-main 目录中的内容（不删除目录本身）
        rm -rf "$REF_MAIN"/* "$REF_MAIN"/.* 2>/dev/null || true
        # 重新克隆 main 分支到 ref-main
        echo "正在重新克隆 main 分支... / Re-cloning main branch..."
        git clone --branch main "$AUTH_REPO_URL" "$REF_MAIN"
        echo "✅ 已重新克隆 main 分支 / Re-cloned main branch successfully"
    fi
else
    echo "ref-main 不是 Git 仓库，初始化... / ref-main is not a Git repository, initializing..."
    # 先清空 ref-main 目录中的内容（不删除目录本身）
    rm -rf "$REF_MAIN"/* "$REF_MAIN"/.* 2>/dev/null || true
    # 克隆 main 分支到 ref-main
    git clone --branch main "$AUTH_REPO_URL" "$REF_MAIN"
fi

echo ""
echo "=== 检查 ref-data 目录 ==="

# 检查 /app/ref-data 是否为 Git 仓库
if [ -d "$REF_DATA/.git" ]; then
    echo "ref-data 已是 Git 仓库 / ref-data has already been a Git repository"
    echo "尝试拉取远程 data 分支最新内容... / Trying to pull latest data branch from remote..."

    cd "$REF_DATA"

    # 尝试拉取远程更新
    if git fetch origin data 2>/dev/null && git pull origin data --no-edit 2>/dev/null; then
        echo "✅ 成功拉取并合并远程 data 分支内容 / Successfully pulled and merged remote data branch"
    else
        echo "⚠️  拉取远程 data 分支失败，清空本地内容并重新克隆 / Failed to pull remote data branch, clearing local content and re-cloning..."
        # 返回上级目录以便清空
        cd /app
        # 清空 ref-data 目录中的内容（不删除目录本身）
        rm -rf "$REF_DATA"/* "$REF_DATA"/.* 2>/dev/null || true
        # 重新克隆 data 分支到 ref-data
        echo "正在重新克隆 data 分支... / Re-cloning data branch..."
        git clone --branch data "$AUTH_REPO_URL" "$REF_DATA"
        echo "✅ 已重新克隆 data 分支 / Re-cloned data branch successfully"
    fi
else
    echo "ref-data 不是 Git 仓库，初始化... / ref-data is not a Git repository, initializing..."
    # 检查 data 分支是否存在
    if git ls-remote --heads "$REPO_URL" data | grep -q data; then
        echo "data 分支已存在，克隆 data 分支到 ref-data / data branch exists, cloning data branch to ref-data"
        # 先清空 ref-data 目录中的内容（不删除目录本身）
        rm -rf "$REF_DATA"/* "$REF_DATA"/.* 2>/dev/null || true
        # 克隆 data 分支到 ref-data
        git clone --branch data "$AUTH_REPO_URL" "$REF_DATA"
    else
        echo "data 分支不存在，创建新分支 / data branch does not exist, creating new branch"
        # 先清空 ref-data 目录中的内容（不删除目录本身）
        rm -rf "$REF_DATA"/* "$REF_DATA"/.* 2>/dev/null || true

        # 创建空的 data 分支 / Create empty data branch
        cd "$REF_DATA"
        git init
        git checkout -b data
        git rm -rf --cached . >/dev/null 2>&1 || true
        # 确保 data 目录存在 / Ensure data directory exists
        mkdir -p data
        echo "# Data Branch" > README.md
        git add README.md

        git commit -m "chore: initialize data branch"
        git remote add origin "$AUTH_REPO_URL"
        git push origin data
    fi
fi

echo ""
echo "=== 步骤1: 爬取 arXiv 论文 ==="

cd "$REF_MAIN"

echo "开始爬取 $today 的arXiv论文... / Starting to crawl $today arXiv papers..."
echo "爬取类别: $CATEGORIES / Crawling categories: $CATEGORIES"

# 检查今日文件是否已存在，如存在则删除 / Check if today's file exists, delete if found
if [ -f "$REF_DATA/data/${today}.jsonl" ]; then
    echo "🗑️ 发现今日文件已存在，正在删除重新生成... / Found existing today's file, deleting for fresh start..."
    rm "$REF_DATA/data/${today}.jsonl"
    echo "✅ 已删除现有文件：$REF_DATA/data/${today}.jsonl / Deleted existing file: ../ref-data/data/${today}.jsonl"
else
    echo "📝 今日文件不存在，准备新建... / Today's file doesn't exist, ready to create new one..."
fi

cd daily_arxiv

# 使用Scrapy爬取
scrapy crawl arxiv -o "$REF_DATA/data/${today}.jsonl"

# 检查爬取是否成功 / Check if crawling was successful
if [ ! -f "$REF_DATA/data/${today}.jsonl" ]; then
    echo "爬取失败，未生成数据文件 / Crawling failed, no data file generated"
    exit 1
fi

echo "爬取完成 / Crawling completed"

echo ""
echo "=== 步骤2: 执行去重检查 ==="

echo "执行去重检查... / Performing intelligent deduplication check..."

cd "$REF_MAIN/daily_arxiv"

# 执行去重检查脚本 / Execute intelligent deduplication check script
set +e  # 暂时允许命令失败 / Temporarily allow command failure
python daily_arxiv/check_stats.py --data "$REF_DATA/data/${today}.jsonl"

# 获取退出码 / Get exit code
dedup_exit_code=$?
set -e  # 恢复严格模式 / Restore strict mode

echo "去重检查退出码: $dedup_exit_code / Dedup check exit code: $dedup_exit_code"

has_new_content=false
skip_reason=""

case $dedup_exit_code in
    0)
        has_new_content=true
        ;;
    1)
        has_new_content=false
        skip_reason="no_new_content"
        ;;
    2)
        has_new_content=false
        skip_reason="processing_error"
        ;;
    *)
        echo "❌ 未知退出码，停止工作流 / Unknown exit code, stop workflow"
        has_new_content=false
        skip_reason="unknown_error"
        ;;
esac

echo ""
echo "=== 步骤3: AI 增强处理 ==="

ai_success=false
if [ "$has_new_content" = "true" ]; then
    cd "$REF_MAIN"

    echo "开始AI增强处理... / Starting AI enhancement processing..."
    echo "使用模型: $MODEL_NAME / Using model: $MODEL_NAME"
    echo "输出语言: $LANGUAGE / Output language: $LANGUAGE"
    echo "并行处理工作线程数: $MAX_WORKERS / Number of parallel worker threads: $MAX_WORKERS"

    cd ai

    # 使用AI处理爬取的数据 / Use AI to process the crawled data
    LOG_FILE=$(mktemp)
    python enhance.py --data "$REF_DATA/data/${today}.jsonl" --max_workers $MAX_WORKERS 2>&1 | tee $LOG_FILE
    if tail -10 "$LOG_FILE" | grep -q "AI_FAILED"; then
        echo "❌ AI处理存在错误 / AI processing has errors"
    else
        ai_success=true
        echo "✅ AI增强处理完成 / AI enhancement processing completed"
    fi
    rm "$LOG_FILE"
fi

echo ""
echo "=== 步骤4: Summary ==="

cd "$REF_MAIN"

if [ "$has_new_content" = "true" ]; then
    echo "✅ 工作流完成：去重发现新内容并成功处理 / Workflow completed: Smart deduplication found new content and processed successfully"
else
    case "$skip_reason" in
        "no_new_content")
            echo "ℹ️ 工作流完成：去重后无新内容 / Workflow completed: No new content after smart deduplication"
            ;;
        "processing_error")
            echo "⚠️ 工作流完成：去重处理出错 / Workflow completed: Deduplication processing error"
            ;;
        "unknown_error")
            echo "⚠️ 工作流完成：未知错误 / Workflow completed: Unknown error"
            ;;
        *)
            echo "ℹ️ 工作流完成：未知原因跳过处理 / Workflow completed: Skipped for unknown reason"
            ;;
    esac
fi

echo ""
echo "=== 步骤5: 发送企业微信通知 ==="

echo "📤 发送企业微信通知... / Sending WeChat bot notification..."

if [ -z "$WECHAT_WEBHOOK_URL" ]; then
    echo "⚠️ 未设置企业微信Webhook URL，跳过推送 / WeChat webhook URL not set, skipping notification"
else
    cd "$REF_MAIN/notify"

    # 根据工作流状态发送不同的通知
    if [ "$has_new_content" = "true" ] && [ "$ai_success" = "true" ]; then
        # 成功处理新内容
        echo "✅ 发送成功通知 / Sending success notification"
        python wechat_bot.py --data "$REF_DATA/data/${today}_AI_enhanced_${LANGUAGE}.jsonl" --status "success" --count "-1" --webhook "$WECHAT_WEBHOOK_URL"

    elif [ "$has_new_content" = "false" ]; then
        # 无新内容
        echo "ℹ️ 发送无新内容通知 / Sending no new content notification"
        python wechat_bot.py --data "$REF_DATA/data/${today}_AI_enhanced_${LANGUAGE}.jsonl" --status "no_content" --webhook "$WECHAT_WEBHOOK_URL"

    else
        # 处理失败
        echo "❌ 发送失败通知 / Sending error notification"
        ERROR_MSG="工作流处理过程中出现错误"
        if [ "$skip_reason" = "processing_error" ]; then
            ERROR_MSG="去重处理出错"
        elif [ "$ai_success" != "true" ]; then
            ERROR_MSG="AI增强处理失败"
        fi
        python wechat_bot.py --data "$REF_DATA/data/${today}_AI_enhanced_${LANGUAGE}.jsonl" --status "error" --error "$ERROR_MSG" --webhook "$WECHAT_WEBHOOK_URL"
    fi

    echo "✅ 企业微信通知发送完成 / WeChat bot notification completed"
fi

echo ""
echo "=== 步骤6: 注入密码哈希到 auth-config.js ==="

cd "$REF_MAIN"

echo "🔐 注入密码哈希到 auth-config.js... / Injecting password hash into auth-config.js..."

if [ -z "$PASSWORD" ]; then
    echo "⚠️  WARNING: ACCESS_PASSWORD not set in Secrets"
    echo "⚠️  Password protection will be DISABLED"
    echo "⚠️  To enable password protection, add ACCESS_PASSWORD in repository Secrets"
    echo "ℹ️  Website will remain publicly accessible without authentication"

    # Use a special value that will disable authentication
    PASSWORD_HASH="DISABLED_NO_PASSWORD_SET_IN_SECRETS"
else
    # Generate SHA-256 hash using openssl
    PASSWORD_HASH=$(echo -n "$PASSWORD" | openssl dgst -sha256 -hex | awk '{print $2}')
    echo "✅ Password hash generated successfully"
    echo "✅ Hash length: ${#PASSWORD_HASH} characters"
    echo "🔐 Password protection is ENABLED"
fi

# Inject hash into auth-config.js
if [ -f "js/auth-config.js" ]; then
    # Match the assignment at the start of the line and replace the quoted value (single or double quotes)
    sed -E -i "s@passwordHash: ['\"].*['\"],@passwordHash: '${PASSWORD_HASH}',@" js/auth-config.js || true
    echo "✅ Password hash injected/updated into js/auth-config.js"
else
    echo "❌ ERROR: js/auth-config.js not found!"
fi

echo "🔐 密码哈希注入完成 / Authentication setup complete"

echo ""
echo "=== 步骤7: 注入默认过滤关键词及作者列表到 data-config.js ==="

cd "$REF_MAIN"

echo "注入默认过滤关键词及作者列表到 data-config.js... / Injecting default filter keywords & authors into data-config.js..."
echo "默认关键词 / Default Keywords: $DEFAULT_KEYWORDS"
echo "默认作者列表 / Default Authors: $DEFAULT_AUTHORS"

# Inject filter config into data-config.js
if [ -f "js/data-config.js" ]; then
    # Replace the defaultKeywords and defaultAuthors values
    sed -i "s@defaultKeywords: .*'@defaultKeywords: '${DEFAULT_KEYWORDS}'@" js/data-config.js || true
    sed -i "s@defaultAuthors: .*'@defaultAuthors: '${DEFAULT_AUTHORS}'@" js/data-config.js || true
    echo "✅ Default keywords and authors injected/updated into js/data-config.js"
else
    echo "❌ ERROR: js/data-config.js not found!"
fi

echo "🔐 默认过滤配置注入完成 / Default filter config injection complete"

echo ""
echo "=== 步骤8: 注入仓库信息到 data-config.js ==="

cd "$REF_MAIN"

echo "🔐 注入仓库信息到 data-config.js... / Injecting repository info into data-config.js..."

# 从 GIT_REPO 提取 owner 和 name
REPO_OWNER=$(echo "$GIT_REPO" | cut -d'/' -f1)
REPO_NAME=$(echo "$GIT_REPO" | cut -d'/' -f2)

echo "仓库所有者: $REPO_OWNER / Repository owner: $REPO_OWNER"
echo "仓库名称: $REPO_NAME / Repository name: $REPO_NAME"

# 注入仓库信息到 data-config.js / Inject repository info into data-config.js
if [ -f "js/data-config.js" ]; then
    sed -i "s/PLACEHOLDER_REPO_OWNER/$REPO_OWNER/g" js/data-config.js
    sed -i "s/PLACEHOLDER_REPO_NAME/$REPO_NAME/g" js/data-config.js
    echo "✅ 仓库信息已注入到 js/data-config.js / Repository info injected into js/data-config.js"
else
    echo "❌ ERROR: js/data-config.js not found!"
fi

echo "🔐 数据仓库信息注入完成 / Repository info injection complete"

echo ""
echo "=== 步骤9: 提交代码变更到 main 分支 ==="

cd "$REF_MAIN"

git add js/auth-config.js 2>/dev/null || true
git add js/data-config.js 2>/dev/null || true

# 检查是否有变更需要提交 / Check if there are changes to commit
if git diff --staged --quiet 2>/dev/null; then
    echo "🟡 没有变更需要提交 / No changes to commit"
else
    git commit -m "update: $(date -u '+%Y-%m-%d') arXiv papers"
    echo "✅ 变更已提交 / Changes committed"
fi

echo ""
echo "=== 步骤10: 推送代码变更到 main 分支 ==="

cd "$REF_MAIN"

# 设置Git配置以处理自动合并 / Set Git config for automatic merging
git config pull.rebase true
git config rebase.autoStash true

# 尝试推送代码变更到 main 分支 / Try to push code changes to main branch
for i in {1..3}; do
    echo "推送代码变更尝试 $i / Push code changes attempt $i"
    if git push origin main; then
        echo "✅ 推送成功 / Push successful"
        break
    else
        echo "🟡 推送失败，拉取最新变更... / Push failed, pulling latest changes..."
        git pull origin main --no-edit || true
        if [ $i -eq 3 ]; then
            echo "❌ 3次尝试后推送失败 / Failed to push after 3 attempts"
        fi
    fi
done

echo ""
echo "=== 步骤11: 设置并提交到 data 分支 ==="

if [ "$ai_success" = "true" ]; then
    cd "$REF_DATA"

    echo "更新文件列表... / Updating file list..."
    ls data/*.jsonl | sed 's|data/||' > file-list.txt

    # 只添加数据文件 / Only add data files
    git add data/*.jsonl 2>/dev/null || true
    git add file-list.txt 2>/dev/null || true

    # 检查是否有数据变更需要提交 / Check if there are data changes to commit
    if git diff --staged --quiet; then
        echo "🟡 没有数据变更需要提交 / No data changes to commit"
    else
        git commit -m "update: $today arXiv papers"
        echo "✅ 数据变更已提交到 data 分支 / Data changes committed to data branch"
    fi
fi

echo ""
echo "=== 步骤12: 推送数据变更到 data 分支 ==="

if [ "$ai_success" = "true" ]; then
    cd "$REF_DATA"

    # 设置Git配置以处理自动合并 / Set Git config for automatic merging
    git config pull.rebase true
    git config rebase.autoStash true

    # 尝试推送代码变更到 data 分支 / Try to push code changes to data branch
    for i in {1..3}; do
        echo "推送代码变更尝试 $i / Push code changes attempt $i"
        if git push origin data; then
            echo "✅ 推送成功 / Push successful"
            break
        else
            echo "🟡 推送失败，拉取最新变更... / Push failed, pulling latest changes..."
            git pull origin data --no-edit || true
            if [ $i -eq 3 ]; then
                echo "❌ 3次尝试后推送失败 / Failed to push after 3 attempts"
            fi
        fi
    done
fi

echo ""
echo "=== 任务完成 ==="
echo "✅ 所有步骤已成功执行"
echo "📅 日期: $today"
echo "📊 数据已提交到 data 分支"
