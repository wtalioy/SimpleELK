#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Web 应用 - 用于生成日志供 ELK Stack 采集
成员5：应用开发
"""

from flask import Flask, request, jsonify
import logging
import json
import time
import random
from datetime import datetime
import traceback
import sys

# 创建 Flask 应用
app = Flask(__name__)

# ============================================
# 日志配置 - 输出到 stdout，JSON 格式
# ============================================
class JsonFormatter(logging.Formatter):
    """
    自定义 JSON 格式化器
    将日志输出为 JSON 格式，便于 Logstash 解析
    """
    def format(self, record):
        # 构建基础日志字典
        log_data = {
            "timestamp": datetime.utcnow().isoformat() + "Z",
            "level": record.levelname,
            "logger": record.name,
            "message": record.getMessage(),
            "module": record.module,
            "function": record.funcName,
            "line": record.lineno
        }
        
        # 如果有 HTTP 请求信息，添加到日志中
        if hasattr(record, 'http_method'):
            log_data.update({
                "http_method": record.http_method,
                "url": record.url,
                "status_code": record.status_code,
                "response_time_ms": record.response_time_ms,
                "ip": record.ip,
                "user_agent": record.user_agent
            })
        
        # 如果有异常信息，添加堆栈跟踪
        if record.exc_info:
            log_data["exception"] = {
                "type": record.exc_info[0].__name__,
                "message": str(record.exc_info[1]),
                "stacktrace": traceback.format_exception(*record.exc_info)
            }
        
        return json.dumps(log_data, ensure_ascii=False)


# 配置根日志记录器
logger = logging.getLogger('web_app')
logger.setLevel(logging.DEBUG)

# 创建控制台处理器，输出到 stdout
console_handler = logging.StreamHandler(sys.stdout)
console_handler.setLevel(logging.DEBUG)
console_handler.setFormatter(JsonFormatter())

# 添加处理器到日志记录器
logger.addHandler(console_handler)

# 请求计数器（用于模拟业务数据）
request_counter = {"count": 0}


# ============================================
# 辅助函数
# ============================================
def log_request(status_code, response_time, extra_msg=""):
    """
    记录 HTTP 请求日志
    
    参数:
        status_code: HTTP 状态码
        response_time: 响应时间（毫秒）
        extra_msg: 额外的消息
    """
    log_level = logging.INFO
    message = f"HTTP Request Processed"
    
    # 根据状态码决定日志级别
    if status_code >= 500:
        log_level = logging.ERROR
        message = f"Server Error: {extra_msg}" if extra_msg else "Server Error"
    elif status_code >= 400:
        log_level = logging.WARNING
        message = f"Client Error: {extra_msg}" if extra_msg else "Client Error"
    elif status_code >= 300:
        log_level = logging.INFO
        message = f"Redirect: {extra_msg}" if extra_msg else "Redirect"
    else:
        message = f"Success: {extra_msg}" if extra_msg else "Success"
    
    # 创建日志记录，附加 HTTP 信息
    logger.log(
        log_level,
        message,
        extra={
            'http_method': request.method,
            'url': request.url,
            'status_code': status_code,
            'response_time_ms': round(response_time * 1000, 2),
            'ip': request.remote_addr,
            'user_agent': request.headers.get('User-Agent', 'Unknown')
        }
    )


# ============================================
# 路由定义
# ============================================

@app.route('/')
def index():
    """
    首页路由
    返回应用信息和可用接口列表
    """
    start_time = time.time()
    
    response = {
        "service": "ELK Web Application",
        "version": "1.0.0",
        "description": "日志生成应用 - 云计算课程项目",
        "endpoints": {
            "health_check": "/health",
            "user_api": "/api/user/<user_id>",
            "order_api": "/api/order",
            "product_api": "/api/product/<product_id>",
            "login": "/api/login",
            "error_404": "/error/404",
            "error_500": "/error/500",
            "error_timeout": "/error/timeout"
        },
        "total_requests": request_counter["count"]
    }
    
    request_counter["count"] += 1
    response_time = time.time() - start_time
    log_request(200, response_time, "Homepage accessed")
    
    return jsonify(response), 200


@app.route('/health')
def health_check():
    """
    健康检查接口
    用于监控服务状态
    """
    start_time = time.time()
    
    response = {
        "status": "healthy",
        "timestamp": datetime.utcnow().isoformat(),
        "uptime_seconds": time.time()
    }
    
    request_counter["count"] += 1
    response_time = time.time() - start_time
    log_request(200, response_time, "Health check")
    
    return jsonify(response), 200


@app.route('/api/user/<int:user_id>')
def get_user(user_id):
    """
    用户信息查询接口
    模拟用户数据查询场景
    
    参数:
        user_id: 用户ID
    """
    start_time = time.time()
    
    # 模拟数据库查询延迟
    time.sleep(random.uniform(0.01, 0.05))
    
    # 模拟用户不存在的情况（10% 概率）
    if user_id > 1000:
        response = {"error": "User not found"}
        request_counter["count"] += 1
        response_time = time.time() - start_time
        log_request(404, response_time, f"User {user_id} not found")
        return jsonify(response), 404
    
    response = {
        "user_id": user_id,
        "username": f"user_{user_id}",
        "email": f"user{user_id}@example.com",
        "created_at": datetime.utcnow().isoformat()
    }
    
    request_counter["count"] += 1
    response_time = time.time() - start_time
    log_request(200, response_time, f"User {user_id} retrieved")
    
    return jsonify(response), 200


@app.route('/api/order', methods=['GET', 'POST'])
def order():
    """
    订单接口
    模拟订单创建和查询场景
    """
    start_time = time.time()
    
    if request.method == 'POST':
        # 模拟订单创建
        time.sleep(random.uniform(0.05, 0.15))
        
        order_id = random.randint(10000, 99999)
        response = {
            "order_id": order_id,
            "status": "created",
            "amount": random.randint(10, 1000),
            "created_at": datetime.utcnow().isoformat()
        }
        
        request_counter["count"] += 1
        response_time = time.time() - start_time
        log_request(201, response_time, f"Order {order_id} created")
        
        return jsonify(response), 201
    
    else:
        # 模拟订单查询
        time.sleep(random.uniform(0.02, 0.08))
        
        response = {
            "orders": [
                {"order_id": i, "status": random.choice(["pending", "paid", "shipped"])}
                for i in range(1, random.randint(3, 8))
            ]
        }
        
        request_counter["count"] += 1
        response_time = time.time() - start_time
        log_request(200, response_time, "Orders retrieved")
        
        return jsonify(response), 200


@app.route('/api/product/<int:product_id>')
def get_product(product_id):
    """
    商品信息查询接口
    模拟商品查询场景
    
    参数:
        product_id: 商品ID
    """
    start_time = time.time()
    
    # 模拟数据库查询
    time.sleep(random.uniform(0.02, 0.06))
    
    response = {
        "product_id": product_id,
        "name": f"Product {product_id}",
        "price": random.randint(10, 500),
        "stock": random.randint(0, 100),
        "category": random.choice(["Electronics", "Books", "Clothing", "Food"])
    }
    
    request_counter["count"] += 1
    response_time = time.time() - start_time
    log_request(200, response_time, f"Product {product_id} retrieved")
    
    return jsonify(response), 200


@app.route('/api/login', methods=['POST'])
def login():
    """
    用户登录接口
    模拟用户认证场景
    """
    start_time = time.time()
    
    # 模拟认证处理时间
    time.sleep(random.uniform(0.1, 0.2))
    
    # 模拟登录失败（20% 概率）
    if random.random() < 0.2:
        response = {"error": "Invalid credentials"}
        request_counter["count"] += 1
        response_time = time.time() - start_time
        log_request(401, response_time, "Login failed - Invalid credentials")
        return jsonify(response), 401
    
    response = {
        "status": "success",
        "token": f"token_{random.randint(100000, 999999)}",
        "expires_in": 3600
    }
    
    request_counter["count"] += 1
    response_time = time.time() - start_time
    log_request(200, response_time, "User logged in successfully")
    
    return jsonify(response), 200


# ============================================
# 错误模拟路由（用于测试错误日志）
# ============================================

@app.route('/error/404')
def error_404():
    """
    模拟 404 错误
    """
    start_time = time.time()
    response = {"error": "Resource not found"}
    
    request_counter["count"] += 1
    response_time = time.time() - start_time
    log_request(404, response_time, "Simulated 404 error")
    
    return jsonify(response), 404


@app.route('/error/500')
def error_500():
    """
    模拟 500 服务器错误
    会产生异常堆栈跟踪（多行日志）
    """
    start_time = time.time()
    request_counter["count"] += 1
    
    try:
        # 故意触发异常
        result = 1 / 0
    except Exception as e:
        response_time = time.time() - start_time
        logger.error(
            "Internal Server Error",
            exc_info=True,  # 这会记录完整的堆栈跟踪
            extra={
                'http_method': request.method,
                'url': request.url,
                'status_code': 500,
                'response_time_ms': round(response_time * 1000, 2),
                'ip': request.remote_addr,
                'user_agent': request.headers.get('User-Agent', 'Unknown')
            }
        )
        
        return jsonify({"error": "Internal Server Error", "message": str(e)}), 500


@app.route('/error/timeout')
def error_timeout():
    """
    模拟超时场景
    响应时间超过 3 秒
    """
    start_time = time.time()
    
    # 模拟长时间处理
    time.sleep(random.uniform(3.0, 5.0))
    
    response = {"message": "This request took too long"}
    
    request_counter["count"] += 1
    response_time = time.time() - start_time
    log_request(200, response_time, f"Slow request - took {response_time:.2f}s")
    
    return jsonify(response), 200


# ============================================
# 错误处理器
# ============================================

@app.errorhandler(404)
def not_found(error):
    """全局 404 错误处理"""
    start_time = time.time()
    response_time = time.time() - start_time
    log_request(404, response_time, "Page not found")
    return jsonify({"error": "Not found"}), 404


@app.errorhandler(500)
def internal_error(error):
    """全局 500 错误处理"""
    start_time = time.time()
    response_time = time.time() - start_time
    log_request(500, response_time, "Internal server error")
    return jsonify({"error": "Internal server error"}), 500


# ============================================
# 应用启动
# ============================================

if __name__ == '__main__':
    logger.info("=" * 50)
    logger.info("Web Application Starting...")
    logger.info("Service: ELK Log Generator")
    logger.info("Port: 5000")
    logger.info("=" * 50)
    
    # 启动 Flask 应用
    # host='0.0.0.0' 允许外部访问（Docker 容器需要）
    # debug=False 生产模式
    app.run(host='0.0.0.0', port=8000, debug=False)

