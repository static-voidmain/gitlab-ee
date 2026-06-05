# GitLab EE Premium 단일 호스트 Docker 배포

이 스캐폴드는 한국 금융권 카드사 기준의 보수적 운영을 전제로 한 GitLab EE Premium 배포 템플릿입니다. 2026-06-02 기준 공식 최신 안정 릴리스인 GitLab `19.0.0-ee.0`, Runner `alpine-v19.0.0`, Docs `19.0`으로 고정했습니다.

## 아키텍처 설계 요약

- 외부 Nginx가 TLS 종료, HSTS, 접근 로그, WAF/Fail2Ban 연계를 담당합니다.
- Compose는 GitLab HTTP와 GitLab Docs를 `127.0.0.1`에만 바인딩합니다.
- 회사 정책상 GitLab SSH는 제공하지 않습니다. SSH 포트는 publish하지 않고 Git over HTTPS의 계정 비밀번호 인증을 허용합니다.
- GitLab Premium에서 제공하는 비밀번호 복잡도 정책, MR approval, Coverage-Check를 사용합니다.
- Ultimate 전용 내장 SAST 기능은 사용하지 않고 사내 CodeRay 6.0 RG CLI, Checkstyle, coverage 템플릿으로 대체합니다.
- Docker runner는 표준 빌드에 사용하고, Shell runner는 protected/tagged CodeRay 작업 전용으로 제한합니다.
- Docker runner는 단일 호스트 자원 고갈을 막기 위해 전체 최대 10개 job을 병렬 처리합니다. Shell runner는 고위험 executor이므로 1개 job으로 제한합니다.
- Git/Registry HTTP 인증 실패 IP 차단은 GitLab 내장 Rack Attack을 사용합니다. Nginx access log의 `401` 기반 Fail2Ban 예시는 정상 Git 요청을 오탐하므로 비활성화했습니다.
- GitLab Ruby RSS 증가를 낮추기 위해 Puma worker/thread, Sidekiq concurrency, jemalloc decay, 내장 Prometheus/exporter 비활성화 값을 `.env`로 제어합니다.

## 핵심 코드/스크립트 구현

1. `.env.example`을 `.env`로 복사하고 FQDN, SMTP, Runner 토큰, Nexus URL을 수정합니다.
2. 외부 Nginx에는 `ops/nginx/gitlab-ee-reverse-proxy.conf`를 기반으로 upstream을 연결합니다.
3. GitLab을 기동합니다. GitLab 18.x에서 올리는 경우 먼저 [GitLab 19.0 breaking changes](https://about.gitlab.com/blog/a-guide-to-the-breaking-changes-in-gitlab-19-0/)를 검토하고 별도 검증 환경에서 업그레이드합니다.

```bash
docker compose up -d gitlab gitlab-docs
docker compose logs -f gitlab
```

4. 최초 root 비밀번호를 확인한 뒤 Premium 라이선스를 GitLab Admin UI에서 등록합니다.

```bash
docker compose exec gitlab grep 'Password:' /etc/gitlab/initial_root_password
```

5. 보안/운영 정책을 적용합니다.

```bash
./scripts/bootstrap-gitlab-settings.sh
```

6. GitLab UI에서 instance/group/project runner를 생성하고 `glrt-` 토큰을 `.env`에 넣습니다. Shell executor 전용 이미지를 포함한 Runner 이미지를 먼저 빌드하고 runtime 설정을 프로비저닝합니다.

```bash
./images/build-images.sh
./scripts/register-runners.sh
docker compose up -d gitlab-runner-docker gitlab-runner-shell
```

`register-runners.sh`는 기존 runtime `config.toml`을 덮어쓰지 않습니다. GitLab Runner가 자동 회전 토큰을 저장할 수 있으므로 교체 전 기존 파일을 별도로 검토합니다.

7. 운영 cron 예시는 `ops/cron.d/gitlab-ee`를 참고해 root crontab 또는 운영 표준 스케줄러에 등록합니다.

## 성능 튜닝 가이드

기본 프로파일은 단일 호스트에서 GitLab Rails(Ruby) 메모리를 낮추는 방향입니다. GitLab 공식 요구사항은 일반 운영 기준 16GB RAM, 일부 제약 환경은 8GB 이상을 안내하며, Puma worker와 thread는 CPU/RAM 및 PostgreSQL 연결 수에 영향을 줍니다. 메모리가 부족한 경우 GitLab 공식 memory-constrained 설정은 Puma single mode(`GITLAB_PUMA_WORKER_PROCESSES=0`)도 제시하지만, 운영 처리량과 phased restart 제약이 있으므로 검증 환경에서만 먼저 확인합니다.

주요 조정 값:

- `GITLAB_MEMORY_LIMIT=8g`, `GITLAB_MEMORY_SWAP_LIMIT=10g`: GitLab 컨테이너의 Docker cgroup 상한입니다.
- `GITLAB_PUMA_WORKER_PROCESSES=2`, `GITLAB_PUMA_MAX_THREADS=4`: Web 요청 처리량과 Ruby RSS의 핵심 레버입니다.
- `GITLAB_PUMA_PER_WORKER_MAX_MEMORY_MB=1200`: Puma worker RSS watchdog 기준입니다. 너무 낮으면 worker restart가 잦아져 응답성이 떨어집니다.
- `GITLAB_SIDEKIQ_CONCURRENCY=10`: background job 동시 처리량을 낮춰 Sidekiq Ruby 메모리와 Redis/DB 연결 수를 줄입니다.
- `GITLAB_DISABLE_BUNDLED_MONITORING=true`: 외부 관측성 스택을 전제로 내장 Prometheus/exporter를 꺼서 메모리를 절약합니다.
- `GITALY_*`: 큰 repository clone/fetch/push가 단일 호스트 자원을 과점하지 않도록 repository 단위 동시성을 제한합니다.

변경 반영:

```bash
docker compose --env-file .env config
docker compose up -d --force-recreate gitlab
docker compose logs -f gitlab
```

메모리 확인:

```bash
docker stats --no-stream gitlab-ee
docker compose exec gitlab bash -lc "ps -eo pid,comm,rss,args --sort=-rss | head -20"
docker compose exec gitlab bash -lc "grep -i 'rss memory limit exceeded' /var/log/gitlab/gitlab-rails/application_json.log || true"
```

공식 참고 문서: [GitLab installation requirements](https://docs.gitlab.com/install/requirements/), [memory-constrained environments](https://docs.gitlab.com/omnibus/settings/memory_constrained_envs/), [Puma settings](https://docs.gitlab.com/administration/operations/puma/), [Sidekiq concurrency](https://docs.gitlab.com/administration/sidekiq/extra_sidekiq_processes/), [Gitaly concurrency limiting](https://docs.gitlab.com/administration/gitaly/concurrency_limiting/).

## 테스트 및 배포 가이드

정적 검증:

```bash
docker compose --env-file .env.example config
./scripts/security-smoke-test.sh --static-only
```

이미지 취약점 스캔은 Docker Desktop 또는 Docker Scout CLI 인증이 필요합니다. 기본값은 로컬 Docker에 빌드된 이미지를 우선 검사하고, 원격 registry 배포 후보를 따로 검증할 때만 `SCOUT_IMAGE_PREFIX=registry://`를 사용합니다.

```bash
./scripts/scan-images.sh
SCOUT_IMAGE_PREFIX=registry:// ./scripts/scan-images.sh gitlab/gitlab-ee:19.0.0-ee.0
```

스크립트는 이미지마다 `docker scout quickview` 요약과 Critical/High CVE 상세 보고서를 `reports/docker-scout/`에 저장합니다. Critical 또는 High가 하나라도 있으면 최종 종료 코드는 실패입니다.

백업 검증:

```bash
./scripts/backup.sh
./scripts/restore-check.sh
```

샘플 Maven 프로젝트 검증:

```bash
cd samples/java-maven
mvn -B verify
```

GitLab 프로젝트에는 `ci/templates/*.yml`을 include하여 CodeRay, Checkstyle, Coverage, Nexus 업로드를 표준화합니다. MR 댓글 갱신에는 `GITLAB_MR_COMMENT_TOKEN` masked/protected CI 변수가 필요합니다.
Nexus 업로드 job은 수동 실행이며 `DEPLOY_ENV=dev`, `stg`, `prd` 중 하나를 명시해야 합니다. `prd` 업로드는 Git tag pipeline에서만 허용됩니다.

## 운영 체크리스트

- GitLab Admin > Settings > Merge requests에서 `Coverage-Check` approval rule을 프로젝트별로 활성화합니다.
- Docker runner는 protected runner로 만들고 untagged job 실행을 비활성화합니다.
- Shell runner는 `secure-shell,coderay` 태그 전용으로 만들고 신뢰된 프로젝트에만 허용합니다.
- Docker runner의 `allowed_images`는 로컬 `bwc/*:*` Runner 이미지로 제한합니다. Docker executor는 `if-not-present` pull 정책으로 로컬에 등록된 이미지를 우선 사용합니다.
- `security/vulnerability-exceptions.yml`의 예외는 만료일과 승인 티켓 없이는 허용하지 않습니다.
- Git HTTP Password auth를 허용하므로 TLS 강제, 로그인 실패 잠금, 90일 비밀번호 만료, 401/실패 로그인 로그 모니터링을 같이 운영합니다.
- 백업 파일은 호스트 보관으로 끝내지 않고 암호화된 별도 저장소로 복제하며 정기 복구 훈련을 수행합니다.

## Docker Scout 기준선

2026-06-02에 공식 amd64 이미지를 `docker scout quickview --platform linux/amd64 registry://...`로 확인한 결과입니다. 취약점 DB 변경에 따라 수치는 달라지므로 운영 승격 때마다 다시 검사합니다.

| 이미지 | Critical | High | 판단 |
| --- | ---: | ---: | --- |
| `gitlab/gitlab-ee:19.0.0-ee.0` | 73 | 92 | 공식 최신 EE 이미지 외 대체 불가. 상세 CVE 검토와 패치 추적 필수 |
| `gitlab/gitlab-runner:alpine-v19.0.0` | 24 | 28 | 최신 Alpine Runner 사용. protected scope와 상세 CVE 검토 필수 |
| `registry.gitlab.com/gitlab-org/technical-writing/docs-gitlab-com/archives:19.0` | 0 | 2 | 외부 비공개 Docs endpoint로 제한하고 후속 패치 추적 |
| `node:24-bookworm-slim` | 1 | 12 | 사용하지 않음 |
| `node:24-alpine3.23` | 0 | 0 | Node runner 베이스로 선택 |
| `maven:3.9.15-eclipse-temurin-21` | 0 | 0 | Maven runner 베이스로 선택 |
| `eclipse-temurin:21-jdk-noble` | 0 | 0 | JDK runner 베이스로 선택 |

잠재적 위험 요소: Git HTTP Password auth, Docker socket 기반 Docker executor, Shell runner, JDK 7은 모두 고위험 영역이므로 protected scope와 로그 모니터링 없이 운영하면 안 됩니다.
