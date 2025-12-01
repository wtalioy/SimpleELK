# Elasticsearch 配置说明

## 概述

本目录包含 Elasticsearch 的核心配置文件，用于云原生日志收集平台（ELK Stack）的部署。

## 文件说明

### elasticsearch.yml

Elasticsearch 主配置文件，包含以下优化配置：

#### 🎯 核心配置
- **集群名称**: docker-cluster
- **节点名称**: es-node-1
- **节点角色**: master + data + ingest
- **发现模式**: 单节点模式（开发/测试环境）

#### ⚡ 性能优化
- **内存锁定**: 启用 `bootstrap.memory_lock`，防止swap影响性能
- **HTTP压缩**: 启用压缩，减少网络传输
- **查询缓存**: 10% 堆内存用于查询缓存
- **字段缓存**: 20% 堆内存用于字段数据缓存
- **线程池优化**: 写入/搜索队列大小设置为1000

#### 🔧 资源配置
- **JVM Heap**: 1GB（通过 docker-compose.yml 配置）
- **最大分片数**: 3000 per node
- **索引缓冲**: 10% 堆内存

#### 🔐 安全配置
- **开发环境**: 禁用 X-Pack Security
- **生产环境**: 建议启用安全功能（详见部署文档）

## Docker Volume 数据持久化

```yaml
volumes:
  - elasticsearch_data:/usr/share/elasticsearch/data  # 索引数据
  - elasticsearch_logs:/usr/share/elasticsearch/logs  # 日志文件
  - ./elasticsearch.yml:/usr/share/elasticsearch/config/elasticsearch.yml:ro  # 配置文件（只读）
```

数据持久化到宿主机目录：
- **数据**: `../volumes/elasticsearch/data/`
- **日志**: `../volumes/elasticsearch/logs/`

## 重要注意事项

### 索引级别配置

从 Elasticsearch 5.x 开始，索引级别的设置（如 `index.refresh_interval`、`index.merge.*`）**不能**在 `elasticsearch.yml` 中配置。

应通过以下方式设置：

#### 方式1: Index Template（推荐）

```bash
curl -X PUT "http://localhost:9200/_index_template/default_template" \
  -H 'Content-Type: application/json' -d'
{
  "index_patterns": ["*"],
  "template": {
    "settings": {
      "index.refresh_interval": "30s",
      "index.number_of_replicas": 0
    }
  }
}'
```

#### 方式2: 直接设置索引

```bash
curl -X PUT "http://localhost:9200/my_index/_settings" \
  -H 'Content-Type: application/json' -d'
{
  "index": {
    "refresh_interval": "30s"
  }
}'
```

### 版本兼容性

本配置针对 **Elasticsearch 9.2.1** 优化，已移除以下废弃配置：

- ❌ `indices.query.bool.max_clause_count` (已弃用)
- ❌ `xpack.ilm.enabled` (默认启用)
- ❌ `xpack.monitoring.collection.enabled` (已弃用)

如果使用其他版本的 Elasticsearch，请参考官方文档调整配置。

## 快速启动

```bash
# 1. 仅启动 Elasticsearch
docker-compose up -d elasticsearch

# 2. 查看日志
docker-compose logs -f elasticsearch

# 3. 健康检查
../scripts/es-health-check.sh

# 4. 验证服务
curl http://localhost:9200
```

## 故障排查

### 容器无法启动

```bash
# 检查日志
docker-compose logs elasticsearch

# 检查配置文件语法
docker exec elasticsearch cat /usr/share/elasticsearch/config/elasticsearch.yml

# 验证内存锁定
curl http://localhost:9200/_nodes?filter_path=**.mlockall
```

### 数据持久化问题

```bash
# 检查数据目录权限
ls -lh ../volumes/elasticsearch/data/

# 确保目录有写权限
chmod -R 777 ../volumes/elasticsearch/
```

