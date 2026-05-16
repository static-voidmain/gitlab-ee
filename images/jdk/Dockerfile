# syntax=docker/dockerfile:1.7
ARG BASE_IMAGE=eclipse-temurin:21-jdk-noble
FROM ${BASE_IMAGE}

# 요구사항: JDK runner 이미지. 제약사항: amd64 빌드는 build-images.sh에서 --platform으로 강제한다.
USER root
RUN set -eux; \
    if command -v apt-get >/dev/null 2>&1; then \
      apt-get update; \
      apt-get install -y --no-install-recommends bash ca-certificates curl git tzdata; \
      rm -rf /var/lib/apt/lists/*; \
    fi; \
    groupadd --gid 10001 ci || true; \
    useradd --uid 10001 --gid 10001 --create-home --shell /bin/bash ci || true

USER 10001:10001
WORKDIR /workspace
ENV LANG=C.UTF-8
