#!/bin/bash
# ELK Stack 初始化脚本
# 云原生日志收集平台

set -e

echo "=========================================="
echo "  云原生日志收集平台 - ELK Stack 初始化"
echo "=========================================="

if ! command -v docker &> /dev/null; then
    echo "错误: Docker 未安装，请先安装 Docker"
    exit 1
fi

if ! command -v docker-compose &> /dev/null && ! docker compose version &> /dev/null; then
    echo "错误: Docker Compose 未安装，请先安装 Docker Compose"
    exit 1
fi

echo "创建必要的目录..."
mkdir -p data/elasticsearch
mkdir -p logs

echo "设置目录权限..."
chmod -R 777 data/elasticsearch

echo "检查系统配置..."
CURRENT_MAP_COUNT=$(cat /proc/sys/vm/max_map_count 2>/dev/null || echo "0")
if [ "$CURRENT_MAP_COUNT" -lt 262144 ]; then
    echo "设置 vm.max_map_count..."
    sudo sysctl -w vm.max_map_count=262144
    echo "vm.max_map_count=262144" | sudo tee -a /etc/sysctl.conf
fi

echo ""
echo "=========================================="
echo "  初始化完成！"
echo "=========================================="
echo ""
echo "启动服务: docker-compose up -d"
echo "查看日志: docker-compose logs -f"
echo "停止服务: docker-compose down"
echo ""
echo "服务访问地址:"
echo "  - Elasticsearch: http://localhost:9200"
echo "  - Kibana:        http://localhost:5601"
echo "  - Logstash API:  http://localhost:9600"
echo ""
