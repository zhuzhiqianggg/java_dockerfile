FROM ubuntu:24.04

SHELL ["/bin/bash", "-c"]

LABEL maintainer="DevOps Team <devops@example.com>" \
      version="2.0" \
      description="Java base runtime with JMX monitoring (SkyWalking optional)"

ARG DEBIAN_FRONTEND=noninteractive

RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        locales \
        curl \
        ca-certificates \
        iputils-ping \
        dnsutils \
        netcat-openbsd \
        procps && \
    sed -i '/zh_CN.UTF-8/s/^# //g' /etc/locale.gen && \
    locale-gen zh_CN.UTF-8 && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

RUN mkdir -p /opt/{jdk,jmx_exporter} /service/{jar,logs,dumps} /tmp/dumps

COPY --chmod=755 ./tini /usr/bin/tini

COPY ./jdk1.8.0_451 /opt/jdk
ENV JAVA_HOME=/opt/jdk \
    PATH=$PATH:/opt/jdk/bin

COPY ./jmx_prometheus_javaagent-1.3.0.jar /opt/jmx_exporter/jmx_prometheus_javaagent.jar
COPY ./jmx-config.yml /opt/jmx_exporter/config.yml

COPY --chmod=755 entrypoint.sh /entrypoint.sh
COPY --chmod=755 oom_handler.sh /opt/oom_handler.sh

ENV APP_NAME="" \
    APP_PORT=8080 \
    JVM_HEAP="" \
    JVM_EXTRA_OPTS="" \
    JMX_PORT="" \
    SW_COLLECTOR_HOST="" \
    SW_COLLECTOR_PORT=11800 \
    SW_AGENT_NAME="" \
    SW_AGENT_NAMESPACE="" \
    SW_AGENT_CLUSTER="" \
    DEBUG="false"

RUN groupadd -r appuser && useradd -r -g appuser appuser && \
    chown -R root:appuser /opt /service && \
    chmod -R 755 /opt && \
    chmod 775 /service/logs /service/dumps /tmp/dumps

HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
    CMD /bin/bash -c 'curl -sf http://localhost:${APP_PORT}/actuator/health 2>/dev/null || nc -z localhost ${APP_PORT} || exit 1'

WORKDIR /service
USER appuser
ENTRYPOINT ["/usr/bin/tini", "--", "/entrypoint.sh"]
