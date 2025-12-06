#!/bin/bash
# Filebeat 配置测试脚本
# 云原生日志收集平台

set -e

IMAGE_NAME="docker.elastic.co/beats/filebeat:9.2.1"

echo "=========================================="
echo "  Filebeat 配置测试"
echo "=========================================="

# 确保在项目根目录
if [ ! -f "filebeat/filebeat.yml" ]; then
    [ -f "../filebeat/filebeat.yml" ] && cd .. || { echo "错误: 找不到配置文件"; exit 1; }
fi

CONFIG_PATH="$(realpath filebeat/filebeat.yml)"

# 1. 测试配置文件语法
echo "检查配置文件语法..."
if docker run --rm \
    -v "${CONFIG_PATH}:/usr/share/filebeat/filebeat.yml:ro" \
    ${IMAGE_NAME} \
    filebeat test config -e --strict.perms=false > /dev/null 2>&1; then
    echo "配置文件语法正确"
else
    echo "配置文件存在错误:"
    docker run --rm \
        -v "${CONFIG_PATH}:/usr/share/filebeat/filebeat.yml:ro" \
        ${IMAGE_NAME} \
        filebeat test config -e --strict.perms=false
    exit 1
fi

# 2. 测试输出连接（如果 Logstash 已运行）
if docker ps --format '{{.Names}}' | grep -q "^logstash$"; then
    echo "测试 Logstash 连接..."
    if docker run --rm \
        --network simpleelk_elk \
        -v "${CONFIG_PATH}:/usr/share/filebeat/filebeat.yml:ro" \
        ${IMAGE_NAME} \
        filebeat test output -e --strict.perms=false 2>&1 | grep -q "talk to server"; then
        echo "Logstash 连接成功"
    else
        echo "无法连接到 Logstash (服务可能未启动)"
    fi
else
    echo "跳过连接测试 (Logstash 未运行)"
fi

echo ""
echo "=========================================="
echo "  测试完成"
echo "=========================================="
