#!/usr/bin/env bash
set -Eeuo pipefail

# 요구사항: GitLab EE와 Runner를 간단하고 재현 가능하게 연결한다.
# 구현상세: glrt- authentication token은 GitLab UI/API에서 Runner 생성 후 발급받아 .env에 넣는다.

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${ROOT_DIR}"

if [[ ! -f .env ]]; then
  echo "ERROR: .env file is required. Copy .env.example to .env first." >&2
  exit 1
fi

set -a
# shellcheck disable=SC1091
source .env
set +a

validate_token() {
  local name="$1"
  local value="$2"
  if [[ -z "${value}" || "${value}" == glrt-replace-* || "${value}" != glrt-* ]]; then
    echo "ERROR: ${name} must be a real glrt- runner authentication token." >&2
    exit 1
  fi
}

register_runner() {
  local service="$1"
  local token="$2"
  local description="$3"
  local executor="$4"
  local template="$5"

  echo "Registering ${description} (${executor})..."
  docker compose run --rm "${service}" register \
    --non-interactive \
    --url "${GITLAB_EXTERNAL_URL}" \
    --token "${token}" \
    --name "${description}" \
    --executor "${executor}" \
    --template-config "${template}"
}

validate_token RUNNER_DOCKER_AUTH_TOKEN "${RUNNER_DOCKER_AUTH_TOKEN:-}"
validate_token RUNNER_SHELL_AUTH_TOKEN "${RUNNER_SHELL_AUTH_TOKEN:-}"

register_runner \
  gitlab-runner-docker \
  "${RUNNER_DOCKER_AUTH_TOKEN}" \
  "${RUNNER_DOCKER_DESCRIPTION:-gitlab-ee-docker-amd64}" \
  docker \
  /runner-templates/docker-runner.template.toml

register_runner \
  gitlab-runner-shell \
  "${RUNNER_SHELL_AUTH_TOKEN}" \
  "${RUNNER_SHELL_DESCRIPTION:-gitlab-ee-shell-coderay-amd64}" \
  shell \
  /runner-templates/shell-runner.template.toml

echo "Runner registration completed. Confirm protected/tagged settings in GitLab UI."
