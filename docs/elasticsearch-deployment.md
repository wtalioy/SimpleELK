# Elasticsearch 部署文档

## 环境要求

### 硬件配置

| 组件 | 最低要求 | 说明 |
|------|---------|------|
| CPU | 2 核 | |
| 内存 | 4 GB | ES 需要至少 2GB，系统预留 2GB |
| 磁盘 | 20 GB | 根据日志量调整 |

### 软件环境

```bash
Docker: >= 20.10.0
Docker Compose: >= 2.0.0
操作系统: macOS 11.0+ / Linux 4.0+
```

### 系统配置

**macOS:**
- Docker Desktop 内存设置: 至少 4GB
- 文件描述符: `ulimit -n 65536`

**Linux:**
```bash
# 虚拟内存设置
sudo sysctl -w vm.max_map_count=262144
echo "vm.max_map_count=262144" | sudo tee -a /etc/sysctl.conf

# 文件描述符限制
echo "* soft nofile 65536" | sudo tee -a /etc/security/limits.conf
echo "* hard nofile 65536" | sudo tee -a /etc/security/limits.conf
```

---

## 部署步骤

### 1. 克隆项目

```bash
git clone https://github.com/wtalioy/SimpleELK.git
cd SimpleELK
git checkout feature/elasticsearch-deployment
```

### 2. 创建数据目录

```bash
mkdir -p volumes/elasticsearch/{data,logs}
chmod -R 777 volumes/elasticsearch/
```

### 3. 启动 Elasticsearch

```bash
docker-compose up -d elasticsearch
```

### 4. 验证部署

```bash
# 等待服务启动（约30秒）
sleep 30

# 检查容器状态
docker ps | grep elasticsearch

# 访问 HTTP 接口
curl http://localhost:9200

# 运行健康检查
./scripts/es-health-check.sh
```

预期输出：
```json
{
  "name" : "es-node-1",
  "cluster_name" : "docker-cluster",
  "version" : {
    "number" : "9.2.1"
  }
}
```

---

## 配置说明

### elasticsearch.yml 配置

文件位置: `elasticsearch/elasticsearch.yml`

#### 核心配置

```yaml
# 集群配置
cluster.name: "docker-cluster"
node.name: "es-node-1"
node.roles: [ master, data, ingest ]
discovery.type: single-node

# 网络配置
network.host: 0.0.0.0
http.port: 9200
transport.port: 9300
```

#### 性能优化

```yaml
# 内存锁定（防止 swap）
bootstrap.memory_lock: true

# 缓存配置
indices.queries.cache.size: 10%
indices.fielddata.cache.size: 20%
indices.memory.index_buffer_size: 10%

# 线程池配置
thread_pool.write.queue_size: 1000
thread_pool.search.queue_size: 1000
```

**重要说明**:

1. **内存锁定**: 防止操作系统将 ES 内存交换到磁盘，保证性能稳定
2. **缓存优化**: 合理分配堆内存用于查询缓存和字段数据缓存
3. **线程池**: 提升并发写入和搜索能力

### docker-compose.yml 配置

文件位置: `docker-compose.yml`

#### JVM 内存配置

```yaml
environment:
  - "ES_JAVA_OPTS=-Xms1g -Xmx1g"
```

**配置原则**:
- Xms（初始堆内存）和 Xmx（最大堆内存）必须相等，避免动态调整导致性能抖动
- 堆内存不超过物理内存的 50%
- 单节点建议 1GB-2GB

#### 资源限制

```yaml
deploy:
  resources:
    limits:
      memory: 2g
      cpus: '2.0'
    reservations:
      memory: 1g
      cpus: '1.0'
```

**说明**:
- `limits`: 容器最大可用资源
- `reservations`: 保证分配的最小资源

#### 系统限制

```yaml
ulimits:
  memlock:
    soft: -1
    hard: -1
  nofile:
    soft: 65536
    hard: 65536
```

**说明**:
- `memlock`: 允许锁定所有内存
- `nofile`: 文件描述符数量（ES 需要大量文件句柄）

#### 健康检查

```yaml
healthcheck:
  test: ["CMD-SHELL", "curl -sf http://localhost:9200/_cluster/health | grep -q '\"status\":\"green\\|yellow\"'"]
  interval: 30s
  timeout: 10s
  retries: 5
  start_period: 60s
```

**说明**:
- `interval`: 每 30 秒检查一次
- `start_period`: 启动后 60 秒才开始检查（给予启动时间）
- 检查集群状态是否为 GREEN 或 YELLOW

---

## 数据持久化

### 配置实现

**volumes 配置** (docker-compose.yml):

```yaml
volumes:
  elasticsearch_data:
    driver: local
    driver_opts:
      type: none
      o: bind
      device: ./volumes/elasticsearch/data

  elasticsearch_logs:
    driver: local
    driver_opts:
      type: none
      o: bind
      device: ./volumes/elasticsearch/logs
```

**容器挂载** (docker-compose.yml):

```yaml
volumes:
  - elasticsearch_data:/usr/share/elasticsearch/data
  - elasticsearch_logs:/usr/share/elasticsearch/logs
  - ./elasticsearch/elasticsearch.yml:/usr/share/elasticsearch/config/elasticsearch.yml:ro
```

### 目录结构

```
volumes/
└── elasticsearch/
    ├── data/                # 索引数据存储
    │   ├── _state/
    │   ├── nodes/
    │   └── node.lock
    └── logs/                # ES 日志文件
        ├── gc.log
        └── docker-cluster.log
```

### 验证持久化

```bash
# 1. 创建测试索引
curl -X PUT "http://localhost:9200/test-index"

# 2. 插入测试数据
curl -X POST "http://localhost:9200/test-index/_doc/1" \
  -H 'Content-Type: application/json' \
  -d '{"message": "test data"}'

# 3. 重启容器
docker-compose restart elasticsearch
sleep 30

# 4. 验证数据存在
curl -X GET "http://localhost:9200/test-index/_doc/1"
```

预期输出包含 `"found": true`，证明数据持久化成功。

### 数据备份

```bash
# 停止服务
docker-compose stop elasticsearch

# 备份数据目录
tar -czf es-backup-$(date +%Y%m%d).tar.gz volumes/elasticsearch/data

# 重启服务
docker-compose start elasticsearch
```

---

## 健康检查

### 使用健康检查脚本

脚本位置: `scripts/es-health-check.sh`

#### 基本用法

```bash
# 默认检查 localhost:9200
./scripts/es-health-check.sh

# 指定主机和端口
./scripts/es-health-check.sh --host elasticsearch --port 9200

# 详细输出模式
./scripts/es-health-check.sh -v

# 查看帮助
./scripts/es-health-check.sh --help
```

#### 脚本功能

1. **连接检查**: 验证 ES 服务是否可访问
2. **集群信息**: 显示集群名称、节点名称、版本等
3. **健康状态**: 检查集群状态（GREEN/YELLOW/RED）
4. **节点信息**: CPU、内存、磁盘使用率
5. **索引统计**: 索引数量和大小
6. **磁盘使用**: 存储空间监控

#### 集群状态说明

| 状态 | 含义 | 处理 |
|------|------|------|
| GREEN | 所有主分片和副本分片都已分配 | 正常 |
| YELLOW | 所有主分片已分配，部分副本未分配 | 单节点集群正常状态 |
| RED | 存在未分配的主分片 | 立即检查并修复 |

### Docker 健康检查

查看容器健康状态:

```bash
# 查看容器状态
docker ps | grep elasticsearch

# 查看健康检查详情
docker inspect elasticsearch | jq '.[0].State.Health'
```

### API 监控

```bash
# 集群健康
curl "http://localhost:9200/_cluster/health?pretty"

# 节点统计
curl "http://localhost:9200/_nodes/stats?pretty"

# 索引列表
curl "http://localhost:9200/_cat/indices?v"
```

---

## 故障排查

### 容器无法启动

**现象**: 容器反复重启或立即退出

**排查步骤**:

```bash
# 1. 查看容器状态
docker ps -a | grep elasticsearch

# 2. 查看启动日志
docker-compose logs --tail=100 elasticsearch

# 3. 检查配置文件语法
docker exec elasticsearch cat /usr/share/elasticsearch/config/elasticsearch.yml
```

**常见原因**:

1. **配置文件错误**
   - 检查 `elasticsearch.yml` 语法
   - 确认没有索引级别配置（如 `index.refresh_interval`）

2. **内存不足**
   - Docker Desktop 内存设置至少 4GB
   - 检查 JVM 堆内存配置

3. **权限问题**
   ```bash
   chmod -R 777 volumes/elasticsearch/
   ```

4. **端口冲突**
   ```bash
   lsof -i :9200
   ```

### 无法连接服务

**现象**: `curl http://localhost:9200` 连接被拒绝

**排查步骤**:

```bash
# 1. 检查容器是否运行
docker ps | grep elasticsearch

# 2. 等待服务完全启动
# 首次启动需要 1-2 分钟

# 3. 检查健康状态
docker inspect elasticsearch | jq '.[0].State.Health.Status'

# 4. 查看日志
docker-compose logs -f elasticsearch
```

### 集群状态 RED

**现象**: 健康检查显示 RED 状态

**排查**:

```bash
# 查看未分配分片原因
curl "http://localhost:9200/_cluster/allocation/explain?pretty"

# 查看分片状态
curl "http://localhost:9200/_cat/shards?v"
```

**常见原因**:

1. **磁盘空间不足**: 清理磁盘或扩容
2. **分片损坏**: 删除损坏的索引
3. **配置错误**: 检查 `elasticsearch.yml`

### 内存使用过高

**现象**: 容器 OOM 或系统卡顿

**解决方案**:

```yaml
# 调整 JVM 堆内存（docker-compose.yml）
environment:
  - "ES_JAVA_OPTS=-Xms512m -Xmx512m"
```

```yaml
# 减少缓存大小（elasticsearch.yml）
indices.queries.cache.size: 5%
indices.fielddata.cache.size: 10%
```

### 数据持久化失败

**现象**: 重启后数据丢失

**检查**:

```bash
# 1. 验证数据目录存在
ls -lh volumes/elasticsearch/data/

# 2. 检查 volume 配置
docker volume inspect simpleelk_elasticsearch_data

# 3. 确认文件写入
ls -lh volumes/elasticsearch/data/nodes/
```

**解决**:

```bash
# 重新创建数据目录
rm -rf volumes/elasticsearch/
mkdir -p volumes/elasticsearch/{data,logs}
chmod -R 777 volumes/elasticsearch/

# 重启服务
docker-compose restart elasticsearch
```

---

## 常用命令参考

### 容器管理

```bash
# 启动服务
docker-compose up -d elasticsearch

# 停止服务
docker-compose stop elasticsearch

# 重启服务
docker-compose restart elasticsearch

# 查看日志
docker-compose logs -f elasticsearch

# 进入容器
docker exec -it elasticsearch bash

# 完全清理
docker-compose down
docker volume rm simpleelk_elasticsearch_data simpleelk_elasticsearch_logs
```

### 数据操作

```bash
# 创建索引
curl -X PUT "http://localhost:9200/my-index"

# 插入文档
curl -X POST "http://localhost:9200/my-index/_doc" \
  -H 'Content-Type: application/json' \
  -d '{"field": "value"}'

# 查询数据
curl -X GET "http://localhost:9200/my-index/_search?pretty"

# 删除索引
curl -X DELETE "http://localhost:9200/my-index"
```

### 集群管理

```bash
# 集群健康
curl "http://localhost:9200/_cluster/health?pretty"

# 节点信息
curl "http://localhost:9200/_cat/nodes?v"

# 索引列表
curl "http://localhost:9200/_cat/indices?v"

# 内存锁定状态
curl "http://localhost:9200/_nodes?filter_path=**.mlockall&pretty"
```

