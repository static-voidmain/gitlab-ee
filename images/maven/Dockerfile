# syntax=docker/dockerfile:1.7
ARG MAVEN_IMAGE=maven:3.9.15-eclipse-temurin-21
ARG JDK_BASE_IMAGE=bwc/jdk:21
FROM ${MAVEN_IMAGE} AS maven-dist

FROM ${JDK_BASE_IMAGE}

# 요구사항: Maven + JDK runner 이미지. 구현상세: Maven 3.9.x는 Java 8 이상 지원한다.
# 구현상세: Maven 배포판만 복사하고 내부 JDK runner 레이어를 재사용하여 중복 OS 패키지를 제거한다.
COPY --from=maven-dist /usr/share/maven /usr/share/maven
COPY --from=maven-dist /usr/local/bin/mvn-entrypoint.sh /usr/local/bin/mvn-entrypoint.sh

ENTRYPOINT ["/usr/local/bin/mvn-entrypoint.sh"]
CMD ["mvn"]
USER bwc:bwc
WORKDIR /workspace
ENV MAVEN_HOME=/usr/share/maven \
    MAVEN_CONFIG=/home/bwc/.m2 \
    MAVEN_OPTS="-Dhttps.protocols=TLSv1.2,TLSv1.3" \
    PATH=/usr/share/maven/bin:${PATH} \
    LANG=C.UTF-8
