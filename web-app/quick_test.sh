#!/bin/bash
# ============================================
# 快速测试脚本
# 用于验证 Web 应用是否正常工作
# ============================================

echo "=========================================="
echo "🧪 ELK Web 应用快速测试"
echo "=========================================="

# 目标地址
TARGET="http://localhost:5000"

# 颜色定义
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 测试计数
TOTAL=0
PASSED=0
FAILED=0

# 测试函数
test_endpoint() {
    local name=$1
    local url=$2
    local expected_code=$3
    
    TOTAL=$((TOTAL + 1))
    echo -n "测试 ${name}... "
    
    response=$(curl -s -o /dev/null -w "%{http_code}" "${TARGET}${url}")
    
    if [ "$response" -eq "$expected_code" ]; then
        echo -e "${GREEN}✓ 通过${NC} (状态码: $response)"
        PASSED=$((PASSED + 1))
    else
        echo -e "${RED}✗ 失败${NC} (期望: $expected_code, 实际: $response)"
        FAILED=$((FAILED + 1))
    fi
}

# 检查服务是否运行
echo ""
echo "1️⃣  检查服务是否运行..."
if curl -s "${TARGET}/health" > /dev/null 2>&1; then
    echo -e "${GREEN}✓ 服务正在运行${NC}"
else
    echo -e "${RED}✗ 服务未运行！${NC}"
    echo "请先启动服务: docker-compose up -d"
    exit 1
fi

# 运行测试
echo ""
echo "2️⃣  测试各个接口..."
echo ""

test_endpoint "首页" "/" 200
test_endpoint "健康检查" "/health" 200
test_endpoint "用户信息" "/api/user/123" 200
test_endpoint "商品信息" "/api/product/1" 200
test_endpoint "订单查询" "/api/order" 200
test_endpoint "404错误" "/error/404" 404
test_endpoint "500错误" "/error/500" 500
test_endpoint "不存在的页面" "/nonexistent" 404

# 测试 POST 请求
echo -n "测试 订单创建 (POST)... "
TOTAL=$((TOTAL + 1))
response=$(curl -s -o /dev/null -w "%{http_code}" -X POST "${TARGET}/api/order" -H "Content-Type: application/json" -d '{}')
if [ "$response" -eq "201" ]; then
    echo -e "${GREEN}✓ 通过${NC} (状态码: $response)"
    PASSED=$((PASSED + 1))
else
    echo -e "${RED}✗ 失败${NC} (期望: 201, 实际: $response)"
    FAILED=$((FAILED + 1))
fi

echo -n "测试 用户登录 (POST)... "
TOTAL=$((TOTAL + 1))
response=$(curl -s -o /dev/null -w "%{http_code}" -X POST "${TARGET}/api/login" -H "Content-Type: application/json" -d '{}')
if [ "$response" -eq "200" ] || [ "$response" -eq "401" ]; then
    echo -e "${GREEN}✓ 通过${NC} (状态码: $response)"
    PASSED=$((PASSED + 1))
else
    echo -e "${RED}✗ 失败${NC} (期望: 200 或 401, 实际: $response)"
    FAILED=$((FAILED + 1))
fi

# 测试日志输出
echo ""
echo "3️⃣  检查日志输出（JSON格式）..."
echo ""

echo "获取最近的日志（最后 5 行）："
echo "----------------------------------------"
docker logs --tail 5 elk-web-app 2>&1 | grep -E '^\{.*\}$' || docker logs --tail 10 elk-web-app 2>&1 | tail -5
echo "----------------------------------------"

# 总结
echo ""
echo "=========================================="
echo "📊 测试结果汇总"
echo "=========================================="
echo "总测试数: $TOTAL"
echo -e "通过: ${GREEN}$PASSED${NC}"
echo -e "失败: ${RED}$FAILED${NC}"

if [ $FAILED -eq 0 ]; then
    echo -e "\n${GREEN}✅ 所有测试通过！应用运行正常。${NC}"
    exit 0
else
    echo -e "\n${RED}❌ 有 $FAILED 个测试失败，请检查应用。${NC}"
    exit 1
fi

