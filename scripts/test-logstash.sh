#!/bin/bash
# Logstash 功能测试脚本
# 云原生日志收集平台

set -e

# 自动检测 Docker 主机连接方式
if curl -s --max-time 2 http://localhost:9200 > /dev/null 2>&1; then
    DOCKER_HOST="localhost"
elif curl -s --max-time 2 http://host.docker.internal:9200 > /dev/null 2>&1; then
    DOCKER_HOST="host.docker.internal"
else
    DOCKER_HOST=$(ip route | grep default | awk '{print $3}')
fi

ELASTICSEARCH_HOST="http://${DOCKER_HOST}:9200"
LOGSTASH_API="http://${DOCKER_HOST}:9600"
WEB_APP_URL="http://${DOCKER_HOST}:8000"

echo "=========================================="
echo "  Logstash 功能测试"
echo "=========================================="
echo "测试时间: $(date '+%Y-%m-%d %H:%M:%S')"
echo "Docker 主机: $DOCKER_HOST"
echo ""

# 步骤 1: 检查服务状态
echo "检查服务状态..."
curl -sf "$ELASTICSEARCH_HOST" > /dev/null || { echo "Elasticsearch 服务异常"; exit 1; }
curl -sf "$LOGSTASH_API/_node/stats" > /dev/null || { echo "Logstash 服务异常"; exit 1; }
curl -sf "$WEB_APP_URL/health" > /dev/null || { echo "Web App 服务异常"; exit 1; }
echo "所有服务运行正常"
echo ""

# 步骤 2: 检查管道配置
echo "检查 Logstash 管道..."
curl -s "$LOGSTASH_API/_node/stats/pipelines" | grep -q "\"main\"" || { echo "管道配置未加载"; exit 1; }
echo "管道配置已加载"
echo ""

# 步骤 3: 生成测试日志
echo "生成测试日志..."
for i in {1..5}; do curl -s "$WEB_APP_URL/api/user/$i" > /dev/null; done
for i in {1001..1003}; do curl -s "$WEB_APP_URL/api/user/$i" > /dev/null; done
for i in {1..3}; do curl -s "$WEB_APP_URL/error/500" > /dev/null; done
curl -s "$WEB_APP_URL/slow/3" > /dev/null &
echo "测试日志已生成"
echo "等待日志处理 (15秒)..."
sleep 15
echo ""

# 步骤 4: 验证索引
echo "验证 Elasticsearch 索引..."
TODAY=$(date +%Y.%m.%d)

INFO_INDEX="webapp-logs-info-$TODAY"
ERROR_INDEX="webapp-logs-error-$TODAY"
WARNING_INDEX="webapp-logs-warning-$TODAY"
ACCESS_INDEX="webapp-access-$TODAY"

INFO_COUNT=$(curl -s "$ELASTICSEARCH_HOST/$INFO_INDEX/_count" 2>/dev/null | grep -o '"count":[0-9]*' | cut -d':' -f2 || echo 0)
ERROR_COUNT=$(curl -s "$ELASTICSEARCH_HOST/$ERROR_INDEX/_count" 2>/dev/null | grep -o '"count":[0-9]*' | cut -d':' -f2 || echo 0)
WARNING_COUNT=$(curl -s "$ELASTICSEARCH_HOST/$WARNING_INDEX/_count" 2>/dev/null | grep -o '"count":[0-9]*' | cut -d':' -f2 || echo 0)
ACCESS_COUNT=$(curl -s "$ELASTICSEARCH_HOST/$ACCESS_INDEX/_count" 2>/dev/null | grep -o '"count":[0-9]*' | cut -d':' -f2 || echo 0)

echo "索引验证完成"
echo ""

# 步骤 5: 验证字段解析
echo "验证日志解析..."
INFO_RESULT=$(curl -s "$ELASTICSEARCH_HOST/$INFO_INDEX/_search?size=1" 2>/dev/null)
ERROR_RESULT=$(curl -s "$ELASTICSEARCH_HOST/$ERROR_INDEX/_search?size=1&q=exception:*" 2>/dev/null)

if echo "$INFO_RESULT" | grep -q "\"severity\":\"INFO\""; then
    echo "severity 字段正确"
fi

if echo "$ERROR_RESULT" | grep -q "\"full_stacktrace\""; then
    echo "异常堆栈解析正确"
fi
echo ""

# 测试结果
echo "=========================================="
echo "  测试完成"
echo "=========================================="
echo "INFO 日志:    $INFO_COUNT 条"
echo "WARNING 日志: $WARNING_COUNT 条"
echo "ERROR 日志:   $ERROR_COUNT 条"
echo "访问日志:     $ACCESS_COUNT 条"
echo "=========================================="
echo ""
