#!/usr/bin/env bash
set -Eeuo pipefail

# 테스트 통과: SSH 미노출, loopback bind, Compose 정합성, 기본 endpoint를 확인한다.

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${ROOT_DIR}"

ENV_FILE=".env"
if [[ ! -f "${ENV_FILE}" ]]; then
  ENV_FILE=".env.example"
fi

env_value() {
  name="$1"
  default_value="$2"
  value="$(grep -E "^${name}=" "${ENV_FILE}" | tail -1 | cut -d= -f2- || true)"
  if [[ -n "${value}" ]]; then
    printf '%s\n' "${value}"
  else
    printf '%s\n' "${default_value}"
  fi
}

static_only=false
if [[ "${1:-}" == "--static-only" ]]; then
  static_only=true
fi

echo "Checking compose config..."
static_platform="${GITLAB_STATIC_PLATFORM:-linux/amd64}"
compose_config="$(GITLAB_ENV_FILE="${ENV_FILE}" GITLAB_PLATFORM="${static_platform}" docker compose --env-file "${ENV_FILE}" config)"
vmware_config="$(GITLAB_ENV_FILE=.env.vmware-2c6g.example GITLAB_PLATFORM="${static_platform}" docker compose --env-file .env.vmware-2c6g.example -f docker-compose.yml -f docker-compose.vmware-2c6g.yml config)"
gitlab_config="$(awk '/^[[:space:]]+gitlab:$/ { in_gitlab=1; next } /^[[:space:]]+gitlab-docs:$/ { in_gitlab=0 } in_gitlab { print }' <<<"${compose_config}")"
vmware_gitlab_config="$(awk '/^[[:space:]]+gitlab:$/ { in_gitlab=1; next } /^[[:space:]]+gitlab-docs:$/ { in_gitlab=0 } in_gitlab { print }' <<<"${vmware_config}")"

if grep -Eq 'published: "?22"?' <<<"${compose_config}"; then
  echo "ERROR: SSH port 22 is published. Company policy forbids GitLab SSH exposure." >&2
  exit 1
fi

if ! grep -q '127.0.0.1' <<<"${compose_config}"; then
  echo "ERROR: Expected loopback-bound ports were not found." >&2
  exit 1
fi

if grep -Eq '^[[:space:]]*mem_limit:' <<<"${compose_config}"; then
  echo "ERROR: Default GitLab compose profile must not set a container memory limit." >&2
  exit 1
fi

if ! grep -Eq "^[[:space:]]*platform:[[:space:]]*${static_platform}$" <<<"${gitlab_config}" ||
  ! grep -Eq "^[[:space:]]*platform:[[:space:]]*${static_platform}$" <<<"${vmware_gitlab_config}"; then
  echo "ERROR: GitLab EE service must pin platform from GITLAB_PLATFORM to avoid stale cached image architecture." >&2
  exit 1
fi

if ! grep -Eq '^[[:space:]]*cpus:[[:space:]]*2' <<<"${vmware_config}" ||
  ! grep -Eq '^[[:space:]]*mem_limit:' <<<"${vmware_config}" ||
  ! grep -Eq '^[[:space:]]*memswap_limit:' <<<"${vmware_config}"; then
  echo "ERROR: VMware 2 vCPU / 6 GiB test override must set GitLab CPU and memory limits." >&2
  exit 1
fi

if grep -q '/srv/gitlab-ee' <<<"${vmware_config}" ||
  ! grep -Eq 'runtime[/\\]+gitlab-ee' <<<"${vmware_config}"; then
  echo "ERROR: VMware test profile must use workspace-local runtime/gitlab-ee bind mounts." >&2
  exit 1
fi

echo "Static checks passed."

if ! grep -q "rack_attack_git_basic_auth" docker-compose.yml; then
  echo "ERROR: GitLab native Git/Registry authentication ban is not configured." >&2
  exit 1
fi

if ! grep -Fq "puma['worker_processes']" docker-compose.yml ||
  ! grep -Fq "sidekiq['concurrency']" docker-compose.yml ||
  ! grep -Fq "GITLAB_RESOURCE_PROFILE" docker-compose.yml ||
  ! grep -Fq "GITLAB_BUNDLED_MONITORING_ENABLE" docker-compose.yml ||
  ! grep -Fq "bundled_monitoring_enabled" docker-compose.yml ||
  ! grep -Fq "gitlab_kas['enable']" docker-compose.yml ||
  ! grep -Fq "GITLAB_RESOURCE_PROFILE=vmware_2c_6g" .env.vmware-2c6g.example; then
  echo "ERROR: GitLab performance/memory tuning settings are not configured." >&2
  exit 1
fi

if ! grep -Fq 'map $http_upgrade $gitlab_connection_upgrade' ops/nginx/gitlab-ee-reverse-proxy.conf ||
  ! grep -Fq 'proxy_set_header Upgrade $http_upgrade;' ops/nginx/gitlab-ee-reverse-proxy.conf ||
  ! grep -Fq 'proxy_set_header Connection $gitlab_connection_upgrade;' ops/nginx/gitlab-ee-reverse-proxy.conf; then
  echo "ERROR: GitLab reverse proxy must pass WebSocket headers for optional KAS support." >&2
  exit 1
fi

if grep -Eq '^[[:space:]]*enabled[[:space:]]*=[[:space:]]*true' ops/fail2ban/jail.d/gitlab-nginx-git-http.local; then
  echo "ERROR: Unsafe Git HTTP 401 Fail2Ban rule must remain disabled." >&2
  exit 1
fi

if ! grep -Eq '^concurrent[[:space:]]*=[[:space:]]*10$' runner/templates/docker-runner.template.toml ||
  ! grep -Eq '^[[:space:]]*limit[[:space:]]*=[[:space:]]*10$' runner/templates/docker-runner.template.toml; then
  echo "ERROR: Docker runner must allow 10 concurrent jobs." >&2
  exit 1
fi

if grep -q 'Type = "s3"' runner/templates/docker-runner.template.toml; then
  echo "ERROR: Incomplete S3 cache configuration must not be enabled." >&2
  exit 1
fi

echo "Security configuration checks passed."

if [[ "${static_only}" == true ]]; then
  exit 0
fi

docker_arch="$(docker info --format '{{.Architecture}}' 2>/dev/null || true)"
docker_arch_normalized=""
expected_gitlab_platform=""
case "$(printf '%s' "${docker_arch}" | tr '[:upper:]' '[:lower:]')" in
  amd64 | x86_64)
    docker_arch_normalized="x86_64"
    expected_gitlab_platform="linux/amd64"
    ;;
  arm64 | aarch64)
    docker_arch_normalized="aarch64"
    expected_gitlab_platform="linux/arm64"
    ;;
esac

gitlab_platform="$(env_value GITLAB_PLATFORM "")"
if [[ -n "${expected_gitlab_platform}" && "${gitlab_platform}" != "${expected_gitlab_platform}" ]]; then
  echo "ERROR: GITLAB_PLATFORM must match Docker host architecture. Expected=${expected_gitlab_platform}, current=${gitlab_platform:-unset}." >&2
  exit 1
fi

echo "Checking running services..."
docker compose ps gitlab gitlab-docs

gitlab_container_name="$(env_value GITLAB_CONTAINER_NAME gitlab-ee)"
gitlab_health="$(docker inspect --format '{{if .State.Health}}{{.State.Health.Status}}{{else}}{{.State.Status}}{{end}}' "${gitlab_container_name}")"
if [[ "${gitlab_health}" != "healthy" ]]; then
  echo "ERROR: GitLab container health must be healthy. Current health=${gitlab_health}." >&2
  exit 1
fi

docker exec "${gitlab_container_name}" curl --fail --silent "http://127.0.0.1/-/health" >/dev/null
gitlab_container_arch="$(docker exec "${gitlab_container_name}" uname -m)"
if [[ -n "${docker_arch_normalized}" && "${gitlab_container_arch}" != "${docker_arch_normalized}" ]]; then
  echo "ERROR: GitLab EE container architecture must match Docker host architecture. Host=${docker_arch_normalized}, container=${gitlab_container_arch}." >&2
  exit 1
fi

gitlab_docs_bind="$(env_value GITLAB_DOCS_BIND 127.0.0.1)"
gitlab_docs_port="$(env_value GITLAB_DOCS_PORT 4000)"
curl --fail --silent "http://${gitlab_docs_bind}:${gitlab_docs_port}/" >/dev/null

echo "Runtime smoke checks passed."
