# syntax=docker/dockerfile:1.7
ARG MAVEN_IMAGE=maven:3.9.15-eclipse-temurin-21
ARG JDK_BASE_IMAGE=eclipse-temurin:21-jdk-noble
FROM ${MAVEN_IMAGE} AS maven-dist

FROM ${JDK_BASE_IMAGE}

# 요구사항: Maven + JDK runner 이미지. 구현상세: Maven 3.9.x는 Java 8 이상 지원한다.
# 구현상세: Maven 배포판만 복사하고 내부 JDK runner 레이어를 재사용하여 중복 OS 패키지를 제거한다.
COPY --from=maven-dist /usr/share/maven /usr/share/maven
COPY --from=maven-dist /usr/local/bin/mvn-entrypoint.sh /usr/local/bin/mvn-entrypoint.sh
USER root
RUN set -eux; \
    apt-get update; \
    DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends curl jq; \
    rm -rf /var/lib/apt/lists/* /usr/share/doc/* /usr/share/man/*; \
    ln -sf /usr/share/maven/bin/mvn /usr/bin/mvn; \
    getent group ci >/dev/null || groupadd --gid 10001 ci; \
    id -u ci >/dev/null 2>&1 || useradd --uid 10001 --gid 10001 --create-home --shell /bin/bash ci; \
    mkdir -p /home/ci/.m2 /workspace; \
    chown -R 10001:10001 /home/ci /workspace

ENTRYPOINT ["/usr/local/bin/mvn-entrypoint.sh"]
CMD ["mvn"]
USER 10001:10001
WORKDIR /workspace
ENV MAVEN_HOME=/usr/share/maven \
    MAVEN_CONFIG=/home/ci/.m2 \
    MAVEN_OPTS="-Dhttps.protocols=TLSv1.2,TLSv1.3" \
    LANG=C.UTF-8
