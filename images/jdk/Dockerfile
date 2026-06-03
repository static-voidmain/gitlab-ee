# syntax=docker/dockerfile:1.7
ARG BASE_IMAGE=eclipse-temurin:21-jdk-noble
ARG RUNTIME_BASE_IMAGE=ubuntu:noble
FROM ${BASE_IMAGE} AS jdk-dist

FROM ${RUNTIME_BASE_IMAGE} AS runtime-base

# 요구사항: JDK runner 이미지. 제약사항: amd64 빌드는 build-images.sh에서 --platform으로 강제한다.
# 구현상세: 공통 OS 의존성 레이어를 JDK 복사 전에 만들어 버전별 이미지가 registry blob을 공유하게 한다.
ENV JAVA_HOME=/opt/java/openjdk \
    PATH=/opt/java/openjdk/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin \
    LANG=C.UTF-8
USER root
RUN set -eux; \
    apt-get update; \
    DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
      binutils \
      ca-certificates \
      fontconfig \
      openssl \
      p11-kit \
      tzdata; \
    rm -rf /var/lib/apt/lists/* /usr/share/doc/* /usr/share/man/*; \
    groupadd --gid 10001 ci; \
    useradd --uid 10001 --gid 10001 --create-home --shell /bin/bash ci; \
    mkdir -p /workspace; \
    chown -R 10001:10001 /workspace

FROM runtime-base

# 구현상세: Temurin의 검증된 JDK와 CA entrypoint만 복사하여 다운로드 전용 패키지가 최종 이미지에 남지 않게 한다.
COPY --from=jdk-dist /opt/java/openjdk /opt/java/openjdk
COPY --from=jdk-dist /__cacert_entrypoint.sh /__cacert_entrypoint.sh
RUN set -eux; \
    find "${JAVA_HOME}/lib" -name '*.so' -exec dirname '{}' ';' | sort -u > /etc/ld.so.conf.d/docker-openjdk.conf; \
    ldconfig; \
    java -version; \
    javac -version

ENTRYPOINT ["/__cacert_entrypoint.sh"]
CMD ["java", "-version"]
USER 10001:10001
WORKDIR /workspace
