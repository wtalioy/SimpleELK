# Filebeat 配置说明

## 概述

本目录包含 Filebeat 的核心配置文件,用于采集 Docker 容器日志并发送到 Logstash 进行处理。
**专门优化用于采集 Web 应用的 JSON 格式日志**。

## 文件说明

### filebeat.yml

Filebeat 主配置文件,包含以下核心功能:

#### 日志采集配置

- **采集类型**: Docker 容器日志 (container)
- **日志路径**: `/var/lib/docker/containers/*/*.log`
- **采集模式**: 实时监控
- **编码格式**: UTF-8
- **容器过滤**: 只采集 `elk-web-app` 容器的日志

#### JSON 日志解析 ✨

Web 应用输出的是结构化 JSON 日志,Filebeat 直接解析:

```json
{
  "timestamp": "2025-12-06T10:30:45.123456Z",
  "level": "ERROR",
  "logger": "web_app",
  "message": "Internal Server Error",
  "http_method": "GET",
  "url": "http://localhost:8000/error/500",
  "status_code": 500,
  "response_time_ms": 12.34,
  "ip": "172.18.0.1",
  "user_agent": "Mozilla/5.0...",
  "exception": {
    "type": "ZeroDivisionError",
    "message": "division by zero",
    "stacktrace": ["Traceback...", "  File..."]
  }
}
```

**解析配置**:
- `keys_under_root: true` - JSON 字段提取到根级别
- `add_error_key: true` - 解析失败时添加错误信息
- `overwrite_keys: true` - 允许覆盖默认字段

#### 多行日志合并

处理 Python 异常堆栈跟踪等多行日志:
- **匹配模式**: 识别 JSON 对象和缩进的堆栈跟踪
- **合并策略**: 将多行内容合并为一条完整日志
- **最大行数**: 500 行
- **超时时间**: 10 秒

#### 元数据提取

- **Docker 信息**: 自动添加容器名称、ID、镜像等元数据
- **主机信息**: 添加主机名、IP、网络信息
- **自定义字段**: log_source, collector, environment

#### 处理器 (Processors)

1. **add_docker_metadata** - 添加 Docker 容器元数据
2. **add_host_metadata** - 添加主机信息
3. **drop_event** - 只保留 web-app 容器的日志
4. **timestamp** - 解析时间戳字段
5. **rename** - 规范化字段名称 (level → log.level)
6. **drop_fields** - 删除冗余字段,减少存储

#### 输出配置

- **目标**: Logstash (端口 5044)
- **负载均衡**: 启用
- **批量发送**: 2048 条/批
- **压缩传输**: 压缩级别 3

## Docker Volume 数据持久化

```yaml
volumes:
  - filebeat_data:/usr/share/filebeat/data
  - filebeat_logs:/var/log/filebeat
  - ./filebeat.yml:/usr/share/filebeat/filebeat.yml:ro
  - /var/lib/docker/containers:/var/lib/docker/containers:ro
  - /var/run/docker.sock:/var/run/docker.sock:ro
```

数据持久化到宿主机目录：
- **数据**: `../volumes/filebeat/data/`
- **日志**: `../volumes/filebeat/logs/`

## 使用脚本

```bash
# 1. 初始化和测试
./scripts/filebeat.sh init
./scripts/filebeat.sh test
./scripts/filebeat.sh start

# 2. 查看状态和日志
./scripts/filebeat.sh status
./scripts/filebeat.sh logs

# 3. 测试完成后清理
./scripts/filebeat.sh clean        # 保留镜像
./scripts/filebeat.sh clean --all  # 完全清理,释放所有空间
```

## Web 应用日志示例

### 正常请求日志 (INFO)

```json
{
  "timestamp": "2025-12-06T10:30:45.123456Z",
  "level": "INFO",
  "logger": "web_app",
  "message": "Success: User 123 retrieved",
  "module": "app",
  "function": "get_user",
  "line": 195,
  "http_method": "GET",
  "url": "http://localhost:8000/api/user/123",
  "status_code": 200,
  "response_time_ms": 45.67,
  "ip": "172.18.0.1",
  "user_agent": "python-requests/2.31.0"
}
```

### 错误日志 (ERROR)

```json
{
  "timestamp": "2025-12-06T10:31:20.456789Z",
  "level": "ERROR",
  "logger": "web_app",
  "message": "Internal Server Error",
  "module": "app",
  "function": "error_500",
  "line": 358,
  "http_method": "GET",
  "url": "http://localhost:8000/error/500",
  "status_code": 500,
  "response_time_ms": 12.34,
  "ip": "172.18.0.1",
  "user_agent": "Mozilla/5.0",
  "exception": {
    "type": "ZeroDivisionError",
    "message": "division by zero",
    "stacktrace": [
      "Traceback (most recent call last):\n",
      "  File \"/app/app.py\", line 353, in error_500\n",
      "    result = 1 / 0\n",
      "ZeroDivisionError: division by zero\n"
    ]
  }
}
```

### 慢请求日志 (WARNING)

```json
{
  "timestamp": "2025-12-06T10:32:15.789012Z",
  "level": "INFO",
  "logger": "web_app",
  "message": "Slow request - took 3.45s",
  "http_method": "GET",
  "url": "http://localhost:8000/error/timeout",
  "status_code": 200,
  "response_time_ms": 3450.12,
  "ip": "172.18.0.1",
  "user_agent": "curl/7.68.0"
}
```

## 日志字段说明

| 字段 | 类型 | 说明 |
|------|------|------|
| timestamp | string | UTC 时间戳 (ISO 8601) |
| level | string | 日志级别 (INFO/WARNING/ERROR) |
| logger | string | 日志记录器名称 |
| message | string | 日志消息 |
| http_method | string | HTTP 请求方法 |
| url | string | 请求 URL |
| status_code | integer | HTTP 状态码 |
| response_time_ms | float | 响应时间(毫秒) |
| ip | string | 客户端 IP |
| user_agent | string | 用户代理 |
| exception.type | string | 异常类型 |
| exception.message | string | 异常消息 |
| exception.stacktrace | array | 堆栈跟踪 |

## 多行日志合并示例

**Python 异常堆栈(多行):**
```json
{
  "exception": {
    "stacktrace": [
      "Traceback (most recent call last):\n",
      "  File \"/app/app.py\", line 353\n",
      "    result = 1 / 0\n",
      "ZeroDivisionError: division by zero\n"
    ]
  }
}
```

**Filebeat 处理后:** JSON 对象完整保留,stacktrace 数组中的所有行都被正确解析。

## 注意事项

- ✅ **JSON 自动解析**: 无需手动配置字段提取
- ✅ **容器过滤**: 只采集 elk-web-app 容器,避免噪音
- ✅ **异常处理**: Python 堆栈跟踪完整保留在 exception.stacktrace
- ✅ **性能优化**: 删除冗余字段,减少网络传输和存储
- ⚠️ **时间戳**: 使用应用日志中的 timestamp,而非 Filebeat 采集时间
- ⚠️ **多行超时**: 10 秒内必须接收完整的多行日志
