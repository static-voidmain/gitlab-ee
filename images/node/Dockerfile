# syntax=docker/dockerfile:1.7
FROM node:24-alpine3.23

# 요구사항: npm/pnpm runner 이미지. 구현상세: Node 24 LTS와 Corepack 기반 pnpm 10 최신 패치를 제공한다.
# 제약사항: 소스 checkout은 Runner helper가 담당하므로 취약점 표면을 넓히는 curl/git/jq를 추가하지 않는다.
ARG PNPM_VERSION=10.34.1
RUN set -eux; \
    corepack enable; \
    corepack install --global "pnpm@${PNPM_VERSION}"; \
    addgroup --gid 10001 bwc; \
    adduser --uid 10001 --ingroup bwc --disabled-password --shell /bin/sh bwc; \
    mkdir -p /workspace; \
    chown -R 10001:10001 /workspace

USER bwc:bwc
WORKDIR /workspace
ENV NPM_CONFIG_AUDIT=true \
    NPM_CONFIG_FUND=false \
    LANG=C.UTF-8
