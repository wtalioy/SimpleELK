# SimpleELK

基于 Elasticsearch / Logstash / Kibana / Filebeat 的示例日志采集与演示应用，包含一个用于生成结构化日志的 Flask Web 服务。

## 目录结构

- `docker-compose.yml`：一键启动 ELK + Web 应用
- `elasticsearch/`、`logstash/`、`filebeat/`、`kibana/`：组件配置
  - `elasticsearch/templates/`：索引模板配置
  - `elasticsearch/ilm/`：索引生命周期管理策略
  - `elasticsearch/watchers/`：Elasticsearch Watcher 告警配置
- `web-app/`：日志生成 Web 服务与压测脚本
- `scripts/`：启动脚本和初始化脚本
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

# 初始化 Elasticsearch 配置（索引模板、ILM策略、Watcher告警）
chmod +x scripts/setup_elasticsearch.sh
./scripts/setup_elasticsearch.sh

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
- `scripts/setup_elasticsearch.sh`：初始化 Elasticsearch 配置（索引模板、ILM策略、Watcher告警）

## 增强功能

本项目在基础ELK Stack之上增加了以下增强功能，提高技术含量和可展示性：

### 1. Elasticsearch 索引优化
- **索引模板**：标准化字段映射，优化查询性能
- **索引生命周期管理（ILM）**：自动滚动、归档和删除过期数据
- **Watcher告警**：实时监控错误率和慢请求，自动触发告警

### 2. Logstash Pipeline 增强
- **响应时间分析**：自动分级（fast/normal/slow/very_slow）
- **User-Agent解析**：提取浏览器、操作系统、设备信息
- **业务指标计算**：API端点识别、资源类型提取、请求分类
- **时间窗口分析**：小时、星期、时段分析

### 3. 高级分析功能
- 多维度日志分析（时间、端点、用户行为等）
- 实时告警机制
- 性能指标追踪（响应时间分布、错误率趋势等）

详细说明请参考：`docs/enhancements.md`

## 已知注意事项

- 首次启动可能需等待 ES/Kibana 就绪，Compose 已包含健康检查；可通过 `docker compose logs -f <service>` 观察
- 如果修改 Filebeat/Logstash 解析逻辑，需 `docker compose restart filebeat logstash` 使配置生效
- **Watcher功能**：Elasticsearch Watcher需要X-Pack（商业版）或Open Distro for Elasticsearch。在标准Elasticsearch中，Watcher可能不可用，但其他功能（ILM、索引模板）仍然可用
- 建议在启动服务后运行 `scripts/setup_elasticsearch.sh` 来初始化索引模板和ILM策略

