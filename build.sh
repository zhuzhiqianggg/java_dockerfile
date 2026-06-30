#!/bin/bash
set -euo pipefail

cd "$(dirname "$(readlink -f "$0")")"

APP_NAME="${1:-test-app}"
APP_PORT="${2:-8080}"
BASE_IMAGE="${3:-java-base:latest}"

echo "============================================"
echo " Java Docker Base - Build & Test"
echo "============================================"
echo " Base image: ${BASE_IMAGE}"
echo " App name:   ${APP_NAME}"
echo " App port:   ${APP_PORT}"
echo "============================================"

echo ""
echo "[1/4] Building base image..."
docker build -t "${BASE_IMAGE}" .

echo ""
echo "[2/4] Building test app (Maven in Docker)..."
docker run --rm \
    -v "$(pwd)/test-app:/app" \
    -v maven-repo:/root/.m2 \
    -w /app \
    maven:3.8.5-openjdk-8 \
    mvn clean package -q -DskipTests

JAR="test-app/target/test-app.jar"
if [[ ! -f "${JAR}" ]]; then
    echo "ERROR: ${JAR} not found after Maven build!"
    exit 1
fi
echo "       Jar: ${JAR} ($(du -h "${JAR}" | cut -f1))"

echo ""
echo "[3/4] Starting container..."
docker rm -f "${APP_NAME}" 2>/dev/null || true
docker run -d --name "${APP_NAME}" \
    --memory=512m \
    -p "${APP_PORT}:${APP_PORT}" \
    -e APP_NAME="${APP_NAME}" \
    -e APP_PORT="${APP_PORT}" \
    -v "$(pwd)/${JAR}:/service/jar/${APP_NAME}.jar" \
    "${BASE_IMAGE}"

echo ""
echo "[4/4] Waiting for app to start..."
for i in $(seq 1 15); do
    sleep 2
    if curl -sf "http://localhost:${APP_PORT}/api/info" > /dev/null 2>&1; then
        echo "============================================"
        echo " App started successfully!"
        echo "============================================"
        curl -s "http://localhost:${APP_PORT}/api/info"
        echo ""
        curl -s "http://localhost:${APP_PORT}/actuator/health" | python3 -m json.tool 2>/dev/null || curl -s "http://localhost:${APP_PORT}/actuator/health"
        echo ""
        echo "--- BUILD & TEST PASSED ---"
        echo ""
        echo "Test endpoints:"
        echo "  http://localhost:${APP_PORT}/api/info"
        echo "  http://localhost:${APP_PORT}/actuator/health"
        echo "  docker logs -f ${APP_NAME}"
        echo ""
        echo "Stop:  docker stop ${APP_NAME} && docker rm ${APP_NAME}"
        exit 0
    fi
    echo " Waiting... ($i/15)"
done

echo ""
echo "App failed to start within timeout. Logs:"
docker logs "${APP_NAME}" 2>&1 | tail -40
echo "--- BUILD & TEST FAILED ---"
docker rm -f "${APP_NAME}" 2>/dev/null || true
exit 1
