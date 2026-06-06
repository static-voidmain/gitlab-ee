#!/usr/bin/env bash
set -Eeuo pipefail

# 요구사항: GitLab EE와 Runner를 간단하고 재현 가능하게 연결한다.
# 구현상세: glrt- authentication token은 GitLab UI/API에서 Runner 생성 후 발급받아 .env에 넣는다.
# 제약사항: register --template-config는 전역 옵션을 무시하므로 완전한 runtime config를 직접 배치한다.

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

validate_url() {
  local name="$1"
  local value="$2"

  if [[ -z "${value}" ]]; then
    echo "ERROR: ${name} must not be empty." >&2
    exit 1
  fi

  if [[ "${value}" =~ ^https://[^/:[:space:]]+(:[0-9]+)?(/.*)?$ ]]; then
    return 0
  fi

  if [[ "${value}" =~ ^http://(localhost|127\.0\.0\.1)(:[0-9]+)?(/.*)?$ ]]; then
    return 0
  fi

  if [[ "${value}" == http://* ]]; then
    echo "ERROR: ${name} may use http:// only for localhost or 127.0.0.1 smoke tests." >&2
    exit 1
  fi

  echo "ERROR: ${name} must use https://, or http://localhost for smoke tests." >&2
  exit 1
}

validate_runner_url() {
  local value="$1"
  validate_url GITLAB_EXTERNAL_URL "${value}"

  if [[ "${value}" =~ ^http://(localhost|127\.0\.0\.1)(:[0-9]+)?(/.*)?$ ]]; then
    echo "WARNING: GITLAB_EXTERNAL_URL=${value} is valid only for host-local smoke tests." >&2
    echo "WARNING: Runner containers cannot reach GitLab through their own localhost; use this only when validating local config generation." >&2
  fi
}

validate_tokens() {
  validate_token RUNNER_DOCKER_AUTH_TOKEN "${RUNNER_DOCKER_AUTH_TOKEN:-}"
  validate_token RUNNER_SHELL_AUTH_TOKEN "${RUNNER_SHELL_AUTH_TOKEN:-}"
}

install_runner_config() {
  local config_home="$1"
  local template="$2"
  local config_file="${config_home}/config.toml"

  install -d -m 700 "${config_home}"
  if [[ -e "${config_file}" ]]; then
    echo "Keeping existing runner config: ${config_file}"
    echo "Review it manually before replacing it because GitLab Runner can persist rotated tokens there."
  else
    install -m 600 "${template}" "${config_file}"
    echo "Installed runner config: ${config_file}"
  fi
  chmod 600 "${config_file}"
}

main() {
  validate_tokens
  validate_runner_url "${GITLAB_EXTERNAL_URL:-}"

  install_runner_config \
    "${RUNNER_DOCKER_CONFIG_HOME:-./runtime/gitlab-runner/docker}" \
    runner/templates/docker-runner.template.toml

  install_runner_config \
    "${RUNNER_SHELL_CONFIG_HOME:-./runtime/gitlab-runner/shell}" \
    runner/templates/shell-runner.template.toml

  echo "Runner configs provisioned."
  echo "Start runners with: docker compose up -d gitlab-runner-docker gitlab-runner-shell"
  echo "Confirm protected/tagged settings in GitLab UI."
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  main "$@"
fi
