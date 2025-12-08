# SimpleELK 设计与运维说明

## 1. 概览

- 目标：提供可一键启动的 ELK（Elasticsearch / Logstash / Kibana / Filebeat）日志采集演示环境，包含一套生成结构化/异常日志的 Flask Web 应用。
- 版本：Elasticsearch / Logstash / Kibana / Filebeat 使用 `9.2.1`；Web 应用基于 Python 3.9 + Flask + Gunicorn。
- 部署方式：`docker compose` 单机部署，所有数据与日志挂载到仓库内 `volumes/` 目录。

## 2. 架构与数据流

1) Web 应用（`web-app`，端口 8000）生成 JSON 结构化日志（stdout）与 Gunicorn 访问日志。  
2) Filebeat（端口 5066）读取 `/var/lib/docker/containers/*/*.log`，仅保留 `elk-web-app` 容器日志，识别日志类型并做基础清洗后发送至 Logstash:5044。  
3) Logstash（端口 5044/5000/9600）按日志类型和级别解析、打标签、分索引，写入 Elasticsearch:9200。  
4) Kibana（端口 5601）提供可视化与管理界面。  
5) Elasticsearch（端口 9200/9300）存储与检索日志，使用单节点模式，禁用安全（开发场景）。

## 3. 环境要求与系统调优

- 硬件：CPU≥2 核，内存≥4GB（ES 至少 2GB，可用内存 ≥4GB）。磁盘≥20GB。
- 软件：Docker ≥20.10，Docker Compose ≥2.0；Linux/macOS。
- Linux 需预设：
  - `vm.max_map_count=262144`
  - `nofile` 软/硬限制 65536
  - 示例：
    ```bash
    sudo sysctl -w vm.max_map_count=262144
    echo "vm.max_map_count=262144" | sudo tee -a /etc/sysctl.conf
    echo "* soft nofile 65536" | sudo tee -a /etc/security/limits.conf
    echo "* hard nofile 65536" | sudo tee -a /etc/security/limits.conf
    ```

## 4. 仓库结构

- `docker-compose.yml`：编排 ELK + Web 应用。
- `elasticsearch/`：`elasticsearch.yml`。
- `logstash/`：`config/logstash.yml`、`pipeline/docker-logs.conf`。
- `filebeat/`：`filebeat.yml`。
- `kibana/`：`kibana.yml`。
- `web-app/`：Flask 应用、Dockerfile、压测脚本。
- `scripts/`：启动与自动准备脚本。
- `volumes/`：数据与日志挂载目录（仓库含 `.gitkeep` 占位，首次即可启动）。
- `docs/`：设计与部署文档（本文件）。

## 5. 组件要点与配置摘要

### Elasticsearch
- 角色/版本：单节点 master+data+ingest，`docker.elastic.co/elasticsearch/elasticsearch:9.2.1`，开发模式禁用 X-Pack Security。
- 端口：HTTP 9200，Transport 9300；健康状态需 green/yellow。
- 关键配置：`cluster.name=docker-cluster`，`node.name=es-node-1`，`discovery.type=single-node`，`bootstrap.memory_lock: true`，缓存/索引缓冲 10%/20%/10%，线程池写/搜队列 1000，JVM `-Xms1g -Xmx1g`。
- 资源与挂载：数据 `./volumes/elasticsearch/data`，日志 `./volumes/elasticsearch/logs`，配置只读挂载；compose 资源限制 memory 2g/1g，cpu 2/1，ulimit memlock -1、nofile 65536。
- 前置：Linux 需 `vm.max_map_count=262144`、`nofile` 65536。目录需存在且可写（仓库已带占位）。
- 索引设置：如 `refresh_interval` 需通过 Index Template/索引 API，不放在 `elasticsearch.yml`。
- 故障排查：启动失败看目录权限与 sysctl；健康 red/yellow 检查资源与日志。

### Logstash
- 版本：`docker.elastic.co/logstash/logstash:9.2.1`，端口 Beats 5044，TCP/UDP 5000 预留，API 9600。
- Pipeline：输入 Beats；Filter 识别 `log_type` (application/gunicorn_access/other)，合并异常栈，解析 level→`severity_lowercase`，HTTP 分类与慢请求打标，时间戳解析；Gunicorn 日志 Grok/拆分 URL；通用添加容器信息与 `processed_at`，移除冗余字段。
- 输出索引：`webapp-logs-%{severity_lowercase}-%{+YYYY.MM.dd}`，`webapp-access-%{+YYYY.MM.dd}`，`webapp-other-%{+YYYY.MM.dd}`。
- 挂载：`logstash/config/logstash.yml`、`logstash/pipeline` 只读；需改配置时重启。
- 注意：索引命名依赖 `severity_lowercase`；关注 `_grokparsefailure`、`_dateparsefailure` 标签；默认 memory queue，若需容错可改持久化队列并挂载数据目录。

### Filebeat
- 版本：`docker.elastic.co/beats/filebeat:9.2.1`，HTTP 5066。
- 输入与过滤：`filestream` 读取 `/var/lib/docker/containers/*/*.log`，仅容器名含 `elk-web-app`；脚本判定 `log_type`（application/gunicorn_access/other）；应用日志 `decode_json_fields` + 提升字段；Gunicorn `dissect` + HTTP 字段；通用添加 docker/host 元数据，时间戳解析，`fingerprint` 去重，`drop_fields` 精简。
- 输出：Logstash:5044，负载均衡，worker 2，bulk 2048，压缩 3。
- 挂载：Docker 日志目录与 sock、`filebeat.yml` 只读、`filebeat_data`、`filebeat_logs`。
- 注意：JS 处理器需 ES5；修改配置需重启 Filebeat；容器名需与过滤一致。

### Kibana
- 版本：`docker.elastic.co/kibana/kibana:9.2.1`，端口 5601。
- 连接：`elasticsearch.hosts: ["http://elasticsearch:9200"]`；开发默认无安全，生产应启用 X-Pack/TLS。
- 健康：`/api/status` 包含 `available`；依赖 ES 就绪。
- 索引模式：`webapp-logs-*`、`webapp-access-*`、`webapp-other-*`；时间字段 `@timestamp`；可基于 `severity`/`severity_lowercase` 做过滤和可视化。
- 配置要点：`server.host: 0.0.0.0`，可按需设置 `server.publicBaseUrl`、`logging.dest`，安全场景需配置凭据/Token。

### Web 应用
- 版本/运行：Gunicorn 8000，基于 `python:3.9-slim`，`PYTHONUNBUFFERED=1` 确保日志实时刷出，非 root `appuser`。
- 接口：`/`、`/health`、`/api/user/<id>`、`/api/product/<id>`、`/api/order` (GET/POST)、`/api/login`、`/error/404`、`/error/500`、`/error/timeout`。
- 日志：stdout JSON，字段含 timestamp/level/http_method/url/status_code/response_time_ms/ip/user_agent/exception.stacktrace；仅容器名含 `elk-web-app` 才被 Filebeat 采集。
- 压测：`stress_test.py` 可调 `TARGET_URL`、并发、持续时间、请求间隔、verbose；输出 QPS/状态码分布/延时分位。
- Dockerfile：健康检查 `/health`，可调 Gunicorn workers 以配合 CPU。

## 6. 数据持久化与目录

compose 通过 bind mount 挂载：
- ES 数据：`./volumes/elasticsearch/data` -> `/usr/share/elasticsearch/data`
- ES 日志：`./volumes/elasticsearch/logs` -> `/usr/share/elasticsearch/logs`
- Filebeat 数据/日志：`./volumes/filebeat/{data,logs}` -> `/usr/share/filebeat/data`、`/var/log/filebeat`

仓库已包含占位目录，可直接 `docker compose up -d`；若删除目录需重新 `mkdir -p` 后再启动。

## 7. 运营与脚本

- `scripts/start.sh`：一键启动、等待 ES/Logstash/Web/Kibana，就绪后生成示例日志并创建 Kibana 索引模式。

常用操作：
```bash
# 查看日志
docker compose logs -f elasticsearch
docker compose logs -f logstash
docker compose logs -f filebeat
docker compose logs -f kibana
docker compose logs -f web-app

# 重启单个组件使配置生效
docker compose restart filebeat logstash
```

## 8. 故障排查速查

- Compose 启动失败：确认 `volumes/...` 目录存在；检查系统 `vm.max_map_count` 与 `nofile`；查看对应服务日志。
- ES 红黄：等待节点启动；检查 `docker compose logs elasticsearch`；验证健康检查命令。
- Filebeat 无数据：确认容器名 `elk-web-app` 是否匹配；检查 5044 通路。
- Logstash 未写入：查看 `_grokparsefailure` 标签；验证 pipeline 与索引命名；检查到 ES 的连通性。
- Kibana 无法访问：确认 5601 端口、`/api/status` 输出；若 ES 未就绪，等待或重启 Kibana。

## 9. 参考与扩展

- 生产化建议：启用 X-Pack 安全、使用受管卷/独立存储、调优 JVM Heap、为 Logstash 配置持久化队列与监控、为 Filebeat 启用 TLS 与认证。 

