#!/bin/bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

ES_URL="${ES_URL:-http://localhost:9200}"
KIBANA_URL="${KIBANA_URL:-http://localhost:5601}"
LOGSTASH_URL="${LOGSTASH_URL:-http://localhost:9600}"
WEB_URL="${WEB_URL:-http://localhost:8000}"

echo "=========================================="
echo "  启动 SimpleELK"
echo "=========================================="

echo "1) 构建 web-app 镜像..."
docker compose build web-app

echo "2) 启动 docker compose 服务..."
docker compose up -d

echo -n "3) 等待 Elasticsearch..."
until curl -sf "$ES_URL/_cluster/health?wait_for_status=yellow&timeout=1s" > /dev/null; do
  echo -n "."
  sleep 5
done
echo "ok"

echo -n "4) 等待 Logstash..."
until curl -sf "$LOGSTASH_URL/_node/stats" > /dev/null; do
  echo -n "."
  sleep 5
done
echo "ok"

echo -n "5) 等待 Web 应用..."
until curl -sf "$WEB_URL/health" > /dev/null; do
  echo -n "."
  sleep 3
done
echo "ok"

echo -n "6) 等待 Kibana..."
until curl -s "$KIBANA_URL/api/status" | grep -q "available"; do
  echo -n "."
  sleep 5
done
echo "ok"

if [ -f "$ROOT_DIR/kibana/dashboard.ndjson" ]; then
  echo -n "7) 导入 Kibana 仪表盘..."
  curl -s -X POST "$KIBANA_URL/api/saved_objects/_import?overwrite=true" \
    -H "kbn-xsrf: true" \
    -F "file=@$ROOT_DIR/kibana/dashboard.ndjson" > /dev/null || true
  echo "ok"
fi

if [ -x "$ROOT_DIR/scripts/setup_elasticsearch.sh" ]; then
  echo -n "8) 初始化 Elasticsearch（模板/ILM/初始索引/Watcher）..."
  "$ROOT_DIR/scripts/setup_elasticsearch.sh" || {
    echo "⚠️  Elasticsearch 初始化脚本执行失败，请检查日志" >&2
  }
  echo "ok"
fi

echo ""
echo "=========================================="
echo "  启动完成"
echo "  - Elasticsearch: $ES_URL"
echo "  - Kibana:        $KIBANA_URL"
echo "  - Logstash API:  $LOGSTASH_URL"
echo "  - Web 应用:      $WEB_URL"
echo "=========================================="

