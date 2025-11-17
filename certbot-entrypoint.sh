#!/bin/sh
set -e

echo "🚀 Certbot 续期服务启动中..."

# 安装 Docker CLI（用于 reload nginx）
if ! command -v docker >/dev/null 2>&1; then
    echo "📦 正在安装 docker-cli..."
    apk add --no-cache docker-cli
    echo "✅ docker-cli 安装完成"
fi

# 设置信号处理
trap "echo '⚠️  收到终止信号，正在退出...'; exit 0" TERM INT

echo "✅ Certbot 续期循环已启动（每 12 小时检查一次）"

# 续期循环
while true; do
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "🔍 [$(date '+%Y-%m-%d %H:%M:%S')] 开始检查证书续期..."
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

    # 显示续期前的证书状态
    echo ""
    echo "📋 续期前证书状态："
    certbot certificates 2>&1 | grep -E "(Certificate Name|Domains|Expiry Date)" || echo "   未找到证书信息"

    # 执行续期
    echo ""
    echo "🔄 执行续期检查..."
    if certbot renew --deploy-hook "docker exec lobe-nginx nginx -s reload" 2>&1; then
        echo "✅ 续期检查完成"
    else
        echo "⚠️  续期检查失败"
    fi

    # 显示续期后的证书状态
    echo ""
    echo "📋 续期后证书状态："
    certbot certificates 2>&1 | grep -E "(Certificate Name|Domains|Expiry Date)" || echo "   未找到证书信息"

    # 计算下次检查的具体时间
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    current_ts=$(date +%s)
    next_ts=$((current_ts + 43200))  # 12小时 = 43200秒

    # 尝试格式化时间（兼容 GNU date 和 BSD date）
    next_time=$(date -d "@$next_ts" '+%Y-%m-%d %H:%M:%S' 2>/dev/null || date -r $next_ts '+%Y-%m-%d %H:%M:%S' 2>/dev/null || echo "")

    if [ -n "$next_time" ]; then
        echo "💤 下次检查时间: $next_time"
    else
        echo "💤 下次检查时间: 12 小时后"
    fi
    echo ""

    # 等待 12 小时
    sleep 12h &
    wait $!
done
