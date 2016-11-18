#!/bin/bash
set -eu

SCRIPTS_DIR=$(cd "$(dirname "$0")" && pwd)
PIPELINES_DIR="${SCRIPTS_DIR}/../pipelines"

# shellcheck disable=SC2091
$("${SCRIPTS_DIR}/environment.sh" "$@")
"${SCRIPTS_DIR}/fly_sync_and_login.sh"

env=${DEPLOY_ENV}

generate_vars_file() {
   cat <<EOF
---
makefile_env_target: ${MAKEFILE_ENV_TARGET}
self_update_pipeline: ${SELF_UPDATE_PIPELINE:-true}
aws_account: ${AWS_ACCOUNT}
deploy_env: ${env}
state_bucket: gds-paas-${env}-state
branch_name: ${BRANCH:-master}
aws_region: ${AWS_DEFAULT_REGION:-eu-west-1}
concourse_atc_password: ${CONCOURSE_ATC_PASSWORD}
system_dns_zone_name: ${SYSTEM_DNS_ZONE_NAME}
pipeline_trigger_file: ${pipeline_name}.trigger
EOF
}

generate_manifest_file() {
  # This exists because concourse does not support boolean value interpolation by design
  enable_auto_trigger=$([ "${ENABLE_AUTO_TRIGGER:-}" ] && echo "true" || echo "false")
  sed -e "s/{{auto_trigger}}/${enable_auto_trigger}/" \
    < "${PIPELINES_DIR}/${pipeline_name}.yml"
}

pipeline_name=setup

generate_vars_file > /dev/null # Check for missing vars

bash "${SCRIPTS_DIR}/deploy-pipeline.sh" \
  "${env}" "${pipeline_name}" \
  <(generate_manifest_file) \
  <(generate_vars_file)
