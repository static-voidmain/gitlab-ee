#!/usr/bin/env bash
set -Eeuo pipefail

# 운영: 90일 비밀번호 만료 기준선을 매일 보정한다.
# 구현상세: 신규/비밀번호 변경 직후 password_expires_at이 nil인 계정에 다음 만료일을 부여한다.

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${ROOT_DIR}"

if [[ -f .env ]]; then
  set -a
  # shellcheck disable=SC1091
  source .env
  set +a
fi

docker compose exec -T \
  -e PASSWORD_EXPIRE_DAYS="${PASSWORD_EXPIRE_DAYS:-90}" \
  -e PASSWORD_EXPIRE_SSO_USERS="${PASSWORD_EXPIRE_SSO_USERS:-false}" \
  -e PASSWORD_EXCEPTION_FILE="/opt/gitlab-config/password-expiration-exceptions.yml" \
  gitlab gitlab-rails runner /opt/gitlab-bootstrap/expire_passwords.rb
