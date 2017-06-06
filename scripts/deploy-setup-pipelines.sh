#!/bin/bash
set -eu

if [ -z "${CF_API:-}" ]; then
  echo "WARNING: \$CF_API not set, the app deployment pipelines will fail"
fi

SCRIPTS_DIR=$(cd "$(dirname "$0")" && pwd)
PIPELINES_DIR="${SCRIPTS_DIR}/../pipelines"

# shellcheck disable=SC2091
$("${SCRIPTS_DIR}/environment.sh")
"${SCRIPTS_DIR}/fly_sync_and_login.sh"

generate_vars_file() {
  cat <<EOF
---
makefile_env_target: "${MAKEFILE_ENV_TARGET}"
self_update_pipeline: "${SELF_UPDATE_PIPELINE:-true}"
aws_account: "${AWS_ACCOUNT}"
deploy_env: "${DEPLOY_ENV}"
state_bucket_name: "${STATE_BUCKET_NAME:-gds-paas-${DEPLOY_ENV}-state}"
releases_bucket_name: "${RELEASES_BUCKET_NAME:-gds-paas-${DEPLOY_ENV}-releases}"
releases_blobs_bucket_name: "${RELEASES_BLOBS_BUCKET_NAME:-gds-paas-${DEPLOY_ENV}-releases-blobs}"
branch_name: "${BRANCH:-master}"
aws_region: "${AWS_DEFAULT_REGION:-eu-west-1}"
concourse_atc_password: "${CONCOURSE_ATC_PASSWORD}"
concourse_url: "${CONCOURSE_URL}"
system_dns_zone_name: "${SYSTEM_DNS_ZONE_NAME}"
pipeline_trigger_file: "${pipeline_name}.trigger"
github_access_token: "${GITHUB_ACCESS_TOKEN}"
cf_api: "${CF_API:-}"
cf_api_secure: "${CF_API_SECURE:-}"
cf_user: "${CF_USER}"
cf_password: "${CF_PASSWORD}"
EOF
}

upload_pipeline() {
  UNPAUSE_PIPELINES=true bash "${SCRIPTS_DIR}/deploy-pipeline.sh" \
        "${pipeline_name}" \
        "${PIPELINES_DIR}/${pipeline_name}.yml" \
        <(generate_vars_file)
}

remove_pipeline() {
  yes y | ${FLY_CMD} -t "${FLY_TARGET}" destroy-pipeline --pipeline "${pipeline_name}" || true
}

pipeline_name=setup
generate_vars_file > /dev/null # Check for missing vars

upload_pipeline

pipeline_name=destroy
if [ "${ENABLE_DESTROY:-}" = "true" ]; then
  upload_pipeline
else
  remove_pipeline
fi
