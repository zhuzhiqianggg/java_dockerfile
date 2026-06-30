# Java Docker Base Image

Java 基础运行环境镜像，支持 **amd64** 和 **arm64** 双架构。

基于 `eclipse-temurin:8-jdk`，内置 JMX Prometheus 监控，不包含 SkyWalking。

依赖全部在线下载，git 仅管理源码，克隆后可直接构建。

## ARM (arm64) 支持

镜像原生支持 **amd64** 和 **arm64**，无需修改代码。

| 场景 | 说明 |
|---|---|
| ARM 机器上直接构建 | `docker build -t img .` → 自动拉取 arm64 版本 `eclipse-temurin:8-jdk`，`TARGETARCH=arm64` 自动下载 tini-arm64 |
| x86 上构建 arm64 镜像 | `docker build --platform linux/arm64 -t img .` |
| 构建双架构并推送到仓库 | `docker buildx build --platform linux/amd64,linux/arm64 -t your-registry/img:tag --push .` |

所以构建出来的镜像在 arm64 服务器上直接可用。

## 构建

```bash
# 默认 amd64（最新 JDK 8 + JMX Exporter 1.6.0）
docker build -t java-base:latest .

# 指定 arm64
docker build --platform linux/arm64 -t java-base:latest .

# 使用 build.sh 构建并测试
./build.sh
./build.sh -t swr.cn-east-3.myhuaweicloud.com/beosin-develop/jdk:1.8_JMX_SW_20260630
./build.sh -t myimg:latest -n myapp -p 9000
./build.sh --platform linux/arm64 -t img:arm64
./build.sh -h   # 查看帮助

# 指定 JDK 版本（锁定具体更新）
docker build --build-arg JDK_VERSION=8u492-b09-jdk -t java-base:latest .

# 指定 JMX Exporter 版本（兼容 JDK 8 即可）
docker build --build-arg JMX_VERSION=1.6.0 -t java-base:latest .

# 单次命令构建双架构并推送
docker buildx build --platform linux/amd64,linux/arm64 \
  -t your-registry/java-base:latest --push .
```

## 构建参数

| 参数 | 默认值 | 说明 |
|---|---|---|
| `JDK_VERSION` | `8-jdk` | Eclipse Temurin 基础镜像标签，设为 `8u492-b09-jdk` 可锁定具体版本 |
| `JMX_VERSION` | `1.6.0` | Prometheus JMX Exporter 版本（从 GitHub Releases 下载） |

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

## 快速测试

依赖：Docker，无需安装 Java/Maven。

```bash
# 一键构建 + 测试 (build.sh)
chmod +x build.sh
./build.sh                              # 默认构建 java-base:latest 并测试
./build.sh -t my-registry/java-base:v1  # 指定镜像名称
./build.sh -n myapp -p 9000             # 指定应用名和端口
./build.sh -h                           # 查看全部选项

# 或使用 docker compose
docker compose run --rm build-test-app
docker compose up -d test-app
curl http://localhost:8080/api/info

# 清理
docker compose down
docker volume rm java_maven-repo
```

`test-app/` 是一个最小 Spring Boot 2.7 (JDK 8 兼容) 项目，包含 `/api/info` 和 `/actuator/health` 端点，用于验证镜像的构建和运行。详见 [`test-app/`](test-app/)。
