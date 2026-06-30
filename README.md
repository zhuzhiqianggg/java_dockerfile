# Java Docker Base Image

Java 基础运行环境镜像，支持 **amd64** 和 **arm64** 双架构。

基于 `eclipse-temurin:8-jdk`，内置 JMX Prometheus 监控，不包含 SkyWalking。

依赖全部在线下载，git 仅管理源码，克隆后可直接构建。

## 构建

```bash
# 默认 amd64
docker build -t java-base:latest .

# 指定 arm64
docker build --platform linux/arm64 -t java-base:latest .

# 单次命令构建双架构并推送
docker buildx build --platform linux/amd64,linux/arm64 \
  -t your-registry/java-base:latest --push .
```

## 环境变量

| 变量 | 默认值 | 说明 |
|---|---|---|
| `APP_NAME` | (必填) | 服务名称，对应 jar 文件名 |
| `APP_PORT` | `8080` | 服务端口 |
| `JVM_HEAP` | (自动) | 堆内存，为空则根据容器内存自动计算 |
| `JVM_EXTRA_OPTS` | (空) | 附加 JVM 参数 |
| `JMX_PORT` | (空) | JMX Prometheus 端口，设值即启用 |
| `DEBUG` | `false` | 调试日志 |

## 启动

```bash
docker run -d --name myapp \
  -e APP_NAME=my-service \
  -e APP_PORT=8080 \
  -v /path/to/my-service.jar:/service/jar/my-service.jar \
  java-base:latest
```

## 内存说明

JVM 总内存 = 堆 + Metaspace + CodeCache + 线程栈 + 堆外 (约 20-30%)。
推荐限制容器总内存，由 JVM 自动分配：

```bash
docker run --memory=6g -e APP_NAME=myapp my-image
# -> JVM 堆 ~4.2g (MaxRAMPercentage=70)
```

## OOM 诊断

- 堆快照: `/service/dumps/*.hprof`
- Crash 日志: `/service/logs/hs_err_pid*.log`
- GC 日志: `/service/logs/gc.log`
