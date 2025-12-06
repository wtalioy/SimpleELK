# Filebeat 配置说明

## 概述

本目录包含 Filebeat 的核心配置文件，用于采集 Docker 容器日志并发送到 Logstash 进行处理。

## 文件说明

### filebeat.yml

Filebeat 主配置文件，包含以下核心功能：

#### 日志采集配置

- **采集类型**: filestream（Docker 容器日志）
- **日志路径**: `/var/lib/docker/containers/*/*.log`
- **容器过滤**: 只采集 `elk-web-app` 容器
- **解析器**: container 格式（自动解析 Docker JSON）

#### JSON 日志解析

- **keys_under_root**: JSON 字段提取到根级别
- **add_error_key**: 解析失败时添加错误信息
- **overwrite_keys**: 允许覆盖默认字段

#### 处理器配置

1. **add_docker_metadata** - 添加容器元数据
2. **add_host_metadata** - 添加主机信息
3. **script** - JavaScript 处理（ES5 兼容）
   - 类型检测（JSON/文本）
   - 字段提取和转换
4. **drop_fields** - 删除冗余字段

#### 输出配置

- **目标**: Logstash（端口 5044）
- **负载均衡**: 启用
- **批量发送**: 2048 条/批
- **压缩**: 级别 3

## Docker Volume 数据持久化

```yaml
volumes:
  - filebeat_data:/usr/share/filebeat/data  # 注册表数据
  - filebeat_logs:/var/log/filebeat  # 日志文件
  - ./filebeat.yml:/usr/share/filebeat/filebeat.yml:ro  # 配置文件（只读）
  - /var/lib/docker/containers:/var/lib/docker/containers:ro  # 容器日志
  - /var/run/docker.sock:/var/run/docker.sock:ro  # Docker API
```

数据持久化到宿主机目录：
- **数据**: `../volumes/filebeat/data/`
- **日志**: `../volumes/filebeat/logs/`

## 测试配置与连接

```bash
./scripts/filebeat.sh
```

## 日志字段示例

### 应用日志（JSON）
```json
{
  "timestamp": "2025-12-06T10:30:45.123456Z",
  "severity": "ERROR",
  "message": "Internal Server Error",
  "http_method": "GET",
  "url": "/error/500",
  "status_code": 500,
  "response_time_ms": 12.34,
  "exception": {
    "type": "ZeroDivisionError",
    "message": "division by zero"
  }
}
```

### Gunicorn 日志（文本）
```
172.18.0.1 - - [06/Dec/2025:10:30:45] "GET /api/user/123 HTTP/1.1" 200
```

## 注意事项

- **JavaScript 处理器**: 使用 ES5 语法（不支持 ES6+）
- **容器过滤**: 仅采集 `elk-web-app` 容器日志
- **类型检测**: 自动识别 JSON 和文本日志
