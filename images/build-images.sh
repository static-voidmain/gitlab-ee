#!/usr/bin/env bash
set -Eeuo pipefail

# 요구사항: Runner용 maven/gradle/jdk/npm/pnpm/shell 이미지를 amd64로 직접 제작한다.
# 제약사항: 빌드 후 scripts/scan-images.sh로 Critical/High 취약점 결과를 확인한다.

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${ROOT_DIR}"

image_namespace="${LOCAL_IMAGE_NAMESPACE:-bwc}"
include_legacy=false
include_shell_tools=false

for arg in "$@"; do
  case "${arg}" in
    --include-legacy) include_legacy=true ;;
    --include-shell-tools) include_shell_tools=true ;;
    *) echo "ERROR: Unsupported option: ${arg}" >&2; exit 1 ;;
  esac
done

build_image() {
  local dockerfile="$1"
  local tag="$2"
  shift 2
  echo "Building ${tag}"
  docker build --platform linux/amd64 -f "${dockerfile}" -t "${tag}" "$@" .
}

build_image images/jdk/Dockerfile "${image_namespace}/jdk:8" --build-arg BASE_IMAGE=eclipse-temurin:8-jdk-jammy
build_image images/jdk/Dockerfile "${image_namespace}/jdk:17" --build-arg BASE_IMAGE=eclipse-temurin:17-jdk-noble
build_image images/jdk/Dockerfile "${image_namespace}/jdk:21" --build-arg BASE_IMAGE=eclipse-temurin:21-jdk-noble

build_image images/maven/Dockerfile "${image_namespace}/maven:jdk8" --build-arg MAVEN_IMAGE=maven:3.9.15-eclipse-temurin-8 --build-arg JDK_BASE_IMAGE="${image_namespace}/jdk:8"
build_image images/maven/Dockerfile "${image_namespace}/maven:jdk17" --build-arg MAVEN_IMAGE=maven:3.9.15-eclipse-temurin-17 --build-arg JDK_BASE_IMAGE="${image_namespace}/jdk:17"
build_image images/maven/Dockerfile "${image_namespace}/maven:jdk21" --build-arg MAVEN_IMAGE=maven:3.9.15-eclipse-temurin-21 --build-arg JDK_BASE_IMAGE="${image_namespace}/jdk:21"

build_image images/gradle/Dockerfile "${image_namespace}/gradle:jdk8" --build-arg GRADLE_IMAGE=gradle:8.14.5-jdk21 --build-arg JDK_BASE_IMAGE="${image_namespace}/jdk:8"
build_image images/gradle/Dockerfile "${image_namespace}/gradle:jdk17" --build-arg GRADLE_IMAGE=gradle:9.5.1-jdk21 --build-arg JDK_BASE_IMAGE="${image_namespace}/jdk:17"
build_image images/gradle/Dockerfile "${image_namespace}/gradle:jdk21" --build-arg GRADLE_IMAGE=gradle:9.5.1-jdk21 --build-arg JDK_BASE_IMAGE="${image_namespace}/jdk:21"

build_image images/node/Dockerfile "${image_namespace}/node:24"
docker tag "${image_namespace}/node:24" "${image_namespace}/npm:24"
docker tag "${image_namespace}/node:24" "${image_namespace}/pnpm:24"
build_image images/gitlab-runner-shell/Dockerfile "${image_namespace}/gitlab-runner-shell:19.0.0"

if [[ "${include_shell_tools}" == true ]]; then
  build_image images/shell-tools/Dockerfile "${image_namespace}/shell-tools:2026.06"
fi

if [[ "${include_legacy}" == true ]]; then
  build_image images/legacy-jdk7/Dockerfile "${image_namespace}/jdk:7"
  build_image images/maven-legacy-jdk7/Dockerfile "${image_namespace}/maven:jdk7"
  build_image images/gradle-legacy-jdk7/Dockerfile "${image_namespace}/gradle:jdk7"
fi

echo "Build completed. Run ./scripts/scan-images.sh before pushing to production use."
