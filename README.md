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
- 운영 기본 프로파일은 GitLab Omnibus의 Puma, Sidekiq, Gitaly, KAS, bundled monitoring 기본 구성을 유지합니다.
- VMware 2 vCPU / 6 GiB RAM 검증 환경은 별도 `.env.vmware-2c6g.example`와 `docker-compose.vmware-2c6g.yml` override로만 저메모리 튜닝을 적용합니다.
- macOS Apple Silicon과 Windows 10 Docker Desktop 검증 환경은 `scripts/prepare-platform-env.sh`로 GitLab EE 본체 `GITLAB_PLATFORM`을 host 아키텍처에 맞게 생성합니다.

## 핵심 코드/스크립트 구현

1. `.env.example`을 `.env`로 복사하거나 `scripts/prepare-platform-env.sh default --force`로 생성한 뒤 FQDN, SMTP, Runner 토큰, Nexus URL을 수정합니다.
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

## 프로파일 가이드

운영 서버는 `.env.example`을 기반으로 `GITLAB_RESOURCE_PROFILE=default`를 유지합니다. 이 프로파일은 GitLab Omnibus의 Puma, Sidekiq, Gitaly, KAS, bundled Prometheus/exporter 기본 구성을 건드리지 않습니다.
기존 저메모리 테스트용 `.env`를 운영에 재사용하면 `GITLAB_DISABLE_BUNDLED_MONITORING=true` 같은 값이 남아 기본 구성이 깨질 수 있으므로 운영 `.env`는 `.env.example`에서 다시 생성합니다.

```bash
./scripts/prepare-platform-env.sh default --force
docker compose --env-file .env config
docker compose --env-file .env up -d gitlab gitlab-docs
```

VMware 2 vCPU / 6 GiB RAM 검증 환경은 GitLab 공식 권장 사양보다 작으므로 기능 검증과 smoke test 용도로만 사용합니다. 집의 macOS M2Max Docker Desktop과 회사의 VMware Ubuntu Live Server 24.04.4 검증 VM에서만 이 저메모리 프로파일과 Docker 리소스 제한 override를 함께 적용합니다.
macOS M2Max 같은 Apple Silicon Docker Desktop은 `GITLAB_PLATFORM=linux/arm64`, 일반 x86_64 랙서버/VMware 위 Ubuntu는 `GITLAB_PLATFORM=linux/amd64`를 사용해야 합니다. GitLab EE tag가 로컬에 amd64로 캐시된 경우 platform을 생략하면 macOS에서도 amd64/QEMU로 재생성될 수 있으므로, 반드시 `scripts/prepare-platform-env.sh`로 로컬 `.env`를 생성합니다.
Docker Desktop 환경에서는 `/srv` 같은 host 경로가 mount 거부될 수 있으므로, 이 테스트 프로파일은 GitLab config/log/data/backups를 workspace 내부 `./runtime/gitlab-ee`에 저장합니다. VMware Ubuntu 검증 VM에서도 같은 경로를 사용해 smoke test 데이터를 운영 경로와 분리합니다.

```bash
./scripts/prepare-platform-env.sh vmware-2c6g --force
docker compose --env-file .env -f docker-compose.yml -f docker-compose.vmware-2c6g.yml config
docker compose --env-file .env -f docker-compose.yml -f docker-compose.vmware-2c6g.yml up -d gitlab gitlab-docs
```

Ubuntu Live Server 24.04.4 검증 VM에서는 Docker Engine 설치 후 같은 스크립트를 실행합니다. x86_64 VMware VM이면 `GITLAB_PLATFORM=linux/amd64`가 생성되어야 합니다.

VMware 테스트 프로파일 주요 값:

- `GITLAB_RESOURCE_PROFILE=vmware_2c_6g`: Puma, Sidekiq, Gitaly 튜닝을 활성화합니다.
- `GITLAB_CPU_LIMIT=2`, `GITLAB_MEMORY_LIMIT=5g`, `GITLAB_MEMORY_SWAP_LIMIT=6g`: 작은 VM에서 Docker cgroup 상한을 둡니다.
- `GITLAB_PUMA_WORKER_PROCESSES=1`, `GITLAB_PUMA_PER_WORKER_MAX_MEMORY_MB=1400`, `GITLAB_PUMA_MAX_THREADS=4`: Web 처리량보다 Ruby RSS 절감을 우선하되 GitLab 19 첫 기동의 Puma worker churn을 피합니다.
- `GITLAB_SIDEKIQ_CONCURRENCY=5`: background job 동시 처리량을 낮춰 Redis/DB 연결과 Ruby 메모리를 줄입니다.
- `GITLAB_BUNDLED_MONITORING_ENABLE=false`, `GITLAB_KAS_ENABLE=false`: 검증 VM에서는 기본 비활성화하고 필요한 기능 테스트 때만 켭니다.

## 운영 VMware VM 권장 옵션

운영 서버는 일반 랙서버 위 VMware에서 기동되는 x86_64 Ubuntu LTS VM을 전제로 합니다. GitLab 공식 요구사항은 최대 20 RPS 또는 1,000 users 기준으로 8 vCPU, 16 GiB RAM을 안내하지만, GitLab EE 19.x 단일 호스트 운영과 upgrade/reconfigure 여유를 고려해 아래 값을 시작점으로 권장합니다.

| 구분 | Smoke test VM | 운영 최소 기준 | 운영 권장 시작점 |
| --- | ---: | ---: | ---: |
| 용도 | 기능 검증, 기동 확인 | 소규모 운영 하한 | 단일 호스트 운영 표준 |
| vCPU | 2 | 8 | 8-12 |
| RAM | 6 GiB | 16 GiB | 32 GiB |
| Swap | 2-4 GiB | 8 GiB | 8-16 GiB, `vm.swappiness=10` |
| OS disk | 40 GiB | 80 GiB | 100 GiB |
| GitLab data disk | workspace `./runtime` | 300 GiB 이상 SSD | repository 총량의 3배 이상 또는 500 GiB 이상 SSD/NVMe |
| Docker memory limit | 5 GiB | 설정하지 않음 | 설정하지 않음 |
| GitLab profile | `vmware_2c_6g` | `default` | `default` |

VMware 옵션:

- vCPU는 물리 NUMA node 하나 안에 들어가도록 시작합니다. 처음부터 과도하게 크게 잡지 말고 CPU Ready가 지속적으로 5%를 넘으면 증설합니다.
- 운영 VM은 메모리 overcommit을 피하고 가능하면 100% memory reservation을 둡니다. Ballooning이나 swapping이 발생하면 PostgreSQL, Redis, Puma latency가 급격히 나빠집니다.
- GitLab data volume은 OS disk와 분리한 SSD/NVMe datastore에 배치합니다. 컨트롤러는 VMware Paravirtual SCSI 또는 NVMe, NIC는 VMXNET3를 사용합니다.
- Thin provisioning은 datastore 여유와 경보가 확실할 때만 사용합니다. 예측 가능한 latency가 더 중요하면 eager-zeroed thick을 우선합니다.
- 장기 VMware snapshot은 금지합니다. 패치 직전의 단기 snapshot도 작업 직후 삭제하고, 복구 기준은 `./scripts/backup.sh`와 정기 restore drill로 둡니다.
- VM 시간은 chrony/NTP 또는 VMware Tools 중 하나를 기준으로만 동기화합니다. 이중 동기화로 시간이 튀면 CI job, token, audit log 추적이 흔들릴 수 있습니다.
- GitLab Runner, Docker build cache, Harbor/Nexus 같은 고부하 컴포넌트는 운영 GitLab 본체 VM과 분리합니다. 같은 VM에 Runner를 올릴 경우 protected/tagged runner와 concurrency 제한을 반드시 유지합니다.

공식 요구사항을 넘는 사용자 수, 대형 repository, mirroring, 대량 CI event가 예상되면 단일 VM을 키우기보다 GitLab reference architecture 기준으로 PostgreSQL, Gitaly, Redis, Runner 분리를 먼저 검토합니다.

기능 재활성화:

```bash
# GitLab bundled Prometheus/exporter 사용
GITLAB_BUNDLED_MONITORING_ENABLE=true
GITLAB_PUMA_EXPORTER_ENABLE=false
GITLAB_SIDEKIQ_METRICS_ENABLE=true

# GitLab Relay(KAS) 사용
GITLAB_KAS_ENABLE=true
```

GitLab Rails의 `/-/metrics` endpoint는 GitLab Admin UI의 `Settings > Metrics and profiling`에서 켤 수 있지만, bundled Prometheus/exporter 서비스와 KAS 실행 여부는 Omnibus 설정을 재구성해야 합니다. Compose 반영 시에는 아래 변경 반영 절차를 사용합니다.

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

공식 참고 문서: [GitLab installation requirements](https://docs.gitlab.com/install/requirements/), [memory-constrained environments](https://docs.gitlab.com/omnibus/settings/memory_constrained_envs/), [Puma settings](https://docs.gitlab.com/administration/operations/puma/), [Sidekiq concurrency](https://docs.gitlab.com/administration/sidekiq/extra_sidekiq_processes/), [Gitaly concurrency limiting](https://docs.gitlab.com/administration/gitaly/concurrency_limiting/), [Monitoring GitLab with Prometheus](https://docs.gitlab.com/administration/monitoring/prometheus/), [GitLab Prometheus metrics](https://docs.gitlab.com/administration/monitoring/prometheus/gitlab_metrics/), [GitLab Relay(KAS)](https://docs.gitlab.com/administration/clusters/kas/).

## 테스트 및 배포 가이드

정적 검증:

```bash
GITLAB_ENV_FILE=.env.example GITLAB_PLATFORM=linux/amd64 docker compose --env-file .env.example config
GITLAB_ENV_FILE=.env.vmware-2c6g.example GITLAB_PLATFORM=linux/amd64 docker compose --env-file .env.vmware-2c6g.example -f docker-compose.yml -f docker-compose.vmware-2c6g.yml config
./scripts/security-smoke-test.sh --static-only
```

플랫폼별 smoke test:

```bash
./scripts/prepare-platform-env.sh vmware-2c6g --force
docker compose --env-file .env -f docker-compose.yml -f docker-compose.vmware-2c6g.yml up -d gitlab gitlab-docs
./scripts/security-smoke-test.sh
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
