# ELK 日志生成 Web 应用

---

##  功能特性

### 1. Web 应用接口

| 接口路径 | 方法 | 功能说明 |
|---------|------|---------|
| `/` | GET | 首页，返回服务信息 |
| `/health` | GET | 健康检查接口 |
| `/api/user/<user_id>` | GET | 查询用户信息（模拟业务） |
| `/api/product/<product_id>` | GET | 查询商品信息 |
| `/api/order` | GET/POST | 查询/创建订单 |
| `/api/login` | POST | 用户登录 |
| `/error/404` | GET | 模拟 404 错误 |
| `/error/500` | GET | 模拟 500 错误（带堆栈跟踪） |
| `/error/timeout` | GET | 模拟慢请求（3-5秒） |

### 2. 日志特性

- **格式**：JSON 格式，易于 Logstash 解析
- **输出方式**：标准输出（stdout），Filebeat 可直接采集
- **包含字段**：
  - `timestamp`: 时间戳（ISO 8601 格式）
  - `level`: 日志级别（INFO/WARNING/ERROR）
  - `http_method`: HTTP 方法
  - `url`: 请求 URL
  - `status_code`: HTTP 状态码
  - `response_time_ms`: 响应时间（毫秒）
  - `ip`: 客户端 IP
  - `user_agent`: 用户代理
  - `exception`: 异常信息（如果有）

### 3. 压测脚本

- 支持多线程并发请求
- 模拟真实用户行为（随机间隔）
- 按权重分配不同的请求场景
- 实时统计和报告

---

## 快速开始

### 方式一：使用 Docker Compose

```bash
# 1. 进入项目目录
cd /home/ezhou/cloud/web-app

# 2. 启动服务
docker-compose up -d

# 3. 查看日志
docker-compose logs -f

# 4. 验证服务
curl http://localhost:8000/health

# 5. 停止服务
docker-compose down
```

### 方式二：手动构建 Docker 镜像

```bash
# 1. 构建镜像
docker build -t elk-web-app .

# 2. 运行容器
docker run -d -p 8000:5000 --name elk-web-app elk-web-app

# 3. 查看日志
docker logs -f elk-web-app

# 4. 停止容器
docker stop elk-web-app
docker rm elk-web-app
```

### 方式三：本地运行（开发调试）

```bash
# 1. 安装依赖
pip install -r requirements.txt

# 2. 运行应用
python app.py

# 3. 访问 http://localhost:8000
```

---

##  压力测试

### 基础使用

```bash
# 1. 确保 Web 应用已启动

# 2. 运行压测脚本（默认配置）
python stress_test.py
```

### 自定义配置

编辑 `stress_test.py` 文件顶部的配置参数：

```python
# 目标地址
TARGET_URL = "http://localhost:8000"

# 并发用户数（建议 10-50）
CONCURRENT_USERS = 20

# 持续时间（秒）- 0 表示持续运行
DURATION = 300  # 5 分钟

# 请求间隔（秒）
REQUEST_INTERVAL = (0.5, 2.0)

# 是否显示详细日志
VERBOSE = True
```

### 压测输出示例

```
ELK 日志压力测试工具
======================================================================
目标地址: http://localhost:8000
并发用户: 20
持续时间: 300 秒
======================================================================

[2025-12-01 10:23:45] 200 | 访问首页              |   45.32ms | http://localhost:5000/
[2025-12-01 10:23:46] 200 | 查询用户信息          |   52.18ms | http://localhost:5000/api/user/123
[2025-12-01 10:23:47] 404 | 触发404错误           |   12.45ms | http://localhost:5000/error/404
[2025-12-01 10:23:48] 500 | 触发500错误           |   23.67ms | http://localhost:5000/error/500

 压力测试统计报告
======================================================================
运行时间: 300.00 秒
总请求数: 5432
成功请求: 5380 (99.0%)
失败请求: 52 (1.0%)
平均 QPS: 18.11

状态码分布:
  200: 4123 (75.9%)
  201: 456 (8.4%)
  404: 521 (9.6%)
  500: 280 (5.2%)
  401: 52 (1.0%)

响应时间统计:
  最小值: 12.34 ms
  最大值: 5234.56 ms
  平均值: 87.65 ms
  P50: 52.34 ms
  P95: 156.78 ms
  P99: 234.56 ms
======================================================================
```

---

##  项目结构

```
web-app/
├── app.py                  # Flask Web 应用主程序
├── requirements.txt        # Python 依赖包
├── Dockerfile             # Docker 镜像构建文件
├── docker-compose.yml     # Docker Compose 配置（本地测试）
├── stress_test.py         # 压力测试脚本
└── README.md              # 项目说明文档
```
---

## 📊 日志示例

### 正常请求日志

```json
{
  "timestamp": "2025-12-01T10:23:45.123456Z",
  "level": "INFO",
  "logger": "web_app",
  "message": "Success: User 123 retrieved",
  "module": "app",
  "function": "get_user",
  "line": 145,
  "http_method": "GET",
  "url": "http://localhost:8000/api/user/123",
  "status_code": 200,
  "response_time_ms": 45.32,
  "ip": "172.17.0.1",
  "user_agent": "python-requests/2.31.0"
}
```

### 异常日志（多行堆栈）

```json
{
  "timestamp": "2025-12-01T10:23:46.789012Z",
  "level": "ERROR",
  "logger": "web_app",
  "message": "Internal Server Error",
  "module": "app",
  "function": "error_500",
  "line": 289,
  "http_method": "GET",
  "url": "http://localhost:8000/error/500",
  "status_code": 500,
  "response_time_ms": 23.67,
  "ip": "172.17.0.1",
  "user_agent": "python-requests/2.31.0",
  "exception": {
    "type": "ZeroDivisionError",
    "message": "division by zero",
    "stacktrace": [
      "Traceback (most recent call last):",
      "  File \"/app/app.py\", line 285, in error_500",
      "    result = 1 / 0",
      "ZeroDivisionError: division by zero"
    ]
  }
}
```

