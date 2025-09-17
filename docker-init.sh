#!/bin/bash
# 独角数卡 Docker 初始化脚本
# 用于将容器内的文件复制到主机 /opt/dujiaoka 目录

set -e

DUJIAOKA_DIR="/opt/dujiaoka"
CONTAINER_NAME="dujiaoka_temp"
IMAGE_NAME="ghcr.io/openaegis/dujiaoka:latest"

echo "🚀 独角数卡 Docker 初始化脚本"
echo "===================================="

# 检查是否为 root 用户
if [ "$EUID" -ne 0 ]; then
    echo "❌ 请使用 root 权限运行此脚本"
    echo "   sudo $0"
    exit 1
fi

# 创建目录结构
echo "📁 创建目录结构..."
mkdir -p "$DUJIAOKA_DIR"/{app,config,resources,routes,database,public,storage,uploads}

# 拉取最新镜像
echo "⬇️  拉取最新镜像..."
docker pull "$IMAGE_NAME"

# 创建临时容器并复制文件
echo "📋 复制应用文件到主机..."
docker create --name "$CONTAINER_NAME" "$IMAGE_NAME" > /dev/null

# 复制核心目录
docker cp "$CONTAINER_NAME:/app/app" "$DUJIAOKA_DIR/"
docker cp "$CONTAINER_NAME:/app/config" "$DUJIAOKA_DIR/"
docker cp "$CONTAINER_NAME:/app/resources" "$DUJIAOKA_DIR/"
docker cp "$CONTAINER_NAME:/app/routes" "$DUJIAOKA_DIR/"
docker cp "$CONTAINER_NAME:/app/database" "$DUJIAOKA_DIR/"
docker cp "$CONTAINER_NAME:/app/public" "$DUJIAOKA_DIR/"

# 复制环境配置文件示例
if [ ! -f "$DUJIAOKA_DIR/.env" ]; then
    docker cp "$CONTAINER_NAME:/app/.env.example" "$DUJIAOKA_DIR/.env" 2>/dev/null || true
fi

# 清理临时容器
docker rm "$CONTAINER_NAME" > /dev/null

# 设置目录权限
echo "🔧 设置目录权限..."
chown -R 1000:1000 "$DUJIAOKA_DIR"
chmod -R 755 "$DUJIAOKA_DIR"
chmod -R 777 "$DUJIAOKA_DIR/storage" "$DUJIAOKA_DIR/public/uploads" 2>/dev/null || true

echo ""
echo "✅ 初始化完成！"
echo ""
echo "📂 文件位置："
echo "   应用代码: $DUJIAOKA_DIR/app/"
echo "   配置文件: $DUJIAOKA_DIR/config/"
echo "   模板文件: $DUJIAOKA_DIR/resources/"
echo "   路由文件: $DUJIAOKA_DIR/routes/"
echo "   数据库脚本: $DUJIAOKA_DIR/database/"
echo "   静态文件: $DUJIAOKA_DIR/public/"
echo "   环境配置: $DUJIAOKA_DIR/.env"
echo ""
echo "🛠️  修改文件后重启容器生效："
echo "   docker-compose restart app"
echo ""
echo "🚀 现在可以启动独角数卡："
echo "   docker-compose up -d"