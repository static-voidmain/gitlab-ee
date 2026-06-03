# syntax=docker/dockerfile:1.7
ARG BASE_IMAGE=gitlab/gitlab-runner:alpine-v19.0.0
FROM ${BASE_IMAGE} AS runner-dist

FROM alpine:3.23

# 요구사항: Shell executor에서 CodeRay CLI, MR API 호출, 기본 Git 작업을 직접 실행한다.
# 구현상세: 공식 이미지에서 Runner 바이너리와 entrypoint만 복사하여 Docker executor용 docker-machine을 제외한다.
# 제약사항: CodeRay CLI는 runtime read-only mount로 주입한다.
USER root
RUN set -eux; \
    apk add --no-cache bash ca-certificates curl dumb-init git git-lfs jq tzdata; \
    update-ca-certificates; \
    adduser --uid 100 --ingroup nogroup --disabled-password --shell /bin/bash gitlab-runner; \
    mkdir -p /etc/gitlab-runner /home/gitlab-runner; \
    chown -R gitlab-runner:nogroup /home/gitlab-runner

COPY --from=runner-dist /usr/bin/gitlab-runner /usr/bin/gitlab-runner
COPY --from=runner-dist /entrypoint /entrypoint

VOLUME ["/etc/gitlab-runner", "/home/gitlab-runner"]
STOPSIGNAL SIGQUIT
ENTRYPOINT ["/usr/bin/dumb-init", "/entrypoint"]
CMD ["run", "--user=gitlab-runner", "--working-directory=/home/gitlab-runner"]
