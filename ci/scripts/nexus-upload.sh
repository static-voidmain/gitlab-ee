#!/usr/bin/env bash
set -Eeuo pipefail

# 요구사항: Runner 산출물(*.jar, *.war)을 사내 Nexus dev/stg/prd repository에 업로드한다.
# 제약사항: Nexus 계정/비밀번호는 masked/protected CI variable로만 주입한다.

for name in NEXUS_URL NEXUS_USERNAME NEXUS_PASSWORD; do
  if [[ -z "${!name:-}" ]]; then
    echo "ERROR: ${name} is required." >&2
    exit 1
  fi
done

deploy_env="${DEPLOY_ENV:-${CI_ENVIRONMENT_NAME:-dev}}"
case "${deploy_env}" in
  dev|develop|development) nexus_repo="${NEXUS_DEV_REPOSITORY:-maven-dev}" ;;
  stg|stage|staging|qa) nexus_repo="${NEXUS_STG_REPOSITORY:-maven-stg}" ;;
  prd|prod|production) nexus_repo="${NEXUS_PRD_REPOSITORY:-maven-prd}" ;;
  *) nexus_repo="${NEXUS_REPOSITORY:-maven-dev}" ;;
esac

mapfile -t artifacts < <(find target -maxdepth 2 -type f \( -name '*.jar' -o -name '*.war' \) \
  ! -name '*-sources.jar' ! -name '*-javadoc.jar' | sort)

if [[ "${#artifacts[@]}" -eq 0 ]]; then
  echo "ERROR: No jar/war artifacts found under target/." >&2
  exit 1
fi

settings_file="$(mktemp)"
trap 'rm -f "${settings_file}"' EXIT

cat >"${settings_file}" <<XML
<settings xmlns="http://maven.apache.org/SETTINGS/1.2.0">
  <servers>
    <server>
      <id>nexus</id>
      <username>${NEXUS_USERNAME}</username>
      <password>${NEXUS_PASSWORD}</password>
    </server>
  </servers>
</settings>
XML

if [[ ! -f pom.xml ]]; then
  echo "ERROR: pom.xml is required for Maven deploy-file metadata." >&2
  exit 1
fi

for artifact in "${artifacts[@]}"; do
  packaging="${artifact##*.}"
  echo "Uploading ${artifact} to ${nexus_repo}"
  mvn -B -ntp --settings "${settings_file}" deploy:deploy-file \
    -DrepositoryId=nexus \
    -Durl="${NEXUS_URL%/}/repository/${nexus_repo}" \
    -DpomFile=pom.xml \
    -Dfile="${artifact}" \
    -Dpackaging="${packaging}" \
    -DgeneratePom=false \
    -DretryFailedDeploymentCount=3
done
