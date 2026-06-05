#!/usr/bin/env bash
set -Eeuo pipefail

# 요구사항: GitLab Premium 보안/운영 정책을 초기 기동 후 자동 적용한다.
# 제약사항: 민감정보는 .env에서만 로드하고, Git 저장소에 하드코딩하지 않는다.

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${ROOT_DIR}"

if [[ -f .env ]]; then
  set -a
  # shellcheck disable=SC1091
  source .env
  set +a
fi

GITLAB_DOCS_EXTERNAL_URL="${GITLAB_DOCS_EXTERNAL_URL:-https://gitlab-docs.example.co.kr}"

if ! docker compose ps -q gitlab >/dev/null 2>&1; then
  echo "ERROR: docker compose service 'gitlab' is not available." >&2
  exit 1
fi

echo "Applying GitLab application settings..."
docker compose exec -T \
  -e GITLAB_DOCS_EXTERNAL_URL="${GITLAB_DOCS_EXTERNAL_URL}" \
  gitlab gitlab-rails runner /opt/gitlab-bootstrap/apply_settings.rb

echo "Scheduling password expiration baseline..."
docker compose exec -T \
  -e PASSWORD_EXPIRE_DAYS="${PASSWORD_EXPIRE_DAYS:-90}" \
  -e PASSWORD_EXCEPTION_FILE="/opt/gitlab-config/password-expiration-exceptions.yml" \
  gitlab gitlab-rails runner /opt/gitlab-bootstrap/expire_passwords.rb

echo "Done."
