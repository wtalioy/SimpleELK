# Logstash 配置说明

## 概述

本目录包含 Logstash 的核心配置文件，用于接收 Filebeat 日志、解析处理并发送到 Elasticsearch。

## 文件说明

### config/logstash.yml

Logstash 主配置文件，包含以下核心配置：

#### API 配置

- **监听地址**: 0.0.0.0:9600

#### Pipeline 配置

- **配置路径**: `/usr/share/logstash/pipeline`
- **工作线程**: 2
- **批量大小**: 125 事件/批
- **批量延迟**: 50ms

#### 队列配置

- **队列类型**: memory（内存队列）
- **最大容量**: 1GB
- **监控**: 禁用（开发环境）

### pipeline/docker-logs.conf

日志处理管道配置，包含以下核心功能：

#### Input 阶段

```ruby
beats {
  port => 5044  # 接收 Filebeat 数据
}
```

#### Filter 阶段

1. **日志类型检测**
   - JSON 应用日志（`log_type: application`）
   - Gunicorn 访问日志（`log_type: gunicorn_access`）

2. **JSON 日志处理**
   - 异常堆栈提取（`exception.stacktrace`）
   - 时间戳解析
   - 字段重命名和类型转换

3. **Gunicorn 日志处理**
   - Grok 模式匹配
   - HTTP 字段提取（method, path, status, response_time）

4. **严重级别路由**
   - severity_lowercase 字段生成
   - INFO/WARNING/ERROR 分类

#### Output 阶段

```ruby
# 按严重级别分索引
index => "webapp-logs-%{[severity_lowercase]}-%{+YYYY.MM.dd}"

# 访问日志单独索引
index => "webapp-access-%{+YYYY.MM.dd}"
```

## Docker Volume 数据持久化

```yaml
volumes:
  - logstash_data:/usr/share/logstash/data  # Pipeline 状态
  - ./config/logstash.yml:/usr/share/logstash/config/logstash.yml:ro
  - ./pipeline:/usr/share/logstash/pipeline:ro
```

## 测试

```bash
# 1. 启动服务
docker-compose up -d

# 2. 查看日志
docker-compose logs -f logstash

# 3. 启动测试
./scripts/test-logstash.sh
```

## 索引命名规范

| 日志类型 | 索引名称 | 示例 |
|---------|---------|------|
| INFO 日志 | `webapp-logs-info-YYYY.MM.dd` | webapp-logs-info-2025.12.06 |
| WARNING 日志 | `webapp-logs-warning-YYYY.MM.dd` | webapp-logs-warning-2025.12.06 |
| ERROR 日志 | `webapp-logs-error-YYYY.MM.dd` | webapp-logs-error-2025.12.06 |
| 访问日志 | `webapp-access-YYYY.MM.dd` | webapp-access-2025.12.06 |

## 注意事项

- **索引命名**: 使用小写 `severity_lowercase` 字段
- **异常处理**: `exception.stacktrace` 数组包含完整堆栈信息
- **时间戳**: 优先使用应用日志的 `timestamp` 字段
