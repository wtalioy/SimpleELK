#!/bin/bash

################################################################################
# Elasticsearch 集群健康检查脚本
# 云原生日志收集平台 - SimpleELK
#
# 功能：
#   - 检查 Elasticsearch 服务状态
#   - 集群健康状态监控
#   - 节点信息查询
#   - 索引统计信息
#   - 磁盘使用情况
#
# 使用方法：
#   ./es-health-check.sh [OPTIONS]
#
# 选项：
#   -h, --host     Elasticsearch 主机地址 (默认: localhost)
#   -p, --port     Elasticsearch 端口 (默认: 9200)
#   -v, --verbose  详细输出模式
#   --help         显示帮助信息
################################################################################

# 默认配置
ES_HOST="${ES_HOST:-localhost}"
ES_PORT="${ES_PORT:-9200}"
ES_URL="http://${ES_HOST}:${ES_PORT}"
VERBOSE=false

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color
BOLD='\033[1m'

################################################################################
# 工具函数
################################################################################

# 打印标题
print_header() {
    echo -e "\n${BOLD}${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BOLD}${CYAN}  $1${NC}"
    echo -e "${BOLD}${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"
}

# 打印成功信息
print_success() {
    echo -e "${GREEN}✓${NC} $1"
}

# 打印错误信息
print_error() {
    echo -e "${RED}✗${NC} $1"
}

# 打印警告信息
print_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

# 打印信息
print_info() {
    echo -e "${BLUE}ℹ${NC} $1"
}

# 打印键值对
print_kv() {
    printf "  ${BOLD}%-25s${NC} : %s\n" "$1" "$2"
}

# 解析命令行参数
parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--host)
                ES_HOST="$2"
                ES_URL="http://${ES_HOST}:${ES_PORT}"
                shift 2
                ;;
            -p|--port)
                ES_PORT="$2"
                ES_URL="http://${ES_HOST}:${ES_PORT}"
                shift 2
                ;;
            -v|--verbose)
                VERBOSE=true
                shift
                ;;
            --help)
                show_help
                exit 0
                ;;
            *)
                echo "未知参数: $1"
                show_help
                exit 1
                ;;
        esac
    done
}

# 显示帮助信息
show_help() {
    cat << EOF
Elasticsearch 集群健康检查脚本

使用方法:
    $0 [OPTIONS]

选项:
    -h, --host HOST      Elasticsearch 主机地址 (默认: localhost)
    -p, --port PORT      Elasticsearch 端口 (默认: 9200)
    -v, --verbose        详细输出模式
    --help               显示此帮助信息

环境变量:
    ES_HOST              Elasticsearch 主机地址
    ES_PORT              Elasticsearch 端口

示例:
    $0                                    # 使用默认配置
    $0 -h elasticsearch -p 9200          # 指定主机和端口
    $0 -v                                # 详细输出模式
    ES_HOST=es.example.com $0            # 使用环境变量

EOF
}

################################################################################
# 检查函数
################################################################################

# 检查依赖工具
check_dependencies() {
    local missing_deps=()

    for cmd in curl jq; do
        if ! command -v "$cmd" &> /dev/null; then
            missing_deps+=("$cmd")
        fi
    done

    if [ ${#missing_deps[@]} -ne 0 ]; then
        print_error "缺少必需工具: ${missing_deps[*]}"
        echo "请安装: brew install curl jq"
        exit 1
    fi
}

# 检查 ES 连接
check_connection() {
    print_header "连接检查"

    if curl -sf "$ES_URL" > /dev/null 2>&1; then
        print_success "Elasticsearch 服务可达: $ES_URL"
        return 0
    else
        print_error "无法连接到 Elasticsearch: $ES_URL"
        print_info "请检查："
        print_info "  1. Elasticsearch 是否已启动: docker ps | grep elasticsearch"
        print_info "  2. 端口是否正确: $ES_PORT"
        print_info "  3. 网络是否可达: curl $ES_URL"
        exit 1
    fi
}

# 获取集群信息
get_cluster_info() {
    print_header "集群基本信息"

    local info=$(curl -sf "$ES_URL")

    if [ -z "$info" ]; then
        print_error "无法获取集群信息"
        return 1
    fi

    local cluster_name=$(echo "$info" | jq -r '.cluster_name')
    local node_name=$(echo "$info" | jq -r '.name')
    local version=$(echo "$info" | jq -r '.version.number')
    local build_date=$(echo "$info" | jq -r '.version.build_date')

    print_kv "集群名称" "$cluster_name"
    print_kv "节点名称" "$node_name"
    print_kv "ES 版本" "$version"
    print_kv "构建日期" "$build_date"
}

# 检查集群健康状态
check_cluster_health() {
    print_header "集群健康状态"

    local health=$(curl -sf "$ES_URL/_cluster/health")

    if [ -z "$health" ]; then
        print_error "无法获取集群健康状态"
        return 1
    fi

    local status=$(echo "$health" | jq -r '.status')
    local nodes=$(echo "$health" | jq -r '.number_of_nodes')
    local data_nodes=$(echo "$health" | jq -r '.number_of_data_nodes')
    local active_shards=$(echo "$health" | jq -r '.active_shards')
    local relocating_shards=$(echo "$health" | jq -r '.relocating_shards')
    local initializing_shards=$(echo "$health" | jq -r '.initializing_shards')
    local unassigned_shards=$(echo "$health" | jq -r '.unassigned_shards')
    local pending_tasks=$(echo "$health" | jq -r '.number_of_pending_tasks')

    # 根据状态显示不同颜色
    case $status in
        green)
            print_success "集群状态: ${GREEN}${BOLD}GREEN${NC} (健康)"
            ;;
        yellow)
            print_warning "集群状态: ${YELLOW}${BOLD}YELLOW${NC} (警告 - 存在未分配副本分片)"
            ;;
        red)
            print_error "集群状态: ${RED}${BOLD}RED${NC} (严重 - 存在未分配主分片)"
            ;;
    esac

    echo ""
    print_kv "节点总数" "$nodes"
    print_kv "数据节点数" "$data_nodes"
    print_kv "活跃分片" "$active_shards"
    print_kv "迁移中分片" "$relocating_shards"
    print_kv "初始化分片" "$initializing_shards"

    if [ "$unassigned_shards" -gt 0 ]; then
        print_kv "未分配分片" "${RED}$unassigned_shards${NC}"
    else
        print_kv "未分配分片" "$unassigned_shards"
    fi

    print_kv "待处理任务" "$pending_tasks"
}

# 检查节点信息
check_nodes() {
    print_header "节点信息"

    local nodes=$(curl -sf "$ES_URL/_cat/nodes?v&h=name,heap.percent,ram.percent,cpu,load_1m,disk.used_percent,node.role&format=json")

    if [ -z "$nodes" ]; then
        print_error "无法获取节点信息"
        return 1
    fi

    echo "$nodes" | jq -r '.[] | "\(.name)\t\(.["heap.percent"])%\t\(.["ram.percent"])%\t\(.cpu)%\t\(.load_1m)\t\(.["disk.used_percent"])%\t\(.["node.role"])"' | \
    while IFS=$'\t' read -r name heap ram cpu load disk role; do
        echo ""
        print_kv "节点名称" "$name"
        print_kv "节点角色" "$role"
        print_kv "堆内存使用" "$heap"
        print_kv "RAM 使用" "$ram"
        print_kv "CPU 使用" "$cpu"
        print_kv "系统负载 (1m)" "$load"
        print_kv "磁盘使用" "$disk"
    done
}

# 检查索引统计
check_indices() {
    print_header "索引统计"

    local indices=$(curl -sf "$ES_URL/_cat/indices?format=json")

    if [ -z "$indices" ]; then
        print_warning "没有找到索引"
        return 0
    fi

    local count=$(echo "$indices" | jq -r '. | length')
    print_kv "索引总数" "$count"

    if [ "$VERBOSE" = true ]; then
        echo -e "\n${BOLD}索引详情:${NC}"
        printf "  ${BOLD}%-30s %-10s %-15s %-12s %-10s${NC}\n" "索引名称" "状态" "文档数" "存储大小" "主分片数"
        echo "$indices" | jq -r '.[] | "\(.index)\t\(.health)\t\(.["docs.count"])\t\(.["store.size"])\t\(.pri)"' | \
        while IFS=$'\t' read -r index health docs size pri; do
            case $health in
                green) color=$GREEN ;;
                yellow) color=$YELLOW ;;
                red) color=$RED ;;
                *) color=$NC ;;
            esac
            printf "  %-30s ${color}%-10s${NC} %-15s %-12s %-10s\n" "$index" "$health" "$docs" "$size" "$pri"
        done
    fi
}

# 检查磁盘使用情况
check_disk_usage() {
    print_header "磁盘使用情况"

    local allocation=$(curl -sf "$ES_URL/_cat/allocation?v&format=json")

    if [ -z "$allocation" ]; then
        print_error "无法获取磁盘使用信息"
        return 1
    fi

    echo "$allocation" | jq -r '.[] | select(.node != null) | "\(.node)\t\(.["disk.used"])\t\(.["disk.avail"])\t\(.["disk.total"])\t\(.["disk.percent"])"' | \
    while IFS=$'\t' read -r node used avail total percent; do
        print_kv "节点" "$node"
        print_kv "已使用" "$used"
        print_kv "可用空间" "$avail"
        print_kv "总空间" "$total"

        # 根据使用率显示不同颜色
        if [ "${percent%\%}" -ge 90 ]; then
            print_kv "使用率" "${RED}$percent${NC}"
        elif [ "${percent%\%}" -ge 85 ]; then
            print_kv "使用率" "${YELLOW}$percent${NC}"
        else
            print_kv "使用率" "${GREEN}$percent${NC}"
        fi
    done
}

# 生成健康报告摘要
generate_summary() {
    print_header "健康检查摘要"

    local health=$(curl -sf "$ES_URL/_cluster/health")
    local status=$(echo "$health" | jq -r '.status')

    case $status in
        green)
            print_success "集群运行正常，所有功能可用"
            ;;
        yellow)
            print_warning "集群功能正常，但存在副本分片未分配（单节点集群正常现象）"
            print_info "建议：生产环境应部署多节点集群以提高可用性"
            ;;
        red)
            print_error "集群存在严重问题，部分数据可能不可用"
            print_info "请立即检查日志并采取恢复措施"
            ;;
    esac

    echo ""
    print_info "检查完成时间: $(date '+%Y-%m-%d %H:%M:%S')"
}

################################################################################
# 主函数
################################################################################

main() {
    # 解析参数
    parse_args "$@"

    # 打印欢迎信息
    echo ""
    echo -e "${BOLD}${MAGENTA}╔══════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BOLD}${MAGENTA}║                                                          ║${NC}"
    echo -e "${BOLD}${MAGENTA}║        Elasticsearch 集群健康检查工具                   ║${NC}"
    echo -e "${BOLD}${MAGENTA}║        Cloud Native Log Collection Platform              ║${NC}"
    echo -e "${BOLD}${MAGENTA}║                                                          ║${NC}"
    echo -e "${BOLD}${MAGENTA}╚══════════════════════════════════════════════════════════╝${NC}"
    echo ""

    print_info "目标地址: ${BOLD}$ES_URL${NC}"

    # 检查依赖
    check_dependencies

    # 执行检查
    check_connection
    get_cluster_info
    check_cluster_health
    check_nodes
    check_indices
    check_disk_usage
    generate_summary

    echo ""
}

# 执行主函数
main "$@"
