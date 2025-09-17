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


# 检查是否已存在安装
if [ -d "$DUJIAOKA_DIR" ] && [ "$(ls -A $DUJIAOKA_DIR 2>/dev/null)" ]; then
    echo "⚠️  检测到已存在的独角数卡安装"
    echo "目录: $DUJIAOKA_DIR"
    echo ""
    echo "请选择操作："
    echo "1) 更新到最新版本 (保留数据)"
    echo "2) 完全卸载后重装"
    echo "3) 显示当前数据库密码"
    echo "4) 退出"
    echo ""
    read -p "请输入选项 (1-4): " choice
    
    case $choice in
        1)
            echo "🔄 更新到最新版本..."
            UPDATE_MODE=true
            ;;
        2)
            echo "🗑️ 卸载现有安装..."
            # 停止并删除容器
            docker stop dujiaoka_app dujiaoka_mysql dujiaoka_redis 2>/dev/null || true
            docker rm dujiaoka_app dujiaoka_mysql dujiaoka_redis 2>/dev/null || true
            # 删除数据卷
            docker volume rm dujiaoka_mysql_data dujiaoka_redis_data 2>/dev/null || true
            # 删除目录
            rm -rf "$DUJIAOKA_DIR"
            echo "✅ 卸载完成，开始重新安装..."
            UPDATE_MODE=false
            ;;
        3)
            if [ -f "$DUJIAOKA_DIR/.env.docker-compose" ]; then
                echo ""
                echo "🔑 当前数据库密码："
                echo "   数据库密码: $(grep "DB_PASSWORD" "$DUJIAOKA_DIR/.env.docker-compose" | cut -d'=' -f2)"
                echo "   Root密码: $(grep "MYSQL_ROOT_PASSWORD" "$DUJIAOKA_DIR/.env.docker-compose" | cut -d'=' -f2)"
                echo ""
            else
                echo "❌ 未找到密码文件"
            fi
            exit 0
            ;;
        4)
            echo "👋 退出安装"
            exit 0
            ;;
        *)
            echo "❌ 无效选项"
            exit 1
            ;;
    esac
else
    echo "📍 首次安装独角数卡"
    UPDATE_MODE=false
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

# 处理密码生成
if [ "$UPDATE_MODE" = true ] && [ -f "$DUJIAOKA_DIR/.env.docker-compose" ]; then
    # 更新模式，读取现有密码
    echo "🔐 使用现有密码..."
    DB_PASSWORD=$(grep "DB_PASSWORD" "$DUJIAOKA_DIR/.env.docker-compose" | cut -d'=' -f2)
    MYSQL_ROOT_PASSWORD=$(grep "MYSQL_ROOT_PASSWORD" "$DUJIAOKA_DIR/.env.docker-compose" | cut -d'=' -f2)
    APP_KEY=$(grep "APP_KEY" "$DUJIAOKA_DIR/.env.docker-compose" | cut -d'=' -f2)
else
    # 新安装或重装，生成新密码
    echo "🔐 生成随机密码..."
    DB_PASSWORD=$(openssl rand -base64 16 | tr -d "=+/" | cut -c1-16)
    MYSQL_ROOT_PASSWORD=$(openssl rand -base64 16 | tr -d "=+/" | cut -c1-16)
    APP_KEY="base64:$(openssl rand -base64 32)"
fi

# 创建或更新.env文件
echo "  创建/更新.env配置文件..."
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


# 清理临时容器
docker rm "$CONTAINER_NAME" > /dev/null

# 设置目录权限
echo "🔧 设置目录权限..."
chown -R 1000:1000 "$DUJIAOKA_DIR"
chmod -R 755 "$DUJIAOKA_DIR"
# 设置Laravel必要的写入权限
chmod -R 777 "$DUJIAOKA_DIR/storage" 2>/dev/null || true
chmod -R 777 "$DUJIAOKA_DIR/bootstrap/cache" 2>/dev/null || true
# 确保日志目录存在并有权限
mkdir -p "$DUJIAOKA_DIR/storage/logs" 2>/dev/null || true
chmod -R 777 "$DUJIAOKA_DIR/storage/logs" 2>/dev/null || true

echo ""
echo "✅ 初始化完成！"
echo ""
echo "📂 完整应用代码已复制到: $DUJIAOKA_DIR/"
echo "   📝 现在可以直接修改整个应用的所有文件"
echo "   🔧 环境配置: $DUJIAOKA_DIR/.env"
echo "   💾 数据持久化目录: $DUJIAOKA_DIR/storage/"
echo ""
if [ "$UPDATE_MODE" = true ]; then
    echo "🔑 使用现有密码更新..."
else
    echo "🔑 使用随机生成的密码启动..."
fi
echo "   数据库密码: $DB_PASSWORD"
echo "   Root密码: $MYSQL_ROOT_PASSWORD"
echo ""

# 进入dujiaoka目录
cd "$DUJIAOKA_DIR"

# 创建docker-compose环境文件
cat > .env.docker-compose << EOF
DB_DATABASE=dujiaoka
DB_USERNAME=dujiaoka
DB_PASSWORD=$DB_PASSWORD
MYSQL_ROOT_PASSWORD=$MYSQL_ROOT_PASSWORD
APP_KEY=$APP_KEY
APP_URL=http://localhost:8080
DOCKER_TAG=latest
EOF

# 下载docker-compose配置文件
echo "📥 下载docker-compose配置..."
curl -sSL https://raw.githubusercontent.com/OpenAegis/dujiaoka/main/docker-compose.dev.yml -o docker-compose.yml

# 启动服务
echo "🚀 启动独角数卡服务..."
docker-compose --env-file .env.docker-compose up -d

# 等待服务启动
echo "⏳ 等待服务启动..."
sleep 30

# 检查服务状态
echo "📊 检查服务状态..."
docker-compose --env-file .env.docker-compose ps

# 等待MySQL完全启动
echo "⏳ 等待MySQL完全启动..."
for i in {1..30}; do
    if docker exec dujiaoka_mysql mysqladmin ping -h localhost --silent; then
        echo "✅ MySQL已就绪"
        break
    fi
    echo "  等待MySQL启动... ($i/30)"
    sleep 2
done

# 检查数据库连接
echo "🔍 测试数据库连接..."
echo "  使用密码: $DB_PASSWORD"
echo "  数据库用户: dujiaoka"

# 检查MySQL是否创建了用户
echo "🔍 检查MySQL用户..."
docker exec dujiaoka_mysql mysql -u root -p"$MYSQL_ROOT_PASSWORD" -e "SELECT User, Host FROM mysql.user WHERE User='dujiaoka';" 2>/dev/null || echo "无法查询用户信息"

# 尝试用root连接测试
echo "🔍 测试root连接..."
docker exec dujiaoka_mysql mysql -u root -p"$MYSQL_ROOT_PASSWORD" -e "SELECT 1;" 2>/dev/null && echo "✅ Root连接成功" || echo "❌ Root连接失败"

# 测试应用用户连接
echo "🔍 测试应用用户连接..."
docker exec dujiaoka_mysql mysql -u dujiaoka -p"$DB_PASSWORD" -e "SELECT 1;" dujiaoka 2>/dev/null && echo "✅ 数据库连接成功" || {
    echo "❌ 数据库连接失败，尝试重新创建用户..."
    docker exec dujiaoka_mysql mysql -u root -p"$MYSQL_ROOT_PASSWORD" -e "
        DROP USER IF EXISTS 'dujiaoka'@'%';
        CREATE USER 'dujiaoka'@'%' IDENTIFIED WITH mysql_native_password BY '$DB_PASSWORD';
        GRANT ALL PRIVILEGES ON dujiaoka.* TO 'dujiaoka'@'%';
        FLUSH PRIVILEGES;
    " 2>/dev/null && echo "✅ 用户重新创建成功" || echo "❌ 用户创建失败"
}

# 初始化数据库
echo "📊 初始化数据库..."

# 确保容器内权限正确
echo "  设置容器内权限..."
docker exec dujiaoka_app chown -R www-data:www-data /app/storage /app/bootstrap/cache
docker exec dujiaoka_app chmod -R 777 /app/storage /app/bootstrap/cache

# 清理配置缓存
echo "  清理Laravel缓存..."
docker exec dujiaoka_app php artisan config:clear || true
docker exec dujiaoka_app php artisan cache:clear || true

# 生成应用密钥
echo "  生成应用密钥..."
docker exec dujiaoka_app php artisan key:generate --force || true

# 执行数据库迁移
echo "  执行数据库迁移..."
docker exec dujiaoka_app php artisan migrate --force && echo "✅ 数据库迁移成功" || {
    echo "❌ 数据库迁移失败，尝试详细调试..."
    echo "检查数据库连接..."
    docker exec dujiaoka_app php artisan tinker --execute="DB::connection()->getPdo();" || echo "数据库连接失败"
    echo "查看迁移状态..."
    docker exec dujiaoka_app php artisan migrate:status || echo "无法查看迁移状态"
}

# 创建管理员账户 (如果是新安装)
if [ "$UPDATE_MODE" != true ]; then
    echo "  创建管理员账户..."
    docker exec dujiaoka_app php artisan admin:create-user --force 2>/dev/null || echo "管理员账户创建失败，请手动创建"
fi

echo ""
if [ "$UPDATE_MODE" = true ]; then
    echo "🎉 独角数卡更新完成！"
else
    echo "🎉 独角数卡安装完成！"
fi
echo "🌐 访问地址: http://localhost:8080"
echo "🛠️  修改文件后重启容器生效: docker-compose restart app"
echo "🔑 查看密码: $0 (选择选项3)"