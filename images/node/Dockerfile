# syntax=docker/dockerfile:1.7
FROM node:24-bookworm-slim

# 요구사항: npm/pnpm runner 이미지. 구현상세: Node 24 LTS와 Corepack 기반 pnpm을 제공한다.
ARG PNPM_VERSION=10
USER root
RUN set -eux; \
    apt-get update; \
    apt-get install -y --no-install-recommends bash ca-certificates curl git jq tzdata; \
    rm -rf /var/lib/apt/lists/*; \
    corepack enable; \
    corepack prepare "pnpm@${PNPM_VERSION}" --activate; \
    mkdir -p /workspace; \
    chown -R node:node /workspace

USER node
WORKDIR /workspace
ENV NPM_CONFIG_AUDIT=true \
    NPM_CONFIG_FUND=false \
    LANG=C.UTF-8
