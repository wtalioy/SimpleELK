#!/bin/bash
# ============================================
# Elasticsearch 初始化脚本
# 用于创建索引模板、ILM策略和Watcher告警
# ============================================

ES_HOST="http://localhost:9200"
MAX_RETRIES=30
RETRY_INTERVAL=5

echo "等待 Elasticsearch 启动..."
for i in $(seq 1 $MAX_RETRIES); do
    if curl -sf "$ES_HOST/_cluster/health" > /dev/null 2>&1; then
        echo "Elasticsearch 已就绪"
        break
    fi
    if [ $i -eq $MAX_RETRIES ]; then
        echo "错误: Elasticsearch 未能在预期时间内启动"
        exit 1
    fi
    echo "等待中... ($i/$MAX_RETRIES)"
    sleep $RETRY_INTERVAL
done

# 等待集群状态为 green 或 yellow
echo "等待集群状态就绪..."
for i in $(seq 1 20); do
    STATUS=$(curl -s "$ES_HOST/_cluster/health" | grep -o '"status":"[^"]*"' | cut -d'"' -f4)
    if [ "$STATUS" = "green" ] || [ "$STATUS" = "yellow" ]; then
        echo "集群状态: $STATUS"
        break
    fi
    sleep 2
done

# 创建 ILM 策略
echo "创建 ILM 策略..."
curl -X PUT "$ES_HOST/_ilm/policy/webapp-logs-policy" \
  -H 'Content-Type: application/json' \
  -d @elasticsearch/ilm/webapp-logs-policy.json

curl -X PUT "$ES_HOST/_ilm/policy/webapp-access-policy" \
  -H 'Content-Type: application/json' \
  -d @elasticsearch/ilm/webapp-access-policy.json

# 创建索引模板
echo "创建索引模板..."
curl -X PUT "$ES_HOST/_index_template/webapp-logs-template" \
  -H 'Content-Type: application/json' \
  -d @elasticsearch/templates/webapp-logs-template.json

curl -X PUT "$ES_HOST/_index_template/webapp-access-template" \
  -H 'Content-Type: application/json' \
  -d @elasticsearch/templates/webapp-access-template.json

# 创建初始索引（带别名）
echo "创建初始索引..."
curl -X PUT "$ES_HOST/webapp-logs-error-000001" \
  -H 'Content-Type: application/json' \
  -d '{
    "aliases": {
      "webapp-logs": {
        "is_write_index": true
      }
    }
  }'

curl -X PUT "$ES_HOST/webapp-logs-warning-000001" \
  -H 'Content-Type: application/json' \
  -d '{
    "aliases": {
      "webapp-logs": {
        "is_write_index": false
      }
    }
  }'

curl -X PUT "$ES_HOST/webapp-logs-info-000001" \
  -H 'Content-Type: application/json' \
  -d '{
    "aliases": {
      "webapp-logs": {
        "is_write_index": false
      }
    }
  }'

curl -X PUT "$ES_HOST/webapp-access-000001" \
  -H 'Content-Type: application/json' \
  -d '{
    "aliases": {
      "webapp-access": {
        "is_write_index": true
      }
    }
  }'

# 创建 Watcher 告警（如果文件存在）
if [ -f "elasticsearch/watchers/error-rate-watcher.json" ]; then
    echo "创建 Watcher 告警..."
    curl -X PUT "$ES_HOST/_watcher/watch/error-rate-alert" \
      -H 'Content-Type: application/json' \
      -d @elasticsearch/watchers/error-rate-watcher.json
fi

if [ -f "elasticsearch/watchers/slow-request-watcher.json" ]; then
    curl -X PUT "$ES_HOST/_watcher/watch/slow-request-alert" \
      -H 'Content-Type: application/json' \
      -d @elasticsearch/watchers/slow-request-watcher.json
fi

echo "Elasticsearch 初始化完成！"

