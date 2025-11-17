# LobeChat Database Deployment

一个完整的 LobeChat 数据库版本 Docker Compose 部署方案，包含所有必要的服务和组件。

## 📋 项目简介

本项目提供了一个生产就绪的 LobeChat 部署方案，包含：

- **LobeChat**: AI 聊天应用主服务
- **PostgreSQL**: 数据库（支持 pgvector 向量搜索）
- **MinIO**: S3 兼容的对象存储服务
- **Casdoor**: SSO 单点登录认证系统
- **SearxNG**: 隐私友好的搜索引擎
- **Nginx**: 反向代理和负载均衡
- **Certbot**: 自动化 SSL 证书管理（支持 Cloudflare DNS）
- **Cloudflared**: Cloudflare Tunnel 隧道服务

## 🚀 快速开始

### 前置要求

- Docker >= 20.10
- Docker Compose >= 2.0

### 初始化项目

在启动 Docker Compose 之前，需要先获取 LobeChat 官方配置并合并本项目的个性化配置：

1. **执行官方安装脚本**

   ```bash
   # 执行官方 setup 脚本生成初始配置文件
   bash <(curl -fsSL https://lobe.li/setup.sh) -l zh_CN
   ```

   ⚠️ **重要**：在交互式脚本执行过程中：
   - 当询问部署模式时，请选择 **`domain`** 模式（而非 `local` 模式）
   - 这样生成的配置文件会包含域名相关的配置项，便于后续与本项目的 Nginx 反向代理集成

   该脚本会自动生成：
   - `docker-compose.yml` - 官方 Docker Compose 配置
   - `.env` - 环境变量配置文件
   - 必要的密钥和配置项

2. **合并个性化配置**

   将官方生成的配置与本项目的 `compose.yaml`、`.env`、`nginx.conf` 等配置文件合并，保留本项目的个性化定制部分（Nginx、Certbot、Cloudflared 等）。

### 配置步骤

#### 1. 配置域名信息 ⚠️

在正式部署前，你需要将所有示例域名 `example.com` 替换为你的实际域名。

**需要修改 `nginx.conf` 中的域名：**

将以下域名替换为你的实际域名：
- `lobe.example.com` → 你的 LobeChat 应用域名
- `auth.example.com` → 你的 Casdoor 认证服务域名
- `minio.example.com` → 你的 MinIO API 域名
- `minio-ui.example.com` → 你的 MinIO 控制台域名

同时修改 SSL 证书路径中的域名：
```nginx
# 将所有证书路径中的 example.com 替换为你的主域名
ssl_certificate /etc/letsencrypt/live/your-domain.com/fullchain.pem;
ssl_certificate_key /etc/letsencrypt/live/your-domain.com/privkey.pem;
```

**需要修改 `.env` 文件中的域名和密钥：**

```bash
# 应用域名配置
APP_URL=https://lobe.your-domain.com
AUTH_CASDOOR_ISSUER=https://auth.your-domain.com
S3_PUBLIC_DOMAIN=https://minio.your-domain.com
S3_ENDPOINT=https://minio.your-domain.com
origin=https://auth.your-domain.com

# SSL 证书配置
CERTBOT_EMAIL=your-email@example.com
CERTBOT_DOMAINS=*.your-domain.com,your-domain.com

# 必填密钥（需要生成或配置）
POSTGRES_PASSWORD=your_secure_password
AUTH_CASDOOR_ID=your_casdoor_app_id
AUTH_CASDOOR_SECRET=your_casdoor_app_secret
MINIO_ROOT_PASSWORD=your_minio_password
OPENROUTER_API_KEY=your_api_key
CLOUDFLARE_TUNNEL_TOKEN=your_tunnel_token
```

**配置检查清单：**

完成域名配置后，请确认以下内容已全部修改：

- [ ] `nginx.conf`: 所有 `*.example.com` 域名已替换（共 4 个子域名）
- [ ] `nginx.conf`: 所有 SSL 证书路径中的 `example.com` 已替换（共 4 处）
- [ ] `.env`: `APP_URL` 已配置为实际域名
- [ ] `.env`: `AUTH_CASDOOR_ISSUER` 和 `origin` 已配置为实际域名
- [ ] `.env`: `S3_PUBLIC_DOMAIN` 和 `S3_ENDPOINT` 已配置为实际域名
- [ ] `.env`: `CERTBOT_DOMAINS` 已配置为实际的通配符域名
- [ ] `.env`: 所有必填密钥已生成并填写（7 个配置项）

#### 2. 配置 Cloudflare DNS 凭证

   编辑 `certbot-credentials/cloudflare.ini`，填入你的 Cloudflare API Token。

#### 3. 创建 Nginx 日志目录

   在项目根目录下创建 `nginx-logs` 目录用于存储 Nginx 访问日志和错误日志：

   ```bash
   mkdir -p nginx-logs
   ```

   该目录会被挂载到 Nginx 容器的 `/var/log/nginx` 路径，用于存储：
   - 主日志：`access.log`、`error.log`
   - LobeChat 日志：`lobe-access.log`、`lobe-error.log`
   - Casdoor 日志：`casdoor-access.log`、`casdoor-error.log`
   - MinIO 日志：`minio-access.log`、`minio-error.log`、`minio-console-access.log`、`minio-console-error.log`

### SSL 证书首次获取

⚠️ **重要**：首次部署时需要按以下步骤获取 SSL 证书：

1. **修改 `compose.yaml` 中的 certbot 服务配置**

   找到 certbot 服务，取消注释 `command` 行，注释掉 `entrypoint` 行：

   ```yaml
   certbot:
     image: certbot/dns-cloudflare:latest
     container_name: lobe-certbot
     # ... 其他配置 ...

     # 首次运行：放开这一行获取证书
     command: certonly --dns-cloudflare --dns-cloudflare-credentials /credentials/cloudflare.ini --dns-cloudflare-propagation-seconds 30 --email $CERTBOT_EMAIL --agree-tos --non-interactive -d $CERTBOT_DOMAINS

     # 首次运行：注释掉这一行
     # entrypoint: /bin/sh /entrypoint.sh
   ```

2. **启动服务获取证书**

   ```bash
   docker compose up certbot
   ```

   等待证书获取完成，看到 "Successfully received certificate" 消息后按 `Ctrl+C` 停止。

3. **切换到自动续期模式**

   重新编辑 `compose.yaml`，注释 `command` 行，放开 `entrypoint` 行：

   ```yaml
   certbot:
     image: certbot/dns-cloudflare:latest
     container_name: lobe-certbot
     # ... 其他配置 ...

     # 证书获取成功后：注释掉这一行
     # command: certonly --dns-cloudflare --dns-cloudflare-credentials /credentials/cloudflare.ini --dns-cloudflare-propagation-seconds 30 --email $CERTBOT_EMAIL --agree-tos --non-interactive -d $CERTBOT_DOMAINS

     # 证书获取成功后：放开这一行启用自动续期
     entrypoint: /bin/sh /entrypoint.sh
   ```

4. **启动所有服务**

   ```bash
   docker compose up -d

   # 查看日志
   docker compose logs -f
   ```

5. **访问服务**

   - LobeChat: `https://lobe.example.com`
   - Casdoor 管理: `https://auth.example.com`
   - MinIO 控制台: `https://minio.example.com:9001`

## 📦 服务列表

| 服务 | 容器名 | 端口 | 说明 |
|-----|--------|------|------|
| LobeChat | lobe-chat | 3210 | AI 聊天应用 |
| PostgreSQL | lobe-postgres | 5432 | 数据库 |
| MinIO | lobe-minio | 9002, 9001 | 对象存储 |
| Casdoor | lobe-casdoor | 8001 | 认证服务 |
| SearxNG | lobe-searxng | 8080 | 搜索引擎 |
| Nginx | lobe-nginx | 80, 443 | 反向代理 |
| Certbot | lobe-certbot | - | SSL 证书管理 |
| Cloudflared | lobe-cloudflared | - | Cloudflare 隧道 |

## 🔧 高级配置

### 启用监控（可选）

项目包含可选的监控组件（Grafana、Prometheus、Tempo）：

```bash
# 使用 otel profile 启动监控服务
docker compose --profile otel up -d

# Grafana 访问地址: http://localhost:3000
```

### SSL 证书自动续期

Certbot 容器会自动处理证书续期，通过 `certbot-entrypoint.sh` 脚本实现：
- 每天检查证书有效期
- 自动续期即将过期的证书
- 续期后自动重载 Nginx

### 自定义 Nginx 配置

编辑 `nginx.conf` 文件可以自定义反向代理规则。

## 📂 目录结构

```
lobe-chat-db/
├── compose.yaml              # Docker Compose 配置
├── .env                      # 环境变量配置
├── nginx.conf                # Nginx 配置
├── certbot-entrypoint.sh     # Certbot 自动续期脚本
├── certbot-credentials/      # SSL 证书 API 凭证
│   └── cloudflare.ini
├── searxng-settings.yml      # SearxNG 搜索引擎配置
├── init_data.json            # Casdoor 初始化数据
└── README.md                 # 本文件
```

## 🔐 安全建议

1. **修改默认密码**: 确保修改所有默认密码
2. **保护敏感文件**: `.env` 和 `certbot-credentials/` 不要提交到公开仓库
3. **定期更新**: 定期更新 Docker 镜像版本
4. **防火墙配置**: 仅开放必要的端口
5. **备份数据**: 定期备份 PostgreSQL 数据和 MinIO 对象

## 🛠️ 常用命令

```bash
# 启动所有服务
docker compose up -d

# 停止所有服务
docker compose down

# 查看日志
docker compose logs -f [服务名]

# 重启特定服务
docker compose restart [服务名]

# 查看服务状态
docker compose ps

# 清理并重建
docker compose down -v
docker compose up -d --build
```

## 🐛 故障排查

### LobeChat 无法连接 Casdoor

检查 `AUTH_CASDOOR_ISSUER` 配置是否正确，确保：
- 域名可以正常访问
- OIDC 配置端点可用: `${AUTH_CASDOOR_ISSUER}/.well-known/openid-configuration`

### SSL 证书获取失败

1. 检查 Cloudflare API Token 权限
2. 确认 DNS 记录正确配置
3. 查看 certbot 日志: `docker compose logs certbot`

### MinIO 连接失败

确保 `S3_ENDPOINT` 和 `S3_PUBLIC_DOMAIN` 配置正确，并且防火墙允许访问。

## 📖 参考文档

- [LobeChat 官方文档](https://lobehub.com/docs)
- [LobeChat Server Database 部署指南](https://lobehub.com/docs/self-hosting/server-database/docker-compose)
- [Casdoor 文档](https://casdoor.org/docs/overview)
- [MinIO 文档](https://min.io/docs/minio/linux/index.html)

---

Made with ❤️ for LobeChat Community
