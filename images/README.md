# Runner 이미지 빌드 가이드

`images/build-images.sh`는 amd64 전용 Runner 이미지를 사내 registry 태그로 빌드합니다.

```bash
INTERNAL_IMAGE_REGISTRY=registry.example.co.kr/scm-runners ./images/build-images.sh
./scripts/scan-images.sh
```

기본 정책:

- JDK 8/17/21은 Eclipse Temurin 기반 이미지를 사용합니다.
- Maven은 Apache Maven 3.9.x 최신 유지보수 라인 기준으로 구성합니다.
- Gradle 9.x는 Java 17 이상에서만 실행 가능하므로 JDK 8은 Gradle 8.14.x 계열을 사용합니다.
- Node 24 runner는 Docker Scout 기준 Critical/High가 더 적은 `node:24-alpine3.23` 기반으로 구성합니다.
- `gitlab-runner-shell:19.0.0`은 Shell executor에서 CodeRay CLI와 MR API 호출을 실행하기 위한 최소 도구를 추가합니다.
- JDK 7은 지원 종료로 보안 예외 이미지이며 `--include-legacy` 옵션과 승인된 내부 tarball이 있어야 빌드됩니다.

JDK 7 legacy 빌드에 필요한 파일:

- `vendor/jdk7/jdk-7u80-linux-x64.tar.gz`
- `vendor/jdk7/apache-maven-3.6.3-bin.tar.gz`
- `vendor/jdk7/gradle-4.10.3-bin.zip`

잠재적 위험 요소: JDK 7 이미지는 Critical/High 취약점 잔존이 예상되므로 protected runner와 수동 승인 없이 사용하면 안 됩니다.
