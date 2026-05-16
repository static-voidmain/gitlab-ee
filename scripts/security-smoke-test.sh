#!/usr/bin/env bash
set -Eeuo pipefail

# 테스트 통과: SSH 미노출, loopback bind, Compose 정합성, 기본 endpoint를 확인한다.

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${ROOT_DIR}"

ENV_FILE=".env"
if [[ ! -f "${ENV_FILE}" ]]; then
  ENV_FILE=".env.example"
fi

static_only=false
if [[ "${1:-}" == "--static-only" ]]; then
  static_only=true
fi

echo "Checking compose config..."
compose_config="$(docker compose --env-file "${ENV_FILE}" config)"

if grep -Eq 'published: "?22"?' <<<"${compose_config}"; then
  echo "ERROR: SSH port 22 is published. Company policy forbids GitLab SSH exposure." >&2
  exit 1
fi

if ! grep -q '127.0.0.1' <<<"${compose_config}"; then
  echo "ERROR: Expected loopback-bound ports were not found." >&2
  exit 1
fi

echo "Static checks passed."

if [[ "${static_only}" == true ]]; then
  exit 0
fi

echo "Checking running services..."
docker compose ps gitlab gitlab-docs
curl --fail --silent "http://${GITLAB_HTTP_BIND:-127.0.0.1}:${GITLAB_HTTP_PORT:-8080}/-/health" >/dev/null
curl --fail --silent "http://${GITLAB_DOCS_BIND:-127.0.0.1}:${GITLAB_DOCS_PORT:-4000}/" >/dev/null

echo "Runtime smoke checks passed."
