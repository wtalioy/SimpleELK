#!/bin/bash
# ELK Stack 清理脚本
# 云原生日志收集平台

set -e

echo "=========================================="
echo "  云原生日志收集平台 - ELK Stack 清理"
echo "=========================================="

echo "停止并删除容器..."
docker-compose down -v 2>/dev/null || docker compose down -v 2>/dev/null || true

read -p "是否删除数据目录? (y/N): " confirm
if [ "$confirm" = "y" ] || [ "$confirm" = "Y" ]; then
    echo "删除数据目录..."
    rm -rf data/
    rm -rf logs/
    echo "数据目录已删除"
else
    echo "保留数据目录"
fi

echo "清理 Docker 网络..."
docker network prune -f 2>/dev/null || true

read -p "是否删除 ELK 相关镜像? (y/N): " confirm_images
if [ "$confirm_images" = "y" ] || [ "$confirm_images" = "Y" ]; then
    echo "删除 ELK 镜像..."
    docker rmi docker.elastic.co/elasticsearch/elasticsearch:9.2.1 2>/dev/null || true
    docker rmi docker.elastic.co/logstash/logstash:9.2.1 2>/dev/null || true
    docker rmi docker.elastic.co/kibana/kibana:9.2.1 2>/dev/null || true
    echo "镜像已删除"
fi

echo ""
echo "=========================================="
echo "  清理完成！"
echo "=========================================="
