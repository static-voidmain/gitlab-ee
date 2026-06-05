# syntax=docker/dockerfile:1.7
ARG GRADLE_IMAGE=gradle:9.5.1-jdk21
ARG JDK_BASE_IMAGE=bwc/jdk:21
FROM ${GRADLE_IMAGE} AS gradle-dist

FROM ${JDK_BASE_IMAGE}

# 요구사항: Gradle + JDK runner 이미지.
# 구현상세: 취약점이 많은 공식 Gradle runtime 대신 배포판만 복사하고 내부 JDK runner 레이어를 재사용한다.
# 제약사항: JDK 8은 Gradle 8.14.x, JDK 17/21은 Gradle 9.x 계열을 build arg로 선택한다.
COPY --from=gradle-dist /opt/gradle /opt/gradle
USER bwc:bwc
WORKDIR /workspace
ENV GRADLE_HOME=/opt/gradle \
    GRADLE_USER_HOME=/home/bwc/.gradle \
    PATH=/opt/gradle/bin:${PATH} \
    LANG=C.UTF-8
