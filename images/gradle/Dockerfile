# syntax=docker/dockerfile:1.7
ARG BASE_IMAGE=gradle:9.3.1-jdk21
FROM ${BASE_IMAGE}

# 요구사항: Gradle + JDK runner 이미지.
# 구현상세: JDK 8은 Gradle 8.14.x, JDK 17/21은 Gradle 9.x 계열을 build arg로 선택한다.
USER root
RUN set -eux; \
    if command -v apt-get >/dev/null 2>&1; then \
      apt-get update; \
      apt-get install -y --no-install-recommends bash ca-certificates curl git tzdata jq; \
      rm -rf /var/lib/apt/lists/*; \
    elif command -v microdnf >/dev/null 2>&1; then \
      microdnf install -y bash ca-certificates curl git tzdata jq; \
      microdnf clean all; \
    fi; \
    mkdir -p /workspace; \
    chown -R gradle:gradle /workspace

USER gradle
WORKDIR /workspace
ENV GRADLE_USER_HOME=/home/gradle/.gradle \
    LANG=C.UTF-8
