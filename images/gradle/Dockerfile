# syntax=docker/dockerfile:1.7
ARG GRADLE_IMAGE=gradle:9.3.1-jdk21
ARG JDK_BASE_IMAGE=eclipse-temurin:21-jdk-noble
FROM ${GRADLE_IMAGE} AS gradle-dist

FROM ${JDK_BASE_IMAGE}

# 요구사항: Gradle + JDK runner 이미지.
# 구현상세: 취약점이 많은 공식 Gradle runtime 대신 배포판만 복사하고 Temurin 기반 최종 이미지를 만든다.
# 제약사항: JDK 8은 Gradle 8.14.x, JDK 17/21은 Gradle 9.x 계열을 build arg로 선택한다.
USER root
RUN set -eux; \
    apt-get update; \
    apt-get install -y --no-install-recommends bash ca-certificates; \
    rm -rf /var/lib/apt/lists/*; \
    groupadd --gid 10001 ci; \
    useradd --uid 10001 --gid 10001 --create-home --shell /bin/bash ci; \
    mkdir -p /workspace; \
    chown -R 10001:10001 /workspace

COPY --from=gradle-dist /opt/gradle /opt/gradle
USER 10001:10001
WORKDIR /workspace
ENV GRADLE_HOME=/opt/gradle \
    GRADLE_USER_HOME=/home/ci/.gradle \
    PATH=/opt/gradle/bin:${PATH} \
    LANG=C.UTF-8
