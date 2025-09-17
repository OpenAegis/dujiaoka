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
mkdir -p "$DUJIAOKA_DIR"

# 拉取最新镜像
echo "⬇️  拉取最新镜像..."
docker pull "$IMAGE_NAME"

# 创建临时容器并复制文件
echo "📋 复制应用文件到主机..."
docker create --name "$CONTAINER_NAME" "$IMAGE_NAME" > /dev/null

# 复制整个应用目录
echo "  复制完整应用代码..."
docker cp "$CONTAINER_NAME:/app/." "$DUJIAOKA_DIR/"

# 生成随机密码
echo "🔐 生成随机密码..."
DB_PASSWORD=$(openssl rand -base64 16 | tr -d "=+/" | cut -c1-16)
MYSQL_ROOT_PASSWORD=$(openssl rand -base64 16 | tr -d "=+/" | cut -c1-16)
APP_KEY="base64:$(openssl rand -base64 32)"

# 创建基础.env文件（如果不存在）
if [ ! -f "$DUJIAOKA_DIR/.env" ]; then
    echo "  创建.env配置文件..."
    cat > "$DUJIAOKA_DIR/.env" << EOF
APP_NAME=独角数卡
APP_ENV=production
APP_KEY=$APP_KEY
APP_DEBUG=false
APP_URL=http://localhost:8080

DB_CONNECTION=mysql
DB_HOST=mysql
DB_PORT=3306
DB_DATABASE=dujiaoka
DB_USERNAME=dujiaoka
DB_PASSWORD=$DB_PASSWORD

CACHE_DRIVER=redis
SESSION_DRIVER=redis
REDIS_HOST=redis
REDIS_PORT=6379
EOF
fi


# 清理临时容器
docker rm "$CONTAINER_NAME" > /dev/null

# 设置目录权限
echo "🔧 设置目录权限..."
chown -R 1000:1000 "$DUJIAOKA_DIR"
chmod -R 755 "$DUJIAOKA_DIR"
chmod -R 777 "$DUJIAOKA_DIR/storage" "$DUJIAOKA_DIR/bootstrap/cache" 2>/dev/null || true

echo ""
echo "✅ 初始化完成！"
echo ""
echo "📂 完整应用代码已复制到: $DUJIAOKA_DIR/"
echo "   📝 现在可以直接修改整个应用的所有文件"
echo "   🔧 环境配置: $DUJIAOKA_DIR/.env"
echo "   💾 数据持久化目录: $DUJIAOKA_DIR/storage/"
echo ""
echo "🔑 使用随机生成的密码启动..."
echo "   数据库密码: $DB_PASSWORD"
echo "   Root密码: $MYSQL_ROOT_PASSWORD"
echo ""

# 进入dujiaoka目录
cd "$DUJIAOKA_DIR"

# 启动服务
echo "🚀 启动独角数卡服务..."
DB_PASSWORD="$DB_PASSWORD" MYSQL_ROOT_PASSWORD="$MYSQL_ROOT_PASSWORD" docker-compose up -d

# 等待服务启动
echo "⏳ 等待服务启动..."
sleep 30

# 检查服务状态
echo "📊 检查服务状态..."
docker-compose ps

echo ""
echo "🎉 独角数卡启动完成！"
echo "🌐 访问地址: http://localhost:8080"
echo "🛠️  修改文件后重启容器生效: docker-compose restart app"