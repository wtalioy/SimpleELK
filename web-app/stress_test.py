#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
压力测试脚本 - 自动发包工具
用于模拟真实用户访问，产生大量日志供 ELK 分析

功能:
1. 模拟高并发访问
2. 模拟正常请求和异常请求
3. 模拟真实业务场景（浏览、登录、下单）
4. 产生多样化的日志数据

成员5：应用开发
"""

import requests
import random
import time
import threading
import signal
import sys
from datetime import datetime
from concurrent.futures import ThreadPoolExecutor, as_completed
from collections import defaultdict

# ============================================
# 配置参数
# ============================================

# 目标服务器地址
TARGET_URL = "http://localhost:8000"

# 并发用户数
CONCURRENT_USERS = 20

# 测试持续时间（秒）- 设为 0 表示持续运行直到手动停止
DURATION = 300  # 默认运行 5 分钟

# 每个用户的请求间隔（秒）
REQUEST_INTERVAL = (0.5, 2.0)  # 随机间隔 0.5-2 秒

# 是否显示详细日志
VERBOSE = True

# ============================================
# 全局统计变量
# ============================================
stats = {
    "total_requests": 0,
    "success_count": 0,
    "error_count": 0,
    "status_codes": defaultdict(int),
    "response_times": [],
    "start_time": None,
    "running": True
}

stats_lock = threading.Lock()


# ============================================
# 请求场景定义
# ============================================

# 定义各种请求场景及其权重
# 权重越高，被选中的概率越大
SCENARIOS = [
    {
        "name": "访问首页",
        "method": "GET",
        "url": "/",
        "weight": 30,  # 30% 概率
    },
    {
        "name": "健康检查",
        "method": "GET",
        "url": "/health",
        "weight": 10,  # 10% 概率
    },
    {
        "name": "查询用户信息",
        "method": "GET",
        "url": lambda: f"/api/user/{random.randint(1, 1200)}",  # 动态生成 user_id
        "weight": 25,  # 25% 概率
    },
    {
        "name": "查询商品信息",
        "method": "GET",
        "url": lambda: f"/api/product/{random.randint(1, 500)}",  # 动态生成 product_id
        "weight": 20,  # 20% 概率
    },
    {
        "name": "查询订单列表",
        "method": "GET",
        "url": "/api/order",
        "weight": 10,  # 10% 概率
    },
    {
        "name": "创建订单",
        "method": "POST",
        "url": "/api/order",
        "weight": 8,  # 8% 概率
    },
    {
        "name": "用户登录",
        "method": "POST",
        "url": "/api/login",
        "weight": 5,  # 5% 概率
    },
    {
        "name": "触发404错误",
        "method": "GET",
        "url": "/error/404",
        "weight": 3,  # 3% 概率
    },
    {
        "name": "触发500错误",
        "method": "GET",
        "url": "/error/500",
        "weight": 2,  # 2% 概率
    },
    {
        "name": "访问不存在的页面",
        "method": "GET",
        "url": lambda: f"/nonexistent/{random.randint(1, 100)}",
        "weight": 2,  # 2% 概率
    },
    {
        "name": "慢请求（超时）",
        "method": "GET",
        "url": "/error/timeout",
        "weight": 1,  # 1% 概率（较少触发，因为很慢）
    },
]

# 计算总权重
TOTAL_WEIGHT = sum(scenario["weight"] for scenario in SCENARIOS)


# ============================================
# 辅助函数
# ============================================

def select_scenario():
    """
    根据权重随机选择一个请求场景
    
    返回:
        dict: 选中的场景配置
    """
    rand = random.uniform(0, TOTAL_WEIGHT)
    cumulative = 0
    
    for scenario in SCENARIOS:
        cumulative += scenario["weight"]
        if rand <= cumulative:
            return scenario
    
    return SCENARIOS[0]  # 默认返回第一个


def get_url(scenario):
    """
    获取场景的 URL
    支持静态 URL 和动态生成的 URL
    
    参数:
        scenario: 场景配置
    
    返回:
        str: 完整的 URL
    """
    url = scenario["url"]
    if callable(url):
        url = url()  # 如果是函数，调用它生成 URL
    
    return TARGET_URL + url


def send_request(scenario):
    """
    发送 HTTP 请求
    
    参数:
        scenario: 场景配置
    
    返回:
        dict: 包含响应信息的字典
    """
    method = scenario["method"]
    url = get_url(scenario)
    
    try:
        start_time = time.time()
        
        # 发送请求（设置超时为 10 秒）
        if method == "GET":
            response = requests.get(url, timeout=10)
        elif method == "POST":
            response = requests.post(url, json={}, timeout=10)
        else:
            response = requests.request(method, url, timeout=10)
        
        response_time = time.time() - start_time
        
        return {
            "success": True,
            "status_code": response.status_code,
            "response_time": response_time,
            "scenario_name": scenario["name"],
            "url": url
        }
    
    except requests.exceptions.Timeout:
        response_time = time.time() - start_time
        return {
            "success": False,
            "status_code": 0,
            "response_time": response_time,
            "scenario_name": scenario["name"],
            "url": url,
            "error": "Timeout"
        }
    
    except Exception as e:
        return {
            "success": False,
            "status_code": 0,
            "response_time": 0,
            "scenario_name": scenario["name"],
            "url": url,
            "error": str(e)
        }


def update_stats(result):
    """
    更新统计数据（线程安全）
    
    参数:
        result: 请求结果字典
    """
    with stats_lock:
        stats["total_requests"] += 1
        
        if result["success"]:
            stats["success_count"] += 1
            stats["status_codes"][result["status_code"]] += 1
            stats["response_times"].append(result["response_time"])
        else:
            stats["error_count"] += 1


def print_result(result):
    """
    打印请求结果（可选的详细日志）
    
    参数:
        result: 请求结果字典
    """
    if not VERBOSE:
        return
    
    timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    
    if result["success"]:
        status_code = result["status_code"]
        response_time_ms = result["response_time"] * 1000
        
        # 根据状态码决定输出颜色（使用 ANSI 颜色代码）
        if status_code < 300:
            color = "\033[92m"  # 绿色
        elif status_code < 400:
            color = "\033[93m"  # 黄色
        else:
            color = "\033[91m"  # 红色
        
        reset = "\033[0m"
        
        print(f"[{timestamp}] {color}{status_code}{reset} | "
              f"{result['scenario_name']:<20} | "
              f"{response_time_ms:>7.2f}ms | "
              f"{result['url']}")
    else:
        print(f"[{timestamp}] \033[91mERROR\033[0m | "
              f"{result['scenario_name']:<20} | "
              f"Error: {result.get('error', 'Unknown')} | "
              f"{result['url']}")


# ============================================
# 模拟用户行为
# ============================================

def simulate_user(user_id, duration):
    """
    模拟单个用户的行为
    
    参数:
        user_id: 用户编号
        duration: 运行时长（秒），0 表示持续运行
    """
    start_time = time.time()
    request_count = 0
    
    print(f"👤 User {user_id} started")
    
    while stats["running"]:
        # 检查是否超时
        if duration > 0 and (time.time() - start_time) > duration:
            break
        
        # 选择场景并发送请求
        scenario = select_scenario()
        result = send_request(scenario)
        
        # 更新统计
        update_stats(result)
        print_result(result)
        
        request_count += 1
        
        # 随机等待一段时间（模拟真实用户行为）
        time.sleep(random.uniform(*REQUEST_INTERVAL))
    
    print(f"👤 User {user_id} finished - Total requests: {request_count}")


# ============================================
# 统计报告
# ============================================

def print_stats():
    """
    打印统计报告
    """
    print("\n" + "=" * 70)
    print("📊 压力测试统计报告")
    print("=" * 70)
    
    duration = time.time() - stats["start_time"]
    
    print(f"运行时间: {duration:.2f} 秒")
    print(f"总请求数: {stats['total_requests']}")
    print(f"成功请求: {stats['success_count']} ({stats['success_count']/stats['total_requests']*100:.1f}%)")
    print(f"失败请求: {stats['error_count']} ({stats['error_count']/stats['total_requests']*100:.1f}%)")
    print(f"平均 QPS: {stats['total_requests']/duration:.2f}")
    
    print("\n状态码分布:")
    for code, count in sorted(stats["status_codes"].items()):
        percentage = count / stats["total_requests"] * 100
        print(f"  {code}: {count} ({percentage:.1f}%)")
    
    if stats["response_times"]:
        response_times = sorted(stats["response_times"])
        print("\n响应时间统计:")
        print(f"  最小值: {min(response_times)*1000:.2f} ms")
        print(f"  最大值: {max(response_times)*1000:.2f} ms")
        print(f"  平均值: {sum(response_times)/len(response_times)*1000:.2f} ms")
        print(f"  P50: {response_times[len(response_times)//2]*1000:.2f} ms")
        print(f"  P95: {response_times[int(len(response_times)*0.95)]*1000:.2f} ms")
        print(f"  P99: {response_times[int(len(response_times)*0.99)]*1000:.2f} ms")
    
    print("=" * 70 + "\n")


# ============================================
# 信号处理
# ============================================

def signal_handler(sig, frame):
    """
    处理 Ctrl+C 信号，优雅退出
    """
    print("\n\n⚠️  收到退出信号，正在停止测试...")
    stats["running"] = False


# ============================================
# 主函数
# ============================================

def main():
    """
    主函数 - 启动压力测试
    """
    # 注册信号处理器
    signal.signal(signal.SIGINT, signal_handler)
    
    print("=" * 70)
    print("🚀 ELK 日志压力测试工具")
    print("=" * 70)
    print(f"目标地址: {TARGET_URL}")
    print(f"并发用户: {CONCURRENT_USERS}")
    print(f"持续时间: {DURATION if DURATION > 0 else '持续运行（按 Ctrl+C 停止）'} 秒")
    print(f"请求间隔: {REQUEST_INTERVAL[0]}-{REQUEST_INTERVAL[1]} 秒")
    print("=" * 70 + "\n")
    
    # 检查服务是否可用
    print("🔍 检查目标服务...")
    try:
        response = requests.get(f"{TARGET_URL}/health", timeout=5)
        if response.status_code == 200:
            print("✅ 目标服务正常\n")
        else:
            print(f"⚠️  目标服务响应异常: {response.status_code}\n")
    except Exception as e:
        print(f"❌ 无法连接到目标服务: {e}")
        print("请确保服务已启动并且地址正确！\n")
        return
    
    # 记录开始时间
    stats["start_time"] = time.time()
    
    # 启动线程池
    print(f"🏃 启动 {CONCURRENT_USERS} 个并发用户...\n")
    
    with ThreadPoolExecutor(max_workers=CONCURRENT_USERS) as executor:
        futures = [
            executor.submit(simulate_user, i+1, DURATION)
            for i in range(CONCURRENT_USERS)
        ]
        
        # 等待所有线程完成
        for future in as_completed(futures):
            try:
                future.result()
            except Exception as e:
                print(f"❌ 用户线程异常: {e}")
    
    # 打印统计报告
    print_stats()
    
    print("✅ 压力测试完成！")


if __name__ == "__main__":
    main()

