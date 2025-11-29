#!/bin/bash
# 创建 Kibana 索引模式脚本
# 云原生日志收集平台

set -e

KIBANA_URL="${KIBANA_URL:-http://localhost:5601}"
ES_URL="${ES_URL:-http://localhost:9200}"

echo "=========================================="
echo "  创建 Kibana 索引模式"
echo "=========================================="

# 等待 Kibana 就绪
echo "等待 Kibana 就绪..."
until curl -s "$KIBANA_URL/api/status" | grep -q "available"; do
    echo "Kibana 未就绪，等待中..."
    sleep 5
done
echo "Kibana 已就绪"

# 等待 Elasticsearch 有数据
echo "检查 Elasticsearch 索引..."
until curl -s "$ES_URL/_cat/indices" | grep -q "docker-logs"; do
    echo "等待日志数据..."
    sleep 5
done
echo "发现日志索引"

# 创建索引模式
echo "创建索引模式 docker-logs-*..."
curl -X POST "$KIBANA_URL/api/saved_objects/index-pattern/docker-logs" \
  -H "kbn-xsrf: true" \
  -H "Content-Type: application/json" \
  -d '{
    "attributes": {
      "title": "docker-logs-*",
      "timeFieldName": "@timestamp"
    }
  }'

echo ""
echo "=========================================="
echo "  索引模式创建完成！"
echo "=========================================="
echo ""
echo "访问 Kibana: $KIBANA_URL"
echo "进入 Discover 页面查看日志"
echo ""
