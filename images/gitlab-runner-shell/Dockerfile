# syntax=docker/dockerfile:1.7
ARG BASE_IMAGE=gitlab/gitlab-runner:alpine-v19.0.0
FROM ${BASE_IMAGE}

# 요구사항: Shell executor에서 CodeRay CLI, MR API 호출, 기본 Git 작업을 직접 실행한다.
# 제약사항: GitLab Runner 공식 Alpine 이미지에 필요한 최소 도구만 추가하고 CodeRay CLI는 runtime read-only mount로 주입한다.
USER root
RUN set -eux; \
    apk add --no-cache bash ca-certificates curl git jq; \
    update-ca-certificates

