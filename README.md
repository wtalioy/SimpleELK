# SimpleELK

基于 Elasticsearch / Logstash / Kibana / Filebeat 的示例日志采集与演示应用，包含一个用于生成结构化日志的 Flask Web 服务。

## 目录结构

- `docker-compose.yml`：一键启动 ELK + Web 应用
- `elasticsearch/`、`logstash/`、`filebeat/`、`kibana/`：组件配置
- `web-app/`：日志生成 Web 服务与压测脚本
- `scripts/`：启动脚本
- `volumes/`：持久化数据与日志挂载目录
- `docs/`：设计文档（`design.md`）

## 快速开始

```bash
git clone https://github.com/wtalioy/SimpleELK.git
cd SimpleELK

chmod +x scripts/start.sh
./scripts/start.sh

# 查看服务状态
docker compose ps

# 简单健康检查
curl http://localhost:9200        # Elasticsearch
curl http://localhost:5601/api/status  # Kibana
curl http://localhost:8000/health     # Web 应用

# 生成测试流量（可选，便于仪表盘看到更多数据）
cd web-app
python stress_test.py
```

关闭与清理：

```bash
docker compose down
```

## 组件说明

- 镜像版本：Elasticsearch/Logstash/Kibana/Filebeat 使用 `9.2.1`
- 持久化：数据与日志挂载到 `./volumes/...` 目录，仓库已包含占位文件以避免缺失
- Web 应用：暴露 `8000` 端口，日志以 JSON 输出到 stdout，便于 Filebeat 采集
- 更多细节：见 `docs/design.md` 及各组件子文档

## 模块运行与特殊配置速览

- Elasticsearch：单节点；需 `vm.max_map_count` 和 `nofile` 调优，堆内存 `-Xms/-Xmx` 相等；数据/日志挂载见 `elasticsearch/`；Compose 服务名 `elasticsearch`。
- Logstash：Beats 入口 5044，pipeline 位于 `logstash/pipeline/docker-logs.conf`，按 severity/访问日志分流；Compose 服务名 `logstash`。
- Filebeat：仅采集容器名包含 `elk-web-app` 的日志，需挂载 Docker 日志目录与 sock，输出到 Logstash:5044；Compose 服务名 `filebeat`。
- Kibana：连接 `elasticsearch:9200`，健康检查 `/api/status`；`start.sh` 自动导入 `kibana/export.ndjson` 仪表盘；Compose 服务名 `kibana`。
- Web 应用：Gunicorn 端口 8000，stdout JSON 日志，接口与压测要点见 `docs/design.md`；Compose 服务名 `web-app`。

## 脚本

- `scripts/start.sh`：一键启动、等待各服务、生成示例日志、创建 Kibana 索引模式

## 已知注意事项

- 首次启动可能需等待 ES/Kibana 就绪，Compose 已包含健康检查；可通过 `docker compose logs -f <service>` 观察
- 如果修改 Filebeat/Logstash 解析逻辑，需 `docker compose restart filebeat logstash` 使配置生效

