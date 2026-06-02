# syntax=docker/dockerfile:1.7
FROM alpine:3.23

# 요구사항: Shell runner 보조 이미지. MR 댓글과 API 호출에 필요한 최소 도구만 설치한다.
# 제약사항: tar/unzip/git 등 추가 도구가 필요하면 프로젝트별 승인 이미지를 별도로 만든다.
USER root
RUN set -eux; \
    apk add --no-cache \
      bash ca-certificates curl jq; \
    addgroup --gid 10001 ci; \
    adduser --uid 10001 --ingroup ci --disabled-password --shell /bin/bash ci; \
    mkdir -p /workspace; \
    chown -R 10001:10001 /workspace

USER 10001:10001
WORKDIR /workspace
ENV LANG=C.UTF-8
