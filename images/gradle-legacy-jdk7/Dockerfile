# syntax=docker/dockerfile:1.7
FROM ubuntu:20.04

# 보안 예외: JDK 7 + Gradle 4.10.3은 protected legacy runner 전용이다.
ARG JDK7_TARBALL=jdk-7u80-linux-x64.tar.gz
ARG GRADLE_ZIP=gradle-4.10.3-bin.zip
USER root
RUN set -eux; \
    apt-get update; \
    apt-get install -y --no-install-recommends bash ca-certificates curl git tzdata unzip; \
    rm -rf /var/lib/apt/lists/*; \
    groupadd --gid 10001 ci; \
    useradd --uid 10001 --gid 10001 --create-home --shell /bin/bash ci; \
    mkdir -p /opt/jdk7 /opt/gradle /workspace
COPY vendor/jdk7/${JDK7_TARBALL} /tmp/jdk7.tar.gz
COPY vendor/jdk7/${GRADLE_ZIP} /tmp/gradle.zip
RUN set -eux; \
    tar -xzf /tmp/jdk7.tar.gz --strip-components=1 -C /opt/jdk7; \
    unzip -q /tmp/gradle.zip -d /opt; \
    mv /opt/gradle-4.10.3/* /opt/gradle/; \
    rm -rf /opt/gradle-4.10.3 /tmp/jdk7.tar.gz /tmp/gradle.zip; \
    chown -R root:root /opt/jdk7 /opt/gradle; \
    chown -R 10001:10001 /workspace

ENV JAVA_HOME=/opt/jdk7 \
    GRADLE_HOME=/opt/gradle \
    PATH=/opt/gradle/bin:/opt/jdk7/bin:${PATH} \
    LANG=C.UTF-8
USER 10001:10001
WORKDIR /workspace
