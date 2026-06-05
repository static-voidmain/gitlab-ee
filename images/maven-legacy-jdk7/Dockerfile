# syntax=docker/dockerfile:1.7
FROM ubuntu:20.04

# 보안 예외: JDK 7 + Maven은 protected legacy runner 전용이다.
ARG JDK7_TARBALL=jdk-7u80-linux-x64.tar.gz
ARG MAVEN_TARBALL=apache-maven-3.6.3-bin.tar.gz
RUN set -eux; \
    apt-get update; \
    apt-get install -y --no-install-recommends bash ca-certificates curl git tzdata; \
    rm -rf /var/lib/apt/lists/*; \
    groupadd --gid 10001 bwc; \
    useradd --uid 10001 --gid 10001 --create-home --shell /bin/bash bwc; \
    mkdir -p /opt/jdk7 /opt/maven /workspace
COPY vendor/jdk7/${JDK7_TARBALL} /tmp/jdk7.tar.gz
COPY vendor/jdk7/${MAVEN_TARBALL} /tmp/maven.tar.gz
RUN set -eux; \
    tar -xzf /tmp/jdk7.tar.gz --strip-components=1 -C /opt/jdk7; \
    tar -xzf /tmp/maven.tar.gz --strip-components=1 -C /opt/maven; \
    rm -f /tmp/jdk7.tar.gz /tmp/maven.tar.gz; \
    chown -R root:root /opt/jdk7 /opt/maven; \
    chown -R 10001:10001 /workspace

ENV JAVA_HOME=/opt/jdk7 \
    MAVEN_HOME=/opt/maven \
    PATH=/opt/maven/bin:/opt/jdk7/bin:${PATH} \
    LANG=C.UTF-8
USER bwc:bwc
WORKDIR /workspace
