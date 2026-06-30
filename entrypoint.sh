#!/bin/bash
set -euo pipefail

# =============================================================================
#  Java Base Image Entrypoint
#  Usage: docker run -e APP_NAME=myapp -e APP_PORT=8080 ...
#
#  内存说明:
#    JVM 进程总内存 = Heap + Metaspace + CodeCache + ThreadStack + DirectBuffer + Native
#    当 -Xmx4g 时, 总 RSS ≈ 4.8~5.5G 是正常范围.
#    推荐做法: 不设 JVM_HEAP, 通过 Docker --memory 限制容器总内存,
#    配合 -XX:MaxRAMPercentage=70 自动计算堆大小, 保留 30% 给非堆开销.
#    例: docker run --memory=6g -> 自动 Heap~4.2g, 总内存~6g, 不会超限.
# =============================================================================

log()    { echo "[$(date '+%Y-%m-%d %H:%M:%S')] [entrypoint] $*" >&2; }
debug()  { [[ "${DEBUG}" == "true" ]] && echo "[$(date '+%Y-%m-%d %H:%M:%S')] [entrypoint] DEBUG: $*" >&2; }
error()  { echo "[$(date '+%Y-%m-%d %H:%M:%S')] [entrypoint] ERROR: $*" >&2; }

validate() {
    [[ -z "${APP_NAME}" ]] && { error "APP_NAME is required"; exit 1; }
    [[ -z "${APP_PORT}" ]]  && { error "APP_PORT is required";  exit 1; }
    local jar="/service/jar/${APP_NAME}.jar"
    [[ -f "$jar" ]] || { error "JAR not found: $jar"; exit 1; }
    debug "Validation passed"
}

build_default_jvm_opts() {
    local -a opts=(
        "-Djava.security.egd=file:/dev/urandom"
        "-Duser.timezone=Asia/Shanghai"
        "-Dfile.encoding=UTF-8"
        "-Djava.awt.headless=true"
        "-Djava.net.preferIPv4Stack=true"
        "-Djava.io.tmpdir=/tmp"
        "-Dsun.net.inetaddr.ttl=60"

        "-XX:+UseContainerSupport"
        "-XX:MaxRAMPercentage=70.0"

        "-XX:+UnlockExperimentalVMOptions"
        "-XX:+UseG1GC"
        "-XX:MaxGCPauseMillis=200"
        "-XX:G1HeapRegionSize=16m"
        "-XX:G1NewSizePercent=15"
        "-XX:G1MaxNewSizePercent=40"
        "-XX:InitiatingHeapOccupancyPercent=45"
        "-XX:ConcGCThreads=2"
        "-XX:+ParallelRefProcEnabled"
        "-XX:+DisableExplicitGC"

        "-XX:MetaspaceSize=128m"
        "-XX:MaxMetaspaceSize=256m"
        "-XX:ReservedCodeCacheSize=240m"

        "-XX:+AlwaysPreTouch"
        "-XX:+UseStringDeduplication"
        "-XX:+OptimizeStringConcat"
        "-XX:+UseCompressedOops"
        "-XX:+UseCompressedClassPointers"

        "-XX:+HeapDumpOnOutOfMemoryError"
        "-XX:HeapDumpPath=/service/dumps"
        "-XX:ErrorFile=/service/logs/hs_err_pid%p.log"
        "-XX:OnOutOfMemoryError=/opt/oom_handler.sh"
        "-XX:+ExitOnOutOfMemoryError"
        "-XX:NativeMemoryTracking=summary"

        "-Dspring.main.register-shutdown-hook=true"
        "-Dspring.jmx.enabled=true"
    )

    local ver
    ver=$(java -version 2>&1 | head -1)
    debug "Java version: ${ver}"

    if grep -q "1\.8" <<< "${ver}"; then
        opts+=(
            "-Xloggc:/service/logs/gc.log"
            "-XX:+PrintGCDetails"
            "-XX:+PrintGCDateStamps"
            "-XX:+PrintGCApplicationStoppedTime"
            "-XX:+UseGCLogFileRotation"
            "-XX:NumberOfGCLogFiles=5"
            "-XX:GCLogFileSize=10M"
        )
    else
        opts+=("-Xlog:gc*,gc+heap=debug:file=/service/logs/gc.log:time,uptime:filecount=5,filesize=10M")
    fi

    printf "%s\n" "${opts[@]}"
}

main() {
    log "Starting ${APP_NAME} on port ${APP_PORT}"
    validate
    mkdir -p /service/logs /service/dumps

    local -a cmd=("java" "-Dlabel=${APP_NAME}")

    if [[ -n "${JVM_HEAP}" ]]; then
        debug "JVM_HEAP: ${JVM_HEAP}"
        read -ra heap <<< "${JVM_HEAP}"
        cmd+=("${heap[@]}")
    fi

    if [[ -n "${JMX_PORT}" ]]; then
        log "JMX exporter: port ${JMX_PORT}"
        cmd+=("-javaagent:/opt/jmx_exporter/jmx_prometheus_javaagent.jar=${JMX_PORT}:/opt/jmx_exporter/config.yml")
    fi

    while IFS= read -r opt; do
        [[ -n "$opt" ]] && cmd+=("$opt")
    done < <(build_default_jvm_opts)

    if [[ -n "${JVM_EXTRA_OPTS}" ]]; then
        debug "JVM_EXTRA_OPTS: ${JVM_EXTRA_OPTS}"
        read -ra extra <<< "${JVM_EXTRA_OPTS}"
        cmd+=("${extra[@]}")
    fi

    cmd+=("-jar" "/service/jar/${APP_NAME}.jar" "--server.port=${APP_PORT}")

    debug "Final command: ${cmd[*]}"
    exec "${cmd[@]}"
}

main "$@"
