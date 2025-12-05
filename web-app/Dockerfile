# ============================================
# 多阶段构建 Dockerfile
# 用于创建轻量级的 Flask Web 应用镜像
# ============================================

# 使用官方 Python 3.9 slim 镜像作为基础镜像
FROM python:3.9-slim

# 设置工作目录
WORKDIR /app

# 设置环境变量
# PYTHONUNBUFFERED=1: 确保 Python 输出直接发送到终端（不缓冲）
# 这对于 Docker 日志采集非常重要！
ENV PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    PIP_NO_CACHE_DIR=1 \
    PIP_DISABLE_PIP_VERSION_CHECK=1

# 复制依赖文件
COPY requirements.txt .

# 安装 Python 依赖
# 使用 --no-cache-dir 减小镜像大小
RUN pip install --no-cache-dir -r requirements.txt

# 复制应用代码
COPY app.py .

# 暴露端口
EXPOSE 8000

# 健康检查
# 每 30 秒检查一次应用是否正常运行
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD python -c "import requests; requests.get('http://localhost:8000/health')" || exit 1

# 创建非 root 用户运行应用（安全最佳实践）
RUN useradd -m -u 1000 appuser && chown -R appuser:appuser /app
USER appuser

# 启动应用
# 使用 gunicorn 作为生产级 WSGI 服务器
# --workers 2: 使用 2 个工作进程
# --bind 0.0.0.0:8000: 监听所有网络接口
# --access-logfile -: 访问日志输出到 stdout
# --error-logfile -: 错误日志输出到 stderr
# --log-level info: 日志级别
CMD ["gunicorn", "--workers", "2", "--bind", "0.0.0.0:8000", "--access-logfile", "-", "--error-logfile", "-", "--log-level", "info", "app:app"]

