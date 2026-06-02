#!/usr/bin/env bash
set -Eeuo pipefail

# 요구사항: Runner용 maven/gradle/jdk/npm/pnpm/shell 이미지를 amd64로 직접 제작한다.
# 제약사항: 빌드 후 scripts/scan-images.sh로 Critical/High 취약점 결과를 확인한다.

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${ROOT_DIR}"

registry="${INTERNAL_IMAGE_REGISTRY:-registry.example.co.kr/scm-runners}"
include_legacy=false
if [[ "${1:-}" == "--include-legacy" ]]; then
  include_legacy=true
fi

build_image() {
  local dockerfile="$1"
  local tag="$2"
  shift 2
  echo "Building ${tag}"
  docker build --platform linux/amd64 -f "${dockerfile}" -t "${tag}" "$@" .
}

build_image images/jdk/Dockerfile "${registry}/jdk:8" --build-arg BASE_IMAGE=eclipse-temurin:8-jdk-jammy
build_image images/jdk/Dockerfile "${registry}/jdk:17" --build-arg BASE_IMAGE=eclipse-temurin:17-jdk-noble
build_image images/jdk/Dockerfile "${registry}/jdk:21" --build-arg BASE_IMAGE=eclipse-temurin:21-jdk-noble

build_image images/maven/Dockerfile "${registry}/maven:jdk8" --build-arg BASE_IMAGE=maven:3.9.15-eclipse-temurin-8
build_image images/maven/Dockerfile "${registry}/maven:jdk17" --build-arg BASE_IMAGE=maven:3.9.15-eclipse-temurin-17
build_image images/maven/Dockerfile "${registry}/maven:jdk21" --build-arg BASE_IMAGE=maven:3.9.15-eclipse-temurin-21

build_image images/gradle/Dockerfile "${registry}/gradle:jdk8" --build-arg GRADLE_IMAGE=gradle:8.14.4-jdk21 --build-arg JDK_BASE_IMAGE=eclipse-temurin:8-jdk-noble
build_image images/gradle/Dockerfile "${registry}/gradle:jdk17" --build-arg GRADLE_IMAGE=gradle:9.3.1-jdk21 --build-arg JDK_BASE_IMAGE=eclipse-temurin:17-jdk-noble
build_image images/gradle/Dockerfile "${registry}/gradle:jdk21" --build-arg GRADLE_IMAGE=gradle:9.3.1-jdk21 --build-arg JDK_BASE_IMAGE=eclipse-temurin:21-jdk-noble

build_image images/node/Dockerfile "${registry}/node:24"
build_image images/node/Dockerfile "${registry}/npm:24"
build_image images/node/Dockerfile "${registry}/pnpm:24"
build_image images/shell-tools/Dockerfile "${registry}/shell-tools:2026.06"
build_image images/gitlab-runner-shell/Dockerfile "${registry}/gitlab-runner-shell:19.0.0"

if [[ "${include_legacy}" == true ]]; then
  build_image images/legacy-jdk7/Dockerfile "${registry}/jdk:7"
  build_image images/maven-legacy-jdk7/Dockerfile "${registry}/maven:jdk7"
  build_image images/gradle-legacy-jdk7/Dockerfile "${registry}/gradle:jdk7"
fi

echo "Build completed. Run ./scripts/scan-images.sh before pushing to production use."
