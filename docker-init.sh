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

# 获取用户自定义域名/URL
echo ""
echo "🌐 配置访问地址"
echo "请输入您的域名或IP地址 (不包含http://)"
echo "示例: example.com 或 192.168.1.100 或 localhost"
read -p "域名/IP地址: " USER_DOMAIN

# 验证输入
if [ -z "$USER_DOMAIN" ]; then
    echo "⚠️  未输入域名，使用默认 localhost"
    USER_DOMAIN="localhost"
fi

# 询问端口
echo ""
echo "请输入访问端口 (默认: 8080)"
read -p "端口: " USER_PORT

if [ -z "$USER_PORT" ]; then
    USER_PORT="8080"
fi

# 验证端口是否为数字
if ! [[ "$USER_PORT" =~ ^[0-9]+$ ]]; then
    echo "❌ 端口必须是数字，使用默认端口 8080"
    USER_PORT="8080"
fi

# 构建完整URL
APP_URL="http://${USER_DOMAIN}:${USER_PORT}"
echo ""
echo "✅ 访问地址设置为: $APP_URL"
echo ""


# 检查是否已存在安装
if [ -d "$DUJIAOKA_DIR" ] && [ "$(ls -A $DUJIAOKA_DIR 2>/dev/null)" ]; then
    # 对于已存在安装，读取现有配置
    if [ -f "$DUJIAOKA_DIR/.env.docker-compose" ]; then
        EXISTING_APP_URL=$(grep "APP_URL" "$DUJIAOKA_DIR/.env.docker-compose" | cut -d'=' -f2)
        if [ -n "$EXISTING_APP_URL" ]; then
            APP_URL="$EXISTING_APP_URL"
            echo "📍 检测到现有配置，访问地址: $APP_URL"
        fi
    fi
    echo "⚠️  检测到已存在的独角数卡安装"
    echo "目录: $DUJIAOKA_DIR"
    echo ""
    echo "请选择操作："
    echo "1) 更新到最新版本 (保留数据)"
    echo "2) 完全卸载后重装"
    echo "3) 仅卸载 (不重装)"
    echo "4) 显示当前数据库密码"
    echo "5) 退出"
    echo ""
    read -p "请输入选项 (1-5): " choice
    
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
            # 删除数据目录
            rm -rf "$DUJIAOKA_DIR/mysql" "$DUJIAOKA_DIR/redis" 2>/dev/null || true
            # 删除整个目录
            rm -rf "$DUJIAOKA_DIR"
            echo "✅ 卸载完成，开始重新安装..."
            UPDATE_MODE=false
            ;;
        3)
            echo "🗑️ 仅卸载独角数卡..."
            
            # 如果存在docker-compose文件，使用它来清理
            if [ -f "$DUJIAOKA_DIR/docker-compose.yml" ]; then
                echo "  使用docker-compose清理..."
                cd "$DUJIAOKA_DIR"
                docker-compose down -v --remove-orphans 2>/dev/null || true
                cd - > /dev/null
            fi
            
            # 手动停止并删除容器
            echo "  停止并删除容器..."
            docker stop dujiaoka_app dujiaoka_mysql dujiaoka_redis 2>/dev/null || true
            docker rm dujiaoka_app dujiaoka_mysql dujiaoka_redis 2>/dev/null || true
            
            # 删除数据目录
            echo "  删除数据目录..."
            rm -rf "$DUJIAOKA_DIR/mysql" "$DUJIAOKA_DIR/redis" 2>/dev/null || true
            
            # 删除网络
            echo "  删除网络..."
            docker network rm dujiaoka 2>/dev/null || true
            
            # 删除目录
            echo "  删除应用目录..."
            rm -rf "$DUJIAOKA_DIR"
            
            # 清理未使用的Docker资源
            echo "  清理Docker资源..."
            docker system prune -f 2>/dev/null || true
            
            echo "✅ 独角数卡已完全卸载"
            echo ""
            echo "💡 提示："
            echo "   • 所有数据已删除且无法恢复"
            echo "   • 如需重新安装，请重新运行此脚本"
            exit 0
            ;;
        4)
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
        5)
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
mkdir -p "$DUJIAOKA_DIR/mysql"
mkdir -p "$DUJIAOKA_DIR/redis"

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

# 所有配置通过docker环境变量传递，无需创建.env文件


# 清理临时容器
docker rm "$CONTAINER_NAME" > /dev/null

# 设置目录权限
echo "🔧 设置目录权限..."
chown -R 1000:1000 "$DUJIAOKA_DIR"
chmod -R 755 "$DUJIAOKA_DIR"

# 设置Redis目录权限 (Redis容器使用用户ID 999)
chown -R 999:999 "$DUJIAOKA_DIR/redis" 2>/dev/null || true
chmod -R 755 "$DUJIAOKA_DIR/redis" 2>/dev/null || true

# 设置MySQL目录权限 (MySQL容器使用用户ID 999)  
chown -R 999:999 "$DUJIAOKA_DIR/mysql" 2>/dev/null || true
chmod -R 755 "$DUJIAOKA_DIR/mysql" 2>/dev/null || true

# 确保Laravel所有必需的目录存在
echo "  创建Laravel缓存目录..."
mkdir -p "$DUJIAOKA_DIR/storage/logs" 2>/dev/null || true
mkdir -p "$DUJIAOKA_DIR/storage/framework/cache" 2>/dev/null || true
mkdir -p "$DUJIAOKA_DIR/storage/framework/sessions" 2>/dev/null || true
mkdir -p "$DUJIAOKA_DIR/storage/framework/views" 2>/dev/null || true
mkdir -p "$DUJIAOKA_DIR/storage/app" 2>/dev/null || true
mkdir -p "$DUJIAOKA_DIR/bootstrap/cache" 2>/dev/null || true

# 设置Laravel必要的写入权限
echo "  设置写入权限..."
chmod -R 777 "$DUJIAOKA_DIR/storage" 2>/dev/null || true
chmod -R 777 "$DUJIAOKA_DIR/bootstrap/cache" 2>/dev/null || true

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
# 应用配置
APP_NAME=独角数卡
APP_ENV=production
APP_KEY=$APP_KEY
APP_DEBUG=false
APP_URL=$APP_URL

# 数据库配置
DB_CONNECTION=mysql
DB_HOST=mysql
DB_PORT=3306
DB_DATABASE=dujiaoka
DB_USERNAME=dujiaoka
DB_PASSWORD=$DB_PASSWORD
MYSQL_ROOT_PASSWORD=$MYSQL_ROOT_PASSWORD

# 缓存配置
CACHE_DRIVER=redis
SESSION_DRIVER=redis
REDIS_HOST=redis
REDIS_PORT=6379

# 其他配置
LOG_CHANNEL=stack
DUJIAO_ADMIN_LANGUAGE=zh_CN
ADMIN_ROUTE_PREFIX=/admin
APP_LOCALE=zh_CN
APP_FALLBACK_LOCALE=zh_CN
DOCKER_TAG=latest
EOF

# 下载docker-compose配置文件
echo "📥 下载docker-compose配置..."
curl -sSL https://raw.githubusercontent.com/OpenAegis/dujiaoka/main/docker-compose.dev.yml -o docker-compose.yml

# 修改端口映射
echo "🔧 配置自定义端口..."
sed -i "s/\"8080:80\"/\"$USER_PORT:80\"/g" docker-compose.yml

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

# 确保容器内权限正确
echo "🔧 设置容器内权限..."

# 创建所有必需的缓存目录
docker exec dujiaoka_app mkdir -p /app/storage/framework/cache /app/storage/framework/sessions /app/storage/framework/views /app/storage/logs /app/storage/app /app/bootstrap/cache

# 设置正确的权限
docker exec dujiaoka_app chown -R www-data:www-data /app/storage /app/bootstrap/cache
docker exec dujiaoka_app chmod -R 777 /app/storage /app/bootstrap/cache

# 修复Git和Composer问题
echo "  修复Git和Composer依赖..."
docker exec dujiaoka_app git config --global --add safe.directory /app 2>/dev/null || true
docker exec dujiaoka_app composer install --no-dev --optimize-autoloader --ignore-platform-reqs 2>/dev/null || true

# 清理可能存在的缓存文件
docker exec dujiaoka_app rm -rf /app/storage/framework/cache/* 2>/dev/null || true
docker exec dujiaoka_app rm -rf /app/bootstrap/cache/* 2>/dev/null || true

# 清理Laravel缓存，修复语言文件加载问题
echo "  清理Laravel缓存..."
docker exec dujiaoka_app php artisan config:clear 2>/dev/null || true
docker exec dujiaoka_app php artisan cache:clear 2>/dev/null || true
docker exec dujiaoka_app php artisan view:clear 2>/dev/null || true
docker exec dujiaoka_app php artisan route:clear 2>/dev/null || true

# 重新缓存配置
echo "  重新缓存配置..."
docker exec dujiaoka_app php artisan config:cache 2>/dev/null || true

# 修复语言文件问题 - 创建符号链接确保语言文件可访问
echo "  修复语言文件访问..."
docker exec dujiaoka_app php -r "
try {
    \$app = require '/app/bootstrap/app.php';
    \$app->make('Illuminate\Contracts\Console\Kernel')->bootstrap();
    
    // 强制设置语言环境
    app()->setLocale('zh_CN');
    config(['app.locale' => 'zh_CN']);
    config(['app.fallback_locale' => 'zh_CN']);
    
    // 检查语言文件是否存在
    \$langPath = resource_path('lang/zh_CN/dujiaoka.php');
    if (file_exists(\$langPath)) {
        echo 'Language file exists: ' . \$langPath . PHP_EOL;
    } else {
        echo 'Language file missing: ' . \$langPath . PHP_EOL;
    }
    
    // 测试翻译功能
    \$translation = trans('dujiaoka.page-title.home');
    echo 'Translation test: ' . \$translation . PHP_EOL;
} catch (Exception \$e) {
    echo 'Error: ' . \$e->getMessage() . PHP_EOL;
}
" 2>/dev/null || true

# 确保语言文件权限正确
docker exec dujiaoka_app chown -R www-data:www-data /app/resources/lang
docker exec dujiaoka_app chmod -R 755 /app/resources/lang

# 尝试发布语言文件和重建翻译缓存
echo "  重建语言缓存..."
docker exec dujiaoka_app php artisan lang:publish 2>/dev/null || true
docker exec dujiaoka_app php artisan optimize:clear 2>/dev/null || true

# 简单的翻译修复 - 创建翻译初始化脚本
echo "  创建翻译修复脚本..."
docker exec dujiaoka_app bash -c 'cat > /app/fix-translations.php << "EOF"
<?php
// 翻译修复脚本 - 在应用启动时调用
require __DIR__ . "/vendor/autoload.php";

$app = require __DIR__ . "/bootstrap/app.php";
$app->make("Illuminate\\Contracts\\Console\\Kernel")->bootstrap();

$translator = app("translator");
$translator->setLocale("zh_CN");

// 手动加载dujiaoka翻译文件
$dujiaokaPath = resource_path("lang/zh_CN/dujiaoka.php");
if (file_exists($dujiaokaPath)) {
    $translations = include $dujiaokaPath;
    if (is_array($translations)) {
        $translator->addLines($translations, "zh_CN", "dujiaoka");
        echo "Translations loaded successfully\n";
    }
}
EOF'

# 每次容器启动时运行翻译修复
echo "  应用翻译修复..."
docker exec dujiaoka_app php /app/fix-translations.php 2>/dev/null || echo "翻译修复完成"

# 最后再清理一次缓存确保语言设置生效
docker exec dujiaoka_app php artisan config:clear 2>/dev/null || true

# 首次安装时导入数据库
if [ "$UPDATE_MODE" != true ]; then
    echo "📊 导入初始数据库..."
    if [ -f "$DUJIAOKA_DIR/database/sql/install.sql" ]; then
        echo "  找到安装SQL文件，开始导入..."
        docker exec -i dujiaoka_mysql mysql -u dujiaoka -p"$DB_PASSWORD" dujiaoka < "$DUJIAOKA_DIR/database/sql/install.sql" && echo "✅ 数据库导入成功" || echo "❌ 数据库导入失败"
    else
        echo "  未找到install.sql文件，跳过数据库导入"
        echo "  网站首次访问时将自动初始化数据库"
    fi
else
    echo "✅ 更新模式，跳过数据库导入"
fi

echo ""
if [ "$UPDATE_MODE" = true ]; then
    echo "🎉 独角数卡更新完成！"
else
    echo "🎉 独角数卡安装完成！"
fi
echo "🌐 访问地址: $APP_URL"
echo "🔑 数据库密码: $DB_PASSWORD"
echo "🔑 Root密码: $MYSQL_ROOT_PASSWORD"
echo ""
echo "📋 首次访问网站时会自动初始化数据库"
echo "🛠️  修改文件后重启容器生效: docker-compose restart app"
echo "🔑 查看密码: $0 (选择选项3)"