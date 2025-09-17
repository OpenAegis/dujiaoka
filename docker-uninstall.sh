#!/bin/bash
# 独角数卡 Docker 完全卸载脚本
# 警告：此脚本将删除所有相关的容器、镜像、数据卷和文件！

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 显示警告信息
echo -e "${RED}⚠️  独角数卡 Docker 完全卸载脚本${NC}"
echo -e "${RED}================================${NC}"
echo -e "${YELLOW}警告：此操作将完全删除以下内容：${NC}"
echo -e "  • 所有独角数卡相关容器"
echo -e "  • 所有独角数卡相关镜像"
echo -e "  • 所有数据卷（包括数据库数据）"
echo -e "  • /opt/dujiaoka 目录及所有文件"
echo -e "  • Docker网络配置"
echo ""
echo -e "${RED}数据将无法恢复！${NC}"
echo ""

# 确认操作
read -p "确定要继续吗？请输入 'YES' 来确认: " confirm
if [ "$confirm" != "YES" ]; then
    echo -e "${GREEN}操作已取消${NC}"
    exit 0
fi

echo ""
echo -e "${BLUE}开始卸载独角数卡...${NC}"

# 1. 停止并删除容器
echo -e "${YELLOW}1. 停止并删除容器...${NC}"
docker stop dujiaoka_app dujiaoka_mysql dujiaoka_redis 2>/dev/null || true
docker rm dujiaoka_app dujiaoka_mysql dujiaoka_redis 2>/dev/null || true

# 通过docker-compose清理（如果存在）
if [ -f "docker-compose.yml" ]; then
    echo "  使用 docker-compose 清理..."
    docker-compose down -v --remove-orphans 2>/dev/null || true
fi

# 查找并删除所有相关容器
echo "  删除所有独角数卡相关容器..."
docker ps -a --filter "name=dujiaoka" --format "{{.Names}}" | xargs -r docker rm -f 2>/dev/null || true

# 2. 删除镜像
echo -e "${YELLOW}2. 删除镜像...${NC}"
# 删除本地构建的镜像
docker rmi dujiaoka:latest 2>/dev/null || true
# 删除GHCR镜像
docker rmi ghcr.io/openaegis/dujiaoka:latest 2>/dev/null || true
docker rmi ghcr.io/openAegis/dujiaoka:latest 2>/dev/null || true
# 删除所有独角数卡相关镜像
docker images --filter "reference=*dujiaoka*" --format "{{.Repository}}:{{.Tag}}" | xargs -r docker rmi 2>/dev/null || true

# 3. 删除数据卷
echo -e "${YELLOW}3. 删除数据卷...${NC}"
docker volume rm dujiaoka_mysql_data 2>/dev/null || true
docker volume rm dujiaoka_redis_data 2>/dev/null || true
docker volume rm dujiaoka_app_storage 2>/dev/null || true
docker volume rm dujiaoka_app_public 2>/dev/null || true
# 删除带项目前缀的卷
docker volume ls --filter "name=*mysql_data" --format "{{.Name}}" | grep -E "(dujiaoka|独角)" | xargs -r docker volume rm 2>/dev/null || true
docker volume ls --filter "name=*redis_data" --format "{{.Name}}" | grep -E "(dujiaoka|独角)" | xargs -r docker volume rm 2>/dev/null || true
docker volume ls --filter "name=*app_storage" --format "{{.Name}}" | grep -E "(dujiaoka|独角)" | xargs -r docker volume rm 2>/dev/null || true
docker volume ls --filter "name=*app_public" --format "{{.Name}}" | grep -E "(dujiaoka|独角)" | xargs -r docker volume rm 2>/dev/null || true

# 4. 删除网络
echo -e "${YELLOW}4. 删除网络...${NC}"
docker network rm dujiaoka 2>/dev/null || true
docker network ls --filter "name=*dujiaoka*" --format "{{.Name}}" | xargs -r docker network rm 2>/dev/null || true

# 5. 删除文件目录
echo -e "${YELLOW}5. 删除文件目录...${NC}"
if [ -d "/opt/dujiaoka" ]; then
    echo "  删除 /opt/dujiaoka 目录..."
    rm -rf /opt/dujiaoka
    echo "  ✅ /opt/dujiaoka 目录已删除"
fi

# 删除当前目录的配置文件（可选）
read -p "是否删除当前目录的 docker-compose.yml 和 .env 文件？ (y/N): " delete_local
if [[ $delete_local =~ ^[Yy]$ ]]; then
    rm -f docker-compose.yml docker-compose.dev.yml .env .env.docker docker-init.sh docker-uninstall.sh 2>/dev/null || true
    echo "  ✅ 本地配置文件已删除"
fi

# 6. 清理未使用的Docker资源
echo -e "${YELLOW}6. 清理未使用的Docker资源...${NC}"
docker system prune -f 2>/dev/null || true

# 7. 验证清理结果
echo -e "${YELLOW}7. 验证清理结果...${NC}"
echo "剩余的独角数卡相关资源："

# 检查容器
CONTAINERS=$(docker ps -a --filter "name=dujiaoka" --format "{{.Names}}" 2>/dev/null || true)
if [ -n "$CONTAINERS" ]; then
    echo -e "${RED}  警告：发现残留容器: $CONTAINERS${NC}"
else
    echo -e "${GREEN}  ✅ 容器清理完成${NC}"
fi

# 检查镜像
IMAGES=$(docker images --filter "reference=*dujiaoka*" --format "{{.Repository}}:{{.Tag}}" 2>/dev/null || true)
if [ -n "$IMAGES" ]; then
    echo -e "${RED}  警告：发现残留镜像: $IMAGES${NC}"
else
    echo -e "${GREEN}  ✅ 镜像清理完成${NC}"
fi

# 检查数据卷
VOLUMES=$(docker volume ls --filter "name=*dujiaoka*" --format "{{.Name}}" 2>/dev/null || true)
if [ -n "$VOLUMES" ]; then
    echo -e "${RED}  警告：发现残留数据卷: $VOLUMES${NC}"
else
    echo -e "${GREEN}  ✅ 数据卷清理完成${NC}"
fi

# 检查网络
NETWORKS=$(docker network ls --filter "name=*dujiaoka*" --format "{{.Name}}" 2>/dev/null || true)
if [ -n "$NETWORKS" ]; then
    echo -e "${RED}  警告：发现残留网络: $NETWORKS${NC}"
else
    echo -e "${GREEN}  ✅ 网络清理完成${NC}"
fi

# 检查文件目录
if [ -d "/opt/dujiaoka" ]; then
    echo -e "${RED}  警告：/opt/dujiaoka 目录仍然存在${NC}"
else
    echo -e "${GREEN}  ✅ 文件目录清理完成${NC}"
fi

echo ""
echo -e "${GREEN}🎉 独角数卡卸载完成！${NC}"
echo -e "${BLUE}所有相关的容器、镜像、数据卷和文件都已删除。${NC}"
echo ""

# 显示Docker磁盘使用情况
echo -e "${YELLOW}当前Docker磁盘使用情况：${NC}"
docker system df 2>/dev/null || true

echo ""
echo -e "${YELLOW}提示：${NC}"
echo -e "  • 如需重新安装，请重新运行部署命令"
echo -e "  • 如需清理更多Docker资源，可运行: docker system prune -a --volumes"
echo -e "  • 数据已完全删除，无法恢复"