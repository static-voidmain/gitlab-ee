# syntax=docker/dockerfile:1.7
ARG BASE_IMAGE=maven:3.9.15-eclipse-temurin-21
FROM ${BASE_IMAGE}

# 요구사항: Maven + JDK runner 이미지. 구현상세: Maven 3.9.x는 Java 8 이상 지원.
USER root
RUN set -eux; \
    if command -v apt-get >/dev/null 2>&1; then \
      apt-get update; \
      apt-get install -y --no-install-recommends bash ca-certificates curl git tzdata jq; \
      rm -rf /var/lib/apt/lists/*; \
    fi; \
    groupadd --gid 10001 ci || true; \
    useradd --uid 10001 --gid 10001 --create-home --shell /bin/bash ci || true; \
    mkdir -p /home/ci/.m2 /workspace; \
    chown -R 10001:10001 /home/ci /workspace

USER 10001:10001
WORKDIR /workspace
ENV MAVEN_OPTS="-Dhttps.protocols=TLSv1.2,TLSv1.3" \
    LANG=C.UTF-8
