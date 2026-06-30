# Java Docker Base Image

Java 基础运行环境镜像，基于 Ubuntu 24.04 + JDK 8，内置 JMX Prometheus 监控和可选 SkyWalking APM。

## 快速开始

```bash
# 构建基础镜像
docker build -t java-base:latest .

# 启动服务
docker run -d --name myapp \
  -e APP_NAME=my-service \
  -e APP_PORT=8080 \
  -v /path/to/my-service.jar:/service/jar/my-service.jar \
  java-base:latest
```

## 环境变量

| 变量 | 默认值 | 说明 |
|---|---|---|
| `APP_NAME` | (必填) | 服务名称，对应 jar 文件名 |
| `APP_PORT` | `8080` | 服务端口 |
| `JVM_HEAP` | (自动) | 堆内存，为空则根据容器内存自动计算 |
| `JVM_EXTRA_OPTS` | (空) | 附加 JVM 参数 |
| `JMX_PORT` | (空) | JMX Prometheus 端口，设值即启用 |
| `SW_COLLECTOR_HOST` | (空) | SkyWalking OAP 地址，设值即启用 |
| `SW_COLLECTOR_PORT` | `11800` | SkyWalking 端口 |
| `SW_AGENT_NAME` | (空) | SkyWalking 服务名称 |
| `DEBUG` | `false` | 调试日志 |

## 内存管理

JVM 总内存 = 堆 + Metaspace + CodeCache + 线程栈 + DirectBuffer + Native 开销 (约 20-30%)。

推荐方式：不设 `JVM_HEAP`，通过 Docker `--memory` 限制容器总内存：
```bash
docker run --memory=6g -e APP_NAME=myapp my-image
# → JVM 自动分配堆约 4.2g，保留 1.8g 给堆外开销
```

## OOM 诊断

OOM 时自动生成堆转储和诊断信息：
- 堆快照: `/service/dumps/*.hprof`
- Crash 日志: `/service/logs/hs_err_pid*.log`
- GC 日志: `/service/logs/gc.log`
- OOM 诊断: `/opt/oom_handler.sh`

## 使用 SkyWalking

如需 SkyWalking APM，在子镜像中添加：
```dockerfile
FROM java-base:latest
COPY ./skywalking-agent /opt/skywalking
```

运行时设置环境变量启用：
```bash
docker run -e SW_COLLECTOR_HOST=oap:11800 -e SW_AGENT_NAME=myapp ...
```
