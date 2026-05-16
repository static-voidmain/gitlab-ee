# GitLab EE Premium 단일 호스트 Docker 배포

이 스캐폴드는 한국 금융권 카드사 기준의 보수적 운영을 전제로 한 GitLab EE Premium 배포 템플릿입니다. GitLab은 `18.11.3-ee.0`, Runner는 `alpine-v18.11.2`, Docs는 `18.11`로 고정했습니다.

## 아키텍처 설계 요약

- 외부 Nginx가 TLS 종료, HSTS, 접근 로그, WAF/Fail2Ban 연계를 담당합니다.
- Compose는 GitLab HTTP와 GitLab Docs를 `127.0.0.1`에만 바인딩합니다.
- 회사 정책상 GitLab SSH는 제공하지 않습니다. SSH 포트는 publish하지 않고 Git over HTTPS의 계정 비밀번호 인증을 허용합니다.
- GitLab Premium에서 제공하는 비밀번호 복잡도 정책, MR approval, Coverage-Check를 사용합니다.
- Ultimate 전용 내장 SAST 기능은 사용하지 않고 사내 CodeRay 6.0 RG CLI, Checkstyle, coverage 템플릿으로 대체합니다.
- Docker runner는 표준 빌드에 사용하고, Shell runner는 protected/tagged CodeRay 작업 전용으로 제한합니다.

## 핵심 코드/스크립트 구현

1. `.env.example`을 `.env`로 복사하고 FQDN, SMTP, Runner 토큰, Nexus URL을 수정합니다.
2. 외부 Nginx에는 `ops/nginx/gitlab-ee-reverse-proxy.conf`를 기반으로 upstream을 연결합니다.
3. GitLab을 기동합니다.

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

6. GitLab UI에서 instance/group/project runner를 생성하고 `glrt-` 토큰을 `.env`에 넣은 뒤 Runner를 등록합니다.

```bash
./scripts/register-runners.sh
```

7. 운영 cron 예시는 `ops/cron.d/gitlab-ee`를 참고해 root crontab 또는 운영 표준 스케줄러에 등록합니다.

## 테스트 및 배포 가이드

정적 검증:

```bash
docker compose --env-file .env.example config
./scripts/security-smoke-test.sh --static-only
```

이미지 취약점 스캔:

```bash
./scripts/scan-images.sh
```

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

## 운영 체크리스트

- GitLab Admin > Settings > Merge requests에서 `Coverage-Check` approval rule을 프로젝트별로 활성화합니다.
- Docker runner는 protected runner로 만들고 untagged job 실행을 비활성화합니다.
- Shell runner는 `secure-shell,coderay` 태그 전용으로 만들고 신뢰된 프로젝트에만 허용합니다.
- `security/vulnerability-exceptions.yml`의 예외는 만료일과 승인 티켓 없이는 허용하지 않습니다.
- Git HTTP Password auth를 허용하므로 TLS 강제, 로그인 실패 잠금, 90일 비밀번호 만료, 401/실패 로그인 로그 모니터링을 같이 운영합니다.

잠재적 위험 요소: Git HTTP Password auth, Docker socket 기반 Docker executor, Shell runner, JDK 7은 모두 고위험 영역이므로 protected scope와 로그 모니터링 없이 운영하면 안 됩니다.
