#!/bin/bash

################################################################################
# Filebeat 管理脚本
# 云原生日志收集平台 - SimpleELK
#
# 功能：
#   - 初始化 Filebeat 环境
#   - 配置文件语法检查
#   - 服务启动/停止/重启
#   - 日志查看和状态监控
#
# 使用方法：
#   ./filebeat.sh <命令>
#
# 命令：
#   init      初始化环境（创建必要目录）
#   test      测试配置文件语法
#   start     启动 Filebeat 服务
#   stop      停止 Filebeat 服务
#   restart   重启 Filebeat 服务
#   logs      查看实时日志
#   status    检查运行状态
#   help      显示帮助信息
################################################################################

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'
BOLD='\033[1m'

# 配置
CONTAINER_NAME="filebeat"
IMAGE_NAME="docker.elastic.co/beats/filebeat:9.2.1"

################################################################################
# 工具函数
################################################################################

# 打印标题
print_header() {
    echo -e "\n${BOLD}${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BOLD}${CYAN}  $1${NC}"
    echo -e "${BOLD}${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"
}

# 打印信息
print_info() {
    echo -e "${BLUE}ℹ${NC} $1"
}

# 打印成功
print_success() {
    echo -e "${GREEN}✓${NC} $1"
}

# 打印错误
print_error() {
    echo -e "${RED}✗${NC} $1"
}

# 打印警告
print_warn() {
    echo -e "${YELLOW}⚠${NC} $1"
}

# 检查 Docker 环境
check_docker() {
    if ! command -v docker &> /dev/null; then
        print_error "Docker 未安装，请先安装 Docker"
        exit 1
    fi
    
    if ! docker ps &> /dev/null; then
        print_error "Docker 服务未运行，请启动 Docker"
        exit 1
    fi
}

# 检查 Docker Compose
check_docker_compose() {
    if ! command -v docker-compose &> /dev/null && ! docker compose version &> /dev/null; then
        print_error "Docker Compose 未安装，请先安装 Docker Compose"
        exit 1
    fi
    
    # 优先使用新版命令
    if docker compose version &> /dev/null; then
        COMPOSE_CMD="docker compose"
    else
        COMPOSE_CMD="docker-compose"
    fi
}

# 检查依赖服务是否运行
check_dependencies() {
    local missing_services=()
    
    # 检查 Elasticsearch
    if ! docker ps --format '{{.Names}}' | grep -q "^elasticsearch$"; then
        missing_services+=("elasticsearch")
    fi
    
    # 检查 Logstash
    if ! docker ps --format '{{.Names}}' | grep -q "^logstash$"; then
        missing_services+=("logstash")
    fi
    
    if [ ${#missing_services[@]} -gt 0 ]; then
        print_warn "以下依赖服务未运行: ${missing_services[*]}"
        print_info "Filebeat 需要 Logstash 服务才能正常工作"
        echo ""
        read -p "$(echo -e "${YELLOW}是否继续启动 Filebeat? (y/N): ${NC}")" confirm
        if [ "$confirm" != "y" ] && [ "$confirm" != "Y" ]; then
            print_info "已取消启动"
            exit 0
        fi
    fi
}

################################################################################
# 主要功能函数
################################################################################

init() {
    print_header "初始化 Filebeat 环境"
    
    print_info "创建必要的目录..."
    mkdir -p volumes/filebeat/data volumes/filebeat/logs
    
    print_info "设置目录权限..."
    chmod -R 755 volumes/filebeat 2>/dev/null || true
    
    echo ""
    print_success "Filebeat 环境初始化完成！"
}

test_config() {
    print_header "测试 Filebeat 配置文件"
    
    check_docker
    
    # 确保在项目根目录
    if [ ! -f "filebeat/filebeat.yml" ]; then
        if [ -f "../filebeat/filebeat.yml" ]; then
            cd ..
        else
            print_error "找不到配置文件: filebeat/filebeat.yml"
            print_info "请在项目根目录下运行此脚本"
            exit 1
        fi
    fi
    
    print_info "检查配置文件语法..."
    echo ""
    
    # 使用绝对路径避免路径问题
    CONFIG_PATH="$(realpath filebeat/filebeat.yml)"
    
    if docker run --rm \
        -v "${CONFIG_PATH}:/usr/share/filebeat/filebeat.yml:ro" \
        ${IMAGE_NAME} \
        filebeat test config -e --strict.perms=false; then
        echo ""
        print_success "✓ 配置文件语法正确！"
        
        # 额外测试输出连接（如果 Logstash 在运行）
        echo ""
        print_info "测试输出连接..."
        if docker ps --format '{{.Names}}' | grep -q "^logstash$"; then
            if docker run --rm \
                --network simpleelk_elk \
                -v "${CONFIG_PATH}:/usr/share/filebeat/filebeat.yml:ro" \
                ${IMAGE_NAME} \
                filebeat test output -e --strict.perms=false 2>&1 | grep -q "talk to server"; then
                print_success "✓ Logstash 连接测试通过！"
            else
                print_warn "⚠ 无法连接到 Logstash（服务可能未完全启动）"
            fi
        else
            print_warn "⚠ Logstash 未运行，跳过输出连接测试"
            print_info "提示: 启动 Logstash 后可以测试输出连接"
        fi
    else
        echo ""
        print_error "✗ 配置文件存在错误！"
        exit 1
    fi
}

start() {
    print_header "启动 Filebeat 服务"
    
    check_docker
    check_docker_compose
    
    print_info "初始化环境..."
    init > /dev/null 2>&1
    
    # 检查依赖服务
    check_dependencies
    
    print_info "启动 Filebeat 容器..."
    ${COMPOSE_CMD} up -d ${CONTAINER_NAME}
    
    # 等待容器启动
    sleep 2
    
    # 检查容器是否成功启动
    if docker ps --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
        echo ""
        print_success "✓ Filebeat 启动成功！"
        
        # 显示容器状态
        echo ""
        docker ps --filter "name=${CONTAINER_NAME}" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
        
        echo ""
        echo -e "${BLUE}后续操作：${NC}"
        echo "  查看日志: ./scripts/filebeat.sh logs"
        echo "  查看状态: ./scripts/filebeat.sh status"
    else
        echo ""
        print_error "✗ Filebeat 启动失败！"
        print_info "查看错误日志: docker logs ${CONTAINER_NAME}"
        exit 1
    fi
}

stop() {
    print_header "停止 Filebeat 服务"
    
    check_docker_compose
    
    print_info "停止 Filebeat 容器..."
    ${COMPOSE_CMD} stop ${CONTAINER_NAME}
    
    echo ""
    print_success "✓ Filebeat 已停止！"
}

restart() {
    print_header "重启 Filebeat 服务"
    
    check_docker_compose
    
    print_info "重启 Filebeat 容器..."
    ${COMPOSE_CMD} restart ${CONTAINER_NAME}
    
    # 等待容器重启
    sleep 2
    
    echo ""
    if docker ps --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
        print_success "✓ Filebeat 已重启！"
        echo ""
        docker ps --filter "name=${CONTAINER_NAME}" --format "table {{.Names}}\t{{.Status}}"
    else
        print_error "✗ Filebeat 重启失败！"
        print_info "查看错误日志: docker logs ${CONTAINER_NAME}"
        exit 1
    fi
}

clean() {
    local skip_confirm="${1:-false}"
    local remove_image="${2:-false}"
    
    print_header "清理 Filebeat 资源"
    
    check_docker
    
    # 检查是否有数据
    local has_container=false
    local has_volumes=false
    local has_local_data=false
    
    if docker ps -a --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$" 2>/dev/null; then
        has_container=true
    fi
    
    if docker volume ls --format '{{.Name}}' | grep -q "filebeat" 2>/dev/null; then
        has_volumes=true
    fi
    
    if [ -d "volumes/filebeat" ] && [ -n "$(ls -A volumes/filebeat 2>/dev/null)" ]; then
        has_local_data=true
    fi
    
    if [ "$has_container" = false ] && [ "$has_volumes" = false ] && [ "$has_local_data" = false ]; then
        print_info "没有发现需要清理的资源"
        
        # 检查镜像
        if docker images --format '{{.Repository}}:{{.Tag}}' | grep -q "^${IMAGE_NAME}$" 2>/dev/null; then
            echo ""
            if [ "$skip_confirm" = true ] || [ "$remove_image" = true ]; then
                print_info "删除 Filebeat 镜像..."
                docker rmi ${IMAGE_NAME} 2>/dev/null || true
                print_success "镜像已删除"
            else
                read -p "$(echo -e "${YELLOW}是否删除 Filebeat 镜像? 这将释放约 600MB 空间 (y/N): ${NC}")" confirm_image
                if [ "$confirm_image" = "y" ] || [ "$confirm_image" = "Y" ]; then
                    print_info "删除 Filebeat 镜像..."
                    docker rmi ${IMAGE_NAME} 2>/dev/null || true
                    print_success "镜像已删除"
                fi
            fi
        fi
        return 0
    fi
    
    echo -e "${YELLOW}⚠  警告: 此操作将删除以下资源:${NC}"
    echo "  • Filebeat 容器"
    echo "  • Filebeat 数据卷 (filebeat_data, filebeat_logs)"
    echo "  • 本地数据目录 (volumes/filebeat/)"
    # 停止并删除容器
    if [ "$has_container" = true ]; then
        print_info "停止并删除容器..."
        ${COMPOSE_CMD} rm -sf ${CONTAINER_NAME} 2>/dev/null || docker rm -f ${CONTAINER_NAME} 2>/dev/null || true
        print_success "容器已删除"
    fi      print_info "已取消清理操作"
            return 0
        fi
        echo ""
    fi
    
    # 停止并删除容器
    if [ "$has_container" = true ]; then
        print_info "停止并删除容器..."
        docker-compose rm -sf ${CONTAINER_NAME} 2>/dev/null || docker rm -f ${CONTAINER_NAME} 2>/dev/null || true
        print_success "容器已删除"
    fi
    
    # 删除数据卷
    if [ "$has_volumes" = true ]; then
        print_info "删除数据卷..."
        docker volume rm simpleelk_filebeat_data 2>/dev/null || true
        docker volume rm simpleelk_filebeat_logs 2>/dev/null || true
        print_success "数据卷已删除"
    fi
    
    # 删除本地数据目录
    if [ "$has_local_data" = true ]; then
        print_info "删除本地数据目录..."
        rm -rf volumes/filebeat/
        print_success "本地数据已删除"
    fi
    
    # 询问是否删除镜像
    if docker images --format '{{.Repository}}:{{.Tag}}' | grep -q "^${IMAGE_NAME}$" 2>/dev/null; then
        echo ""
        if [ "$skip_confirm" = true ] && [ "$remove_image" = true ]; then
            print_info "删除 Filebeat 镜像..."
            docker rmi ${IMAGE_NAME} 2>/dev/null || true
            print_success "镜像已删除"
        elif [ "$skip_confirm" != true ]; then
            read -p "$(echo -e "${YELLOW}是否删除 Filebeat 镜像? 这将释放约 600MB 空间 (y/N): ${NC}")" confirm_image
            if [ "$confirm_image" = "y" ] || [ "$confirm_image" = "Y" ]; then
                print_info "删除 Filebeat 镜像..."
                docker rmi ${IMAGE_NAME} 2>/dev/null || true
                print_success "镜像已删除"
            else
                print_info "保留镜像以便后续使用"
            fi
        fi
    fi
    
    echo ""
    print_success "清理完成！"
    
    # 显示释放的空间
    echo ""
    echo -e "${BLUE}提示:${NC}"
    echo "  • 查看 Docker 磁盘使用: docker system df"
    echo "  • 清理所有未使用资源: docker system prune -a"
}

logs() {
    print_header "Filebeat 实时日志"
    
    check_docker
    
    if ! docker ps --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
        print_error "Filebeat 容器未运行"
        print_info "请先启动服务: ./scripts/filebeat.sh start"
        exit 1
    fi
    
    echo -e "${YELLOW}⌨  按 Ctrl+C 退出日志查看${NC}"
    echo ""
    docker logs -f ${CONTAINER_NAME}
}

status() {
    print_header "Filebeat 状态检查"
    
    check_docker
    
    echo -e "${BOLD}${BLUE}[1] 容器运行状态${NC}"
    if docker ps --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
        print_success "容器正在运行"
        
        # 显示容器详细信息
        CONTAINER_INFO=$(docker inspect ${CONTAINER_NAME} --format '{{.State.Status}}|{{.State.StartedAt}}|{{.RestartCount}}')
        IFS='|' read -r STATUS STARTED RESTARTS <<< "$CONTAINER_INFO"
        echo "  状态: ${STATUS}"
        echo "  启动时间: ${STARTED}"
        echo "  重启次数: ${RESTARTS}"
    else
        print_error "容器未运行"
        if docker ps -a --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
            print_info "容器已创建但未启动，使用 'start' 命令启动"
        else
            print_info "容器不存在，使用 'start' 命令创建并启动"
        fi
    fi
    
    echo ""
    echo -e "${BOLD}${BLUE}[2] 最近日志 (最后 10 行)${NC}"
    if docker logs ${CONTAINER_NAME} --tail 10 2>/dev/null; then
        : # 成功
    else
        print_warn "无法获取日志（容器可能未运行）"
    fi
    
    echo ""
}

################################################################################
# 帮助信息
################################################################################

show_help() {
    cat << EOF
${BOLD}${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}
${BOLD}${CYAN}  Filebeat 管理脚本${NC}
${BOLD}${CYAN}  云原生日志收集平台 - SimpleELK${NC}
${BOLD}${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}

${BOLD}用法:${NC}
    ./scripts/filebeat.sh <命令>

${BOLD}命令:${NC}
    ${GREEN}init${NC}      初始化环境（创建必要目录）
    ${GREEN}test${NC}      测试配置文件语法
    ${GREEN}start${NC}     启动 Filebeat 服务
    ${GREEN}stop${NC}      停止 Filebeat 服务
    ${GREEN}restart${NC}   重启 Filebeat 服务
    ${GREEN}logs${NC}      查看实时日志
    ${GREEN}status${NC}    检查运行状态
    ${GREEN}clean${NC}     清理所有资源（容器、卷、数据）
                 使用 --all 同时删除镜像
    ${GREEN}help${NC}      显示此帮助信息

${BOLD}示例:${NC}
    ./scripts/filebeat.sh init
    ./scripts/filebeat.sh test
    ./scripts/filebeat.sh start
    ./scripts/filebeat.sh logs
    ./scripts/filebeat.sh status
    ./scripts/filebeat.sh clean        # 清理但保留镜像
    ./scripts/filebeat.sh clean --all  # 清理包括镜像

${BOLD}说明:${NC}
    • 首次使用建议执行: init -> test -> start
    • 测试完成后执行 clean 释放空间
    • clean --all 会删除镜像（约 600MB）
    • 配置文件位置: filebeat/filebeat.yml
    • 数据目录: volumes/filebeat/data
    • 日志目录: volumes/filebeat/logs

EOF
}

################################################################################
# 主程序入口
################################################################################

case "${1:-help}" in
    init)
        init
        ;;
    test)
        test_config
        ;;
    start)
        start
        ;;
    stop)
        stop
        ;;
    restart)
        restart
        ;;
    logs)
        logs
        ;;
    status)
        status
        ;;
    clean)
        # 检查是否有 --all 参数
        if [ "$2" = "--all" ] || [ "$2" = "-a" ]; then
            clean true true  # skip_confirm=true, remove_image=true
        else
            clean false false
        fi
        ;;
    help|--help|-h)
        show_help
        ;;
    *)
        print_error "未知命令: $1"
        echo ""
        show_help
        exit 1
        ;;
esac
