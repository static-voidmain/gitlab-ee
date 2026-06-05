# syntax=docker/dockerfile:1.7
FROM ubuntu:20.04

# 보안 예외: JDK 7은 지원 종료로 Critical/High 0건 달성이 어렵다.
# 구현상세: 외부 다운로드 대신 승인된 내부 tarball만 COPY한다.
ARG JDK7_TARBALL=jdk-7u80-linux-x64.tar.gz
RUN set -eux; \
    apt-get update; \
    apt-get install -y --no-install-recommends bash ca-certificates curl git tzdata; \
    rm -rf /var/lib/apt/lists/*; \
    groupadd --gid 10001 bwc; \
    useradd --uid 10001 --gid 10001 --create-home --shell /bin/bash bwc; \
    mkdir -p /opt/jdk7 /workspace
COPY vendor/jdk7/${JDK7_TARBALL} /tmp/jdk7.tar.gz
RUN set -eux; \
    tar -xzf /tmp/jdk7.tar.gz --strip-components=1 -C /opt/jdk7; \
    rm -f /tmp/jdk7.tar.gz; \
    chown -R root:root /opt/jdk7; \
    chown -R 10001:10001 /workspace

ENV JAVA_HOME=/opt/jdk7 \
    PATH=/opt/jdk7/bin:${PATH} \
    LANG=C.UTF-8
USER bwc:bwc
WORKDIR /workspace
