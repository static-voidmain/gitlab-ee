# Runner 이미지 빌드 가이드

`images/build-images.sh`는 amd64 전용 Runner 이미지를 로컬 Docker daemon 태그로 빌드합니다. 기본 네임스페이스는 `bwc`입니다.

```bash
./images/build-images.sh
./scripts/scan-images.sh
```

선택 이미지가 필요한 경우에만 명시적으로 추가합니다.

```bash
./images/build-images.sh --include-shell-tools
./images/build-images.sh --include-legacy
./scripts/scan-images.sh --include-shell-tools
./scripts/scan-images.sh --include-legacy
```

다른 로컬 네임스페이스가 필요하면 registry URL이 아니라 Docker 이미지명 prefix만 지정합니다.

```bash
LOCAL_IMAGE_NAMESPACE=my-team ./images/build-images.sh
```

기본 정책:

- JDK 8/17/21은 Eclipse Temurin 기반 이미지를 사용합니다.
- JDK는 Temurin JDK와 CA entrypoint만 `ubuntu:noble` 최종 단계에 복사하여 다운로드 전용 패키지를 제거합니다.
- Maven은 Apache Maven 3.9.x 최신 유지보수 라인 기준으로 구성합니다.
- Maven과 Gradle은 로컬 JDK runner 레이어를 재사용하여 이미지 중복을 줄입니다.
- Gradle 9.x는 Java 17 이상에서만 실행 가능하므로 JDK 8은 Gradle 8.14.5, JDK 17/21은 Gradle 9.5.1을 사용합니다.
- Node 24 runner는 Docker Scout 기준 Critical/High가 더 적은 `node:24-alpine3.23` 기반으로 구성합니다.
- pnpm은 runtime 재다운로드를 막기 위해 Corepack global 설치 버전을 `10.34.1`로 고정합니다.
- `node:24`, `npm:24`, `pnpm:24`는 동일 이미지에 붙는 별칭이므로 Docker image layer를 중복 저장하지 않습니다.
- `gitlab-runner-shell:19.0.0`은 공식 Runner 바이너리만 복사하여 Shell executor에 불필요한 `docker-machine`을 제외합니다.
- `shell-tools:2026.06`은 현재 표준 pipeline에서 사용하지 않으므로 `--include-shell-tools`를 지정할 때만 빌드합니다.
- JDK 7은 지원 종료로 보안 예외 이미지이며 `--include-legacy` 옵션과 승인된 내부 tarball이 있어야 빌드됩니다.

JDK 7 legacy 빌드에 필요한 파일:

- `vendor/jdk7/jdk-7u80-linux-x64.tar.gz`
- `vendor/jdk7/apache-maven-3.6.3-bin.tar.gz`
- `vendor/jdk7/gradle-4.10.3-bin.zip`

잠재적 위험 요소: JDK 7 이미지는 Critical/High 취약점 잔존이 예상되므로 protected runner와 수동 승인 없이 사용하면 안 됩니다.
