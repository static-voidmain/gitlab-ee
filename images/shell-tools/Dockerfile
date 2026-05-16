# syntax=docker/dockerfile:1.7
FROM debian:bookworm-slim

# 요구사항: Shell runner 보조 이미지. MR 댓글, API 호출, 스크립트 검증에 필요한 최소 도구만 설치한다.
USER root
RUN set -eux; \
    apt-get update; \
    apt-get install -y --no-install-recommends \
      bash ca-certificates curl git jq openssl tar unzip findutils grep sed gawk tzdata; \
    rm -rf /var/lib/apt/lists/*; \
    groupadd --gid 10001 ci; \
    useradd --uid 10001 --gid 10001 --create-home --shell /bin/bash ci; \
    mkdir -p /workspace; \
    chown -R 10001:10001 /workspace

USER 10001:10001
WORKDIR /workspace
ENV LANG=C.UTF-8
