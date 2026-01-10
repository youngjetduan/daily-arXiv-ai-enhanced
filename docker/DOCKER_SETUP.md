# Docker 部署指南

本项目支持通过 Docker 容器化部署，并自动将生成的数据提交到 GitHub 仓库的 `data` 分支，以便 GitHub Pages 正确显示最新内容。

## 文件说明

- `docker/Dockerfile`: Docker 镜像构建文件
- `docker/entrypoint.sh`: Docker 容器入口脚本
- `docker/DOCKER_SETUP.md`: Docker 部署文档（本文件）
- `.env.example`: 环境变量模板

## 目录结构说明

Docker 容器内部使用 `/app` 作为根目录:

```
/app/
├── config
│   ├── .env        # 环境变量文件（必需）
│   └── logs/       # 日志文件目录（自动创建）
│       └── dailyarxiv.log  # 执行日志
├── ref-main/          # main 分支代码（镜像内）
│   ├── .git/         # Git 仓库
│   ├── daily_arxiv/   # Scrapy 爬虫
│   ├── ai/           # AI 增强处理
│   ├── to_md/        # Markdown 转换
│   ├── .venv/        # Python 虚拟环境
│   ├── js/           # JavaScript 配置文件（运行时会被修改并提交到 main 分支）
│   │   ├── auth-config.js
│   │   └── data-config.js
│   └── dailyarxiv.sh # 执行脚本
└── ref-data/          # data 分支数据（必须挂载外部存储）
    ├── .git/         # Git 仓库
    ├── data/         # 生成的数据文件
    │   ├── 2025-01-10.jsonl
    │   └── 2025-01-10_AI_enhanced_Chinese.jsonl
    ├── file-list.txt
    └── README.md
```

## 重要说明

### 挂载目录要求
1. **`/app/ref-data`** 是数据目录，**必须挂载到外部存储**，用于：
   - 持久化 arXiv 论文数据
   - 管理 data 分支的 Git 仓库
   - 支持与远程 data 分支的同步

2. **`/app/config`** 是配置目录，**必须挂载**，用于：
   - 存放 `.env` 环境变量配置文件（必需）
   - 存放执行日志文件（自动生成）

3. **`/app/ref-main`** 是代码目录，在构建镜像时复制到容器内，**不需要挂载**
   - 包含所有程序代码
   - `js/auth-config.js` 和 `js/data-config.js` 会在运行时被修改
   - 修改后的文件会通过 Git 提交到远程 main 分支，实现配置持久化

## 功能特点

1. **自动 Git 推送**: 容器内完成数据处理后，自动将结果提交并推送到远程仓库的 `data` 分支
2. **完整工作流**: 包含爬取、去重、AI 增强、Markdown 转换等完整流程
3. **错误处理**: 每个步骤都有错误检查和回退机制
4. **GitHub Actions 集成**: 可通过 GitHub Actions 自动化构建镜像
5. **数据持久化**: 通过挂载 `/app/ref-data` 实现数据持久化
6. **日志记录**: 所有执行日志保存在 `/app/config/logs` 目录，方便排查问题

## 环境变量配置

### 必需的环境变量

| 变量名 | 说明 | 示例 |
|--------|------|------|
| `OPENAI_API_KEY` | OpenAI API 密钥 | `sk-...` |
| `GIT_TOKEN` | GitHub 个人访问令牌（用于推送） | `ghp_...` |
| `GIT_REPO` | GitHub 仓库格式 | `username/repo-name` |
| `GIT_EMAIL` | Git 提交邮箱 | `your-email@example.com` |
| `GIT_NAME` | Git 提交者名称 | `Your Name` |

### 可选的环境变量

| 变量名 | 说明 | 默认值 |
|--------|------|--------|
| `OPENAI_BASE_URL` | OpenAI API 基础 URL | `https://api.openai.com/v1` |
| `MODEL_NAME` | 使用的 LLM 模型 | `deepseek-chat` |
| `LANGUAGE` | 输出语言 | `Chinese` |
| `CATEGORIES` | arXiv 分类（逗号分隔） | `cs.AI, cs.CL, cs.CV` |
| `MAX_WORKERS` | 并行处理工作线程数 | `1` |
| `WECHAT_WEBHOOK_URL` | 企业微信 Webhook URL（通知） | - |
| `PASSWORD` | 访问密码（可选） | - |
| `DEFAULT_KEYWORDS` | 默认过滤关键词 | - |
| `DEFAULT_AUTHORS` | 默认过滤作者 | - |

## 使用方法

### 方法一：使用 .env 文件（推荐）

```bash
# 1. 创建必要的挂载目录
mkdir -p ref-data config

# 2. 复制环境变量模板到 config 目录
cp .env.example config/.env

# 3. 编辑 config/.env 文件，填入你的配置
nano config/.env

# 4. 运行容器
docker run -d \
    --name daily-arxiv \
    -v "$(pwd)/ref-data:/app/ref-data" \
    -v "$(pwd)/config:/app/config" \
    daily-arxiv:latest
```

### 方法二：直接使用环境变量

```bash
# 1. 创建必要的挂载目录
mkdir -p ref-data config

# 2. 构建镜像
docker build -f docker/Dockerfile -t daily-arxiv:latest .

# 3. 运行容器（注意：必须挂载 /app/ref-data 和 /app/config 目录）
docker run -d \
    --name daily-arxiv \
    -v "$(pwd)/ref-data:/app/ref-data" \
    -v "$(pwd)/config:/app/config" \
    -e OPENAI_API_KEY='your-openai-api-key' \
    -e GIT_TOKEN='your-github-token' \
    -e GIT_REPO='username/repo-name' \
    -e GIT_EMAIL='your-email@example.com' \
    -e GIT_NAME='Your Name' \
    daily-arxiv:latest
```

### 查看容器日志

```bash
# 查看实时容器日志
docker logs -f daily-arxiv

# 查看日志文件（日志保存在 config/logs 目录）
tail -f config/logs/dailyarxiv_*.log
```

### 方法三：GitHub Actions（推荐用于自动化构建镜像）

使用 GitHub Actions 自动构建并推送 Docker 镜像到 Docker Hub。

#### 1. 配置 GitHub Secrets（可选）

如需自动推送镜像到 Docker Hub，在你的仓库中配置以下 Secrets（Settings → Secrets and variables → Actions → New repository secret）：

| Secret 名称 | 说明 | 示例 |
|------------|------|------|
| `DOCKERHUB_USERNAME` | Docker Hub 用户名 | `yourusername` |
| `DOCKERHUB_TOKEN` | Docker Hub 访问令牌（需要 Read, Write, Delete 权限） | `dckr_pat_xxx...` |

**注意**：如果不设置这些 Secrets，GitHub Actions 仍然会构建镜像，但不会推送到 Docker Hub。

#### 2. 获取 Docker Hub 访问令牌

如需推送镜像，按以下步骤获取访问令牌：

1. 访问 https://hub.docker.com/settings/security
2. 点击 "New Access Token"
3. 输入令牌名称（如 `daily-arxiv-push`）
4. 选择权限：Read, Write, Delete
5. 点击 "Generate" 并复制令牌
6. 将令牌添加到 GitHub Secrets 中的 `DOCKERHUB_TOKEN`

#### 3. 自动构建和推送

将代码推送到 `main` 分支后，GitHub Actions 会自动：
- 构建多架构 Docker 镜像（amd64 和 arm64）
- 如果设置了 Docker Hub Secrets，自动推送到 Docker Hub
- 如果未设置 Secrets，仅构建镜像不推送

也可以在 GitHub Actions 页面手动触发工作流。

#### 4. 从 Docker Hub 拉取镜像

构建完成后，可以直接从 Docker Hub 拉取镜像：

```bash
# 拉取镜像
docker pull yourusername/daily-arxiv-ai-enhanced:latest

# 运行容器
docker run -d \
    --name daily-arxiv \
    -v $(pwd)/ref-data:/app/ref-data \
    -v $(pwd)/config:/app/config \
    yourusername/daily-arxiv-ai-enhanced:latest
```

## 挂载目录说明

### /app/ref-data（数据目录）
**用途**：存储 arXiv 论文数据和 data 分支的 Git 仓库
**必需**：是
**示例**：
```bash
# 在宿主机上创建目录
mkdir -p ref-data

# 首次运行后，目录结构如下：
ref-data/
├── .git/              # data 分支 Git 仓库
├── data/              # 生成的数据文件
│   ├── 2025-01-10.jsonl
│   └── 2025-01-10_AI_enhanced_Chinese.jsonl
├── file-list.txt      # 数据文件列表
└── README.md
```

### /app/config（配置目录）
**用途**：存放环境变量配置文件和执行日志
**必需**：是
**示例**：
```bash
# 在宿主机上创建目录
mkdir -p config

# 复制 .env 模板
cp .env.example config/.env

# 编辑配置文件
nano config/.env

# 目录结构如下：
config/
├── .env               # 环境变量配置（必需）
└── logs/              # 日志文件目录（自动创建）
    └── dailyarxiv.log  # 执行日志（每次运行覆盖）
```

## 常见问题解答

### 1. 为什么需要挂载 /app/ref-data 目录？
`/app/ref-data` 目录用于存储 arXiv 论文数据和 data 分支的 Git 仓库。如果不挂载：
- 容器重启后数据会丢失
- 无法与远程 data 分支同步
- GitHub Pages 无法获取最新数据

### 2. 为什么需要挂载 /app/config 目录？
`/app/config` 目录用于：
- 存放 `.env` 环境变量配置文件（必需）
- 保存执行日志文件（便于排查问题）
- 日志文件每次运行时覆盖，只保留最新日志

### 3. js/auth-config.js 和 js/data-config.js 的修改会丢失吗？
不会。这两个文件虽然在 `/app/ref-main`（镜像内的代码目录），但是：
- 每次运行时会被 `dailyarxiv.sh` 修改
- 修改后会被提交到远程 main 分支
- 下次运行时会从 main 分支拉取最新代码（包含最新的配置）

### 4. 如何查看执行日志？
有两种方式查看日志：

**方式一：通过 docker 命令**
```bash
# 实时查看容器日志
docker logs -f daily-arxiv
```

**方式二：查看日志文件（推荐）**
```bash
# 日志文件保存在挂载的 config/logs 目录
tail -f config/logs/dailyarxiv.log
```

### 4. 如何修改定时任务时间？
在 `config/.env` 文件中添加：
```bash
# 格式：分 时 日 月 周
# 示例：每天早上 8 点（北京时间 16 点）执行
CRON_SCHEDULE=0 16 * * *
```

## 故障排除

### 1. Git 推送失败

**问题**：数据无法推送到远程仓库

**解决方法**：
1. 检查 `GIT_TOKEN` 权限：
   ```bash
   # 需要有 repo 权限（完整仓库访问）
   # 在 GitHub Settings → Developer settings → Personal access tokens 中检查
   ```

2. 检查 `GIT_REPO` 格式：
   ```bash
   # 正确格式：username/repo-name
   # 错误格式：https://github.com/username/repo-name
   ```

3. 查看日志中的错误信息：
   ```bash
   grep "推送" config/logs/dailyarxiv_*.log
   ```

### 2. Docker 构建失败

**问题**：GitHub Actions 构建失败

**解决方法**：
1. 检查 Docker 版本：
   ```bash
   docker --version  # 需要 Docker 20.10+
   ```

2. 检查 GitHub Secrets 是否配置：
   - `DOCKERHUB_USERNAME`
   - `DOCKERHUB_TOKEN`

3. 查看构建日志：
   - GitHub Actions 页面 → Build and Push Docker Image → View logs

### 3. 容器启动失败

**问题**：容器无法启动或立即退出

**解决方法**：
1. 查看容器日志：
   ```bash
   docker logs daily-arxiv
   ```

2. 检查配置文件：
   ```bash
   # .env 文件必须存在
   ls -la config/.env

   # 检查必需的环境变量
   grep -E "OPENAI_API_KEY|GIT_TOKEN|GIT_REPO|GIT_EMAIL|GIT_NAME" config/.env
   ```

3. 检查挂载目录权限：
   ```bash
   chmod -R 755 ref-data config
   ```

### 4. 容器内网络问题

**问题**：无法访问外部服务

**解决方法**：

确保容器能访问：
- arXiv.org (爬取论文)
- OpenAI API (AI 增强)
- GitHub (推送代码)

测试网络连接：
```bash
docker exec daily-arxiv curl -I https://arxiv.org
docker exec daily-arxiv curl -I https://api.openai.com
docker exec daily-arxiv curl -I https://github.com
```

### 8. 日志文件过大

**问题**：日志文件占用过多磁盘空间

**解决方法**：
日志文件每次运行时覆盖，只保留最新日志。如果日志过大，可以手动清空：
```bash
# 清空日志文件
> config/logs/dailyarxiv.log
```

### 6. 数据未提交到远程

**问题**：数据处理完成但没有推送到远程仓库

**检查项**：
1. `GIT_REPO` 格式是否正确（应该是 `username/repo-name`）
2. `GIT_TOKEN` 是否有 `repo` 权限
3. 查看执行日志：
   ```bash
   grep -A 5 "推送" config/logs/dailyarxiv_*.log
   ```

4. 查看 ref-data Git 状态：
   ```bash
   cd ref-data
   git status
   git log -1
   ```

### 7. ref-data 目录初始化失败

**问题**：首次运行时 data 分支初始化失败

**解决方法**：
容器首次运行时会在 `/app/ref-data` 初始化 Git 仓库。如果失败，可以手动初始化：

```bash
# 清空目录（保留目录本身）
rm -rf ref-data/* ref-data/.[!.]* 2>/dev/null || true

# 手动初始化
cd ref-data
git init
git checkout -b data
git rm -rf --cached . >/dev/null 2>&1 || true
mkdir -p data
echo "# Data Branch" > README.md
git add README.md
git commit -m "chore: initialize data branch"
git remote add origin https://github.com/YOUR_USERNAME/YOUR_REPO.git
git push -u origin data
```

### 8. 日志文件过大

**问题**：日志文件占用过多磁盘空间

**解决方法**：
日志文件每次运行时覆盖，只保留最新日志。如果日志过大，可以手动清空：
```bash
# 清空日志文件
> config/logs/dailyarxiv.log
```

### 9. 环境变量值包含空格

**问题**：`GIT_NAME` 等环境变量包含空格导致错误

**解决方法**：
在 `.env` 文件中使用引号括起来：
```bash
# 正确
GIT_NAME="Your Name"
# 或
GIT_NAME='Your Name'

# 错误
GIT_NAME=Your Name
```

### 10. AI 处理失败

**问题**：AI 增强处理出错

**解决方法**：
1. 检查 OpenAI API 配置：
   ```bash
   grep "OPENAI" config/.env
   ```

2. 查看 AI 处理日志：
   ```bash
   grep -i "AI" config/logs/dailyarxiv_*.log
   ```

3. 检查模型名称和 API URL：
   - `MODEL_NAME` 是否正确
   - `OPENAI_BASE_URL` 是否正确

### 11. 数据分支同步冲突

**问题**：多个容器同时运行导致 Git 冲突

**解决方法**：
1. 确保只有一个容器实例运行：
   ```bash
   docker ps | grep daily-arxiv
   ```

2. 如果需要多个实例，使用不同的挂载目录

3. 手动解决冲突：
   ```bash
   cd ref-data
   git fetch origin data
   git rebase origin/data
   # 解决冲突后
   git add .
   git rebase --continue
   git push origin data
   ```

## 与原 GitHub Actions 工作流的区别

| 特性 | 原工作流 (run.yml) | Docker 容器 |
|------|-------------------|----------------------------------|
| 执行环境 | GitHub Actions Runner | Docker 容器 |
| 代码目录 | `/app/ref-main` | `/app/ref-main`（镜像内） |
| 数据目录 | `/app/ref-data` | `/app/ref-data`（挂载） |
| 依赖安装 | 直接在 Runner 上安装 | 在镜像中预装 |
| 可移植性 | 仅限 GitHub Actions | 可在任何支持 Docker 的环境运行 |
| 资源占用 | 每次重新安装依赖 | 镜像复用，更快 |
| 本地测试 | 较困难 | 容易（使用 docker-compose） |

## 许可证

本项目采用 Apache-2.0 许可证。
